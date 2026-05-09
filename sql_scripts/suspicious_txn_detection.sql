-- ============================================================
-- Detection paths + steps for SEC-SQL-AUD-006/007/008
-- ============================================================

BEGIN;

-- -----------------------------------------------------------
-- HELPER: one function call pattern per root-cause per vendor
-- Layout: INSERT step1 -> INSERT step2 -> INSERT path -> link
-- -----------------------------------------------------------

CREATE OR REPLACE PROCEDURE add_path(
  rc_id TEXT, vslug TEXT,
  path_name TEXT, path_desc TEXT,
  step1_name TEXT, step1_sql TEXT, step1_exp TEXT,
  step2_name TEXT, step2_sql TEXT, step2_exp TEXT
) LANGUAGE plpgsql AS $$
DECLARE ls1 INT; ls2 INT; lp INT;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES (vslug, 'query', step1_name,
            jsonb_build_object('sql', step1_sql),
            step1_exp::jsonb)
    RETURNING id INTO ls1;

    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES (vslug, 'query', step2_name,
            jsonb_build_object('sql', step2_sql),
            step2_exp::jsonb)
    RETURNING id INTO ls2;

    INSERT INTO rootcause.detection_paths
      (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES (rc_id, vslug, path_name, path_desc, 'authored', true)
    RETURNING id INTO lp;

    INSERT INTO rootcause.detection_path_steps
      (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES
      (lp, ls1, 1, 'next',      'ruled_out'),
      (lp, ls2, 2, 'confirmed', 'ruled_out');
END;
$$;

DO $BODY$
BEGIN

-- ------------------------------------------------------------
-- RC01  -- Privileged account DML outside maintenance window
-- ------------------------------------------------------------

  -- PostgreSQL
  CALL add_path(
    'SEC-SQL-AUD-006-RC01','postgresql',
    'Detect privileged DML outside maintenance window - PostgreSQL',
    'Finds active DML statements running under superuser or pg_monitor-member roles',
    'Check active DML by privileged accounts',
    'SELECT pid, usename, application_name, client_addr, state, query, query_start
     FROM pg_stat_activity
     WHERE state = ''active''
       AND query ~* ''^\s*(INSERT|UPDATE|DELETE|TRUNCATE)''
       AND usename IN (
           SELECT rolname FROM pg_roles
           WHERE rolsuper = true OR rolcreaterole = true OR rolcreatedb = true
       )
     ORDER BY query_start',
    '{"condition":"row_count > 0","description":"Privileged account has an active DML statement"}',
    'Check hour-of-day for off-window indicator',
    'SELECT pid, usename, query, query_start,
            EXTRACT(HOUR FROM query_start AT TIME ZONE ''UTC'') AS utc_hour
     FROM pg_stat_activity
     WHERE state = ''active''
       AND query ~* ''^\s*(INSERT|UPDATE|DELETE|TRUNCATE)''
       AND usename IN (SELECT rolname FROM pg_roles WHERE rolsuper = true)
       AND EXTRACT(HOUR FROM query_start AT TIME ZONE ''UTC'') NOT BETWEEN 2 AND 5',
    '{"condition":"row_count > 0","description":"Privileged DML running outside the 02:00-05:00 UTC maintenance window"}'
  );

  -- SQL Server
  CALL add_path(
    'SEC-SQL-AUD-006-RC01','sqlserver',
    'Detect privileged DML outside maintenance window - SQL Server',
    'Identifies sysadmin or db_owner sessions executing DML via DMVs',
    'Check active DML sessions by privileged logins',
    'SELECT s.session_id, s.login_name, s.host_name, s.program_name,
            r.command, r.start_time, t.text AS sql_text
     FROM sys.dm_exec_sessions s
     JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
     CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
     WHERE s.is_user_process = 1
       AND r.command IN (''INSERT'',''UPDATE'',''DELETE'')
       AND (IS_SRVROLEMEMBER(''sysadmin'', s.login_name) = 1
            OR IS_MEMBER(''db_owner'') = 1)',
    '{"condition":"row_count > 0","description":"Sysadmin or db_owner account has active DML request"}',
    'Check whether DML falls outside maintenance window (02:00-05:00)',
    'SELECT s.login_name, r.command, r.start_time,
            DATEPART(HOUR, r.start_time) AS start_hour
     FROM sys.dm_exec_sessions s
     JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
     WHERE s.is_user_process = 1
       AND r.command IN (''INSERT'',''UPDATE'',''DELETE'')
       AND IS_SRVROLEMEMBER(''sysadmin'', s.login_name) = 1
       AND DATEPART(HOUR, r.start_time) NOT BETWEEN 2 AND 5',
    '{"condition":"row_count > 0","description":"Privileged DML running outside the 02:00-05:00 maintenance window"}'
  );

  -- MySQL
  CALL add_path(
    'SEC-SQL-AUD-006-RC01','mysql',
    'Detect privileged DML outside maintenance window - MySQL',
    'Identifies SUPER or DBA accounts with active DML in INFORMATION_SCHEMA.PROCESSLIST',
    'Check PROCESSLIST for privileged DML',
    'SELECT p.ID, p.USER, p.HOST, p.DB, p.COMMAND, p.TIME, p.INFO
     FROM INFORMATION_SCHEMA.PROCESSLIST p
     WHERE p.COMMAND = ''Query''
       AND p.INFO REGEXP ''^\s*(INSERT|UPDATE|DELETE|TRUNCATE)''
       AND p.USER IN (
           SELECT DISTINCT grantee
           FROM INFORMATION_SCHEMA.USER_PRIVILEGES
           WHERE PRIVILEGE_TYPE = ''SUPER'' OR PRIVILEGE_TYPE = ''ALL PRIVILEGES''
       )',
    '{"condition":"row_count > 0","description":"Privileged MySQL account has active DML statement"}',
    'Cross-check with hour of execution',
    'SELECT p.USER, p.INFO, HOUR(NOW()) AS current_hour
     FROM INFORMATION_SCHEMA.PROCESSLIST p
     WHERE p.COMMAND = ''Query''
       AND p.INFO REGEXP ''^\s*(INSERT|UPDATE|DELETE)''
       AND p.USER IN (SELECT DISTINCT grantee FROM INFORMATION_SCHEMA.USER_PRIVILEGES WHERE PRIVILEGE_TYPE = ''SUPER'')
       AND HOUR(NOW()) NOT BETWEEN 2 AND 5',
    '{"condition":"row_count > 0","description":"Privileged DML outside 02:00-05:00 maintenance window confirmed"}'
  );

  -- Oracle
  CALL add_path(
    'SEC-SQL-AUD-006-RC01','oracle',
    'Detect privileged DML outside maintenance window - Oracle',
    'Uses V$SESSION and V$SQL to find DBA-role sessions executing DML',
    'Check V$SESSION for DML by DBA-role accounts',
    'SELECT s.SID, s.SERIAL#, s.USERNAME, s.OSUSER, s.MACHINE,
            s.STATUS, q.SQL_TEXT, s.LOGON_TIME
     FROM V$SESSION s
     JOIN V$SQL q ON s.SQL_ID = q.SQL_ID
     WHERE s.STATUS = ''ACTIVE''
       AND q.COMMAND_TYPE IN (2,6,7,9)  -- INSERT,UPDATE,DELETE,SELECT FOR UPDATE
       AND s.USERNAME IN (
           SELECT GRANTEE FROM DBA_ROLE_PRIVS WHERE GRANTED_ROLE = ''DBA''
       )',
    '{"condition":"row_count > 0","description":"DBA-role account has active DML session"}',
    'Check whether session is outside maintenance window',
    'SELECT s.USERNAME, q.SQL_TEXT, TO_CHAR(SYSDATE,''HH24'') AS current_hour
     FROM V$SESSION s JOIN V$SQL q ON s.SQL_ID = q.SQL_ID
     WHERE s.STATUS = ''ACTIVE''
       AND q.COMMAND_TYPE IN (2,6,7,9)
       AND s.USERNAME IN (SELECT GRANTEE FROM DBA_ROLE_PRIVS WHERE GRANTED_ROLE = ''DBA'')
       AND TO_NUMBER(TO_CHAR(SYSDATE,''HH24'')) NOT BETWEEN 2 AND 5',
    '{"condition":"row_count > 0","description":"DBA DML outside 02:00-05:00 maintenance window"}'
  );

-- ------------------------------------------------------------
-- RC02  -- Superuser ad-hoc queries on sensitive tables
-- ------------------------------------------------------------

  CALL add_path(
    'SEC-SQL-AUD-006-RC02','postgresql',
    'Detect superuser ad-hoc queries on sensitive tables - PostgreSQL',
    'Identifies superuser SELECT statements targeting tables flagged as sensitive via comment or naming convention',
    'Scan active queries by superusers against likely-sensitive table names',
    'SELECT pid, usename, query, query_start, client_addr
     FROM pg_stat_activity
     WHERE usename IN (SELECT rolname FROM pg_roles WHERE rolsuper = true)
       AND state = ''active''
       AND query ~* ''(password|secret|credential|api_key|token|ssn|credit_card|pii|salary|key_store)''',
    '{"condition":"row_count > 0","description":"Superuser querying table or column names associated with sensitive data"}',
    'Verify table exists in sensitive object list',
    'SELECT c.relname, n.nspname, obj_description(c.oid) AS comment
     FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE (c.relname ~* ''(password|secret|credential|api_key|token|ssn|salary|key_store)''
            OR obj_description(c.oid) ~* ''sensitive|pii|confidential|restricted'')
       AND c.relkind = ''r''',
    '{"condition":"row_count > 0","description":"Sensitive tables exist and were queried by superuser"}'
  );

  CALL add_path(
    'SEC-SQL-AUD-006-RC02','sqlserver',
    'Detect superuser ad-hoc queries on sensitive tables - SQL Server',
    'Uses DMVs and extended properties to find sysadmin SELECT on data-classified tables',
    'Find sysadmin sessions querying sensitive table names',
    'SELECT s.login_name, t.text, r.start_time, s.host_name
     FROM sys.dm_exec_sessions s
     JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
     CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
     WHERE IS_SRVROLEMEMBER(''sysadmin'', s.login_name) = 1
       AND t.text LIKE ''%password%'' OR t.text LIKE ''%credential%''
          OR t.text LIKE ''%api_key%'' OR t.text LIKE ''%salary%''',
    '{"condition":"row_count > 0","description":"Sysadmin actively querying sensitive object names"}',
    'Check data classification labels on queried objects',
    'SELECT SCHEMA_NAME(t.schema_id) AS schema_name, t.name AS table_name,
            ep.value AS sensitivity_label
     FROM sys.tables t
     LEFT JOIN sys.extended_properties ep
           ON ep.major_id = t.object_id AND ep.name = ''SensitivityLabel''
     WHERE t.name IN (SELECT PARSENAME(REPLACE(p.text,''['',''''),1)
                      FROM sys.dm_exec_cached_plans cp
                      CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) p
                      WHERE p.text LIKE ''%sysadmin%'')',
    '{"condition":"row_count > 0","description":"Tables queried carry sensitivity labels confirming risk"}'
  );

  CALL add_path(
    'SEC-SQL-AUD-006-RC02','mysql',
    'Detect superuser ad-hoc queries on sensitive tables - MySQL',
    'Identifies SUPER account processlist entries targeting sensitive table names',
    'Check processlist for SUPER account sensitive-table queries',
    'SELECT ID, USER, HOST, DB, TIME, INFO
     FROM INFORMATION_SCHEMA.PROCESSLIST
     WHERE USER IN (SELECT DISTINCT grantee FROM INFORMATION_SCHEMA.USER_PRIVILEGES WHERE PRIVILEGE_TYPE = ''SUPER'')
       AND (INFO LIKE ''%password%'' OR INFO LIKE ''%credential%''
            OR INFO LIKE ''%api_key%'' OR INFO LIKE ''%salary%'' OR INFO LIKE ''%token%'')',
    '{"condition":"row_count > 0","description":"SUPER account querying sensitive table or column names"}',
    'Verify sensitive tables exist in current schema',
    'SELECT TABLE_SCHEMA, TABLE_NAME, TABLE_COMMENT
     FROM INFORMATION_SCHEMA.TABLES
     WHERE TABLE_NAME REGEXP ''(password|credential|api_key|salary|token|ssn|pii)''
        OR TABLE_COMMENT REGEXP ''(sensitive|confidential|pii|restricted)''',
    '{"condition":"row_count > 0","description":"Sensitive tables confirmed to exist in queried database"}'
  );

  CALL add_path(
    'SEC-SQL-AUD-006-RC02','oracle',
    'Detect superuser ad-hoc queries on sensitive tables - Oracle',
    'Uses V$SESSION and Oracle Data Masking/Redaction views to detect DBA access to sensitive objects',
    'Check DBA sessions querying sensitive object names',
    'SELECT s.USERNAME, q.SQL_TEXT, s.MACHINE, s.LOGON_TIME
     FROM V$SESSION s JOIN V$SQL q ON s.SQL_ID = q.SQL_ID
     WHERE s.USERNAME IN (SELECT GRANTEE FROM DBA_ROLE_PRIVS WHERE GRANTED_ROLE = ''DBA'')
       AND (UPPER(q.SQL_TEXT) LIKE ''%PASSWORD%'' OR UPPER(q.SQL_TEXT) LIKE ''%CREDENTIAL%''
            OR UPPER(q.SQL_TEXT) LIKE ''%SALARY%''  OR UPPER(q.SQL_TEXT) LIKE ''%API_KEY%'')',
    '{"condition":"row_count > 0","description":"DBA account querying sensitive object names"}',
    'Check DBA_REDACT_COLUMNS or DBA_SENSITIVE_DATA for those objects',
    'SELECT OWNER, OBJECT_NAME, COLUMN_NAME, SENSITIVE_TYPE
     FROM DBA_SENSITIVE_DATA
     WHERE SENSITIVE_TYPE IS NOT NULL
     UNION ALL
     SELECT OBJECT_OWNER, OBJECT_NAME, COLUMN_NAME, POLICY_NAME
     FROM DBA_REDACT_COLUMNS',
    '{"condition":"row_count > 0","description":"Sensitive/redacted columns confirmed  -- DBA access is high-risk"}'
  );

-- ------------------------------------------------------------
-- RC03  -- High privilege account accessing out-of-scope schema
-- ------------------------------------------------------------

  CALL add_path(
    'SEC-SQL-AUD-006-RC03','postgresql',
    'Detect privileged account accessing out-of-scope schema - PostgreSQL',
    'Finds superuser activity in schemas where no prior access pattern was established',
    'Check superuser current-schema vs normal operating schema',
    'SELECT pid, usename, query, query_start,
            current_setting(''search_path'') AS search_path
     FROM pg_stat_activity
     WHERE usename IN (SELECT rolname FROM pg_roles WHERE rolsuper = true)
       AND state = ''active''
       AND query !~* ''^\s*(--|\\/\\*|SHOW|SET|BEGIN|COMMIT|ROLLBACK)''',
    '{"condition":"row_count > 0","description":"Superuser active in a schema context  -- verify if expected"}',
    'List schemas the superuser has recently accessed vs expected list',
    'SELECT DISTINCT schemaname, tablename, tableowner
     FROM pg_tables
     WHERE tableowner NOT IN (
         SELECT rolname FROM pg_roles WHERE rolsuper = true
     )
     AND schemaname NOT IN (''pg_catalog'',''information_schema'',''public'')',
    '{"condition":"row_count > 0","description":"Non-owned schemas exist that superuser may be laterally accessing"}'
  );

  CALL add_path(
    'SEC-SQL-AUD-006-RC03','sqlserver',
    'Detect privileged account accessing out-of-scope schema - SQL Server',
    'Uses DMVs to identify sysadmin cross-schema object access',
    'Detect sysadmin queries referencing multiple schemas',
    'SELECT s.login_name, DB_NAME(r.database_id) AS db_name,
            t.text, r.start_time
     FROM sys.dm_exec_sessions s
     JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
     CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
     WHERE IS_SRVROLEMEMBER(''sysadmin'', s.login_name) = 1
       AND t.text LIKE ''%].%.[%''',
    '{"condition":"row_count > 0","description":"Sysadmin SQL references multi-schema object notation"}',
    'List schemas accessed vs schemas the login owns',
    'SELECT dp.name AS schema_name, dp.type_desc,
            USER_NAME(dp.principal_id) AS owner
     FROM sys.schemas s
     JOIN sys.database_principals dp ON dp.principal_id = s.principal_id
     WHERE s.name NOT IN (''dbo'',''sys'',''INFORMATION_SCHEMA'',''guest'')',
    '{"condition":"row_count > 0","description":"Non-standard schemas exist; verify sysadmin access is scoped"}'
  );

  CALL add_path(
    'SEC-SQL-AUD-006-RC03','mysql',
    'Detect privileged account accessing out-of-scope schema - MySQL',
    'Identifies SUPER account queries against databases outside the account default schema',
    'Check processlist for SUPER account cross-database queries',
    'SELECT ID, USER, DB, HOST, TIME, INFO
     FROM INFORMATION_SCHEMA.PROCESSLIST
     WHERE USER IN (SELECT DISTINCT grantee FROM INFORMATION_SCHEMA.USER_PRIVILEGES WHERE PRIVILEGE_TYPE = ''SUPER'')
       AND DB NOT IN (''mysql'',''information_schema'',''performance_schema'',''sys'')',
    '{"condition":"row_count > 0","description":"SUPER account active in user database  -- check if scoped"}',
    'List all databases the super account has explicit grants on',
    'SELECT GRANTEE, TABLE_SCHEMA, PRIVILEGE_TYPE
     FROM INFORMATION_SCHEMA.SCHEMA_PRIVILEGES
     WHERE GRANTEE IN (
         SELECT CONCAT('''''''',USER,'''''''',''@'','''''',HOST,'''''''')
         FROM INFORMATION_SCHEMA.PROCESSLIST
         WHERE USER IN (SELECT DISTINCT grantee FROM INFORMATION_SCHEMA.USER_PRIVILEGES WHERE PRIVILEGE_TYPE=''SUPER'')
     )',
    '{"condition":"row_count > 0","description":"Explicit cross-database grants confirm out-of-scope access risk"}'
  );

  CALL add_path(
    'SEC-SQL-AUD-006-RC03','oracle',
    'Detect privileged account accessing out-of-scope schema - Oracle',
    'Identifies DBA sessions accessing schemas they do not own',
    'Check DBA session activity on non-owned schemas',
    'SELECT s.USERNAME, o.OWNER AS accessed_schema, q.SQL_TEXT
     FROM V$SESSION s
     JOIN V$SQL q ON s.SQL_ID = q.SQL_ID
     JOIN ALL_OBJECTS o ON UPPER(q.SQL_TEXT) LIKE ''%'' || o.OBJECT_NAME || ''%''
     WHERE s.USERNAME IN (SELECT GRANTEE FROM DBA_ROLE_PRIVS WHERE GRANTED_ROLE = ''DBA'')
       AND o.OWNER != s.USERNAME
       AND o.OWNER NOT IN (''SYS'',''SYSTEM'',''OUTLN'',''DBSNMP'')
     FETCH FIRST 20 ROWS ONLY',
    '{"condition":"row_count > 0","description":"DBA account accessing objects in schemas it does not own"}',
    'Verify whether DBA has ANY privilege grants on the accessed schemas',
    'SELECT GRANTEE, OWNER, TABLE_NAME, PRIVILEGE
     FROM DBA_TAB_PRIVS
     WHERE GRANTEE IN (SELECT GRANTEE FROM DBA_ROLE_PRIVS WHERE GRANTED_ROLE = ''DBA'')
       AND OWNER NOT IN (''SYS'',''SYSTEM'')
     ORDER BY GRANTEE, OWNER',
    '{"condition":"row_count > 0","description":"DBA has explicit grants outside own schema  -- lateral access confirmed"}'
  );

-- ------------------------------------------------------------
-- RC04  -- Service account performing interactive transactions
-- ------------------------------------------------------------

  CALL add_path(
    'SEC-SQL-AUD-006-RC04','postgresql',
    'Detect service account interactive sessions - PostgreSQL',
    'Finds service accounts connected via interactive clients rather than application drivers',
    'Check application_name of service account sessions',
    'SELECT pid, usename, application_name, client_addr, backend_start, state
     FROM pg_stat_activity
     WHERE application_name IN (''psql'',''pgAdmin'',''DBeaver'',''DataGrip'',''TablePlus'',''Postico'',''HeidiSQL'')
       AND usename IN (
           SELECT rolname FROM pg_roles
           WHERE rolname ~* ''(svc|service|app|api|etl|batch|job|daemon|bot)''
       )',
    '{"condition":"row_count > 0","description":"Service account connected through an interactive SQL client"}',
    'Check for multi-statement ad-hoc query patterns from service accounts',
    'SELECT pid, usename, query
     FROM pg_stat_activity
     WHERE usename IN (SELECT rolname FROM pg_roles WHERE rolname ~* ''(svc|service|app|api)'')
       AND query ~* '';\s*(SELECT|INSERT|UPDATE|DELETE)''
       AND state = ''active''',
    '{"condition":"row_count > 0","description":"Service account executing chained ad-hoc statements  -- not typical application behaviour"}'
  );

  CALL add_path(
    'SEC-SQL-AUD-006-RC04','sqlserver',
    'Detect service account interactive sessions - SQL Server',
    'Identifies service accounts connecting via SSMS or other interactive tools',
    'Check program_name for interactive tools used by service accounts',
    'SELECT s.login_name, s.program_name, s.host_name, s.client_interface_name, s.login_time
     FROM sys.dm_exec_sessions s
     WHERE s.program_name LIKE ''Microsoft SQL Server Management Studio%''
        OR s.program_name LIKE ''DBeaver%''
        OR s.program_name LIKE ''DataGrip%''
        OR s.program_name LIKE ''Azure Data Studio%''
        OR s.program_name LIKE ''sqlcmd%''
     AND s.login_name LIKE ''%svc%'' OR s.login_name LIKE ''%service%''
        OR s.login_name LIKE ''%app%'' OR s.login_name LIKE ''%api%''',
    '{"condition":"row_count > 0","description":"Service account connected via interactive management tool"}',
    'Verify the account is a service account by checking its description or role membership',
    'SELECT sp.name, sp.type_desc, sp.is_disabled,
            ISNULL(ep.value, ''No description'') AS description
     FROM sys.server_principals sp
     LEFT JOIN sys.extended_properties ep ON ep.major_id = sp.principal_id AND ep.name = ''AccountType''
     WHERE sp.name LIKE ''%svc%'' OR sp.name LIKE ''%service%'' OR sp.name LIKE ''%api%''',
    '{"condition":"row_count > 0","description":"Confirmed service accounts exist and show interactive sessions"}'
  );

  CALL add_path(
    'SEC-SQL-AUD-006-RC04','mysql',
    'Detect service account interactive sessions - MySQL',
    'Uses PROCESSLIST to find service accounts connected from interactive hosts',
    'Check processlist for service accounts using interactive clients',
    'SELECT ID, USER, HOST, COMMAND, TIME, INFO
     FROM INFORMATION_SCHEMA.PROCESSLIST
     WHERE USER REGEXP ''(svc|service|app|api|etl|batch|bot|daemon)''
       AND COMMAND != ''Sleep''
       AND HOST NOT REGEXP ''^(10\.|172\.|192\.168\.)''',
    '{"condition":"row_count > 0","description":"Service account active from non-internal network address  -- possible interactive session"}',
    'Check if account has only expected application-level privileges',
    'SELECT GRANTEE, PRIVILEGE_TYPE, IS_GRANTABLE
     FROM INFORMATION_SCHEMA.USER_PRIVILEGES
     WHERE GRANTEE REGEXP ''(svc|service|app|api)''
       AND PRIVILEGE_TYPE NOT IN (''SELECT'',''INSERT'',''UPDATE'',''DELETE'',''EXECUTE'')',
    '{"condition":"row_count > 0","description":"Service account holds unexpected privilege types beyond standard application grants"}'
  );

  CALL add_path(
    'SEC-SQL-AUD-006-RC04','oracle',
    'Detect service account interactive sessions - Oracle',
    'Uses V$SESSION to identify service accounts with interactive program attributes',
    'Check V$SESSION for service accounts with interactive program names',
    'SELECT USERNAME, PROGRAM, MACHINE, TERMINAL, LOGON_TIME, STATUS
     FROM V$SESSION
     WHERE (UPPER(PROGRAM) LIKE ''%SQLPLUS%'' OR UPPER(PROGRAM) LIKE ''%SQLDEV%''
            OR UPPER(PROGRAM) LIKE ''%TOAD%''  OR UPPER(PROGRAM) LIKE ''%DBEAVER%'')
       AND UPPER(USERNAME) LIKE ANY(ARRAY[''%SVC%'',''%SERVICE%'',''%APP%'',''%API%'',''%ETL%''])',
    '{"condition":"row_count > 0","description":"Service account connected via interactive Oracle client tool"}',
    'Verify account has application-only role assignments',
    'SELECT GRANTEE, GRANTED_ROLE, ADMIN_OPTION, DEFAULT_ROLE
     FROM DBA_ROLE_PRIVS
     WHERE UPPER(GRANTEE) REGEXP_LIKE GRANTEE, ''(SVC|SERVICE|APP|API|ETL)''
       AND GRANTED_ROLE NOT IN (''CONNECT'',''RESOURCE'')',
    '{"condition":"row_count > 0","description":"Service account holds roles beyond CONNECT/RESOURCE  -- privilege misuse risk"}'
  );

-- ------------------------------------------------------------
-- RC05  -- Privilege escalation during active session
-- ------------------------------------------------------------

  CALL add_path(
    'SEC-SQL-AUD-006-RC05','postgresql',
    'Detect privilege escalation during active session - PostgreSQL',
    'Identifies sessions executing SET ROLE, GRANT, or CREATE ROLE mid-session',
    'Check active sessions for privilege-elevating commands',
    'SELECT pid, usename, query, query_start, client_addr
     FROM pg_stat_activity
     WHERE state = ''active''
       AND query ~* ''^\s*(GRANT|SET\s+ROLE|CREATE\s+ROLE|ALTER\s+ROLE|SECURITY\s+DEFINER)''',
    '{"condition":"row_count > 0","description":"Active session executing privilege-escalation command"}',
    'Check if the account had lower privileges at login vs current effective role',
    'SELECT pid, usename, query
     FROM pg_stat_activity
     WHERE query ~* ''SET\s+ROLE\s+\w+''
       AND usename NOT IN (SELECT rolname FROM pg_roles WHERE rolsuper = true)',
    '{"condition":"row_count > 0","description":"Non-superuser account switching roles mid-session  -- escalation pattern detected"}'
  );

  CALL add_path(
    'SEC-SQL-AUD-006-RC05','sqlserver',
    'Detect privilege escalation during active session - SQL Server',
    'Finds EXECUTE AS, GRANT, or ALTER SERVER ROLE within active sessions',
    'Check running requests for EXECUTE AS or GRANT statements',
    'SELECT s.login_name, s.original_login_name, t.text, r.start_time
     FROM sys.dm_exec_sessions s
     JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
     CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
     WHERE t.text LIKE ''%EXECUTE AS%''
        OR t.text LIKE ''%GRANT%SERVER ROLE%''
        OR t.text LIKE ''%ALTER SERVER ROLE%''',
    '{"condition":"row_count > 0","description":"Session executing impersonation or server-role grant command"}',
    'Compare original_login_name vs login_name for impersonation gap',
    'SELECT session_id, login_name, original_login_name, status
     FROM sys.dm_exec_sessions
     WHERE login_name != original_login_name
       AND is_user_process = 1',
    '{"condition":"row_count > 0","description":"Impersonation active  -- login_name differs from original_login_name"}'
  );

  CALL add_path(
    'SEC-SQL-AUD-006-RC05','mysql',
    'Detect privilege escalation during active session - MySQL',
    'Finds GRANT or SET commands in active processlist indicating mid-session escalation',
    'Check PROCESSLIST for active GRANT or privilege-changing statements',
    'SELECT ID, USER, HOST, DB, TIME, INFO
     FROM INFORMATION_SCHEMA.PROCESSLIST
     WHERE COMMAND = ''Query''
       AND (INFO LIKE ''%GRANT %'' OR INFO LIKE ''%SET ROLE%''
            OR INFO LIKE ''%CREATE USER%'' OR INFO LIKE ''%ALTER USER%'')',
    '{"condition":"row_count > 0","description":"Active session issuing privilege-granting or role-change command"}',
    'Check if the issuing account itself lacks GRANT OPTION',
    'SELECT GRANTEE, PRIVILEGE_TYPE, IS_GRANTABLE
     FROM INFORMATION_SCHEMA.USER_PRIVILEGES
     WHERE GRANTEE IN (
         SELECT CONCAT('''''''',USER,'''''''',''@'','''''',HOST,'''''''')
         FROM INFORMATION_SCHEMA.PROCESSLIST
         WHERE INFO LIKE ''%GRANT %''
     )
     AND IS_GRANTABLE = ''NO''',
    '{"condition":"row_count > 0","description":"Account issuing GRANT does not hold GRANT OPTION  -- unauthorized escalation attempt"}'
  );

  CALL add_path(
    'SEC-SQL-AUD-006-RC05','oracle',
    'Detect privilege escalation during active session - Oracle',
    'Uses V$SQL and DBA_AUDIT_TRAIL to find GRANT or proxy activation mid-session',
    'Check V$SQL for recent GRANT or ALTER SESSION SET ROLE statements',
    'SELECT s.USERNAME, q.SQL_TEXT, s.LOGON_TIME, s.STATUS
     FROM V$SESSION s JOIN V$SQL q ON s.SQL_ID = q.SQL_ID
     WHERE (UPPER(q.SQL_TEXT) LIKE ''%GRANT %''
            OR UPPER(q.SQL_TEXT) LIKE ''%ALTER SESSION SET ROLE%''
            OR UPPER(q.SQL_TEXT) LIKE ''%DBMS_PRIVILEGE_CAPTURE%'')',
    '{"condition":"row_count > 0","description":"Session executing GRANT or SET ROLE mid-connection"}',
    'Check audit trail for role activations by non-DBA accounts',
    'SELECT DB_USER, ACTION_NAME, OBJ_NAME, TIMESTAMP, RETURN_CODE
     FROM DBA_AUDIT_TRAIL
     WHERE ACTION_NAME IN (''GRANT ROLE'',''SET ROLE'',''GRANT PRIVILEGE'')
       AND DB_USER NOT IN (SELECT GRANTEE FROM DBA_ROLE_PRIVS WHERE GRANTED_ROLE = ''DBA'')
       AND TIMESTAMP > SYSDATE - 1',
    '{"condition":"row_count > 0","description":"Non-DBA account granted or activated elevated role in last 24 hours"}'
  );

-- ------------------------------------------------------------
-- SEC-SQL-AUD-007 root causes  -- Unknown Transaction Patterns
-- ------------------------------------------------------------

-- RC01  -- Unregistered application signatures
  CALL add_path(
    'SEC-SQL-AUD-007-RC01','postgresql',
    'Detect unregistered application signatures - PostgreSQL',
    'Finds sessions whose application_name is not in the approved registry',
    'Check application_name against known registry',
    'SELECT pid, usename, application_name, client_addr, state, query_start
     FROM pg_stat_activity
     WHERE application_name NOT IN (''app_main'',''app_reporting'',''etl_service'',''monitoring'',''pgbouncer'',''patroni'','''')
       AND application_name != ''''
       AND state != ''idle''',
    '{"condition":"row_count > 0","description":"Active session from unregistered application_name"}',
    'Check if the source IP also falls outside approved CIDR ranges',
    'SELECT pid, usename, application_name, client_addr
     FROM pg_stat_activity
     WHERE application_name NOT IN (''app_main'',''app_reporting'',''etl_service'',''monitoring'')
       AND client_addr IS NOT NULL
       AND NOT (client_addr << ''10.0.0.0/8''::inet
             OR client_addr << ''172.16.0.0/12''::inet
             OR client_addr << ''192.168.0.0/16''::inet)',
    '{"condition":"row_count > 0","description":"Unregistered app connecting from external IP  -- high-confidence unknown source"}'
  );

  CALL add_path(
    'SEC-SQL-AUD-007-RC01','sqlserver',
    'Detect unregistered application signatures - SQL Server',
    'Identifies program_name values not in the approved application list',
    'Check program_name against approved registry',
    'SELECT s.session_id, s.login_name, s.program_name, s.host_name, s.client_interface_name
     FROM sys.dm_exec_sessions s
     WHERE s.is_user_process = 1
       AND s.program_name NOT IN (
           ''AppMain'',''ReportingService'',''ETLAgent'',''SqlAgent'',
           ''Microsoft SQL Server Management Studio - Query'', -- remove in prod
           ''.Net SqlClient Data Provider''
       )
       AND s.program_name NOT LIKE ''%SQLAgent%''',
    '{"condition":"row_count > 0","description":"Active session from unregistered program_name"}',
    'Correlate host_name with approved server inventory',
    'SELECT s.host_name, COUNT(*) AS session_count
     FROM sys.dm_exec_sessions s
     WHERE s.is_user_process = 1
       AND s.program_name NOT IN (''AppMain'',''ReportingService'',''ETLAgent'')
     GROUP BY s.host_name',
    '{"condition":"row_count > 0","description":"Unregistered application sessions grouped by host  -- identify rogue source"}'
  );

  CALL add_path(
    'SEC-SQL-AUD-007-RC01','mysql',
    'Detect unregistered application signatures - MySQL',
    'Finds connections with program names not matching known application list via performance_schema',
    'Check performance_schema.accounts for unknown programs',
    'SELECT pa.USER, pa.HOST, pa.CURRENT_CONNECTIONS, pa.TOTAL_CONNECTIONS
     FROM performance_schema.accounts pa
     WHERE pa.HOST NOT REGEXP ''^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)''
       AND pa.USER NOT IN (''replication'',''monitoring'',''backup'',''root'')
       AND pa.CURRENT_CONNECTIONS > 0',
    '{"condition":"row_count > 0","description":"Active connections from hosts outside approved internal ranges"}',
    'Cross-check with information_schema processlist for active queries',
    'SELECT USER, HOST, DB, COMMAND, INFO
     FROM INFORMATION_SCHEMA.PROCESSLIST
     WHERE HOST NOT REGEXP ''^(10\.|172\.|192\.168\.)''
       AND COMMAND != ''Sleep''',
    '{"condition":"row_count > 0","description":"Active query from external host  -- unregistered application signature confirmed"}'
  );

  CALL add_path(
    'SEC-SQL-AUD-007-RC01','oracle',
    'Detect unregistered application signatures - Oracle',
    'Uses V$SESSION PROGRAM and MODULE columns to find unregistered application connections',
    'Check SESSION program/module against approved list',
    'SELECT USERNAME, PROGRAM, MODULE, CLIENT_INFO, MACHINE, LOGON_TIME
     FROM V$SESSION
     WHERE TYPE = ''USER''
       AND STATUS = ''ACTIVE''
       AND PROGRAM NOT IN (''JDBC Thin Client'',''OCI'',''app_main.exe'',''etl_agent'')
       AND MODULE NOT IN (''APP_MAIN'',''REPORTING'',''ETL'')',
    '{"condition":"row_count > 0","description":"Active session with unregistered PROGRAM or MODULE"}',
    'Check CLIENT_INFO for additional application registration data',
    'SELECT USERNAME, CLIENT_INFO, MACHINE, COUNT(*) AS sessions
     FROM V$SESSION
     WHERE TYPE = ''USER'' AND CLIENT_INFO IS NULL AND STATUS = ''ACTIVE''
     GROUP BY USERNAME, CLIENT_INFO, MACHINE',
    '{"condition":"row_count > 0","description":"Sessions with no CLIENT_INFO registration suggest rogue or unregistered tool"}'
  );

-- RC02  -- Query patterns not matching baseline
  CALL add_path(
    'SEC-SQL-AUD-007-RC02','postgresql',
    'Detect anomalous query patterns vs baseline - PostgreSQL',
    'Uses pg_stat_statements to flag query structures not seen in historical baseline',
    'Check for queries with unusual table-join depth or column count',
    'SELECT query, calls, total_exec_time, rows, userid::regrole AS username
     FROM pg_stat_statements
     WHERE (SELECT COUNT(*) FROM REGEXP_MATCHES(query, ''JOIN'', ''gi'')) > 6
        OR query ~* ''UNION\s+ALL''
        OR query ~* ''INTO\s+OUTFILE''
        OR query ~* ''COPY\s+.+\s+TO''
     ORDER BY total_exec_time DESC
     LIMIT 20',
    '{"condition":"row_count > 0","description":"Query with unusual JOIN depth, UNION ALL, or file-copy pattern detected"}',
    'Check for never-seen-before query fingerprints (new queryid)',
    'SELECT queryid, query, calls, userid::regrole
     FROM pg_stat_statements
     WHERE calls = 1
       AND query !~* ''^\s*(BEGIN|COMMIT|ROLLBACK|SET|SHOW|EXPLAIN)''
       AND LENGTH(query) > 200
     ORDER BY total_exec_time DESC
     LIMIT 20',
    '{"condition":"row_count > 0","description":"Single-execution long queries with new queryid  -- potential manually crafted SQL"}'
  );

  CALL add_path(
    'SEC-SQL-AUD-007-RC02','sqlserver',
    'Detect anomalous query patterns vs baseline - SQL Server',
    'Uses query store and DMVs to find query patterns with no prior execution history',
    'Check Query Store for single-execution anomalous plans',
    'SELECT qt.query_sql_text, rs.count_executions, rs.avg_duration, qp.query_plan
     FROM sys.query_store_query_text qt
     JOIN sys.query_store_query q ON q.query_text_id = qt.query_text_id
     JOIN sys.query_store_plan qp ON qp.query_id = q.query_id
     JOIN sys.query_store_runtime_stats rs ON rs.plan_id = qp.plan_id
     WHERE rs.count_executions = 1
       AND rs.avg_duration > 10000000
       AND qt.query_sql_text NOT LIKE ''%sys.%''
     ORDER BY rs.avg_duration DESC',
    '{"condition":"row_count > 0","description":"Single-execution long-running query with no historical baseline"}',
    'Scan plan cache for queries with unusually high logical reads',
    'SELECT TOP 20 st.text, qs.execution_count, qs.total_logical_reads / qs.execution_count AS avg_reads
     FROM sys.dm_exec_query_stats qs
     CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
     WHERE qs.execution_count = 1
       AND qs.total_logical_reads > 100000
     ORDER BY avg_reads DESC',
    '{"condition":"row_count > 0","description":"New query with extreme logical read count  -- unknown/anomalous pattern"}'
  );

  CALL add_path(
    'SEC-SQL-AUD-007-RC02','mysql',
    'Detect anomalous query patterns vs baseline - MySQL',
    'Uses performance_schema events_statements_history for structural anomalies',
    'Check statement history for high-scan full-table queries',
    'SELECT DIGEST_TEXT, COUNT_STAR, AVG_TIMER_WAIT/1000000000 AS avg_ms,
            SUM_ROWS_EXAMINED, SUM_ROWS_SENT
     FROM performance_schema.events_statements_summary_by_digest
     WHERE COUNT_STAR = 1
       AND SUM_ROWS_EXAMINED > 1000000
       AND DIGEST_TEXT NOT LIKE ''%information_schema%''
     ORDER BY SUM_ROWS_EXAMINED DESC
     LIMIT 20',
    '{"condition":"row_count > 0","description":"Single-execution query scanning >1M rows  -- anomalous pattern"}',
    'Check for queries with UNION or multi-table joins not in baseline digest list',
    'SELECT DIGEST, DIGEST_TEXT, COUNT_STAR
     FROM performance_schema.events_statements_summary_by_digest
     WHERE (DIGEST_TEXT LIKE ''%UNION%'' OR DIGEST_TEXT LIKE ''%JOIN%JOIN%JOIN%'')
       AND COUNT_STAR < 3
       AND LAST_SEEN > NOW() - INTERVAL 1 HOUR
     ORDER BY LAST_SEEN DESC',
    '{"condition":"row_count > 0","description":"Recent complex UNION or deep-join query with near-zero historical frequency"}'
  );

  CALL add_path(
    'SEC-SQL-AUD-007-RC02','oracle',
    'Detect anomalous query patterns vs baseline - Oracle',
    'Uses V$SQL and AWR baseline to identify queries absent from historical workload',
    'Check V$SQL for single-execution queries with high buffer gets',
    'SELECT SQL_ID, SQL_TEXT, EXECUTIONS, BUFFER_GETS, DISK_READS,
            FIRST_LOAD_TIME, LAST_ACTIVE_TIME
     FROM V$SQL
     WHERE EXECUTIONS = 1
       AND BUFFER_GETS > 100000
       AND PARSING_USER_ID NOT IN (SELECT USER_ID FROM DBA_USERS WHERE USERNAME IN (''SYS'',''SYSTEM''))
     ORDER BY BUFFER_GETS DESC
     FETCH FIRST 20 ROWS ONLY',
    '{"condition":"row_count > 0","description":"Single-execution query with unusually high buffer gets  -- not in baseline"}',
    'Compare SQL_ID against AWR baseline SQL summary',
    'SELECT sql_id, elapsed_time_total, executions_total, buffer_gets_total
     FROM DBA_HIST_SQLSTAT
     WHERE snap_id IN (SELECT snap_id FROM DBA_HIST_SNAPSHOT WHERE BEGIN_INTERVAL_TIME > SYSDATE-1)
     MINUS
     SELECT sql_id, elapsed_time_total, executions_total, buffer_gets_total
     FROM DBA_HIST_SQLSTAT
     WHERE snap_id IN (SELECT snap_id FROM DBA_HIST_SNAPSHOT WHERE BEGIN_INTERVAL_TIME BETWEEN SYSDATE-7 AND SYSDATE-1)',
    '{"condition":"row_count > 0","description":"SQL IDs present in last 24h not seen in prior 7-day baseline  -- new unknown queries"}'
  );

-- RC03  -- Connections from unexpected network addresses
  CALL add_path(
    'SEC-SQL-AUD-007-RC03','postgresql',
    'Detect connections from unexpected network addresses - PostgreSQL',
    'Identifies active sessions from IPs outside approved CIDR ranges',
    'Check pg_stat_activity for external IP connections',
    'SELECT pid, usename, application_name, client_addr, client_hostname, state
     FROM pg_stat_activity
     WHERE client_addr IS NOT NULL
       AND NOT (client_addr << ''10.0.0.0/8''::inet
             OR client_addr << ''172.16.0.0/12''::inet
             OR client_addr << ''192.168.0.0/16''::inet
             OR client_addr = ''127.0.0.1''::inet)',
    '{"condition":"row_count > 0","description":"Active session from IP outside approved private ranges"}',
    'Check pg_hba.conf rules to verify if source is whitelisted',
    'SELECT type, database, user_name, address, auth_method
     FROM pg_hba_file_rules
     WHERE address NOT IN (''127.0.0.1/32'',''::1/128'',''samenet'')
       AND address !~ ''^10\.'' AND address !~ ''^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[01]\.'' AND address !~ ''^192\.168\.''',
    '{"condition":"row_count > 0","description":"pg_hba.conf contains rules allowing external IPs  -- verify they are approved"}'
  );

  CALL add_path(
    'SEC-SQL-AUD-007-RC03','sqlserver',
    'Detect connections from unexpected network addresses - SQL Server',
    'Uses DMV to identify logins from IPs outside the internal network',
    'Check dm_exec_connections for external source IPs',
    'SELECT c.client_net_address, s.login_name, s.program_name, s.host_name, c.connect_time
     FROM sys.dm_exec_connections c
     JOIN sys.dm_exec_sessions s ON s.session_id = c.session_id
     WHERE c.client_net_address NOT LIKE ''10.%''
       AND c.client_net_address NOT LIKE ''172.%''
       AND c.client_net_address NOT LIKE ''192.168.%''
       AND c.client_net_address != ''<local machine>''
       AND s.is_user_process = 1',
    '{"condition":"row_count > 0","description":"Connection from non-internal IP range  -- potentially unauthorized source"}',
    'Check firewall rules via SQL Server login auditing',
    'SELECT event_time, server_principal_name, client_ip, application_name, succeeded
     FROM sys.fn_get_audit_file(''C:\Audit\*.sqlaudit'', DEFAULT, DEFAULT)
     WHERE action_id = ''LGN''
       AND client_ip NOT LIKE ''10.%''
       AND client_ip NOT LIKE ''192.168.%''
     ORDER BY event_time DESC',
    '{"condition":"row_count > 0","description":"Audit log confirms successful logins from external IPs"}'
  );

  CALL add_path(
    'SEC-SQL-AUD-007-RC03','mysql',
    'Detect connections from unexpected network addresses - MySQL',
    'Identifies active connections from non-internal hosts',
    'Check PROCESSLIST for external host connections',
    'SELECT ID, USER, HOST, DB, COMMAND, TIME
     FROM INFORMATION_SCHEMA.PROCESSLIST
     WHERE HOST NOT REGEXP ''^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|localhost|127\.0\.0\.1)''',
    '{"condition":"row_count > 0","description":"Active MySQL connection from external network address"}',
    'Check user account host restrictions for the connecting user',
    'SELECT User, Host, account_locked, password_expired
     FROM mysql.user
     WHERE Host NOT IN (''localhost'',''127.0.0.1'',''::1'')
       AND Host NOT REGEXP ''^(10\.|172\.|192\.168\.)',
     '{"condition":"row_count > 0","description":"User accounts exist with unrestricted or external host permissions"}'
  );

  CALL add_path(
    'SEC-SQL-AUD-007-RC03','oracle',
    'Detect connections from unexpected network addresses - Oracle',
    'Uses V$SESSION and MACHINE column to detect external client connections',
    'Check V$SESSION for connections from non-approved machines',
    'SELECT USERNAME, MACHINE, TERMINAL, PROGRAM, LOGON_TIME, STATUS
     FROM V$SESSION
     WHERE TYPE = ''USER''
       AND MACHINE NOT LIKE ''%.internal''
       AND MACHINE NOT LIKE ''%.corp''
       AND MACHINE NOT IN (SELECT HOST_NAME FROM V$INSTANCE)',
    '{"condition":"row_count > 0","description":"Session from machine not matching internal domain pattern"}',
    'Cross-check with Oracle Connection Manager or sqlnet.ora allowed hosts',
    'SELECT NAME, VALUE FROM V$PARAMETER
     WHERE NAME IN (''tcp.validnode_checking'',''tcp.invited_nodes'',''tcp.excluded_nodes'')',
    '{"condition":"value IS NULL OR value = ''''''","description":"TCP valid-node checking not configured  -- any host can connect"}'
  );

-- RC04  -- Off-hours activity from non-automated accounts (abbreviated  -- 1 step pair per vendor)
  CALL add_path(
    'SEC-SQL-AUD-007-RC04','postgresql',
    'Detect off-hours non-automated account activity - PostgreSQL',
    'Flags human accounts active outside business hours (08:00-20:00 local)',
    'Check pg_stat_activity for human accounts outside business hours',
    'SELECT pid, usename, application_name, state, query_start,
            EXTRACT(HOUR FROM NOW() AT TIME ZONE ''UTC'') AS utc_hour
     FROM pg_stat_activity
     WHERE state != ''idle''
       AND usename NOT IN (SELECT rolname FROM pg_roles WHERE rolname ~* ''(svc|service|app|etl|batch|monitor|backup|agent|replica)'')
       AND EXTRACT(HOUR FROM NOW() AT TIME ZONE ''UTC'') NOT BETWEEN 6 AND 20',
    '{"condition":"row_count > 0","description":"Human account active outside 06:00-20:00 UTC business window"}',
    'Check whether account has any automated/scheduled job association',
    'SELECT rolname, rolcanlogin, rolvaliduntil, pg_catalog.shobj_description(oid, ''pg_authid'') AS comment
     FROM pg_roles
     WHERE rolname IN (
         SELECT usename FROM pg_stat_activity
         WHERE state != ''idle''
           AND EXTRACT(HOUR FROM NOW() AT TIME ZONE ''UTC'') NOT BETWEEN 6 AND 20
     )',
    '{"condition":"row_count > 0","description":"Account metadata does not indicate a scheduled/service role  -- off-hours access suspicious"}'
  );

  CALL add_path('SEC-SQL-AUD-007-RC04','sqlserver',
    'Detect off-hours non-automated account activity - SQL Server',
    'Identifies human logins active outside 06:00-20:00',
    'Check dm_exec_sessions for human accounts outside business hours',
    'SELECT login_name, program_name, host_name, login_time, status,
            DATEPART(HOUR, GETUTCDATE()) AS utc_hour
     FROM sys.dm_exec_sessions
     WHERE is_user_process = 1
       AND login_name NOT LIKE ''%svc%'' AND login_name NOT LIKE ''%service%''
         AND login_name NOT LIKE ''%agent%'' AND login_name NOT LIKE ''NT %''
       AND DATEPART(HOUR, GETUTCDATE()) NOT BETWEEN 6 AND 20',
    '{"condition":"row_count > 0","description":"Human account active outside 06:00-20:00 UTC"}',
    'Verify login has no SQL Agent job scheduled at this hour',
    'SELECT j.name AS job_name, s.name AS schedule_name, s.active_start_time, s.active_end_time
     FROM msdb.dbo.sysjobs j
     JOIN msdb.dbo.sysjobschedules js ON js.job_id = j.job_id
     JOIN msdb.dbo.sysschedules s ON s.schedule_id = js.schedule_id
     WHERE j.enabled = 1
       AND s.active_start_time / 10000 NOT BETWEEN 6 AND 20',
    '{"condition":"row_count = 0","description":"No scheduled jobs at this hour  -- off-hours activity is not automated"}'
  );

  CALL add_path('SEC-SQL-AUD-007-RC04','mysql',
    'Detect off-hours non-automated account activity - MySQL',
    'Checks PROCESSLIST for human accounts outside 06:00-20:00 UTC',
    'Check processlist hour for non-service accounts',
    'SELECT ID, USER, HOST, DB, COMMAND, TIME, INFO,
            HOUR(UTC_TIMESTAMP()) AS utc_hour
     FROM INFORMATION_SCHEMA.PROCESSLIST
     WHERE USER NOT REGEXP ''(svc|service|app|etl|batch|monitor|backup|replication)''
       AND COMMAND != ''Sleep''
       AND HOUR(UTC_TIMESTAMP()) NOT BETWEEN 6 AND 20',
    '{"condition":"row_count > 0","description":"Human-type account executing queries outside business hours"}',
    'Check account event scheduler or scheduled event association',
    'SELECT EVENT_SCHEMA, EVENT_NAME, STATUS, EXECUTE_AT, INTERVAL_VALUE, INTERVAL_FIELD, DEFINER
     FROM INFORMATION_SCHEMA.EVENTS
     WHERE STATUS = ''ENABLED''
       AND DEFINER IN (
           SELECT CONCAT(USER,''@'',SUBSTRING_INDEX(HOST,'':'',1))
           FROM INFORMATION_SCHEMA.PROCESSLIST
           WHERE HOUR(UTC_TIMESTAMP()) NOT BETWEEN 6 AND 20
       )',
    '{"condition":"row_count = 0","description":"No scheduled events for this account at this hour  -- off-hours access unplanned"}'
  );

  CALL add_path('SEC-SQL-AUD-007-RC04','oracle',
    'Detect off-hours non-automated account activity - Oracle',
    'Detects human accounts in V$SESSION outside 06:00-20:00',
    'Check V$SESSION for human accounts outside business hours',
    'SELECT USERNAME, PROGRAM, MACHINE, LOGON_TIME, STATUS,
            TO_NUMBER(TO_CHAR(SYS_EXTRACT_UTC(SYSTIMESTAMP),''HH24'')) AS utc_hour
     FROM V$SESSION
     WHERE TYPE = ''USER''
       AND STATUS = ''ACTIVE''
       AND USERNAME NOT IN (SELECT USERNAME FROM DBA_USERS WHERE USERNAME REGEXP_LIKE USERNAME, ''(SVC|SERVICE|APP|ETL|BATCH|MONITOR|BACKUP)'')
       AND TO_NUMBER(TO_CHAR(SYS_EXTRACT_UTC(SYSTIMESTAMP),''HH24'')) NOT BETWEEN 6 AND 20',
    '{"condition":"row_count > 0","description":"Human Oracle account active outside 06:00-20:00 UTC"}',
    'Verify no DBMS_SCHEDULER job runs at this hour for the account',
    'SELECT JOB_NAME, STATE, LAST_RUN_DURATION, NEXT_RUN_DATE, OWNER
     FROM DBA_SCHEDULER_JOBS
     WHERE STATE = ''RUNNING''
       AND OWNER NOT IN (''SYS'',''SYSTEM'',''DBSNMP'')',
    '{"condition":"row_count = 0","description":"No DBMS_SCHEDULER jobs running  -- off-hours human session is unscheduled"}'
  );

-- RC05  -- Previously unseen stored procedures/functions
  CALL add_path('SEC-SQL-AUD-007-RC05','postgresql',
    'Detect execution of previously unseen functions - PostgreSQL',
    'Finds function calls in pg_stat_activity not present in historical pg_stat_statements',
    'Check for recently created functions called in active sessions',
    'SELECT p.proname, n.nspname, p.procost, p.proacl, r.rolname AS owner,
            p.prosrc
     FROM pg_proc p
     JOIN pg_namespace n ON n.oid = p.pronamespace
     JOIN pg_roles r ON r.oid = p.proowner
     WHERE p.proacl IS NOT NULL
       AND pg_catalog.pg_function_is_visible(p.oid)
       AND (EXTRACT(EPOCH FROM NOW()) - EXTRACT(EPOCH FROM (
               SELECT MIN(query_start) FROM pg_stat_activity WHERE query ~* p.proname
            ))) < 3600',
    '{"condition":"row_count > 0","description":"Recently invoked function found in active sessions"}',
    'Check function creation date against baseline window',
    'SELECT routine_name, routine_schema, created, routine_definition
     FROM information_schema.routines
     WHERE routine_type = ''FUNCTION''
       AND created > NOW() - INTERVAL ''7 days''
       AND routine_schema NOT IN (''pg_catalog'',''information_schema'')',
    '{"condition":"row_count > 0","description":"Functions created within the last 7 days  -- potential backdoor injection"}'
  );

  CALL add_path('SEC-SQL-AUD-007-RC05','sqlserver',
    'Detect execution of previously unseen stored procedures - SQL Server',
    'Uses Query Store and sys.objects to find recently created or first-time-executed procedures',
    'Check Query Store for first-execution of stored procedures',
    'SELECT OBJECT_NAME(q.object_id) AS proc_name,
            qt.query_sql_text, rs.first_execution_time, rs.count_executions
     FROM sys.query_store_query q
     JOIN sys.query_store_query_text qt ON qt.query_text_id = q.query_text_id
     JOIN sys.query_store_plan qp ON qp.query_id = q.query_id
     JOIN sys.query_store_runtime_stats rs ON rs.plan_id = qp.plan_id
     WHERE rs.count_executions = 1
       AND rs.first_execution_time > DATEADD(DAY,-7,GETDATE())
       AND q.object_id IS NOT NULL',
    '{"condition":"row_count > 0","description":"Stored procedures executed for the first time in last 7 days"}',
    'Check if the procedure was created recently',
    'SELECT name, create_date, modify_date, type_desc, OBJECT_DEFINITION(object_id) AS definition
     FROM sys.objects
     WHERE type IN (''P'',''FN'',''IF'',''TF'')
       AND create_date > DATEADD(DAY,-7,GETDATE())
     ORDER BY create_date DESC',
    '{"condition":"row_count > 0","description":"Recently created stored procedures/functions  -- verify legitimacy"}'
  );

  CALL add_path('SEC-SQL-AUD-007-RC05','mysql',
    'Detect execution of previously unseen routines - MySQL',
    'Identifies recently created stored procedures being called',
    'Check ROUTINES for recently created procedures',
    'SELECT ROUTINE_SCHEMA, ROUTINE_NAME, ROUTINE_TYPE, CREATED, LAST_ALTERED, DEFINER
     FROM INFORMATION_SCHEMA.ROUTINES
     WHERE CREATED > NOW() - INTERVAL 7 DAY
       AND ROUTINE_TYPE IN (''PROCEDURE'',''FUNCTION'')',
    '{"condition":"row_count > 0","description":"Stored routines created within the last 7 days"}',
    'Check performance_schema for recent execution of those routines',
    'SELECT OBJECT_SCHEMA, OBJECT_NAME, OBJECT_TYPE, COUNT_STAR, LAST_SEEN
     FROM performance_schema.objects_summary_global_by_type
     WHERE OBJECT_TYPE IN (''PROCEDURE'',''FUNCTION'')
       AND LAST_SEEN > NOW() - INTERVAL 1 HOUR
     ORDER BY LAST_SEEN DESC',
    '{"condition":"row_count > 0","description":"Recently created routine was called in the last hour  -- verify intent"}'
  );

  CALL add_path('SEC-SQL-AUD-007-RC05','oracle',
    'Detect execution of previously unseen procedures - Oracle',
    'Uses DBA_OBJECTS and V$SQL to find newly created procedures being called',
    'Check DBA_OBJECTS for recently created procedures',
    'SELECT OWNER, OBJECT_NAME, OBJECT_TYPE, CREATED, LAST_DDL_TIME, STATUS
     FROM DBA_OBJECTS
     WHERE OBJECT_TYPE IN (''PROCEDURE'',''FUNCTION'',''PACKAGE'',''PACKAGE BODY'',''TRIGGER'')
       AND CREATED > SYSDATE - 7
       AND OWNER NOT IN (''SYS'',''SYSTEM'',''OUTLN'',''DBSNMP'',''APEX_PUBLIC_USER'')',
    '{"condition":"row_count > 0","description":"Procedure/function/trigger created within last 7 days by non-SYS account"}',
    'Verify if those objects appear in recent V$SQL executions',
    'SELECT sql_id, sql_text, executions, last_active_time
     FROM V$SQL
     WHERE (UPPER(sql_text) LIKE ''%EXECUTE %'' OR UPPER(sql_text) LIKE ''%CALL %'')
       AND last_active_time > SYSDATE - 1/24
       AND parsing_user_id NOT IN (SELECT user_id FROM dba_users WHERE username IN (''SYS'',''SYSTEM''))',
    '{"condition":"row_count > 0","description":"Recently created object was called in the last hour  -- potential backdoor execution"}'
  );

-- ------------------------------------------------------------
-- SEC-SQL-AUD-008  -- Risky Transaction Execution
-- ------------------------------------------------------------

-- RC01  -- Bulk data export / mass SELECT
  CALL add_path('SEC-SQL-AUD-008-RC01','postgresql',
    'Detect bulk data export on sensitive tables - PostgreSQL',
    'Identifies COPY TO or large-result SELECTs on tables matching sensitive naming patterns',
    'Check active COPY TO or high-row-count SELECT statements',
    'SELECT pid, usename, query, query_start, state
     FROM pg_stat_activity
     WHERE state = ''active''
       AND (query ~* ''COPY\s+.+\s+TO'' OR query ~* ''^\s*SELECT''
       AND query ~* ''(password|salary|credit_card|ssn|pii|secret|api_key|token)'')',
    '{"condition":"row_count > 0","description":"Active COPY TO or SELECT on sensitive table names"}',
    'Check pg_stat_statements for queries returning unusually high row counts',
    'SELECT query, calls, rows / NULLIF(calls,0) AS avg_rows_per_call, userid::regrole
     FROM pg_stat_statements
     WHERE rows / NULLIF(calls,0) > 10000
       AND query ~* ''(password|salary|credit|ssn|pii|api_key)''
     ORDER BY avg_rows_per_call DESC
     LIMIT 10',
    '{"condition":"row_count > 0","description":"Queries averaging >10,000 rows against sensitive tables  -- bulk export pattern"}'
  );

  CALL add_path('SEC-SQL-AUD-008-RC01','sqlserver',
    'Detect bulk data export on sensitive tables - SQL Server',
    'Finds BCP, BULK INSERT, or large SELECT statements on classified objects',
    'Check active requests for bulk export commands',
    'SELECT s.login_name, r.command, t.text, r.start_time, r.logical_reads
     FROM sys.dm_exec_sessions s
     JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
     CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
     WHERE (r.command IN (''BULK INSERT'',''INSERT ... SELECT'')
            OR t.text LIKE ''%OPENROWSET%'' OR t.text LIKE ''%BCP%'')
       AND r.logical_reads > 100000',
    '{"condition":"row_count > 0","description":"Bulk export command with high logical reads in progress"}',
    'Check Query Store for high-row-count SELECT history on sensitive tables',
    'SELECT qt.query_sql_text, rs.avg_rowcount, rs.count_executions, rs.last_execution_time
     FROM sys.query_store_query_text qt
     JOIN sys.query_store_query q ON q.query_text_id = qt.query_text_id
     JOIN sys.query_store_plan qp ON qp.query_id = q.query_id
     JOIN sys.query_store_runtime_stats rs ON rs.plan_id = qp.plan_id
     WHERE rs.avg_rowcount > 10000
       AND (qt.query_sql_text LIKE ''%salary%'' OR qt.query_sql_text LIKE ''%credential%''
            OR qt.query_sql_text LIKE ''%password%'' OR qt.query_sql_text LIKE ''%ssn%'')',
    '{"condition":"row_count > 0","description":"Historical evidence of mass row retrieval from sensitive tables"}'
  );

  CALL add_path('SEC-SQL-AUD-008-RC01','mysql',
    'Detect bulk data export on sensitive tables - MySQL',
    'Identifies SELECT INTO OUTFILE or large result-set queries in processlist',
    'Check processlist for SELECT INTO OUTFILE or sensitive table mass reads',
    'SELECT ID, USER, HOST, DB, TIME, INFO
     FROM INFORMATION_SCHEMA.PROCESSLIST
     WHERE COMMAND = ''Query''
       AND (INFO LIKE ''%INTO OUTFILE%'' OR INFO LIKE ''%INTO DUMPFILE%''
            OR (INFO REGEXP ''(password|salary|ssn|credit|api_key)'' AND INFO LIKE ''%SELECT%''))',
    '{"condition":"row_count > 0","description":"SELECT INTO OUTFILE or sensitive-table mass SELECT in progress"}',
    'Check performance_schema for high rows-sent digest',
    'SELECT DIGEST_TEXT, SUM_ROWS_SENT, SUM_ROWS_EXAMINED, COUNT_STAR, LAST_SEEN
     FROM performance_schema.events_statements_summary_by_digest
     WHERE SUM_ROWS_SENT / NULLIF(COUNT_STAR,0) > 10000
       AND DIGEST_TEXT REGEXP ''(password|salary|ssn|credit|api_key)''
     ORDER BY SUM_ROWS_SENT DESC
     LIMIT 10',
    '{"condition":"row_count > 0","description":"Digest shows queries returning >10k rows per execution from sensitive tables"}'
  );

  CALL add_path('SEC-SQL-AUD-008-RC01','oracle',
    'Detect bulk data export on sensitive tables - Oracle',
    'Detects Oracle Data Pump, UTL_FILE, or large-fetch sessions on sensitive objects',
    'Check V$SESSION for Data Pump or UTL_FILE programs accessing sensitive tables',
    'SELECT s.USERNAME, s.PROGRAM, s.MODULE, q.SQL_TEXT,
            s.LAST_CALL_ET, s.STATUS
     FROM V$SESSION s JOIN V$SQL q ON s.SQL_ID = q.SQL_ID
     WHERE (UPPER(s.PROGRAM) LIKE ''%EXPDP%'' OR UPPER(s.PROGRAM) LIKE ''%DATA_PUMP%''
            OR UPPER(q.SQL_TEXT) LIKE ''%UTL_FILE%'')
       AND s.TYPE = ''USER''',
    '{"condition":"row_count > 0","description":"Data Pump export or UTL_FILE write session active"}',
    'Check V$SQL for high-fetch-count queries against sensitive object names',
    'SELECT sql_id, sql_text, fetches, executions, rows_processed
     FROM V$SQL
     WHERE rows_processed / NULLIF(executions,0) > 10000
       AND (UPPER(sql_text) LIKE ''%PASSWORD%'' OR UPPER(sql_text) LIKE ''%SALARY%''
            OR UPPER(sql_text) LIKE ''%SSN%'' OR UPPER(sql_text) LIKE ''%API_KEY%'')
     ORDER BY rows_processed DESC
     FETCH FIRST 10 ROWS ONLY',
    '{"condition":"row_count > 0","description":"Queries returning >10k rows per execution from sensitive Oracle objects"}'
  );

-- RC02  -- Mass DELETE or TRUNCATE without WHERE
  CALL add_path('SEC-SQL-AUD-008-RC02','postgresql',
    'Detect mass DELETE or TRUNCATE without WHERE clause - PostgreSQL',
    'Finds active or recent DELETE/TRUNCATE statements lacking a WHERE predicate',
    'Check active queries for WHERE-less DELETE or TRUNCATE',
    'SELECT pid, usename, query, query_start, state
     FROM pg_stat_activity
     WHERE state IN (''active'',''idle in transaction'')
       AND (query ~* ''^\s*TRUNCATE\s+'' OR
            (query ~* ''^\s*DELETE\s+FROM'' AND query !~* ''\sWHERE\s''))',
    '{"condition":"row_count > 0","description":"TRUNCATE or WHERE-less DELETE is active or uncommitted"}',
    'Check table sizes for tables potentially targeted',
    'SELECT schemaname, relname, n_live_tup, n_dead_tup, last_autovacuum
     FROM pg_stat_user_tables
     WHERE n_live_tup > 10000
     ORDER BY n_live_tup DESC
     LIMIT 20',
    '{"condition":"row_count > 0","description":"Large tables exist that would cause significant data loss if truncated"}'
  );

  CALL add_path('SEC-SQL-AUD-008-RC02','sqlserver',
    'Detect mass DELETE or TRUNCATE without WHERE - SQL Server',
    'Uses DMVs to find running DELETE or TRUNCATE without predicates',
    'Check active requests for WHERE-less DELETE or TRUNCATE TABLE',
    'SELECT s.login_name, r.command, t.text, r.start_time, r.row_count
     FROM sys.dm_exec_sessions s
     JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
     CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
     WHERE (r.command = ''DELETE'' AND t.text NOT LIKE ''%WHERE%'')
        OR r.command = ''TRUNCATE TABLE''',
    '{"condition":"row_count > 0","description":"TRUNCATE or WHERE-less DELETE is currently executing"}',
    'Check if the target table holds significant row count',
    'SELECT t.name AS table_name, SUM(p.rows) AS row_count
     FROM sys.tables t
     JOIN sys.indexes i ON i.object_id = t.object_id AND i.index_id <= 1
     JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id = i.index_id
     WHERE t.name IN (
         SELECT PARSENAME(t2.text, 1)
         FROM sys.dm_exec_requests r2
         CROSS APPLY sys.dm_exec_sql_text(r2.sql_handle) t2
         WHERE r2.command IN (''DELETE'',''TRUNCATE TABLE'')
     )
     GROUP BY t.name HAVING SUM(p.rows) > 1000',
    '{"condition":"row_count > 0","description":"Target table has significant row count  -- mass deletion would cause major data loss"}'
  );

  CALL add_path('SEC-SQL-AUD-008-RC02','mysql',
    'Detect mass DELETE or TRUNCATE without WHERE - MySQL',
    'Identifies WHERE-less DELETE or TRUNCATE in processlist',
    'Check PROCESSLIST for WHERE-less DELETE or TRUNCATE',
    'SELECT ID, USER, HOST, DB, TIME, INFO
     FROM INFORMATION_SCHEMA.PROCESSLIST
     WHERE COMMAND = ''Query''
       AND (INFO REGEXP ''^\\s*TRUNCATE'' OR
            (INFO REGEXP ''^\\s*DELETE\\s+FROM'' AND INFO NOT REGEXP ''\\sWHERE\\s''))',
    '{"condition":"row_count > 0","description":"TRUNCATE or WHERE-less DELETE actively running"}',
    'Check table row counts for targeted tables',
    'SELECT TABLE_SCHEMA, TABLE_NAME, TABLE_ROWS, DATA_LENGTH
     FROM INFORMATION_SCHEMA.TABLES
     WHERE TABLE_ROWS > 10000
       AND TABLE_SCHEMA NOT IN (''information_schema'',''performance_schema'',''mysql'',''sys'')',
    '{"condition":"row_count > 0","description":"Large tables at risk of mass deletion exist in database"}'
  );

  CALL add_path('SEC-SQL-AUD-008-RC02','oracle',
    'Detect mass DELETE or TRUNCATE without WHERE - Oracle',
    'Uses V$SQL to find DELETE without WHERE predicate or TRUNCATE TABLE',
    'Check V$SQL for TRUNCATE or WHERE-less DELETE',
    'SELECT s.USERNAME, q.SQL_TEXT, q.EXECUTIONS, s.LAST_CALL_ET
     FROM V$SESSION s JOIN V$SQL q ON s.SQL_ID = q.SQL_ID
     WHERE (UPPER(q.SQL_TEXT) LIKE ''TRUNCATE TABLE %''
            OR (UPPER(q.SQL_TEXT) LIKE ''DELETE FROM %'' AND UPPER(q.SQL_TEXT) NOT LIKE ''%WHERE%''))
       AND s.STATUS = ''ACTIVE''',
    '{"condition":"row_count > 0","description":"TRUNCATE or WHERE-less DELETE is actively executing"}',
    'Check row counts of targeted tables',
    'SELECT OWNER, SEGMENT_NAME, BLOCKS * 8192 / 1024 / 1024 AS size_mb
     FROM DBA_SEGMENTS
     WHERE SEGMENT_TYPE = ''TABLE''
       AND BLOCKS > 1000
       AND OWNER NOT IN (''SYS'',''SYSTEM'',''OUTLN'')
     ORDER BY BLOCKS DESC
     FETCH FIRST 20 ROWS ONLY',
    '{"condition":"row_count > 0","description":"Large table segments exist  -- truncation risk is high"}'
  );

-- RC03  -- DDL in production by non-DBA accounts
  CALL add_path('SEC-SQL-AUD-008-RC03','postgresql',
    'Detect DDL executed in production by non-DBA accounts - PostgreSQL',
    'Finds CREATE, ALTER, DROP statements run by accounts without DBA role',
    'Check active DDL statements by non-superuser accounts',
    'SELECT pid, usename, query, query_start, client_addr
     FROM pg_stat_activity
     WHERE state = ''active''
       AND query ~* ''^\s*(CREATE|ALTER|DROP)\s+(TABLE|INDEX|VIEW|SEQUENCE|FUNCTION|PROCEDURE|TRIGGER|SCHEMA|DATABASE)''
       AND usename NOT IN (SELECT rolname FROM pg_roles WHERE rolsuper = true OR rolcreatedb = true)',
    '{"condition":"row_count > 0","description":"Non-superuser account executing DDL statement in production"}',
    'Check if the account holds DDL-permitting roles',
    'SELECT r.rolname AS account, g.rolname AS granted_role
     FROM pg_roles r
     JOIN pg_auth_members m ON m.member = r.oid
     JOIN pg_roles g ON g.oid = m.roleid
     WHERE r.rolname IN (
         SELECT usename FROM pg_stat_activity
         WHERE query ~* ''^\s*(CREATE|ALTER|DROP)'' AND state = ''active''
     )',
    '{"condition":"row_count = 0","description":"Account has no DBA roles yet is executing DDL  -- change-control violation"}'
  );

  CALL add_path('SEC-SQL-AUD-008-RC03','sqlserver',
    'Detect DDL in production by non-DBA accounts - SQL Server',
    'Identifies CREATE/ALTER/DROP statements from non-sysadmin logins',
    'Check active DDL requests from non-sysadmin logins',
    'SELECT s.login_name, r.command, t.text, r.start_time, DB_NAME(r.database_id) AS db_name
     FROM sys.dm_exec_sessions s
     JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
     CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
     WHERE r.command IN (''CREATE TABLE'',''ALTER TABLE'',''DROP TABLE'',
                         ''CREATE INDEX'',''DROP INDEX'',''CREATE VIEW'',
                         ''ALTER PROCEDURE'',''CREATE PROCEDURE'',''DROP PROCEDURE'')
       AND IS_SRVROLEMEMBER(''sysadmin'', s.login_name) = 0
       AND IS_MEMBER(''db_ddladmin'') = 0',
    '{"condition":"row_count > 0","description":"DDL executed by account without sysadmin or db_ddladmin role"}',
    'Check if the login holds any DDL-enabling database roles',
    'SELECT dp.name AS login, drm.role_principal_id,
            dp2.name AS role_name
     FROM sys.database_principals dp
     JOIN sys.database_role_members drm ON drm.member_principal_id = dp.principal_id
     JOIN sys.database_principals dp2 ON dp2.principal_id = drm.role_principal_id
     WHERE dp.name IN (
         SELECT s2.login_name FROM sys.dm_exec_sessions s2
         JOIN sys.dm_exec_requests r2 ON r2.session_id = s2.session_id
         WHERE r2.command LIKE ''%CREATE%'' OR r2.command LIKE ''%ALTER%'' OR r2.command LIKE ''%DROP%''
     )',
    '{"condition":"row_count = 0","description":"No DDL roles found for this account  -- production DDL executed without authorization"}'
  );

  CALL add_path('SEC-SQL-AUD-008-RC03','mysql',
    'Detect DDL in production by non-DBA accounts - MySQL',
    'Identifies CREATE/ALTER/DROP in processlist from non-privileged users',
    'Check PROCESSLIST for DDL by non-admin users',
    'SELECT p.ID, p.USER, p.HOST, p.DB, p.TIME, p.INFO
     FROM INFORMATION_SCHEMA.PROCESSLIST p
     WHERE p.COMMAND = ''Query''
       AND p.INFO REGEXP ''^\s*(CREATE|ALTER|DROP)\s+(TABLE|INDEX|VIEW|DATABASE|PROCEDURE|FUNCTION|TRIGGER)''
       AND p.USER NOT IN (
           SELECT DISTINCT grantee
           FROM INFORMATION_SCHEMA.USER_PRIVILEGES
           WHERE PRIVILEGE_TYPE IN (''SUPER'',''CREATE'',''ALTER'',''DROP'',''ALL PRIVILEGES'')
       )',
    '{"condition":"row_count > 0","description":"DDL executed by account without explicit DDL privileges"}',
    'Verify the account holds no schema-level DDL grants',
    'SELECT GRANTEE, TABLE_SCHEMA, PRIVILEGE_TYPE
     FROM INFORMATION_SCHEMA.SCHEMA_PRIVILEGES
     WHERE PRIVILEGE_TYPE IN (''CREATE'',''ALTER'',''DROP'',''INDEX'')
       AND GRANTEE IN (
           SELECT CONCAT('''''''',USER,'''''''',''@'','''''',HOST,'''''''')
           FROM INFORMATION_SCHEMA.PROCESSLIST
           WHERE INFO REGEXP ''^\s*(CREATE|ALTER|DROP)''
       )',
    '{"condition":"row_count = 0","description":"No schema-level DDL grant found  -- unauthorized DDL execution in production confirmed"}'
  );

  CALL add_path('SEC-SQL-AUD-008-RC03','oracle',
    'Detect DDL in production by non-DBA accounts - Oracle',
    'Uses DBA_AUDIT_TRAIL and V$SQL to find DDL from non-DBA users',
    'Check DBA_AUDIT_TRAIL for recent DDL by non-DBA accounts',
    'SELECT DB_USER, ACTION_NAME, OBJ_OWNER, OBJ_NAME, TIMESTAMP
     FROM DBA_AUDIT_TRAIL
     WHERE ACTION_NAME IN (''CREATE TABLE'',''ALTER TABLE'',''DROP TABLE'',
                           ''CREATE INDEX'',''DROP INDEX'',''CREATE VIEW'',
                           ''CREATE PROCEDURE'',''ALTER PROCEDURE'',''DROP PROCEDURE'')
       AND DB_USER NOT IN (SELECT GRANTEE FROM DBA_ROLE_PRIVS WHERE GRANTED_ROLE = ''DBA'')
       AND TIMESTAMP > SYSDATE - 1/24',
    '{"condition":"row_count > 0","description":"DDL executed by non-DBA account in the last hour per audit trail"}',
    'Verify whether user holds CREATE ANY TABLE or ALTER ANY TABLE system privilege',
    'SELECT GRANTEE, PRIVILEGE, ADMIN_OPTION
     FROM DBA_SYS_PRIVS
     WHERE PRIVILEGE IN (''CREATE ANY TABLE'',''ALTER ANY TABLE'',''DROP ANY TABLE'',
                         ''CREATE ANY INDEX'',''CREATE ANY PROCEDURE'')
       AND GRANTEE IN (
           SELECT DB_USER FROM DBA_AUDIT_TRAIL
           WHERE ACTION_NAME LIKE ''%TABLE%'' OR ACTION_NAME LIKE ''%INDEX%''
           AND TIMESTAMP > SYSDATE - 1/24
       )',
    '{"condition":"row_count > 0","description":"Non-DBA account holds ANY DDL privilege  -- change-control bypass confirmed"}'
  );

-- RC04  -- Transactions accessing credential/encryption key tables
  CALL add_path('SEC-SQL-AUD-008-RC04','postgresql',
    'Detect access to credential or encryption key tables - PostgreSQL',
    'Identifies queries touching tables whose names or comments indicate credential or key storage',
    'Scan active queries for credential/key table access',
    'SELECT pid, usename, query, query_start, state
     FROM pg_stat_activity
     WHERE state = ''active''
       AND query ~* ''(api_key|secret_key|enc_key|master_key|password_hash|user_credential|token_store|vault|keyring)''
       AND usename NOT IN (SELECT rolname FROM pg_roles WHERE rolname ~* ''(keymgmt|vault|hsm|crypto)'')',
    '{"condition":"row_count > 0","description":"Non-key-management account accessing credential or key table names"}',
    'Confirm those tables exist and are tagged sensitive',
    'SELECT c.relname, n.nspname, obj_description(c.oid) AS comment
     FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE c.relname ~* ''(api_key|secret_key|enc_key|master_key|password_hash|token_store|vault|keyring)''
       AND c.relkind = ''r''',
    '{"condition":"row_count > 0","description":"Credential/key tables confirmed to exist  -- access by non-authorized account is high-risk"}'
  );

  CALL add_path('SEC-SQL-AUD-008-RC04','sqlserver',
    'Detect access to credential or encryption key tables - SQL Server',
    'Uses DMVs to find queries touching key-vault or credential objects',
    'Check active queries for credential/key object names',
    'SELECT s.login_name, t.text, r.start_time
     FROM sys.dm_exec_sessions s
     JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
     CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
     WHERE t.text LIKE ''%api_key%'' OR t.text LIKE ''%secret_key%''
        OR t.text LIKE ''%enc_key%''  OR t.text LIKE ''%master_key%''
        OR t.text LIKE ''%credential%'' OR t.text LIKE ''%token_store%''',
    '{"condition":"row_count > 0","description":"Active query references credential or encryption key object names"}',
    'Check sys.symmetric_keys and sys.certificates for matching objects',
    'SELECT name, symmetric_key_id, key_algorithm, key_length, create_date
     FROM sys.symmetric_keys
     UNION ALL
     SELECT name, certificate_id, subject, key_length, create_date
     FROM sys.certificates',
    '{"condition":"row_count > 0","description":"Encryption keys and certificates exist in database  -- access by unauthorized session confirmed"}'
  );

  CALL add_path('SEC-SQL-AUD-008-RC04','mysql',
    'Detect access to credential or encryption key tables - MySQL',
    'Finds processlist entries referencing key or credential table names',
    'Check PROCESSLIST for queries on credential/key tables',
    'SELECT ID, USER, HOST, DB, TIME, INFO
     FROM INFORMATION_SCHEMA.PROCESSLIST
     WHERE COMMAND = ''Query''
       AND INFO REGEXP ''(api_key|secret_key|enc_key|master_key|password_hash|token_store|vault|keyring|credential)''
       AND USER NOT REGEXP ''(keymgmt|vault|hsm|crypto|keyring_plugin)''',
    '{"condition":"row_count > 0","description":"Non-key-management account querying credential or key table"}',
    'Verify keyring plugin status and key table existence',
    'SELECT PLUGIN_NAME, PLUGIN_STATUS, PLUGIN_TYPE
     FROM INFORMATION_SCHEMA.PLUGINS
     WHERE PLUGIN_NAME LIKE ''keyring%''
     -- second query:
     SELECT TABLE_SCHEMA, TABLE_NAME
     FROM INFORMATION_SCHEMA.TABLES
     WHERE TABLE_NAME REGEXP ''(api_key|secret_key|enc_key|master_key|token_store|credential)''',
    '{"condition":"row_count > 0","description":"Keyring plugin active or credential tables confirmed  -- unauthorized access is high-risk"}'
  );

  CALL add_path('SEC-SQL-AUD-008-RC04','oracle',
    'Detect access to credential or encryption key tables - Oracle',
    'Uses V$SQL and DBA_OBJECTS to detect access to TDE or application credential objects',
    'Check V$SQL for queries on credential/key object names',
    'SELECT s.USERNAME, q.SQL_TEXT, q.EXECUTIONS, s.STATUS
     FROM V$SESSION s JOIN V$SQL q ON s.SQL_ID = q.SQL_ID
     WHERE (UPPER(q.SQL_TEXT) LIKE ''%API_KEY%'' OR UPPER(q.SQL_TEXT) LIKE ''%SECRET_KEY%''
            OR UPPER(q.SQL_TEXT) LIKE ''%ENC_KEY%''  OR UPPER(q.SQL_TEXT) LIKE ''%MASTER_KEY%''
            OR UPPER(q.SQL_TEXT) LIKE ''%WALLET%''    OR UPPER(q.SQL_TEXT) LIKE ''%CREDENTIAL%'')
       AND s.USERNAME NOT IN (SELECT GRANTEE FROM DBA_ROLE_PRIVS WHERE GRANTED_ROLE = ''DBA'')',
    '{"condition":"row_count > 0","description":"Non-DBA session accessing TDE wallet or application credential objects"}',
    'Check TDE wallet status and encryption key objects',
    'SELECT * FROM V$ENCRYPTION_WALLET
     -- second query:
     SELECT KEY_ID, CREATOR, KEY_USE, STATUS FROM V$ENCRYPTION_KEYS',
    '{"condition":"row_count > 0","description":"TDE keys exist in wallet  -- unauthorized access by non-DBA session is critical risk"}'
  );

-- RC05  -- Cross-schema transactions outside application scope
  CALL add_path('SEC-SQL-AUD-008-RC05','postgresql',
    'Detect cross-schema transactions outside application scope - PostgreSQL',
    'Finds queries joining tables from schemas the application is not expected to combine',
    'Check active queries for multi-schema joins not matching known patterns',
    'SELECT pid, usename, query, query_start
     FROM pg_stat_activity
     WHERE state = ''active''
       AND query ~* ''\w+\.\w+.*JOIN.*\w+\.\w+''
       AND query !~* ''(pg_catalog|information_schema|pg_toast)''
       AND usename NOT IN (SELECT rolname FROM pg_roles WHERE rolsuper = true)',
    '{"condition":"row_count > 0","description":"Non-superuser executing cross-schema JOIN  -- verify application scope"}',
    'List schema pairs referenced in the query vs expected schema pairs',
    'SELECT DISTINCT n.nspname AS schema_name
     FROM pg_namespace n
     JOIN pg_class c ON c.relnamespace = n.oid
     JOIN pg_depend d ON d.refobjid = c.oid
     WHERE n.nspname NOT IN (''pg_catalog'',''information_schema'',''public'')
     ORDER BY 1',
    '{"condition":"row_count > 1","description":"Multiple application schemas exist  -- cross-schema join access needs validation"}'
  );

  CALL add_path('SEC-SQL-AUD-008-RC05','sqlserver',
    'Detect cross-schema transactions outside application scope - SQL Server',
    'Identifies queries referencing multiple schemas via three-part or four-part naming',
    'Check active queries for cross-schema three/four-part names',
    'SELECT s.login_name, t.text, r.start_time, DB_NAME(r.database_id) AS db
     FROM sys.dm_exec_sessions s
     JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
     CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
     WHERE t.text LIKE ''%].[%].[%''
        OR (t.text LIKE ''% dbo.% '' AND t.text LIKE ''% hr.% '')
        OR (t.text LIKE ''% dbo.% '' AND t.text LIKE ''% finance.% '')',
    '{"condition":"row_count > 0","description":"Query references multiple non-standard schemas simultaneously"}',
    'List all schemas in the database and their expected owners',
    'SELECT s.name AS schema_name, dp.name AS owner, COUNT(o.object_id) AS object_count
     FROM sys.schemas s
     JOIN sys.database_principals dp ON dp.principal_id = s.principal_id
     LEFT JOIN sys.objects o ON o.schema_id = s.schema_id
     WHERE s.name NOT IN (''dbo'',''sys'',''INFORMATION_SCHEMA'',''guest'')
     GROUP BY s.name, dp.name',
    '{"condition":"row_count > 1","description":"Multiple non-standard schemas exist  -- cross-schema access requires authorization review"}'
  );

  CALL add_path('SEC-SQL-AUD-008-RC05','mysql',
    'Detect cross-schema transactions outside application scope - MySQL',
    'Finds queries referencing multiple databases in the same statement',
    'Check PROCESSLIST for cross-database queries',
    'SELECT ID, USER, HOST, DB, TIME, INFO
     FROM INFORMATION_SCHEMA.PROCESSLIST
     WHERE COMMAND = ''Query''
       AND INFO REGEXP ''[a-zA-Z_]+\.[a-zA-Z_]+\.[a-zA-Z_]+''
       AND INFO NOT REGEXP ''(information_schema|performance_schema|sys\.)''',
    '{"condition":"row_count > 0","description":"Query uses three-part database.table notation across multiple schemas"}',
    'List all user-created databases on the server',
    'SELECT SCHEMA_NAME, DEFAULT_CHARACTER_SET_NAME
     FROM INFORMATION_SCHEMA.SCHEMATA
     WHERE SCHEMA_NAME NOT IN (''information_schema'',''performance_schema'',''mysql'',''sys'')',
    '{"condition":"row_count > 1","description":"Multiple user databases exist  -- cross-database JOIN access requires scope review"}'
  );

  CALL add_path('SEC-SQL-AUD-008-RC05','oracle',
    'Detect cross-schema transactions outside application scope - Oracle',
    'Uses V$SQL to find queries joining objects across multiple non-related schemas',
    'Check V$SQL for queries referencing multiple owner schemas',
    'SELECT s.USERNAME, q.SQL_TEXT, q.EXECUTIONS, q.LAST_ACTIVE_TIME
     FROM V$SESSION s JOIN V$SQL q ON s.SQL_ID = q.SQL_ID
     WHERE s.TYPE = ''USER'' AND s.STATUS = ''ACTIVE''
       AND (SELECT COUNT(DISTINCT OWNER)
            FROM DBA_OBJECTS
            WHERE OBJECT_NAME = ANY(
                SELECT REGEXP_SUBSTR(UPPER(q.SQL_TEXT),''[A-Z_][A-Z0-9_]+'', 1, LEVEL)
                FROM DUAL
                CONNECT BY LEVEL <= REGEXP_COUNT(UPPER(q.SQL_TEXT),''[A-Z_][A-Z0-9_]+'')
            )
            AND OBJECT_TYPE = ''TABLE''
            AND OWNER NOT IN (''SYS'',''SYSTEM'')
       ) > 2',
    '{"condition":"row_count > 0","description":"Query references tables from more than 2 non-SYS schemas simultaneously"}',
    'List schema owners and their expected applications',
    'SELECT USERNAME, ACCOUNT_STATUS, PROFILE, CREATED
     FROM DBA_USERS
     WHERE USERNAME NOT IN (''SYS'',''SYSTEM'',''OUTLN'',''DBSNMP'',''APEX_PUBLIC_USER'',''ANONYMOUS'')
       AND ACCOUNT_STATUS = ''OPEN''
     ORDER BY CREATED',
    '{"condition":"row_count > 2","description":"Multiple open application schemas exist  -- cross-schema access outside app scope is high-risk"}'
  );

END;
$BODY$;

DROP PROCEDURE IF EXISTS add_path(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT);

COMMIT;
