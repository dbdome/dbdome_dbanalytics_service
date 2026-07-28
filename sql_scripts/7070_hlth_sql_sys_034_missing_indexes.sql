-- ============================================================
-- 7070  HLTH-SQL-SYS-034-RC01  Missing index suggestions captured (sqlserver)
--   HEALTH system series root cause.
--   Enriched from the base missing-index query:
--     * kept the dedupe (widest INCLUDE per table+equality set) but ADDED
--       user_scans to the advantage formula (seeks alone undercounts)
--     * inequality_columns restored to the output (the base selected it in
--       the CTE and then dropped it from the final projection)
--     * generated CREATE INDEX statement per suggestion (IX_dbdome_ prefix)
--     * NOLOCK / OPTION (RECOMPILE) dropped; TOP 100 by advantage
--   2005+. Requires VIEW SERVER STATE.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-034','HLTH','SQL','SYS','Missing Index Suggestions','missing-indexes',
        'Deduplicated missing-index suggestions across the instance, ranked by estimated advantage, with ready CREATE INDEX statements.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-034-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-034-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-034-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-034-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-034-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-034-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-034-RC01', 'HLTH-SQL-SYS-034', 'Missing index suggestions captured',
    'missing-indexes-rc01',
    'Missing-index DMV suggestions deduplicated per table + equality-column set (keeping the widest INCLUDE variant), ranked by advantage = (seeks + scans) x avg cost x impact: database, table, key/inequality/included columns, usage counters, last seek time and a generated CREATE INDEX statement. Suggestions reset on restart and vanish on plan eviction - persistent high-advantage entries across snapshots are the real candidates.',
    ARRAY['health', 'indexes', 'missing-index', 'performance', 'tuning'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-034-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nWITH mi AS (\n    SELECT ROW_NUMBER() OVER (PARTITION BY mid.database_id, mid.statement, mid.equality_columns\n                              ORDER BY LEN(ISNULL(mid.included_columns, '''')) DESC) AS seq,\n           DB_NAME(mid.database_id) AS database_name,\n           CONVERT(decimal(18,2), (migs.user_seeks + migs.user_scans) * migs.avg_total_user_cost * (migs.avg_user_impact * 0.01)) AS index_advantage,\n           CONVERT(varchar(19), migs.last_user_seek, 120) AS last_user_seek,\n           mid.statement AS table_ref,\n           mid.equality_columns,\n           mid.inequality_columns,\n           mid.included_columns,\n           migs.unique_compiles,\n           migs.user_seeks,\n           migs.user_scans,\n           CONVERT(decimal(18,2), migs.avg_total_user_cost) AS avg_total_user_cost,\n           CONVERT(decimal(5,2), migs.avg_user_impact) AS avg_user_impact,\n           ''CREATE INDEX IX_dbdome_'' + CONVERT(varchar(20), mig.index_group_handle) + ''_'' + CONVERT(varchar(20), mid.index_handle)\n             + '' ON '' + mid.statement + '' ('' + ISNULL(mid.equality_columns, '''')\n             + CASE WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL THEN '','' ELSE '''' END\n             + ISNULL(mid.inequality_columns, '''') + '')''\n             + ISNULL('' INCLUDE ('' + mid.included_columns + '')'', '''') AS create_index_statement\n    FROM sys.dm_db_missing_index_group_stats migs\n    JOIN sys.dm_db_missing_index_groups mig ON mig.index_group_handle = migs.group_handle\n    JOIN sys.dm_db_missing_index_details mid ON mid.index_handle = mig.index_handle\n)\nSELECT TOP 100\n    database_name, index_advantage, last_user_seek, table_ref,\n    equality_columns, inequality_columns, included_columns,\n    unique_compiles, user_seeks, user_scans, avg_total_user_cost, avg_user_impact,\n    create_index_statement\nFROM mi\nWHERE seq = 1 AND equality_columns IS NOT NULL\nORDER BY index_advantage DESC"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Missing index suggestions present (zero rows = optimizer wants nothing)"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-034-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-034-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-034-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-034-RC01 (sqlserver)', 'Missing index suggestions captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-034-RC01 (sqlserver)', '{"action": "Never create blindly: the DMVs suggest per-query indexes - overlapping suggestions on one table usually consolidate into ONE index (widest keys + merged INCLUDE); check against existing indexes (a suggestion nearly identical to an existing index means key ORDER is the problem); every index taxes writes - weigh user_seeks against the table write rate; last_user_seek long ago = stale suggestion, skip; validate the winner against the workload (correlate HLTH-SQL-SYS-005/010)."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-034-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-034-RC01 (sqlserver)', 'resolve-hlth_sql_sys_034_rc01-sqlserver', 'Missing index suggestions captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_034_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_034_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'database_name')               AS database_name,
    (j.value ->> 'index_advantage')::numeric    AS index_advantage,
    (j.value ->> 'last_user_seek')              AS last_user_seek,
    (j.value ->> 'table_ref')                   AS table_ref,
    (j.value ->> 'equality_columns')            AS equality_columns,
    (j.value ->> 'inequality_columns')          AS inequality_columns,
    (j.value ->> 'included_columns')            AS included_columns,
    (j.value ->> 'unique_compiles')::bigint     AS unique_compiles,
    (j.value ->> 'user_seeks')::bigint          AS user_seeks,
    (j.value ->> 'user_scans')::bigint          AS user_scans,
    (j.value ->> 'avg_total_user_cost')::numeric AS avg_total_user_cost,
    (j.value ->> 'avg_user_impact')::numeric    AS avg_user_impact,
    (j.value ->> 'create_index_statement')      AS create_index_statement,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-034-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_034_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_034_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-034-RC01';

COMMIT;
