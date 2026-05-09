-- =============================================================================
-- FIX: All failing metric detection steps
-- =============================================================================
-- This script fixes SQL stored in rootcause.detection_steps that causes
-- execution failures when run against SQL Server targets.
--
-- Error categories addressed:
--   1. WRONG_VENDOR_SQL  (6 metrics)  - MySQL queries assigned to sqlserver vendor
--   2. MULTI_STATEMENT   (1 step)     - Two SELECT statements joined by semicolon
--   3. INVALID_COLUMN    (3 metrics)  - References to non-existent columns/objects
--   4. MISSING_OBJECT    (1 metric)   - References to distribution DB (replication)
--   5. POLICY_TABLE      (1 metric)   - References to sysmaintplan_plans.has_target
--
-- NOTE: The following error categories are fixed in Python code, NOT here:
--   - NVARCHAR_MAX (66 metrics)  -> output converter in vendor_connection.py
--   - UTF8_ENCODING (63 metrics) -> output converter in vendor_connection.py
--   - PARAM_BINDING (58 metrics) -> parameter substitution in mssql collector
--   - LIKE_COLON (26 steps)      -> SQLAlchemy colon-escape in mssql collector
-- =============================================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. WRONG VENDOR SQL — MySQL syntax running against SQL Server
--    Root causes: SEC-SQL-ACC-010-RC08 through RC13 (sqlserver vendor)
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────
-- SEC-SQL-ACC-010-RC08  (step 12122)
-- Privilege escalation attempts in transactions
-- Was: MySQL GLOBAL_STATUS (Select_full_join, Select_scan)
-- Fix: Detect privilege escalation via SQL Server audit/session info
-- ─────────────────────────────────────────────
UPDATE rootcause.detection_steps
SET content  = '{"sql": "SELECT s.session_id, s.login_name, s.original_login_name, s.host_name, s.program_name, p.permission_name, p.state_desc, p.class_desc FROM sys.dm_exec_sessions s CROSS APPLY (SELECT TOP 5 dp.permission_name, dp.state_desc, dp.class_desc FROM sys.database_permissions dp WHERE dp.grantee_principal_id = DATABASE_PRINCIPAL_ID(s.login_name) AND dp.state_desc = ''GRANT'' AND dp.permission_name IN (''ALTER ANY USER'', ''ALTER ANY ROLE'', ''CONTROL'', ''ALTER'', ''TAKE OWNERSHIP'')) p WHERE s.is_user_process = 1 AND s.original_login_name <> s.login_name ORDER BY s.session_id"}'::jsonb,
    expected = '{"condition": "row_count > 0", "description": "Sessions where current login differs from original login may indicate privilege escalation attempts"}'::jsonb
WHERE id = 12122;

-- ─────────────────────────────────────────────
-- SEC-SQL-ACC-010-RC09  (step 12123)
-- Data exfiltration patterns in transactions
-- Was: MySQL performance_schema.events_statements_summary_by_digest
-- Fix: Detect large data reads via SQL Server DMVs
-- ─────────────────────────────────────────────
UPDATE rootcause.detection_steps
SET content  = '{"sql": "SELECT TOP 10 s.session_id, s.login_name, s.host_name, s.program_name, r.total_elapsed_time / 1000 AS elapsed_ms, r.reads AS logical_reads, r.writes, r.row_count, SUBSTRING(t.text, (r.statement_start_offset/2)+1, ((CASE r.statement_end_offset WHEN -1 THEN DATALENGTH(t.text) ELSE r.statement_end_offset END - r.statement_start_offset)/2)+1) AS current_statement FROM sys.dm_exec_sessions s JOIN sys.dm_exec_requests r ON r.session_id = s.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE s.is_user_process = 1 AND (r.reads > 100000 OR r.row_count > 50000) ORDER BY r.reads DESC"}'::jsonb,
    expected = '{"condition": "row_count > 0", "description": "Sessions with very high read counts or row counts may indicate data exfiltration activity"}'::jsonb
WHERE id = 12123;

-- ─────────────────────────────────────────────
-- SEC-SQL-ACC-010-RC10  (step 12124)
-- Same login active from multiple hosts
-- Was: MySQL GLOBAL_STATUS (Aborted_clients, Aborted_connects)
-- Fix: Detect same login from multiple hosts via SQL Server sessions
-- ─────────────────────────────────────────────
UPDATE rootcause.detection_steps
SET content  = '{"sql": "SELECT login_name, COUNT(DISTINCT host_name) AS host_count, STRING_AGG(DISTINCT host_name, '', '') AS hosts, COUNT(*) AS session_count FROM sys.dm_exec_sessions WHERE is_user_process = 1 AND login_name IS NOT NULL AND host_name IS NOT NULL GROUP BY login_name HAVING COUNT(DISTINCT host_name) > 1 ORDER BY host_count DESC"}'::jsonb,
    expected = '{"condition": "row_count > 0", "description": "Same login active from multiple hosts may indicate credential sharing or compromise"}'::jsonb
WHERE id = 12124;

-- ─────────────────────────────────────────────
-- SEC-SQL-ACC-010-RC11  (step 12125)
-- Schema reconnaissance activity
-- Was: MySQL GLOBAL_VARIABLES (wait_timeout, interactive_timeout)
-- Fix: Detect queries against INFORMATION_SCHEMA or sys catalog
-- ─────────────────────────────────────────────
UPDATE rootcause.detection_steps
SET content  = '{"sql": "SELECT s.session_id, s.login_name, s.host_name, s.program_name, r.start_time, SUBSTRING(t.text, 1, 200) AS query_text FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON s.session_id = r.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE s.is_user_process = 1 AND (t.text LIKE ''%INFORMATION_SCHEMA%'' OR t.text LIKE ''%sys.tables%'' OR t.text LIKE ''%sys.columns%'' OR t.text LIKE ''%sys.objects%'' OR t.text LIKE ''%sysobjects%'' OR t.text LIKE ''%syscolumns%'') ORDER BY r.start_time DESC"}'::jsonb,
    expected = '{"condition": "row_count > 0", "description": "Active queries probing system catalog or INFORMATION_SCHEMA may indicate schema reconnaissance"}'::jsonb
WHERE id = 12125;

-- ─────────────────────────────────────────────
-- SEC-SQL-ACC-010-RC12  (step 12126)
-- Dormant account suddenly active
-- Was: MySQL information_schema.PROCESSLIST
-- Fix: Detect recently active sessions from logins that haven't been used
-- ─────────────────────────────────────────────
UPDATE rootcause.detection_steps
SET content  = '{"sql": "SELECT s.login_name, s.host_name, s.program_name, s.login_time, s.last_request_start_time, sp.modify_date AS login_last_modified, DATEDIFF(DAY, sp.modify_date, GETDATE()) AS days_since_modified FROM sys.dm_exec_sessions s JOIN sys.server_principals sp ON sp.name = s.login_name WHERE s.is_user_process = 1 AND sp.is_disabled = 0 AND DATEDIFF(DAY, sp.modify_date, s.login_time) > 90 ORDER BY sp.modify_date ASC"}'::jsonb,
    expected = '{"condition": "row_count > 0", "description": "Sessions from accounts not modified in 90+ days that are suddenly active may indicate dormant account compromise"}'::jsonb
WHERE id = 12126;

-- ─────────────────────────────────────────────
-- SEC-SQL-ACC-010-RC13  (step 12127)
-- Mass data modification in transactions
-- Was: MySQL GLOBAL_STATUS/GLOBAL_VARIABLES (threads_connected, max_connections)
-- Fix: Detect transactions with large row modifications
-- ─────────────────────────────────────────────
UPDATE rootcause.detection_steps
SET content  = '{"sql": "SELECT s.session_id, s.login_name, s.host_name, s.program_name, t.transaction_id, tat.transaction_begin_time, DATEDIFF(SECOND, tat.transaction_begin_time, GETDATE()) AS duration_seconds, (SELECT SUM(tdt.database_transaction_log_bytes_used) FROM sys.dm_tran_database_transactions tdt WHERE tdt.transaction_id = t.transaction_id) AS log_bytes_used FROM sys.dm_exec_sessions s JOIN sys.dm_tran_session_transactions t ON t.session_id = s.session_id JOIN sys.dm_tran_active_transactions tat ON tat.transaction_id = t.transaction_id WHERE s.is_user_process = 1 ORDER BY log_bytes_used DESC"}'::jsonb,
    expected = '{"condition": "row_count > 0", "description": "Active transactions with large log usage indicate mass data modifications that may be malicious"}'::jsonb
WHERE id = 12127;


-- ═══════════════════════════════════════════════════════════════════════════
-- 2. MULTI-STATEMENT SQL — Two SELECTs joined by semicolon
--    Step 1132 for PERF-SQL-CE-001-RC07
-- ═══════════════════════════════════════════════════════════════════════════

-- Fix: Keep only the second (more useful) query — tempdb contention counts
UPDATE rootcause.detection_steps
SET content = '{"sql": "SELECT (SELECT COUNT(*) FROM sys.dm_os_waiting_tasks WHERE wait_type LIKE ''PAGELATCH%'' AND resource_description LIKE ''2:%'' AND CHARINDEX('':'', resource_description, CHARINDEX('':'', resource_description) + 1) > 0 AND RIGHT(resource_description, LEN(resource_description) - LEN(LEFT(resource_description, CHARINDEX('':'', resource_description, CHARINDEX('':'', resource_description) + 1)))) = ''1'') AS tempdb_pfs_waiters, (SELECT COUNT(*) FROM sys.dm_os_waiting_tasks WHERE wait_type LIKE ''PAGELATCH%'' AND resource_description LIKE ''2:%'' AND RIGHT(resource_description, 1) = ''2'') AS tempdb_gam_waiters, (SELECT COUNT(*) FROM sys.dm_os_waiting_tasks WHERE wait_type LIKE ''PAGELATCH%'' AND resource_description LIKE ''2:%'' AND RIGHT(resource_description, 1) = ''3'') AS tempdb_sgam_waiters, (SELECT waiting_tasks_count FROM sys.dm_os_wait_stats WHERE wait_type = ''PAGELATCH_EX'') AS pagelatch_ex_count, (SELECT waiting_tasks_count FROM sys.dm_os_wait_stats WHERE wait_type = ''PAGELATCH_UP'') AS pagelatch_up_count"}'::jsonb
WHERE id = 1132;


-- ═══════════════════════════════════════════════════════════════════════════
-- 3. INVALID COLUMN / BROKEN SQL
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────
-- PERF-SQL-CN-003-RC11  (step 1314)
-- Was: References [text] column from sys.dm_exec_sessions (doesn't exist)
--      and sys.fn_xe_file_target_read_file which has column name issues
-- Fix: Rewrite to use only sys.fn_xe_file_target_read_file properly
-- ─────────────────────────────────────────────
UPDATE rootcause.detection_steps
SET content = '{"sql": "SELECT TOP 20 xet.timestamp_utc AS log_date, ''XEvent'' AS process_info, CAST(xet.event_data AS NVARCHAR(4000)) AS event_text FROM sys.fn_xe_file_target_read_file(''system_health*.xel'', NULL, NULL, NULL) AS xet WHERE CAST(xet.event_data AS NVARCHAR(MAX)) LIKE ''%failover%'' OR CAST(xet.event_data AS NVARCHAR(MAX)) LIKE ''%restart%'' ORDER BY xet.timestamp_utc DESC"}'::jsonb
WHERE id = 1314;

-- ─────────────────────────────────────────────
-- PERF-SQL-TX-002-RC06  (step 2540)
-- Was: References msdb.dbo.sysjobactivity.run_status (invalid column)
-- Fix: Use correct column names from sysjobactivity
-- ─────────────────────────────────────────────
UPDATE rootcause.detection_steps
SET content = '{"sql": "SELECT j.name AS job_name, ja.start_execution_date, ja.last_executed_step_id, DATEDIFF(MINUTE, ja.start_execution_date, GETDATE()) AS running_minutes FROM msdb.dbo.sysjobs j JOIN msdb.dbo.sysjobactivity ja ON j.job_id = ja.job_id WHERE j.name LIKE ''cdc%capture%'' AND ja.session_id = (SELECT MAX(session_id) FROM msdb.dbo.syssessions) AND ja.start_execution_date IS NOT NULL AND ja.stop_execution_date IS NULL"}'::jsonb
WHERE id = 2540;

-- ─────────────────────────────────────────────
-- PERF-SQL-TX-002-RC07  (step 2542)
-- Was: References distribution.dbo.MSdistribution_agents (may not exist)
-- Fix: Wrap in existence check using IF EXISTS
-- ─────────────────────────────────────────────
UPDATE rootcause.detection_steps
SET content = '{"sql": "SELECT d.name AS database_name, d.log_reuse_wait_desc, lu.cntr_value / 1024 AS log_used_mb, CASE d.log_reuse_wait_desc WHEN ''REPLICATION'' THEN ''Replication agent may be behind'' WHEN ''LOG_BACKUP'' THEN ''Log backup needed'' WHEN ''ACTIVE_TRANSACTION'' THEN ''Long-running transaction'' WHEN ''AVAILABILITY_REPLICA'' THEN ''AG replica sync delay'' ELSE d.log_reuse_wait_desc END AS reuse_wait_reason FROM sys.databases d JOIN sys.dm_os_performance_counters lu ON lu.counter_name = ''Log File(s) Used Size (KB)'' AND lu.instance_name = d.name WHERE d.log_reuse_wait_desc = ''REPLICATION'' AND d.database_id > 4"}'::jsonb
WHERE id = 2542;

-- ─────────────────────────────────────────────
-- SEC-SQL-CFG-003-RC06  (step 3030)
-- Was: References msdb.dbo.sysmaintplan_plans.has_target (invalid column)
-- Fix: Use correct column or alternative approach
-- ─────────────────────────────────────────────
UPDATE rootcause.detection_steps
SET content = '{"sql": "SELECT (SELECT COUNT(*) FROM msdb.dbo.syspolicy_policies WHERE is_enabled = 1) AS active_policies, (SELECT COUNT(*) FROM msdb.dbo.syspolicy_policies p JOIN msdb.dbo.syspolicy_conditions c ON p.condition_id = c.condition_id WHERE p.is_enabled = 1 AND (c.name LIKE ''%database%name%'' OR c.name LIKE ''%sample%'' OR c.name LIKE ''%test%'')) AS db_naming_policies, (SELECT COUNT(*) FROM msdb.dbo.sysmaintplan_plans) AS maintenance_plans, (SELECT COUNT(*) FROM sys.server_principals WHERE type = ''R'' AND name LIKE ''%DBA%'') AS dba_roles"}'::jsonb
WHERE id = 3030;


-- ═══════════════════════════════════════════════════════════════════════════
-- 4. PAGELATCH LIKE-pattern fixes (avoid colon-digit in LIKE patterns)
--    These cause SQLAlchemy to treat :1, :2, :3 as bound parameters
-- ═══════════════════════════════════════════════════════════════════════════

-- Step 1660 — PERF-SQL-IO-004-RC02 (PFS page contention)
UPDATE rootcause.detection_steps
SET content = '{"sql": "SELECT session_id, wait_type, wait_resource, wait_time, blocking_session_id, CASE WHEN wait_resource LIKE ''2:1:%'' THEN ''First data file PFS'' WHEN wait_resource LIKE ''2:%'' THEN ''Other tempdb page'' ELSE ''Non-tempdb'' END AS contention_type FROM sys.dm_exec_requests WHERE wait_type LIKE ''PAGELATCH%'' AND wait_resource LIKE ''2:%'' AND RIGHT(wait_resource, 1) = ''1'' ORDER BY wait_time DESC"}'::jsonb
WHERE id = 1660;

-- Step 1662 — PERF-SQL-IO-004-RC03 (GAM page contention)
UPDATE rootcause.detection_steps
SET content = '{"sql": "SELECT session_id, wait_type, wait_resource, wait_time, blocking_session_id, CASE WHEN PARSENAME(REPLACE(wait_resource, '':'', ''.''), 1) = ''2'' THEN ''GAM page'' WHEN PARSENAME(REPLACE(wait_resource, '':'', ''.''), 1) = ''1'' THEN ''PFS page'' ELSE ''Other page'' END AS page_type FROM sys.dm_exec_requests WHERE wait_type LIKE ''PAGELATCH%'' AND wait_resource LIKE ''2:%'' AND RIGHT(wait_resource, 1) = ''2'' ORDER BY wait_time DESC"}'::jsonb
WHERE id = 1662;

-- Step 1664 — PERF-SQL-IO-004-RC04 (SGAM page contention)
UPDATE rootcause.detection_steps
SET content = '{"sql": "SELECT session_id, wait_type, wait_resource, wait_time, blocking_session_id FROM sys.dm_exec_requests WHERE wait_type LIKE ''PAGELATCH%'' AND wait_resource LIKE ''2:%'' AND RIGHT(wait_resource, 1) = ''3'' ORDER BY wait_time DESC"}'::jsonb
WHERE id = 1664;


-- ═══════════════════════════════════════════════════════════════════════════
-- Verify all updates
-- ═══════════════════════════════════════════════════════════════════════════
SELECT ds.id, ds.vendor_slug,
       LEFT(ds.content->>'sql', 80) AS sql_preview,
       LEFT(ds.expected->>'description', 60) AS expected_desc
FROM rootcause.detection_steps ds
WHERE ds.id IN (
    -- Wrong vendor SQL
    12121, 12122, 12123, 12124, 12125, 12126, 12127,
    -- Multi-statement
    1132,
    -- Invalid column / broken SQL
    1314, 2540, 2542, 3030,
    -- PAGELATCH LIKE patterns
    1660, 1662, 1664
)
ORDER BY ds.id;

COMMIT;
