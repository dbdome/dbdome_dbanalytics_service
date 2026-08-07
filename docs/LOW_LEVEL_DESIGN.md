# DBDOME dbanalytics Service — Low-Level Design

This document describes the internal architecture of the DBDOME on-prem
service (`dbdome_dbanalytics_service`): its processes, module layout, data
flows, database schema areas, configuration/secrets model, integrations, and
the build/deploy pipeline.

---

## 1. System overview

DBDOME is an on-prem database security & monitoring product. One Python
codebase produces a single frozen executable that runs as **two Windows
services** against a bundled PostgreSQL, with **Grafana as the user-facing
UI**:

```
                                   ┌────────────────────────────┐
 Monitored targets                 │ C:\ProgramData\DBDOME\bin  │
 (SQL Server, Oracle, MySQL,       │                            │
  MariaDB, PostgreSQL,             │  DBDOME_scheduler service  │──collect──► targets
  ClickHouse, Informix)  ◄─ODBC/──►│  (dbdome_service.exe       │
                          drivers  │     --service scheduler)   │
                                   │                            │
  Browser ──:3000──► Grafana ──────│  DBDOME_web service        │
     ▲                (grafana.exe)│  (dbdome_service.exe       │
     │ dashboards link to          │     --service web)         │
     │ :8080 form/API endpoints ──►│  FastAPI on :8080 (HTTPS)  │
                                   └──────────┬─────────────────┘
                                              │
                                   PostgreSQL :5432, db `dbanalytics`
                                   (schemas: config, metrics, monitoring,
                                    alerts, rootcause, log, processes,
                                    jobs, reports, agg, threats, widget, web)
```

- **Scheduler service** — runs the collection/analysis/alerting pipeline on
  intervals (APScheduler).
- **Web service** — FastAPI app serving JSON APIs and small HTML config pages
  that Grafana dashboards link out to (mail config, TLS cert, LDAP, app-login
  guard, panel print/email, RBAC provisioning, data-protection actions...).
- **Grafana** — the login surface and dashboard UI (`:3000`, sqlite
  `grafana.db` under `C:\ProgramData\DBDOME\data`). The web service rewrites
  dashboard IP references at startup to match the machine address.

## 2. Runtime processes and entry points

| Entry point | Role |
|---|---|
| `dbdome_main.py` | Process bootstrap: starts the web server (`start_web()`, uvicorn with optional TLS kwargs) and/or scheduler loop |
| `dbdome_service.py` | Windows service wrapper (`--service web` / `--service scheduler`), managed by NSSM |
| `http_server.py` | The FastAPI application (~8.8k lines): all HTTP endpoints |
| `job_operation_scheduler.py` | APScheduler runtime: `sync_jobs()` config-watcher every 30 s reads `metrics.registered_processes` (`is_active` toggles jobs live — no restart needed), `max_instances=1`, `coalesce=True`, SIGTERM-aware shutdown |
| `api_docs.py` | OpenAPI/endpoint documentation generation |

**Service management:** both services are registered via NSSM from
`C:\ProgramData\DBDOME\bin`. There is **no crash-recovery configured** — a
startup crash leaves :8080 down until manually started — and the deploy
procedure does not restart services by itself.

## 3. Repository layout (module map)

| Path | Contents |
|---|---|
| `collection/` | Per-vendor collectors: `mssql/`, `oracle/`, `mysql/`, `MariaDB/`, `postgres/`, `clickhouse/` (HTTP :8123), `informix/`; `collect_metrics.py` orchestration; `monitored_servers_routines.py` (target↔routine wiring); `purge/` |
| `analysis/` | Metric analysis + LLM agents: generic/custom metric analyzers, SQL-injection & sensitive-column-access analytics, threat population, user-risk, `anomaly_agent.py` / `rootcause_explainer.py` / `self_activity_agent.py` (headless `claude -p` agents), `self_activity_filter.py` (excluded-logins filter applied inside every collector) |
| `processes/` | Scheduled process implementations (registered in `metrics.registered_processes`): GRC scanners (SoD, privilege change, DDL audit, TLS enforcement, vulnerability, cross-border, ransomware guard), data protection (masking engines, auto-mask, continuous discovery, sensitive schema discovery), `app_login_guard.py`, `blocker.py` (kill sessions, gated by `blocker_dry_run`), `internal_health_monitor.py` (disk/CPU/mem/service-down self-alerts), `gmmr_maintenance.py` (partition upkeep), `detection_tree_builder.py`/`detection_tree_executor.py`, `retention_engine.py`, hash-chain writer/verifier (tamper-evident audit), `compliance_report_generator.py` (credential-free, JSON templates incl. India DPDPA/IRDAI/RBI/CERT-In), `threat_response_engine.py`, `rbac_provisioning.py`, `sql_script_runner.py` |
| `alerts/` | `alert_dispatcher.py` (mail/SIEM fan-out of findings; canonical resultset via `rootcause.get_alert_log_resultset_byid(row_id)`), `metrics_api_sender.py` (ingest/heartbeat to dbexpert.ai; `organizations_servers.api_url` drives sends), `event_sender.py` |
| `siem/` | SIEM senders: `wazuh/`, `crowdstrike/`, `fortianalyzer/`, `rapid/` + `generic/` (CEF / LEEF / RFC5424 / JSON over UDP / TCP / TLS / HTTP; `config.siem.service_name` = `"format:transport"`; TCP framing is LF-delimited) |
| `jobs/job_handler.py` | Scheduled report jobs: renders Grafana panels/SQL reports to PDF+CSV and emails them (`config.mail_jobs` / `reports_jobs`, `v_job_scheduler` wiring; SQL reports must be parameter-free) |
| `email_utils/` | SMTP senders (alert mail, attachments) reading `config.mail_config` (+ `config.mail_groups` recipients) |
| `utils/` | `config_dotenv.py` (connection string from exe-adjacent `.env`), `secrets_crypto.py` (Fernet `enc:v1:`; key `DBDOME_SECRET_KEY` in `.env`, outside DB backups), `log4dbexpert.py` (`db_write_log` → `log.operation_log`), `ssl_cert.py` (customer TLS cert install/revert for :8080), `ldap_settings.py` (Grafana LDAP/AD login config — renders `ldap.toml` + patches `custom.ini` + restarts Grafana) |
| `ReportGenerator/`, `print_utils/` | PDF generation (reportlab; `dasboard_capture.py` renders Grafana panels), report templates |
| `config/` | `registered_processes` seeding, server/target update helpers |
| `sql_scripts/` | **Numbered DB-object catalog `NNNN_name.sql`** (idempotent; applied in numeric order; see §10) |
| `synch/`, `metrics_api/` | Sync/ingest helpers for the cloud side |
| `advisories/`, `certification/`, `ssrs/`, `ai/` | Advisory content, certification checks, SSRS integration, ML/embedding assets (`all-MiniLM-L6-v2` path via `.env`) |
| `purgers/` | Data-retention purgers |
| `DBDOME_dbanalytics.spec` | PyInstaller spec — two Analysis blocks → `dbdome_dbanalytics.exe` + `dbdome_service.exe` + shared `_internal\` |

## 4. Data architecture (`dbanalytics` schemas)

| Schema | Role |
|---|---|
| `config` | Installation config: `global_params` (key/value incl. `blocker_dry_run`, `disk_size`, `grafana_db`, `local_ip`), `mail_config` + `mail_groups` (+ `save_mail_config` / `save_mail_group` procedures), `siem`, `ldap_settings` (7400), report/mail job configs |
| `metrics` | Target inventory & wiring: `servers` (monitored targets; passwords `enc:v1:`), `servers_routines`, `registered_processes` (scheduler job registry), `app_logins`/`programs` watchlists (+ `white` flag), `exclude_logins` |
| `monitoring` | Collected data: `general_metric_metadata_results` (**gmmr** — the central results store, partitioned, maintained by `gmmr_maintenance` under a SECURITY DEFINER helper), views `v_hlth_*`/`v_*` consumed by Grafana panels, `parse_execution_plan` |
| `rootcause` | Detection taxonomy: root causes, detection steps (content encrypted at rest — pgcrypto Phase 1, per-session key via libpq options), resolution content, `get_alert_log_resultset_byid` canonical resultset, `v_root_cause_alerts` |
| `alerts` | `alert_log` (two-level partitioning: RANGE(entry_date) → HASH(root_cause_id)), BEFORE-INSERT suppression triggers (excluded/whitelisted logins), `alert_incidents` lifecycle (open → resolved; auto-resolve configurable + customer-only manual resolve via the web form), mail alert log |
| `log` | `operation_log` (service-wide logging via `db_write_log`), DAM audit views (`log.v_*_audit`) |
| `processes` / `jobs` | Process execution bookkeeping; job schedules |
| `threats`, `agg`, `reports`, `widget`, `web` | Threat analytics, aggregations, generated reports, dashboard widgets, web UI state |

**Two DB users**: `dbdome_adm` (runtime owner) and `dbdome_mon_usr`
(monitoring; member of adm). Objects restored from dumps arrive owned by
`postgres` — numbered scripts re-assert ownership with guarded
`ALTER ... OWNER TO dbdome_adm` blocks.

## 5. Collection pipeline

```
sync_jobs (30s) ─ reads metrics.registered_processes (is_active)
      │
      ▼ per interval
process_handler.execute_process ─► collection/<vendor>/monitoring_metrics_*  ─► targets
      │                                  │  (generic query collectors + dedicated
      │                                  │   collectors; ODBC/oracledb/pymysql/
      │                                  │   psycopg2/HTTP for ClickHouse)
      │                                  ▼
      │                     self_activity_filter.filter_excluded_logins
      │                                  ▼
      └──────────────► monitoring.general_metric_metadata_results (gmmr, jsonb)
                                         ▼
                     analysis/analyse_* (thresholds, custom metrics, threats,
                     SQL-injection, sensitive-column access, user risk)
                                         ▼
                              alerts.alert_log (partitioned)
```

Key invariants:
- Every collector path routes through the **excluded-logins filter** (dedicated
  collectors historically bypassed it — fixed; the filter is case-insensitive).
- Metric definitions/credentials come from `metrics.servers` +
  `metrics.servers_routines`; passwords decrypt via `secrets_crypto` at use.
- ODBC builders default the database to `master` when unset (a NULL database
  produced misleading 18456/4060 login failures).

## 6. Alerting & response pipeline

1. Analysis writes findings into `alerts.alert_log`. A **BEFORE INSERT
   trigger** suppresses rows for excluded logins and whitelisted applicative
   logins (`metrics.app_logins.white`), so no downstream path sees them.
2. An AFTER INSERT trigger upserts `alerts.alert_incidents` — the
   open→resolved lifecycle. Auto-resolve is configurable; manual resolve is a
   Grafana-linked form (`/api/resolve-incident-form`, resolution types CHECKed
   in the DB and mirrored in `http_server._RESOLUTION_TYPES`).
3. `alert_dispatcher` fans out: **email** (canonical detection resultset from
   `rootcause.get_alert_log_resultset_byid`) and **SIEM** (per-product senders
   + generic CEF/LEEF/RFC5424/JSON).
4. **Active response**: `app_login_guard` (watched login from watched program →
   alert + optional session kill via `blocker.py`, gated by `blocker_dry_run`),
   `threat_response_engine`, `ransomware_guard`.
5. **Self-monitoring**: `internal_health_monitor` raises disk/CPU/memory/
   service-down alerts about the DBDOME host itself (psutil; `disk_size`
   global param maintained automatically).
6. **Ingest**: `metrics_api_sender` posts findings/heartbeats to the cloud
   (dbexpert.ai) using `organizations_servers` links — a NULL `api_url`
   silently disables sends for that org/server pair.

## 7. Web/API layer (`http_server.py`)

FastAPI app served by uvicorn on **:8080** (HTTPS with a self-signed
"personal" cert by default; customer cert uploadable at `/ssl_certificate`,
stored via `utils/ssl_cert.py`; cert binds at startup → changes need a web
service restart). Selected endpoint families:

| Family | Endpoints (representative) |
|---|---|
| Startup | Dashboard IP rewrite into `grafana.db` (path from `config.global_params.grafana_db`, OS-aware fallback, `GRAFANA_DB` env override) |
| Mail | mail-config form → `POST /submit-mailconfiguration` (two separate transactions: `config.save_mail_config`, then `config.save_mail_group`; failures render an error page and are logged — never silently rolled back), `POST /api/mailconfiguration/test` (send test mail without saving) |
| Panel export | `/api/print-panel` (PDF), `/api/email-panel(-form)` (renders panel PDF/CSV and emails via `config.mail_config`), DAM report equivalents |
| TLS | `/ssl_certificate` + `/api/ssl/{status,upload,revert}` |
| LDAP | `/ldap_settings` + `/api/ldap/{status,save,test,apply}` (Grafana AD login; see `docs/DBDOME_LDAP_Configuration_Guide.md`) |
| Security ops | `/app_login_guard` watchlist config, `/rbac_provision`, data-protection actions (`/dp_dynamic_mask`, `/dp_static_mask`, `/dp_anonymize`), incident resolve form |
| Redirects | `GET /` 302 → Grafana `:3000` dashboard, host taken from `request.url.hostname` (falls back to configured address when no Host header) |

Design conventions: small self-contained dark-theme HTML pages (Grafana-like
styling) + `/api/*` JSON endpoints; page logic delegated to `utils/*` modules;
DB access via `get_connection_string()`; everything logged through
`db_write_log`.

## 8. Grafana integration

- Grafana runs as its own service (`DBDOME_Grafana`) from the same bin;
  provisioning paths must be **absolute** (service cwd is `bin\`); logs under
  `bin\logs`.
- Conf dir `C:\ProgramData\DBDOME\conf` (`custom.ini`, `ldap.toml`,
  provisioning); data `C:\ProgramData\DBDOME\data\grafana.db`.
- Dashboards link back to :8080 forms; the print/email-panel endpoints emit
  UTC `timestamptz` so `$__timeFrom()` filters work, and data links carry
  `${__from}/${__to}`.
- Login: local users by default; optional LDAP/AD via `config.ldap_settings`
  (rendered `ldap.toml` + `[auth.ldap]`; local logins stay enabled as
  fallback).

## 9. Configuration & secrets

| Mechanism | Contents |
|---|---|
| `bin\.env` (exe-adjacent; the live config) | `PG_*` connection, `ORG_IP` (**must equal the machine's LAN IP** — the Ubuntu appliance auto-syncs it on IP change), `DBDOME_SECRET_KEY` (Fernet key), `GRAFANA_EXE` watchdog, Oracle client dir, `LLM` model path |
| `config.global_params` | Runtime-tunable key/values (blocker dry-run, disk size, grafana_db path, install identity...) |
| `utils/secrets_crypto.py` | Reversible app-layer encryption for secrets the service must *use* (target DB passwords, SMTP, LDAP bind): Fernet, `enc:v1:` prefix, key lives **outside** the DB so dumps/backups are useless alone; plaintext passthrough for legacy values; encrypt-on-write, decrypt-on-read |
| Detection-content crypto | `rootcause` detection-step logic encrypted at rest via pgcrypto with a per-session key delivered through libpq `options` (Phase 1 of the IP-protection plan; RBAC hardening via `dbdome_engine`/`dbdome_grafana_ro` roles) |

## 10. Database-object deployment (`sql_scripts/NNNN_*.sql`)

DB objects (tables/views/functions/procedures/seeds) are **numbered idempotent
scripts** applied in numeric order. Convention per script: header comment
with rationale, `CREATE OR REPLACE`/`IF NOT EXISTS`, guarded
`ALTER ... OWNER TO dbdome_adm`. Current tip: `7410`.

Deploying a DB change (no rebuild needed for pure SQL):
1. Edit/add the canonical `sql_scripts/NNNN_*.sql`.
2. Apply it to the live `dbanalytics` immediately (psycopg2, autocommit).
3. Copy into all four `_internal/sql_scripts/` dirs so installs/startups
   converge: `dist_rd\dbdome_dbanalytics\_internal`, `C:\installs\dbdome_update\dbdome\bin\_internal`,
   `C:\installs\dbdome_setup\dbdome\bin\_internal`, `C:\ProgramData\DBDOME\bin\_internal`.
4. Apply to the **golden install DB** `dbanalytics_install` and re-dump it to
   `<installer-tree>\postgres\install\dbanalytics_install.backup`
   (`pg_dump -Fc -Z9 --no-owner --no-acl`) so fresh installs restore the same
   state.

## 11. Build & deploy

- **Build**: `C:\apps\venv314\Scripts\python.exe -m PyInstaller --clean
  --noconfirm --distpath dist_rd --workpath build_rd DBDOME_dbanalytics.spec`
  (~10 min). That venv carries reportlab/matplotlib/scipy/ldap3 — the bare
  Python 3.14 produces a broken ~18 MB bundle; a good exe is **~36-39 MB**.
- **Verify**: exe size, key modules present in the PYZ, smoke import
  ("Application startup complete"; port-in-use error acceptable).
- **Deploy (live box)**: stop `DBDOME_web` + `DBDOME_scheduler` → wait for
  process exit → back up exes + rename `_internal` → robocopy new `_internal`
  → **restore `_internal\.env` from the backup** (top-level `bin\.env` is
  untouched) → copy exes → start services → health-check :8080.
- **Installer trees**: same overlay into `C:\installs\dbdome_update` and
  `C:\installs\dbdome_setup` (no services there), plus the refreshed install
  dump.
- **Ubuntu appliance** (`dbdome_ubuntu`): runs from **source** under
  `/opt/dbdome` — deploy = scp changed `.py` files + `systemctl restart`.

## 12. Integrations

| Integration | Mechanism |
|---|---|
| SIEM | `config.siem` rows (`service_name` = `"format:transport"`); dedicated Wazuh/CrowdStrike/FortiAnalyzer/Rapid senders + generic CEF/LEEF/RFC5424/JSON over UDP/TCP/TLS/HTTP; Wazuh reference setup: manager :514 TCP+UDP with custom dbdome decoder/rules |
| dbexpert.ai cloud | Findings/heartbeat ingest via `alerts/metrics_api_sender` (org-server links; license bootstrap/heartbeat) |
| Email | Exchange/Gmail SMTP via `config.mail_config` (encrypted password, TLS opt), recipients in `config.mail_groups` |
| LLM agents | Headless `claude -p` agents (`analysis/anomaly_agent`, `rootcause_explainer`, `self_activity_agent`) — bounded, read-only prompts; anomaly agent stores findings + raises alerts |

## 13. Known operational gotchas

- Services have **no auto-restart**; deploys don't restart them — always
  verify :8080 after any overlay.
- `ORG_IP` must match the machine LAN IP or dashboard links/ingest and
  target-side registrations misbehave.
- Firewall rules created scoped `Domain,Private` on a Public-categorized NIC
  make :8080/:3000 unreachable externally while working on loopback —
  create/repair rules with `profile=any` (installer fix shipped in
  dbdiagnostics `2a0b1be`; DBDOME boxes may predate it).
- Importing `http_server` in a dev/test session **mutates the live
  `grafana.db`** (startup IP-rewrite) — never import it casually on a
  production box.
- `config.mail_groups.group_name` is UNIQUE; `save_mail_group` upserts on it
  (7410). Pre-7410 boxes roll back the whole mail-config save when re-saving
  a group name — the empty-`mail_config`-with-advanced-sequence signature.
- gmmr grows fast; partition maintenance (`gmmr_maintenance` via SECURITY
  DEFINER) and the purgers/retention engine are load-bearing — check them
  before debugging "missing data".
