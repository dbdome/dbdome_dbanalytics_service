-- ============================================================
-- 7130  HLTH-SQL-SYS-040-RC01  SQL memory breakdown captured (sqlserver)
--   HEALTH system series root cause.
--   Modernized from the base Perfmon breakdown query:
--     * Total/Free/Stolen/Reserved PAGES counters were REMOVED in SQL 2012 -
--       the base returns nothing for them on any modern server; replaced
--       with the KB successors (Database Cache / Free / Stolen Server
--       Memory) which exist 2012+
--     * spt_values page-size lookup dropped (pages are always 8KB);
--       trailing-space counter names handled with RTRIM
--     * added Memory Grants Pending/Outstanding - pending grants are the
--       most direct memory-starvation signal the base was missing
--     * instance-name prefix handled via LIKE (named instances)
--   2012+ for the KB successors; missing counters drop out via NULL filter.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-040','HLTH','SQL','SYS','SQL Memory Breakdown','sql-memory-breakdown',
        'Memory Manager counter breakdown: where SQL Server memory actually goes - cache, stolen, locks, optimizer, workspace grants - plus grant queue state.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-040-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-040-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-040-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-040-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-040-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-040-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-040-RC01', 'HLTH-SQL-SYS-040', 'SQL memory breakdown captured',
    'sql-memory-breakdown-rc01',
    'Memory Manager counters as (counter, value, unit) rows: total vs target server memory, database cache vs free vs stolen memory, connection/lock/SQL-cache/optimizer/granted-workspace/reserved memory, plan cache and cursor memory, and the memory grant queue (pending + outstanding counts). Complements HLTH-SQL-SYS-014 (buffer behavior) and SYS-036 (OS view) with the WHERE-does-it-go breakdown.',
    ARRAY['health', 'memory', 'counters', 'grants', 'breakdown'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-040-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nWITH pc AS (\n    SELECT RTRIM(counter_name) AS cn, cntr_value AS v\n    FROM sys.dm_os_performance_counters\n    WHERE object_name LIKE ''%Memory Manager%''\n)\nSELECT counter, CAST(value AS decimal(18,2)) AS value, unit FROM (\n    SELECT ''total_server_memory_mb'' AS counter, (SELECT v/1024.0 FROM pc WHERE cn = ''Total Server Memory (KB)'') AS value, ''MB'' AS unit\n    UNION ALL SELECT ''target_server_memory_mb'',     (SELECT v/1024.0 FROM pc WHERE cn = ''Target Server Memory (KB)''), ''MB''\n    UNION ALL SELECT ''database_cache_memory_mb'',    (SELECT v/1024.0 FROM pc WHERE cn = ''Database Cache Memory (KB)''), ''MB''\n    UNION ALL SELECT ''free_memory_mb'',              (SELECT v/1024.0 FROM pc WHERE cn = ''Free Memory (KB)''), ''MB''\n    UNION ALL SELECT ''stolen_server_memory_mb'',     (SELECT v/1024.0 FROM pc WHERE cn = ''Stolen Server Memory (KB)''), ''MB''\n    UNION ALL SELECT ''connection_memory_mb'',        (SELECT v/1024.0 FROM pc WHERE cn = ''Connection Memory (KB)''), ''MB''\n    UNION ALL SELECT ''lock_memory_mb'',              (SELECT v/1024.0 FROM pc WHERE cn = ''Lock Memory (KB)''), ''MB''\n    UNION ALL SELECT ''sql_cache_memory_mb'',         (SELECT v/1024.0 FROM pc WHERE cn = ''SQL Cache Memory (KB)''), ''MB''\n    UNION ALL SELECT ''optimizer_memory_mb'',         (SELECT v/1024.0 FROM pc WHERE cn = ''Optimizer Memory (KB)''), ''MB''\n    UNION ALL SELECT ''granted_workspace_memory_mb'', (SELECT v/1024.0 FROM pc WHERE cn = ''Granted Workspace Memory (KB)''), ''MB''\n    UNION ALL SELECT ''reserved_server_memory_mb'',   (SELECT v/1024.0 FROM pc WHERE cn = ''Reserved Server Memory (KB)''), ''MB''\n    UNION ALL SELECT ''memory_grants_pending'',       (SELECT v FROM pc WHERE cn = ''Memory Grants Pending''), ''count''\n    UNION ALL SELECT ''memory_grants_outstanding'',   (SELECT v FROM pc WHERE cn = ''Memory Grants Outstanding''), ''count''\n    UNION ALL SELECT ''plan_cache_pages_mb'',\n        (SELECT TOP 1 cntr_value*8/1024.0 FROM sys.dm_os_performance_counters\n         WHERE object_name LIKE ''%Plan Cache%'' AND RTRIM(counter_name) = ''Cache Pages'' AND RTRIM(instance_name) = ''_Total''), ''MB''\n    UNION ALL SELECT ''cursor_memory_mb'',\n        (SELECT TOP 1 cntr_value/1024.0 FROM sys.dm_os_performance_counters\n         WHERE object_name LIKE ''%Cursor Manager by Type%'' AND RTRIM(counter_name) = ''Cursor memory usage'' AND RTRIM(instance_name) = ''_Total''), ''MB''\n) x\nWHERE value IS NOT NULL"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Memory Manager counters captured"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-040-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-040-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-040-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-040-RC01 (sqlserver)', 'SQL memory breakdown captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-040-RC01 (sqlserver)', '{"action": "memory_grants_pending above 0 on consecutive snapshots is the loudest memory alarm - queries are WAITING for workspace memory (RESOURCE_SEMAPHORE waits in SYS-002; find the big-grant queries and fix their sorts/hashes); total far below target means SQL wants more than it can get (external pressure - SYS-036); stolen memory large and growing relative to database cache squeezes the buffer pool (plan cache bloat from unparameterized SQL - correlate SYS-005 query_hash duplicates); lock_memory_mb ballooning accompanies runaway transactions (SYS-003)."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-040-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-040-RC01 (sqlserver)', 'resolve-hlth_sql_sys_040_rc01-sqlserver', 'SQL memory breakdown captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_040_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_040_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'counter')                     AS counter,
    (j.value ->> 'value')::numeric              AS value,
    (j.value ->> 'unit')                        AS unit,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-040-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_040_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_040_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-040-RC01';

COMMIT;
