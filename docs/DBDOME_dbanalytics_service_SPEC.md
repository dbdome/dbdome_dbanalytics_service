# DBDOME_dbanalytics_service — Comprehensive Specification

> Derived from the live `dbanalytics` PostgreSQL catalog, the `DBDOME_dbanalytics_service`
> codebase, the Grafana deployment under `C:\ProgramData\DBDOME\bin`, and the `config`
> schema. Generated 2026-06-30.

---

## 1. Purpose

DBDOME is an agentless **database security, governance/compliance (GRC), performance and
health monitoring** platform. It continuously interrogates heterogeneous database servers,
maps findings to a large **root-cause catalog** (~7,000 root causes across Security,
Performance and Health), **alerts** (email / SIEM), **enforces data-protection** (masking,
anonymization, session blocking), runs a full **GRC program** (compliance reporting,
attestation, segregation-of-duties, risk register, immutable audit hash chain), and
surfaces everything through **91 Grafana dashboards**.

Supported monitored engines: **Oracle, SQL Server, PostgreSQL, MySQL, MariaDB, Informix**.

---

## 2. Runtime architecture

| Component | Detail |
|---|---|
| **Web service** | `DBDOME_web` → `dbdome_service.exe --service web`; FastAPI + uvicorn; **198 HTTP routes**; ports **8080** and **8001** (`config.global_params.dbexpert.ai.api.port`) |
| **Scheduler service** | `DBDOME_scheduler` → `dbdome_service.exe --service scheduler`; APScheduler; job set driven by `metrics.registered_processes` (live toggle via a 30 s config-watcher) |
| **Grafana** | `DBDOME_Grafana` (NSSM) → `dbdomeg-server.exe`, port **8000** (`config.global_params.grafana.dbexpert.ai.port`); SQLite `grafana.db` under `…\DBDOME\data\` |
| **Catalog DB** | PostgreSQL database **`dbanalytics`** (owner `dbdome_adm`; read role `dbdome_mon_usr`), **21 schemas** |
| **Entry points** | `dbdome_main.py` (run/orchestrator), `dbdome_service.py` (Windows-service wrapper), `http_server.py` (FastAPI app), `job_operation_scheduler.py` (dynamic job resolver) |
| **Build/deploy** | PyInstaller onedir (`DBDOME_dbanalytics.spec`, built with `C:\apps\venv314`) → `C:\ProgramData\DBDOME\bin`; packaged for `C:\installs\dbdome_setup` (full install) and `C:\installs\dbdome_update` (incremental updater). Ubuntu appliance runs the same code from source. |
| **Cloud ingest** | Optional push to `config.global_params.INGEST_URL` (`https://dbexpertai.com/api/ingest`) with `INGEST_API_KEY` |

---

## 3. Data model — `dbanalytics` schemas

| Schema | Tables | Views | Purpose |
|---|---:|---:|---|
| `rootcause` | 20 | 4 | Detection catalog: domains, areas, issues, root_causes, detection_paths/steps, resolution_paths/steps, vendors, risk_level. View `v_rootcauses` flattens runnable detections. |
| `metrics` | 27 | 5 | Monitored `servers`, `custom_metrics`, `registered_processes` (scheduler jobs), server logs. View `v_custom_metrics` = custom_metrics ∪ rootcause detection SQL. |
| `monitoring` | 72 | 858 | Per-root-cause result views over `general_metric_metadata_results` (partitioned jsonb store); helper fns (`get_local_ip`, `jsonb_lower_keys`, `get_alert_log_resultset_byid`). |
| `config` | 36 | 6 | **All feature configuration** (see §10). |
| `alerts` | 4 | — | `alert_log`, `mail_alert_log`, blocks. |
| `anonymization` | 28 | — | Anonymized table copies + masking/tokenization state. |
| `log` | 14 | 25 | Operation log, DDL audit, firewall audit, SoD violations, RBAC/masking/DP logs. |
| `threats` | 8 | — | Behavioural analytics / risk-scoring state. |
| `processes` | 5 | 5 | Detection-tree process runs and history. |
| `jobs` | 5 | — | Job/report scheduling state. |
| `reports` | 2 | — | Rendered HTML/PDF report store. |
| `widget` | 20 | — | Dashboard widget definitions/exports. |
| `siem` / `siem_config` | 1 / 1 | 9 | SIEM forwarding state and views. |
| `users` / `web` / `meta` / `public` / `action` / `flowchart` / `monitoring_history` / `reports` | … | … | Auth, web state, migration ledger (`meta.schema_migrations`), shared objects. |

---

## 4. Collection & detection engine

- **Vendor collectors** (`collection/<vendor>/monitoring_metrics_<vendor>_generic_query.py`)
  for **oracle, mssql, postgres, mysql, MariaDB, informix** (+ `purge`). Each: decrypt
  per-server secret → connect with the production connector → run each metric query →
  `read_sql` → serialize via `utils.metric_json.to_records_json` (datetimes rendered as
  `YYYY-MM-DD HH:MM:SS`, not epoch) → `_build_comparison` vs `expected` → store +
  conditionally alert.
- **Root-cause catalog** (live counts): **Health 2,714 · Performance 2,372 · Security 1,950**
  root causes, under 3 enabled domains (`HLTH`, `PERF`, `SEC`). Each root cause has
  per-vendor **detection paths** with one or more **steps** (multi-step `live → audit`
  trees, e.g. `SEC-SQL-AUD-020`), and **resolution paths/steps** with a `risk_level`.
- **Detection-tree executor** (`processes/detection_tree_executor.py`) walks multi-step
  paths (`on_match_action` / `on_no_match_action` = `confirmed` | `ruled_out` | `next`)
  for diagnosis/evidence; the generic collector runs the flat metric.
- Collection cadence is split by domain: `collect_metrics_operation_sec` (30 s),
  `_perf` (10 s), `_hlth` (10 s), `_critical` (30 s), `_other` (60 s).

---

## 5. Alerting & routing — `config.webook_alerts`

Routing is a matrix keyed by **(metric_type = domain, risk_level)** with per-cell booleans:

| Domain | Risk | mail | SIEM | diagnosis evidence | blocker | auto_mask |
|---|---|:--:|:--:|:--:|:--:|:--:|
| Security | critical | ✔ | ✔ | ✔ | – | ✔ |
| Security | high | ✔ | – | – | – | – |
| Performance | critical/high | – | ✔ | ✔ | – | – |
| Health | high/med/low | – | ✔ | ✔ | – | – |

Plus `is_active` and `recurrency_hours` (mail de-dup window). Mail is gated additionally by
`rootcause.risk_level.is_active`. Delivery:
- **Email** — `email_utils.smtp_email_sender.send_mail_alert_no_attachment` reads
  `config.mail_config` ⋈ `config.mail_groups`; logs to `alerts.mail_alert_log` (72 h dedup,
  SMTP circuit-breaker). The alert body renders `metric_metadata_json` as an HTML table.
- **SIEM** — `config.siem` (e.g. `rapid_7`), Rapid7 + CrowdStrike senders.
- **Diagnosis evidence** — `manage_diagnosys_alerts` attaches the reproduction query/results.
- Findings written to `alerts.alert_log` (one per server+root_cause per hour), surfaced by
  `monitoring.get_alert_log_resultset_byid` for the Grafana alert-detail panel.

---

## 6. Data protection & active response

| Capability | Engine | Config / gate |
|---|---|---|
| Dynamic Data Masking | `processes/data_masking_engine.py`, `auto_mask.py` | `config.masking_rules`; `webook_alerts.auto_mask`; `global_params.masking_dry_run` |
| Static masking / anonymization / tokenization | `processes/data_protection.py` | `anonymization` schema; `config.masking_tokens` |
| Session **blocker** (kill offending sessions) | `processes/blocker.py` | `webook_alerts.blocker`; `global_params.blocker_dry_run` |
| Encryption / tokenize columns | `data_protection.py` (`encrypt_column`) | `global_params.encryption_dry_run` |
| RBAC provisioning | `processes/rbac_provisioning.py` | `/rbac_provision`; `log.rbac_log` |
| Threat response (escalate/notify/suspend/block-IP) | `processes/threat_response_engine.py` | `config.threat_response_playbooks`, `config.blocked_ips`, `config.suspended_users` |

All destructive actions honour **dry-run flags** in `config.global_params`.

---

## 7. GRC / compliance program

Regulations in scope (`config.regulation_profiles`): **GDPR, HIPAA, PCI-DSS, SOC2** (+ PPL
dashboard). Engines (each a scheduler process):

- **Firewall policy engine** — `config.firewall_policies` (56), `grc_firewall_scanner.py` → `log.firewall_audit_log`.
- **Immutable audit hash chain** — `hash_chain_writer.py` (60 s) + `hash_chain_verifier.py` (daily) SHA-256 chain over audit rows.
- **Segregation of Duties** — `sod_scanner.py` vs `config.sod_rules` → `log.sod_violations`.
- **Risk register** — `config.risk_register` (inherent/residual scoring).
- **Control attestation** — `attestation_scheduler.py`, `config.attestation_controls` / `attestation_periods`.
- **Compliance reporting** — `compliance_report_generator.py`: daily PCI-DSS/HIPAA, weekly GDPR/SOC2 PDFs (`config.compliance_report_schedules`).
- **Cross-border transfer tracking** — `cross_border_scanner.py`, `config.data_regions` / `transfer_agreements`.
- **Access review** — `access_review_scheduler.py`, `config.access_review_cycles`.
- **Incident lifecycle / GDPR 72 h** — `incident_gdpr_timer.py`.
- **User risk scoring** — `user_risk_scoring.py` (behaviour baseline, `threats` schema).
- **DDL audit** — `ddl_audit_scanner.py` → `log.ddl_audit_log`.
- **Policy-exception notifier**, **evidence-package generator**, **continuous data discovery / sensitive-schema discovery** (`config.masking_rules` sync), **TLS enforcement** & **vulnerability scanners**.

---

## 8. Scheduler processes (`metrics.registered_processes`)

| Process | Interval | Active (this catalog) | Role |
|---|---:|:--:|---|
| collect_metrics_operation_sec / _perf / _other | 30 / 10 / 60 s | ✔ | Domain collection |
| collect_metrics_operation_hlth / _critical | 10 / 30 s | – | Domain collection |
| gmmr_maintain | 3600 s | ✔ | Partition maintenance + dedup of results store |
| auto_mask | 300 s | ✔ | Apply DDM when a critical alert has `auto_mask` |
| blocker | 120 s | ✔ | Kill sessions for `blocker` root causes (dry-run gated) |
| dump_and_prune_metrics | 86400 s | ✔ | CSV dump + retention prune (`config.dump_metrics`) |
| retention_space_alert | 3600 s | ✔ | Email when free disk < `retention_free_space_alert_pct` |
| grc_firewall_scan / hash_chain_write / hash_chain_verify | 60 / 60 / 86400 s | – | GRC phase 1 |
| user_risk_scoring / compliance_reports_* / sync_masking_rules / run_threat_response / sod_violation_scan / cross_border_scan / attestation_scheduler / incident_gdpr_timer / ddl_audit_scan | various | – | GRC phases 2–6 |
| alerts, analyse_metrics_operation, detection_tree_build/oracle, dashboard_data_export, report_job, metrics_advisories, … | — | – | Optional auxiliary jobs |

*(Toggle any by `UPDATE metrics.registered_processes SET is_active=…`; effective within 30 s.)*

---

## 9. Web / API (`http_server.py`, 198 routes)

Functional groups: configuration forms (`/processform`, `/serverform`, `/mailconfiguration`,
`/siem_configuration`, `/global_param_set`, `/webook_alert_set`, `/custom_metrics`,
`/addrecipients`), reporting (`/generate_report`, `/capture_report`, `/reportbymail`,
`/download_report`), data-protection actions (`/dp_dynamic_mask`, `/dp_static_mask`,
`/dp_anonymize[_pre|_actual|_confirm|_preview]`, `/rbac_provision`, `/sensitive_column_add`),
server lifecycle (`/server_enable`), and the rootcause/GRC admin APIs + the cloud ingest
endpoints.

---

## 10. Configuration reference — the `config` schema (feature switches)

| Table | Drives |
|---|---|
| `global_params` | Global keys: ports (api 8001, grafana 8000), `local_ip`, dry-run flags (`blocker_/masking_/encryption_dry_run`), `dump_location`, `retention_free_space_alert_pct`, `firewall_audit_retention_days`, `INGEST_URL`/`INGEST_API_KEY`, dashboard/data paths |
| `webook_alerts` (12) | Alert routing matrix (mail/SIEM/diagnosis/blocker/auto_mask per domain×risk) |
| `mail_config` / `mail_groups` / `mail_alerts` / `mail_alerts_schedule` / `mail_jobs` | SMTP server + recipient groups + scheduled mailings |
| `siem` / `sime_interface` | SIEM target(s) (Rapid7, CrowdStrike) and interface keys |
| `thresholds` / `alerts` / `alerts_thresholds` / `alerts_reports` / `alerts_issue_root_causes` | Threshold definitions and alert↔report↔rootcause links |
| `reports` (151) / `reports_jobs` | Report catalog (query + URL) and scheduling |
| `retention_policy` (5222) / `dump_metrics` / `dumps` | Per-server/table retention + dump locations |
| `firewall_policies` (56) / `sqli_signatures` (13) | Firewall rules + SQL-injection signatures |
| `masking_rules` / `masking_tokens` | DDM rules + tokenization vault |
| `regulation_profiles` (4) / `compliance_report_schedules` (16) | GDPR/HIPAA/PCI-DSS/SOC2 + report schedules |
| `sod_rules` (4) / `risk_register` / `attestation_controls` (13) / `attestation_periods` | SoD, risk, attestation |
| `data_regions` / `transfer_agreements` / `access_review_cycles` | Cross-border + access review |
| `threat_response_playbooks` (7) / `blocked_ips` / `suspended_users` | Automated response |
| `action_types` | Catalog of remediation actions |

Views: `v_blocked_ips_active`, `v_suspended_users_active`, `v_masking_coverage`,
`v_masking_rules_detail`, `v_unmasked_sensitive_columns`, `v_mail_alert_schedule`.

---

## 11. Grafana (91 dashboards)

Grouped by capability:
- **Discovery & PII** — Data Discovery & Classification; PII Sensitive columns / data in use; Credentials stored in tables; Linked-servers/DBLINK hidden credentials.
- **Activity & Audit** — Activity Monitoring & Audit; Schema DML Tracking; Audit expired; Connections per user; Database restored.
- **Threat & Injection** — Threat Detection & Behavioral Analytics; SQL Injection (boolean/comment based); IPS Dashboard (FortiAnalyzer); Unknown TCP connections.
- **Policy & Protection** — Policy Enforcement & Protection; Policy not enforced; Data Protection; Enabled sysadmin; Locked accounts.
- **Vulnerability & Automation** — Vulnerability Assessment; Automation & Workflows; Blocker Activity; Blocking transactions.
- **GRC suite (15)** — Overview, Compliance, Audit Log, Control Attestation, Cross-Border Transfer, Immutable Audit Hash Chain, Incident Lifecycle, Masking Coverage, Policy Exceptions, Risk Register, Risk Scoring, Threat Response, Segregation of Duties, Access Review.
- **Ops & Config** — Rootcauses, Recent alerts, Alerts, Retention (+ policy), Processes, Custom metrics, Configuration, Email/Mail, SIEM configuration, Connectivity, PPL (Israeli Protection-of-Privacy Law).

Datasource: the PostgreSQL `dbanalytics` catalog; dashboard host links are templated via the
`${global_ip}` variable resolved from `config.get_local_ip()` (kept in sync with the machine LAN IP).

> **See also:** for the exhaustive per-dashboard breakdown — every dashboard's **panels
> (title + type), action buttons, links and drill-downs** — see **§17 "Grafana dashboards —
> full panel / button / link catalog"** in `DBDOME_FUNCTIONALITIES.md`, and **Appendix A
> "Per-panel SQL/query reference"** for the SQL behind each panel.

---

## 12. Integrations

- **SIEM**: Rapid7 InsightIDR, CrowdStrike (config.siem).
- **SMTP**: any server via config.mail_config (TLS).
- **SSRS**: report download/attach (`ssrs` package).
- **Cloud ingest**: `dbexpertai.com/api/ingest` with API key.
- **FortiAnalyzer / IPS**: dashboard integration.

---

## 13. Feature list (summary)

**Monitoring & detection**
- Agentless multi-vendor monitoring (Oracle, SQL Server, PostgreSQL, MySQL, MariaDB, Informix)
- ~7,000 root-cause detections across Security / Performance / Health
- Multi-step detection trees (live activity + audit-trail), per-vendor SQL
- Custom metrics; per-domain collection cadence; partitioned result store with auto-maintenance
- Human-readable timestamps in stored results

**Alerting**
- Routing matrix per domain×risk (email, SIEM, diagnosis evidence, blocker, auto-mask)
- Email (SMTP, recipient groups, dedup, circuit-breaker, HTML result table)
- SIEM forwarding (Rapid7, CrowdStrike); diagnosis-evidence attachment
- Threshold and recurrency controls

**Data protection & response**
- Dynamic + static masking, anonymization, tokenization, column encryption
- Auto-mask on critical findings; session blocker (kill); RBAC provisioning
- Threat-response playbooks: escalate / notify / suspend user / block IP
- Global dry-run safety switches

**GRC / compliance**
- GDPR, HIPAA, PCI-DSS, SOC2 (+ PPL) profiles
- Firewall policy engine; SQL-injection signatures
- Immutable SHA-256 audit hash chain (+ verification)
- Segregation-of-Duties, risk register, control attestation
- Compliance PDF reporting (scheduled); cross-border transfer tracking; access reviews
- Incident lifecycle / GDPR 72-h breach timer; DDL audit; user risk scoring

**Platform**
- FastAPI web (198 routes) + APScheduler (live-toggle jobs)
- 91 Grafana dashboards
- Retention/dump engine with disk-space alerting
- Cloud ingest; PyInstaller packaging (setup + incremental updater); Ubuntu appliance
- IP self-service (`dbdome-setip`) and ORG_IP/local_ip auto-sync on the appliance
</content>
