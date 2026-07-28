-- ============================================================
-- 6780  HLTH-SQL-SYS-005-RC01  Top CPU-consuming cached queries (sqlserver)
--   Fifth HEALTH system root cause (series: 6740/6750/6760/6770).
--   Top 20 statements from sys.dm_exec_query_stats by total CPU.
--
--   Enriched from the base dm_exec_query_stats query:
--     * worker/elapsed times converted from microseconds to ms consistently
--       (the base mixed raw microseconds and /1000000 seconds)
--     * added per-execution averages (avg_cpu_ms / avg_elapsed_ms /
--       avg_logical_reads) -- total-ordered lists hide cheap-but-chatty vs
--       expensive-per-run offenders without them
--     * added executions_per_min since the plan was cached, plan_cached_time
--       (creation_time -- totals are only comparable for plans cached over a
--       similar window), database_name (NULL for ad-hoc statements) and
--       query_hash (groups ad-hoc variants of the same query shape, 2008+)
--     * statement text extraction kept (offsets honoured), capped at 4000
--   Requires VIEW SERVER STATE. Stats reset on instance restart/plan eviction.
--
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

-- 0) AREA + ISSUE -----------------------------------------------------------
INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-005','HLTH','SQL','SYS','Top Resource-Consuming Queries','top-resource-consuming-queries',
        'Track the cached statements consuming the most CPU (and their IO profile) so regressions and runaway ad-hoc workloads surface early.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

-- cleanup of any prior HLTH-SQL-SYS-005-RC01 artifacts (idempotent rebuild)
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-005-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-005-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-005-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-005-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-005-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-005-RC01 %';

-- 1) ROOT CAUSE -------------------------------------------------------------
INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-005-RC01', 'HLTH-SQL-SYS-005', 'Top CPU-consuming cached queries captured',
    'top-cpu-consuming-queries',
    'Top 20 cached statements ordered by total CPU: statement text, database, query hash, execution count and rate, total/average/last CPU and elapsed times (ms), logical/physical IO totals and averages, plan cache time and last execution. Feeds CPU-regression and runaway-ad-hoc-workload health checks.',
    ARRAY['health', 'cpu', 'queries', 'performance', 'plan-cache'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

-- 2) DETECTION STEP (sqlserver) --------------------------------------------
INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-005-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nSELECT TOP 20\n    LEFT(SUBSTRING(qt.text, (qs.statement_start_offset/2)+1,\n        ((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(qt.text) ELSE qs.statement_end_offset END - qs.statement_start_offset)/2)+1), 4000) AS sql_text,\n    DB_NAME(qt.dbid) AS database_name,\n    CONVERT(varchar(20), qs.query_hash, 1) AS query_hash,\n    qs.execution_count,\n    CONVERT(decimal(18,2), qs.execution_count * 60.0 / NULLIF(DATEDIFF(SECOND, qs.creation_time, GETDATE()), 0)) AS executions_per_min,\n    qs.total_worker_time/1000 AS total_cpu_ms,\n    qs.total_worker_time/1000/NULLIF(qs.execution_count, 0) AS avg_cpu_ms,\n    qs.last_worker_time/1000 AS last_cpu_ms,\n    qs.total_elapsed_time/1000 AS total_elapsed_ms,\n    qs.total_elapsed_time/1000/NULLIF(qs.execution_count, 0) AS avg_elapsed_ms,\n    qs.last_elapsed_time/1000 AS last_elapsed_ms,\n    qs.total_logical_reads,\n    qs.total_logical_reads/NULLIF(qs.execution_count, 0) AS avg_logical_reads,\n    qs.last_logical_reads,\n    qs.total_logical_writes,\n    qs.last_logical_writes,\n    qs.total_physical_reads,\n    CONVERT(varchar(19), qs.creation_time, 120) AS plan_cached_time,\n    CONVERT(varchar(19), qs.last_execution_time, 120) AS last_execution_time\nFROM sys.dm_exec_query_stats qs\nCROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt\nORDER BY qs.total_worker_time DESC"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Top CPU-consuming cached statements captured"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-005-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-005-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-005-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-005-RC01 (sqlserver)', 'Top CPU-consuming cached queries captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-005-RC01 (sqlserver)', '{"action": "Compare avg_cpu_ms against history for regressions (plan change, missing index, stale stats); high executions_per_min with low avg cost means the app is chattering - fix caching/batching at the source; same query_hash appearing as many ad-hoc variants suggests unparameterized SQL (consider forced parameterization or app-side parameters); check plan_cached_time before comparing totals - a freshly cached plan has small totals regardless of cost."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-005-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-005-RC01 (sqlserver)', 'resolve-hlth_sql_sys_005_rc01-sqlserver', 'Triage the top CPU consumers: regressions, chatty executions and unparameterized ad-hoc variants.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

-- 4) MONITORING VIEW --------------------------------------------------------
CREATE OR REPLACE VIEW monitoring.v_hlth_sql_sys_005_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'sql_text')                     AS sql_text,
    (j.value ->> 'database_name')                AS database_name,
    (j.value ->> 'query_hash')                   AS query_hash,
    (j.value ->> 'execution_count')::bigint      AS execution_count,
    (j.value ->> 'executions_per_min')::numeric  AS executions_per_min,
    (j.value ->> 'total_cpu_ms')::bigint         AS total_cpu_ms,
    (j.value ->> 'avg_cpu_ms')::bigint           AS avg_cpu_ms,
    (j.value ->> 'last_cpu_ms')::bigint          AS last_cpu_ms,
    (j.value ->> 'total_elapsed_ms')::bigint     AS total_elapsed_ms,
    (j.value ->> 'avg_elapsed_ms')::bigint       AS avg_elapsed_ms,
    (j.value ->> 'last_elapsed_ms')::bigint      AS last_elapsed_ms,
    (j.value ->> 'total_logical_reads')::bigint  AS total_logical_reads,
    (j.value ->> 'avg_logical_reads')::bigint    AS avg_logical_reads,
    (j.value ->> 'last_logical_reads')::bigint   AS last_logical_reads,
    (j.value ->> 'total_logical_writes')::bigint AS total_logical_writes,
    (j.value ->> 'last_logical_writes')::bigint  AS last_logical_writes,
    (j.value ->> 'total_physical_reads')::bigint AS total_physical_reads,
    (j.value ->> 'plan_cached_time')             AS plan_cached_time,
    (j.value ->> 'last_execution_time')          AS last_execution_time,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-005-RC01';

-- keep view/grants aligned with the 6690 hardening when the engine role exists
DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_005_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_005_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

-- 5) VERIFY ----------------------------------------------------------------
SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-005-RC01';

COMMIT;
