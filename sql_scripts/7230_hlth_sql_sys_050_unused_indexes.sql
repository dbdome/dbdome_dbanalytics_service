-- ============================================================
-- 7230  HLTH-SQL-SYS-050-RC01  Unused indexes captured across all databases (sqlserver)
--   HEALTH system series root cause.
--   Rebuilt from the base per-database unused-index query:
--     * dm_db_index_usage_stats is PER-DATABASE-scoped even though it looks
--       instance-wide; the base wrapped it in a @DBNAME loop - replaced with
--       one dynamic UNION over all online user databases (single EXEC)
--     * LEFT JOIN to usage stats (INNER missed indexes with NO usage row at
--       all - never-touched indexes, the most unused of all)
--     * added last_user_update, size (partition_stats) and write count as the
--       ranking; size for the reclaim estimate
--   2005+. Requires VIEW SERVER STATE + db access.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-050','HLTH','SQL','SYS','Unused Nonclustered Indexes','unused-indexes',
        'Nonclustered indexes with zero reads (seeks/scans/lookups) since startup but ongoing write maintenance - pure write overhead across all databases.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-050-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-050-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-050-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-050-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-050-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-050-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-050-RC01', 'HLTH-SQL-SYS-050', 'Unused indexes captured across all databases',
    'unused-indexes-rc01',
    'Every non-PK, non-unique nonclustered index in every user database with ZERO reads (user_seeks + user_scans + user_lookups = 0) since the last restart, but non-zero user_updates (write cost): database, schema, table, index, the usage counters, last seek/update times, table row count and the index size. Highest write burden first. These indexes cost writes and space while returning nothing - drop candidates. Since usage stats reset on restart, confirm across a full workload cycle (and on all AG replicas) before dropping.',
    ARRAY['health', 'indexes', 'unused', 'maintenance', 'write-overhead'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-050-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nDECLARE @sql nvarchar(max) = N'''';\nSELECT @sql = @sql + N'' UNION ALL SELECT N'''''' + REPLACE(name, '''''''', '''''''''''') + N'''''' COLLATE DATABASE_DEFAULT AS database_name,''\n    + N'' sch.name COLLATE DATABASE_DEFAULT AS schema_name,''\n    + N'' o.name COLLATE DATABASE_DEFAULT AS table_name,''\n    + N'' i.name COLLATE DATABASE_DEFAULT AS index_name,''\n    + N'' i.index_id,''\n    + N'' ISNULL(us.user_seeks,0) AS user_seeks, ISNULL(us.user_scans,0) AS user_scans,''\n    + N'' ISNULL(us.user_lookups,0) AS user_lookups, ISNULL(us.user_updates,0) AS user_updates,''\n    + N'' CONVERT(varchar(19), us.last_user_seek, 120) AS last_user_seek,''\n    + N'' CONVERT(varchar(19), us.last_user_update, 120) AS last_user_update,''\n    + N'' p.row_count,''\n    + N'' CAST(p.reserved_page_count*8/1024.0 AS decimal(18,2)) AS index_mb''\n    + N'' FROM '' + QUOTENAME(name) + N''.sys.indexes i''\n    + N'' JOIN '' + QUOTENAME(name) + N''.sys.objects o ON o.object_id = i.object_id''\n    + N'' JOIN '' + QUOTENAME(name) + N''.sys.schemas sch ON sch.schema_id = o.schema_id''\n    + N'' JOIN (SELECT object_id, index_id, SUM(row_count) AS row_count, SUM(reserved_page_count) AS reserved_page_count''\n    + N''       FROM '' + QUOTENAME(name) + N''.sys.dm_db_partition_stats GROUP BY object_id, index_id) p''\n    + N''   ON p.object_id = i.object_id AND p.index_id = i.index_id''\n    + N'' LEFT JOIN '' + QUOTENAME(name) + N''.sys.dm_db_index_usage_stats us''\n    + N''   ON us.object_id = i.object_id AND us.index_id = i.index_id AND us.database_id = DB_ID(N'''''' + REPLACE(name, '''''''', '''''''''''') + N'''''')''\n    + N'' WHERE o.is_ms_shipped = 0 AND o.type = ''''U''''''\n    + N''   AND i.type_desc = ''''NONCLUSTERED'''' AND i.is_primary_key = 0 AND i.is_unique_constraint = 0''\n    + N''   AND (ISNULL(us.user_seeks,0) + ISNULL(us.user_scans,0) + ISNULL(us.user_lookups,0)) = 0''\nFROM sys.databases\nWHERE database_id > 4 AND state = 0 AND user_access = 0;\nIF @sql = N''''\n    SELECT CAST(NULL AS sysname) AS database_name, CAST(NULL AS sysname) AS schema_name,\n           CAST(NULL AS sysname) AS table_name, CAST(NULL AS sysname) AS index_name,\n           CAST(NULL AS int) AS index_id, CAST(NULL AS bigint) AS user_seeks, CAST(NULL AS bigint) AS user_scans,\n           CAST(NULL AS bigint) AS user_lookups, CAST(NULL AS bigint) AS user_updates,\n           CAST(NULL AS varchar(19)) AS last_user_seek, CAST(NULL AS varchar(19)) AS last_user_update,\n           CAST(NULL AS bigint) AS row_count, CAST(NULL AS decimal(18,2)) AS index_mb\n    WHERE 1 = 0;\nELSE\nBEGIN\n    SET @sql = N''SELECT TOP 500 * FROM ('' + STUFF(@sql, 1, 11, N'''') + N'') u ORDER BY user_updates DESC, index_mb DESC'';\n    EXEC(@sql);\nEND"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Unused indexes found (zero rows = every index earns its keep)"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-050-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-050-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-050-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-050-RC01 (sqlserver)', 'Unused indexes captured across all databases', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-050-RC01 (sqlserver)', '{"action": "user_updates is the write penalty this index imposes for zero read benefit - the highest values are the best drop candidates; ALWAYS verify usage stats cover a FULL business cycle (month-end/quarter-end reports may be the only reader) and that the instance has not restarted recently (stats reset - check SYS-001 uptime); on AG/mirroring, an index unused on the primary may serve readable-secondary workloads - check every replica; script the index definition before dropping so it can be recreated; a unique index is excluded even if unused (it may enforce a constraint)."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-050-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-050-RC01 (sqlserver)', 'resolve-hlth_sql_sys_050_rc01-sqlserver', 'Unused indexes captured across all databases: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_050_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_050_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'database_name')               AS database_name,
    (j.value ->> 'schema_name')                 AS schema_name,
    (j.value ->> 'table_name')                  AS table_name,
    (j.value ->> 'index_name')                  AS index_name,
    (j.value ->> 'index_id')::int               AS index_id,
    (j.value ->> 'user_seeks')::bigint          AS user_seeks,
    (j.value ->> 'user_scans')::bigint          AS user_scans,
    (j.value ->> 'user_lookups')::bigint        AS user_lookups,
    (j.value ->> 'user_updates')::bigint        AS user_updates,
    (j.value ->> 'last_user_seek')              AS last_user_seek,
    (j.value ->> 'last_user_update')            AS last_user_update,
    (j.value ->> 'row_count')::bigint           AS row_count,
    (j.value ->> 'index_mb')::numeric           AS index_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-050-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_050_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_050_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-050-RC01';

COMMIT;
