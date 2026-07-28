-- ============================================================
-- 7240  HLTH-SQL-SYS-051-RC01  Database permission grants captured (sqlserver)
--   HEALTH system series root cause.
--   Rebuilt from the base per-database user_grants query:
--     * sys.database_permissions is PER-DATABASE - the base used a @DBNAME
--       loop; replaced with one dynamic UNION over all online user databases
--     * the base INNER JOIN to sys.objects DROPPED database- and schema-scope
--       grants (class 0 and 3, which have no object row) - now LEFT JOINs
--       with the securable resolved per class
--     * added grant state (GRANT/DENY/WITH GRANT) and securable class;
--       filtered out public/guest/dbo/sys noise
--   2005+. Requires db access on every database.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-051','HLTH','SQL','SYS','Database Permission Grants','database-permissions',
        'Explicit database-level permission grants per user (object, schema and database scope) across every database - the database-tier privilege inventory.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-051-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-051-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-051-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-051-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-051-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-051-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-051-RC01', 'HLTH-SQL-SYS-051', 'Database permission grants captured',
    'database-permissions-rc01',
    'Every explicit database permission granted to a real user (public/guest/dbo/sys excluded, principal_id > 4) in every user database: grantee and type, permission name, GRANT/DENY/WITH GRANT state, the securable class and the resolved securable name (schema.object, schema::name, or the database). The database/object-tier companion to the server-tier inventory in SYS-032; together they give the full privilege picture for least-privilege review and drift detection.',
    ARRAY['health', 'security', 'permissions', 'grants', 'authorization'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-051-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nDECLARE @sql nvarchar(max) = N'''';\nSELECT @sql = @sql + N'' UNION ALL''\n    + N'' SELECT N'''''' + REPLACE(name, '''''''', '''''''''''') + N'''''' COLLATE DATABASE_DEFAULT AS database_name,''\n    + N'' dp.name COLLATE DATABASE_DEFAULT AS grantee, dp.type_desc COLLATE DATABASE_DEFAULT AS grantee_type,''\n    + N'' perm.permission_name COLLATE DATABASE_DEFAULT AS permission, perm.state_desc COLLATE DATABASE_DEFAULT AS state,''\n    + N'' perm.class_desc COLLATE DATABASE_DEFAULT AS class,''\n    + N'' CASE perm.class WHEN 0 THEN ''''(database)''''''\n    + N''   WHEN 1 THEN ISNULL(sch.name + ''''.'''', '''''''') + obj.name''\n    + N''   WHEN 3 THEN ''''schema::'''' + sch2.name ELSE CONVERT(sysname, perm.major_id) END COLLATE DATABASE_DEFAULT AS securable''\n    + N'' FROM '' + QUOTENAME(name) + N''.sys.database_permissions perm''\n    + N'' JOIN '' + QUOTENAME(name) + N''.sys.database_principals dp ON dp.principal_id = perm.grantee_principal_id''\n    + N'' LEFT JOIN '' + QUOTENAME(name) + N''.sys.objects obj ON perm.class = 1 AND obj.object_id = perm.major_id''\n    + N'' LEFT JOIN '' + QUOTENAME(name) + N''.sys.schemas sch ON sch.schema_id = obj.schema_id''\n    + N'' LEFT JOIN '' + QUOTENAME(name) + N''.sys.schemas sch2 ON perm.class = 3 AND sch2.schema_id = perm.major_id''\n    + N'' WHERE dp.name NOT IN (''''public'''', ''''guest'''', ''''dbo'''', ''''INFORMATION_SCHEMA'''', ''''sys'''')''\n    + N''   AND dp.principal_id > 4''\nFROM sys.databases\nWHERE database_id > 4 AND state = 0 AND user_access = 0;\nIF @sql = N''''\n    SELECT CAST(NULL AS sysname) AS database_name, CAST(NULL AS sysname) AS grantee,\n           CAST(NULL AS nvarchar(60)) AS grantee_type, CAST(NULL AS sysname) AS permission,\n           CAST(NULL AS nvarchar(60)) AS state, CAST(NULL AS nvarchar(60)) AS class,\n           CAST(NULL AS sysname) AS securable\n    WHERE 1 = 0;\nELSE\nBEGIN\n    SET @sql = N''SELECT TOP 1000 * FROM ('' + STUFF(@sql, 1, 10, N'''') + N'') u ORDER BY database_name, grantee, securable'';\n    EXEC(@sql);\nEND"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Database permission grants captured (zero rows = only role-based / inherited access)"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-051-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-051-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-051-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-051-RC01 (sqlserver)', 'Database permission grants captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-051-RC01 (sqlserver)', '{"action": "Direct object grants to individual users are a maintenance and audit hazard - prefer database ROLES (grant to a role, add users to it); WITH GRANT (state GRANT_WITH_GRANT_OPTION) lets the grantee re-grant - a privilege-sprawl vector; CONTROL or ALTER at database or schema scope is near-owner power - scrutinize; a DENY that contradicts a role GRANT is a common access-troubleshooting cause; diff snapshots to catch grant drift and correlate additions with SEC-SQL-AUD-026 privilege-escalation events. Note this shows EXPLICIT grants only - effective access also flows through role membership and server-level rights (SYS-032)."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-051-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-051-RC01 (sqlserver)', 'resolve-hlth_sql_sys_051_rc01-sqlserver', 'Database permission grants captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_051_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_051_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'database_name')               AS database_name,
    (j.value ->> 'grantee')                     AS grantee,
    (j.value ->> 'grantee_type')                AS grantee_type,
    (j.value ->> 'permission')                  AS permission,
    (j.value ->> 'state')                       AS state,
    (j.value ->> 'class')                       AS class,
    (j.value ->> 'securable')                   AS securable,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-051-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_051_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_051_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-051-RC01';

COMMIT;
