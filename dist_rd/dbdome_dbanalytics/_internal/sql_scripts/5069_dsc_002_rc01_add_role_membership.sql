-- =============================================================================
-- 5069_dsc_002_rc01_add_role_membership.sql
-- SEC-SQL-DSC-002-RC01 (sqlserver) listed database/server ROLES and USERS/LOGINS
-- separately but never the MEMBERSHIP linking them. Add membership rows so each
-- member is shown against the role it belongs to:
--   principal_type = 'database_role_member' / 'server_role_member'
--   principal_name = the member (user/login)
--   detail         = the role it is a member of (incl. fixed roles db_owner,
--                    db_datareader, sysadmin, ... which the role-definition
--                    branches skip).
-- Source: sys.database_role_members / sys.server_role_members.
-- Same 5-column shape (server, database_name, principal_type, principal_name,
-- detail) so the existing monitoring.v_sec_sql_dsc_002_rc01 surfaces them.
-- No '--' inside the stored SQL (collector flattens newlines). Idempotent.
-- =============================================================================
UPDATE rootcause.detection_steps
SET content = jsonb_set(content, '{sql}', to_jsonb($q$SET NOCOUNT ON;
DECLARE @sql nvarchar(max) = N'';
SELECT @sql = @sql
    + N'SELECT @@SERVERNAME AS server, ''' + name + N''' AS database_name, ''database_role'' AS principal_type, '
    + N'dp.name AS principal_name, dp.type_desc AS detail FROM ' + QUOTENAME(name)
    + N'.sys.database_principals dp WHERE dp.type = ''R'' AND dp.is_fixed_role = 0 AND dp.name <> ''public'' '
    + N'UNION ALL SELECT @@SERVERNAME, ''' + name + N''', ''user'', dp.name, dp.type_desc FROM ' + QUOTENAME(name)
    + N'.sys.database_principals dp WHERE dp.type IN (''S'',''U'',''G'') '
    + N'AND dp.name NOT IN (''dbo'',''guest'',''INFORMATION_SCHEMA'',''sys'') '
    + N'UNION ALL SELECT @@SERVERNAME, ''' + name + N''', ''database_role_member'', m.name, r.name FROM ' + QUOTENAME(name)
    + N'.sys.database_role_members drm '
    + N'JOIN ' + QUOTENAME(name) + N'.sys.database_principals r ON r.principal_id = drm.role_principal_id '
    + N'JOIN ' + QUOTENAME(name) + N'.sys.database_principals m ON m.principal_id = drm.member_principal_id '
    + N'WHERE m.name NOT IN (''dbo'') '
    + N'UNION ALL '
FROM sys.databases
WHERE state = 0 AND database_id > 4 AND HAS_DBACCESS(name) = 1
  AND name NOT IN ('distribution','ReportServer','ReportServerTempDB','SSISDB');
SET @sql = @sql
    + N'SELECT @@SERVERNAME AS server, CAST(NULL AS sysname) AS database_name, ''server_role'' AS principal_type, '
    + N'sp.name AS principal_name, sp.type_desc AS detail FROM sys.server_principals sp WHERE sp.type = ''R'' '
    + N'UNION ALL SELECT @@SERVERNAME, NULL, ''login'', sp.name, sp.type_desc FROM sys.server_principals sp '
    + N'WHERE sp.type IN (''S'',''U'',''G'') AND sp.name NOT LIKE ''##%'' '
    + N'UNION ALL SELECT @@SERVERNAME, NULL, ''server_role_member'', m.name, r.name FROM sys.server_role_members srm '
    + N'JOIN sys.server_principals r ON r.principal_id = srm.role_principal_id '
    + N'JOIN sys.server_principals m ON m.principal_id = srm.member_principal_id '
    + N'WHERE m.name NOT LIKE ''##%''';
EXEC sys.sp_executesql @sql;$q$::text))
WHERE vendor_slug='sqlserver' AND name='Detect SEC-SQL-DSC-002-RC01 (sqlserver)';

-- VERIFY: membership branches now present
SELECT name,
       CASE WHEN content->>'sql' LIKE '%database_role_members%'
             AND content->>'sql' LIKE '%server_role_members%'
            THEN 'membership-added' ELSE 'MISSING' END AS state
FROM rootcause.detection_steps
WHERE vendor_slug='sqlserver' AND name='Detect SEC-SQL-DSC-002-RC01 (sqlserver)';
