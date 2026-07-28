-- ============================================================
-- 6770  HLTH-SQL-SYS-004-RC01  Recent sessions & lock footprint (sqlserver)
--   Fourth HEALTH system root cause (series: 6740 NUMA, 6750 sessions,
--   6760 transactions). Sessions that logged in within the last 120 seconds
--   (connection churn / login-storm visibility) with their lock footprint.
--
--   Rebuilt from the base sysprocesses query:
--     * CROSS APPLY dm_exec_sql_text dropped sessions with no sql_handle --
--       i.e. freshly-connected idle sessions, exactly what this check is for;
--       now OUTER APPLY with most_recent_sql_handle fallback
--     * [locked] = ISNULL(request_session_id,0) returned the SESSION ID (or 0),
--       not a flag; replaced with holds_locks (0/1) + lock_count
--     * deprecated sys.sysprocesses replaced with dm_exec_sessions /
--       dm_exec_connections / dm_exec_requests (sysprocesses kept ONLY as the
--       database-id fallback for idle sessions -- dm_exec_sessions.database_id
--       needs 2012+); memusage pages converted to KB; physical_io split into
--       reads / writes + logical_reads
--     * enriched with client_net_address + auth_scheme (where the connection
--       came from and how it authenticated), client_interface_name,
--       blocking_session_id, last_request_start/end times
--     * spid > 50 replaced with is_user_process = 1; excludes the collector
--   Every object/column is SQL Server 2005+ -- fits all versions with one
--   static query. Requires VIEW SERVER STATE.
--   Zero rows simply means no new connections in the window (ruled_out).
--
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

-- 0) AREA + ISSUE -----------------------------------------------------------
INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-004','HLTH','SQL','SYS','Recent Connection Activity','recent-connection-activity',
        'Monitor sessions that connected in the last two minutes: who, from where, how authenticated, what they run and whether they already hold locks. Surfaces connection churn, login storms and immediately-locking newcomers.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

-- cleanup of any prior HLTH-SQL-SYS-004-RC01 artifacts (idempotent rebuild)
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-004-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-004-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-004-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-004-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-004-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-004-RC01 %';

-- 1) ROOT CAUSE -------------------------------------------------------------
INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-004-RC01', 'HLTH-SQL-SYS-004', 'Recent sessions captured with lock footprint',
    'recent-sessions-lock-footprint',
    'Snapshot of sessions whose login_time is within the last 120 seconds: session identity (login, NT domain/user, host, program, client interface), connection source IP and auth scheme, current/last request times, executing or last statement text, per-session CPU/memory/IO, blocking id, and whether the session already holds locks (holds_locks + lock_count from dm_tran_locks). Feeds connection-churn, login-storm and eager-locker health checks.',
    ARRAY['health', 'sessions', 'connections', 'locks', 'login-storm', 'churn'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

-- 2) DETECTION STEP (sqlserver) --------------------------------------------
INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-004-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nSELECT TOP 500\n    s.session_id,\n    r.blocking_session_id,\n    CASE WHEN lk.lock_count > 0 THEN 1 ELSE 0 END AS holds_locks,\n    lk.lock_count,\n    DATEDIFF(SECOND, s.login_time, GETDATE()) AS session_age_sec,\n    CONVERT(varchar(19), s.login_time, 120) AS login_time,\n    CONVERT(varchar(19), s.last_request_start_time, 120) AS last_request_start_time,\n    CONVERT(varchar(19), s.last_request_end_time, 120) AS last_request_end_time,\n    s.status,\n    r.command,\n    DB_NAME(COALESCE(r.database_id, sp.dbid)) AS database_name,\n    s.login_name,\n    s.nt_domain,\n    s.nt_user_name,\n    s.host_name,\n    s.program_name,\n    s.client_interface_name,\n    c.client_net_address,\n    c.auth_scheme,\n    s.cpu_time AS cpu_time_ms,\n    s.memory_usage * 8 AS memory_kb,\n    s.logical_reads,\n    s.reads,\n    s.writes,\n    LEFT(t.text, 4000) AS sql_text\nFROM sys.dm_exec_sessions s\nLEFT JOIN sys.dm_exec_connections c ON c.session_id = s.session_id\nLEFT JOIN sys.dm_exec_requests r ON r.session_id = s.session_id\nLEFT JOIN master.dbo.sysprocesses sp ON sp.spid = s.session_id AND sp.ecid = 0\nOUTER APPLY sys.dm_exec_sql_text(COALESCE(r.sql_handle, c.most_recent_sql_handle)) t\nOUTER APPLY (SELECT COUNT(*) AS lock_count FROM sys.dm_tran_locks tl WHERE tl.request_session_id = s.session_id) lk\nWHERE s.is_user_process = 1 AND s.session_id <> @@SPID\n  AND s.login_time >= DATEADD(SECOND, -120, GETDATE())\nORDER BY s.login_time DESC"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Sessions that connected within the last 120 seconds (zero rows = no new connections)"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-004-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-004-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-004-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-004-RC01 (sqlserver)', 'Recent sessions captured with lock footprint', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-004-RC01 (sqlserver)', '{"action": "Review the newcomers: many sessions from one client_net_address/program in a short window suggests connection-pool misconfiguration or a login storm (check pool settings / app restart loops); holds_locks = 1 seconds after login with rising lock_count flags eager lockers worth correlating with blocking; unexpected auth_scheme (e.g. SQL instead of KERBEROS) or unknown host/program values are worth a security look (cross-check SEC-SQL-AUD-021).", "note": "Zero rows is normal - it just means no connections in the last two minutes."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-004-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-004-RC01 (sqlserver)', 'resolve-hlth_sql_sys_004_rc01-sqlserver', 'Review recent connections for churn, login storms, eager lockers and unexpected sources.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

-- 4) MONITORING VIEW --------------------------------------------------------
CREATE OR REPLACE VIEW monitoring.v_hlth_sql_sys_004_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'session_id')::int              AS session_id,
    (j.value ->> 'blocking_session_id')::int     AS blocking_session_id,
    (j.value ->> 'holds_locks')::int             AS holds_locks,
    (j.value ->> 'lock_count')::int              AS lock_count,
    (j.value ->> 'session_age_sec')::bigint      AS session_age_sec,
    (j.value ->> 'login_time')                   AS login_time,
    (j.value ->> 'last_request_start_time')      AS last_request_start_time,
    (j.value ->> 'last_request_end_time')        AS last_request_end_time,
    (j.value ->> 'status')                       AS status,
    (j.value ->> 'command')                      AS command,
    (j.value ->> 'database_name')                AS database_name,
    (j.value ->> 'login_name')                   AS login_name,
    (j.value ->> 'nt_domain')                    AS nt_domain,
    (j.value ->> 'nt_user_name')                 AS nt_user_name,
    (j.value ->> 'host_name')                    AS host_name,
    (j.value ->> 'program_name')                 AS program_name,
    (j.value ->> 'client_interface_name')        AS client_interface_name,
    (j.value ->> 'client_net_address')           AS client_net_address,
    (j.value ->> 'auth_scheme')                  AS auth_scheme,
    (j.value ->> 'cpu_time_ms')::bigint          AS cpu_time_ms,
    (j.value ->> 'memory_kb')::bigint            AS memory_kb,
    (j.value ->> 'logical_reads')::bigint        AS logical_reads,
    (j.value ->> 'reads')::bigint                AS reads,
    (j.value ->> 'writes')::bigint               AS writes,
    (j.value ->> 'sql_text')                     AS sql_text,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-004-RC01';

-- keep view/grants aligned with the 6690 hardening when the engine role exists
DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_004_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_004_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

-- 5) VERIFY ----------------------------------------------------------------
SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-004-RC01';

COMMIT;
