-- ============================================================
-- 6760  HLTH-SQL-SYS-003-RC01  Active transactions (sqlserver)
--   Third HEALTH system root cause (series: 6740 NUMA, 6750 active sessions).
--
--   Rebuilt from the base dm_exec_requests query, fixing three defects:
--     * base is now dm_tran_session_transactions + dm_tran_active_transactions,
--       LEFT-joined to dm_exec_requests -- so IDLE sessions holding an open
--       transaction (the classic log-growth / blocking culprit) are captured;
--       for those the statement text comes from the connection''s
--       most_recent_sql_handle
--     * the missing-index block was LEFT JOIN ... ON 1=1 (cartesian: every
--       request x every missing index on the instance); replaced with an
--       OUTER APPLY TOP 1 scoped to the transaction''s database, keeping the
--       same improvement_measure formula and CREATE INDEX statement
--     * CROSS APPLY dm_exec_query_plan silently dropped requests with no
--       cached plan and its output was unused -- removed
--   Enriched with: transaction name/begin time/state (decoded), per-tx log
--   bytes used (dm_tran_database_transactions -- log truncation risk),
--   is_idle_with_open_tran flag, decoded duration from the TRANSACTION begin
--   time (not the request), session identity.
--   Filters: is_user_process = 1 (instead of session_id > 50),
--   user transactions only, excludes the collector (@@SPID); the old
--   database_id > 4 filter is dropped so tempdb-heavy transactions stay
--   visible. TOP 500 by duration.
--   Every object/column is SQL Server 2005+ -- fits all versions with one
--   static query. Requires VIEW SERVER STATE.
--
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

-- 0) AREA + ISSUE -----------------------------------------------------------
INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-003','HLTH','SQL','SYS','Active Transaction Health','active-transaction-health',
        'Monitor open transactions: duration, idle sessions holding transactions, transaction log consumption, blocking and the statements involved.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

-- cleanup of any prior HLTH-SQL-SYS-003-RC01 artifacts (idempotent rebuild)
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-003-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-003-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-003-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-003-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-003-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-003-RC01 %';

-- 1) ROOT CAUSE -------------------------------------------------------------
INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-003-RC01', 'HLTH-SQL-SYS-003', 'Active transactions captured (incl. idle open transactions)',
    'active-transactions',
    'Snapshot of every open user transaction: duration since transaction begin, state, per-transaction log bytes used, whether the owning session is idle (open transaction with no active request), blocking session, request progress and IO, session identity, the statement involved, and the top missing-index suggestion for the transaction''s database (improvement measure + ready CREATE INDEX statement). Feeds long-transaction, log-growth and blocking health checks.',
    ARRAY['health', 'transactions', 'locking', 'blocking', 'log', 'missing-index'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

-- 2) DETECTION STEP (sqlserver) --------------------------------------------
INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-003-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nSELECT TOP 500\n    st.session_id,\n    r.blocking_session_id,\n    DATEDIFF(SECOND, at2.transaction_begin_time, GETDATE()) AS duration_sec,\n    DB_NAME(COALESCE(r.database_id, lgdb.database_id)) AS database_name,\n    at2.name AS transaction_name,\n    CONVERT(varchar(19), at2.transaction_begin_time, 120) AS transaction_begin_time,\n    CASE at2.transaction_state WHEN 0 THEN ''Initializing'' WHEN 1 THEN ''Initialized'' WHEN 2 THEN ''Active'' WHEN 3 THEN ''Ended'' WHEN 4 THEN ''PreparingCommit'' WHEN 5 THEN ''Prepared'' WHEN 6 THEN ''Committed'' WHEN 7 THEN ''RollingBack'' WHEN 8 THEN ''RolledBack'' ELSE CAST(at2.transaction_state AS varchar(10)) END AS transaction_state,\n    CASE WHEN r.session_id IS NULL THEN 1 ELSE 0 END AS is_idle_with_open_tran,\n    (SELECT COUNT(*) FROM sys.dm_tran_session_transactions st2 WHERE st2.session_id = st.session_id) AS open_transaction_count,\n    lg.log_bytes_used,\n    CONVERT(varchar(19), r.start_time, 120) AS request_start_time,\n    CONVERT(varchar(19), s.last_request_end_time, 120) AS last_request_end_time,\n    s.cpu_time AS session_cpu_time_ms,\n    r.command,\n    r.logical_reads,\n    r.reads,\n    r.writes,\n    CONVERT(decimal(5,1), r.percent_complete) AS percent_complete,\n    r.wait_type,\n    r.last_wait_type,\n    s.login_name,\n    s.program_name,\n    s.host_name,\n    LEFT(t.text, 4000) AS sql_text,\n    mi.improvement_measure,\n    mi.equality_columns,\n    mi.statement AS missing_index_table,\n    mi.create_index_statement\nFROM sys.dm_tran_session_transactions st\nJOIN sys.dm_tran_active_transactions at2 ON at2.transaction_id = st.transaction_id\nJOIN sys.dm_exec_sessions s ON s.session_id = st.session_id\nLEFT JOIN sys.dm_exec_requests r ON r.session_id = st.session_id\nLEFT JOIN sys.dm_exec_connections c ON c.session_id = st.session_id\nOUTER APPLY (SELECT TOP 1 tdt.database_id FROM sys.dm_tran_database_transactions tdt WHERE tdt.transaction_id = st.transaction_id ORDER BY tdt.database_transaction_log_bytes_used DESC) lgdb\nOUTER APPLY (SELECT SUM(tdt.database_transaction_log_bytes_used) AS log_bytes_used FROM sys.dm_tran_database_transactions tdt WHERE tdt.transaction_id = st.transaction_id) lg\nOUTER APPLY sys.dm_exec_sql_text(COALESCE(r.sql_handle, c.most_recent_sql_handle)) t\nOUTER APPLY (SELECT TOP 1\n        CONVERT(decimal(28,1), migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans)) AS improvement_measure,\n        mid.equality_columns,\n        mid.statement,\n        ''CREATE INDEX IX_'' + CONVERT(varchar(20), mig.index_group_handle) + ''_'' + CONVERT(varchar(20), mid.index_handle) + '' ON '' + mid.statement + '' ('' + ISNULL(mid.equality_columns, '''') + CASE WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL THEN '','' ELSE '''' END + ISNULL(mid.inequality_columns, '''') + '')'' + ISNULL('' INCLUDE ('' + mid.included_columns + '')'', '''') AS create_index_statement\n     FROM sys.dm_db_missing_index_details mid\n     JOIN sys.dm_db_missing_index_groups mig ON mig.index_handle = mid.index_handle\n     JOIN sys.dm_db_missing_index_group_stats migs ON migs.group_handle = mig.index_group_handle\n     WHERE mid.database_id = COALESCE(r.database_id, lgdb.database_id)\n     ORDER BY migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans) DESC) mi\nWHERE s.is_user_process = 1 AND st.is_user_transaction = 1 AND st.session_id <> @@SPID\nORDER BY duration_sec DESC"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Open user transactions captured with duration, log usage and blocking detail"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET
    content = EXCLUDED.content, expected = EXCLUDED.expected;

-- 3) DETECTION PATH + RESOLUTION -------------------------------------------
DO $gen$
DECLARE
    v_step_id   bigint;
    v_path_id   bigint;
    v_res_step  bigint;
    v_res_path  bigint;
BEGIN
    SELECT id INTO v_step_id FROM rootcause.detection_steps
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-003-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-003-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-003-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-003-RC01 (sqlserver)', 'Active transactions captured (incl. idle open transactions)', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-003-RC01 (sqlserver)', '{"action": "Prioritize is_idle_with_open_tran = 1 rows: a sleeping session holding a transaction blocks log truncation and other sessions indefinitely -- identify the application via login/host/program and last statement, fix the missing COMMIT/ROLLBACK before considering KILL. Watch log_bytes_used growth (log-full risk), long duration_sec with blocking_session_id chains, and RollingBack state (do NOT kill -- rollback must finish). The missing-index columns are the top suggestion for that database (heuristic): validate against the workload before creating the index."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-003-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-003-RC01 (sqlserver)', 'resolve-hlth_sql_sys_003_rc01-sqlserver', 'Triage open transactions: idle holders, log consumption, blocking chains and rollback state before any kill decision.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

-- 4) MONITORING VIEW --------------------------------------------------------
CREATE OR REPLACE VIEW monitoring.v_hlth_sql_sys_003_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'session_id')::int              AS session_id,
    (j.value ->> 'blocking_session_id')::int     AS blocking_session_id,
    (j.value ->> 'duration_sec')::bigint         AS duration_sec,
    (j.value ->> 'database_name')                AS database_name,
    (j.value ->> 'transaction_name')             AS transaction_name,
    (j.value ->> 'transaction_begin_time')       AS transaction_begin_time,
    (j.value ->> 'transaction_state')            AS transaction_state,
    (j.value ->> 'is_idle_with_open_tran')::int  AS is_idle_with_open_tran,
    (j.value ->> 'open_transaction_count')::int  AS open_transaction_count,
    (j.value ->> 'log_bytes_used')::bigint       AS log_bytes_used,
    (j.value ->> 'request_start_time')           AS request_start_time,
    (j.value ->> 'last_request_end_time')        AS last_request_end_time,
    (j.value ->> 'session_cpu_time_ms')::bigint  AS session_cpu_time_ms,
    (j.value ->> 'command')                      AS command,
    (j.value ->> 'logical_reads')::bigint        AS logical_reads,
    (j.value ->> 'reads')::bigint                AS reads,
    (j.value ->> 'writes')::bigint               AS writes,
    (j.value ->> 'percent_complete')::numeric    AS percent_complete,
    (j.value ->> 'wait_type')                    AS wait_type,
    (j.value ->> 'last_wait_type')               AS last_wait_type,
    (j.value ->> 'login_name')                   AS login_name,
    (j.value ->> 'program_name')                 AS program_name,
    (j.value ->> 'host_name')                    AS host_name,
    (j.value ->> 'sql_text')                     AS sql_text,
    (j.value ->> 'improvement_measure')::numeric AS improvement_measure,
    (j.value ->> 'equality_columns')             AS equality_columns,
    (j.value ->> 'missing_index_table')          AS missing_index_table,
    (j.value ->> 'create_index_statement')       AS create_index_statement,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-003-RC01';

-- keep view/grants aligned with the 6690 hardening when the engine role exists
DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_003_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_003_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

-- 5) VERIFY ----------------------------------------------------------------
SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-003-RC01';

COMMIT;
