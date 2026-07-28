-- ============================================================
-- 7060  HLTH-SQL-SYS-033-RC01  Long executions vs baseline captured (sqlserver)
--   HEALTH system series root cause.
--   Reimplemented from the legacy monitoring.long_procedures maintenance
--   fragment (UPDATE baseline + DELETE >1 day): the repository-side baseline
--   table is unnecessary -
--     * sys.dm_exec_procedure_stats already holds each procedure''s average
--       duration (the baseline); this detection joins live dm_exec_requests
--       against it via the sql_text object id
--     * flags: running > 5s AND (> 2x its baseline OR no baseline)
--     * no purge job needed; the collector''s history in gmmr provides the
--       long-term trend the old table approximated
--   2008+ (dm_exec_procedure_stats). Requires VIEW SERVER STATE.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-033','HLTH','SQL','SYS','Long-Running Executions vs Baseline','long-running-executions',
        'Currently executing statements that run long against their own historical average - the live regression detector.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-033-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-033-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-033-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-033-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-033-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-033-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-033-RC01', 'HLTH-SQL-SYS-033', 'Long executions vs baseline captured',
    'long-running-executions-rc01',
    'Every request running longer than 5 seconds that is ALSO over twice its procedure historical average duration (from dm_exec_procedure_stats) or has no baseline at all (ad-hoc batch): session identity, database, procedure name, current elapsed vs baseline avg, times-over-baseline factor, wait/blocking state and the batch text. Zero rows = nothing running abnormally long right now. Replaces the repository-side long_procedures baseline table + purge maintenance: the plan cache IS the baseline.',
    ARRAY['health', 'procedures', 'duration', 'regression', 'baseline'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-033-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nSELECT TOP 100\n    r.session_id,\n    s.login_name,\n    s.host_name,\n    s.program_name,\n    DB_NAME(t.dbid) AS database_name,\n    OBJECT_NAME(t.objectid, t.dbid) AS procedure_name,\n    r.total_elapsed_time AS current_elapsed_ms,\n    ps.avg_ms AS baseline_avg_ms,\n    CAST(r.total_elapsed_time * 1.0 / NULLIF(ps.avg_ms, 0) AS decimal(12,1)) AS times_over_baseline,\n    r.status,\n    r.wait_type,\n    r.blocking_session_id,\n    CONVERT(varchar(19), r.start_time, 120) AS start_time,\n    LEFT(t.text, 4000) AS batch_text\nFROM sys.dm_exec_requests r\nJOIN sys.dm_exec_sessions s ON s.session_id = r.session_id\nCROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t\nLEFT JOIN (\n    SELECT object_id, database_id,\n           total_elapsed_time/1000/NULLIF(execution_count, 0) AS avg_ms\n    FROM sys.dm_exec_procedure_stats\n) ps ON ps.object_id = t.objectid AND ps.database_id = t.dbid\nWHERE s.is_user_process = 1\n  AND r.session_id <> @@SPID\n  AND r.total_elapsed_time > 5000\n  AND (ps.avg_ms IS NULL OR r.total_elapsed_time > 2 * ps.avg_ms)\nORDER BY times_over_baseline DESC, r.total_elapsed_time DESC"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Abnormally long executions present (zero rows = none right now)"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-033-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-033-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-033-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-033-RC01 (sqlserver)', 'Long executions vs baseline captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-033-RC01 (sqlserver)', '{"action": "times_over_baseline is the triage order: a proc at 20x its average with a wait_type points at blocking or a plan regression (check blocking_session_id, then compare the plan - parameter sniffing is the classic cause); baseline_avg_ms NULL means an ad-hoc batch with no history - judge by absolute time; recurring appearances of the same procedure here BEFORE it becomes a user complaint is exactly the point - correlate HLTH-SQL-SYS-010 trends."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-033-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-033-RC01 (sqlserver)', 'resolve-hlth_sql_sys_033_rc01-sqlserver', 'Long executions vs baseline captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_033_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_033_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'session_id')::int             AS session_id,
    (j.value ->> 'login_name')                  AS login_name,
    (j.value ->> 'host_name')                   AS host_name,
    (j.value ->> 'program_name')                AS program_name,
    (j.value ->> 'database_name')               AS database_name,
    (j.value ->> 'procedure_name')              AS procedure_name,
    (j.value ->> 'current_elapsed_ms')::bigint  AS current_elapsed_ms,
    (j.value ->> 'baseline_avg_ms')::bigint     AS baseline_avg_ms,
    (j.value ->> 'times_over_baseline')::numeric AS times_over_baseline,
    (j.value ->> 'status')                      AS status,
    (j.value ->> 'wait_type')                   AS wait_type,
    (j.value ->> 'blocking_session_id')::int    AS blocking_session_id,
    (j.value ->> 'start_time')                  AS start_time,
    (j.value ->> 'batch_text')                  AS batch_text,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-033-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_033_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_033_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-033-RC01';

COMMIT;
