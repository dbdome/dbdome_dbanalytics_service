-- =============================================================================
-- 5062_dsc_001_rc01_add_principals.sql
-- SEC-SQL-DSC-001-RC01 "Data Structure Discovery" returned only data objects
-- (database -> schema -> table -> column). Extend it to ALSO return the RBAC
-- principals (server roles, logins, database roles, users) in one unified
-- result, discriminated by object_type:
--   object_type = 'column'                          -> data hierarchy rows
--   object_type = 'server_role' | 'login'           -> instance-level principals
--   object_type = 'database_role' | 'user'          -> per-database principals
-- Data columns (schema/table/column/data_type/ordinal) are NULL on principal
-- rows; principal columns (principal_type/principal_name/detail) are NULL on
-- data rows. Single dynamic batch, no '--' comments (the collector flattens
-- \n -> space). The companion view is rebuilt to expose the new columns.
-- Idempotent. =============================================================================

UPDATE rootcause.detection_steps
SET content = jsonb_set(content, '{sql}', to_jsonb($dsc001$SET NOCOUNT ON;
DECLARE @sql nvarchar(max) = N'';
SELECT @sql = @sql
    + N'SELECT @@SERVERNAME AS server, ''' + name + N''' AS database_name, CAST(''column'' AS sysname) AS object_type, '
    + N's.name AS schema_name, t.name AS table_name, c.name AS column_name, ty.name AS data_type, c.column_id AS ordinal, '
    + N'CAST(NULL AS sysname) AS principal_type, CAST(NULL AS sysname) AS principal_name, CAST(NULL AS nvarchar(256)) AS detail '
    + N'FROM ' + QUOTENAME(name) + N'.sys.tables t '
    + N'JOIN ' + QUOTENAME(name) + N'.sys.schemas s ON s.schema_id = t.schema_id '
    + N'JOIN ' + QUOTENAME(name) + N'.sys.columns c ON c.object_id = t.object_id '
    + N'JOIN ' + QUOTENAME(name) + N'.sys.types ty ON ty.user_type_id = c.user_type_id '
    + N'WHERE t.is_ms_shipped = 0 UNION ALL '
    + N'SELECT @@SERVERNAME, ''' + name + N''', CAST(''database_role'' AS sysname), '
    + N'CAST(NULL AS sysname), CAST(NULL AS sysname), CAST(NULL AS sysname), CAST(NULL AS sysname), CAST(NULL AS int), '
    + N'CAST(''database_role'' AS sysname), dp.name, CAST(dp.type_desc AS nvarchar(256)) '
    + N'FROM ' + QUOTENAME(name) + N'.sys.database_principals dp '
    + N'WHERE dp.type = ''R'' AND dp.is_fixed_role = 0 AND dp.name <> ''public'' UNION ALL '
    + N'SELECT @@SERVERNAME, ''' + name + N''', CAST(''user'' AS sysname), '
    + N'CAST(NULL AS sysname), CAST(NULL AS sysname), CAST(NULL AS sysname), CAST(NULL AS sysname), CAST(NULL AS int), '
    + N'CAST(''user'' AS sysname), dp.name, CAST(dp.type_desc AS nvarchar(256)) '
    + N'FROM ' + QUOTENAME(name) + N'.sys.database_principals dp '
    + N'WHERE dp.type IN (''S'',''U'',''G'') AND dp.name NOT IN (''dbo'',''guest'',''INFORMATION_SCHEMA'',''sys'') UNION ALL '
FROM sys.databases
WHERE state = 0 AND database_id > 4 AND HAS_DBACCESS(name) = 1
  AND name NOT IN ('distribution','ReportServer','ReportServerTempDB','SSISDB');
IF LEN(@sql) > 10 SET @sql = LEFT(@sql, LEN(@sql) - 10);
IF @sql <> N'' SET @sql = @sql + N' UNION ALL ';
SET @sql = @sql
    + N'SELECT @@SERVERNAME AS server, CAST(NULL AS sysname) AS database_name, CAST(''server_role'' AS sysname) AS object_type, '
    + N'CAST(NULL AS sysname) AS schema_name, CAST(NULL AS sysname) AS table_name, CAST(NULL AS sysname) AS column_name, CAST(NULL AS sysname) AS data_type, CAST(NULL AS int) AS ordinal, '
    + N'CAST(''server_role'' AS sysname) AS principal_type, sp.name AS principal_name, CAST(sp.type_desc AS nvarchar(256)) AS detail '
    + N'FROM sys.server_principals sp WHERE sp.type = ''R'' UNION ALL '
    + N'SELECT @@SERVERNAME, CAST(NULL AS sysname), CAST(''login'' AS sysname), '
    + N'CAST(NULL AS sysname), CAST(NULL AS sysname), CAST(NULL AS sysname), CAST(NULL AS sysname), CAST(NULL AS int), '
    + N'CAST(''login'' AS sysname), sp.name, CAST(sp.type_desc AS nvarchar(256)) '
    + N'FROM sys.server_principals sp WHERE sp.type IN (''S'',''U'',''G'') AND sp.name NOT LIKE ''##%''';
EXEC sys.sp_executesql @sql;$dsc001$::text))
WHERE vendor_slug = 'sqlserver'
  AND name LIKE '%DSC-001-RC01%';

-- Rebuild the view to expose object_type + principal columns (column order
-- changes, so DROP+CREATE; nothing depends on this view).
DROP VIEW IF EXISTS monitoring.v_sec_sql_dsc_001_rc01;
CREATE VIEW monitoring.v_sec_sql_dsc_001_rc01 AS
SELECT
    r.server,
    j.value ->> 'object_type'    AS object_type,
    j.value ->> 'database_name'  AS database_name,
    j.value ->> 'schema_name'    AS schema_name,
    j.value ->> 'table_name'     AS table_name,
    j.value ->> 'column_name'    AS column_name,
    j.value ->> 'data_type'      AS data_type,
    j.value ->> 'ordinal'        AS ordinal,
    j.value ->> 'principal_type' AS principal_type,
    j.value ->> 'principal_name' AS principal_name,
    j.value ->> 'detail'         AS detail,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-DSC-001-RC01';

-- VERIFY
SELECT id, vendor_slug, name,
       length(content->>'sql') AS sql_len,
       CASE WHEN content->>'sql' LIKE '%server_principals%' THEN 'has-principals' ELSE 'data-only' END AS state
FROM rootcause.detection_steps
WHERE vendor_slug='sqlserver' AND name LIKE '%DSC-001-RC01%';
