# Appendix A — Per-panel SQL / query reference

> The SQL behind every Grafana panel (PostgreSQL `dbanalytics` datasource), grouped by dashboard then panel. `${global_ip}`, `${issue_id}`, `${rc_id}` etc. are Grafana template variables resolved at view time. Long lines are wrapped for print. Generated 2026-06-30.

Coverage: **88 dashboards, 600 queries**.


## 1. Data Discovery & Classification

**Sensitive Columns (PII)** — _stat_
```sql
SELECT COUNT(*) FROM alerts.alert_log where root_cause_id = 'SEC-SQL-PRI-001-RC12'
```

**PII Issues Detected** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.general_metric_metadata_results WHERE metric_name LIKE 'SEC-SQL-PRI%%' AND
    (metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(entry_date)
```

**PII Access Alerts** — _stat_
```sql
SELECT COUNT(*) FROM alerts.mail_alert_log WHERE metric_name LIKE '%%RC05%%' AND $__timeFilter(entry_date)
```

**Audit Issues** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.general_metric_metadata_results WHERE metric_name LIKE 'SEC-SQL-AUD%%' AND
    (metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(entry_date)
```

**Servers Scanned** — _stat_
```sql
SELECT COUNT(DISTINCT server) FROM monitoring.general_metric_metadata_results WHERE (metric_name LIKE
    'SEC-SQL-PRI%%' OR metric_name LIKE 'SEC-SQL-AUD%%') AND $__timeFilter(entry_date)
```

**Issues (PII)** — _table_
```sql
select  issue_ID  , issue_name from 
(
  select distinct  issue_ID  , issue_name , metric_name from 
  rootcause.v_rootcauses rc
  left outer join monitoring.general_metric_metadata_results gmmr on gmmr.metric_name = rc.root_cause_id
  where rc.domain_code = 'SEC' and  rc.vendor_name = 'sqlserver'
)
order by (case when metric_name is null then 0 else 1 end ) desc,metric_name
```

**Root causes (PII) - ${issue_id}** — _table_
```sql
select distinct root_cause_id, root_cause_name, root_cause_desc
from rootcause.v_rootcauses
where domain_code = 'SEC'
  and vendor_name = 'sqlserver'
  and ('${issue_id}' = '' OR issue_id = '${issue_id}')
```

**Metric metadata - ${rc_id}** — _table_
```sql
SELECT
    r.entry_date AT TIME ZONE 'Asia/Jerusalem' AS entry_date,
    r.server,
    (
      SELECT jsonb_object_agg(
        k,
        CASE
          WHEN jsonb_typeof(v) = 'number'
               AND (v::text)::numeric BETWEEN 1000000000000 AND 9999999999999
          THEN to_jsonb(
                 to_char(
                   to_timestamp(((v::text)::numeric) / 1000)
                     AT TIME ZONE 'Asia/Jerusalem',
                   'YYYY-MM-DD HH24:MI:SS'
                 )
               )
          ELSE v
        END
      )
      FROM jsonb_each(elem) AS j(k, v)
    ) AS metadata
  FROM monitoring.general_metric_metadata_results r,
       LATERAL jsonb_array_elements(
         CASE WHEN jsonb_typeof(r.metric_metadata) = 'array'
              THEN r.metric_metadata
              ELSE jsonb_build_array(r.metric_metadata) END
       ) AS elem
  WHERE r.metric_name = '${rc_id}'
  ORDER BY r.entry_date DESC
  LIMIT 500
```

**Sensitive Data (PII) — Sensitive columns actively queried (PII in use)** — _table_
```sql
select * from monitoring.v_sec_sql_pri_001_rc13
```

**Alerts** — _table_
```sql
select al.*  from alerts.alert_log al 
left outer join alerts.mail_alert_log mal on mal.server = al.server and mal.metric_name = al.root_cause_id and
    mal.entry_date = mal.entry_date
where  root_cause_id =  '${rc_id}'
```

**PII Root Cause Findings (SEC-SQL-PRI)** — _table_
```sql
SELECT gm.server, gm.metric_name AS root_cause_id,
            COALESCE(rc.name, gm.metric_name) AS root_cause,
            (gm.metric_metadata_vs_expected::jsonb->>'row_count')::int AS rows_found,
            COALESCE(gm.metric_metadata_vs_expected::jsonb->>'severity', 'medium') AS severity,
            (gm.metric_metadata_vs_expected::jsonb->'expected'->>'description') AS finding,
            gm.entry_date AT TIME ZONE 'Asia/Jerusalem' AS detected_at
        FROM monitoring.general_metric_metadata_results gm
        LEFT JOIN rootcause.root_causes rc ON rc.root_cause_id = gm.metric_name
        WHERE gm.metric_name LIKE 'SEC-SQL-PRI%%'
          AND gm.metric_metadata_vs_expected IS NOT NULL
          AND (gm.metric_metadata_vs_expected::jsonb->>'matched')::text = 'true'
          AND $__timeFilter(gm.entry_date)
        ORDER BY gm.entry_date DESC LIMIT 50
```

**Audit Findings Over Time** — _timeseries_
```sql
SELECT DATE_TRUNC('hour', gm.entry_date) AS time,
            COALESCE(i.name, gm.metric_name) AS metric,
            COUNT(*) AS value
        FROM monitoring.general_metric_metadata_results gm
        LEFT JOIN rootcause.root_causes rc ON rc.root_cause_id = gm.metric_name
        LEFT JOIN rootcause.issues i ON i.issue_id = rc.issue_id
        WHERE gm.metric_name LIKE 'SEC-SQL-AUD%%'
          AND gm.metric_metadata_vs_expected IS NOT NULL
          AND (gm.metric_metadata_vs_expected::jsonb->>'matched')::text = 'true'
          AND $__timeFilter(gm.entry_date)
        GROUP BY time, metric ORDER BY time
```

**Top Audit Root Causes** — _bargauge_
```sql
SELECT COALESCE(rc.name, gm.metric_name) AS type, COUNT(*) AS count
        FROM monitoring.general_metric_metadata_results gm
        LEFT JOIN rootcause.root_causes rc ON rc.root_cause_id = gm.metric_name
        WHERE gm.metric_name LIKE 'SEC-SQL-AUD%%'
          AND (gm.metric_metadata_vs_expected::jsonb->>'matched')::text = 'true'
          AND $__timeFilter(gm.entry_date)
        GROUP BY type ORDER BY count DESC LIMIT 10
```

**Audit Trail Findings (SEC-SQL-AUD)** — _table_
```sql
SELECT gm.server, gm.metric_name AS root_cause_id,
            COALESCE(rc.name, gm.metric_name) AS root_cause,
            COALESCE(i.name, '') AS issue,
            (gm.metric_metadata_vs_expected::jsonb->>'row_count')::int AS rows,
            COALESCE(gm.metric_metadata_vs_expected::jsonb->>'severity', 'medium') AS severity,
            gm.entry_date AT TIME ZONE 'Asia/Jerusalem' AS detected_at
        FROM monitoring.general_metric_metadata_results gm
        LEFT JOIN rootcause.root_causes rc ON rc.root_cause_id = gm.metric_name
        LEFT JOIN rootcause.issues i ON i.issue_id = rc.issue_id
        WHERE gm.metric_name LIKE 'SEC-SQL-AUD%%'
          AND gm.metric_metadata_vs_expected IS NOT NULL
          AND (gm.metric_metadata_vs_expected::jsonb->>'matched')::text = 'true'
          AND $__timeFilter(gm.entry_date)
        ORDER BY gm.entry_date DESC LIMIT 50
```

**Sensitive by table , column** — _table_
```sql
select count(*) "sensitive transactions"  , server , table_name , column_name from
    monitoring.v_sec_sql_PRI_001_RC13
group by server , table_name , column_name
```

**Sensitive Transactions by User** — _table_
```sql
select * from monitoring.v_sec_sql_PRI_001_RC13
```

**Misunderstanding of Encryption (TDE)** — _table_
```sql
select * from monitoring.v_SEC_SQL_PRI_001_RC01
```

**Performance Overhead Fears** — _table_
```sql
select * from monitoring.v_SEC_SQL_PRI_001_RC03
```

**PII Exposed in Clear Text: Legacy Schema Constraints** — _table_
```sql
select * from monitoring.v_SEC_SQL_PRI_001_RC05
```

**In-House ""Masking"" Logic Failure** — _table_
```sql
select * from monitoring.v_sec_sql_pri_001_rc07 where $__timeFilter(entry_date)
```

**Key Management Complexity** — _table_
```sql
select * from monitoring.v_sec_sql_pri_001_rc09 where $__timeFilter(entry_date)
```

**Lack of Native Masking Features (Old Versions)** — _table_
```sql
select * from monitoring.v_sec_sql_pri_001_rc10 where $__timeFilter(entry_date)
```

**Unsecured Backups/Snapshots** — _table_
```sql
select * from monitoring.v_sec_sql_pri_001_rc11 where $__timeFilter(entry_date)
```


## 10. Unknown TCP connections

**Unkown TCP connections** — _table_
```sql
select * from monitoring.tcp_connections  where $__timeFilter(connect_time)   and client_net_address not in 
(
select client_net_address from monitoring.tcp_connections  where connect_time < current_date - interval '1
    day'
)
```


## 11. Transaction requests

**Trnsaction requests** — _table_
```sql
select * from monitoring.transaction_requests where login_name != 'dbdome_mon_usr' AND
    $__timeFilter(LAST_request_end_time)
```


## 2. Activity Monitoring & Audit

**Active Transactions** — _stat_
```sql
select count(*) from 
(
SELECT 
       server, session_id, login_name, host_name,
       program_name,
       database_name,
       transaction_state      AS status,
       transaction_begin_time at time zone current_setting('TimeZone') AS start_time,
       NULL::text             AS command,
       NULL::text             AS cpu_time,
       duration_seconds       AS duration,
       transaction_id,
       NULL::text             AS transaction_name,
       query_text             AS query,
       NULL::uuid             AS server_id
FROM monitoring.v_sec_sql_acc_011_rc02
where entry_date >= $__timeFrom() at time zone current_setting('TimeZone')
and  entry_date <= $__timeTo() at time zone current_setting('TimeZone')

)
```

**Unique Users** — _stat_
```sql
SELECT COUNT(DISTINCT login_name) FROM monitoring.v_sec_sql_acc_011_rc02 WHERE $__timeFilter(entry_date) at
    time zone current_setting('TimeZone')
```

**Servers** — _stat_
```sql
SELECT COUNT(DISTINCT server) FROM monitoring.v_sec_sql_acc_011_rc02 
where entry_date >= $__timeFrom() at time zone current_setting('TimeZone')
and  entry_date <= $__timeTo() at time zone current_setting('TimeZone')
```

**Anomaly Findings** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.general_metric_metadata_results WHERE metric_name LIKE 'SEC-SQL-ACC-010%%' AND
    (metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(entry_date)  and
    $__timeFilter(entry_date) at time zone current_setting('TimeZone')
```

**Alerts Sent** — _stat_
```sql
SELECT COUNT(*) FROM alerts.mail_alert_log WHERE $__timeFilter(entry_date)
```

**Active Transactions** — _table_
```sql
select * from 
(
SELECT
       server, session_id, login_name, host_name,
       program_name,
       database_name,
       transaction_state      AS status,
       transaction_begin_time at time zone current_setting('TimeZone') AS start_time,
       NULL::text             AS command,
       NULL::text             AS cpu_time,
       duration_seconds       AS duration,
       transaction_id,
       NULL::text             AS transaction_name,
       query_text             AS query,
       NULL::uuid             AS server_id , 
       entry_date
FROM monitoring.v_sec_sql_acc_011_rc02
)
where entry_date >= $__timeFrom() at time zone current_setting('TimeZone')
and  entry_date <= $__timeTo() at time zone current_setting('TimeZone')
```

**Transaction Activity Over Time** — _timeseries_
```sql
SELECT DATE_TRUNC('hour', a.entry_date) AS time, COUNT(*) AS transactions FROM 
(
  select * from monitoring.v_sec_sql_acc_011_rc02 
  where entry_date >= $__timeFrom() at time zone current_setting('TimeZone')
and  entry_date <= $__timeTo() at time zone current_setting('TimeZone')

)a
group by DATE_TRUNC('hour', a.entry_date)
```

**Top Users by Transactions** — _barchart_
```sql
SELECT login_name, COUNT(*) AS transactions FROM monitoring.v_sec_sql_acc_011_rc02 

where entry_date >= $__timeFrom() at time zone current_setting('TimeZone')
and  entry_date <= $__timeTo() at time zone current_setting('TimeZone')
group by login_name
```

**Print (filtered view)** — _table_
```sql
SELECT '🖨  Print this filtered view (opens clean tab -> Ctrl+P / Save as PDF)' AS print
```


## 2. Schema DML Tracking

**Active Transactions** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.v_perf_sql_tx_010_rc01 WHERE $__timeFilter(entry_date)
```

**Unique Users** — _stat_
```sql
SELECT COUNT(DISTINCT login_name) FROM monitoring.v_active_transactions WHERE $__timeFilter(entry_date)
```

**Servers** — _stat_
```sql
SELECT COUNT(DISTINCT server) FROM monitoring.v_active_transactions WHERE $__timeFilter(entry_date)
```

**Anomaly Findings** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.general_metric_metadata_results WHERE metric_name LIKE 'SEC-SQL-ACC-010%%' AND
    (metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(entry_date)
```

**Alerts Sent** — _stat_
```sql
SELECT COUNT(*) FROM alerts.mail_alert_log WHERE $__timeFilter(entry_date)
```

**Active Transactions** — _table_
```sql
select * from monitoring.v_Active_transactions where $__timeFilter(entry_date)
```

**Transaction Activity Over Time** — _timeseries_
```sql
SELECT DATE_TRUNC('hour', entry_date) AS time, COUNT(*) AS transactions FROM monitoring.v_PERF_SQL_TX_010_RC01
WHERE $__timeFilter(entry_date) GROUP BY time ORDER BY time
```

**Top Users by Transactions** — _barchart_
```sql
SELECT login_name, COUNT(*) AS transactions FROM monitoring.active_transactions WHERE
    $__timeFilter(last_request_end_time) GROUP BY login_name ORDER BY transactions DESC LIMIT 10
```

**Transaction Anomaly Findings (SEC-SQL-ACC-010)** — _table_
```sql
SELECT gm.server, gm.metric_name AS root_cause_id, COALESCE(rc.name, gm.metric_name) AS root_cause,
    (gm.metric_metadata_vs_expected::jsonb->>'row_count')::int AS rows,
    COALESCE(gm.metric_metadata_vs_expected::jsonb->>'severity', 'medium') AS severity,
    (gm.metric_metadata_vs_expected::jsonb->'expected'->>'description') AS description, gm.entry_date AT TIME
    ZONE 'Asia/Jerusalem' AS detected_at FROM monitoring.general_metric_metadata_results gm LEFT JOIN
    rootcause.root_causes rc ON rc.root_cause_id = gm.metric_name WHERE gm.metric_name LIKE
    'SEC-SQL-ACC-010%%' AND gm.metric_metadata_vs_expected IS NOT NULL AND
    (gm.metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(gm.entry_date) ORDER
    BY gm.entry_date DESC LIMIT 50
```

**Sensitive Data Transactions** — _table_
```sql
select * from monitoring.general_metric_metadata_results where metric_name like 'SEC-SQL-AU-010%'
```


## 3. Threat Detection & Behavioral Analytics

**SQL Injections** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.general_metric_metadata_results WHERE metric_name LIKE 'SEC-SQL-INJ%%' AND
    (metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(entry_date)
```

**Credentials Exposed** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.v_mssql_credentials_stored_in_tables
```

**Anomaly Findings** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.general_metric_metadata_results WHERE metric_name LIKE 'SEC-SQL-ACC-010%%' AND
    (metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(entry_date)
```

**Policy Violations** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.v_policy_enforeced
```

**Locked Accounts** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.v_oracle_locked_accounts
```

**Alerts Sent** — _stat_
```sql
SELECT COUNT(*) FROM alerts.mail_alert_log WHERE $__timeFilter(entry_date)
```

**Active Users** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.tcp_connections WHERE $__timeFilter(connect_time)
```

**Threat Findings Over Time** — _timeseries_
```sql
SELECT DATE_TRUNC('hour', entry_date) AS time, COALESCE(i.name, gm.metric_name) AS metric, COUNT(*) AS value
    FROM monitoring.general_metric_metadata_results gm LEFT JOIN rootcause.root_causes rc ON rc.root_cause_id
    = gm.metric_name LEFT JOIN rootcause.issues i ON i.issue_id = rc.issue_id WHERE (gm.metric_name LIKE
    'SEC-SQL-INJ%%' OR gm.metric_name LIKE 'SEC-SQL-ACC-010%%') AND
    (gm.metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(gm.entry_date) GROUP
    BY time, metric ORDER BY time
```

**Top Threat Root Causes** — _bargauge_
```sql
SELECT COALESCE(rc.name, gm.metric_name) AS threat, COUNT(*) AS count FROM
    monitoring.general_metric_metadata_results gm LEFT JOIN rootcause.root_causes rc ON rc.root_cause_id =
    gm.metric_name WHERE (gm.metric_name LIKE 'SEC-SQL-INJ%%' OR gm.metric_name LIKE 'SEC-SQL-ACC-010%%') AND
    (gm.metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(gm.entry_date) GROUP
    BY threat ORDER BY count DESC LIMIT 12
```

**SQL Injection Types by Root Cause (from rootcause taxonomy)** — _table_
```sql
SELECT DISTINCT
    rc.root_cause_id,
    rc.root_cause_name AS injection_type,
    COALESCE(g.finding_count, 0) AS findings,
    COALESCE(g.last_detected AT TIME ZONE 'Asia/Jerusalem', NULL) AS last_detected
FROM rootcause.v_rootcauses rc
LEFT JOIN (
    SELECT metric_name,
           COUNT(*) AS finding_count,
           MAX(entry_date) AS last_detected
    FROM monitoring.general_metric_metadata_results
    WHERE $__timeFilter(entry_date)
    GROUP BY metric_name
) g ON g.metric_name = rc.root_cause_id
WHERE rc.domain_code = 'SEC' AND rc.area_code = 'INJ'
ORDER BY findings DESC
```

**SQL Injection Findings** — _table_
```sql
select rc.root_cause_name "inection type", 
(select count(*) from monitoring.general_metric_metadata_results  where metric_name = rc.root_cause_id and
    entry_date > current_date )
from rootcause.v_rootcauses rc  where domain_code = 'SEC' and area_code  = 'INJ'
```

**Credentials Stored in Database Tables** — _table_
```sql
SELECT * FROM monitoring.v_mssql_credentials_stored_in_tables
```

**Database Restored** — _table_
```sql
SELECT * FROM monitoring.v_database_restored
```

**Enabled Sysadmin** — _table_
```sql
SELECT * FROM monitoring.v_enabled_sysadmin WHERE $__timeFilter(entry_date)
```

**Weak Password Enforcement** — _table_
```sql
SELECT * FROM monitoring.v_sysadmin_accounts_with_weakpassword_enforcement
```

**Linked Server / DBLINKS Hidden Credentials** — _table_
```sql
SELECT * FROM monitoring.linked_servers_hidden_credentials
```

**Locked Accounts** — _table_
```sql
SELECT server, username, account_status, to_timestamp(lock_date::bigint / 1000) AS lock_date FROM
    monitoring.v_oracle_locked_accounts
```

**Scanned Jobs for Leaks** — _table_
```sql
SELECT * FROM monitoring.v_scan_jobs_for_leak
```

**Policy Not Enforced** — _table_
```sql
SELECT * FROM monitoring.v_policy_enforeced
```


## 4. Policy Enforcement & Protection

**Privileged Logins** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.v_enabled_sysadmin WHERE $__timeFilter(entry_date)
```

**Weak Password Policies** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.v_sysadmin_accounts_with_weakpassword_enforcement
```

**Credentials in Tables** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.v_mssql_superuser WHERE login_name != 'infosecuser'
```

**Policy Not Enforced** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.v_policy_enforeced
```

**Policy Findings** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.general_metric_metadata_results WHERE (metric_name LIKE 'SEC-SQL-AZ%%' OR
    metric_name LIKE 'SEC-SQL-CFG%%' OR metric_name LIKE 'SEC-SQL-AU%%') AND
    (metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(entry_date)
```

**Root causes (PII) - ${root_cause_id}** — _table_
```sql
select distinct root_cause_id, root_cause_name, root_cause_desc
from rootcause.v_rootcauses
where domain_code = 'SEC'
  and vendor_name = 'sqlserver'
  and ('${root_cause_id}' = '' OR root_cause_id = '${root_cause_id}')
```

**Policy Violations by Type** — _barchart_
```sql
SELECT COALESCE(i.name, gm.metric_name) AS violation_type, COUNT(*) AS count FROM
    monitoring.general_metric_metadata_results gm LEFT JOIN rootcause.root_causes rc ON rc.root_cause_id =
    gm.metric_name LEFT JOIN rootcause.issues i ON i.issue_id = rc.issue_id WHERE (gm.metric_name LIKE
    'SEC-SQL-AZ%%' OR gm.metric_name LIKE 'SEC-SQL-CFG%%' OR gm.metric_name LIKE 'SEC-SQL-AU%%' OR
    gm.metric_name LIKE 'SEC-SQL-NET%%' OR gm.metric_name LIKE 'SEC-SQL-ACC-010-RC08%%') AND
    (gm.metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(gm.entry_date) GROUP
    BY violation_type ORDER BY count DESC LIMIT 15
```


## 5. Data Protection

**Unmasked Columns** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.v_SEC_SQL_PRI_001_RC10
```

**PII Columns** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.v_SEC_SQL_PRI_001_RC13
```

**Encryption Findings** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.general_metric_metadata_results WHERE (metric_name LIKE 'SEC-SQL-ENC%%' OR
    metric_name LIKE 'SEC-SQL-PRI%%') AND (metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND
    $__timeFilter(entry_date)
```

**Masking Findings** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.general_metric_metadata_results WHERE metric_name LIKE 'SEC-SQL-DAT%%' AND
    (metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(entry_date)
```

**Unmasked Data by Server** — _table_
```sql
SELECT  * FROM monitoring.v_SEC_SQL_PRI_001_RC10
```

**Data Protection - Unmasked Columns** — _table_
```sql
SELECT * FROM monitoring.v_SEC_SQL_PRI_001_RC13 WHERE $__timeFilter(entry_date)
```

**Sensitive Schema (PII Columns)** — _table_
```sql
SELECT * from monitoring.v_SEC_SQL_PRI_001_RC12
```

**Privileged Logins** — _table_
```sql
SELECT DISTINCT root_cause_id, root_cause_name, domain_name, area_name
FROM rootcause.v_rootcauses
WHERE root_cause_name ~* '(privilege)'
ORDER BY root_cause_id;
```

**Root cause details - ${root_cause_id}  ${detail_server} ${detail_table} ${detail_column}** — _table_
```sql
SELECT j.value AS result
FROM jsonb_array_elements(
  COALESCE(monitoring.get_root_cause_resultset(NULLIF('${root_cause_id}',''), $__timeFrom())::jsonb,
    '[]'::jsonb)
) AS j
WHERE (NULLIF('${detail_server}','') IS NULL OR j.value->>'server'      = '${detail_server}')
  AND (NULLIF('${detail_table}','')  IS NULL OR j.value->>'table_name'  = '${detail_table}')
  AND (NULLIF('${detail_column}','') IS NULL OR j.value->>'column_name' = '${detail_column}')
LIMIT 500
```


## 6. Vulnerability Assessment

**Privileged Logins** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.privileged_logins
```

**Weak Passwords** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.weak_passwords
```

**Config Findings** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.general_metric_metadata_results WHERE metric_name LIKE 'SEC-SQL-CFG%%' AND
    (metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(entry_date)
```

**Network Findings** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.general_metric_metadata_results WHERE metric_name LIKE 'SEC-SQL-NET%%' AND
    (metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(entry_date)
```

**Total Vulnerabilities** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.general_metric_metadata_results WHERE metric_name LIKE 'SEC-SQL%%' AND
    (metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(entry_date)
```

**Vulnerabilities by Area** — _barchart_
```sql
SELECT COALESCE(a.name, 'Unknown') AS area, COUNT(*) AS findings FROM
    monitoring.general_metric_metadata_results gm LEFT JOIN rootcause.root_causes rc ON rc.root_cause_id =
    gm.metric_name LEFT JOIN rootcause.issues i ON i.issue_id = rc.issue_id LEFT JOIN rootcause.areas a ON
    a.code = i.area_code WHERE gm.metric_name LIKE 'SEC-SQL%%' AND
    (gm.metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(gm.entry_date) GROUP
    BY a.name ORDER BY findings DESC LIMIT 15
```

**By Severity** — _piechart_
```sql
SELECT COALESCE(gm.metric_metadata_vs_expected::jsonb->>'severity', 'medium') AS severity, COUNT(*) AS count
    FROM monitoring.general_metric_metadata_results gm WHERE gm.metric_name LIKE 'SEC-SQL%%' AND
    (gm.metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(gm.entry_date) GROUP
    BY severity ORDER BY count DESC
```

**Vulnerability Findings Over Time** — _timeseries_
```sql
SELECT DATE_TRUNC('hour', gm.entry_date) AS time, COALESCE(a.name, 'Other') AS metric, COUNT(*) AS value FROM
    monitoring.general_metric_metadata_results gm LEFT JOIN rootcause.root_causes rc ON rc.root_cause_id =
    gm.metric_name LEFT JOIN rootcause.issues i ON i.issue_id = rc.issue_id LEFT JOIN rootcause.areas a ON
    a.code = i.area_code WHERE gm.metric_name LIKE 'SEC-SQL%%' AND
    (gm.metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(gm.entry_date) GROUP
    BY time, metric ORDER BY time
```

**Privileged Logins** — _table_
```sql
SELECT * FROM monitoring.privileged_logins ORDER BY entry_date DESC LIMIT 100
```

**Server Hardening Findings** — _table_
```sql
SELECT * FROM monitoring.server_hardening_unused_inactive_sql_server_logins ORDER BY entry_date DESC LIMIT 50
```

**Vulnerability Root Cause Findings** — _table_
```sql
SELECT gm.server, COALESCE(a.name, '') AS area, COALESCE(i.name, '') AS issue, gm.metric_name AS
    root_cause_id, COALESCE(rc.name, gm.metric_name) AS root_cause,
    (gm.metric_metadata_vs_expected::jsonb->>'row_count')::int AS rows,
    COALESCE(gm.metric_metadata_vs_expected::jsonb->>'severity', 'medium') AS severity,
    (gm.metric_metadata_vs_expected::jsonb->'expected'->>'description') AS description, gm.entry_date AT TIME
    ZONE 'Asia/Jerusalem' AS detected_at FROM monitoring.general_metric_metadata_results gm LEFT JOIN
    rootcause.root_causes rc ON rc.root_cause_id = gm.metric_name LEFT JOIN rootcause.issues i ON i.issue_id =
    rc.issue_id LEFT JOIN rootcause.areas a ON a.code = i.area_code WHERE gm.metric_name LIKE 'SEC-SQL%%' AND
    gm.metric_metadata_vs_expected IS NOT NULL AND (gm.metric_metadata_vs_expected::jsonb->>'matched')::text =
    'true' AND $__timeFilter(gm.entry_date) ORDER BY gm.entry_date DESC LIMIT 100
```

**Weak Passwords** — _table_
```sql
SELECT * FROM monitoring.weak_passwords ORDER BY entry_date DESC LIMIT 50
```


## 7. Automation & Workflows

**Servers** — _stat_
```sql
SELECT COUNT(*) FROM metrics.servers WHERE is_active = true
```

**Root Causes** — _stat_
```sql
SELECT COUNT(DISTINCT root_cause_id) FROM rootcause.root_causes
```

**Detection Rules** — _stat_
```sql
SELECT COUNT(*) FROM rootcause.detection_paths WHERE is_active = true
```

**Custom Metrics** — _stat_
```sql
SELECT COUNT(*) FROM metrics.custom_metrics WHERE is_active = true
```

**Active Transactions** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.active_transactions WHERE $__timeFilter(last_request_end_time)
```

**Metric Results** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.general_metric_metadata_results WHERE $__timeFilter(entry_date)
```

**Log Entries** — _stat_
```sql
SELECT COUNT(*) FROM log.operation_log WHERE $__timeFilter(entry_date)
```

**Metric Executions Over Time** — _timeseries_
```sql
SELECT DATE_TRUNC('hour', entry_date) AS time, COUNT(*) AS executions FROM
    monitoring.general_metric_metadata_results WHERE $__timeFilter(entry_date) GROUP BY time ORDER BY time
```

**Root Causes** — _table_
```sql
SELECT DISTINCT root_cause_id, root_cause_name, domain_name, area_name, issue_name, vendor_name FROM
    rootcause.v_rootcauses ORDER BY root_cause_id LIMIT 100
```

**Enable / Disable Metrics per Server** — _table_
```sql
SELECT sr.row_id, s.server AS "IP Address", s.servername, r.routine_name AS metric_rule, CASE WHEN
    sr.is_active = true THEN 'Active' ELSE 'Inactive' END AS status FROM metrics.servers_routines sr JOIN
    metrics.servers s ON s.row_id = sr.server_id JOIN metrics.routines r ON r.row_id = sr.routine_id ORDER BY
    s.server, r.routine_name
```

**All Metrics (Latest Execution)** — _table_
```sql
SELECT MAX(entry_date) AT TIME ZONE 'Asia/Jerusalem' AS last_run, metric_name FROM
    monitoring.general_metric_metadata_results GROUP BY metric_name ORDER BY last_run DESC
```

**Custom Metrics** — _table_
```sql
SELECT row_id, metric_name, LEFT(query, 80) AS query_preview, description, is_active, db_vendor FROM
    metrics.custom_metrics ORDER BY metric_name
```

**Operation Log** — _table_
```sql
SELECT entry_date AT TIME ZONE 'Asia/Jerusalem' AS time, routine_name, server_name, LEFT(message, 120) AS
    message FROM log.operation_log WHERE $__timeFilter(entry_date) ORDER BY entry_date DESC LIMIT 50
```

**Log Entries by Routine** — _barchart_
```sql
SELECT routine_name, COUNT(*) AS entries FROM log.operation_log WHERE $__timeFilter(entry_date) GROUP BY
    routine_name ORDER BY entries DESC LIMIT 15
```

**Root cause details - ${root_cause_id}** — _table_
```sql
SELECT j.value AS result
FROM jsonb_array_elements(
  COALESCE(monitoring.get_root_cause_resultset(NULLIF('${root_cause_id}',''), $__timeFrom())::jsonb,
    '[]'::jsonb)
) AS j
LIMIT 500
```


## 8. Database restored

**Database restored** — _table_
```sql
select * from monitoring.v_database_restored limit 100--where $__timeFilter(backup_finish_date)
```


## 9. Connections per user

**Connections per user** — _table_
```sql
select cc.server , cc.login_name , cc.connection_count  ,  "Average connection" from
    monitoring.connection_count  cc
join(
select server , login_name , AVG(connection_count::int) "Average connection"  from monitoring.connection_count
where login_name != 'dbdome_mon_usr'
group by server , login_name
) B on cc."server" = B.SERVER and cc.login_name = b.Login_name
where cc.login_name != 'dbdome_mon_usr' and $__timeFilter(entry_date)
```

**Unkown TCP connections** — _table_
```sql
select tcp.server , tcp.client_net_address , tcp.connect_time , at.login_name, at.query , at.start_time ,
    at.last_request_end_time
from (
select tcp.server ,  tcp.client_net_address , tcp.connect_time from monitoring.tcp_connections  tcp where
    client_net_address not in
(
select client_net_address from monitoring.tcp_connections  where connect_time < Now() - interval '1 day'
) 
)tcp 
left outer join  monitoring.active_transactions at on at.server = tcp.server and at.start_time between
    tcp.connect_time and at.last_request_end_time
where $__timeFilter(tcp.connect_time)   and login_name !='dbdome_mon_usr'
```


## Alerts

**Total Alerts** — _stat_
```sql
SELECT 
count(*)
  FROM ALERTS.ALERT_LOG l
  where  l.entry_date  >= $__timeFrom() at time zone current_setting('TimeZone')
  and  l.entry_date  <= $__timeTo() at time zone current_setting('TimeZone')
  and root_cause_id like 'SEC-%'
```

**Critical** — _stat_
```sql
SELECT 
count(*)
  FROM ALERTS.ALERT_LOG l
  
where  l.entry_date  >= $__timeFrom() at time zone current_setting('TimeZone')
and  l.entry_date  <= $__timeTo() at time zone current_setting('TimeZone')
and l.risk_level = 'critical'
and l.root_cause_ID like 'SEC-%'
```

**High** — _stat_
```sql
SELECT 
count(*)
  FROM ALERTS.ALERT_LOG l
  
where  l.entry_date  >= $__timeFrom() at time zone current_setting('TimeZone')
and  l.entry_date  <= $__timeTo() at time zone current_setting('TimeZone')
and l.risk_level = 'high'
and l.root_cause_ID like 'SEC-%'
```

**Medium** — _stat_
```sql
SELECT 
count(*)
  FROM ALERTS.ALERT_LOG l
  
where  l.entry_date  >= $__timeFrom() at time zone current_setting('TimeZone')
and  l.entry_date  <= $__timeTo() at time zone current_setting('TimeZone')
and l.risk_level = 'medium'
and l.root_cause_ID like 'SEC%'
```

**Low alerts** — _stat_
```sql
SELECT 
count(*)
  FROM ALERTS.ALERT_LOG l
  
where  l.entry_date  >= $__timeFrom() at time zone current_setting('TimeZone')
and  l.entry_date  <= $__timeTo() at time zone current_setting('TimeZone')
and l.risk_level = 'low'
and l.root_cause_ID like 'SEC-%'
```

**Servers** — _stat_
```sql
select count(distinct(server_id)) from monitoring.general_metric_metadata_results
```

**Alerts Sent by Mail** — _table_
```sql
SELECT 
  row_id , 
	server,
    servername , 
    risk_level , 
    area,
    issue,
    root_cause,
    root_cause_name,     
    recipients,
    occured_at occured_at ,
    sent_at sent_at , 
	Blocked_at  Blocked_at
FROM (	
  SELECT ROW_NUMBER()  OVER (PARTITION BY l.server, l.root_cause_id ORDER BY L.ENTRY_DATE DESC )SEQ , 
        l.row_id ,
         l.server,
         s.servername , 
         l.risk_level , 
         COALESCE(rc.area_name,   '') AS area,
         COALESCE(rc.issue_name,  '') AS issue,
         l.root_cause_id              AS root_cause,
         rc.root_cause_name,     
         mal.recipients,
         l.entry_date  AS occured_at,
         mal.entry_date sent_at ,
		 blc.entry_date  Blocked_at
  FROM ALERTS.ALERT_LOG l
  join (select server_id , servername , server ,db_vendor  from metrics.servers where is_active is true ) s on
    s.server = l.server
  LEFT JOIN alerts.mail_alert_log mal ON mal.server = l.server AND mal.metric_name = l.root_cause_id and
    mal.entry_date = l.entry_date
  LEFT JOIN alerts.blocks blc ON blc.server = l.server AND blc.metric_name = l.root_cause_id and
    blc.entry_date = l.entry_date
  JOIN rootcause.v_rootcauses rc ON rc.root_cause_id = l.root_cause_id and (rc.vendor_name = s.db_vendor or
    rc.vendor_name ='sqlserver')
    AND (l.risk_level = '${risk_level}' OR '${risk_level}' = 'All')
) WHERE SEQ=1
and  occured_at  >= $__timeFrom() at time zone current_setting('TimeZone')
and  occured_at  <= $__timeTo() at time zone current_setting('TimeZone')
```

**Active Detection Findings** — _table_
```sql
SELECT * FROM monitoring.get_alert_log_resultset_byid('${alert_id}')
WHERE '${alert_id}' <> ''
```


## Audit expired

**Expired Audit Records** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.v_oracle_audit_expired
```

**Servers Affected** — _stat_
```sql
SELECT COUNT(DISTINCT server) FROM monitoring.v_oracle_audit_expired
```

**Audit Root Causes** — _stat_
```sql
SELECT COUNT(DISTINCT metric_name) FROM monitoring.general_metric_metadata_results WHERE metric_name LIKE
    'SEC-SQL-AUD%%' AND (metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND
    $__timeFilter(entry_date)
```

**Audit Alerts Sent** — _stat_
```sql
SELECT COUNT(*) FROM alerts.mail_alert_log WHERE metric_name LIKE 'SEC-SQL-AUD%%' AND
    $__timeFilter(entry_date)
```

**Expired Audits by Server** — _barchart_
```sql
SELECT server, COUNT(*) AS expired FROM monitoring.v_oracle_audit_expired GROUP BY server ORDER BY expired
    DESC
```

**Top Audit Root Causes** — _bargauge_
```sql
SELECT COALESCE(rc.name, gm.metric_name) AS root_cause, COUNT(*) AS count FROM
    monitoring.general_metric_metadata_results gm LEFT JOIN rootcause.root_causes rc ON rc.root_cause_id =
    gm.metric_name WHERE gm.metric_name LIKE 'SEC-SQL-AUD%%' AND
    (gm.metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(gm.entry_date) GROUP
    BY root_cause ORDER BY count DESC LIMIT 10
```

**Audit Expired Records** — _table_
```sql
SELECT * FROM monitoring.v_oracle_audit_expired
```

**Audit Root Cause Findings (SEC-SQL-AUD)** — _table_
```sql
SELECT gm.server, COALESCE(i.name, '') AS issue, gm.metric_name AS root_cause_id, COALESCE(rc.name,
    gm.metric_name) AS root_cause, (gm.metric_metadata_vs_expected::jsonb->>'row_count')::int AS rows,
    COALESCE(gm.metric_metadata_vs_expected::jsonb->>'severity', 'medium') AS severity,
    (gm.metric_metadata_vs_expected::jsonb->'expected'->>'description') AS description, gm.entry_date AT TIME
    ZONE 'Asia/Jerusalem' AS detected_at FROM monitoring.general_metric_metadata_results gm LEFT JOIN
    rootcause.root_causes rc ON rc.root_cause_id = gm.metric_name LEFT JOIN rootcause.issues i ON i.issue_id =
    rc.issue_id WHERE gm.metric_name LIKE 'SEC-SQL-AUD%%' AND gm.metric_metadata_vs_expected IS NOT NULL AND
    (gm.metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(gm.entry_date) ORDER
    BY gm.entry_date DESC LIMIT 50
```


## Blocker Activity

**Killed** — _stat_
```sql
SELECT count(*) FROM alerts.blocker_log WHERE action='killed' AND $__timeFilter(entry_date)
```

**Dry-run** — _stat_
```sql
SELECT count(*) FROM alerts.blocker_log WHERE action='dry-run' AND $__timeFilter(entry_date)
```

**Skipped** — _stat_
```sql
SELECT count(*) FROM alerts.blocker_log WHERE action='skipped' AND $__timeFilter(entry_date)
```

**Errors** — _stat_
```sql
SELECT count(*) FROM alerts.blocker_log WHERE action='error' AND $__timeFilter(entry_date)
```

**Dry-run mode** — _stat_
```sql
SELECT value FROM config.global_params WHERE key='blocker_dry_run' ORDER BY row_id DESC LIMIT 1
```

**Blocker log** — _table_
```sql
SELECT entry_date AT TIME ZONE 'Asia/Jerusalem' AS entry_date, server, db_vendor, root_cause_id, session_id,
    action, detail FROM alerts.blocker_log WHERE $__timeFilter(entry_date) ORDER BY entry_date DESC LIMIT 500
```

**Executed blocks (alerts.blocks)** — _table_
```sql
SELECT entry_date AT TIME ZONE 'Asia/Jerusalem' AS entry_date, server, metric_name, subject, body FROM
    alerts.blocks ORDER BY entry_date DESC LIMIT 200
```


## Blocking transactions

**blocked transactions** — _barchart_
```sql
select 
count(*) "number of blocked transactions" , 
server ||'-'||login_name 
from monitoring.v_blocking_transactions
where  login_name != 'infosecuser'
group by server ||'-'||login_name
```

**(untitled panel)** — _table_
```sql
select distinct   TO_CHAR(to_timestamp(start_time::bigint / 1000 ), 'YYYY-MM-DD') AS "start time" from
    monitoring.v_blocking_transactions
order by TO_CHAR(to_timestamp(start_time::bigint / 1000 ), 'YYYY-MM-DD')
```

**Active users** — _bargauge_
```sql
select sum("Number of connections") from 
(
select count(*) "Number of connections" from monitoring.tcp_connections where connect_time between Now() -
    interval '1 minute' and Now()
union all
select count(*) from monitoring.v_oracle_transactions where entry_date > Now() - interval '1 minute'
)
```

**SQL injection by patterns** — _table_
```sql
select 
server , 
session_id , 
login_name , 
status , 
 to_timestamp( start_time::bigint /1000) start_time,
command , 
cpu_time , 
Total_elapsed_time::bigint / 1000000 Total_elapsed_time
from monitoring.v_blocking_transactions
```

**Recent alerts - SQL injections** — _stat_
```sql
select 
    (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query  ILIKE ANY (ARRAY['%/*%*/%', '%--%']  )) as "comment_based_injections",
        (select count(*) from monitoring.active_transactions where  LAST_request_end_time > Now() - interval
    '1 minute' and query   ILIKE ANY (ARRAY['%OR 1=1%', '%AND 1=1%' , '%OR ''a''=''a%'''])) as "Boolean-based
    injections" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query  ILIKE ANY (ARRAY['%'' OR 1=1 --''%', '%"" OR 1=1 --%'])) as "tautology_with_comments" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query  ILIKE ANY (ARRAY['%UNION SELECT', '%UNION ALL SELECT%'])) as "union_based_injection" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query  ILIKE ANY (ARRAY['%; DROP TABLE users', '%; EXEC xp_cmdshell%'])) as "stacked_queries"
    ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%WAITFOR DELAY%', '%pg_sleep%','%SLEEP%'])) as "time_based_blind
    _injection"          ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%CONVERT%', '%CAST%'])) as "error_based_injection"           ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%information_schema.tables%',
    '%information_schema.columns%','%sys.tables%','%pg_catalog%'])) as "information_schema_probing"
    ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%'' OR ''=''%', '%'' OR ''x''=''x''%', '%admin''--%'])) as
    "Authentication bypass patterns" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%0x414243%', '%CHAR(65,66,67)%'])) as "encoding injection"  ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%xp_cmdshell%', '%sp_executesql%'])) as "shell_system_functions
    injection" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%ORDER BY 1%', '%ORDER BY%'])) as "ORDER BY_GROUP BY injection"
```

**Connectivity reports** — _barchart_
```sql
select count(*) , server ,client_net_address from monitoring.tcp_connections
where connect_Time > Now()   - interval '15 minutes'
group by server ,client_net_address
```

**Sensitivity reports** — _barchart_
```sql
select count(*) , at.server from monitoring.active_transactions at
join(
select TABLE_NAME ,  column_name from monitoring.v_schema where column_name ILIKE ANY
    (array['%fname%','%lname%','%email%','%lastname%','%firstname%','%last_name%','%firstname%','%phone%','%ssn%','%dob%','%birth%','%credit%','%email%','%idcard%','%idnum%','%id_card%','%id_num%'])
) c on at.query like '%'||c.column_name ||'%'
group by at.server
```

**SQL Injection analysis** — _barchart_
```sql
select server ,
    (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query  ILIKE ANY (ARRAY['%/*%*/%', '%--%']  )) as "comment_based_injections",
        (select count(*) from monitoring.active_transactions where  LAST_request_end_time > Now() - interval
    '1 minute' and query   ILIKE ANY (ARRAY['%OR 1=1%', '%AND 1=1%' , '%OR ''a''=''a%'''])) as "Boolean-based
    injections" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query  ILIKE ANY (ARRAY['%'' OR 1=1 --''%', '%"" OR 1=1 --%'])) as "tautology_with_comments" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query  ILIKE ANY (ARRAY['%UNION SELECT', '%UNION ALL SELECT%'])) as "union_based_injection" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query  ILIKE ANY (ARRAY['%; DROP TABLE users', '%; EXEC xp_cmdshell%'])) as "stacked_queries"
    ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%WAITFOR DELAY%', '%pg_sleep%','%SLEEP%'])) as "time_based_blind
    _injection"          ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%CONVERT%', '%CAST%'])) as "error_based_injection"           ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%information_schema.tables%',
    '%information_schema.columns%','%sys.tables%','%pg_catalog%'])) as "information_schema_probing"
    ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%'' OR ''=''%', '%'' OR ''x''=''x''%', '%admin''--%'])) as
    "Authentication bypass patterns" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%0x414243%', '%CHAR(65,66,67)%'])) as "encoding injection"  ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%xp_cmdshell%', '%sp_executesql%'])) as "shell_system_functions
    injection" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%ORDER BY 1%', '%ORDER BY%'])) as "ORDER BY_GROUP BY injection"
from monitoring.active_transactions
group by server
```


## Blocks in databases

**Database Blocks** — _barchart_
```sql
select count(*) , server from monitoring.v_mssql_blocking_sessiond
group by server
```

**(untitled panel)** — _table_
```sql
select distinct server  from monitoring.v_mssql_blocking_sessiond
```

**Active users** — _bargauge_
```sql
select sum("Number of connections") from 
(
select count(*) "Number of connections" from monitoring.tcp_connections where connect_time between Now() -
    interval '1 minute' and Now()
union all
select count(*) from monitoring.v_oracle_transactions where entry_date > Now() - interval '1 minute'
)
```

**Database blocks** — _table_
```sql
select * from monitoring.v_mssql_blocking_sessiond
```

**Recent alerts** — _stat_
```sql
select 
    (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query  ILIKE ANY (ARRAY['%/*%*/%', '%--%']  )) as "comment_based_injections",
        (select count(*) from monitoring.active_transactions where  LAST_request_end_time > Now() - interval
    '1 minute' and query   ILIKE ANY (ARRAY['%OR 1=1%', '%AND 1=1%' , '%OR ''a''=''a%'''])) as "Boolean-based
    injections" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query  ILIKE ANY (ARRAY['%'' OR 1=1 --''%', '%"" OR 1=1 --%'])) as "tautology_with_comments" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query  ILIKE ANY (ARRAY['%UNION SELECT', '%UNION ALL SELECT%'])) as "union_based_injection" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query  ILIKE ANY (ARRAY['%; DROP TABLE users', '%; EXEC xp_cmdshell%'])) as "stacked_queries"
    ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%WAITFOR DELAY%', '%pg_sleep%','%SLEEP%'])) as "time_based_blind
    _injection"          ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%CONVERT%', '%CAST%'])) as "error_based_injection"           ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%information_schema.tables%',
    '%information_schema.columns%','%sys.tables%','%pg_catalog%'])) as "information_schema_probing"
    ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%'' OR ''=''%', '%'' OR ''x''=''x''%', '%admin''--%'])) as
    "Authentication bypass patterns" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%0x414243%', '%CHAR(65,66,67)%'])) as "encoding injection"  ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%xp_cmdshell%', '%sp_executesql%'])) as "shell_system_functions
    injection" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%ORDER BY 1%', '%ORDER BY%'])) as "ORDER BY_GROUP BY injection"
from monitoring.active_transactions
group by server
```

**Connection number per user** — _barchart_
```sql
select sum(connection_count::int) , server ||'-'||login_name   from monitoring.connection_count
group by  server ||'-'||login_name
```

**Active threats** — _gauge_
```sql
select count(*) "suspicious queries" from monitoring.v_suspiscous
```


## Configuration

**Monitored Servers** — _stat_
```sql
SELECT COUNT(*) AS "Servers" FROM metrics.servers WHERE is_active = true
```

**Active Detection Rules** — _stat_
```sql
SELECT COUNT(*) AS "Rules" FROM rootcause.detection_paths WHERE is_active = true
```

**Alert Rules** — _stat_
```sql
SELECT COUNT(*) AS "Alert Rules" FROM config.alerts_issue_root_causes
```

**Sensitive Columns** — _stat_
```sql
SELECT COUNT(*) AS "PII Columns" FROM monitoring.sensitive_schema
```

**Scheduled Reports** — _stat_
```sql
SELECT COUNT(*) AS "Reports" FROM config.reports WHERE is_active = true
```

**Alerts Sent (7d)** — _stat_
```sql
SELECT COUNT(*) AS "Alerts" FROM alerts.mail_alert_log WHERE entry_date >= NOW() - INTERVAL '7 days'
```

**Monitored Servers** — _table_
```sql
SELECT server, db_name AS database, port, db_vendor AS vendor, auth_type, is_active, server_id FROM
    metrics.servers ORDER BY server
```

**Detection Rules by Vendor** — _piechart_
```sql
SELECT vendor_slug AS vendor, COUNT(*) AS rules FROM rootcause.detection_paths WHERE is_active = true GROUP BY
    vendor_slug ORDER BY rules DESC
```

**Detection Rules by Domain** — _piechart_
```sql
SELECT d.name AS domain, COUNT(DISTINCT dp.id) AS rules FROM rootcause.detection_paths dp JOIN
    rootcause.root_causes rc ON rc.root_cause_id = dp.root_cause_id JOIN rootcause.issues i ON i.issue_id =
    rc.issue_id JOIN rootcause.domains d ON d.code = i.domain_code WHERE dp.is_active = true GROUP BY d.name
    ORDER BY rules DESC
```

**Alerts Sent Over Time** — _timeseries_
```sql
SELECT DATE_TRUNC('hour', entry_date) AS time, COUNT(*) AS alerts FROM alerts.mail_alert_log WHERE
    $__timeFilter(entry_date) GROUP BY time ORDER BY time
```

**Alerts by Severity** — _barchart_
```sql
SELECT CASE WHEN metric_name LIKE '%RC01' THEN 'Unknown Login' WHEN metric_name LIKE '%RC02' THEN 'Unexpected
    Program' WHEN metric_name LIKE '%RC03' THEN 'Unexpected DB' WHEN metric_name LIKE '%RC04' THEN 'Suspicious
    Patterns' WHEN metric_name LIKE '%RC05' THEN 'PII Access' WHEN metric_name LIKE '%RC06' THEN 'SQL
    Injection' WHEN metric_name LIKE '%RC07' THEN 'After Hours' WHEN metric_name LIKE '%RC08' THEN 'Privilege
    Escalation' WHEN metric_name LIKE '%RC09' THEN 'Data Exfiltration' WHEN metric_name LIKE '%RC10' THEN
    'Multi-Host Login' WHEN metric_name LIKE '%RC11' THEN 'Schema Recon' WHEN metric_name LIKE '%RC12' THEN
    'Dormant Account' WHEN metric_name LIKE '%RC13' THEN 'Mass Modification' ELSE metric_name END AS
    alert_type, COUNT(*) AS count FROM alerts.mail_alert_log WHERE $__timeFilter(entry_date) GROUP BY
    alert_type ORDER BY count DESC LIMIT 15
```

**Configured Reports** — _table_
```sql
SELECT r.report_name, r.is_active, COALESCE(j.occurance, 'not scheduled') AS schedule, j.occurs_at::text AS
    run_time, r.report_url AS type FROM config.reports r LEFT JOIN config.reports_jobs rj ON rj.report_id =
    r.row_id LEFT JOIN jobs.jobs j ON j.row_id = rj.job_id ORDER BY r.report_name
```

**Alert Thresholds** — _table_
```sql
SELECT a.alert_name, t.level, CASE t.level WHEN 1 THEN 'Info' WHEN 2 THEN 'Warning' WHEN 3 THEN 'Critical' END
    AS severity, t.value_start, t.value_end FROM config.alerts_thresholds at JOIN config.alerts a ON a.row_id
    = at.alert_id JOIN config.thresholds t ON t.row_id = at.threshold_id ORDER BY t.level DESC, a.alert_name
```

**Sensitive Schema - PII Columns** — _table_
```sql
SELECT server, database_name, table_name, column_name, data_type, entry_date FROM monitoring.sensitive_schema
    ORDER BY server, table_name, column_name LIMIT 100
```

**PII Columns by Category** — _piechart_
```sql
SELECT CASE WHEN lower(column_name) ~ '(email|e_mail)' THEN 'Email' WHEN lower(column_name) ~
    '(phone|mobile|cell)' THEN 'Phone' WHEN lower(column_name) ~ '(first_name|last_name|full_name|surname)'
    THEN 'Name' WHEN lower(column_name) ~ '(address|street|city|zip)' THEN 'Address' WHEN lower(column_name) ~
    '(ssn|national_id|passport|id_card)' THEN 'ID/SSN' WHEN lower(column_name) ~
    '(credit_card|card_num|iban|bank)' THEN 'Financial' WHEN lower(column_name) ~ '(salary|income|wage)' THEN
    'Salary' WHEN lower(column_name) ~ '(password|pwd|secret)' THEN 'Credential' WHEN lower(column_name) ~
    '(birth|dob)' THEN 'DOB' ELSE 'Other' END AS category, COUNT(*) AS count FROM monitoring.sensitive_schema
    GROUP BY category ORDER BY count DESC
```

**Webhook Alert Channels** — _table_
```sql
SELECT metric_type, CASE WHEN send_mail_alert THEN 'ON' ELSE 'OFF' END AS mail, CASE WHEN send_siem_alert THEN
    'ON' ELSE 'OFF' END AS siem, CASE WHEN send_diagnosis_evidence THEN 'ON' ELSE 'OFF' END AS diagnosis FROM
    config.webook_alerts ORDER BY metric_type
```

**Global Parameters** — _table_
```sql
SELECT key, CASE WHEN key ILIKE '%password%' OR key ILIKE '%api_key%' OR key ILIKE '%secret%' THEN '********'
    ELSE value END AS value FROM config.global_params ORDER BY key
```

**Recent Operation Log** — _table_
```sql
SELECT entry_date AS time, routine_name, server_name, LEFT(message, 150) AS message FROM log.operation_log
    WHERE $__timeFilter(entry_date) ORDER BY entry_date DESC LIMIT 50
```

**Detection Results Over Time** — _timeseries_
```sql
SELECT DATE_TRUNC('hour', entry_date) AS time, SUM(CASE WHEN
    (metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' THEN 1 ELSE 0 END) AS matched, SUM(CASE
    WHEN (metric_metadata_vs_expected::jsonb->>'matched')::text = 'false' THEN 1 ELSE 0 END) AS not_matched
    FROM monitoring.general_metric_metadata_results WHERE metric_metadata_vs_expected IS NOT NULL AND
    $__timeFilter(entry_date) GROUP BY time ORDER BY time
```

**Top Root Causes by Findings** — _barchart_
```sql
SELECT metric_name AS root_cause, COUNT(*) AS findings FROM monitoring.general_metric_metadata_results WHERE
    metric_metadata_vs_expected IS NOT NULL AND (metric_metadata_vs_expected::jsonb->>'matched')::text =
    'true' AND $__timeFilter(entry_date) GROUP BY metric_name ORDER BY findings DESC LIMIT 15
```

**Rootcause Taxonomy Overview** — _table_
```sql
SELECT d.name AS domain, a.name AS area, i.issue_id, i.name AS issue, COUNT(DISTINCT rc.root_cause_id) AS
    root_causes, COUNT(DISTINCT dp.id) AS detection_paths, COUNT(DISTINCT rp.id) AS resolution_paths FROM
    rootcause.domains d JOIN rootcause.issues i ON i.domain_code = d.code JOIN rootcause.areas a ON a.code =
    i.area_code JOIN rootcause.root_causes rc ON rc.issue_id = i.issue_id LEFT JOIN rootcause.detection_paths
    dp ON dp.root_cause_id = rc.root_cause_id AND dp.is_active = true LEFT JOIN rootcause.resolution_paths rp
    ON rp.root_cause_id = rc.root_cause_id AND rp.is_active = true WHERE d.is_enabled = true GROUP BY d.name,
    a.name, i.issue_id, i.name ORDER BY d.name, a.name, i.issue_id LIMIT 100
```

**Mail Configuration** — _table_
```sql
SELECT row_id, mail_sender, smtp_server, smtp_port, CASE WHEN smtp_user IS NOT NULL THEN 'Configured' ELSE
    'None' END AS auth, tls FROM config.mail_config ORDER BY row_id
```

**Mail Groups & Recipients** — _table_
```sql
SELECT row_id, mail_config_id, group_name, recipients, is_active FROM config.mail_groups ORDER BY group_name
```

**Risk Levels** — _table_
```sql
SELECT row_id, trim(risk_level) AS risk_level, is_active FROM rootcause.risk_level ORDER BY row_id
```

**Print (filtered view)** — _table_
```sql
SELECT '🖨  Print this filtered view (opens clean tab -> Ctrl+P / Save as PDF)' AS print
```


## Connectivity

**Active Connections** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.tcp_connections WHERE connect_time > NOW() - INTERVAL '1 hour'
```

**Unique Clients** — _stat_
```sql
SELECT COUNT(DISTINCT client_net_address) FROM monitoring.tcp_connections WHERE connect_time > NOW() -
    INTERVAL '1 hour'
```

**Servers** — _stat_
```sql
SELECT COUNT(DISTINCT server) FROM monitoring.tcp_connections WHERE connect_time > NOW() - INTERVAL '1 hour'
```

**Network Findings** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.general_metric_metadata_results WHERE metric_name LIKE 'SEC-SQL-NET%%' AND
    (metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(entry_date)
```

**Connection Findings** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.general_metric_metadata_results WHERE metric_name LIKE 'PERF-SQL-CN%%' AND
    (metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(entry_date)
```

**Connections by Server & Client** — _barchart_
```sql
SELECT server || ' <- ' || client_net_address AS connection, COUNT(*) AS count FROM monitoring.tcp_connections
    WHERE connect_time > NOW() - INTERVAL '1 hour' GROUP BY server, client_net_address ORDER BY count DESC
    LIMIT 15
```

**By Protocol** — _piechart_
```sql
SELECT COALESCE(protocol_type, 'unknown') AS protocol, COUNT(*) AS count FROM monitoring.tcp_connections WHERE
    connect_time > NOW() - INTERVAL '1 hour' GROUP BY protocol_type
```

**By Auth Scheme** — _piechart_
```sql
SELECT COALESCE(auth_scheme, 'unknown') AS auth, COUNT(*) AS count FROM monitoring.tcp_connections WHERE
    connect_time > NOW() - INTERVAL '1 hour' GROUP BY auth_scheme
```

**TCP Connections** — _table_
```sql
SELECT server, connect_time, net_transport, protocol_type, encrypt_option, auth_scheme, client_net_address,
    num_reads, num_writes, last_read, last_write FROM monitoring.tcp_connections WHERE connect_time > NOW() -
    INTERVAL '1 hour' ORDER BY connect_time DESC LIMIT 200
```

**Network & Connection Root Cause Findings** — _table_
```sql
SELECT gm.server, COALESCE(i.name, '') AS issue, gm.metric_name AS root_cause_id, COALESCE(rc.name,
    gm.metric_name) AS root_cause, (gm.metric_metadata_vs_expected::jsonb->>'row_count')::int AS rows,
    COALESCE(gm.metric_metadata_vs_expected::jsonb->>'severity', 'medium') AS severity,
    (gm.metric_metadata_vs_expected::jsonb->'expected'->>'description') AS description, gm.entry_date AT TIME
    ZONE 'Asia/Jerusalem' AS detected_at FROM monitoring.general_metric_metadata_results gm LEFT JOIN
    rootcause.root_causes rc ON rc.root_cause_id = gm.metric_name LEFT JOIN rootcause.issues i ON i.issue_id =
    rc.issue_id WHERE (gm.metric_name LIKE 'SEC-SQL-NET%%' OR gm.metric_name LIKE 'PERF-SQL-CN%%' OR
    gm.metric_name LIKE 'SEC-SQL-ACC-010-RC10%%') AND gm.metric_metadata_vs_expected IS NOT NULL AND
    (gm.metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(gm.entry_date) ORDER
    BY gm.entry_date DESC LIMIT 50
```

**Data Activity (Transactions/hour)** — _barchart_
```sql
SELECT server, COUNT(*) AS transactions FROM monitoring.active_transactions WHERE last_request_end_time >
    NOW() - INTERVAL '1 hour' GROUP BY server ORDER BY transactions DESC
```

**Connections per Client** — _barchart_
```sql
SELECT server || ' <- ' || client_net_address AS client, COUNT(*) AS connections FROM
    monitoring.tcp_connections WHERE connect_time > NOW() - INTERVAL '1 hour' GROUP BY server,
    client_net_address ORDER BY connections DESC LIMIT 10
```


## Credentials stored in tables

**Credentials Found** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.v_mssql_credentials_stored_in_tables
```

**Servers Affected** — _stat_
```sql
SELECT COUNT(DISTINCT server) FROM monitoring.v_mssql_credentials_stored_in_tables
```

**Tables with Credentials** — _stat_
```sql
SELECT COUNT(DISTINCT table_name) FROM monitoring.v_mssql_credentials_stored_in_tables
```

**Root Cause Findings** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.general_metric_metadata_results WHERE metric_name LIKE 'SEC-SQL-PRI%%' AND
    (metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(entry_date)
```

**Credentials by Server & Table** — _barchart_
```sql
SELECT server || ' - ' || table_name AS location, COUNT(*) AS count FROM
    monitoring.v_mssql_credentials_stored_in_tables GROUP BY server, table_name ORDER BY count DESC LIMIT 15
```

**By Server** — _piechart_
```sql
SELECT server, COUNT(*) AS count FROM monitoring.v_mssql_credentials_stored_in_tables GROUP BY server ORDER BY
    count DESC
```

**Credentials Stored in Database Tables** — _table_
```sql
SELECT * FROM monitoring.v_mssql_credentials_stored_in_tables
```

**PII/Credential Root Cause Findings** — _table_
```sql
SELECT gm.server, gm.metric_name AS root_cause_id, COALESCE(rc.name, gm.metric_name) AS root_cause,
    (gm.metric_metadata_vs_expected::jsonb->>'row_count')::int AS rows,
    COALESCE(gm.metric_metadata_vs_expected::jsonb->>'severity', 'medium') AS severity,
    (gm.metric_metadata_vs_expected::jsonb->'expected'->>'description') AS description, gm.entry_date AT TIME
    ZONE 'Asia/Jerusalem' AS detected_at FROM monitoring.general_metric_metadata_results gm LEFT JOIN
    rootcause.root_causes rc ON rc.root_cause_id = gm.metric_name WHERE (gm.metric_name LIKE 'SEC-SQL-PRI%%'
    OR gm.metric_name LIKE 'SEC-SQL-ENC%%') AND gm.metric_metadata_vs_expected IS NOT NULL AND
    (gm.metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(gm.entry_date) ORDER
    BY gm.entry_date DESC LIMIT 50
```


## Custom metrics

**Total Metrics** — _stat_
```sql
SELECT COUNT(*) FROM metrics.custom_metrics
```

**Active Metrics** — _stat_
```sql
SELECT COUNT(*) FROM metrics.custom_metrics WHERE is_active = true
```

**Inactive Metrics** — _stat_
```sql
SELECT COUNT(*) FROM metrics.custom_metrics WHERE is_active = false
```

**Metric Results (period)** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.general_metric_metadata_results WHERE $__timeFilter(entry_date)
```

**Matched Findings** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.general_metric_metadata_results WHERE metric_metadata_vs_expected IS NOT NULL
    AND (metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(entry_date)
```

**Metrics by Vendor** — _piechart_
```sql
SELECT COALESCE(db_vendor, 'unknown') AS vendor, COUNT(*) AS count FROM metrics.custom_metrics GROUP BY
    db_vendor ORDER BY count DESC
```

**By Type** — _piechart_
```sql
SELECT COALESCE(metrics_type, 'standard') AS type, COUNT(*) AS count FROM metrics.custom_metrics GROUP BY
    metrics_type ORDER BY count DESC
```

**Top Executed Metrics** — _barchart_
```sql
SELECT metric_name, COUNT(*) AS executions FROM monitoring.general_metric_metadata_results WHERE
    $__timeFilter(entry_date) GROUP BY metric_name ORDER BY executions DESC LIMIT 15
```

**Custom Metrics Configuration** — _table_
```sql
SELECT row_id, metric_name, LEFT(query, 100) AS query_preview, description, is_active, db_vendor,
    metrics_type, entry_date AT TIME ZONE 'Asia/Jerusalem' AS created FROM metrics.custom_metrics ORDER BY
    metric_name
```

**Metric Results with Comparison** — _table_
```sql
SELECT server, metric_name, (metric_metadata_vs_expected::jsonb->>'row_count')::int AS rows,
    (metric_metadata_vs_expected::jsonb->>'matched')::text AS matched,
    COALESCE(metric_metadata_vs_expected::jsonb->>'severity', '') AS severity,
    metric_metadata_vs_expected::jsonb->>'condition' AS condition, entry_date AT TIME ZONE 'Asia/Jerusalem' AS
    executed_at FROM monitoring.general_metric_metadata_results WHERE metric_metadata_vs_expected IS NOT NULL
    AND $__timeFilter(entry_date) ORDER BY entry_date DESC LIMIT 100
```

**Metric Executions Over Time** — _timeseries_
```sql
SELECT DATE_TRUNC('hour', entry_date) AS time, COUNT(*) AS executions FROM
    monitoring.general_metric_metadata_results WHERE $__timeFilter(entry_date) GROUP BY time ORDER BY time
```


## Database connections per user

**Total Connections** — _stat_
```sql
SELECT SUM(connection_count::int) FROM monitoring.connection_count
```

**Unique Users** — _stat_
```sql
SELECT COUNT(DISTINCT login_name) FROM monitoring.connection_count
```

**Servers** — _stat_
```sql
SELECT COUNT(DISTINCT server) FROM monitoring.connection_count
```

**Multi-Host Alerts** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.general_metric_metadata_results WHERE metric_name LIKE '%%ACC-010-RC10%%' AND
    (metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(entry_date)
```

**Connection Findings** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.general_metric_metadata_results WHERE metric_name LIKE 'PERF-SQL-CN%%' AND
    (metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(entry_date)
```

**Connections per User** — _barchart_
```sql
SELECT server || ' - ' || login_name AS user_server, SUM(connection_count::int) AS connections FROM
    monitoring.connection_count GROUP BY server, login_name ORDER BY connections DESC LIMIT 20
```

**By Server** — _piechart_
```sql
SELECT server, SUM(connection_count::int) AS connections FROM monitoring.connection_count GROUP BY server
    ORDER BY connections DESC
```

**Connections per User (Detail)** — _table_
```sql
SELECT * FROM monitoring.connection_count ORDER BY connection_count::int DESC
```

**Connection Root Cause Findings** — _table_
```sql
SELECT gm.server, COALESCE(i.name, '') AS issue, gm.metric_name AS root_cause_id, COALESCE(rc.name,
    gm.metric_name) AS root_cause, (gm.metric_metadata_vs_expected::jsonb->>'row_count')::int AS rows,
    COALESCE(gm.metric_metadata_vs_expected::jsonb->>'severity', 'medium') AS severity,
    (gm.metric_metadata_vs_expected::jsonb->'expected'->>'description') AS description, gm.entry_date AT TIME
    ZONE 'Asia/Jerusalem' AS detected_at FROM monitoring.general_metric_metadata_results gm LEFT JOIN
    rootcause.root_causes rc ON rc.root_cause_id = gm.metric_name LEFT JOIN rootcause.issues i ON i.issue_id =
    rc.issue_id WHERE (gm.metric_name LIKE 'PERF-SQL-CN%%' OR gm.metric_name LIKE '%%ACC-010-RC10%%') AND
    gm.metric_metadata_vs_expected IS NOT NULL AND (gm.metric_metadata_vs_expected::jsonb->>'matched')::text =
    'true' AND $__timeFilter(gm.entry_date) ORDER BY gm.entry_date DESC LIMIT 50
```


## Database restored

**Database restored** — _gauge_
```sql
select count(*) from monitoring.v_database_restored
```

**(untitled panel)** — _table_
```sql
select  server from monitoring.v_database_restored
```

**Active users** — _bargauge_
```sql
select sum("Number of connections") from 
(
select count(*) "Number of connections" from monitoring.tcp_connections where connect_time between Now() -
    interval '1 minute' and Now()
union all
select count(*) from monitoring.v_oracle_transactions where entry_date > Now() - interval '1 minute'
)
```

**Recent alerts** — _stat_
```sql
select 
    (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query  ILIKE ANY (ARRAY['%/*%*/%', '%--%']  )) as "comment_based_injections",
        (select count(*) from monitoring.active_transactions where  LAST_request_end_time > Now() - interval
    '1 minute' and query   ILIKE ANY (ARRAY['%OR 1=1%', '%AND 1=1%' , '%OR ''a''=''a%'''])) as "Boolean-based
    injections" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query  ILIKE ANY (ARRAY['%'' OR 1=1 --''%', '%"" OR 1=1 --%'])) as "tautology_with_comments" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query  ILIKE ANY (ARRAY['%UNION SELECT', '%UNION ALL SELECT%'])) as "union_based_injection" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query  ILIKE ANY (ARRAY['%; DROP TABLE users', '%; EXEC xp_cmdshell%'])) as "stacked_queries"
    ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%WAITFOR DELAY%', '%pg_sleep%','%SLEEP%'])) as "time_based_blind
    _injection"          ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%CONVERT%', '%CAST%'])) as "error_based_injection"           ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%information_schema.tables%',
    '%information_schema.columns%','%sys.tables%','%pg_catalog%'])) as "information_schema_probing"
    ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%'' OR ''=''%', '%'' OR ''x''=''x''%', '%admin''--%'])) as
    "Authentication bypass patterns" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%0x414243%', '%CHAR(65,66,67)%'])) as "encoding injection"  ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%xp_cmdshell%', '%sp_executesql%'])) as "shell_system_functions
    injection" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%ORDER BY 1%', '%ORDER BY%'])) as "ORDER BY_GROUP BY injection"
from monitoring.active_transactions
group by server
```

**Database restored** — _table_
```sql
select  * from monitoring.v_database_restored
```

**Connection number per user** — _barchart_
```sql
select sum(connection_count::int) , server ||'-'||login_name   from monitoring.connection_count
group by  server ||'-'||login_name
```

**Active threats** — _gauge_
```sql
select count(*) "suspicious queries" from monitoring.v_suspiscous
```


## Email configuration

**Email configuration** — _table_
```sql
select mc.row_id , smtp_server , smtp_password  , smtp_port , tls  , mg.recipients from config.mail_config mc
	join config.mail_groups mg on mg.mail_config_id = mc.row_id
```

**Mail Groups & Recipients** — _table_
```sql
SELECT row_id, mail_config_id, group_name, recipients, is_active FROM config.mail_groups ORDER BY group_name
```


## Enabled sysadmin

**Enabled sysadmin** — _barchart_
```sql
select count(*) ,server  from monitoring.v_enabled_sysadmin
group by server
```

**(untitled panel)** — _table_
```sql
select distinct server  from monitoring.v_enabled_sysadmin
```

**Active users** — _bargauge_
```sql
select sum("Number of connections") from 
(
select count(*) "Number of connections" from monitoring.tcp_connections where connect_time between Now() -
    interval '1 minute' and Now()
union all
select count(*) from monitoring.v_oracle_transactions where entry_date > Now() - interval '1 minute'
)
```

**Recent alerts** — _stat_
```sql
select 
    (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query  ILIKE ANY (ARRAY['%/*%*/%', '%--%']  )) as "comment_based_injections",
        (select count(*) from monitoring.active_transactions where  LAST_request_end_time > Now() - interval
    '1 minute' and query   ILIKE ANY (ARRAY['%OR 1=1%', '%AND 1=1%' , '%OR ''a''=''a%'''])) as "Boolean-based
    injections" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query  ILIKE ANY (ARRAY['%'' OR 1=1 --''%', '%"" OR 1=1 --%'])) as "tautology_with_comments" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query  ILIKE ANY (ARRAY['%UNION SELECT', '%UNION ALL SELECT%'])) as "union_based_injection" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query  ILIKE ANY (ARRAY['%; DROP TABLE users', '%; EXEC xp_cmdshell%'])) as "stacked_queries"
    ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%WAITFOR DELAY%', '%pg_sleep%','%SLEEP%'])) as "time_based_blind
    _injection"          ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%CONVERT%', '%CAST%'])) as "error_based_injection"           ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%information_schema.tables%',
    '%information_schema.columns%','%sys.tables%','%pg_catalog%'])) as "information_schema_probing"
    ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%'' OR ''=''%', '%'' OR ''x''=''x''%', '%admin''--%'])) as
    "Authentication bypass patterns" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%0x414243%', '%CHAR(65,66,67)%'])) as "encoding injection"  ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%xp_cmdshell%', '%sp_executesql%'])) as "shell_system_functions
    injection" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%ORDER BY 1%', '%ORDER BY%'])) as "ORDER BY_GROUP BY injection"
from monitoring.active_transactions
group by server
```

**Enabled sysadmin** — _table_
```sql
select * from monitoring.v_enabled_sysadmin  where $__timeFilter(entry_date)
```

**Connection number per user** — _barchart_
```sql
select sum(connection_count::int) , server ||'-'||login_name   from monitoring.connection_count
group by  server ||'-'||login_name
```

**Active threats** — _gauge_
```sql
select count(*) "suspicious queries" from monitoring.v_suspiscous
```


## GRC Access Review

**Open Review Instances** — _stat_
```sql
SELECT COUNT(*) FROM log.access_review_instances WHERE status='OPEN'
```

**Overdue Reviews** — _stat_
```sql
SELECT COUNT(*) FROM log.access_review_instances WHERE status='OPEN' AND period_end < NOW()
```

**Completed (90d)** — _stat_
```sql
SELECT COUNT(*) FROM log.access_review_instances WHERE status='COMPLETE' AND completed_at >= NOW()-INTERVAL
    '90 days'
```

**Active Cycles** — _stat_
```sql
SELECT COUNT(*) FROM config.access_review_cycles WHERE is_active=TRUE
```

**Reviews Opened vs Completed per Month** — _timeseries_
```sql
SELECT
  date_trunc('month', created_at) AS "time",
  SUM(CASE WHEN status IN ('OPEN','COMPLETE','CANCELLED') THEN 1 ELSE 0 END) AS "Opened",
  SUM(CASE WHEN status='COMPLETE' THEN 1 ELSE 0 END) AS "Completed"
FROM log.access_review_instances
WHERE $__timeFilter(created_at)
GROUP BY 1 ORDER BY 1
```

**Instances by Status** — _piechart_
```sql
SELECT status, COUNT(*) AS count
FROM log.access_review_instances
GROUP BY status
```

**Open Reviews by Cycle** — _barchart_
```sql
SELECT cycle_name, COUNT(*) AS open_instances
FROM log.access_review_instances
WHERE status='OPEN'
GROUP BY cycle_name ORDER BY open_instances DESC LIMIT 10
```

**Avg Days to Complete by Cycle** — _barchart_
```sql
SELECT cycle_name,
       ROUND(AVG(EXTRACT(EPOCH FROM (completed_at - created_at))/86400)::numeric, 1)
         AS avg_days
FROM log.access_review_instances
WHERE status='COMPLETE'
GROUP BY cycle_name ORDER BY avg_days DESC LIMIT 10
```

**Overdue Review Instances — Action Required** — _table_
```sql
sELECT i.instance_id,
         i.cycle_name,
         i.period_start,
         i.period_end,
         NOW()::date - i.period_end::date AS days_overdue,
         COALESCE(NULLIF(array_to_string(c.scope_regulations, ', '), ''), '—') AS regulation,
         i.created_at
  FROM log.access_review_instances i
  JOIN config.access_review_cycles c ON c.cycle_id = i.cycle_id
  WHERE i.status='OPEN' AND i.period_end < NOW()
  ORDER BY i.period_end ASC
  LIMIT 200
```

**All Open Review Instances** — _table_
```sql
SELECT i.instance_id,
         i.cycle_name,
         i.status,
         i.period_start,
         i.period_end,
         CASE WHEN i.period_end < NOW() THEN 'OVERDUE' ELSE 'ON-TIME' END AS deadline,
         COALESCE(NULLIF(array_to_string(c.scope_regulations, ', '), ''), '') AS regulation,
         i.created_at
  FROM log.access_review_instances i
  JOIN config.access_review_cycles c ON c.cycle_id = i.cycle_id
  WHERE i.status='OPEN'
  ORDER BY i.period_end ASC
  LIMIT 500
```

**Review Cycle Configuration** — _table_
```sql
SELECT cycle_id, cycle_name, frequency,
         next_cycle_due_at                                          AS next_run,
         COALESCE(NULLIF(array_to_string(scope_regulations, ', '), ''), '—') AS regulation,
         CASE WHEN is_active THEN 'Active' ELSE 'Inactive' END     AS status
  FROM config.access_review_cycles
  ORDER BY cycle_name
```


## GRC Audit Log

**ALERTED Events** — _stat_
```sql
SELECT COUNT(*) FROM log.firewall_audit_log
WHERE action_taken='ALERTED' AND $__timeFilter(event_time)
```

**BLOCKED Events** — _stat_
```sql
SELECT COUNT(*) FROM log.firewall_audit_log
WHERE action_taken='BLOCKED' AND $__timeFilter(event_time)
```

**MASKED Events** — _stat_
```sql
SELECT COUNT(*) FROM log.firewall_audit_log
WHERE action_taken='MASKED' AND $__timeFilter(event_time)
```

**Events per Hour by Action** — _timeseries_
```sql
SELECT
  date_trunc('hour', event_time) AS "time",
  SUM(CASE WHEN action_taken='BLOCKED' THEN 1 ELSE 0 END) AS "BLOCKED",
  SUM(CASE WHEN action_taken='ALERTED' THEN 1 ELSE 0 END) AS "ALERTED",
  SUM(CASE WHEN action_taken='MASKED'  THEN 1 ELSE 0 END) AS "MASKED",
  SUM(CASE WHEN action_taken='ALLOWED' THEN 1 ELSE 0 END) AS "ALLOWED"
FROM log.firewall_audit_log
WHERE $__timeFilter(event_time)
GROUP BY 1 ORDER BY 1
```

**Top Source IPs (BLOCKED)** — _barchart_
```sql
SELECT COALESCE(client_ip,'unknown') AS ip, COUNT(*) AS events
FROM log.firewall_audit_log
WHERE action_taken='BLOCKED' AND $__timeFilter(event_time)
GROUP BY client_ip ORDER BY events DESC LIMIT 10
```

**Top Users (BLOCKED)** — _barchart_
```sql
SELECT COALESCE(db_user,'unknown') AS db_user, COUNT(*) AS events
FROM log.firewall_audit_log
WHERE action_taken='BLOCKED' AND $__timeFilter(event_time)
GROUP BY db_user ORDER BY events DESC LIMIT 10
```

**Top Servers (all actions)** — _barchart_
```sql
SELECT COALESCE(server_name,'unknown') AS server, COUNT(*) AS events
FROM log.firewall_audit_log
WHERE $__timeFilter(event_time)
GROUP BY server_name ORDER BY events DESC LIMIT 10
```

**Audit Events** — _table_
```sql
SELECT a.event_time, a.server_name, a.db_user, a.client_ip, a.db_name,
       a.action_taken, a.risk_score, a.regulation,
       p.policy_name,
       left(a.sql_statement, 120) AS sql_statement
FROM log.firewall_audit_log a
LEFT JOIN config.firewall_policies p ON p.policy_id = a.matched_policy
WHERE $__timeFilter(a.event_time)
ORDER BY a.event_time DESC LIMIT 200
```


## GRC Compliance

**PCI-DSS Events** — _stat_
```sql
SELECT COUNT(*) FROM log.firewall_audit_log
WHERE regulation='PCI-DSS' AND $__timeFilter(event_time)
```

**HIPAA Events** — _stat_
```sql
SELECT COUNT(*) FROM log.firewall_audit_log
WHERE regulation='HIPAA' AND $__timeFilter(event_time)
```

**GDPR Events** — _stat_
```sql
SELECT COUNT(*) FROM log.firewall_audit_log
WHERE regulation='GDPR' AND $__timeFilter(event_time)
```

**SOC2 Events** — _stat_
```sql
SELECT COUNT(*) FROM log.firewall_audit_log
WHERE regulation='SOC2' AND $__timeFilter(event_time)
```

**Events by Regulation (hourly)** — _timeseries_
```sql
SELECT
  date_trunc('hour', event_time) AS "time",
  SUM(CASE WHEN regulation='PCI-DSS' THEN 1 ELSE 0 END) AS "PCI-DSS",
  SUM(CASE WHEN regulation='HIPAA'   THEN 1 ELSE 0 END) AS "HIPAA",
  SUM(CASE WHEN regulation='GDPR'    THEN 1 ELSE 0 END) AS "GDPR",
  SUM(CASE WHEN regulation='SOC2'    THEN 1 ELSE 0 END) AS "SOC2"
FROM log.firewall_audit_log
WHERE $__timeFilter(event_time) AND regulation IS NOT NULL
GROUP BY 1 ORDER BY 1
```

**Actions by Regulation** — _barchart_
```sql
SELECT regulation, COUNT(*) AS events
FROM log.firewall_audit_log
WHERE $__timeFilter(event_time) AND regulation IS NOT NULL
GROUP BY regulation ORDER BY events DESC
```

**Regulation Breach Events (BLOCKED / ALERTED)** — _table_
```sql
SELECT a.event_time, a.server_name, a.db_user, a.client_ip,
       a.action_taken, a.regulation, a.risk_score,
       p.policy_name
FROM log.firewall_audit_log a
LEFT JOIN config.firewall_policies p ON p.policy_id = a.matched_policy
WHERE a.action_taken IN ('BLOCKED','ALERTED')
  AND a.regulation IS NOT NULL
  AND $__timeFilter(a.event_time)
ORDER BY a.event_time DESC LIMIT 100
```

**Masking Coverage by Regulation** — _table_
```sql
SELECT regulation, COUNT(*) AS total_rules,
       SUM(CASE WHEN is_active THEN 1 ELSE 0 END) AS active_rules,
       array_to_string(array_agg(DISTINCT pii_type ORDER BY pii_type), ', ') AS pii_types
FROM config.masking_rules
WHERE regulation IS NOT NULL
GROUP BY regulation ORDER BY regulation
```

**Daily Audit Summary by Action** — _table_
```sql
SELECT DATE(event_time) AS report_date, action_taken,
       COUNT(*) AS event_count,
       COUNT(DISTINCT db_user) AS unique_users,
       COUNT(DISTINCT server_name) AS servers,
       MAX(risk_score) AS max_risk
FROM log.firewall_audit_log
WHERE $__timeFilter(event_time)
GROUP BY 1, 2 ORDER BY 1 DESC, event_count DESC
```


## GRC Control Attestation Workflow

**Pending Attestations** — _stat_
```sql
SELECT COUNT(*) FROM log.attestations WHERE attestation_status='PENDING'
```

**Exception Attestations** — _stat_
```sql
SELECT COUNT(*) FROM log.attestations WHERE attestation_status='EXCEPTION'
```

**Open Periods** — _stat_
```sql
SELECT COUNT(*) FROM config.attestation_periods WHERE status='OPEN'
```

**Completion Rate (Latest Period)** — _stat_
```sql
SELECT ROUND(100.0*SUM(CASE WHEN attestation_status!='PENDING' THEN 1 ELSE 0
    END)/NULLIF(COUNT(*),0)::numeric,1)
FROM log.attestations
WHERE period_id=(SELECT MAX(period_id) FROM log.attestations)
```

**Attestations Completed per Month** — _timeseries_
```sql
SELECT
  date_trunc('month', attested_at) AS "time",
  COUNT(*) AS attested
FROM log.attestations
WHERE attestation_status!='PENDING' AND $__timeFilter(attested_at)
GROUP BY 1 ORDER BY 1
```

**Attestation Status Distribution** — _piechart_
```sql
SELECT attestation_status AS status, COUNT(*) AS count
FROM log.attestations
GROUP BY attestation_status
```

**Pending by Regulation** — _barchart_
```sql
SELECT regulation, COUNT(*) AS pending
FROM log.attestations WHERE attestation_status='PENDING'
GROUP BY regulation ORDER BY pending DESC
```

**Completion Rate — SOC2** — _gauge_
```sql
SELECT ROUND(100.0*SUM(CASE WHEN attestation_status!='PENDING' THEN 1 ELSE 0
    END)/NULLIF(COUNT(*),0)::numeric,1)
FROM log.attestations WHERE regulation='SOC2'
```

**Completion Rate — SOX** — _gauge_
```sql
SELECT ROUND(100.0*SUM(CASE WHEN attestation_status!='PENDING' THEN 1 ELSE 0
    END)/NULLIF(COUNT(*),0)::numeric,1)
FROM log.attestations WHERE regulation='SOX'
```

**Completion Rate — PCI-DSS** — _gauge_
```sql
SELECT ROUND(100.0*SUM(CASE WHEN attestation_status!='PENDING' THEN 1 ELSE 0
    END)/NULLIF(COUNT(*),0)::numeric,1)
FROM log.attestations WHERE regulation='PCI-DSS'
```

**Completion Rate — GDPR** — _gauge_
```sql
SELECT ROUND(100.0*SUM(CASE WHEN attestation_status!='PENDING' THEN 1 ELSE 0
    END)/NULLIF(COUNT(*),0)::numeric,1)
FROM log.attestations WHERE regulation='GDPR'
```

**Pending Attestations — Action Required** — _table_
```sql
SELECT a.attestation_id, p.period_name, p.due_date,
       a.control_name, a.regulation,
       CASE WHEN p.due_date<CURRENT_DATE THEN 'OVERDUE' ELSE 'ON-TIME' END AS deadline,
       a.created_at
FROM log.attestations a
JOIN config.attestation_periods p ON p.period_id=a.period_id
WHERE a.attestation_status='PENDING'
ORDER BY p.due_date ASC, a.regulation, a.control_name
LIMIT 500
```

**Attestation Exceptions** — _table_
```sql
SELECT a.attestation_id, p.period_name, a.control_name, a.regulation,
       a.attested_by, a.attested_at, a.exception_description
FROM log.attestations a
JOIN config.attestation_periods p ON p.period_id=a.period_id
WHERE a.attestation_status='EXCEPTION'
ORDER BY a.attested_at DESC LIMIT 200
```


## GRC Cross-Border Transfer Tracking

**Transfers Detected (30d)** — _stat_
```sql
SELECT COUNT(*) FROM log.cross_border_transfers WHERE detected_at>=NOW()-INTERVAL '30 days'
```

**Without Legal Basis (30d)** — _stat_
```sql
SELECT COUNT(*) FROM log.cross_border_transfers WHERE has_legal_basis=FALSE AND detected_at>=NOW()-INTERVAL
    '30 days'
```

**Critical Risk Transfers** — _stat_
```sql
SELECT COUNT(*) FROM log.cross_border_transfers WHERE risk_level='CRITICAL' AND detected_at>=NOW()-INTERVAL
    '30 days'
```

**Server Regions Configured** — _stat_
```sql
SELECT COUNT(*) FROM config.data_regions
```

**Cross-Border Transfers per Day** — _timeseries_
```sql
SELECT
  date_trunc('day', detected_at) AS "time",
  SUM(CASE WHEN has_legal_basis THEN 1 ELSE 0 END) AS "With Legal Basis",
  SUM(CASE WHEN NOT has_legal_basis THEN 1 ELSE 0 END) AS "No Legal Basis"
FROM log.cross_border_transfers
WHERE $__timeFilter(detected_at)
GROUP BY 1 ORDER BY 1
```

**Transfer Mechanisms Used** — _piechart_
```sql
SELECT COALESCE(transfer_mechanism,'NONE') AS mechanism, COUNT(*) AS transfers
FROM log.cross_border_transfers
WHERE detected_at>=NOW()-INTERVAL '30 days'
GROUP BY mechanism
```

**Transfers by Destination Country (30d)** — _barchart_
```sql
SELECT COALESCE(destination_country,'Unknown') AS country, COUNT(*) AS transfers
FROM log.cross_border_transfers
WHERE detected_at>=NOW()-INTERVAL '30 days'
GROUP BY country ORDER BY transfers DESC LIMIT 10
```

**Transfer Agreements** — _table_
```sql
SELECT source_server, destination_server, agreement_type,
       valid_from, valid_until
FROM config.transfer_agreements
ORDER BY source_server, destination_server
```

**Transfers Without Legal Basis — Action Required** — _table_
```sql
SELECT transfer_id, source_server, destination_server,
       source_country, destination_country,
       transfer_mechanism, db_user, risk_level, detected_at
FROM log.cross_border_transfers
WHERE has_legal_basis=FALSE
ORDER BY detected_at DESC LIMIT 200
```

**Server Region Registry** — _table_
```sql
SELECT server_name, country_code, country_name,
       data_residency_zone,
       CASE WHEN is_adequate THEN 'YES' ELSE 'NO' END AS adequate
FROM config.data_regions ORDER BY data_residency_zone, server_name
```


## GRC Immutable Audit Hash Chain

**Total Rows Hashed** — _stat_
```sql
SELECT COUNT(*) FROM log.firewall_audit_log WHERE regulation is not null
```

**Rows Pending Hash** — _stat_
```sql
SELECT COUNT(*) FROM log.firewall_audit_log WHERE regulation IS NULL
```

**Last Verification Result** — _stat_
```sql
SELECT CASE WHEN is_valid THEN 1 ELSE 0 END FROM log.hash_chain_checkpoints ORDER BY verified_at DESC LIMIT 1
```

**Verifications Run** — _stat_
```sql
SELECT COUNT(*) FROM log.hash_chain_checkpoints
```

**Recent Audit Log — Hash Status** — _table_
```sql
SELECT audit_id, event_time, server_name, db_user, action_taken,
       LEFT(row_hash,24)||'…' AS row_hash,
       CASE WHEN row_hash IS NOT NULL THEN 'HASHED' ELSE 'PENDING' END AS status
FROM log.firewall_audit_log
ORDER BY audit_id DESC LIMIT 200
```

**Rows Hashed per Hour** — _timeseries_
```sql
SELECT
  date_trunc('hour', event_time) AS "time",
  COUNT(*) AS rows_hashed
FROM log.firewall_audit_log
WHERE row_hash IS NOT NULL AND $__timeFilter(event_time)
GROUP BY 1 ORDER BY 1
```

**Verification Results (Last 30)** — _barchart_
```sql
SELECT
  CASE WHEN is_valid THEN 'VALID' ELSE 'INVALID' END AS result,
  COUNT(*) AS count
FROM log.hash_chain_checkpoints
group by is_valid , verified_at
ORDER BY verified_at DESC
LIMIT 30
```

**Hash Chain Verification Checkpoints** — _table_
```sql
SELECT checkpoint_id, verified_at, rows_hashed, last_hashed_id,
       LEFT(last_hash,24)||'…' AS chain_tip,
       CASE WHEN is_valid THEN 'VALID' ELSE 'INVALID' END AS result,
       broken_at_id, error_detail
FROM log.hash_chain_checkpoints
ORDER BY verified_at DESC LIMIT 100
```


## GRC Incident Lifecycle Management

**Active Incidents** — _stat_
```sql
SELECT COUNT(*) FROM log.incidents WHERE state NOT IN ('CLOSED')
```

**Critical Active** — _stat_
```sql
SELECT COUNT(*) FROM log.incidents WHERE severity='CRITICAL' AND state NOT IN ('CLOSED')
```

**GDPR 72h Overdue** — _stat_
```sql
SELECT COUNT(*) FROM log.incidents WHERE involves_personal_data=TRUE AND gdpr_notification_due<NOW() AND
    gdpr_notified_at IS NULL AND state!='CLOSED'
```

**CAPA Actions Open** — _stat_
```sql
SELECT COUNT(*) FROM log.incident_capa WHERE status='OPEN'
```

**Incidents per Week by Severity** — _timeseries_
```sql
SELECT
  date_trunc('week', detected_at) AS "time",
  SUM(CASE WHEN severity='CRITICAL' THEN 1 ELSE 0 END) AS "CRITICAL",
  SUM(CASE WHEN severity='HIGH'     THEN 1 ELSE 0 END) AS "HIGH",
  SUM(CASE WHEN severity='MEDIUM'   THEN 1 ELSE 0 END) AS "MEDIUM",
  SUM(CASE WHEN severity='LOW'      THEN 1 ELSE 0 END) AS "LOW"
FROM log.incidents
WHERE $__timeFilter(detected_at)
GROUP BY 1 ORDER BY 1
```

**Incidents by State** — _piechart_
```sql
SELECT state, COUNT(*) AS incidents FROM log.incidents GROUP BY state
```

**Incidents by Category (90d)** — _barchart_
```sql
SELECT COALESCE(category,'other') AS category, COUNT(*) AS incidents
FROM log.incidents
WHERE detected_at>=NOW()-INTERVAL '90 days'
GROUP BY category ORDER BY incidents DESC
```

**Avg Resolution Time by Severity (h)** — _barchart_
```sql
SELECT severity,
       ROUND(AVG(EXTRACT(EPOCH FROM (closed_at-detected_at))/3600)::numeric,1) AS avg_hours
FROM log.incidents
WHERE state='CLOSED' AND closed_at IS NOT NULL
GROUP BY severity ORDER BY avg_hours DESC
```

**GDPR Breach Notifications** — _table_
```sql
SELECT incident_id, title, severity,
       detected_at, gdpr_notification_due,
       CASE WHEN gdpr_notified_at IS NOT NULL THEN 'NOTIFIED'
            WHEN gdpr_notification_due<NOW()  THEN 'OVERDUE'
            ELSE 'PENDING' END AS gdpr_status,
       gdpr_notified_at
FROM log.incidents
WHERE involves_personal_data=TRUE
ORDER BY gdpr_notification_due ASC NULLS LAST
LIMIT 100
```

**Active Incidents** — _table_
```sql
SELECT incident_id, title, severity, state, category,
       detected_at, assigned_to,
       CASE WHEN involves_personal_data THEN 'YES' ELSE '' END AS gdpr
FROM log.incidents
WHERE state NOT IN ('CLOSED')
ORDER BY CASE severity WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2
         WHEN 'MEDIUM' THEN 3 ELSE 4 END, detected_at DESC
LIMIT 200
```

**Open CAPA Actions** — _table_
```sql
SELECT c.capa_id, c.incident_id, i.title AS incident_title,
       c.capa_type, c.description, c.assigned_to, c.due_date,
       c.status,
       CASE WHEN c.due_date<CURRENT_DATE THEN 'OVERDUE' ELSE '' END AS deadline
FROM log.incident_capa c
JOIN log.incidents i ON i.incident_id=c.incident_id
WHERE c.status IN ('OPEN','IN_PROGRESS')
ORDER BY c.due_date ASC NULLS LAST
LIMIT 200
```


## GRC Masking Coverage

**Active Masking Rules** — _stat_
```sql
SELECT COUNT(*) FROM config.masking_rules WHERE is_active=TRUE
```

**Sensitive Columns (total)** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.sensitive_schema
```

**Unmasked Sensitive Columns** — _stat_
```sql
SELECT COUNT(*) FROM config.v_unmasked_sensitive_columns
```

**Token Vault Entries** — _stat_
```sql
SELECT COUNT(*) FROM config.masking_tokens
```

**Rules by Mask Type** — _piechart_
```sql
SELECT mask_type, COUNT(*) AS rules
FROM config.masking_rules WHERE is_active=TRUE
GROUP BY mask_type ORDER BY rules DESC
```

**Rules by PII Type** — _piechart_
```sql
SELECT pii_type, COUNT(*) AS rules
FROM config.masking_rules WHERE is_active=TRUE
GROUP BY pii_type ORDER BY rules DESC
```

**Active Rules by Regulation** — _barchart_
```sql
SELECT COALESCE(regulation,'unclassified') AS regulation,
       COUNT(*) AS active_rules
FROM config.masking_rules WHERE is_active=TRUE
GROUP BY regulation ORDER BY active_rules DESC
```

**Unmasked Sensitive Columns (Risk Gap)** — _table_
```sql
SELECT server, database_name, table_name, column_name,
       pii_type, data_type
FROM config.v_unmasked_sensitive_columns
ORDER BY server, table_name
```

**Active Masking Rules** — _table_
```sql
SELECT server_name, table_name, column_name,
       pii_type, mask_type, regulation,
       array_to_string(allowed_roles, ', ') AS bypass_roles,
       updated_at
FROM config.v_masking_rules_detail
WHERE is_active=TRUE
ORDER BY server_name, table_name, column_name
```

**Masking Coverage Summary** — _table_
```sql
SELECT server_name, regulation, total_sensitive_columns,
       actively_masked,
       array_to_string(pii_types_covered, ', ') AS pii_types
FROM config.v_masking_coverage
ORDER BY server_name, regulation
```


## GRC Overview

**BLOCKED (24h)** — _stat_
```sql
SELECT COUNT(*) FROM log.firewall_audit_log WHERE action_taken='BLOCKED' AND event_time >= NOW()-INTERVAL '24
    hours'
```

**ALERTED (24h)** — _stat_
```sql
SELECT COUNT(*) FROM log.firewall_audit_log WHERE action_taken='ALERTED' AND event_time >= NOW()-INTERVAL '24
    hours'
```

**Open Incidents** — _stat_
```sql
SELECT COUNT(*) FROM log.security_incidents WHERE status IN ('OPEN','ACKNOWLEDGED')
```

**High-Risk Users (≥70)** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.user_risk_profiles WHERE risk_score >= 70
```

**Active Blocked IPs** — _stat_
```sql
SELECT COUNT(*) FROM config.blocked_ips WHERE is_active=TRUE AND (expires_at IS NULL OR expires_at > NOW())
```

**Active Masking Rules** — _stat_
```sql
SELECT COUNT(*) FROM config.masking_rules WHERE is_active=TRUE
```

**Top Servers by Events (24h)** — _barchart_
```sql
SELECT server_name, COUNT(*) AS events
FROM log.firewall_audit_log
WHERE event_time >= NOW()-INTERVAL '24 hours'
GROUP BY server_name ORDER BY events DESC LIMIT 10
```

**Firewall Events by Action (hourly)** — _timeseries_
```sql
SELECT
  date_trunc('hour', event_time) AS "time",
  SUM(CASE WHEN action_taken='BLOCKED' THEN 1 ELSE 0 END) AS "BLOCKED",
  SUM(CASE WHEN action_taken='ALERTED' THEN 1 ELSE 0 END) AS "ALERTED",
  SUM(CASE WHEN action_taken='MASKED'  THEN 1 ELSE 0 END) AS "MASKED",
  SUM(CASE WHEN action_taken='ALLOWED' THEN 1 ELSE 0 END) AS "ALLOWED"
FROM log.firewall_audit_log
WHERE $__timeFilter(event_time)
GROUP BY 1 ORDER BY 1
```

**Recent BLOCKED / CRITICAL Events** — _table_
```sql
SELECT a.event_time, a.server_name, a.db_user, a.client_ip,
       a.action_taken, a.risk_score, a.regulation,
       p.policy_name
FROM log.firewall_audit_log a
LEFT JOIN config.firewall_policies p ON p.policy_id = a.matched_policy
WHERE a.action_taken IN ('BLOCKED','ALERTED')
  AND a.risk_score >= 70
  AND $__timeFilter(a.event_time)
ORDER BY a.event_time DESC LIMIT 50
```

**Exceptions Pending Approval** — _stat_
```sql
SELECT COUNT(*) FROM config.policy_exceptions WHERE approval_status='PENDING'
```

**Overdue Access Reviews** — _stat_
```sql
SELECT COUNT(*) FROM log.access_review_instances WHERE status='OPEN' AND period_end < NOW()
```

**Open Critical Incidents** — _stat_
```sql
SELECT COUNT(*) FROM log.incidents WHERE severity='CRITICAL' AND state NOT IN ('CLOSED')
```

**GDPR 72h Overdue** — _stat_
```sql
SELECT COUNT(*) FROM log.incidents WHERE involves_personal_data=TRUE AND gdpr_notification_due<NOW() AND
    gdpr_notified_at IS NULL AND state!='CLOSED'
```

**Pending Attestations** — _stat_
```sql
SELECT COUNT(*) FROM log.attestations WHERE attestation_status='PENDING'
```

**Transfers Without Legal Basis** — _stat_
```sql
SELECT COUNT(*) FROM log.cross_border_transfers WHERE has_legal_basis=FALSE AND detected_at>=NOW()-INTERVAL
    '30 days'
```

**Hash Chain Valid** — _stat_
```sql
SELECT CASE WHEN COUNT(*)=0 THEN 0 WHEN bool_and(is_valid) THEN 1 ELSE 0 END FROM log.hash_chain_checkpoints
    WHERE verified_at>=NOW()-INTERVAL '24 hours'
```


## GRC Policy Exceptions

**Pending Approval** — _stat_
```sql
SELECT COUNT(*) FROM config.policy_exceptions WHERE approval_status='PENDING'
```

**Active Approved Exceptions** — _stat_
```sql
SELECT COUNT(*) FROM config.v_active_policy_exceptions
```

**Expiring in <7 Days** — _stat_
```sql
SELECT COUNT(*) FROM config.policy_exceptions WHERE approval_status='APPROVED' AND expires_at BETWEEN NOW()
    AND NOW()+INTERVAL '7 days'
```

**Rejected (30d)** — _stat_
```sql
SELECT COUNT(*) FROM config.policy_exceptions WHERE approval_status='REJECTED' AND created_at >=
    NOW()-INTERVAL '30 days'
```

**Exception Requests per Day** — _timeseries_
```sql
SELECT
  date_trunc('day', created_at) AS "time",
  SUM(CASE WHEN approval_status='APPROVED' THEN 1 ELSE 0 END) AS "Approved",
  SUM(CASE WHEN approval_status='PENDING'  THEN 1 ELSE 0 END) AS "Pending",
  SUM(CASE WHEN approval_status='REJECTED' THEN 1 ELSE 0 END) AS "Rejected"
FROM config.policy_exceptions
WHERE $__timeFilter(created_at)
GROUP BY 1 ORDER BY 1
```

**Exceptions by Status** — _piechart_
```sql
SELECT approval_status, COUNT(*) AS count
FROM config.policy_exceptions
GROUP BY approval_status
```

**Active Exceptions by Regulation** — _barchart_
```sql
SELECT COALESCE(regulation,'—') AS regulation, COUNT(*) AS count
FROM config.policy_exceptions
WHERE approval_status='APPROVED'
  AND (expires_at IS NULL OR expires_at > NOW())
GROUP BY regulation ORDER BY count DESC
```

**Exceptions by Server** — _barchart_
```sql
SELECT COALESCE(server_name,'any') AS server_name, COUNT(*) AS count
FROM config.policy_exceptions
WHERE approval_status='APPROVED'
  AND (expires_at IS NULL OR expires_at > NOW())
GROUP BY server_name ORDER BY count DESC LIMIT 10
```

**Top Requestors (90d)** — _barchart_
```sql
SELECT created_by, COUNT(*) AS requests
FROM config.policy_exceptions
WHERE created_at >= NOW()-INTERVAL '90 days'
GROUP BY created_by ORDER BY requests DESC LIMIT 10
```

**Pending Approval — Action Required** — _table_
```sql
SELECT exception_id,
       COALESCE(p.policy_name,'—') AS policy,
       COALESCE(e.server_name,'any') AS server,
       COALESCE(e.db_user,'any') AS db_user,
       COALESCE(e.client_ip_cidr,'any') AS client_ip_cidr,
       COALESCE(e.regulation,'—') AS regulation,
       e.reason,
       e.created_by,
       e.created_at,
       e.expires_at
FROM config.policy_exceptions e
LEFT JOIN config.firewall_policies p ON p.policy_id = e.policy_id
WHERE e.approval_status='PENDING'
ORDER BY e.created_at ASC
LIMIT 200
```

**Active Approved Exceptions** — _table_
```sql
SELECT e.exception_id,
       COALESCE(p.policy_name,'—') AS policy,
       COALESCE(e.server_name,'any') AS server,
       COALESCE(e.db_user,'any') AS db_user,
       COALESCE(e.client_ip_cidr,'any') AS client_ip_cidr,
       COALESCE(e.regulation,'—') AS regulation,
       e.approved_by,
       e.approved_at,
       e.expires_at
FROM config.v_active_policy_exceptions e
LEFT JOIN config.firewall_policies p ON p.policy_id = e.policy_id
ORDER BY e.expires_at ASC NULLS LAST
LIMIT 200
```

**Exception History (All)** — _table_
```sql
SELECT e.exception_id,
       COALESCE(p.policy_name,'—') AS policy,
       COALESCE(e.server_name,'any') AS server,
       COALESCE(e.db_user,'any') AS db_user,
       e.approval_status,
       COALESCE(e.regulation,'—') AS regulation,
       e.created_by,
       e.created_at,
       e.approved_by,
       e.approved_at,
       e.expires_at
FROM config.policy_exceptions e
LEFT JOIN config.firewall_policies p ON p.policy_id = e.policy_id
ORDER BY e.created_at DESC LIMIT 500
```


## GRC Risk Register

**Open Risks** — _stat_
```sql
SELECT COUNT(*) FROM config.risk_register WHERE status='OPEN'
```

**Critical / High Risks (Score ≥15)** — _stat_
```sql
SELECT COUNT(*) FROM config.risk_register WHERE inherent_risk_score>=15 AND status NOT IN
    ('CLOSED','ACCEPTED')
```

**In Treatment** — _stat_
```sql
SELECT COUNT(*) FROM config.risk_register WHERE status='IN_TREATMENT'
```

**Avg Residual Risk Score** — _stat_
```sql
SELECT ROUND(AVG(residual_risk_score)::numeric,1) FROM config.risk_register WHERE status NOT IN ('CLOSED')
```

**Risks by Inherent Score Bucket** — _barchart_
```sql
SELECT
  CASE WHEN inherent_risk_score>=20 THEN 'Critical (20-25)'
       WHEN inherent_risk_score>=15 THEN 'High (15-19)'
       WHEN inherent_risk_score>=10 THEN 'Medium (10-14)'
       WHEN inherent_risk_score>=5  THEN 'Low (5-9)'
       ELSE 'Minimal (<5)' END AS bucket,
  COUNT(*) AS risks
FROM config.risk_register WHERE status NOT IN ('CLOSED')
GROUP BY bucket ORDER BY MIN(inherent_risk_score) DESC
```

**Risks by Category** — _barchart_
```sql
SELECT COALESCE(risk_category,'other') AS category,
       COUNT(*) AS risks
FROM config.risk_register WHERE status NOT IN ('CLOSED')
GROUP BY category ORDER BY risks DESC
```

**Risks by Treatment Strategy** — _piechart_
```sql
SELECT COALESCE(treatment_strategy,'NONE') AS strategy, COUNT(*) AS risks
FROM config.risk_register WHERE status NOT IN ('CLOSED')
GROUP BY strategy
```

**Top Assets by Residual Risk Score** — _barchart_
```sql
SELECT asset_name,
       ROUND(SUM(residual_risk_score)::numeric,1) AS total_residual
FROM config.risk_register WHERE status NOT IN ('CLOSED')
GROUP BY asset_name ORDER BY total_residual DESC LIMIT 10
```

**Risks by Regulation** — _barchart_
```sql
SELECT UNNEST(COALESCE(regulation,ARRAY['—'])) AS reg,
       COUNT(*) AS risks
FROM config.risk_register WHERE status NOT IN ('CLOSED')
GROUP BY reg ORDER BY risks DESC
```

**Risk Register** — _table_
```sql
SELECT risk_id, asset_name, risk_title, risk_category,
       likelihood, impact, inherent_risk_score,
       control_effectiveness AS ctrl_eff,
       ROUND(residual_risk_score::numeric,1) AS residual,
       treatment_strategy, risk_owner, status, review_date
FROM config.risk_register
ORDER BY inherent_risk_score DESC NULLS LAST, risk_id
LIMIT 500
```


## GRC Risk Scoring

**High-Risk Users (≥70)** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.user_risk_profiles WHERE risk_score >= 70
```

**Critical-Risk Users (≥90)** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.user_risk_profiles WHERE risk_score >= 90
```

**Average Risk Score** — _gauge_
```sql
SELECT AVG(risk_score)::int AS value FROM monitoring.user_risk_profiles
```

**Monitored Users** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.user_risk_profiles
```

**Risk Score Trend (events)** — _timeseries_
```sql
SELECT
  date_trunc('hour', event_time) AS "time",
  AVG(risk_score)::int AS "avg_score",
  MAX(risk_score) AS "max_score"
FROM monitoring.user_risk_events
WHERE $__timeFilter(event_time)
GROUP BY 1 ORDER BY 1
```

**Users by Risk Band** — _barchart_
```sql
SELECT
  CASE
    WHEN risk_score >= 90 THEN '90-100 Critical'
    WHEN risk_score >= 70 THEN '70-89 High'
    WHEN risk_score >= 40 THEN '40-69 Medium'
    ELSE '0-39 Low'
  END AS risk_band,
  COUNT(*) AS users
FROM monitoring.user_risk_profiles
GROUP BY risk_band ORDER BY risk_band DESC
```

**Top 30 High-Risk Users** — _table_
```sql
SELECT server_name,  risk_score,
       consecutive_high_risk,
       ROUND(avg_queries_per_hour::numeric, 1) AS avg_qph,
       ROUND(avg_duration_secs::numeric, 2) AS avg_dur_s,
       CASE WHEN typical_hour_start IS NOT NULL
            THEN typical_hour_start::text||':00-'||typical_hour_end::text||':00'
            ELSE '—' END AS typical_hours,
       last_updated
FROM monitoring.user_risk_profiles
ORDER BY risk_score DESC
LIMIT 30
```

**Recent Risk Events** — _table_
```sql
SELECT event_time, server_name,  risk_score, risk_factors
FROM monitoring.user_risk_events
WHERE $__timeFilter(event_time)
ORDER BY event_time DESC LIMIT 100
```


## GRC Threat Response

**Response Success Rate (%)** — _gauge_
```sql
SELECT CASE WHEN COUNT(*)=0 THEN 100
            ELSE ROUND(100.0*SUM(CASE WHEN success THEN 1 ELSE 0 END)/COUNT(*), 1)
       END AS value
FROM log.threat_response_log
WHERE triggered_at >= NOW()-INTERVAL '24 hours'
```

**Open Incidents** — _stat_
```sql
SELECT COUNT(*) FROM log.security_incidents WHERE status IN ('OPEN','ACKNOWLEDGED')
```

**Blocked IPs (active)** — _stat_
```sql
SELECT COUNT(*) FROM config.blocked_ips WHERE is_active=TRUE AND (expires_at IS NULL OR expires_at > NOW())
```

**Suspended Users (active)** — _stat_
```sql
SELECT COUNT(*) FROM config.suspended_users WHERE is_active=TRUE AND (expires_at IS NULL OR expires_at >
    NOW())
```

**Responses (24h)** — _stat_
```sql
SELECT COUNT(*) FROM log.threat_response_log WHERE triggered_at >= NOW()-INTERVAL '24 hours'
```

**Active Suspended Users** — _table_
```sql
SELECT server_name, login_name, reason, suspended_by, suspended_at, expires_at, remaining
FROM config.v_suspended_users_active
ORDER BY suspended_at DESC
```

**Automated Responses per Hour** — _timeseries_
```sql
SELECT
  date_trunc('hour', triggered_at) AS "time",
  SUM(CASE WHEN response_type='BLOCK_IP'     THEN 1 ELSE 0 END) AS "BLOCK_IP",
  SUM(CASE WHEN response_type='SUSPEND_USER' THEN 1 ELSE 0 END) AS "SUSPEND_USER",
  SUM(CASE WHEN response_type='NOTIFY'       THEN 1 ELSE 0 END) AS "NOTIFY",
  SUM(CASE WHEN response_type='ESCALATE'     THEN 1 ELSE 0 END) AS "ESCALATE",
  SUM(CASE WHEN response_type='WEBHOOK'      THEN 1 ELSE 0 END) AS "WEBHOOK"
FROM log.threat_response_log
WHERE $__timeFilter(triggered_at)
GROUP BY 1 ORDER BY 1
```

**Open Security Incidents** — _table_
```sql
SELECT incident_id, title, severity, regulation,
       server_name, db_user, client_ip, status, created_at
FROM log.v_active_threats
ORDER BY CASE severity WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 ELSE 3 END,
         created_at DESC
```

**Recent Automated Responses** — _table_
```sql
SELECT triggered_at, playbook_name, trigger_type, subject,
       response_type,
       CASE WHEN success THEN 'OK' ELSE 'FAILED' END AS result,
       COALESCE(error_message, (response_detail->>'detail')::text, '') AS detail
FROM log.threat_response_log
WHERE $__timeFilter(triggered_at)
ORDER BY triggered_at DESC LIMIT 50
```

**Active Blocked IPs** — _table_
```sql
SELECT ip_address, reason, blocked_by, blocked_at, expires_at, remaining
FROM config.v_blocked_ips_active
ORDER BY blocked_at DESC
```

**Active Response Playbooks** — _table_
```sql
SELECT playbook_name, trigger_type, trigger_threshold,
       COALESCE(trigger_regulation,'any') AS regulation,
       response_type, cooldown_mins
FROM config.threat_response_playbooks
WHERE is_active=TRUE
ORDER BY playbook_id
```


## GRC Workflow Segregation of Duties

**SoD Violations (30d)** — _stat_
```sql
SELECT COUNT(*) FROM log.sod_violations WHERE detected_at>=NOW()-INTERVAL '30 days'
```

**Violations This Week** — _stat_
```sql
SELECT COUNT(*) FROM log.sod_violations WHERE detected_at>=NOW()-INTERVAL '7 days'
```

**Active SoD Rules** — _stat_
```sql
SELECT COUNT(*) FROM config.sod_rules WHERE is_active=TRUE
```

**Unique Violators (30d)** — _stat_
```sql
SELECT 
COUNT(DISTINCT acknowledged_by) 

FROM log.sod_violations WHERE detected_at>=NOW()-INTERVAL '30 days'
```

**Workflow SoD Violations per Day** — _timeseries_
```sql
SELECT
  date_trunc('day', detected_at) AS "time",
  COUNT(*) AS violations
FROM log.sod_violations
WHERE $__timeFilter(detected_at)
GROUP BY 1 ORDER BY 1
```

**Violations by Action Type (30d)** — _barchart_
```sql
SELECT rule_name, COUNT(*) AS violations
FROM log.sod_violations
WHERE detected_at>=NOW()-INTERVAL '30 days'
GROUP BY rule_name ORDER BY violations DESC
```

**Top Violators (30d)** — _barchart_
```sql
--SELECT COUNT(*) FROM log.sod_violations WHERE detected_at>=NOW()-INTERVAL '30 days'
SELECT acknowledged_by, COUNT(*) AS attempts
FROM log.sod_violations
WHERE detected_at>=NOW()-INTERVAL '30 days'
GROUP BY acknowledged_by ORDER BY attempts DESC LIMIT 10
```

**SoD Rule Configuration** — _table_
```sql
SELECT rule_id, rule_name, description,
       CASE WHEN is_active THEN 'Active' ELSE 'Disabled' END AS status
FROM config.sod_rules ORDER BY rule_id
```

**Workflow SoD Violation Log (30d)** — _table_
```sql
SELECT v.detected_at, v.rule_name, v.attempted_by,
       v.resource_id, v.resource_owner, v.violation_reason
FROM log.sod_violations v
WHERE v.acknowledged_at>=NOW()-INTERVAL '30 days'
ORDER BY v.detected_at DESC LIMIT 300
```


## IPS Dashboard - FortiAnalyzer

**Total Events** — _stat_
```sql
SELECT COALESCE(count(*),0) AS "Total Events" FROM alerts.alert_log where $__timeFilter(entry_date)
```

**Critical** — _stat_
```sql
SELECT count(*) FROM alerts.alert_log WHERE risk_level ='critical' and $__timeFilter(entry_date)
```

**High** — _stat_
```sql
SELECT count(*) FROM alerts.alert_log WHERE risk_level ='high' and $__timeFilter(entry_date)
```

**Medium** — _stat_
```sql
SELECT count(*) FROM alerts.alert_log WHERE risk_level ='medium' and $__timeFilter(entry_date)
```

**Blocked** — _stat_
```sql
SELECT COALESCE(SUM(count),0) AS "Blocked" FROM siem.fortianalyzer_ips_events WHERE action='blocked'
```

**Monitored** — _stat_
```sql
select count(*) from alerts.mail_alert_log where recipients is not null and  $__timeFilter(entry_date)
```

**Intrusions by Severity** — _piechart_
```sql
SELECT risk_level AS "Severity", count(*) AS "Count" FROM alerts.alert_log  GROUP BY risk_level ORDER BY CASE
    risk_level WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 ELSE 5 END
```

**Intrusions by Type** — _barchart_
```sql
select RC.issue_name as "Type"  , count(*)  AS "Count" from alerts.alert_log al 
join rootcause.v_rootcauses rc on rc.root_cause_id = al.root_cause_id
where $__timeFilter(entry_date) 
group by al.root_cause_id , issue_name 
order by count(*) desc limit 20
```

**Intrusion Events Timeline (Last 7 Days)** — _timeseries_
```sql
SELECT 
    date_trunc('hour', entry_date)::timestamp AS "time" ,
	COUNT(*) AS "count",
    risk_level AS severity
FROM alerts.alert_log
where $__timeFilter(entry_date) 
GROUP BY 
    risk_level,
    date_trunc('hour', entry_date)
ORDER BY 
    time;
```

**Monitored Intrusions** — _table_
```sql
SELECT root_cause_name AS "Attack", issue_name AS "Type",  count(*) AS "Count" 
FROM alerts.alert_log  al
join rootcause.v_rootcauses rc on rc.root_cause_id  = al.root_cause_id 
where $__timeFilter(entry_date) 
group by root_cause_name , issue_name
```

**Top Victims** — _table_
```sql
SELECT server , root_cause_name AS "Attack", issue_name AS "Type",  count(*) AS "Count" 
FROM alerts.mail_alert_log  al
join rootcause.v_rootcauses rc on rc.root_cause_id  = al.metric_name
group by root_cause_name , issue_name ,server
```

**Blocked Intrusions** — _table_
```sql
SELECT root_cause_name AS "Attack", issue_name AS "Type", risk_level AS "Severity", count(*) AS "Count" 
FROM alerts.mail_alert_log ma
join rootcause.v_rootcauses rc on rc.root_cause_id  = ma.metric_name
where $__timeFilter(entry_date) 
group by root_cause_name , issue_name ,risk_level
ORDER BY CASE risk_level WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END DESC LIMIT
    20
```

**Top Attack Sources** — _table_
```sql
SELECT 	
        count(*) *100 /         (select count(*) from alerts.alert_log al1 where $__timeFilter(al1.entry_date)
    ) pct_of_total ,
	gmmr.metric_metadata , 
	risk_level 
	 FROM alerts.alert_log al
         join monitoring.general_metric_metadata_results gmmr on gmmr.server = al.server and al.root_cause_id
    = gmmr.metric_name and al.entry_date between gmmr.entry_date -interval '1 second' and gmmr.entry_date
    +interval '1 second'
   where $__timeFilter(al.entry_date) 
	group by risk_level , metric_metadata
	order by pct_of_total desc
```


## Linked servers  / DBLINKS - Hidden credentials

**Linked server / DBLINKS Hidden credentials** — _gauge_
```sql
select count(*) "Number of hidden credentials", server  from monitoring.linked_servers_hidden_credentials
group by server
```

**(untitled panel)** — _table_
```sql
select distinct server from monitoring.linked_servers_hidden_credentials
```

**Active users** — _bargauge_
```sql
select sum("Number of connections") from 
(
select count(*) "Number of connections" from monitoring.tcp_connections where connect_time between Now() -
    interval '1 minute' and Now()
union all
select count(*) from monitoring.v_oracle_transactions where entry_date > Now() - interval '1 minute'
)
```

**Recent alerts** — _stat_
```sql
select 
    (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query  ILIKE ANY (ARRAY['%/*%*/%', '%--%']  )) as "comment_based_injections",
        (select count(*) from monitoring.active_transactions where  LAST_request_end_time > Now() - interval
    '1 minute' and query   ILIKE ANY (ARRAY['%OR 1=1%', '%AND 1=1%' , '%OR ''a''=''a%'''])) as "Boolean-based
    injections" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query  ILIKE ANY (ARRAY['%'' OR 1=1 --''%', '%"" OR 1=1 --%'])) as "tautology_with_comments" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query  ILIKE ANY (ARRAY['%UNION SELECT', '%UNION ALL SELECT%'])) as "union_based_injection" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query  ILIKE ANY (ARRAY['%; DROP TABLE users', '%; EXEC xp_cmdshell%'])) as "stacked_queries"
    ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%WAITFOR DELAY%', '%pg_sleep%','%SLEEP%'])) as "time_based_blind
    _injection"          ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%CONVERT%', '%CAST%'])) as "error_based_injection"           ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%information_schema.tables%',
    '%information_schema.columns%','%sys.tables%','%pg_catalog%'])) as "information_schema_probing"
    ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%'' OR ''=''%', '%'' OR ''x''=''x''%', '%admin''--%'])) as
    "Authentication bypass patterns" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%0x414243%', '%CHAR(65,66,67)%'])) as "encoding injection"  ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%xp_cmdshell%', '%sp_executesql%'])) as "shell_system_functions
    injection" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%ORDER BY 1%', '%ORDER BY%'])) as "ORDER BY_GROUP BY injection"
from monitoring.active_transactions
group by server
```

**Linked server / DBLINKS Hidden credentials** — _table_
```sql
select * from monitoring.linked_servers_hidden_credentials
```

**Connection number per user** — _barchart_
```sql
select sum(connection_count::int) , server ||'-'||login_name   from monitoring.connection_count
group by  server ||'-'||login_name
```

**Active threats** — _gauge_
```sql
select count(*) "suspicious queries" from monitoring.v_suspiscous
```


## Locked accounts

**Locked accounts** — _barchart_
```sql
select server , count(*) lock_date from monitoring.v_oracle_locked_accounts
group by server
```

**(untitled panel)** — _table_
```sql
select distinct server from monitoring.v_oracle_locked_accounts
```

**Locked accounts** — _table_
```sql
select server , username , account_status , to_timestamp(lock_date::bigint / 1000) lock_date from
    monitoring.v_oracle_locked_accounts
```

**Sensitivity reports** — _barchart_
```sql
SELECT server , 
 	count(*) "Number of sensitivity issues"
   FROM ( SELECT query_id , entry_date  , server , (sql_feature_predictions.features ->> 'query'::text) AS
    query,
            ((sql_feature_predictions.features ->> 'sensitive_columns'::text))::boolean AS sensitive_columns
           FROM monitoring.sql_feature_predictions) a
  left outer join monitoring.sql_suspicious susp on susp.query_id = a.query_id
  WHERE (sensitive_columns IS TRUE) 
   group by server
```

**SQL Injection analysis** — _barchart_
```sql
SELECT SERVER , 
    SUM(CASE WHEN dangerous_function = TRUE THEN 1 ELSE 0 END) AS dangerous_function,
    SUM(CASE WHEN sleep_time = TRUE THEN 1 ELSE 0 END) AS sleep_time , 
	SUM(CASE WHEN boolean_sqli = TRUE THEN 1 ELSE 0 END) AS "boolean Injection"	 , 
	SUM(CASE WHEN outfile_copy = TRUE THEN 1 ELSE 0 END) AS "copy injections"	 , 
	SUM(CASE WHEN union_select = TRUE THEN 1 ELSE 0 END) AS "union_select	injections"  , 
	SUM(CASE WHEN commented_payload = TRUE THEN 1 ELSE 0 END) AS commented_payload	  	
FROM monitoring.v_sql_feature_predictions GROUP BY SERVER
```

**Data activity monitoring** — _barchart_
```sql
select count(*) , server   from monitoring.active_transactions
where  last_request_end_time > Now() - interval '1 hour'
group by server
```


## Mail

**Mail configuration** — _table_
```sql
select mc.*  , mg.recipients from config.mail_config mc
	join config.mail_groups mg on mg.mail_config_id = mc.row_id
```


## PII - Sensitive columns

**Total Events** — _stat_
```sql
SELECT COALESCE(count(*),0) AS "Total Events" FROM alerts.alert_log  al
join rootcause.v_rootcauses rc on rc.root_cause_id = al.root_cause_id 
where $__timeFilter(entry_date) 
and rc.root_cause_desc like '%PPL%'
```

**Critical** — _stat_
```sql
SELECT count(*) FROM alerts.alert_log al 
join rootcause.v_rootcauses rc on rc.root_cause_id = al.root_cause_id
where rc.root_cause_desc like '%PPL%'
and  al.risk_level ='critical' and $__timeFilter(entry_date)
```

**High** — _stat_
```sql
SELECT count(*) FROM alerts.alert_log al 
join rootcause.v_rootcauses rc on rc.root_cause_id = al.root_cause_id
where rc.root_cause_desc like '%PPL%'
and  al.risk_level ='high' and $__timeFilter(entry_date)
```

**Medium** — _stat_
```sql
SELECT count(*) FROM alerts.alert_log al 
join rootcause.v_rootcauses rc on rc.root_cause_id = al.root_cause_id
where rc.root_cause_desc like '%PPL%'
and  al.risk_level ='medium' and $__timeFilter(entry_date)
```

**Blcked** — _stat_
```sql
SELECT count(*) FROM alerts.mail_alert_log al 
join rootcause.v_rootcauses rc on rc.root_cause_id = al.metric_name
where rc.root_cause_desc like '%PPL%'
and $__timeFilter(entry_date)
```

**Monitored** — _stat_
```sql
select count(*) from alerts.mail_alert_log where recipients is not null and  $__timeFilter(entry_date)
```

**Root causes** — _table_
```sql
select root_cause_ID ,step_name,ROOT_CAUSE_DESC   , risk_level
from 
(
select distinct rc.root_cause_ID ,rc.step_name, rc.ROOT_CAUSE_DESC   , al.risk_level
FROM  rootcause.v_rootcauses rc
join  alerts.alert_log al on al.root_cause_id = rc.root_cause_ID
where rc.root_cause_id like 'SEC-SQL-PRI%'
and vendor_name = 'sqlserver'
)
ORDER BY CASE risk_level WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END DESC LIMIT
    20
```

**Detailed findings** — _table_
```sql
SELECT * FROM monitoring.get_alert_log_resultset('${root_cause_id}', $__timeFrom())
WHERE '${root_cause_id}' <> '' LIMIT 10;
```

**Root cause details - ${root_cause_id}** — _table_
```sql
SELECT j.value AS result
FROM jsonb_array_elements(
  COALESCE(monitoring.get_root_cause_resultset(NULLIF('${root_cause_id}',''), $__timeFrom())::jsonb,
    '[]'::jsonb)
) AS j
LIMIT 500
```


## PII - Sensitive data in use

**Total Events** — _stat_
```sql
SELECT COALESCE(count(*),0) AS "Total Events" FROM alerts.alert_log  al
join rootcause.v_rootcauses rc on rc.root_cause_id = al.root_cause_id 
where $__timeFilter(entry_date) 
and rc.root_cause_desc like '%PPL%'
```

**Critical** — _stat_
```sql
SELECT count(*) FROM alerts.alert_log al 
join rootcause.v_rootcauses rc on rc.root_cause_id = al.root_cause_id
where rc.root_cause_desc like '%PPL%'
and  al.risk_level ='critical' and $__timeFilter(entry_date)
```

**High** — _stat_
```sql
SELECT count(*) FROM alerts.alert_log al 
join rootcause.v_rootcauses rc on rc.root_cause_id = al.root_cause_id
where rc.root_cause_desc like '%PPL%'
and  al.risk_level ='high' and $__timeFilter(entry_date)
```

**Medium** — _stat_
```sql
SELECT count(*) FROM alerts.alert_log al 
join rootcause.v_rootcauses rc on rc.root_cause_id = al.root_cause_id
where rc.root_cause_desc like '%PPL%'
and  al.risk_level ='medium' and $__timeFilter(entry_date)
```

**Blcked** — _stat_
```sql
SELECT count(*) FROM alerts.mail_alert_log al 
join rootcause.v_rootcauses rc on rc.root_cause_id = al.metric_name
where rc.root_cause_desc like '%PPL%'
and $__timeFilter(entry_date)
```

**Monitored** — _stat_
```sql
select count(*) from alerts.mail_alert_log where recipients is not null and  $__timeFilter(entry_date)
```

**Root causes** — _table_
```sql
select root_cause_ID ,step_name,ROOT_CAUSE_DESC   , risk_level
from 
(
select distinct rc.root_cause_ID ,rc.step_name, rc.ROOT_CAUSE_DESC   , al.risk_level
FROM  rootcause.v_rootcauses rc
join  alerts.alert_log al on al.root_cause_id = rc.root_cause_ID
where rc.root_cause_id like 'SEC-SQL-PRI%'
and vendor_name = 'sqlserver'
)
ORDER BY CASE risk_level WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END DESC LIMIT
    20
```

**Detailed findings** — _table_
```sql
SELECT * FROM monitoring.get_alert_log_resultset('${root_cause_id}', $__timeFrom())
WHERE '${root_cause_id}' <> '' LIMIT 10;
```

**Root cause details - ${root_cause_id}** — _table_
```sql
SELECT j.value AS result
FROM jsonb_array_elements(
  COALESCE(monitoring.get_root_cause_resultset(NULLIF('${root_cause_id}',''), $__timeFrom())::jsonb,
    '[]'::jsonb)
) AS j
LIMIT 500
```


## PPL- Protection of Privacy Law, 5741 – 1981

**Total Events** — _stat_
```sql
SELECT COALESCE(count(*),0) AS "Total Events" FROM alerts.alert_log  al
join rootcause.v_rootcauses rc on rc.root_cause_id = al.root_cause_id 
where $__timeFilter(entry_date) 
and rc.root_cause_desc like '%PPL%'
```

**Critical** — _stat_
```sql
SELECT count(*) FROM alerts.alert_log al 
join rootcause.v_rootcauses rc on rc.root_cause_id = al.root_cause_id
where rc.root_cause_desc like '%PPL%'
and  al.risk_level ='critical' and $__timeFilter(entry_date)
```

**High** — _stat_
```sql
SELECT count(*) FROM alerts.alert_log al 
join rootcause.v_rootcauses rc on rc.root_cause_id = al.root_cause_id
where rc.root_cause_desc like '%PPL%'
and  al.risk_level ='high' and $__timeFilter(entry_date)
```

**Medium** — _stat_
```sql
SELECT count(*) FROM alerts.alert_log al 
join rootcause.v_rootcauses rc on rc.root_cause_id = al.root_cause_id
where rc.root_cause_desc like '%PPL%'
and  al.risk_level ='medium' and $__timeFilter(entry_date)
```

**Blcked** — _stat_
```sql
SELECT count(*) FROM alerts.mail_alert_log al 
join rootcause.v_rootcauses rc on rc.root_cause_id = al.metric_name
where rc.root_cause_desc like '%PPL%'
and $__timeFilter(entry_date)
```

**Monitored** — _stat_
```sql
select count(*) from alerts.mail_alert_log where recipients is not null and  $__timeFilter(entry_date)
```

**Intrusions by Severity** — _piechart_
```sql
SELECT risk_level AS "Severity", count(*) AS "Count" FROM alerts.alert_log  GROUP BY risk_level ORDER BY CASE
    risk_level WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 ELSE 5 END
```

**Intrusions by Type** — _barchart_
```sql
select RC.issue_name as "Type"  , count(*)  AS "Count" from alerts.alert_log al 
join rootcause.v_rootcauses rc on rc.root_cause_id = al.root_cause_id
where $__timeFilter(entry_date) 
and rc.root_cause_desc like '%PPL%'
group by al.root_cause_id , issue_name
```

**Intrusion Events Timeline (Last 7 Days)** — _timeseries_
```sql
SELECT 
    date_trunc('hour', entry_date)::timestamp AS "time" ,
	COUNT(*) AS "count",
    rc.risk_level AS severity
FROM alerts.alert_log al
join rootcause.v_rootcauses rc on rc.root_cause_id = al.root_cause_id
where $__timeFilter(entry_date) 
and root_cause_desc like '%PPL%'
GROUP BY 
    rc.risk_level,
    date_trunc('hour', entry_date)
ORDER BY 
    time;
```

**Blocked Intrusions** — _table_
```sql
SELECT root_cause_name AS "Attack", issue_name AS "Type", risk_level AS "Severity", count(*) AS "Count" 
FROM alerts.mail_alert_log ma
join rootcause.v_rootcauses rc on rc.root_cause_id  = ma.metric_name
where $__timeFilter(entry_date) 
and rc.root_cause_DESC like '%PPL%'
group by root_cause_name , issue_name ,risk_level
ORDER BY CASE risk_level WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END DESC LIMIT
    20
```

**Monitored Intrusions** — _table_
```sql
SELECT root_cause_name AS "Attack", issue_name AS "Type",  count(*) AS "Count"  , rc.root_cause_desc
FROM alerts.alert_log  al
join rootcause.v_rootcauses rc on rc.root_cause_id  = al.root_cause_id 
where $__timeFilter(entry_date) 
and rc.root_cause_desc like '%PPL%'
group by root_cause_name , issue_name , rc.root_cause_desc
```

**Top Victims** — _table_
```sql
SELECT server , root_cause_name AS "Attack", issue_name AS "Type",  count(*) AS "Count" 
FROM alerts.mail_alert_log  al
join rootcause.v_rootcauses rc on rc.root_cause_id  = al.metric_name
where root_cause_desc like '%PPL%'
group by root_cause_name , issue_name ,server
```

**Root causes** — _table_
```sql
select rc.root_cause_ID , rc.ROOT_CAUSE_DESC
FROM  rootcause.v_rootcauses rc
where rc.root_cause_DESC like '%PPL%' and vendor_name = 'sqlserver'
ORDER BY CASE risk_level WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END DESC LIMIT
    20
```

**Top Attack Sources** — _table_
```sql
SELECT 	
        count(*) *100 /         (select count(*) from alerts.alert_log al1 where $__timeFilter(al1.entry_date)
    ) pct_of_total ,
	gmmr.metric_metadata , 
	risk_level 
	 FROM alerts.alert_log al
         join monitoring.general_metric_metadata_results gmmr on gmmr.server = al.server and al.root_cause_id
    = gmmr.metric_name and al.entry_date between gmmr.entry_date -interval '1 second' and gmmr.entry_date
    +interval '1 second'
   where $__timeFilter(al.entry_date) 
	group by risk_level , metric_metadata
	order by pct_of_total desc
```


## Policy not enforced

**Policy not enforced** — _barchart_
```sql
select server , count(*) lock_date from monitoring.v_policy_enforeced
group by server
```

**(untitled panel)** — _table_
```sql
select distinct server  from monitoring.v_policy_enforeced
```

**Policy not enforced** — _table_
```sql
select  * from monitoring.v_policy_enforeced
```

**Sensitivity reports** — _barchart_
```sql
SELECT server , 
 	count(*) "Number of sensitivity issues"
   FROM ( SELECT query_id , entry_date  , server , (sql_feature_predictions.features ->> 'query'::text) AS
    query,
            ((sql_feature_predictions.features ->> 'sensitive_columns'::text))::boolean AS sensitive_columns
           FROM monitoring.sql_feature_predictions) a
  left outer join monitoring.sql_suspicious susp on susp.query_id = a.query_id
  WHERE (sensitive_columns IS TRUE) 
   group by server
```

**SQL Injection analysis** — _barchart_
```sql
SELECT SERVER , 
    SUM(CASE WHEN dangerous_function = TRUE THEN 1 ELSE 0 END) AS dangerous_function,
    SUM(CASE WHEN sleep_time = TRUE THEN 1 ELSE 0 END) AS sleep_time , 
	SUM(CASE WHEN boolean_sqli = TRUE THEN 1 ELSE 0 END) AS "boolean Injection"	 , 
	SUM(CASE WHEN outfile_copy = TRUE THEN 1 ELSE 0 END) AS "copy injections"	 , 
	SUM(CASE WHEN union_select = TRUE THEN 1 ELSE 0 END) AS "union_select	injections"  , 
	SUM(CASE WHEN commented_payload = TRUE THEN 1 ELSE 0 END) AS commented_payload	  	
FROM monitoring.v_sql_feature_predictions GROUP BY SERVER
```

**Data activity monitoring** — _barchart_
```sql
select count(*) , server   from monitoring.active_transactions
where  last_request_end_time > Now() - interval '1 hour'
group by server
```


## Processes

**Processes** — _table_
```sql
select process_name , is_active as Active ,  interval from  metrics.registered_processes
```
```sql
select 
    SUM(CASE WHEN dangerous_function = TRUE THEN 1 ELSE 0 END)  + 
    SUM(CASE WHEN sleep_time = TRUE THEN 1 ELSE 0 END)  + 
	SUM(CASE WHEN boolean_sqli = TRUE THEN 1 ELSE 0 END)+
	SUM(CASE WHEN long_literal = TRUE THEN 1 ELSE 0 END)+
	SUM(CASE WHEN outfile_copy = TRUE THEN 1 ELSE 0 END)+ 
	SUM(CASE WHEN union_select = TRUE THEN 1 ELSE 0 END)+ 
	SUM(CASE WHEN schema_access = TRUE THEN 1 ELSE 0 END) + 
	SUM(CASE WHEN stacked_query = TRUE THEN 1 ELSE 0 END) + 
	SUM(CASE WHEN commented_payload = TRUE THEN 1 ELSE 0 END) +
	SUM(CASE WHEN sensitive_columns = TRUE THEN 1 ELSE 0 END) "Active threats"
FROM monitoring.v_sql_feature_predictions
```

**Sensitivity reports** — _barchart_
```sql
SELECT server , 
 	count(*) "Number of sensitivity issues"
   FROM ( SELECT query_id , entry_date  , server , (sql_feature_predictions.features ->> 'query'::text) AS
    query,
            ((sql_feature_predictions.features ->> 'sensitive_columns'::text))::boolean AS sensitive_columns
           FROM monitoring.sql_feature_predictions) a
  left outer join monitoring.sql_suspicious susp on susp.query_id = a.query_id
  WHERE (sensitive_columns IS TRUE) 
   group by server
```

**SQL Injection analysis** — _barchart_
```sql
SELECT SERVER , 
    SUM(CASE WHEN dangerous_function = TRUE THEN 1 ELSE 0 END) AS dangerous_function,
    SUM(CASE WHEN sleep_time = TRUE THEN 1 ELSE 0 END) AS sleep_time , 
	SUM(CASE WHEN boolean_sqli = TRUE THEN 1 ELSE 0 END) AS "boolean Injection"	 , 
	SUM(CASE WHEN outfile_copy = TRUE THEN 1 ELSE 0 END) AS "copy injections"	 , 
	SUM(CASE WHEN union_select = TRUE THEN 1 ELSE 0 END) AS "union_select	injections"  , 
	SUM(CASE WHEN commented_payload = TRUE THEN 1 ELSE 0 END) AS commented_payload	  	
FROM monitoring.v_sql_feature_predictions GROUP BY SERVER
```

**Data activity monitoring** — _barchart_
```sql
select count(*) , server   from monitoring.active_transactions
where  last_request_end_time > Now() - interval '1 hour'
group by server
```

**Connectivity reports** — _barchart_
```sql
select count(*) , server ,client_net_address from monitoring.tcp_connections
where connect_Time > Now()   - interval '1 hour'
group by server ,client_net_address
```


## Recent alerts

**Security dashboard** — _table_
```sql
SELECT  tcp.server ,tcp.client_net_address, at.query , at.login_name	  , tcp.connect_time 

FROM monitoring.TCP_connections tcp
left outer join monitoring.active_transactions at on at.server = tcp.server and at.session_id = tcp.session_id
    and at.start_time  between tcp.connect_time and at.last_request_end_time
WHERE connect_time between Now() - interval '5 minutes' and  now()
```

**Critical issues** — _table_
```sql
SELECT  tcp.server ,tcp.client_net_address, at.query , at.login_name	  , tcp.connect_time 

FROM monitoring.TCP_connections tcp
left outer join monitoring.active_transactions at on at.server = tcp.server and at.session_id = tcp.session_id
    and at.start_time  between tcp.connect_time and at.last_request_end_time
WHERE connect_time between Now() - interval '5 minutes' and  now()
```

**Active threats** — _table_
```sql
SELECT  tcp.server ,tcp.client_net_address, at.query , at.login_name	  , tcp.connect_time 

FROM monitoring.TCP_connections tcp
left outer join monitoring.active_transactions at on at.server = tcp.server and at.session_id = tcp.session_id
    and at.start_time  between tcp.connect_time and at.last_request_end_time
WHERE connect_time between Now() - interval '5 minutes' and  now()
```

**Active threats** — _table_
```sql
SELECT  tcp.server ,tcp.client_net_address, at.query , at.login_name	  , tcp.connect_time 

FROM monitoring.TCP_connections tcp
left outer join monitoring.active_transactions at on at.server = tcp.server and at.session_id = tcp.session_id
    and at.start_time  between tcp.connect_time and at.last_request_end_time
WHERE connect_time between Now() - interval '5 minutes' and  now()
```

**Active users** — _table_
```sql
SELECT  tcp.server ,tcp.client_net_address, at.query , at.login_name	  , tcp.connect_time 

FROM monitoring.TCP_connections tcp
left outer join monitoring.active_transactions at on at.server = tcp.server and at.session_id = tcp.session_id
    and at.start_time  between tcp.connect_time and at.last_request_end_time
WHERE connect_time between Now() - interval '5 minutes' and  now()
```

**Cyber attacks** — _table_
```sql
SELECT  tcp.server ,tcp.client_net_address, at.query , at.login_name	  , tcp.connect_time 

FROM monitoring.TCP_connections tcp
left outer join monitoring.active_transactions at on at.server = tcp.server and at.session_id = tcp.session_id
    and at.start_time  between tcp.connect_time and at.last_request_end_time
WHERE connect_time between Now() - interval '5 minutes' and  now()
```

**Recent alerts** — _table_
```sql
SELECT  tcp.server ,tcp.client_net_address, at.query , at.login_name	  , tcp.connect_time 

FROM monitoring.TCP_connections tcp
left outer join monitoring.active_transactions at on at.server = tcp.server and at.session_id = tcp.session_id
    and at.start_time  between tcp.connect_time and at.last_request_end_time
WHERE connect_time between Now() - interval '5 minutes' and  now()
```

**Sensitivity reports** — _table_
```sql
SELECT  tcp.server ,tcp.client_net_address, at.query , at.login_name	  , tcp.connect_time 

FROM monitoring.TCP_connections tcp
left outer join monitoring.active_transactions at on at.server = tcp.server and at.session_id = tcp.session_id
    and at.start_time  between tcp.connect_time and at.last_request_end_time
WHERE connect_time between Now() - interval '5 minutes' and  now()
```

**SQL Injection analysis** — _table_
```sql
SELECT  tcp.server ,tcp.client_net_address, at.query , at.login_name	  , tcp.connect_time 

FROM monitoring.TCP_connections tcp
left outer join monitoring.active_transactions at on at.server = tcp.server and at.session_id = tcp.session_id
    and at.start_time  between tcp.connect_time and at.last_request_end_time
WHERE connect_time between Now() - interval '5 minutes' and  now()
```

**Data activity monitoring** — _table_
```sql
SELECT  tcp.server ,tcp.client_net_address, at.query , at.login_name	  , tcp.connect_time 

FROM monitoring.TCP_connections tcp
left outer join monitoring.active_transactions at on at.server = tcp.server and at.session_id = tcp.session_id
    and at.start_time  between tcp.connect_time and at.last_request_end_time
WHERE connect_time between Now() - interval '5 minutes' and  now()
```

**Connectivity reports** — _table_
```sql
SELECT  tcp.server ,tcp.client_net_address, at.query , at.login_name	  , tcp.connect_time 

FROM monitoring.TCP_connections tcp
left outer join monitoring.active_transactions at on at.server = tcp.server and at.session_id = tcp.session_id
    and at.start_time  between tcp.connect_time and at.last_request_end_time
WHERE connect_time between Now() - interval '5 minutes' and  now()
```


## Retention

**Retention Overview** — _table_
```sql
SELECT ro.category, ro.item, rc.root_cause_name, ro.data_size, ro.data_bytes, ro.row_count, ro.space_free,
       dm.retention_months,
       CASE WHEN dm.retention_months IS NOT NULL THEN '▲' END AS up,
       CASE WHEN dm.retention_months IS NOT NULL THEN '▼' END AS down,
       (dm.retention_months + 1) AS up_val,
       GREATEST(dm.retention_months - 1, 0) AS down_val,
       CASE WHEN ro.item IS NOT NULL THEN '⭳ Dump' END AS dump
FROM metrics.t_retention_overview ro
LEFT JOIN (SELECT DISTINCT root_cause_id, root_cause_name FROM rootcause.v_rootcauses) rc ON rc.root_cause_id
    = ro.item
LEFT JOIN config.dump_metrics dm ON dm.metric_name = ro.item
ORDER BY ro.category, ro.item
```

**Apply retention edit (auto-runs on ▲/▼ click)** — _table_
```sql
UPDATE config.dump_metrics SET retention_months = NULLIF('${edit_value}','')::int WHERE metric_name =
    NULLIF('${edit_metric}','') RETURNING metric_name AS edited_metric, retention_months AS new_retention
```

**Current dump location** — _table_
```sql
SELECT config.get_dump_location() AS dump_location
```

**Save dump location  (refresh to save)** — _table_
```sql
SELECT CASE WHEN '${dump_location}' <> '' AND '${dump_location}' <> coalesce(config.get_dump_location(),'')
    THEN config.set_dump_location('${dump_location}') ELSE config.get_dump_location() END AS dump_location
```

**Dump metrics (config.dump_metrics)** — _table_
```sql
SELECT row_id, metric_name, retention_months, entry_date FROM config.dump_metrics ORDER BY metric_name
```

**Dumps catalog (config.dumps)** — _table_
```sql
SELECT row_id, metric_name, month, year, row_count, dump_location, entry_date,
       '↩ Restore' AS restore
FROM config.dumps
ORDER BY year DESC, month DESC, metric_name
```

**Apply dump (auto-runs on Dump click)** — _table_
```sql
SELECT * FROM config.dump_last_month(NULLIF('${dump_metric}',''))
```

**Apply restore (auto-runs on Restore click)** — _table_
```sql
SELECT * FROM config.restore_dump(NULLIF('${restore_id}','')::bigint)
```


## Retention  policy

**Retention policy** — _table_
```sql
select row_id , server , table_name  , days_to_keep from config.retention_policy
```

**Sensitivity reports** — _barchart_
```sql
SELECT server , 
 	count(*) "Number of sensitivity issues"
   FROM ( SELECT query_id , entry_date  , server , (sql_feature_predictions.features ->> 'query'::text) AS
    query,
            ((sql_feature_predictions.features ->> 'sensitive_columns'::text))::boolean AS sensitive_columns
           FROM monitoring.sql_feature_predictions) a
  left outer join monitoring.sql_suspicious susp on susp.query_id = a.query_id
  WHERE (sensitive_columns IS TRUE) 
   group by server
```

**SQL Injection analysis** — _barchart_
```sql
SELECT SERVER , 
    SUM(CASE WHEN dangerous_function = TRUE THEN 1 ELSE 0 END) AS dangerous_function,
    SUM(CASE WHEN sleep_time = TRUE THEN 1 ELSE 0 END) AS sleep_time , 
	SUM(CASE WHEN boolean_sqli = TRUE THEN 1 ELSE 0 END) AS "boolean Injection"	 , 
	SUM(CASE WHEN outfile_copy = TRUE THEN 1 ELSE 0 END) AS "copy injections"	 , 
	SUM(CASE WHEN union_select = TRUE THEN 1 ELSE 0 END) AS "union_select	injections"  , 
	SUM(CASE WHEN commented_payload = TRUE THEN 1 ELSE 0 END) AS commented_payload	  	
FROM monitoring.v_sql_feature_predictions GROUP BY SERVER
```

**Data activity monitoring** — _barchart_
```sql
select count(*) , server   from monitoring.active_transactions
where  last_request_end_time > Now() - interval '1 hour'
group by server
```

**Connectivity reports** — _barchart_
```sql
select count(*) , server ,client_net_address from monitoring.tcp_connections
where connect_Time > Now()   - interval '1 hour'
group by server ,client_net_address
```


## Rootcauses

**Issues  (click 'select' to load its root causes)** — _table_
```sql
SELECT i.issue_id, i.name AS issue_name, left(i.description,220) AS issue_desc,
       (ARRAY['low','medium','high','critical'])[ max(CASE vr.risk_level WHEN 'low' THEN 1 WHEN 'medium' THEN
    2 WHEN 'high' THEN 3 WHEN 'critical' THEN 4 ELSE 0 END) ] AS risk_level,
       bool_or(vr.is_active) AS is_active,
       'select ▶' AS open
FROM rootcause.issues i
LEFT JOIN rootcause.v_rootcauses vr ON vr.issue_id = i.issue_id
where i.domain_code = 'SEC' and i.database_type_code = 'SQL'
GROUP BY i.issue_id, i.name, i.description
ORDER BY i.issue_id
```

**Root causes for selected issue  -  toggle active / set risk level (saved via API)** — _table_
```sql
WITH vr AS (
  SELECT root_cause_id, bool_or(is_active) AS is_active,
         max(CASE risk_level WHEN 'low' THEN 1 WHEN 'medium' THEN 2 WHEN 'high' THEN 3 WHEN 'critical' THEN 4
    ELSE 0 END) AS risk_ord
  FROM rootcause.v_rootcauses WHERE issue_id = '${sel_issue}' GROUP BY root_cause_id
)
SELECT rc.root_cause_id, rc.name AS root_cause_name, left(rc.description,220) AS root_cause_desc,
       coalesce(vr.is_active,false) AS is_active,
       (ARRAY['low','medium','high','critical'])[vr.risk_ord] AS risk_level,
       rc.issue_id,
       (NOT coalesce(vr.is_active,false))::text AS next_active,
       CASE WHEN coalesce(vr.is_active,false) THEN '🔴 Disable' ELSE '🟢 Enable' END AS toggle,
       'Low' AS set_low, 'Medium' AS set_medium, 'High' AS set_high, 'Critical' AS set_critical
FROM rootcause.root_causes rc
LEFT JOIN vr ON vr.root_cause_id = rc.root_cause_id
WHERE rc.issue_id = '${sel_issue}'
ORDER BY rc.root_cause_id
```


## SIEM configuration

**SIEM** — _table_
```sql
select * from config.sime_interface
```

**Sensitivity reports** — _barchart_
```sql
SELECT server , 
 	count(*) "Number of sensitivity issues"
   FROM ( SELECT query_id , entry_date  , server , (sql_feature_predictions.features ->> 'query'::text) AS
    query,
            ((sql_feature_predictions.features ->> 'sensitive_columns'::text))::boolean AS sensitive_columns
           FROM monitoring.sql_feature_predictions) a
  left outer join monitoring.sql_suspicious susp on susp.query_id = a.query_id
  WHERE (sensitive_columns IS TRUE) 
   group by server
```

**SQL Injection analysis** — _barchart_
```sql
SELECT SERVER , 
    SUM(CASE WHEN dangerous_function = TRUE THEN 1 ELSE 0 END) AS dangerous_function,
    SUM(CASE WHEN sleep_time = TRUE THEN 1 ELSE 0 END) AS sleep_time , 
	SUM(CASE WHEN boolean_sqli = TRUE THEN 1 ELSE 0 END) AS "boolean Injection"	 , 
	SUM(CASE WHEN outfile_copy = TRUE THEN 1 ELSE 0 END) AS "copy injections"	 , 
	SUM(CASE WHEN union_select = TRUE THEN 1 ELSE 0 END) AS "union_select	injections"  , 
	SUM(CASE WHEN commented_payload = TRUE THEN 1 ELSE 0 END) AS commented_payload	  	
FROM monitoring.v_sql_feature_predictions GROUP BY SERVER
```

**Data activity monitoring** — _barchart_
```sql
select count(*) , server   from monitoring.active_transactions
where  last_request_end_time > Now() - interval '1 hour'
group by server
```

**Connectivity reports** — _barchart_
```sql
select count(*) , server ,client_net_address from monitoring.tcp_connections
where connect_Time > Now()   - interval '1 hour'
group by server ,client_net_address
```


## SQL Injection

**SQL injection by patterns** — _gauge_
```sql
select 
    (select count(*) from monitoring.expensive_queries where query  ILIKE ANY (ARRAY['%/*%*/%', '%--%']  )) as
    "comment_based_injections",
        (select count(*) from monitoring.expensive_queries where   query   ILIKE ANY (ARRAY['%OR 1=1%', '%AND
    1=1%' , '%OR ''a''=''a%'''])) as "Boolean-based injections" ,
        (select count(*) from monitoring.expensive_queries where  query  ILIKE ANY (ARRAY['%'' OR 1=1 --''%',
    '%"" OR 1=1 --%'])) as "tautology_with_comments" ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%UNION SELECT',
    '%UNION ALL SELECT%'])) as "union_based_injection" ,
        (select count(*) from monitoring.expensive_queries where query  ILIKE ANY (ARRAY['%; DROP TABLE
    users', '%; EXEC xp_cmdshell%'])) as "stacked_queries" ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%WAITFOR DELAY%',
    '%pg_sleep%','%SLEEP%'])) as "time_based_blind _injection"    ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%CONVERT%',
    '%CAST%'])) as "error_based_injection"            ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY
    (ARRAY['%information_schema.tables%', '%information_schema.columns%','%sys.tables%','%pg_catalog%'])) as
    "information_schema_probing"                          ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%'' OR ''=''%', '%''
    OR ''x''=''x''%', '%admin''--%'])) as "Authentication bypass patterns" ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%0x414243%',
    '%CHAR(65,66,67)%'])) as "encoding injection"  ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%xp_cmdshell%',
    '%sp_executesql%'])) as "shell_system_functions injection" ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%ORDER BY 1%',
    '%ORDER BY%'])) as "ORDER BY_GROUP BY injection"
```

**SQL Injections  - Injection prevention** — _table_
```sql
select root_cause , description from rootcause.v_root_causes_with_context
```


## SQL injection - Boolean-based injections

**Critical issues - SQL injection** — _gauge_
```sql
select 
    (select count(*) from monitoring.v_new_queries_last_hour where query  ILIKE ANY (ARRAY['%/*%*/%', '%--%']
    )) as "comment_based_injections",
        (select count(*) from monitoring.v_new_queries_last_hour where query   ILIKE ANY (ARRAY['%OR 1=1%',
    '%AND 1=1%' , '%OR ''a''=''a%'''])) as "Boolean-based injections" ,
        (select count(*) from monitoring.v_new_queries_last_hour where query  ILIKE ANY (ARRAY['%'' OR 1=1
    --''%', '%"" OR 1=1 --%'])) as "tautology_with_comments" ,
        (select count(*) from monitoring.v_new_queries_last_hour where query  ILIKE ANY (ARRAY['%UNION
    SELECT', '%UNION ALL SELECT%'])) as "union_based_injection" ,
        (select count(*) from monitoring.v_new_queries_last_hour where query  ILIKE ANY (ARRAY['%; DROP TABLE
    users', '%; EXEC xp_cmdshell%'])) as "stacked_queries" ,
        (select count(*) from monitoring.v_new_queries_last_hour where query ILIKE ANY (ARRAY['%WAITFOR
    DELAY%', '%pg_sleep%','%SLEEP%'])) as "time_based_blind _injection"      ,
        (select count(*) from monitoring.v_new_queries_last_hour where query ILIKE ANY (ARRAY['%CONVERT%',
    '%CAST%'])) as "error_based_injection"               ,
        (select count(*) from monitoring.v_new_queries_last_hour where query ILIKE ANY
    (ARRAY['%information_schema.tables%', '%information_schema.columns%','%sys.tables%','%pg_catalog%'])) as
    "information_schema_probing"                     ,
        (select count(*) from monitoring.v_new_queries_last_hour where query ILIKE ANY (ARRAY['%'' OR ''=''%',
    '%'' OR ''x''=''x''%', '%admin''--%'])) as "Authentication bypass patterns" ,
        (select count(*) from monitoring.v_new_queries_last_hour where query ILIKE ANY (ARRAY['%0x414243%',
    '%CHAR(65,66,67)%'])) as "encoding injection"  ,
        (select count(*) from monitoring.v_new_queries_last_hour where query ILIKE ANY (ARRAY['%xp_cmdshell%',
    '%sp_executesql%'])) as "shell_system_functions injection" ,
        (select count(*) from monitoring.v_new_queries_last_hour where query ILIKE ANY (ARRAY['%ORDER BY 1%',
    '%ORDER BY%'])) as "ORDER BY_GROUP BY injection"
```

**comment based injections** — _table_
```sql
select  SERVER , COLUMNS ,TABLES ,CONDITION   , FUNC AS FUCTION  , JOINS , LITERAL    , QUERY from
    monitoring.v_new_queries_last_hour where query  ILIKE ANY (ARRAY['%OR 1=1%', '%AND 1=1%' , '%OR
    ''a''=''a%'''])
```


## SQL injection - Comment based

**Critical issues - SQL injection** — _gauge_
```sql
select 
    (select count(*) from monitoring.expensive_queries where query  ILIKE ANY (ARRAY['%/*%*/%', '%--%']  )) as
    "comment_based_injections",
        (select count(*) from monitoring.expensive_queries where query   ILIKE ANY (ARRAY['%OR 1=1%', '%AND
    1=1%' , '%OR ''a''=''a%'''])) as "Boolean-based injections" ,
        (select count(*) from monitoring.expensive_queries where query  ILIKE ANY (ARRAY['%'' OR 1=1 --''%',
    '%"" OR 1=1 --%'])) as "tautology_with_comments" ,
        (select count(*) from monitoring.expensive_queries where query  ILIKE ANY (ARRAY['%UNION SELECT',
    '%UNION ALL SELECT%'])) as "union_based_injection" ,
        (select count(*) from monitoring.expensive_queries where query  ILIKE ANY (ARRAY['%; DROP TABLE
    users', '%; EXEC xp_cmdshell%'])) as "stacked_queries" ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%WAITFOR DELAY%',
    '%pg_sleep%','%SLEEP%'])) as "time_based_blind _injection"    ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%CONVERT%',
    '%CAST%'])) as "error_based_injection"             ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY
    (ARRAY['%information_schema.tables%', '%information_schema.columns%','%sys.tables%','%pg_catalog%'])) as
    "information_schema_probing"                   ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%'' OR ''=''%', '%''
    OR ''x''=''x''%', '%admin''--%'])) as "Authentication bypass patterns" ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%0x414243%',
    '%CHAR(65,66,67)%'])) as "encoding injection"  ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%xp_cmdshell%',
    '%sp_executesql%'])) as "shell_system_functions injection" ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%ORDER BY 1%',
    '%ORDER BY%'])) as "ORDER BY_GROUP BY injection"
```

**comment based injections** — _table_
```sql
select   server, to_timestamp(creation_time::bigint/1000) "end time "        ,  '(--.*?$|/\*.*?\*/)' "used to
    truncate the query"
, QUERY from monitoring.expensive_queries where query  ILIKE ANY (ARRAY['%/*%*/%', '%--%']  )
```


## SQL injection - Information schema probing

**Critical issues - SQL injection** — _gauge_
```sql
select 
    (select count(*) from monitoring.v_new_queries_last_hour where query  ILIKE ANY (ARRAY['%/*%*/%', '%--%']
    )) as "comment_based_injections",
        (select count(*) from monitoring.v_new_queries_last_hour where query   ILIKE ANY (ARRAY['%OR 1=1%',
    '%AND 1=1%' , '%OR ''a''=''a%'''])) as "Boolean-based injections" ,
        (select count(*) from monitoring.v_new_queries_last_hour where query  ILIKE ANY (ARRAY['%'' OR 1=1
    --''%', '%"" OR 1=1 --%'])) as "tautology_with_comments" ,
        (select count(*) from monitoring.v_new_queries_last_hour where query  ILIKE ANY (ARRAY['%UNION
    SELECT', '%UNION ALL SELECT%'])) as "union_based_injection" ,
        (select count(*) from monitoring.v_new_queries_last_hour where query  ILIKE ANY (ARRAY['%; DROP TABLE
    users', '%; EXEC xp_cmdshell%'])) as "stacked_queries" ,
        (select count(*) from monitoring.v_new_queries_last_hour where query ILIKE ANY (ARRAY['%WAITFOR
    DELAY%', '%pg_sleep%','%SLEEP%'])) as "time_based_blind _injection"      ,
        (select count(*) from monitoring.v_new_queries_last_hour where query ILIKE ANY (ARRAY['%CONVERT%',
    '%CAST%'])) as "error_based_injection"               ,
        (select count(*) from monitoring.v_new_queries_last_hour where query ILIKE ANY
    (ARRAY['%information_schema.tables%', '%information_schema.columns%','%sys.tables%','%pg_catalog%'])) as
    "information_schema_probing"                     ,
        (select count(*) from monitoring.v_new_queries_last_hour where query ILIKE ANY (ARRAY['%'' OR ''=''%',
    '%'' OR ''x''=''x''%', '%admin''--%'])) as "Authentication bypass patterns" ,
        (select count(*) from monitoring.v_new_queries_last_hour where query ILIKE ANY (ARRAY['%0x414243%',
    '%CHAR(65,66,67)%'])) as "encoding injection"  ,
        (select count(*) from monitoring.v_new_queries_last_hour where query ILIKE ANY (ARRAY['%xp_cmdshell%',
    '%sp_executesql%'])) as "shell_system_functions injection" ,
        (select count(*) from monitoring.v_new_queries_last_hour where query ILIKE ANY (ARRAY['%ORDER BY 1%',
    '%ORDER BY%'])) as "ORDER BY_GROUP BY injection"
```

**Information schema probing** — _table_
```sql
select distinct server , query , to_timeStamp(creation_time::bigint/1000) , avg_elapsed_time duration
FROM monitoring.expensive_queries where query  ILIKE ANY (ARRAY['%information_schema.tables%',
    '%information_schema.columns%','%sys.tables%','%pg_catalog%'])
```


## SQL injection - Stacked queries

**Critical issues - SQL injection** — _gauge_
```sql
select 
    (select count(*) from monitoring.v_new_queries_last_hour where query  ILIKE ANY (ARRAY['%/*%*/%', '%--%']
    )) as "comment_based_injections",
        (select count(*) from monitoring.v_new_queries_last_hour where query   ILIKE ANY (ARRAY['%OR 1=1%',
    '%AND 1=1%' , '%OR ''a''=''a%'''])) as "Boolean-based injections" ,
        (select count(*) from monitoring.v_new_queries_last_hour where query  ILIKE ANY (ARRAY['%'' OR 1=1
    --''%', '%"" OR 1=1 --%'])) as "tautology_with_comments" ,
        (select count(*) from monitoring.v_new_queries_last_hour where query  ILIKE ANY (ARRAY['%UNION
    SELECT', '%UNION ALL SELECT%'])) as "union_based_injection" ,
        (select count(*) from monitoring.v_new_queries_last_hour where query  ILIKE ANY (ARRAY['%; DROP TABLE
    users', '%; EXEC xp_cmdshell%'])) as "stacked_queries" ,
        (select count(*) from monitoring.v_new_queries_last_hour where query ILIKE ANY (ARRAY['%WAITFOR
    DELAY%', '%pg_sleep%','%SLEEP%'])) as "time_based_blind _injection"      ,
        (select count(*) from monitoring.v_new_queries_last_hour where query ILIKE ANY (ARRAY['%CONVERT%',
    '%CAST%'])) as "error_based_injection"               ,
        (select count(*) from monitoring.v_new_queries_last_hour where query ILIKE ANY
    (ARRAY['%information_schema.tables%', '%information_schema.columns%','%sys.tables%','%pg_catalog%'])) as
    "information_schema_probing"                     ,
        (select count(*) from monitoring.v_new_queries_last_hour where query ILIKE ANY (ARRAY['%'' OR ''=''%',
    '%'' OR ''x''=''x''%', '%admin''--%'])) as "Authentication bypass patterns" ,
        (select count(*) from monitoring.v_new_queries_last_hour where query ILIKE ANY (ARRAY['%0x414243%',
    '%CHAR(65,66,67)%'])) as "encoding injection"  ,
        (select count(*) from monitoring.v_new_queries_last_hour where query ILIKE ANY (ARRAY['%xp_cmdshell%',
    '%sp_executesql%'])) as "shell_system_functions injection" ,
        (select count(*) from monitoring.v_new_queries_last_hour where query ILIKE ANY (ARRAY['%ORDER BY 1%',
    '%ORDER BY%'])) as "ORDER BY_GROUP BY injection"
```

**Stacked query injections** — _table_
```sql
select   distinct server , query , to_timeStamp(creation_time::bigint/1000) , avg_elapsed_time duration
from monitoring.expensive_queries where query  ILIKE ANY (ARRAY['%; DROP TABLE%', '%; EXEC xp_cmdshell%'])
```


## SQL injection - Time based

**Critical issues - SQL injection** — _gauge_
```sql
select 
    (select count(*) from monitoring.v_new_queries_last_hour where query  ILIKE ANY (ARRAY['%/*%*/%', '%--%']
    )) as "comment_based_injections",
        (select count(*) from monitoring.v_new_queries_last_hour where query   ILIKE ANY (ARRAY['%OR 1=1%',
    '%AND 1=1%' , '%OR ''a''=''a%'''])) as "Boolean-based injections" ,
        (select count(*) from monitoring.v_new_queries_last_hour where query  ILIKE ANY (ARRAY['%'' OR 1=1
    --''%', '%"" OR 1=1 --%'])) as "tautology_with_comments" ,
        (select count(*) from monitoring.v_new_queries_last_hour where query  ILIKE ANY (ARRAY['%UNION
    SELECT', '%UNION ALL SELECT%'])) as "union_based_injection" ,
        (select count(*) from monitoring.v_new_queries_last_hour where query  ILIKE ANY (ARRAY['%; DROP TABLE
    users', '%; EXEC xp_cmdshell%'])) as "stacked_queries" ,
        (select count(*) from monitoring.v_new_queries_last_hour where query ILIKE ANY (ARRAY['%WAITFOR
    DELAY%', '%pg_sleep%','%SLEEP%'])) as "time_based_blind _injection"      ,
        (select count(*) from monitoring.v_new_queries_last_hour where query ILIKE ANY (ARRAY['%CONVERT%',
    '%CAST%'])) as "error_based_injection"               ,
        (select count(*) from monitoring.v_new_queries_last_hour where query ILIKE ANY
    (ARRAY['%information_schema.tables%', '%information_schema.columns%','%sys.tables%','%pg_catalog%'])) as
    "information_schema_probing"                     ,
        (select count(*) from monitoring.v_new_queries_last_hour where query ILIKE ANY (ARRAY['%'' OR ''=''%',
    '%'' OR ''x''=''x''%', '%admin''--%'])) as "Authentication bypass patterns" ,
        (select count(*) from monitoring.v_new_queries_last_hour where query ILIKE ANY (ARRAY['%0x414243%',
    '%CHAR(65,66,67)%'])) as "encoding injection"  ,
        (select count(*) from monitoring.v_new_queries_last_hour where query ILIKE ANY (ARRAY['%xp_cmdshell%',
    '%sp_executesql%'])) as "shell_system_functions injection" ,
        (select count(*) from monitoring.v_new_queries_last_hour where query ILIKE ANY (ARRAY['%ORDER BY 1%',
    '%ORDER BY%'])) as "ORDER BY_GROUP BY injection"
```

**Stacked query injections** — _table_
```sql
select   distinct server , query , to_timeStamp(creation_time::bigint/1000) , avg_elapsed_time duration
from monitoring.expensive_queries where query  ILIKE ANY (ARRAY['%; DROP TABLE%', '%; EXEC xp_cmdshell%'])
```


## SQL injection - Time based blind injection

**Critical issues - SQL injection** — _gauge_
```sql
select 
    (select count(*) from monitoring.expensive_queries where query  ILIKE ANY (ARRAY['%/*%*/%', '%--%']  )) as
    "comment_based_injections",
        (select count(*) from monitoring.expensive_queries where   query   ILIKE ANY (ARRAY['%OR 1=1%', '%AND
    1=1%' , '%OR ''a''=''a%'''])) as "Boolean-based injections" ,
        (select count(*) from monitoring.expensive_queries where  query  ILIKE ANY (ARRAY['%'' OR 1=1 --''%',
    '%"" OR 1=1 --%'])) as "tautology_with_comments" ,
        (select count(*) from monitoring.expensive_queries where  query  ILIKE ANY (ARRAY['%UNION SELECT',
    '%UNION ALL SELECT%'])) as "union_based_injection" ,
        (select count(*) from monitoring.expensive_queries where  query  ILIKE ANY (ARRAY['%; DROP TABLE
    users', '%; EXEC xp_cmdshell%'])) as "stacked_queries" ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%WAITFOR DELAY%',
    '%pg_sleep%','%SLEEP%'])) as "time_based_blind _injection"   ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%CONVERT%',
    '%CAST%'])) as "error_based_injection"             ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY
    (ARRAY['%information_schema.tables%', '%information_schema.columns%','%sys.tables%','%pg_catalog%'])) as
    "information_schema_probing"                   ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%'' OR ''=''%', '%''
    OR ''x''=''x''%', '%admin''--%'])) as "Authentication bypass patterns" ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%0x414243%',
    '%CHAR(65,66,67)%'])) as "encoding injection"  ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%xp_cmdshell%',
    '%sp_executesql%'])) as "shell_system_functions injection" ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%ORDER BY 1%',
    '%ORDER BY%'])) as "ORDER BY_GROUP BY injection"
```

**Time based blind injections** — _table_
```sql
select server , query , to_timeStamp(creation_time::bigint/1000) , avg_elapsed_time duration 
FROM monitoring.expensive_queries where query  ILIKE ANY (ARRAY['%WAITFOR DELAY%', '%pg_sleep%','%SLEEP%'])
```


## SQL injection - Union based

**Critical issues - SQL injection** — _gauge_
```sql
select 
    (select count(*) from monitoring.expensive_queries where query  ILIKE ANY (ARRAY['%/*%*/%', '%--%']  )) as
    "comment_based_injections",
        (select count(*) from monitoring.expensive_queries where   query   ILIKE ANY (ARRAY['%OR 1=1%', '%AND
    1=1%' , '%OR ''a''=''a%'''])) as "Boolean-based injections" ,
        (select count(*) from monitoring.expensive_queries where  query  ILIKE ANY (ARRAY['%'' OR 1=1 --''%',
    '%"" OR 1=1 --%'])) as "tautology_with_comments" ,
        (select count(*) from monitoring.expensive_queries where  query  ILIKE ANY (ARRAY['%UNION SELECT',
    '%UNION ALL SELECT%'])) as "union_based_injection" ,
        (select count(*) from monitoring.expensive_queries where  query  ILIKE ANY (ARRAY['%; DROP TABLE
    users', '%; EXEC xp_cmdshell%'])) as "stacked_queries" ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%WAITFOR DELAY%',
    '%pg_sleep%','%SLEEP%'])) as "time_based_blind _injection"   ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%CONVERT%',
    '%CAST%'])) as "error_based_injection"             ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY
    (ARRAY['%information_schema.tables%', '%information_schema.columns%','%sys.tables%','%pg_catalog%'])) as
    "information_schema_probing"                   ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%'' OR ''=''%', '%''
    OR ''x''=''x''%', '%admin''--%'])) as "Authentication bypass patterns" ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%0x414243%',
    '%CHAR(65,66,67)%'])) as "encoding injection"  ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%xp_cmdshell%',
    '%sp_executesql%'])) as "shell_system_functions injection" ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%ORDER BY 1%',
    '%ORDER BY%'])) as "ORDER BY_GROUP BY injection"
```

**Union based injections** — _table_
```sql
select server , query , to_timeStamp(creation_time::bigint/1000) , avg_elapsed_time duration 
FROM monitoring.expensive_queries where query  ILIKE ANY (ARRAY['%UNION SELECT', '%UNION ALL SELECT%'])
```


## SQL injection - tautology with comments

**Critical issues - SQL injection** — _gauge_
```sql
select 
    (select count(*) from monitoring.expensive_queries where query  ILIKE ANY (ARRAY['%/*%*/%', '%--%']  )) as
    "comment_based_injections",
        (select count(*) from monitoring.expensive_queries where query   ILIKE ANY (ARRAY['%OR 1=1%', '%AND
    1=1%' , '%OR ''a''=''a%'''])) as "Boolean-based injections" ,
        (select count(*) from monitoring.expensive_queries where query  ILIKE ANY (ARRAY['%'' OR 1=1 --''%',
    '%"" OR 1=1 --%'])) as "tautology_with_comments" ,
        (select count(*) from monitoring.expensive_queries where query  ILIKE ANY (ARRAY['%UNION SELECT',
    '%UNION ALL SELECT%'])) as "union_based_injection" ,
        (select count(*) from monitoring.expensive_queries where query  ILIKE ANY (ARRAY['%; DROP TABLE
    users', '%; EXEC xp_cmdshell%'])) as "stacked_queries" ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%WAITFOR DELAY%',
    '%pg_sleep%','%SLEEP%'])) as "time_based_blind _injection"    ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%CONVERT%',
    '%CAST%'])) as "error_based_injection"             ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY
    (ARRAY['%information_schema.tables%', '%information_schema.columns%','%sys.tables%','%pg_catalog%'])) as
    "information_schema_probing"                   ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%'' OR ''=''%', '%''
    OR ''x''=''x''%', '%admin''--%'])) as "Authentication bypass patterns" ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%0x414243%',
    '%CHAR(65,66,67)%'])) as "encoding injection"  ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%xp_cmdshell%',
    '%sp_executesql%'])) as "shell_system_functions injection" ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%ORDER BY 1%',
    '%ORDER BY%'])) as "ORDER BY_GROUP BY injection"
```

**comment based injections** — _table_
```sql
select server , query , to_timeStamp(creation_time::bigint/1000) , avg_elapsed_time duration 
FROM monitoring.expensive_queries where query  ILIKE ANY (ARRAY['%'' OR 1=1 --''%', '%"" OR 1=1 --%'])
```


## SQL injection -Authentication Bypass

**Critical issues - SQL injection** — _gauge_
```sql
select 
    (select count(*) from monitoring.expensive_queries where query  ILIKE ANY (ARRAY['%/*%*/%', '%--%']  )) as
    "comment_based_injections",
        (select count(*) from monitoring.expensive_queries where   query   ILIKE ANY (ARRAY['%OR 1=1%', '%AND
    1=1%' , '%OR ''a''=''a%'''])) as "Boolean-based injections" ,
        (select count(*) from monitoring.expensive_queries where  query  ILIKE ANY (ARRAY['%'' OR 1=1 --''%',
    '%"" OR 1=1 --%'])) as "tautology_with_comments" ,
        (select count(*) from monitoring.expensive_queries where  query  ILIKE ANY (ARRAY['%UNION SELECT',
    '%UNION ALL SELECT%'])) as "union_based_injection" ,
        (select count(*) from monitoring.expensive_queries where  query  ILIKE ANY (ARRAY['%; DROP TABLE
    users', '%; EXEC xp_cmdshell%'])) as "stacked_queries" ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%WAITFOR DELAY%',
    '%pg_sleep%','%SLEEP%'])) as "time_based_blind _injection"   ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%CONVERT%',
    '%CAST%'])) as "error_based_injection"             ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY
    (ARRAY['%information_schema.tables%', '%information_schema.columns%','%sys.tables%','%pg_catalog%'])) as
    "information_schema_probing"                   ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%'' OR ''=''%', '%''
    OR ''x''=''x''%', '%admin''--%'])) as "Authentication bypass patterns" ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%0x414243%',
    '%CHAR(65,66,67)%'])) as "encoding injection"  ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%xp_cmdshell%',
    '%sp_executesql%'])) as "shell_system_functions injection" ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%ORDER BY 1%',
    '%ORDER BY%'])) as "ORDER BY_GROUP BY injection"
```

**Authentication bypass** — _table_
```sql
select server , query , to_timeStamp(creation_time::bigint/1000) , avg_elapsed_time duration 
FROM monitoring.expensive_queries where query  ILIKE ANY (ARRAY['%'' OR ''=''%', '%'' OR ''x''=''x''%',
    '%admin''--%'])
```


## SQL injection -Encoding

**Critical issues - SQL injection** — _gauge_
```sql
select 
    (select count(*) from monitoring.expensive_queries where query  ILIKE ANY (ARRAY['%/*%*/%', '%--%']  )) as
    "comment_based_injections",
        (select count(*) from monitoring.expensive_queries where   query   ILIKE ANY (ARRAY['%OR 1=1%', '%AND
    1=1%' , '%OR ''a''=''a%'''])) as "Boolean-based injections" ,
        (select count(*) from monitoring.expensive_queries where  query  ILIKE ANY (ARRAY['%'' OR 1=1 --''%',
    '%"" OR 1=1 --%'])) as "tautology_with_comments" ,
        (select count(*) from monitoring.expensive_queries where  query  ILIKE ANY (ARRAY['%UNION SELECT',
    '%UNION ALL SELECT%'])) as "union_based_injection" ,
        (select count(*) from monitoring.expensive_queries where  query  ILIKE ANY (ARRAY['%; DROP TABLE
    users', '%; EXEC xp_cmdshell%'])) as "stacked_queries" ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%WAITFOR DELAY%',
    '%pg_sleep%','%SLEEP%'])) as "time_based_blind _injection"   ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%CONVERT%',
    '%CAST%'])) as "error_based_injection"             ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY
    (ARRAY['%information_schema.tables%', '%information_schema.columns%','%sys.tables%','%pg_catalog%'])) as
    "information_schema_probing"                   ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%'' OR ''=''%', '%''
    OR ''x''=''x''%', '%admin''--%'])) as "Authentication bypass patterns" ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%0x414243%',
    '%CHAR(65,66,67)%'])) as "encoding injection"  ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%xp_cmdshell%',
    '%sp_executesql%'])) as "shell_system_functions injection" ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%ORDER BY 1%',
    '%ORDER BY%'])) as "ORDER BY_GROUP BY injection"
```

**Encoding injection** — _table_
```sql
select server , query , to_timeStamp(creation_time::bigint/1000) , avg_elapsed_time duration 
FROM monitoring.expensive_queries where query  ILIKE ANY (ARRAY['%0x414243%', '%CHAR(65,66,67)%'])
```


## SQL injection -Error based injection

**Critical issues - SQL injection** — _gauge_
```sql
select 
    (select count(*) from monitoring.expensive_queries where query  ILIKE ANY (ARRAY['%/*%*/%', '%--%']  )) as
    "comment_based_injections",
        (select count(*) from monitoring.expensive_queries where   query   ILIKE ANY (ARRAY['%OR 1=1%', '%AND
    1=1%' , '%OR ''a''=''a%'''])) as "Boolean-based injections" ,
        (select count(*) from monitoring.expensive_queries where  query  ILIKE ANY (ARRAY['%'' OR 1=1 --''%',
    '%"" OR 1=1 --%'])) as "tautology_with_comments" ,
        (select count(*) from monitoring.expensive_queries where  query  ILIKE ANY (ARRAY['%UNION SELECT',
    '%UNION ALL SELECT%'])) as "union_based_injection" ,
        (select count(*) from monitoring.expensive_queries where  query  ILIKE ANY (ARRAY['%; DROP TABLE
    users', '%; EXEC xp_cmdshell%'])) as "stacked_queries" ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%WAITFOR DELAY%',
    '%pg_sleep%','%SLEEP%'])) as "time_based_blind _injection"   ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%CONVERT%',
    '%CAST%'])) as "error_based_injection"             ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY
    (ARRAY['%information_schema.tables%', '%information_schema.columns%','%sys.tables%','%pg_catalog%'])) as
    "information_schema_probing"                   ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%'' OR ''=''%', '%''
    OR ''x''=''x''%', '%admin''--%'])) as "Authentication bypass patterns" ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%0x414243%',
    '%CHAR(65,66,67)%'])) as "encoding injection"  ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%xp_cmdshell%',
    '%sp_executesql%'])) as "shell_system_functions injection" ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%ORDER BY 1%',
    '%ORDER BY%'])) as "ORDER BY_GROUP BY injection"
```

**Error based injections** — _table_
```sql
select  distinct server , to_timestamp(creation_time::bigint/1000) , query  from monitoring.expensive_queries
    where query  ILIKE ANY (ARRAY['%CONVERT%', '%CAST%'])
```


## SQL injection -Shell function

**Critical issues - SQL injection** — _gauge_
```sql
select 
    (select count(*) from monitoring.expensive_queries where query  ILIKE ANY (ARRAY['%/*%*/%', '%--%']  )) as
    "comment_based_injections",
        (select count(*) from monitoring.expensive_queries where   query   ILIKE ANY (ARRAY['%OR 1=1%', '%AND
    1=1%' , '%OR ''a''=''a%'''])) as "Boolean-based injections" ,
        (select count(*) from monitoring.expensive_queries where  query  ILIKE ANY (ARRAY['%'' OR 1=1 --''%',
    '%"" OR 1=1 --%'])) as "tautology_with_comments" ,
        (select count(*) from monitoring.expensive_queries where  query  ILIKE ANY (ARRAY['%UNION SELECT',
    '%UNION ALL SELECT%'])) as "union_based_injection" ,
        (select count(*) from monitoring.expensive_queries where  query  ILIKE ANY (ARRAY['%; DROP TABLE
    users', '%; EXEC xp_cmdshell%'])) as "stacked_queries" ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%WAITFOR DELAY%',
    '%pg_sleep%','%SLEEP%'])) as "time_based_blind _injection"   ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%CONVERT%',
    '%CAST%'])) as "error_based_injection"             ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY
    (ARRAY['%information_schema.tables%', '%information_schema.columns%','%sys.tables%','%pg_catalog%'])) as
    "information_schema_probing"                   ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%'' OR ''=''%', '%''
    OR ''x''=''x''%', '%admin''--%'])) as "Authentication bypass patterns" ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%0x414243%',
    '%CHAR(65,66,67)%'])) as "encoding injection"  ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%xp_cmdshell%',
    '%sp_executesql%'])) as "shell_system_functions injection" ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%ORDER BY 1%',
    '%ORDER BY%'])) as "ORDER BY_GROUP BY injection"
```

**Shell commands** — _table_
```sql
select server , query , to_timeStamp(creation_time::bigint/1000) , avg_elapsed_time duration 
FROM monitoring.expensive_queries where query  ILIKE ANY (ARRAY['%xp_cmdshell%', '%sp_executesql%'])
```


## SQL injection -order / Group by

**Critical issues - SQL injection** — _gauge_
```sql
select 
    (select count(*) from monitoring.expensive_queries where query  ILIKE ANY (ARRAY['%/*%*/%', '%--%']  )) as
    "comment_based_injections",
        (select count(*) from monitoring.expensive_queries where   query   ILIKE ANY (ARRAY['%OR 1=1%', '%AND
    1=1%' , '%OR ''a''=''a%'''])) as "Boolean-based injections" ,
        (select count(*) from monitoring.expensive_queries where  query  ILIKE ANY (ARRAY['%'' OR 1=1 --''%',
    '%"" OR 1=1 --%'])) as "tautology_with_comments" ,
        (select count(*) from monitoring.expensive_queries where  query  ILIKE ANY (ARRAY['%UNION SELECT',
    '%UNION ALL SELECT%'])) as "union_based_injection" ,
        (select count(*) from monitoring.expensive_queries where  query  ILIKE ANY (ARRAY['%; DROP TABLE
    users', '%; EXEC xp_cmdshell%'])) as "stacked_queries" ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%WAITFOR DELAY%',
    '%pg_sleep%','%SLEEP%'])) as "time_based_blind _injection"   ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%CONVERT%',
    '%CAST%'])) as "error_based_injection"             ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY
    (ARRAY['%information_schema.tables%', '%information_schema.columns%','%sys.tables%','%pg_catalog%'])) as
    "information_schema_probing"                   ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%'' OR ''=''%', '%''
    OR ''x''=''x''%', '%admin''--%'])) as "Authentication bypass patterns" ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%0x414243%',
    '%CHAR(65,66,67)%'])) as "encoding injection"  ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%xp_cmdshell%',
    '%sp_executesql%'])) as "shell_system_functions injection" ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%ORDER BY 1%',
    '%ORDER BY%'])) as "ORDER BY_GROUP BY injection"
```

**Order / Group by** — _table_
```sql
select distinct server , query , to_timeStamp(creation_time::bigint/1000) last_request_end_time ,
    avg_elapsed_time duration
FROM monitoring.expensive_queries  where query   ILIKE ANY (ARRAY['%ORDER BY 1%', '%ORDER BY%2'])
```


## SQL injection board

**Critical issues - SQL injection** — _gauge_
```sql
select 
    (select count(*) from monitoring.expensive_queries where query  ILIKE ANY (ARRAY['%/*%*/%', '%--%']  )) as
    "comment_based_injections",
        (select count(*) from monitoring.expensive_queries where   query   ILIKE ANY (ARRAY['%OR 1=1%', '%AND
    1=1%' , '%OR ''a''=''a%'''])) as "Boolean-based injections" ,
        (select count(*) from monitoring.expensive_queries where  query  ILIKE ANY (ARRAY['%'' OR 1=1 --''%',
    '%"" OR 1=1 --%'])) as "tautology_with_comments" ,
        (select count(*) from monitoring.expensive_queries where  query  ILIKE ANY (ARRAY['%UNION SELECT',
    '%UNION ALL SELECT%'])) as "union_based_injection" ,
        (select count(*) from monitoring.expensive_queries where  query  ILIKE ANY (ARRAY['%; DROP TABLE
    users', '%; EXEC xp_cmdshell%'])) as "stacked_queries" ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%WAITFOR DELAY%',
    '%pg_sleep%','%SLEEP%'])) as "time_based_blind _injection"   ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%CONVERT%',
    '%CAST%'])) as "error_based_injection"             ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY
    (ARRAY['%information_schema.tables%', '%information_schema.columns%','%sys.tables%','%pg_catalog%'])) as
    "information_schema_probing"                   ,
        (select count(*) from monitoring.expensive_queries where query ILIKE ANY (ARRAY['%'' OR ''=''%', '%''
    OR ''x''=''x''%', '%admin''--%'])) as "Authentication bypass patterns" ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%0x414243%',
    '%CHAR(65,66,67)%'])) as "encoding injection"  ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%xp_cmdshell%',
    '%sp_executesql%'])) as "shell_system_functions injection" ,
        (select count(*) from monitoring.expensive_queries where  query ILIKE ANY (ARRAY['%ORDER BY 1%',
    '%ORDER BY%'])) as "ORDER BY_GROUP BY injection"
```

**SQL injection - Sleep time** — _table_
```sql
select sfp."server" , sfp.query , at.last_request_end_time , command , logical_reads , reads ,   writes ,
    login_name , program_name
from  monitoring.v_sql_feature_predictions sfp  
join  monitoring.active_transactions at on at.query = sfp.query
where sfp.sleep_time  is true  
limit 100;
```


## Same login active from multiple hosts

**Root causes** — _table_
```sql
select root_cause_ID ,step_name,ROOT_CAUSE_DESC   , risk_level
from 
(
select distinct rc.root_cause_ID ,rc.step_name, rc.ROOT_CAUSE_DESC   , al.risk_level
FROM  rootcause.v_rootcauses rc
join  alerts.alert_log al on al.root_cause_id = rc.root_cause_ID
where rc.root_cause_id like 'SEC-SQL-ACC-010-RC10'
and vendor_name = 'sqlserver'
)
ORDER BY CASE risk_level WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END DESC LIMIT
    20
```

**Detailed findings** — _table_
```sql
select * from monitoring.v_sec_sql_acc_010_rc10 where $__timeFilter(entry_date) and login_name
    !='dbdome_mon_usr'
```


## Scan jobs for leaks

**Jobs with Leaks** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.v_scan_jobs_for_leak
```

**Servers Affected** — _stat_
```sql
SELECT COUNT(DISTINCT server) FROM monitoring.v_scan_jobs_for_leak
```

**Security Findings** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.general_metric_metadata_results WHERE metric_name LIKE 'SEC-SQL%%' AND
    (metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(entry_date)
```

**Alerts Sent** — _stat_
```sql
SELECT COUNT(*) FROM alerts.mail_alert_log WHERE $__timeFilter(entry_date)
```

**Leaked Jobs by Server** — _barchart_
```sql
SELECT server, COUNT(*) AS leaks FROM monitoring.v_scan_jobs_for_leak GROUP BY server ORDER BY leaks DESC
```

**Sensitivity Issues by Server** — _bargauge_
```sql
SELECT server, COUNT(*) AS issues FROM monitoring.sql_feature_predictions WHERE $__timeFilter(entry_date)
    GROUP BY server ORDER BY issues DESC LIMIT 10
```

**Scanned Jobs for Leaks** — _table_
```sql
SELECT * FROM monitoring.v_scan_jobs_for_leak
```

**SQL Injection Analysis** — _barchart_
```sql
SELECT COALESCE(rc.name, gm.metric_name) AS type, COUNT(*) AS count FROM
    monitoring.general_metric_metadata_results gm LEFT JOIN rootcause.root_causes rc ON rc.root_cause_id =
    gm.metric_name WHERE gm.metric_name LIKE 'SEC-SQL-INJ%%' AND
    (gm.metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(gm.entry_date) GROUP
    BY type ORDER BY count DESC LIMIT 10
```

**Data Activity (Transactions/hour)** — _barchart_
```sql
SELECT server, COUNT(*) AS transactions FROM monitoring.active_transactions WHERE last_request_end_time >
    NOW() - INTERVAL '1 hour' GROUP BY server ORDER BY transactions DESC
```


## Security Issues Explorer

**Security hierarchy — click a root cause to filter alerts** — _table_
```sql
SELECT
  COALESCE(
    (SELECT ds.expected->>'severity'
       FROM rootcause.detection_paths dp
       JOIN rootcause.detection_path_steps dps
         ON dps.detection_path_id = dp.id AND dps.sequence = 1
       JOIN rootcause.detection_steps ds
         ON ds.id = dps.detection_step_id
      WHERE dp.root_cause_id = rc.root_cause_id
        AND dp.is_active = true
      LIMIT 1),
    'medium'
  ) AS risk_level,
  d.name   AS domain_name,
  a.name   AS area_name,
  i.name   AS issue_name,
  rc.root_cause_id,
  rc.name  AS root_cause_name,
  rc.description AS root_cause_desc
FROM rootcause.root_causes rc
JOIN rootcause.issues   i ON i.issue_id = rc.issue_id
JOIN rootcause.areas    a ON a.code = i.area_code AND a.database_type_code = i.database_type_code
JOIN rootcause.domains  d ON d.code = i.domain_code
WHERE d.code = 'SEC'
ORDER BY risk_level, domain_name, area_name, issue_name, rc.name
```

**Alerts for selected root cause — ${rc}** — _table_
```sql
SELECT
  mal.entry_date,
  mal.server,
  mal.metric_name AS root_cause_id,
  rc.name         AS root_cause_name,
  mal.transaction_type,
  mal.subject,
  mal.recipients
FROM alerts.mail_alert_log mal
LEFT JOIN rootcause.root_causes rc ON rc.root_cause_id = mal.metric_name
WHERE ('${rc:raw}' = '' OR mal.metric_name = '${rc:raw}')
ORDER BY mal.entry_date DESC
LIMIT 500
```


## Send report by mail

**(untitled panel)** — _table_
```sql
select distinct server  from monitoring.v_combined_transactions
```

**(untitled panel)** — _table_
```sql
select distinct  TO_CHAR(last_request_end_time, 'YYYY-MM-DD') AS "start time" from
    monitoring.v_combined_transactions
order by TO_CHAR(last_request_end_time, 'YYYY-MM-DD')
```

**(untitled panel)** — _table_
```sql
select distinct  TO_CHAR(last_request_end_time, 'YYYY-MM-DD') AS "end time" from
    monitoring.v_combined_transactions
```


## Sensitive Columns Explorer

**Servers (sensitive columns)** — _table_
```sql
SELECT server, count(DISTINCT db_name) AS databases, count(*) AS sensitive_columns FROM
    monitoring.v_sec_sql_pri_001_rc12 GROUP BY server ORDER BY server
```

**Databases on ${srv}** — _table_
```sql
SELECT db_name, count(DISTINCT table_schema||'.'||table_name) AS tables, count(*) AS columns FROM
    monitoring.v_sec_sql_pri_001_rc12 WHERE (NULLIF('${srv}','') IS NULL OR server='${srv}') GROUP BY db_name
    ORDER BY db_name
```

**Sensitive columns - ${srv} / ${db}** — _table_
```sql
SELECT distinct server, db_name, table_schema, table_name, column_name, data_type, pii_category, max_length,
    '+ track' AS track, '🛡 mask' AS mask, '🔐 encrypt' AS encrypt, '↩ revert' AS revert FROM
    monitoring.v_sec_sql_pri_001_rc12 WHERE (NULLIF('${srv}','') IS NULL OR server='${srv}') AND
    (NULLIF('${db}','') IS NULL OR db_name='${db}') ORDER BY db_name, table_schema, table_name, column_name
    LIMIT 2000
```

**Column details - ${dtbl}.${dcol}** — _table_
```sql
SELECT j.value AS result FROM
    jsonb_array_elements(COALESCE(monitoring.get_root_cause_resultset('SEC-SQL-PRI-001-RC12',
    $__timeFrom())::jsonb,'[]'::jsonb)) j WHERE (NULLIF('${srv}','') IS NULL OR j.value->>'server'='${srv}')
    AND (NULLIF('${db}','') IS NULL OR j.value->>'db_name'='${db}') AND (NULLIF('${dsch}','') IS NULL OR
    j.value->>'schema_name'='${dsch}') AND (NULLIF('${dtbl}','') IS NULL OR j.value->>'table_name'='${dtbl}')
    AND (NULLIF('${dcol}','') IS NULL OR j.value->>'column_name'='${dcol}') LIMIT 500
```

**Tracked sensitive columns (metrics.sensitive_columns)** — _table_
```sql
SELECT server, db_name, schema_name, table_name, column_name, pii_category, entry_date AT TIME ZONE
    'Asia/Jerusalem' AS entry_date FROM metrics.sensitive_columns ORDER BY entry_date DESC LIMIT 500
```

**Masking activity (metrics.masking_log)** — _table_
```sql
SELECT entry_date AT TIME ZONE 'Asia/Jerusalem' AS time, server, db_name,
       schema_name||'.'||table_name||'.'||column_name AS column, mask_function, action, detail
FROM metrics.masking_log
WHERE (NULLIF('${srv}','') IS NULL OR server='${srv}')
ORDER BY log_id DESC LIMIT 200
```

**Masked data preview - real vs masked (as test user)** — _table_
```sql
SELECT server, db_name, schema_name||'.'||table_name AS "table", column_name AS "column",
       row_no, real_value AS "real (privileged)", masked_value AS "masked (test user)"
FROM metrics.mask_preview
WHERE (NULLIF('${srv}','') IS NULL OR server='${srv}')
  AND (NULLIF('${db}','') IS NULL OR db_name='${db}')
ORDER BY entry_date DESC, schema_name, table_name, column_name, row_no LIMIT 500
```

**Print (filtered view)** — _table_
```sql
SELECT '🖨  Print this filtered view (opens clean tab -> Ctrl+P / Save as PDF)' AS print
```

**Encryption activity (metrics.encryption_log)** — _table_
```sql
SELECT entry_date AT TIME ZONE 'Asia/Jerusalem' AS time, server, db_name,
       schema_name||'.'||table_name||coalesce('.'||nullif(column_name,''),'') AS object, action, detail
FROM metrics.encryption_log
WHERE (NULLIF('${srv}','') IS NULL OR server='${srv}')
ORDER BY log_id DESC LIMIT 200
```

**Tokenized data preview - original vs token** — _table_
```sql
SELECT schema_name||'.'||table_name AS "table", column_name AS "column",
       row_no, original_value, token_value
FROM metrics.encryption_preview
WHERE (NULLIF('${srv}','') IS NULL OR server='${srv}')
  AND (NULLIF('${db}','') IS NULL OR db_name='${db}')
ORDER BY entry_date DESC, table_name, column_name, row_no LIMIT 500
```


## Sensitivity report

**Sensitive data (PII)** — _table_
```sql
select at.server , at.query , last_request_end_time, c.column_name , c.table_name from
    monitoring.v_combined_transactions at
join(
select TABLE_NAME ,  column_name from monitoring.v_sensitive_columns 
) c on at.query like '%'||c.column_name ||'%'
and last_request_end_time > Now() - interval '15 minutes'
```

**(untitled panel)** — _table_
```sql
select  distinct server  from monitoring.v_combined_transactions
```

**(untitled panel)** — _table_
```sql
select distinct  TO_CHAR(last_request_end_time, 'YYYY-MM-DD') AS "start time" from
    monitoring.v_combined_transactions
order by TO_CHAR(last_request_end_time, 'YYYY-MM-DD')
```

**(untitled panel)** — _table_
```sql
select distinct  TO_CHAR(last_request_end_time, 'YYYY-MM-DD') AS "end time" from
    monitoring.v_combined_transactions
```

**Sensitive columns and schema (PII)** — _table_
```sql
select * from monitoring.v_sensitive_columns
```
```sql
select server , tables ,  columns , query   from (
select row_number() over ( partition by query order by p.entry_date desc ) seq , p.server , susp."tables" ,
    susp."columns" , susp.query from monitoring.sql_suspicious susp
join monitoring.sensitive_schema  sc on susp.query like '%'||sc.column_name ||'%'
join monitoring.sql_feature_predictions p on p.query_id = susp.query_id
) a where seq=1
```
```sql
select server , table_name , column_name ,columns , query   
from 
(
select row_number() over ( partition by query order by p.entry_date desc ) seq  , p.server , sc.table_name ,
    sc.column_name ,columns , p.condition , joins , func , p.query   from monitoring.metric_query_parsing   p
join monitoring.sensitive_schema  sc on p.query like '%'||sc.column_name ||'%'
) where seq = 1
```


## Stored procedure slower than its average

**Root causes** — _table_
```sql
select root_cause_ID ,step_name,ROOT_CAUSE_DESC   , risk_level
from 
(
select distinct rc.root_cause_ID ,rc.step_name, rc.ROOT_CAUSE_DESC   , al.risk_level
FROM  rootcause.v_rootcauses rc
join  alerts.alert_log al on al.root_cause_id = rc.root_cause_ID
where rc.root_cause_id like 'SEC-SQL-ACC-011%'
and vendor_name = 'sqlserver'
)
ORDER BY CASE risk_level WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END DESC LIMIT
    20
```

**Detailed findings** — _table_
```sql
select * from monitoring.v_SEC_SQL_ACC_011_RC02 
order by entry_date desc 
limit 100
```

**Root cause details - ${root_cause_id}** — _table_
```sql
SELECT j.value AS result
FROM jsonb_array_elements(
  COALESCE(monitoring.get_root_cause_resultset(NULLIF('${root_cause_id}',''), $__timeFrom())::jsonb,
    '[]'::jsonb)
) AS j
LIMIT 500
```


## Super users (sysadmin / sysDBA)

**SYSADMIN / SYSDBA** — _barchart_
```sql
select count(*) , server from monitoring.v_mssql_superuser  where login_name != 'infosecuser'
group by server
```

**Active users** — _bargauge_
```sql
select sum("Number of connections") from 
(
select count(*) "Number of connections" from monitoring.tcp_connections where connect_time between Now() -
    interval '1 minute' and Now()
union all
select count(*) from monitoring.v_oracle_transactions where entry_date > Now() - interval '1 minute'
)
```

**(untitled panel)** — _table_
```sql
select distinct server  from monitoring.v_sysadmin
```

**Recent alerts** — _stat_
```sql
select 
    (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query  ILIKE ANY (ARRAY['%/*%*/%', '%--%']  )) as "comment_based_injections",
        (select count(*) from monitoring.active_transactions where  LAST_request_end_time > Now() - interval
    '1 minute' and query   ILIKE ANY (ARRAY['%OR 1=1%', '%AND 1=1%' , '%OR ''a''=''a%'''])) as "Boolean-based
    injections" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query  ILIKE ANY (ARRAY['%'' OR 1=1 --''%', '%"" OR 1=1 --%'])) as "tautology_with_comments" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query  ILIKE ANY (ARRAY['%UNION SELECT', '%UNION ALL SELECT%'])) as "union_based_injection" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query  ILIKE ANY (ARRAY['%; DROP TABLE users', '%; EXEC xp_cmdshell%'])) as "stacked_queries"
    ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%WAITFOR DELAY%', '%pg_sleep%','%SLEEP%'])) as "time_based_blind
    _injection"          ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%CONVERT%', '%CAST%'])) as "error_based_injection"           ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%information_schema.tables%',
    '%information_schema.columns%','%sys.tables%','%pg_catalog%'])) as "information_schema_probing"
    ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%'' OR ''=''%', '%'' OR ''x''=''x''%', '%admin''--%'])) as
    "Authentication bypass patterns" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%0x414243%', '%CHAR(65,66,67)%'])) as "encoding injection"  ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%xp_cmdshell%', '%sp_executesql%'])) as "shell_system_functions
    injection" ,
        (select count(*) from monitoring.active_transactions where LAST_request_end_time > Now() - interval '1
    minute' and query ILIKE ANY (ARRAY['%ORDER BY 1%', '%ORDER BY%'])) as "ORDER BY_GROUP BY injection"
from monitoring.active_transactions
group by server
```

**Credentials stored in database tables** — _table_
```sql
select * from monitoring.v_mssql_superuser  where login_name != 'infosecuser'
```


## Take Action

**Critical issues - SQL injection** — _gauge_
```sql
SELECT
    SUM(CASE WHEN dangerous_function = TRUE THEN 1 ELSE 0 END) AS dangerous_function,
    SUM(CASE WHEN sleep_time = TRUE THEN 1 ELSE 0 END) AS sleep_time , 
	SUM(CASE WHEN boolean_sqli = TRUE THEN 1 ELSE 0 END) AS boolean_sqli	 , 
	SUM(CASE WHEN long_literal = TRUE THEN 1 ELSE 0 END) AS long_literal	 , 
	SUM(CASE WHEN outfile_copy = TRUE THEN 1 ELSE 0 END) AS outfile_copy	 , 
	SUM(CASE WHEN union_select = TRUE THEN 1 ELSE 0 END) AS union_select	  , 
	SUM(CASE WHEN schema_access = TRUE THEN 1 ELSE 0 END) AS schema_access	  , 
	SUM(CASE WHEN stacked_query = TRUE THEN 1 ELSE 0 END) AS stacked_query	  , 
	SUM(CASE WHEN commented_payload = TRUE THEN 1 ELSE 0 END) AS commented_payload	  , 
	SUM(CASE WHEN sensitive_columns = TRUE THEN 1 ELSE 0 END) AS sensitive_columns	  	
FROM monitoring.v_sql_feature_predictions;
```

**Active threats** — _gauge_
```sql
select count(*) "suspicious queries" from monitoring.v_suspiscous
```

**Active users** — _bargauge_
```sql
select count(*) from monitoring.tcp_connections where connect_time between Now - interval '1 month' and Now()
```

**Take action** — _table_
```sql
select row_id , action_name, action_description, server, case when is_active  = true then 'Enabled' else
    'disabled' end  Enabled  from config.action_types
where  server != 'unknown'
order by server , action_name
```

**Recent alerts** — _stat_
```sql
select 
    SUM(CASE WHEN dangerous_function = TRUE THEN 1 ELSE 0 END) AS dangerous_function,
    SUM(CASE WHEN sleep_time = TRUE THEN 1 ELSE 0 END) AS sleep_time , 
	SUM(CASE WHEN boolean_sqli = TRUE THEN 1 ELSE 0 END) AS boolean_sqli	 , 
	SUM(CASE WHEN long_literal = TRUE THEN 1 ELSE 0 END) AS long_literal	 , 
	SUM(CASE WHEN outfile_copy = TRUE THEN 1 ELSE 0 END) AS outfile_copy	 , 
	SUM(CASE WHEN union_select = TRUE THEN 1 ELSE 0 END) AS union_select	  , 
	SUM(CASE WHEN schema_access = TRUE THEN 1 ELSE 0 END) AS schema_access	  , 
	SUM(CASE WHEN stacked_query = TRUE THEN 1 ELSE 0 END) AS stacked_query	  , 
	SUM(CASE WHEN commented_payload = TRUE THEN 1 ELSE 0 END) AS commented_payload	  , 
	SUM(CASE WHEN sensitive_columns = TRUE THEN 1 ELSE 0 END) AS sensitive_columns	  	
FROM monitoring.v_sql_feature_predictions
```

**Sensitivity reports** — _barchart_
```sql
SELECT server , 
 	count(*) "Number of sensitivity issues"
   FROM ( SELECT query_id , entry_date  , server , (sql_feature_predictions.features ->> 'query'::text) AS
    query,
            ((sql_feature_predictions.features ->> 'sensitive_columns'::text))::boolean AS sensitive_columns
           FROM monitoring.sql_feature_predictions) a
  left outer join monitoring.sql_suspicious susp on susp.query_id = a.query_id
  WHERE (sensitive_columns IS TRUE) 
   group by server
```

**SQL Injection analysis** — _barchart_
```sql
SELECT SERVER , 
    SUM(CASE WHEN dangerous_function = TRUE THEN 1 ELSE 0 END) AS dangerous_function,
    SUM(CASE WHEN sleep_time = TRUE THEN 1 ELSE 0 END) AS sleep_time , 
	SUM(CASE WHEN boolean_sqli = TRUE THEN 1 ELSE 0 END) AS "boolean Injection"	 , 
	SUM(CASE WHEN outfile_copy = TRUE THEN 1 ELSE 0 END) AS "copy injections"	 , 
	SUM(CASE WHEN union_select = TRUE THEN 1 ELSE 0 END) AS "union_select	injections"  , 
	SUM(CASE WHEN commented_payload = TRUE THEN 1 ELSE 0 END) AS commented_payload	  	
FROM monitoring.v_sql_feature_predictions GROUP BY SERVER
```

**Data activity monitoring** — _barchart_
```sql
select count(*) , server   from monitoring.active_transactions
where  last_request_end_time > Now() - interval '1 hour'
group by server
```

**Connectivity reports** — _barchart_
```sql
select count(*) , server ,client_net_address from monitoring.tcp_connections
where connect_Time > Now()   - interval '1 hour'
group by server ,client_net_address
```


## Transaction report

**(untitled panel)** — _table_
```sql
select distinct server  from monitoring.v_blocking_transactions
```

**(untitled panel)** — _table_
```sql
select   TO_CHAR(to_timestamp(start_time::bigint / 1000 ), 'YYYY-MM-DD') AS "start time" from
    monitoring.v_blocking_transactions
order by TO_CHAR(to_timestamp(start_time::bigint / 1000 ), 'YYYY-MM-DD') limit 	 1
```

**(untitled panel)** — _table_
```sql
select   TO_CHAR(to_timestamp(start_time::bigint / 1000 ), 'YYYY-MM-DD') AS "start time" from
    monitoring.v_blocking_transactions
order by TO_CHAR(to_timestamp(start_time::bigint / 1000 ), 'YYYY-MM-DD') limit 	 1
```

**Transactions** — _table_
```sql
select * from monitoring.v_combined_transactions  WHERE $__timeFilter(last_request_end_time)  order by
    last_request_end_time desc
```
```sql
select 
    SUM(CASE WHEN dangerous_function = TRUE THEN 1 ELSE 0 END)  + 
    SUM(CASE WHEN sleep_time = TRUE THEN 1 ELSE 0 END)  + 
	SUM(CASE WHEN boolean_sqli = TRUE THEN 1 ELSE 0 END)+
	SUM(CASE WHEN long_literal = TRUE THEN 1 ELSE 0 END)+
	SUM(CASE WHEN outfile_copy = TRUE THEN 1 ELSE 0 END)+ 
	SUM(CASE WHEN union_select = TRUE THEN 1 ELSE 0 END)+ 
	SUM(CASE WHEN schema_access = TRUE THEN 1 ELSE 0 END) + 
	SUM(CASE WHEN stacked_query = TRUE THEN 1 ELSE 0 END) + 
	SUM(CASE WHEN commented_payload = TRUE THEN 1 ELSE 0 END) +
	SUM(CASE WHEN sensitive_columns = TRUE THEN 1 ELSE 0 END) "Active threats"
FROM monitoring.v_sql_feature_predictions
```

**Sensitivity reports** — _barchart_
```sql
SELECT server , 
 	count(*) "Number of sensitivity issues"
   FROM ( SELECT query_id , entry_date  , server , (sql_feature_predictions.features ->> 'query'::text) AS
    query,
            ((sql_feature_predictions.features ->> 'sensitive_columns'::text))::boolean AS sensitive_columns
           FROM monitoring.sql_feature_predictions) a
  left outer join monitoring.sql_suspicious susp on susp.query_id = a.query_id
  WHERE (sensitive_columns IS TRUE) 
   group by server
```

**SQL Injection analysis** — _barchart_
```sql
SELECT SERVER , 
    SUM(CASE WHEN dangerous_function = TRUE THEN 1 ELSE 0 END) AS dangerous_function,
    SUM(CASE WHEN sleep_time = TRUE THEN 1 ELSE 0 END) AS sleep_time , 
	SUM(CASE WHEN boolean_sqli = TRUE THEN 1 ELSE 0 END) AS "boolean Injection"	 , 
	SUM(CASE WHEN outfile_copy = TRUE THEN 1 ELSE 0 END) AS "copy injections"	 , 
	SUM(CASE WHEN union_select = TRUE THEN 1 ELSE 0 END) AS "union_select	injections"  , 
	SUM(CASE WHEN commented_payload = TRUE THEN 1 ELSE 0 END) AS commented_payload	  	
FROM monitoring.v_sql_feature_predictions GROUP BY SERVER
```

**Data activity monitoring** — _barchart_
```sql
select count(*) , server   from monitoring.active_transactions
where  last_request_end_time > Now() - interval '1 hour'
group by server
```

**Connectivity reports** — _barchart_
```sql
select count(*) , server ,client_net_address from monitoring.tcp_connections
where connect_Time > Now()   - interval '1 hour'
group by server ,client_net_address
```


## Vulnerability

**SQL Injections** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.general_metric_metadata_results WHERE metric_name LIKE 'SEC-SQL-INJ%%' AND
    (metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(entry_date)
```

**Suspicious Queries** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.general_metric_metadata_results WHERE metric_name LIKE
    'SEC-SQL-ACC-010-RC04%%' AND (metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND
    $__timeFilter(entry_date)
```

**Config Vulnerabilities** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.general_metric_metadata_results WHERE metric_name LIKE 'SEC-SQL-CFG%%' AND
    (metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(entry_date)
```

**Active Users** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.tcp_connections WHERE $__timeFilter(connect_time)
```

**Total Findings** — _stat_
```sql
SELECT COUNT(*) FROM monitoring.general_metric_metadata_results WHERE metric_name LIKE 'SEC-SQL%%' AND
    (metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND $__timeFilter(entry_date)
```

**Vulnerability by Issue Type** — _barchart_
```sql
SELECT COALESCE(i.name, gm.metric_name) AS issue, COUNT(*) AS findings FROM
    monitoring.general_metric_metadata_results gm LEFT JOIN rootcause.root_causes rc ON rc.root_cause_id =
    gm.metric_name LEFT JOIN rootcause.issues i ON i.issue_id = rc.issue_id WHERE gm.metric_name LIKE
    'SEC-SQL%%' AND (gm.metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND
    $__timeFilter(gm.entry_date) GROUP BY issue ORDER BY findings DESC LIMIT 15
```

**By Security Area** — _piechart_
```sql
SELECT COALESCE(a.name, 'Unknown') AS area, COUNT(*) AS count FROM monitoring.general_metric_metadata_results
    gm LEFT JOIN rootcause.root_causes rc ON rc.root_cause_id = gm.metric_name LEFT JOIN rootcause.issues i ON
    i.issue_id = rc.issue_id LEFT JOIN rootcause.areas a ON a.code = i.area_code WHERE gm.metric_name LIKE
    'SEC-SQL%%' AND (gm.metric_metadata_vs_expected::jsonb->>'matched')::text = 'true' AND
    $__timeFilter(gm.entry_date) GROUP BY area ORDER BY count DESC
```

**Security Vulnerability Findings** — _table_
```sql
SELECT gm.server, COALESCE(a.name, '') AS area, COALESCE(i.name, '') AS issue, gm.metric_name AS
    root_cause_id, COALESCE(rc.name, gm.metric_name) AS root_cause,
    (gm.metric_metadata_vs_expected::jsonb->>'row_count')::int AS rows,
    COALESCE(gm.metric_metadata_vs_expected::jsonb->>'severity', 'medium') AS severity,
    (gm.metric_metadata_vs_expected::jsonb->'expected'->>'description') AS description, gm.entry_date AT TIME
    ZONE 'Asia/Jerusalem' AS detected_at FROM monitoring.general_metric_metadata_results gm LEFT JOIN
    rootcause.root_causes rc ON rc.root_cause_id = gm.metric_name LEFT JOIN rootcause.issues i ON i.issue_id =
    rc.issue_id LEFT JOIN rootcause.areas a ON a.code = i.area_code WHERE gm.metric_name LIKE 'SEC-SQL%%' AND
    gm.metric_metadata_vs_expected IS NOT NULL AND (gm.metric_metadata_vs_expected::jsonb->>'matched')::text =
    'true' AND $__timeFilter(gm.entry_date) ORDER BY gm.entry_date DESC LIMIT 100
```

**SQL Injection by Server** — _barchart_
```sql
SELECT gm.server, COUNT(*) AS injections FROM monitoring.general_metric_metadata_results gm WHERE
    gm.metric_name LIKE 'SEC-SQL-INJ%%' AND (gm.metric_metadata_vs_expected::jsonb->>'matched')::text = 'true'
    AND $__timeFilter(gm.entry_date) GROUP BY gm.server ORDER BY injections DESC LIMIT 10
```

**Connectivity by Server** — _barchart_
```sql
SELECT server || ' <- ' || client_net_address AS client, COUNT(*) AS connections FROM
    monitoring.tcp_connections WHERE $__timeFilter(connect_time) GROUP BY server, client_net_address ORDER BY
    connections DESC LIMIT 10
```


## Webhook Alerts Configuration

**Webhook Alerts - click a true/false cell to toggle** — _table_
```sql
SELECT row_id, metric_type, risk_level, send_mail_alert, send_siem_alert, send_diagnosis_evidence, blocker,
    auto_mask, is_active, recurrency_hours, (NOT send_mail_alert) AS mail_next, (NOT send_siem_alert) AS
    siem_next, (NOT send_diagnosis_evidence) AS diag_next, (NOT blocker) AS blocker_next, (NOT auto_mask) AS
    auto_mask_next, (NOT is_active) AS active_next FROM config.webook_alerts ORDER BY metric_type, risk_level
```

**Blocker global dry-run (true = log only, false = ARMED to kill)** — _table_
```sql
SELECT value AS blocker_dry_run, CASE WHEN value='true' THEN 'false' ELSE 'true' END AS next_val FROM
    config.global_params WHERE key='blocker_dry_run' ORDER BY row_id DESC LIMIT 1
```

**Masking global dry-run (true = log only, false = ARMED to apply masks)** — _table_
```sql
SELECT value AS masking_dry_run, CASE WHEN value='true' THEN 'false' ELSE 'true' END AS next_val FROM
    config.global_params WHERE key='masking_dry_run' ORDER BY row_id DESC LIMIT 1
```


## alert_report

**Open Alerts** — _nodeGraph_
```sql
select * from flowchart.v_sources_alerts
```

**Open Alerts** — _table_
```sql
SELECT server , root_cause , query , entry_date
FROM monitoring.alerts_open
WHERE state = 'open'
```


## alert_report_Error_Based

**Open Alerts** — _nodeGraph_
```sql
select * from flowchart.v_sources_alerts
```

**Open Alerts** — _table_
```sql
SELECT server , root_cause , query , entry_date
FROM monitoring.alerts_open
WHERE state = 'open'
and root_cause = 'Error-Based Injection (MSSQL-style)'
```


## alert_report_Privilege_Escalation_Chain

**Open Alerts** — _nodeGraph_
```sql
select * from flowchart.v_sources_alerts
```

**Open Alerts** — _table_
```sql
SELECT server , root_cause , query , entry_date
FROM monitoring.alerts_open
WHERE state = 'open'
```


## alert_report_Stacked

**Open Alerts** — _nodeGraph_
```sql
select * from flowchart.v_sources_alerts
```

**Open Alerts** — _table_
```sql
SELECT server , root_cause , query , entry_date
FROM monitoring.alerts_open
WHERE state = 'open'
and root_cause = 'Stacked Queries (Very MSSQL-Specific)'
```


## alert_report_sensitive_schema

**Open Alerts** — _nodeGraph_
```sql
select * from flowchart.v_sources_alerts
```

**Sensitive columns and schema (PII)** — _table_
```sql
select distinct server ,  table_catalog , table_name , column_name entdtry_date  from monitoring.schema
```
```sql
select  susp.server, duration_secs, last_request_end_time, command, program_name, query  from
    monitoring.v_combined_transactions susp
join monitoring.sensitive_schema  sc on susp.query like '%'||sc.column_name ||'%'  
where last_request_end_time > $__timeFrom(last_request_end_time)
```
```sql
select server , table_name , column_name ,columns , query   
from 
(
select row_number() over ( partition by query order by p.entry_date desc ) seq  , p.server , sc.table_name ,
    sc.column_name ,columns , p.condition , joins , func , p.query   from monitoring.metric_query_parsing   p
join monitoring.sensitive_schema  sc on p.query like '%'||sc.column_name ||'%'
) where seq = 1
```

**Sensitive data (PII)** — _table_
```sql
select*  from monitoring.v_sensitive_data_inuse where $__timeFilter(last_request_end_time)
```


## risk level alerts

**Risk level alerts** — _table_
```sql
select  distinct rc.issue_name , rc.root_cause_name , rc.Risk_level , rl.is_active  from
    rootcause.v_rootcauses rc
	join rootcause.risk_level 	rl on  rl.risk_level = rc.risk_level	
	and domain_code = 'SEC'
```

**Risk Levels** — _table_
```sql
SELECT row_id, trim(risk_level) AS risk_level, is_active FROM rootcause.risk_level ORDER BY row_id
```


## sysadmin accounts with weak password enforcement

**sysadmin accounts with weak password enforcement** — _barchart_
```sql
select server , count(*) lock_date from monitoring.v_sysadmin_accounts_with_weakpassword_enforcement
group by server
```

**(untitled panel)** — _table_
```sql
select distinct server  from monitoring.v_sysadmin_accounts_with_weakpassword_enforcement
```

**sysadmin accounts with weak password enforcement** — _table_
```sql
select  * from monitoring.v_sysadmin_accounts_with_weakpassword_enforcement
```

**Sensitivity reports** — _barchart_
```sql
SELECT server , 
 	count(*) "Number of sensitivity issues"
   FROM ( SELECT query_id , entry_date  , server , (sql_feature_predictions.features ->> 'query'::text) AS
    query,
            ((sql_feature_predictions.features ->> 'sensitive_columns'::text))::boolean AS sensitive_columns
           FROM monitoring.sql_feature_predictions) a
  left outer join monitoring.sql_suspicious susp on susp.query_id = a.query_id
  WHERE (sensitive_columns IS TRUE) 
   group by server
```

**SQL Injection analysis** — _barchart_
```sql
SELECT SERVER , 
    SUM(CASE WHEN dangerous_function = TRUE THEN 1 ELSE 0 END) AS dangerous_function,
    SUM(CASE WHEN sleep_time = TRUE THEN 1 ELSE 0 END) AS sleep_time , 
	SUM(CASE WHEN boolean_sqli = TRUE THEN 1 ELSE 0 END) AS "boolean Injection"	 , 
	SUM(CASE WHEN outfile_copy = TRUE THEN 1 ELSE 0 END) AS "copy injections"	 , 
	SUM(CASE WHEN union_select = TRUE THEN 1 ELSE 0 END) AS "union_select	injections"  , 
	SUM(CASE WHEN commented_payload = TRUE THEN 1 ELSE 0 END) AS commented_payload	  	
FROM monitoring.v_sql_feature_predictions GROUP BY SERVER
```

**Data activity monitoring** — _barchart_
```sql
select count(*) , server   from monitoring.active_transactions
where  last_request_end_time > Now() - interval '1 hour'
group by server
```


## webhook alerts

**web hook alerts** — _table_
```sql
SELECT row_id, metric_type, send_mail_alert, send_siem_alert, send_diagnosis_evidence FROM
    config.webook_alerts ORDER BY metric_type
```

