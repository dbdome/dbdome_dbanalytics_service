-- ============================================================
-- 6800  HLTH-SQL-SYS-007-RC01  Buffer pool usage by database (sqlserver)
--   Seventh HEALTH system root cause (series: 6740-6790).
--   Aggregate buffer pool (data cache) consumption per database.
--
--   Enriched from the base dm_os_buffer_descriptors query:
--     * added dirty_mb (is_modified pages -- checkpoint/flush pressure) and
--       cached_pages alongside the cached MB
--     * NULLIF guard on the percent-of-total division (empty cache edge case)
--     * dropped WITH (NOLOCK) / OPTION (RECOMPILE) -- meaningless on a DMV
--       aggregation
--     * kept ResourceDB (32767) exclusion, rank and percent-of-total
--   Note: scanning dm_os_buffer_descriptors touches one row per cached 8KB
--   page; on very large-memory servers this query costs a few seconds -- fine
--   at collector cadence but not for a tight loop.
--   Every object/column is SQL Server 2005+ -- fits all versions.
--   Requires VIEW SERVER STATE.
--
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

-- 0) AREA + ISSUE -----------------------------------------------------------
INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-007','HLTH','SQL','SYS','Buffer Pool Distribution','buffer-pool-distribution',
        'Track which databases occupy the buffer pool (data cache), including dirty-page volume, to spot cache-hog databases, sudden working-set shifts and checkpoint pressure.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

-- cleanup of any prior HLTH-SQL-SYS-007-RC01 artifacts (idempotent rebuild)
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-007-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-007-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-007-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-007-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-007-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-007-RC01 %';

-- 1) ROOT CAUSE -------------------------------------------------------------
INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-007-RC01', 'HLTH-SQL-SYS-007', 'Buffer pool usage per database captured',
    'buffer-pool-usage-per-database',
    'Per-database buffer pool footprint: rank, cached MB and pages, dirty (modified, not yet flushed) MB, and percent of the total data cache. Feeds cache-hog, working-set-shift and checkpoint-pressure health checks.',
    ARRAY['health', 'memory', 'buffer-pool', 'cache', 'capacity'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

-- 2) DETECTION STEP (sqlserver) --------------------------------------------
INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-007-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nWITH bp AS (\n    SELECT database_id,\n           COUNT(*) AS cached_pages,\n           CAST(COUNT(*) * 8/1024.0 AS decimal(12,2)) AS cached_mb,\n           CAST(SUM(CASE WHEN is_modified = 1 THEN 1 ELSE 0 END) * 8/1024.0 AS decimal(12,2)) AS dirty_mb\n    FROM sys.dm_os_buffer_descriptors\n    WHERE database_id <> 32767\n    GROUP BY database_id\n)\nSELECT ROW_NUMBER() OVER (ORDER BY cached_mb DESC) AS buffer_pool_rank,\n       DB_NAME(database_id) AS database_name,\n       cached_mb,\n       dirty_mb,\n       cached_pages,\n       CAST(cached_mb / NULLIF(SUM(cached_mb) OVER(), 0) * 100.0 AS decimal(5,2)) AS buffer_pool_percent\nFROM bp\nORDER BY buffer_pool_rank"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Buffer pool distribution per database captured"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-007-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-007-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-007-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-007-RC01 (sqlserver)', 'Buffer pool usage per database captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-007-RC01 (sqlserver)', '{"action": "Compare the distribution over time: one database suddenly claiming a much larger share signals a working-set change (new scan-heavy query, missing index, stats problem) - correlate with HLTH-SQL-SYS-005 top CPU queries; persistent high dirty_mb points at checkpoint/IO pressure (check recovery interval / indirect checkpoint and log throughput); tempdb ranking near the top usually means spills - correlate wait types (HLTH-SQL-SYS-002)."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-007-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-007-RC01 (sqlserver)', 'resolve-hlth_sql_sys_007_rc01-sqlserver', 'Watch buffer-pool share shifts, dirty-page pressure and tempdb cache growth.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

-- 4) MONITORING VIEW --------------------------------------------------------
CREATE OR REPLACE VIEW monitoring.v_hlth_sql_sys_007_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'buffer_pool_rank')::int       AS buffer_pool_rank,
    (j.value ->> 'database_name')               AS database_name,
    (j.value ->> 'cached_mb')::numeric          AS cached_mb,
    (j.value ->> 'dirty_mb')::numeric           AS dirty_mb,
    (j.value ->> 'cached_pages')::bigint        AS cached_pages,
    (j.value ->> 'buffer_pool_percent')::numeric AS buffer_pool_percent,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-007-RC01';

-- keep view/grants aligned with the 6690 hardening when the engine role exists
DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_007_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_007_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

-- 5) VERIFY ----------------------------------------------------------------
SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-007-RC01';

COMMIT;
