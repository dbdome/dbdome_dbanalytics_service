-- ============================================================
-- 6750  HLTH-SQL-SYS-002-RC01  Active sessions, waits & blocking (sqlserver)
--   Second HEALTH system root cause (series started in 6740).
--
--   Enriched from the base dm_exec_requests query:
--     * joined sys.dm_exec_sessions for login/host/program identity
--     * blocking_session_id kept front and center (blocking-chain analysis)
--     * transaction_isolation_level decoded to its name
--     * added status, command, database, cpu/elapsed/reads/writes/row_count,
--       request start_time and the CURRENT STATEMENT text via
--       sys.dm_exec_sql_text (statement offsets honoured)
--     * excludes system sessions and the collector itself (@@SPID)
--   Every column exists on SQL Server 2005+ — fits all versions with a single
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
VALUES ('HLTH-SQL-SYS-002','HLTH','SQL','SYS','Active Sessions & Wait Health','active-sessions-wait-health',
        'Monitor the live request workload: which sessions are running, what they wait on, who blocks whom, isolation levels and per-request resource consumption.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

-- cleanup of any prior HLTH-SQL-SYS-002-RC01 artifacts (idempotent rebuild)
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-002-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-002-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-002-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-002-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-002-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-002-RC01 %';

-- 1) ROOT CAUSE -------------------------------------------------------------
INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-002-RC01', 'HLTH-SQL-SYS-002', 'Active sessions with waits & blocking captured',
    'active-sessions-waits-blocking',
    'Snapshot of every active user request: session and blocking-session id, current/last wait type, wait time and resource, decoded transaction isolation level, lock timeout, session identity (login/host/program), database, per-request CPU/elapsed/IO/row counts and the statement text currently executing. Feeds blocking-chain, wait-profile and long-runner health checks.',
    ARRAY['health', 'sessions', 'waits', 'blocking', 'locking', 'workload'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

-- 2) DETECTION STEP (sqlserver) --------------------------------------------
INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-002-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nSELECT r.session_id,\n    r.blocking_session_id,\n    r.status,\n    r.command,\n    DB_NAME(r.database_id) AS database_name,\n    s.login_name,\n    s.host_name,\n    s.program_name,\n    r.wait_time AS wait_time_ms,\n    r.wait_type,\n    r.last_wait_type,\n    r.wait_resource,\n    CASE r.transaction_isolation_level WHEN 0 THEN ''Unspecified'' WHEN 1 THEN ''ReadUncommitted'' WHEN 2 THEN ''ReadCommitted'' WHEN 3 THEN ''RepeatableRead'' WHEN 4 THEN ''Serializable'' WHEN 5 THEN ''Snapshot'' ELSE CAST(r.transaction_isolation_level AS varchar(10)) END AS isolation_level,\n    r.lock_timeout AS lock_timeout_ms,\n    r.cpu_time AS cpu_time_ms,\n    r.total_elapsed_time AS elapsed_time_ms,\n    r.logical_reads,\n    r.reads,\n    r.writes,\n    r.row_count,\n    CONVERT(varchar(19), r.start_time, 120) AS start_time,\n    LEFT(SUBSTRING(t.text, r.statement_start_offset/2 + 1,\n         CASE WHEN r.statement_end_offset > 0 THEN (r.statement_end_offset - r.statement_start_offset)/2 + 1 ELSE 4000 END), 4000) AS sql_text\nFROM sys.dm_exec_requests r\nJOIN sys.dm_exec_sessions s ON s.session_id = r.session_id\nOUTER APPLY sys.dm_exec_sql_text(r.sql_handle) t\nWHERE s.is_user_process = 1 AND r.session_id <> @@SPID\nORDER BY r.blocking_session_id DESC, r.wait_time DESC"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Active user requests captured with wait and blocking detail"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-002-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-002-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-002-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-002-RC01 (sqlserver)', 'Active sessions with waits & blocking captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-002-RC01 (sqlserver)', '{"action": "Review the snapshot for: non-zero blocking_session_id chains (find the head blocker: a session that blocks others but has blocking_session_id = 0), wait_time_ms spikes on LCK_% (lock contention), PAGEIOLATCH_% (storage latency), CXPACKET/CXCONSUMER (parallelism), RESOURCE_SEMAPHORE (memory grants); ReadUncommitted isolation on critical writes; and long-running statements via elapsed_time_ms vs start_time. Correlate sql_text with the blocking resource before killing any session."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-002-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-002-RC01 (sqlserver)', 'resolve-hlth_sql_sys_002_rc01-sqlserver', 'Analyze blocking chains, wait-type profile and long runners from the active-session snapshot.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

-- 4) MONITORING VIEW --------------------------------------------------------
CREATE OR REPLACE VIEW monitoring.v_hlth_sql_sys_002_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'session_id')::int            AS session_id,
    (j.value ->> 'blocking_session_id')::int   AS blocking_session_id,
    (j.value ->> 'status')                     AS status,
    (j.value ->> 'command')                    AS command,
    (j.value ->> 'database_name')              AS database_name,
    (j.value ->> 'login_name')                 AS login_name,
    (j.value ->> 'host_name')                  AS host_name,
    (j.value ->> 'program_name')               AS program_name,
    (j.value ->> 'wait_time_ms')::bigint       AS wait_time_ms,
    (j.value ->> 'wait_type')                  AS wait_type,
    (j.value ->> 'last_wait_type')             AS last_wait_type,
    (j.value ->> 'wait_resource')              AS wait_resource,
    (j.value ->> 'isolation_level')            AS isolation_level,
    (j.value ->> 'lock_timeout_ms')::bigint    AS lock_timeout_ms,
    (j.value ->> 'cpu_time_ms')::bigint        AS cpu_time_ms,
    (j.value ->> 'elapsed_time_ms')::bigint    AS elapsed_time_ms,
    (j.value ->> 'logical_reads')::bigint      AS logical_reads,
    (j.value ->> 'reads')::bigint              AS reads,
    (j.value ->> 'writes')::bigint             AS writes,
    (j.value ->> 'row_count')::bigint          AS row_count,
    (j.value ->> 'start_time')                 AS start_time,
    (j.value ->> 'sql_text')                   AS sql_text,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-002-RC01';

-- keep view/grants aligned with the 6690 hardening when the engine role exists
DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_002_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_002_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

-- 5) VERIFY ----------------------------------------------------------------
SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-002-RC01';

COMMIT;
