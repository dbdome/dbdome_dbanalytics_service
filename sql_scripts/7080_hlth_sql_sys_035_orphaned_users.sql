-- ============================================================
-- 7080  HLTH-SQL-SYS-035-RC01  Orphaned users captured across all databases (sqlserver)
--   HEALTH system series root cause.
--   Rebuilt from the base single-database query:
--     * sys.database_principals is PER-DATABASE - the base only ever checked
--       the connected db; now a dynamic UNION over every online database
--       (single EXEC -> first rowset), tempdb excluded
--     * authentication_type_desc needs 2012+; capability-probed, with the
--       all-versions filter type IN (S,U,G) + real SID + principal_id > 4
--       (which also excludes the guest false-positive the base risked)
--     * added create_date, default schema and OWNED SCHEMAS (the blocker
--       for DROP USER remediation)
--   2005+. Requires db access on every database.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-035','HLTH','SQL','SYS','Orphaned Database Users','orphaned-users',
        'Database users whose SID no longer matches any server login, across every database - dead identities that block logins or linger as risk.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-035-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-035-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-035-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-035-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-035-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-035-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-035-RC01', 'HLTH-SQL-SYS-035', 'Orphaned users captured across all databases',
    'orphaned-users-rc01',
    'Every SQL/Windows-mapped database user (principal_id > 4, real SID) in every ONLINE database whose SID has no matching server login: database, user name, type, authentication type (2012+), SID, creation date, default schema and the schemas the user OWNS (which block a simple DROP USER). Classic causes: database restored from another server, or the login was dropped. Zero rows = no orphans.',
    ARRAY['health', 'security', 'users', 'orphaned', 'logins'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-035-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nDECLARE @sql nvarchar(max) = N'''';\nDECLARE @auth bit;\nSET @auth = CASE WHEN EXISTS (SELECT 1 FROM sys.all_columns\n                              WHERE object_id = OBJECT_ID(N''sys.database_principals'')\n                                AND name = N''authentication_type'') THEN 1 ELSE 0 END;\nSELECT @sql = @sql + N'' UNION ALL SELECT N'''''' + REPLACE(name, '''''''', '''''''''''') + N'''''' COLLATE DATABASE_DEFAULT AS database_name,''\n    + N'' dp.name COLLATE DATABASE_DEFAULT AS user_name,''\n    + N'' dp.type_desc COLLATE DATABASE_DEFAULT AS user_type,''\n    + CASE WHEN @auth = 1 THEN N'' dp.authentication_type_desc COLLATE DATABASE_DEFAULT AS authentication_type,''\n           ELSE N'' CAST(NULL AS nvarchar(60)) AS authentication_type,'' END\n    + N'' CONVERT(varchar(85), dp.sid, 1) AS sid,''\n    + N'' CONVERT(varchar(19), dp.create_date, 120) AS create_date,''\n    + N'' dp.default_schema_name COLLATE DATABASE_DEFAULT AS default_schema,''\n    + N'' STUFF((SELECT '''','''' + sch.name FROM '' + QUOTENAME(name) + N''.sys.schemas sch''\n    + N'' WHERE sch.principal_id = dp.principal_id FOR XML PATH('''''''')), 1, 1, '''''''') AS owned_schemas''\n    + N'' FROM '' + QUOTENAME(name) + N''.sys.database_principals dp''\n    + N'' LEFT JOIN sys.server_principals sp ON sp.sid = dp.sid''\n    + N'' WHERE dp.type IN (''''S'''', ''''U'''', ''''G'''') AND dp.sid IS NOT NULL''\n    + N'' AND dp.principal_id > 4 AND sp.sid IS NULL''\nFROM sys.databases\nWHERE database_id <> 2 AND state = 0 AND user_access = 0;\nIF @sql = N''''\n    SELECT CAST(NULL AS sysname) AS database_name, CAST(NULL AS sysname) AS user_name,\n           CAST(NULL AS nvarchar(60)) AS user_type, CAST(NULL AS nvarchar(60)) AS authentication_type,\n           CAST(NULL AS varchar(85)) AS sid, CAST(NULL AS varchar(19)) AS create_date,\n           CAST(NULL AS sysname) AS default_schema, CAST(NULL AS nvarchar(4000)) AS owned_schemas\n    WHERE 1 = 0;\nELSE\nBEGIN\n    SET @sql = N''SELECT TOP 500 * FROM ('' + STUFF(@sql, 1, 11, N'''') + N'') u ORDER BY database_name, user_name'';\n    EXEC(@sql);\nEND"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Orphaned users found (zero rows = no orphans anywhere)"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-035-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-035-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-035-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-035-RC01 (sqlserver)', 'Orphaned users captured across all databases', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-035-RC01 (sqlserver)', '{"action": "After a restore from another server, remap with ALTER USER [name] WITH LOGIN = [login] (same-named login exists) - never recreate the login with a new SID and a second user; truly dead users: transfer owned_schemas first (ALTER AUTHORIZATION ON SCHEMA), then DROP USER; a Windows-type orphan can mean the AD account was deleted - check for leftover permissions before dropping; recurring orphans after every deploy point at a restore pipeline that skips user remapping."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-035-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-035-RC01 (sqlserver)', 'resolve-hlth_sql_sys_035_rc01-sqlserver', 'Orphaned users captured across all databases: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_035_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_035_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'database_name')               AS database_name,
    (j.value ->> 'user_name')                   AS user_name,
    (j.value ->> 'user_type')                   AS user_type,
    (j.value ->> 'authentication_type')         AS authentication_type,
    (j.value ->> 'sid')                         AS sid,
    (j.value ->> 'create_date')                 AS create_date,
    (j.value ->> 'default_schema')              AS default_schema,
    (j.value ->> 'owned_schemas')               AS owned_schemas,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-035-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_035_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_035_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-035-RC01';

COMMIT;
