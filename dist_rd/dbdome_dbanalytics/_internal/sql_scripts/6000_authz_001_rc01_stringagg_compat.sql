-- 6000: SEC-SQL-AUTHZ-001-RC01 (sqlserver) made STRING_AGG-free for SQL Server < 2017.
-- Creates two helper scalar functions (FOR XML PATH based) IF NOT EXISTS at the start of
-- each per-database batch, then uses them in the SELECT. Idempotent (full-value SET).
UPDATE rootcause.detection_steps
SET content = jsonb_set(content, '{sql}', to_jsonb($dbdome$SET NOCOUNT ON;
IF OBJECT_ID('tempdb..#access') IS NOT NULL DROP TABLE #access;
CREATE TABLE #access (server SYSNAME NULL, database_name SYSNAME NULL, login_name SYSNAME NULL, database_user SYSNAME NULL, principal_type NVARCHAR(60) NULL, roles NVARCHAR(MAX) NULL, permissions NVARCHAR(MAX) NULL, login_status NVARCHAR(40) NULL);
DECLARE @db SYSNAME; DECLARE @sql NVARCHAR(MAX);
DECLARE db_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT name FROM sys.databases WHERE state = 0 AND database_id > 4 AND HAS_DBACCESS(name) = 1
      AND name NOT IN ('master','model','msdb','tempdb','distribution','ReportServer','ReportServerTempDB','SSISDB');
OPEN db_cursor; FETCH NEXT FROM db_cursor INTO @db;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'USE ' + QUOTENAME(@db) + N'; IF OBJECT_ID(''dbo.fn_dbdome_principal_roles'') IS NULL EXEC(''CREATE FUNCTION dbo.fn_dbdome_principal_roles(@member_id int) RETURNS nvarchar(max) AS BEGIN RETURN STUFF((SELECT '''','''' + rp.name COLLATE DATABASE_DEFAULT FROM sys.database_role_members drm JOIN sys.database_principals rp ON rp.principal_id = drm.role_principal_id WHERE drm.member_principal_id = @member_id ORDER BY rp.name FOR XML PATH(''''''''), TYPE).value(''''text()[1]'''',''''nvarchar(max)''''), 1, 1, ''''''''); END''); IF OBJECT_ID(''dbo.fn_dbdome_principal_perms'') IS NULL EXEC(''CREATE FUNCTION dbo.fn_dbdome_principal_perms(@grantee_id int) RETURNS nvarchar(max) AS BEGIN RETURN STUFF((SELECT '''', '''' + p.state_desc COLLATE DATABASE_DEFAULT + '''' '''' + p.permission_name + '''' ON '''' + CASE p.class WHEN 0 THEN DB_NAME() WHEN 1 THEN ISNULL(QUOTENAME(SCHEMA_NAME(o.schema_id)) + ''''.'''', '''''''') + ISNULL(o.name, ''''(object_id '''' + CAST(p.major_id AS nvarchar(20)) + '''')'''') WHEN 3 THEN ISNULL(s.name, ''''(schema_id '''' + CAST(p.major_id AS nvarchar(20)) + '''')'''') ELSE p.class_desc + '''' (major_id '''' + CAST(p.major_id AS nvarchar(20)) + '''')'''' END FROM sys.database_permissions p LEFT JOIN sys.objects o ON p.class = 1 AND o.object_id = p.major_id LEFT JOIN sys.schemas s ON p.class = 3 AND s.schema_id = p.major_id WHERE p.grantee_principal_id = @grantee_id FOR XML PATH(''''''''), TYPE).value(''''text()[1]'''',''''nvarchar(max)''''), 1, 2, ''''''''); END''); INSERT INTO #access (server, database_name, login_name, database_user, principal_type, roles, permissions, login_status) SELECT @@SERVERNAME, DB_NAME(), sp.name, dp.name, dp.type_desc, dbo.fn_dbdome_principal_roles(dp.principal_id), dbo.fn_dbdome_principal_perms(dp.principal_id), CASE WHEN sp.name IS NOT NULL THEN ''mapped'' WHEN dp.authentication_type_desc = ''INSTANCE'' THEN ''ORPHANED'' WHEN dp.authentication_type_desc = ''DATABASE'' THEN ''contained'' WHEN dp.authentication_type_desc = ''NONE'' THEN ''no-login'' ELSE dp.authentication_type_desc END FROM sys.database_principals AS dp LEFT JOIN sys.server_principals AS sp ON sp.sid = dp.sid WHERE dp.type IN (''S'',''U'',''G'',''E'',''X'') AND dp.is_fixed_role = 0 AND dp.principal_id >= 5 AND dp.name NOT IN (''sys'',''INFORMATION_SCHEMA'',''guest'');';
    BEGIN TRY EXEC sys.sp_executesql @sql; END TRY BEGIN CATCH END CATCH;
    FETCH NEXT FROM db_cursor INTO @db;
END
CLOSE db_cursor; DEALLOCATE db_cursor;
SELECT server, database_name, login_name, database_user, principal_type, roles, permissions, login_status FROM #access ORDER BY database_name, database_user;
DROP TABLE #access;$dbdome$::text))
WHERE vendor_slug = 'sqlserver' AND name = 'Detect SEC-SQL-AUTHZ-001-RC01 (sqlserver)';
