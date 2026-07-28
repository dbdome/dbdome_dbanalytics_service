-- ============================================================
-- 6950  HLTH-SQL-SYS-022-RC01  Per-database file space usage captured (sqlserver)
--   HEALTH system series root cause.
--   Rebuilt from the base OPENQUERY-per-database query:
--     * OPENQUERY wrapper and cursor replaced with one dynamic UNION ALL
--       over every ONLINE multi-user database via <db>.sys prefix (verified
--       to switch context on 2012+); single EXEC so the collector''s bare
--       fetchall() sees the rowset as the FIRST result
--     * pages converted to MB (page counts are 8KB pages), allocated_pct
--       added, plus version_store / user_object / internal_object breakdown
--       (the tempdb-pressure diagnostics)
--   Full per-db coverage needs 2012+ (pre-2012 the DMV is tempdb-only).
--   Requires db access on every database (collector is sysadmin).
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-022','HLTH','SQL','SYS','Data File Space Usage','data-file-space-usage',
        'Allocated vs unallocated space inside the data files of every database, including the tempdb version-store and object breakdown.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-022-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-022-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-022-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-022-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-022-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-022-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-022-RC01', 'HLTH-SQL-SYS-022', 'Per-database file space usage captured',
    'data-file-space-usage-rc01',
    'For every ONLINE multi-user database: total data-file MB, allocated vs unallocated extents, allocated percent, and the reserved breakdown that diagnoses tempdb pressure (version store, user objects, internal objects). Answers how full is each database INSIDE its files - the complement of the volume-level view in HLTH-SQL-SYS-021.',
    ARRAY['health', 'space', 'files', 'tempdb', 'capacity'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-022-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nDECLARE @sql nvarchar(max) = N'''';\nSELECT @sql = @sql + N'' UNION ALL SELECT N'''''' + REPLACE(name, '''''''', '''''''''''') + N'''''' COLLATE DATABASE_DEFAULT AS database_name,''\n    + N'' CAST(SUM(total_page_count)*8/1024.0 AS decimal(18,1)) AS total_mb,''\n    + N'' CAST(SUM(allocated_extent_page_count)*8/1024.0 AS decimal(18,1)) AS allocated_mb,''\n    + N'' CAST(SUM(unallocated_extent_page_count)*8/1024.0 AS decimal(18,1)) AS unallocated_mb,''\n    + N'' CAST(SUM(version_store_reserved_page_count)*8/1024.0 AS decimal(18,1)) AS version_store_mb,''\n    + N'' CAST(SUM(user_object_reserved_page_count)*8/1024.0 AS decimal(18,1)) AS user_object_mb,''\n    + N'' CAST(SUM(internal_object_reserved_page_count)*8/1024.0 AS decimal(18,1)) AS internal_object_mb''\n    + N'' FROM '' + QUOTENAME(name) + N''.sys.dm_db_file_space_usage''\nFROM sys.databases\nWHERE state = 0 AND user_access = 0;\nSET @sql = N''SELECT database_name, total_mb, allocated_mb, unallocated_mb,''\n    + N'' CAST(allocated_mb*100.0/NULLIF(total_mb,0) AS decimal(5,2)) AS allocated_pct,''\n    + N'' version_store_mb, user_object_mb, internal_object_mb''\n    + N'' FROM ('' + STUFF(@sql, 1, 11, N'''') + N'') u ORDER BY total_mb DESC'';\nEXEC(@sql);"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Data-file space usage captured per database"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-022-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-022-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-022-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-022-RC01 (sqlserver)', 'Per-database file space usage captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-022-RC01 (sqlserver)', '{"action": "allocated_pct near 100 with autogrowth at its cap (HLTH-SQL-SYS-021 max_size_mb) is the databases-side out-of-space risk; large unallocated_mb is reclaimable headroom already paid for on disk - do NOT shrink routinely, just account for it in capacity math; on tempdb, a swollen version_store_mb points at a long-running snapshot/RCSI transaction (find it via HLTH-SQL-SYS-003) and internal_object_mb at spills (sorts/hashes - correlate memory grants)."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-022-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-022-RC01 (sqlserver)', 'resolve-hlth_sql_sys_022_rc01-sqlserver', 'Per-database file space usage captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_sys_022_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'database_name')               AS database_name,
    (j.value ->> 'total_mb')::numeric           AS total_mb,
    (j.value ->> 'allocated_mb')::numeric       AS allocated_mb,
    (j.value ->> 'unallocated_mb')::numeric     AS unallocated_mb,
    (j.value ->> 'allocated_pct')::numeric      AS allocated_pct,
    (j.value ->> 'version_store_mb')::numeric   AS version_store_mb,
    (j.value ->> 'user_object_mb')::numeric     AS user_object_mb,
    (j.value ->> 'internal_object_mb')::numeric AS internal_object_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-022-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_022_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_022_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-022-RC01';

COMMIT;
