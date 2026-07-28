-- =============================================================================
-- 6120_rbac_inventory_rootcause.sql
-- Root cause SEC-SQL-DSC-002-RC01 "RBAC inventory" — returns the server's RBAC
-- principals in one result set, tagged by principal_type so each feeds a separate
-- dashboard panel:
--   server_role | login            (server scope)
--   database_role | user           (per database)
-- Columns: server, database_name, principal_type, principal_name, detail.
-- Powers the RBAC dashboard panels (server roles / db roles / logins / users).
-- Idempotent. (area DSC created by 6110.)
-- =============================================================================

INSERT INTO rootcause.areas (code, database_type_code, name, description, is_enabled, category_id)
SELECT 'DSC','SQL','Data Structure Discovery','Server data hierarchy / data discovery scoping', true, 'c001'
WHERE NOT EXISTS (SELECT 1 FROM rootcause.areas WHERE code='DSC' AND database_type_code='SQL');

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, category_id)
VALUES ('SEC-SQL-DSC-002','SEC','SQL','DSC','RBAC Principal Inventory','rbac-principal-inventory',
        'Inventory of server and database security principals (server roles, logins, database roles, users) for RBAC review and provisioning.',
        'c001')
ON CONFLICT (issue_id) DO NOTHING;

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES ('SEC-SQL-DSC-002-RC01','SEC-SQL-DSC-002','RBAC inventory (server roles, db roles, logins, users)',
        'rbac-inventory',
        'Lists every server role, login, database role and database user on the server (tagged by principal_type), so the RBAC dashboard can show each in its own panel.',
        ARRAY['rbac','roles','logins','users','authorization','inventory'], ARRAY['sqlserver'])
ON CONFLICT (root_cause_id) DO UPDATE SET
    name=EXCLUDED.name, description=EXCLUDED.description, topics=EXCLUDED.topics, vendors_applicable=EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver','query','Detect SEC-SQL-DSC-002-RC01 (sqlserver)',
    jsonb_build_object('sql', $q$
SET NOCOUNT ON;
DECLARE @sql nvarchar(max) = N'';
SELECT @sql = @sql
    + N'SELECT @@SERVERNAME AS server, ''' + name + N''' AS database_name, ''database_role'' AS principal_type, '
    + N'dp.name AS principal_name, dp.type_desc AS detail FROM ' + QUOTENAME(name)
    + N'.sys.database_principals dp WHERE dp.type = ''R'' AND dp.is_fixed_role = 0 AND dp.name <> ''public'' '
    + N'UNION ALL SELECT @@SERVERNAME, ''' + name + N''', ''user'', dp.name, dp.type_desc FROM ' + QUOTENAME(name)
    + N'.sys.database_principals dp WHERE dp.type IN (''S'',''U'',''G'') '
    + N'AND dp.name NOT IN (''dbo'',''guest'',''INFORMATION_SCHEMA'',''sys'') UNION ALL '
FROM sys.databases
WHERE state = 0 AND database_id > 4 AND HAS_DBACCESS(name) = 1
  AND name NOT IN ('distribution','ReportServer','ReportServerTempDB','SSISDB');
SET @sql = @sql
    + N'SELECT @@SERVERNAME AS server, CAST(NULL AS sysname) AS database_name, ''server_role'' AS principal_type, '
    + N'sp.name AS principal_name, sp.type_desc AS detail FROM sys.server_principals sp WHERE sp.type = ''R'' '
    + N'UNION ALL SELECT @@SERVERNAME, NULL, ''login'', sp.name, sp.type_desc FROM sys.server_principals sp '
    + N'WHERE sp.type IN (''S'',''U'',''G'') AND sp.name NOT LIKE ''##%''';
EXEC sys.sp_executesql @sql;
$q$),
    jsonb_build_object('condition','row_count > 0','description','RBAC principals enumerated'))
ON CONFLICT (vendor_slug, name) DO UPDATE SET content = EXCLUDED.content, expected = EXCLUDED.expected;

DO $gen$
DECLARE v_step_id bigint; v_path_id bigint;
BEGIN
    SELECT id INTO v_step_id FROM rootcause.detection_steps
     WHERE vendor_slug='sqlserver' AND name='Detect SEC-SQL-DSC-002-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id='SEC-SQL-DSC-002-RC01' AND vendor_slug='sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('SEC-SQL-DSC-002-RC01','sqlserver','Detect SEC-SQL-DSC-002-RC01 (sqlserver)','RBAC inventory','diagnostic',true)
        RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
    END IF;
END
$gen$;
