-- =============================================================================
-- 7530_login_name_attribution_sqlserver.sql
--
-- Give sqlserver detections a real login_name, so 'who did this?' survives into
-- alerts.alert_log, the mail/SIEM payloads and the guard processes.
--
-- WHY
--   Measured on this catalog across the 1,104 metrics collected in the last 14
--   days: 12 carried a populated login_name, 50 carried the column but ALWAYS
--   NULL, and 1,042 had no such column at all. The always-NULL 50 are the shape
--   7520 documented for SEC-SQL-AUD-020: a branch reading sys.dm_exec_query_stats
--   hardcodes CAST(NULL AS NVARCHAR(128)) AS login_name because the plan cache is
--   an aggregate with no session attached, so attribution is gone by the time the
--   row exists.
--
--   Of everything unattributed, only part CAN be attributed at all:
--     102  read sys.dm_exec_sessions / sysprocesses  -> the login is already in the row source
--      41  read requests/connections                 -> needs a join to dm_exec_sessions
--      18  read the default trace / audit file       -> LoginName / server_principal_name
--     118  plan cache only                           -> NOT attributable, ever
--     609  catalog / config / inventory              -> no principal exists to attribute
--   Adding a NULL column to the last two groups would be theatre, so they are
--   deliberately untouched.
--
-- WHAT THIS SHIPS
--   26 detection steps, each REWRITTEN AND THEN PROVEN against a live SQL Server
--   (Microsoft SQL Server 2022 RTM-CU25) before being included here. The bar for
--   inclusion was: the original runs, the rewrite runs, the row count is
--   IDENTICAL, and the result really exposes a login_name column. Two candidate
--   rewrites were rejected by that check and are NOT in this file.
--       5  join-sessions-then-project  (0 already returned a real login on the test box)
--      21  project-existing-session-source  (10 already returned a real login on the test box)
--
-- HOW IT MATCHES
--   By (root_cause_id, vendor, step name) PLUS an md5 of the current decrypted SQL:
--   step ids differ per install, and a box whose SQL has since diverged from what
--   was validated is SKIPPED with a notice rather than silently overwritten. Same
--   reasoning as 7520's 'preserve whatever is live on the box'.
--
-- NOT INCLUDED (deliberate, tracked)
--   169 steps still need hand work: multi-statement batches with control flow
--   (the AUD-020 default-trace case is one of these), queries whose only source is
--   the plan cache, and steps whose original could not be executed on the one test
--   instance that was reachable (192.168.1.214 / 181.214.214.98 were both down), so
--   no rewrite for them could be proven. They are listed at the end of this file.
--
-- The alert path needs no change: fn_get_alert_log_resultset already falls back to
--   jsonb_lower_keys(elem)->>'login_name' from the evidence row when
--   alerts.alert_log.login_name is empty, so a new column flows straight through to
--   mail/SIEM. Per-RC monitoring.v_* views expose fixed keys and would each need the
--   column added separately to surface it in Grafana.
--
-- Encryption-aware (7300): reads via rootcause.dec(), writes via rootcause.enc().
-- Idempotent: a step already carrying the new SQL is skipped.
-- =============================================================================

DO $mig$
DECLARE
    v_enc    boolean := to_regprocedure('rootcause.enc(jsonb)') IS NOT NULL;
    v_haskey boolean := nullif(current_setting('rootcause.k', true), '') IS NOT NULL;
    v_cur    text;
    v_done   int := 0;
    v_skip   int := 0;
    v_miss   int := 0;
    r        record;
    s        record;
BEGIN
    IF v_enc AND NOT v_haskey THEN
        RAISE EXCEPTION
            '7530: detection_steps are encrypted (7300) but this session has no key. '
            'Connect as dbdome_adm / dbdome_mon_usr, or run: '
            'SELECT set_config(''rootcause.k'', ''<DBDOME_SECRET_KEY>'', false);';
    END IF;

    FOR r IN
        SELECT * FROM (VALUES
            ('HLTH-SQL-AD-001-RC04', 'Find active blocking chains', '260d36d66402cb012b0fdf785678a888', '55121b55969eaeadab2ef3205df2be20',
             $ln7530$SELECT dbdome_ses.login_name AS login_name, r.session_id, r.blocking_session_id, r.wait_type, r.wait_time / 1000 AS wait_seconds, r.wait_resource, t.text AS blocked_query FROM sys.dm_exec_requests r CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t  LEFT JOIN sys.dm_exec_sessions dbdome_ses ON dbdome_ses.session_id = r.session_id WHERE r.blocking_session_id <> 0$ln7530$),   /* join-sessions-then-project */
            ('HLTH-SQL-AD-002-RC05', 'Find lock waits on FK-related tables', '9f015d015938cbc075a1f9db7fcfdb86', 'db18a4dd696806dde7ccb89f7aa96de9',
             $ln7530$SELECT dbdome_ses.login_name AS login_name, t1.resource_type, OBJECT_NAME(t1.resource_associated_entity_id) AS locked_object, t1.request_mode, t1.request_status, t2.blocking_session_id, t2.wait_type, t2.wait_time / 1000 AS wait_seconds FROM sys.dm_tran_locks t1 JOIN sys.dm_exec_requests t2 ON t1.request_session_id = t2.session_id  LEFT JOIN sys.dm_exec_sessions dbdome_ses ON dbdome_ses.session_id = t2.session_id WHERE t2.blocking_session_id <> 0 AND t1.resource_type IN ('KEY', 'RID', 'PAGE', 'OBJECT')$ln7530$),   /* join-sessions-then-project */
            ('HLTH-SQL-DM-001-RC07', 'Find orphaned distributed transactions', 'd69cefc9ef0a53a1e57f58fb3786d134', '6b0e2e8064884471d9132f1195d4653a',
             $ln7530$SELECT s.login_name AS login_name, t.transaction_id, t.name AS transaction_name, t.transaction_begin_time, s.session_id, s.login_name, s.host_name, CASE WHEN s.session_id IS NULL THEN 'ORPHANED' ELSE 'ACTIVE' END AS status FROM sys.dm_tran_active_transactions t LEFT JOIN sys.dm_tran_session_transactions st ON t.transaction_id = st.transaction_id LEFT JOIN sys.dm_exec_sessions s ON st.session_id = s.session_id WHERE t.transaction_type = 1 AND t.transaction_begin_time < DATEADD(MINUTE, -5, GETDATE())$ln7530$),   /* project-existing-session-source */
            ('HLTH-SQL-RP-001-RC07', 'Check for long-running active transactions on primary', 'e942fe58abff7c7a49877d62eb48e198', 'afa6f86271cbfd945474d04d014a4a2e',
             $ln7530$SELECT s.login_name AS login_name, t.session_id, t.transaction_id, DATEDIFF(SECOND, tat.transaction_begin_time, GETDATE()) AS duration_sec, tat.transaction_begin_time, dt.database_transaction_log_bytes_used / 1048576 AS log_used_mb, dt.database_transaction_log_bytes_reserved / 1048576 AS log_reserved_mb, s.login_name, s.program_name, r.command, SUBSTRING(st.text, (r.statement_start_offset / 2) + 1, 100) AS current_stmt FROM sys.dm_tran_session_transactions t JOIN sys.dm_tran_active_transactions tat ON t.transaction_id = tat.transaction_id JOIN sys.dm_tran_database_transactions dt ON t.transaction_id = dt.transaction_id JOIN sys.dm_exec_sessions s ON t.session_id = s.session_id LEFT JOIN sys.dm_exec_requests r ON t.session_id = r.session_id OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) st WHERE DATEDIFF(SECOND, tat.transaction_begin_time, GETDATE()) > 300 AND dt.database_transaction_log_bytes_used > 10485760 ORDER BY dt.database_transaction_log_bytes_used DESC$ln7530$),   /* project-existing-session-source */
            ('HLTH-SQL-RP-001-RC17', 'Check for active backup operations on secondary', '79d5133ffc4f45460b8a8d9ae4543b29', 'd0daa47852ca4621e0a1ac6b16f9d651',
             $ln7530$SELECT dbdome_ses.login_name AS login_name, r.session_id, r.command, r.percent_complete, r.total_elapsed_time / 60000 AS elapsed_min, r.estimated_completion_time / 60000 AS est_remaining_min, r.wait_type, r.wait_time, DB_NAME(r.database_id) AS database_name FROM sys.dm_exec_requests r  LEFT JOIN sys.dm_exec_sessions dbdome_ses ON dbdome_ses.session_id = r.session_id WHERE r.command LIKE 'BACKUP%'$ln7530$),   /* join-sessions-then-project */
            ('HLTH-SQL-RP-006-RC05', 'Check for long-running queries on readable secondary', 'e92935294048bca98465a21cd5943337', 'f419f559e0cf35b1ec0f249c3091dbdc',
             $ln7530$SELECT dbdome_ses.login_name AS login_name, r.session_id, r.start_time, DATEDIFF(SECOND, r.start_time, GETDATE()) AS duration_sec, r.command, r.status, r.wait_type, r.blocking_session_id, DB_NAME(r.database_id) AS database_name, SUBSTRING(st.text, (r.statement_start_offset/2)+1, 200) AS query_fragment FROM sys.dm_exec_requests r CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st  LEFT JOIN sys.dm_exec_sessions dbdome_ses ON dbdome_ses.session_id = r.session_id WHERE r.database_id > 4 AND DATEDIFF(SECOND, r.start_time, GETDATE()) > 300 AND r.command IN ('SELECT', 'BACKUP DATABASE', 'DBCC') ORDER BY duration_sec DESC$ln7530$),   /* join-sessions-then-project */
            ('HLTH-SQL-RP-006-RC10', 'Check AG secondary for long-running snapshot transactions', 'f96bf4934a914844355e46b6d082cc00', '1c4c0faf9dc1c17c5fdffeb68dd4f6a8',
             $ln7530$SELECT s.login_name AS login_name, s.session_id, s.login_time, s.status, DATEDIFF(SECOND, t.transaction_begin_time, GETDATE()) AS transaction_age_sec, t.transaction_type, t.transaction_state, DB_NAME(dt.database_id) AS database_name FROM sys.dm_tran_active_snapshot_database_transactions ast JOIN sys.dm_tran_active_transactions t ON ast.transaction_id = t.transaction_id JOIN sys.dm_tran_session_transactions st ON t.transaction_id = st.transaction_id JOIN sys.dm_exec_sessions s ON st.session_id = s.session_id LEFT JOIN sys.dm_tran_database_transactions dt ON t.transaction_id = dt.transaction_id WHERE DATEDIFF(SECOND, t.transaction_begin_time, GETDATE()) > 600 ORDER BY transaction_age_sec DESC$ln7530$),   /* project-existing-session-source */
            ('HLTH-SQL-SM-002-RC12', 'Check databases with snapshot isolation enabled and long transactions', 'cdb9bc5c9b72d964ac360930649a3ddc', '30f71c49daad350168f65bf0241f650c',
             $ln7530$SELECT s.login_name AS login_name, d.name AS database_name, d.snapshot_isolation_state_desc, d.is_read_committed_snapshot_on, ast.transaction_id, ast.elapsed_time_seconds, s.login_name, s.host_name FROM sys.databases d LEFT JOIN sys.dm_tran_active_snapshot_database_transactions ast ON 1=1 LEFT JOIN sys.dm_exec_sessions s ON ast.session_id = s.session_id WHERE d.snapshot_isolation_state_desc <> 'OFF' OR d.is_read_committed_snapshot_on = 1$ln7530$),   /* project-existing-session-source */
            ('HLTH-SQL-SM-004-RC07', 'Check for active DBCC operations', 'c07bb7ee7aad1117ecd39e01ea9549bb', '34ef66109ace884088019aa8da140b18',
             $ln7530$SELECT dbdome_ses.login_name AS login_name, r.session_id, r.command, r.percent_complete, r.total_elapsed_time / 60000 AS elapsed_minutes, r.estimated_completion_time / 60000 AS est_remaining_minutes, DB_NAME(r.database_id) AS target_database, SUBSTRING(t.text, 1, 200) AS command_text FROM sys.dm_exec_requests r CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t  LEFT JOIN sys.dm_exec_sessions dbdome_ses ON dbdome_ses.session_id = r.session_id WHERE r.command LIKE 'DBCC%'$ln7530$),   /* join-sessions-then-project */
            ('HLTH-SQL-SM-004-RC12', 'Find long-running queries with large memory grants and tempdb usage', '56fbd5cb8c45a6be8f4ccad7d23031f0', '6aac0b3730b9f091a0d4c10ed212df61',
             $ln7530$SELECT s.login_name AS login_name, r.session_id, r.total_elapsed_time / 60000 AS elapsed_minutes, r.granted_query_memory * 8 / 1024 AS granted_memory_mb, tsu.internal_objects_alloc_page_count * 8 / 1024 AS internal_alloc_mb, tsu.user_objects_alloc_page_count * 8 / 1024 AS user_alloc_mb, s.program_name, s.host_name, SUBSTRING(t.text, (r.statement_start_offset/2)+1, 200) AS query_fragment FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t JOIN sys.dm_db_task_space_usage tsu ON r.session_id = tsu.session_id WHERE r.total_elapsed_time > 60000 AND (r.granted_query_memory * 8 / 1024 > 256 OR tsu.internal_objects_alloc_page_count * 8 / 1024 > 100) ORDER BY r.granted_query_memory DESC$ln7530$),   /* project-existing-session-source */
            ('HLTH-SQL-SM-004-RC13', 'Check for sessions creating many temp objects', '2c86e7c137ff3ebd794e4c83a97b2020', '15b3f45cb6e6dd06c696e220a40c679b',
             $ln7530$SELECT s.login_name AS login_name, su.session_id, su.user_objects_alloc_page_count * 8 / 1024 AS user_alloc_mb, su.user_objects_dealloc_page_count * 8 / 1024 AS user_dealloc_mb, su.internal_objects_alloc_page_count * 8 / 1024 AS internal_alloc_mb, s.program_name, s.host_name, s.login_time, (SELECT COUNT(*) FROM tempdb.sys.objects WHERE type = 'U' AND name LIKE '#%') AS active_temp_tables FROM sys.dm_db_session_space_usage su JOIN sys.dm_exec_sessions s ON su.session_id = s.session_id WHERE su.user_objects_alloc_page_count > 1000 ORDER BY su.user_objects_alloc_page_count DESC$ln7530$),   /* project-existing-session-source */
            ('HLTH-SQL-SM-007-RC11', 'Check version store size and longest running transaction', 'b39eec07ce61c03ed6590c6041fdc94f', '7d11523b3acc0bb1e02afcb4e3d392cf',
             $ln7530$SELECT s.login_name AS login_name, (SELECT SUM(version_store_reserved_page_count) * 8 / 1024 FROM tempdb.sys.dm_db_file_space_usage) AS version_store_mb, t.transaction_id, t.name AS tran_name, t.transaction_begin_time, DATEDIFF(SECOND, t.transaction_begin_time, GETDATE()) AS duration_sec, s.login_name, s.host_name FROM sys.dm_tran_active_transactions t LEFT JOIN sys.dm_tran_session_transactions st ON t.transaction_id = st.transaction_id LEFT JOIN sys.dm_exec_sessions s ON st.session_id = s.session_id WHERE t.transaction_begin_time < DATEADD(MINUTE, -5, GETDATE()) ORDER BY t.transaction_begin_time ASC$ln7530$),   /* project-existing-session-source */
            ('PERF-SQL-TX-001-RC03', 'Check for open transactions with multiple batches and idle gaps', 'b4c21f23e23fc8593d06350335c3e5c9', '4ad2f64a1e946eadc87e0c62726c9031',
             $ln7530$SELECT s.login_name AS login_name, t.transaction_id, t.name AS tran_name, t.transaction_begin_time, DATEDIFF(SECOND, t.transaction_begin_time, GETDATE()) AS duration_sec, s.session_id, s.login_name, s.host_name, s.program_name, s.status AS session_status, r.command, r.wait_type, r.blocking_session_id FROM sys.dm_tran_active_transactions t JOIN sys.dm_tran_session_transactions tst ON t.transaction_id = tst.transaction_id JOIN sys.dm_exec_sessions s ON tst.session_id = s.session_id LEFT JOIN sys.dm_exec_requests r ON s.session_id = r.session_id WHERE t.transaction_begin_time < DATEADD(MINUTE, -5, GETDATE()) ORDER BY t.transaction_begin_time$ln7530$),   /* project-existing-session-source */
            ('PERF-SQL-TX-001-RC05', 'Check for blocked transactions with open duration and wait details', 'b4c21f23e23fc8593d06350335c3e5c9', '4ad2f64a1e946eadc87e0c62726c9031',
             $ln7530$SELECT s.login_name AS login_name, t.transaction_id, t.name AS tran_name, t.transaction_begin_time, DATEDIFF(SECOND, t.transaction_begin_time, GETDATE()) AS duration_sec, s.session_id, s.login_name, s.host_name, s.program_name, s.status AS session_status, r.command, r.wait_type, r.blocking_session_id FROM sys.dm_tran_active_transactions t JOIN sys.dm_tran_session_transactions tst ON t.transaction_id = tst.transaction_id JOIN sys.dm_exec_sessions s ON tst.session_id = s.session_id LEFT JOIN sys.dm_exec_requests r ON s.session_id = r.session_id WHERE t.transaction_begin_time < DATEADD(MINUTE, -5, GETDATE()) ORDER BY t.transaction_begin_time$ln7530$),   /* project-existing-session-source */
            ('PERF-SQL-TX-001-RC07', 'Check for transactions with large log usage and high write activity', 'b4c21f23e23fc8593d06350335c3e5c9', '4ad2f64a1e946eadc87e0c62726c9031',
             $ln7530$SELECT s.login_name AS login_name, t.transaction_id, t.name AS tran_name, t.transaction_begin_time, DATEDIFF(SECOND, t.transaction_begin_time, GETDATE()) AS duration_sec, s.session_id, s.login_name, s.host_name, s.program_name, s.status AS session_status, r.command, r.wait_type, r.blocking_session_id FROM sys.dm_tran_active_transactions t JOIN sys.dm_tran_session_transactions tst ON t.transaction_id = tst.transaction_id JOIN sys.dm_exec_sessions s ON tst.session_id = s.session_id LEFT JOIN sys.dm_exec_requests r ON s.session_id = r.session_id WHERE t.transaction_begin_time < DATEADD(MINUTE, -5, GETDATE()) ORDER BY t.transaction_begin_time$ln7530$),   /* project-existing-session-source */
            ('PERF-SQL-TX-001-RC09', 'Check for open transactions with high network round trips relative to work done', 'b4c21f23e23fc8593d06350335c3e5c9', '4ad2f64a1e946eadc87e0c62726c9031',
             $ln7530$SELECT s.login_name AS login_name, t.transaction_id, t.name AS tran_name, t.transaction_begin_time, DATEDIFF(SECOND, t.transaction_begin_time, GETDATE()) AS duration_sec, s.session_id, s.login_name, s.host_name, s.program_name, s.status AS session_status, r.command, r.wait_type, r.blocking_session_id FROM sys.dm_tran_active_transactions t JOIN sys.dm_tran_session_transactions tst ON t.transaction_id = tst.transaction_id JOIN sys.dm_exec_sessions s ON tst.session_id = s.session_id LEFT JOIN sys.dm_exec_requests r ON s.session_id = r.session_id WHERE t.transaction_begin_time < DATEADD(MINUTE, -5, GETDATE()) ORDER BY t.transaction_begin_time$ln7530$),   /* project-existing-session-source */
            ('PERF-SQL-TX-001-RC11', 'Check for completely idle sessions with open transactions', 'b4c21f23e23fc8593d06350335c3e5c9', '4ad2f64a1e946eadc87e0c62726c9031',
             $ln7530$SELECT s.login_name AS login_name, t.transaction_id, t.name AS tran_name, t.transaction_begin_time, DATEDIFF(SECOND, t.transaction_begin_time, GETDATE()) AS duration_sec, s.session_id, s.login_name, s.host_name, s.program_name, s.status AS session_status, r.command, r.wait_type, r.blocking_session_id FROM sys.dm_tran_active_transactions t JOIN sys.dm_tran_session_transactions tst ON t.transaction_id = tst.transaction_id JOIN sys.dm_exec_sessions s ON tst.session_id = s.session_id LEFT JOIN sys.dm_exec_requests r ON s.session_id = r.session_id WHERE t.transaction_begin_time < DATEADD(MINUTE, -5, GETDATE()) ORDER BY t.transaction_begin_time$ln7530$),   /* project-existing-session-source */
            ('SEC-SQL-ACC-010-RC07', 'Detect after-hours transaction activity', '79afd5adaeaacbda4d8c12618221e0fb', '08f1f1020a4cc1e20e9b81648e047eab',
             $ln7530$SELECT s.login_name AS login_name, s.session_id, s.login_name, s.host_name, s.program_name, t.transaction_id, tat.transaction_begin_time, DATEDIFF(SECOND, tat.transaction_begin_time, GETDATE()) AS duration_seconds, DATEPART(HOUR, tat.transaction_begin_time) AS start_hour FROM sys.dm_exec_sessions s JOIN sys.dm_tran_session_transactions t ON t.session_id = s.session_id JOIN sys.dm_tran_active_transactions tat ON tat.transaction_id = t.transaction_id WHERE s.is_user_process = 1 AND (DATEPART(HOUR, tat.transaction_begin_time) < 7 OR DATEPART(HOUR, tat.transaction_begin_time) >= 19) AND s.login_name NOT IN ('sa', 'app_user', 'svc_app', 'etl_service') AND s.login_name NOT LIKE '##%' AND s.login_name NOT LIKE '%$' AND NOT (COALESCE(s.program_name, '') LIKE '%.Net SqlClient Data Provider%' OR COALESCE(s.program_name, '') LIKE '%JDBC%' OR COALESCE(s.program_name, '') LIKE '%jTDS%' OR COALESCE(s.program_name, '') LIKE '%ODBC%' OR COALESCE(s.program_name, '') LIKE 'SQLAlchemy%' OR COALESCE(s.program_name, '') LIKE 'pyodbc%' OR COALESCE(s.program_name, '') LIKE 'python%' OR COALESCE(s.program_name, '') LIKE 'PHP%' OR COALESCE(s.program_name, '') LIKE 'node%' OR (COALESCE(s.program_name, '') <> '' AND LOWER(s.login_name) LIKE '%' + LOWER(s.program_name) + '%')) ORDER BY tat.transaction_begin_time$ln7530$),   /* project-existing-session-source */
            ('SEC-SQL-ACC-010-RC08', 'Detect privilege escalation in active transactions', '44fbba92afa0139d4afaba0fb9a13c11', '556c70e733d340bdeebdf7ce56f96266',
             $ln7530$SELECT s.login_name AS login_name, s.session_id, s.login_name, s.original_login_name, s.host_name, s.program_name, p.permission_name, p.state_desc, p.class_desc FROM sys.dm_exec_sessions s CROSS APPLY (SELECT TOP 5 dp.permission_name, dp.state_desc, dp.class_desc FROM sys.database_permissions dp WHERE dp.grantee_principal_id = DATABASE_PRINCIPAL_ID(s.login_name) AND dp.state_desc = 'GRANT' AND dp.permission_name IN ('ALTER ANY USER', 'ALTER ANY ROLE', 'CONTROL', 'ALTER', 'TAKE OWNERSHIP')) p WHERE s.is_user_process = 1 AND s.original_login_name <> s.login_name ORDER BY s.session_id$ln7530$),   /* project-existing-session-source */
            ('SEC-SQL-ACC-010-RC09', 'Detect data exfiltration patterns in transactions', '47ddc1a920358e1dc1bf0c184f25040b', '7e94691e54c83d6b3837773a8681f0ed',
             $ln7530$SELECT TOP 10 s.login_name AS login_name, s.session_id, s.login_name, s.host_name, s.program_name, r.total_elapsed_time / 1000 AS elapsed_ms, r.reads AS logical_reads, r.writes, r.row_count, SUBSTRING(t.text, (r.statement_start_offset/2)+1, ((CASE r.statement_end_offset WHEN -1 THEN DATALENGTH(t.text) ELSE r.statement_end_offset END - r.statement_start_offset)/2)+1) AS current_statement FROM sys.dm_exec_sessions s JOIN sys.dm_exec_requests r ON r.session_id = s.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE s.is_user_process = 1 AND (r.reads > 100000 OR r.row_count > 50000) ORDER BY r.reads DESC$ln7530$),   /* project-existing-session-source */
            ('SEC-SQL-ACC-010-RC11', 'Detect schema reconnaissance in active transactions', '4fc9c4bb6743097dc778ba30057f3a5d', '6b4f5a4285d42b74d711debfed48adaf',
             $ln7530$SELECT s.login_name AS login_name, s.session_id, s.login_name, s.host_name, s.program_name, r.start_time, SUBSTRING(t.text, 1, 200) AS query_text FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON s.session_id = r.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE s.is_user_process = 1 AND (t.text LIKE '%INFORMATION_SCHEMA%' OR t.text LIKE '%sys.tables%' OR t.text LIKE '%sys.columns%' OR t.text LIKE '%sys.objects%' OR t.text LIKE '%sysobjects%' OR t.text LIKE '%syscolumns%') ORDER BY r.start_time DESC$ln7530$),   /* project-existing-session-source */
            ('SEC-SQL-ACC-010-RC12', 'Detect dormant accounts with active transactions', '96def94a821d829de27af5d2fd86b16d', '0fdc6f28cc693ad297f5796a9a03b9b7',
             $ln7530$SELECT s.login_name AS login_name, s.login_name, s.host_name, s.program_name, s.login_time, s.last_request_start_time, sp.modify_date AS login_last_modified, DATEDIFF(DAY, sp.modify_date, GETDATE()) AS days_since_modified FROM sys.dm_exec_sessions s JOIN sys.server_principals sp ON sp.name = s.login_name WHERE s.is_user_process = 1 AND sp.is_disabled = 0 AND DATEDIFF(DAY, sp.modify_date, s.login_time) > 90 ORDER BY sp.modify_date ASC$ln7530$),   /* project-existing-session-source */
            ('SEC-SQL-ACC-010-RC13', 'Detect mass data modification in active transactions', '9ecca34659cac792a4e22d8bfc4ad3a7', 'fffeb9a54fc491f5500bfb8fa8414ab7',
             $ln7530$SELECT s.login_name AS login_name, s.session_id, s.login_name, s.host_name, s.program_name, t.transaction_id, tat.transaction_begin_time, DATEDIFF(SECOND, tat.transaction_begin_time, GETDATE()) AS duration_seconds, (SELECT SUM(tdt.database_transaction_log_bytes_used) FROM sys.dm_tran_database_transactions tdt WHERE tdt.transaction_id = t.transaction_id) AS log_bytes_used FROM sys.dm_exec_sessions s JOIN sys.dm_tran_session_transactions t ON t.session_id = s.session_id JOIN sys.dm_tran_active_transactions tat ON tat.transaction_id = t.transaction_id WHERE s.is_user_process = 1 ORDER BY log_bytes_used DESC$ln7530$),   /* project-existing-session-source */
            ('SEC-SQL-AU-001-RC03', 'Check for logins from external hosts', '0513455cec1a5cddd3ee6ef6125eb009', 'f139095454f6b142f56ea2b64d64a334',
             $ln7530$SELECT TOP 20 s.login_name AS login_name, s.session_id, s.login_name, s.host_name, c.client_net_address, s.program_name, s.login_time FROM sys.dm_exec_sessions s JOIN sys.dm_exec_connections c ON s.session_id = c.session_id WHERE s.is_user_process = 1 ORDER BY s.login_time DESC$ln7530$),   /* project-existing-session-source */
            ('SEC-SQL-PRI-001-RC14', 'Detect active transactions touching sensitive columns (sqlserver)', '80ec8970a278617ced49c91cd7028270', 'e5a9740a33a14dd0211a487d394cfb88',
             $ln7530$SELECT s.login_name AS login_name, r.session_id, s.login_name, s.host_name, s.program_name, DB_NAME(r.database_id) AS database_name, sch.name AS schema_name, t.name AS table_name, c.name AS column_name, CASE WHEN LOWER(c.name) LIKE '%password%' OR LOWER(c.name) LIKE '%pass%' THEN 'Password' WHEN LOWER(c.name) LIKE '%secret%' OR LOWER(c.name) LIKE '%token%' OR LOWER(c.name) LIKE '%key%' THEN 'Credential' WHEN LOWER(c.name) LIKE '%credit%' OR LOWER(c.name) LIKE '%card%' THEN 'Credit Card' WHEN LOWER(c.name) LIKE '%ssn%' OR LOWER(c.name) LIKE '%bvn%' THEN 'ssn|bvn' WHEN LOWER(c.name) LIKE '%email%' THEN 'Email' WHEN LOWER(c.name) LIKE '%phone%' THEN 'Phone' WHEN LOWER(c.name) LIKE '%address%' THEN 'Address' WHEN LOWER(c.name) LIKE '%dob%' OR LOWER(c.name) LIKE '%birth%' THEN 'Date of Birth' WHEN LOWER(c.name) LIKE '%salary%' THEN 'Salary' ELSE 'Other Sensitive' END AS pii_category, LEFT(st.text, 4000) AS query_text, r.start_time, r.status FROM sys.dm_exec_requests r CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st JOIN sys.dm_exec_sessions s ON s.session_id = r.session_id JOIN sys.tables t ON t.is_ms_shipped = 0 JOIN sys.columns c ON c.object_id = t.object_id JOIN sys.schemas sch ON sch.schema_id = t.schema_id WHERE s.is_user_process = 1 AND r.session_id <> @@SPID AND st.text LIKE '%' + t.name + '%' AND (LOWER(c.name) LIKE '%password%' OR LOWER(c.name) LIKE '%pass%' OR LOWER(c.name) LIKE '%secret%' OR LOWER(c.name) LIKE '%token%' OR LOWER(c.name) LIKE '%key%' OR LOWER(c.name) LIKE '%credit%' OR LOWER(c.name) LIKE '%card%' OR LOWER(c.name) LIKE '%ssn%' OR LOWER(c.name) LIKE '%bvn%' OR LOWER(c.name) LIKE '%email%' OR LOWER(c.name) LIKE '%phone%' OR LOWER(c.name) LIKE '%address%' OR LOWER(c.name) LIKE '%dob%' OR LOWER(c.name) LIKE '%birth%' OR LOWER(c.name) LIKE '%salary%') ORDER BY r.session_id, t.name, c.name$ln7530$),   /* project-existing-session-source */
            ('SEC-SQL-PRI-001-RC14', 'Detect active transactions touching sensitive columns (sqlserver)', '80ec8970a278617ced49c91cd7028270', 'e5a9740a33a14dd0211a487d394cfb88',
             $ln7530$SELECT s.login_name AS login_name, r.session_id, s.login_name, s.host_name, s.program_name, DB_NAME(r.database_id) AS database_name, sch.name AS schema_name, t.name AS table_name, c.name AS column_name, CASE WHEN LOWER(c.name) LIKE '%password%' OR LOWER(c.name) LIKE '%pass%' THEN 'Password' WHEN LOWER(c.name) LIKE '%secret%' OR LOWER(c.name) LIKE '%token%' OR LOWER(c.name) LIKE '%key%' THEN 'Credential' WHEN LOWER(c.name) LIKE '%credit%' OR LOWER(c.name) LIKE '%card%' THEN 'Credit Card' WHEN LOWER(c.name) LIKE '%ssn%' OR LOWER(c.name) LIKE '%bvn%' THEN 'ssn|bvn' WHEN LOWER(c.name) LIKE '%email%' THEN 'Email' WHEN LOWER(c.name) LIKE '%phone%' THEN 'Phone' WHEN LOWER(c.name) LIKE '%address%' THEN 'Address' WHEN LOWER(c.name) LIKE '%dob%' OR LOWER(c.name) LIKE '%birth%' THEN 'Date of Birth' WHEN LOWER(c.name) LIKE '%salary%' THEN 'Salary' ELSE 'Other Sensitive' END AS pii_category, LEFT(st.text, 4000) AS query_text, r.start_time, r.status FROM sys.dm_exec_requests r CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st JOIN sys.dm_exec_sessions s ON s.session_id = r.session_id JOIN sys.tables t ON t.is_ms_shipped = 0 JOIN sys.columns c ON c.object_id = t.object_id JOIN sys.schemas sch ON sch.schema_id = t.schema_id WHERE s.is_user_process = 1 AND r.session_id <> @@SPID AND st.text LIKE '%' + t.name + '%' AND (LOWER(c.name) LIKE '%password%' OR LOWER(c.name) LIKE '%pass%' OR LOWER(c.name) LIKE '%secret%' OR LOWER(c.name) LIKE '%token%' OR LOWER(c.name) LIKE '%key%' OR LOWER(c.name) LIKE '%credit%' OR LOWER(c.name) LIKE '%card%' OR LOWER(c.name) LIKE '%ssn%' OR LOWER(c.name) LIKE '%bvn%' OR LOWER(c.name) LIKE '%email%' OR LOWER(c.name) LIKE '%phone%' OR LOWER(c.name) LIKE '%address%' OR LOWER(c.name) LIKE '%dob%' OR LOWER(c.name) LIKE '%birth%' OR LOWER(c.name) LIKE '%salary%') ORDER BY r.session_id, t.name, c.name$ln7530$)   /* project-existing-session-source */
        ) AS t(root_cause_id, step_name, old_md5, new_md5, new_sql)
    LOOP
        FOR s IN
            SELECT ds.id
            FROM rootcause.detection_paths dp
            JOIN rootcause.detection_path_steps dps ON dps.detection_path_id = dp.id
            JOIN rootcause.detection_steps ds       ON ds.id = dps.detection_step_id
            WHERE dp.vendor_slug = 'sqlserver'
              AND dp.root_cause_id = r.root_cause_id
              AND (r.step_name = '' OR ds.name = r.step_name)
        LOOP
            IF v_enc THEN
                EXECUTE 'SELECT rootcause.dec(content)->>''sql'' FROM rootcause.detection_steps WHERE id=$1'
                  INTO v_cur USING s.id;
            ELSE
                SELECT content->>'sql' INTO v_cur FROM rootcause.detection_steps WHERE id = s.id;
            END IF;

            IF v_cur IS NULL THEN
                v_miss := v_miss + 1; CONTINUE;
            END IF;
            IF md5(v_cur) = r.new_md5 THEN
                v_skip := v_skip + 1; CONTINUE;                    /* already applied */
            END IF;
            IF md5(v_cur) <> r.old_md5 THEN
                RAISE NOTICE '7530: % step % diverged from the validated original - left alone',
                             r.root_cause_id, s.id;
                v_miss := v_miss + 1; CONTINUE;
            END IF;

            IF v_enc THEN
                EXECUTE 'UPDATE rootcause.detection_steps SET content = rootcause.enc(jsonb_build_object(''sql'', $1)) WHERE id=$2'
                  USING r.new_sql, s.id;
            ELSE
                UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', r.new_sql)
                 WHERE id = s.id;
            END IF;
            v_done := v_done + 1;
            RAISE NOTICE '7530: login_name added to % (step %)', r.root_cause_id, s.id;
        END LOOP;
    END LOOP;

    RAISE NOTICE '7530: % step(s) updated, % already current, % skipped (missing or diverged)',
                 v_done, v_skip, v_miss;
END $mig$;

-- -----------------------------------------------------------------------------
-- VERIFY
--   After a collection cycle, every metric touched here should show a login on
--   at least the rows that have a session behind them:
--
--   WITH latest AS (
--     SELECT DISTINCT ON (metric_name, server) metric_name, metric_metadata
--       FROM monitoring.general_metric_metadata_results
--      WHERE entry_date > now() - interval '2 hours'
--        AND jsonb_typeof(metric_metadata) = 'array'
--      ORDER BY metric_name, server, entry_date DESC)
--   SELECT metric_name,
--          count(*) FILTER (WHERE nullif(j.value->>'login_name','') IS NOT NULL) AS with_login,
--          count(*) AS rows
--     FROM latest CROSS JOIN LATERAL jsonb_array_elements(metric_metadata) j(value)
--    WHERE metric_name IN ('HLTH-SQL-AD-001-RC04', 'HLTH-SQL-AD-002-RC05', 'HLTH-SQL-DM-001-RC07', 'HLTH-SQL-RP-001-RC07', 'HLTH-SQL-RP-001-RC17', 'HLTH-SQL-RP-006-RC05', 'HLTH-SQL-RP-006-RC10', 'HLTH-SQL-SM-002-RC12', 'HLTH-SQL-SM-004-RC07', 'HLTH-SQL-SM-004-RC12', 'HLTH-SQL-SM-004-RC13', 'HLTH-SQL-SM-007-RC11', 'PERF-SQL-TX-001-RC03', 'PERF-SQL-TX-001-RC05', 'PERF-SQL-TX-001-RC07', 'PERF-SQL-TX-001-RC09', 'PERF-SQL-TX-001-RC11', 'SEC-SQL-ACC-010-RC07', 'SEC-SQL-ACC-010-RC08', 'SEC-SQL-ACC-010-RC09', 'SEC-SQL-ACC-010-RC11', 'SEC-SQL-ACC-010-RC12', 'SEC-SQL-ACC-010-RC13', 'SEC-SQL-AU-001-RC03', 'SEC-SQL-PRI-001-RC14')
--    GROUP BY 1 ORDER BY 1;
--
-- STILL UNATTRIBUTED - hand work, by reason:
--    61  ORIGINAL fails (192.168.1.229)
--          HLTH-SQL-AD-001-RC02, HLTH-SQL-AD-001-RC05, HLTH-SQL-AD-002-RC04, HLTH-SQL-AD-002-RC13, HLTH-SQL-AD-002-RC14, HLTH-SQL-AD-002-RC15
--          HLTH-SQL-AD-003-RC18, HLTH-SQL-BR-003-RC02, HLTH-SQL-CD-002-RC11, HLTH-SQL-CD-004-RC15, HLTH-SQL-CD-004-RC16, HLTH-SQL-DM-001-RC05
--          ... and 38 more
--    60  no attributable source in this statement
--          HLTH-SQL-AD-001-RC01, HLTH-SQL-AD-001-RC03, HLTH-SQL-AD-001-RC04, HLTH-SQL-AD-001-RC07, HLTH-SQL-AD-001-RC08, HLTH-SQL-AD-001-RC10
--          HLTH-SQL-AD-001-RC11, HLTH-SQL-AD-001-RC12, HLTH-SQL-AD-001-RC13, HLTH-SQL-AD-001-RC14, HLTH-SQL-AD-002-RC10, HLTH-SQL-CD-001-RC04
--          ... and 40 more
--    19  could not locate the SELECT head
--          HLTH-SQL-DM-006-RC14, HLTH-SQL-HA-001-RC06, HLTH-SQL-HA-004-RC01, HLTH-SQL-SJ-005-RC08, HLTH-SQL-SM-001-RC04, HLTH-SQL-UP-004-RC21
--          PERF-SQL-QE-001-RC04, PERF-SQL-QE-001-RC08, PERF-SQL-TX-001-RC01, PERF-SQL-TX-001-RC02, PERF-SQL-TX-001-RC04, PERF-SQL-TX-001-RC08
--          ... and 3 more
--    15  multi-statement batch (control flow)
--          HLTH-SQL-DM-007-RC05, HLTH-SQL-LM-001-RC07, HLTH-SQL-LM-005-RC10, HLTH-SQL-RP-001-RC11, HLTH-SQL-SM-001-RC13, HLTH-SQL-SM-002-RC01
--          HLTH-SQL-SM-002-RC03, HLTH-SQL-SM-003-RC04, HLTH-SQL-SM-006-RC17, HLTH-SQL-SM-007-RC05, PERF-SQL-TX-001-RC10, PERF-SQL-TX-002-RC02
--          ... and 3 more
--     9  not a SELECT/CTE batch (control flow or DML)
--          HLTH-SQL-CD-001-RC08, HLTH-SQL-CD-001-RC11, HLTH-SQL-SM-001-RC11, HLTH-SQL-SM-003-RC01, SEC-SQL-AUD-020-RC01, SEC-SQL-AUD-020-RC02
--          SEC-SQL-AUD-020-RC03, SEC-SQL-AUD-020-RC04, SEC-SQL-AUD-021-RC01
--     5  already selects login_name
--          SEC-SQL-AUD-020-RC01, SEC-SQL-AUD-020-RC02, SEC-SQL-AUD-020-RC03, SEC-SQL-AUD-021-RC01, SEC-SQL-PRI-001-RC15
-- -----------------------------------------------------------------------------
