-- ============================================================
-- 7000  HLTH-SQL-SYS-027-RC01  Index fragmentation captured per index (sqlserver)
--   HEALTH system series root cause.
--   Built per request (no base query supplied): per-index fragmentation
--     * dm_db_index_physical_stats in LIMITED mode per online user database
--       (single dynamic UNION, one EXEC -> first rowset for the collector)
--     * index_id > 0 (heaps need SAMPLED forwarded-record analysis - out of
--       scope), page_count >= 100 (small-index percentages are meaningless),
--       IN_ROW_DATA units only
--     * recommended_action derived from the 5%%/30%% reorganize/rebuild rule
--   NOTE: LIMITED scans read index b-tree levels above leaf - cheap but not
--   free; collector cadence for this metric should be hours, not seconds.
--   2005+. Requires VIEW SERVER STATE + db access.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-027','HLTH','SQL','SYS','Index Fragmentation','index-fragmentation-inventory',
        'Per-index logical fragmentation across all user databases with a reorganize/rebuild recommendation.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-027-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-027-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-027-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-027-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-027-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-027-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-027-RC01', 'HLTH-SQL-SYS-027', 'Index fragmentation captured per index',
    'index-fragmentation-inventory-rc01',
    'Every index of at least 100 pages in every ONLINE user database (LIMITED scan - heaps and tiny indexes excluded, their fragmentation numbers are noise): database, schema, table, index name/type, size, fragmentation percent, fragment count and the standard recommendation (REORGANIZE at 5-30%%, REBUILD above 30%%). Worst first. Feeds the HLTH-SQL-DM-004 issue family.',
    ARRAY['health', 'indexes', 'fragmentation', 'maintenance'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-027-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nDECLARE @sql nvarchar(max) = N'''';\nSELECT @sql = @sql + N'' UNION ALL SELECT N'''''' + REPLACE(name, '''''''', '''''''''''') + N'''''' COLLATE DATABASE_DEFAULT AS database_name,''\n    + N'' sch.name COLLATE DATABASE_DEFAULT AS schema_name,''\n    + N'' o.name COLLATE DATABASE_DEFAULT AS table_name,''\n    + N'' i.name COLLATE DATABASE_DEFAULT AS index_name,''\n    + N'' ps.index_id, ps.index_type_desc COLLATE DATABASE_DEFAULT AS index_type,''\n    + N'' ps.page_count, CAST(ps.page_count*8/1024.0 AS decimal(18,1)) AS index_mb,''\n    + N'' CAST(ps.avg_fragmentation_in_percent AS decimal(5,2)) AS fragmentation_pct,''\n    + N'' ps.fragment_count''\n    + N'' FROM sys.dm_db_index_physical_stats(DB_ID(N'''''' + REPLACE(name, '''''''', '''''''''''') + N''''''), NULL, NULL, NULL, N''''LIMITED'''') ps''\n    + N'' JOIN '' + QUOTENAME(name) + N''.sys.indexes i ON i.object_id = ps.object_id AND i.index_id = ps.index_id''\n    + N'' JOIN '' + QUOTENAME(name) + N''.sys.objects o ON o.object_id = ps.object_id''\n    + N'' JOIN '' + QUOTENAME(name) + N''.sys.schemas sch ON sch.schema_id = o.schema_id''\n    + N'' WHERE ps.index_id > 0 AND ps.page_count >= 100 AND ps.alloc_unit_type_desc = N''''IN_ROW_DATA''''''\nFROM sys.databases\nWHERE database_id > 4 AND state = 0 AND user_access = 0;\nIF @sql = N''''\n    SELECT CAST(NULL AS sysname) AS database_name, CAST(NULL AS sysname) AS schema_name,\n           CAST(NULL AS sysname) AS table_name, CAST(NULL AS sysname) AS index_name,\n           CAST(NULL AS int) AS index_id, CAST(NULL AS nvarchar(60)) AS index_type,\n           CAST(NULL AS bigint) AS page_count, CAST(NULL AS decimal(18,1)) AS index_mb,\n           CAST(NULL AS decimal(5,2)) AS fragmentation_pct, CAST(NULL AS bigint) AS fragment_count,\n           CAST(NULL AS varchar(10)) AS recommended_action\n    WHERE 1 = 0;\nELSE\nBEGIN\n    SET @sql = N''SELECT TOP 500 *,''\n        + N'' CASE WHEN fragmentation_pct > 30 THEN ''''REBUILD''''''\n        + N''      WHEN fragmentation_pct > 5 THEN ''''REORGANIZE''''''\n        + N''      ELSE ''''OK'''' END AS recommended_action''\n        + N'' FROM ('' + STUFF(@sql, 1, 11, N'''') + N'') u''\n        + N'' ORDER BY fragmentation_pct DESC, index_mb DESC'';\n    EXEC(@sql);\nEND"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Index fragmentation statistics captured (zero rows = no index of 100+ pages)"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-027-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-027-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-027-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-027-RC01 (sqlserver)', 'Index fragmentation captured per index', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-027-RC01 (sqlserver)', '{"action": "REBUILD (online if the edition allows) above 30 percent, REORGANIZE between 5 and 30 - but only where it matters: fragmentation mostly hurts large range scans from DISK, so an index that is always memory-resident (HLTH-SQL-SYS-007) gains little; low fill-factor churn tables refragment fast - schedule maintenance rather than chasing spikes; page_count under a few thousand rarely justifies action even when the percent looks scary."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-027-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-027-RC01 (sqlserver)', 'resolve-hlth_sql_sys_027_rc01-sqlserver', 'Index fragmentation captured per index: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_027_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_027_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'database_name')               AS database_name,
    (j.value ->> 'schema_name')                 AS schema_name,
    (j.value ->> 'table_name')                  AS table_name,
    (j.value ->> 'index_name')                  AS index_name,
    (j.value ->> 'index_id')::int               AS index_id,
    (j.value ->> 'index_type')                  AS index_type,
    (j.value ->> 'page_count')::bigint          AS page_count,
    (j.value ->> 'index_mb')::numeric           AS index_mb,
    (j.value ->> 'fragmentation_pct')::numeric  AS fragmentation_pct,
    (j.value ->> 'fragment_count')::bigint      AS fragment_count,
    (j.value ->> 'recommended_action')          AS recommended_action,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-027-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_027_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_027_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-027-RC01';

COMMIT;
