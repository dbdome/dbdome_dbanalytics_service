-- ============================================================
-- 6910  HLTH-SQL-SYS-018-RC01  Per-database CPU distribution captured (sqlserver)
--   HEALTH system series root cause.
--   Rebuilt from the base per-DB CPU query:
--     * THE BUG: total_worker_time is MICROSECONDS - the base labeled the
--       raw sum as CPU_Time_Ms; now divided by 1000 so the ms label is true
--     * added executions and cached_statements per DB (expensive-vs-chatty)
--     * dbid 32767 labeled ResourceDB instead of NULL; NULLIF on the
--       percent division; OPTION (RECOMPILE) dropped
--   2005+. Requires VIEW SERVER STATE.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-018','HLTH','SQL','SYS','CPU Distribution by Database','cpu-by-database',
        'Which databases consume the CPU, derived from cached-plan statistics: rank, share and execution volume per database.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-018-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-018-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-018-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-018-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-018-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-018-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-018-RC01', 'HLTH-SQL-SYS-018', 'Per-database CPU distribution captured',
    'cpu-by-database-rc01',
    'CPU time aggregated per database from sys.dm_exec_query_stats via each plan dbid attribute: rank, CPU ms (correctly converted from microseconds), percent of total, execution count and number of cached statements. Reflects CACHED plans only - plan-cache turnover and stats reset on restart skew absolutes; trend the shares.',
    ARRAY['health', 'cpu', 'databases', 'workload', 'distribution'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-018-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nWITH db_cpu AS (\n    SELECT f.database_id,\n           SUM(qs.total_worker_time)/1000 AS cpu_time_ms,\n           SUM(qs.execution_count) AS executions,\n           COUNT(*) AS cached_statements\n    FROM sys.dm_exec_query_stats qs\n    CROSS APPLY (SELECT CONVERT(int, value) AS database_id\n                 FROM sys.dm_exec_plan_attributes(qs.plan_handle)\n                 WHERE attribute = N''dbid'') f\n    GROUP BY f.database_id\n)\nSELECT ROW_NUMBER() OVER (ORDER BY cpu_time_ms DESC) AS cpu_rank,\n       CASE WHEN database_id = 32767 THEN ''ResourceDB'' ELSE DB_NAME(database_id) END AS database_name,\n       cpu_time_ms,\n       CAST(cpu_time_ms * 1.0 / NULLIF(SUM(cpu_time_ms) OVER (), 0) * 100.0 AS decimal(5,2)) AS cpu_percent,\n       executions,\n       cached_statements\nFROM db_cpu\nORDER BY cpu_rank"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Per-database CPU distribution captured"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-018-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-018-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-018-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-018-RC01 (sqlserver)', 'Per-database CPU distribution captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-018-RC01 (sqlserver)', '{"action": "A database whose cpu_percent jumps between snapshots changed workload - drill into HLTH-SQL-SYS-005 filtered to that database; high CPU with few executions = expensive statements (tune them), high executions with modest CPU = chatty app (batch or cache at the source); remember this only covers plans still in cache - heavy OPTION(RECOMPILE)/ad-hoc-flush workloads undercount."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-018-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-018-RC01 (sqlserver)', 'resolve-hlth_sql_sys_018_rc01-sqlserver', 'Per-database CPU distribution captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_sys_018_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'cpu_rank')::int               AS cpu_rank,
    (j.value ->> 'database_name')               AS database_name,
    (j.value ->> 'cpu_time_ms')::bigint         AS cpu_time_ms,
    (j.value ->> 'cpu_percent')::numeric        AS cpu_percent,
    (j.value ->> 'executions')::bigint          AS executions,
    (j.value ->> 'cached_statements')::bigint   AS cached_statements,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-018-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_018_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_018_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-018-RC01';

COMMIT;
