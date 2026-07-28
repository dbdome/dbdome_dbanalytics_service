-- =============================================================================
-- SEC-SQL-ACC-010-RC07 — After-hours transaction activity
-- Reduce FALSE POSITIVES: exclude APPLICATIVE (application/service) accounts.
-- =============================================================================
-- Rationale: applications/service accounts legitimately run transactions 24x7,
-- so after-hours activity from them is normal. Only human/interactive (or
-- unexpected) logins after hours are of interest. Each vendor query now filters
-- out service accounts + an editable list of YOUR application logins.
--
-- >>> EDIT REQUIRED: replace the placeholder logins
--     ('app_user','svc_app','etl_service' / uppercase variants) with your real
--     application/service account names, then re-run this script. <<<
--
-- The query runs on the monitored server, so the exclusion must be expressed
-- in-query (no cross-DB whitelist available). Run on dbanalytics PG (5432).
-- Idempotent: each UPDATE sets the full canonical SQL.
-- =============================================================================

BEGIN;

-- 1. SQL Server (12121) — exclude sa, internal (##), machine ($) and app logins
UPDATE rootcause.detection_steps
SET content = '{"sql": "SELECT s.session_id, s.login_name, s.host_name, s.program_name, t.transaction_id, tat.transaction_begin_time, DATEDIFF(SECOND, tat.transaction_begin_time, GETDATE()) AS duration_seconds, DATEPART(HOUR, tat.transaction_begin_time) AS start_hour FROM sys.dm_exec_sessions s JOIN sys.dm_tran_session_transactions t ON t.session_id = s.session_id JOIN sys.dm_tran_active_transactions tat ON tat.transaction_id = t.transaction_id WHERE s.is_user_process = 1 AND (DATEPART(HOUR, tat.transaction_begin_time) < 7 OR DATEPART(HOUR, tat.transaction_begin_time) >= 19) AND s.login_name NOT IN (''sa'', ''app_user'', ''svc_app'', ''etl_service'') AND s.login_name NOT LIKE ''##%'' AND s.login_name NOT LIKE ''%$'' ORDER BY tat.transaction_begin_time"}'::jsonb,
    expected = '{"condition": "row_count > 0", "description": "Active transactions started outside business hours (before 07:00 or after 19:00) by a non-applicative login may indicate unauthorized or suspicious activity"}'::jsonb
WHERE id = 12121;

-- 2. Oracle (12149)
UPDATE rootcause.detection_steps
SET content = '{"sql": "SELECT s.sid, s.serial#, s.username, s.osuser, s.machine, s.program, t.start_time, ROUND((SYSDATE - TO_DATE(t.start_time, ''MM/DD/YY HH24:MI:SS'')) * 86400) AS duration_seconds, TO_NUMBER(TO_CHAR(TO_DATE(t.start_time, ''MM/DD/YY HH24:MI:SS''), ''HH24'')) AS start_hour FROM v$session s JOIN v$transaction t ON t.ses_addr = s.saddr WHERE s.type = ''USER'' AND (TO_NUMBER(TO_CHAR(TO_DATE(t.start_time, ''MM/DD/YY HH24:MI:SS''), ''HH24'')) < 7 OR TO_NUMBER(TO_CHAR(TO_DATE(t.start_time, ''MM/DD/YY HH24:MI:SS''), ''HH24'')) >= 19) AND UPPER(s.username) NOT IN (''SYS'',''SYSTEM'',''DBSNMP'',''SYSMAN'',''XDB'',''GSMADMIN_INTERNAL'',''APP_USER'',''SVC_APP'',''ETL_SERVICE'') ORDER BY t.start_time"}'::jsonb,
    expected = '{"condition": "row_count > 0", "description": "Active transactions started outside business hours (before 07:00 or after 19:00) by a non-applicative login may indicate unauthorized or suspicious activity"}'::jsonb
WHERE id = 12149;

-- 3. PostgreSQL (12135)
UPDATE rootcause.detection_steps
SET content = '{"sql": "SELECT pid, usename, client_addr, application_name, backend_start, xact_start, EXTRACT(EPOCH FROM (now() - xact_start))::int AS duration_seconds, EXTRACT(HOUR FROM xact_start)::int AS start_hour, state, query FROM pg_stat_activity WHERE xact_start IS NOT NULL AND backend_type = ''client backend'' AND (EXTRACT(HOUR FROM xact_start) < 7 OR EXTRACT(HOUR FROM xact_start) >= 19) AND usename NOT IN (''postgres'',''rdsadmin'',''replication'',''app_user'',''svc_app'',''etl_service'') ORDER BY xact_start"}'::jsonb,
    expected = '{"condition": "row_count > 0", "description": "Active transactions started outside business hours (before 07:00 or after 19:00) by a non-applicative login may indicate unauthorized or suspicious activity"}'::jsonb
WHERE id = 12135;

-- 4. MySQL (12163) — parens added around the hour OR + applicative exclusion
UPDATE rootcause.detection_steps
SET content = '{"sql": "SELECT t.trx_id, t.trx_mysql_thread_id, p.USER AS trx_user, p.HOST AS trx_host, p.DB AS trx_db, t.trx_started, TIMESTAMPDIFF(SECOND, t.trx_started, NOW()) AS duration_seconds, HOUR(t.trx_started) AS start_hour, t.trx_state, t.trx_rows_locked, t.trx_rows_modified FROM information_schema.INNODB_TRX t JOIN information_schema.PROCESSLIST p ON p.ID = t.trx_mysql_thread_id WHERE (HOUR(t.trx_started) < 7 OR HOUR(t.trx_started) >= 19) AND p.USER NOT IN (''root'',''mysql.sys'',''mysql.session'',''event_scheduler'',''app_user'',''svc_app'',''etl_service'') ORDER BY t.trx_started"}'::jsonb,
    expected = '{"condition": "row_count > 0", "description": "Active transactions started outside business hours (before 07:00 or after 19:00) by a non-applicative login may indicate unauthorized or suspicious activity"}'::jsonb
WHERE id = 12163;

-- 5. MariaDB (15462) — same as MySQL
UPDATE rootcause.detection_steps
SET content = '{"sql": "SELECT t.trx_id, t.trx_mysql_thread_id, p.USER AS trx_user, p.HOST AS trx_host, p.DB AS trx_db, t.trx_started, TIMESTAMPDIFF(SECOND, t.trx_started, NOW()) AS duration_seconds, HOUR(t.trx_started) AS start_hour, t.trx_state, t.trx_rows_locked, t.trx_rows_modified FROM information_schema.INNODB_TRX t JOIN information_schema.PROCESSLIST p ON p.ID = t.trx_mysql_thread_id WHERE (HOUR(t.trx_started) < 7 OR HOUR(t.trx_started) >= 19) AND p.USER NOT IN (''root'',''mysql.sys'',''mysql.session'',''event_scheduler'',''app_user'',''svc_app'',''etl_service'') ORDER BY t.trx_started"}'::jsonb,
    expected = '{"condition": "row_count > 0", "description": "Active transactions started outside business hours (before 07:00 or after 19:00) by a non-applicative login may indicate unauthorized or suspicious activity"}'::jsonb
WHERE id = 15462;

-- 6. Informix (12201)
UPDATE rootcause.detection_steps
SET content = '{"sql": "SELECT s.sid, s.username, s.hostname, s.progname, s.connected, EXTEND(CURRENT, HOUR TO HOUR)::INT AS current_hour FROM sysmaster:syssessions s WHERE s.sid > 0 AND (EXTEND(CURRENT, HOUR TO HOUR)::INT < 7 OR EXTEND(CURRENT, HOUR TO HOUR)::INT >= 19) AND UPPER(s.username) NOT IN (''INFORMIX'',''ROOT'',''APP_USER'',''SVC_APP'',''ETL_SERVICE'') ORDER BY s.sid"}'::jsonb,
    expected = '{"condition": "row_count > 0", "description": "Active transactions started outside business hours (before 07:00 or after 19:00) by a non-applicative login may indicate unauthorized or suspicious activity"}'::jsonb
WHERE id = 12201;

-- Verify
SELECT ds.id, ds.vendor_slug,
       (ds.content->>'sql' LIKE '%NOT IN%') AS has_exclusion,
       LEFT(ds.content->>'sql', 60) AS sql_preview
FROM rootcause.detection_steps ds
WHERE ds.id IN (12121, 12149, 12135, 12163, 15462, 12201)
ORDER BY ds.vendor_slug;

COMMIT;
