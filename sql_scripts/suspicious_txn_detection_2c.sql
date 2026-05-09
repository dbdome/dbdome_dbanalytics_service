-- Detection paths: SEC-SQL-AUD-013, 014
SET client_encoding = 'UTF8';
BEGIN;

CREATE OR REPLACE PROCEDURE rootcause.add_detection_path(
  rc_id TEXT, vslug TEXT, path_name TEXT, path_desc TEXT,
  step1_name TEXT, step1_sql TEXT, step1_exp TEXT,
  step2_name TEXT, step2_sql TEXT, step2_exp TEXT
) AS $$
DECLARE ls1 INT; ls2 INT; lp INT;
BEGIN
  INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
  VALUES (vslug,'query',step1_name, jsonb_build_object('sql',step1_sql), step1_exp::jsonb)
  RETURNING id INTO ls1;
  INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
  VALUES (vslug,'query',step2_name, jsonb_build_object('sql',step2_sql), step2_exp::jsonb)
  RETURNING id INTO ls2;
  INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
  VALUES (rc_id, vslug, path_name, path_desc, 'authored', true)
  RETURNING id INTO lp;
  INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
  VALUES (lp,ls1,1,'next','ruled_out'),(lp,ls2,2,'confirmed','ruled_out');
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- SEC-SQL-AUD-013-RC01  Security-relevant ALTER SYSTEM by non-admin
-- ============================================================
CALL rootcause.add_detection_path('SEC-SQL-AUD-013-RC01','postgresql',
  'Detect unauthorized ALTER SYSTEM security parameter change - PostgreSQL',
  'Finds non-superuser sessions issuing ALTER SYSTEM or SET commands that affect authentication, logging, or SSL parameters',
  'Scan active queries for ALTER SYSTEM by non-superuser',
  'SELECT pid, usename, query, client_addr, query_start
   FROM pg_stat_activity
   WHERE state = ''active''
     AND query ~* ''ALTER\s+SYSTEM\s+SET''
     AND usename NOT IN (SELECT rolname FROM pg_roles WHERE rolsuper)',
  '{"condition":"row_count > 0","description":"Non-superuser issuing ALTER SYSTEM SET  -- unauthorized security parameter change"}',
  'Check pg_settings for recently changed security-relevant parameters',
  'SELECT name, setting, source, sourcefile
   FROM pg_settings
   WHERE source NOT IN (''default'',''configuration file'',''client'')
     AND name IN (''ssl'',''ssl_cert_file'',''ssl_key_file'',''log_statement'',
                  ''password_encryption'',''hba_file'',''ident_file'')',
  '{"condition":"row_count > 0","description":"Security-relevant parameters changed from non-file source  -- runtime modification detected"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-013-RC01','sqlserver',
  'Detect unauthorized sp_configure security change - SQL Server',
  'Identifies non-sysadmin sessions executing sp_configure to change security-relevant server options',
  'Check active requests for sp_configure by non-sysadmin',
  'SELECT s.login_name, s.is_sysadmin, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE s.is_sysadmin = 0
     AND t.text LIKE ''%sp_configure%''',
  '{"condition":"row_count > 0","description":"Non-sysadmin login executing sp_configure  -- unauthorized server configuration change"}',
  'Check current security-relevant configuration values',
  'SELECT name, value_in_use, value, description
   FROM sys.configurations
   WHERE name IN (''xp_cmdshell'',''Ole Automation Procedures'',
                  ''remote access'',''clr enabled'',''clr strict security'',
                  ''cross db ownership chaining'',''ad hoc distributed queries'')',
  '{"condition":"row_count > 0","description":"Review security-critical configuration values  -- verify none have been unexpectedly enabled"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-013-RC01','mysql',
  'Detect unauthorized SET GLOBAL security parameter change - MySQL',
  'Identifies non-DBA accounts executing SET GLOBAL on security-relevant variables',
  'Check active queries for SET GLOBAL by non-admin',
  'SELECT ID, USER, HOST, DB, TIME, INFO
   FROM INFORMATION_SCHEMA.PROCESSLIST
   WHERE COMMAND = ''Query''
     AND INFO REGEXP ''SET[[:space:]]+GLOBAL[[:space:]]''
     AND USER NOT IN (SELECT user FROM mysql.user WHERE Super_priv = ''Y'')',
  '{"condition":"row_count > 0","description":"Non-admin account executing SET GLOBAL  -- unauthorized security parameter change"}',
  'Check current values of security-relevant global variables',
  'SELECT VARIABLE_NAME, VARIABLE_VALUE
   FROM performance_schema.global_variables
   WHERE VARIABLE_NAME IN (''local_infile'',''secure_file_priv'',''skip_networking'',
                           ''require_secure_transport'',''ssl_ca'',''general_log'',
                           ''audit_log_policy'')',
  '{"condition":"row_count > 0","description":"Review security-critical variable values  -- verify none have been unexpectedly changed"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-013-RC01','oracle',
  'Detect unauthorized ALTER SYSTEM security parameter change - Oracle',
  'Finds non-DBA sessions issuing ALTER SYSTEM to change security-relevant initialization parameters',
  'Scan V$SQL for ALTER SYSTEM by non-DBA account',
  'SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE UPPER(q.sql_text) LIKE ''%ALTER SYSTEM SET%''
     AND s.username NOT IN (SELECT grantee FROM dba_sys_privs WHERE privilege = ''ALTER SYSTEM'')
     AND q.last_active_time > SYSDATE - 1/24',
  '{"condition":"row_count > 0","description":"Non-privileged account issued ALTER SYSTEM SET in last hour  -- unauthorized security change"}',
  'Check current values of security-relevant init parameters',
  'SELECT name, value, description
   FROM v$parameter
   WHERE name IN (''audit_trail'',''os_authent_prefix'',''remote_os_authent'',
                  ''utl_file_dir'',''o7_dictionary_accessibility'',
                  ''remote_login_passwordfile'',''sec_case_sensitive_logon'')',
  '{"condition":"row_count > 0","description":"Review security-critical parameter values  -- verify none changed from approved baseline"}'
);

-- ============================================================
-- SEC-SQL-AUD-013-RC02  Dangerous feature enabled during session
-- ============================================================
CALL rootcause.add_detection_path('SEC-SQL-AUD-013-RC02','postgresql',
  'Detect dangerous extension or feature enabled mid-session - PostgreSQL',
  'Identifies LOAD or CREATE EXTENSION commands in active sessions that enable OS-level or untrusted capabilities',
  'Scan active queries for LOAD or CREATE EXTENSION commands',
  'SELECT pid, usename, query, client_addr, query_start
   FROM pg_stat_activity
   WHERE state = ''active''
     AND (query ~* ''\bLOAD\b'' OR query ~* ''CREATE\s+EXTENSION'')',
  '{"condition":"row_count > 0","description":"Active LOAD or CREATE EXTENSION command  -- potential dangerous feature being enabled"}',
  'Check installed extensions for recently added entries',
  'SELECT extname, extversion, extrelocatable, extowner::regrole AS owner
   FROM pg_extension
   WHERE extname NOT IN (''plpgsql'',''pg_stat_statements'',''pgaudit'',''pg_trgm'',
                         ''btree_gin'',''btree_gist'',''uuid-ossp'',''pg_buffercache'')',
  '{"condition":"row_count > 0","description":"Non-standard extensions installed  -- verify each is approved and required"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-013-RC02','sqlserver',
  'Detect xp_cmdshell or dangerous feature enabled mid-session - SQL Server',
  'Finds sp_configure commands enabling xp_cmdshell, OLE Automation, or CLR in active sessions',
  'Check active requests for dangerous feature enable commands',
  'SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE (t.text LIKE ''%xp_cmdshell%'' OR t.text LIKE ''%Ole Automation%''
          OR t.text LIKE ''%clr enabled%'' OR t.text LIKE ''%ad hoc distributed queries%'')
     AND t.text LIKE ''%sp_configure%''',
  '{"condition":"row_count > 0","description":"Active sp_configure enabling dangerous SQL Server feature  -- OS-level access risk"}',
  'Verify dangerous features are currently disabled',
  'SELECT name, value_in_use
   FROM sys.configurations
   WHERE name IN (''xp_cmdshell'',''Ole Automation Procedures'',
                  ''clr enabled'',''ad hoc distributed queries'',
                  ''Database Mail XPs'',''SMO and DMO XPs'')
     AND value_in_use = 1',
  '{"condition":"row_count > 0","description":"One or more dangerous SQL Server features are currently enabled  -- remediation required"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-013-RC02','mysql',
  'Detect dangerous feature enabled mid-session - MySQL',
  'Finds SET GLOBAL local_infile=ON or installation of unapproved plugins in active sessions',
  'Check active queries for dangerous feature enable commands',
  'SELECT ID, USER, HOST, DB, TIME, INFO
   FROM INFORMATION_SCHEMA.PROCESSLIST
   WHERE COMMAND = ''Query''
     AND (INFO REGEXP ''local_infile[[:space:]]*=[[:space:]]*1''
          OR INFO REGEXP ''local_infile[[:space:]]*=[[:space:]]*ON''
          OR INFO REGEXP ''INSTALL[[:space:]]+PLUGIN'')',
  '{"condition":"row_count > 0","description":"Active command enabling local_infile or installing a plugin  -- dangerous feature activation"}',
  'Check current dangerous variable states and installed plugins',
  'SELECT VARIABLE_NAME, VARIABLE_VALUE
   FROM performance_schema.global_variables
   WHERE VARIABLE_NAME = ''local_infile'' AND VARIABLE_VALUE = ''ON''
   UNION ALL
   SELECT PLUGIN_NAME, PLUGIN_STATUS
   FROM INFORMATION_SCHEMA.PLUGINS
   WHERE PLUGIN_STATUS = ''ACTIVE''
     AND PLUGIN_NAME NOT IN (''binlog'',''InnoDB'',''MyISAM'',''CSV'',
                             ''PERFORMANCE_SCHEMA'',''MEMORY'',''sha256_password'',
                             ''caching_sha2_password'',''mysql_native_password'',
                             ''validate_password'',''audit_log'')',
  '{"condition":"row_count > 0","description":"local_infile is ON or non-standard active plugin detected  -- review for dangerous capability"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-013-RC02','oracle',
  'Detect dangerous package access enabled mid-session - Oracle',
  'Identifies GRANT of UTL_FILE, DBMS_SCHEDULER, or OS-execution packages in active sessions',
  'Scan V$SQL for GRANT on dangerous Oracle packages',
  'SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE UPPER(q.sql_text) LIKE ''%GRANT%EXECUTE%''
     AND (UPPER(q.sql_text) LIKE ''%UTL_FILE%'' OR UPPER(q.sql_text) LIKE ''%UTL_HTTP%''
          OR UPPER(q.sql_text) LIKE ''%DBMS_SCHEDULER%'' OR UPPER(q.sql_text) LIKE ''%DBMS_ADVISOR%''
          OR UPPER(q.sql_text) LIKE ''%DBMS_JAVA%'')
     AND q.last_active_time > SYSDATE - 1/24',
  '{"condition":"row_count > 0","description":"GRANT EXECUTE on dangerous Oracle package detected in V$SQL  -- OS-level access risk"}',
  'Check current EXECUTE grants on dangerous packages',
  'SELECT grantee, table_name, privilege, grantable
   FROM dba_tab_privs
   WHERE table_name IN (''UTL_FILE'',''UTL_HTTP'',''UTL_SMTP'',''UTL_TCP'',
                        ''DBMS_SCHEDULER'',''DBMS_ADVISOR'',''DBMS_JAVA'',
                        ''DBMS_XMLQUERY'')
     AND privilege = ''EXECUTE''
     AND grantee NOT IN (''SYS'',''SYSTEM'',''DBA'')',
  '{"condition":"row_count > 0","description":"Non-DBA accounts hold EXECUTE on dangerous packages  -- verify each grant is authorized"}'
);

-- ============================================================
-- SEC-SQL-AUD-013-RC03  Trigger disabled/dropped on monitored table
-- ============================================================
CALL rootcause.add_detection_path('SEC-SQL-AUD-013-RC03','postgresql',
  'Detect audit trigger disable or drop - PostgreSQL',
  'Identifies ALTER TABLE DISABLE TRIGGER or DROP TRIGGER commands on application tables in active sessions',
  'Scan active queries for trigger disable or drop on application tables',
  'SELECT pid, usename, query, client_addr, query_start
   FROM pg_stat_activity
   WHERE state = ''active''
     AND (query ~* ''ALTER\s+TABLE\s+.+DISABLE\s+TRIGGER'' OR query ~* ''DROP\s+TRIGGER'')',
  '{"condition":"row_count > 0","description":"Active trigger disable or drop command on application table  -- audit bypass pattern"}',
  'Check pg_trigger for disabled triggers on application tables',
  'SELECT tgname, tgrelid::regclass AS table_name, tgenabled, tgtype
   FROM pg_trigger
   WHERE tgenabled = ''D''
     AND tgrelid NOT IN (SELECT oid FROM pg_class WHERE relnamespace = ''pg_catalog''::regnamespace)',
  '{"condition":"row_count > 0","description":"Disabled triggers found on application tables  -- verify disable was authorized"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-013-RC03','sqlserver',
  'Detect audit trigger disable or drop - SQL Server',
  'Finds DISABLE TRIGGER or DROP TRIGGER DDL commands in active sessions',
  'Check active requests for trigger disable or drop',
  'SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE ''%DISABLE%TRIGGER%'' OR t.text LIKE ''%DROP%TRIGGER%''',
  '{"condition":"row_count > 0","description":"Active DISABLE TRIGGER or DROP TRIGGER command  -- potential audit bypass"}',
  'Enumerate currently disabled triggers',
  'SELECT t.name AS trigger_name, OBJECT_NAME(t.parent_id) AS table_name,
          t.is_disabled, t.type_desc, t.modify_date
   FROM sys.triggers t
   WHERE t.is_disabled = 1
     AND t.parent_class = 1
   ORDER BY t.modify_date DESC',
  '{"condition":"row_count > 0","description":"Currently disabled DML triggers found  -- verify authorization and check for subsequent unaudited DML"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-013-RC03','mysql',
  'Detect audit trigger drop - MySQL',
  'Identifies DROP TRIGGER commands in active sessions targeting application tables',
  'Check active queries for DROP TRIGGER on application tables',
  'SELECT ID, USER, HOST, DB, TIME, INFO
   FROM INFORMATION_SCHEMA.PROCESSLIST
   WHERE COMMAND = ''Query''
     AND INFO REGEXP ''DROP[[:space:]]+TRIGGER[[:space:]]''
     AND DB NOT IN (''information_schema'',''performance_schema'',''mysql'',''sys'')',
  '{"condition":"row_count > 0","description":"Active DROP TRIGGER on application database  -- potential audit bypass pattern"}',
  'Audit current trigger coverage on application tables',
  'SELECT TRIGGER_SCHEMA, TRIGGER_NAME, EVENT_OBJECT_TABLE,
          ACTION_TIMING, EVENT_MANIPULATION, CREATED
   FROM INFORMATION_SCHEMA.TRIGGERS
   WHERE TRIGGER_SCHEMA NOT IN (''information_schema'',''performance_schema'',''mysql'',''sys'')
   ORDER BY CREATED DESC',
  '{"condition":"row_count >= 0","description":"Current trigger inventory  -- verify expected audit triggers are present on all monitored tables"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-013-RC03','oracle',
  'Detect audit trigger disable or drop - Oracle',
  'Finds ALTER TRIGGER DISABLE or DROP TRIGGER commands in V$SQL for application schemas',
  'Scan V$SQL for trigger disable or drop in application schemas',
  'SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE (UPPER(q.sql_text) LIKE ''%ALTER%TRIGGER%DISABLE%'' OR UPPER(q.sql_text) LIKE ''%DROP%TRIGGER%'')
     AND s.username NOT IN (''SYS'',''SYSTEM'')
     AND q.last_active_time > SYSDATE - 1/24',
  '{"condition":"row_count > 0","description":"ALTER TRIGGER DISABLE or DROP TRIGGER by non-SYS account in last hour  -- audit bypass risk"}',
  'Check dba_triggers for disabled triggers on application tables',
  'SELECT owner, trigger_name, table_name, status, trigger_type, last_change
   FROM dba_triggers
   WHERE status = ''DISABLED''
     AND owner NOT IN (''SYS'',''SYSTEM'',''AUDSYS'')
   ORDER BY last_change DESC',
  '{"condition":"row_count > 0","description":"Disabled triggers on application-owned tables  -- verify authorization and check for unaudited DML"}'
);

-- ============================================================
-- SEC-SQL-AUD-013-RC04  Audit / logging parameters changed mid-session
-- ============================================================
CALL rootcause.add_detection_path('SEC-SQL-AUD-013-RC04','postgresql',
  'Detect audit verbosity reduction mid-session - PostgreSQL',
  'Identifies SET commands that reduce log_statement verbosity or disable connection logging',
  'Scan active queries for audit verbosity reduction commands',
  'SELECT pid, usename, query, client_addr, query_start
   FROM pg_stat_activity
   WHERE state = ''active''
     AND (query ~* ''SET\s+log_statement\s*=\s*''
          OR query ~* ''SET\s+log_min_duration_statement\s*=\s*-1''
          OR query ~* ''SET\s+log_connections\s*=\s*off'')',
  '{"condition":"row_count > 0","description":"Active command reducing audit log verbosity  -- potential blind spot creation"}',
  'Check effective log settings for the current session',
  'SELECT name, setting, source
   FROM pg_settings
   WHERE name IN (''log_statement'',''log_min_duration_statement'',
                  ''log_connections'',''log_disconnections'',''log_error_verbosity'')
   ORDER BY name',
  '{"condition":"row_count > 0","description":"Review current log settings  -- verify log_statement is not none and log_connections is on"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-013-RC04','sqlserver',
  'Detect audit specification altered mid-session - SQL Server',
  'Finds ALTER SERVER AUDIT or ALTER DATABASE AUDIT SPECIFICATION commands in active sessions',
  'Check active requests for audit specification modification',
  'SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE ''%ALTER%SERVER%AUDIT%'' OR t.text LIKE ''%ALTER%AUDIT%SPECIFICATION%''',
  '{"condition":"row_count > 0","description":"Active ALTER AUDIT command  -- potential audit coverage modification"}',
  'Check audit specification states for recent changes',
  'SELECT name, is_state_enabled, type_desc, modify_date
   FROM sys.server_audit_specifications
   UNION ALL
   SELECT name, is_state_enabled, type_desc, modify_date
   FROM sys.database_audit_specifications
   ORDER BY modify_date DESC',
  '{"condition":"row_count > 0","description":"Review audit specification enabled states  -- verify all required specifications are active"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-013-RC04','mysql',
  'Detect audit log policy changed mid-session - MySQL',
  'Identifies SET GLOBAL commands targeting audit_log_policy or general_log in active sessions',
  'Check active queries for audit log variable changes',
  'SELECT ID, USER, HOST, DB, TIME, INFO
   FROM INFORMATION_SCHEMA.PROCESSLIST
   WHERE COMMAND = ''Query''
     AND (INFO REGEXP ''SET[[:space:]]+GLOBAL[[:space:]]+(audit_log_policy|general_log|slow_query_log)'')',
  '{"condition":"row_count > 0","description":"Active command modifying audit log policy or general_log state  -- blind spot risk"}',
  'Verify current audit log policy is set to maximum coverage',
  'SELECT VARIABLE_NAME, VARIABLE_VALUE
   FROM performance_schema.global_variables
   WHERE VARIABLE_NAME IN (''audit_log_policy'',''general_log'',''slow_query_log'',
                           ''log_output'',''audit_log_format'')',
  '{"condition":"row_count > 0","description":"Review audit logging variable state  -- verify audit_log_policy=ALL and general_log=ON"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-013-RC04','oracle',
  'Detect audit policy disabled mid-session - Oracle',
  'Finds NOAUDIT commands or ALTER AUDIT POLICY DISABLE in V$SQL within the last hour',
  'Scan V$SQL for audit policy disabling commands',
  'SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE (UPPER(q.sql_text) LIKE ''%NOAUDIT%'' OR UPPER(q.sql_text) LIKE ''%ALTER AUDIT POLICY%DISABLE%''
          OR UPPER(q.sql_text) LIKE ''%ALTER SYSTEM SET AUDIT_TRAIL%NONE%'')
     AND q.last_active_time > SYSDATE - 1/24',
  '{"condition":"row_count > 0","description":"Audit policy disabling command detected in V$SQL within last hour"}',
  'Verify all required unified audit policies are enabled',
  'SELECT policy_name, enabled_option, entity_name, entity_type, success, failure
   FROM audit_unified_enabled_policies
   ORDER BY policy_name',
  '{"condition":"row_count > 0","description":"Review enabled audit policies  -- verify all security-required policies are active"}'
);

-- ============================================================
-- SEC-SQL-AUD-013-RC05  Network / auth config modified at runtime
-- ============================================================
CALL rootcause.add_detection_path('SEC-SQL-AUD-013-RC05','postgresql',
  'Detect runtime authentication config change - PostgreSQL',
  'Identifies ALTER SYSTEM commands modifying authentication or SSL parameters outside maintenance windows',
  'Scan active queries for auth or SSL parameter modification',
  'SELECT pid, usename, query, client_addr, query_start
   FROM pg_stat_activity
   WHERE state = ''active''
     AND query ~* ''ALTER\s+SYSTEM\s+SET''
     AND (query ILIKE ''%ssl%'' OR query ILIKE ''%hba_file%'' OR query ILIKE ''%password_encryption%''
          OR query ILIKE ''%pg_ident_conf_file%'')',
  '{"condition":"row_count > 0","description":"Active ALTER SYSTEM modifying authentication or SSL parameters  -- unauthorized config change"}',
  'Check current authentication and SSL parameter values',
  'SELECT name, setting, source, pending_restart
   FROM pg_settings
   WHERE name IN (''ssl'',''ssl_cert_file'',''ssl_key_file'',''ssl_ca_file'',
                  ''password_encryption'',''krb_server_keyfile'')
   ORDER BY name',
  '{"condition":"row_count > 0","description":"Review SSL and authentication parameter values  -- verify against approved baseline"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-013-RC05','sqlserver',
  'Detect linked server or remote server creation mid-session - SQL Server',
  'Finds sp_addlinkedserver or sp_addremotelogin commands in active sessions',
  'Check active requests for linked or remote server creation',
  'SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE ''%sp_addlinkedserver%'' OR t.text LIKE ''%sp_addremotelogin%''
      OR t.text LIKE ''%sp_setnetname%''',
  '{"condition":"row_count > 0","description":"Active linked or remote server creation command  -- unauthorized network pathway being added"}',
  'List all linked servers and compare to approved baseline',
  'SELECT name, data_source, provider, catalog, connect_timeout, modify_date
   FROM sys.servers
   WHERE is_linked = 1
   ORDER BY modify_date DESC',
  '{"condition":"row_count > 0","description":"Linked servers present  -- verify each is in the approved inventory and was not recently added"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-013-RC05','mysql',
  'Detect runtime authentication plugin change - MySQL',
  'Identifies ALTER USER commands changing authentication plugins or SET GLOBAL bind_address changes',
  'Check active queries for auth plugin changes',
  'SELECT ID, USER, HOST, DB, TIME, INFO
   FROM INFORMATION_SCHEMA.PROCESSLIST
   WHERE COMMAND = ''Query''
     AND (INFO REGEXP ''ALTER[[:space:]]+USER.+IDENTIFIED[[:space:]]+WITH''
          OR INFO REGEXP ''SET[[:space:]]+GLOBAL[[:space:]]+bind_address''
          OR INFO REGEXP ''SET[[:space:]]+GLOBAL[[:space:]]+skip_networking'')',
  '{"condition":"row_count > 0","description":"Active runtime authentication plugin change or network config modification  -- unauthorized access path"}',
  'Check for recent authentication plugin changes',
  'SELECT user, host, plugin, password_changed_time
   FROM mysql.user
   WHERE password_changed_time > NOW() - INTERVAL 1 HOUR
   ORDER BY password_changed_time DESC',
  '{"condition":"row_count > 0","description":"User authentication plugins changed within last hour  -- verify each change was authorized"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-013-RC05','oracle',
  'Detect runtime authentication or network parameter change - Oracle',
  'Finds ALTER SYSTEM commands modifying authentication parameters or database link creation in V$SQL',
  'Scan V$SQL for authentication or network parameter changes',
  'SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE (UPPER(q.sql_text) LIKE ''%ALTER SYSTEM SET REMOTE_LOGIN_PASSWORDFILE%''
          OR UPPER(q.sql_text) LIKE ''%ALTER SYSTEM SET OS_AUTHENT_PREFIX%''
          OR UPPER(q.sql_text) LIKE ''%CREATE DATABASE LINK%''
          OR UPPER(q.sql_text) LIKE ''%ALTER SYSTEM SET REMOTE_OS_AUTHENT%'')
     AND q.last_active_time > SYSDATE - 1/24',
  '{"condition":"row_count > 0","description":"Authentication or network configuration change detected in V$SQL within last hour"}',
  'Review recently created database links',
  'SELECT owner, db_link, username, host, created
   FROM dba_db_links
   WHERE created > SYSDATE - 1/24
   ORDER BY created DESC',
  '{"condition":"row_count > 0","description":"Database links created within last hour  -- verify each is authorized and required"}'
);

-- ============================================================
-- SEC-SQL-AUD-014-RC01  New user/login created during session
-- ============================================================
CALL rootcause.add_detection_path('SEC-SQL-AUD-014-RC01','postgresql',
  'Detect new role/user creation during application session - PostgreSQL',
  'Finds CREATE ROLE or CREATE USER commands issued in active application sessions',
  'Scan active queries for CREATE ROLE or CREATE USER commands',
  'SELECT pid, usename, query, client_addr, query_start
   FROM pg_stat_activity
   WHERE state = ''active''
     AND (query ~* ''\bCREATE\s+ROLE\b'' OR query ~* ''\bCREATE\s+USER\b'')',
  '{"condition":"row_count > 0","description":"Active CREATE ROLE or CREATE USER command  -- potential backdoor account creation"}',
  'Check for recently created roles in pg_roles',
  'SELECT rolname, rolcanlogin, rolcreatedb, rolcreaterole, rolsuper, oid
   FROM pg_roles
   WHERE oid > (SELECT max(oid) - 10 FROM pg_roles)
   ORDER BY oid DESC',
  '{"condition":"row_count > 0","description":"Recently created roles detected  -- verify each was created through an authorized process"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-014-RC01','sqlserver',
  'Detect new login/user creation during application session - SQL Server',
  'Finds CREATE LOGIN or CREATE USER commands in active application sessions',
  'Check active requests for CREATE LOGIN or CREATE USER',
  'SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE ''%CREATE%LOGIN%'' OR t.text LIKE ''%CREATE%USER%''',
  '{"condition":"row_count > 0","description":"Active CREATE LOGIN or CREATE USER command  -- potential backdoor account creation"}',
  'Check for recently created server principals',
  'SELECT name, type_desc, create_date, is_disabled
   FROM sys.server_principals
   WHERE type IN (''S'',''U'',''G'')
     AND create_date > DATEADD(hour,-1,GETDATE())
   ORDER BY create_date DESC',
  '{"condition":"row_count > 0","description":"Logins created in last hour  -- verify each was created through an authorized change process"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-014-RC01','mysql',
  'Detect new user creation during application session - MySQL',
  'Finds CREATE USER or GRANT statements creating new accounts in active application threads',
  'Check active queries for CREATE USER or GRANT commands',
  'SELECT ID, USER, HOST, DB, TIME, INFO
   FROM INFORMATION_SCHEMA.PROCESSLIST
   WHERE COMMAND = ''Query''
     AND (INFO REGEXP ''CREATE[[:space:]]+USER'' OR INFO REGEXP ''GRANT.+TO[[:space:]]+'')',
  '{"condition":"row_count > 0","description":"Active CREATE USER or account-creating GRANT command  -- potential backdoor account"}',
  'Check for recently created MySQL user accounts',
  'SELECT user, host, plugin, password_changed_time, account_locked
   FROM mysql.user
   WHERE password_changed_time > NOW() - INTERVAL 1 HOUR
   ORDER BY password_changed_time DESC',
  '{"condition":"row_count > 0","description":"MySQL accounts created or modified within last hour  -- verify each is authorized"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-014-RC01','oracle',
  'Detect new user creation during application session - Oracle',
  'Finds CREATE USER commands issued in active or recent Oracle sessions',
  'Scan V$SQL for CREATE USER commands',
  'SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE UPPER(q.sql_text) LIKE ''%CREATE USER%''
     AND q.last_active_time > SYSDATE - 1/24',
  '{"condition":"row_count > 0","description":"CREATE USER command found in V$SQL within last hour  -- potential backdoor account creation"}',
  'Check for recently created Oracle accounts',
  'SELECT username, account_status, created, profile
   FROM dba_users
   WHERE created > SYSDATE - 1/24
   ORDER BY created DESC',
  '{"condition":"row_count > 0","description":"Oracle accounts created in last hour  -- verify each was created through an authorized process"}'
);

-- ============================================================
-- SEC-SQL-AUD-014-RC02  Account added to privileged role mid-session
-- ============================================================
CALL rootcause.add_detection_path('SEC-SQL-AUD-014-RC02','postgresql',
  'Detect unauthorized role grant mid-session - PostgreSQL',
  'Identifies GRANT commands assigning superuser or privileged roles in active sessions',
  'Scan active queries for GRANT of privileged roles',
  'SELECT pid, usename, query, client_addr, query_start
   FROM pg_stat_activity
   WHERE state = ''active''
     AND query ~* ''\bGRANT\b''
     AND (query ~* ''SUPERUSER'' OR query ~* ''CREATEROLE'' OR query ~* ''CREATEDB'')',
  '{"condition":"row_count > 0","description":"Active GRANT assigning superuser or high-privilege attribute  -- unauthorized escalation pattern"}',
  'Check recent role membership changes in pg_auth_members',
  'SELECT r.rolname AS role_granted, m.rolname AS granted_to, a.rolname AS granted_by
   FROM pg_auth_members am
   JOIN pg_roles r ON r.oid = am.roleid
   JOIN pg_roles m ON m.oid = am.member
   JOIN pg_roles a ON a.oid = am.grantor
   WHERE r.rolsuper OR r.rolcreaterole OR r.rolcreatedb',
  '{"condition":"row_count > 0","description":"Accounts are members of privileged roles  -- verify each membership is in the approved role grant baseline"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-014-RC02','sqlserver',
  'Detect account added to sysadmin role mid-session - SQL Server',
  'Finds ALTER SERVER ROLE ADD MEMBER commands for sysadmin or securityadmin in active sessions',
  'Check active requests for privileged role membership changes',
  'SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE ''%ALTER%SERVER%ROLE%ADD%MEMBER%''
      OR t.text LIKE ''%sp_addsrvrolemember%''',
  '{"condition":"row_count > 0","description":"Active server role membership change command  -- potential unauthorized privilege escalation"}',
  'Enumerate current sysadmin and securityadmin members',
  'SELECT r.name AS role_name, m.name AS member_login, m.type_desc, m.create_date
   FROM sys.server_role_members rm
   JOIN sys.server_principals r ON r.principal_id = rm.role_principal_id
   JOIN sys.server_principals m ON m.principal_id = rm.member_principal_id
   WHERE r.name IN (''sysadmin'',''securityadmin'',''serveradmin'')',
  '{"condition":"row_count > 0","description":"Current members of privileged server roles  -- verify against approved membership baseline"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-014-RC02','mysql',
  'Detect high-privilege GRANT mid-session - MySQL',
  'Identifies GRANT ALL or GRANT SUPER commands in active application threads',
  'Check active queries for high-privilege GRANT commands',
  'SELECT ID, USER, HOST, DB, TIME, INFO
   FROM INFORMATION_SCHEMA.PROCESSLIST
   WHERE COMMAND = ''Query''
     AND (INFO REGEXP ''GRANT[[:space:]]+ALL''
          OR INFO REGEXP ''GRANT[[:space:]]+SUPER''
          OR INFO REGEXP ''GRANT[[:space:]]+SYSTEM_USER'')',
  '{"condition":"row_count > 0","description":"Active GRANT ALL, SUPER, or SYSTEM_USER privilege  -- potential unauthorized escalation"}',
  'Check current user privilege assignments for excess grants',
  'SELECT user, host, Super_priv, Grant_priv, Create_user_priv, System_user_priv
   FROM mysql.user
   WHERE Super_priv = ''Y'' OR Grant_priv = ''Y'' OR System_user_priv = ''Y''
   ORDER BY user',
  '{"condition":"row_count > 0","description":"Accounts with SUPER or GRANT privilege  -- verify each is in the approved privilege baseline"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-014-RC02','oracle',
  'Detect DBA role grant mid-session - Oracle',
  'Finds GRANT DBA or GRANT SYSDBA commands issued in recent Oracle sessions',
  'Scan V$SQL for privileged role grant commands',
  'SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE UPPER(q.sql_text) LIKE ''%GRANT%DBA%''
      OR UPPER(q.sql_text) LIKE ''%GRANT%SYSDBA%''
      OR UPPER(q.sql_text) LIKE ''%GRANT%SYSOPER%''
     AND q.last_active_time > SYSDATE - 1/24',
  '{"condition":"row_count > 0","description":"GRANT DBA or SYSDBA command in V$SQL within last hour  -- unauthorized privilege escalation"}',
  'Check current DBA and SYSDBA role grantees',
  'SELECT grantee, granted_role, admin_option, default_role
   FROM dba_role_privs
   WHERE granted_role IN (''DBA'',''SYSDBA'',''SYSOPER'',''IMP_FULL_DATABASE'',''EXP_FULL_DATABASE'')
   ORDER BY granted_role, grantee',
  '{"condition":"row_count > 0","description":"Current DBA/SYSDBA role grantees  -- verify against approved role grant baseline"}'
);

-- ============================================================
-- SEC-SQL-AUD-014-RC03  Password changed on another account mid-session
-- ============================================================
CALL rootcause.add_detection_path('SEC-SQL-AUD-014-RC03','postgresql',
  'Detect password change on another account mid-session - PostgreSQL',
  'Finds ALTER ROLE ... PASSWORD commands targeting accounts other than the current user',
  'Scan active queries for ALTER ROLE PASSWORD targeting other accounts',
  'SELECT pid, usename, query, client_addr, query_start
   FROM pg_stat_activity
   WHERE state = ''active''
     AND query ~* ''ALTER\s+ROLE\s+\S+\s+.*PASSWORD''
     AND query NOT ILIKE ''%'' || usename || ''%''',
  '{"condition":"row_count > 0","description":"Active ALTER ROLE PASSWORD command targeting a different account  -- potential credential hijacking"}',
  'Check pg_shadow for recently changed passwords',
  'SELECT usename, passwd, valuntil
   FROM pg_shadow
   ORDER BY usename',
  '{"condition":"row_count > 0","description":"Review pg_shadow  -- cross-reference with expected password rotation schedule to identify unauthorized changes"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-014-RC03','sqlserver',
  'Detect password change on another login mid-session - SQL Server',
  'Identifies ALTER LOGIN ... WITH PASSWORD commands in active sessions targeting other logins',
  'Check active requests for ALTER LOGIN password changes',
  'SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE ''%ALTER%LOGIN%PASSWORD%''',
  '{"condition":"row_count > 0","description":"Active ALTER LOGIN WITH PASSWORD command  -- potential credential hijacking or reactivation"}',
  'Check for recently modified SQL logins',
  'SELECT name, type_desc, is_disabled, modify_date, password_last_set_time
   FROM sys.sql_logins
   WHERE modify_date > DATEADD(hour,-1,GETDATE())
   ORDER BY modify_date DESC',
  '{"condition":"row_count > 0","description":"SQL logins modified in last hour  -- verify each change was authorized and follow password rotation policy"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-014-RC03','mysql',
  'Detect password change on another account mid-session - MySQL',
  'Finds ALTER USER ... IDENTIFIED BY commands targeting other accounts in active threads',
  'Check active queries for ALTER USER password changes',
  'SELECT ID, USER, HOST, DB, TIME, INFO
   FROM INFORMATION_SCHEMA.PROCESSLIST
   WHERE COMMAND = ''Query''
     AND INFO REGEXP ''ALTER[[:space:]]+USER.+IDENTIFIED[[:space:]]+BY''',
  '{"condition":"row_count > 0","description":"Active ALTER USER IDENTIFIED BY password change command  -- verify it targets the current user only"}',
  'Check for recently changed user passwords',
  'SELECT user, host, password_changed_time, plugin, account_locked
   FROM mysql.user
   WHERE password_changed_time > NOW() - INTERVAL 1 HOUR
   ORDER BY password_changed_time DESC',
  '{"condition":"row_count > 0","description":"User passwords changed within last hour  -- verify each change was authorized"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-014-RC03','oracle',
  'Detect password change on another account mid-session - Oracle',
  'Finds ALTER USER ... IDENTIFIED BY commands targeting other accounts in V$SQL',
  'Scan V$SQL for ALTER USER IDENTIFIED BY commands',
  'SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE UPPER(q.sql_text) LIKE ''%ALTER USER%IDENTIFIED BY%''
     AND q.last_active_time > SYSDATE - 1/24',
  '{"condition":"row_count > 0","description":"ALTER USER IDENTIFIED BY command in V$SQL within last hour  -- potential credential reset"}',
  'Check dba_users for recently modified accounts',
  'SELECT username, account_status, expiry_date, last_login, profile
   FROM dba_users
   WHERE expiry_date > SYSDATE
     AND last_login < SYSDATE - 90
   ORDER BY last_login DESC',
  '{"condition":"row_count > 0","description":"Dormant accounts with future expiry dates  -- may indicate password expiry removal to reactivate dormant credentials"}'
);

-- ============================================================
-- SEC-SQL-AUD-014-RC04  Database link / synonym to external system created
-- ============================================================
CALL rootcause.add_detection_path('SEC-SQL-AUD-014-RC04','postgresql',
  'Detect foreign data wrapper or server creation mid-session - PostgreSQL',
  'Finds CREATE SERVER, CREATE FOREIGN TABLE, or CREATE USER MAPPING commands in active sessions',
  'Scan active queries for foreign server or wrapper creation',
  'SELECT pid, usename, query, client_addr, query_start
   FROM pg_stat_activity
   WHERE state = ''active''
     AND (query ~* ''CREATE\s+SERVER'' OR query ~* ''CREATE\s+FOREIGN\s+TABLE''
          OR query ~* ''CREATE\s+USER\s+MAPPING'')',
  '{"condition":"row_count > 0","description":"Active foreign server or data wrapper creation  -- potential external data exfiltration pathway"}',
  'List all defined foreign servers and user mappings',
  'SELECT fs.srvname, fs.srvowner::regrole AS owner,
          um.umuser::regrole AS mapped_user, fs.srvoptions
   FROM pg_foreign_server fs
   LEFT JOIN pg_user_mapping um ON um.umserver = fs.oid',
  '{"condition":"row_count > 0","description":"Foreign servers present  -- verify each is in the approved data source inventory"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-014-RC04','sqlserver',
  'Detect linked server creation mid-session - SQL Server',
  'Finds sp_addlinkedserver or CREATE SYNONYM commands in active sessions',
  'Check active requests for linked server or synonym creation',
  'SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE ''%sp_addlinkedserver%'' OR t.text LIKE ''%CREATE%SYNONYM%''',
  '{"condition":"row_count > 0","description":"Active linked server or synonym creation  -- potential external data exfiltration pathway"}',
  'List all linked servers and their data sources',
  'SELECT name, data_source, provider, catalog, is_linked, modify_date
   FROM sys.servers
   WHERE is_linked = 1
   ORDER BY modify_date DESC',
  '{"condition":"row_count > 0","description":"Linked servers present  -- verify each is in the approved inventory and was not recently added without authorization"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-014-RC04','mysql',
  'Detect FEDERATED table or external link creation mid-session - MySQL',
  'Identifies CREATE TABLE with ENGINE=FEDERATED or FILE privilege usage in active threads',
  'Check active queries for FEDERATED engine table creation',
  'SELECT ID, USER, HOST, DB, TIME, INFO
   FROM INFORMATION_SCHEMA.PROCESSLIST
   WHERE COMMAND = ''Query''
     AND (INFO REGEXP ''ENGINE[[:space:]]*=[[:space:]]*FEDERATED''
          OR INFO REGEXP ''LOAD[[:space:]]+DATA[[:space:]]+INFILE'')',
  '{"condition":"row_count > 0","description":"Active FEDERATED table creation or LOAD DATA INFILE  -- potential external data pathway or file access"}',
  'Check for existing FEDERATED tables',
  'SELECT TABLE_SCHEMA, TABLE_NAME, ENGINE, CREATE_TIME, TABLE_COMMENT
   FROM INFORMATION_SCHEMA.TABLES
   WHERE ENGINE = ''FEDERATED''
   ORDER BY CREATE_TIME DESC',
  '{"condition":"row_count > 0","description":"FEDERATED tables present  -- verify each is authorized and points to an approved external data source"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-014-RC04','oracle',
  'Detect database link creation mid-session - Oracle',
  'Finds CREATE DATABASE LINK or CREATE SYNONYM commands in recent Oracle sessions',
  'Scan V$SQL for CREATE DATABASE LINK commands',
  'SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE (UPPER(q.sql_text) LIKE ''%CREATE%DATABASE LINK%'' OR UPPER(q.sql_text) LIKE ''%CREATE%PUBLIC DATABASE LINK%'')
     AND q.last_active_time > SYSDATE - 1/24',
  '{"condition":"row_count > 0","description":"CREATE DATABASE LINK in V$SQL within last hour  -- potential external exfiltration pathway"}',
  'List all current database links with creation times',
  'SELECT owner, db_link, username, host, created
   FROM dba_db_links
   ORDER BY created DESC',
  '{"condition":"row_count > 0","description":"Database links present  -- verify each is in the approved inventory and was not created without authorization"}'
);

-- ============================================================
-- SEC-SQL-AUD-014-RC05  Account unlocked or expiry removed on dormant account
-- ============================================================
CALL rootcause.add_detection_path('SEC-SQL-AUD-014-RC05','postgresql',
  'Detect dormant account reactivation mid-session - PostgreSQL',
  'Finds ALTER ROLE commands re-enabling LOGIN on previously NOLOGIN accounts in active sessions',
  'Scan active queries for ALTER ROLE LOGIN commands',
  'SELECT pid, usename, query, client_addr, query_start
   FROM pg_stat_activity
   WHERE state = ''active''
     AND query ~* ''ALTER\s+ROLE\s+\S+.*\bLOGIN\b''
     AND query NOT ILIKE ''%NOLOGIN%''',
  '{"condition":"row_count > 0","description":"Active ALTER ROLE enabling LOGIN attribute  -- potential dormant account reactivation"}',
  'Check for recently activated roles that had NOLOGIN status',
  'SELECT rolname, rolcanlogin, rolvaliduntil, oid
   FROM pg_roles
   WHERE rolcanlogin = true
   ORDER BY oid DESC
   LIMIT 20',
  '{"condition":"row_count > 0","description":"Recently modified LOGIN roles  -- cross-reference with approved account activation records"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-014-RC05','sqlserver',
  'Detect dormant login reactivation mid-session - SQL Server',
  'Identifies ALTER LOGIN ENABLE commands in active sessions for previously disabled logins',
  'Check active requests for ALTER LOGIN ENABLE commands',
  'SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE ''%ALTER%LOGIN%ENABLE%''',
  '{"condition":"row_count > 0","description":"Active ALTER LOGIN ENABLE command  -- potential dormant account reactivation"}',
  'Check for recently re-enabled SQL logins',
  'SELECT name, is_disabled, modify_date, create_date, type_desc
   FROM sys.server_principals
   WHERE type = ''S''
     AND is_disabled = 0
     AND modify_date > DATEADD(hour,-1,GETDATE())
   ORDER BY modify_date DESC',
  '{"condition":"row_count > 0","description":"SQL logins enabled within last hour  -- verify each re-activation was authorized"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-014-RC05','mysql',
  'Detect dormant account unlock mid-session - MySQL',
  'Finds ALTER USER ACCOUNT UNLOCK commands in active threads',
  'Check active queries for ALTER USER ACCOUNT UNLOCK',
  'SELECT ID, USER, HOST, DB, TIME, INFO
   FROM INFORMATION_SCHEMA.PROCESSLIST
   WHERE COMMAND = ''Query''
     AND INFO REGEXP ''ALTER[[:space:]]+USER.+ACCOUNT[[:space:]]+UNLOCK''',
  '{"condition":"row_count > 0","description":"Active ALTER USER ACCOUNT UNLOCK command  -- potential dormant account reactivation"}',
  'Check for recently unlocked accounts in mysql.user',
  'SELECT user, host, account_locked, password_changed_time, password_expired
   FROM mysql.user
   WHERE account_locked = ''N''
     AND password_changed_time > NOW() - INTERVAL 1 HOUR
   ORDER BY password_changed_time DESC',
  '{"condition":"row_count > 0","description":"Accounts unlocked within last hour  -- verify each was unlocked through an authorized process"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-014-RC05','oracle',
  'Detect dormant account unlock mid-session - Oracle',
  'Finds ALTER USER ACCOUNT UNLOCK or password expiry removal commands in V$SQL',
  'Scan V$SQL for account unlock or expiry removal commands',
  'SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE (UPPER(q.sql_text) LIKE ''%ALTER USER%ACCOUNT UNLOCK%''
          OR UPPER(q.sql_text) LIKE ''%ALTER USER%ENABLE%''
          OR UPPER(q.sql_text) LIKE ''%ALTER USER%PASSWORD EXPIRE%'')
     AND q.last_active_time > SYSDATE - 1/24',
  '{"condition":"row_count > 0","description":"ALTER USER ACCOUNT UNLOCK or expiry modification in V$SQL within last hour  -- dormant account reactivation risk"}',
  'Check dba_users for accounts recently unlocked or with expiry removed',
  'SELECT username, account_status, expiry_date, lock_date, last_login
   FROM dba_users
   WHERE account_status = ''OPEN''
     AND last_login < SYSDATE - 90
   ORDER BY last_login DESC
   FETCH FIRST 20 ROWS ONLY',
  '{"condition":"row_count > 0","description":"Open accounts that have not logged in for 90 days  -- potential recently unlocked dormant accounts"}'
);

DROP PROCEDURE IF EXISTS rootcause.add_detection_path(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT);

COMMIT;
