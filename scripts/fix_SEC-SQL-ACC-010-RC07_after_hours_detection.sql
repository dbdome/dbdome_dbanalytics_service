-- =============================================================================
-- FIX: SEC-SQL-ACC-010-RC07 — After-hours transaction activity
-- =============================================================================
-- Problem:  All 4 vendor detection steps have wrong SQL.
--           - sqlserver (step 12121): uses MySQL PROCESSLIST/INNODB_TRX syntax
--           - oracle    (step 12149): uses MySQL GLOBAL_STATUS (Select_full_join)
--           - postgresql(step 12135): uses MySQL GLOBAL_STATUS (Innodb_deadlocks)
--           - mysql     (step 12163): uses innodb_buffer_pool_size (unrelated)
--
-- Fix:      Replace each with correct vendor-native SQL that detects
--           transactions running outside business hours (before 07:00 or
--           after 19:00, adjustable via parameters).
-- =============================================================================

BEGIN;

-- ─────────────────────────────────────────────
-- 1. SQL Server  (step_id = 12121)
-- ─────────────────────────────────────────────
UPDATE rootcause.detection_steps
SET content  = '{"sql": "SELECT s.session_id, s.login_name, s.host_name, s.program_name, t.transaction_id, tat.transaction_begin_time, DATEDIFF(SECOND, tat.transaction_begin_time, GETDATE()) AS duration_seconds, DATEPART(HOUR, tat.transaction_begin_time) AS start_hour FROM sys.dm_exec_sessions s JOIN sys.dm_tran_session_transactions t ON t.session_id = s.session_id JOIN sys.dm_tran_active_transactions tat ON tat.transaction_id = t.transaction_id WHERE s.is_user_process = 1 AND (DATEPART(HOUR, tat.transaction_begin_time) < 7 OR DATEPART(HOUR, tat.transaction_begin_time) >= 19) ORDER BY tat.transaction_begin_time"}'::jsonb,
    expected = '{"condition": "row_count > 0", "description": "Active transactions started outside business hours (before 07:00 or after 19:00) may indicate unauthorized or suspicious activity"}'::jsonb
WHERE id = 12121;

-- ─────────────────────────────────────────────
-- 2. Oracle  (step_id = 12149)
-- ─────────────────────────────────────────────
UPDATE rootcause.detection_steps
SET content  = '{"sql": "SELECT s.sid, s.serial#, s.username, s.osuser, s.machine, s.program, t.start_time, ROUND((SYSDATE - TO_DATE(t.start_time, ''MM/DD/YY HH24:MI:SS'')) * 86400) AS duration_seconds, TO_NUMBER(TO_CHAR(TO_DATE(t.start_time, ''MM/DD/YY HH24:MI:SS''), ''HH24'')) AS start_hour FROM v$session s JOIN v$transaction t ON t.ses_addr = s.saddr WHERE s.type = ''USER'' AND (TO_NUMBER(TO_CHAR(TO_DATE(t.start_time, ''MM/DD/YY HH24:MI:SS''), ''HH24'')) < 7 OR TO_NUMBER(TO_CHAR(TO_DATE(t.start_time, ''MM/DD/YY HH24:MI:SS''), ''HH24'')) >= 19) ORDER BY t.start_time"}'::jsonb,
    expected = '{"condition": "row_count > 0", "description": "Active transactions started outside business hours (before 07:00 or after 19:00) may indicate unauthorized or suspicious activity"}'::jsonb
WHERE id = 12149;

-- ─────────────────────────────────────────────
-- 3. PostgreSQL  (step_id = 12135)
-- ─────────────────────────────────────────────
UPDATE rootcause.detection_steps
SET content  = '{"sql": "SELECT pid, usename, client_addr, application_name, backend_start, xact_start, EXTRACT(EPOCH FROM (now() - xact_start))::int AS duration_seconds, EXTRACT(HOUR FROM xact_start)::int AS start_hour, state, query FROM pg_stat_activity WHERE xact_start IS NOT NULL AND backend_type = ''client backend'' AND (EXTRACT(HOUR FROM xact_start) < 7 OR EXTRACT(HOUR FROM xact_start) >= 19) ORDER BY xact_start"}'::jsonb,
    expected = '{"condition": "row_count > 0", "description": "Active transactions started outside business hours (before 07:00 or after 19:00) may indicate unauthorized or suspicious activity"}'::jsonb
WHERE id = 12135;

-- ─────────────────────────────────────────────
-- 4. MySQL  (step_id = 12163)
-- ─────────────────────────────────────────────
UPDATE rootcause.detection_steps
SET content  = '{"sql": "SELECT t.trx_id, t.trx_mysql_thread_id, p.USER AS trx_user, p.HOST AS trx_host, p.DB AS trx_db, t.trx_started, TIMESTAMPDIFF(SECOND, t.trx_started, NOW()) AS duration_seconds, HOUR(t.trx_started) AS start_hour, t.trx_state, t.trx_rows_locked, t.trx_rows_modified FROM information_schema.INNODB_TRX t JOIN information_schema.PROCESSLIST p ON p.ID = t.trx_mysql_thread_id WHERE HOUR(t.trx_started) < 7 OR HOUR(t.trx_started) >= 19 ORDER BY t.trx_started"}'::jsonb,
    expected = '{"condition": "row_count > 0", "description": "Active transactions started outside business hours (before 07:00 or after 19:00) may indicate unauthorized or suspicious activity"}'::jsonb
WHERE id = 12163;

-- ─────────────────────────────────────────────
-- Verify the updates
-- ─────────────────────────────────────────────
SELECT ds.id, ds.vendor_slug, ds.content->>'sql' AS sql_preview, ds.expected->>'description' AS expected_desc
FROM rootcause.detection_steps ds
WHERE ds.id IN (12121, 12149, 12135, 12163)
ORDER BY ds.vendor_slug;

COMMIT;
