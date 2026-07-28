-- ============================================================
-- 6830  HLTH-SQL-SYS-010-RC01  Average procedure duration captured (sqlserver)
--   HEALTH system series root cause.
--   Rebuilt from the base dm_exec_procedure_stats query:
--     * ROW_NUMBER-over-full-text dedupe replaced with
--       OBJECT_NAME(object_id, database_id) -- the proper proc identity
--     * microseconds converted to ms; added min/max duration, avg CPU,
--       avg writes, execution_count, cached_time and type_desc
--     * TOP 50 by average duration
--   Requires VIEW SERVER STATE. dm_exec_procedure_stats needs 2008+.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-010','HLTH','SQL','SYS','Procedure Performance Profile','average-procedure-duration',
        'Track average duration, CPU and IO per cached stored procedure to catch procedure-level regressions.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-010-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-010-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-010-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-010-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-010-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-010-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-010-RC01', 'HLTH-SQL-SYS-010', 'Average procedure duration captured',
    'average-procedure-duration-rc01',
    'Top 50 cached procedures by average elapsed time: database, procedure name (via OBJECT_NAME, not text-dedup), type, execution count, avg/min/max duration ms, avg CPU ms, avg logical reads/writes, cache and last-execution times. Feeds procedure-regression health checks.',
    ARRAY['health', 'procedures', 'performance', 'duration'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-010-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nSELECT TOP 50\n    DB_NAME(qp.database_id) AS database_name,\n    OBJECT_NAME(qp.object_id, qp.database_id) AS procedure_name,\n    qp.type_desc,\n    qp.execution_count,\n    qp.total_elapsed_time/1000/NULLIF(qp.execution_count, 0) AS avg_duration_ms,\n    qp.min_elapsed_time/1000 AS min_duration_ms,\n    qp.max_elapsed_time/1000 AS max_duration_ms,\n    qp.total_worker_time/1000/NULLIF(qp.execution_count, 0) AS avg_cpu_ms,\n    qp.total_logical_reads/NULLIF(qp.execution_count, 0) AS avg_reads,\n    qp.total_logical_writes/NULLIF(qp.execution_count, 0) AS avg_writes,\n    CONVERT(varchar(19), qp.cached_time, 120) AS cached_time,\n    CONVERT(varchar(19), qp.last_execution_time, 120) AS last_execution_time\nFROM sys.dm_exec_procedure_stats qp\nORDER BY qp.total_elapsed_time/NULLIF(qp.execution_count, 0) DESC"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Cached procedure statistics captured"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-010-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-010-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-010-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-010-RC01 (sqlserver)', 'Average procedure duration captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-010-RC01 (sqlserver)', '{"action": "Compare avg_duration_ms against history: a regression with unchanged avg_reads is usually plan/parameter-sniffing (test with RECOMPILE / OPTIMIZE FOR); rising avg_reads points at data growth or a lost index; max far above avg means outlier parameter sets; stats reset when the plan leaves cache (cached_time tells the window)."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-010-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-010-RC01 (sqlserver)', 'resolve-hlth_sql_sys_010_rc01-sqlserver', 'Average procedure duration captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_sys_010_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'database_name')               AS database_name,
    (j.value ->> 'procedure_name')              AS procedure_name,
    (j.value ->> 'type_desc')                   AS type_desc,
    (j.value ->> 'execution_count')::bigint     AS execution_count,
    (j.value ->> 'avg_duration_ms')::bigint     AS avg_duration_ms,
    (j.value ->> 'min_duration_ms')::bigint     AS min_duration_ms,
    (j.value ->> 'max_duration_ms')::bigint     AS max_duration_ms,
    (j.value ->> 'avg_cpu_ms')::bigint          AS avg_cpu_ms,
    (j.value ->> 'avg_reads')::bigint           AS avg_reads,
    (j.value ->> 'avg_writes')::bigint          AS avg_writes,
    (j.value ->> 'cached_time')                 AS cached_time,
    (j.value ->> 'last_execution_time')         AS last_execution_time,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-010-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_010_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_010_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-010-RC01';

COMMIT;
