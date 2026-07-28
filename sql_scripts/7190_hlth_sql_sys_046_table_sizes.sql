-- ============================================================
-- 7190  HLTH-SQL-SYS-046-RC01  Table sizes captured across all databases (sqlserver)
--   HEALTH system series root cause.
--   Built per request (no base query supplied): per-table size, all DBs.
--     * the canonical sys.allocation_units accounting (the basis of
--       sp_spaceused) so data vs index vs unused split correctly, incl. LOB
--       and row-overflow units - a plain page-count sum gets these wrong
--     * dynamic UNION over every online user database (single EXEC -> first
--       rowset for the collector), COLLATE DATABASE_DEFAULT for cross-db
--       UNION safety, GROUP BY sch/table/p.rows (rows is constant per table)
--     * TOP 500 by reserved space instance-wide + index/unused percents
--   2005+. Requires db access on every database.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-046','HLTH','SQL','SYS','Table Sizes','table-sizes',
        'The largest tables across every database with their row count and reserved/data/index/unused space breakdown.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-046-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-046-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-046-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-046-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-046-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-046-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-046-RC01', 'HLTH-SQL-SYS-046', 'Table sizes captured across all databases',
    'table-sizes-rc01',
    'Top 500 tables instance-wide by reserved space: database, schema, table, row count, and the reserved / data / index / unused MB split (plus index and unused percent). Uses the allocation-unit accounting sp_spaceused is built on, so heaps, LOB and row-overflow allocations are all counted. Feeds capacity planning, index-bloat and unused-space health checks; complements the file/volume views (SYS-021/024) with the object-level breakdown.',
    ARRAY['health', 'space', 'tables', 'capacity', 'storage'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-046-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nDECLARE @sql nvarchar(max) = N'''';\nSELECT @sql = @sql + N'' UNION ALL SELECT N'''''' + REPLACE(name, '''''''', '''''''''''') + N'''''' COLLATE DATABASE_DEFAULT AS database_name,''\n    + N'' sch.name COLLATE DATABASE_DEFAULT AS schema_name,''\n    + N'' t.name COLLATE DATABASE_DEFAULT AS table_name,''\n    + N'' p.rows AS row_count,''\n    + N'' CAST(SUM(a.total_pages)*8/1024.0 AS decimal(18,2)) AS reserved_mb,''\n    + N'' CAST(SUM(CASE WHEN a.type <> 1 THEN a.used_pages WHEN p.index_id < 2 THEN a.data_pages ELSE 0 END)*8/1024.0 AS decimal(18,2)) AS data_mb,''\n    + N'' CAST((SUM(a.used_pages) - SUM(CASE WHEN a.type <> 1 THEN a.used_pages WHEN p.index_id < 2 THEN a.data_pages ELSE 0 END))*8/1024.0 AS decimal(18,2)) AS index_mb,''\n    + N'' CAST((SUM(a.total_pages) - SUM(a.used_pages))*8/1024.0 AS decimal(18,2)) AS unused_mb''\n    + N'' FROM '' + QUOTENAME(name) + N''.sys.tables t''\n    + N'' JOIN '' + QUOTENAME(name) + N''.sys.indexes i ON i.object_id = t.object_id''\n    + N'' JOIN '' + QUOTENAME(name) + N''.sys.partitions p ON p.object_id = i.object_id AND p.index_id = i.index_id''\n    + N'' JOIN '' + QUOTENAME(name) + N''.sys.allocation_units a ON a.container_id = p.partition_id''\n    + N'' JOIN '' + QUOTENAME(name) + N''.sys.schemas sch ON sch.schema_id = t.schema_id''\n    + N'' WHERE t.is_ms_shipped = 0''\n    + N'' GROUP BY sch.name, t.name, p.rows''\nFROM sys.databases\nWHERE database_id > 4 AND state = 0 AND user_access = 0;\nIF @sql = N''''\n    SELECT CAST(NULL AS sysname) AS database_name, CAST(NULL AS sysname) AS schema_name,\n           CAST(NULL AS sysname) AS table_name, CAST(NULL AS bigint) AS row_count,\n           CAST(NULL AS decimal(18,2)) AS reserved_mb, CAST(NULL AS decimal(18,2)) AS data_mb,\n           CAST(NULL AS decimal(18,2)) AS index_mb, CAST(NULL AS decimal(18,2)) AS unused_mb\n    WHERE 1 = 0;\nELSE\nBEGIN\n    SET @sql = N''SELECT TOP 500 database_name, schema_name, table_name, row_count, reserved_mb, data_mb, index_mb, unused_mb,''\n        + N'' CAST(index_mb * 100.0 / NULLIF(reserved_mb, 0) AS decimal(5,2)) AS index_pct,''\n        + N'' CAST(unused_mb * 100.0 / NULLIF(reserved_mb, 0) AS decimal(5,2)) AS unused_pct''\n        + N'' FROM ('' + STUFF(@sql, 1, 11, N'''') + N'') u ORDER BY reserved_mb DESC'';\n    EXEC(@sql);\nEND"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Table sizes captured (zero rows = no user tables in any database)"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-046-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-046-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-046-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-046-RC01 (sqlserver)', 'Table sizes captured across all databases', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-046-RC01 (sqlserver)', '{"action": "index_pct much larger than data_mb suggests over-indexing (weigh against write cost and check missing-index overlap in SYS-034); large unused_pct is allocated-but-empty space from deletes or a dropped-then-rebuilt clustered index (reclaimed by a REBUILD, not routine shrink); the biggest tables are the ones whose growth drives file growth (SYS-021 days_to_full) and whose fragmentation (SYS-027) and stats staleness matter most; a huge row_count with tiny data_mb can indicate a very narrow table or heavy compression."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-046-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-046-RC01 (sqlserver)', 'resolve-hlth_sql_sys_046_rc01-sqlserver', 'Table sizes captured across all databases: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_046_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_046_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'database_name')               AS database_name,
    (j.value ->> 'schema_name')                 AS schema_name,
    (j.value ->> 'table_name')                  AS table_name,
    (j.value ->> 'row_count')::bigint           AS row_count,
    (j.value ->> 'reserved_mb')::numeric        AS reserved_mb,
    (j.value ->> 'data_mb')::numeric            AS data_mb,
    (j.value ->> 'index_mb')::numeric           AS index_mb,
    (j.value ->> 'unused_mb')::numeric          AS unused_mb,
    (j.value ->> 'index_pct')::numeric          AS index_pct,
    (j.value ->> 'unused_pct')::numeric         AS unused_pct,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-046-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_046_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_046_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-046-RC01';

COMMIT;
