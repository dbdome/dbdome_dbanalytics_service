-- 5920: add login_status (mapped / ORPHANED / contained / no-login) to the access
-- inventory SEC-SQL-AUTHZ-001-RC01, so loginless/contained users are told apart
-- from genuinely ORPHANED ones (DB user with INSTANCE auth but no server login).
-- Idempotent: skipped once the column is present (NOT LIKE '%login_status%').

UPDATE rootcause.detection_steps
SET content = jsonb_set(content, '{sql}', to_jsonb($authz$
SET NOCOUNT ON;
IF OBJECT_ID('tempdb..#access') IS NOT NULL DROP TABLE #access;
CREATE TABLE #access (server SYSNAME NULL, database_name SYSNAME NULL, login_name SYSNAME NULL, database_user SYSNAME NULL, principal_type NVARCHAR(60) NULL, roles NVARCHAR(MAX) NULL, permissions NVARCHAR(MAX) NULL, login_status NVARCHAR(40) NULL);
DECLARE @db SYSNAME; DECLARE @sql NVARCHAR(MAX);
DECLARE db_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT name FROM sys.databases
    WHERE state = 0 AND database_id > 4 AND HAS_DBACCESS(name) = 1
      AND name NOT IN ('master','model','msdb','tempdb','distribution','ReportServer','ReportServerTempDB','SSISDB');
OPEN db_cursor; FETCH NEXT FROM db_cursor INTO @db;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'USE ' + QUOTENAME(@db) + N';
INSERT INTO #access (server, database_name, login_name, database_user, principal_type, roles, permissions, login_status)
SELECT @@SERVERNAME, DB_NAME(), sp.name, dp.name, dp.type_desc, r.roles, g.permissions, CASE WHEN sp.name IS NOT NULL THEN ''mapped'' WHEN dp.authentication_type_desc = ''INSTANCE'' THEN ''ORPHANED'' WHEN dp.authentication_type_desc = ''DATABASE'' THEN ''contained'' WHEN dp.authentication_type_desc = ''NONE'' THEN ''no-login'' ELSE dp.authentication_type_desc END
FROM sys.database_principals AS dp
LEFT JOIN sys.server_principals AS sp ON sp.sid = dp.sid
LEFT JOIN ( SELECT drm.member_principal_id AS member_id, STRING_AGG(rolep.name COLLATE DATABASE_DEFAULT, '','') WITHIN GROUP (ORDER BY rolep.name) AS roles
    FROM sys.database_role_members AS drm INNER JOIN sys.database_principals AS rolep ON rolep.principal_id = drm.role_principal_id
    GROUP BY drm.member_principal_id ) AS r ON r.member_id = dp.principal_id
LEFT JOIN ( SELECT perm.grantee_principal_id AS grantee_id, STRING_AGG(perm.state_desc COLLATE DATABASE_DEFAULT + '' '' + perm.permission_name + '' ON '' +
        CASE perm.class WHEN 0 THEN DB_NAME()
            WHEN 1 THEN ISNULL(QUOTENAME(SCHEMA_NAME(o.schema_id)) + ''.'', '''') + ISNULL(o.name, ''(object_id '' + CAST(perm.major_id AS NVARCHAR(20)) + '')'')
            WHEN 3 THEN ISNULL(s.name, ''(schema_id '' + CAST(perm.major_id AS NVARCHAR(20)) + '')'')
            ELSE perm.class_desc + '' (major_id '' + CAST(perm.major_id AS NVARCHAR(20)) + '')'' END, '', '') AS permissions
    FROM sys.database_permissions AS perm
    LEFT JOIN sys.objects AS o ON perm.class = 1 AND o.object_id = perm.major_id
    LEFT JOIN sys.schemas AS s ON perm.class = 3 AND s.schema_id = perm.major_id
    GROUP BY perm.grantee_principal_id ) AS g ON g.grantee_id = dp.principal_id
WHERE dp.type IN (''S'',''U'',''G'',''E'',''X'') AND dp.is_fixed_role = 0 AND dp.principal_id >= 5
  AND dp.name NOT IN (''sys'',''INFORMATION_SCHEMA'',''guest'');';
    EXEC sys.sp_executesql @sql;
    FETCH NEXT FROM db_cursor INTO @db;
END
CLOSE db_cursor; DEALLOCATE db_cursor;
SELECT server, database_name, login_name, database_user, principal_type, roles, permissions, login_status FROM #access ORDER BY database_name, database_user;
DROP TABLE #access;
$authz$::text))
WHERE vendor_slug = 'sqlserver'
  AND content->>'sql' LIKE '%STRING_AGG(rolep.name COLLATE%'
  AND content->>'sql' LIKE '%#access%'
  AND content->>'sql' NOT LIKE '%login_status%';
