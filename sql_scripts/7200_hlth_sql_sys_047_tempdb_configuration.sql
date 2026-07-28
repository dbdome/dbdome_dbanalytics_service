-- ============================================================
-- 7200  HLTH-SQL-SYS-047-RC01  TempDB file configuration captured (sqlserver)
--   HEALTH system series root cause.
--   Rebuilt from the base Tempdb.sys.database_files dump:
--     * dropped the backup/LSN/differential columns (all NULL/irrelevant for
--       tempdb, which is never backed up) - kept the file-layout facts
--     * ADDED the tempdb health checks that make this actionable: data file
--       count vs cpu_count, equal-size check, percent-growth and
--       single-file smells - computed instance-wide and repeated per row
--     * size/growth/max_size converted from 8KB pages to MB; growth decoded
--   2005+. Requires VIEW SERVER STATE (dm_os_sys_info) + catalog access.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-047','HLTH','SQL','SYS','TempDB File Configuration','tempdb-configuration',
        'TempDB data and log file layout with the classic tempdb-health checks: file count vs CPUs, equal-size verification and percent-growth anti-pattern.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-047-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-047-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-047-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-047-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-047-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-047-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-047-RC01', 'HLTH-SQL-SYS-047', 'TempDB file configuration captured',
    'tempdb-configuration-rc01',
    'Every tempdb file (data and log) with size, growth setting, max size and state, PLUS instance-level tempdb health flags computed in the same result: data file count vs CPU count, uneven_data_files (unequal sizes defeat proportional-fill and cause allocation hotspots), uses_percent_growth (staggered growth + PFS/GAM contention) and single_data_file_smell (one data file on a multi-CPU box). The tempdb-configuration companion to the allocation-pressure view in SYS-022.',
    ARRAY['health', 'tempdb', 'configuration', 'contention', 'files'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-047-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nDECLARE @data_files int, @cpu_count int, @distinct_sizes int, @pct_growth_files int;\nSELECT @cpu_count = cpu_count FROM sys.dm_os_sys_info;\nSELECT @data_files = COUNT(*) FROM tempdb.sys.database_files WHERE type_desc = ''ROWS'';\nSELECT @distinct_sizes = COUNT(DISTINCT size) FROM tempdb.sys.database_files WHERE type_desc = ''ROWS'';\nSELECT @pct_growth_files = COUNT(*) FROM tempdb.sys.database_files WHERE type_desc = ''ROWS'' AND is_percent_growth = 1;\nSELECT\n    f.file_id,\n    f.name AS logical_name,\n    f.type_desc AS file_type,\n    f.physical_name,\n    CONVERT(bigint, f.size)*8/1024 AS size_mb,\n    f.is_percent_growth,\n    CASE WHEN f.is_percent_growth = 1 THEN CONVERT(varchar(10), f.growth) + '' %''\n         ELSE CONVERT(varchar(20), CONVERT(bigint, f.growth)*8/1024) + '' MB'' END AS growth_setting,\n    CASE WHEN f.max_size = -1 THEN NULL WHEN f.max_size = 268435456 THEN NULL\n         ELSE CONVERT(bigint, f.max_size)*8/1024 END AS max_size_mb,\n    f.state_desc AS state,\n    @data_files AS tempdb_data_file_count,\n    @cpu_count AS cpu_count,\n    CASE WHEN f.type_desc = ''ROWS'' AND @distinct_sizes > 1 THEN 1 ELSE 0 END AS uneven_data_files,\n    CASE WHEN f.type_desc = ''ROWS'' AND f.is_percent_growth = 1 THEN 1 ELSE 0 END AS uses_percent_growth,\n    CASE WHEN f.type_desc = ''ROWS'' AND @data_files = 1 AND @cpu_count > 1 THEN 1 ELSE 0 END AS single_data_file_smell\nFROM tempdb.sys.database_files f\nORDER BY f.type_desc, f.file_id"}'::jsonb,
        '{"condition": "row_count > 0", "description": "TempDB files captured"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-047-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-047-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-047-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-047-RC01 (sqlserver)', 'TempDB file configuration captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-047-RC01 (sqlserver)', '{"action": "uneven_data_files = 1 breaks proportional fill - make all tempdb data files the SAME size and growth so allocations round-robin evenly (the #1 tempdb allocation-contention fix, PAGELATCH_* on 2:1:1); uses_percent_growth = 1 causes ever-larger, staggered autogrows - switch to a fixed MB increment and presize the files equally; single_data_file_smell = 1 on a multi-core box: add data files (start ~1 per core up to 8, then by 4) - correlate PAGELATCH waits in SYS-044; a data file at its max_size stalls all tempdb-heavy work (sorts/spills - SYS-022 internal objects)."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-047-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-047-RC01 (sqlserver)', 'resolve-hlth_sql_sys_047_rc01-sqlserver', 'TempDB file configuration captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_047_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_047_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'file_id')::int                AS file_id,
    (j.value ->> 'logical_name')                AS logical_name,
    (j.value ->> 'file_type')                   AS file_type,
    (j.value ->> 'physical_name')               AS physical_name,
    (j.value ->> 'size_mb')::bigint             AS size_mb,
    (j.value ->> 'is_percent_growth')::int      AS is_percent_growth,
    (j.value ->> 'growth_setting')              AS growth_setting,
    (j.value ->> 'max_size_mb')::bigint         AS max_size_mb,
    (j.value ->> 'state')                       AS state,
    (j.value ->> 'tempdb_data_file_count')::int AS tempdb_data_file_count,
    (j.value ->> 'cpu_count')::int              AS cpu_count,
    (j.value ->> 'uneven_data_files')::int      AS uneven_data_files,
    (j.value ->> 'uses_percent_growth')::int    AS uses_percent_growth,
    (j.value ->> 'single_data_file_smell')::int AS single_data_file_smell,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-047-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_047_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_047_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-047-RC01';

COMMIT;
