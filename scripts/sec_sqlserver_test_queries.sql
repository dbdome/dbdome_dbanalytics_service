-- SEC SQL Server detection test queries (resolved). Run each batch in SSMS.

-- 493 detections, generated from rootcause.v_rootcauses


/* ===== SEC-SQL-ACC-010-RC07 — After-hours transaction activity ===== */
SELECT s.session_id, s.login_name, s.host_name, s.program_name, t.transaction_id, tat.transaction_begin_time, DATEDIFF(SECOND, tat.transaction_begin_time, GETDATE()) AS duration_seconds, DATEPART(HOUR, tat.transaction_begin_time) AS start_hour FROM sys.dm_exec_sessions s JOIN sys.dm_tran_session_transactions t ON t.session_id = s.session_id JOIN sys.dm_tran_active_transactions tat ON tat.transaction_id = t.transaction_id WHERE s.is_user_process = 1 AND (DATEPART(HOUR, tat.transaction_begin_time) < 7 OR DATEPART(HOUR, tat.transaction_begin_time) >= 19) AND s.login_name NOT IN ('sa', 'app_user', 'svc_app', 'etl_service') AND s.login_name NOT LIKE '##%' AND s.login_name NOT LIKE '%$' AND NOT (COALESCE(s.program_name, '') LIKE '%.Net SqlClient Data Provider%' OR COALESCE(s.program_name, '') LIKE '%JDBC%' OR COALESCE(s.program_name, '') LIKE '%jTDS%' OR COALESCE(s.program_name, '') LIKE '%ODBC%' OR COALESCE(s.program_name, '') LIKE 'SQLAlchemy%' OR COALESCE(s.program_name, '') LIKE 'pyodbc%' OR COALESCE(s.program_name, '') LIKE 'python%' OR COALESCE(s.program_name, '') LIKE 'PHP%' OR COALESCE(s.program_name, '') LIKE 'node%' OR (COALESCE(s.program_name, '') <> '' AND LOWER(s.login_name) LIKE '%' + LOWER(s.program_name) + '%')) ORDER BY tat.transaction_begin_time
GO

/* ===== SEC-SQL-ACC-010-RC08 — Privilege escalation attempts in transactions ===== */
SELECT s.session_id, s.login_name, s.original_login_name, s.host_name, s.program_name, p.permission_name, p.state_desc, p.class_desc FROM sys.dm_exec_sessions s CROSS APPLY (SELECT TOP 5 dp.permission_name, dp.state_desc, dp.class_desc FROM sys.database_permissions dp WHERE dp.grantee_principal_id = DATABASE_PRINCIPAL_ID(s.login_name) AND dp.state_desc = 'GRANT' AND dp.permission_name IN ('ALTER ANY USER', 'ALTER ANY ROLE', 'CONTROL', 'ALTER', 'TAKE OWNERSHIP')) p WHERE s.is_user_process = 1 AND s.original_login_name <> s.login_name ORDER BY s.session_id
GO

/* ===== SEC-SQL-ACC-010-RC09 — Data exfiltration patterns in transactions ===== */
SELECT TOP 10 s.session_id, s.login_name, s.host_name, s.program_name, r.total_elapsed_time / 1000 AS elapsed_ms, r.reads AS logical_reads, r.writes, r.row_count, SUBSTRING(t.text, (r.statement_start_offset/2)+1, ((CASE r.statement_end_offset WHEN -1 THEN DATALENGTH(t.text) ELSE r.statement_end_offset END - r.statement_start_offset)/2)+1) AS current_statement FROM sys.dm_exec_sessions s JOIN sys.dm_exec_requests r ON r.session_id = s.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE s.is_user_process = 1 AND (r.reads > 100000 OR r.row_count > 50000) ORDER BY r.reads DESC
GO

/* ===== SEC-SQL-ACC-010-RC10 — Same login active from multiple hosts ===== */
SELECT login_name, COUNT(DISTINCT host_name) AS host_count, STUFF((SELECT DISTINCT ', ' + host_name FROM
  sys.dm_exec_sessions s2 WHERE s2.login_name = s.login_name AND s2.host_name IS NOT NULL FOR XML PATH('')), 1, 2,
  '') AS hosts, COUNT(*) AS session_count FROM sys.dm_exec_sessions s WHERE is_user_process = 1 AND login_name IS NOT
  NULL AND host_name IS NOT NULL GROUP BY login_name HAVING COUNT(DISTINCT host_name) > 1 ORDER BY host_count
  DESC
GO

/* ===== SEC-SQL-ACC-010-RC11 — Schema reconnaissance activity ===== */
SELECT s.session_id, s.login_name, s.host_name, s.program_name, r.start_time, SUBSTRING(t.text, 1, 200) AS query_text FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON s.session_id = r.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE s.is_user_process = 1 AND (t.text LIKE '%INFORMATION_SCHEMA%' OR t.text LIKE '%sys.tables%' OR t.text LIKE '%sys.columns%' OR t.text LIKE '%sys.objects%' OR t.text LIKE '%sysobjects%' OR t.text LIKE '%syscolumns%') ORDER BY r.start_time DESC
GO

/* ===== SEC-SQL-ACC-010-RC12 — Dormant account suddenly active ===== */
SELECT s.login_name, s.host_name, s.program_name, s.login_time, s.last_request_start_time, sp.modify_date AS login_last_modified, DATEDIFF(DAY, sp.modify_date, GETDATE()) AS days_since_modified FROM sys.dm_exec_sessions s JOIN sys.server_principals sp ON sp.name = s.login_name WHERE s.is_user_process = 1 AND sp.is_disabled = 0 AND DATEDIFF(DAY, sp.modify_date, s.login_time) > 90 ORDER BY sp.modify_date ASC
GO

/* ===== SEC-SQL-ACC-010-RC13 — Mass data modification in transactions ===== */
SELECT s.session_id, s.login_name, s.host_name, s.program_name, t.transaction_id, tat.transaction_begin_time, DATEDIFF(SECOND, tat.transaction_begin_time, GETDATE()) AS duration_seconds, (SELECT SUM(tdt.database_transaction_log_bytes_used) FROM sys.dm_tran_database_transactions tdt WHERE tdt.transaction_id = t.transaction_id) AS log_bytes_used FROM sys.dm_exec_sessions s JOIN sys.dm_tran_session_transactions t ON t.session_id = s.session_id JOIN sys.dm_tran_active_transactions tat ON tat.transaction_id = t.transaction_id WHERE s.is_user_process = 1 ORDER BY log_bytes_used DESC
GO

/* ===== SEC-SQL-ACC-011-RC02 — Active transactions (excluding monitoring user) ===== */
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

/* ===== SEC-SQL-AU-001-RC01 — Installation defaults not changed ===== */
SELECT
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'xp_cmdshell') AS xp_cmdshell_enabled,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'remote admin connections') AS dac_remote_enabled,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'cross db ownership chaining') AS cross_db_chaining,
  (SELECT COUNT(*) FROM sys.server_principals WHERE name = 'sa' AND sid = 0x01) AS sa_not_renamed,
  (SELECT is_disabled FROM sys.server_principals WHERE name = 'BUILTIN\Administrators') AS builtin_admin_enabled
GO

/* ===== SEC-SQL-AU-001-RC02 — Installation mode misalignment ===== */
SELECT sp.name, sl.is_policy_checked, sl.is_expiration_checked,
  sp.is_disabled, sp.create_date, sp.modify_date,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set,
  LOGINPROPERTY(sp.name, 'BadPasswordCount') AS bad_password_count
FROM sys.server_principals sp
JOIN sys.sql_logins sl ON sp.principal_id = sl.principal_id
WHERE sp.type = 'S'
  AND sp.is_disabled = 0
  AND (sl.is_policy_checked = 0 OR sl.is_expiration_checked = 0)
GO

/* ===== SEC-SQL-AU-001-RC03 — Database not in protected network ===== */
SELECT TOP 20 s.session_id, s.login_name, s.host_name, c.client_net_address, s.program_name, s.login_time FROM sys.dm_exec_sessions s JOIN sys.dm_exec_connections c ON s.session_id = c.session_id WHERE s.is_user_process = 1 ORDER BY s.login_time DESC
GO

/* ===== SEC-SQL-AU-001-RC04 — Lack of post-deployment hardening checklist ===== */
SELECT
  (SELECT is_disabled FROM sys.server_principals WHERE sid = 0x01) AS sa_disabled,
  (SELECT COUNT(*) FROM sys.server_principals WHERE name = 'sa' AND sid = 0x01) AS sa_not_renamed,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'xp_cmdshell') AS xp_cmdshell,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'Ole Automation Procedures') AS ole_automation,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'clr enabled') AS clr_enabled,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'cross db ownership chaining') AS cross_db_chaining,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'Database Mail XPs') AS db_mail_xps,
  (SELECT is_disabled FROM sys.server_principals WHERE name = 'BUILTIN\Administrators') AS builtin_admin_disabled
GO

/* ===== SEC-SQL-AU-001-RC05 — Knowledge gap on account purposes ===== */
SELECT sp.name, sp.type_desc, sp.is_disabled,
  sp.create_date, sp.modify_date,
  CASE
    WHEN sp.sid = 0x01 THEN 'sa (default sysadmin)'
    WHEN sp.name = 'BUILTIN\Administrators' THEN 'Local Admins group'
    WHEN sp.name = 'NT AUTHORITY\SYSTEM' THEN 'OS System account'
    WHEN sp.name = 'NT SERVICE\MSSQLSERVER' THEN 'SQL Service account'
    WHEN sp.name = 'NT SERVICE\SQLSERVERAGENT' THEN 'Agent Service account'
    WHEN sp.name LIKE '##%##' THEN 'Internal system certificate'
    ELSE 'Custom or unknown'
  END AS account_purpose
FROM sys.server_principals sp
WHERE (sp.sid = 0x01
  OR sp.name IN ('BUILTIN\Administrators', 'NT AUTHORITY\SYSTEM')
  OR sp.name LIKE '##%##'
  OR sp.type = 'S')
  AND sp.is_disabled = 0
ORDER BY sp.type_desc, sp.name
GO

/* ===== SEC-SQL-AU-001-RC06 — Incomplete migration procedures ===== */
SELECT sp.name, sp.type_desc, sp.is_disabled,
  sp.create_date,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set
FROM sys.server_principals sp
JOIN sys.server_role_members srm ON sp.principal_id = srm.member_principal_id
JOIN sys.server_principals r ON srm.role_principal_id = r.principal_id
WHERE r.name = 'sysadmin'
  AND sp.name NOT LIKE 'NT SERVICE\%'
  AND sp.name NOT LIKE '##%##'
  AND sp.is_disabled = 0
GO

/* ===== SEC-SQL-AU-001-RC07 — Recovery procedure reliance ===== */
SELECT sp.name, sp.is_disabled,
  sl.is_policy_checked, sl.is_expiration_checked,
  LOGINPROPERTY('sa', 'PasswordLastSetTime') AS password_last_set,
  LOGINPROPERTY('sa', 'BadPasswordCount') AS bad_password_count,
  LOGINPROPERTY('sa', 'LockoutTime') AS lockout_time,
  (SELECT MAX(login_time) FROM sys.dm_exec_sessions
   WHERE original_login_name = 'sa') AS last_sa_session
FROM sys.server_principals sp
LEFT JOIN sys.sql_logins sl ON sp.principal_id = sl.principal_id
WHERE sp.sid = 0x01
  AND sp.is_disabled = 0
GO

/* ===== SEC-SQL-AU-001-RC08 — Multi-vendor environment complexity ===== */
SELECT
  SUM(CASE WHEN sp.type = 'S' AND sp.is_disabled = 0 THEN 1 ELSE 0 END) AS enabled_sql_logins,
  SUM(CASE WHEN sp.type = 'U' AND sp.is_disabled = 0 THEN 1 ELSE 0 END) AS enabled_windows_logins,
  SUM(CASE WHEN sp.type = 'G' AND sp.is_disabled = 0 THEN 1 ELSE 0 END) AS enabled_windows_groups,
  SUM(CASE WHEN sp.type = 'E' AND sp.is_disabled = 0 THEN 1 ELSE 0 END) AS enabled_external_logins,
  (SELECT is_disabled FROM sys.server_principals WHERE sid = 0x01) AS sa_disabled
FROM sys.server_principals sp
WHERE sp.name NOT LIKE '##%##'
  AND sp.name NOT LIKE 'NT %'
GO

/* ===== SEC-SQL-AU-001-RC09 — No integration with identity provisioning ===== */
SELECT sp.name, sp.type_desc, sp.create_date,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set,
  DATEDIFF(DAY, CAST(LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS DATETIME), GETDATE()) AS password_age_days,
  sl.is_policy_checked, sl.is_expiration_checked
FROM sys.server_principals sp
JOIN sys.sql_logins sl ON sp.principal_id = sl.principal_id
WHERE sp.type = 'S'
  AND sp.is_disabled = 0
  AND sp.name NOT LIKE '##%##'
  AND sp.sid <> 0x01
  AND DATEDIFF(DAY, CAST(LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS DATETIME), GETDATE()) > 90
GO

/* ===== SEC-SQL-AU-001-RC10 — Account privilege escalation over time ===== */
SELECT sp.name, sp.type_desc,
  sp.create_date,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set,
  (SELECT COUNT(*) FROM sys.server_role_members srm2
   JOIN sys.server_principals r2 ON srm2.role_principal_id = r2.principal_id
   WHERE srm2.member_principal_id = sp.principal_id) AS total_server_roles
FROM sys.server_principals sp
JOIN sys.server_role_members srm ON sp.principal_id = srm.member_principal_id
JOIN sys.server_principals r ON srm.role_principal_id = r.principal_id
WHERE r.name = 'sysadmin'
  AND sp.is_disabled = 0
  AND sp.type IN ('S', 'U')
  AND sp.name NOT LIKE 'NT SERVICE\%'
  AND sp.name NOT LIKE '##%##'
  AND sp.sid <> 0x01
GO

/* ===== SEC-SQL-AU-001-RC11 — Inadequate change control ===== */
SELECT sp.name, sp.type_desc, sp.create_date, sp.modify_date,
  DATEDIFF(DAY, sp.modify_date, GETDATE()) AS days_since_modified,
  (SELECT COUNT(*) FROM sys.server_role_members srm
   WHERE srm.member_principal_id = sp.principal_id) AS server_role_count
FROM sys.server_principals sp
WHERE sp.modify_date > DATEADD(DAY, -30, GETDATE())
  AND sp.name NOT LIKE '##%##'
  AND sp.name NOT LIKE 'NT %'
  AND sp.type IN ('S', 'U', 'G')
ORDER BY sp.modify_date DESC
GO

/* ===== SEC-SQL-AU-001-RC12 — Assumption of "unused" protection ===== */
SELECT sp.name, sp.type_desc, sp.is_disabled,
  sp.create_date, sp.modify_date,
  sl.is_policy_checked, sl.is_expiration_checked,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set,
  LOGINPROPERTY(sp.name, 'DaysUntilExpiration') AS days_until_expiration
FROM sys.server_principals sp
LEFT JOIN sys.sql_logins sl ON sp.principal_id = sl.principal_id
WHERE sp.name IN ('sa', '##MS_PolicyEventProcessingLogin##', '##MS_PolicyTsqlExecutionLogin##')
  AND sp.is_disabled = 0
GO

/* ===== SEC-SQL-AU-002-RC01 — Initialization flag usage ===== */
SELECT sp.name, sp.type_desc, sp.is_disabled,
  sp.create_date, sp.modify_date,
  sl.is_policy_checked, sl.is_expiration_checked,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE PWDCOMPARE('', sl.password_hash) = 1
  AND sp.type_desc = 'SQL_LOGIN'
GO

/* ===== SEC-SQL-AU-002-RC02 — SQL Server Windows Auth mode conversion ===== */
SELECT
  SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_auth_only,
  (SELECT COUNT(*) FROM sys.sql_logins sl
   JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
   WHERE PWDCOMPARE('', sl.password_hash) = 1
     AND sp.type_desc = 'SQL_LOGIN') AS blank_password_count,
  (SELECT COUNT(*) FROM sys.sql_logins) AS total_sql_logins
GO

/* ===== SEC-SQL-AU-002-RC03 — Installation interruption ===== */
SELECT sp.name, sp.create_date, sp.modify_date,
  sl.is_policy_checked,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set,
  (SELECT create_date FROM sys.databases WHERE name = 'master') AS instance_create_date,
  DATEDIFF(HOUR, (SELECT create_date FROM sys.databases WHERE name = 'master'), sp.create_date) AS hours_after_install
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE PWDCOMPARE('', sl.password_hash) = 1
  AND sp.type_desc = 'SQL_LOGIN'
GO

/* ===== SEC-SQL-AU-002-RC04 — Test account forgotten in production ===== */
SELECT sp.name, sp.type_desc, sp.is_disabled,
  sp.create_date,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set,
  (SELECT MAX(login_time) FROM sys.dm_exec_sessions WHERE login_name = sp.name) AS last_login,
  (SELECT COUNT(*) FROM sys.database_principals dp
   JOIN sys.databases d ON dp.name = sp.name
   WHERE dp.type = 'S') AS db_user_mappings
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE PWDCOMPARE('', sl.password_hash) = 1
  AND sp.type_desc = 'SQL_LOGIN'
GO

/* ===== SEC-SQL-AU-002-RC05 — Password never set in configuration ===== */
SELECT sp.name, sp.type_desc, sp.is_disabled,
  sp.create_date, sp.modify_date,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set,
  CASE WHEN CAST(LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS datetime)
    = sp.create_date THEN 'NEVER_CHANGED' ELSE 'CHANGED' END AS password_status
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE PWDCOMPARE('', sl.password_hash) = 1
  AND sp.type_desc = 'SQL_LOGIN'
GO

/* ===== SEC-SQL-AU-002-RC06 — Identity provisioning tool failure ===== */
SELECT sp.name, sp.create_date,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set,
  sl.is_policy_checked, sl.is_expiration_checked,
  COUNT(*) OVER (PARTITION BY CAST(sp.create_date AS date)) AS logins_created_same_day
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE PWDCOMPARE('', sl.password_hash) = 1
  AND sp.type_desc = 'SQL_LOGIN'
ORDER BY sp.create_date
GO

/* ===== SEC-SQL-AU-002-RC07 — Configuration file permission bypass ===== */
SELECT sp.name, sp.type_desc, sp.is_disabled,
  sp.create_date, sp.modify_date,
  sl.is_policy_checked, sl.is_expiration_checked,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set,
  LOGINPROPERTY(sp.name, 'BadPasswordCount') AS bad_password_attempts,
  LOGINPROPERTY(sp.name, 'IsLocked') AS is_locked
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE PWDCOMPARE('', sl.password_hash) = 1
  AND sp.type_desc = 'SQL_LOGIN'
  AND sl.is_policy_checked = 0
GO

/* ===== SEC-SQL-AU-002-RC08 — SQL Server's legacy behavior ===== */
SELECT sp.name, sp.type_desc, sp.is_disabled,
  sp.create_date, sp.modify_date,
  sl.is_policy_checked, sl.is_expiration_checked,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set,
  SERVERPROPERTY('ProductVersion') AS sql_version,
  SERVERPROPERTY('ProductLevel') AS sql_level
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE PWDCOMPARE('', sl.password_hash) = 1
  AND sp.type_desc = 'SQL_LOGIN'
GO

/* ===== SEC-SQL-AU-002-RC09 — Application provisioning defaults ===== */
SELECT sp.name, sp.type_desc, sp.is_disabled,
  sp.create_date,
  sl.is_policy_checked, sl.is_expiration_checked,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set,
  (SELECT STRING_AGG(dp.name, ', ') FROM sys.database_principals dp
   JOIN sys.databases d ON d.database_id = DB_ID()
   WHERE dp.name = sp.name AND dp.type = 'S') AS mapped_db_users
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE PWDCOMPARE('', sl.password_hash) = 1
  AND sp.type_desc = 'SQL_LOGIN'
  AND sp.name NOT IN ('sa')
  AND (sp.name LIKE '%app%' OR sp.name LIKE '%svc%' OR sp.name LIKE '%service%'
    OR sp.name LIKE '%api%' OR sp.name LIKE '%web%' OR sp.name LIKE '%batch%'
    OR sp.name LIKE '%etl%' OR sp.name LIKE '%report%')
GO

/* ===== SEC-SQL-AU-002-RC10 — LDAP/directory integration incomplete ===== */
SELECT
  sql_sp.name AS sql_login, sql_sp.create_date AS sql_created,
  sql_sp.is_disabled AS sql_disabled,
  LOGINPROPERTY(sql_sp.name, 'PasswordLastSetTime') AS password_last_set,
  (SELECT COUNT(*) FROM sys.server_principals win_sp
   WHERE win_sp.type IN ('U', 'G')
     AND win_sp.name LIKE '%' + REPLACE(sql_sp.name, '_', '%') + '%') AS possible_windows_matches
FROM sys.sql_logins sl
JOIN sys.server_principals sql_sp ON sl.principal_id = sql_sp.principal_id
WHERE PWDCOMPARE('', sl.password_hash) = 1
  AND sql_sp.type_desc = 'SQL_LOGIN'
GO

/* ===== SEC-SQL-AU-002-RC11 — Batch user creation scripts ===== */
SELECT sp.name, sp.create_date,
  sl.is_policy_checked,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set,
  COUNT(*) OVER (PARTITION BY CAST(sp.create_date AS smalldatetime)) AS batch_size
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE PWDCOMPARE('', sl.password_hash) = 1
  AND sp.type_desc = 'SQL_LOGIN'
ORDER BY sp.create_date
GO

/* ===== SEC-SQL-AU-002-RC12 — No pre-deployment security scanning ===== */
SELECT sp.name, sp.type_desc, sp.is_disabled,
  sp.create_date,
  sl.is_policy_checked, sl.is_expiration_checked,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set,
  LOGINPROPERTY(sp.name, 'IsLocked') AS is_locked,
  IS_SRVROLEMEMBER('sysadmin', sp.name) AS is_sysadmin,
  IS_SRVROLEMEMBER('securityadmin', sp.name) AS is_securityadmin,
  CASE
    WHEN sp.name = 'sa' THEN 'CRITICAL'
    WHEN IS_SRVROLEMEMBER('sysadmin', sp.name) = 1 THEN 'CRITICAL'
    WHEN IS_SRVROLEMEMBER('securityadmin', sp.name) = 1 THEN 'HIGH'
    ELSE 'MEDIUM'
  END AS severity
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE PWDCOMPARE('', sl.password_hash) = 1
  AND sp.type_desc = 'SQL_LOGIN'
GO

/* ===== SEC-SQL-AU-003-RC01 — Default configuration never modified ===== */
SELECT
  COUNT(*) AS total_sql_logins,
  SUM(CASE WHEN sl.is_policy_checked = 0 THEN 1 ELSE 0 END) AS no_policy,
  SUM(CASE WHEN sl.is_expiration_checked = 0 THEN 1 ELSE 0 END) AS no_expiration,
  SUM(CASE WHEN sl.is_policy_checked = 0 AND sl.is_expiration_checked = 0 THEN 1 ELSE 0 END) AS no_both,
  ROUND(SUM(CASE WHEN sl.is_policy_checked = 0 THEN 1.0 ELSE 0 END) / NULLIF(COUNT(*), 0) * 100, 1) AS pct_no_policy
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE sp.type_desc = 'SQL_LOGIN'
  AND sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
GO

/* ===== SEC-SQL-AU-003-RC02 — Complexity enforcement disabled intentionally ===== */
SELECT sp.name,
  PWDCOMPARE('', sl.password_hash) AS is_blank,
  PWDCOMPARE('password', sl.password_hash) AS is_password,
  PWDCOMPARE('Password1', sl.password_hash) AS is_Password1,
  PWDCOMPARE('123456', sl.password_hash) AS is_123456,
  PWDCOMPARE(sp.name, sl.password_hash) AS is_same_as_login,
  PWDCOMPARE('P@ssw0rd', sl.password_hash) AS is_Passw0rd,
  PWDCOMPARE('admin', sl.password_hash) AS is_admin,
  PWDCOMPARE('sa', sl.password_hash) AS is_sa
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE sp.type_desc = 'SQL_LOGIN'
  AND sp.is_disabled = 0
  AND sl.is_policy_checked = 0
  AND sp.name NOT LIKE '##%'
GO

/* ===== SEC-SQL-AU-003-RC03 — Legacy system requirements ===== */
SELECT sp.name, sp.type_desc, sp.is_disabled,
  sp.create_date, sp.modify_date,
  sl.is_policy_checked, sl.is_expiration_checked,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set,
  DATEDIFF(DAY, sp.create_date, GETDATE()) AS age_days,
  DATEDIFF(DAY, CAST(LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS datetime), GETDATE()) AS password_age_days
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE sp.type_desc = 'SQL_LOGIN'
  AND sp.is_disabled = 0
  AND sl.is_policy_checked = 0
  AND DATEDIFF(DAY, sp.create_date, GETDATE()) > 365
  AND sp.name NOT LIKE '##%'
GO

/* ===== SEC-SQL-AU-003-RC04 — Regulatory compliance misinterpretation ===== */
SELECT
  SUM(CASE WHEN sl.is_policy_checked = 1 AND sl.is_expiration_checked = 1 THEN 1 ELSE 0 END) AS fully_enforced,
  SUM(CASE WHEN sl.is_policy_checked = 1 AND sl.is_expiration_checked = 0 THEN 1 ELSE 0 END) AS policy_only,
  SUM(CASE WHEN sl.is_policy_checked = 0 THEN 1 ELSE 0 END) AS no_policy,
  COUNT(*) AS total_sql_logins
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE sp.type_desc = 'SQL_LOGIN'
  AND sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
GO

/* ===== SEC-SQL-AU-003-RC05 — Complexity vs. length tradeoff avoided ===== */
SELECT sp.name, sp.type_desc,
  sl.is_policy_checked, sl.is_expiration_checked,
  LEN(sp.name) AS login_name_length,
  PWDCOMPARE('', sl.password_hash) AS is_blank,
  PWDCOMPARE(sp.name, sl.password_hash) AS is_same_as_login,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE sp.type_desc = 'SQL_LOGIN'
  AND sp.is_disabled = 0
  AND sl.is_policy_checked = 0
  AND sp.name NOT LIKE '##%'
GO

/* ===== SEC-SQL-AU-003-RC06 — Performance concerns ===== */
SELECT
  SUM(CASE WHEN sl.is_policy_checked = 0 THEN 1 ELSE 0 END) AS no_policy_count,
  COUNT(*) AS total_sql_logins,
  ROUND(SUM(CASE WHEN sl.is_policy_checked = 0 THEN 1.0 ELSE 0 END) / NULLIF(COUNT(*), 0) * 100, 1) AS pct_no_policy
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE sp.type_desc = 'SQL_LOGIN'
  AND sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
GO

/* ===== SEC-SQL-AU-003-RC07 — User friction avoidance ===== */
SELECT sp.name,
  sl.is_policy_checked, sl.is_expiration_checked,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set,
  DATEDIFF(DAY, CAST(LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS datetime), GETDATE()) AS password_age_days
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE sp.type_desc = 'SQL_LOGIN'
  AND sp.is_disabled = 0
  AND sl.is_policy_checked = 0
  AND sl.is_expiration_checked = 0
  AND sp.name NOT LIKE '##%'
GO

/* ===== SEC-SQL-AU-003-RC08 — Development environment settings bleeding to production ===== */
SELECT sp.name, sp.type_desc, sp.create_date, sp.modify_date,
  sl.is_policy_checked, sl.is_expiration_checked,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set,
  LOGINPROPERTY(sp.name, 'BadPasswordCount') AS bad_password_count,
  LOGINPROPERTY(sp.name, 'IsLocked') AS is_locked
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE sp.type_desc = 'SQL_LOGIN'
  AND sp.is_disabled = 0
  AND (sl.is_policy_checked = 0 OR sl.is_expiration_checked = 0)
  AND sp.name NOT LIKE '##%'
GO

/* ===== SEC-SQL-AU-003-RC09 — No centralized policy definition ===== */
SELECT
  COUNT(*) AS total_sql_logins,
  SUM(CASE WHEN sl.is_policy_checked = 1 THEN 1 ELSE 0 END) AS policy_enforced_count,
  SUM(CASE WHEN sl.is_policy_checked = 0 THEN 1 ELSE 0 END) AS policy_not_enforced_count,
  SUM(CASE WHEN sl.is_expiration_checked = 1 THEN 1 ELSE 0 END) AS expiration_enforced_count,
  SUM(CASE WHEN sl.is_expiration_checked = 0 THEN 1 ELSE 0 END) AS expiration_not_enforced_count,
  CAST(SUM(CASE WHEN sl.is_policy_checked = 0 THEN 1 ELSE 0 END) AS FLOAT) /
    NULLIF(COUNT(*), 0) * 100 AS pct_without_policy
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE sp.type_desc = 'SQL_LOGIN'
  AND sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
GO

/* ===== SEC-SQL-AU-003-RC10 — Password manager unavailability ===== */
SELECT sp.name, sp.type_desc, sl.is_policy_checked,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set,
  PWDCOMPARE('', sl.password_hash) AS is_blank,
  PWDCOMPARE(sp.name, sl.password_hash) AS matches_login_name,
  PWDCOMPARE('password', sl.password_hash) AS pwd_password,
  PWDCOMPARE('Password1', sl.password_hash) AS pwd_Password1,
  PWDCOMPARE('P@ssw0rd', sl.password_hash) AS pwd_Passw0rd,
  PWDCOMPARE('Welcome1', sl.password_hash) AS pwd_Welcome1,
  PWDCOMPARE('Sql2016', sl.password_hash) AS pwd_Sql2016,
  PWDCOMPARE('Admin123', sl.password_hash) AS pwd_Admin123,
  PWDCOMPARE('changeme', sl.password_hash) AS pwd_changeme,
  PWDCOMPARE('Pass1234', sl.password_hash) AS pwd_Pass1234
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE sp.type_desc = 'SQL_LOGIN'
  AND sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
GO

/* ===== SEC-SQL-AU-003-RC11 — Lack of monitoring tools ===== */
SELECT
  (SELECT COUNT(*) FROM sys.server_audits WHERE is_state_enabled = 1) AS active_audits,
  (SELECT COUNT(*) FROM sys.server_audit_specifications sas
   JOIN sys.server_audits sa ON sas.audit_guid = sa.audit_guid
   WHERE sa.is_state_enabled = 1 AND sas.is_state_enabled = 1) AS active_audit_specs,
  (SELECT COUNT(*) FROM sys.server_audit_specification_details sasd
   JOIN sys.server_audit_specifications sas ON sasd.server_specification_id = sas.server_specification_id
   JOIN sys.server_audits sa ON sas.audit_guid = sa.audit_guid
   WHERE sa.is_state_enabled = 1
     AND sasd.audit_action_name IN ('FAILED_LOGIN_GROUP', 'SUCCESSFUL_LOGIN_GROUP',
       'LOGIN_CHANGE_PASSWORD_GROUP', 'SERVER_PRINCIPAL_CHANGE_GROUP')) AS login_audit_actions,
  CAST(SERVERPROPERTY('IsIntegratedSecurityOnly') AS INT) AS windows_auth_only
GO

/* ===== SEC-SQL-AU-003-RC12 — Policy documentation missing ===== */
SELECT
  sl.is_policy_checked,
  sl.is_expiration_checked,
  COUNT(*) AS login_count,
  STRING_AGG(sp.name, ', ') WITHIN GROUP (ORDER BY sp.name) AS logins
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE sp.type_desc = 'SQL_LOGIN'
  AND sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
GROUP BY sl.is_policy_checked, sl.is_expiration_checked
ORDER BY sl.is_policy_checked, sl.is_expiration_checked
GO

/* ===== SEC-SQL-AU-003-RC13 — Account creation automation without validation ===== */
SELECT sp.name, sp.type_desc, sp.create_date, sp.modify_date,
  sl.is_policy_checked, sl.is_expiration_checked,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set,
  DATEDIFF(SECOND, sp.create_date, CAST(LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS DATETIME)) AS secs_between_create_and_pwdset
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE sp.type_desc = 'SQL_LOGIN'
  AND sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
  AND sl.is_policy_checked = 0
ORDER BY sp.create_date DESC
GO

/* ===== SEC-SQL-AU-004-RC03 — OS service account access ===== */
SELECT sp.name AS login_name, sp.type_desc AS login_type, CASE WHEN IS_SRVROLEMEMBER('sysadmin', sp.name) = 1 THEN 'sysadmin' WHEN IS_SRVROLEMEMBER('securityadmin', sp.name) = 1 THEN 'securityadmin' WHEN IS_SRVROLEMEMBER('serveradmin', sp.name) = 1 THEN 'serveradmin' ELSE 'standard' END AS role_level FROM sys.server_principals sp WHERE sp.type IN ('S', 'U', 'G') AND sp.name NOT LIKE '##%' AND sp.is_disabled = 0 ORDER BY CASE WHEN IS_SRVROLEMEMBER('sysadmin', sp.name) = 1 THEN 0 ELSE 1 END, sp.name
GO

/* ===== SEC-SQL-AU-004-RC04 — OS-integrated authentication trust configuration ===== */
SELECT sp.name, sp.type_desc,
  LEFT(sp.name, CASE WHEN CHARINDEX('\', sp.name) > 0 THEN CHARINDEX('\', sp.name) - 1 ELSE LEN(sp.name) END) AS domain_name,
  IS_SRVROLEMEMBER('sysadmin', sp.name) AS is_sysadmin,
  IS_SRVROLEMEMBER('securityadmin', sp.name) AS is_securityadmin,
  IS_SRVROLEMEMBER('dbcreator', sp.name) AS is_dbcreator,
  (SELECT COUNT(*) FROM sys.database_principals dp
   JOIN sys.database_role_members drm ON dp.principal_id = drm.member_principal_id
   WHERE dp.sid = sp.sid) AS db_role_count
FROM sys.server_principals sp
WHERE sp.type_desc IN ('WINDOWS_LOGIN', 'WINDOWS_GROUP')
  AND sp.is_disabled = 0
  AND sp.name NOT LIKE 'NT %'
  AND CHARINDEX('\', sp.name) > 0
  AND LEFT(sp.name, CHARINDEX('\', sp.name) - 1) <>
    CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS NVARCHAR(128))
  AND (IS_SRVROLEMEMBER('sysadmin', sp.name) = 1
    OR IS_SRVROLEMEMBER('securityadmin', sp.name) = 1
    OR IS_SRVROLEMEMBER('dbcreator', sp.name) = 1)
GO

/* ===== SEC-SQL-AU-004-RC06 — Kerberos/SSPI authentication without encryption ===== */
SELECT
  CONNECTIONPROPERTY('net_transport') AS current_transport,
  CONNECTIONPROPERTY('protocol_type') AS current_protocol,
  CONNECTIONPROPERTY('auth_scheme') AS current_auth,
  CONNECTIONPROPERTY('encrypt_option') AS current_encrypt,
  (SELECT value_in_use FROM sys.configurations WHERE name = 'remote admin connections') AS remote_dac,
  SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_auth_only
GO

/* ===== SEC-SQL-AU-004-RC07 — Cross-system domain trusts ===== */
SELECT
  LEFT(sp.name, CHARINDEX('\', sp.name + '\') - 1) AS domain_name,
  sp.type_desc,
  COUNT(*) AS login_count,
  SUM(CASE WHEN IS_SRVROLEMEMBER('sysadmin', sp.name) = 1 THEN 1 ELSE 0 END) AS sysadmin_count,
  SUM(CASE WHEN sp.is_disabled = 0 THEN 1 ELSE 0 END) AS enabled_count
FROM sys.server_principals sp
WHERE sp.type_desc IN ('WINDOWS_LOGIN', 'WINDOWS_GROUP')
  AND sp.name LIKE '%\%'
  AND sp.name NOT LIKE 'NT %'
  AND sp.name NOT LIKE '##%'
GROUP BY LEFT(sp.name, CHARINDEX('\', sp.name + '\') - 1), sp.type_desc
HAVING COUNT(*) > 0
ORDER BY domain_name
GO

/* ===== SEC-SQL-AU-004-RC08 — No validation of OS identity ===== */
SELECT
  SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_auth_only,
  (SELECT COUNT(*) FROM sys.server_principals
   WHERE type_desc IN ('WINDOWS_LOGIN', 'WINDOWS_GROUP')
   AND is_disabled = 0 AND name NOT LIKE 'NT %') AS active_windows_logins,
  (SELECT COUNT(*) FROM sys.server_triggers
   WHERE parent_class_desc = 'SERVER' AND is_disabled = 0
   AND name LIKE '%logon%') AS active_logon_triggers,
  (SELECT COUNT(*) FROM sys.endpoints
   WHERE state_desc = 'STARTED' AND type_desc = 'TSQL'
   AND principal_id <> 1) AS restricted_endpoints
GO

/* ===== SEC-SQL-AU-004-RC10 — Assume-inside-firewall security model ===== */
SELECT
  c.client_net_address,
  c.auth_scheme,
  c.encrypt_option,
  COUNT(*) AS session_count,
  COUNT(DISTINCT s.login_name) AS distinct_logins
FROM sys.dm_exec_connections c
JOIN sys.dm_exec_sessions s ON c.session_id = s.session_id
WHERE s.is_user_process = 1
GROUP BY c.client_net_address, c.auth_scheme, c.encrypt_option
ORDER BY session_count DESC
GO

/* ===== SEC-SQL-AU-004-RC11 — LDAP with weak connection security ===== */
SELECT ls.name, ls.product, ls.provider, ls.data_source,
  ls.provider_string, ls.catalog,
  CASE WHEN ls.data_source LIKE 'LDAP://%' THEN 'LDAP_UNENCRYPTED'
       WHEN ls.data_source LIKE 'LDAPS://%' THEN 'LDAPS_ENCRYPTED'
       WHEN ls.provider LIKE '%ADsDSOObject%' THEN 'ADSI_PROVIDER'
       ELSE 'OTHER' END AS ldap_security
FROM sys.servers ls
WHERE ls.is_linked = 1
  AND (ls.provider LIKE '%ADsDSOObject%'
    OR ls.data_source LIKE '%LDAP%'
    OR ls.product LIKE '%Active Directory%')
GO

/* ===== SEC-SQL-AU-004-RC12 — No OS authentication logging ===== */
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

/* ===== SEC-SQL-AU-005-RC01 — Application compatibility requirement ===== */
SELECT
  SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_auth_only,
  CASE WHEN CAST(SERVERPROPERTY('IsIntegratedSecurityOnly') AS INT) = 0
    THEN 'MIXED_MODE' ELSE 'WINDOWS_ONLY' END AS auth_mode,
  (SELECT COUNT(*) FROM sys.sql_logins sl
   JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
   WHERE sp.type_desc = 'SQL_LOGIN' AND sp.is_disabled = 0
   AND sp.name NOT LIKE '##%' AND sp.name <> 'sa') AS active_sql_logins
GO

/* ===== SEC-SQL-AU-005-RC02 — Multi-tenancy needs ===== */
SELECT
  SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_auth_only,
  (SELECT COUNT(*) FROM sys.sql_logins sl
   JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
   WHERE sp.type_desc = 'SQL_LOGIN' AND sp.is_disabled = 0
   AND sp.name NOT LIKE '##%' AND sp.name <> 'sa') AS active_sql_logins,
  (SELECT COUNT(DISTINCT sp.default_database_name)
   FROM sys.sql_logins sl
   JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
   WHERE sp.type_desc = 'SQL_LOGIN' AND sp.is_disabled = 0
   AND sp.name NOT LIKE '##%' AND sp.name <> 'sa'
   AND sp.default_database_name NOT IN ('master', 'tempdb', 'msdb', 'model')
  ) AS distinct_default_dbs
GO

/* ===== SEC-SQL-AU-005-RC03 — Misguided "flexibility" goal ===== */
SELECT
  SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_auth_only,
  (SELECT COUNT(*) FROM sys.server_principals WHERE type IN ('U', 'G') AND is_disabled = 0) AS active_windows_logins,
  (SELECT COUNT(*) FROM sys.sql_logins sl JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id WHERE sp.is_disabled = 0 AND sp.name NOT LIKE '##%') AS active_sql_logins,
  (SELECT COUNT(*) FROM sys.sql_logins sl JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id WHERE sp.is_disabled = 0 AND sp.name NOT LIKE '##%' AND sl.is_policy_checked = 0) AS sql_logins_no_policy
GO

/* ===== SEC-SQL-AU-005-RC04 — Incomplete migration ===== */
SELECT
  SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_auth_only,
  (SELECT COUNT(*) FROM sys.server_principals WHERE type IN ('U', 'G') AND is_disabled = 0) AS active_windows_logins,
  (SELECT COUNT(*) FROM sys.sql_logins sl JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
   WHERE sp.is_disabled = 0 AND sp.name NOT LIKE '##%' AND sp.name <> 'sa') AS active_sql_logins
GO

/* ===== SEC-SQL-AU-005-RC05 — External contractor access ===== */
SELECT
  SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_auth_only,
  sp.name, sp.type_desc, sp.create_date, sp.is_disabled,
  sl.is_policy_checked, sl.is_expiration_checked,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set,
  (SELECT MAX(login_time) FROM sys.dm_exec_sessions WHERE login_name = sp.name) AS last_session
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE SERVERPROPERTY('IsIntegratedSecurityOnly') = 0
  AND sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
  AND sp.name <> 'sa'
  AND (sp.name LIKE '%contractor%' OR sp.name LIKE '%vendor%' OR sp.name LIKE '%extern%'
    OR sp.name LIKE '%consult%' OR sp.name LIKE '%partner%' OR sp.name LIKE '%3rd%'
    OR sp.name LIKE '%third%' OR sp.name LIKE '%guest%' OR sp.name LIKE '%temp_%')
GO

/* ===== SEC-SQL-AU-005-RC06 — Development environment consistency ===== */
SELECT
  SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_auth_only,
  SERVERPROPERTY('ServerName') AS server_name,
  sp.name, sp.type_desc, sp.create_date,
  sl.is_policy_checked, sl.is_expiration_checked,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE SERVERPROPERTY('IsIntegratedSecurityOnly') = 0
  AND sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
  AND (sp.name LIKE '%dev%' OR sp.name LIKE '%debug%' OR sp.name LIKE '%local%'
    OR sp.name LIKE '%test%' OR sp.name LIKE '%staging%' OR sp.name LIKE '%qa%')
GO

/* ===== SEC-SQL-AU-005-RC07 — Post-installation guidance misunderstood ===== */
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

/* ===== SEC-SQL-AU-005-RC08 — Service account password storage ===== */
SELECT
  SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_auth_only,
  sp.name, sp.type_desc, sp.create_date,
  sl.is_policy_checked, sl.is_expiration_checked,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set,
  DATEDIFF(DAY, CAST(LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS datetime), GETDATE()) AS password_age_days,
  (SELECT COUNT(*) FROM sys.dm_exec_sessions WHERE login_name = sp.name AND is_user_process = 1) AS active_sessions
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE SERVERPROPERTY('IsIntegratedSecurityOnly') = 0
  AND sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
  AND sp.name <> 'sa'
  AND (sp.name LIKE '%svc%' OR sp.name LIKE '%service%' OR sp.name LIKE '%app%'
    OR sp.name LIKE '%api%' OR sp.name LIKE '%web%' OR sp.name LIKE '%batch%'
    OR sp.name LIKE '%etl%' OR sp.name LIKE '%job%')
GO

/* ===== SEC-SQL-AU-005-RC09 — No policy mandating Windows Auth ===== */
SELECT
  SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_auth_only,
  (SELECT COUNT(*) FROM sys.sql_logins sl
   JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
   WHERE sp.is_disabled = 0 AND sp.name NOT LIKE '##%') AS active_sql_logins,
  (SELECT COUNT(DISTINCT login_name) FROM sys.dm_exec_sessions
   WHERE is_user_process = 1
     AND login_name IN (SELECT sp.name FROM sys.sql_logins sl JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id)) AS sql_logins_with_sessions,
  (SELECT COUNT(*) FROM sys.server_principals WHERE type IN ('U', 'G') AND is_disabled = 0) AS active_windows_logins
GO

/* ===== SEC-SQL-AU-005-RC10 — Lateral movement not considered ===== */
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

/* ===== SEC-SQL-AU-005-RC11 — Kerberos delegation configuration complexity ===== */
SELECT
  SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_auth_only,
  (SELECT auth_scheme FROM sys.dm_exec_connections WHERE session_id = @@SPID) AS current_auth_scheme,
  (SELECT COUNT(*) FROM sys.dm_exec_connections WHERE auth_scheme = 'KERBEROS' AND parent_connection_id IS NULL) AS kerberos_connections,
  (SELECT COUNT(*) FROM sys.dm_exec_connections WHERE auth_scheme = 'NTLM' AND parent_connection_id IS NULL) AS ntlm_connections,
  (SELECT COUNT(*) FROM sys.dm_exec_connections WHERE auth_scheme = 'SQL' AND parent_connection_id IS NULL) AS sql_auth_connections
GO

/* ===== SEC-SQL-AU-005-RC12 — Application connection string defaults ===== */
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

/* ===== SEC-SQL-AU-005-RC13 — No automated compliance scanning ===== */
SELECT
  SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_auth_only,
  SERVERPROPERTY('ProductVersion') AS sql_version,
  (SELECT COUNT(*) FROM sys.sql_logins sl
   JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
   WHERE sp.is_disabled = 0 AND sp.name NOT LIKE '##%') AS active_sql_logins,
  (SELECT COUNT(*) FROM sys.server_audits WHERE is_state_enabled = 1) AS active_audits,
  (SELECT COUNT(*) FROM sys.server_audit_specifications WHERE is_state_enabled = 1) AS active_audit_specs
GO

/* ===== SEC-SQL-AU-006-RC01 — No activity monitoring ===== */
SELECT
  (SELECT COUNT(*) FROM sys.server_audits WHERE is_state_enabled = 1) AS active_audits,
  (SELECT COUNT(*) FROM sys.server_audit_specifications sas
   JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
   WHERE sas.is_state_enabled = 1
     AND sasd.audit_action_name IN ('SUCCESSFUL_LOGIN_GROUP', 'FAILED_LOGIN_GROUP', 'LOGIN_CHANGE_PASSWORD_GROUP')) AS login_tracking_actions,
  CAST(SERVERPROPERTY('IsIntegratedSecurityOnly') AS int) AS windows_auth_only
GO

/* ===== SEC-SQL-AU-006-RC02 — Offboarding process incomplete ===== */
SELECT sp.name, sp.type_desc, sp.create_date, sp.modify_date,
  sp.is_disabled,
  (SELECT MAX(login_time) FROM sys.dm_exec_sessions WHERE login_name = sp.name) AS last_session_time,
  DATEDIFF(DAY, sp.create_date, GETDATE()) AS account_age_days,
  CASE WHEN sp.type = 'S'
    THEN DATEDIFF(DAY, CAST(LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS datetime), GETDATE())
    ELSE NULL END AS password_age_days
FROM sys.server_principals sp
WHERE sp.type IN ('S', 'U')
  AND sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
  AND sp.name NOT LIKE 'NT %'
  AND sp.name NOT IN ('sa')
  AND sp.name NOT LIKE '%svc%'
  AND sp.name NOT LIKE '%service%'
  AND sp.name NOT LIKE '%app%'
GO

/* ===== SEC-SQL-AU-006-RC03 — Service account lifecycle unknown ===== */
SELECT sp.name, sp.type_desc, sp.create_date, sp.modify_date,
  sp.is_disabled,
  CASE WHEN sp.type = 'S'
    THEN DATEDIFF(DAY, CAST(LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS datetime), GETDATE())
    ELSE NULL END AS password_age_days,
  (SELECT MAX(login_time) FROM sys.dm_exec_sessions WHERE login_name = sp.name) AS last_session,
  DATEDIFF(DAY, sp.create_date, GETDATE()) AS account_age_days
FROM sys.server_principals sp
LEFT JOIN sys.sql_logins sl ON sp.principal_id = sl.principal_id
WHERE sp.type IN ('S', 'U')
  AND sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
  AND sp.name NOT LIKE 'NT %'
  AND sp.name <> 'sa'
  AND (sp.name LIKE '%svc%' OR sp.name LIKE '%service%' OR sp.name LIKE '%app%'
    OR sp.name LIKE '%job%' OR sp.name LIKE '%batch%' OR sp.name LIKE '%etl%'
    OR sp.name LIKE '%agent%' OR sp.name LIKE '%daemon%' OR sp.name LIKE '%sys%')
ORDER BY sp.create_date ASC
GO

/* ===== SEC-SQL-AU-006-RC04 — Contractor account cleanup forgotten ===== */
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

/* ===== SEC-SQL-AU-006-RC05 — Temporary project access never revoked ===== */
SELECT sp.name, sp.type_desc, sp.create_date,
  sl.is_expiration_checked,
  DATEDIFF(DAY, sp.create_date, GETDATE()) AS account_age_days,
  DATEDIFF(DAY, sp.modify_date, GETDATE()) AS days_since_modified,
  (SELECT MAX(login_time) FROM sys.dm_exec_sessions WHERE login_name = sp.name) AS last_session
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
  AND sp.name <> 'sa'
  AND sl.is_expiration_checked = 0
  AND (SELECT MAX(login_time) FROM sys.dm_exec_sessions WHERE login_name = sp.name) IS NULL
  AND DATEDIFF(DAY, sp.modify_date, GETDATE()) > 90
GO

/* ===== SEC-SQL-AU-006-RC06 — Test/dev accounts migrated to production ===== */
SELECT sp.name, sp.type_desc, sp.create_date, sp.modify_date,
  sp.is_disabled,
  CASE WHEN sp.type = 'S' THEN sl.is_policy_checked ELSE NULL END AS policy_enforced,
  CASE WHEN sp.type = 'S' THEN sl.is_expiration_checked ELSE NULL END AS expiration_enforced,
  CASE WHEN sp.type = 'S'
    THEN LOGINPROPERTY(sp.name, 'PasswordLastSetTime') ELSE NULL END AS password_last_set,
  (SELECT MAX(login_time) FROM sys.dm_exec_sessions WHERE login_name = sp.name) AS last_session,
  IS_SRVROLEMEMBER('sysadmin', sp.name) AS is_sysadmin
FROM sys.server_principals sp
LEFT JOIN sys.sql_logins sl ON sp.principal_id = sl.principal_id
WHERE sp.type IN ('S', 'U')
  AND sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
  AND sp.name NOT LIKE 'NT %'
  AND (sp.name LIKE '%test%' OR sp.name LIKE '%dev%' OR sp.name LIKE '%debug%'
    OR sp.name LIKE '%qa%' OR sp.name LIKE '%staging%' OR sp.name LIKE '%demo%'
    OR sp.name LIKE '%sample%' OR sp.name LIKE '%sandbox%' OR sp.name LIKE '%local%')
GO

/* ===== SEC-SQL-AU-006-RC07 — No formal account inventory ===== */
SELECT
  COUNT(*) AS total_logins,
  SUM(CASE WHEN sp.is_disabled = 0 THEN 1 ELSE 0 END) AS enabled_logins,
  SUM(CASE WHEN sp.is_disabled = 1 THEN 1 ELSE 0 END) AS disabled_logins,
  SUM(CASE WHEN sp.type = 'S' AND sp.is_disabled = 0 THEN 1 ELSE 0 END) AS active_sql_logins,
  SUM(CASE WHEN sp.type IN ('U', 'G') AND sp.is_disabled = 0 THEN 1 ELSE 0 END) AS active_windows_logins,
  SUM(CASE WHEN sp.is_disabled = 0 AND ls.last_login IS NULL THEN 1 ELSE 0 END) AS enabled_no_session,
  MIN(sp.create_date) AS oldest_login_date,
  MAX(sp.create_date) AS newest_login_date
FROM sys.server_principals sp
LEFT JOIN (SELECT login_name, MAX(login_time) AS last_login FROM sys.dm_exec_sessions GROUP BY login_name) ls ON ls.login_name = sp.name
WHERE sp.type IN ('S', 'U', 'G')
  AND sp.name NOT LIKE '##%'
  AND sp.name NOT LIKE 'NT %'
  AND sp.name NOT IN ('sa')
GO

/* ===== SEC-SQL-AU-006-RC08 — HR/Identity integration absent ===== */
SELECT
  (SELECT COUNT(*) FROM sys.server_principals WHERE type = 'S' AND is_disabled = 0 AND name NOT LIKE '##%' AND name <> 'sa') AS active_sql_logins,
  (SELECT COUNT(*) FROM sys.server_principals WHERE type IN ('U', 'G') AND is_disabled = 0 AND name NOT LIKE 'NT %') AS active_windows_logins,
  (SELECT COUNT(*) FROM sys.server_principals WHERE type = 'S' AND is_disabled = 0 AND name NOT LIKE '##%' AND name <> 'sa'
    AND (SELECT MAX(login_time) FROM sys.dm_exec_sessions WHERE login_name = sys.server_principals.name) IS NULL) AS sql_logins_no_session,
  SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_auth_only
GO

/* ===== SEC-SQL-AU-006-RC09 — Quarterly reviews too infrequent ===== */
SELECT
  (SELECT COUNT(*) FROM sys.server_principals
   WHERE type IN ('S', 'U', 'G') AND is_disabled = 0
     AND name NOT LIKE '##%' AND name NOT LIKE 'NT %') AS total_active_logins,
  (SELECT COUNT(*) FROM sys.server_principals
   WHERE type IN ('S', 'U', 'G') AND is_disabled = 0
     AND name NOT LIKE '##%' AND name NOT LIKE 'NT %'
     AND DATEDIFF(DAY, create_date, GETDATE()) < 90) AS created_last_quarter,
  (SELECT COUNT(*) FROM sys.server_principals sp
   WHERE sp.type IN ('S', 'U', 'G') AND sp.is_disabled = 0
     AND sp.name NOT LIKE '##%' AND sp.name NOT LIKE 'NT %'
     AND (SELECT MAX(login_time) FROM sys.dm_exec_sessions WHERE login_name = sp.name) IS NULL
     AND DATEDIFF(DAY, sp.modify_date, GETDATE()) > 90) AS dormant_over_90_days
GO

/* ===== SEC-SQL-AU-006-RC10 — Shared service accounts misclassified ===== */
SELECT sp.name AS login_name, sp.type_desc,
  (SELECT COUNT(DISTINCT s.host_name) FROM sys.dm_exec_sessions s
   WHERE s.login_name = sp.name AND s.is_user_process = 1) AS distinct_hosts,
  STRING_AGG(srm.role_principal_id, ',') AS server_role_ids,
  (SELECT COUNT(*) FROM sys.server_role_members rm2
   JOIN sys.server_principals sr ON rm2.role_principal_id = sr.principal_id
   WHERE rm2.member_principal_id = sp.principal_id
     AND sr.name IN ('sysadmin','securityadmin','serveradmin','dbcreator')) AS privileged_roles
FROM sys.server_principals sp
LEFT JOIN sys.server_role_members srm ON sp.principal_id = srm.member_principal_id
WHERE sp.type IN ('S', 'U', 'G')
  AND sp.is_disabled = 0
  AND (SELECT COUNT(DISTINCT s.host_name) FROM sys.dm_exec_sessions s
       WHERE s.login_name = sp.name AND s.is_user_process = 1) > 1
GROUP BY sp.name, sp.type_desc, sp.principal_id
GO

/* ===== SEC-SQL-AU-006-RC11 — Account ownership unclear ===== */
SELECT sp.name AS login_name, sp.type_desc,
  sp.create_date, sp.modify_date, sp.is_disabled,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set,
  CASE WHEN sp.name LIKE 'svc_%' OR sp.name LIKE 'app_%' THEN 'service_pattern'
       WHEN sp.name LIKE 'sa' OR sp.name LIKE '##%' THEN 'system_account'
       WHEN sp.type_desc = 'WINDOWS_LOGIN' THEN 'windows_login'
       ELSE 'unknown_ownership' END AS ownership_classification
FROM sys.server_principals sp
WHERE sp.type IN ('S', 'U', 'G')
  AND sp.is_disabled = 0
  AND sp.principal_id > 10
  AND sp.name NOT LIKE '##%'
GO

/* ===== SEC-SQL-AU-006-RC12 — No automated dormancy detection ===== */
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

/* ===== SEC-SQL-AU-006-RC13 — Privilege accumulation over time ===== */
SELECT sp.name AS login_name, sp.type_desc,
  sp.create_date, sp.is_disabled,
  COUNT(srm.role_principal_id) AS server_role_count,
  STRING_AGG(sr.name, ', ') AS server_roles
FROM sys.server_principals sp
JOIN sys.server_role_members srm ON sp.principal_id = srm.member_principal_id
JOIN sys.server_principals sr ON srm.role_principal_id = sr.principal_id
WHERE sp.type IN ('S', 'U', 'G')
  AND sp.is_disabled = 0
  AND sp.principal_id > 10
GROUP BY sp.name, sp.type_desc, sp.create_date, sp.is_disabled
HAVING COUNT(srm.role_principal_id) > 2
ORDER BY server_role_count DESC
GO

/* ===== SEC-SQL-AU-006-RC14 — Audit trails insufficient ===== */
SELECT
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'login auditing') AS login_audit_level,
  (SELECT COUNT(*) FROM sys.server_audits WHERE is_state_enabled = 1) AS active_audits,
  (SELECT COUNT(*) FROM sys.server_audit_specifications sas
   JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
   WHERE sas.is_state_enabled = 1
     AND sasd.audit_action_name = 'SUCCESSFUL_LOGIN_GROUP') AS success_login_audit,
  (SELECT COUNT(*) FROM sys.server_event_sessions ses
   JOIN sys.server_event_session_events sese ON ses.event_session_id = sese.event_session_id
   WHERE ses.startup_state = 1
     AND sese.name IN ('audit_login', 'login')) AS xe_login_tracking,
  (SELECT COUNT(*) FROM sys.dm_xe_sessions) AS active_xe_sessions
GO

/* ===== SEC-SQL-AU-006-RC15 — Remediation effort underestimated ===== */
SELECT
  COUNT(*) AS total_active_logins,
  SUM(CASE WHEN s.login_name IS NULL THEN 1 ELSE 0 END) AS logins_no_current_session,
  SUM(CASE WHEN DATEDIFF(DAY,
    COALESCE(CAST(LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS DATETIME), sp.modify_date),
    GETDATE()) > 180 THEN 1 ELSE 0 END) AS logins_stale_password,
  SUM(CASE WHEN sp.create_date < DATEADD(YEAR, -1, GETDATE()) THEN 1 ELSE 0 END) AS logins_older_than_1yr
FROM sys.server_principals sp
LEFT JOIN (SELECT DISTINCT login_name FROM sys.dm_exec_sessions WHERE is_user_process = 1) s
  ON s.login_name = sp.name
WHERE sp.type IN ('S', 'U', 'G')
  AND sp.is_disabled = 0
  AND sp.principal_id > 10
  AND sp.name NOT LIKE '##%'
GO

/* ===== SEC-SQL-AU-007-RC02 — Administrator convenience during setup ===== */
SELECT
  SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_only_auth,
  (SELECT is_disabled FROM sys.server_principals WHERE name = 'sa') AS sa_disabled,
  (SELECT LOGINPROPERTY('sa', 'PasswordLastSetTime')) AS sa_password_last_set,
  (SELECT is_policy_checked FROM sys.sql_logins WHERE name = 'sa') AS sa_policy_enforced,
  (SELECT is_expiration_checked FROM sys.sql_logins WHERE name = 'sa') AS sa_expiration_enforced
GO

/* ===== SEC-SQL-AU-007-RC04 — Development environment settings ===== */
SELECT
  SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_only_auth,
  (SELECT is_disabled FROM sys.server_principals WHERE name = 'sa') AS sa_disabled,
  (SELECT COUNT(*) FROM sys.sql_logins sl
   JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
   WHERE sp.is_disabled = 0 AND sl.is_policy_checked = 0
     AND sp.name NOT LIKE '##%') AS logins_no_policy,
  (SELECT COUNT(*) FROM sys.database_principals
   WHERE name = 'guest' AND type = 'S'
     AND 1 = 1
     AND principal_id = 2) AS guest_enabled_in_current_db,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations
   WHERE name = 'remote admin connections') AS dac_enabled
GO

/* ===== SEC-SQL-AU-007-RC05 — Remote access addition overlooked ===== */
SELECT
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'remote access') AS remote_access,
  CONNECTIONPROPERTY('encrypt_option') AS current_encrypt_option,
  (SELECT COUNT(*) FROM sys.dm_exec_connections WHERE encrypt_option = 'FALSE') AS unencrypted_connections,
  (SELECT COUNT(*) FROM sys.dm_exec_connections WHERE encrypt_option = 'TRUE') AS encrypted_connections,
  (SELECT COUNT(*) FROM sys.endpoints WHERE protocol_desc = 'TCP'
    AND type_desc <> 'TSQL') AS tcp_endpoints_non_default
GO

/* ===== SEC-SQL-AU-007-RC06 — Incomplete hardening documentation ===== */
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

/* ===== SEC-SQL-AU-007-RC07 — Configuration file management tools ===== */
SELECT
  (SELECT COUNT(*) FROM sys.configurations
   WHERE value <> value_in_use) AS pending_config_changes,
  (SELECT COUNT(*) FROM msdb.dbo.sysjobs j
   JOIN msdb.dbo.sysjobsteps js ON j.job_id = js.job_id
   WHERE j.enabled = 1
     AND (js.command LIKE '%sp_configure%'
       OR js.command LIKE '%RECONFIGURE%'
       OR js.command LIKE '%ALTER LOGIN%'
       OR js.command LIKE '%ALTER SERVER CONFIGURATION%')) AS config_modifying_jobs,
  (SELECT TOP 1 t.text FROM sys.dm_exec_connections c
   CROSS APPLY sys.dm_exec_sql_text(c.most_recent_sql_handle) t
   WHERE t.text LIKE '%sp_configure%' OR t.text LIKE '%RECONFIGURE%'
   ORDER BY c.connect_time DESC) AS recent_config_sql
GO

/* ===== SEC-SQL-AU-007-RC09 — Recovery procedure reliance ===== */
SELECT
  (SELECT is_disabled FROM sys.server_principals WHERE name = 'sa') AS sa_disabled,
  (SELECT LOGINPROPERTY('sa', 'PasswordLastSetTime')) AS sa_password_last_set,
  (SELECT modify_date FROM sys.server_principals WHERE name = 'sa') AS sa_last_modified,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'remote admin connections') AS remote_dac_enabled,
  (SELECT COUNT(*) FROM sys.server_principals
   WHERE type_desc = 'SQL_LOGIN' AND is_disabled = 0
     AND create_date > DATEADD(DAY, -30, GETDATE())
     AND name NOT LIKE '##%') AS recent_sql_logins_created
GO

/* ===== SEC-SQL-AU-007-RC10 — Container/Kubernetes secrets practice ===== */
SELECT sp.name AS login_name, sp.type_desc, c.auth_scheme, CASE WHEN IS_SRVROLEMEMBER('sysadmin', sp.name) = 1 THEN 'EXCESSIVE' WHEN IS_SRVROLEMEMBER('securityadmin', sp.name) = 1 THEN 'ELEVATED' ELSE 'STANDARD' END AS privilege_level FROM sys.server_principals sp LEFT JOIN sys.dm_exec_connections c ON sp.sid = SUSER_SID(sp.name) WHERE sp.type = 'S' AND sp.is_disabled = 0 AND sp.name NOT LIKE '##%'
GO

/* ===== SEC-SQL-AU-007-RC11 — Single-node assumption ===== */
SELECT
  SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_only_auth,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'remote admin connections') AS remote_dac,
  (SELECT COUNT(*) FROM sys.dm_exec_connections WHERE encrypt_option = 'FALSE'
    AND client_net_address <> '<local machine>') AS unencrypted_remote_connections,
  (SELECT COUNT(*) FROM sys.server_principals WHERE type_desc = 'SQL_LOGIN'
    AND is_disabled = 0 AND name NOT LIKE '##%') AS active_sql_logins,
  (SELECT is_disabled FROM sys.server_principals WHERE name = 'sa') AS sa_disabled
GO

/* ===== SEC-SQL-AU-007-RC12 — Administrator password forgotten or locked ===== */
SELECT
  (SELECT name FROM sys.server_principals WHERE name = 'sa') AS sa_exists,
  (SELECT is_disabled FROM sys.server_principals WHERE name = 'sa') AS sa_disabled,
  (SELECT LOGINPROPERTY('sa', 'PasswordLastSetTime')) AS sa_password_last_set,
  (SELECT modify_date FROM sys.server_principals WHERE name = 'sa') AS sa_modified,
  (SELECT COUNT(*) FROM sys.server_principals sp
   JOIN sys.server_role_members srm ON sp.principal_id = srm.member_principal_id
   JOIN sys.server_principals sr ON srm.role_principal_id = sr.principal_id
   WHERE sr.name = 'sysadmin' AND sp.type_desc = 'SQL_LOGIN'
     AND sp.is_disabled = 0 AND sp.name NOT LIKE '##%') AS active_sysadmin_sql_logins
GO

/* ===== SEC-SQL-AU-007-RC13 — Documentation templates outdated ===== */
SELECT
  SERVERPROPERTY('ProductVersion') AS sql_version,
  SERVERPROPERTY('ProductLevel') AS service_pack,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'remote access') AS remote_access_legacy,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'scan for startup procs') AS scan_startup_procs,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'allow updates') AS allow_direct_updates,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'default trace enabled') AS default_trace,
  (SELECT COUNT(*) FROM sys.server_principals
   WHERE type_desc = 'SQL_LOGIN' AND is_disabled = 0
     AND name NOT LIKE '##%'
     AND (SELECT is_policy_checked FROM sys.sql_logins sl WHERE sl.principal_id = sys.server_principals.principal_id) = 0) AS logins_no_policy,
  SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_only_auth
GO

/* ===== SEC-SQL-AU-007-RC14 — No configuration drift detection ===== */
SELECT
  (SELECT COUNT(*) FROM msdb.dbo.syspolicy_policies WHERE is_enabled = 1) AS active_policies,
  (SELECT COUNT(*) FROM msdb.dbo.syspolicy_policies p
   JOIN msdb.dbo.syspolicy_policy_categories pc ON p.policy_category_id = pc.policy_category_id
   WHERE p.is_enabled = 1
     AND (pc.name LIKE '%security%' OR pc.name LIKE '%Surface Area%'
       OR p.name LIKE '%security%' OR p.name LIKE '%password%')) AS security_policies,
  (SELECT COUNT(*) FROM msdb.dbo.syspolicy_system_health_state
   WHERE result = 0) AS policy_violations
GO

/* ===== SEC-SQL-AUD-001-RC01 — Global logging switch is disabled ===== */
SELECT sa.name AS audit_name, sa.is_state_enabled AS audit_enabled,
  sas.name AS server_spec_name, sas.is_state_enabled AS spec_enabled
FROM sys.server_audits sa
LEFT JOIN sys.server_audit_specifications sas
  ON sa.audit_guid = sas.audit_guid
UNION ALL
SELECT sa.name, sa.is_state_enabled,
  das.name AS db_spec_name, das.is_state_enabled
FROM sys.server_audits sa
LEFT JOIN sys.database_audit_specifications das
  ON sa.audit_guid = das.audit_guid
GO

/* ===== SEC-SQL-AUD-001-RC02 — Missing audit plugin/extension ===== */
SELECT sa.name AS audit_name, sa.is_state_enabled,
  sa.type_desc AS destination,
  (SELECT COUNT(*) FROM sys.server_audit_specifications sas
   WHERE sas.audit_guid = sa.audit_guid
     AND sas.is_state_enabled = 1) AS active_server_specs,
  (SELECT COUNT(*) FROM sys.database_audit_specifications das
   WHERE das.audit_guid = sa.audit_guid
     AND das.is_state_enabled = 1) AS active_db_specs
FROM sys.server_audits sa
WHERE sa.is_state_enabled = 1
GO

/* ===== SEC-SQL-AUD-001-RC03 — Audit policy set to "NONE" ===== */
SELECT sas.name AS spec_name, sas.is_state_enabled,
  COUNT(sasd.audit_action_id) AS action_group_count,
  STRING_AGG(sasd.audit_action_name, ', ') AS actions
FROM sys.server_audit_specifications sas
LEFT JOIN sys.server_audit_specification_details sasd
  ON sas.server_specification_id = sasd.server_specification_id
WHERE sas.is_state_enabled = 1
GROUP BY sas.name, sas.is_state_enabled
GO

/* ===== SEC-SQL-AUD-001-RC04 — License restrictions ===== */
SELECT SERVERPROPERTY('Edition') AS edition,
  SERVERPROPERTY('ProductVersion') AS version,
  SERVERPROPERTY('ProductLevel') AS service_pack,
  SERVERPROPERTY('EngineEdition') AS engine_edition,
  CASE
    WHEN SERVERPROPERTY('EngineEdition') = 1 THEN 'Personal/Desktop - NO AUDIT'
    WHEN SERVERPROPERTY('EngineEdition') = 2 THEN 'Standard - Limited Audit (server-level only pre-2016 SP1)'
    WHEN SERVERPROPERTY('EngineEdition') = 3 THEN 'Enterprise - Full Audit'
    WHEN SERVERPROPERTY('EngineEdition') = 4 THEN 'Express - NO SQL Server Audit'
    WHEN SERVERPROPERTY('EngineEdition') = 5 THEN 'Azure SQL - Uses Azure Auditing'
    ELSE 'Unknown'
  END AS audit_capability
GO

/* ===== SEC-SQL-AUD-001-RC05 — Service account permission failures ===== */
SELECT sa.name, sfa.log_file_path,
  sa.on_failure_desc, sa.is_state_enabled,
  sa.type_desc AS log_type
FROM sys.server_audits sa
LEFT JOIN sys.server_file_audits sfa ON sa.audit_id = sfa.audit_id
WHERE sa.type_desc = 'FILE'
  AND (sa.is_state_enabled = 0
    OR sa.on_failure_desc = 'SHUTDOWN')
GO

/* ===== SEC-SQL-AUD-001-RC06 — Performance-based disablement ===== */
SELECT sa.name, sa.queue_delay,
  sa.type_desc,
  CASE
    WHEN sa.queue_delay = 0 THEN 'SYNCHRONOUS (highest impact)'
    WHEN sa.queue_delay = 1000 THEN 'DEFAULT (1 second buffer)'
    WHEN sa.queue_delay > 1000 THEN 'RELAXED (reduced accuracy for performance)'
    ELSE 'CUSTOM'
  END AS delay_assessment
FROM sys.server_audits sa
GO

/* ===== SEC-SQL-AUD-001-RC07 — Misconfigured log destination ===== */
SELECT a.name AS audit_name, a.type_desc, CASE WHEN a.is_state_enabled = 1 THEN 'ENABLED' ELSE 'DISABLED' END AS status, a.on_failure_desc, a.queue_delay, sfa.log_file_path AS audit_file_path, sfa.max_file_size, sfa.max_rollover_files FROM sys.server_audits a LEFT JOIN sys.server_file_audits sfa ON a.audit_id = sfa.audit_id
GO

/* ===== SEC-SQL-AUD-001-RC08 — Default "Secure by Default" settings ===== */
SELECT
  (SELECT COUNT(*) FROM sys.server_audits) AS audit_count,
  (SELECT COUNT(*) FROM sys.server_audit_specifications) AS server_spec_count,
  (SELECT COUNT(*) FROM sys.database_audit_specifications) AS db_spec_count,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations
   WHERE name = 'c2 audit mode') AS c2_audit,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations
   WHERE name = 'common criteria compliance enabled') AS common_criteria
GO

/* ===== SEC-SQL-AUD-001-RC09 — Conflicting configuration files ===== */
SELECT sa.name AS audit_name, sa.is_state_enabled,
  sa.type_desc AS destination,
  sa.on_failure_desc,
  (SELECT COUNT(*) FROM sys.server_audit_specifications sas
   WHERE sas.audit_guid = sa.audit_guid) AS server_specs,
  (SELECT COUNT(*) FROM sys.database_audit_specifications das
   WHERE das.audit_guid = sa.audit_guid) AS db_specs
FROM sys.server_audits sa
ORDER BY sa.name
GO

/* ===== SEC-SQL-AUD-001-RC10 — Plugin initialization failure ===== */
SELECT sa.name, sa.is_state_enabled,
  sa.create_date, sa.modify_date,
  sa.type_desc, sa.on_failure_desc,
  sfa.log_file_path
FROM sys.server_audits sa
LEFT JOIN sys.server_file_audits sfa ON sa.audit_id = sfa.audit_id
WHERE sa.is_state_enabled = 0
  AND sa.modify_date > DATEADD(day, -30, GETDATE())
GO

/* ===== SEC-SQL-AUD-001-RC11 — Container/Ephemeral storage misconfiguration ===== */
SELECT
  SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS hostname,
  SERVERPROPERTY('MachineName') AS machine_name,
  sa.name AS audit_name,
  sfa.log_file_path,
  sa.type_desc,
  sa.is_state_enabled,
  (SELECT COUNT(*) FROM sys.dm_os_loaded_modules
   WHERE name LIKE '%container%' OR name LIKE '%docker%') AS container_hint
FROM sys.server_audits sa
LEFT JOIN sys.server_file_audits sfa ON sa.audit_id = sfa.audit_id
WHERE sa.type_desc = 'FILE'
GO

/* ===== SEC-SQL-AUD-001-RC12 — Audit process crash ===== */
SELECT sa.name, sa.is_state_enabled,
  sa.on_failure_desc,
  sa.modify_date,
  (SELECT sqlserver_start_time FROM sys.dm_os_sys_info) AS last_restart,
  CASE WHEN sa.modify_date >
    (SELECT sqlserver_start_time FROM sys.dm_os_sys_info)
    THEN 'Modified after restart'
    ELSE 'Not modified since restart'
  END AS state_change_timing
FROM sys.server_audits sa
WHERE sa.is_state_enabled = 0
GO

/* ===== SEC-SQL-AUD-002-RC01 — Aggressive rotation configuration ===== */
SELECT a.name AS audit_name, a.type_desc, CASE WHEN a.is_state_enabled = 1 THEN 'ENABLED' ELSE 'DISABLED' END AS status, a.on_failure_desc, a.queue_delay, sfa.log_file_path AS audit_file_path, sfa.max_file_size, sfa.max_rollover_files FROM sys.server_audits a LEFT JOIN sys.server_file_audits sfa ON a.audit_id = sfa.audit_id
GO

/* ===== SEC-SQL-AUD-002-RC02 — Insufficient disk space ===== */
SELECT a.name AS audit_name, a.type_desc, CASE WHEN a.is_state_enabled = 1 THEN 'ENABLED' ELSE 'DISABLED' END AS status, a.on_failure_desc, a.queue_delay, sfa.log_file_path AS audit_file_path, sfa.max_file_size, sfa.max_rollover_files FROM sys.server_audits a LEFT JOIN sys.server_file_audits sfa ON a.audit_id = sfa.audit_id
GO

/* ===== SEC-SQL-AUD-002-RC03 — Lack of external archival ===== */
SELECT a.name AS audit_name, a.type_desc, CASE WHEN a.is_state_enabled = 1 THEN 'ENABLED' ELSE 'DISABLED' END AS status, a.on_failure_desc, a.queue_delay, sfa.log_file_path AS audit_file_path, sfa.max_file_size, sfa.max_rollover_files FROM sys.server_audits a LEFT JOIN sys.server_file_audits sfa ON a.audit_id = sfa.audit_id
GO

/* ===== SEC-SQL-AUD-002-RC04 — Default retention policies ===== */
SELECT a.name AS audit_name, a.type_desc, CASE WHEN a.is_state_enabled = 1 THEN 'ENABLED' ELSE 'DISABLED' END AS status, a.on_failure_desc, a.queue_delay, sfa.log_file_path AS audit_file_path, sfa.max_file_size, sfa.max_rollover_files FROM sys.server_audits a LEFT JOIN sys.server_file_audits sfa ON a.audit_id = sfa.audit_id
GO

/* ===== SEC-SQL-AUD-002-RC05 — Memory-only logging ===== */
SELECT sa.name, sa.type_desc AS destination,
  sa.is_state_enabled, sa.on_failure_desc,
  CASE
    WHEN sa.type_desc = 'APPLICATION_LOG' THEN 'Windows Application Log — limited retention'
    WHEN sa.type_desc = 'SECURITY_LOG' THEN 'Windows Security Log — requires privilege'
    ELSE sa.type_desc
  END AS retention_risk
FROM sys.server_audits sa
WHERE sa.type_desc IN ('APPLICATION_LOG', 'SECURITY_LOG')
  AND sa.is_state_enabled = 1
GO

/* ===== SEC-SQL-AUD-002-RC06 — Misconfigured "Purge" jobs ===== */
SELECT a.name AS audit_name, a.type_desc, CASE WHEN a.is_state_enabled = 1 THEN 'ENABLED' ELSE 'DISABLED' END AS status, a.on_failure_desc, a.queue_delay, sfa.log_file_path AS audit_file_path, sfa.max_file_size, sfa.max_rollover_files FROM sys.server_audits a LEFT JOIN sys.server_file_audits sfa ON a.audit_id = sfa.audit_id
GO

/* ===== SEC-SQL-AUD-002-RC07 — File system quotas ===== */
SELECT sa.name, sa.on_failure_desc,
  CASE sa.on_failure_desc
    WHEN 'CONTINUE' THEN 'RISK: Audit silently stops — security gap'
    WHEN 'SHUTDOWN' THEN 'RISK: Server shuts down — availability impact'
    WHEN 'FAIL_OPERATION' THEN 'RISK: Audited operations fail — application impact'
  END AS risk_assessment
FROM sys.server_audits sa
WHERE sa.type_desc = 'FILE'
  AND sa.is_state_enabled = 1
GO

/* ===== SEC-SQL-AUD-002-RC08 — Circular log overwrite ===== */
SELECT a.name AS audit_name, a.type_desc, CASE WHEN a.is_state_enabled = 1 THEN 'ENABLED' ELSE 'DISABLED' END AS status, a.on_failure_desc, a.queue_delay, sfa.log_file_path AS audit_file_path, sfa.max_file_size, sfa.max_rollover_files FROM sys.server_audits a LEFT JOIN sys.server_file_audits sfa ON a.audit_id = sfa.audit_id
GO

/* ===== SEC-SQL-AUD-002-RC09 — Container restart data loss ===== */
SELECT a.name AS audit_name, a.type_desc, CASE WHEN a.is_state_enabled = 1 THEN 'ENABLED' ELSE 'DISABLED' END AS status_desc, a.on_failure_desc, a.queue_delay, sfa.log_file_path, sfa.max_file_size, sfa.max_rollover_files FROM sys.server_audits a LEFT JOIN sys.server_file_audits sfa ON a.audit_id = sfa.audit_id
GO

/* ===== SEC-SQL-AUD-002-RC10 — Manual deletion by admins ===== */
SELECT sp.name AS login_name, sp.type_desc,
  perm.permission_name, perm.state_desc,
  (SELECT COUNT(*) FROM sys.server_role_members rm
   JOIN sys.server_principals sr ON rm.role_principal_id = sr.principal_id
   WHERE rm.member_principal_id = sp.principal_id
     AND sr.name = 'sysadmin') AS is_sysadmin,
  (SELECT COUNT(*) FROM sys.server_permissions p2
   WHERE p2.grantee_principal_id = sp.principal_id
     AND p2.permission_name IN ('ALTER ANY SERVER AUDIT', 'CONTROL SERVER')) AS audit_control_perms
FROM sys.server_principals sp
LEFT JOIN sys.server_permissions perm ON sp.principal_id = perm.grantee_principal_id
  AND perm.permission_name IN ('ALTER ANY SERVER AUDIT', 'CONTROL SERVER')
WHERE sp.is_disabled = 0
  AND sp.type IN ('S', 'U', 'G')
  AND sp.name NOT LIKE '##%'
  AND (
    EXISTS (SELECT 1 FROM sys.server_role_members rm
      JOIN sys.server_principals sr ON rm.role_principal_id = sr.principal_id
      WHERE rm.member_principal_id = sp.principal_id AND sr.name = 'sysadmin')
    OR EXISTS (SELECT 1 FROM sys.server_permissions p2
      WHERE p2.grantee_principal_id = sp.principal_id
        AND p2.permission_name IN ('ALTER ANY SERVER AUDIT', 'CONTROL SERVER')
        AND p2.state_desc IN ('GRANT', 'GRANT_WITH_GRANT_OPTION'))
  )
GO

/* ===== SEC-SQL-AUD-003-RC01 — Insecure file permissions ===== */
SELECT sp.name AS login_name, sp.type_desc,
  (SELECT COUNT(*) FROM sys.server_role_members rm
   JOIN sys.server_principals sr ON rm.role_principal_id = sr.principal_id
   WHERE rm.member_principal_id = sp.principal_id
     AND sr.name = 'sysadmin') AS is_sysadmin,
  (SELECT COUNT(*) FROM sys.server_permissions p
   WHERE p.grantee_principal_id = sp.principal_id
     AND p.permission_name = 'CONTROL SERVER'
     AND p.state_desc IN ('GRANT', 'GRANT_WITH_GRANT_OPTION')) AS has_control_server
FROM sys.server_principals sp
WHERE sp.is_disabled = 0
  AND sp.type IN ('S', 'U', 'G')
  AND sp.name NOT LIKE '##%'
  AND (
    EXISTS (SELECT 1 FROM sys.server_role_members rm
      JOIN sys.server_principals sr ON rm.role_principal_id = sr.principal_id
      WHERE rm.member_principal_id = sp.principal_id AND sr.name = 'sysadmin')
    OR EXISTS (SELECT 1 FROM sys.server_permissions p
      WHERE p.grantee_principal_id = sp.principal_id
        AND p.permission_name = 'CONTROL SERVER'
        AND p.state_desc IN ('GRANT', 'GRANT_WITH_GRANT_OPTION'))
  )
GO

/* ===== SEC-SQL-AUD-003-RC02 — Internal audit tables are mutable ===== */
SELECT
  (SELECT COUNT(*) FROM sys.server_audits WHERE type_desc = 'FILE') AS file_based_audits,
  (SELECT COUNT(*) FROM sys.server_audits WHERE type_desc IN ('APPLICATION LOG', 'SECURITY LOG')) AS event_log_audits,
  (SELECT COUNT(DISTINCT rm.member_principal_id)
   FROM sys.server_role_members rm
   JOIN sys.server_principals sr ON rm.role_principal_id = sr.principal_id
   WHERE sr.name = 'sysadmin') AS sysadmin_count,
  CASE
    WHEN (SELECT COUNT(*) FROM sys.server_audits WHERE type_desc = 'FILE') > 0
      AND (SELECT COUNT(*) FROM sys.server_audits WHERE type_desc IN ('APPLICATION LOG', 'SECURITY LOG')) = 0
    THEN 'FILE_ONLY_MUTABLE'
    WHEN (SELECT COUNT(*) FROM sys.server_audits WHERE type_desc IN ('APPLICATION LOG', 'SECURITY LOG')) > 0
    THEN 'EVENT_LOG_LESS_MUTABLE'
    ELSE 'NO_AUDIT'
  END AS mutability_risk
GO

/* ===== SEC-SQL-AUD-003-RC03 — Lack of File Integrity Monitoring (FIM) ===== */
SELECT
  (SELECT COUNT(*) FROM sys.server_audits WHERE type_desc = 'FILE' AND is_state_enabled = 1) AS file_audits,
  (SELECT COUNT(*) FROM sys.server_audits WHERE type_desc IN ('APPLICATION LOG', 'SECURITY LOG') AND is_state_enabled = 1) AS event_log_audits,
  CASE
    WHEN (SELECT COUNT(*) FROM sys.server_audits WHERE type_desc IN ('APPLICATION LOG', 'SECURITY LOG') AND is_state_enabled = 1) = 0
    THEN 'NO_SECONDARY_DESTINATION'
    ELSE 'HAS_EVENT_LOG_BACKUP'
  END AS redundancy_status
GO

/* ===== SEC-SQL-AUD-003-RC04 — Service account ownership ===== */
SELECT dss.servicename, dss.service_account,
  sp.principal_id,
  (SELECT COUNT(*) FROM sys.server_role_members rm
   JOIN sys.server_principals sr ON rm.role_principal_id = sr.principal_id
   WHERE rm.member_principal_id = sp.principal_id AND sr.name = 'sysadmin') AS is_sysadmin,
  (SELECT COUNT(*) FROM sys.server_permissions p
   WHERE p.grantee_principal_id = sp.principal_id
     AND p.permission_name = 'ALTER ANY SERVER AUDIT') AS has_alter_audit
FROM sys.dm_server_services dss
LEFT JOIN sys.server_principals sp ON dss.service_account = sp.name
WHERE dss.servicename LIKE '%SQL Server%'
GO

/* ===== SEC-SQL-AUD-003-RC05 — Missing "Append-Only" attributes ===== */
SELECT a.name AS audit_name, a.type_desc, CASE WHEN a.is_state_enabled = 1 THEN 'ENABLED' ELSE 'DISABLED' END AS status_desc, a.on_failure_desc, a.queue_delay, sfa.log_file_path, sfa.max_file_size, sfa.max_rollover_files FROM sys.server_audits a LEFT JOIN sys.server_file_audits sfa ON a.audit_id = sfa.audit_id
GO

/* ===== SEC-SQL-AUD-003-RC06 — Audit logs not shipped remotely ===== */
SELECT j.name AS job_name,
  j.enabled,
  js.step_name,
  js.command
FROM msdb.dbo.sysjobs j
JOIN msdb.dbo.sysjobsteps js ON j.job_id = js.job_id
WHERE j.enabled = 1
  AND (js.command LIKE '%audit%' OR js.command LIKE '%fn_get_audit_file%'
    OR js.command LIKE '%syslog%' OR js.command LIKE '%SIEM%'
    OR js.command LIKE '%EventLog%' OR js.command LIKE '%.sqlaudit%')
GO

/* ===== SEC-SQL-AUD-003-RC07 — Non-repudiation features disabled ===== */
SELECT
  (SELECT COUNT(*) FROM sys.server_audit_specification_details sasd
   JOIN sys.server_audit_specifications sas ON sasd.server_specification_id = sas.server_specification_id
   WHERE sas.is_state_enabled = 1
     AND sasd.audit_action_name = 'SERVER_PRINCIPAL_IMPERSONATION_GROUP') AS impersonation_audited,
  (SELECT COUNT(*) FROM sys.server_permissions
   WHERE permission_name = 'IMPERSONATE'
     AND state_desc IN ('GRANT', 'GRANT_WITH_GRANT_OPTION')) AS impersonate_grants,
  (SELECT COUNT(*) FROM sys.server_audit_specification_details sasd
   JOIN sys.server_audit_specifications sas ON sasd.server_specification_id = sas.server_specification_id
   WHERE sas.is_state_enabled = 1
     AND sasd.audit_action_name IN ('SUCCESSFUL_LOGIN_GROUP', 'FAILED_LOGIN_GROUP')) AS login_events_audited
GO

/* ===== SEC-SQL-AUD-003-RC08 — Admin accounts shared/untracked ===== */
SELECT sp.name, sp.is_disabled,
  sl.is_policy_checked, sl.is_expiration_checked,
  (SELECT COUNT(*) FROM sys.dm_exec_sessions s
   WHERE s.login_name = 'sa' AND s.is_user_process = 1) AS active_sa_sessions,
  sp.modify_date AS last_password_change
FROM sys.sql_logins sl
JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
WHERE sp.name = 'sa'
GO

/* ===== SEC-SQL-AUD-003-RC09 — Audit disablement capability ===== */
SELECT
  COUNT(*) AS total_audits,
  SUM(CASE WHEN a.on_failure_desc = 'SHUTDOWN' THEN 1 ELSE 0 END) AS shutdown_on_failure,
  SUM(CASE WHEN a.on_failure_desc = 'FAIL_OPERATION' THEN 1 ELSE 0 END) AS fail_op_on_failure,
  SUM(CASE WHEN a.on_failure_desc = 'CONTINUE' THEN 1 ELSE 0 END) AS continue_on_failure
FROM sys.server_audits a
WHERE a.is_state_enabled = 1
GO

/* ===== SEC-SQL-AUD-004-RC01 — Logging level set to "Errors Only" ===== */
SELECT sas.name AS spec_name,
  sasd.audit_action_name
FROM sys.server_audit_specification_details sasd
JOIN sys.server_audit_specifications sas ON sasd.server_specification_id = sas.server_specification_id
WHERE sas.is_state_enabled = 1
  AND sasd.audit_action_name = 'FAILED_LOGIN_GROUP'
GO

/* ===== SEC-SQL-AUD-004-RC02 — "Successful Logins Only" filter ===== */
SELECT
  (SELECT COUNT(*) FROM sys.server_audit_specification_details sasd
   JOIN sys.server_audit_specifications sas ON sasd.server_specification_id = sas.server_specification_id
   WHERE sas.is_state_enabled = 1 AND sasd.audit_action_name = 'FAILED_LOGIN_GROUP') AS failed_login_audited,
  (SELECT COUNT(*) FROM sys.server_audit_specification_details sasd
   JOIN sys.server_audit_specifications sas ON sasd.server_specification_id = sas.server_specification_id
   WHERE sas.is_state_enabled = 1 AND sasd.audit_action_name = 'SUCCESSFUL_LOGIN_GROUP') AS success_login_audited
GO

/* ===== SEC-SQL-AUD-004-RC03 — Connection string errors ===== */
SELECT a.name AS audit_name, a.type_desc, CASE WHEN a.is_state_enabled = 1 THEN 'ENABLED' ELSE 'DISABLED' END AS status_desc, a.on_failure_desc, a.queue_delay, sfa.log_file_path, sfa.max_file_size, sfa.max_rollover_files FROM sys.server_audits a LEFT JOIN sys.server_file_audits sfa ON a.audit_id = sfa.audit_id
GO

/* ===== SEC-SQL-AUD-004-RC04 — Generic "Audit All" disabled ===== */
SELECT
  (SELECT COUNT(*) FROM sys.server_audits WHERE is_state_enabled = 1) AS active_audits,
  (SELECT COUNT(*) FROM sys.server_audit_specifications WHERE is_state_enabled = 1) AS active_server_specs,
  (SELECT COUNT(*) FROM sys.database_audit_specifications WHERE is_state_enabled = 1) AS active_db_specs
GO

/* ===== SEC-SQL-AUD-004-RC05 — Log sampling/Throttling ===== */
SELECT a.name AS audit_name, a.type_desc, CASE WHEN a.is_state_enabled = 1 THEN 'ENABLED' ELSE 'DISABLED' END AS status_desc, a.on_failure_desc, a.queue_delay, sfa.log_file_path, sfa.max_file_size, sfa.max_rollover_files FROM sys.server_audits a LEFT JOIN sys.server_file_audits sfa ON a.audit_id = sfa.audit_id
GO

/* ===== SEC-SQL-AUD-004-RC06 — Misinterpreted Error Codes ===== */
SELECT sasd.audit_action_name,
  sasd.class_desc,
  sas.name AS spec_name
FROM sys.server_audit_specification_details sasd
JOIN sys.server_audit_specifications sas ON sasd.server_specification_id = sas.server_specification_id
WHERE sas.is_state_enabled = 1
  AND sasd.audit_action_name LIKE '%LOGIN%'
GO

/* ===== SEC-SQL-AUD-004-RC07 — Internal vs External Authentication ===== */
SELECT
  SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_auth_only,
  (SELECT COUNT(*) FROM sys.sql_logins sl
   JOIN sys.server_principals sp ON sl.principal_id = sp.principal_id
   WHERE sp.is_disabled = 0 AND sp.name NOT LIKE '##%') AS active_sql_logins,
  (SELECT COUNT(*) FROM sys.server_principals
   WHERE type IN ('U', 'G') AND is_disabled = 0) AS active_windows_logins,
  (SELECT COUNT(*) FROM sys.server_audit_specification_details sasd
   JOIN sys.server_audit_specifications sas ON sasd.server_specification_id = sas.server_specification_id
   WHERE sas.is_state_enabled = 1
     AND sasd.audit_action_name = 'FAILED_LOGIN_GROUP') AS failed_login_audited
GO

/* ===== SEC-SQL-AUD-004-RC08 — Application-side suppression ===== */
SELECT
  (SELECT cntr_value FROM sys.dm_os_performance_counters
   WHERE counter_name = 'Connection Reset/sec' AND instance_name = '') AS connection_resets,
  (SELECT cntr_value FROM sys.dm_os_performance_counters
   WHERE counter_name = 'Logins/sec' AND instance_name = '') AS total_logins,
  (SELECT cntr_value FROM sys.dm_os_performance_counters
   WHERE counter_name = 'Logouts/sec' AND instance_name = '') AS total_logouts,
  (SELECT cntr_value FROM sys.dm_os_performance_counters
   WHERE counter_name = 'User Connections' AND instance_name = '') AS current_user_connections
GO

/* ===== SEC-SQL-AUD-005-RC01 — DML-focused Audit Policy ===== */
SELECT sas.name AS spec_name,
  sasd.audit_action_name,
  sasd.class_desc,
  CASE
    WHEN sasd.audit_action_name LIKE '%DDL%' THEN 'DDL'
    WHEN sasd.audit_action_name LIKE '%LOGIN%' THEN 'LOGIN'
    WHEN sasd.audit_action_name LIKE '%SCHEMA%' THEN 'SCHEMA'
    WHEN sasd.audit_action_name LIKE '%PRINCIPAL%' THEN 'PRINCIPAL'
    WHEN sasd.audit_action_name LIKE '%PERMISSION%' THEN 'PERMISSION'
    WHEN sasd.audit_action_name LIKE '%AUDIT%' THEN 'AUDIT_META'
    ELSE 'OTHER'
  END AS action_category
FROM sys.server_audit_specification_details sasd
JOIN sys.server_audit_specifications sas ON sasd.server_specification_id = sas.server_specification_id
WHERE sas.is_state_enabled = 1
GO

/* ===== SEC-SQL-AUD-005-RC02 — Granularity settings ===== */
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

/* ===== SEC-SQL-AUD-005-RC03 — Privileged User Exclusion ===== */
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

/* ===== SEC-SQL-AUD-005-RC04 — Logging "Write" vs "DDL" ===== */
SELECT
  SUM(CASE WHEN sasd.audit_action_name IN ('DATABASE_OBJECT_ACCESS_GROUP', 'SCHEMA_OBJECT_ACCESS_GROUP') THEN 1 ELSE 0 END) AS dml_access_groups,
  SUM(CASE WHEN sasd.audit_action_name IN ('SCHEMA_OBJECT_CHANGE_GROUP', 'DATABASE_OBJECT_CHANGE_GROUP', 'DATABASE_CHANGE_GROUP') THEN 1 ELSE 0 END) AS ddl_change_groups,
  SUM(CASE WHEN sasd.audit_action_name IN ('SERVER_OBJECT_CHANGE_GROUP', 'SERVER_PRINCIPAL_CHANGE_GROUP') THEN 1 ELSE 0 END) AS server_change_groups
FROM sys.server_audit_specifications sas
JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
WHERE sas.is_state_enabled = 1
GO

/* ===== SEC-SQL-AUD-005-RC05 — Deployment via Scripts ===== */
SELECT
  (SELECT COUNT(*) FROM sys.server_audit_specifications sas
   JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
   WHERE sas.is_state_enabled = 1
     AND sasd.audit_action_name IN ('SCHEMA_OBJECT_CHANGE_GROUP', 'DATABASE_OBJECT_CHANGE_GROUP')
     AND sasd.class_desc = 'SERVER') AS server_wide_ddl_audit,
  (SELECT COUNT(DISTINCT dasd.audited_principal_id)
   FROM sys.database_audit_specifications das
   JOIN sys.database_audit_specification_details dasd ON das.database_specification_id = dasd.database_specification_id
   WHERE das.is_state_enabled = 1
     AND dasd.audit_action_name IN ('SCHEMA_OBJECT_CHANGE_GROUP', 'DATABASE_OBJECT_CHANGE_GROUP')
     AND dasd.audited_principal_id <> 0) AS principal_scoped_ddl_audit
GO

/* ===== SEC-SQL-AUD-005-RC06 — Temporary Table Exclusion ===== */
SELECT
  (SELECT COUNT(*) FROM tempdb.sys.database_audit_specifications das
   WHERE das.is_state_enabled = 1) AS tempdb_audit_specs,
  (SELECT COUNT(*) FROM tempdb.sys.database_audit_specification_details dasd
   JOIN tempdb.sys.database_audit_specifications das ON dasd.database_specification_id = das.database_specification_id
   WHERE das.is_state_enabled = 1
     AND dasd.audit_action_name IN ('SCHEMA_OBJECT_CHANGE_GROUP', 'DATABASE_OBJECT_CHANGE_GROUP')) AS tempdb_ddl_audit,
  (SELECT COUNT(*) FROM sys.server_audit_specifications sas
   JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
   WHERE sas.is_state_enabled = 1
     AND sasd.audit_action_name = 'SCHEMA_OBJECT_CHANGE_GROUP') AS server_ddl_audit
GO

/* ===== SEC-SQL-AUD-005-RC07 — Extension/Plugin Limitations ===== */
SELECT
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'xp_cmdshell') AS xp_cmdshell_enabled,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'Ole Automation Procedures') AS ole_automation_enabled,
  (SELECT COUNT(*) FROM master.sys.extended_procedures) AS extended_procs,
  (SELECT COUNT(*) FROM sys.assemblies WHERE is_user_defined = 1
    AND permission_set_desc IN ('EXTERNAL_ACCESS', 'UNSAFE')) AS unsafe_assemblies
GO

/* ===== SEC-SQL-AUD-005-RC08 — Statement Truncation ===== */
SELECT a.name AS audit_name, a.type_desc, CASE WHEN a.is_state_enabled = 1 THEN 'ENABLED' ELSE 'DISABLED' END AS status, sfa.max_file_size, sfa.max_rollover_files FROM sys.server_audits a LEFT JOIN sys.server_file_audits sfa ON a.audit_id = sfa.audit_id
GO

/* ===== SEC-SQL-AUD-006-RC01 — Privileged account executing DML outside maintenance window ===== */
SELECT s.session_id, s.login_name, s.host_name, s.program_name,
            r.command, r.start_time, t.text AS sql_text
     FROM sys.dm_exec_sessions s
     JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
     CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
     WHERE s.is_user_process = 1
       AND r.command IN ('INSERT','UPDATE','DELETE')
       AND (IS_SRVROLEMEMBER('sysadmin', s.login_name) = 1
            OR IS_MEMBER('db_owner') = 1)
GO

/* ===== SEC-SQL-AUD-006-RC02 — Superuser running ad-hoc queries on sensitive tables ===== */
SELECT SCHEMA_NAME(t.schema_id) AS schema_name, t.name AS table_name,
            ep.value AS sensitivity_label
     FROM sys.tables t
     LEFT JOIN sys.extended_properties ep
           ON ep.major_id = t.object_id AND ep.name = 'SensitivityLabel'
     WHERE t.name IN (SELECT PARSENAME(REPLACE(p.text,'[',''),1)
                      FROM sys.dm_exec_cached_plans cp
                      CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) p
                      WHERE p.text LIKE '%sysadmin%')
GO

/* ===== SEC-SQL-AUD-006-RC03 — High privilege account accessing schema outside designated scope ===== */
SELECT s.login_name, DB_NAME(r.database_id) AS db_name,
            t.text, r.start_time
     FROM sys.dm_exec_sessions s
     JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
     CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
     WHERE IS_SRVROLEMEMBER('sysadmin', s.login_name) = 1
       AND t.text LIKE '%].%.[%'
GO

/* ===== SEC-SQL-AUD-006-RC04 — Service account performing interactive or manual transactions ===== */
SELECT sp.name, sp.type_desc, sp.is_disabled,
            ISNULL(ep.value, 'No description') AS description
     FROM sys.server_principals sp
     LEFT JOIN sys.extended_properties ep ON ep.major_id = sp.principal_id AND ep.name = 'AccountType'
     WHERE sp.name LIKE '%svc%' OR sp.name LIKE '%service%' OR sp.name LIKE '%api%'
GO

/* ===== SEC-SQL-AUD-006-RC05 — Privilege escalation during active session ===== */
SELECT session_id, login_name, original_login_name, status
     FROM sys.dm_exec_sessions
     WHERE login_name != original_login_name
       AND is_user_process = 1
GO

/* ===== SEC-SQL-AUD-007-RC01 — Transactions from unregistered application signatures ===== */
SELECT s.session_id, s.login_name, s.program_name, s.host_name, s.client_interface_name
     FROM sys.dm_exec_sessions s
     WHERE s.is_user_process = 1
       AND s.program_name NOT IN (
           'AppMain','ReportingService','ETLAgent','SqlAgent',
           'Microsoft SQL Server Management Studio - Query', -- remove in prod
           '.Net SqlClient Data Provider'
       )
       AND s.program_name NOT LIKE '%SQLAgent%'
GO

/* ===== SEC-SQL-AUD-007-RC02 — Query patterns not matching known application baseline ===== */
SELECT TOP 20 st.text, qs.execution_count, qs.total_logical_reads / qs.execution_count AS avg_reads
     FROM sys.dm_exec_query_stats qs
     CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
     WHERE qs.execution_count = 1
       AND qs.total_logical_reads > 100000
     ORDER BY avg_reads DESC
GO

/* ===== SEC-SQL-AUD-007-RC03 — Connections from unexpected network addresses ===== */
SELECT s.login_name, c.client_net_address, s.program_name, s.login_time, s.host_name FROM sys.dm_exec_sessions s JOIN sys.dm_exec_connections c ON s.session_id = c.session_id WHERE s.is_user_process = 1 AND c.client_net_address NOT LIKE '10.%' AND c.client_net_address NOT LIKE '192.168.%' AND c.client_net_address NOT LIKE '127.%' AND c.client_net_address NOT LIKE '<local machine>' ORDER BY s.login_time DESC
GO

/* ===== SEC-SQL-AUD-007-RC04 — Off-hours transaction activity from non-automated accounts ===== */
SELECT login_name, program_name, host_name, login_time, status,
            DATEPART(HOUR, GETUTCDATE()) AS utc_hour
     FROM sys.dm_exec_sessions
     WHERE is_user_process = 1
       AND login_name NOT LIKE '%svc%' AND login_name NOT LIKE '%service%'
         AND login_name NOT LIKE '%agent%' AND login_name NOT LIKE 'NT %'
       AND DATEPART(HOUR, GETUTCDATE()) NOT BETWEEN 6 AND 20
GO

/* ===== SEC-SQL-AUD-007-RC05 — Execution of previously unseen stored procedures or functions ===== */
SELECT OBJECT_NAME(q.object_id) AS proc_name,
            qt.query_sql_text, rs.first_execution_time, rs.count_executions
     FROM sys.query_store_query q
     JOIN sys.query_store_query_text qt ON qt.query_text_id = q.query_text_id
     JOIN sys.query_store_plan qp ON qp.query_id = q.query_id
     JOIN sys.query_store_runtime_stats rs ON rs.plan_id = qp.plan_id
     WHERE rs.count_executions = 1
       AND rs.first_execution_time > DATEADD(DAY,-7,GETDATE())
       AND q.object_id IS NOT NULL
GO

/* ===== SEC-SQL-AUD-008-RC01 — Bulk data export or mass SELECT on sensitive tables ===== */
SELECT s.login_name, r.command, t.text, r.start_time, r.logical_reads
     FROM sys.dm_exec_sessions s
     JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
     CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
     WHERE (r.command IN ('BULK INSERT','INSERT ... SELECT')
            OR t.text LIKE '%OPENROWSET%' OR t.text LIKE '%BCP%')
       AND r.logical_reads > 100000
GO

/* ===== SEC-SQL-AUD-008-RC02 — Mass DELETE or TRUNCATE without WHERE clause ===== */
SELECT t.name AS table_name, SUM(p.rows) AS row_count
     FROM sys.tables t
     JOIN sys.indexes i ON i.object_id = t.object_id AND i.index_id <= 1
     JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id = i.index_id
     WHERE t.name IN (
         SELECT PARSENAME(t2.text, 1)
         FROM sys.dm_exec_requests r2
         CROSS APPLY sys.dm_exec_sql_text(r2.sql_handle) t2
         WHERE r2.command IN ('DELETE','TRUNCATE TABLE')
     )
     GROUP BY t.name HAVING SUM(p.rows) > 1000
GO

/* ===== SEC-SQL-AUD-008-RC03 — DDL statements executed in production by non-DBA accounts ===== */
SELECT s.login_name, r.command, t.text, r.start_time, DB_NAME(r.database_id) AS db_name
     FROM sys.dm_exec_sessions s
     JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
     CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
     WHERE r.command IN ('CREATE TABLE','ALTER TABLE','DROP TABLE',
                         'CREATE INDEX','DROP INDEX','CREATE VIEW',
                         'ALTER PROCEDURE','CREATE PROCEDURE','DROP PROCEDURE')
       AND IS_SRVROLEMEMBER('sysadmin', s.login_name) = 0
       AND IS_MEMBER('db_ddladmin') = 0
GO

/* ===== SEC-SQL-AUD-008-RC04 — Transactions accessing credential or encryption key tables ===== */
SELECT s.login_name, t.text, r.start_time
     FROM sys.dm_exec_sessions s
     JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
     CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
     WHERE t.text LIKE '%api_key%' OR t.text LIKE '%secret_key%'
        OR t.text LIKE '%enc_key%'  OR t.text LIKE '%master_key%'
        OR t.text LIKE '%credential%' OR t.text LIKE '%token_store%'
GO

/* ===== SEC-SQL-AUD-008-RC05 — Cross-schema transactions outside application scope ===== */
SELECT s.name AS schema_name, dp.name AS owner, COUNT(o.object_id) AS object_count
     FROM sys.schemas s
     JOIN sys.database_principals dp ON dp.principal_id = s.principal_id
     LEFT JOIN sys.objects o ON o.schema_id = s.schema_id
     WHERE s.name NOT IN ('dbo','sys','INFORMATION_SCHEMA','guest')
     GROUP BY s.name, dp.name
GO

/* ===== SEC-SQL-AUD-009-RC01 — Tautology patterns detected in active query text ===== */
SELECT s.login_name, t.text, r.start_time, s.host_name
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE '%OR 1=1%' OR t.text LIKE '%OR 1>0%' OR t.text LIKE '%OR TRUE%'
GO

/* ===== SEC-SQL-AUD-009-RC02 — Stacked or chained query execution detected ===== */
SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE '%;%SELECT%' OR t.text LIKE '%;%DROP%'
      OR t.text LIKE '%;%INSERT%' OR t.text LIKE '%;%EXEC%'
GO

/* ===== SEC-SQL-AUD-009-RC03 — UNION-based probing across unknown tables ===== */
SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE (t.text LIKE '%UNION%SELECT%') AND (t.text LIKE '%sys.%' OR t.text LIKE '%INFORMATION_SCHEMA%')
GO

/* ===== SEC-SQL-AUD-009-RC04 — Time-delay injection functions detected in active queries ===== */
SELECT s.login_name, t.text, r.start_time, r.wait_type, r.wait_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE '%WAITFOR%DELAY%' OR t.text LIKE '%WAITFOR%TIME%'
GO

/* ===== SEC-SQL-AUD-009-RC05 — Comment-based obfuscation or encoding in query text ===== */
SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE '%CHAR(%+CHAR(%' OR t.text LIKE '%/*%*/%'
GO

/* ===== SEC-SQL-AUD-010-RC01 — Excessive information_schema or catalog enumeration ===== */
SELECT TOP 10 q.initial_compile_start_time, count(DISTINCT qt.query_sql_text) AS catalog_query_variants FROM sys.query_store_query_text qt JOIN sys.query_store_query q ON q.query_text_id = qt.query_text_id JOIN sys.query_store_runtime_stats rs ON rs.plan_id IN (SELECT plan_id FROM sys.query_store_plan WHERE query_id = q.query_id) WHERE qt.query_sql_text LIKE '%INFORMATION_SCHEMA%' OR qt.query_sql_text LIKE '%sys.columns%' GROUP BY q.initial_compile_start_time ORDER BY catalog_query_variants DESC
GO

/* ===== SEC-SQL-AUD-010-RC02 — System principal and user enumeration by non-admin account ===== */
SELECT s.login_name, CAST(t.text AS NVARCHAR(4000)) AS query_text, r.start_time FROM sys.dm_exec_sessions s JOIN sys.dm_exec_requests r ON s.session_id = r.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE IS_SRVROLEMEMBER('sysadmin', s.login_name) = 0 AND (t.text LIKE '%sys.server_principals%' OR t.text LIKE '%sys.database_principals%' OR t.text LIKE '%sys.sql_logins%')
GO

/* ===== SEC-SQL-AUD-010-RC03 — Mass table and column listing within a single session ===== */
SELECT s.login_name, t.text, r.start_time, r.row_count
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE '%INFORMATION_SCHEMA%COLUMNS%'
     AND t.text NOT LIKE '%TABLE_NAME%=% '
GO

/* ===== SEC-SQL-AUD-010-RC04 — Stored procedure and function source code enumeration ===== */
SELECT s.login_name, IS_SRVROLEMEMBER('sysadmin', s.login_name) AS is_sysadmin, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE IS_SRVROLEMEMBER('sysadmin', s.login_name) = 0
     AND (t.text LIKE '%sys.sql_modules%' OR t.text LIKE '%INFORMATION_SCHEMA%ROUTINES%')
GO

/* ===== SEC-SQL-AUD-010-RC05 — Permission and privilege discovery queries ===== */
SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE '%fn_my_permissions%' OR t.text LIKE '%sys.database_permissions%'
      OR t.text LIKE '%sys.server_permissions%'
GO

/* ===== SEC-SQL-AUD-011-RC01 — Direct DML executed on audit or log tables ===== */
SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE (t.text LIKE '%INSERT%' OR t.text LIKE '%UPDATE%' OR t.text LIKE '%DELETE%')
     AND (t.text LIKE '%audit%' OR t.text LIKE '%event_log%' OR t.text LIKE '%trace_log%')
GO

/* ===== SEC-SQL-AUD-011-RC02 — Audit settings disabled or downgraded mid-session ===== */
SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE '%ALTER%AUDIT%STATE%OFF%'
      OR t.text LIKE '%sp_configure%audit%'
GO

/* ===== SEC-SQL-AUD-011-RC03 — Audit or log table truncated or dropped ===== */
SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE (t.text LIKE '%TRUNCATE%TABLE%' OR t.text LIKE '%DROP%TABLE%')
     AND (t.text LIKE '%audit%' OR t.text LIKE '%event_log%' OR t.text LIKE '%trace%')
GO

/* ===== SEC-SQL-AUD-011-RC04 — Trigger disabled immediately before DML operation ===== */
SELECT t.name AS trigger_name, OBJECT_NAME(t.parent_id) AS table_name, t.is_disabled, t.modify_date
   FROM sys.triggers t
   WHERE t.is_disabled = 1
   ORDER BY t.modify_date DESC
GO

/* ===== SEC-SQL-AUD-011-RC05 — Error log or event buffer cleared during session ===== */
SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE '%sp_cycle_errorlog%'
GO

/* ===== SEC-SQL-AUD-012-RC01 — Transaction open beyond threshold with no activity ===== */
SELECT s.session_id, s.login_name, s.open_transaction_count,
          s.last_request_start_time,
          DATEDIFF(minute, s.last_request_start_time, GETDATE()) AS idle_minutes,
          s.host_name, s.program_name
   FROM sys.dm_exec_sessions s
   WHERE s.open_transaction_count > 0
     AND DATEDIFF(minute, s.last_request_start_time, GETDATE()) > 30
   ORDER BY idle_minutes DESC
GO

/* ===== SEC-SQL-AUD-012-RC02 — Exclusive locks held on large tables for extended period ===== */
SELECT tl.request_session_id AS spid, s.login_name,
          OBJECT_NAME(tl.resource_associated_entity_id) AS table_name,
          p.rows AS est_rows, tl.request_mode, tl.request_status,
          DATEDIFF(minute, s.last_request_start_time, GETDATE()) AS lock_minutes
   FROM sys.dm_tran_locks tl
   JOIN sys.dm_exec_sessions s ON s.session_id = tl.request_session_id
   JOIN sys.partitions p ON p.object_id = tl.resource_associated_entity_id
   WHERE tl.resource_type = 'OBJECT'
     AND tl.request_mode IN ('X','SCH-M')
     AND p.rows > 100000
     AND DATEDIFF(minute, s.last_request_start_time, GETDATE()) > 10
GO

/* ===== SEC-SQL-AUD-012-RC03 — Idle-in-transaction session blocking downstream operations ===== */
SELECT s.session_id, s.login_name, s.status, s.open_transaction_count, DATEDIFF(second, s.last_request_end_time,
  GETDATE()) AS idle_seconds, count(r.session_id) AS blocked_sessions FROM sys.dm_exec_sessions s LEFT JOIN
  sys.dm_exec_requests r ON r.blocking_session_id = s.session_id WHERE s.open_transaction_count > 0 AND s.status =
  'sleeping' AND s.last_request_end_time IS NOT NULL AND DATEDIFF(second, s.last_request_end_time, GETDATE()) > 300
  GROUP BY s.session_id, s.login_name, s.status, s.open_transaction_count, s.last_request_end_time HAVING
  count(r.session_id) > 0
GO

/* ===== SEC-SQL-AUD-012-RC04 — Large-volume rollback indicating probe-and-revert behaviour ===== */
SELECT st.session_id, dt.database_id, dt.database_transaction_begin_time, dt.database_transaction_log_bytes_used, dt.database_transaction_log_bytes_reserved, dt.database_transaction_type FROM sys.dm_tran_database_transactions dt JOIN sys.dm_tran_session_transactions st ON st.transaction_id = dt.transaction_id WHERE dt.database_transaction_log_bytes_used > 10485760 ORDER BY dt.database_transaction_log_bytes_used DESC
GO

/* ===== SEC-SQL-AUD-012-RC05 — Savepoint abuse with repeated partial rollbacks ===== */
SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE '%SAVE%TRANSACTION%' OR t.text LIKE '%ROLLBACK%TRAN%' AND t.text LIKE '%SAVE%'
GO

/* ===== SEC-SQL-AUD-013-RC01 — Security-relevant ALTER SYSTEM or SET executed by non-admin ===== */
SELECT s.login_name, CAST(t.text AS NVARCHAR(4000)) AS query_text, r.start_time FROM sys.dm_exec_sessions s JOIN sys.dm_exec_requests r ON s.session_id = r.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE IS_SRVROLEMEMBER('sysadmin', s.login_name) = 0 AND t.text LIKE '%sp_configure%'
GO

/* ===== SEC-SQL-AUD-013-RC02 — Dangerous feature enabled during session ===== */
SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE (t.text LIKE '%xp_cmdshell%' OR t.text LIKE '%Ole Automation%'
          OR t.text LIKE '%clr enabled%' OR t.text LIKE '%ad hoc distributed queries%')
     AND t.text LIKE '%sp_configure%'
GO

/* ===== SEC-SQL-AUD-013-RC03 — Trigger disabled or dropped on monitored table ===== */
SELECT t.name AS trigger_name, OBJECT_NAME(t.parent_id) AS table_name,
          t.is_disabled, t.type_desc, t.modify_date
   FROM sys.triggers t
   WHERE t.is_disabled = 1
     AND t.parent_class = 1
   ORDER BY t.modify_date DESC
GO

/* ===== SEC-SQL-AUD-013-RC04 — Audit or logging parameters changed mid-session ===== */
SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE '%ALTER%SERVER%AUDIT%' OR t.text LIKE '%ALTER%AUDIT%SPECIFICATION%'
GO

/* ===== SEC-SQL-AUD-013-RC05 — Network or authentication configuration modified at runtime ===== */
SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE '%sp_addlinkedserver%' OR t.text LIKE '%sp_addremotelogin%'
      OR t.text LIKE '%sp_setnetname%'
GO

/* ===== SEC-SQL-AUD-014-RC01 — New user or login created during application session ===== */
SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE '%CREATE%LOGIN%' OR t.text LIKE '%CREATE%USER%'
GO

/* ===== SEC-SQL-AUD-014-RC02 — Account added to privileged role mid-session ===== */
SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE '%ALTER%SERVER%ROLE%ADD%MEMBER%'
      OR t.text LIKE '%sp_addsrvrolemember%'
GO

/* ===== SEC-SQL-AUD-014-RC03 — Password changed on another account during active session ===== */
SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE '%ALTER%LOGIN%PASSWORD%'
GO

/* ===== SEC-SQL-AUD-014-RC04 — Database link or synonym to external system created ===== */
SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE '%sp_addlinkedserver%' OR t.text LIKE '%CREATE%SYNONYM%'
GO

/* ===== SEC-SQL-AUD-014-RC05 — Account unlocked or expiry removed on dormant account ===== */
SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE '%ALTER%LOGIN%ENABLE%'
GO

/* ===== SEC-SQL-AUD-015-RC01 — Recent schema changes or DML detected via SQL Server Audit ===== */
SET NOCOUNT ON;
DECLARE @audit_path NVARCHAR(520);
SELECT TOP (1)
       @audit_path = log_file_path
                     + REPLACE(log_file_name, N'.sqlaudit', N'*.sqlaudit')
FROM   sys.server_file_audits
WHERE  is_state_enabled = 1
ORDER BY audit_id;

IF @audit_path IS NULL
BEGIN
    SELECT TOP 0
        CAST(NULL AS DATETIME2)     AS event_time,
        CAST(NULL AS NVARCHAR(128)) AS login_name,
        CAST(NULL AS NVARCHAR(128)) AS database_name,
        CAST(NULL AS NVARCHAR(128)) AS schema_name,
        CAST(NULL AS NVARCHAR(128)) AS object_name,
        CAST(NULL AS NVARCHAR(4))   AS action_id,
        CAST(NULL AS NVARCHAR(16))  AS action,
        CAST(NULL AS NVARCHAR(8))   AS change_kind,
        CAST(NULL AS NVARCHAR(45))  AS client_ip,
        CAST(NULL AS NVARCHAR(128)) AS application_name,
        CAST(NULL AS NVARCHAR(MAX)) AS statement;
    RETURN;
END;

SELECT  af.event_time AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Jerusalem' AS event_time,
        af.server_principal_name   AS login_name,
        af.database_name,
        af.schema_name,
        af.object_name,
        af.action_id,
        CASE af.action_id
             WHEN 'CR' THEN 'CREATE' WHEN 'AL' THEN 'ALTER' WHEN 'DR' THEN 'DROP'
             WHEN 'IN' THEN 'INSERT' WHEN 'UP' THEN 'UPDATE' WHEN 'DE' THEN 'DELETE'
             WHEN 'TR' THEN 'TRUNCATE' WHEN 'SL' THEN 'SELECT'
             ELSE af.action_id END AS action,
        CASE WHEN af.action_id IN ('CR','AL','DR')      THEN 'SCHEMA'
             WHEN af.action_id IN ('IN','UP','DE','TR') THEN 'DML'
             ELSE 'OTHER' END      AS change_kind,
        af.client_ip,
        af.application_name,
        af.statement
FROM    sys.fn_get_audit_file(@audit_path, DEFAULT, DEFAULT) AS af
WHERE   af.action_id IN ('CR','AL','DR','IN','UP','DE','TR')
  AND   af.event_time >= DATEADD(hour, -24, SYSUTCDATETIME())
  AND   af.succeeded  = 1
ORDER BY af.event_time DESC;
GO

/* ===== SEC-SQL-AUTHZ-001-RC01 — Database access & privilege inventory (logins, roles, grants) ===== */
SET NOCOUNT ON;
IF OBJECT_ID('tempdb..#access') IS NOT NULL DROP TABLE #access;
CREATE TABLE #access (server SYSNAME NULL, database_name SYSNAME NULL, login_name SYSNAME NULL, database_user SYSNAME NULL, principal_type NVARCHAR(60) NULL, roles NVARCHAR(MAX) NULL, permissions NVARCHAR(MAX) NULL);
DECLARE @db SYSNAME; DECLARE @sql NVARCHAR(MAX);
DECLARE db_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT name FROM sys.databases
    WHERE state = 0 AND database_id > 4 AND HAS_DBACCESS(name) = 1
      AND name NOT IN ('master','model','msdb','tempdb','distribution','ReportServer','ReportServerTempDB','SSISDB');
OPEN db_cursor; FETCH NEXT FROM db_cursor INTO @db;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'USE ' + QUOTENAME(@db) + N';
INSERT INTO #access (server, database_name, login_name, database_user, principal_type, roles, permissions)
SELECT @@SERVERNAME, DB_NAME(), sp.name, dp.name, dp.type_desc, r.roles, g.permissions
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
SELECT server, database_name, login_name, database_user, principal_type, roles, permissions FROM #access ORDER BY database_name, database_user;
DROP TABLE #access;
GO

/* ===== SEC-SQL-AZ-001-RC01 — Lack of Role-Based Access Control (RBAC) implementation ===== */
SELECT
  SUM(CASE WHEN dp.type_desc IN ('SQL_USER', 'WINDOWS_USER', 'EXTERNAL_USER') THEN 1 ELSE 0 END) AS direct_user_grants,
  SUM(CASE WHEN dp.type_desc = 'DATABASE_ROLE' THEN 1 ELSE 0 END) AS role_grants,
  COUNT(*) AS total_grants
FROM sys.database_permissions p
JOIN sys.database_principals dp ON p.grantee_principal_id = dp.principal_id
WHERE p.state_desc IN ('GRANT', 'GRANT_WITH_GRANT_OPTION')
  AND p.class_desc <> 'DATABASE'
  AND dp.principal_id > 4
GO

/* ===== SEC-SQL-AZ-001-RC02 — Principle of least privilege not enforced ===== */
SELECT sp.name AS login_name, sp.type_desc,
  STRING_AGG(sr.name, ', ') AS server_roles,
  (SELECT COUNT(*) FROM sys.dm_exec_sessions s
   WHERE s.login_name = sp.name AND s.is_user_process = 1) AS active_sessions,
  sp.create_date
FROM sys.server_principals sp
JOIN sys.server_role_members srm ON sp.principal_id = srm.member_principal_id
JOIN sys.server_principals sr ON srm.role_principal_id = sr.principal_id
WHERE sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
  AND sp.principal_id > 10
  AND sr.name IN ('sysadmin', 'securityadmin', 'serveradmin', 'dbcreator')
GROUP BY sp.name, sp.type_desc, sp.create_date
GO

/* ===== SEC-SQL-AZ-001-RC03 — Developer environments influence production practices ===== */
SELECT sp.name AS login_name, sp.type_desc,
  IS_SRVROLEMEMBER('sysadmin', sp.name) AS is_sysadmin,
  (SELECT COUNT(*) FROM sys.server_permissions p
   WHERE p.grantee_principal_id = sp.principal_id
     AND p.state_desc = 'GRANT'
     AND p.permission_name = 'CONTROL SERVER') AS has_control_server,
  s.program_name, s.host_name
FROM sys.server_principals sp
LEFT JOIN sys.dm_exec_sessions s ON s.login_name = sp.name AND s.is_user_process = 1
WHERE sp.is_disabled = 0
  AND sp.principal_id > 10
  AND sp.name NOT LIKE '##%'
  AND (IS_SRVROLEMEMBER('sysadmin', sp.name) = 1
    OR EXISTS (SELECT 1 FROM sys.server_permissions p
      WHERE p.grantee_principal_id = sp.principal_id
        AND p.permission_name = 'CONTROL SERVER'))
  AND s.program_name IS NOT NULL
  AND s.program_name NOT LIKE '%Management Studio%'
  AND s.program_name NOT LIKE '%SQLAgent%'
GO

/* ===== SEC-SQL-AZ-001-RC04 — Time pressure and perceived operational convenience ===== */
SELECT sp.name AS login_name, sp.type_desc,
  (SELECT COUNT(*) FROM sys.dm_exec_sessions s
   WHERE s.login_name = sp.name AND s.is_user_process = 1) AS current_sessions,
  (SELECT COUNT(*) FROM sys.dm_exec_requests r
   JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id
   WHERE s.login_name = sp.name
     AND r.command NOT IN ('BACKUP DATABASE', 'BACKUP LOG', 'DBCC', 'ALTER INDEX')) AS non_admin_requests
FROM sys.server_principals sp
JOIN sys.server_role_members srm ON sp.principal_id = srm.member_principal_id
JOIN sys.server_principals sr ON srm.role_principal_id = sr.principal_id
WHERE sr.name = 'sysadmin'
  AND sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
  AND sp.principal_id > 10
GO

/* ===== SEC-SQL-AZ-001-RC05 — Inadequate permission analysis during application deployment ===== */
SELECT dp.name AS user_name, dp.type_desc,
  STRING_AGG(r.name, ', ') AS database_roles,
  DB_NAME() AS database_name
FROM sys.database_role_members drm
JOIN sys.database_principals dp ON drm.member_principal_id = dp.principal_id
JOIN sys.database_principals r ON drm.role_principal_id = r.principal_id
WHERE dp.principal_id > 4
  AND dp.name <> 'dbo'
  AND r.name IN ('db_owner', 'db_ddladmin', 'db_securityadmin')
GROUP BY dp.name, dp.type_desc
GO

/* ===== SEC-SQL-AZ-001-RC06 — Multi-schema and cross-database application requirements ===== */
SELECT
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'cross db ownership chaining') AS cross_db_chaining_enabled,
  (SELECT COUNT(DISTINCT dp.name) FROM sys.database_permissions p
   JOIN sys.database_principals dp ON p.grantee_principal_id = dp.principal_id
   WHERE p.class = 3 AND p.state_desc IN ('GRANT', 'GRANT_WITH_GRANT_OPTION')
     AND dp.principal_id > 4 AND dp.name <> 'dbo') AS users_with_schema_grants,
  (SELECT COUNT(DISTINCT SCHEMA_NAME(p.major_id)) FROM sys.database_permissions p
   JOIN sys.database_principals dp ON p.grantee_principal_id = dp.principal_id
   WHERE p.class = 3 AND p.state_desc IN ('GRANT', 'GRANT_WITH_GRANT_OPTION')
     AND dp.principal_id > 4 AND dp.name <> 'dbo') AS schemas_granted
GO

/* ===== SEC-SQL-AZ-001-RC07 — Third-party application vendor requirements ===== */
SELECT s.login_name, s.program_name, s.host_name,
  IS_SRVROLEMEMBER('sysadmin', s.login_name) AS is_sysadmin,
  COUNT(*) AS session_count
FROM sys.dm_exec_sessions s
WHERE s.is_user_process = 1
  AND s.program_name IS NOT NULL
  AND s.program_name <> ''
  AND s.program_name NOT LIKE '%Management Studio%'
  AND s.program_name NOT LIKE '%SQLAgent%'
  AND s.program_name NOT LIKE '%Report Server%'
  AND IS_SRVROLEMEMBER('sysadmin', s.login_name) = 1
GROUP BY s.login_name, s.program_name, s.host_name
GO

/* ===== SEC-SQL-AZ-001-RC08 — Absence of periodic access reviews and certification ===== */
SELECT
  (SELECT COUNT(*) FROM sys.server_principals
   WHERE type IN ('S','U','G') AND is_disabled = 0 AND principal_id > 10
     AND name NOT LIKE '##%') AS total_active_logins,
  (SELECT COUNT(*) FROM sys.server_principals
   WHERE type IN ('S','U','G') AND is_disabled = 0 AND principal_id > 10
     AND name NOT LIKE '##%'
     AND modify_date < DATEADD(YEAR, -1, GETDATE())) AS logins_unmodified_1yr,
  (SELECT COUNT(*) FROM sys.server_principals sp
   WHERE sp.type IN ('S','U','G') AND sp.is_disabled = 0 AND sp.principal_id > 10
     AND sp.name NOT LIKE '##%'
     AND NOT EXISTS (SELECT 1 FROM sys.dm_exec_sessions s
       WHERE s.login_name = sp.name AND s.is_user_process = 1)) AS logins_no_current_session,
  (SELECT COUNT(*) FROM sys.server_principals
   WHERE type IN ('S','U','G') AND is_disabled = 1) AS disabled_logins
GO

/* ===== SEC-SQL-AZ-001-RC09 — Employee role transitions without privilege adjustment ===== */
SELECT sp.name AS login_name, sp.type_desc,
  sp.create_date, sp.modify_date,
  STRING_AGG(sr.name, ', ') AS server_roles,
  COUNT(srm.role_principal_id) AS role_count
FROM sys.server_principals sp
JOIN sys.server_role_members srm ON sp.principal_id = srm.member_principal_id
JOIN sys.server_principals sr ON srm.role_principal_id = sr.principal_id
WHERE sp.is_disabled = 0
  AND sp.principal_id > 10
  AND sp.name NOT LIKE '##%'
GROUP BY sp.name, sp.type_desc, sp.create_date, sp.modify_date
HAVING COUNT(srm.role_principal_id) >= 2
ORDER BY role_count DESC
GO

/* ===== SEC-SQL-AZ-001-RC10 — Legacy applications with hardcoded privilege assumptions ===== */
SELECT o.type_desc, COUNT(*) AS object_count,
  MIN(o.create_date) AS earliest_object,
  MAX(o.modify_date) AS latest_modified
FROM sys.objects o
WHERE o.schema_id = SCHEMA_ID('dbo')
  AND o.is_ms_shipped = 0
  AND o.type IN ('U', 'P', 'V', 'FN', 'IF', 'TF')
GROUP BY o.type_desc
ORDER BY object_count DESC
GO

/* ===== SEC-SQL-AZ-001-RC11 — Knowledge gaps and lack of training ===== */
SELECT
  (SELECT COUNT(*) FROM sys.database_principals dp
   WHERE dp.type IN ('S','U','G') AND dp.sid <> 0x00
     AND dp.principal_id > 4
     AND NOT EXISTS (SELECT 1 FROM sys.server_principals sp WHERE sp.sid = dp.sid)) AS orphaned_users,
  (SELECT COUNT(*) FROM sys.database_permissions p
   WHERE p.state_desc = 'DENY'
     AND EXISTS (SELECT 1 FROM sys.database_permissions p2
       WHERE p2.grantee_principal_id = p.grantee_principal_id
         AND p2.major_id = p.major_id AND p2.minor_id = p.minor_id
         AND p2.state_desc = 'GRANT')) AS conflicting_grant_deny,
  (SELECT COUNT(*) FROM sys.database_principals dp
   JOIN sys.database_role_members drm ON dp.principal_id = drm.member_principal_id
   JOIN sys.database_principals r ON drm.role_principal_id = r.principal_id
   WHERE r.name = 'db_owner'
     AND EXISTS (SELECT 1 FROM sys.database_permissions p
       WHERE p.grantee_principal_id = dp.principal_id AND p.state_desc = 'DENY')) AS db_owner_with_deny
GO

/* ===== SEC-SQL-AZ-001-RC12 — Vendor default configurations ===== */
SELECT
  (SELECT is_disabled FROM sys.server_principals WHERE name = 'sa') AS sa_disabled,
  (SELECT is_disabled FROM sys.server_principals WHERE name = 'BUILTIN\Administrators') AS builtin_admin_exists,
  SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_only_auth,
  (SELECT COUNT(*) FROM sys.databases WHERE name IN ('AdventureWorks', 'Northwind', 'pubs', 'AdventureWorksDW')) AS sample_databases,
  (SELECT 1 FROM sys.database_principals WHERE name = 'guest' AND principal_id = 2) AS guest_access_current_db,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'default trace enabled') AS default_trace_enabled
GO

/* ===== SEC-SQL-AZ-001-RC13 — No centralized identity and access governance ===== */
SELECT
  SUM(CASE WHEN sp.type_desc = 'SQL_LOGIN' AND sp.is_disabled = 0 THEN 1 ELSE 0 END) AS sql_logins,
  SUM(CASE WHEN sp.type_desc = 'WINDOWS_LOGIN' AND sp.is_disabled = 0 THEN 1 ELSE 0 END) AS windows_logins,
  SUM(CASE WHEN sp.type_desc = 'WINDOWS_GROUP' AND sp.is_disabled = 0 THEN 1 ELSE 0 END) AS windows_groups,
  SUM(CASE WHEN sp.type_desc IN ('EXTERNAL_USER', 'EXTERNAL_GROUP') AND sp.is_disabled = 0 THEN 1 ELSE 0 END) AS azure_ad_principals,
  SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_only_auth
FROM sys.server_principals sp
WHERE sp.principal_id > 10
  AND sp.name NOT LIKE '##%'
GO

/* ===== SEC-SQL-AZ-001-RC14 — Shared service and application accounts ===== */
SELECT sp.name AS login_name, sp.type_desc, sp.create_date, sp.modify_date,
  sr.name AS role_name,
  sp.is_disabled,
  (SELECT MAX(s.login_time) FROM sys.dm_exec_sessions s WHERE s.login_name = sp.name) AS last_session_time
FROM sys.server_principals sp
JOIN sys.server_role_members srm ON sp.principal_id = srm.member_principal_id
JOIN sys.server_principals sr ON srm.role_principal_id = sr.principal_id
WHERE sr.name IN ('sysadmin', 'securityadmin', 'serveradmin', 'dbcreator')
  AND sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
  AND sp.name NOT IN ('sa')
  AND (
    sp.name LIKE '%svc%' OR sp.name LIKE '%app%' OR sp.name LIKE '%service%'
    OR sp.name LIKE '%agent%' OR sp.name LIKE '%batch%' OR sp.name LIKE '%job%'
    OR sp.name LIKE '%api%' OR sp.name LIKE '%web%' OR sp.name LIKE '%etl%'
    OR sp.name LIKE '%scheduler%' OR sp.name LIKE '%daemon%'
  )
GO

/* ===== SEC-SQL-AZ-002-RC01 — Misunderstanding of rootcause role scope ===== */
SELECT dp.permission_name, dp.class_desc,
  COALESCE(OBJECT_NAME(dp.major_id), SCHEMA_NAME(dp.major_id), '') AS object_name,
  CASE WHEN dp.permission_name IN ('INSERT', 'UPDATE', 'DELETE', 'EXECUTE', 'ALTER', 'CONTROL')
    THEN 'HIGH_RISK' ELSE 'MODERATE_RISK' END AS risk_level,
  COUNT(*) AS grant_count
FROM sys.database_permissions dp
JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id
WHERE pr.name = 'public'
  AND dp.state_desc = 'GRANT'
  AND dp.class_desc IN ('OBJECT_OR_COLUMN', 'SCHEMA', 'DATABASE', 'TYPE')
  AND dp.major_id > 0
  AND OBJECTPROPERTY(dp.major_id, 'IsMSShipped') = 0
GROUP BY dp.permission_name, dp.class_desc,
  COALESCE(OBJECT_NAME(dp.major_id), SCHEMA_NAME(dp.major_id), '')
ORDER BY risk_level, dp.permission_name
GO

/* ===== SEC-SQL-AZ-002-RC02 — Quick-fix troubleshooting approach ===== */
SELECT dp.permission_name, dp.state_desc, dp.class_desc,
  CASE dp.class_desc
    WHEN 'SCHEMA' THEN SCHEMA_NAME(dp.major_id)
    WHEN 'DATABASE' THEN DB_NAME()
    ELSE COALESCE(OBJECT_NAME(dp.major_id), CAST(dp.major_id AS NVARCHAR(20)))
  END AS scope_name,
  dp.type AS permission_type
FROM sys.database_permissions dp
JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id
WHERE pr.name = 'public'
  AND dp.state_desc = 'GRANT'
  AND (
    (dp.class_desc = 'SCHEMA' AND dp.permission_name IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE', 'EXECUTE', 'ALTER', 'CONTROL'))
    OR (dp.class_desc = 'DATABASE' AND dp.permission_name IN ('CONNECT', 'CREATE TABLE', 'CREATE VIEW', 'CREATE PROCEDURE', 'EXECUTE', 'ALTER ANY SCHEMA'))
  )
GO

/* ===== SEC-SQL-AZ-002-RC03 — Temporary workarounds becoming permanent ===== */
SELECT OBJECT_NAME(dp.major_id) AS object_name,
  dp.permission_name,
  o.create_date,
  COALESCE(ius.last_user_seek, ius.last_user_scan, ius.last_user_lookup, '1900-01-01') AS last_accessed,
  DATEDIFF(DAY,
    COALESCE(ius.last_user_seek, ius.last_user_scan, ius.last_user_lookup, o.create_date),
    GETDATE()) AS days_since_last_access
FROM sys.database_permissions dp
JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id
JOIN sys.objects o ON dp.major_id = o.object_id
LEFT JOIN sys.dm_db_index_usage_stats ius ON o.object_id = ius.object_id AND ius.database_id = DB_ID()
WHERE pr.name = 'public'
  AND dp.state_desc = 'GRANT'
  AND dp.class_desc = 'OBJECT_OR_COLUMN'
  AND o.is_ms_shipped = 0
  AND dp.permission_name IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE', 'EXECUTE')
ORDER BY days_since_last_access DESC
GO

/* ===== SEC-SQL-AZ-002-RC04 — Legacy database practices ===== */
SELECT DB_NAME() AS database_name,
  dp.permission_name, dp.class_desc,
  COALESCE(OBJECT_NAME(dp.major_id), SCHEMA_NAME(dp.major_id), '') AS object_name,
  COUNT(*) AS grant_count
FROM sys.database_permissions dp
JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id
WHERE pr.name = 'public'
  AND dp.state_desc = 'GRANT'
  AND dp.class_desc IN ('OBJECT_OR_COLUMN', 'SCHEMA', 'DATABASE')
  AND dp.major_id > 0
  AND OBJECTPROPERTY(dp.major_id, 'IsMSShipped') = 0
GROUP BY dp.permission_name, dp.class_desc,
  COALESCE(OBJECT_NAME(dp.major_id), SCHEMA_NAME(dp.major_id), '')
GO

/* ===== SEC-SQL-AZ-002-RC05 — Insufficient permission auditing on rootcause ===== */
SELECT sa.name AS audit_name,
  sas.name AS spec_name, sas.is_state_enabled,
  sasd.audit_action_name
FROM sys.server_audits sa
LEFT JOIN sys.server_audit_specifications sas ON sa.audit_guid = sas.audit_guid
LEFT JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
WHERE sa.is_state_enabled = 1
  AND sas.is_state_enabled = 1
  AND sasd.audit_action_name IN (
    'DATABASE_PERMISSION_CHANGE_GROUP', 'SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP',
    'SERVER_PERMISSION_CHANGE_GROUP', 'DATABASE_ROLE_MEMBER_CHANGE_GROUP')
GO

/* ===== SEC-SQL-AZ-002-RC06 — Default view permissions in system objects ===== */
SELECT dp.permission_name, dp.class_desc,
  OBJECT_SCHEMA_NAME(dp.major_id) AS schema_name,
  OBJECT_NAME(dp.major_id) AS object_name,
  o.type_desc
FROM sys.database_permissions dp
JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id
JOIN sys.objects o ON dp.major_id = o.object_id
WHERE pr.name = 'public'
  AND dp.state_desc = 'GRANT'
  AND o.is_ms_shipped = 1
  AND dp.permission_name IN ('VIEW DEFINITION', 'SELECT', 'EXECUTE')
  AND OBJECT_SCHEMA_NAME(dp.major_id) NOT IN ('sys', 'INFORMATION_SCHEMA')
GO

/* ===== SEC-SQL-AZ-002-RC07 — Confusion between schema and database-level rootcause ===== */
SELECT SCHEMA_NAME(dp.major_id) AS schema_name,
  dp.permission_name, dp.state_desc,
  dp.class_desc
FROM sys.database_permissions dp
JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id
WHERE pr.name = 'public'
  AND dp.class_desc = 'SCHEMA'
  AND dp.state_desc = 'GRANT'
  AND dp.permission_name IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE', 'EXECUTE', 'ALTER', 'CONTROL',
    'VIEW DEFINITION', 'REFERENCES', 'CREATE SEQUENCE', 'TAKE OWNERSHIP')
GO

/* ===== SEC-SQL-AZ-002-RC08 — Testing/development configuration copied to production ===== */
SELECT DB_NAME() AS database_name,
  dp.permission_name, dp.class_desc,
  CASE dp.class_desc
    WHEN 'SCHEMA' THEN SCHEMA_NAME(dp.major_id)
    WHEN 'OBJECT_OR_COLUMN' THEN OBJECT_NAME(dp.major_id)
    WHEN 'DATABASE' THEN DB_NAME()
    ELSE '' END AS scope,
  COUNT(*) AS grant_count
FROM sys.database_permissions dp
JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id
WHERE pr.name = 'public'
  AND dp.state_desc = 'GRANT'
  AND dp.class_desc IN ('OBJECT_OR_COLUMN', 'SCHEMA', 'DATABASE')
  AND dp.permission_name IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE', 'EXECUTE', 'ALTER', 'CONTROL')
  AND (dp.major_id = 0 OR OBJECTPROPERTY(dp.major_id, 'IsMSShipped') = 0)
GROUP BY dp.permission_name, dp.class_desc,
  CASE dp.class_desc
    WHEN 'SCHEMA' THEN SCHEMA_NAME(dp.major_id)
    WHEN 'OBJECT_OR_COLUMN' THEN OBJECT_NAME(dp.major_id)
    WHEN 'DATABASE' THEN DB_NAME()
    ELSE '' END
HAVING COUNT(*) >= 1
GO

/* ===== SEC-SQL-AZ-002-RC09 — Bulk permission scripts without proper restriction ===== */
SELECT dp.permission_name, o.type_desc,
  COUNT(*) AS objects_with_grant,
  (SELECT COUNT(*) FROM sys.objects o2 WHERE o2.type = o.type AND o2.is_ms_shipped = 0) AS total_objects_of_type,
  CAST(COUNT(*) * 100.0 / NULLIF((SELECT COUNT(*) FROM sys.objects o2 WHERE o2.type = o.type AND o2.is_ms_shipped = 0), 0) AS DECIMAL(5,1)) AS pct_covered
FROM sys.database_permissions dp
JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id
JOIN sys.objects o ON dp.major_id = o.object_id
WHERE pr.name = 'public'
  AND dp.state_desc = 'GRANT'
  AND dp.class_desc = 'OBJECT_OR_COLUMN'
  AND o.is_ms_shipped = 0
  AND dp.permission_name IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE', 'EXECUTE')
GROUP BY dp.permission_name, o.type_desc, o.type
HAVING COUNT(*) >= 5
GO

/* ===== SEC-SQL-AZ-002-RC10 — Lack of role-based alternative ===== */
SELECT
  (SELECT COUNT(*) FROM sys.database_permissions dp
   JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id
   WHERE pr.name = 'public' AND dp.state_desc = 'GRANT'
   AND dp.class_desc IN ('OBJECT_OR_COLUMN', 'SCHEMA')
   AND dp.major_id > 0 AND OBJECTPROPERTY(dp.major_id, 'IsMSShipped') = 0) AS public_user_grants,
  (SELECT COUNT(*) FROM sys.database_principals
   WHERE type = 'R' AND is_fixed_role = 0
   AND name NOT IN ('public', 'dbo', 'guest', 'INFORMATION_SCHEMA', 'sys')) AS custom_roles,
  (SELECT COUNT(*) FROM sys.database_permissions dp
   JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id
   WHERE pr.type = 'R' AND pr.is_fixed_role = 0
   AND pr.name NOT IN ('public', 'dbo')
   AND dp.state_desc = 'GRANT'
   AND dp.class_desc IN ('OBJECT_OR_COLUMN', 'SCHEMA')) AS custom_role_grants
GO

/* ===== SEC-SQL-AZ-002-RC11 — Incompletely implemented permission revocation ===== */
SELECT dp.permission_name, dp.state_desc,
  dp.class_desc,
  COUNT(*) AS permission_count
FROM sys.database_permissions dp
JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id
WHERE pr.name = 'public'
  AND dp.class_desc IN ('OBJECT_OR_COLUMN', 'SCHEMA', 'DATABASE')
  AND dp.state_desc IN ('GRANT', 'DENY')
  AND dp.major_id > 0
GROUP BY dp.permission_name, dp.state_desc, dp.class_desc
ORDER BY dp.permission_name, dp.state_desc
GO

/* ===== SEC-SQL-AZ-002-RC12 — Tool or vendor recommendations that are unsafe ===== */
SELECT OBJECT_SCHEMA_NAME(dp.major_id) AS schema_name,
  OBJECT_NAME(dp.major_id) AS proc_name,
  dp.permission_name,
  COALESCE(sm.definition, '') AS proc_definition_preview
FROM sys.database_permissions dp
JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id
JOIN sys.objects o ON dp.major_id = o.object_id
LEFT JOIN sys.sql_modules sm ON o.object_id = sm.object_id
WHERE pr.name = 'public'
  AND dp.state_desc = 'GRANT'
  AND dp.permission_name = 'EXECUTE'
  AND o.is_ms_shipped = 0
  AND o.type IN ('P', 'FN', 'IF', 'TF')
GO

/* ===== SEC-SQL-AZ-002-RC13 — Emergency access during incidents ===== */
SELECT dp.permission_name, dp.class_desc,
  OBJECT_SCHEMA_NAME(dp.major_id) AS schema_name,
  OBJECT_NAME(dp.major_id) AS object_name,
  o.modify_date,
  DATEDIFF(DAY, o.modify_date, GETDATE()) AS days_since_modified
FROM sys.database_permissions dp
JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id
JOIN sys.objects o ON dp.major_id = o.object_id
WHERE pr.name = 'public'
  AND dp.state_desc = 'GRANT'
  AND o.is_ms_shipped = 0
  AND dp.permission_name IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE', 'EXECUTE', 'ALTER', 'CONTROL')
GO

/* ===== SEC-SQL-AZ-003-RC01 — Absence of user lifecycle management automation ===== */
SELECT dp_user.name AS orphaned_user, dp_user.type_desc,
  perm.permission_name, perm.state_desc, perm.class_desc,
  COALESCE(OBJECT_NAME(perm.major_id), SCHEMA_NAME(perm.major_id), '') AS object_name,
  rm.role_name
FROM sys.database_principals dp_user
LEFT JOIN sys.server_principals sp ON dp_user.sid = sp.sid
LEFT JOIN sys.database_permissions perm ON dp_user.principal_id = perm.grantee_principal_id
LEFT JOIN (
  SELECT drm.member_principal_id,
    STRING_AGG(dp_role.name, ', ') AS role_name
  FROM sys.database_role_members drm
  JOIN sys.database_principals dp_role ON drm.role_principal_id = dp_role.principal_id
  GROUP BY drm.member_principal_id
) rm ON dp_user.principal_id = rm.member_principal_id
WHERE dp_user.type IN ('S', 'U', 'G')
  AND sp.sid IS NULL
  AND dp_user.name NOT IN ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys', 'MS_DataCollectorInternalUser')
  AND dp_user.name NOT LIKE '##%'
  AND dp_user.authentication_type <> 0
  AND (perm.permission_name IS NOT NULL OR rm.role_name IS NOT NULL)
GO

/* ===== SEC-SQL-AZ-003-RC02 — Manual offboarding processes with gaps ===== */
SELECT dp.name AS user_name, dp.type_desc, dp.sid,
  dp.create_date, dp.modify_date,
  DATEDIFF(DAY, dp.modify_date, GETDATE()) AS days_since_modified,
  DB_NAME() AS database_name
FROM sys.database_principals dp
LEFT JOIN sys.server_principals sp ON dp.sid = sp.sid
WHERE dp.type IN ('S', 'U', 'G')
  AND sp.sid IS NULL
  AND dp.name NOT IN ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys', 'MS_DataCollectorInternalUser')
  AND dp.name NOT LIKE '##%'
  AND dp.authentication_type <> 0
GO

/* ===== SEC-SQL-AZ-003-RC03 — Delayed or forgotten deprovisioning ===== */
SELECT dp.name AS user_name, dp.type_desc,
  dp.create_date, dp.modify_date,
  DATEDIFF(DAY, dp.modify_date, GETDATE()) AS days_orphaned_estimate,
  DB_NAME() AS database_name
FROM sys.database_principals dp
LEFT JOIN sys.server_principals sp ON dp.sid = sp.sid
WHERE dp.type IN ('S', 'U', 'G')
  AND sp.sid IS NULL
  AND dp.name NOT IN ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys', 'MS_DataCollectorInternalUser')
  AND dp.name NOT LIKE '##%'
  AND dp.authentication_type <> 0
  AND DATEDIFF(DAY, dp.modify_date, GETDATE()) > 90
GO

/* ===== SEC-SQL-AZ-003-RC04 — Lack of integration between HR systems and database access ===== */
SELECT
  SUM(CASE WHEN sp.type = 'S' THEN 1 ELSE 0 END) AS sql_logins,
  SUM(CASE WHEN sp.type = 'U' THEN 1 ELSE 0 END) AS windows_logins,
  SUM(CASE WHEN sp.type = 'G' THEN 1 ELSE 0 END) AS windows_groups,
  COUNT(*) AS total_logins,
  CAST(SUM(CASE WHEN sp.type = 'S' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0) AS DECIMAL(5,1)) AS pct_sql_auth
FROM sys.server_principals sp
WHERE sp.type IN ('S', 'U', 'G')
  AND sp.name NOT LIKE '##%'
  AND sp.name NOT IN ('sa')
  AND sp.is_disabled = 0
GO

/* ===== SEC-SQL-AZ-003-RC05 — No reconciliation process between database accounts and authorized users ===== */
SELECT sp.name AS login_name, sp.type_desc,
  sp.create_date, sp.modify_date,
  sp.is_disabled,
  DATEDIFF(DAY, sp.create_date, GETDATE()) AS days_since_created,
  (SELECT MAX(s.login_time) FROM sys.dm_exec_sessions s WHERE s.login_name = sp.name) AS last_session_time
FROM sys.server_principals sp
WHERE sp.type IN ('S', 'U')
  AND sp.name NOT LIKE '##%'
  AND sp.name NOT IN ('sa')
  AND sp.is_disabled = 0
  AND NOT EXISTS (
    SELECT 1 FROM sys.dm_exec_sessions s WHERE s.login_name = sp.name
  )
  AND DATEDIFF(DAY, sp.create_date, GETDATE()) > 30
GO

/* ===== SEC-SQL-AZ-003-RC06 — Service and application accounts without ownership tracking ===== */
SELECT sp.name AS login_name,
  sp.create_date AS login_created,
  DATEDIFF(DAY, sp.create_date, GETDATE()) AS age_days,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set,
  CASE WHEN LOGINPROPERTY(sp.name, 'IsExpired') = 1 THEN 'EXPIRED'
    WHEN LOGINPROPERTY(sp.name, 'IsLocked') = 1 THEN 'LOCKED'
    WHEN LOGINPROPERTY(sp.name, 'IsMustChange') = 1 THEN 'MUST_CHANGE'
    ELSE 'ACTIVE' END AS password_status,
  (SELECT COUNT(*) FROM sys.dm_exec_sessions s WHERE s.login_name = sp.name) AS current_sessions
FROM sys.server_principals sp
WHERE sp.type = 'S'
  AND sp.name NOT LIKE '##%'
  AND sp.name NOT IN ('sa')
  AND sp.is_disabled = 0
  AND (
    sp.name LIKE '%svc%' OR sp.name LIKE '%app%' OR sp.name LIKE '%service%'
    OR sp.name LIKE '%agent%' OR sp.name LIKE '%batch%' OR sp.name LIKE '%job%'
    OR sp.name LIKE '%api%' OR sp.name LIKE '%web%' OR sp.name LIKE '%etl%'
    OR sp.name LIKE '%scheduler%' OR sp.name LIKE '%daemon%' OR sp.name LIKE '%system%'
  )
  AND DATEDIFF(DAY, sp.create_date, GETDATE()) > 180
GO

/* ===== SEC-SQL-AZ-003-RC07 — Contractor and vendor accounts without explicit end dates ===== */
SELECT sp.name AS login_name, sp.type_desc, sp.create_date,
  sl.is_expiration_checked, sl.is_policy_checked,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set,
  DATEDIFF(DAY, sp.create_date, GETDATE()) AS account_age_days
FROM sys.server_principals sp
JOIN sys.sql_logins sl ON sp.principal_id = sl.principal_id
WHERE sl.is_expiration_checked = 0
  AND sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
  AND (
    sp.name LIKE '%vendor%' OR sp.name LIKE '%contractor%'
    OR sp.name LIKE '%consultant%' OR sp.name LIKE '%external%'
    OR sp.name LIKE '%partner%' OR sp.name LIKE '%temp%'
    OR sp.name LIKE '%3rd%' OR sp.name LIKE '%third%'
    OR DATEDIFF(DAY, sp.create_date, GETDATE()) > 365
  )
GO

/* ===== SEC-SQL-AZ-003-RC08 — Shared database accounts and credentials ===== */
SELECT sp.name AS login_name, sp.type_desc, sp.create_date,
  sp.is_disabled,
  (SELECT COUNT(*) FROM sys.dm_exec_sessions s WHERE s.login_name = sp.name AND s.is_user_process = 1) AS active_sessions,
  (SELECT COUNT(DISTINCT s.host_name) FROM sys.dm_exec_sessions s WHERE s.login_name = sp.name AND s.is_user_process = 1) AS distinct_hosts
FROM sys.server_principals sp
WHERE sp.type_desc = 'SQL_LOGIN'
  AND sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
  AND (
    sp.name LIKE '%app%' OR sp.name LIKE '%service%'
    OR sp.name LIKE '%admin%' OR sp.name LIKE '%test%'
    OR sp.name LIKE '%user%' OR sp.name LIKE '%shared%'
    OR sp.name LIKE '%generic%' OR sp.name LIKE '%common%'
    OR sp.name LIKE '%default%' OR sp.name LIKE '%dev%'
  )
  AND sp.name NOT IN ('sa')
GO

/* ===== SEC-SQL-AZ-003-RC09 — Cross-database and application account complexity ===== */
SELECT dp.name AS user_name, dp.type_desc,
  dr.name AS role_name,
  dp.create_date, dp.modify_date,
  CASE WHEN sp.sid IS NULL THEN 'ORPHANED' ELSE 'MAPPED' END AS mapping_status
FROM sys.database_principals dp
JOIN sys.database_role_members drm ON dp.principal_id = drm.member_principal_id
JOIN sys.database_principals dr ON drm.role_principal_id = dr.principal_id
LEFT JOIN sys.server_principals sp ON dp.sid = sp.sid
WHERE dp.type IN ('S', 'U', 'G')
  AND dp.name NOT IN ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys')
  AND dp.sid IS NOT NULL AND dp.sid <> 0x00
ORDER BY dp.name, dr.name
GO

/* ===== SEC-SQL-AZ-003-RC10 — Legacy account creation without documentation ===== */
SELECT sp.name AS login_name,
  sp.create_date,
  DATEDIFF(DAY, sp.create_date, GETDATE()) AS account_age_days,
  (SELECT COUNT(*) FROM sys.dm_exec_sessions s WHERE s.login_name = sp.name AND s.is_user_process = 1) AS active_sessions,
  CASE WHEN EXISTS (
    SELECT 1 FROM sys.extended_properties ep
    WHERE ep.class = 0 AND ep.name LIKE '%owner%' OR ep.name LIKE '%purpose%' OR ep.name LIKE '%ticket%'
  ) THEN 1 ELSE 0 END AS has_documentation
FROM sys.server_principals sp
JOIN sys.sql_logins sl ON sp.principal_id = sl.principal_id
WHERE sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
  AND sp.name NOT IN ('sa')
  AND DATEDIFF(DAY, sp.create_date, GETDATE()) > 365
GO

/* ===== SEC-SQL-AZ-003-RC11 — Database environment fragmentation ===== */
SELECT
  (SELECT COUNT(*) FROM sys.databases WHERE state = 0 AND database_id > 4) AS user_database_count,
  (SELECT COUNT(*) FROM sys.server_principals WHERE type IN ('S', 'U', 'G') AND is_disabled = 0 AND name NOT LIKE '##%') AS active_login_count,
  (SELECT COUNT(*) FROM sys.server_principals WHERE type IN ('S', 'U', 'G') AND is_disabled = 0 AND name NOT LIKE '##%') * 1.0 /
    NULLIF((SELECT COUNT(*) FROM sys.databases WHERE state = 0 AND database_id > 4), 0) AS logins_per_database
GO

/* ===== SEC-SQL-AZ-003-RC12 — Lack of privileged access management (PAM) systems ===== */
SELECT sp.name AS login_name, sp.type_desc,
  sr.name AS server_role,
  sl.is_expiration_checked, sl.is_policy_checked,
  sp.create_date, sp.modify_date,
  LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set
FROM sys.server_principals sp
JOIN sys.server_role_members srm ON sp.principal_id = srm.member_principal_id
JOIN sys.server_principals sr ON srm.role_principal_id = sr.principal_id
JOIN sys.sql_logins sl ON sp.principal_id = sl.principal_id
WHERE sr.name IN ('sysadmin', 'securityadmin', 'serveradmin', 'dbcreator')
  AND sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
  AND (sl.is_expiration_checked = 0 OR sl.is_policy_checked = 0)
GO

/* ===== SEC-SQL-AZ-003-RC13 — Application default accounts never updated ===== */
SELECT sp.name AS login_name,
  sp.create_date,
  STRING_AGG(sr.name, ', ') AS server_roles,
  (SELECT COUNT(*) FROM sys.server_permissions perm WHERE perm.grantee_principal_id = sp.principal_id) AS server_permission_count
FROM sys.server_principals sp
JOIN sys.sql_logins sl ON sp.principal_id = sl.principal_id
LEFT JOIN sys.server_role_members srm ON sp.principal_id = srm.member_principal_id
LEFT JOIN sys.server_principals sr ON srm.role_principal_id = sr.principal_id AND sr.type = 'R'
WHERE sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
  AND (
    sp.name LIKE '%app%' OR sp.name LIKE '%svc%'
    OR sp.name LIKE '%service%' OR sp.name LIKE '%default%'
    OR sp.name LIKE '%webapp%' OR sp.name LIKE '%api%'
  )
  AND (sp.create_date = sp.modify_date
    OR CAST(LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS DATETIME) = sp.create_date)
GROUP BY sp.name, sp.create_date, sp.principal_id
GO

/* ===== SEC-SQL-AZ-003-RC14 — Failed or incomplete migration processes ===== */
SELECT dp.name AS user_name, dp.type_desc,
  dp.create_date, dp.modify_date,
  dp.sid,
  dp.default_schema_name,
  dp.authentication_type_desc
FROM sys.database_principals dp
LEFT JOIN sys.server_principals sp ON dp.sid = sp.sid
WHERE dp.type IN ('S', 'U', 'G')
  AND dp.sid IS NOT NULL
  AND dp.sid <> 0x00
  AND LEN(dp.sid) > 0
  AND sp.sid IS NULL
  AND dp.name NOT IN ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys', 'MS_DataCollectorInternalUser')
GO

/* ===== SEC-SQL-AZ-003-RC15 — Assumption that low-privilege accounts are harmless ===== */
SELECT perm.class_desc,
  OBJECT_SCHEMA_NAME(perm.major_id) AS schema_name,
  OBJECT_NAME(perm.major_id) AS object_name,
  perm.permission_name, perm.state_desc,
  dp.name AS grantee_name
FROM sys.database_permissions perm
JOIN sys.database_principals dp ON perm.grantee_principal_id = dp.principal_id
WHERE dp.name = 'public'
  AND perm.state_desc = 'GRANT'
  AND perm.class_desc = 'OBJECT_OR_COLUMN'
  AND perm.permission_name IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE', 'EXECUTE')
GO

/* ===== SEC-SQL-AZ-004-RC01 — Application requirements for file export functionality ===== */
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

/* ===== SEC-SQL-AZ-004-RC02 — Lack of secure alternatives or awareness of alternatives ===== */
SELECT
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'xp_cmdshell') AS xp_cmdshell_enabled,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'Ole Automation Procedures') AS ole_automation_enabled,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'clr enabled') AS clr_enabled,
  (SELECT COUNT(*) FROM sys.assemblies WHERE permission_set_desc = 'SAFE' AND is_user_defined = 1) AS safe_clr_assemblies,
  (SELECT COUNT(*) FROM msdb.dbo.sysssispackages) AS ssis_packages
GO

/* ===== SEC-SQL-AZ-004-RC03 — Business intelligence and reporting tool requirements ===== */
SELECT sp.name AS login_name, sp.type_desc,
  sp.create_date,
  sr.name AS server_role
FROM sys.server_principals sp
JOIN sys.server_role_members srm ON sp.principal_id = srm.member_principal_id
JOIN sys.server_principals sr ON srm.role_principal_id = sr.principal_id
WHERE sr.name = 'bulkadmin'
  AND sp.is_disabled = 0
GO

/* ===== SEC-SQL-AZ-004-RC04 — Inadequate file operation path restrictions ===== */
SELECT
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'xp_cmdshell') AS xp_cmdshell_enabled,
  (SELECT COUNT(*) FROM sys.credentials WHERE name = '##xp_cmdshell_proxy_account##') AS has_proxy_account,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'Ole Automation Procedures') AS ole_automation_enabled
GO

/* ===== SEC-SQL-AZ-004-RC05 — Default configuration not hardened during installation ===== */
SELECT name,
  CAST(value AS INT) AS configured_value,
  CAST(value_in_use AS INT) AS running_value,
  description
FROM sys.configurations
WHERE name IN (
  'xp_cmdshell',
  'Ole Automation Procedures',
  'Ad Hoc Distributed Queries',
  'clr enabled',
  'clr strict security',
  'show advanced options'
)
ORDER BY name
GO

/* ===== SEC-SQL-AZ-004-RC06 — Developer convenience during development ===== */
SELECT
  (SELECT COUNT(*) FROM sys.server_principals sp
   JOIN sys.server_role_members srm ON sp.principal_id = srm.member_principal_id
   JOIN sys.server_principals sr ON srm.role_principal_id = sr.principal_id
   WHERE sr.name = 'sysadmin' AND sp.is_disabled = 0
     AND sp.name NOT LIKE '##%' AND sp.name NOT IN ('sa')) AS sysadmin_count,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'xp_cmdshell') AS xp_cmdshell_enabled,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'Ole Automation Procedures') AS ole_enabled
GO

/* ===== SEC-SQL-AZ-004-RC07 — Troubleshooting and ad-hoc data extraction ===== */
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

/* ===== SEC-SQL-AZ-004-RC08 — Third-party tool or vendor requirements ===== */
SELECT
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'Ole Automation Procedures') AS ole_automation_enabled,
  (SELECT COUNT(*) FROM sys.assemblies WHERE is_user_defined = 1 AND permission_set_desc IN ('EXTERNAL_ACCESS', 'UNSAFE_ACCESS')) AS external_assemblies,
  (SELECT COUNT(*) FROM sys.server_principals sp
   JOIN sys.server_permissions perm ON sp.principal_id = perm.grantee_principal_id
   WHERE perm.permission_name IN ('EXTERNAL ACCESS ASSEMBLY', 'UNSAFE ASSEMBLY')
     AND perm.state_desc = 'GRANT') AS assembly_permission_grantees,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'Ad Hoc Distributed Queries') AS adhoc_queries_enabled
GO

/* ===== SEC-SQL-AZ-004-RC09 — Historical privilege accumulation ===== */
SELECT sp.name AS login_name, sp.type_desc,
  sp.create_date,
  DATEDIFF(DAY, sp.create_date, GETDATE()) AS account_age_days,
  (SELECT COUNT(*) FROM sys.server_role_members srm
   JOIN sys.server_principals sr ON srm.role_principal_id = sr.principal_id
   WHERE srm.member_principal_id = sp.principal_id
     AND sr.name IN ('sysadmin', 'bulkadmin')) AS privileged_role_count,
  (SELECT COUNT(*) FROM sys.server_permissions perm
   WHERE perm.grantee_principal_id = sp.principal_id
     AND perm.permission_name IN ('ADMINISTER BULK OPERATIONS', 'EXTERNAL ACCESS ASSEMBLY', 'UNSAFE ASSEMBLY', 'CONTROL SERVER')
     AND perm.state_desc = 'GRANT') AS file_access_permissions
FROM sys.server_principals sp
WHERE sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
  AND sp.name NOT IN ('sa')
  AND sp.type IN ('S', 'U', 'G')
GO

/* ===== SEC-SQL-AZ-004-RC10 — Insufficient monitoring of FILE privilege usage ===== */
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

/* ===== SEC-SQL-AZ-004-RC11 — Shared service accounts with FILE privilege ===== */
SELECT sp.name AS login_name, sp.type_desc,
  sp.create_date,
  (SELECT COUNT(*) FROM sys.server_role_members srm
   JOIN sys.server_principals sr ON srm.role_principal_id = sr.principal_id
   WHERE srm.member_principal_id = sp.principal_id
     AND sr.name IN ('sysadmin', 'bulkadmin')) AS privileged_roles,
  (SELECT COUNT(*) FROM sys.server_permissions perm
   WHERE perm.grantee_principal_id = sp.principal_id
     AND perm.permission_name IN ('ADMINISTER BULK OPERATIONS', 'EXTERNAL ACCESS ASSEMBLY', 'UNSAFE ASSEMBLY')
     AND perm.state_desc = 'GRANT') AS file_access_grants,
  (SELECT COUNT(DISTINCT s.host_name) FROM sys.dm_exec_sessions s WHERE s.login_name = sp.name AND s.is_user_process = 1) AS distinct_hosts,
  (SELECT COUNT(DISTINCT s.program_name) FROM sys.dm_exec_sessions s WHERE s.login_name = sp.name AND s.is_user_process = 1) AS distinct_programs
FROM sys.server_principals sp
WHERE sp.is_disabled = 0
  AND sp.type_desc = 'SQL_LOGIN'
  AND sp.name NOT LIKE '##%'
  AND sp.name NOT IN ('sa')
  AND (
    sp.name LIKE '%svc%' OR sp.name LIKE '%service%'
    OR sp.name LIKE '%app%' OR sp.name LIKE '%shared%'
    OR sp.name LIKE '%common%'
  )
GO

/* ===== SEC-SQL-AZ-004-RC12 — Configuration management errors ===== */
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

/* ===== SEC-SQL-AZ-004-RC13 — Privilege grants during emergency scenarios ===== */
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

/* ===== SEC-SQL-AZ-004-RC14 — Misunderstanding of attack vectors ===== */
SELECT c.name AS config_name,
  c.value_in_use AS enabled
FROM sys.configurations c
WHERE c.name IN ('xp_cmdshell', 'Ole Automation Procedures', 'clr enabled', 'Ad Hoc Distributed Queries')
UNION ALL
SELECT 'BULK INSERT permissions' AS config_name,
  CAST(COUNT(*) AS INT) AS enabled
FROM sys.database_permissions dp
JOIN sys.database_principals p ON dp.grantee_principal_id = p.principal_id
WHERE dp.permission_name = 'ADMINISTER BULK OPERATIONS'
  AND dp.state_desc IN ('GRANT', 'GRANT_WITH_GRANT_OPTION')
UNION ALL
SELECT 'EXTERNAL ACCESS CLR assemblies' AS config_name,
  CAST(COUNT(*) AS INT) AS enabled
FROM sys.assemblies
WHERE permission_set_desc IN ('EXTERNAL_ACCESS', 'UNSAFE')
GO

/* ===== SEC-SQL-AZ-005-RC01 — Insufficient understanding of ownership chaining mechanics ===== */
SELECT d.name AS database_name,
  d.is_db_chaining_on,
  sp.name AS db_owner,
  d.create_date,
  (SELECT COUNT(DISTINCT d2.owner_sid)
   FROM sys.databases d2
   WHERE d2.is_db_chaining_on = 1
     AND d2.state = 0
     AND d2.database_id > 4) AS distinct_owner_count
FROM sys.databases d
LEFT JOIN sys.server_principals sp ON d.owner_sid = sp.sid
WHERE d.is_db_chaining_on = 1
  AND d.state = 0
  AND d.database_id > 4
ORDER BY sp.name, d.name
GO

/* ===== SEC-SQL-AZ-005-RC02 — Convenience over security principle ===== */
SELECT d.name AS database_name,
  d.is_db_chaining_on,
  sp.name AS db_owner,
  d.compatibility_level,
  (SELECT value_in_use FROM sys.configurations WHERE name = 'cross db ownership chaining') AS server_level_chaining
FROM sys.databases d
LEFT JOIN sys.server_principals sp ON d.owner_sid = sp.sid
WHERE d.state = 0
  AND d.database_id > 4
  AND (d.is_db_chaining_on = 1
    OR (SELECT value_in_use FROM sys.configurations WHERE name = 'cross db ownership chaining') = 1)
GO

/* ===== SEC-SQL-AZ-005-RC03 — Legacy application design assuming ownership chaining ===== */
SELECT o.name AS object_name,
  o.type_desc,
  OBJECT_DEFINITION(o.object_id) AS definition_preview,
  o.create_date,
  o.modify_date
FROM sys.objects o
WHERE o.type IN ('V', 'P', 'FN', 'IF', 'TF')
  AND OBJECT_DEFINITION(o.object_id) LIKE '%[[]%.%].[[]%' ESCAPE '\'
  AND o.is_ms_shipped = 0
GO

/* ===== SEC-SQL-AZ-005-RC04 — Unclear ownership across multiple databases ===== */
SELECT sp.name AS db_owner,
  COUNT(*) AS databases_owned,
  SUM(CASE WHEN d.is_db_chaining_on = 1 THEN 1 ELSE 0 END) AS chaining_enabled_count,
  STRING_AGG(CASE WHEN d.is_db_chaining_on = 1 THEN d.name END, ', ') AS chaining_databases
FROM sys.databases d
LEFT JOIN sys.server_principals sp ON d.owner_sid = sp.sid
WHERE d.state = 0
  AND d.database_id > 4
GROUP BY sp.name
HAVING SUM(CASE WHEN d.is_db_chaining_on = 1 THEN 1 ELSE 0 END) > 1
GO

/* ===== SEC-SQL-AZ-005-RC05 — Multi-database applications without explicit permission architecture ===== */
SELECT
  (SELECT COUNT(*) FROM sys.certificates WHERE name NOT LIKE '##%') AS user_certificates,
  (SELECT COUNT(*) FROM sys.asymmetric_keys WHERE name NOT LIKE '##%') AS user_asymmetric_keys,
  (SELECT COUNT(*) FROM sys.database_principals WHERE type = 'C') AS cert_mapped_users,
  (SELECT COUNT(*) FROM sys.database_principals WHERE authentication_type_desc = 'DATABASE') AS contained_users,
  (SELECT COUNT(*) FROM sys.database_permissions
   WHERE permission_name IN ('AUTHENTICATE', 'CONNECT')
     AND state_desc IN ('GRANT', 'GRANT_WITH_GRANT_OPTION')) AS explicit_auth_grants
GO

/* ===== SEC-SQL-AZ-005-RC06 — Migration from single-database to multi-database environments ===== */
SELECT
  (SELECT COUNT(*) FROM sys.synonyms WHERE base_object_name LIKE '%[.]%[.]%') AS cross_db_synonyms,
  (SELECT COUNT(*) FROM sys.objects
   WHERE type IN ('V', 'P', 'FN', 'IF', 'TF')
     AND is_ms_shipped = 0
     AND OBJECT_DEFINITION(object_id) LIKE '%[[]%.%].[[]%' ESCAPE '\') AS cross_db_objects,
  (SELECT COUNT(*) FROM sys.databases
   WHERE is_db_chaining_on = 1 AND database_id > 4) AS chaining_db_count
GO

/* ===== SEC-SQL-AZ-005-RC07 — System database requirements ===== */
SELECT
  (SELECT value_in_use FROM sys.configurations WHERE name = 'cross db ownership chaining') AS server_chaining,
  (SELECT COUNT(*) FROM sys.databases WHERE is_db_chaining_on = 1 AND database_id <= 4) AS system_dbs_chaining,
  (SELECT COUNT(*) FROM sys.databases WHERE is_db_chaining_on = 1 AND database_id > 4) AS user_dbs_chaining,
  (SELECT COUNT(*) FROM sys.databases WHERE database_id > 4 AND state = 0) AS total_user_dbs
GO

/* ===== SEC-SQL-AZ-005-RC08 — Lack of audit or monitoring of cross-database access ===== */
SELECT
  (SELECT value_in_use FROM sys.configurations WHERE name = 'cross db ownership chaining') AS server_chaining,
  (SELECT COUNT(*) FROM sys.databases WHERE is_db_chaining_on = 1 AND database_id > 4) AS user_dbs_with_chaining
GO

/* ===== SEC-SQL-AZ-005-RC09 — Testing configurations carried forward to production ===== */
SELECT
  (SELECT value_in_use FROM sys.configurations WHERE name = 'cross db ownership chaining') AS server_chaining,
  (SELECT COUNT(*) FROM sys.databases WHERE is_db_chaining_on = 1 AND database_id > 4) AS dbs_with_chaining,
  (SELECT COUNT(*) FROM sys.databases WHERE is_trustworthy_on = 1 AND database_id > 4) AS dbs_trustworthy,
  (SELECT COUNT(*) FROM sys.server_audits WHERE is_state_enabled = 1) AS active_audits,
  (SELECT COUNT(*) FROM sys.database_permissions WHERE permission_name = 'AUTHENTICATE' AND state_desc = 'DENY') AS authenticate_denies
GO

/* ===== SEC-SQL-AZ-005-RC10 — Third-party vendor requirements or recommendations ===== */
SELECT d.name AS database_name,
  d.is_db_chaining_on,
  sp.name AS db_owner,
  (SELECT COUNT(DISTINCT s.name) FROM sys.schemas s
   WHERE s.name NOT IN ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys', 'db_owner', 'db_accessadmin',
     'db_securityadmin', 'db_ddladmin', 'db_backupoperator', 'db_datareader', 'db_datawriter',
     'db_denydatareader', 'db_denydatawriter')) AS custom_schemas,
  (SELECT COUNT(*) FROM sys.database_principals
   WHERE type IN ('S', 'U', 'G') AND name NOT IN ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys')
     AND is_fixed_role = 0) AS app_users
FROM sys.databases d
LEFT JOIN sys.server_principals sp ON d.owner_sid = sp.sid
WHERE d.is_db_chaining_on = 1
  AND d.state = 0
  AND d.database_id > 4
GO

/* ===== SEC-SQL-AZ-005-RC11 — Incomplete understanding of risk when owner differs ===== */
SELECT d.name AS database_name,
  sp.name AS db_owner,
  d.is_db_chaining_on,
  (SELECT COUNT(DISTINCT d2.owner_sid)
   FROM sys.databases d2
   WHERE d2.is_db_chaining_on = 1
     AND d2.state = 0
     AND d2.database_id > 4) AS distinct_owners_with_chaining,
  (SELECT COUNT(*)
   FROM sys.databases d3
   WHERE d3.is_db_chaining_on = 1
     AND d3.state = 0
     AND d3.database_id > 4) AS total_chaining_dbs
FROM sys.databases d
LEFT JOIN sys.server_principals sp ON d.owner_sid = sp.sid
WHERE d.is_db_chaining_on = 1
  AND d.state = 0
  AND d.database_id > 4
GO

/* ===== SEC-SQL-AZ-005-RC12 — Database isolation principle not enforced ===== */
SELECT
  (SELECT value_in_use FROM sys.configurations WHERE name = 'cross db ownership chaining') AS server_chaining,
  (SELECT COUNT(*) FROM sys.databases WHERE state = 0 AND database_id > 4) AS total_user_dbs,
  (SELECT COUNT(*) FROM sys.databases WHERE is_db_chaining_on = 1 AND state = 0 AND database_id > 4) AS dbs_chaining_on,
  (SELECT COUNT(*) FROM sys.databases WHERE is_trustworthy_on = 1 AND state = 0 AND database_id > 4) AS dbs_trustworthy,
  (SELECT COUNT(DISTINCT owner_sid) FROM sys.databases WHERE state = 0 AND database_id > 4) AS distinct_owners
GO

/* ===== SEC-SQL-AZ-006-RC01 — Overly broad delegation of grant rights ===== */
SELECT sp.name AS principal_name, sp.type_desc,
  perm.permission_name, perm.state_desc,
  perm.class_desc,
  CASE
    WHEN perm.permission_name IN ('CONTROL SERVER', 'ALTER ANY DATABASE', 'ALTER ANY LOGIN',
      'ALTER ANY SERVER ROLE', 'ALTER ANY LINKED SERVER', 'ALTER ANY CREDENTIAL') THEN 'HIGH_IMPACT'
    WHEN perm.permission_name LIKE 'ALTER ANY%' THEN 'MEDIUM_IMPACT'
    ELSE 'STANDARD'
  END AS delegation_risk
FROM sys.server_permissions perm
JOIN sys.server_principals sp ON perm.grantee_principal_id = sp.principal_id
WHERE perm.state_desc = 'GRANT_WITH_GRANT_OPTION'
  AND sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
  AND sp.type IN ('S', 'U', 'G', 'R')
GO

/* ===== SEC-SQL-AZ-006-RC02 — Inadequate understanding of WITH GRANT OPTION implications ===== */
SELECT sp.name AS principal_name, sp.type_desc,
  perm.permission_name, perm.state_desc,
  IS_SRVROLEMEMBER('sysadmin', sp.name) AS is_sysadmin,
  IS_SRVROLEMEMBER('securityadmin', sp.name) AS is_securityadmin
FROM sys.server_permissions perm
JOIN sys.server_principals sp ON perm.grantee_principal_id = sp.principal_id
WHERE perm.state_desc = 'GRANT_WITH_GRANT_OPTION'
  AND sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
  AND IS_SRVROLEMEMBER('sysadmin', sp.name) = 0
GO

/* ===== SEC-SQL-AZ-006-RC03 — Convenience for distributed access management ===== */
SELECT
  CASE WHEN perm.major_id > 0 THEN OBJECT_NAME(perm.major_id) ELSE 'DATABASE_LEVEL' END AS target_object,
  perm.permission_name,
  perm.class_desc,
  COUNT(*) AS grantees_with_grant_option,
  STRING_AGG(dp.name, ', ') AS delegating_principals
FROM sys.database_permissions perm
JOIN sys.database_principals dp ON perm.grantee_principal_id = dp.principal_id
WHERE perm.state_desc = 'GRANT_WITH_GRANT_OPTION'
  AND dp.name NOT IN ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys')
  AND dp.type IN ('S', 'U', 'G')
GROUP BY perm.major_id, perm.permission_name, perm.class_desc
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC
GO

/* ===== SEC-SQL-AZ-006-RC04 — No approval workflow for permission delegation ===== */
SELECT
  (SELECT COUNT(*) FROM sys.server_audits WHERE is_state_enabled = 1) AS active_audits,
  (SELECT COUNT(*)
   FROM sys.server_audit_specifications sas
   JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
   WHERE sas.is_state_enabled = 1
     AND sasd.audit_action_name IN (
       'DATABASE_PERMISSION_CHANGE_GROUP',
       'SERVER_PERMISSION_CHANGE_GROUP',
       'SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP')) AS permission_change_audits,
  (SELECT COUNT(*)
   FROM sys.database_permissions perm
   JOIN sys.database_principals grantor ON perm.grantor_principal_id = grantor.principal_id
   WHERE grantor.name <> 'dbo'
     AND perm.state_desc IN ('GRANT', 'GRANT_WITH_GRANT_OPTION')) AS delegated_grant_count
GO

/* ===== SEC-SQL-AZ-006-RC05 — Inadequate monitoring of grant activity ===== */
SELECT
  (SELECT COUNT(*) FROM sys.server_audits WHERE is_state_enabled = 1) AS active_audits,
  (SELECT COUNT(*)
   FROM sys.server_audit_specifications sas
   JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
   WHERE sas.is_state_enabled = 1
     AND sasd.audit_action_name = 'SERVER_PERMISSION_CHANGE_GROUP') AS server_perm_audit,
  (SELECT COUNT(*)
   FROM sys.server_audit_specifications sas
   JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
   WHERE sas.is_state_enabled = 1
     AND sasd.audit_action_name = 'DATABASE_PERMISSION_CHANGE_GROUP') AS db_perm_audit,
  (SELECT COUNT(*)
   FROM sys.server_audit_specifications sas
   JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
   WHERE sas.is_state_enabled = 1
     AND sasd.audit_action_name = 'SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP') AS schema_perm_audit
GO

/* ===== SEC-SQL-AZ-006-RC06 — Lack of restrictions on re-delegation ===== */
SELECT grantor.name AS grantor_name, grantor.type_desc AS grantor_type,
  dp.name AS grantee_name, dp.type_desc AS grantee_type,
  perm.permission_name, perm.state_desc, perm.class_desc,
  CASE WHEN perm.major_id > 0 THEN OBJECT_NAME(perm.major_id) ELSE NULL END AS object_name
FROM sys.database_permissions perm
JOIN sys.database_principals dp ON perm.grantee_principal_id = dp.principal_id
JOIN sys.database_principals grantor ON perm.grantor_principal_id = grantor.principal_id
WHERE grantor.name <> 'dbo'
  AND dp.name NOT IN ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys')
  AND perm.state_desc IN ('GRANT', 'GRANT_WITH_GRANT_OPTION')
  AND dp.type IN ('S', 'U', 'G', 'R')
GO

/* ===== SEC-SQL-AZ-006-RC07 — Grant option on sensitive privileges ===== */
SELECT sp.name AS principal_name, sp.type_desc,
  perm.permission_name, perm.state_desc, perm.class_desc
FROM sys.server_permissions perm
JOIN sys.server_principals sp ON perm.grantee_principal_id = sp.principal_id
WHERE perm.state_desc = 'GRANT_WITH_GRANT_OPTION'
  AND perm.permission_name IN (
    'CONTROL SERVER', 'ALTER ANY DATABASE', 'ALTER ANY LOGIN',
    'ALTER ANY SERVER ROLE', 'ALTER ANY CREDENTIAL', 'ALTER ANY EVENT SESSION',
    'IMPERSONATE', 'ALTER ANY LINKED SERVER', 'ALTER ANY SERVER AUDIT',
    'AUTHENTICATE SERVER', 'CREATE ANY DATABASE')
  AND sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
GO

/* ===== SEC-SQL-AZ-006-RC08 — Default role configurations including grant option ===== */
SELECT sp.name AS role_name, sp.type_desc,
  perm.permission_name, perm.state_desc, perm.class_desc,
  (SELECT COUNT(*) FROM sys.server_role_members rm
   WHERE rm.role_principal_id = sp.principal_id) AS member_count
FROM sys.server_permissions perm
JOIN sys.server_principals sp ON perm.grantee_principal_id = sp.principal_id
WHERE perm.state_desc = 'GRANT_WITH_GRANT_OPTION'
  AND sp.type = 'R'
  AND sp.name NOT IN ('sysadmin', 'securityadmin', 'serveradmin', 'setupadmin',
    'processadmin', 'diskadmin', 'dbcreator', 'bulkadmin')
GO

/* ===== SEC-SQL-AZ-006-RC09 — Privilege escalation through role membership ===== */
SELECT dp.name AS user_name, dp.type_desc,
  COUNT(DISTINCT rm.role_principal_id) AS role_count,
  (SELECT COUNT(*) FROM sys.database_permissions p
   JOIN sys.database_role_members rm2 ON p.grantee_principal_id = rm2.role_principal_id
   WHERE rm2.member_principal_id = dp.principal_id
     AND p.state_desc = 'GRANT_WITH_GRANT_OPTION') AS inherited_grant_options,
  STRING_AGG(r.name, ', ') AS roles
FROM sys.database_role_members rm
JOIN sys.database_principals dp ON rm.member_principal_id = dp.principal_id
JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
WHERE dp.type IN ('S', 'U', 'G')
  AND dp.name NOT IN ('dbo', 'guest')
GROUP BY dp.name, dp.type_desc, dp.principal_id
HAVING COUNT(DISTINCT rm.role_principal_id) > 1
GO

/* ===== SEC-SQL-AZ-006-RC10 — Separation of duties violations ===== */
SELECT dp.name AS principal_name,
  STRING_AGG(r.name, ', ') AS role_memberships,
  SUM(CASE WHEN r.name IN ('db_datareader', 'db_datawriter') THEN 1 ELSE 0 END) AS data_roles,
  SUM(CASE WHEN r.name IN ('db_owner', 'db_securityadmin', 'db_ddladmin', 'db_accessadmin') THEN 1 ELSE 0 END) AS admin_roles
FROM sys.database_role_members rm
JOIN sys.database_principals dp ON rm.member_principal_id = dp.principal_id
JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
WHERE dp.type IN ('S', 'U', 'G')
  AND dp.name NOT IN ('dbo', 'guest')
GROUP BY dp.name
HAVING SUM(CASE WHEN r.name IN ('db_datareader', 'db_datawriter') THEN 1 ELSE 0 END) > 0
  AND SUM(CASE WHEN r.name IN ('db_owner', 'db_securityadmin', 'db_ddladmin', 'db_accessadmin') THEN 1 ELSE 0 END) > 0
GO

/* ===== SEC-SQL-AZ-006-RC11 — Implicit grant options in template scripts ===== */
SELECT perm.permission_name, perm.class_desc,
  COUNT(DISTINCT dp.principal_id) AS principals_with_grant_option,
  STRING_AGG(dp.name, ', ') AS principal_names
FROM sys.database_permissions perm
JOIN sys.database_principals dp ON perm.grantee_principal_id = dp.principal_id
WHERE perm.state_desc = 'GRANT_WITH_GRANT_OPTION'
  AND dp.name NOT IN ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys')
  AND dp.type IN ('S', 'U', 'G', 'R')
GROUP BY perm.permission_name, perm.class_desc
HAVING COUNT(DISTINCT dp.principal_id) >= 3
ORDER BY COUNT(DISTINCT dp.principal_id) DESC
GO

/* ===== SEC-SQL-AZ-006-RC12 — Compliance framework gaps ===== */
SELECT
  SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_auth_only,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'default trace enabled') AS default_trace_enabled,
  (SELECT COUNT(*) FROM sys.server_audits WHERE is_state_enabled = 1) AS server_audits,
  (SELECT COUNT(*)
   FROM sys.server_audit_specifications sas
   JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
   WHERE sas.is_state_enabled = 1
     AND sasd.audit_action_name IN (
       'FAILED_LOGIN_GROUP', 'SUCCESSFUL_LOGIN_GROUP',
       'LOGIN_CHANGE_PASSWORD_GROUP', 'AUDIT_CHANGE_GROUP')) AS login_audit_actions
GO

/* ===== SEC-SQL-AZ-006-RC13 — Inherited permissions from legacy systems ===== */
SELECT dp.name AS principal_name, dp.type_desc,
  perm.permission_name, perm.state_desc, perm.class_desc,
  CASE WHEN perm.major_id > 0 THEN OBJECT_NAME(perm.major_id) ELSE 'DATABASE_LEVEL' END AS object_name,
  CASE WHEN perm.major_id > 0 THEN
    (SELECT create_date FROM sys.objects WHERE object_id = perm.major_id)
    ELSE NULL END AS object_create_date,
  DB_NAME() AS database_name,
  (SELECT compatibility_level FROM sys.databases WHERE database_id = DB_ID()) AS compat_level
FROM sys.database_permissions perm
JOIN sys.database_principals dp ON perm.grantee_principal_id = dp.principal_id
WHERE perm.state_desc = 'GRANT_WITH_GRANT_OPTION'
  AND dp.name NOT IN ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys')
  AND dp.type IN ('S', 'U', 'G', 'R')
GO

/* ===== SEC-SQL-AZ-006-RC14 — Confusion between intent and capability ===== */
SELECT dp.name AS principal_name, dp.type_desc,
  perm.permission_name, perm.state_desc,
  CASE WHEN perm.major_id > 0 THEN OBJECT_NAME(perm.major_id) ELSE 'DATABASE_LEVEL' END AS object_name
FROM sys.database_permissions perm
JOIN sys.database_principals dp ON perm.grantee_principal_id = dp.principal_id
WHERE perm.state_desc = 'GRANT_WITH_GRANT_OPTION'
  AND perm.permission_name IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE', 'EXECUTE', 'REFERENCES', 'VIEW DEFINITION')
  AND dp.name NOT IN ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys')
  AND dp.type IN ('S', 'U', 'G')
  AND IS_ROLEMEMBER('db_owner', dp.name) = 0
  AND IS_ROLEMEMBER('db_securityadmin', dp.name) = 0
GO

/* ===== SEC-SQL-CFG-001-RC01 — Legacy Application Compatibility ===== */
SELECT name, CAST(value_in_use AS INT) AS is_enabled,
  description
FROM sys.configurations
WHERE name IN ('xp_cmdshell', 'Ole Automation Procedures', 'show advanced options')
GO

/* ===== SEC-SQL-CFG-001-RC02 — Third-Party Vendor Requirements ===== */
SELECT name, CAST(value_in_use AS INT) AS is_enabled,
  description
FROM sys.configurations
WHERE name IN ('xp_cmdshell', 'Ole Automation Procedures', 'show advanced options')
GO

/* ===== SEC-SQL-CFG-001-RC03 — Administrative Troubleshooting Convenience ===== */
SELECT
  (SELECT COUNT(*) FROM sys.objects
   WHERE type = 'P' AND is_ms_shipped = 0
     AND OBJECT_DEFINITION(object_id) LIKE '%xp_cmdshell%') AS procs_using_cmdshell,
  (SELECT COUNT(*) FROM msdb.dbo.sysjobsteps
   WHERE command LIKE '%xp_cmdshell%') AS job_steps_using_cmdshell,
  (SELECT COUNT(*) FROM sys.triggers
   WHERE OBJECT_DEFINITION(object_id) LIKE '%xp_cmdshell%') AS triggers_using_cmdshell
GO

/* ===== SEC-SQL-CFG-001-RC04 — Inadequate Change Control ===== */
SELECT
  (SELECT COUNT(*) FROM sys.server_audits WHERE is_state_enabled = 1) AS active_audits,
  (SELECT COUNT(*)
   FROM sys.server_audit_specifications sas
   JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
   WHERE sas.is_state_enabled = 1
     AND sasd.audit_action_name IN ('SERVER_OPERATION_GROUP', 'AUDIT_CHANGE_GROUP')) AS config_change_audits,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'default trace enabled') AS default_trace
GO

/* ===== SEC-SQL-CFG-001-RC05 — SQL Injection Vulnerability ===== */
SELECT sp.name AS login_name, sp.type_desc,
  sp.is_policy_checked, sp.is_expiration_checked,
  CASE WHEN sp.type = 'S' THEN 'SQL_LOGIN' ELSE 'WINDOWS_LOGIN' END AS auth_type,
  LOGINPROPERTY(sp.name, 'DaysUntilExpiration') AS days_until_expiration
FROM sys.sql_logins sp
WHERE sp.is_disabled = 0
  AND sp.name NOT LIKE '##%'
  AND sp.name <> 'sa'
  AND sp.type = 'S'
GO

/* ===== SEC-SQL-CFG-001-RC06 — Excessive Service Account Privileges ===== */
SELECT servicename, service_account, status_desc,
  CASE
    WHEN service_account LIKE '%LocalSystem%' THEN 'LOCAL_SYSTEM_HIGH_RISK'
    WHEN service_account LIKE '%Administrator%' THEN 'ADMIN_HIGH_RISK'
    WHEN service_account LIKE 'NT AUTHORITY\SYSTEM' THEN 'LOCAL_SYSTEM_HIGH_RISK'
    WHEN service_account LIKE 'NT AUTHORITY\NetworkService' THEN 'NETWORK_SERVICE_MODERATE'
    WHEN service_account LIKE 'NT Service\%' THEN 'VIRTUAL_ACCOUNT_LOW_RISK'
    ELSE 'DOMAIN_ACCOUNT_CHECK_PRIVILEGES'
  END AS privilege_assessment
FROM sys.dm_server_services
WHERE servicename LIKE 'SQL Server%'
GO

/* ===== SEC-SQL-CFG-001-RC07 — Lack of Monitoring and Auditing ===== */
SELECT
  (SELECT COUNT(*) FROM sys.server_audits WHERE is_state_enabled = 1) AS active_audits,
  (SELECT COUNT(*)
   FROM sys.server_audit_specifications sas
   JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
   WHERE sas.is_state_enabled = 1
     AND sasd.audit_action_name IN (
       'SERVER_OPERATION_GROUP',
       'SCHEMA_OBJECT_ACCESS_GROUP',
       'DATABASE_OBJECT_ACCESS_GROUP')) AS access_audit_actions,
  (SELECT COUNT(*)
   FROM sys.server_audit_specifications sas
   JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
   WHERE sas.is_state_enabled = 1
     AND sasd.audit_action_name = 'USER_DEFINED_AUDIT_GROUP') AS custom_audit_actions
GO

/* ===== SEC-SQL-CFG-001-RC08 — Knowledge Gap on Alternatives ===== */
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

/* ===== SEC-SQL-CFG-001-RC09 — Privilege Escalation via Weak Credentials ===== */
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

/* ===== SEC-SQL-CFG-001-RC10 — Lateral Movement Capability ===== */
SELECT s.name AS linked_server_name, s.data_source,
  s.is_rpc_out_enabled, s.is_data_access_enabled,
  s.is_remote_login_enabled,
  CASE WHEN s.is_rpc_out_enabled = 1 THEN 'CAN_EXEC_REMOTE_PROCS' ELSE 'DATA_ONLY' END AS rpc_capability,
  (SELECT COUNT(*) FROM sys.linked_logins ll
   WHERE ll.server_id = s.server_id AND ll.uses_self_credential = 1) AS self_credential_mappings
FROM sys.servers s
WHERE s.is_linked = 1
GO

/* ===== SEC-SQL-CFG-001-RC11 — Persistence Mechanisms ===== */
SELECT j.name AS job_name, j.enabled,
  j.date_created, j.date_modified,
  sp.name AS job_owner,
  js.step_name, js.command,
  CASE WHEN DATEDIFF(DAY, j.date_modified, GETDATE()) < 30 THEN 'RECENTLY_MODIFIED'
    WHEN DATEDIFF(DAY, j.date_created, GETDATE()) < 30 THEN 'RECENTLY_CREATED'
    ELSE 'ESTABLISHED' END AS recency,
  (SELECT TOP 1 jh.run_date FROM msdb.dbo.sysjobhistory jh
   WHERE jh.job_id = j.job_id ORDER BY jh.run_date DESC) AS last_run_date
FROM msdb.dbo.sysjobs j
JOIN msdb.dbo.sysjobsteps js ON j.job_id = js.job_id
JOIN sys.server_principals sp ON j.owner_sid = sp.sid
WHERE js.command LIKE '%xp_cmdshell%'
ORDER BY j.date_modified DESC
GO

/* ===== SEC-SQL-CFG-001-RC12 — Backup Restoration from Compromised Environments ===== */
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

/* ===== SEC-SQL-CFG-003-RC01 — Default Installation Artifacts ===== */
SELECT d.name AS database_name,
  d.create_date,
  d.state_desc,
  d.recovery_model_desc,
  sp.name AS db_owner,
  CASE
    WHEN d.name IN ('AdventureWorks', 'AdventureWorks2014', 'AdventureWorks2016', 'AdventureWorks2017', 'AdventureWorks2019', 'AdventureWorks2022') THEN 'ADVENTUREWORKS_SAMPLE'
    WHEN d.name IN ('AdventureWorksDW', 'AdventureWorksDW2014', 'AdventureWorksDW2016', 'AdventureWorksDW2017', 'AdventureWorksDW2019', 'AdventureWorksDW2022') THEN 'ADVENTUREWORKS_DW_SAMPLE'
    WHEN d.name IN ('AdventureWorksLT', 'AdventureWorksLT2014', 'AdventureWorksLT2016', 'AdventureWorksLT2017', 'AdventureWorksLT2019', 'AdventureWorksLT2022') THEN 'ADVENTUREWORKS_LT_SAMPLE'
    WHEN d.name IN ('WideWorldImporters', 'WideWorldImportersDW') THEN 'WWI_SAMPLE'
    WHEN d.name IN ('Northwind', 'pubs') THEN 'LEGACY_SAMPLE'
    ELSE 'KNOWN_SAMPLE'
  END AS sample_type
FROM sys.databases d
LEFT JOIN sys.server_principals sp ON d.owner_sid = sp.sid
WHERE d.name IN (
  'AdventureWorks', 'AdventureWorks2014', 'AdventureWorks2016', 'AdventureWorks2017', 'AdventureWorks2019', 'AdventureWorks2022',
  'AdventureWorksDW', 'AdventureWorksDW2014', 'AdventureWorksDW2016', 'AdventureWorksDW2017', 'AdventureWorksDW2019', 'AdventureWorksDW2022',
  'AdventureWorksLT', 'AdventureWorksLT2014', 'AdventureWorksLT2016', 'AdventureWorksLT2017', 'AdventureWorksLT2019', 'AdventureWorksLT2022',
  'WideWorldImporters', 'WideWorldImportersDW',
  'Northwind', 'pubs')
  AND d.state = 0
GO

/* ===== SEC-SQL-CFG-003-RC02 — Development Environment Cloning ===== */
SELECT d.name AS database_name,
  d.recovery_model_desc,
  d.is_auto_shrink_on,
  d.is_auto_close_on,
  d.page_verify_option_desc,
  d.is_trustworthy_on,
  d.is_db_chaining_on,
  CASE WHEN d.recovery_model_desc = 'SIMPLE' THEN 1 ELSE 0 END
    + CASE WHEN d.is_auto_shrink_on = 1 THEN 1 ELSE 0 END
    + CASE WHEN d.is_auto_close_on = 1 THEN 1 ELSE 0 END
    + CASE WHEN d.is_trustworthy_on = 1 THEN 1 ELSE 0 END
    + CASE WHEN d.page_verify_option_desc <> 'CHECKSUM' THEN 1 ELSE 0 END AS dev_setting_count
FROM sys.databases d
WHERE d.state = 0
  AND d.database_id > 4
  AND (d.name LIKE '%test%' OR d.name LIKE '%Test%' OR d.name LIKE '%TEST%'
    OR d.name LIKE '%dev%' OR d.name LIKE '%Dev%' OR d.name LIKE '%DEV%'
    OR d.name LIKE '%sandbox%' OR d.name LIKE '%Sandbox%'
    OR d.name LIKE '%staging%' OR d.name LIKE '%Staging%'
    OR d.name LIKE '%QA%' OR d.name LIKE '%qa%'
    OR d.name LIKE '%demo%' OR d.name LIKE '%Demo%'
    OR d.name LIKE '%sample%' OR d.name LIKE '%Sample%'
    OR (d.name LIKE '%temp%' AND d.name <> 'tempdb')
    OR d.name LIKE '%tmp%')
GO

/* ===== SEC-SQL-CFG-003-RC03 — Backup Restoration Error ===== */
SELECT rh.destination_database_name AS restored_as,
  bs.database_name AS original_name,
  bs.server_name AS source_server,
  rh.restore_date,
  rh.user_name AS restored_by,
  CASE
    WHEN bs.database_name IN ('AdventureWorks', 'AdventureWorks2014', 'AdventureWorks2016', 'AdventureWorks2017',
      'AdventureWorks2019', 'AdventureWorks2022', 'AdventureWorksDW', 'AdventureWorksLT',
      'WideWorldImporters', 'WideWorldImportersDW', 'Northwind', 'pubs') THEN 'SAMPLE_SOURCE'
    WHEN bs.database_name LIKE '%test%' OR bs.database_name LIKE '%dev%' THEN 'TEST_SOURCE'
    WHEN bs.database_name <> rh.destination_database_name THEN 'CROSS_RESTORE'
    ELSE 'NORMAL_RESTORE'
  END AS restore_classification
FROM msdb.dbo.restorehistory rh
JOIN msdb.dbo.backupset bs ON rh.backup_set_id = bs.backup_set_id
WHERE rh.restore_date >= DATEADD(YEAR, -1, GETDATE())
  AND (bs.database_name IN ('AdventureWorks', 'AdventureWorks2014', 'AdventureWorks2016', 'AdventureWorks2017',
    'AdventureWorks2019', 'AdventureWorks2022', 'AdventureWorksDW', 'AdventureWorksLT',
    'WideWorldImporters', 'WideWorldImportersDW', 'Northwind', 'pubs')
    OR bs.database_name LIKE '%test%' OR bs.database_name LIKE '%dev%' OR bs.database_name LIKE '%sample%')
ORDER BY rh.restore_date DESC
GO

/* ===== SEC-SQL-CFG-003-RC04 — Migration Process Gaps ===== */
SELECT d.name AS database_name,
  d.create_date,
  d.compatibility_level,
  d.state_desc,
  sp.name AS db_owner,
  DATEDIFF(DAY, d.create_date, GETDATE()) AS age_days,
  (SELECT MIN(d2.create_date) FROM sys.databases d2 WHERE d2.database_id > 4 AND d2.state = 0) AS earliest_user_db,
  (SELECT MAX(d2.create_date) FROM sys.databases d2 WHERE d2.database_id > 4 AND d2.state = 0) AS latest_user_db,
  CASE
    WHEN d.name IN ('AdventureWorks', 'AdventureWorks2014', 'AdventureWorks2016', 'AdventureWorks2017',
      'AdventureWorks2019', 'AdventureWorks2022', 'AdventureWorksDW', 'AdventureWorksLT',
      'WideWorldImporters', 'WideWorldImportersDW', 'Northwind', 'pubs') THEN 'KNOWN_SAMPLE'
    WHEN d.name LIKE '%test%' OR d.name LIKE '%dev%' OR d.name LIKE '%demo%'
      OR d.name LIKE '%sample%' OR d.name LIKE '%sandbox%' THEN 'TEST_PATTERN'
    ELSE 'UNKNOWN'
  END AS db_classification
FROM sys.databases d
LEFT JOIN sys.server_principals sp ON d.owner_sid = sp.sid
WHERE d.state = 0
  AND d.database_id > 4
  AND (d.name IN (
    'AdventureWorks', 'AdventureWorks2014', 'AdventureWorks2016', 'AdventureWorks2017',
    'AdventureWorks2019', 'AdventureWorks2022', 'AdventureWorksDW', 'AdventureWorksLT',
    'WideWorldImporters', 'WideWorldImportersDW', 'Northwind', 'pubs',
    'test', 'testdb', 'sample', 'demo')
    OR d.name LIKE '%test%' OR d.name LIKE '%dev%' OR d.name LIKE '%demo%'
    OR d.name LIKE '%sample%' OR d.name LIKE '%sandbox%')
GO

/* ===== SEC-SQL-CFG-003-RC05 — Knowledge Loss During Transitions ===== */
SELECT d.name AS database_name,
  d.create_date,
  DATEDIFF(DAY, d.create_date, GETDATE()) AS age_days,
  (SELECT COUNT(*)
   FROM sys.dm_exec_sessions s
   WHERE s.database_id = d.database_id
     AND s.is_user_process = 1) AS active_sessions,
  (SELECT MAX(last_user_seek)
   FROM sys.dm_db_index_usage_stats ius
   WHERE ius.database_id = d.database_id) AS last_user_seek,
  (SELECT MAX(last_user_scan)
   FROM sys.dm_db_index_usage_stats ius
   WHERE ius.database_id = d.database_id) AS last_user_scan,
  (SELECT MAX(last_user_lookup)
   FROM sys.dm_db_index_usage_stats ius
   WHERE ius.database_id = d.database_id) AS last_user_lookup
FROM sys.databases d
WHERE d.state = 0
  AND d.database_id > 4
  AND (d.name IN (
    'AdventureWorks', 'AdventureWorks2014', 'AdventureWorks2016', 'AdventureWorks2017',
    'AdventureWorks2019', 'AdventureWorks2022', 'AdventureWorksDW', 'AdventureWorksLT',
    'WideWorldImporters', 'WideWorldImportersDW', 'Northwind', 'pubs',
    'test', 'testdb', 'sample', 'demo')
    OR d.name LIKE '%test%' OR d.name LIKE '%dev%' OR d.name LIKE '%demo%'
    OR d.name LIKE '%sample%' OR d.name LIKE '%sandbox%')
GO

/* ===== SEC-SQL-CFG-003-RC06 — Inadequate Cleanup Procedures ===== */
SELECT
  (SELECT COUNT(*) FROM sys.databases d
   WHERE d.state = 0 AND d.database_id > 4
     AND (d.name IN (
       'AdventureWorks', 'AdventureWorks2014', 'AdventureWorks2016', 'AdventureWorks2017',
       'AdventureWorks2019', 'AdventureWorks2022', 'AdventureWorksDW', 'AdventureWorksLT',
       'WideWorldImporters', 'WideWorldImportersDW', 'Northwind', 'pubs',
       'test', 'testdb', 'sample', 'demo')
       OR d.name LIKE '%test%' OR d.name LIKE '%dev%' OR d.name LIKE '%demo%'
       OR d.name LIKE '%sample%' OR d.name LIKE '%sandbox%')) AS sample_test_db_count,
  (SELECT COUNT(*) FROM sys.databases WHERE state = 0 AND database_id > 4) AS total_user_dbs,
  (SELECT COUNT(*) FROM sys.server_triggers
   WHERE is_disabled = 0
     AND OBJECT_DEFINITION(object_id) LIKE '%CREATE_DATABASE%') AS create_db_triggers,
  (SELECT COUNT(*) FROM sys.server_triggers
   WHERE is_disabled = 0
     AND (OBJECT_DEFINITION(object_id) LIKE '%test%'
       OR OBJECT_DEFINITION(object_id) LIKE '%sample%'
       OR OBJECT_DEFINITION(object_id) LIKE '%demo%')) AS naming_policy_triggers
GO

/* ===== SEC-SQL-CFG-003-RC07 — Application Configuration Pointing to Wrong Database ===== */
SELECT s.database_id,
  DB_NAME(s.database_id) AS database_name,
  s.program_name,
  s.host_name,
  s.login_name,
  COUNT(*) AS connection_count,
  MAX(s.last_request_end_time) AS last_activity
FROM sys.dm_exec_sessions s
WHERE s.is_user_process = 1
  AND DB_NAME(s.database_id) IN (
    SELECT d.name FROM sys.databases d
    WHERE d.database_id > 4 AND d.state = 0
      AND (d.name IN ('AdventureWorks', 'AdventureWorks2012', 'AdventureWorks2014', 'AdventureWorks2016', 'AdventureWorks2017', 'AdventureWorks2019', 'AdventureWorksDW', 'AdventureWorksLT', 'Northwind', 'pubs', 'WideWorldImporters', 'WideWorldImportersDW')
        OR d.name LIKE '%test%' OR d.name LIKE '%dev%' OR d.name LIKE '%sample%' OR d.name LIKE '%demo%' OR d.name LIKE '%sandbox%' OR d.name LIKE '%example%'))
GROUP BY s.database_id, s.program_name, s.host_name, s.login_name
ORDER BY connection_count DESC
GO

/* ===== SEC-SQL-CFG-003-RC08 — Demonstration and Training Use ===== */
SELECT
  (SELECT COUNT(*) FROM sys.databases WHERE name IN ('AdventureWorks', 'AdventureWorks2012', 'AdventureWorks2014', 'AdventureWorks2016', 'AdventureWorks2017', 'AdventureWorks2019', 'AdventureWorksDW', 'AdventureWorksLT', 'Northwind', 'pubs', 'WideWorldImporters', 'WideWorldImportersDW') OR name LIKE '%training%' OR name LIKE '%demo%' OR name LIKE '%tutorial%' OR name LIKE '%lab%' OR name LIKE '%learn%') AS training_db_count,
  (SELECT COUNT(*) FROM sys.databases WHERE database_id > 4 AND state = 0 AND recovery_model_desc = 'FULL') AS full_recovery_dbs,
  (SELECT COUNT(*) FROM sys.server_audits WHERE is_state_enabled = 1) AS active_audits,
  CAST(SERVERPROPERTY('Edition') AS NVARCHAR(128)) AS server_edition,
  (SELECT COUNT(*) FROM sys.databases WHERE database_id > 4 AND state = 0 AND is_encrypted = 1) AS encrypted_dbs
GO

/* ===== SEC-SQL-CFG-003-RC10 — Insufficient RBAC Controls ===== */
SELECT d.name AS database_name,
  d.create_date,
  (SELECT COUNT(DISTINCT dp.principal_id)
   FROM sys.database_permissions perm
   JOIN sys.database_principals dp ON perm.grantee_principal_id = dp.principal_id
   WHERE perm.permission_name = 'CONNECT'
     AND perm.state_desc IN ('GRANT', 'GRANT_WITH_GRANT_OPTION')
     AND dp.name NOT IN ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys', 'public')) AS explicit_connect_grants,
  (SELECT COUNT(*) FROM sys.database_principals
   WHERE type IN ('S', 'U', 'G') AND name NOT IN ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys')) AS db_users
FROM sys.databases d
WHERE d.database_id > 4
  AND d.state = 0
  AND (d.name IN ('AdventureWorks', 'AdventureWorks2012', 'AdventureWorks2014', 'AdventureWorks2016', 'AdventureWorks2017', 'AdventureWorks2019', 'AdventureWorksDW', 'AdventureWorksLT', 'Northwind', 'pubs', 'WideWorldImporters', 'WideWorldImportersDW')
    OR d.name LIKE '%test%' OR d.name LIKE '%dev%' OR d.name LIKE '%sample%' OR d.name LIKE '%demo%' OR d.name LIKE '%sandbox%')
GO

/* ===== SEC-SQL-CFG-003-RC11 — Compliance Scope Confusion ===== */
SELECT
  (SELECT COUNT(*) FROM sys.databases
   WHERE database_id > 4 AND state = 0
     AND (name IN ('AdventureWorks', 'AdventureWorks2012', 'AdventureWorks2014', 'AdventureWorks2016', 'AdventureWorks2017', 'AdventureWorks2019', 'AdventureWorksDW', 'AdventureWorksLT', 'Northwind', 'pubs', 'WideWorldImporters', 'WideWorldImportersDW')
       OR name LIKE '%test%' OR name LIKE '%dev%' OR name LIKE '%sample%' OR name LIKE '%demo%' OR name LIKE '%sandbox%')) AS sample_test_db_count,
  (SELECT COUNT(*) FROM sys.databases
   WHERE database_id > 4 AND state = 0 AND is_encrypted = 1) AS tde_encrypted_dbs,
  (SELECT COUNT(*) FROM sys.server_audits WHERE is_state_enabled = 1) AS active_audits,
  (SELECT COUNT(*) FROM sys.databases
   WHERE database_id > 4 AND state = 0 AND recovery_model_desc = 'FULL') AS full_recovery_dbs
GO

/* ===== SEC-SQL-CFG-003-RC13 — Weak Object Naming Conventions ===== */
SELECT d.name AS database_name,
  d.create_date,
  d.state_desc,
  d.recovery_model_desc,
  CASE
    WHEN d.name LIKE 'DB[_]%' OR d.name LIKE 'Database%' OR d.name LIKE 'MyDB%'
      OR d.name LIKE 'New%Database%' OR d.name LIKE 'Copy%' OR d.name LIKE '%[_]old'
      OR d.name LIKE '%[_]bak' OR d.name LIKE '%[_]copy' OR d.name LIKE '%[_]temp'
      OR d.name LIKE '%[_]v[0-9]%' OR d.name LIKE '%[_]backup'
      THEN 'AMBIGUOUS_NAME'
    WHEN d.name LIKE '%test%' OR d.name LIKE '%dev%' OR d.name LIKE '%staging%'
      OR d.name LIKE '%qa%' OR d.name LIKE '%uat%' OR d.name LIKE '%sandbox%'
      THEN 'ENV_MARKER'
    WHEN LEN(d.name) <= 3 THEN 'TOO_SHORT'
    ELSE 'ACCEPTABLE'
  END AS naming_quality
FROM sys.databases d
WHERE d.database_id > 4
  AND d.state = 0
GO

/* ===== SEC-SQL-CFG-003-RC14 — Multi-Tenant Instance Management ===== */
SELECT
  (SELECT COUNT(*) FROM sys.databases WHERE database_id > 4 AND state = 0) AS total_user_dbs,
  (SELECT COUNT(DISTINCT owner_sid) FROM sys.databases WHERE database_id > 4 AND state = 0) AS distinct_owners,
  (SELECT COUNT(*) FROM sys.databases
   WHERE database_id > 4 AND state = 0
     AND (name IN ('AdventureWorks', 'AdventureWorks2012', 'AdventureWorks2014', 'AdventureWorks2016', 'AdventureWorks2017', 'AdventureWorks2019', 'AdventureWorksDW', 'AdventureWorksLT', 'Northwind', 'pubs', 'WideWorldImporters', 'WideWorldImportersDW')
       OR name LIKE '%test%' OR name LIKE '%dev%' OR name LIKE '%sample%' OR name LIKE '%demo%' OR name LIKE '%sandbox%')) AS sample_test_dbs,
  (SELECT COUNT(*) FROM sys.server_principals WHERE type IN ('S', 'U', 'G') AND is_disabled = 0 AND name NOT LIKE '##%' AND name NOT IN ('sa', 'public')) AS active_logins
GO

/* ===== SEC-SQL-CFG-004-RC01 — Application Code Execution Requirement ===== */
SELECT c.value_in_use AS clr_enabled,
  (SELECT value_in_use FROM sys.configurations WHERE name = 'clr strict security') AS clr_strict_security,
  (SELECT COUNT(*) FROM sys.assemblies WHERE is_user_defined = 1) AS user_assembly_count
FROM sys.configurations c
WHERE c.name = 'clr enabled'
GO

/* ===== SEC-SQL-CFG-004-RC02 — Performance Optimization ===== */
SELECT c.value_in_use AS clr_enabled,
  a.name AS assembly_name,
  a.permission_set_desc,
  OBJECT_NAME(am.object_id) AS module_name,
  o.type_desc AS module_type
FROM sys.configurations c
CROSS JOIN sys.assemblies a
JOIN sys.assembly_modules am ON a.assembly_id = am.assembly_id
JOIN sys.objects o ON am.object_id = o.object_id
WHERE c.name = 'clr enabled'
  AND c.value_in_use = 1
  AND a.is_user_defined = 1
  AND o.type IN ('FS', 'FT', 'AF')
GO

/* ===== SEC-SQL-CFG-004-RC03 — Third-Party Tool Dependencies ===== */
SELECT c.value_in_use AS clr_enabled,
  (SELECT value_in_use FROM sys.configurations WHERE name = 'clr strict security') AS clr_strict_security,
  a.name AS assembly_name,
  a.permission_set_desc,
  a.clr_name,
  CASE WHEN a.permission_set_desc IN ('EXTERNAL_ACCESS', 'UNSAFE_ACCESS') THEN 'ELEVATED' ELSE 'SAFE' END AS risk_level,
  d.is_trustworthy_on
FROM sys.configurations c
CROSS JOIN sys.assemblies a
CROSS JOIN sys.databases d
WHERE c.name = 'clr enabled'
  AND c.value_in_use = 1
  AND a.is_user_defined = 1
  AND d.database_id = DB_ID()
GO

/* ===== SEC-SQL-CFG-004-RC04 — Unsigned Assembly Bypass ===== */
SELECT a.name AS assembly_name,
  a.permission_set_desc,
  CASE WHEN EXISTS (
    SELECT 1 FROM sys.certificates c
    JOIN sys.server_principals sp ON c.sid = sp.sid
    WHERE sp.name LIKE '%' + a.name + '%')
    THEN 'CERTIFICATE_FOUND' ELSE 'NO_CERTIFICATE' END AS signing_status,
  CASE WHEN EXISTS (
    SELECT 1 FROM sys.asymmetric_keys ak
    JOIN sys.server_principals sp ON ak.sid = sp.sid
    WHERE sp.name LIKE '%' + a.name + '%')
    THEN 'ASYMKEY_FOUND' ELSE 'NO_ASYMKEY' END AS asymkey_status,
  d.is_trustworthy_on
FROM sys.assemblies a
CROSS JOIN sys.databases d
WHERE a.is_user_defined = 1
  AND d.database_id = DB_ID()
  AND a.permission_set_desc IN ('EXTERNAL_ACCESS', 'UNSAFE_ACCESS')
GO

/* ===== SEC-SQL-CFG-004-RC05 — Lack of Assembly Vetting ===== */
SELECT a.name AS assembly_name,
  a.permission_set_desc,
  a.create_date,
  a.clr_name,
  CASE
    WHEN a.permission_set_desc = 'UNSAFE_ACCESS' THEN 'CRITICAL_RISK'
    WHEN a.permission_set_desc = 'EXTERNAL_ACCESS' THEN 'HIGH_RISK'
    ELSE 'STANDARD_RISK'
  END AS risk_level,
  (SELECT COUNT(*) FROM sys.assembly_references ar WHERE ar.assembly_id = a.assembly_id) AS dependency_count
FROM sys.assemblies a
WHERE a.is_user_defined = 1
  AND a.permission_set_desc IN ('EXTERNAL_ACCESS', 'UNSAFE_ACCESS')
GO

/* ===== SEC-SQL-CFG-004-RC06 — Privilege Escalation via CLR ===== */
SELECT dp.name AS principal_name, dp.type_desc,
  perm.permission_name, perm.state_desc,
  OBJECT_NAME(perm.major_id) AS module_name,
  a.permission_set_desc AS assembly_permission
FROM sys.database_permissions perm
JOIN sys.database_principals dp ON perm.grantee_principal_id = dp.principal_id
JOIN sys.assembly_modules am ON perm.major_id = am.object_id
JOIN sys.assemblies a ON am.assembly_id = a.assembly_id
WHERE perm.permission_name = 'EXECUTE'
  AND perm.state_desc IN ('GRANT', 'GRANT_WITH_GRANT_OPTION')
  AND a.permission_set_desc = 'UNSAFE_ACCESS'
  AND dp.name NOT IN ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys')
GO

/* ===== SEC-SQL-CFG-004-RC07 — Sandbox Escape ===== */
SELECT d.name AS database_name,
  d.is_trustworthy_on,
  sp.name AS db_owner,
  IS_SRVROLEMEMBER('sysadmin', sp.name) AS owner_is_sysadmin,
  (SELECT COUNT(*) FROM sys.assemblies WHERE is_user_defined = 1 AND permission_set_desc IN ('EXTERNAL_ACCESS', 'UNSAFE_ACCESS')) AS elevated_assemblies,
  (SELECT value_in_use FROM sys.configurations WHERE name = 'clr strict security') AS clr_strict_security
FROM sys.databases d
LEFT JOIN sys.server_principals sp ON d.owner_sid = sp.sid
WHERE d.database_id = DB_ID()
GO

/* ===== SEC-SQL-CFG-004-RC08 — Registry Modification ===== */
SELECT
  (SELECT service_account FROM sys.dm_server_services WHERE servicename LIKE 'SQL Server%' AND servicename NOT LIKE '%Agent%') AS sql_service_account,
  (SELECT COUNT(*) FROM sys.assemblies WHERE is_user_defined = 1 AND permission_set_desc = 'UNSAFE_ACCESS') AS unsafe_assembly_count,
  (SELECT name FROM sys.databases WHERE database_id = DB_ID()) AS current_database,
  (SELECT is_trustworthy_on FROM sys.databases WHERE database_id = DB_ID()) AS is_trustworthy
GO

/* ===== SEC-SQL-CFG-004-RC09 — Network-Based Attacks ===== */
SELECT dp.name AS principal_name, dp.type_desc,
  OBJECT_NAME(perm.major_id) AS module_name,
  a.name AS assembly_name,
  a.permission_set_desc
FROM sys.database_permissions perm
JOIN sys.database_principals dp ON perm.grantee_principal_id = dp.principal_id
JOIN sys.assembly_modules am ON perm.major_id = am.object_id
JOIN sys.assemblies a ON am.assembly_id = a.assembly_id
WHERE perm.permission_name = 'EXECUTE'
  AND perm.state_desc IN ('GRANT', 'GRANT_WITH_GRANT_OPTION')
  AND a.permission_set_desc IN ('EXTERNAL_ACCESS', 'UNSAFE_ACCESS')
UNION ALL
SELECT 'public' AS principal_name, 'DATABASE_ROLE' AS type_desc,
  OBJECT_NAME(am.object_id) AS module_name,
  a.name AS assembly_name,
  a.permission_set_desc
FROM sys.assembly_modules am
JOIN sys.assemblies a ON am.assembly_id = a.assembly_id
JOIN sys.database_permissions perm ON perm.major_id = am.object_id
JOIN sys.database_principals dp ON perm.grantee_principal_id = dp.principal_id
WHERE dp.name = 'public'
  AND perm.permission_name = 'EXECUTE'
  AND a.permission_set_desc IN ('EXTERNAL_ACCESS', 'UNSAFE_ACCESS')
GO

/* ===== SEC-SQL-CFG-004-RC10 — External Library Access ===== */
SELECT a.name AS assembly_name,
  a.permission_set_desc,
  ar.referenced_assembly_id,
  ra.name AS referenced_assembly_name,
  ra.clr_name AS referenced_clr_name
FROM sys.assemblies a
LEFT JOIN sys.assembly_references ar ON a.assembly_id = ar.assembly_id
LEFT JOIN sys.assemblies ra ON ar.referenced_assembly_id = ra.assembly_id
WHERE a.is_user_defined = 1
  AND a.permission_set_desc IN ('EXTERNAL_ACCESS', 'UNSAFE_ACCESS')
ORDER BY a.name
GO

/* ===== SEC-SQL-CFG-004-RC11 — Post-Exploitation Persistence ===== */
SELECT d.name AS database_name,
  d.is_trustworthy_on,
  sp.name AS db_owner,
  IS_SRVROLEMEMBER('sysadmin', sp.name) AS owner_is_sysadmin,
  (SELECT COUNT(*) FROM sys.assemblies WHERE is_user_defined = 1) AS user_assemblies,
  (SELECT COUNT(*) FROM sys.assemblies WHERE is_user_defined = 1 AND permission_set_desc = 'UNSAFE_ACCESS') AS unsafe_assemblies,
  (SELECT value_in_use FROM sys.configurations WHERE name = 'clr enabled') AS clr_enabled,
  (SELECT value_in_use FROM sys.configurations WHERE name = 'clr strict security') AS clr_strict_security
FROM sys.databases d
LEFT JOIN sys.server_principals sp ON d.owner_sid = sp.sid
WHERE d.database_id = DB_ID()
GO

/* ===== SEC-SQL-CFG-004-RC12 — Insufficient Configuration Segregation ===== */
SELECT d.name AS database_name,
  d.is_trustworthy_on,
  sp.name AS db_owner,
  CASE
    WHEN d.is_trustworthy_on = 1 AND (SELECT value_in_use FROM sys.configurations WHERE name = 'clr enabled') = 1
      THEN 'CLR_CAPABLE - can load UNSAFE assemblies'
    WHEN (SELECT value_in_use FROM sys.configurations WHERE name = 'clr enabled') = 1
      THEN 'CLR_ENABLED - can load SAFE assemblies'
    ELSE 'CLR_DISABLED'
  END AS clr_exposure
FROM sys.databases d
LEFT JOIN sys.server_principals sp ON d.owner_sid = sp.sid
WHERE d.database_id > 4
  AND d.state = 0
ORDER BY d.is_trustworthy_on DESC, d.name
GO

/* ===== SEC-SQL-CFG-004-RC13 — Monitoring Gaps ===== */
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

/* ===== SEC-SQL-CFG-005-RC01 — Troubleshooting Discovery ===== */
DBCC TRACESTATUS(-1) WITH NO_INFOMSGS
GO

/* ===== SEC-SQL-CFG-005-RC02 — Vendor/Support Recommendation ===== */
DBCC TRACESTATUS(-1) WITH NO_INFOMSGS
GO

/* ===== SEC-SQL-CFG-005-RC04 — Perceived Performance Optimization ===== */
SELECT name, value_in_use, description FROM sys.configurations WHERE name IN ('clr enabled','cross db ownership chaining','Database Mail XPs','Ole Automation Procedures','xp_cmdshell','Ad Hoc Distributed Queries','remote access','remote admin connections','scan for startup procs') ORDER BY name
GO

/* ===== SEC-SQL-CFG-005-RC05 — Dangerous Flag Combinations ===== */
DBCC TRACESTATUS(-1) WITH NO_INFOMSGS
GO

/* ===== SEC-SQL-CFG-005-RC06 — Experimentation in Production ===== */
SELECT
  CAST(SERVERPROPERTY('Edition') AS NVARCHAR(128)) AS server_edition,
  CAST(SERVERPROPERTY('ProductLevel') AS NVARCHAR(128)) AS product_level,
  (SELECT COUNT(*) FROM sys.server_audits WHERE is_state_enabled = 1) AS active_audits,
  (SELECT COUNT(*) FROM sys.databases WHERE is_encrypted = 1) AS tde_encrypted_dbs,
  (SELECT COUNT(*) FROM sys.databases WHERE database_id > 4 AND state = 0 AND recovery_model_desc = 'FULL') AS full_recovery_dbs,
  (SELECT COUNT(*) FROM sys.availability_groups) AS ag_count
GO

/* ===== SEC-SQL-CFG-005-RC07 — One-Off Debugging Enabled Persistently ===== */
SELECT registry_key, value_name, CAST(value_data AS NVARCHAR(256)) AS value_data
FROM sys.dm_server_registry
WHERE registry_key LIKE '%MSSQLServer\Parameters%'
  AND CAST(value_data AS NVARCHAR(256)) LIKE '-T%'
GO

/* ===== SEC-SQL-CFG-005-RC08 — Configuration Drift ===== */
SELECT
  (SELECT COUNT(*) FROM sys.dm_server_registry
   WHERE registry_key LIKE '%MSSQLServer\Parameters%'
     AND CAST(value_data AS NVARCHAR(256)) LIKE '-T%') AS startup_trace_flag_count,
  (SELECT STRING_AGG(REPLACE(CAST(value_data AS NVARCHAR(256)), '-T', ''), ', ')
   FROM sys.dm_server_registry
   WHERE registry_key LIKE '%MSSQLServer\Parameters%'
     AND CAST(value_data AS NVARCHAR(256)) LIKE '-T%') AS startup_trace_flags,
  CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128)) AS sql_version,
  CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(128)) AS machine_name,
  (SELECT sqlserver_start_time FROM sys.dm_os_sys_info) AS last_restart
GO

/* ===== SEC-SQL-CFG-005-RC10 — Verbose Logging for "Security" ===== */
SELECT
  (SELECT COUNT(*) FROM sys.dm_os_enumerate_fixed_drives) AS drive_count,
  (SELECT cntr_value FROM sys.dm_os_performance_counters
   WHERE counter_name = 'Errors/sec' AND instance_name = '_Total') AS errors_per_sec,
  (SELECT value_in_use FROM sys.configurations WHERE name = 'number of errorlog files') AS errorlog_file_count,
  (SELECT sqlserver_start_time FROM sys.dm_os_sys_info) AS last_restart,
  DATEDIFF(DAY, (SELECT sqlserver_start_time FROM sys.dm_os_sys_info), GETDATE()) AS uptime_days
GO

/* ===== SEC-SQL-CFG-005-RC11 — Deprecated Flag Persistence ===== */
SELECT
  CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) AS major_version,
  CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128)) AS full_version,
  CAST(SERVERPROPERTY('Edition') AS NVARCHAR(128)) AS edition,
  CASE
    WHEN CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) >= 13 THEN 'TF 1117, 1118, 2371 are default behavior'
    ELSE 'Pre-2016: flags may still be needed'
  END AS tf_1117_1118_2371_status,
  CASE
    WHEN CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) >= 13 THEN 'Use ALTER DATABASE SCOPED CONFIGURATION'
    ELSE 'Database scoped config not available'
  END AS dbsc_availability
GO

/* ===== SEC-SQL-CFG-005-RC12 — Lazy Optimization ===== */
SELECT
  (SELECT COUNT(*) FROM sys.query_store_query_text WHERE 1=0) AS query_store_check,
  (SELECT is_query_store_on FROM sys.databases WHERE database_id = DB_ID()) AS query_store_enabled,
  (SELECT COUNT(*) FROM sys.plan_guides) AS plan_guides_count,
  (SELECT desired_state_desc FROM sys.database_query_store_options WHERE 1=1) AS qs_desired_state,
  CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) AS major_version
GO

/* ===== SEC-SQL-CFG-005-RC13 — Lack of Audit Trail ===== */
CREATE TABLE #tf(TraceFlag INT, Status INT, Global INT, Session INT); INSERT INTO #tf EXEC('DBCC TRACESTATUS(-1) WITH NO_INFOMSGS'); SELECT (SELECT COUNT(*) FROM #tf WHERE Global = 1) AS active_global_trace_flags, (SELECT COUNT(*) FROM sys.server_audits WHERE is_state_enabled = 1) AS active_server_audits, (SELECT COUNT(*) FROM sys.server_audit_specification_details sasd JOIN sys.server_audit_specifications sas ON sasd.server_specification_id = sas.server_specification_id WHERE sas.is_state_enabled = 1 AND sasd.audit_action_name = 'TRACE_CHANGE_GROUP') AS trace_change_audit_count; DROP TABLE #tf;
GO

/* ===== SEC-SQL-CFG-005-RC14 — Misunderstanding Hidden Features ===== */
DBCC TRACESTATUS(-1) WITH NO_INFOMSGS
GO

/* ===== SEC-SQL-CFG-006-RC01 — Static Credential Storage ===== */
SELECT s.name AS linked_server_name,
  s.product,
  s.provider,
  s.data_source,
  ll.uses_self_credential,
  ll.remote_name,
  CASE
    WHEN ll.uses_self_credential = 0 AND ll.remote_name IS NOT NULL THEN 'STATIC_CREDENTIAL'
    WHEN ll.uses_self_credential = 1 THEN 'SELF_MAPPING'
    ELSE 'NO_CREDENTIAL'
  END AS credential_type
FROM sys.servers s
JOIN sys.linked_logins ll ON s.server_id = ll.server_id
WHERE s.is_linked = 1
  AND ll.uses_self_credential = 0
  AND ll.remote_name IS NOT NULL
GO

/* ===== SEC-SQL-CFG-006-RC02 — Overprivileged Link Credentials ===== */
SELECT s.name AS linked_server_name,
  s.data_source,
  s.product,
  ll.remote_name,
  CASE
    WHEN ll.remote_name IN ('sa', 'SA', 'dbo') THEN 'CRITICAL_OVERPRIVILEGED'
    WHEN ll.remote_name LIKE '%admin%' OR ll.remote_name LIKE '%sysadmin%'
      OR ll.remote_name LIKE '%root%' OR ll.remote_name LIKE '%superuser%'
      THEN 'LIKELY_OVERPRIVILEGED'
    ELSE 'CHECK_REMOTE_PERMISSIONS'
  END AS privilege_assessment,
  CASE WHEN ll.local_principal_id = 0 THEN 'DEFAULT_FOR_ALL' ELSE 'SPECIFIC_LOGIN' END AS mapping_scope
FROM sys.servers s
JOIN sys.linked_logins ll ON s.server_id = ll.server_id
WHERE s.is_linked = 1
  AND ll.uses_self_credential = 0
  AND ll.remote_name IS NOT NULL
GO

/* ===== SEC-SQL-CFG-006-RC03 — rootcause Database Link Exposure ===== */
SELECT s.name AS linked_server_name,
  s.data_source,
  s.product,
  ll.local_principal_id,
  CASE WHEN ll.local_principal_id = 0 THEN 'DEFAULT_MAPPING_ALL_USERS' ELSE sp.name END AS local_login,
  ll.uses_self_credential,
  ll.remote_name,
  CASE
    WHEN ll.local_principal_id = 0 AND ll.uses_self_credential = 0 AND ll.remote_name IS NOT NULL
      THEN 'CRITICAL: All local logins map to single remote credential'
    WHEN ll.local_principal_id = 0 AND ll.uses_self_credential = 1
      THEN 'WARNING: All local logins pass through their own credentials'
    WHEN ll.local_principal_id = 0 AND ll.remote_name IS NULL
      THEN 'DEFAULT: Connections not made (no mapping)'
    ELSE 'SPECIFIC: Individual login mapping'
  END AS exposure_level
FROM sys.servers s
JOIN sys.linked_logins ll ON s.server_id = ll.server_id
LEFT JOIN sys.server_principals sp ON ll.local_principal_id = sp.principal_id
WHERE s.is_linked = 1
GO

/* ===== SEC-SQL-CFG-006-RC04 — Privilege Escalation via Link ===== */
SELECT s.name AS linked_server_name,
  s.data_source,
  s.is_rpc_out_enabled,
  s.is_data_access_enabled,
  ll.remote_name,
  ll.uses_self_credential,
  CASE WHEN ll.local_principal_id = 0 THEN 'DEFAULT_MAPPING' ELSE 'SPECIFIC_LOGIN' END AS mapping_scope,
  CASE
    WHEN s.is_rpc_out_enabled = 1 AND ll.uses_self_credential = 0 AND ll.remote_name IS NOT NULL
      THEN 'ESCALATION_RISK: RPC + stored credential'
    ELSE 'LIMITED_RISK'
  END AS risk_assessment
FROM sys.servers s
JOIN sys.linked_logins ll ON s.server_id = ll.server_id
WHERE s.is_linked = 1
  AND s.is_rpc_out_enabled = 1
  AND ll.uses_self_credential = 0
  AND ll.remote_name IS NOT NULL
GO

/* ===== SEC-SQL-CFG-006-RC05 — Inadequate Access Control ===== */
SELECT s.name AS linked_server_name,
  s.data_source,
  s.is_rpc_out_enabled,
  s.is_data_access_enabled,
  (SELECT COUNT(*) FROM sys.linked_logins ll WHERE ll.server_id = s.server_id) AS total_mappings,
  (SELECT COUNT(*) FROM sys.linked_logins ll WHERE ll.server_id = s.server_id AND ll.local_principal_id = 0) AS default_mappings,
  (SELECT COUNT(*) FROM sys.linked_logins ll WHERE ll.server_id = s.server_id AND ll.local_principal_id > 0) AS explicit_mappings
FROM sys.servers s
WHERE s.is_linked = 1
  AND (s.is_data_access_enabled = 1 OR s.is_rpc_out_enabled = 1)
GO

/* ===== SEC-SQL-CFG-006-RC06 — Cross-Database Privilege Inheritance ===== */
SELECT s.name AS linked_server,
  s.provider,
  s.data_source,
  ll.uses_self_credential,
  ll.remote_name,
  sp.name AS local_login,
  CASE WHEN ll.uses_self_credential = 1 THEN 'SELF_MAPPING'
    WHEN ll.remote_name IS NOT NULL THEN 'EXPLICIT_MAPPING'
    ELSE 'DEFAULT' END AS mapping_type
FROM sys.servers s
JOIN sys.linked_logins ll ON s.server_id = ll.server_id
LEFT JOIN sys.server_principals sp ON ll.local_principal_id = sp.principal_id
WHERE s.is_linked = 1
  AND (ll.uses_self_credential = 1
    OR ll.local_principal_id = 0)
GO

/* ===== SEC-SQL-CFG-006-RC07 — Unvalidated Dynamic Queries ===== */
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

/* ===== SEC-SQL-CFG-006-RC08 — Remote Database Exploitation ===== */
SELECT s.name AS linked_server,
  s.provider,
  s.data_source,
  s.product,
  s.is_rpc_out_enabled,
  s.is_remote_login_enabled,
  s.is_data_access_enabled,
  ll.uses_self_credential,
  ll.remote_name,
  CASE WHEN s.is_rpc_out_enabled = 1 AND s.is_remote_login_enabled = 1
    THEN 'HIGH_RISK: full remote execution'
    WHEN s.is_rpc_out_enabled = 1
    THEN 'MEDIUM_RISK: RPC Out enabled'
    ELSE 'LOW_RISK' END AS risk_level
FROM sys.servers s
JOIN sys.linked_logins ll ON s.server_id = ll.server_id
WHERE s.is_linked = 1
  AND s.is_rpc_out_enabled = 1
GO

/* ===== SEC-SQL-CFG-006-RC09 — Credential Exposure via Monitoring ===== */
SELECT s.name AS session_name, se.event_name FROM sys.dm_xe_sessions s JOIN sys.dm_xe_session_events se ON s.address = se.event_session_address
GO

/* ===== SEC-SQL-CFG-006-RC10 — Long-Lived Credentials ===== */
SELECT s.name AS linked_server,
  s.data_source,
  s.provider,
  s.modify_date AS linked_server_modified,
  DATEDIFF(DAY, s.modify_date, GETDATE()) AS days_since_modification,
  ll.uses_self_credential,
  ll.remote_name,
  CASE WHEN ll.uses_self_credential = 0 AND ll.remote_name IS NOT NULL
    AND DATEDIFF(DAY, s.modify_date, GETDATE()) > 90
    THEN 'STALE_CREDENTIAL: >' + CAST(DATEDIFF(DAY, s.modify_date, GETDATE()) AS VARCHAR) + ' days'
    WHEN ll.uses_self_credential = 0 AND ll.remote_name IS NOT NULL
    THEN 'SQL_CREDENTIAL: ' + CAST(DATEDIFF(DAY, s.modify_date, GETDATE()) AS VARCHAR) + ' days old'
    ELSE 'WINDOWS_AUTH' END AS credential_status
FROM sys.servers s
JOIN sys.linked_logins ll ON s.server_id = ll.server_id
WHERE s.is_linked = 1
  AND ll.uses_self_credential = 0
  AND ll.remote_name IS NOT NULL
ORDER BY s.modify_date ASC
GO

/* ===== SEC-SQL-CFG-006-RC11 — Scope Confusion ===== */
SELECT s.name AS linked_server,
  s.data_source,
  s.provider,
  ll.remote_name AS default_remote_login,
  ll.uses_self_credential,
  (SELECT COUNT(*) FROM sys.linked_logins ll2
    WHERE ll2.server_id = s.server_id AND ll2.local_principal_id <> 0) AS explicit_mapping_count,
  CASE WHEN ll.remote_name IS NOT NULL AND ll.local_principal_id = 0
    THEN 'DEFAULT_MAPPING: all unmapped logins use "' + ll.remote_name + '"'
    WHEN ll.uses_self_credential = 1 AND ll.local_principal_id = 0
    THEN 'DEFAULT_SELF: all logins delegate own credentials'
    ELSE 'NO_DEFAULT' END AS scope_risk
FROM sys.servers s
JOIN sys.linked_logins ll ON s.server_id = ll.server_id
WHERE s.is_linked = 1
  AND ll.local_principal_id = 0
  AND (ll.remote_name IS NOT NULL OR ll.uses_self_credential = 1)
GO

/* ===== SEC-SQL-CFG-006-RC13 — Linked Server Configuration Persistence ===== */
SELECT s.name AS linked_server,
  s.modify_date,
  DATEDIFF(DAY, s.modify_date, GETDATE()) AS days_since_change,
  CASE WHEN EXISTS (
    SELECT 1 FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
    WHERE st.text LIKE '%' + s.name + '%'
      AND qs.last_execution_time > DATEADD(DAY, -30, GETDATE())
  ) THEN 'RECENTLY_USED' ELSE 'NO_RECENT_ACTIVITY' END AS usage_status
FROM sys.servers s
WHERE s.is_linked = 1
  AND DATEDIFF(DAY, s.modify_date, GETDATE()) > 180
GO

/* ===== SEC-SQL-CFG-006-RC14 — Missing Encryption ===== */
SELECT s.name AS linked_server,
  s.data_source,
  s.provider,
  c.encrypt_option,
  c.auth_scheme,
  c.net_transport,
  c.protocol_type,
  c.client_net_address,
  CASE WHEN c.encrypt_option = 'FALSE' THEN 'UNENCRYPTED'
    WHEN c.encrypt_option = 'TRUE' THEN 'ENCRYPTED'
    ELSE 'UNKNOWN' END AS encryption_status
FROM sys.servers s
LEFT JOIN sys.dm_exec_connections c
  ON c.most_recent_sql_handle IS NOT NULL
WHERE s.is_linked = 1
GO

/* ===== SEC-SQL-CFG-006-RC15 — Mutual Authentication Gaps ===== */
SELECT s.name AS linked_server,
  s.data_source,
  s.provider,
  ll.uses_self_credential,
  ll.remote_name,
  CASE WHEN ll.uses_self_credential = 0 AND ll.remote_name IS NOT NULL
    THEN 'SQL_AUTH: no mutual authentication'
    WHEN ll.uses_self_credential = 1
    THEN 'WINDOWS_AUTH: check Kerberos delegation'
    ELSE 'NO_MAPPING' END AS auth_assessment
FROM sys.servers s
JOIN sys.linked_logins ll ON s.server_id = ll.server_id
WHERE s.is_linked = 1
GO

/* ===== SEC-SQL-CFG-006-RC16 — Catalog-Level Exposure ===== */
SELECT
  (SELECT COUNT(*) FROM sys.servers WHERE is_linked = 1) AS linked_server_count,
  (SELECT COUNT(*) FROM sys.server_permissions
    WHERE permission_name = 'VIEW SERVER STATE'
      AND state_desc = 'GRANT'
      AND grantee_principal_id NOT IN (
        SELECT principal_id FROM sys.server_principals WHERE type = 'R' AND name = 'sysadmin'
      )) AS non_sysadmin_view_server_state_grants,
  (SELECT COUNT(*) FROM sys.server_permissions
    WHERE permission_name = 'VIEW ANY DEFINITION'
      AND state_desc = 'GRANT') AS view_any_definition_grants,
  (SELECT COUNT(DISTINCT sp.name)
    FROM sys.server_role_members srm
    JOIN sys.server_principals sp ON srm.member_principal_id = sp.principal_id
    JOIN sys.server_principals sr ON srm.role_principal_id = sr.principal_id
    WHERE sr.name IN ('setupadmin', 'sysadmin')) AS admin_role_members
GO

/* ===== SEC-SQL-ENC-001-RC01 — Default Configuration Not Changed ===== */
SELECT encrypt_option,
  COUNT(*) AS connection_count,
  CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,1)) AS pct
FROM sys.dm_exec_connections
GROUP BY encrypt_option
ORDER BY connection_count DESC
GO

/* ===== SEC-SQL-ENC-001-RC02 — Missing Encryption Parameter in Connection Strings ===== */
SELECT c.encrypt_option,
  s.program_name,
  s.host_name,
  s.login_name,
  c.auth_scheme,
  c.net_transport,
  c.client_net_address,
  COUNT(*) AS connection_count
FROM sys.dm_exec_connections c
JOIN sys.dm_exec_sessions s ON c.session_id = s.session_id
WHERE c.encrypt_option = 'FALSE'
  AND s.is_user_process = 1
  AND c.net_transport <> 'Shared memory'
GROUP BY c.encrypt_option, s.program_name, s.host_name, s.login_name,
  c.auth_scheme, c.net_transport, c.client_net_address
ORDER BY connection_count DESC
GO

/* ===== SEC-SQL-ENC-001-RC03 — Backward Compatibility Requirements ===== */
SELECT d.name AS database_name,
  d.compatibility_level,
  CASE
    WHEN d.compatibility_level <= 100 THEN 'SQL Server 2008 or earlier'
    WHEN d.compatibility_level = 110 THEN 'SQL Server 2012'
    WHEN d.compatibility_level = 120 THEN 'SQL Server 2014'
    WHEN d.compatibility_level = 130 THEN 'SQL Server 2016'
    WHEN d.compatibility_level = 140 THEN 'SQL Server 2017'
    WHEN d.compatibility_level = 150 THEN 'SQL Server 2019'
    WHEN d.compatibility_level = 160 THEN 'SQL Server 2022'
    ELSE 'Unknown' END AS compat_version,
  (SELECT COUNT(*) FROM sys.dm_exec_sessions s WHERE s.database_id = d.database_id AND s.is_user_process = 1) AS active_sessions
FROM sys.databases d
WHERE d.database_id > 4
  AND d.state = 0
  AND d.compatibility_level < 130
ORDER BY d.compatibility_level ASC
GO

/* ===== SEC-SQL-ENC-001-RC04 — Client Driver Version Mismatch ===== */
SELECT s.client_interface_name,
  s.client_version,
  c.encrypt_option,
  c.protocol_version,
  COUNT(*) AS connection_count,
  COUNT(CASE WHEN c.encrypt_option = 'FALSE' THEN 1 END) AS unencrypted_count,
  COUNT(CASE WHEN c.encrypt_option = 'TRUE' THEN 1 END) AS encrypted_count
FROM sys.dm_exec_connections c
JOIN sys.dm_exec_sessions s ON c.session_id = s.session_id
WHERE s.is_user_process = 1
  AND c.net_transport <> 'Shared memory'
GROUP BY s.client_interface_name, s.client_version, c.encrypt_option, c.protocol_version
ORDER BY s.client_interface_name, s.client_version
GO

/* ===== SEC-SQL-ENC-001-RC07 — Certificate Management Complexity ===== */
SELECT name,
  certificate_id,
  subject,
  start_date,
  expiry_date,
  DATEDIFF(DAY, GETDATE(), expiry_date) AS days_until_expiry,
  CASE WHEN expiry_date < GETDATE() THEN 'EXPIRED'
    WHEN DATEDIFF(DAY, GETDATE(), expiry_date) < 30 THEN 'EXPIRING_SOON'
    WHEN DATEDIFF(DAY, GETDATE(), expiry_date) < 90 THEN 'MONITOR'
    ELSE 'OK' END AS cert_health
FROM sys.certificates
ORDER BY expiry_date ASC
GO

/* ===== SEC-SQL-ENC-001-RC08 — Self-Signed Certificate Issues ===== */
SELECT c.encrypt_option,
  c.auth_scheme,
  s.program_name,
  s.host_name,
  COUNT(*) AS connection_count,
  CASE WHEN c.encrypt_option = 'TRUE' THEN 'ENCRYPTED'
    ELSE 'UNENCRYPTED' END AS encryption_state
FROM sys.dm_exec_connections c
JOIN sys.dm_exec_sessions s ON c.session_id = s.session_id
WHERE s.is_user_process = 1
  AND c.net_transport <> 'Shared memory'
GROUP BY c.encrypt_option, c.auth_scheme, s.program_name, s.host_name
ORDER BY c.encrypt_option, connection_count DESC
GO

/* ===== SEC-SQL-ENC-001-RC09 — Network Architecture Assumptions ===== */
SELECT
  CASE WHEN c.client_net_address IN ('127.0.0.1', '::1', '<local machine>') OR c.net_transport = 'Shared memory'
    THEN 'LOCAL' ELSE 'REMOTE' END AS connection_locality,
  c.encrypt_option,
  COUNT(*) AS connection_count,
  CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY
    CASE WHEN c.client_net_address IN ('127.0.0.1', '::1', '<local machine>') OR c.net_transport = 'Shared memory'
      THEN 'LOCAL' ELSE 'REMOTE' END) AS DECIMAL(5,1)) AS pct_within_locality
FROM sys.dm_exec_connections c
JOIN sys.dm_exec_sessions s ON c.session_id = s.session_id
WHERE s.is_user_process = 1
GROUP BY
  CASE WHEN c.client_net_address IN ('127.0.0.1', '::1', '<local machine>') OR c.net_transport = 'Shared memory'
    THEN 'LOCAL' ELSE 'REMOTE' END,
  c.encrypt_option
ORDER BY connection_locality, c.encrypt_option
GO

/* ===== SEC-SQL-ENC-001-RC10 — Lack of Security Requirements ===== */
SELECT COUNT(*) AS unencrypted_connections,
  (SELECT COUNT(*) FROM sys.dm_exec_connections) AS total_connections
FROM sys.dm_exec_connections
WHERE encrypt_option = 'FALSE'
GO

/* ===== SEC-SQL-ENC-001-RC11 — Application Middleware Bypass ===== */
SELECT
  SUM(CASE WHEN c.encrypt_option = 'TRUE' THEN 1 ELSE 0 END) AS encrypted_count,
  SUM(CASE WHEN c.encrypt_option = 'FALSE' THEN 1 ELSE 0 END) AS unencrypted_count
FROM sys.dm_exec_connections c
JOIN sys.dm_exec_sessions s ON c.session_id = s.session_id
WHERE s.is_user_process = 1
GO

/* ===== SEC-SQL-ENC-001-RC12 — Testing and Development Environment Carryover ===== */
DECLARE @force_encryption INT;
EXEC master.dbo.xp_instance_regread
  N'HKEY_LOCAL_MACHINE',
  N'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQLServer\SuperSocketNetLib',
  N'ForceEncryption', @force_encryption OUTPUT;
SELECT @force_encryption AS force_encryption,
  SERVERPROPERTY('MachineName') AS machine_name,
  SERVERPROPERTY('IsClustered') AS is_clustered,
  SERVERPROPERTY('ProductLevel') AS product_level;
GO

/* ===== SEC-SQL-ENC-001-RC13 — Inadequate Monitoring and Visibility ===== */
SELECT sas.name AS audit_spec_name, sas.is_state_enabled, sasd.audit_action_name, sasd.class_desc FROM sys.server_audit_specifications sas JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
GO

/* ===== SEC-SQL-ENC-002-RC01 — Legacy Application Dependency on TLS 1.0/1.1 ===== */
SELECT s.program_name, s.host_name, s.login_name,
  c.protocol_version,
  CASE c.protocol_version
    WHEN 0x301 THEN 'TLS 1.0'
    WHEN 0x302 THEN 'TLS 1.1'
    WHEN 0x303 THEN 'TLS 1.2'
    WHEN 0x304 THEN 'TLS 1.3'
    ELSE 'Unknown/None (' + CONVERT(VARCHAR, c.protocol_version) + ')'
  END AS tls_version,
  COUNT(*) AS connection_count
FROM sys.dm_exec_connections c
JOIN sys.dm_exec_sessions s ON c.session_id = s.session_id
WHERE s.is_user_process = 1
  AND c.encrypt_option = 'TRUE'
  AND c.protocol_version IN (0x301, 0x302)
GROUP BY s.program_name, s.host_name, s.login_name, c.protocol_version
ORDER BY connection_count DESC
GO

/* ===== SEC-SQL-ENC-002-RC02 — Deprecated Client Libraries in Use ===== */
SELECT s.program_name, s.host_name,
  c.client_net_address,
  c.protocol_version,
  CASE c.protocol_version
    WHEN 0x301 THEN 'TLS 1.0'
    WHEN 0x302 THEN 'TLS 1.1'
    WHEN 0x303 THEN 'TLS 1.2'
    WHEN 0x304 THEN 'TLS 1.3'
    ELSE 'Unknown'
  END AS tls_version,
  c.net_transport,
  COUNT(*) AS connection_count
FROM sys.dm_exec_connections c
JOIN sys.dm_exec_sessions s ON c.session_id = s.session_id
WHERE s.is_user_process = 1
  AND c.encrypt_option = 'TRUE'
  AND c.protocol_version < 0x303
GROUP BY s.program_name, s.host_name, c.client_net_address,
  c.protocol_version, c.net_transport
ORDER BY c.protocol_version ASC
GO

/* ===== SEC-SQL-ENC-002-RC03 — .NET Framework Constraints ===== */
SELECT s.program_name, s.host_name, s.login_name,
  c.protocol_version,
  CASE c.protocol_version
    WHEN 0x301 THEN 'TLS 1.0'
    WHEN 0x302 THEN 'TLS 1.1'
    WHEN 0x303 THEN 'TLS 1.2'
    ELSE 'Other'
  END AS tls_version,
  COUNT(*) AS connection_count
FROM sys.dm_exec_connections c
JOIN sys.dm_exec_sessions s ON c.session_id = s.session_id
WHERE s.is_user_process = 1
  AND c.encrypt_option = 'TRUE'
  AND c.protocol_version < 0x303
  AND s.program_name LIKE '%.Net%'
GROUP BY s.program_name, s.host_name, s.login_name, c.protocol_version
ORDER BY connection_count DESC
GO

/* ===== SEC-SQL-ENC-002-RC04 — Java/JDK Version Limitations ===== */
SELECT s.program_name, s.host_name, s.login_name,
  c.protocol_version,
  CASE c.protocol_version
    WHEN 0x301 THEN 'TLS 1.0'
    WHEN 0x302 THEN 'TLS 1.1'
    WHEN 0x303 THEN 'TLS 1.2'
    ELSE 'Other'
  END AS tls_version,
  COUNT(*) AS connection_count
FROM sys.dm_exec_connections c
JOIN sys.dm_exec_sessions s ON c.session_id = s.session_id
WHERE s.is_user_process = 1
  AND c.encrypt_option = 'TRUE'
  AND c.protocol_version < 0x303
  AND (s.program_name LIKE '%jdbc%' OR s.program_name LIKE '%Java%'
    OR s.program_name LIKE '%jTDS%' OR s.program_name LIKE '%Microsoft JDBC%')
GROUP BY s.program_name, s.host_name, s.login_name, c.protocol_version
ORDER BY connection_count DESC
GO

/* ===== SEC-SQL-ENC-002-RC05 — Database Mail and Service Broker Legacy Code ===== */
SELECT ep.name AS endpoint_name, ep.type_desc, ep.state_desc, ep.protocol_desc FROM sys.endpoints ep WHERE ep.type_desc = 'SERVICE_BROKER'
GO

/* ===== SEC-SQL-ENC-002-RC06 — Operating System Default Restrictions ===== */
DECLARE @tls10_enabled INT, @tls11_enabled INT;
EXEC master.dbo.xp_instance_regread
  N'HKEY_LOCAL_MACHINE',
  N'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server',
  N'Enabled', @tls10_enabled OUTPUT;
EXEC master.dbo.xp_instance_regread
  N'HKEY_LOCAL_MACHINE',
  N'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server',
  N'Enabled', @tls11_enabled OUTPUT;
SELECT
  ISNULL(@tls10_enabled, 1) AS tls10_server_enabled,
  ISNULL(@tls11_enabled, 1) AS tls11_server_enabled;
GO

/* ===== SEC-SQL-ENC-002-RC09 — Configuration Oversight ===== */
SELECT
  SUM(CASE WHEN c.protocol_version < 0x303 THEN 1 ELSE 0 END) AS old_tls_connections,
  SUM(CASE WHEN c.protocol_version >= 0x303 THEN 1 ELSE 0 END) AS modern_tls_connections
FROM sys.dm_exec_connections c
WHERE c.encrypt_option = 'TRUE'
GO

/* ===== SEC-SQL-ENC-002-RC10 — Intentional Compatibility Decisions ===== */
SELECT
  c.protocol_version,
  CASE c.protocol_version
    WHEN 0x301 THEN 'TLS 1.0'
    WHEN 0x302 THEN 'TLS 1.1'
    WHEN 0x303 THEN 'TLS 1.2'
    WHEN 0x304 THEN 'TLS 1.3'
    ELSE 'Other'
  END AS tls_version,
  COUNT(*) AS connection_count,
  COUNT(DISTINCT s.program_name) AS distinct_apps
FROM sys.dm_exec_connections c
JOIN sys.dm_exec_sessions s ON c.session_id = s.session_id
WHERE s.is_user_process = 1
  AND c.encrypt_option = 'TRUE'
GROUP BY c.protocol_version
ORDER BY c.protocol_version ASC
GO

/* ===== SEC-SQL-ENC-002-RC11 — No Automated Configuration Audit ===== */
SELECT
  (SELECT COUNT(*) FROM sys.server_audit_specifications WHERE is_state_enabled = 1) AS active_audit_specs,
  (SELECT COUNT(*) FROM sys.dm_xe_sessions WHERE name LIKE '%tls%' OR name LIKE '%encrypt%' OR name LIKE '%login%') AS tls_xe_sessions,
  (SELECT COUNT(*) FROM sys.server_audits WHERE is_state_enabled = 1) AS active_audits
GO

/* ===== SEC-SQL-ENC-002-RC12 — Database Version Limitations ===== */
SELECT
  SERVERPROPERTY('ProductVersion') AS product_version,
  SERVERPROPERTY('ProductLevel') AS product_level,
  SERVERPROPERTY('Edition') AS edition,
  SERVERPROPERTY('ProductMajorVersion') AS major_version,
  SERVERPROPERTY('ProductBuildType') AS build_type,
  CASE
    WHEN CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) < 11
      THEN 'NO_TLS12_SUPPORT'
    WHEN CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) = 11
      AND CAST(PARSENAME(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR), 2) AS INT) < 6216
      THEN 'NEEDS_PATCH_FOR_TLS12'
    WHEN CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) = 12
      AND CAST(PARSENAME(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR), 2) AS INT) < 4439
      THEN 'NEEDS_PATCH_FOR_TLS12'
    ELSE 'TLS12_SUPPORTED'
  END AS tls12_status
GO

/* ===== SEC-SQL-ENC-003-RC01 — Not Aware of TDE Feature ===== */
SELECT
  (SELECT COUNT(*) FROM master.sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##') AS master_db_has_dmk,
  (SELECT COUNT(*) FROM master.sys.certificates WHERE name LIKE '%TDE%' OR name LIKE '%Encrypt%') AS tde_certs_count,
  (SELECT COUNT(*) FROM sys.databases WHERE database_id > 4 AND is_encrypted = 0 AND state_desc = 'ONLINE'
    AND name NOT IN ('distribution', 'ReportServer', 'ReportServerTempDB')) AS unencrypted_user_dbs
GO

/* ===== SEC-SQL-ENC-003-RC02 — Licensing Restrictions ===== */
SELECT
  SERVERPROPERTY('Edition') AS edition,
  SERVERPROPERTY('ProductVersion') AS product_version,
  CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) AS major_version,
  CASE
    WHEN CAST(SERVERPROPERTY('Edition') AS NVARCHAR(128)) LIKE '%Enterprise%' THEN 'TDE_SUPPORTED'
    WHEN CAST(SERVERPROPERTY('Edition') AS NVARCHAR(128)) LIKE '%Developer%' THEN 'TDE_SUPPORTED'
    WHEN CAST(SERVERPROPERTY('Edition') AS NVARCHAR(128)) LIKE '%Standard%'
      AND CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) >= 15 THEN 'TDE_SUPPORTED'
    WHEN CAST(SERVERPROPERTY('Edition') AS NVARCHAR(128)) LIKE '%Standard%'
      AND CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) < 15 THEN 'TDE_NOT_SUPPORTED'
    ELSE 'TDE_NOT_SUPPORTED'
  END AS tde_support_status
GO

/* ===== SEC-SQL-ENC-003-RC03 — Missing License Entitlements ===== */
SELECT
  SERVERPROPERTY('Edition') AS edition,
  SERVERPROPERTY('ProductVersion') AS product_version,
  CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) AS major_version,
  CASE
    WHEN CAST(SERVERPROPERTY('Edition') AS NVARCHAR(128)) LIKE '%Standard%'
      AND CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) < 15
    THEN 'MISSING_TDE_ENTITLEMENT'
    WHEN CAST(SERVERPROPERTY('Edition') AS NVARCHAR(128)) LIKE '%Express%'
    THEN 'MISSING_TDE_ENTITLEMENT'
    WHEN CAST(SERVERPROPERTY('Edition') AS NVARCHAR(128)) LIKE '%Web%'
    THEN 'MISSING_TDE_ENTITLEMENT'
    ELSE 'TDE_ENTITLED'
  END AS entitlement_status
GO

/* ===== SEC-SQL-ENC-003-RC04 — Key Management System Not Available ===== */
SELECT
  (SELECT COUNT(*) FROM sys.cryptographic_providers) AS ekm_provider_count,
  (SELECT COUNT(*) FROM master.sys.certificates) AS master_cert_count,
  (SELECT COUNT(*) FROM master.sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##') AS master_dmk_exists,
  (SELECT COUNT(*) FROM master.sys.asymmetric_keys) AS master_asym_key_count
GO

/* ===== SEC-SQL-ENC-003-RC06 — Database Design Incompatibility ===== */
SELECT d.name AS database_name, d.is_encrypted,
  fg.name AS filegroup_name, fg.type_desc,
  CASE
    WHEN fg.type_desc = 'FILESTREAM_DATA_FILEGROUP' THEN 'FILESTREAM'
    WHEN fg.type_desc = 'MEMORY_OPTIMIZED_DATA_FILEGROUP' THEN 'IN_MEMORY_OLTP'
    ELSE fg.type_desc
  END AS feature_type
FROM sys.databases d
JOIN sys.master_files mf ON d.database_id = mf.database_id
JOIN sys.filegroups fg ON mf.data_space_id = fg.data_space_id
  AND mf.database_id = DB_ID()
WHERE d.database_id > 4
  AND d.is_encrypted = 0
  AND fg.type_desc IN ('FILESTREAM_DATA_FILEGROUP', 'MEMORY_OPTIMIZED_DATA_FILEGROUP')
GO

/* ===== SEC-SQL-ENC-003-RC10 — Temporary workspace encryption complications ===== */
SELECT
  (SELECT COUNT(*) FROM sys.databases WHERE database_id > 4 AND is_encrypted = 1
    AND state_desc = 'ONLINE') AS encrypted_db_count,
  (SELECT COUNT(*) FROM sys.databases WHERE database_id > 4 AND is_encrypted = 0
    AND state_desc = 'ONLINE'
    AND name NOT IN ('distribution', 'ReportServer', 'ReportServerTempDB')) AS unencrypted_db_count,
  (SELECT is_encrypted FROM sys.databases WHERE name = 'tempdb') AS tempdb_encrypted,
  (SELECT COUNT(*) FROM sys.dm_database_encryption_keys WHERE database_id = 2) AS tempdb_has_dek
GO

/* ===== SEC-SQL-ENC-003-RC11 — High Availability and Replication Issues ===== */
SELECT d.name, d.is_encrypted,
  d.replica_id,
  ag.name AS ag_name,
  m.mirroring_state_desc,
  (SELECT COUNT(*) FROM msdb.dbo.log_shipping_primary_databases lsp
   WHERE lsp.primary_database = d.name) AS log_shipping_primary
FROM sys.databases d
LEFT JOIN sys.availability_replicas ar ON d.replica_id = ar.replica_id
LEFT JOIN sys.availability_groups ag ON ar.group_id = ag.group_id
LEFT JOIN sys.database_mirroring m ON d.database_id = m.database_id
WHERE d.database_id > 4
  AND d.is_encrypted = 0
  AND d.state_desc = 'ONLINE'
  AND (d.replica_id IS NOT NULL
    OR m.mirroring_state IS NOT NULL
    OR EXISTS (SELECT 1 FROM msdb.dbo.log_shipping_primary_databases lsp
               WHERE lsp.primary_database = d.name))
GO

/* ===== SEC-SQL-ENC-003-RC12 — Cloud Database Settings ===== */
SELECT
  SERVERPROPERTY('Edition') AS edition,
  SERVERPROPERTY('EngineEdition') AS engine_edition,
  CASE CAST(SERVERPROPERTY('EngineEdition') AS INT)
    WHEN 5 THEN 'Azure SQL Database'
    WHEN 6 THEN 'Azure Synapse'
    WHEN 8 THEN 'Azure SQL Managed Instance'
    WHEN 9 THEN 'Azure SQL Edge'
    ELSE 'On-Premises or IaaS'
  END AS hosting_type,
  (SELECT COUNT(*) FROM sys.databases WHERE database_id > 4 AND is_encrypted = 0
    AND state_desc = 'ONLINE'
    AND name NOT IN ('distribution', 'ReportServer', 'ReportServerTempDB')) AS unencrypted_user_dbs
GO

/* ===== SEC-SQL-ENC-003-RC13 — Development/Test Database Assumption ===== */
SELECT d.name, d.is_encrypted, d.create_date,
  d.state_desc,
  CASE
    WHEN d.name LIKE '%dev%' OR d.name LIKE '%test%'
      OR d.name LIKE '%staging%' OR d.name LIKE '%qa%'
      OR d.name LIKE '%sandbox%' OR d.name LIKE '%uat%'
      OR d.name LIKE '%demo%' OR d.name LIKE '%temp%'
    THEN 'LIKELY_NON_PRODUCTION'
    ELSE 'LIKELY_PRODUCTION'
  END AS environment_guess
FROM sys.databases d
WHERE d.database_id > 4
  AND d.is_encrypted = 0
  AND d.state_desc = 'ONLINE'
  AND d.name NOT IN ('distribution', 'ReportServer', 'ReportServerTempDB')
GO

/* ===== SEC-SQL-ENC-003-RC15 — Previous Failed Implementation Attempt ===== */
SELECT
  (SELECT COUNT(*) FROM master.sys.certificates
   WHERE name LIKE '%TDE%' OR name LIKE '%Encrypt%' OR name LIKE '%DEK%') AS tde_cert_count,
  (SELECT COUNT(*) FROM master.sys.symmetric_keys
   WHERE name = '##MS_DatabaseMasterKey##') AS master_dmk_exists,
  (SELECT COUNT(*) FROM sys.dm_database_encryption_keys
   WHERE encryption_state IN (0, 1, 5)) AS inactive_dek_count,
  (SELECT COUNT(*) FROM sys.databases
   WHERE database_id > 4 AND is_encrypted = 1) AS encrypted_db_count
GO

/* ===== SEC-SQL-ENC-003-RC16 — Wallets and Key Storage Issues ===== */
SELECT
  (SELECT COUNT(*) FROM master.sys.symmetric_keys
   WHERE name = '##MS_DatabaseMasterKey##') AS master_dmk_exists,
  (SELECT COUNT(*) FROM master.sys.certificates
   WHERE expiry_date > GETDATE()) AS valid_cert_count,
  (SELECT COUNT(*) FROM master.sys.certificates
   WHERE expiry_date <= GETDATE()) AS expired_cert_count,
  (SELECT COUNT(*) FROM sys.cryptographic_providers) AS ekm_provider_count,
  (SELECT COUNT(*) FROM master.sys.asymmetric_keys) AS asym_key_count
GO

/* ===== SEC-SQL-ENC-004-RC01 — Feature Not Enabled at Backup Time ===== */
SELECT TOP 20 bs.database_name, bs.backup_start_date, bs.type AS backup_type, bs.compressed_backup_size / 1024 / 1024 AS size_mb, CASE WHEN bs.encryptor_type IS NOT NULL THEN 'ENCRYPTED' ELSE 'NOT_ENCRYPTED' END AS encryption_status, bs.key_algorithm, bs.encryptor_type, d.is_encrypted AS tde_enabled FROM msdb.dbo.backupset bs LEFT JOIN sys.databases d ON bs.database_name = d.name ORDER BY bs.backup_start_date DESC
GO

/* ===== SEC-SQL-ENC-004-RC03 — Key Management for Backups Not Established ===== */
SELECT
  (SELECT COUNT(*) FROM master.sys.symmetric_keys
   WHERE name = '##MS_DatabaseMasterKey##') AS master_dmk_exists,
  (SELECT COUNT(*) FROM master.sys.certificates
   WHERE expiry_date > GETDATE()) AS valid_cert_count,
  (SELECT COUNT(*) FROM master.sys.asymmetric_keys) AS asym_key_count,
  (SELECT COUNT(*) FROM sys.cryptographic_providers) AS ekm_provider_count
GO

/* ===== SEC-SQL-ENC-004-RC05 — Performance Impact on Backup Windows ===== */
SELECT TOP 20 bs.database_name, bs.backup_start_date, bs.type AS backup_type, bs.compressed_backup_size / 1024 / 1024 AS size_mb, CASE WHEN bs.encryptor_type IS NOT NULL THEN 'ENCRYPTED' ELSE 'NOT_ENCRYPTED' END AS encryption_status, bs.key_algorithm, bs.encryptor_type, d.is_encrypted AS tde_enabled FROM msdb.dbo.backupset bs LEFT JOIN sys.databases d ON bs.database_name = d.name ORDER BY bs.backup_start_date DESC
GO

/* ===== SEC-SQL-ENC-004-RC06 — Backup Storage Assumptions ===== */
SELECT TOP 20 bs.database_name, bs.backup_start_date, bs.type AS backup_type, bs.compressed_backup_size / 1024 / 1024 AS size_mb, CASE WHEN bs.encryptor_type IS NOT NULL THEN 'ENCRYPTED' ELSE 'NOT_ENCRYPTED' END AS encryption_status, bs.key_algorithm, bs.encryptor_type, d.is_encrypted AS tde_enabled FROM msdb.dbo.backupset bs LEFT JOIN sys.databases d ON bs.database_name = d.name ORDER BY bs.backup_start_date DESC
GO

/* ===== SEC-SQL-ENC-004-RC08 — Off-Site Backup Storage Not Recognized as High Risk ===== */
SELECT TOP 20 bs.database_name, bs.backup_start_date, bs.type AS backup_type, bs.compressed_backup_size / 1024 / 1024 AS size_mb, CASE WHEN bs.encryptor_type IS NOT NULL THEN 'ENCRYPTED' ELSE 'NOT_ENCRYPTED' END AS encryption_status, bs.key_algorithm, bs.encryptor_type, d.is_encrypted AS tde_enabled FROM msdb.dbo.backupset bs LEFT JOIN sys.databases d ON bs.database_name = d.name ORDER BY bs.backup_start_date DESC
GO

/* ===== SEC-SQL-ENC-004-RC10 — Certificate and Key Expiration on Backups ===== */
SELECT TOP 20 bs.database_name, bs.backup_start_date, bs.type AS backup_type, bs.compressed_backup_size / 1024 / 1024 AS size_mb, CASE WHEN bs.encryptor_type IS NOT NULL THEN 'ENCRYPTED' ELSE 'NOT_ENCRYPTED' END AS encryption_status, bs.key_algorithm, bs.encryptor_type, d.is_encrypted AS tde_enabled FROM msdb.dbo.backupset bs LEFT JOIN sys.databases d ON bs.database_name = d.name ORDER BY bs.backup_start_date DESC
GO

/* ===== SEC-SQL-ENC-004-RC11 — Database Encryption Complexity Misunderstood ===== */
SELECT
  (SELECT COUNT(*) FROM sys.certificates WHERE name NOT LIKE '##%') AS user_certificates,
  (SELECT COUNT(*) FROM sys.symmetric_keys WHERE name NOT LIKE '##%') AS user_symmetric_keys,
  (SELECT COUNT(*) FROM sys.asymmetric_keys) AS asymmetric_keys,
  (SELECT is_master_key_encrypted_by_server FROM sys.databases WHERE name = 'master') AS dmk_exists
GO

/* ===== SEC-SQL-ENC-004-RC13 — Multiple Backup Destinations Not Coordinated ===== */
SELECT TOP 20 bs.database_name, bs.backup_start_date, bs.type AS backup_type, bs.compressed_backup_size / 1024 / 1024 AS size_mb, CASE WHEN bs.encryptor_type IS NOT NULL THEN 'ENCRYPTED' ELSE 'NOT_ENCRYPTED' END AS encryption_status, bs.key_algorithm, bs.encryptor_type, d.is_encrypted AS tde_enabled FROM msdb.dbo.backupset bs LEFT JOIN sys.databases d ON bs.database_name = d.name ORDER BY bs.backup_start_date DESC
GO

/* ===== SEC-SQL-ENC-004-RC15 — Developer and QA Databases Using Production Backups ===== */
SELECT TOP 20 bs.database_name, bs.backup_start_date, bs.type AS backup_type, bs.compressed_backup_size / 1024 / 1024 AS size_mb, CASE WHEN bs.encryptor_type IS NOT NULL THEN 'ENCRYPTED' ELSE 'NOT_ENCRYPTED' END AS encryption_status, bs.key_algorithm, bs.encryptor_type, d.is_encrypted AS tde_enabled FROM msdb.dbo.backupset bs LEFT JOIN sys.databases d ON bs.database_name = d.name ORDER BY bs.backup_start_date DESC
GO

/* ===== SEC-SQL-ENC-004-RC16 — Backup Scripts Written Before Encryption Features Existed ===== */
SELECT TOP 20 bs.database_name, bs.backup_start_date, bs.type AS backup_type, bs.compressed_backup_size / 1024 / 1024 AS size_mb, CASE WHEN bs.encryptor_type IS NOT NULL THEN 'ENCRYPTED' ELSE 'NOT_ENCRYPTED' END AS encryption_status, bs.key_algorithm, bs.encryptor_type, d.is_encrypted AS tde_enabled FROM msdb.dbo.backupset bs LEFT JOIN sys.databases d ON bs.database_name = d.name ORDER BY bs.backup_start_date DESC
GO

/* ===== SEC-SQL-ENC-005-RC01 — Default/Legacy Cipher Suites Not Disabled ===== */
SELECT SERVERPROPERTY('IsClustered') AS is_clustered,
  CONNECTIONPROPERTY('protocol_type') AS current_protocol,
  CONNECTIONPROPERTY('encrypt_option') AS current_encrypt,
  (SELECT value_in_use FROM sys.configurations WHERE name = 'force encryption') AS force_encryption_config
GO

/* ===== SEC-SQL-ENC-005-RC02 — Short Key Lengths Selected for Performance ===== */
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

/* ===== SEC-SQL-ENC-005-RC03 — Deprecated Algorithm Still in Use ===== */
SELECT TOP 20 bs.database_name, bs.backup_start_date, bs.type AS backup_type, bs.compressed_backup_size / 1024 / 1024 AS size_mb, CASE WHEN bs.encryptor_type IS NOT NULL THEN 'ENCRYPTED' ELSE 'NOT_ENCRYPTED' END AS encryption_status, bs.key_algorithm, bs.encryptor_type, d.is_encrypted AS tde_enabled FROM msdb.dbo.backupset bs LEFT JOIN sys.databases d ON bs.database_name = d.name ORDER BY bs.backup_start_date DESC
GO

/* ===== SEC-SQL-ENC-005-RC04 — Certificate Signed with Weak Hash ===== */
SELECT c.name AS certificate_name,
  c.start_date, c.expiry_date,
  c.key_length,
  c.pvt_key_encryption_type_desc,
  c.subject,
  CERTPROPERTY(c.certificate_id, 'Sig_Algorithm') AS signature_algorithm,
  DATEDIFF(DAY, GETDATE(), c.expiry_date) AS days_until_expiry
FROM sys.certificates c
WHERE c.name NOT LIKE '##%'
ORDER BY c.start_date ASC
GO

/* ===== SEC-SQL-ENC-005-RC05 — Self-Signed Certificates with Weak Parameters ===== */
SELECT c.name AS certificate_name,
  c.issuer_name, c.subject,
  c.key_length,
  c.start_date, c.expiry_date,
  c.pvt_key_encryption_type_desc,
  CAST(CERTPROPERTY(c.certificate_id, 'Sig_Algorithm') AS NVARCHAR(256)) AS signature_algorithm,
  CASE
    WHEN c.key_length < 2048 THEN 'WEAK_KEY_LENGTH'
    WHEN CAST(CERTPROPERTY(c.certificate_id, 'Sig_Algorithm') AS NVARCHAR(256)) LIKE '%md5%' THEN 'WEAK_HASH'
    WHEN CAST(CERTPROPERTY(c.certificate_id, 'Sig_Algorithm') AS NVARCHAR(256)) LIKE '%sha1%' THEN 'LEGACY_HASH'
    ELSE 'OK'
  END AS weakness_status
FROM sys.certificates c
WHERE c.name NOT LIKE '##%'
  AND c.issuer_name = c.subject
ORDER BY c.key_length ASC, c.start_date ASC
GO

/* ===== SEC-SQL-ENC-005-RC10 — CBC Mode Still Allowed in Configuration ===== */
SELECT encrypt_option, COUNT(*) AS connection_count FROM sys.dm_exec_connections WHERE session_id IN (SELECT
  session_id FROM sys.dm_exec_sessions WHERE is_user_process = 1) GROUP BY encrypt_option
GO

/* ===== SEC-SQL-ENC-005-RC11 — TLS 1.2 Allows Weak Ciphers ===== */
SELECT encrypt_option, protocol_type, auth_scheme, COUNT(*) AS connection_count FROM sys.dm_exec_connections
  WHERE session_id IN (SELECT session_id FROM sys.dm_exec_sessions WHERE is_user_process = 1) GROUP BY encrypt_option,
  protocol_type, auth_scheme
GO

/* ===== SEC-SQL-ENC-005-RC12 — Key Rotation Policy Not Implemented ===== */
SELECT name, subject, start_date, expiry_date,
  DATEDIFF(DAY, start_date, GETDATE()) AS age_days,
  DATEDIFF(DAY, GETDATE(), expiry_date) AS days_until_expiry,
  pvt_key_encryption_type_desc,
  CASE
    WHEN DATEDIFF(DAY, start_date, GETDATE()) > 730 THEN 'OVERDUE_ROTATION'
    WHEN DATEDIFF(DAY, start_date, GETDATE()) > 365 THEN 'APPROACHING_ROTATION'
    ELSE 'OK'
  END AS rotation_status
FROM master.sys.certificates
WHERE name NOT LIKE '##%'
ORDER BY start_date ASC
GO

/* ===== SEC-SQL-ENC-005-RC13 — Asymmetric Key Weak Parameters ===== */
SELECT name, algorithm_desc, key_length,
  pvt_key_encryption_type_desc,
  CASE
    WHEN algorithm_desc = 'RSA_512' THEN 'CRITICAL_WEAK'
    WHEN algorithm_desc = 'RSA_1024' THEN 'WEAK'
    WHEN algorithm_desc = 'RSA_2048' THEN 'ACCEPTABLE'
    WHEN algorithm_desc = 'RSA_3072' THEN 'STRONG'
    WHEN algorithm_desc = 'RSA_4096' THEN 'STRONG'
    ELSE 'UNKNOWN'
  END AS strength_assessment
FROM sys.asymmetric_keys
WHERE key_length < 2048
GO

/* ===== SEC-SQL-ENC-005-RC14 — No Monitoring of Negotiated Ciphers ===== */
SELECT sas.name AS audit_spec_name, sas.is_state_enabled, sasd.audit_action_name, sasd.class_desc FROM sys.server_audit_specifications sas JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
GO

/* ===== SEC-SQL-ENC-005-RC16 — Vendor Default Cipher Suites Used Without Review ===== */
DECLARE @rc4 INT, @3des INT, @aes128 INT, @aes256 INT;
EXEC master.dbo.xp_instance_regread
  N'HKEY_LOCAL_MACHINE',
  N'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 128/128',
  N'Enabled', @rc4 OUTPUT;
EXEC master.dbo.xp_instance_regread
  N'HKEY_LOCAL_MACHINE',
  N'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\Triple DES 168',
  N'Enabled', @3des OUTPUT;
SELECT
  CASE WHEN @rc4 IS NULL AND @3des IS NULL
    THEN 'NO_CIPHER_CUSTOMIZATION'
    ELSE 'SOME_CIPHER_CUSTOMIZATION'
  END AS customization_status,
  @rc4 AS rc4_setting, @3des AS triple_des_setting;
GO

/* ===== SEC-SQL-INJ-001-RC01 — String concatenation for query building ===== */
SELECT OBJECT_SCHEMA_NAME(m.object_id) AS schema_name,
  OBJECT_NAME(m.object_id) AS proc_name,
  m.object_id
FROM sys.sql_modules m
JOIN sys.objects o ON m.object_id = o.object_id
WHERE o.type IN ('P', 'FN', 'IF', 'TF')
  AND (
    m.definition LIKE '%EXEC(%+%@%+%' COLLATE Latin1_General_BIN
    OR m.definition LIKE '%EXECUTE(%+%@%+%' COLLATE Latin1_General_BIN
    OR m.definition LIKE '%EXEC (@%' COLLATE Latin1_General_BIN
    OR m.definition LIKE '%EXECUTE (@%' COLLATE Latin1_General_BIN
    OR m.definition LIKE '%EXEC(@%' COLLATE Latin1_General_BIN
    OR m.definition LIKE '%EXECUTE(@%' COLLATE Latin1_General_BIN
  )
GO

/* ===== SEC-SQL-INJ-001-RC02 — Inadequate input validation and sanitization ===== */
SELECT OBJECT_SCHEMA_NAME(m.object_id) AS schema_name,
  OBJECT_NAME(m.object_id) AS proc_name,
  CASE
    WHEN m.definition LIKE '%EXEC(%' OR m.definition LIKE '%EXECUTE(%'
      THEN 'EXEC_PATTERN'
    WHEN m.definition LIKE '%sp_executesql%'
      THEN 'SP_EXECUTESQL'
    ELSE 'OTHER'
  END AS dynamic_sql_type
FROM sys.sql_modules m
JOIN sys.objects o ON m.object_id = o.object_id
WHERE o.type = 'P'
  AND (m.definition LIKE '%EXEC(%+%@%' COLLATE Latin1_General_BIN
    OR m.definition LIKE '%EXECUTE(%+%@%' COLLATE Latin1_General_BIN
    OR m.definition LIKE '%EXEC (@%' COLLATE Latin1_General_BIN
    OR m.definition LIKE '%EXEC(@%' COLLATE Latin1_General_BIN)
  AND m.definition NOT LIKE '%QUOTENAME%' COLLATE Latin1_General_BIN
  AND m.definition NOT LIKE '%REPLACE(%''%'',%''''''''%)%'
GO

/* ===== SEC-SQL-INJ-001-RC04 — Legacy code and technical debt ===== */
SELECT OBJECT_SCHEMA_NAME(m.object_id) AS schema_name,
  OBJECT_NAME(m.object_id) AS proc_name,
  o.create_date, o.modify_date,
  DATEDIFF(YEAR, o.create_date, GETDATE()) AS age_years,
  CASE
    WHEN m.definition LIKE '%sp_executesql%' THEN 'HAS_SP_EXECUTESQL'
    ELSE 'NO_SP_EXECUTESQL'
  END AS parameterization_status
FROM sys.sql_modules m
JOIN sys.objects o ON m.object_id = o.object_id
WHERE o.type = 'P'
  AND (m.definition LIKE '%EXEC(%+%@%' COLLATE Latin1_General_BIN
    OR m.definition LIKE '%EXECUTE(%+%@%' COLLATE Latin1_General_BIN
    OR m.definition LIKE '%EXEC (@%' COLLATE Latin1_General_BIN
    OR m.definition LIKE '%EXEC(@%' COLLATE Latin1_General_BIN)
  AND m.definition NOT LIKE '%sp_executesql%' COLLATE Latin1_General_BIN
  AND DATEDIFF(YEAR, o.create_date, GETDATE()) >= 3
ORDER BY o.create_date ASC
GO

/* ===== SEC-SQL-INJ-001-RC07 — Mixing static and dynamic SQL constructs ===== */
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

/* ===== SEC-SQL-INJ-001-RC08 — Complex business requirements ===== */
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

/* ===== SEC-SQL-INJ-001-RC09 — Performance optimization assumptions ===== */
SELECT OBJECT_SCHEMA_NAME(m.object_id) AS schema_name,
  OBJECT_NAME(m.object_id) AS proc_name,
  ps.execution_count,
  ps.total_elapsed_time / 1000 AS total_elapsed_ms,
  CASE WHEN ps.execution_count > 0
    THEN ps.total_elapsed_time / ps.execution_count / 1000
    ELSE 0 END AS avg_elapsed_ms,
  ps.total_logical_reads,
  CASE WHEN m.definition LIKE '%OPTION%RECOMPILE%' THEN 1 ELSE 0 END AS has_recompile_hint
FROM sys.sql_modules m
JOIN sys.objects o ON m.object_id = o.object_id
LEFT JOIN sys.dm_exec_procedure_stats ps ON m.object_id = ps.object_id
WHERE o.type = 'P'
  AND (m.definition LIKE '%EXEC(%+%@%' COLLATE Latin1_General_BIN
    OR m.definition LIKE '%EXEC(@ %' COLLATE Latin1_General_BIN
    OR m.definition LIKE '%EXEC (@%' COLLATE Latin1_General_BIN
    OR m.definition LIKE '%sp_executesql%')
  AND ps.execution_count >= 1000
ORDER BY ps.execution_count DESC
GO

/* ===== SEC-SQL-INJ-001-RC10 — ORM framework misuse ===== */
SELECT
  SUM(CASE WHEN objtype = 'Adhoc' THEN 1 ELSE 0 END) AS adhoc_plans,
  SUM(CASE WHEN objtype = 'Prepared' THEN 1 ELSE 0 END) AS prepared_plans,
  SUM(CASE WHEN objtype = 'Proc' THEN 1 ELSE 0 END) AS proc_plans,
  COUNT(*) AS total_plans,
  CASE WHEN COUNT(*) > 0
    THEN CAST(SUM(CASE WHEN objtype = 'Adhoc' THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100
    ELSE 0 END AS adhoc_pct
FROM sys.dm_exec_cached_plans
GO

/* ===== SEC-SQL-INJ-001-RC13 — Operator control issues ===== */
SELECT OBJECT_SCHEMA_NAME(m.object_id) AS schema_name,
  OBJECT_NAME(m.object_id) AS proc_name,
  m.execute_as_principal_id,
  dp.name AS execute_as_name,
  dp.type_desc AS principal_type
FROM sys.sql_modules m
JOIN sys.objects o ON m.object_id = o.object_id
LEFT JOIN sys.database_principals dp ON m.execute_as_principal_id = dp.principal_id
WHERE o.type = 'P'
  AND m.execute_as_principal_id IS NOT NULL
  AND m.execute_as_principal_id <> 0
  AND (m.definition LIKE '%EXEC(%+%@%' COLLATE Latin1_General_BIN
    OR m.definition LIKE '%EXEC(@ %' COLLATE Latin1_General_BIN
    OR m.definition LIKE '%EXEC (@%' COLLATE Latin1_General_BIN
    OR m.definition LIKE '%sp_executesql%')
GO

/* ===== SEC-SQL-INJ-001-RC14 — Implicit trust in framework defaults ===== */
SELECT name, CAST(value_in_use AS INT) AS value_in_use
FROM sys.configurations
WHERE name = 'optimize for ad hoc workloads'
GO

/* ===== SEC-SQL-INJ-001-RC15 — Incomplete parameter binding ===== */
SELECT OBJECT_SCHEMA_NAME(m.object_id) AS schema_name,
  OBJECT_NAME(m.object_id) AS proc_name,
  m.object_id
FROM sys.sql_modules m
JOIN sys.objects o ON m.object_id = o.object_id
WHERE o.type IN ('P', 'FN', 'IF', 'TF')
  AND m.definition LIKE '%sp_executesql%' COLLATE Latin1_General_BIN
  AND (
    m.definition LIKE '%sp_executesql%+%@%+%' COLLATE Latin1_General_BIN
    OR m.definition LIKE '%sp_executesql %N''%'' + @%' COLLATE Latin1_General_BIN
    OR m.definition LIKE '%SET @%=%+%@%+%[^,]%sp_executesql%@%' COLLATE Latin1_General_BIN
  )
GO

/* ===== SEC-SQL-INJ-002-RC01 — Legacy system constraints ===== */
SELECT OBJECT_NAME(ps.object_id) AS xproc_name,
  ps.execution_count, ps.last_execution_time,
  DATEDIFF(DAY, ps.last_execution_time, GETDATE()) AS days_since_last_exec
FROM sys.dm_exec_procedure_stats ps
WHERE OBJECT_NAME(ps.object_id) IN (
  'xp_cmdshell', 'xp_regread', 'xp_regwrite', 'xp_regdeletevalue',
  'xp_regdeletekey', 'xp_regenumvalues', 'xp_fileexist',
  'xp_subdirs', 'xp_dirtree', 'xp_fixeddrives',
  'xp_enumerrorlogs', 'xp_readerrorlog',
  'xp_servicecontrol', 'xp_sprintf', 'xp_sscanf'
)
ORDER BY ps.execution_count DESC
GO

/* ===== SEC-SQL-INJ-002-RC02 — Backward compatibility requirements ===== */
SELECT d.name AS database_name,
  d.compatibility_level,
  CASE d.compatibility_level
    WHEN 100 THEN '2008'
    WHEN 110 THEN '2012'
    WHEN 120 THEN '2014'
    WHEN 130 THEN '2016'
    WHEN 140 THEN '2017'
    WHEN 150 THEN '2019'
    WHEN 160 THEN '2022'
    ELSE CAST(d.compatibility_level AS VARCHAR)
  END AS compat_version
FROM sys.databases d
WHERE d.database_id > 4
  AND d.compatibility_level < 130
GO

/* ===== SEC-SQL-INJ-002-RC05 — High barrier to refactoring ===== */
SELECT xproc_name, COUNT(DISTINCT calling_proc) AS dependent_proc_count
FROM (
  SELECT OBJECT_NAME(m.object_id) AS calling_proc,
    'xp_cmdshell' AS xproc_name
  FROM sys.sql_modules m
  JOIN sys.objects o ON m.object_id = o.object_id
  WHERE o.type = 'P'
    AND m.definition LIKE '%xp_cmdshell%' COLLATE Latin1_General_BIN
  UNION ALL
  SELECT OBJECT_NAME(m.object_id), 'xp_regread'
  FROM sys.sql_modules m
  JOIN sys.objects o ON m.object_id = o.object_id
  WHERE o.type = 'P'
    AND m.definition LIKE '%xp_regread%' COLLATE Latin1_General_BIN
  UNION ALL
  SELECT OBJECT_NAME(m.object_id), 'xp_fileexist'
  FROM sys.sql_modules m
  JOIN sys.objects o ON m.object_id = o.object_id
  WHERE o.type = 'P'
    AND m.definition LIKE '%xp_fileexist%' COLLATE Latin1_General_BIN
  UNION ALL
  SELECT OBJECT_NAME(m.object_id), 'xp_dirtree'
  FROM sys.sql_modules m
  JOIN sys.objects o ON m.object_id = o.object_id
  WHERE o.type = 'P'
    AND m.definition LIKE '%xp_dirtree%' COLLATE Latin1_General_BIN
  UNION ALL
  SELECT OBJECT_NAME(m.object_id), 'xp_subdirs'
  FROM sys.sql_modules m
  JOIN sys.objects o ON m.object_id = o.object_id
  WHERE o.type = 'P'
    AND m.definition LIKE '%xp_subdirs%' COLLATE Latin1_General_BIN
) refs
GROUP BY xproc_name
HAVING COUNT(DISTINCT calling_proc) >= 3
GO

/* ===== SEC-SQL-INJ-002-RC06 — Operational automation dependencies ===== */
SELECT j.name AS job_name, j.enabled AS job_enabled,
  js.step_name, js.subsystem, js.command,
  CASE
    WHEN js.command LIKE '%xp_cmdshell%' THEN 'xp_cmdshell'
    WHEN js.command LIKE '%xp_regread%' THEN 'xp_regread'
    WHEN js.command LIKE '%xp_fileexist%' THEN 'xp_fileexist'
    WHEN js.command LIKE '%xp_dirtree%' THEN 'xp_dirtree'
    WHEN js.command LIKE '%xp_subdirs%' THEN 'xp_subdirs'
    WHEN js.command LIKE '%xp_fixeddrives%' THEN 'xp_fixeddrives'
    WHEN js.command LIKE '%xp_servicecontrol%' THEN 'xp_servicecontrol'
    WHEN js.command LIKE '%xp_readerrorlog%' THEN 'xp_readerrorlog'
    ELSE 'other_xproc'
  END AS xproc_used
FROM msdb.dbo.sysjobs j
JOIN msdb.dbo.sysjobsteps js ON j.job_id = js.job_id
WHERE js.subsystem = 'TSQL'
  AND (js.command LIKE '%xp_cmdshell%' COLLATE Latin1_General_BIN
    OR js.command LIKE '%xp_regread%' COLLATE Latin1_General_BIN
    OR js.command LIKE '%xp_fileexist%' COLLATE Latin1_General_BIN
    OR js.command LIKE '%xp_dirtree%' COLLATE Latin1_General_BIN
    OR js.command LIKE '%xp_subdirs%' COLLATE Latin1_General_BIN
    OR js.command LIKE '%xp_fixeddrives%' COLLATE Latin1_General_BIN
    OR js.command LIKE '%xp_servicecontrol%' COLLATE Latin1_General_BIN
    OR js.command LIKE '%xp_readerrorlog%' COLLATE Latin1_General_BIN)
GO

/* ===== SEC-SQL-INJ-002-RC07 — Insufficient privilege controls ===== */
SELECT dp.name AS grantee_name, dp.type_desc AS principal_type,
  p.permission_name, p.state_desc,
  OBJECT_NAME(p.major_id) AS xproc_name
FROM master.sys.database_permissions p
JOIN master.sys.database_principals dp ON p.grantee_principal_id = dp.principal_id
WHERE p.permission_name = 'EXECUTE'
  AND p.state_desc IN ('GRANT', 'GRANT_WITH_GRANT_OPTION')
  AND OBJECT_NAME(p.major_id) IN (
    'xp_cmdshell', 'xp_regread', 'xp_regwrite', 'xp_regdeletevalue',
    'xp_regdeletekey', 'xp_fileexist', 'xp_subdirs', 'xp_dirtree',
    'xp_fixeddrives', 'xp_servicecontrol', 'xp_enumerrorlogs'
  )
  AND dp.name NOT IN ('dbo', 'public')
GO

/* ===== SEC-SQL-INJ-002-RC08 — Missing monitoring and enforcement ===== */
SELECT sas.name AS audit_spec_name, sas.is_state_enabled, sasd.audit_action_name, sasd.class_desc FROM sys.server_audit_specifications sas JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
GO

/* ===== SEC-SQL-INJ-002-RC09 — Assumption of network isolation ===== */
SELECT DISTINCT c.client_net_address,
  s.login_name, s.program_name,
  c.auth_scheme
FROM sys.dm_exec_connections c
JOIN sys.dm_exec_sessions s ON c.session_id = s.session_id
WHERE s.is_user_process = 1
  AND c.client_net_address IS NOT NULL
  AND c.client_net_address <> '<local machine>'
  AND c.client_net_address NOT LIKE '10.%'
  AND c.client_net_address NOT LIKE '172.1[6-9].%'
  AND c.client_net_address NOT LIKE '172.2[0-9].%'
  AND c.client_net_address NOT LIKE '172.3[0-1].%'
  AND c.client_net_address NOT LIKE '192.168.%'
  AND c.client_net_address NOT LIKE '127.%'
  AND c.client_net_address NOT LIKE 'fe80:%'
  AND c.client_net_address NOT LIKE '::1'
GO

/* ===== SEC-SQL-INJ-002-RC10 — Security compliance misalignment ===== */
SELECT
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations
    WHERE name = 'xp_cmdshell') AS xp_cmdshell_enabled,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations
    WHERE name = 'Ole Automation Procedures') AS ole_auto_enabled,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations
    WHERE name = 'clr enabled') AS clr_enabled,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations
    WHERE name = 'external scripts enabled') AS external_scripts_enabled,
  (SELECT COUNT(*) FROM master.sys.credentials
    WHERE name = '##xp_cmdshell_proxy_account##') AS xp_proxy_exists
GO

/* ===== SEC-SQL-INJ-002-RC11 — Service account privilege excess ===== */
SELECT
  (SELECT service_account FROM sys.dm_server_services
    WHERE servicename LIKE '%SQL Server%'
      AND servicename NOT LIKE '%Agent%'
      AND servicename NOT LIKE '%Launchpad%') AS sql_service_account,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations
    WHERE name = 'xp_cmdshell') AS xp_cmdshell_enabled
GO

/* ===== SEC-SQL-INJ-002-RC12 — Third-party application requirements ===== */
SELECT s.program_name, s.host_name, s.login_name,
  COUNT(DISTINCT r.session_id) AS active_sessions,
  MAX(s.last_request_start_time) AS last_activity
FROM sys.dm_exec_sessions s
LEFT JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
WHERE s.is_user_process = 1
  AND s.program_name IS NOT NULL
  AND s.program_name <> ''
  AND s.program_name NOT LIKE '%Microsoft SQL Server Management Studio%'
  AND s.program_name NOT LIKE '%sqlcmd%'
  AND s.program_name NOT LIKE '%SQLCMD%'
  AND s.program_name NOT LIKE '%SQLAgent%'
GROUP BY s.program_name, s.host_name, s.login_name
HAVING COUNT(*) > 0
GO

/* ===== SEC-SQL-INJ-002-RC14 — DLL file vulnerabilities ===== */
SELECT o.name AS xproc_name,
  o.type_desc, o.create_date,
  OBJECT_DEFINITION(o.object_id) AS definition,
  SCHEMA_NAME(o.schema_id) AS schema_name
FROM sys.objects o
WHERE o.type = 'X'
  AND o.is_ms_shipped = 0
GO

/* ===== SEC-SQL-INJ-002-RC15 — SQL injection chaining ===== */
SELECT OBJECT_SCHEMA_NAME(m.object_id) AS schema_name,
  OBJECT_NAME(m.object_id) AS proc_name,
  CASE
    WHEN m.definition LIKE '%EXEC(%+%@%' AND m.definition NOT LIKE '%sp_executesql%'
      THEN 'HIGH_RISK_EXEC_CONCAT'
    WHEN m.definition LIKE '%sp_executesql%+%@%+%'
      THEN 'MEDIUM_RISK_INCOMPLETE_PARAMS'
    WHEN m.definition LIKE '%EXEC(%+%@%'
      THEN 'MODERATE_RISK_EXEC_PATTERN'
    ELSE 'LOW_RISK'
  END AS injection_risk_level
FROM sys.sql_modules m
JOIN sys.objects o ON m.object_id = o.object_id
WHERE o.type = 'P'
  AND (m.definition LIKE '%EXEC(%+%@%' COLLATE Latin1_General_BIN
    OR m.definition LIKE '%EXECUTE(%+%@%' COLLATE Latin1_General_BIN
    OR m.definition LIKE '%EXEC (@%' COLLATE Latin1_General_BIN
    OR m.definition LIKE '%EXEC(@%' COLLATE Latin1_General_BIN)
GO

/* ===== SEC-SQL-INJ-002-RC16 — Insufficient removal validation ===== */
SELECT
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations
    WHERE name = 'xp_cmdshell') AS xp_cmdshell_enabled,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations
    WHERE name = 'Ole Automation Procedures') AS ole_auto_enabled,
  (SELECT COUNT(*) FROM master.sys.credentials
    WHERE name = '##xp_cmdshell_proxy_account##') AS proxy_account_exists,
  (SELECT COUNT(*) FROM master.sys.database_permissions p
    JOIN master.sys.database_principals dp ON p.grantee_principal_id = dp.principal_id
    WHERE p.permission_name = 'EXECUTE'
      AND OBJECT_NAME(p.major_id) LIKE 'xp_%'
      AND dp.name NOT IN ('dbo', 'public')) AS explicit_xproc_grants
GO

/* ===== SEC-SQL-NET-001-RC01 — Bind Address Misconfiguration ===== */
SELECT listener_id, ip_address, port, type_desc,
  state_desc, start_time
FROM sys.dm_tcp_listener_states
WHERE ip_address IN ('0.0.0.0', '::', '0:0:0:0:0:0:0:0')
  AND state_desc = 'ONLINE'
GO

/* ===== SEC-SQL-NET-001-RC02 — Overly Permissive Security Group/Firewall Rules ===== */
SELECT TOP 20 event_data.value('(event/@timestamp)[1]', 'datetime2') AS event_time, event_data.value('(event/data[@name="error_number"]/value)[1]', 'int') AS error_number, event_data.value('(event/data[@name="message"]/value)[1]', 'nvarchar(512)') AS error_message FROM (SELECT CAST(target_data AS xml) AS target_xml FROM sys.dm_xe_session_targets st JOIN sys.dm_xe_sessions s ON s.address = st.event_session_address WHERE s.name = 'system_health' AND st.target_name = 'ring_buffer') AS xdata CROSS APPLY target_xml.nodes('RingBufferTarget/event[@name="error_reported"]') AS n(event_data) WHERE event_data.value('(event/data[@name="error_number"]/value)[1]', 'int') IN (18456, 18452, 18451) ORDER BY event_time DESC
GO

/* ===== SEC-SQL-NET-001-RC03 — rootcause Cloud Instance Configuration ===== */
SELECT listener_id, ip_address, port, type_desc, state_desc
FROM sys.dm_tcp_listener_states
WHERE ip_address NOT IN ('127.0.0.1', '::1')
  AND ip_address <> '0.0.0.0'
  AND state_desc = 'STARTED'
GO

/* ===== SEC-SQL-NET-001-RC05 — Lack of IP Allowlist/Whitelist Enforcement ===== */
SELECT t.name AS trigger_name, t.create_date, t.modify_date,
  m.definition
FROM sys.server_triggers t
JOIN sys.server_sql_modules m ON t.object_id = m.object_id
WHERE t.type = 'TR'
  AND t.parent_class_desc = 'SERVER'
  AND (m.definition LIKE '%EVENTDATA%' OR m.definition LIKE '%client_net_address%'
    OR m.definition LIKE '%CONNECTIONPROPERTY%')
GO

/* ===== SEC-SQL-NET-001-RC11 — Shadow IT / Unauthorized Deployments ===== */
SELECT
  SERVERPROPERTY('MachineName') AS machine_name,
  SERVERPROPERTY('InstanceName') AS instance_name,
  SERVERPROPERTY('Edition') AS edition,
  SERVERPROPERTY('ProductVersion') AS version,
  SERVERPROPERTY('ProductLevel') AS service_pack,
  SERVERPROPERTY('IsClustered') AS is_clustered,
  (SELECT COUNT(*) FROM sys.databases WHERE database_id > 4) AS user_db_count,
  (SELECT create_date FROM sys.server_principals WHERE sid = 0x01) AS sa_create_date,
  (SELECT is_disabled FROM sys.server_principals WHERE sid = 0x01) AS sa_disabled,
  (SELECT COUNT(*) FROM sys.dm_tcp_listener_states WHERE state_desc = 'STARTED') AS active_listeners
GO

/* ===== SEC-SQL-NET-001-RC12 — Temporary Access Left Permanently ===== */
SELECT sp.name AS login_name, sp.type_desc, sp.create_date,
  sp.modify_date, sp.is_disabled,
  DATEDIFF(DAY, sp.create_date, GETDATE()) AS days_since_created
FROM sys.server_principals sp
WHERE sp.type IN ('S', 'U', 'G')
  AND sp.name NOT LIKE '##%'
  AND sp.name NOT IN ('sa', 'NT AUTHORITY\SYSTEM', 'NT SERVICE\MSSQLSERVER',
    'NT SERVICE\SQLSERVERAGENT', 'NT SERVICE\SQLWriter',
    'NT SERVICE\Winmgmt', 'NT SERVICE\SQLTELEMETRY')
  AND sp.is_disabled = 0
  AND DATEDIFF(DAY, sp.create_date, GETDATE()) > 90
  AND sp.principal_id NOT IN (
    SELECT DISTINCT security_id FROM sys.dm_exec_sessions
    WHERE is_user_process = 1
  )
GO

/* ===== SEC-SQL-NET-002-RC01 — Default Configuration Never Changed ===== */
SELECT listener_id, ip_address, port, type_desc, state_desc
FROM sys.dm_tcp_listener_states
WHERE state_desc = 'STARTED'
  AND type_desc = 'TSQL'
  AND port = 1433
GO

/* ===== SEC-SQL-NET-002-RC02 — Lack of Security Hardening Process ===== */
SELECT
  (SELECT is_disabled FROM sys.server_principals WHERE sid = 0x01) AS sa_disabled,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'xp_cmdshell') AS xp_cmdshell_enabled,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'Ole Automation Procedures') AS ole_auto_enabled,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'cross db ownership chaining') AS cross_db_chaining,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'clr enabled') AS clr_enabled,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'remote admin connections') AS remote_dac_enabled,
  (SELECT COUNT(*) FROM sys.server_principals WHERE type = 'S' AND name = 'sa' AND is_disabled = 0) AS sa_active
GO

/* ===== SEC-SQL-NET-002-RC03 — Convenience and Standardization ===== */
SELECT listener_id, ip_address, port, type_desc, state_desc
FROM sys.dm_tcp_listener_states
WHERE state_desc = 'STARTED'
  AND type_desc = 'TSQL'
  AND port = 1433
GO

/* ===== SEC-SQL-NET-002-RC04 — Documentation Focuses on Default Values ===== */
SELECT port, ip_address, type_desc
FROM sys.dm_tcp_listener_states
WHERE state_desc = 'STARTED'
  AND type_desc = 'TSQL'
  AND port = 1433
GO

/* ===== SEC-SQL-NET-002-RC05 — Port Scanning Facilitation ===== */
SELECT port, ip_address, type_desc, state_desc
FROM sys.dm_tcp_listener_states
WHERE state_desc = 'STARTED'
  AND port IN (1433, 1434)
ORDER BY port
GO

/* ===== SEC-SQL-NET-002-RC06 — Application Connection String Hardcoding ===== */
SELECT port, ip_address, type_desc
FROM sys.dm_tcp_listener_states
WHERE state_desc = 'STARTED'
  AND type_desc = 'TSQL'
  AND port = 1433
GO

/* ===== SEC-SQL-NET-002-RC08 — No Port Randomization or Obscurity Strategy ===== */
SELECT servicename, status_desc, startup_type_desc
FROM sys.dm_server_services
WHERE servicename LIKE '%Browser%'
GO

/* ===== SEC-SQL-NET-002-RC10 — Assumption Port Numbers Alone Provide Security ===== */
SELECT
  (SELECT DISTINCT local_tcp_port FROM sys.dm_exec_connections
   WHERE local_tcp_port IS NOT NULL AND net_transport = 'TCP') AS listening_port,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations
   WHERE name = 'remote admin connections') AS remote_dac_enabled,
  (SELECT COUNT(*) FROM sys.dm_exec_connections
   WHERE encrypt_option = 'FALSE' AND net_transport = 'TCP') AS unencrypted_connections,
  (SELECT COUNT(*) FROM sys.dm_exec_connections
   WHERE net_transport = 'TCP') AS total_tcp_connections
GO

/* ===== SEC-SQL-NET-002-RC12 — Version Disclosure via Banners ===== */
SELECT
  @@VERSION AS version_banner,
  SERVERPROPERTY('ProductVersion') AS product_version,
  SERVERPROPERTY('ProductLevel') AS service_pack,
  SERVERPROPERTY('Edition') AS edition,
  (SELECT DISTINCT local_tcp_port FROM sys.dm_exec_connections
   WHERE local_tcp_port IS NOT NULL AND net_transport = 'TCP') AS listening_port
GO

/* ===== SEC-SQL-NET-002-RC13 — Brute Force Attack Simplification ===== */
SELECT
  (SELECT DISTINCT local_tcp_port FROM sys.dm_exec_connections
   WHERE local_tcp_port IS NOT NULL AND net_transport = 'TCP') AS listening_port,
  SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_auth_only,
  (SELECT COUNT(*) FROM sys.sql_logins WHERE is_disabled = 0) AS enabled_sql_logins
GO

/* ===== SEC-SQL-NET-002-RC14 — Lack of Port Rotation Practices ===== */
SELECT
  (SELECT DISTINCT local_tcp_port FROM sys.dm_exec_connections
   WHERE local_tcp_port IS NOT NULL AND net_transport = 'TCP') AS current_port,
  (SELECT create_date FROM sys.databases WHERE name = 'master') AS instance_install_date,
  DATEDIFF(DAY,
    (SELECT create_date FROM sys.databases WHERE name = 'master'),
    GETDATE()) AS days_since_install,
  (SELECT sqlserver_start_time FROM sys.dm_os_sys_info) AS last_restart
GO

/* ===== SEC-SQL-NET-002-RC15 — Automated Scanning Vulnerability ===== */
SELECT
  (SELECT DISTINCT local_tcp_port FROM sys.dm_exec_connections
   WHERE local_tcp_port IS NOT NULL AND net_transport = 'TCP') AS listening_port,
  SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_auth_only,
  (SELECT COUNT(*) FROM sys.sql_logins
   WHERE name = 'sa' AND is_disabled = 0) AS sa_enabled,
  (SELECT status_desc FROM sys.dm_server_services
   WHERE servicename LIKE '%Browser%') AS browser_status
GO

/* ===== SEC-SQL-NET-003-RC03 — Database Features Requiring Internet Access ===== */
SELECT s.name AS linked_server_name,
  s.data_source AS remote_server,
  s.provider,
  s.product,
  s.is_remote_login_enabled,
  s.is_data_access_enabled
FROM sys.servers s
WHERE s.is_linked = 1
  AND s.data_source IS NOT NULL
  AND s.data_source NOT LIKE '%.local'
  AND s.data_source NOT LIKE '10.%'
  AND s.data_source NOT LIKE '172.1[6-9].%'
  AND s.data_source NOT LIKE '172.2[0-9].%'
  AND s.data_source NOT LIKE '172.3[0-1].%'
  AND s.data_source NOT LIKE '192.168.%'
  AND s.data_source NOT LIKE 'localhost%'
GO

/* ===== SEC-SQL-NET-003-RC04 — External data access configuration ===== */
SELECT s.name AS linked_server_name,
  s.data_source,
  s.provider,
  s.product,
  s.catalog,
  s.is_remote_login_enabled,
  s.is_data_access_enabled,
  s.is_rpc_out_enabled,
  ll.remote_name AS mapped_remote_login,
  ll.uses_self_credential
FROM sys.servers s
LEFT JOIN sys.linked_logins ll ON s.server_id = ll.server_id
WHERE s.is_linked = 1
GO

/* ===== SEC-SQL-NET-003-RC05 — External Data Source Integration ===== */
SELECT
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations
   WHERE name = 'polybase enabled') AS polybase_enabled,
  eds.name AS data_source_name,
  eds.type_desc AS source_type,
  eds.location AS remote_location,
  eds.credential_id,
  c.name AS credential_name
FROM sys.external_data_sources eds
LEFT JOIN sys.database_scoped_credentials c ON eds.credential_id = c.credential_id
GO

/* ===== SEC-SQL-NET-003-RC06 — Package Manager and Repository Access ===== */
SELECT
  (SELECT COUNT(*) FROM sys.dm_exec_requests
   WHERE command = 'ExternalScript') AS active_external_scripts,
  (SELECT cntr_value FROM sys.dm_os_performance_counters
   WHERE counter_name = 'Total Executions'
     AND object_name LIKE '%External Scripts%') AS total_executions
GO

/* ===== SEC-SQL-NET-003-RC14 — Database Replication to Cloud ===== */
SELECT s.name AS linked_server_name,
  s.data_source,
  s.provider,
  s.product,
  s.catalog,
  l.remote_name,
  s.is_data_access_enabled,
  s.is_rpc_out_enabled
FROM sys.servers s
LEFT JOIN sys.linked_logins l ON s.server_id = l.server_id
WHERE s.is_linked = 1
  AND (s.data_source LIKE '%.database.windows.net%'
    OR s.data_source LIKE '%.database.azure.com%'
    OR s.data_source LIKE '%.rds.amazonaws.com%'
    OR s.data_source LIKE '%.sql.azuresynapse.net%'
    OR s.data_source LIKE '%.cosmos.azure.com%'
    OR s.data_source LIKE '%.cloud.google.com%'
    OR s.data_source LIKE '%.googleapis.com%')
GO

/* ===== SEC-SQL-NET-003-RC15 — Monitoring and Logging Exfiltration ===== */
SELECT p.name AS profile_name,
  a.name AS account_name,
  a.email_address,
  s.servername AS smtp_server,
  s.port AS smtp_port,
  s.enable_ssl
FROM msdb.dbo.sysmail_profile p
JOIN msdb.dbo.sysmail_profileaccount pa ON p.profile_id = pa.profile_id
JOIN msdb.dbo.sysmail_account a ON pa.account_id = a.account_id
JOIN msdb.dbo.sysmail_server s ON a.account_id = s.account_id
GO

/* ===== SEC-SQL-PAT-001-RC01 — Lack of proactive EOL tracking and monitoring ===== */
SELECT
  SERVERPROPERTY('ProductVersion') AS product_version,
  SERVERPROPERTY('ProductMajorVersion') AS major_version,
  SERVERPROPERTY('ProductMinorVersion') AS minor_version,
  SERVERPROPERTY('ProductLevel') AS product_level,
  SERVERPROPERTY('ProductUpdateLevel') AS update_level,
  SERVERPROPERTY('Edition') AS edition,
  @@VERSION AS full_version_string,
  CASE CAST(SERVERPROPERTY('ProductMajorVersion') AS INT)
    WHEN 10 THEN 'SQL Server 2008/2008R2 — EXTENDED SUPPORT ENDED 2019-07-09'
    WHEN 11 THEN 'SQL Server 2012 — EXTENDED SUPPORT ENDED 2022-07-12'
    WHEN 12 THEN 'SQL Server 2014 — EXTENDED SUPPORT ENDED 2024-07-09'
    WHEN 13 THEN 'SQL Server 2016 — EXTENDED SUPPORT ENDS 2026-07-14'
    WHEN 14 THEN 'SQL Server 2017 — EXTENDED SUPPORT ENDS 2027-10-12'
    WHEN 15 THEN 'SQL Server 2019 — MAINSTREAM SUPPORT ENDS 2025-02-28, EXTENDED 2030-01-08'
    WHEN 16 THEN 'SQL Server 2022 — MAINSTREAM SUPPORT ENDS 2028-01-11, EXTENDED 2033-01-11'
    ELSE 'Unknown version — verify manually'
  END AS lifecycle_status
GO

/* ===== SEC-SQL-PAT-001-RC02 — Deferred major version upgrades due to technical complexity ===== */
SELECT
  CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) AS current_major,
  16 AS latest_major_version,
  16 - CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) AS versions_behind,
  CASE CAST(SERVERPROPERTY('ProductMajorVersion') AS INT)
    WHEN 10 THEN 'SQL Server 2008/2008R2 — 6 major versions behind'
    WHEN 11 THEN 'SQL Server 2012 — 5 major versions behind'
    WHEN 12 THEN 'SQL Server 2014 — 4 major versions behind'
    WHEN 13 THEN 'SQL Server 2016 — 3 major versions behind'
    WHEN 14 THEN 'SQL Server 2017 — 2 major versions behind'
    WHEN 15 THEN 'SQL Server 2019 — 1 major version behind'
    WHEN 16 THEN 'SQL Server 2022 — current release'
    ELSE 'Unknown version'
  END AS version_assessment,
  SERVERPROPERTY('ProductVersion') AS product_version,
  SERVERPROPERTY('ProductLevel') AS product_level
GO

/* ===== SEC-SQL-PAT-001-RC05 — Application dependency on deprecated database features ===== */
SELECT instance_name AS deprecated_feature,
  cntr_value AS usage_count,
  CASE
    WHEN instance_name LIKE '%STRING_ESCAPE%' THEN 'syntax'
    WHEN instance_name LIKE '%compatibility%' THEN 'compatibility'
    WHEN instance_name LIKE '%DATABASEPROPERTY%' THEN 'metadata-function'
    WHEN instance_name LIKE '%SET ROWCOUNT%' THEN 'syntax'
    WHEN instance_name LIKE '%RAISERROR%' THEN 'syntax'
    WHEN instance_name LIKE '%sp_addtype%' THEN 'system-proc'
    WHEN instance_name LIKE '%ntext%' THEN 'data-type'
    WHEN instance_name LIKE '%image%' THEN 'data-type'
    WHEN instance_name LIKE '%text%' THEN 'data-type'
    ELSE 'other'
  END AS category
FROM sys.dm_os_performance_counters
WHERE object_name LIKE '%Deprecated Features%'
  AND cntr_value > 1000
ORDER BY cntr_value DESC
GO

/* ===== SEC-SQL-PAT-001-RC09 — Client and driver compatibility concerns ===== */
SELECT
  s.program_name,
  s.client_interface_name,
  c.protocol_version,
  c.client_net_address,
  COUNT(*) AS sessions
FROM sys.dm_exec_sessions s
JOIN sys.dm_exec_connections c ON s.session_id = c.session_id
WHERE c.protocol_version < 1946157060
  AND s.is_user_process = 1
GROUP BY s.program_name, s.client_interface_name,
  c.protocol_version, c.client_net_address
ORDER BY sessions DESC
GO

/* ===== SEC-SQL-PAT-001-RC11 — Legacy application portfolio constraints ===== */
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

/* ===== SEC-SQL-PAT-001-RC12 — Incremental neglect over multiple release cycles ===== */
SELECT
  si.sqlserver_start_time,
  DATEDIFF(DAY, si.sqlserver_start_time, GETDATE()) AS days_since_restart,
  (SELECT COUNT(*) FROM sys.configurations WHERE value <> value_in_use) AS pending_config_changes,
  (SELECT COUNT(*) FROM sys.databases WHERE state_desc <> 'ONLINE' AND database_id > 4) AS non_online_dbs,
  (SELECT MAX(backup_finish_date) FROM msdb.dbo.backupset WHERE type = 'D') AS last_full_backup,
  DATEDIFF(DAY, (SELECT MAX(backup_finish_date) FROM msdb.dbo.backupset WHERE type = 'D'), GETDATE()) AS days_since_last_backup
FROM sys.dm_os_sys_info si
GO

/* ===== SEC-SQL-PAT-002-RC02 — Extended CVE disclosure-to-patch timelines ===== */
SELECT
  sqlserver_start_time,
  DATEDIFF(DAY, sqlserver_start_time, GETDATE()) AS uptime_days,
  DATEDIFF(HOUR, sqlserver_start_time, GETDATE()) AS uptime_hours
FROM sys.dm_os_sys_info
GO

/* ===== SEC-SQL-PAT-002-RC09 — Incompatible dependency chains ===== */
SELECT s.name AS linked_server_name,
  s.product, s.provider, s.data_source,
  s.provider_string,
  s.is_linked, s.is_remote_login_enabled
FROM sys.servers s
WHERE s.is_linked = 1
GO

/* ===== SEC-SQL-PAT-002-RC10 — Active database usage preventing maintenance windows ===== */
SELECT
  (SELECT COUNT(*) FROM sys.dm_exec_sessions WHERE is_user_process = 1) AS active_user_sessions,
  (SELECT COUNT(*) FROM sys.dm_tran_active_transactions t
   JOIN sys.dm_tran_session_transactions st ON t.transaction_id = st.transaction_id
   WHERE DATEDIFF(MINUTE, t.transaction_begin_time, GETDATE()) > 30) AS long_running_transactions,
  (SELECT COUNT(*) FROM sys.dm_exec_requests WHERE status IN ('running', 'runnable', 'suspended')
   AND session_id > 50) AS active_requests
GO

/* ===== SEC-SQL-PAT-002-RC12 — Critical patches for rarely-exploited vulnerabilities ===== */
SELECT
  sqlserver_start_time,
  DATEDIFF(DAY, sqlserver_start_time, GETDATE()) AS days_since_restart,
  CASE
    WHEN DATEDIFF(DAY, sqlserver_start_time, GETDATE()) > 180 THEN 'CRITICAL: Over 6 months since restart'
    WHEN DATEDIFF(DAY, sqlserver_start_time, GETDATE()) > 90 THEN 'WARNING: Over 3 months since restart'
    ELSE 'OK: Restarted within last 90 days'
  END AS patch_staleness
FROM sys.dm_os_sys_info
GO

/* ===== SEC-SQL-PRI-001-RC01 — Misunderstanding of "Encryption at Rest" (TDE) ===== */
SELECT
  (SELECT COUNT(*) FROM sys.column_master_keys) AS column_master_key_count,
  (SELECT COUNT(*) FROM sys.column_encryption_keys) AS column_encryption_key_count,
  (SELECT COUNT(*) FROM sys.column_encryption_key_values) AS cek_value_count
GO

/* ===== SEC-SQL-PRI-001-RC02 — Searchability \& Indexing Requirements ===== */
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

/* ===== SEC-SQL-PRI-001-RC03 — Performance Overhead Fears ===== */
SELECT
  SERVERPROPERTY('Edition') AS edition,
  SERVERPROPERTY('ProductMajorVersion') AS major_version,
  CASE
    WHEN CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) >= 13
      AND (CAST(SERVERPROPERTY('Edition') AS NVARCHAR(128)) LIKE '%Enterprise%'
        OR CAST(SERVERPROPERTY('Edition') AS NVARCHAR(128)) LIKE '%Developer%'
        OR CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) >= 15)
    THEN 'Always Encrypted available'
    ELSE 'Always Encrypted not available'
  END AS ae_availability
GO

/* ===== SEC-SQL-PRI-001-RC04 — Incorrect Data Types ===== */
SELECT
  OBJECT_SCHEMA_NAME(c.object_id) AS schema_name,
  OBJECT_NAME(c.object_id) AS table_name,
  c.name AS column_name,
  ty.name AS data_type,
  c.max_length,
  c.encryption_type_desc,
  mc.is_masked
FROM sys.columns c
JOIN sys.types ty ON c.user_type_id = ty.user_type_id
JOIN sys.objects o ON c.object_id = o.object_id
LEFT JOIN sys.masked_columns mc ON c.object_id = mc.object_id AND c.column_id = mc.column_id
WHERE o.type = 'U'
  AND ty.name IN ('varchar', 'nvarchar', 'char', 'nchar')
  AND c.encryption_type IS NULL
  AND (mc.is_masked IS NULL OR mc.is_masked = 0)
  AND (
    c.name LIKE '%ssn%'
    OR c.name LIKE '%social_security%'
    OR c.name LIKE '%credit_card%'
    OR c.name LIKE '%card_number%'
    OR c.name LIKE '%tax_id%'
    OR c.name LIKE '%passport%'
    OR c.name LIKE '%driver_license%'
    OR c.name LIKE '%national_id%'
    OR c.name LIKE '%bank_account%'
    OR c.name LIKE '%routing_number%'
  )
GO

/* ===== SEC-SQL-PRI-001-RC05 — Legacy Schema Constraints ===== */
SELECT
  OBJECT_SCHEMA_NAME(c.object_id) AS schema_name,
  OBJECT_NAME(c.object_id) AS table_name,
  c.name AS column_name,
  ty.name AS data_type,
  c.encryption_type_desc
FROM sys.columns c
JOIN sys.types ty ON c.user_type_id = ty.user_type_id
JOIN sys.objects o ON c.object_id = o.object_id
WHERE o.type = 'U'
  AND c.encryption_type IS NULL
  AND (
    c.name LIKE '%ssn%'
    OR c.name LIKE '%social_security%'
    OR c.name LIKE '%credit_card%'
    OR c.name LIKE '%card_number%'
    OR c.name LIKE '%tax_id%'
    OR c.name LIKE '%passport%'
    OR c.name LIKE '%driver_license%'
    OR c.name LIKE '%national_id%'
    OR c.name LIKE '%bank_account%'
    OR c.name LIKE '%date_of_birth%'
    OR c.name LIKE '%dob%'
  )
GO

/* ===== SEC-SQL-PRI-001-RC06 — In-House "Masking" Logic Failure ===== */
SELECT OBJECT_SCHEMA_NAME(c.object_id) + '.' + OBJECT_NAME(c.object_id) AS table_name, c.name AS column_name, t.name AS data_type, c.max_length, CASE WHEN c.name LIKE '%email%' OR c.name LIKE '%phone%' OR c.name LIKE '%ssn%' OR c.name LIKE '%credit%' OR c.name LIKE '%address%' THEN 'PII_CANDIDATE' ELSE 'STANDARD' END AS pii_status FROM sys.columns c JOIN sys.types t ON c.user_type_id = t.user_type_id WHERE OBJECT_SCHEMA_NAME(c.object_id) NOT IN ('sys') AND (c.name LIKE '%email%' OR c.name LIKE '%phone%' OR c.name LIKE '%ssn%' OR c.name LIKE '%credit%' OR c.name LIKE '%address%')
GO

/* ===== SEC-SQL-PRI-001-RC07 — ETL \& Data Warehousing Stripping ===== */
SELECT TOP 50
  qs.last_execution_time,
  SUBSTRING(st.text, 1, 500) AS query_text,
  qs.execution_count,
  qp.query_plan.exist('//RelOp[@LogicalOp="Insert"]') AS has_insert,
  qp.query_plan.exist('//RelOp[@LogicalOp="Clustered Index Insert"]') AS has_bulk_insert
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
WHERE (st.text LIKE '%SELECT%INTO%' OR st.text LIKE '%BULK INSERT%'
  OR st.text LIKE '%INSERT%INTO%SELECT%' OR st.text LIKE '%OPENROWSET%')
  AND qs.last_execution_time > DATEADD(DAY, -7, GETDATE())
ORDER BY qs.last_execution_time DESC
GO

/* ===== SEC-SQL-PRI-001-RC09 — Key Management Complexity ===== */
SELECT cmk.name AS master_key_name, cmk.key_store_provider_name,
  cmk.key_path, cmk.create_date, cmk.modify_date,
  CASE cmk.key_store_provider_name
    WHEN 'MSSQL_CERTIFICATE_STORE' THEN 'Windows Certificate Store'
    WHEN 'AZURE_KEY_VAULT' THEN 'Azure Key Vault'
    WHEN 'MSSQL_CNG_STORE' THEN 'CNG Provider'
    WHEN 'MSSQL_CSP_PROVIDER' THEN 'CSP Provider'
    ELSE 'Unknown'
  END AS store_description
FROM sys.column_master_keys cmk
ORDER BY cmk.name
GO

/* ===== SEC-SQL-PRI-001-RC10 — Lack of Native Masking Features (Old Versions) ===== */
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

/* ===== SEC-SQL-PRI-001-RC11 — Unsecured Backups/Snapshots ===== */
SELECT d.name AS database_name, dek.encryption_state, CASE dek.encryption_state WHEN 0 THEN 'No encryption key' WHEN 1 THEN 'Unencrypted' WHEN 2 THEN 'Encryption in progress' WHEN 3 THEN 'Encrypted' WHEN 4 THEN 'Key change in progress' WHEN 5 THEN 'Decryption in progress' ELSE 'Unknown' END AS encryption_state_desc, dek.key_algorithm AS tde_algorithm, dek.key_length AS tde_key_length, c.name AS certificate_name, c.expiry_date AS cert_expiry FROM sys.databases d LEFT JOIN sys.dm_database_encryption_keys dek ON d.database_id = dek.database_id LEFT JOIN sys.certificates c ON dek.encryptor_thumbprint = c.thumbprint WHERE d.database_id > 4 ORDER BY CASE WHEN dek.encryption_state IS NULL THEN 0 ELSE 1 END, dek.encryption_state ASC
GO

/* ===== SEC-SQL-PRI-001-RC12 — Sensitive columns discovered in schema (PII) ===== */
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

EXEC sp_executesql @sql;

SELECT db_name, schema_name, table_name, column_name, data_type, max_length, pii_category
  FROM #sensitive_cols
 ORDER BY pii_category, db_name, schema_name, table_name, column_name;
GO

/* ===== SEC-SQL-PRI-001-RC13 — Sensitive columns actively queried (PII in use) ===== */
SELECT s.name AS schema_name, t.name AS table_name, c.name AS column_name, ius.user_seeks + ius.user_scans + ius.user_lookups AS total_reads, ius.last_user_seek, ius.last_user_scan, CASE WHEN c.name LIKE '%ssn%' OR c.name LIKE '%social_security%' THEN 'SSN' WHEN c.name LIKE '%credit_card%' OR c.name LIKE '%card_number%' OR c.name LIKE '%cvv%' THEN 'Credit Card' WHEN c.name LIKE '%password%' OR c.name LIKE '%passwd%' OR c.name LIKE '%secret%' OR c.name LIKE '%api_key%' THEN 'Credential' WHEN c.name LIKE '%email%' THEN 'Email' WHEN c.name LIKE '%phone%' OR c.name LIKE '%mobile%' THEN 'Phone' WHEN c.name LIKE '%salary%' OR c.name LIKE '%income%' THEN 'Financial' WHEN c.name LIKE '%bank_account%' OR c.name LIKE '%iban%' THEN 'Bank Account' WHEN c.name LIKE '%national_id%' OR c.name LIKE '%passport%' OR c.name LIKE '%tax_id%' THEN 'Government ID' WHEN c.name LIKE '%medical%' OR c.name LIKE '%diagnosis%' THEN 'Medical' ELSE 'Other Sensitive' END AS pii_category FROM sys.columns c JOIN sys.tables t ON t.object_id = c.object_id JOIN sys.schemas s ON s.schema_id = t.schema_id JOIN sys.dm_db_index_usage_stats ius ON ius.object_id = t.object_id AND ius.database_id = DB_ID() WHERE t.is_ms_shipped = 0 AND (ius.user_seeks + ius.user_scans + ius.user_lookups) > 0 AND (c.name LIKE '%ssn%' OR c.name LIKE '%credit_card%' OR c.name LIKE '%password%' OR c.name LIKE '%email%' OR c.name LIKE '%phone%' OR c.name LIKE '%salary%' OR c.name LIKE '%bank_account%' OR c.name LIKE '%national_id%' OR c.name LIKE '%passport%' OR c.name LIKE '%tax_id%' OR c.name LIKE '%medical%' OR c.name LIKE '%diagnosis%' OR c.name LIKE '%birth%' OR c.name LIKE '%dob%' OR c.name LIKE '%ip_address%' OR c.name LIKE '%biometric%' OR c.name LIKE '%secret%' OR c.name LIKE '%api_key%' OR c.name LIKE '%iban%' OR c.name LIKE '%income%') ORDER BY total_reads DESC
GO

/* ===== SEC-SQL-PRI-001-RC14 — Active transactions reading/writing sensitive columns (PII) ===== */
SELECT r.session_id, s.login_name, s.host_name, s.program_name, DB_NAME(r.database_id) AS database_name, sch.name AS schema_name, t.name AS table_name, c.name AS column_name, CASE WHEN LOWER(c.name) LIKE '%password%' OR LOWER(c.name) LIKE '%pass%' THEN 'Password' WHEN LOWER(c.name) LIKE '%secret%' OR LOWER(c.name) LIKE '%token%' OR LOWER(c.name) LIKE '%key%' THEN 'Credential' WHEN LOWER(c.name) LIKE '%credit%' OR LOWER(c.name) LIKE '%card%' THEN 'Credit Card' WHEN LOWER(c.name) LIKE '%ssn%' THEN 'SSN' WHEN LOWER(c.name) LIKE '%email%' THEN 'Email' WHEN LOWER(c.name) LIKE '%phone%' THEN 'Phone' WHEN LOWER(c.name) LIKE '%address%' THEN 'Address' WHEN LOWER(c.name) LIKE '%dob%' OR LOWER(c.name) LIKE '%birth%' THEN 'Date of Birth' WHEN LOWER(c.name) LIKE '%salary%' THEN 'Salary' ELSE 'Other Sensitive' END AS pii_category, LEFT(st.text, 4000) AS query_text, r.start_time, r.status FROM sys.dm_exec_requests r CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st JOIN sys.dm_exec_sessions s ON s.session_id = r.session_id JOIN sys.tables t ON t.is_ms_shipped = 0 JOIN sys.columns c ON c.object_id = t.object_id JOIN sys.schemas sch ON sch.schema_id = t.schema_id WHERE s.is_user_process = 1 AND r.session_id <> @@SPID AND st.text LIKE '%' + t.name + '%' AND (LOWER(c.name) LIKE '%password%' OR LOWER(c.name) LIKE '%pass%' OR LOWER(c.name) LIKE '%secret%' OR LOWER(c.name) LIKE '%token%' OR LOWER(c.name) LIKE '%key%' OR LOWER(c.name) LIKE '%credit%' OR LOWER(c.name) LIKE '%card%' OR LOWER(c.name) LIKE '%ssn%' OR LOWER(c.name) LIKE '%email%' OR LOWER(c.name) LIKE '%phone%' OR LOWER(c.name) LIKE '%address%' OR LOWER(c.name) LIKE '%dob%' OR LOWER(c.name) LIKE '%birth%' OR LOWER(c.name) LIKE '%salary%') ORDER BY r.session_id, t.name, c.name
GO

/* ===== SEC-SQL-PRI-001-RC15 — Sensitive columns in cached plans / active transactions (PII) ===== */
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
JOIN sys.dm_exec_sessions               ses ON ses.session_id     = sts.session_id
JOIN sys.dm_exec_connections            con ON con.session_id     = sts.session_id
CROSS APPLY sys.dm_exec_sql_text(con.most_recent_sql_handle) AS t
JOIN #sensitive_cols sc ON t.text LIKE '%' + sc.table_name + '%'
WHERE tat.transaction_state = 2
  AND ses.is_user_process   = 1
  AND t.text IS NOT NULL
  AND LEFT(t.text, 4000) NOT LIKE '%tempdb..#sensitive_cols%'
ORDER BY source, last_execution_time;
GO

/* ===== SEC-SQL-PRI-002-RC01 — Global "Log Everything" Configuration ===== */
SELECT sa.name AS audit_name, CASE WHEN sa.is_state_enabled = 1 THEN 'STARTED' ELSE 'STOPPED' END AS audit_status,
  sas.name AS spec_name,
  sasd.audit_action_name, sasd.class_desc,
  sasd.audited_result
FROM sys.server_audits sa
JOIN sys.server_audit_specifications sas ON sa.audit_guid = sas.audit_guid
JOIN sys.server_audit_specification_details sasd ON sas.server_specification_id = sasd.server_specification_id
WHERE sa.is_state_enabled = 1
ORDER BY sa.name, sasd.audit_action_name
GO

/* ===== SEC-SQL-PRI-002-RC02 — Unparameterized Queries (String Concatenation) ===== */
SELECT
  objtype AS plan_type,
  COUNT(*) AS plan_count,
  SUM(CAST(size_in_bytes AS BIGINT)) / 1048576 AS size_mb,
  CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,1)) AS pct_of_plans
FROM sys.dm_exec_cached_plans
GROUP BY objtype
ORDER BY plan_count DESC
GO

/* ===== SEC-SQL-PRI-002-RC03 — Verbose Error Logging ===== */
SELECT message_id, severity, text, language_id
FROM sys.messages
WHERE message_id > 50000
  AND language_id = 1033
ORDER BY message_id
GO

/* ===== SEC-SQL-PRI-002-RC04 — Audit Trail Over-Configuration ===== */
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

/* ===== SEC-SQL-PRI-002-RC05 — Sensitive Functions in Logs ===== */
SELECT es.name AS session_name, es.startup_state, ese.name AS event_name, ese.package FROM sys.server_event_sessions es JOIN sys.server_event_session_events ese ON es.event_session_id = ese.event_session_id
GO

/* ===== SEC-SQL-PRI-002-RC06 — Crash Dumps and Core Files ===== */
SELECT name, CAST(value_in_use AS INT) AS current_value,
  CASE name
    WHEN 'default trace enabled' THEN
      CASE CAST(value_in_use AS INT)
        WHEN 1 THEN 'Default trace ON — captures events to trc files'
        ELSE 'Default trace OFF'
      END
  END AS assessment
FROM sys.configurations
WHERE name IN ('default trace enabled')
UNION ALL
SELECT 'sqldumper_flags' AS name,
  0 AS current_value,
  'Check LOG\SQLDUMPER_ERRORLOG.log for dump flags' AS assessment
GO

/* ===== SEC-SQL-PRI-002-RC07 — Slow Query Logs with Low Thresholds ===== */
SELECT es.name AS session_name, es.startup_state, ese.name AS event_name, ese.package FROM sys.server_event_sessions es JOIN sys.server_event_session_events ese ON es.event_session_id = ese.event_session_id
GO

/* ===== SEC-SQL-PRI-002-RC09 — Trace Files left Enabled ===== */
SELECT t.id AS trace_id, t.path,
  te.name AS event_name, tc.name AS column_name
FROM sys.traces t
CROSS APPLY sys.fn_trace_geteventinfo(t.id) ei
JOIN sys.trace_events te ON ei.eventid = te.trace_event_id
JOIN sys.trace_columns tc ON ei.columnid = tc.trace_column_id
WHERE t.status = 1
  AND te.name IN ('SQL:BatchCompleted', 'SQL:StmtCompleted',
    'RPC:Completed', 'SP:StmtCompleted',
    'SQL:BatchStarting', 'RPC:Starting')
  AND tc.name = 'TextData'
ORDER BY t.id, te.name
GO

/* ===== SEC-SQL-PRI-002-RC11 — Insufficient Log Rotation/Permissions ===== */
SELECT name, CAST(value_in_use AS INT) AS value_in_use,
  CASE name
    WHEN 'number of errorlog files' THEN
      CASE
        WHEN CAST(value_in_use AS INT) <= 6 THEN 'DEFAULT (6) — may retain too few or too many logs'
        WHEN CAST(value_in_use AS INT) > 30 THEN 'HIGH — ' + CAST(value_in_use AS VARCHAR) + ' log files retained'
        ELSE 'CUSTOM — ' + CAST(value_in_use AS VARCHAR) + ' log files'
      END
  END AS assessment
FROM sys.configurations
WHERE name = 'number of errorlog files'
GO

/* ===== SEC-SQL-PRI-003-RC01 — No documented security-level classification ===== */
SELECT DB_NAME() AS database_name, 'missing PPL_Security_Level extended property' AS finding WHERE NOT EXISTS (SELECT 1 FROM sys.extended_properties WHERE name = 'PPL_Security_Level' AND class = 0)
GO

/* ===== SEC-SQL-PRI-003-RC02 — Database meets High-level criteria but configured as Basic/Medium ===== */
SELECT t.name AS table_name, p.rows, 'row_count >= 100000 — likely High-level under PPL Reg §2' AS finding FROM sys.tables t JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1) WHERE p.rows >= 100000 ORDER BY p.rows DESC
GO

/* ===== SEC-SQL-PRI-003-RC03 — External access enabled without High-level controls ===== */
SELECT name AS check_name, value_in_use FROM sys.configurations WHERE name IN ('remote access') AND CAST(value_in_use AS INT) = 1 UNION ALL SELECT 'mixed mode auth', CASE SERVERPROPERTY('IsIntegratedSecurityOnly') WHEN 0 THEN 1 ELSE 0 END WHERE CAST(SERVERPROPERTY('IsIntegratedSecurityOnly') AS INT) = 0
GO

/* ===== SEC-SQL-PRI-004-RC01 — TDE / database-level encryption not enabled ===== */
SELECT DB_NAME(database_id) AS database_name, encryption_state, key_algorithm FROM sys.dm_database_encryption_keys WHERE encryption_state <> 3 OR encryption_state IS NULL UNION ALL SELECT name, 0 AS encryption_state, NULL FROM sys.databases d WHERE database_id > 4 AND NOT EXISTS (SELECT 1 FROM sys.dm_database_encryption_keys k WHERE k.database_id = d.database_id)
GO

/* ===== SEC-SQL-PRI-004-RC02 — Sensitive columns stored without column-level encryption ===== */
SELECT s.name AS schema_name, t.name AS table_name, c.name AS column_name, ty.name AS data_type FROM sys.columns c JOIN sys.tables t ON t.object_id = c.object_id JOIN sys.schemas s ON s.schema_id = t.schema_id JOIN sys.types ty ON ty.user_type_id = c.user_type_id WHERE t.is_ms_shipped = 0 AND c.encryption_type IS NULL AND (LOWER(c.name) LIKE '%password%' OR LOWER(c.name) LIKE '%ssn%' OR LOWER(c.name) LIKE '%credit_card%' OR LOWER(c.name) LIKE '%card_number%' OR LOWER(c.name) LIKE '%email%' OR LOWER(c.name) LIKE '%phone%' OR LOWER(c.name) LIKE '%passport%' OR LOWER(c.name) LIKE '%medical%')
GO

/* ===== SEC-SQL-PRI-004-RC03 — Connections not enforced over TLS ===== */
SELECT session_id, encrypt_option FROM sys.dm_exec_connections WHERE encrypt_option = 'FALSE' AND session_id > 50
GO

/* ===== SEC-SQL-PRI-005-RC01 — No audit specification configured ===== */
SELECT 'No server audit specifications' AS finding WHERE NOT EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE is_state_enabled = 1) UNION ALL SELECT 'No database audit specifications' WHERE NOT EXISTS (SELECT 1 FROM sys.database_audit_specifications WHERE is_state_enabled = 1)
GO

/* ===== SEC-SQL-PRI-005-RC02 — Audit configured but does not cover SELECT on PII tables ===== */
SELECT t.name AS pii_table, 'No audit action covers SELECT' AS finding FROM sys.tables t JOIN sys.columns c ON c.object_id = t.object_id WHERE t.is_ms_shipped = 0 AND (LOWER(c.name) LIKE '%password%' OR LOWER(c.name) LIKE '%ssn%' OR LOWER(c.name) LIKE '%credit_card%' OR LOWER(c.name) LIKE '%email%') AND NOT EXISTS (SELECT 1 FROM sys.database_audit_specification_details d WHERE d.audit_action_name = 'SELECT' AND d.major_id = t.object_id)
GO

/* ===== SEC-SQL-PRI-005-RC03 — Audit log retention < 24 months ===== */
SELECT name, max_rollover_files, max_file_size FROM sys.server_file_audits WHERE (max_rollover_files * COALESCE(NULLIF(max_file_size,0), 1)) < 100000
GO

/* ===== SEC-SQL-PRI-006-RC01 — Public role has SELECT on PII tables ===== */
SELECT s.name AS schema_name, o.name AS table_name, p.permission_name, dp.name AS principal FROM sys.database_permissions p JOIN sys.objects o ON o.object_id = p.major_id JOIN sys.schemas s ON s.schema_id = o.schema_id JOIN sys.database_principals dp ON dp.principal_id = p.grantee_principal_id JOIN sys.columns c ON c.object_id = o.object_id WHERE p.permission_name = 'SELECT' AND p.state = 'G' AND dp.name = 'public' AND (LOWER(c.name) LIKE '%password%' OR LOWER(c.name) LIKE '%ssn%' OR LOWER(c.name) LIKE '%credit_card%' OR LOWER(c.name) LIKE '%email%')
GO

/* ===== SEC-SQL-PRI-006-RC02 — Application accounts hold sysadmin / db_owner ===== */
SELECT sp.name AS principal, r.name AS role_name FROM sys.server_principals sp JOIN sys.server_role_members srm ON srm.member_principal_id = sp.principal_id JOIN sys.server_principals r ON r.principal_id = srm.role_principal_id WHERE r.name IN ('sysadmin','securityadmin','serveradmin') AND (LOWER(sp.name) LIKE '%app%' OR LOWER(sp.name) LIKE '%svc%' OR LOWER(sp.name) LIKE '%service%' OR LOWER(sp.name) LIKE '%api%')
GO

/* ===== SEC-SQL-PRI-006-RC03 — Stale logins retain access to personal data ===== */
SELECT sp.name AS login_name, MAX(s.login_time) AS last_login FROM sys.server_principals sp LEFT JOIN sys.dm_exec_sessions s ON s.login_name = sp.name WHERE sp.type IN ('S','U') AND sp.is_disabled = 0 AND sp.name NOT LIKE '##%' AND sp.name <> 'sa' GROUP BY sp.name HAVING MAX(s.login_time) IS NULL OR MAX(s.login_time) < DATEADD(day, -90, GETDATE())
GO

/* ===== SEC-SQL-PRI-007-RC01 — SQL logins without password policy ===== */
SELECT name, is_policy_checked, is_expiration_checked FROM sys.sql_logins WHERE (is_policy_checked = 0 OR is_expiration_checked = 0) AND is_disabled = 0 AND name <> 'sa'
GO

/* ===== SEC-SQL-PRI-007-RC02 — Shared / generic logins in use ===== */
SELECT name, type_desc FROM sys.server_principals WHERE is_disabled = 0 AND LOWER(name) IN ('admin','app','svc','dba','root','user','test','dbuser')
GO

/* ===== SEC-SQL-PRI-007-RC03 — SA / superuser login enabled and active ===== */
SELECT name, is_disabled FROM sys.server_principals WHERE name = 'sa' AND is_disabled = 0
GO

/* ===== SEC-SQL-PRI-008-RC01 — No recent backup of database holding personal data ===== */
SELECT d.name AS database_name, MAX(b.backup_finish_date) AS last_backup FROM sys.databases d LEFT JOIN msdb.dbo.backupset b ON b.database_name = d.name AND b.type IN ('D','I') WHERE d.database_id > 4 AND d.state_desc = 'ONLINE' GROUP BY d.name HAVING MAX(b.backup_finish_date) IS NULL OR MAX(b.backup_finish_date) < DATEADD(day, -7, GETDATE())
GO

/* ===== SEC-SQL-PRI-008-RC02 — Backups not encrypted ===== */
SELECT TOP 50 database_name, backup_finish_date, encryptor_type, has_backup_checksums FROM msdb.dbo.backupset WHERE backup_finish_date > DATEADD(day, -30, GETDATE()) AND encryptor_type IS NULL ORDER BY backup_finish_date DESC
GO

/* ===== SEC-SQL-PRI-008-RC03 — Backups stored on same volume as data files ===== */
SELECT TOP 20 b.database_name, mf.physical_device_name AS backup_path, df.physical_name AS data_path, 'same volume / same parent directory' AS finding FROM msdb.dbo.backupset b JOIN msdb.dbo.backupmediafamily mf ON mf.media_set_id = b.media_set_id JOIN sys.master_files df ON df.database_id = DB_ID(b.database_name) AND df.type_desc = 'ROWS' WHERE b.backup_finish_date > DATEADD(day, -30, GETDATE()) AND (LEFT(mf.physical_device_name, 3) = LEFT(df.physical_name, 3) OR SUBSTRING(mf.physical_device_name, 1, NULLIF(CHARINDEX('\', mf.physical_device_name, 4), 0)) = SUBSTRING(df.physical_name, 1, NULLIF(CHARINDEX('\', df.physical_name, 4), 0))) ORDER BY b.backup_finish_date DESC
GO

/* ===== SEC-SQL-PRI-009-RC01 — Records older than retention threshold in PII tables ===== */
SELECT s.name AS schema_name, t.name AS table_name, c.name AS date_column, ty.name AS data_type, p.rows AS row_count FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id JOIN sys.columns c ON c.object_id = t.object_id JOIN sys.types ty ON ty.user_type_id = c.user_type_id JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1) WHERE t.is_ms_shipped = 0 AND ty.name IN ('datetime','datetime2','date','datetimeoffset') AND (LOWER(c.name) LIKE '%created%' OR LOWER(c.name) LIKE '%inserted%' OR LOWER(c.name) LIKE '%entry_date%' OR LOWER(c.name) LIKE '%registered%') AND p.rows > 0 AND EXISTS (SELECT 1 FROM sys.columns c2 WHERE c2.object_id = t.object_id AND (LOWER(c2.name) LIKE '%email%' OR LOWER(c2.name) LIKE '%phone%' OR LOWER(c2.name) LIKE '%ssn%' OR LOWER(c2.name) LIKE '%passport%' OR LOWER(c2.name) LIKE '%credit_card%' OR LOWER(c2.name) LIKE '%medical%' OR LOWER(c2.name) LIKE '%teudat%')) ORDER BY p.rows DESC
GO

/* ===== SEC-SQL-PRI-009-RC02 — Inactive subjects with persistent personal data ===== */
SELECT s.name AS schema_name, t.name AS table_name, c.name AS last_active_col, ty.name AS data_type, p.rows AS row_count FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id JOIN sys.columns c ON c.object_id = t.object_id JOIN sys.types ty ON ty.user_type_id = c.user_type_id JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1) WHERE t.is_ms_shipped = 0 AND ty.name IN ('datetime','datetime2','date','datetimeoffset') AND (LOWER(c.name) LIKE '%last_login%' OR LOWER(c.name) LIKE '%last_active%' OR LOWER(c.name) LIKE '%last_seen%' OR LOWER(c.name) LIKE '%last_used%') AND p.rows > 0 ORDER BY p.rows DESC
GO

/* ===== SEC-SQL-PRI-009-RC03 — Soft-deleted rows never purged ===== */
SELECT s.name AS schema_name, t.name AS table_name, c.name AS soft_delete_col FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id JOIN sys.columns c ON c.object_id = t.object_id WHERE t.is_ms_shipped = 0 AND (LOWER(c.name) IN ('is_deleted','isdeleted','deleted') OR LOWER(c.name) LIKE '%deleted_at%' OR LOWER(c.name) LIKE '%deletion_date%')
GO

/* ===== SEC-SQL-PRI-010-RC01 — Failed-login spike from a single source ===== */
SELECT 'Login-failure detection requires a server audit with FAILED_LOGIN_GROUP — none is configured' AS finding WHERE NOT EXISTS (SELECT 1 FROM sys.server_audit_specifications sas JOIN sys.server_audit_specification_details sasd ON sasd.server_specification_id = sas.server_specification_id WHERE sas.is_state_enabled = 1 AND sasd.audit_action_name = 'FAILED_LOGIN_GROUP') UNION ALL SELECT TOP 20 LEFT(server_principal_name, 100) + ' / ' + LEFT(client_ip, 50) + ' (>20 failures last hour)' AS finding FROM sys.fn_get_audit_file('*.sqlaudit', DEFAULT, DEFAULT) WHERE action_id = 'LGIF' AND event_time > DATEADD(hour, -1, GETUTCDATE()) GROUP BY server_principal_name, client_ip HAVING COUNT(*) > 20
GO

/* ===== SEC-SQL-PRI-010-RC02 — Privilege escalation event detected ===== */
SELECT TOP 50 sp.name AS principal, r.name AS role_name, srm.role_principal_id FROM sys.server_principals sp JOIN sys.server_role_members srm ON srm.member_principal_id = sp.principal_id JOIN sys.server_principals r ON r.principal_id = srm.role_principal_id WHERE r.name IN ('sysadmin','securityadmin') AND sp.create_date > DATEADD(day, -30, GETDATE())
GO

/* ===== SEC-SQL-PRI-010-RC03 — After-hours sensitive-data access ===== */
SELECT s.session_id, s.login_name, s.host_name, s.program_name, r.start_time FROM sys.dm_exec_sessions s JOIN sys.dm_exec_requests r ON r.session_id = s.session_id WHERE s.is_user_process = 1 AND (DATEPART(hour, r.start_time) < 6 OR DATEPART(hour, r.start_time) >= 22)
GO

/* ===== SEC-SQL-PRI-011-RC01 — Teudat Zehut (Israeli national ID) columns unencrypted ===== */
SELECT s.name AS schema_name, t.name AS table_name, c.name AS column_name FROM sys.columns c JOIN sys.tables t ON t.object_id = c.object_id JOIN sys.schemas s ON s.schema_id = t.schema_id WHERE t.is_ms_shipped = 0 AND c.encryption_type IS NULL AND (LOWER(c.name) LIKE '%teudat%zehut%' OR LOWER(c.name) LIKE '%teudatzehut%' OR LOWER(c.name) = 'tz' OR LOWER(c.name) LIKE '%t_z%' OR LOWER(c.name) = 'national_id' OR LOWER(c.name) = 'israeli_id' OR LOWER(c.name) = 'id_number')
GO

/* ===== SEC-SQL-PRI-011-RC02 — Medical / health-data columns without classification ===== */
SELECT s.name AS schema_name, t.name AS table_name, c.name AS column_name FROM sys.columns c JOIN sys.tables t ON t.object_id = c.object_id JOIN sys.schemas s ON s.schema_id = t.schema_id WHERE t.is_ms_shipped = 0 AND (LOWER(c.name) LIKE '%medical%' OR LOWER(c.name) LIKE '%diagnosis%' OR LOWER(c.name) LIKE '%treatment%' OR LOWER(c.name) LIKE '%prescription%' OR LOWER(c.name) LIKE '%health%' OR LOWER(c.name) LIKE '%illness%' OR LOWER(c.name) LIKE '%disease%' OR LOWER(c.name) LIKE '%hmo%' OR LOWER(c.name) LIKE '%kupat%')
GO

/* ===== SEC-SQL-PRI-011-RC03 — Religion / political-opinion / sexual-orientation columns exposed ===== */
SELECT s.name AS schema_name, t.name AS table_name, c.name AS column_name FROM sys.columns c JOIN sys.tables t ON t.object_id = c.object_id JOIN sys.schemas s ON s.schema_id = t.schema_id WHERE t.is_ms_shipped = 0 AND (LOWER(c.name) LIKE '%religion%' OR LOWER(c.name) = 'dat' OR LOWER(c.name) LIKE '%political%' OR LOWER(c.name) LIKE '%orientation%' OR LOWER(c.name) LIKE '%ethnic%' OR LOWER(c.name) LIKE '%nationality%')
GO

/* ===== SEC-SQL-QE-001-RC01 — Stored procedure slower than its historical average ===== */
SELECT @@SERVERNAME AS server, DB_NAME(r.database_id) AS database_name, OBJECT_SCHEMA_NAME(st.objectid, r.database_id) + '.' + OBJECT_NAME(st.objectid, r.database_id) AS procedure_name, s.login_name AS login_name, ps.total_elapsed_time / NULLIF(ps.execution_count, 0) / 1000.0 AS avg_duration_ms, r.total_elapsed_time / 1000.0 AS actual_duration_ms FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON s.session_id = r.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st JOIN sys.dm_exec_procedure_stats ps ON ps.object_id = st.objectid AND ps.database_id = r.database_id WHERE s.is_user_process = 1 AND st.objectid IS NOT NULL AND OBJECT_SCHEMA_NAME(st.objectid, r.database_id) <> 'sys' AND DB_NAME(r.database_id) NOT IN ('master','model','msdb','tempdb') AND (r.total_elapsed_time * 1000.0) > (ps.total_elapsed_time / NULLIF(ps.execution_count, 0)) ORDER BY actual_duration_ms DESC
GO