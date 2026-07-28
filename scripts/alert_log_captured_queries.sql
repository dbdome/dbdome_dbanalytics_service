-- Captured SQL from alerts.alert_log (source=alerts).
-- These are the statements flagged sessions were running; some may be DML.
-- SAFETY: run inside a rolled-back transaction, e.g.:
--   BEGIN TRAN;  <paste a batch>  ROLLBACK;
-- 159 distinct (server, query) pairs, NaN root causes skipped.


/* ===== Active transactions @ 181.214.214.98 ===== */
SELECT     s.session_id        AS session_id,     s.login_name        AS login_name,     s.host_name         AS host_name,     DB_NAME(s.database_id) AS database_name,     r.status            AS status,     r.start_time        AS start_time,     r.command           AS command,     r.cpu_time          AS cpu_time,     r.total_elapsed_time AS total_elapsed_time,     at.transaction_id   AS transaction_id,     at.name             AS transaction_name,     LEFT(REPLACE(REPLACE(REPLACE(t.text, NCHAR(0), N''), CHAR(13), N' '), CHAR(10), N' '), 4000) AS query_text FROM sys.dm_exec_sessions s JOIN sys.dm_exec_requests r              ON r.session_id = s.session_id JOIN sys.dm_tran_session_transactions st ON st.session_id = s.session_id JOIN sys.dm_tran_active_transactions at  ON at.transaction_id = st.transaction_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS t WHERE s.is_user_process = 1   AND t.text IS NOT NULL
GO

/* ===== SEC-SQL-AZ-004-RC07 @ 181.214.214.98 ===== */
SELECT name, value_in_use, description FROM sys.configurations WHERE name IN ('clr enabled','cross db ownership chaining','Database Mail XPs','Ole Automation Procedures','xp_cmdshell','Ad Hoc Distributed Queries','remote access','remote admin connections','scan for startup procs') ORDER BY name
GO

/* ===== SEC-SQL-AZ-004-RC07 @ 181.214.214.98 ===== */
SELECT o.name AS object_name,
  o.type_desc,
  s.name AS schema_name,
  o.create_date,
  o.modify_date,
  CASE WHEN OBJECT_DEFINITION(o.object_id) LIKE '%xp_cmdshell%' THEN 'REFERENCES_CMDSHELL'
    WHEN OBJECT_DEFINITION(o.object_id) LIKE '%sp_configure%' THEN 'REFERENCES_SP_CONFIGURE'
    ELSE 'INDIRECT' END AS reference_type
FROM sys.objects o
JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE o.is_ms_shipped = 0
  AND o.type IN ('P', 'TR', 'FN', 'IF', 'TF')
  AND (OBJECT_DEFINITION(o.object_id) LIKE '%xp_cmdshell%'
    OR OBJECT_DEFINITION(o.object_id) LIKE '%sp_configure%xp_cmdshell%')
ORDER BY o.modify_date DESC
GO

/* ===== SEC-SQL-AZ-004-RC07 @ 181.214.214.98 ===== */
SELECT o.name AS proc_name,
  CASE
    WHEN OBJECT_DEFINITION(o.object_id) LIKE '%xp_cmdshell%dir %' OR
      OBJECT_DEFINITION(o.object_id) LIKE '%xp_cmdshell%copy %' OR
      OBJECT_DEFINITION(o.object_id) LIKE '%xp_cmdshell%del %' OR
      OBJECT_DEFINITION(o.object_id) LIKE '%xp_cmdshell%move %' THEN 'FILE_OPERATIONS'
    WHEN OBJECT_DEFINITION(o.object_id) LIKE '%xp_cmdshell%net %' OR
      OBJECT_DEFINITION(o.object_id) LIKE '%xp_cmdshell%ping %' OR
      OBJECT_DEFINITION(o.object_id) LIKE '%xp_cmdshell%nslookup%' THEN 'NETWORK_OPERATIONS'
    WHEN OBJECT_DEFINITION(o.object_id) LIKE '%xp_cmdshell%bcp %' THEN 'BCP_EXPORT'
    WHEN OBJECT_DEFINITION(o.object_id) LIKE '%xp_cmdshell%osql%' OR
      OBJECT_DEFINITION(o.object_id) LIKE '%xp_cmdshell%sqlcmd%' THEN 'SQL_EXEC'
    ELSE 'OTHER'
  END AS usage_pattern
FROM sys.objects o
WHERE o.type = 'P'
  AND o.is_ms_shipped = 0
  AND OBJECT_DEFINITION(o.object_id) LIKE '%xp_cmdshell%'
GO

/* ===== SEC-SQL-AZ-004-RC07 @ 181.214.214.98 ===== */
SELECT c.name, CAST(c.value AS INT) AS configured_value,
  CAST(c.value_in_use AS INT) AS runtime_value,
  CASE WHEN c.value <> c.value_in_use THEN 'CONFIG_DRIFT' ELSE 'CONSISTENT' END AS drift_status
FROM sys.configurations c
WHERE c.name IN ('xp_cmdshell', 'show advanced options')
GO

/* ===== SEC-SQL-AZ-004-RC07 @ 181.214.214.98 ===== */
SELECT c.name, CAST(c.value_in_use AS INT) AS enabled
FROM sys.configurations c
WHERE c.name IN ('xp_cmdshell', 'show advanced options')
ORDER BY c.name
GO

/* ===== SEC-SQL-AZ-004-RC07 @ 181.214.214.98 ===== */
SELECT name, CAST(value_in_use AS INT) AS is_enabled,
  description
FROM sys.configurations
WHERE name IN ('xp_cmdshell', 'Ole Automation Procedures', 'show advanced options')
GO

/* ===== SEC-SQL-AZ-004-RC07 @ 181.214.214.98 ===== */
SELECT 'Linked Servers with file access' AS check_type,
  s.name AS server_name, s.provider,
  s.data_source,
  CASE WHEN s.provider IN ('Microsoft.ACE.OLEDB.12.0', 'Microsoft.Jet.OLEDB.4.0', 'BULK', 'MSDASQL')
    THEN 'FILE_SYSTEM_PROVIDER' ELSE 'DATABASE_PROVIDER' END AS provider_type
FROM sys.servers s
WHERE s.is_linked = 1
  AND (s.provider IN ('Microsoft.ACE.OLEDB.12.0', 'Microsoft.Jet.OLEDB.4.0', 'BULK', 'MSDASQL')
    OR s.data_source LIKE '%.csv' OR s.data_source LIKE '%.xls%' OR s.data_source LIKE '%.txt')
UNION ALL
SELECT 'Ad Hoc Distributed Queries' AS check_type,
  CAST(c.value_in_use AS NVARCHAR(128)) AS server_name,
  'sys.configurations' AS provider,
  'Allows OPENROWSET/OPENDATASOURCE ad hoc access' AS data_source,
  CASE WHEN c.value_in_use = 1 THEN 'ENABLED' ELSE 'DISABLED' END AS provider_type
FROM sys.configurations c
WHERE c.name = 'Ad Hoc Distributed Queries'
GO

/* ===== SEC-SQL-AZ-004-RC07 @ 181.214.214.98 ===== */
SELECT dp.name AS principal_name, dp.type_desc,
  o.name AS procedure_name,
  p.permission_name, p.state_desc,
  IS_SRVROLEMEMBER('sysadmin', dp.name) AS is_sysadmin
FROM sys.server_permissions p
JOIN sys.server_principals dp ON p.grantee_principal_id = dp.principal_id
JOIN master.sys.objects o ON p.major_id = o.object_id
WHERE o.name IN ('xp_cmdshell', 'xp_fileexist', 'xp_subdirs', 'xp_dirtree', 'xp_fixeddrives', 'xp_create_subdir')
  AND p.permission_name = 'EXECUTE'
  AND p.state_desc IN ('GRANT', 'GRANT_WITH_GRANT_OPTION')
  AND dp.is_disabled = 0
  AND dp.name NOT LIKE '##%'
  AND IS_SRVROLEMEMBER('sysadmin', dp.name) = 0
GO

/* ===== SEC-SQL-AZ-004-RC07 @ 181.214.214.98 ===== */
SELECT dp.name AS principal_name, dp.type_desc,
  o.name AS procedure_name,
  p.permission_name, p.state_desc,
  c.value_in_use AS xp_cmdshell_enabled
FROM sys.server_permissions p
JOIN sys.server_principals dp ON p.grantee_principal_id = dp.principal_id
JOIN master.sys.objects o ON p.major_id = o.object_id
CROSS JOIN sys.configurations c
WHERE o.name IN ('xp_cmdshell', 'xp_fileexist', 'xp_subdirs', 'xp_dirtree', 'xp_fixeddrives')
  AND p.state_desc IN ('GRANT', 'GRANT_WITH_GRANT_OPTION')
  AND c.name = 'xp_cmdshell'
  AND dp.name NOT LIKE '##%'
  AND dp.is_disabled = 0
GO

/* ===== SEC-SQL-AZ-004-RC07 @ 181.214.214.98 ===== */
SELECT
  (SELECT COUNT(*) FROM sys.server_audit_specifications sas
   JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
   WHERE sas.is_state_enabled = 1
     AND sasd.audit_action_name = 'USER_DEFINED_AUDIT_GROUP') AS user_defined_audit,
  (SELECT COUNT(*) FROM sys.server_audit_specifications sas
   JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
   WHERE sas.is_state_enabled = 1
     AND sasd.audit_action_name = 'SCHEMA_OBJECT_ACCESS_GROUP') AS object_access_audit,
  (SELECT COUNT(*) FROM msdb.dbo.sysjobs j
   JOIN msdb.dbo.sysjobsteps js ON j.job_id = js.job_id
   WHERE js.command LIKE '%xp_cmdshell%'
     AND j.enabled = 1) AS jobs_using_cmdshell
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#sensitive_cols') IS NOT NULL DROP TABLE #sensitive_cols;
CREATE TABLE #sensitive_cols (
    db_name      sysname,
    schema_name  sysname,
    table_name   sysname,
    column_name  sysname,
    pii_category nvarchar(50)
);

DECLARE @sql nvarchar(max) = N'';
SELECT @sql = @sql + N'
USE ' + QUOTENAME(name) + N';
INSERT INTO #sensitive_cols (db_name, schema_name, table_name, column_name, pii_category)
SELECT DB_NAME(), s.name, t.name, c.name,
  CASE
    WHEN LOWER(c.name) LIKE ''%password%'' OR LOWER(c.name) LIKE ''%pass%'' THEN ''Password''
    WHEN LOWER(c.name) LIKE ''%secret%''   OR LOWER(c.name) LIKE ''%token%'' OR LOWER(c.name) LIKE ''%key%'' THEN ''Credential''
    WHEN LOWER(c.name) LIKE ''%credit%''   OR LOWER(c.name) LIKE ''%card%''  THEN ''Credit Card''
    WHEN LOWER(c.name) LIKE ''%ssn%''      THEN ''SSN''
    WHEN LOWER(c.name) LIKE ''%email%''    THEN ''Email''
    WHEN LOWER(c.name) LIKE ''%phone%''    THEN ''Phone''
    WHEN LOWER(c.name) LIKE ''%address%''  THEN ''Address''
    WHEN LOWER(c.name) LIKE ''%dob%''      OR LOWER(c.name) LIKE ''%birth%'' THEN ''Date of Birth''
    WHEN LOWER(c.name) LIKE ''%salary%''   THEN ''Salary''
    WHEN LOWER(c.name) LIKE ''%passport%'' THEN ''Passport''
    WHEN LOWER(c.name) LIKE ''%medical%''  OR LOWER(c.name) LIKE ''%diagnosis%'' THEN ''Medical''
    WHEN LOWER(c.name) LIKE ''%teudat%''   THEN ''Teudat Zehut''
    ELSE ''Other Sensitive''
  END
FROM sys.tables  t
JOIN sys.columns c ON c.object_id = t.object_id
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE t.is_ms_shipped = 0
  AND (LOWER(c.name) LIKE ''%password%'' OR LOWER(c.name) LIKE ''%pass%''
    OR LOWER(c.name) LIKE ''%secret%''   OR LOWER(c.name) LIKE ''%token%'' OR LOWER(c.name) LIKE ''%key%''
    OR LOWER(c.name) LIKE ''%credit%''   OR LOWER(c.name) LIKE ''%card%''
    OR LOWER(c.name) LIKE ''%ssn%''
    OR LOWER(c.name) LIKE ''%email%''
    OR LOWER(c.name) LIKE ''%phone%''
    OR LOWER(c.name) LIKE ''%address%''
    OR LOWER(c.name) LIKE ''%dob%''      OR LOWER(c.name) LIKE ''%birth%''
    OR LOWER(c.name) LIKE ''%salary%''
    OR LOWER(c.name) LIKE ''%passport%''
    OR LOWER(c.name) LIKE ''%medical%''  OR LOWER(c.name) LIKE ''%diagnosis%''
    OR LOWER(c.name) LIKE ''%teudat%'');
'
FROM sys.databases
WHERE state = 0
  AND database_id > 4
  AND HAS_DBACCESS(name) = 1
  AND name NOT IN ('distribution', 'ReportServer', 'ReportServerTempDB', 'SSISDB');

EXEC sp_executesql @sql;

SELECT top 100 'cached_plan'         AS source,
       CAST(NULL AS INT)     AS session_id,
       CAST(NULL AS BIGINT)  AS transaction_id,
       qs.execution_count,
       qs.last_execution_time,
       qs.total_logical_reads / NULLIF(qs.execution_count, 0)         AS avg_reads,
       qs.total_worker_time / NULLIF(qs.execution_count, 0) / 1000    AS avg_cpu_ms,
       CAST(NULL AS DATETIME) AS transaction_begin_time,
       sc.db_name, sc.schema_name, sc.table_name, sc.column_name, sc.pii_category,
       LEFT(t.text, 4000)    AS query_text
FROM sys.dm_exec_query_stats AS qs WITH (NOLOCK)
CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) AS t
JOIN #sensitive_cols sc ON t.text LIKE '%' + sc.table_name + '%'
WHERE t.text IS NOT NULL
  AND LEFT(t.text, 4000) NOT LIKE '%tempdb..#sensitive_cols%'
UNION ALL
SELECT 'active_transaction'  AS source,
       ses.session_id,
       tat.transaction_id,
       CAST(NULL AS BIGINT)  AS execution_count,
       CAST(NULL AS DATETIME) AS last_execution_time,
       CAST(NULL AS BIGINT)  AS avg_reads,
       CAST(NULL AS BIGINT)  AS avg_cpu_ms,
       tat.transaction_begin_time,
       sc.db_name, sc.schema_name, sc.table_name, sc.column_name, sc.pii_category,
       LEFT(t.text, 4000)    AS query_text
FROM sys.dm_tran_active_transactions    tat
JOIN sys.dm_tran_session_transactions   sts ON sts.transaction_id = tat.transaction_id
JOIN sys.dm_exec_sessions               ses ON ses.session_id     = sts.session_id
JOIN sys.dm_exec_connections            con
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT
      s.session_id,
      s.login_name,
      s.host_name,
      r.status,
      r.start_time,
      r.command,
      r.cpu_time,
      r.total_elapsed_time,
      at.transaction_id,
      at.name AS transaction_name,
      LEFT(REPLACE(REPLACE(REPLACE(t.text, NCHAR(0), N''), CHAR(13), N' '), CHAR(10), N' '), 4000) AS query_text
  FROM sys.dm_exec_sessions s
  JOIN sys.dm_exec_requests r              ON r.session_id = s.session_id
  JOIN sys.dm_tran_session_transactions st ON st.session_id = s.session_id
  JOIN sys.dm_tran_active_transactions at  ON at.transaction_id = st.transaction_id
  CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
  WHERE s.is_user_process = 1
    AND t.text IS NOT NULL;
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT name, state_desc, user_access_desc, is_read_only,
  is_in_standby, recovery_model_desc
FROM sys.databases
WHERE state_desc <> 'ONLINE'
  OR user_access_desc = 'SINGLE_USER'
  OR is_in_standby = 1
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT TOP 10
  qs.query_hash,
  qs.total_rows / NULLIF(qs.execution_count, 0) AS avg_rows,
  qs.total_logical_reads / NULLIF(qs.execution_count, 0) AS avg_reads,
  qs.total_elapsed_time / NULLIF(qs.execution_count, 0) / 1000 AS avg_elapsed_ms,
  qs.total_spills / NULLIF(qs.execution_count, 0) AS avg_spills,
  qs.total_grant_kb / NULLIF(qs.execution_count, 0) AS avg_grant_kb,
  p.query_plan.value('count(//RelOp[@LogicalOp="Cross Join" or @LogicalOp="Inner Join"])', 'int') AS join_count,
  SUBSTRING(t.text, 1, 400) AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) t
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) p
WHERE qs.total_rows / NULLIF(qs.execution_count, 0) > 1000000
  AND qs.total_logical_reads / NULLIF(qs.execution_count, 0) > 100000
ORDER BY qs.total_rows DESC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT sp.name, sp.type_desc, sp.create_date,
  DATEDIFF(DAY, sp.modify_date, GETDATE()) AS days_since_modified,
  (SELECT MAX(login_time) FROM sys.dm_exec_sessions WHERE login_name = sp.name) AS last_session,
  IS_SRVROLEMEMBER('sysadmin', sp.name) AS is_sysadmin,
  (SELECT STRING_AGG(dp.name + ':' + r.name, ', ')
   FROM sys.database_principals dp
   CROSS APPLY (SELECT r.name FROM sys.database_role_members rm
     JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
     WHERE rm.member_principal_id = dp.principal_id) r
   WHERE dp.sid = sp.sid) AS db_roles
FROM sys.server_principals sp
WHERE sp.type IN ('S', 'U')
  AND sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
  AND sp.name NOT LIKE 'NT %'
  AND sp.name <> 'sa'
  AND (SELECT MAX(login_time) FROM sys.dm_exec_sessions WHERE login_name = sp.name) IS NULL
  AND DATEDIFF(DAY, sp.modify_date, GETDATE()) > 180
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT t.transaction_id, t.name AS tran_name, t.transaction_begin_time, DATEDIFF(SECOND, t.transaction_begin_time, GETDATE()) AS duration_sec, s.session_id, s.login_name, s.host_name, s.program_name, s.status AS session_status, r.command, r.wait_type, r.blocking_session_id FROM sys.dm_tran_active_transactions t JOIN sys.dm_tran_session_transactions tst ON t.transaction_id = tst.transaction_id JOIN sys.dm_exec_sessions s ON tst.session_id = s.session_id LEFT JOIN sys.dm_exec_requests r ON s.session_id = r.session_id WHERE t.transaction_begin_time < DATEADD(MINUTE, -5, GETDATE()) ORDER BY t.transaction_begin_time
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT TOP 20
  qs.query_hash,
  qs.execution_count,
  qs.total_logical_reads / NULLIF(qs.execution_count, 0) AS avg_reads,
  qs.total_elapsed_time / NULLIF(qs.execution_count, 0) / 1000 AS avg_elapsed_ms,
  p.query_plan.exist('//Warnings/PlanAffectingConvert') AS has_convert_warning,
  p.query_plan.value('count(//ScalarOperator[contains(@ScalarString,"CONVERT_IMPLICIT")])', 'int') AS implicit_converts,
  p.query_plan.value('count(//RelOp[@PhysicalOp="Table Scan" or @PhysicalOp="Clustered Index Scan" or @PhysicalOp="Index Scan"])', 'int') AS total_scans,
  SUBSTRING(t.text, 1, 500) AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) t
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) p
WHERE t.text LIKE '%JOIN%'
  AND p.query_plan.exist('//Warnings/PlanAffectingConvert') = 1
  AND qs.total_logical_reads / NULLIF(qs.execution_count, 0) > 5000
  AND qs.execution_count > 5
ORDER BY qs.total_logical_reads DESC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT TOP 15
  qs.sql_handle,
  qs.total_logical_reads / NULLIF(qs.execution_count, 0) AS avg_reads,
  qs.total_worker_time / NULLIF(qs.execution_count, 0) / 1000 AS avg_cpu_ms,
  p.query_plan.value('count(//RelOp[@PhysicalOp="Index Scan"])', 'int') AS index_scans,
  p.query_plan.value('count(//RelOp[@PhysicalOp="Clustered Index Scan"])', 'int') AS ci_scans,
  p.query_plan.value('(//Warnings/PlanAffectingConvert/@ConvertIssue)[1]', 'nvarchar(100)') AS convert_issue,
  t.text AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) t
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) p
WHERE p.query_plan.exist('//Warnings/PlanAffectingConvert') = 1
  AND (p.query_plan.value('count(//RelOp[@PhysicalOp="Index Scan"])', 'int') > 0
    OR p.query_plan.value('count(//RelOp[@PhysicalOp="Clustered Index Scan"])', 'int') > 0)
  AND qs.execution_count > 10
ORDER BY avg_reads DESC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT TOP 15
  qs.sql_handle,
  qs.total_logical_reads / NULLIF(qs.execution_count, 0) AS avg_reads,
  qs.total_elapsed_time / NULLIF(qs.execution_count, 0) / 1000 AS avg_elapsed_ms,
  qs.execution_count,
  p.query_plan.value('count(//ScalarOperator[contains(@ScalarString,"CONVERT_IMPLICIT") and (contains(@ScalarString,"bit") or contains(@ScalarString,"tinyint"))])', 'int') AS flag_converts,
  p.query_plan.value('count(//Warnings/PlanAffectingConvert)', 'int') AS convert_warnings,
  t.text AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) t
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) p
WHERE p.query_plan.exist('//ScalarOperator[contains(@ScalarString,"CONVERT_IMPLICIT") and (contains(@ScalarString,"bit") or contains(@ScalarString,"tinyint"))]') = 1
  AND qs.execution_count > 10
ORDER BY qs.total_logical_reads DESC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT
  OBJECT_SCHEMA_NAME(ic.object_id) AS schema_name,
  OBJECT_NAME(ic.object_id) AS table_name,
  COL_NAME(ic.object_id, ic.column_id) AS column_name,
  i.name AS index_name,
  i.type_desc AS index_type,
  ic.key_ordinal
FROM sys.index_columns ic
JOIN sys.indexes i ON ic.object_id = i.object_id AND ic.index_id = i.index_id
WHERE i.type > 0
  AND (
    COL_NAME(ic.object_id, ic.column_id) LIKE '%ssn%'
    OR COL_NAME(ic.object_id, ic.column_id) LIKE '%social_security%'
    OR COL_NAME(ic.object_id, ic.column_id) LIKE '%credit_card%'
    OR COL_NAME(ic.object_id, ic.column_id) LIKE '%card_number%'
    OR COL_NAME(ic.object_id, ic.column_id) LIKE '%tax_id%'
    OR COL_NAME(ic.object_id, ic.column_id) LIKE '%passport%'
    OR COL_NAME(ic.object_id, ic.column_id) LIKE '%email%'
    OR COL_NAME(ic.object_id, ic.column_id) LIKE '%phone%'
    OR COL_NAME(ic.object_id, ic.column_id) LIKE '%national_id%'
  )
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT name, is_policy_checked, is_expiration_checked
FROM sys.sql_logins
WHERE is_policy_checked = 0
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT
  CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) AS current_major,
  16 AS latest_major_version,
  16 - CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) AS versions_behind,
  SERVERPROPERTY('ProductVersion') AS product_version,
  SERVERPROPERTY('ProductLevel') AS product_level,
  SERVERPROPERTY('ProductUpdateLevel') AS cumulative_update
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT
  (SELECT cntr_value FROM sys.dm_os_performance_counters
   WHERE counter_name = 'Temp Tables Creation Rate' AND instance_name = '') AS temp_table_rate,
  (SELECT COUNT(*) FROM tempdb.sys.objects WHERE type IN ('U', 'TT') AND is_ms_shipped = 0) AS current_temp_objects,
  (SELECT SUM(user_object_reserved_page_count) * 8 / 1024 FROM sys.dm_db_file_space_usage) AS user_objects_mb_in_tempdb
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT
der.session_id session_id,
der.blocking_session_id blocking_session_id,
DATEDIFF(second, der.start_time, GETDATE()) AS duration_secs,
DB_NAME(der.database_id) AS database_name,
der.start_time ,
ses.last_request_end_time,
ses.open_transaction_count,
ses.cpu_time,
der.command,
der.logical_reads,
der.reads,
der.writes,
der.wait_type,
der.last_wait_type,
ses.login_name,
ses.program_name AS program_name,
ses.host_name,
t.text query
FROM sys.dm_exec_requests der
INNER JOIN sys.dm_exec_sessions ses ON der.session_id = ses.session_id
CROSS APPLY sys.dm_exec_sql_text(der.sql_handle) t
CROSS APPLY sys.dm_exec_query_plan(der.plan_handle) cp
WHERE blocking_session_id >0
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
;WITH BlockingHierarchy AS (
    -- Anchor: get all sessions that are being blocked
    SELECT
        der.session_id,
        der.blocking_session_id
    FROM sys.dm_exec_requests der
    WHERE der.blocking_session_id > 0

    UNION ALL

    -- Recursive part: follow the chain upwards
    SELECT
        bh.session_id,
        der.blocking_session_id
    FROM BlockingHierarchy bh
    JOIN sys.dm_exec_requests der
        ON bh.blocking_session_id = der.session_id
    WHERE der.blocking_session_id > 0
)
, RootBlocker AS (
    SELECT
        bh.session_id,
        -- The topmost blocker is the last blocking_session_id that doesn't appear as a session_id
        COALESCE(MAX(der.blocking_session_id), bh.blocking_session_id) AS possible_root
    FROM BlockingHierarchy bh
    LEFT JOIN sys.dm_exec_requests der
        ON bh.blocking_session_id = der.session_id
    GROUP BY bh.session_id, bh.blocking_session_id
)
SELECT
    der.session_id,
    der.blocking_session_id,
    rb.possible_root AS root_blocker_id,
    DATEDIFF(second, der.start_time, GETDATE()) AS duration_secs,
    DB_NAME(der.database_id) AS database_name,
    der.start_time,
    ses.last_request_end_time,
    ses.open_transaction_count,
    ses.cpu_time,
    der.command,
    der.logical_reads,
    der.reads,
    der.writes,
    der.wait_type,
    der.last_wait_type,
    ses.login_name,
    ses.program_name,
    ses.host_name,
    t.text AS query_text
FROM sys.dm_exec_requests der
INNER JOIN sys.dm_exec_sessions ses ON der.session_id = ses.session_id
LEFT JOIN RootBlocker rb ON der.session_id = rb.session_id
CROSS APPLY sys.dm_exec_sql_text(der.sql_handle) t
CROSS APPLY sys.dm_exec_query_plan(der.plan_handle) cp
WHERE blocking_session_id > 0
ORDER BY COALESCE(rb.possible_root, der.blocking_session_id, der.session_id);
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT 
    pr.name AS grantee,
    o.name AS object_name,
    p.permission_name
FROM sys.database_permissions p
JOIN sys.objects o ON p.major_id = o.object_id
JOIN sys.database_principals pr ON p.grantee_principal_id = pr.principal_id
WHERE pr.name = 'public'
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT login_name, COUNT(*) AS connection_count
FROM sys.dm_exec_sessions
WHERE is_user_process = 1
GROUP BY login_name
ORDER BY connection_count DESC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT
    s.session_id        AS session_id,
    s.login_name        AS login_name,
    s.host_name         AS host_name,
    DB_NAME(s.database_id) AS database_name,
    r.status            AS status,
    r.start_time        AS start_time,
    r.command           AS command,
    r.cpu_time          AS cpu_time,
    r.total_elapsed_time AS total_elapsed_time,
    at.transaction_id   AS transaction_id,
    at.name             AS transaction_name,
    LEFT(REPLACE(REPLACE(REPLACE(t.text, NCHAR(0), N''), CHAR(13), N' '), CHAR(10), N' '), 4000) AS query_text
FROM sys.dm_exec_sessions s
JOIN sys.dm_exec_requests r              ON r.session_id = s.session_id
JOIN sys.dm_tran_session_transactions st ON st.session_id = s.session_id
JOIN sys.dm_tran_active_transactions at  ON at.transaction_id = st.transaction_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE s.is_user_process = 1
  AND t.text IS NOT NULL
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT
    s.session_id,
    s.login_name,
    s.host_name,
    r.status,
    r.start_time,
    r.command,
    r.cpu_time,
    r.blocking_session_id,
    r.total_elapsed_time,
    transaction_id    
FROM sys.dm_exec_sessions s
JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT j.name AS job_name, h.step_id, h.step_name,
  h.run_date, h.run_time,
  SUBSTRING(h.message, 1, 500) AS error_message
FROM msdb.dbo.sysjobhistory h
JOIN msdb.dbo.sysjobs j ON h.job_id = j.job_id
WHERE h.run_status = 0
  AND h.run_date >= CONVERT(int, CONVERT(varchar(8), DATEADD(day, -7, GETDATE()), 112))
  AND (h.message LIKE '%CHECK constraint%'
    OR h.message LIKE '%conflicted with the CHECK%'
    OR h.message LIKE '%validation%fail%'
    OR h.message LIKE '%RAISERROR%'
    OR h.message LIKE '%is not valid%'
    OR h.message LIKE '%rejected%'
    OR h.message LIKE '%data validation%'
    OR h.message LIKE '%business rule%'
    OR h.message LIKE '%trigger%'
    OR h.message LIKE '%INSTEAD OF%')
ORDER BY h.run_date DESC, h.run_time DESC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT eventclass, CASE eventclass WHEN 92 THEN 'Data Auto Grow' WHEN 93 THEN 'Log Auto Grow' WHEN 94 THEN 'Data Auto Shrink' WHEN 95 THEN 'Log Auto Shrink' END AS event_type, COUNT(*) AS event_count FROM sys.fn_trace_gettable((SELECT path FROM sys.traces WHERE is_default = 1), DEFAULT) WHERE eventclass IN (92, 93, 94, 95) AND databaseid = 2 GROUP BY eventclass ORDER BY eventclass
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
WITH ranked AS (
  SELECT database_name, backup_size, compressed_backup_size, backup_finish_date,
    LAG(COALESCE(compressed_backup_size, backup_size)) OVER (PARTITION BY database_name ORDER BY backup_finish_date) AS prev_size
  FROM msdb.dbo.backupset
  WHERE type = 'D' AND backup_finish_date > DATEADD(day, -30, GETDATE())
)
SELECT database_name, backup_finish_date,
  COALESCE(compressed_backup_size, backup_size) AS current_size, prev_size,
  CAST(100.0 * (prev_size - COALESCE(compressed_backup_size, backup_size)) / NULLIF(prev_size, 0) AS decimal(5,1)) AS pct_drop
FROM ranked
WHERE prev_size > 0 AND COALESCE(compressed_backup_size, backup_size) < prev_size * 0.5
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT r.session_id, s.login_name, s.host_name, s.program_name, DB_NAME(r.database_id) AS database_name, sch.name AS schema_name, t.name AS table_name, c.name AS column_name, CASE WHEN LOWER(c.name) LIKE '%password%' OR LOWER(c.name) LIKE '%pass%' THEN 'Password' WHEN LOWER(c.name) LIKE '%secret%' OR LOWER(c.name) LIKE '%token%' OR LOWER(c.name) LIKE '%key%' THEN 'Credential' WHEN LOWER(c.name) LIKE '%credit%' OR LOWER(c.name) LIKE '%card%' THEN 'Credit Card' WHEN LOWER(c.name) LIKE '%ssn%' THEN 'SSN' WHEN LOWER(c.name) LIKE '%email%' THEN 'Email' WHEN LOWER(c.name) LIKE '%phone%' THEN 'Phone' WHEN LOWER(c.name) LIKE '%address%' THEN 'Address' WHEN LOWER(c.name) LIKE '%dob%' OR LOWER(c.name) LIKE '%birth%' THEN 'Date of Birth' WHEN LOWER(c.name) LIKE '%salary%' THEN 'Salary' ELSE 'Other Sensitive' END AS pii_category, LEFT(st.text, 4000) AS query_text, r.start_time, r.status FROM sys.dm_exec_requests r CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st JOIN sys.dm_exec_sessions s ON s.session_id = r.session_id JOIN sys.tables t ON t.is_ms_shipped = 0 JOIN sys.columns c ON c.object_id = t.object_id JOIN sys.schemas sch ON sch.schema_id = t.schema_id WHERE s.is_user_process = 1 AND r.session_id <> @@SPID AND st.text LIKE '%' + t.name + '%' AND (LOWER(c.name) LIKE '%password%' OR LOWER(c.name) LIKE '%pass%' OR LOWER(c.name) LIKE '%secret%' OR LOWER(c.name) LIKE '%token%' OR LOWER(c.name) LIKE '%key%' OR LOWER(c.name) LIKE '%credit%' OR LOWER(c.name) LIKE '%card%' OR LOWER(c.name) LIKE '%ssn%' OR LOWER(c.name) LIKE '%email%' OR LOWER(c.name) LIKE '%phone%' OR LOWER(c.name) LIKE '%address%' OR LOWER(c.name) LIKE '%dob%' OR LOWER(c.name) LIKE '%birth%' OR LOWER(c.name) LIKE '%salary%') ORDER BY r.session_id, t.name, c.name
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#sensitive_cols') IS NOT NULL DROP TABLE #sensitive_cols;
CREATE TABLE #sensitive_cols (
    db_name      sysname,
    schema_name  sysname,
    table_name   sysname,
    column_name  sysname,
    data_type    sysname,
    max_length   smallint,
    pii_category nvarchar(50)
);

DECLARE @sql nvarchar(max) = N'';
SELECT @sql = @sql + N'
USE ' + QUOTENAME(name) + N';
INSERT INTO #sensitive_cols (db_name, schema_name, table_name, column_name, data_type, max_length, pii_category)
SELECT DB_NAME(), s.name, t.name, c.name, ty.name, c.max_length,
  CASE
    WHEN c.name LIKE ''%ssn%''         OR c.name LIKE ''%social_security%''                                                                                                THEN ''SSN''
    WHEN c.name LIKE ''%credit_card%'' OR c.name LIKE ''%card_number%'' OR c.name LIKE ''%cvv%'' OR c.name LIKE ''%cvc%'' OR c.name LIKE ''%card_num%''                     THEN ''Credit Card''
    WHEN c.name LIKE ''%password%''    OR c.name LIKE ''%passwd%''      OR c.name LIKE ''%secret%'' OR c.name LIKE ''%api_key%'' OR c.name LIKE ''%apikey%''                THEN ''Credential''
    WHEN c.name LIKE ''%email%''       OR c.name LIKE ''%e_mail%''                                                                                                         THEN ''Email''
    WHEN c.name LIKE ''%phone%''       OR c.name LIKE ''%mobile%''      OR c.name LIKE ''%cell%''                                                                          THEN ''Phone''
    WHEN c.name LIKE ''%birth%''       OR c.name LIKE ''%dob%''         OR c.name LIKE ''%date_of_birth%''                                                                 THEN ''Date of Birth''
    WHEN c.name LIKE ''%salary%''      OR c.name LIKE ''%income%''      OR c.name LIKE ''%wage%''                                                                          THEN ''Financial''
    WHEN c.name LIKE ''%bank_account%'' OR c.name LIKE ''%iban%''       OR c.name LIKE ''%routing%''                                                                       THEN ''Bank Account''
    WHEN c.name LIKE ''%national_id%'' OR c.name LIKE ''%passport%''    OR c.name LIKE ''%driver_license%'' OR c.name LIKE ''%tax_id%'' OR c.name LIKE ''%id_number%''      THEN ''Government ID''
    WHEN c.name LIKE ''%medical%''     OR c.name LIKE ''%diagnosis%''   OR c.name LIKE ''%health%''                                                                        THEN ''Medical''
    WHEN c.name LIKE ''%ip_address%''  OR c.name LIKE ''%mac_address%'' OR c.name LIKE ''%biometric%''                                                                     THEN ''Technical PII''
    ELSE ''Other Sensitive''
  END
FROM sys.columns c
JOIN sys.tables  t  ON t.object_id     = c.object_id
JOIN sys.schemas s  ON s.schema_id     = t.schema_id
JOIN sys.types   ty ON ty.user_type_id = c.user_type_id
WHERE t.is_ms_shipped = 0
  AND (c.name LIKE ''%ssn%''         OR c.name LIKE ''%social_security%''
    OR c.name LIKE ''%credit_card%'' OR c.name LIKE ''%card_number%''  OR c.name LIKE ''%cvv%''   OR c.name LIKE ''%cvc%''
    OR c.name LIKE ''%password%''    OR c.name LIKE ''%passwd%''       OR c.name LIKE ''%secret%'' OR c.name LIKE ''%api_key%''
    OR c.name LIKE ''%email%''
    OR c.name LIKE ''%phone%''       OR c.name LIKE ''%mobile%''
    OR c.name LIKE ''%birth%''       OR c.name LIKE ''%dob%''
    OR c.name LIKE ''%salary%''      OR c.name LIKE ''%income%''
    OR c.name LIKE ''%bank_account%'' OR c.name LIKE ''%iban%''
    OR c.name LIKE ''%national_id%'' OR c.name LIKE ''%passport%''     OR c.name LIKE ''%driver_license%'' OR c.name LIKE ''%tax_id%''
    OR c.name LIKE ''%medical%''     OR c.name LIKE ''%diagnosis%''
    OR c.name LIKE ''%ip_address%''  OR c.name LIKE ''%biometric%'');
'
FROM sys.databases
WHERE state = 0
  AND database_id > 4
  AND HAS_DBACCESS(name) = 1
  AND name NOT IN ('distribution', 'ReportServer', 'ReportServerTempDB', 'SSISDB');

EXEC sp_execu
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#sensitive_cols') IS NOT NULL DROP TABLE #sensitive_cols;
CREATE TABLE #sensitive_cols (
    db_name      sysname,
    schema_name  sysname,
    table_name   sysname,
    column_name  sysname,
    pii_category nvarchar(50)
);

DECLARE @sql nvarchar(max) = N'';
SELECT @sql = @sql + N'
USE ' + QUOTENAME(name) + N';
INSERT INTO #sensitive_cols (db_name, schema_name, table_name, column_name, pii_category)
SELECT DB_NAME(), s.name, t.name, c.name,
  CASE
    WHEN LOWER(c.name) LIKE ''%password%'' OR LOWER(c.name) LIKE ''%pass%'' THEN ''Password''
    WHEN LOWER(c.name) LIKE ''%secret%''   OR LOWER(c.name) LIKE ''%token%'' OR LOWER(c.name) LIKE ''%key%'' THEN ''Credential''
    WHEN LOWER(c.name) LIKE ''%credit%''   OR LOWER(c.name) LIKE ''%card%''  THEN ''Credit Card''
    WHEN LOWER(c.name) LIKE ''%ssn%''      THEN ''SSN''
    WHEN LOWER(c.name) LIKE ''%email%''    THEN ''Email''
    WHEN LOWER(c.name) LIKE ''%phone%''    THEN ''Phone''
    WHEN LOWER(c.name) LIKE ''%address%''  THEN ''Address''
    WHEN LOWER(c.name) LIKE ''%dob%''      OR LOWER(c.name) LIKE ''%birth%'' THEN ''Date of Birth''
    WHEN LOWER(c.name) LIKE ''%salary%''   THEN ''Salary''
    WHEN LOWER(c.name) LIKE ''%passport%'' THEN ''Passport''
    WHEN LOWER(c.name) LIKE ''%medical%''  OR LOWER(c.name) LIKE ''%diagnosis%'' THEN ''Medical''
    WHEN LOWER(c.name) LIKE ''%teudat%''   THEN ''Teudat Zehut''
    ELSE ''Other Sensitive''
  END
FROM sys.tables  t
JOIN sys.columns c ON c.object_id = t.object_id
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE t.is_ms_shipped = 0
  AND (LOWER(c.name) LIKE ''%password%'' OR LOWER(c.name) LIKE ''%pass%''
    OR LOWER(c.name) LIKE ''%secret%''   OR LOWER(c.name) LIKE ''%token%'' OR LOWER(c.name) LIKE ''%key%''
    OR LOWER(c.name) LIKE ''%credit%''   OR LOWER(c.name) LIKE ''%card%''
    OR LOWER(c.name) LIKE ''%ssn%''
    OR LOWER(c.name) LIKE ''%email%''
    OR LOWER(c.name) LIKE ''%phone%''
    OR LOWER(c.name) LIKE ''%address%''
    OR LOWER(c.name) LIKE ''%dob%''      OR LOWER(c.name) LIKE ''%birth%''
    OR LOWER(c.name) LIKE ''%salary%''
    OR LOWER(c.name) LIKE ''%passport%''
    OR LOWER(c.name) LIKE ''%medical%''  OR LOWER(c.name) LIKE ''%diagnosis%''
    OR LOWER(c.name) LIKE ''%teudat%'');
'
FROM sys.databases
WHERE state = 0
  AND database_id > 4
  AND HAS_DBACCESS(name) = 1
  AND name NOT IN ('distribution', 'ReportServer', 'ReportServerTempDB', 'SSISDB');

EXEC sp_executesql @sql;

SELECT top 100 'cached_plan'         AS source,
       CAST(NULL AS INT)     AS session_id,
       CAST(NULL AS BIGINT)  AS transaction_id,
       qs.execution_count,
       qs.last_execution_time,
       qs.total_logical_reads / NULLIF(qs.execution_count, 0)         AS avg_reads,
       qs.total_worker_time / NULLIF(qs.execution_count, 0) / 1000    AS avg_cpu_ms,
       CAST(NULL AS DATETIME) AS transaction_begin_time,
       sc.db_name, sc.schema_name, sc.table_name, sc.column_name, sc.pii_category,
       LEFT(t.text, 4000)    AS query_text,
       CAST(NULL AS sysname) AS login_name
FROM sys.dm_exec_query_stats AS qs WITH (NOLOCK)
CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) AS t
JOIN #sensitive_cols sc ON t.text LIKE '%' + sc.table_name + '%'
WHERE t.text IS NOT NULL
  AND LEFT(t.text, 4000) NOT LIKE '%tempdb..#sensitive_cols%'
UNION ALL
SELECT 'active_transaction'  AS source,
       ses.session_id,
       tat.transaction_id,
       CAST(NULL AS BIGINT)  AS execution_count,
       CAST(NULL AS DATETIME) AS last_execution_time,
       CAST(NULL AS BIGINT)  AS avg_reads,
       CAST(NULL AS BIGINT)  AS avg_cpu_ms,
       tat.transaction_begin_time,
       sc.db_name, sc.schema_name, sc.table_name, sc.column_name, sc.pii_category,
       LEFT(t.text, 4000)    AS query_text,
       ses.login_name AS login_name
FROM sys.dm_tran_active_transactions    tat
JOIN sys.dm_tran_session_transactions   sts ON sts.transaction_id = tat.transaction_id
JOIN sys.dm_exec_sessions               ses ON
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
CREATE TABLE #log(LogDate DATETIME, ProcessInfo NVARCHAR(50), Text NVARCHAR(MAX)); INSERT INTO #log EXEC xp_readerrorlog 0, 1, N'read-only'; INSERT INTO #log EXEC xp_readerrorlog 0, 1, N'Failed to update database'; INSERT INTO #log EXEC xp_readerrorlog 0, 1, N'not allowed because the database is in read-only'; SELECT * FROM #log ORDER BY LogDate DESC; DROP TABLE #log;
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
EXEC sp_readerrorlog 0, 1, N'connection timeout'
EXEC sp_readerrorlog 0, 1, N'transport error'
EXEC sp_readerrorlog 0, 1, N'session timeout'
EXEC sp_readerrorlog 0, 1, N'lease has expired'
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
CREATE TABLE #log(LogDate DATETIME, ProcessInfo NVARCHAR(50), Text NVARCHAR(MAX)); INSERT INTO #log EXEC xp_readerrorlog 0, 1, N'3960'; INSERT INTO #log EXEC xp_readerrorlog 0, 1, N'3961'; INSERT INTO #log EXEC xp_readerrorlog 0, 1, N'Snapshot isolation transaction aborted'; INSERT INTO #log EXEC xp_readerrorlog 0, 1, N'update conflict'; SELECT * FROM #log ORDER BY LogDate DESC; DROP TABLE #log;
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT a.name AS assembly_name,
  a.permission_set_desc,
  a.clr_name,
  a.create_date,
  CASE WHEN EXISTS (
    SELECT 1 FROM sys.assembly_files af
    WHERE af.assembly_id = a.assembly_id AND af.file_id > 1)
    THEN 'HAS_ADDITIONAL_FILES' ELSE 'SINGLE_FILE' END AS file_status,
  d.is_trustworthy_on,
  (SELECT value_in_use FROM sys.configurations WHERE name = 'clr strict security') AS clr_strict_security
FROM sys.assemblies a
CROSS JOIN sys.databases d
WHERE a.is_user_defined = 1
  AND d.database_id = DB_ID()
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT 
    r.destination_database_name,
    r.user_name,
    r.restore_date,
    b.backup_start_date,
    b.backup_finish_date,
    b.database_name AS source_database_name,
    mf.physical_device_name AS backup_file
FROM msdb.dbo.restorehistory r
LEFT JOIN msdb.dbo.backupset b 
    ON r.backup_set_id = b.backup_set_id
LEFT JOIN msdb.dbo.backupmediafamily mf
    ON b.media_set_id = mf.media_set_id
where     b.backup_finish_date > dateadd(day , -1 , getdate())
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT OBJECT_SCHEMA_NAME(m.object_id) AS schema_name,
  OBJECT_NAME(m.object_id) AS proc_name,
  CASE WHEN m.definition LIKE '%EXEC(%+%@%' OR m.definition LIKE '%EXEC(@%'
    OR m.definition LIKE '%EXEC (@%' THEN 1 ELSE 0 END AS has_exec_concat,
  CASE WHEN m.definition LIKE '%sp_executesql%' THEN 1 ELSE 0 END AS has_sp_executesql
FROM sys.sql_modules m
JOIN sys.objects o ON m.object_id = o.object_id
WHERE o.type = 'P'
  AND (m.definition LIKE '%EXEC(%' OR m.definition LIKE '%EXECUTE(%'
    OR m.definition LIKE '%sp_executesql%')
  AND (m.definition LIKE '%SELECT %FROM %' COLLATE Latin1_General_BIN
    OR m.definition LIKE '%INSERT %INTO %' COLLATE Latin1_General_BIN
    OR m.definition LIKE '%UPDATE %SET %' COLLATE Latin1_General_BIN
    OR m.definition LIKE '%DELETE %FROM %' COLLATE Latin1_General_BIN)
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
xp_readerrorlog
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT
    @@SERVERNAME AS server,
    s.session_id,
    s.login_name,
    s.host_name,
    s.program_name,
    DB_NAME(s.database_id) AS database_name,
    t.transaction_id,
    tat.transaction_begin_time,
    DATEDIFF(SECOND, tat.transaction_begin_time, GETDATE()) AS duration_seconds,
    tat.transaction_state,
    SUBSTRING(st.text, 1, 4000) AS query_text
FROM sys.dm_tran_active_transactions tat
JOIN sys.dm_tran_session_transactions t ON t.transaction_id = tat.transaction_id
JOIN sys.dm_exec_sessions s ON s.session_id = t.session_id
LEFT JOIN sys.dm_exec_connections c ON c.session_id = s.session_id
OUTER APPLY sys.dm_exec_sql_text(c.most_recent_sql_handle) st
WHERE s.is_user_process = 1
  AND s.login_name NOT IN ('dbd_mon_usr','dbdome_mon_usr')
ORDER BY tat.transaction_begin_time
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT sp.name, sp.is_disabled, sl.is_policy_checked, sl.is_expiration_checked,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set,
  LOGINPROPERTY(sp.name, 'DaysUntilExpiration') AS days_until_expiration
FROM sys.server_principals sp
LEFT JOIN sys.sql_logins sl ON sp.principal_id = sl.principal_id
WHERE sp.sid = 0x01
  AND sp.is_disabled = 0
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT s.session_id, s.login_name, s.host_name, s.program_name, t.transaction_id, tat.transaction_begin_time, DATEDIFF(SECOND, tat.transaction_begin_time, GETDATE()) AS duration_seconds, (SELECT SUM(tdt.database_transaction_log_bytes_used) FROM sys.dm_tran_database_transactions tdt WHERE tdt.transaction_id = t.transaction_id) AS log_bytes_used FROM sys.dm_exec_sessions s JOIN sys.dm_tran_session_transactions t ON t.session_id = s.session_id JOIN sys.dm_tran_active_transactions tat ON tat.transaction_id = t.transaction_id WHERE s.is_user_process = 1 ORDER BY log_bytes_used DESC
GO

/* ===== SEC-SQL-ACC-010-RC11 @ 181.214.214.98 ===== */
SELECT s.session_id, s.login_name, s.host_name, s.program_name, r.start_time, SUBSTRING(t.text, 1, 200) AS query_text FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON s.session_id = r.sessio
GO

/* ===== SEC-SQL-ACC-010-RC11 @ 181.214.214.98 ===== */
SELECT OBJECT_SCHEMA_NAME(m.object_id) AS schema_name,
  OBJECT_NAME(m.object_id) AS proc_name,
  CASE WHEN m.definition LIKE '%EXEC(%+%@%' OR m.definition LIKE '%EXEC(@%'
    OR m.definition LIKE '%E
GO

/* ===== SEC-SQL-PRI-001-RC15 @ 181.214.214.98 ===== */
SELECT mid.statement AS table_name, mid.equality_columns, mid.inequality_columns, mid.included_columns, migs.avg_user_impact, migs.user_seeks FROM sys.dm_db_missing_index_details mid JOIN sys.dm_db_missing_index_groups mig ON mid.index_handle = mig.index_handle JOIN sys.dm_db_missing_index_group_stats migs ON mig.index_group_handle = migs.group_handle WHERE migs.avg_user_impact > 50 ORDER BY migs.avg_user_impact * migs.user_seeks DESC
GO

/* ===== SEC-SQL-PRI-001-RC15 @ 181.214.214.98 ===== */
SELECT TOP 10
  mid.statement AS table_name,
  mid.equality_columns,
  mid.inequality_columns,
  mid.included_columns,
  migs.user_seeks,
  migs.avg_user_impact,
  migs.user_seeks * migs.avg_total_user_cost * migs.avg_user_impact / 100.0 AS improvement_measure
FROM sys.dm_db_missing_index_details mid
JOIN sys.dm_db_missing_index_groups mig ON mid.index_handle = mig.index_handle
JOIN sys.dm_db_missing_index_group_stats migs ON mig.index_group_handle = migs.group_handle
WHERE migs.user_seeks > 100
ORDER BY improvement_measure DESC
GO

/* ===== SEC-SQL-PRI-001-RC15 @ 181.214.214.98 ===== */
SELECT mid.statement AS table_name, mid.equality_columns, mid.inequality_columns, mid.included_columns, migs.avg_user_impact, migs.user_seeks, migs.user_seeks * migs.avg_total_user_cost * (migs.avg_user_impact / 100.0) AS improvement_score FROM sys.dm_db_missing_index_groups mig JOIN sys.dm_db_missing_index_group_stats migs ON mig.index_group_handle = migs.group_handle JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle WHERE mid.database_id = DB_ID() AND migs.avg_user_impact > 50 ORDER BY improvement_score DESC
GO

/* ===== SEC-SQL-PRI-001-RC15 @ 181.214.214.98 ===== */
SELECT TOP 25
  DB_NAME(d.database_id) AS db_name,
  OBJECT_NAME(d.object_id, d.database_id) AS table_name,
  d.equality_columns,
  d.inequality_columns,
  d.included_columns,
  LEN(d.equality_columns) - LEN(REPLACE(d.equality_columns, ',', '')) + 1 AS equality_col_count,
  gs.user_seeks, gs.avg_total_user_cost, gs.avg_user_impact,
  gs.user_seeks * gs.avg_total_user_cost * (gs.avg_user_impact / 100.0) AS improvement_measure
FROM sys.dm_db_missing_index_details d
JOIN sys.dm_db_missing_index_groups g ON d.index_handle = g.index_handle
JOIN sys.dm_db_missing_index_group_stats gs ON g.index_group_handle = gs.group_handle
WHERE d.database_id = DB_ID()
  AND d.equality_columns LIKE '%,%'
ORDER BY improvement_measure DESC
GO

/* ===== SEC-SQL-PRI-001-RC15 @ 181.214.214.98 ===== */
SELECT sa.name AS audit_name, sas.name AS spec_name,
  sasd.audit_action_name, sasd.audited_principal_id,
  dp.name AS audited_principal
FROM sys.server_audits sa
JOIN sys.server_audit_specifications sas ON sa.audit_guid = sas.audit_guid
JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
LEFT JOIN sys.server_principals dp ON sasd.audited_principal_id = dp.principal_id
WHERE sasd.audited_principal_id != 0
GO

/* ===== SEC-SQL-PRI-001-RC15 @ 181.214.214.98 ===== */
SELECT action_name AS required_group,
  CASE WHEN EXISTS (
    SELECT 1 FROM sys.server_audit_specification_details sasd
    JOIN sys.server_audit_specifications sas
      ON sasd.server_specification_id = sas.server_specification_id
    WHERE sas.is_state_enabled = 1
      AND sasd.audit_action_name = da.action_name
  ) THEN 'PRESENT' ELSE 'MISSING' END AS status
FROM (
  VALUES ('FAILED_LOGIN_GROUP'), ('SUCCESSFUL_LOGIN_GROUP'),
         ('SERVER_ROLE_MEMBER_CHANGE_GROUP'),
         ('DATABASE_PERMISSION_CHANGE_GROUP'),
         ('SCHEMA_OBJECT_ACCESS_GROUP')
) da(action_name)
GO

/* ===== SEC-SQL-PRI-001-RC15 @ 181.214.214.98 ===== */
SELECT TOP 20
  mid.statement AS table_name,
  mid.equality_columns, mid.inequality_columns, mid.included_columns,
  migs.unique_compiles, migs.user_seeks, migs.user_scans,
  migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans) AS improvement_measure,
  migs.last_user_seek
FROM sys.dm_db_missing_index_details mid
JOIN sys.dm_db_missing_index_groups mig ON mid.index_handle = mig.index_handle
JOIN sys.dm_db_missing_index_group_stats migs ON mig.index_group_handle = migs.group_handle
WHERE migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans) > 10000
ORDER BY improvement_measure DESC
GO

/* ===== SEC-SQL-PRI-001-RC15 @ 181.214.214.98 ===== */
SELECT sas.name AS audit_spec_name, sas.is_state_enabled, sasd.audit_action_name FROM sys.server_audit_specifications sas LEFT JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
GO

/* ===== SEC-SQL-PRI-001-RC15 @ 181.214.214.98 ===== */
SELECT
  (SELECT COUNT(*) FROM sys.server_permissions WHERE state_desc = 'GRANT_WITH_GRANT_OPTION') +
  (SELECT COUNT(*) FROM sys.database_permissions WHERE state_desc = 'GRANT_WITH_GRANT_OPTION'
    AND grantee_principal_id NOT IN (SELECT principal_id FROM sys.database_principals
      WHERE name IN ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys'))) AS total_grant_options,
  (SELECT COUNT(*) FROM sys.server_audits WHERE is_state_enabled = 1) AS active_audits,
  (SELECT COUNT(*)
   FROM sys.server_audit_specifications sas
   JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
   WHERE sas.is_state_enabled = 1
     AND sasd.audit_action_name IN (
       'DATABASE_PERMISSION_CHANGE_GROUP', 'SERVER_PERMISSION_CHANGE_GROUP',
       'SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP', 'DATABASE_ROLE_MEMBER_CHANGE_GROUP',
       'SERVER_ROLE_MEMBER_CHANGE_GROUP')) AS permission_audit_actions
GO

/* ===== SEC-SQL-PRI-001-RC15 @ 181.214.214.98 ===== */
select * from [dbo].[RandomPeople]
GO

/* ===== SEC-SQL-PRI-001-RC15 @ 181.214.214.98 ===== */
SELECT das.name AS db_audit_spec, das.is_state_enabled, dasd.audit_action_name, dasd.class_desc, dasd.audited_principal_id FROM sys.database_audit_specifications das JOIN sys.database_audit_specification_details dasd ON das.database_specification_id = dasd.database_specification_id
GO

/* ===== SEC-SQL-PRI-001-RC15 @ 181.214.214.98 ===== */
SELECT sa.name AS audit_name, sas.name AS spec_name,
  sasd.audit_action_name
FROM sys.server_audits sa
JOIN sys.server_audit_specifications sas ON sa.audit_guid = sas.audit_guid
JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
WHERE sa.is_state_enabled = 1
  AND sasd.audit_action_name IN ('ALTER_SERVER_CONFIGURATION',
    'DATABASE_PRINCIPAL_CHANGE_GROUP', 'SERVER_PRINCIPAL_CHANGE_GROUP',
    'SERVER_ROLE_MEMBER_CHANGE_GROUP')
GO

/* ===== SEC-SQL-PRI-001-RC15 @ 181.214.214.98 ===== */
SELECT
  (SELECT COUNT(*) FROM sys.server_principals
   WHERE type_desc IN ('WINDOWS_LOGIN', 'WINDOWS_GROUP')
   AND is_disabled = 0 AND name NOT LIKE 'NT %') AS windows_logins,
  (SELECT COUNT(*) FROM sys.server_audit_specification_details sasd
   JOIN sys.server_audit_specifications sas ON sasd.server_specification_id = sas.server_specification_id
   JOIN sys.server_audits sa ON sas.audit_guid = sa.audit_guid
   WHERE sa.is_state_enabled = 1 AND sas.is_state_enabled = 1
   AND sasd.audit_action_name IN (
     'SUCCESSFUL_LOGIN_GROUP', 'FAILED_LOGIN_GROUP',
     'LOGIN_CHANGE_PASSWORD_GROUP', 'SERVER_PRINCIPAL_CHANGE_GROUP'
   )) AS login_audit_actions
GO

/* ===== SEC-SQL-PRI-001-RC15 @ 181.214.214.98 ===== */
SELECT
  CASE WHEN (SELECT CAST(value_in_use AS INT) FROM sys.configurations
    WHERE name = 'login auditing') >= 2 THEN 1 ELSE 0 END AS login_audit_enabled,
  (SELECT COUNT(*) FROM sys.server_event_sessions ses
   JOIN sys.server_event_session_events sese ON ses.event_session_id = sese.event_session_id
   WHERE sese.name IN ('audit_login', 'login') AND ses.startup_state = 1) AS xe_login_sessions,
  (SELECT COUNT(*) FROM sys.server_audits WHERE is_state_enabled = 1) AS active_audits,
  (SELECT COUNT(*) FROM sys.server_audit_specifications sas
   JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
   WHERE sas.is_state_enabled = 1
     AND sasd.audit_action_name IN ('SUCCESSFUL_LOGIN_GROUP', 'FAILED_LOGIN_GROUP')) AS login_audit_specs
GO

/* ===== SEC-SQL-PRI-001-RC15 @ 181.214.214.98 ===== */
SELECT sasd.audit_action_name,
  sasd.class_desc,
  sas.name AS spec_name
FROM sys.server_audit_specification_details sasd
JOIN sys.server_audit_specifications sas ON sasd.server_specification_id = sas.server_specification_id
WHERE sas.is_state_enabled = 1
  AND sasd.audit_action_name LIKE '%LOGIN%'
GO

/* ===== SEC-SQL-PRI-001-RC15 @ 181.214.214.98 ===== */
SELECT sa.name AS audit_name,
  sas.name AS server_spec_name, sas.is_state_enabled AS server_spec_enabled,
  sasd.audit_action_name, sasd.class_desc
FROM sys.server_audits sa
LEFT JOIN sys.server_audit_specifications sas ON sa.audit_guid = sas.audit_guid
LEFT JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
WHERE sa.is_state_enabled = 1
  AND sas.is_state_enabled = 1
  AND sasd.audit_action_name IN (
    'SCHEMA_OBJECT_CHANGE_GROUP', 'DATABASE_OBJECT_CHANGE_GROUP',
    'DATABASE_CHANGE_GROUP', 'SCHEMA_OBJECT_ACCESS_GROUP')
GO

/* ===== SEC-SQL-PRI-001-RC15 @ 181.214.214.98 ===== */
SELECT
  SUM(CASE WHEN sasd.audit_action_name IN ('DATABASE_OBJECT_ACCESS_GROUP', 'SCHEMA_OBJECT_ACCESS_GROUP') THEN 1 ELSE 0 END) AS dml_access_groups,
  SUM(CASE WHEN sasd.audit_action_name IN ('SCHEMA_OBJECT_CHANGE_GROUP', 'DATABASE_OBJECT_CHANGE_GROUP', 'DATABASE_CHANGE_GROUP') THEN 1 ELSE 0 END) AS ddl_change_groups,
  SUM(CASE WHEN sasd.audit_action_name IN ('SERVER_OBJECT_CHANGE_GROUP', 'SERVER_PRINCIPAL_CHANGE_GROUP') THEN 1 ELSE 0 END) AS server_change_groups
FROM sys.server_audit_specifications sas
JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
WHERE sas.is_state_enabled = 1
GO

/* ===== SEC-SQL-PRI-001-RC15 @ 181.214.214.98 ===== */
SELECT
  (SELECT COUNT(*) FROM sys.server_audits WHERE is_state_enabled = 1) AS active_audits,
  (SELECT COUNT(*)
   FROM sys.server_audit_specifications sas
   JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
   WHERE sas.is_state_enabled = 1
     AND sasd.audit_action_name IN ('SERVER_OPERATION_GROUP', 'AUDIT_CHANGE_GROUP')) AS config_change_audits,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'default trace enabled') AS default_trace
GO

/* ===== SEC-SQL-PRI-001-RC15 @ 181.214.214.98 ===== */
SELECT sa.name AS audit_name,
  CASE WHEN sa.is_state_enabled = 1 THEN 'STARTED' ELSE 'STOPPED' END, sa.type_desc AS audit_target,
  sas.name AS spec_name,
  sasd.audit_action_name, sasd.class_desc
FROM sys.server_audits sa
JOIN sys.server_audit_specifications sas ON sa.audit_guid = sas.audit_guid
JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
WHERE sa.is_state_enabled = 1
  AND sasd.audit_action_name IN (
    'SCHEMA_OBJECT_ACCESS_GROUP',
    'BATCH_COMPLETED_GROUP',
    'STATEMENT_ROLLBACK_GROUP',
    'TRANSACTION_GROUP',
    'DATABASE_OBJECT_ACCESS_GROUP'
  )
ORDER BY sasd.audit_action_name
GO

/* ===== SEC-SQL-PRI-001-RC15 @ 181.214.214.98 ===== */
SELECT d.name AS database_name,
  CASE WHEN EXISTS (
    SELECT 1 FROM sys.database_audit_specifications das
    JOIN sys.database_audit_specification_details dasd ON das.database_specification_id = dasd.database_specification_id
    WHERE das.is_state_enabled = 1
      AND dasd.audit_action_name IN (
        'DATABASE_PERMISSION_CHANGE_GROUP',
        'SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP',
        'DATABASE_ROLE_MEMBER_CHANGE_GROUP'))
    THEN 'MONITORED' ELSE 'UNMONITORED' END AS permission_audit_status
FROM sys.databases d
WHERE d.state = 0
  AND d.database_id > 4
ORDER BY permission_audit_status DESC, d.name
GO

/* ===== SEC-SQL-PRI-001-RC15 @ 181.214.214.98 ===== */
SELECT das.name AS db_spec_name,
  dasd.audit_action_name,
  dasd.class_desc,
  CASE dasd.major_id
    WHEN 0 THEN 'ALL OBJECTS'
    ELSE OBJECT_NAME(dasd.major_id)
  END AS audited_scope,
  dasd.audited_result
FROM sys.database_audit_specifications das
JOIN sys.database_audit_specification_details dasd ON das.database_specification_id = dasd.database_specification_id
WHERE das.is_state_enabled = 1
  AND dasd.audit_action_name = 'SELECT'
  AND dasd.major_id = 0
ORDER BY das.name
GO

/* ===== SEC-SQL-PRI-001-RC15 @ 181.214.214.98 ===== */
SELECT sp.name AS login_name, sp.type_desc,
  IS_SRVROLEMEMBER('sysadmin', sp.name) AS is_sysadmin,
  (SELECT COUNT(*) FROM sys.server_audit_specifications sas
   JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
   WHERE sas.is_state_enabled = 1
     AND sasd.audit_action_name = 'AUDIT_CHANGE_GROUP') AS audit_change_monitored
FROM sys.server_principals sp
JOIN sys.server_role_members srm ON sp.principal_id = srm.member_principal_id
JOIN sys.server_principals sr ON srm.role_principal_id = sr.principal_id
WHERE sr.name = 'sysadmin'
  AND sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
GO

/* ===== SEC-SQL-PRI-001-RC15 @ 181.214.214.98 ===== */
SELECT d.name AS database_name,
  SUM(CASE WHEN dasd.audit_action_name LIKE '%ACCESS%' THEN 1 ELSE 0 END) AS access_actions,
  SUM(CASE WHEN dasd.audit_action_name LIKE '%CHANGE%' THEN 1 ELSE 0 END) AS change_actions,
  SUM(CASE WHEN dasd.audit_action_name LIKE '%PERMISSION%' THEN 1 ELSE 0 END) AS permission_actions
FROM sys.databases d
CROSS APPLY (
  SELECT das2.database_specification_id
  FROM sys.database_audit_specifications das2
  WHERE das2.is_state_enabled = 1) das
CROSS APPLY (
  SELECT dasd2.audit_action_name
  FROM sys.database_audit_specification_details dasd2
  WHERE dasd2.database_specification_id = das.database_specification_id) dasd
WHERE d.state = 0 AND d.database_id > 4
GROUP BY d.name
HAVING SUM(CASE WHEN dasd.audit_action_name LIKE '%CHANGE%' THEN 1 ELSE 0 END) = 0
GO

/* ===== SEC-SQL-PRI-001-RC15 @ 181.214.214.98 ===== */
SELECT
  (SELECT COUNT(*) FROM sys.server_audit_specifications sas
   JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
   WHERE sas.is_state_enabled = 1
     AND sasd.audit_action_name IN (
       'SERVER_ROLE_MEMBER_CHANGE_GROUP', 'DATABASE_ROLE_MEMBER_CHANGE_GROUP',
       'SERVER_PERMISSION_CHANGE_GROUP', 'DATABASE_PERMISSION_CHANGE_GROUP',
       'SERVER_PRINCIPAL_CHANGE_GROUP')) AS permission_audit_specs,
  (SELECT COUNT(*) FROM msdb.dbo.sysjobs j
   JOIN msdb.dbo.sysjobsteps js ON j.job_id = js.job_id
   WHERE j.enabled = 1
     AND (js.command LIKE '%access review%' OR js.command LIKE '%permission%report%'
       OR js.command LIKE '%role member%audit%')) AS access_review_jobs
GO

/* ===== SEC-SQL-PRI-001-RC15 @ 181.214.214.98 ===== */
SELECT j.name AS job_name, js.step_name,
  ((h.run_duration / 10000) * 3600 + ((h.run_duration % 10000) / 100) * 60 + (h.run_duration % 100)) AS duration_sec,
  js.database_name AS step_database,
  js.command
FROM msdb.dbo.sysjobhistory h
JOIN msdb.dbo.sysjobs j ON h.job_id = j.job_id
JOIN msdb.dbo.sysjobsteps js ON h.job_id = js.job_id AND h.step_id = js.step_id
WHERE h.step_id > 0
  AND h.run_status = 1
  AND h.run_date >= CONVERT(int, CONVERT(varchar(8), DATEADD(day, -7, GETDATE()), 112))
  AND ((h.run_duration / 10000) * 3600 + ((h.run_duration % 10000) / 100) * 60 + (h.run_duration % 100)) > 600
  AND js.database_name IN (
    SELECT DB_NAME(d.database_id)
    FROM sys.dm_db_missing_index_details d
    JOIN sys.dm_db_missing_index_groups g ON d.index_handle = g.index_handle
    JOIN sys.dm_db_missing_index_group_stats gs ON g.index_group_handle = gs.group_handle
    WHERE gs.avg_user_impact > 70 AND (gs.user_seeks + gs.user_scans) > 100
  )
ORDER BY duration_sec DESC
GO

/* ===== SEC-SQL-PRI-001-RC15 @ 181.214.214.98 ===== */
SELECT
  (SELECT COUNT(*) FROM sys.server_audits WHERE is_state_enabled = 1) AS active_audits,
  (SELECT COUNT(*) FROM sys.server_audit_specifications sas
   JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
   WHERE sas.is_state_enabled = 1
     AND sasd.audit_action_name IN ('SERVER_PRINCIPAL_CHANGE_GROUP', 'LOGIN_CHANGE_PASSWORD_GROUP')) AS login_audit_actions,
  (SELECT COUNT(*) FROM sys.sql_logins sl
   JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
   WHERE sp.is_disabled = 0 AND sp.name NOT LIKE '##%' AND sp.name <> 'sa'
     AND DATEDIFF(DAY, sp.create_date, GETDATE()) < 90) AS recent_sql_logins
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT bs.database_name, bs.backup_finish_date, bmf.physical_device_name, bs.has_backup_checksums
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.has_backup_checksums = 1
  AND bs.backup_finish_date < DATEADD(day, -30, GETDATE())
ORDER BY bs.backup_finish_date ASC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT
  c.protocol_version,
  CASE
    WHEN c.protocol_version >= 1946157060 THEN 'TDS 7.4 (SQL Server 2012+)'
    WHEN c.protocol_version >= 1912602624 THEN 'TDS 7.3B (SQL Server 2008R2)'
    WHEN c.protocol_version >= 1879048192 THEN 'TDS 7.3A (SQL Server 2008)'
    WHEN c.protocol_version >= 1845493760 THEN 'TDS 7.2 (SQL Server 2005)'
    WHEN c.protocol_version >= 1811939328 THEN 'TDS 7.1 (SQL Server 2000)'
    ELSE 'TDS 7.0 or older'
  END AS tds_version_desc,
  COUNT(*) AS connection_count,
  COUNT(DISTINCT c.client_net_address) AS distinct_clients
FROM sys.dm_exec_connections c
WHERE c.protocol_version IS NOT NULL
GROUP BY c.protocol_version
ORDER BY c.protocol_version ASC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT instance_name AS deprecated_feature,
  cntr_value AS usage_count
FROM sys.dm_os_performance_counters
WHERE object_name LIKE '%Deprecated Features%'
  AND cntr_value > 0
ORDER BY cntr_value DESC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT
  (SELECT COUNT(*) FROM sys.server_audits WHERE is_state_enabled = 1) AS active_server_audits,
  (SELECT COUNT(*) FROM sys.server_audit_specification_details sasd
   JOIN sys.server_audit_specifications sas ON sasd.server_specification_id = sas.server_specification_id
   WHERE sas.is_state_enabled = 1
     AND sasd.audit_action_name IN ('SCHEMA_OBJECT_CHANGE_GROUP', 'DATABASE_OBJECT_CHANGE_GROUP', 'SERVER_OBJECT_CHANGE_GROUP')) AS schema_change_audit_count,
  (SELECT COUNT(*) FROM sys.database_audit_specification_details dasd
   JOIN sys.database_audit_specifications das ON dasd.database_specification_id = das.database_specification_id
   WHERE das.is_state_enabled = 1
     AND dasd.audit_action_name IN ('SCHEMA_OBJECT_CHANGE_GROUP', 'DATABASE_OBJECT_CHANGE_GROUP')) AS db_level_audit_count
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT TOP 20
  qs.sql_handle,
  qs.execution_count,
  qs.total_elapsed_time / NULLIF(qs.execution_count, 0) / 1000 AS avg_elapsed_ms,
  p.query_plan.exist('//Warnings/PlanAffectingConvert') AS has_implicit_convert,
  p.query_plan.value('count(//Warnings/PlanAffectingConvert)', 'int') AS convert_warnings,
  SUBSTRING(t.text, 1, 400) AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) t
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) p
WHERE p.query_plan.exist('//Warnings/PlanAffectingConvert') = 1
  AND qs.execution_count > 10
ORDER BY qs.execution_count DESC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT sp.name, sp.create_date,
  DATEDIFF(DAY, sp.create_date, GETDATE()) AS account_age_days,
  (SELECT MAX(login_time) FROM sys.dm_exec_sessions WHERE login_name = sp.name) AS last_session,
  (SELECT COUNT(*) FROM sys.dm_exec_sessions WHERE login_name = sp.name AND is_user_process = 1) AS active_sessions,
  (SELECT COUNT(dp.principal_id) FROM sys.database_principals dp
   WHERE dp.sid = sp.sid AND dp.type = 'S') AS db_user_count
FROM sys.server_principals sp
WHERE sp.type IN ('S', 'U')
  AND sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
  AND sp.name NOT LIKE 'NT %'
  AND sp.name <> 'sa'
  AND (sp.name LIKE '%svc%' OR sp.name LIKE '%service%' OR sp.name LIKE '%app%'
    OR sp.name LIKE '%job%' OR sp.name LIKE '%batch%' OR sp.name LIKE '%etl%'
    OR sp.name LIKE '%agent%' OR sp.name LIKE '%daemon%')
  AND DATEDIFF(DAY, sp.create_date, GETDATE()) > 365
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT TOP 20
  qs.execution_count,
  qs.last_execution_time,
  SUBSTRING(qt.text, 1, 200) AS query_fragment,
  DB_NAME(qt.dbid) AS database_name
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
WHERE (qt.text LIKE '%SET ROWCOUNT%'
  OR qt.text LIKE '%RAISERROR %,%,%'
  OR qt.text LIKE '%sp_addtype%'
  OR qt.text LIKE '%DATABASEPROPERTY(%'
  OR qt.text LIKE '%::fn_virtualfilestats%')
  AND qt.dbid > 4
ORDER BY qs.execution_count DESC
GO

/* ===== Active transactions @ 181.214.214.98 ===== */
SELECT qs.execution_count AS [Execution Count], (qs.total_logical_reads)*8/1024.0 AS [Total Logical Reads (MB)], (qs.total_logical_reads/qs.execution_count)*8/1024.0 AS [Avg Logical Reads (MB)], (qs.total_worker_time)/1000.0 AS [Total Worker Time (ms)], (qs.total_worker_time/qs.execution_count)/1000.0 AS [Avg Worker Time (ms)], (qs.total_elapsed_time)/1000.0 AS [Total Elapsed Time (ms)], (qs.total_elapsed_time/qs.execution_count)/1000.0 AS [Avg Elapsed Time (ms)], qs.creation_time AS [Creation Time] ,t.text AS [Complete Query Text] FROM sys.dm_exec_query_stats AS qs WITH (NOLOCK) CROSS APPLY sys.dm_exec_sql_text(plan_handle) AS t
GO

/* ===== Active transactions @ 181.214.214.98 ===== */
SELECT der.session_id session_id, der.blocking_session_id blocking_session_id, DATEDIFF(second, der.start_time, GETDATE()) AS duration_secs, DB_NAME(der.database_id) AS database_name, der.start_time , ses.last_request_end_time, ses.open_transaction_count, ses.cpu_time, der.command, der.logical_reads, der.reads, der.writes, der.wait_type, der.last_wait_type, ses.login_name, ses.program_name AS program_name, ses.host_name, t.text query FROM sys.dm_exec_requests der INNER JOIN sys.dm_exec_sessions ses ON der.session_id = ses.session_id CROSS APPLY sys.dm_exec_sql_text(der.sql_handle) t CROSS APPLY sys.dm_exec_query_plan(der.plan_handle) cp WHERE blocking_session_id >0
GO

/* ===== SEC-SQL-AZ-004-RC07 @ 181.214.214.98 ===== */
SELECT
  (SELECT COUNT(*) FROM sys.server_principals sp
   JOIN sys.server_role_members srm ON sp.principal_id = srm.member_principal_id
   JOIN sys.server_principals sr ON srm.role_principal_id = sr.principal_id
   WHERE sr.name = 'sysadmin' AND sp.is_disabled = 0
     AND sp.name NOT LIKE '##%' AND sp.name NOT IN ('sa')) AS sysadmin_count,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'xp_cmdshell') AS xp_cmdshell_enabled,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'Ole Automation Procedures') AS ole_enabled
GO

/* ===== SEC-SQL-AZ-004-RC07 @ 181.214.214.98 ===== */
SELECT
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'xp_cmdshell') AS xp_cmdshell_enabled,
  (SELECT COUNT(*) FROM sys.credentials WHERE name = '##xp_cmdshell_proxy_account##') AS has_proxy_account,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'Ole Automation Procedures') AS ole_automation_enabled
GO

/* ===== SEC-SQL-AZ-004-RC07 @ 181.214.214.98 ===== */
SELECT
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'xp_cmdshell') AS xp_cmdshell_enabled,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'Ole Automation Procedures') AS ole_automation_enabled,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'clr enabled') AS clr_enabled,
  (SELECT COUNT(*) FROM sys.assemblies WHERE permission_set_desc = 'SAFE' AND is_user_defined = 1) AS safe_clr_assemblies,
  (SELECT COUNT(*) FROM msdb.dbo.sysssispackages) AS ssis_packages
GO

/* ===== SEC-SQL-AZ-004-RC07 @ 181.214.214.98 ===== */
SELECT sp.name AS login_name, sp.type_desc,
  perm.permission_name, perm.state_desc,
  OBJECT_NAME(perm.major_id) AS object_name
FROM sys.server_permissions perm
JOIN sys.server_principals sp ON perm.grantee_principal_id = sp.principal_id
WHERE perm.state_desc IN ('GRANT', 'GRANT_WITH_GRANT_OPTION')
  AND (
    perm.permission_name = 'ADMINISTER BULK OPERATIONS'
    OR perm.permission_name = 'EXTERNAL ACCESS ASSEMBLY'
    OR perm.permission_name = 'UNSAFE ASSEMBLY'
  )
UNION ALL
SELECT sp.name, sp.type_desc,
  'EXECUTE', 'GRANT',
  OBJECT_NAME(perm.major_id, DB_ID('master'))
FROM master.sys.database_permissions perm
JOIN sys.server_principals sp ON perm.grantee_principal_id = sp.principal_id
WHERE perm.state_desc IN ('GRANT', 'GRANT_WITH_GRANT_OPTION')
  AND OBJECT_NAME(perm.major_id, DB_ID('master')) IN ('xp_cmdshell', 'sp_OACreate', 'xp_fileexist', 'xp_subdirs', 'xp_dirtree')
GO

/* ===== SEC-SQL-AZ-004-RC07 @ 181.214.214.98 ===== */
SELECT s.login_name, r.command, t.text, r.start_time, r.logical_reads
     FROM sys.dm_exec_sessions s
     JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
     CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
     WHERE (r.command IN ('BULK INSERT','INSERT ... SELECT')
            OR t.text LIKE '%OPENROWSET%' OR t.text LIKE '%BCP%')
       AND r.logical_reads > 100000
GO

/* ===== SEC-SQL-AZ-004-RC07 @ 181.214.214.98 ===== */
SELECT
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'xp_cmdshell') AS xp_cmdshell_enabled,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'Ole Automation Procedures') AS ole_automation_enabled,
  (SELECT COUNT(*) FROM master.sys.extended_procedures) AS extended_procs,
  (SELECT COUNT(*) FROM sys.assemblies WHERE is_user_defined = 1
    AND permission_set_desc IN ('EXTERNAL_ACCESS', 'UNSAFE')) AS unsafe_assemblies
GO

/* ===== SEC-SQL-AZ-004-RC07 @ 181.214.214.98 ===== */
SELECT name, CAST(value_in_use AS INT) AS current_value,
  CASE name
    WHEN 'xp_cmdshell' THEN 0
    WHEN 'Ole Automation Procedures' THEN 0
    WHEN 'clr enabled' THEN 0
    WHEN 'cross db ownership chaining' THEN 0
    WHEN 'remote admin connections' THEN 0
    WHEN 'remote access' THEN 0
    WHEN 'scan for startup procs' THEN 0
  END AS hardened_value
FROM sys.configurations
WHERE name IN ('xp_cmdshell', 'Ole Automation Procedures', 'clr enabled',
  'cross db ownership chaining', 'remote admin connections', 'remote access',
  'scan for startup procs')
  AND CAST(value_in_use AS INT) <> 0
GO

/* ===== SEC-SQL-AZ-004-RC07 @ 181.214.214.98 ===== */
SELECT
  SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_only_auth,
  (SELECT is_disabled FROM sys.server_principals WHERE name = 'sa') AS sa_disabled,
  (SELECT COUNT(*) FROM sys.sql_logins sl
   JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
   WHERE sp.is_disabled = 0 AND sl.is_policy_checked = 0
     AND sp.name NOT LIKE '##%') AS logins_no_policy,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'cross db ownership chaining') AS cross_db_chaining,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'clr enabled') AS clr_enabled,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'xp_cmdshell') AS xp_cmdshell,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'Ole Automation Procedures') AS ole_automation,
  (SELECT COUNT(*) FROM sys.server_audits WHERE is_state_enabled = 1) AS active_audits
GO

/* ===== SEC-SQL-AZ-004-RC07 @ 181.214.214.98 ===== */
SELECT c.name AS config_name,
  CAST(c.value_in_use AS INT) AS is_enabled
FROM sys.configurations c
WHERE c.name IN ('xp_cmdshell', 'Ole Automation Procedures')
  AND CAST(c.value_in_use AS INT) = 1
GO

/* ===== SEC-SQL-AZ-004-RC07 @ 181.214.214.98 ===== */
SELECT c.credential_id, c.name AS credential_name,
  c.credential_identity, c.create_date
FROM master.sys.credentials c
WHERE c.name = '##xp_cmdshell_proxy_account##'
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT
  OBJECT_NAME(c.object_id) AS table_name,
  c.name AS column_name,
  ty.name AS column_type,
  c.scale AS fractional_precision,
  CASE
    WHEN ty.name = 'datetime' THEN 'Legacy 3.33ms precision'
    WHEN ty.name = 'datetime2' THEN '100ns precision'
    WHEN ty.name = 'datetimeoffset' THEN 'TZ-aware 100ns'
    WHEN ty.name = 'smalldatetime' THEN '1 minute precision'
    WHEN ty.name = 'date' THEN 'Date only'
    WHEN ty.name = 'time' THEN 'Time only'
  END AS type_notes
FROM sys.columns c
JOIN sys.types ty ON c.system_type_id = ty.system_type_id AND c.user_type_id = ty.user_type_id
JOIN sys.tables t ON c.object_id = t.object_id
WHERE ty.name IN ('datetime', 'datetime2', 'datetimeoffset', 'smalldatetime', 'date', 'time')
ORDER BY t.name, c.name
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT d.name AS database_name,
  d.is_db_chaining_on,
  sp.name AS db_owner,
  d.owner_sid,
  CASE WHEN d.owner_sid = (SELECT owner_sid FROM sys.databases WHERE name = 'master')
    THEN 'SAME_AS_MASTER' ELSE 'DIFFERENT_OWNER' END AS ownership_alignment
FROM sys.databases d
LEFT JOIN sys.server_principals sp ON d.owner_sid = sp.sid
WHERE d.is_db_chaining_on = 1
  AND d.state = 0
  AND d.database_id > 4
ORDER BY sp.name
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT s.name AS schema_name, o.name AS table_name,
  st.name AS statistics_name,
  sp.last_updated,
  sp.rows AS total_rows,
  sp.rows_sampled,
  sp.modification_counter,
  CASE WHEN sp.rows > 0
    THEN CAST(sp.modification_counter AS float) / sp.rows * 100
    ELSE 0 END AS pct_modified
FROM sys.stats st
JOIN sys.objects o ON st.object_id = o.object_id
JOIN sys.schemas s ON o.schema_id = s.schema_id
CROSS APPLY sys.dm_db_stats_properties(st.object_id, st.stats_id) sp
WHERE o.type = 'U'
  AND sp.modification_counter > 1000
  AND CAST(sp.modification_counter AS float) / NULLIF(sp.rows, 0) > 0.1
ORDER BY sp.modification_counter DESC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT SERVERPROPERTY('IsClustered') AS is_clustered,
  CONNECTIONPROPERTY('protocol_type') AS current_protocol,
  CONNECTIONPROPERTY('encrypt_option') AS current_encrypt,
  (SELECT value_in_use FROM sys.configurations WHERE name = 'force encryption') AS force_encryption_config
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT
      s.session_id AS sid,
      s.login_name,
      s.host_name,
      s.program_name,
      s.login_time,
      DATEDIFF(SECOND, s.login_time, GETDATE()) AS connected_seconds,
      s.status,
      DB_NAME(s.database_id) AS database_name,
      r.command,
      r.wait_type,
      r.blocking_session_id,
      t.text AS current_query
  FROM sys.dm_exec_sessions s
  LEFT JOIN sys.dm_exec_requests r ON r.session_id = s.session_id
  OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) t
  WHERE s.session_id > 50
    AND s.login_name IS NOT NULL
    AND s.login_name <> ''
  ORDER BY s.login_time
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT sk.name, sk.algorithm_desc, sk.key_length,
  sk.create_date, sk.modify_date,
  CASE
    WHEN sk.algorithm_desc IN ('DES', 'TRIPLE_DES', 'RC4', 'RC4_128', 'RC2', 'DESX') THEN 'DEPRECATED_ALGORITHM'
    WHEN sk.key_length < 128 THEN 'CRITICALLY_SHORT'
    WHEN sk.key_length < 256 AND sk.algorithm_desc LIKE 'AES%' THEN 'BELOW_RECOMMENDED'
    ELSE 'OK'
  END AS key_strength_status
FROM sys.symmetric_keys sk
WHERE sk.name NOT LIKE '##%'
ORDER BY sk.key_length ASC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT OBJECT_SCHEMA_NAME(m.object_id) AS schema_name,
  OBJECT_NAME(m.object_id) AS proc_name,
  LEN(m.definition) AS definition_length,
  (LEN(m.definition) - LEN(REPLACE(m.definition, '+ @', ''))) / 3 AS approx_concat_count,
  (LEN(m.definition) - LEN(REPLACE(m.definition, 'IF ', ''))) / 3 AS approx_if_count
FROM sys.sql_modules m
JOIN sys.objects o ON m.object_id = o.object_id
WHERE o.type = 'P'
  AND (m.definition LIKE '%EXEC(%' OR m.definition LIKE '%sp_executesql%')
  AND (LEN(m.definition) - LEN(REPLACE(m.definition, '+ @', ''))) / 3 >= 5
ORDER BY (LEN(m.definition) - LEN(REPLACE(m.definition, '+ @', ''))) DESC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT TOP 10
  t.text AS query_text,
  qs.execution_count,
  qs.last_execution_time,
  qs.total_elapsed_time / qs.execution_count AS avg_elapsed_us
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) t
WHERE (
  t.text LIKE '%xp_cmdshell%'
  OR t.text LIKE '%OPENROWSET%'
  OR t.text LIKE '%BULK INSERT%'
  OR t.text LIKE '%sp_OACreate%'
  OR t.text LIKE '%xp_fileexist%'
  OR t.text LIKE '%xp_dirtree%'
)
ORDER BY qs.last_execution_time DESC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT TOP 50
  qs.execution_count,
  qs.last_execution_time,
  SUBSTRING(st.text, 1, 500) AS query_text,
  CASE
    WHEN st.text LIKE '%OPENQUERY%' THEN 'OPENQUERY'
    WHEN st.text LIKE '%OPENROWSET%' THEN 'OPENROWSET'
    WHEN st.text LIKE '%EXEC%AT%[[]%' THEN 'EXEC_AT_LINKED'
    ELSE 'OTHER'
  END AS linked_query_type,
  DB_NAME(st.dbid) AS source_database
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
WHERE st.text LIKE '%OPENQUERY%'
  OR st.text LIKE '%OPENROWSET%'
  OR (st.text LIKE '%EXEC%' AND st.text LIKE '%AT %[[]%')
ORDER BY qs.execution_count DESC
GO

/* ===== Active transactions @ 181.214.214.98 ===== */
SET NOCOUNT ON;  IF OBJECT_ID('tempdb..#sensitive_cols') IS NOT NULL DROP TABLE #sensitive_cols; CREATE TABLE #sensitive_cols (     db_name      sysname,     schema_name  sysname,     table_name   sysname,     column_name  sysname,     pii_category nvarchar(50) );  DECLARE @sql nvarchar(max) = N''; SELECT @sql = @sql + N' USE ' + QUOTENAME(name) + N'; INSERT INTO #sensitive_cols (db_name, schema_name, table_name, column_name, pii_category) SELECT DB_NAME(), s.name, t.name, c.name,   CASE     WHEN LOWER(c.name) LIKE ''%password%'' OR LOWER(c.name) LIKE ''%pass%'' THEN ''Password''     WHEN LOWER(c.name) LIKE ''%secret%''   OR LOWER(c.name) LIKE ''%token%'' OR LOWER(c.name) LIKE ''%key%'' THEN ''Credential''     WHEN LOWER(c.name) LIKE ''%credit%''   OR LOWER(c.name) LIKE ''%card%''  THEN ''Credit Card''     WHEN LOWER(c.name) LIKE ''%ssn%''      THEN ''SSN''     WHEN LOWER(c.name) LIKE ''%email%''    THEN ''Email''     WHEN LOWER(c.name) LIKE ''%phone%''    THEN ''Phone''     WHEN LOWER(c.name) LIKE ''%address%''  THEN ''Address''     WHEN LOWER(c.name) LIKE ''%dob%''      OR LOWER(c.name) LIKE ''%birth%'' THEN ''Date of Birth''     WHEN LOWER(c.name) LIKE ''%salary%''   THEN ''Salary''     WHEN LOWER(c.name) LIKE ''%passport%'' THEN ''Passport''     WHEN LOWER(c.name) LIKE ''%medical%''  OR LOWER(c.name) LIKE ''%diagnosis%'' THEN ''Medical''     WHEN LOWER(c.name) LIKE ''%teudat%''   THEN ''Teudat Zehut''     ELSE ''Other Sensitive''   END FROM sys.tables  t JOIN sys.columns c ON c.object_id = t.object_id JOIN sys.schemas s ON s.schema_id = t.schema_id WHERE t.is_ms_shipped = 0   AND (LOWER(c.name) LIKE ''%password%'' OR LOWER(c.name) LIKE ''%pass%''     OR LOWER(c.name) LIKE ''%secret%''   OR LOWER(c.name) LIKE ''%token%'' OR LOWER(c.name) LIKE ''%key%''     OR LOWER(c.name) LIKE ''%credit%''   OR LOWER(c.name) LIKE ''%card%''     OR LOWER(c.name) LIKE ''%ssn%''     OR LOWER(c.name) LIKE ''%email%''     OR LOWER(c.name) LIKE ''%phone%''     OR LOWER(c.name) LIKE ''%address%''     OR LOWER(c.name) LIKE ''%dob%''      OR LOWER(c.name) LIKE ''%birth%''     OR LOWER(c.name) LIKE ''%salary%''     OR LOWER(c.name) LIKE ''%passport%''     OR LOWER(c.name) LIKE ''%medical%''  OR LOWER(c.name) LIKE ''%diagnosis%''     OR LOWER(c.name) LIKE ''%teudat%''); ' FROM sys.databases WHERE state = 0   AND database_id > 4   AND HAS_DBACCESS(name) = 1   AND name NOT IN ('distribution', 'ReportServer', 'ReportServerTempDB', 'SSISDB');  EXEC sp_executesql @sql;  SELECT top 100 'cached_plan'         AS source,        CAST(NULL AS INT)     AS session_id,        CAST(NULL AS BIGINT)  AS transaction_id,        qs.execution_count,        qs.last_execution_time,        qs.total_logical_reads / NULLIF(qs.execution_count, 0)         AS avg_reads,        qs.total_worker_time / NULLIF(qs.execution_count, 0) / 1000    AS avg_cpu_ms,        CAST(NULL AS DATETIME) AS transaction_begin_time,        sc.db_name, sc.schema_name, sc.table_name, sc.column_name, sc.pii_category,        LEFT(t.text, 4000)    AS query_text,        CAST(NULL AS sysname) AS login_name FROM sys.dm_exec_query_stats AS qs WITH (NOLOCK) CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) AS t JOIN #sensitive_cols sc ON t.text LIKE '%' + sc.table_name + '%' WHERE t.text IS NOT NULL   AND LEFT(t.text, 4000) NOT LIKE '%tempdb..#sensitive_cols%' UNION ALL SELECT 'active_transaction'  AS source,        ses.session_id,        tat.transaction_id,        CAST(NULL AS BIGINT)  AS execution_count,        CAST(NULL AS DATETIME) AS last_execution_time,        CAST(NULL AS BIGINT)  AS avg_reads,        CAST(NULL AS BIGINT)  AS avg_cpu_ms,        tat.transaction_begin_time,        sc.db_name, sc.schema_name, sc.table_name, sc.column_name, sc.pii_category,        LEFT(t.text, 4000)    AS query_text,        ses.login_name AS login_name FROM sys.dm_tran_active_transactions    tat JOIN sys.dm_tran_session_transactions   sts ON sts.transaction_id = tat.transaction_id JOIN sys.dm_exec_sessions               ses ON
GO

/* ===== Active transactions @ 181.214.214.98 ===== */
SELECT TOP 20   qs.execution_count,   qs.last_execution_time,   SUBSTRING(qt.text, 1, 200) AS query_fragment,   DB_NAME(qt.dbid) AS database_name FROM sys.dm_exec_query_stats qs CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt WHERE (qt.text LIKE '%SET ROWCOUNT%'   OR qt.text LIKE '%RAISERROR %,%,%'   OR qt.text LIKE '%sp_addtype%'   OR qt.text LIKE '%DATABASEPROPERTY(%'   OR qt.text LIKE '%::fn_virtualfilestats%')   AND qt.dbid > 4 ORDER BY qs.execution_count DESC
GO

/* ===== Active transactions @ 181.214.214.98 ===== */
SELECT   (SELECT cntr_value FROM sys.dm_os_performance_counters    WHERE counter_name = 'Temp Tables Creation Rate' AND instance_name = '') AS temp_table_rate,   (SELECT COUNT(*) FROM tempdb.sys.objects WHERE type IN ('U', 'TT') AND is_ms_shipped = 0) AS current_temp_objects,   (SELECT SUM(user_object_reserved_page_count) * 8 / 1024 FROM sys.dm_db_file_space_usage) AS user_objects_mb_in_tempdb
GO

/* ===== Active transactions @ 181.214.214.98 ===== */
SELECT OBJECT_SCHEMA_NAME(m.object_id) AS schema_name,   OBJECT_NAME(m.object_id) AS proc_name,   CASE WHEN m.definition LIKE '%EXEC(%+%@%' OR m.definition LIKE '%EXEC(@%'     OR m.definition LIKE '%EXEC (@%' THEN 1 ELSE 0 END AS has_exec_concat,   CASE WHEN m.definition LIKE '%sp_executesql%' THEN 1 ELSE 0 END AS has_sp_executesql FROM sys.sql_modules m JOIN sys.objects o ON m.object_id = o.object_id WHERE o.type = 'P'   AND (m.definition LIKE '%EXEC(%' OR m.definition LIKE '%EXECUTE(%'     OR m.definition LIKE '%sp_executesql%')   AND (m.definition LIKE '%SELECT %FROM %' COLLATE Latin1_General_BIN     OR m.definition LIKE '%INSERT %INTO %' COLLATE Latin1_General_BIN     OR m.definition LIKE '%UPDATE %SET %' COLLATE Latin1_General_BIN     OR m.definition LIKE '%DELETE %FROM %' COLLATE Latin1_General_BIN)
GO

/* ===== Active transactions @ 181.214.214.98 ===== */
SELECT OBJECT_SCHEMA_NAME(m.object_id) AS schema_name,   OBJECT_NAME(m.object_id) AS proc_name,   LEN(m.definition) AS definition_length,   (LEN(m.definition) - LEN(REPLACE(m.definition, '+ @', ''))) / 3 AS approx_concat_count,   (LEN(m.definition) - LEN(REPLACE(m.definition, 'IF ', ''))) / 3 AS approx_if_count FROM sys.sql_modules m JOIN sys.objects o ON m.object_id = o.object_id WHERE o.type = 'P'   AND (m.definition LIKE '%EXEC(%' OR m.definition LIKE '%sp_executesql%')   AND (LEN(m.definition) - LEN(REPLACE(m.definition, '+ @', ''))) / 3 >= 5 ORDER BY (LEN(m.definition) - LEN(REPLACE(m.definition, '+ @', ''))) DESC
GO

/* ===== SEC-SQL-PRI-001-RC15 @ 181.214.214.98 ===== */
SELECT
  (SELECT COUNT(*) FROM sys.server_audits WHERE is_state_enabled = 1) AS active_audits,
  (SELECT COUNT(*) FROM sys.server_audit_specifications sas
   JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
   WHERE sas.is_state_enabled = 1
     AND sasd.audit_action_name IN ('SUCCESSFUL_LOGIN_GROUP', 'FAILED_LOGIN_GROUP', 'LOGIN_CHANGE_PASSWORD_GROUP')) AS login_tracking_actions,
  CAST(SERVERPROPERTY('IsIntegratedSecurityOnly') AS int) AS windows_auth_only
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT
  SUM(CASE WHEN c.auth_scheme = 'SQL' THEN 1 ELSE 0 END) AS sql_auth_sessions,
  SUM(CASE WHEN c.auth_scheme IN ('KERBEROS', 'NTLM') THEN 1 ELSE 0 END) AS windows_auth_sessions,
  COUNT(*) AS total_sessions,
  ROUND(SUM(CASE WHEN c.auth_scheme = 'SQL' THEN 1.0 ELSE 0 END) / NULLIF(COUNT(*), 0) * 100, 1) AS pct_sql_auth
FROM sys.dm_exec_sessions s
JOIN sys.dm_exec_connections c ON s.session_id = c.session_id
WHERE s.is_user_process = 1
  AND c.parent_connection_id IS NULL
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT j.name, h.run_date, h.run_time, h.run_duration, h.run_status, h.message FROM msdb.dbo.sysjobs j JOIN msdb.dbo.sysjobhistory h ON j.job_id = h.job_id WHERE j.name LIKE '%backup%' AND (h.run_status = 0 OR h.run_status = 3) AND h.run_date >= CONVERT(int, CONVERT(varchar(8), DATEADD(day, -7, GETDATE()), 112)) ORDER BY h.run_duration DESC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT cek.name AS encryption_key_name,
  cmk.name AS master_key_name,
  cmk.key_store_provider_name,
  cek.create_date AS cek_created,
  cek.modify_date AS cek_modified,
  DATEDIFF(DAY, cek.create_date, GETDATE()) AS cek_age_days
FROM sys.column_encryption_keys cek
JOIN sys.column_encryption_key_values cekv ON cek.column_encryption_key_id = cekv.column_encryption_key_id
JOIN sys.column_master_keys cmk ON cekv.column_master_key_id = cmk.column_master_key_id
ORDER BY cek.create_date ASC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT
  (SELECT COUNT(*) FROM sys.masked_columns) AS masked_column_count,
  (SELECT COUNT(*) FROM sys.column_encryption_keys) AS encryption_key_count,
  (SELECT COUNT(*) FROM sys.column_master_keys) AS master_key_count,
  CASE
    WHEN (SELECT COUNT(*) FROM sys.masked_columns) = 0
      AND (SELECT COUNT(*) FROM sys.column_encryption_keys) = 0
    THEN 'FEATURES_AVAILABLE_BUT_UNUSED'
    ELSE 'FEATURES_IN_USE'
  END AS feature_utilization
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT DB_NAME(database_id) AS db_name,
  CAST(total_log_size_in_bytes / 1048576.0 AS DECIMAL(12,2)) AS total_log_size_mb,
  CAST(used_log_space_in_bytes / 1048576.0 AS DECIMAL(12,2)) AS used_log_space_mb,
  CAST(used_log_space_in_percent AS DECIMAL(5,2)) AS used_log_pct
FROM sys.dm_db_log_space_usage
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT su.session_id, su.user_objects_alloc_page_count * 8 / 1024 AS user_alloc_mb, su.user_objects_dealloc_page_count * 8 / 1024 AS user_dealloc_mb, su.internal_objects_alloc_page_count * 8 / 1024 AS internal_alloc_mb, s.program_name, s.host_name, s.login_time, (SELECT COUNT(*) FROM tempdb.sys.objects WHERE type = 'U' AND name LIKE '#%') AS active_temp_tables FROM sys.dm_db_session_space_usage su JOIN sys.dm_exec_sessions s ON su.session_id = s.session_id WHERE su.user_objects_alloc_page_count > 1000 ORDER BY su.user_objects_alloc_page_count DESC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT TOP 10
  qs.query_hash,
  qs.total_logical_reads / NULLIF(qs.execution_count, 0) AS avg_reads,
  qs.total_worker_time / NULLIF(qs.execution_count, 0) / 1000 AS avg_cpu_ms,
  qs.total_elapsed_time / NULLIF(qs.execution_count, 0) / 1000 AS avg_elapsed_ms,
  qs.total_rows / NULLIF(qs.execution_count, 0) AS avg_rows_returned,
  CASE WHEN qs.total_rows > 0
    THEN qs.total_logical_reads / qs.total_rows ELSE 0 END AS reads_per_row,
  p.query_plan.value('(//RelOp/@EstimatedTotalSubtreeCost)[1]', 'float') AS estimated_cost,
  SUBSTRING(t.text, 1, 300) AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) t
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) p
WHERE p.query_plan.exist('//ScalarOperator/Subquery') = 1
  AND p.query_plan.value('count(//RelOp[@PhysicalOp="Nested Loops"]/OuterReferences)', 'int') > 0
  AND qs.total_logical_reads / NULLIF(qs.execution_count, 0) > 10000
ORDER BY reads_per_row DESC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT
  pc.counter_name, pc.cntr_value,
  ws.wait_type, ws.waiting_tasks_count,
  ws.wait_time_ms,
  CASE WHEN ws.waiting_tasks_count > 0
    THEN ws.wait_time_ms / ws.waiting_tasks_count ELSE 0 END AS avg_wait_ms
FROM sys.dm_os_performance_counters pc
CROSS JOIN sys.dm_os_wait_stats ws
WHERE pc.counter_name IN ('Number of Deadlocks/sec', 'Lock Timeouts/sec', 'Lock Wait Time (ms)')
  AND pc.instance_name = '_Total'
  AND ws.wait_type IN ('LCK_M_S', 'LCK_M_X', 'LCK_M_U', 'LCK_M_IX', 'LCK_M_IS')
  AND ws.waiting_tasks_count > 0
ORDER BY ws.wait_time_ms DESC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT t.name AS table_name, p.rows, 'row_count >= 100000 — likely High-level under PPL Reg §2' AS finding FROM sys.tables t JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1) WHERE p.rows >= 100000 ORDER BY p.rows DESC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT 
    blocking_session_id,
    session_id,
    wait_type,
    wait_time,
    wait_resource
FROM sys.dm_exec_requests
WHERE blocking_session_id <> 0
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
EXEC sys.xp_readerrorlog 0, 1, N'Logging SQL Server messages in file',
  NULL, NULL, NULL, N'DESC'
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT c.cluster_name, c.quorum_type_desc, c.quorum_state_desc,
  cm.member_name, cm.member_state_desc, cm.number_of_quorum_votes,
  ags.synchronization_health_desc
FROM sys.dm_hadr_cluster c
CROSS JOIN sys.dm_hadr_cluster_members cm
LEFT JOIN sys.dm_hadr_availability_group_states ags ON 1=1
WHERE c.quorum_state_desc <> 'NORMAL_QUORUM'
  OR cm.member_state_desc <> 'UP'
  OR ags.synchronization_health_desc <> 'HEALTHY'
GO

/* ===== SEC-SQL-ACC-010-RC11 @ 181.214.214.98 ===== */
SELECT OBJECT_SCHEMA_NAME(m.object_id) AS schema_name,
  OBJECT_NAME(m.object_id) AS proc_name,
  LEN(m.definition) AS definition_length,
  (LEN(m.definition) - LEN(REPLACE(m.definition, '+ @', '')))
GO

/* ===== SEC-SQL-AZ-004-RC07 @ 181.214.214.98 ===== */
SELECT CAST(c.value_in_use AS INT) AS xp_cmdshell_enabled,
  j.name AS job_name, j.enabled AS job_enabled,
  j.date_created, j.date_modified,
  sp.name AS job_owner,
  js.step_name, js.subsystem,
  CASE
    WHEN js.command LIKE '%xp_cmdshell%powershell%' THEN 'POWERSHELL_VIA_CMDSHELL'
    WHEN js.command LIKE '%xp_cmdshell%net user%' THEN 'USER_MANAGEMENT'
    WHEN js.command LIKE '%xp_cmdshell%reg %' THEN 'REGISTRY_ACCESS'
    WHEN js.command LIKE '%xp_cmdshell%schtasks%' THEN 'SCHEDULED_TASK'
    WHEN js.command LIKE '%xp_cmdshell%certutil%' THEN 'CERTUTIL_DOWNLOAD'
    WHEN js.command LIKE '%xp_cmdshell%' THEN 'GENERIC_CMDSHELL'
    ELSE 'NO_CMDSHELL'
  END AS cmdshell_pattern
FROM sys.configurations c
CROSS JOIN msdb.dbo.sysjobs j
JOIN msdb.dbo.sysjobsteps js ON j.job_id = js.job_id
JOIN sys.server_principals sp ON j.owner_sid = sp.sid
WHERE c.name = 'xp_cmdshell'
  AND c.value_in_use = 1
  AND js.command LIKE '%xp_cmdshell%'
GO

/* ===== SEC-SQL-AZ-004-RC07 @ 181.214.214.98 ===== */
SELECT sp.name, sp.is_disabled,
  LOGINPROPERTY('sa', 'PasswordLastSetTime') AS sa_password_last_set,
  LOGINPROPERTY('sa', 'BadPasswordCount') AS sa_bad_password_count,
  CAST(c.value_in_use AS INT) AS xp_cmdshell_enabled
FROM sys.server_principals sp
CROSS JOIN sys.configurations c
WHERE sp.name = 'sa'
  AND sp.is_disabled = 0
  AND c.name = 'xp_cmdshell'
  AND c.value_in_use = 1
GO

/* ===== SEC-SQL-AZ-004-RC07 @ 181.214.214.98 ===== */
SELECT CAST(c.value_in_use AS INT) AS xp_cmdshell_enabled,
  sp.name AS login_name, sp.type_desc,
  sp.is_disabled,
  CASE WHEN IS_SRVROLEMEMBER('sysadmin', sp.name) = 1 THEN 'SYSADMIN'
    ELSE 'NON_SYSADMIN' END AS admin_status
FROM sys.configurations c
CROSS JOIN sys.server_principals sp
WHERE c.name = 'xp_cmdshell'
  AND c.value_in_use = 1
  AND sp.type IN ('S', 'U', 'G')
  AND sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
  AND sp.name NOT IN ('sa')
GO

/* ===== long_locks_blocker @ 181.214.214.98 ===== */
SELECT
  (SELECT cntr_value FROM sys.dm_os_performance_counters
   WHERE counter_name = 'Temp Tables Creation Rate' AND instance_name = '') AS temp_table_creation_rate,
  (SELECT SUM(reserved_page_count) * 8 / 1024 FROM tempdb.sys.dm_db_partition_stats
   WHERE object_id < 0) AS tempdb_internal_mb,
  (SELECT COUNT(*) FROM tempdb.sys.objects WHERE is_ms_shipped = 0) AS user_temp_objects,
  (SELECT SUM(size) * 8 / 1024 FROM tempdb.sys.database_files) AS tempdb_total_mb
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT
  SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_auth_only,
  sp.name, sp.type_desc,
  IS_SRVROLEMEMBER('sysadmin', sp.name) AS is_sysadmin,
  IS_SRVROLEMEMBER('securityadmin', sp.name) AS is_securityadmin,
  IS_SRVROLEMEMBER('serveradmin', sp.name) AS is_serveradmin,
  sl.is_policy_checked,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set,
  (SELECT COUNT(*) FROM sys.dm_exec_sessions WHERE login_name = sp.name) AS active_sessions
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE SERVERPROPERTY('IsIntegratedSecurityOnly') = 0
  AND sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
  AND (IS_SRVROLEMEMBER('sysadmin', sp.name) = 1
    OR IS_SRVROLEMEMBER('securityadmin', sp.name) = 1
    OR IS_SRVROLEMEMBER('serveradmin', sp.name) = 1)
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT j.name, h.message FROM msdb.dbo.sysjobs j JOIN msdb.dbo.sysjobhistory h ON j.job_id = h.job_id WHERE j.name LIKE '%backup%' AND h.run_status = 0 AND (h.message LIKE '%VSS%' OR h.message LIKE '%shadow copy%' OR h.message LIKE '%snapshot%') AND h.run_date >= CONVERT(int, CONVERT(varchar(8), DATEADD(day, -7, GETDATE()), 112))
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT TOP 10
  qs.query_hash,
  qs.total_logical_reads / NULLIF(qs.execution_count, 0) AS avg_reads,
  qs.total_elapsed_time / NULLIF(qs.execution_count, 0) / 1000 AS avg_elapsed_ms,
  p.query_plan.value('count(//RelOp[contains(@PhysicalOp,"Scan")])', 'int') AS scan_count,
  p.query_plan.value('count(//RelOp[contains(@PhysicalOp,"Seek")])', 'int') AS seek_count,
  p.query_plan.exist('//MissingIndexGroup') AS has_missing_index,
  SUBSTRING(t.text, 1, 500) AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) t
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) p
WHERE qs.total_logical_reads / NULLIF(qs.execution_count, 0) > 50000
  AND p.query_plan.value('count(//RelOp[contains(@PhysicalOp,"Scan")])', 'int') >= 2
ORDER BY qs.total_logical_reads DESC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT
  tl.request_session_id AS blocking_session_id,
  s.program_name, s.host_name,
  DATEDIFF(second, tat.transaction_begin_time, GETDATE()) AS txn_open_sec,
  COUNT(DISTINCT tl.resource_associated_entity_id) AS locked_resources,
  SUM(CASE WHEN tl.request_mode LIKE '%X%' THEN 1 ELSE 0 END) AS exclusive_locks,
  (SELECT COUNT(*) FROM sys.dm_exec_requests r WHERE r.blocking_session_id = tl.request_session_id) AS blocked_sessions
FROM sys.dm_tran_locks tl
JOIN sys.dm_exec_sessions s ON tl.request_session_id = s.session_id
JOIN sys.dm_tran_session_transactions st ON s.session_id = st.session_id
JOIN sys.dm_tran_active_transactions tat ON st.transaction_id = tat.transaction_id
WHERE s.status = 'sleeping'
  AND s.is_user_process = 1
  AND DATEDIFF(second, tat.transaction_begin_time, GETDATE()) > 60
GROUP BY tl.request_session_id, s.program_name, s.host_name, tat.transaction_begin_time
HAVING COUNT(DISTINCT tl.resource_associated_entity_id) > 0
ORDER BY blocked_sessions DESC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT TOP 10
  qs.query_hash,
  p.query_plan.value('(//RelOp[@PhysicalOp="Hash Match"]/@EstimateRows)[1]', 'float') AS output_rows,
  p.query_plan.value('(//RelOp[@PhysicalOp="Hash Match"]/RelOp[2]/@EstimateRows)[1]', 'float') AS probe_rows,
  CASE WHEN p.query_plan.value('(//RelOp[@PhysicalOp="Hash Match"]/RelOp[2]/@EstimateRows)[1]', 'float') > 0
    THEN p.query_plan.value('(//RelOp[@PhysicalOp="Hash Match"]/@EstimateRows)[1]', 'float') /
         p.query_plan.value('(//RelOp[@PhysicalOp="Hash Match"]/RelOp[2]/@EstimateRows)[1]', 'float') * 100
    ELSE 0 END AS join_selectivity_pct,
  qs.total_logical_reads / NULLIF(qs.execution_count, 0) AS avg_reads,
  qs.total_elapsed_time / NULLIF(qs.execution_count, 0) / 1000 AS avg_elapsed_ms
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) p
WHERE p.query_plan.exist('//RelOp[@PhysicalOp="Hash Match"]') = 1
  AND p.query_plan.exist('//RelOp[@PhysicalOp="Bitmap"]') = 0
  AND qs.total_logical_reads / NULLIF(qs.execution_count, 0) > 100000
ORDER BY qs.total_logical_reads DESC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT j.name AS job_name, js.step_id, js.step_name,
  js.subsystem, js.command,
  CASE
    WHEN js.command LIKE '%OPENQUERY%' OR js.command LIKE '%OPENROWSET%'
      OR js.command LIKE '%[[]%.%].%[[]%.%].%' THEN 'linked_server'
    WHEN js.command LIKE '%BACKUP%TO%DISK%=%''\\\\%' THEN 'remote_backup'
    WHEN js.command LIKE '%RESTORE%FROM%DISK%=%''\\\\%' THEN 'remote_restore'
    ELSE 'other_remote'
  END AS remote_type
FROM msdb.dbo.sysjobsteps js
JOIN msdb.dbo.sysjobs j ON js.job_id = j.job_id
WHERE js.command LIKE '%OPENQUERY%'
  OR js.command LIKE '%OPENROWSET%'
  OR js.command LIKE '%[[]%.%].%[[]%.%].%'
  OR js.command LIKE '%BACKUP%TO%DISK%=%''\\\\%'
  OR js.command LIKE '%RESTORE%FROM%DISK%=%''\\\\%'
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
EXEC sp_readerrorlog 0, 1, N'endpoint'
EXEC sp_readerrorlog 0, 1, N'connection_handshake'
EXEC sp_readerrorlog 0, 1, N'login failed for user'
EXEC sp_readerrorlog 0, 1, N'could not connect'
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
WITH log_chain AS (
  SELECT database_name, first_lsn, last_lsn, backup_start_date,
    LAG(last_lsn) OVER (PARTITION BY database_name ORDER BY backup_start_date) AS prev_last_lsn
  FROM msdb.dbo.backupset
  WHERE type = 'L' AND backup_start_date > DATEADD(day, -7, GETDATE())
)
SELECT database_name, backup_start_date, first_lsn, prev_last_lsn
FROM log_chain
WHERE prev_last_lsn IS NOT NULL AND first_lsn != prev_last_lsn
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT qs.execution_count AS [Execution Count],
(qs.total_logical_reads)*8/1024.0 AS [Total Logical Reads (MB)],
(qs.total_logical_reads/qs.execution_count)*8/1024.0 AS [Avg Logical Reads (MB)],
(qs.total_worker_time)/1000.0 AS [Total Worker Time (ms)],
(qs.total_worker_time/qs.execution_count)/1000.0 AS [Avg Worker Time (ms)],
(qs.total_elapsed_time)/1000.0 AS [Total Elapsed Time (ms)],
(qs.total_elapsed_time/qs.execution_count)/1000.0 AS [Avg Elapsed Time (ms)],
qs.creation_time AS [Creation Time]
,t.text AS [Complete Query Text]
FROM sys.dm_exec_query_stats AS qs WITH (NOLOCK)
CROSS APPLY sys.dm_exec_sql_text(plan_handle) AS t
GO

/* ===== SEC-SQL-ACC-010-RC11 @ 181.214.214.98 ===== */
SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#sensitive_cols') IS NOT NULL DROP TABLE #sensitive_cols;
CREATE TABLE #sensitive_cols (
    db_name      sysname,
    schema_name  sysname,
    table_name   sys
GO

/* ===== SEC-SQL-AZ-004-RC07 @ 181.214.214.98 ===== */
SELECT name, value_in_use, minimum, maximum,
  is_dynamic, is_advanced
FROM sys.configurations
WHERE value_in_use <> CASE
  WHEN name = 'max degree of parallelism' THEN 0
  WHEN name = 'cost threshold for parallelism' THEN 5
  WHEN name = 'max server memory (MB)' THEN 2147483647
  WHEN name = 'optimize for ad hoc workloads' THEN 0
  WHEN name = 'remote admin connections' THEN 0
  WHEN name = 'backup compression default' THEN 0
  WHEN name = 'clr enabled' THEN 0
  WHEN name = 'xp_cmdshell' THEN 0
  ELSE minimum END
ORDER BY name
GO

/* ===== Active transactions @ 181.214.214.98 ===== */
SELECT TOP 15   qs.sql_handle,   qs.total_logical_reads / NULLIF(qs.execution_count, 0) AS avg_reads,   qs.total_worker_time / NULLIF(qs.execution_count, 0) / 1000 AS avg_cpu_ms,   p.query_plan.value('count(//RelOp[@PhysicalOp="Index Scan"])', 'int') AS index_scans,   p.query_plan.value('count(//RelOp[@PhysicalOp="Clustered Index Scan"])', 'int') AS ci_scans,   p.query_plan.value('(//Warnings/PlanAffectingConvert/@ConvertIssue)[1]', 'nvarchar(100)') AS convert_issue,   t.text AS query_text FROM sys.dm_exec_query_stats qs CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) t CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) p WHERE p.query_plan.exist('//Warnings/PlanAffectingConvert') = 1   AND (p.query_plan.value('count(//RelOp[@PhysicalOp="Index Scan"])', 'int') > 0     OR p.query_plan.value('count(//RelOp[@PhysicalOp="Clustered Index Scan"])', 'int') > 0)   AND qs.execution_count > 10 ORDER BY avg_reads DESC
GO

/* ===== Active transactions @ 181.214.214.98 ===== */
SELECT TOP 10   qs.sql_handle,   qs.total_logical_reads / NULLIF(qs.execution_count, 0) AS avg_reads,   p.query_plan.value('count(//RelOp[@PhysicalOp="Index Scan" or @PhysicalOp="Clustered Index Scan"])', 'int') AS scan_ops,   p.query_plan.value('count(//RelOp[@PhysicalOp="Index Seek" or @PhysicalOp="Clustered Index Seek"])', 'int') AS seek_ops,   p.query_plan.value('(//Warnings/PlanAffectingConvert/@ConvertIssue)[1]', 'nvarchar(100)') AS convert_issue,   t.text AS query_text FROM sys.dm_exec_query_stats qs CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) t CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) p WHERE t.text LIKE '%IN%(%'   AND p.query_plan.exist('//Warnings/PlanAffectingConvert') = 1   AND p.query_plan.value('count(//RelOp[@PhysicalOp="Index Scan" or @PhysicalOp="Clustered Index Scan"])', 'int') > 0 ORDER BY avg_reads DESC
GO

/* ===== Active transactions @ 181.214.214.98 ===== */
SELECT TOP 15   qs.sql_handle,   qs.total_logical_reads / NULLIF(qs.execution_count, 0) AS avg_reads,   qs.total_elapsed_time / NULLIF(qs.execution_count, 0) / 1000 AS avg_elapsed_ms,   qs.execution_count,   p.query_plan.value('count(//ScalarOperator[contains(@ScalarString,"CONVERT_IMPLICIT") and (contains(@ScalarString,"bit") or contains(@ScalarString,"tinyint"))])', 'int') AS flag_converts,   p.query_plan.value('count(//Warnings/PlanAffectingConvert)', 'int') AS convert_warnings,   t.text AS query_text FROM sys.dm_exec_query_stats qs CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) t CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) p WHERE p.query_plan.exist('//ScalarOperator[contains(@ScalarString,"CONVERT_IMPLICIT") and (contains(@ScalarString,"bit") or contains(@ScalarString,"tinyint"))]') = 1   AND qs.execution_count > 10 ORDER BY qs.total_logical_reads DESC
GO

/* ===== Active transactions @ 181.214.214.98 ===== */
SELECT   (SELECT cntr_value FROM sys.dm_os_performance_counters    WHERE counter_name = 'Temp Tables Creation Rate' AND instance_name = '') AS temp_table_creation_rate,   (SELECT SUM(reserved_page_count) * 8 / 1024 FROM tempdb.sys.dm_db_partition_stats    WHERE object_id < 0) AS tempdb_internal_mb,   (SELECT COUNT(*) FROM tempdb.sys.objects WHERE is_ms_shipped = 0) AS user_temp_objects,   (SELECT SUM(size) * 8 / 1024 FROM tempdb.sys.database_files) AS tempdb_total_mb
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT TOP 20
  qs.query_hash,
  qs.execution_count,
  qs.total_logical_reads / NULLIF(qs.execution_count, 0) AS avg_reads,
  qs.total_elapsed_time / NULLIF(qs.execution_count, 0) / 1000 AS avg_elapsed_ms,
  p.query_plan.value('count(//RelOp[@PhysicalOp="Nested Loops"]/OuterReferences)', 'int') AS outer_ref_loops,
  p.query_plan.value('count(//RelOp[@PhysicalOp="Table Scan"])', 'int') AS table_scans,
  p.query_plan.value('count(//RelOp[@PhysicalOp="Clustered Index Scan"])', 'int') AS ci_scans,
  p.query_plan.value('count(//RelOp[@PhysicalOp="Index Scan"])', 'int') AS ix_scans,
  SUBSTRING(t.text, 1, 400) AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) t
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) p
WHERE p.query_plan.value('count(//RelOp[@PhysicalOp="Nested Loops"]/OuterReferences)', 'int') > 0
  AND (p.query_plan.value('count(//RelOp[@PhysicalOp="Table Scan"])', 'int') > 0
    OR p.query_plan.value('count(//RelOp[@PhysicalOp="Clustered Index Scan"])', 'int') > 0)
  AND qs.total_logical_reads / NULLIF(qs.execution_count, 0) > 50000
  AND qs.execution_count > 3
ORDER BY qs.total_logical_reads DESC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT TOP 20
  qs.query_hash,
  qs.execution_count,
  qs.total_logical_reads / NULLIF(qs.execution_count, 0) AS avg_reads,
  qs.total_elapsed_time / NULLIF(qs.execution_count, 0) / 1000 AS avg_elapsed_ms,
  p.query_plan.value('count(//RelOp[@PhysicalOp="Nested Loops"]/OuterReferences)', 'int') AS outer_ref_loops,
  p.query_plan.value('count(//RelOp[@PhysicalOp="Table Scan"])', 'int') +
  p.query_plan.value('count(//RelOp[@PhysicalOp="Clustered Index Scan"])', 'int') AS full_scans,
  p.query_plan.value('count(//MissingIndexGroup)', 'int') AS missing_indexes,
  SUBSTRING(t.text, 1, 400) AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) t
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) p
WHERE p.query_plan.value('count(//RelOp[@PhysicalOp="Nested Loops"]/OuterReferences)', 'int') > 0
  AND (p.query_plan.value('count(//RelOp[@PhysicalOp="Table Scan"])', 'int') > 0
    OR p.query_plan.value('count(//RelOp[@PhysicalOp="Clustered Index Scan"])', 'int') > 0
    OR p.query_plan.exist('//MissingIndexGroup') = 1)
  AND qs.total_logical_reads / NULLIF(qs.execution_count, 0) > 20000
  AND qs.execution_count > 3
ORDER BY qs.total_logical_reads DESC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT sp.name, sp.create_date,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set,
  sl.is_policy_checked, sl.is_expiration_checked
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
  AND sp.name <> 'sa'
  AND DATEDIFF(DAY, sp.create_date, GETDATE()) < 365
ORDER BY sp.create_date DESC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT servicename, status_desc, startup_type_desc, last_startup_time FROM sys.dm_server_services WHERE servicename LIKE '%Agent%' OR servicename LIKE '%SQL Server%'
GO

/* ===== SEC-SQL-ACC-010-RC11 @ 181.214.214.98 ===== */
SELECT OBJECT_SCHEMA_NAME(m.object_id) AS schema_name,
  OBJECT_NAME(m.object_id) AS proc_name,
  m.object_id
FROM sys.sql_modules m
JOIN sys.objects o ON m.object_id = o.object_id
WHERE o.type IN ('P
GO

/* ===== SEC-SQL-AZ-004-RC07 @ 181.214.214.98 ===== */
SELECT CAST(value_in_use AS INT) AS xp_cmdshell_enabled
FROM sys.configurations
WHERE name = 'xp_cmdshell'
GO

/* ===== SEC-SQL-AZ-004-RC07 @ 181.214.214.98 ===== */
SELECT CAST(c.value_in_use AS INT) AS xp_cmdshell_enabled,
  SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS server_name,
  (SELECT service_account FROM sys.dm_server_services WHERE servicename LIKE 'SQL Server%' AND servicename NOT LIKE '%Agent%') AS sql_service_account,
  (SELECT service_account FROM sys.dm_server_services WHERE servicename LIKE '%Agent%') AS agent_service_account
FROM sys.configurations c
WHERE c.name = 'xp_cmdshell'
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT DISTINCT vs.volume_mount_point, vs.logical_volume_name, CAST(vs.available_bytes / 1048576.0 AS decimal(18,2)) AS available_mb, CAST(vs.total_bytes / 1048576.0 AS decimal(18,2)) AS total_mb, CAST(100.0 * vs.available_bytes / vs.total_bytes AS decimal(5,2)) AS pct_free FROM sys.master_files mf CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) vs WHERE CAST(100.0 * vs.available_bytes / vs.total_bytes AS decimal(5,2)) < 10
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT
  SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_auth_only,
  sp.name, sp.is_disabled,
  sp.create_date, sp.modify_date,
  LOGINPROPERTY('sa', 'PasswordLastSetTime') AS sa_password_last_set,
  (SELECT create_date FROM sys.databases WHERE name = 'master') AS instance_created,
  DATEDIFF(DAY, (SELECT create_date FROM sys.databases WHERE name = 'master'),
    CAST(LOGINPROPERTY('sa', 'PasswordLastSetTime') AS datetime)) AS days_password_set_after_install
FROM sys.server_principals sp
WHERE sp.name = 'sa'
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT
  s.session_id, s.login_name, s.host_name, s.program_name,
  s.status,
  tat.transaction_begin_time,
  DATEDIFF(second, tat.transaction_begin_time, GETDATE()) AS open_duration_sec,
  s.last_request_start_time,
  s.last_request_end_time,
  DATEDIFF(second, s.last_request_end_time, GETDATE()) AS idle_since_sec,
  s.total_elapsed_time / 1000 AS total_elapsed_sec,
  s.cpu_time AS session_cpu_ms,
  dt.database_transaction_log_bytes_used AS log_bytes,
  (SELECT text FROM sys.dm_exec_sql_text(c.most_recent_sql_handle)) AS last_sql
FROM sys.dm_tran_session_transactions st
JOIN sys.dm_tran_active_transactions tat ON st.transaction_id = tat.transaction_id
JOIN sys.dm_tran_database_transactions dt ON tat.transaction_id = dt.transaction_id
JOIN sys.dm_exec_sessions s
JOIN sys.dm_exec_connections c ON s.session_id = c.session_id ON st.session_id = s.session_id
WHERE s.is_user_process = 1
  AND DATEDIFF(second, tat.transaction_begin_time, GETDATE()) > 30
  AND s.status = 'sleeping'
  AND s.cpu_time < 1000
ORDER BY open_duration_sec DESC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT rg.name AS resource_pool, rg.max_cpu_percent, rg.cap_cpu_percent, rgs.total_cpu_usage_ms, rgs.active_memgrant_count, rgs.used_memgrant_kb, rgs.max_memory_kb, rgs.used_memory_kb, rgs.target_memory_kb FROM sys.resource_governor_resource_pools rg LEFT JOIN sys.dm_resource_governor_resource_pools rgs ON rg.pool_id = rgs.pool_id
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT wait_type,
  waiting_tasks_count,
  wait_time_ms,
  wait_time_ms / NULLIF(waiting_tasks_count, 0) AS avg_wait_ms
FROM sys.dm_os_wait_stats
WHERE wait_type IN (
  'PAGEIOLATCH_SH', 'PAGEIOLATCH_EX', 'PAGEIOLATCH_UP',
  'WRITELOG', 'IO_COMPLETION', 'ASYNC_IO_COMPLETION'
)
  AND waiting_tasks_count > 0
ORDER BY wait_time_ms DESC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT name AS login_name
FROM sys.server_principals
WHERE type IN ('S', 'U', 'G') -- SQL login, Windows login, Windows group
  AND name NOT LIKE '##%'
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
CREATE TABLE #ErrorLog (LogDate DATETIME, ProcessInfo NVARCHAR(100), Text NVARCHAR(4000));
INSERT INTO #ErrorLog EXEC xp_readerrorlog 0, 1, N'Login failed';
SELECT COUNT(*) AS failed_login_count,
  MIN(LogDate) AS earliest_failure,
  MAX(LogDate) AS latest_failure
FROM #ErrorLog;
DROP TABLE #ErrorLog
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
CREATE TABLE #ErrorLog (LogDate DATETIME, ProcessInfo NVARCHAR(100), Text NVARCHAR(4000));
INSERT INTO #ErrorLog EXEC xp_readerrorlog 0, 1, N'Login failed';
SELECT COUNT(*) AS total_failures,
  COUNT(DISTINCT CASE
    WHEN Text LIKE '%[CLIENT: %' THEN SUBSTRING(Text, CHARINDEX('[CLIENT: ', Text) + 9, CHARINDEX(']', Text, CHARINDEX('[CLIENT: ', Text)) - CHARINDEX('[CLIENT: ', Text) - 9)
  END) AS distinct_source_ips
FROM #ErrorLog;
DROP TABLE #ErrorLog
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT network_subnet_ip, network_subnet_ipv4_mask,
  is_public, is_ipv4, member_name
FROM sys.dm_hadr_cluster_networks
ORDER BY network_subnet_ip
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT s.name AS schema_name, t.name AS table_name, c.name AS date_column, ty.name AS data_type, p.rows AS row_count FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id JOIN sys.columns c ON c.object_id = t.object_id JOIN sys.types ty ON ty.user_type_id = c.user_type_id JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1) WHERE t.is_ms_shipped = 0 AND ty.name IN ('datetime','datetime2','date','datetimeoffset') AND (LOWER(c.name) LIKE '%created%' OR LOWER(c.name) LIKE '%inserted%' OR LOWER(c.name) LIKE '%entry_date%' OR LOWER(c.name) LIKE '%registered%') AND p.rows > 0 AND EXISTS (SELECT 1 FROM sys.columns c2 WHERE c2.object_id = t.object_id AND (LOWER(c2.name) LIKE '%email%' OR LOWER(c2.name) LIKE '%phone%' OR LOWER(c2.name) LIKE '%ssn%' OR LOWER(c2.name) LIKE '%passport%' OR LOWER(c2.name) LIKE '%credit_card%' OR LOWER(c2.name) LIKE '%medical%' OR LOWER(c2.name) LIKE '%teudat%')) ORDER BY p.rows DESC
GO

/* ===== SEC-SQL-ACC-011-RC02 @ 181.214.214.98 ===== */
SELECT s.session_id, s.login_name, s.host_name, s.program_name, r.start_time, SUBSTRING(t.text, 1, 200) AS query_text FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON s.session_id = r.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE s.is_user_process = 1 AND (t.text LIKE '%INFORMATION_SCHEMA%' OR t.text LIKE '%sys.tables%' OR t.text LIKE '%sys.columns%' OR t.text LIKE '%sys.objects%' OR t.text LIKE '%sysobjects%' OR t.text LIKE '%syscolumns%') ORDER BY r.start_time DESC
GO

/* ===== SEC-SQL-ACC-010-RC11 @ 181.214.214.98 ===== */
SELECT
  (SELECT cntr_value FROM sys.dm_os_performance_counters
   WHERE counter_name = 'Temp Tables Creation Rate' AND instance_name = '') AS temp_table_rate,
  (SELECT COUNT(*) FROM tempdb.sys.objec
GO