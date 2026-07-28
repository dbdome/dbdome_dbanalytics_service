-- ============================================================
-- 6860  HLTH-SQL-SYS-013-RC01  Blocked sessions captured with blocker identity (sqlserver)
--   HEALTH system series root cause.
--   Enriched from the base blocked-requests query:
--     * joined the BLOCKER side: login/host/program/status, its current or
--       last statement (falling back to the connection most_recent_sql_handle
--       when the blocker is idle), and blocker_blocked_by (0 = head of
--       chain) -- the base query named the blocker session id but told you
--       nothing about it
--     * blocked side gets session identity + statement text + database
--     * transaction_isolation_level decoded to its name
--   2005+. Requires VIEW SERVER STATE. Zero rows = healthy.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-013','HLTH','SQL','SYS','Active Blocking Chains','blocking-sessions',
        'Live blocked-session snapshot with full blocker identity: who is blocked, by whom, on what resource, and what both sides are running.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-013-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-013-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-013-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-013-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-013-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-013-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-013-RC01', 'HLTH-SQL-SYS-013', 'Blocked sessions captured with blocker identity',
    'blocking-sessions-rc01',
    'Every currently blocked request with wait time/type/resource and decoded isolation level, PLUS the blocker side: its login/host/program, status (sleeping = idle blocker holding an open transaction), its running or last statement, and blocker_blocked_by (0 = that blocker is the HEAD of the chain). Zero rows = no blocking right now.',
    ARRAY['health', 'blocking', 'locking', 'waits', 'chains'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-013-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nSELECT TOP 500\n    r.session_id,\n    r.blocking_session_id,\n    ISNULL(bs_r.blocking_session_id, 0) AS blocker_blocked_by,\n    r.wait_time AS wait_time_ms,\n    r.wait_type,\n    r.last_wait_type,\n    r.wait_resource,\n    CASE r.transaction_isolation_level WHEN 0 THEN ''Unspecified'' WHEN 1 THEN ''ReadUncommitted'' WHEN 2 THEN ''ReadCommitted'' WHEN 3 THEN ''RepeatableRead'' WHEN 4 THEN ''Serializable'' WHEN 5 THEN ''Snapshot'' ELSE CAST(r.transaction_isolation_level AS varchar(10)) END AS isolation_level,\n    r.lock_timeout AS lock_timeout_ms,\n    DB_NAME(r.database_id) AS database_name,\n    s.login_name AS blocked_login,\n    s.host_name AS blocked_host,\n    s.program_name AS blocked_program,\n    LEFT(t.text, 4000) AS blocked_sql_text,\n    bs.login_name AS blocker_login,\n    bs.host_name AS blocker_host,\n    bs.program_name AS blocker_program,\n    bs.status AS blocker_status,\n    LEFT(bt.text, 4000) AS blocker_sql_text\nFROM sys.dm_exec_requests r\nJOIN sys.dm_exec_sessions s ON s.session_id = r.session_id\nLEFT JOIN sys.dm_exec_sessions bs ON bs.session_id = r.blocking_session_id\nLEFT JOIN sys.dm_exec_requests bs_r ON bs_r.session_id = r.blocking_session_id\nLEFT JOIN sys.dm_exec_connections bc ON bc.session_id = r.blocking_session_id\nOUTER APPLY sys.dm_exec_sql_text(r.sql_handle) t\nOUTER APPLY sys.dm_exec_sql_text(COALESCE(bs_r.sql_handle, bc.most_recent_sql_handle)) bt\nWHERE r.blocking_session_id <> 0\nORDER BY r.wait_time DESC"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Blocked sessions present (zero rows = no blocking)"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET
    content = EXCLUDED.content, expected = EXCLUDED.expected;

DO $gen$
DECLARE
    v_step_id   bigint;
    v_path_id   bigint;
    v_res_step  bigint;
    v_res_path  bigint;
BEGIN
    SELECT id INTO v_step_id FROM rootcause.detection_steps
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-013-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-013-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-013-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-013-RC01 (sqlserver)', 'Blocked sessions captured with blocker identity', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-013-RC01 (sqlserver)', '{"action": "Walk to the head: blocker_blocked_by = 0 marks the head blocker - fix or kill THAT session, not the victims; blocker_status = sleeping means an application holds an open transaction while idle (correlate HLTH-SQL-SYS-003 and fix the missing COMMIT); long waits on LCK_M_S from reporting queries suggest enabling RCSI; wait_resource names the contended object/page/row."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-013-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-013-RC01 (sqlserver)', 'resolve-hlth_sql_sys_013_rc01-sqlserver', 'Blocked sessions captured with blocker identity: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_sys_013_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'session_id')::int              AS session_id,
    (j.value ->> 'blocking_session_id')::int     AS blocking_session_id,
    (j.value ->> 'blocker_blocked_by')::int      AS blocker_blocked_by,
    (j.value ->> 'wait_time_ms')::bigint         AS wait_time_ms,
    (j.value ->> 'wait_type')                    AS wait_type,
    (j.value ->> 'last_wait_type')               AS last_wait_type,
    (j.value ->> 'wait_resource')                AS wait_resource,
    (j.value ->> 'isolation_level')              AS isolation_level,
    (j.value ->> 'lock_timeout_ms')::bigint      AS lock_timeout_ms,
    (j.value ->> 'database_name')                AS database_name,
    (j.value ->> 'blocked_login')                AS blocked_login,
    (j.value ->> 'blocked_host')                 AS blocked_host,
    (j.value ->> 'blocked_program')              AS blocked_program,
    (j.value ->> 'blocked_sql_text')             AS blocked_sql_text,
    (j.value ->> 'blocker_login')                AS blocker_login,
    (j.value ->> 'blocker_host')                 AS blocker_host,
    (j.value ->> 'blocker_program')              AS blocker_program,
    (j.value ->> 'blocker_status')               AS blocker_status,
    (j.value ->> 'blocker_sql_text')             AS blocker_sql_text,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-013-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_013_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_013_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-013-RC01';

COMMIT;
