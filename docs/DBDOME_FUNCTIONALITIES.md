# DBDOME — Complete Functionalities Catalog

> Exhaustive list of every functionality, enumerated from the 198 HTTP routes
> (`http_server.py`), the 35 scheduler/process engines (`processes/`), the vendor
> collectors, and the `config`-schema capabilities. Generated 2026-06-30.

Legend: **[UI]** web page · **[API]** JSON endpoint · **[JOB]** scheduler process ·
**[ENG]** background engine · **[CLI]** appliance tool.

---

## 1. Platform & home
- **[UI]** Landing / home console — `/`, `/dbdome`
- **[UI/API]** Fleet overview (all monitored servers, health) — `/fleet`, `/api/fleet`
- **[API]** Test a database connection (pre-flight) — `/test-connection`
- **[CLI]** Appliance network/IP self-service — `dbdome-setip` (+ console auto-launch)
- **[ENG]** ORG_IP / `config.global_params.local_ip` / Grafana `${global_ip}` auto-sync to LAN IP

## 2. Monitored-server management
- **[UI]** Add/edit a monitored server — `/serverform`, `/submit-serverform`
- **[UI]** Enable/disable a server — `/server_enable`
- **[UI]** Database restore action — `/db_restore`
- Per-server encrypted credentials in `metrics.servers`; vendors: Oracle, SQL Server, PostgreSQL, MySQL, MariaDB, Informix

## 3. Metrics & custom metrics
- **[UI]** Define/edit custom metrics — `/custom_metrics`, `/custom_metrics_update`, `/submit_custom_metrics`, `/submit_custom_metrics_update`
- **[UI]** Enable a custom metric / per-server / all-servers — `/submit_custom_metric_enable`, `/metric_enable`, `/metric_enable_all_servers`, `/submit_metrics_enable`, `/submit_metrics_enable_all_servers`
- **[UI]** Edit a metric's schema column mapping — `/update_schema_column`
- **[JOB]** Domain collection cycles — `collect_metrics_operation_sec` (30s), `_perf` (10s), `_hlth`, `_critical`, `_other` (60s)
- **[ENG]** Per-vendor collectors run detection SQL → serialize (timestamps formatted) → compare vs expected → store in `monitoring.general_metric_metadata_results`
- **[JOB]** `gmmr_maintain` — partition maintenance + duplicate cleanup of the results store
- **[JOB]** `dedup_metric_results`, `purge_general_metric_metadata`, `analyse_metrics_operation`

## 4. Root-cause catalog & detection
- ~7,000 root causes across **Security / Performance / Health** (3 enabled domains)
- **[UI]** Activate/deactivate a root cause — `/root_cause_active`
- **[UI]** Set a root cause's risk level — `/root_cause_risk`
- **[UI]** Manage global risk levels & toggles — `/risklevel`, `/risklevel_toggle`, `/submit-risklevel`, `/api/risk-level/list`
- Multi-step detection paths (live activity + audit trail) per vendor
- **[ENG]** Detection-tree executor — `processes/detection_tree_executor.py`; **[JOB]** `detection_tree_build`, `detection_tree_oracle`
- **[ENG]** Advisories — `advisories/` (`metrics_advisory`, `dashboard_advisories`)

## 5. Scheduler / process control
- **[UI]** View/toggle background processes — `/processform`, `/submit-processform`
- Live job toggling via `metrics.registered_processes.is_active` (effective ≤30s)
- **[ENG]** `process_handler.py` orchestrates registered processes

## 6. Alerting
- **[UI/API]** Alert dashboard — `/alert_dashboard`, `/api/alert_dashboard`
- **[UI/API]** Alert rules CRUD — `/alert_rules`, `/api/alert-rules`, `/submit-alert-rule`, `/api/delete-alert-rule`
- **[UI/API]** Alert thresholds CRUD — `/alert_thresholds`, `/api/alert-thresholds`, `/submit-alert-threshold`, `/api/delete-threshold`
- **[UI/API]** Webhook / routing alerts CRUD (the domain×risk matrix) — `/webhook_alerts`, `/api/webhook-alerts`, `/webook_alert_set`, `/submit-webhook-alert`, `/api/delete-webhook-alert`
- **[ENG]** Alert dispatch: email + SIEM + diagnosis-evidence per `config.webook_alerts`
- Findings → `alerts.alert_log`; mail → `alerts.mail_alert_log` (72h dedup, SMTP circuit-breaker, HTML result-table body)
- **[UI/API]** GRC alert channels CRUD + delivery log — `/grc/alert-channels`, `/api/grc-alerts/channels` (GET/POST/PUT/DELETE), `/api/grc-alerts/delivery-log`

## 7. Email / SMTP
- **[UI]** Mail server configuration — `/mailconfiguration`, `/email_configuration`, `/submit-mailconfiguration`, `/submit_email_configuration`
- **[UI]** Recipient groups — `/addrecipients`, `/submit-addrecipients`
- **[API]** Mail config & group management — `/api/mail-config/list`, `/api/mail-config/delete`, `/api/mail-group/delete`
- **[UI/API]** Email panel (send a dashboard panel) — `/api/email-panel`, `/api/email-panel-form`, `/api/print-panel`

## 8. Reports
- **[UI]** Report catalog & editor — `/reports`, `/reports/edit`, `/reports/save`, `/api/reports/list`, `/api/toggle-report`
- **[UI]** Report scheduling — `/report_schedule`, `/submit-report-schedule`, `/api/report-schedules`
- **[UI]** Generate / capture / download / email a report — `/generate_report`, `/submit-generate_report`, `/capture_report`, `/submit-report_capture`, `/download_report`, `/reportbymail`, `/submit-reportbymail`
- **[ENG]** PDF/HTML rendering — `ReportGenerator/`, dashboard capture (`print_utils/`)

## 9. Data protection & active response
- **[UI]** Dynamic masking — `/dp_dynamic_mask`, `/mask_column`; revert — `/dp_revert_mask`
- **[UI]** Static masking — `/dp_static_mask`
- **[UI]** Anonymization (3-phase) — `/dp_anonymize`, `/dp_anonymize_pre`, `/dp_anonymize_actual`, `/dp_anonymize_confirm`, `/dp_anonymize_preview`
- **[UI]** Tokenization (phased) — `/dp_tokenize`, `/dp_tokenize_pre`, `/dp_tokenize_actual`, `/dp_revert_tokenize`
- **[UI]** Column encryption — `/encrypt_column`, `/revert_encryption`
- **[UI]** RBAC provisioning — `/rbac_provision`
- **[UI]** Generic remediation action — `/take_action`
- **[API]** Masking rules CRUD + sync — `/api/masking-rules` (GET/POST/PUT), `/api/masking-rules/sync`, `/grc/masking-rules`
- **[JOB]** `auto_mask` — apply DDM when a critical alert has `auto_mask=true`
- **[JOB/ENG]** `blocker` — kill offending sessions (gated by `blocker_dry_run`)
- **[ENG]** `data_masking_engine`, `data_protection`, `rbac_provisioning` (dry-run flags for mask/encrypt/block)

## 10. Sensitive-data discovery / PII
- **[UI]** Sensitive schema & columns — `/sensitive_schema`, `/sensitive_column_add`
- **[API]** Discover / toggle sensitive columns — `/api/sensitive-schema`, `/api/sensitive-schema/discover`, `/toggle`, `/bulk-toggle`
- **[API]** Discovery candidates review — `/api/discovery-candidates`, `/api/discovery-candidates/{id}`
- **[ENG]** `continuous_data_discovery`, `sensitive_schema_discovery`

## 11. SIEM integration
- **[UI]** SIEM configuration — `/siem_configuration`, `/submit_siem_configuration`
- **[UI/API]** IPS dashboard (FortiAnalyzer) — `/siem/ips-dashboard`, `/api/siem/ips-dashboard`
- **[API]** IPS report download / schedule / email — `/api/siem/ips-report/download`, `/schedule`, `/email`
- **[ENG]** Rapid7 + CrowdStrike forwarders (`config.siem`, `siem` schema)

## 12. Retention & disk management
- **[UI]** Retention policy — `/retention_policy`, `/submit_retention_policy`
- **[API]** Retention policies CRUD + executions — `/api/retention/policies` (GET/POST/PUT), `/api/retention/executions`
- **[JOB]** `dump_and_prune_metrics` — CSV dump + prune by per-metric retention
- **[JOB]** `retention_space_alert` — email when free disk < threshold
- **[ENG]** `retention_engine`, `dump_metrics`

## 13. Global parameters / configuration
- **[UI/API]** Global params CRUD — `/global_params`, `/global_param_set`, `/submit-global-param`, `/api/global-params`, `/api/delete-global-param`
- Keys: ports, dry-run flags, ingest URL/key, dump location, disk-alert %, retention days, paths

## 14. GRC — Governance, Risk & Compliance
**Dashboards/pages (`/grc/*`)** + **APIs (`/api/*`)**:
- **Compliance reporting** — `/grc/compliance-reports`, `/api/compliance-reports`, `/run`, `/schedules` (GET/PUT), `/download/{file}`; **[JOB]** `compliance_reports_daily` (PCI-DSS/HIPAA), `compliance_reports_weekly` (GDPR/SOC2)
- **Audit log** — `/grc/audit-log`, `/api/audit-log`
- **DDL audit** — `/grc/ddl-audit`, `/api/ddl-audit/logs`, `/api/ddl-audit/summary`; **[JOB]** `ddl_audit_scan`
- **Immutable audit hash chain** — **[JOB]** `hash_chain_write` (60s), `hash_chain_verify` (daily) — SHA-256 chain over audit rows
- **Firewall policies** — `/grc/policies`, `/api/firewall-policies` (GET/POST/PUT/DELETE), `/apply-template`; **[JOB]** `grc_firewall_scan`
- **Segregation of Duties** — `/grc/sod-violations`, `/api/sod/rules` (GET/POST/PUT), `/api/sod/violations`, `/acknowledge`; **[JOB]** `sod_violation_scan`
- **Risk register & scoring** — `/grc/risk-dashboard`, `/api/risk-scores`, `/{server}/{login}/events`; **[JOB]** `user_risk_scoring`
- **Control attestation** — **[JOB]** `attestation_scheduler` (`config.attestation_controls`/`periods`)
- **Threat response** — `/grc/threat-response`, `/api/threat-response/playbooks` (GET/POST/PUT), `/blocked-ips` (GET/POST/DELETE), `/suspended-users` (GET/POST/DELETE), `/incidents` (GET/POST/PUT), `/response-log`; **[JOB]** `run_threat_response` (escalate/notify/suspend/block-IP)
- **Cross-border transfer tracking** — `/grc/...`; **[JOB]** `cross_border_scan` (`config.data_regions`/`transfer_agreements`)
- **Access review** — `/grc/access-review`, `/api/access-review/cycles` (GET/POST), `/instances`
- **Incident / GDPR 72h** — `/api/threat-response/incidents`; **[JOB]** `incident_gdpr_timer`
- **Policy exceptions** — `/grc/policy-exceptions`, `/api/policy-exceptions` (GET/POST/PUT)
- **Privilege-change tracking** — `/grc/privilege-changes`, `/api/privilege-changes`, `/recent-summary`; **[ENG]** `privilege_change_scanner`
- **Regulation controls** — `/grc/regulation-controls`, `/api/regulation-controls`
- **Evidence packages** — `/grc/evidence-packages`, `/api/evidence-packages`, `/generate`, `/{id}/download/{type}`; **[ENG]** `evidence_package_generator`
- **TLS enforcement** — `/grc/tls-enforcement`, `/api/tls/policies` (GET/POST/PUT), `/api/tls/violations`; **[ENG]** `tls_enforcement_scanner`
- **Vulnerability assessment** — `/grc/vulnerability-assessment`, `/api/vulnerability/findings`, `/cve-watchlist` (GET/POST/PUT), `/scan`; **[ENG]** `vulnerability_scanner`
- **Data retention (GRC view)** — `/grc/data-retention`
- **Masking coverage** — `/grc/masking-rules`; **[JOB]** `sync_masking_rules`

## 15. Visualization (Grafana, 91 dashboards)
Discovery & PII, Activity & Audit, Threat/Injection, Policy & Protection, Vulnerability,
Automation/Workflows, the 15-dashboard GRC suite, SIEM/IPS, Retention, Blocker, Configuration,
and the Israeli PPL dashboard — all over the `dbanalytics` PostgreSQL datasource with
`${global_ip}`-templated links.

## 16. Integrations & packaging
- **Cloud ingest** to `dbexpertai.com/api/ingest` (API key)
- **SIEM**: Rapid7, CrowdStrike; **IPS**: FortiAnalyzer
- **SSRS** report download/attach; **SMTP** email
- **Packaging**: full installer (`dbdome_setup`), incremental updater (`dbdome_update`), Ubuntu appliance (eggs ISO), Windows services via NSSM

---

## 17. Grafana dashboards — full panel / button / link catalog

**Shared dashboard chrome** (on essentially every dashboard): a top nav menu linking *Alert dashboard, Alert rules, Alert thresholds, Email configuration, Risk-level alert, Webhook alerts*; and on **every panel** an *Email panel* (`/api/email-panel-form`) and *Print panel* (`/api/print-panel`) action. These are omitted from the per-dashboard lists below.

Totals: **89 dashboards, 895 panels, 74 action buttons**.


### 1. Data Discovery & Classification
*Variables:* global_ip, issue_id, rc_id
- **Panels (27):** table x16, stat x5, text x4, timeseries x1, bargauge x1
  - Sensitive Columns (PII), PII Issues Detected, PII Access Alerts, Audit Issues, Servers Scanned, Issues (PII), Root causes (PII) - ${issue_id}, Metric metadata - ${rc_id}, Sensitive Data (PII) — Sensitive columns actively queried (PII in use), Alerts, PII Root Cause Findings (SEC-SQL-PRI), Audit Findings Over Time, Top Audit Root Causes, Audit Trail Findings (SEC-SQL-AUD), Sensitive by table , column, Sensitive Transactions by User, Misunderstanding of Encryption (TDE), Performance Overhead Fears, PII Exposed in Clear Text: Legacy Schema Constraints, In-House ""Masking"" Logic Failure, Key Management Complexity, Lack of Native Masking Features (Old Versions), Unsecured Backups/Snapshots
- **Action buttons:** /generate_report/DAM%20Compliance%20Report, /generate_report/Privileged%20Access%20Oversight%20Report, /sensitive_schema
- **Links:** /sensitive_schema
- **Drill-downs:** /d/addpcfp/1-data-discovery-and-classification, /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### 10. Unknown TCP connections
*Variables:* global_ip
- **Panels (4):** text x3, table x1
  - Unkown TCP connections
- **Drill-downs:** /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### 11. Transaction requests
*Variables:* global_ip
- **Panels (4):** text x3, table x1
  - Trnsaction requests
- **Drill-downs:** /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### 2. Activity Monitoring & Audit
*Variables:* server, login_name, transaction_status, database_name, global_ip
- **Panels (12):** stat x5, text x3, table x2, timeseries x1, barchart x1
  - Active Transactions, Unique Users, Servers, Anomaly Findings, Alerts Sent, Transaction Activity Over Time, Top Users by Transactions, Print (filtered view)
- **Action buttons:** /generate_report/Privileged%20Access%20Oversight%20Report, /generate_report/rpt_2_activity_monitoring_audit_transactions, /sensitive_schema
- **Links:** /sensitive_schema
- **Drill-downs:** /d/adbcsrw/2-activity-monitoring-and-audit, /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### 2. Schema DML Tracking
*Variables:* global_ip
- **Panels (13):** stat x5, text x3, table x3, timeseries x1, barchart x1
  - Active Transactions, Unique Users, Servers, Anomaly Findings, Alerts Sent, Transaction Activity Over Time, Top Users by Transactions, Transaction Anomaly Findings (SEC-SQL-ACC-010), Sensitive Data Transactions
- **Action buttons:** /generate_report/Privileged%20Access%20Oversight%20Report, /generate_report/rpt_2_activity_monitoring_audit_transactions, /sensitive_schema
- **Links:** /sensitive_schema
- **Drill-downs:** /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### 3. Threat Detection & Behavioral Analytics
*Variables:* global_ip, root_cause_id
- **Panels (22):** table x10, stat x7, text x3, timeseries x1, bargauge x1
  - SQL Injections, Credentials Exposed, Anomaly Findings, Policy Violations, Locked Accounts, Alerts Sent, Active Users, Threat Findings Over Time, Top Threat Root Causes, SQL Injection Types by Root Cause (from rootcause taxonomy), SQL Injection Findings, Credentials Stored in Database Tables, Database Restored, Enabled Sysadmin, Weak Password Enforcement, Linked Server / DBLINKS Hidden Credentials, Scanned Jobs for Leaks, Policy Not Enforced
- **Drill-downs:** /d/adccmtx/3-threat-detection-and-behavioral-analytics, /d/adm7hpj, /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### 4. Policy Enforcement & Protection
*Variables:* global_ip, root_cause_id
- **Panels (10):** stat x5, text x3, table x1, barchart x1
  - Privileged Logins, Weak Password Policies, Credentials in Tables, Policy Not Enforced, Policy Findings, Root causes (PII) - ${root_cause_id}, Policy Violations by Type
- **Drill-downs:** /d/addpcfp/1-data-discovery-and-classification, /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### 5. Data Protection
*Variables:* global_ip, root_cause_id, detail_server, detail_table, detail_column
- **Panels (12):** table x5, stat x4, text x3
  - Unmasked Columns, PII Columns, Encryption Findings, Masking Findings, Unmasked Data by Server, Data Protection - Unmasked Columns, Sensitive Schema (PII Columns), Privileged Logins, Root cause details - ${root_cause_id}  ${detail_server} ${detail_table} ${detail_column}
- **Links:** /sensitive_schema
- **Drill-downs:** /d/ad88jgn/5-data-protection, /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### 6. Vulnerability Assessment
*Variables:* global_ip
- **Panels (15):** stat x5, table x4, text x3, barchart x1, piechart x1, timeseries x1
  - Privileged Logins, Weak Passwords, Config Findings, Network Findings, Total Vulnerabilities, Vulnerabilities by Area, By Severity, Vulnerability Findings Over Time, Server Hardening Findings, Vulnerability Root Cause Findings
- **Links:** /sensitive_schema
- **Drill-downs:** /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### 7. Automation & Workflows
*Variables:* global_ip, root_cause_id
- **Panels (18):** stat x7, table x6, text x3, timeseries x1, barchart x1
  - Servers, Root Causes, Detection Rules, Custom Metrics, Active Transactions, Metric Results, Log Entries, Metric Executions Over Time, Enable / Disable Metrics per Server, All Metrics (Latest Execution), Operation Log, Log Entries by Routine, Root cause details - ${root_cause_id}
- **Drill-downs:** /d/adnz9dq, /d/adsddxs/7-automation-and-workflows, /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### 8. Database restored
*Variables:* global_ip
- **Panels (3):** text x2, table x1
  - Database restored
- **Drill-downs:** /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### 9. Connections per user
*Variables:* global_ip
- **Panels (6):** text x4, table x2
  - Connections per user, Unkown TCP connections
- **Drill-downs:** /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### Alerts
*Variables:* global_ip, risk_level, root_cause_id, alert_id
- **Panels (12):** stat x6, text x4, table x2
  - Total Alerts, Critical, High, Medium, Low alerts, Servers, Alerts Sent by Mail, Active Detection Findings
- **Action buttons:** /generate_report/DAM%20Compliance%20Report, /generate_report/Privileged%20Access%20Oversight%20Report, /report_schedule, /reports
- **Drill-downs:** /d/ad7kkx7/alerts, /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### Audit expired
*Variables:* global_ip
- **Panels (12):** text x4, stat x4, table x2, barchart x1, bargauge x1
  - Expired Audit Records, Servers Affected, Audit Root Causes, Audit Alerts Sent, Expired Audits by Server, Top Audit Root Causes, Audit Expired Records, Audit Root Cause Findings (SEC-SQL-AUD)
- **Drill-downs:** /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### Blocker Activity
- **Panels (10):** stat x5, text x3, table x2
  - Killed, Dry-run, Skipped, Errors, Dry-run mode, Blocker log, Executed blocks (alerts.blocks)

### Blocking transactions
*Variables:* global_ip
- **Panels (11):** barchart x4, text x3, table x2, bargauge x1, stat x1
  - blocked transactions, Active users, SQL injection by patterns, Recent alerts - SQL injections, Connectivity reports, Sensitivity reports, SQL Injection analysis
- **Links:** d/adcrpzr/blocking-transactions
- **Drill-downs:** /d/ad47gg4/sql-injection-shell-function, /d/ad4j4rm/sql-injection-error-based-injection, /d/adcqwvk/sql-injection-time-based-blind-injection, /d/adk5ltv/sql-injection-tautology-with-comments, /d/adkk925/sql-injection-boolean-based-injections, /d/adltjt8/sql-injection-order-group-by, /d/admk64d/sql-injection-authentication-bypass, /d/adn2bdh/sql-injection-information-schema-probing, /d/adp58pz/sql-injection-union-based, /d/adphgv5/sql-injection-comment-based, /d/adq45cm/sql-injection-encoding, /d/adw44xx/sql-injection-stacked-queries …

### Blocks in databases
*Variables:* global_ip
- **Panels (12):** text x5, barchart x2, table x2, bargauge x1, stat x1, gauge x1
  - Database Blocks, Active users, Database blocks, Recent alerts, Connection number per user, Active threats
- **Action buttons:** /download_report/block_in_transactions_report, /reportbymail/block_in_transactions_report
- **Drill-downs:** /d/ad47gg4/sql-injection-shell-function, /d/ad4j4rm/sql-injection-error-based-injection, /d/ad6lv7f/transaction-report, /d/adcqwvk/sql-injection-time-based-blind-injection, /d/adk5ltv/sql-injection-tautology-with-comments, /d/adkk925/sql-injection-boolean-based-injections, /d/adltjt8/sql-injection-order-group-by, /d/admk64d/sql-injection-authentication-bypass, /d/adn2bdh/sql-injection-information-schema-probing, /d/adp58pz/sql-injection-union-based, /d/adphgv5/sql-injection-comment-based, /d/adq45cm/sql-injection-encoding …

### Configuration
*Variables:* global_ip, server
- **Panels (31):** table x12, stat x6, text x6, piechart x3, timeseries x2, barchart x2
  - Monitored Servers, Active Detection Rules, Alert Rules, Sensitive Columns, Scheduled Reports, Alerts Sent (7d), Detection Rules by Vendor, Detection Rules by Domain, Alerts Sent Over Time, Alerts by Severity, Configured Reports, Alert Thresholds, Sensitive Schema - PII Columns, PII Columns by Category, Webhook Alert Channels, Global Parameters, Recent Operation Log, Detection Results Over Time, Top Root Causes by Findings, Rootcause Taxonomy Overview, Mail Configuration, Mail Groups & Recipients, Risk Levels, Print (filtered view)
- **Action buttons:** /addrecipients, /generate_report/DAM%20Compliance%20Report, /generate_report/Privileged%20Access%20Oversight%20Report, /mailconfiguration, /report_schedule, /reports, /risklevel
- **Links:** /global_params, /report_schedule, /sensitive_schema, /webhook_alerts
- **Drill-downs:** /d/dbdome-configuration/configuration, /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### Connectivity
*Variables:* global_ip
- **Panels (16):** stat x5, text x4, barchart x3, piechart x2, table x2
  - Active Connections, Unique Clients, Servers, Network Findings, Connection Findings, Connections by Server & Client, By Protocol, By Auth Scheme, TCP Connections, Network & Connection Root Cause Findings, Data Activity (Transactions/hour), Connections per Client
- **Drill-downs:** /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### Credentials stored in tables
*Variables:* global_ip
- **Panels (12):** text x4, stat x4, table x2, barchart x1, piechart x1
  - Credentials Found, Servers Affected, Tables with Credentials, Root Cause Findings, Credentials by Server & Table, By Server, Credentials Stored in Database Tables, PII/Credential Root Cause Findings
- **Links:** /sensitive_schema
- **Drill-downs:** /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### Custom metrics
*Variables:* global_ip
- **Panels (15):** stat x5, text x4, piechart x2, table x2, barchart x1, timeseries x1
  - Total Metrics, Active Metrics, Inactive Metrics, Metric Results (period), Matched Findings, Metrics by Vendor, By Type, Top Executed Metrics, Custom Metrics Configuration, Metric Results with Comparison, Metric Executions Over Time
- **Links:** /custom_metrics
- **Drill-downs:** /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### Database connections per user
*Variables:* global_ip
- **Panels (13):** stat x5, text x4, table x2, barchart x1, piechart x1
  - Total Connections, Unique Users, Servers, Multi-Host Alerts, Connection Findings, Connections per User, By Server, Connections per User (Detail), Connection Root Cause Findings
- **Drill-downs:** /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### Database restored
*Variables:* global_ip
- **Panels (12):** text x5, gauge x2, table x2, bargauge x1, stat x1, barchart x1
  - Database restored, Active users, Recent alerts, Connection number per user, Active threats
- **Action buttons:** /download_report/database_restored_report, /reportbymail/database_restored_report
- **Drill-downs:** /d/ad47gg4/sql-injection-shell-function, /d/ad4j4rm/sql-injection-error-based-injection, /d/ad6lv7f/transaction-report, /d/adcqwvk/sql-injection-time-based-blind-injection, /d/adk5ltv/sql-injection-tautology-with-comments, /d/adkk925/sql-injection-boolean-based-injections, /d/adltjt8/sql-injection-order-group-by, /d/admk64d/sql-injection-authentication-bypass, /d/adn2bdh/sql-injection-information-schema-probing, /d/adp58pz/sql-injection-union-based, /d/adphgv5/sql-injection-comment-based, /d/adq45cm/sql-injection-encoding …

### Email configuration
*Variables:* global_ip
- **Panels (6):** text x4, table x2
  - Email configuration, Mail Groups & Recipients
- **Action buttons:** /addrecipients, /mailconfiguration
- **Links:** /email_configuration
- **Drill-downs:** /d/adcdjsj/email-configuration, /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### Enabled sysadmin
*Variables:* global_ip
- **Panels (12):** text x5, barchart x2, table x2, bargauge x1, stat x1, gauge x1
  - Enabled sysadmin, Active users, Recent alerts, Connection number per user, Active threats
- **Action buttons:** /download_report/enabled_sysadmin_report, /reportbymail/enabled_sysadmin_report
- **Drill-downs:** /d/ad47gg4/sql-injection-shell-function, /d/ad4j4rm/sql-injection-error-based-injection, /d/adcqwvk/sql-injection-time-based-blind-injection, /d/adk5ltv/sql-injection-tautology-with-comments, /d/adkk925/sql-injection-boolean-based-injections, /d/adltjt8/sql-injection-order-group-by, /d/admk64d/sql-injection-authentication-bypass, /d/adn2bdh/sql-injection-information-schema-probing, /d/adnskjz/enabled-sysadmin, /d/adp58pz/sql-injection-union-based, /d/adphgv5/sql-injection-comment-based, /d/adq45cm/sql-injection-encoding …

### GRC Access Review
*Variables:* global_ip
- **Panels (13):** stat x4, table x3, text x2, barchart x2, timeseries x1, piechart x1
  - Open Review Instances, Overdue Reviews, Completed (90d), Active Cycles, Reviews Opened vs Completed per Month, Instances by Status, Open Reviews by Cycle, Avg Days to Complete by Cycle, Overdue Review Instances — Action Required, All Open Review Instances, Review Cycle Configuration

### GRC Audit Log
*Variables:* global_ip, server_filter
- **Panels (10):** stat x3, barchart x3, text x2, timeseries x1, table x1
  - ALERTED Events, BLOCKED Events, MASKED Events, Events per Hour by Action, Top Source IPs (BLOCKED), Top Users (BLOCKED), Top Servers (all actions), Audit Events
- **Drill-downs:** /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### GRC Compliance
*Variables:* global_ip
- **Panels (11):** stat x4, table x3, text x2, timeseries x1, barchart x1
  - PCI-DSS Events, HIPAA Events, GDPR Events, SOC2 Events, Events by Regulation (hourly), Actions by Regulation, Regulation Breach Events (BLOCKED / ALERTED), Masking Coverage by Regulation, Daily Audit Summary by Action
- **Drill-downs:** /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### GRC Control Attestation Workflow
*Variables:* global_ip
- **Panels (15):** stat x4, gauge x4, text x2, table x2, timeseries x1, piechart x1, barchart x1
  - Pending Attestations, Exception Attestations, Open Periods, Completion Rate (Latest Period), Attestations Completed per Month, Attestation Status Distribution, Pending by Regulation, Completion Rate — SOC2, Completion Rate — SOX, Completion Rate — PCI-DSS, Completion Rate — GDPR, Pending Attestations — Action Required, Attestation Exceptions

### GRC Cross-Border Transfer Tracking
*Variables:* global_ip
- **Panels (12):** stat x4, table x3, text x2, timeseries x1, piechart x1, barchart x1
  - Transfers Detected (30d), Without Legal Basis (30d), Critical Risk Transfers, Server Regions Configured, Cross-Border Transfers per Day, Transfer Mechanisms Used, Transfers by Destination Country (30d), Transfer Agreements, Transfers Without Legal Basis — Action Required, Server Region Registry

### GRC Immutable Audit Hash Chain
*Variables:* global_ip
- **Panels (10):** stat x4, text x2, table x2, timeseries x1, barchart x1
  - Total Rows Hashed, Rows Pending Hash, Last Verification Result, Verifications Run, Recent Audit Log — Hash Status, Rows Hashed per Hour, Verification Results (Last 30), Hash Chain Verification Checkpoints

### GRC Incident Lifecycle Management
*Variables:* global_ip
- **Panels (13):** stat x4, table x3, barchart x2, text x2, timeseries x1, piechart x1
  - Active Incidents, Critical Active, GDPR 72h Overdue, CAPA Actions Open, Incidents per Week by Severity, Incidents by State, Incidents by Category (90d), Avg Resolution Time by Severity (h), GDPR Breach Notifications, Open CAPA Actions

### GRC Masking Coverage
*Variables:* global_ip
- **Panels (12):** stat x4, table x3, piechart x2, text x2, barchart x1
  - Active Masking Rules, Sensitive Columns (total), Unmasked Sensitive Columns, Token Vault Entries, Rules by Mask Type, Rules by PII Type, Active Rules by Regulation, Unmasked Sensitive Columns (Risk Gap), Masking Coverage Summary
- **Drill-downs:** /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### GRC Overview
*Variables:* global_ip
- **Panels (21):** stat x13, text x3, row x2, barchart x1, timeseries x1, table x1
  - BLOCKED (24h), ALERTED (24h), Open Incidents, High-Risk Users (≥70), Active Blocked IPs, Active Masking Rules, Top Servers by Events (24h), Firewall Events by Action (hourly), Recent BLOCKED / CRITICAL Events, Phase 8 KPIs, Exceptions Pending Approval, Overdue Access Reviews, Phase 4 KPIs, Open Critical Incidents, GDPR 72h Overdue, Pending Attestations, Transfers Without Legal Basis, Hash Chain Valid
- **Action buttons:** /d/grc-access-review, /d/grc-attestations, /d/grc-audit-log, /d/grc-compliance, /d/grc-cross-border, /d/grc-ddl-privileges, /d/grc-discovery, /d/grc-evidence, /d/grc-hash-chain, /d/grc-incidents, /d/grc-masking, /d/grc-overview, /d/grc-policy-exceptions, /d/grc-retention, /d/grc-risk-register, /d/grc-risk-scoring, /d/grc-sod, /d/grc-threat-response, /d/grc-tls-vuln, /d/grc-workflow-sod
- **Drill-downs:** /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### GRC Policy Exceptions
*Variables:* global_ip
- **Panels (14):** stat x4, barchart x3, table x3, text x2, timeseries x1, piechart x1
  - Pending Approval, Active Approved Exceptions, Expiring in <7 Days, Rejected (30d), Exception Requests per Day, Exceptions by Status, Active Exceptions by Regulation, Exceptions by Server, Top Requestors (90d), Pending Approval — Action Required, Exception History (All)

### GRC Risk Register
*Variables:* global_ip
- **Panels (12):** stat x4, barchart x4, text x2, piechart x1, table x1
  - Open Risks, Critical / High Risks (Score ≥15), In Treatment, Avg Residual Risk Score, Risks by Inherent Score Bucket, Risks by Category, Risks by Treatment Strategy, Top Assets by Residual Risk Score, Risks by Regulation, Risk Register

### GRC Risk Scoring
*Variables:* global_ip
- **Panels (10):** stat x3, text x2, table x2, gauge x1, timeseries x1, barchart x1
  - High-Risk Users (≥70), Critical-Risk Users (≥90), Average Risk Score, Monitored Users, Risk Score Trend (events), Users by Risk Band, Top 30 High-Risk Users, Recent Risk Events
- **Drill-downs:** /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### GRC Threat Response
*Variables:* global_ip
- **Panels (13):** table x5, stat x4, text x2, gauge x1, timeseries x1
  - Response Success Rate (%), Open Incidents, Blocked IPs (active), Suspended Users (active), Responses (24h), Active Suspended Users, Automated Responses per Hour, Open Security Incidents, Recent Automated Responses, Active Blocked IPs, Active Response Playbooks
- **Drill-downs:** /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### GRC Workflow Segregation of Duties
*Variables:* global_ip
- **Panels (11):** stat x4, barchart x2, table x2, text x2, timeseries x1
  - SoD Violations (30d), Violations This Week, Active SoD Rules, Unique Violators (30d), Workflow SoD Violations per Day, Violations by Action Type (30d), Top Violators (30d), SoD Rule Configuration, Workflow SoD Violation Log (30d)

### IPS Dashboard - FortiAnalyzer
*Variables:* global_ip
- **Panels (15):** stat x6, table x4, text x2, piechart x1, barchart x1, timeseries x1
  - Total Events, Critical, High, Medium, Blocked, Monitored, Intrusions by Severity, Intrusions by Type, Intrusion Events Timeline (Last 7 Days), Monitored Intrusions, Top Victims, Blocked Intrusions, Top Attack Sources
- **Links:** /api/siem/ips-report/download, /siem/ips-dashboard

### Linked servers  / DBLINKS - Hidden credentials
*Variables:* global_ip
- **Panels (12):** text x5, gauge x2, table x2, bargauge x1, stat x1, barchart x1
  - Linked server / DBLINKS Hidden credentials, Active users, Recent alerts, Connection number per user, Active threats
- **Action buttons:** /download_report/linked_server_report, /reportbymail/linked_server_report
- **Drill-downs:** /d/ad47gg4/sql-injection-shell-function, /d/ad4j4rm/sql-injection-error-based-injection, /d/ad6lv7f/transaction-report, /d/adcqwvk/sql-injection-time-based-blind-injection, /d/adk5ltv/sql-injection-tautology-with-comments, /d/adkk925/sql-injection-boolean-based-injections, /d/adltjt8/sql-injection-order-group-by, /d/admk64d/sql-injection-authentication-bypass, /d/adn2bdh/sql-injection-information-schema-probing, /d/adp58pz/sql-injection-union-based, /d/adphgv5/sql-injection-comment-based, /d/adq45cm/sql-injection-encoding …

### Locked accounts
*Variables:* global_ip
- **Panels (11):** text x5, barchart x4, table x2
  - Locked accounts, Sensitivity reports, SQL Injection analysis, Data activity monitoring
- **Action buttons:** /download_report/locked_accounts_report, /reportbymail/locked_accounts_report
- **Drill-downs:** /d/ad8pvv6/locked-accounts, /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### Mail
- **Panels (3):** text x2, table x1
  - Mail configuration
- **Drill-downs:** /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### New dashboard
- **Panels (3):** text x2, timeseries x1
  - report name
- **Drill-downs:** /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### PII - Sensitive columns
*Variables:* global_ip, root_cause_id
- **Panels (11):** stat x6, table x3, text x2
  - Total Events, Critical, High, Medium, Blcked, Monitored, Root causes, Detailed findings, Root cause details - ${root_cause_id}
- **Links:** /api/siem/ips-report/download, /siem/ips-dashboard
- **Drill-downs:** /d/adw9lx6/pii-sensitive-columns

### PII - Sensitive data in use
*Variables:* global_ip, root_cause_id
- **Panels (11):** stat x6, table x3, text x2
  - Total Events, Critical, High, Medium, Blcked, Monitored, Root causes, Detailed findings, Root cause details - ${root_cause_id}
- **Links:** /api/siem/ips-report/download, /siem/ips-dashboard
- **Drill-downs:** /d/ad8885r/pii-sensitive-data-in-use

### PPL- Protection of Privacy Law, 5741 – 1981
*Variables:* global_ip
- **Panels (16):** stat x6, table x5, text x2, piechart x1, barchart x1, timeseries x1
  - Total Events, Critical, High, Medium, Blcked, Monitored, Intrusions by Severity, Intrusions by Type, Intrusion Events Timeline (Last 7 Days), Blocked Intrusions, Monitored Intrusions, Top Victims, Root causes, Top Attack Sources
- **Links:** /api/siem/ips-report/download, /siem/ips-dashboard

### Policy not enforced
*Variables:* global_ip
- **Panels (11):** text x5, barchart x4, table x2
  - Policy not enforced, Sensitivity reports, SQL Injection analysis, Data activity monitoring
- **Action buttons:** /download_report/policy_not_enforeced_report, /reportbymail/policy_not_enforeced_report
- **Drill-downs:** /d/ad99j9q/policy-not-enforced, /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### Processes
*Variables:* global_ip
- **Panels (10):** text x5, barchart x4, table x1
  - Processes, Sensitivity reports, SQL Injection analysis, Data activity monitoring, Connectivity reports
- **Links:** /processform
- **Drill-downs:** /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### Recent alerts
*Variables:* global_ip
- **Panels (15):** table x11, text x4
  - Security dashboard, Critical issues, Active threats, Active users, Cyber attacks, Recent alerts, Sensitivity reports, SQL Injection analysis, Data activity monitoring, Connectivity reports
- **Drill-downs:** /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### Retention
*Variables:* dump_location, edit_metric, edit_value, dump_metric, restore_id
- **Panels (10):** table x8, text x2
  - Retention Overview, Apply retention edit (auto-runs on ▲/▼ click), Current dump location, Save dump location  (refresh to save), Dump metrics (config.dump_metrics), Dumps catalog (config.dumps), Apply dump (auto-runs on Dump click), Apply restore (auto-runs on Restore click)
- **Drill-downs:** /d/adretn001/retention

### Retention  policy
*Variables:* global_ip
- **Panels (9):** text x4, barchart x4, table x1
  - Retention policy, Sensitivity reports, SQL Injection analysis, Data activity monitoring, Connectivity reports
- **Links:** /retention_policy
- **Drill-downs:** /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### Rootcauses
*Variables:* sel_issue, global_ip
- **Panels (4):** text x2, table x2
  - Issues  (click 'select' to load its root causes), Root causes for selected issue  -  toggle active / set risk level (saved via API)
- **Links:** /root_cause_active, /root_cause_risk
- **Drill-downs:** /d/rootcauses/rootcauses

### SIEM configuration
*Variables:* global_ip
- **Panels (8):** barchart x4, text x3, table x1
  - SIEM, Sensitivity reports, SQL Injection analysis, Data activity monitoring, Connectivity reports
- **Links:** /siem_configuration, http://${global_ip}﻿:8080/siem_configuration
- **Drill-downs:** /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### SQL Injection
*Variables:* global_ip
- **Panels (6):** text x4, gauge x1, table x1
  - SQL injection by patterns, SQL Injections  - Injection prevention
- **Drill-downs:** /d/ad47gg4/sql-injection-shell-function, /d/ad4j4rm/sql-injection-error-based-injection, /d/adcqwvk/sql-injection-time-based-blind-injection, /d/adk5ltv/sql-injection-tautology-with-comments, /d/adkk925/sql-injection-boolean-based-injections, /d/adltjt8/sql-injection-order-group-by, /d/admk64d/sql-injection-authentication-bypass, /d/adn2bdh/sql-injection-information-schema-probing, /d/adp58pz/sql-injection-union-based, /d/adphgv5/sql-injection-comment-based, /d/adq45cm/sql-injection-encoding, /d/adw44xx/sql-injection-stacked-queries …

### SQL injection - Boolean-based injections
*Variables:* global_ip
- **Panels (6):** text x4, gauge x1, table x1
  - Critical issues - SQL injection, comment based injections
- **Drill-downs:** /d/ad47gg4/sql-injection-shell-function, /d/ad4j4rm/sql-injection-error-based-injection, /d/adcqwvk/sql-injection-time-based-blind-injection, /d/adk5ltv/sql-injection-tautology-with-comments, /d/adkk925/sql-injection-boolean-based-injections, /d/adltjt8/sql-injection-order-group-by, /d/admk64d/sql-injection-authentication-bypass, /d/adn2bdh/sql-injection-information-schema-probing, /d/adp58pz/sql-injection-union-based, /d/adphgv5/sql-injection-comment-based, /d/adq45cm/sql-injection-encoding, /d/adw44xx/sql-injection-stacked-queries …

### SQL injection - Comment based
*Variables:* global_ip
- **Panels (6):** text x4, gauge x1, table x1
  - Critical issues - SQL injection, comment based injections
- **Drill-downs:** /d/ad47gg4/sql-injection-shell-function, /d/ad4j4rm/sql-injection-error-based-injection, /d/adcqwvk/sql-injection-time-based-blind-injection, /d/adk5ltv/sql-injection-tautology-with-comments, /d/adkk925/sql-injection-boolean-based-injections, /d/adltjt8/sql-injection-order-group-by, /d/admk64d/sql-injection-authentication-bypass, /d/adn2bdh/sql-injection-information-schema-probing, /d/adp58pz/sql-injection-union-based, /d/adphgv5/sql-injection-comment-based, /d/adq45cm/sql-injection-encoding, /d/adw44xx/sql-injection-stacked-queries …

### SQL injection - Information schema probing
*Variables:* global_ip
- **Panels (6):** text x4, gauge x1, table x1
  - Critical issues - SQL injection, Information schema probing
- **Drill-downs:** /d/ad47gg4/sql-injection-shell-function, /d/ad4j4rm/sql-injection-error-based-injection, /d/adcqwvk/sql-injection-time-based-blind-injection, /d/adk5ltv/sql-injection-tautology-with-comments, /d/adkk925/sql-injection-boolean-based-injections, /d/adltjt8/sql-injection-order-group-by, /d/admk64d/sql-injection-authentication-bypass, /d/adn2bdh/sql-injection-information-schema-probing, /d/adp58pz/sql-injection-union-based, /d/adphgv5/sql-injection-comment-based, /d/adq45cm/sql-injection-encoding, /d/adw44xx/sql-injection-stacked-queries …

### SQL injection - Stacked queries
*Variables:* global_ip
- **Panels (6):** text x4, gauge x1, table x1
  - Critical issues - SQL injection, Stacked query injections
- **Drill-downs:** /d/ad47gg4/sql-injection-shell-function, /d/ad4j4rm/sql-injection-error-based-injection, /d/adcqwvk/sql-injection-time-based-blind-injection, /d/adk5ltv/sql-injection-tautology-with-comments, /d/adkk925/sql-injection-boolean-based-injections, /d/adltjt8/sql-injection-order-group-by, /d/admk64d/sql-injection-authentication-bypass, /d/adn2bdh/sql-injection-information-schema-probing, /d/adp58pz/sql-injection-union-based, /d/adphgv5/sql-injection-comment-based, /d/adq45cm/sql-injection-encoding, /d/adw44xx/sql-injection-stacked-queries …

### SQL injection - Time based
*Variables:* global_ip
- **Panels (6):** text x4, gauge x1, table x1
  - Critical issues - SQL injection, Stacked query injections
- **Drill-downs:** /d/ad47gg4/sql-injection-shell-function, /d/ad4j4rm/sql-injection-error-based-injection, /d/adcqwvk/sql-injection-time-based-blind-injection, /d/adk5ltv/sql-injection-tautology-with-comments, /d/adkk925/sql-injection-boolean-based-injections, /d/adltjt8/sql-injection-order-group-by, /d/admk64d/sql-injection-authentication-bypass, /d/adn2bdh/sql-injection-information-schema-probing, /d/adp58pz/sql-injection-union-based, /d/adphgv5/sql-injection-comment-based, /d/adq45cm/sql-injection-encoding, /d/adw44xx/sql-injection-stacked-queries …

### SQL injection - Time based blind injection
*Variables:* global_ip
- **Panels (6):** text x4, gauge x1, table x1
  - Critical issues - SQL injection, Time based blind injections
- **Drill-downs:** /d/ad47gg4/sql-injection-shell-function, /d/ad4j4rm/sql-injection-error-based-injection, /d/adcqwvk/sql-injection-time-based-blind-injection, /d/adk5ltv/sql-injection-tautology-with-comments, /d/adkk925/sql-injection-boolean-based-injections, /d/adltjt8/sql-injection-order-group-by, /d/admk64d/sql-injection-authentication-bypass, /d/adn2bdh/sql-injection-information-schema-probing, /d/adp58pz/sql-injection-union-based, /d/adphgv5/sql-injection-comment-based, /d/adq45cm/sql-injection-encoding, /d/adw44xx/sql-injection-stacked-queries …

### SQL injection - Union based
*Variables:* global_ip
- **Panels (6):** text x4, gauge x1, table x1
  - Critical issues - SQL injection, Union based injections
- **Drill-downs:** /d/ad47gg4/sql-injection-shell-function, /d/ad4j4rm/sql-injection-error-based-injection, /d/adcqwvk/sql-injection-time-based-blind-injection, /d/adk5ltv/sql-injection-tautology-with-comments, /d/adkk925/sql-injection-boolean-based-injections, /d/adltjt8/sql-injection-order-group-by, /d/admk64d/sql-injection-authentication-bypass, /d/adn2bdh/sql-injection-information-schema-probing, /d/adp58pz/sql-injection-union-based, /d/adphgv5/sql-injection-comment-based, /d/adq45cm/sql-injection-encoding, /d/adw44xx/sql-injection-stacked-queries …

### SQL injection - tautology with comments
*Variables:* global_ip
- **Panels (6):** text x4, gauge x1, table x1
  - Critical issues - SQL injection, comment based injections
- **Drill-downs:** /d/ad47gg4/sql-injection-shell-function, /d/ad4j4rm/sql-injection-error-based-injection, /d/adcqwvk/sql-injection-time-based-blind-injection, /d/adk5ltv/sql-injection-tautology-with-comments, /d/adkk925/sql-injection-boolean-based-injections, /d/adltjt8/sql-injection-order-group-by, /d/admk64d/sql-injection-authentication-bypass, /d/adn2bdh/sql-injection-information-schema-probing, /d/adp58pz/sql-injection-union-based, /d/adphgv5/sql-injection-comment-based, /d/adq45cm/sql-injection-encoding, /d/adw44xx/sql-injection-stacked-queries …

### SQL injection -Authentication Bypass
*Variables:* global_ip
- **Panels (6):** text x4, gauge x1, table x1
  - Critical issues - SQL injection, Authentication bypass
- **Drill-downs:** /d/ad47gg4/sql-injection-shell-function, /d/ad4j4rm/sql-injection-error-based-injection, /d/adcqwvk/sql-injection-time-based-blind-injection, /d/adk5ltv/sql-injection-tautology-with-comments, /d/adkk925/sql-injection-boolean-based-injections, /d/adltjt8/sql-injection-order-group-by, /d/admk64d/sql-injection-authentication-bypass, /d/adn2bdh/sql-injection-information-schema-probing, /d/adp58pz/sql-injection-union-based, /d/adphgv5/sql-injection-comment-based, /d/adq45cm/sql-injection-encoding, /d/adw44xx/sql-injection-stacked-queries …

### SQL injection -Encoding
*Variables:* global_ip
- **Panels (6):** text x4, gauge x1, table x1
  - Critical issues - SQL injection, Encoding injection
- **Drill-downs:** /d/ad47gg4/sql-injection-shell-function, /d/ad4j4rm/sql-injection-error-based-injection, /d/adcqwvk/sql-injection-time-based-blind-injection, /d/adk5ltv/sql-injection-tautology-with-comments, /d/adkk925/sql-injection-boolean-based-injections, /d/adltjt8/sql-injection-order-group-by, /d/admk64d/sql-injection-authentication-bypass, /d/adn2bdh/sql-injection-information-schema-probing, /d/adp58pz/sql-injection-union-based, /d/adphgv5/sql-injection-comment-based, /d/adq45cm/sql-injection-encoding, /d/adw44xx/sql-injection-stacked-queries …

### SQL injection -Error based injection
*Variables:* global_ip
- **Panels (6):** text x4, gauge x1, table x1
  - Critical issues - SQL injection, Error based injections
- **Drill-downs:** /d/ad47gg4/sql-injection-shell-function, /d/ad4j4rm/sql-injection-error-based-injection, /d/adcqwvk/sql-injection-time-based-blind-injection, /d/adk5ltv/sql-injection-tautology-with-comments, /d/adkk925/sql-injection-boolean-based-injections, /d/adltjt8/sql-injection-order-group-by, /d/admk64d/sql-injection-authentication-bypass, /d/adn2bdh/sql-injection-information-schema-probing, /d/adp58pz/sql-injection-union-based, /d/adphgv5/sql-injection-comment-based, /d/adq45cm/sql-injection-encoding, /d/adw44xx/sql-injection-stacked-queries …

### SQL injection -Shell function
*Variables:* global_ip
- **Panels (6):** text x4, gauge x1, table x1
  - Critical issues - SQL injection, Shell commands
- **Drill-downs:** /d/ad47gg4/sql-injection-shell-function, /d/ad4j4rm/sql-injection-error-based-injection, /d/adcqwvk/sql-injection-time-based-blind-injection, /d/adk5ltv/sql-injection-tautology-with-comments, /d/adkk925/sql-injection-boolean-based-injections, /d/adltjt8/sql-injection-order-group-by, /d/admk64d/sql-injection-authentication-bypass, /d/adn2bdh/sql-injection-information-schema-probing, /d/adp58pz/sql-injection-union-based, /d/adphgv5/sql-injection-comment-based, /d/adq45cm/sql-injection-encoding, /d/adw44xx/sql-injection-stacked-queries …

### SQL injection -order / Group by
*Variables:* global_ip
- **Panels (6):** text x4, gauge x1, table x1
  - Critical issues - SQL injection, Order / Group by
- **Drill-downs:** /d/ad47gg4/sql-injection-shell-function, /d/ad4j4rm/sql-injection-error-based-injection, /d/adcqwvk/sql-injection-time-based-blind-injection, /d/adk5ltv/sql-injection-tautology-with-comments, /d/adkk925/sql-injection-boolean-based-injections, /d/adltjt8/sql-injection-order-group-by, /d/admk64d/sql-injection-authentication-bypass, /d/adn2bdh/sql-injection-information-schema-probing, /d/adp58pz/sql-injection-union-based, /d/adphgv5/sql-injection-comment-based, /d/adq45cm/sql-injection-encoding, /d/adw44xx/sql-injection-stacked-queries …

### SQL injection board
*Variables:* global_ip
- **Panels (6):** text x4, gauge x1, table x1
  - Critical issues - SQL injection, SQL injection - Sleep time
- **Drill-downs:** /d/ad4btvb/sql-injection-sleep-time, /d/adddd87/sql-injection-boolean-usage, /d/adlpnn2/sql-injection-sensitive-data, /d/adp5zsq/sql-injection-outfile-copy, /d/adqsd5f/sql-injection-union-usage, /d/adrlq5l/sql-injection-dangerous-queries, /d/adwr6tl/sql-injection-stacked-query, /d/adzr5nq/sql-injection-long-literal, /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview …

### Same login active from multiple hosts
*Variables:* global_ip, root_cause_id
- **Panels (5):** text x3, table x2
  - Root causes, Detailed findings
- **Links:** /api/siem/ips-report/download, /siem/ips-dashboard
- **Drill-downs:** /d/adlvvwg/same-login-active-from-multiple-hosts

### Scan jobs for leaks
*Variables:* global_ip
- **Panels (13):** text x4, stat x4, barchart x3, bargauge x1, table x1
  - Jobs with Leaks, Servers Affected, Security Findings, Alerts Sent, Leaked Jobs by Server, Sensitivity Issues by Server, Scanned Jobs for Leaks, SQL Injection Analysis, Data Activity (Transactions/hour)
- **Drill-downs:** /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### Security Issues Explorer
*Variables:* global_ip, rc
- **Panels (4):** text x2, table x2
  - Security hierarchy — click a root cause to filter alerts, Alerts for selected root cause — ${rc}
- **Drill-downs:** /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response, /d/sec-explorer/security-issues-explorer

### Send report by mail
*Variables:* global_ip
- **Panels (7):** text x4, table x3
- **Action buttons:** /download_report/transaction_report, /reportbymail/transaction_report
- **Drill-downs:** /d/ad6lv7f/transaction-report, /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### Sensitive Columns Explorer
*Variables:* srv, db, global_ip, dsch, dtbl, dcol
- **Panels (13):** table x10, text x3
  - Servers (sensitive columns), Databases on ${srv}, Sensitive columns - ${srv} / ${db}, Column details - ${dtbl}.${dcol}, Tracked sensitive columns (metrics.sensitive_columns), Masking activity (metrics.masking_log), Masked data preview - real vs masked (as test user), Print (filtered view), Encryption activity (metrics.encryption_log), Tokenized data preview - original vs token
- **Links:** /encrypt_column, /mask_column, /revert_encryption, /sensitive_column_add
- **Drill-downs:** /d/adpiicol/sensitive-columns-explorer

### Sensitivity report
*Variables:* global_ip
- **Panels (10):** text x5, table x5
  - Sensitive data (PII), Sensitive columns and schema (PII)
- **Action buttons:** /download_report/sensitive_schema_report, /reportbymail/sensitive_schema_report
- **Drill-downs:** /d/adgp5hv/sensitivity-report, /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### Stored procedure slower than its average
*Variables:* global_ip, root_cause_id
- **Panels (5):** table x3, text x2
  - Root causes, Detailed findings, Root cause details - ${root_cause_id}
- **Links:** /api/siem/ips-report/download, /siem/ips-dashboard
- **Drill-downs:** /d/ad55bbz/stored-procedure-slower-than-its-average

### Super users (sysadmin / sysDBA)
*Variables:* global_ip
- **Panels (10):** text x5, table x2, barchart x1, bargauge x1, stat x1
  - SYSADMIN / SYSDBA, Active users, Recent alerts, Credentials stored in database tables
- **Action buttons:** /download_report/sysadmin_report, /reportbymail/sysadmin_report
- **Drill-downs:** /d/adbzzdg/super-users-sysadmin-sysdba, /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### Take Action
*Variables:* global_ip
- **Panels (14):** text x5, barchart x4, gauge x2, bargauge x1, table x1, stat x1
  - Critical issues - SQL injection, Active threats, Active users, Take action, Recent alerts, Sensitivity reports, SQL Injection analysis, Data activity monitoring, Connectivity reports
- **Links:** /take_action
- **Drill-downs:** /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### Transaction report
*Variables:* global_ip
- **Panels (15):** text x7, table x4, barchart x4
  - Transactions, Sensitivity reports, SQL Injection analysis, Data activity monitoring, Connectivity reports
- **Action buttons:** /download_report/blocking_transaction_report, /reportbymail/blocking_transaction_report
- **Drill-downs:** /d/ad6lv7f/transaction-report, /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### Vulnerability
*Variables:* global_ip
- **Panels (14):** stat x5, text x4, barchart x3, piechart x1, table x1
  - SQL Injections, Suspicious Queries, Config Vulnerabilities, Active Users, Total Findings, Vulnerability by Issue Type, By Security Area, Security Vulnerability Findings, SQL Injection by Server, Connectivity by Server
- **Drill-downs:** /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### Webhook Alerts Configuration
*Variables:* global_ip
- **Panels (6):** text x3, table x3
  - Webhook Alerts - click a true/false cell to toggle, Blocker global dry-run (true = log only, false = ARMED to kill), Masking global dry-run (true = log only, false = ARMED to apply masks)
- **Links:** /global_param_set, /webook_alert_set

### alert_report
- **Panels (4):** text x2, nodeGraph x1, table x1
  - Open Alerts
- **Links:** http://${global_ip}﻿:8080/open_alert_change_astaus
- **Drill-downs:** /d/${__data.fields.report_url}, /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### alert_report_Error_Based
- **Panels (4):** text x2, nodeGraph x1, table x1
  - Open Alerts
- **Links:** http://${global_ip}﻿:8080/open_alert_change_astaus
- **Drill-downs:** /d/${__data.fields.report_url}, /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### alert_report_Privilege_Escalation_Chain
- **Panels (4):** text x2, nodeGraph x1, table x1
  - Open Alerts
- **Links:** http://${global_ip}﻿:8080/open_alert_change_astaus
- **Drill-downs:** /d/${__data.fields.report_url}, /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### alert_report_Stacked
- **Panels (4):** text x2, nodeGraph x1, table x1
  - Open Alerts
- **Links:** http://${global_ip}﻿:8080/open_alert_change_astaus
- **Drill-downs:** /d/${__data.fields.report_url}, /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### alert_report_sensitive_schema
- **Panels (5):** table x2, text x2, nodeGraph x1
  - Open Alerts, Sensitive columns and schema (PII), Sensitive data (PII)
- **Drill-downs:** /d/${__data.fields.report_url}, /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### risk level alerts
*Variables:* global_ip
- **Panels (6):** text x4, table x2
  - Risk level alerts, Risk Levels
- **Action buttons:** /risklevel, /risklevel_toggle
- **Links:** /email_configuration
- **Drill-downs:** /d/ad54967/risk-level-alerts, /d/adcdjsj/email-configuration, /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### sysadmin accounts with weak password enforcement
*Variables:* global_ip
- **Panels (12):** text x6, barchart x4, table x2
  - sysadmin accounts with weak password enforcement, Sensitivity reports, SQL Injection analysis, Data activity monitoring
- **Action buttons:** /download_report/week_passwords, /reportbymail/transaction_report
- **Drill-downs:** /d/admz7fh/sysadmin-accounts-with-weak-password-enforcement, /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

### webhook alerts
*Variables:* global_ip
- **Panels (4):** text x3, table x1
  - web hook alerts
- **Links:** /webhook_alerts
- **Drill-downs:** /d/grc-audit-log, /d/grc-compliance, /d/grc-masking, /d/grc-overview, /d/grc-risk-scoring, /d/grc-threat-response

---

## 18. Configuration menu (admin UI nav → page → route)

The admin **Configuration** menu and the page each item opens:

| Menu item | Page title | Route(s) | Catalog § |
|---|---|---|---|
| Servers | Configure Servers | `/serverform`, `/submit-serverform`, `/server_enable` | §2 |
| Processes | Configure Processes | `/processform`, `/submit-processform` | §5 |
| Custom Metrics | Custom Metrics | `/custom_metrics`, `/submit_custom_metrics` | §3 |
| Mail Config | SMTP Configuration | `/mailconfiguration`, `/submit-mailconfiguration`, `/addrecipients` | §7 |
| SIEM | SIEM Configuration | `/siem_configuration`, `/submit_siem_configuration` | §11 |
| Report Scheduling | Schedule Reports | `/report_schedule`, `/submit-report-schedule` | §8 |
| Sensitive Schema | PII Discovery | `/sensitive_schema`, `/sensitive_column_add`, `/api/sensitive-schema/discover` | §10 |
| Alert Thresholds | Configure Thresholds | `/alert_thresholds`, `/submit-alert-threshold` | §6 |
| Alert Rules | Configure Alert Rules | `/alert_rules`, `/submit-alert-rule` | §6 |
| Global Parameters | System Settings | `/global_params`, `/global_param_set`, `/submit-global-param` | §13 |
| Webhook Alerts | Alert Channels | `/webhook_alerts`, `/webook_alert_set`, `/submit-webhook-alert` | §6 |
| Alert Dashboard | Security Alerts | `/alert_dashboard`, `/api/alert_dashboard` | §6 |
| Retention Policy | Data Retention | `/retention_policy`, `/submit_retention_policy` | §12 |
| Report Definitions | Edit Report JSON | `/reports`, `/reports/edit`, `/reports/save` | §8 |

All 14 are backed by FastAPI routes in `http_server.py` and persist to the `config` /
`metrics` schemas (see §10 of the spec for the config-table mapping).
