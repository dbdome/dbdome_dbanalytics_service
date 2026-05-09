-- ============================================================
-- Resolution paths + steps for SEC-SQL-AUD-009 through SEC-SQL-AUD-014
-- Covers all root causes RC01-RC05 across postgresql, sqlserver,
-- mysql, oracle.  120 resolution paths total.
-- ============================================================
SET client_encoding = 'UTF8';
BEGIN;

CREATE OR REPLACE PROCEDURE rootcause.add_resolution_path(
  rc_id     TEXT, vslug     TEXT,
  path_name TEXT, path_slug TEXT, path_desc TEXT, path_risk TEXT,
  s1_name   TEXT, s1_type   TEXT, s1_action TEXT, s1_risk   TEXT, s1_rev BOOLEAN,
  s2_name   TEXT, s2_type   TEXT, s2_action TEXT, s2_risk   TEXT, s2_rev BOOLEAN
) LANGUAGE plpgsql AS $$
DECLARE ls1 INT; ls2 INT; lp INT;
BEGIN
  INSERT INTO rootcause.resolution_steps
    (vendor_slug, step_type, name, content, risk_level, is_reversible)
  VALUES (vslug, s1_type, s1_name, jsonb_build_object('action', s1_action), s1_risk, s1_rev)
  ON CONFLICT (vendor_slug, name) DO UPDATE SET content = EXCLUDED.content
  RETURNING id INTO ls1;

  INSERT INTO rootcause.resolution_steps
    (vendor_slug, step_type, name, content, risk_level, is_reversible)
  VALUES (vslug, s2_type, s2_name, jsonb_build_object('action', s2_action), s2_risk, s2_rev)
  ON CONFLICT (vendor_slug, name) DO UPDATE SET content = EXCLUDED.content
  RETURNING id INTO ls2;

  INSERT INTO rootcause.resolution_paths
    (root_cause_id, vendor_slug, name, slug, description,
     risk_level, execution_mode, status, is_active)
  VALUES (rc_id, vslug, path_name, path_slug, path_desc,
          path_risk, 'supervised', 'authored', true)
  ON CONFLICT (root_cause_id, vendor_slug, name)
  DO UPDATE SET description = EXCLUDED.description
  RETURNING id INTO lp;

  INSERT INTO rootcause.resolution_path_steps
    (resolution_path_id, resolution_step_id, step_order, on_success, on_failure)
  VALUES
    (lp, ls1, 1, 'next',     'stop'),
    (lp, ls2, 2, 'complete', 'stop')
  ON CONFLICT (resolution_path_id, step_order) DO NOTHING;
END;
$$;

DO $BODY$
BEGIN

-- ============================================================
-- SEC-SQL-AUD-009-RC01  Tautology patterns in active query
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-009-RC01', 'postgresql',
    'Terminate SQL injection tautology session - PostgreSQL',
    'aud-009-rc01-terminate-tautology-pg',
    'Immediately terminate the session containing tautology-based SQL injection patterns and escalate for application-layer remediation of the injection vector.',
    'critical',
    'AUD-009-RC01: Terminate tautology injection session - PostgreSQL', 'immediate',
    'Terminate the session: SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid = <target_pid>. Record the full query text from pg_stat_activity.query, client_addr, usename, and application_name for the incident report before terminating.',
    'high', false,
    'AUD-009-RC01: Enforce parameterised queries and WAF rule - PostgreSQL', 'remediate',
    'Review the application code path that generated the query. Replace any dynamic SQL concatenation with parameterised queries using prepared statements. Deploy a WAF rule blocking OR 1=1 and equivalent tautology patterns. Enable pg_audit to log all future SELECT statements from this application role.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-009-RC01', 'sqlserver',
    'Terminate SQL injection tautology session - SQL Server',
    'aud-009-rc01-terminate-tautology-sqlserver',
    'Kill the session containing tautology SQL injection patterns and remediate the injection vector in the application layer.',
    'critical',
    'AUD-009-RC01: Kill tautology injection session - SQL Server', 'immediate',
    'Kill the session: KILL <spid>. Before killing capture sys.dm_exec_sessions joined with sys.dm_exec_sql_text to preserve the exact SQL text, login_name, host_name, and program_name for forensic analysis.',
    'high', false,
    'AUD-009-RC01: Replace dynamic SQL with parameterised queries - SQL Server', 'remediate',
    'Identify the stored procedure or application code using string concatenation. Replace with sp_executesql parameterised calls or ORM prepared statements. Enable SQL Server Audit to capture SELECT events from the affected login. Add an Extended Events session capturing queries containing OR 1=1 patterns.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-009-RC01', 'mysql',
    'Terminate SQL injection tautology session - MySQL',
    'aud-009-rc01-terminate-tautology-mysql',
    'Kill the thread containing tautology SQL injection patterns and enforce parameterised queries in the application.',
    'critical',
    'AUD-009-RC01: Kill tautology injection thread - MySQL', 'immediate',
    'Kill the thread: KILL <process_id>. Record USER, HOST, DB, TIME, and INFO from INFORMATION_SCHEMA.PROCESSLIST before killing. Preserve the query text as forensic evidence for the incident record.',
    'high', false,
    'AUD-009-RC01: Enforce prepared statements and audit filter - MySQL', 'remediate',
    'Replace dynamic SQL in the application with prepared statements using PDO or the MySQL Connector with parameterised queries. Enable the MySQL Enterprise Audit plugin or audit_log plugin with a filter capturing queries from the affected user. Add a connection_control plugin rule to throttle repeated failed authentication from the source IP.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-009-RC01', 'oracle',
    'Terminate SQL injection tautology session - Oracle',
    'aud-009-rc01-terminate-tautology-oracle',
    'Kill the session containing tautology SQL injection patterns and enforce bind variables throughout the application.',
    'critical',
    'AUD-009-RC01: Kill tautology injection session - Oracle', 'immediate',
    'Kill the session: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE. Capture V$SQL SQL_TEXT, V$SESSION USERNAME, OSUSER, MACHINE, and PROGRAM before killing to preserve incident evidence.',
    'high', false,
    'AUD-009-RC01: Enforce bind variables and enable SQL Firewall - Oracle', 'remediate',
    'Audit the application for any EXECUTE IMMEDIATE or DBMS_SQL calls using string concatenation and replace with bind variable equivalents. Enable Oracle SQL Firewall to create an allow-list of approved SQL signatures for the application account. Add a Unified Audit policy capturing all SQL by the affected user for 30 days post-incident.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-009-RC02  Stacked / chained query execution
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-009-RC02', 'postgresql',
    'Terminate stacked query injection session - PostgreSQL',
    'aud-009-rc02-terminate-stacked-query-pg',
    'Terminate the session executing stacked SQL injection queries and disable multi-statement execution in the application driver.',
    'critical',
    'AUD-009-RC02: Terminate stacked query session - PostgreSQL', 'immediate',
    'Terminate: SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid = <target_pid>. Capture the full query string showing multiple statement terminators from pg_stat_activity.query. Note client_addr and application_name.',
    'high', false,
    'AUD-009-RC02: Disable multi-statement execution in application driver - PostgreSQL', 'remediate',
    'Configure the application database driver to use simple query protocol which disallows multiple statements per call. In libpq-based drivers set the connection to use extended query protocol exclusively. Review all EXECUTE and dynamic SQL paths for concatenation vulnerabilities. Enable pgaudit to log all DDL and DML for the affected role.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-009-RC02', 'sqlserver',
    'Terminate stacked query injection session - SQL Server',
    'aud-009-rc02-terminate-stacked-query-sqlserver',
    'Kill the session executing stacked SQL injection and restrict the login to parameterised stored procedure calls only.',
    'critical',
    'AUD-009-RC02: Kill stacked query session - SQL Server', 'immediate',
    'Kill the session: KILL <spid>. Capture the full batch text from sys.dm_exec_sql_text showing semicolon-separated statement chains. Record login_name, host_name, and start_time.',
    'high', false,
    'AUD-009-RC02: Restrict to stored procedure execution and audit - SQL Server', 'remediate',
    'Revoke EXECUTE permission on ad-hoc SQL for the application login. Grant EXECUTE only on specific signed stored procedures. Enable SQL Server Audit event SELECT, INSERT, UPDATE, DELETE on the affected database for this login. Review connection string for MultipleActiveResultSets=True which may enable stacked execution.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-009-RC02', 'mysql',
    'Terminate stacked query injection session - MySQL',
    'aud-009-rc02-terminate-stacked-query-mysql',
    'Kill the thread executing stacked SQL injection and ensure the application uses prepared statements that prevent multi-statement injection.',
    'critical',
    'AUD-009-RC02: Kill stacked query thread - MySQL', 'immediate',
    'Kill the thread: KILL <process_id>. Record INFORMATION_SCHEMA.PROCESSLIST INFO to preserve the stacked query payload. Note USER and HOST for the incident record.',
    'high', false,
    'AUD-009-RC02: Disable multi-statement support in connector - MySQL', 'remediate',
    'Ensure the MySQL connector does not use CLIENT_MULTI_STATEMENTS flag unless explicitly required. Migrate dynamic queries to prepared statements. Enable the audit_log plugin with a filter for multi-statement batches. Review all application code paths for string concatenation in query construction.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-009-RC02', 'oracle',
    'Terminate stacked query injection session - Oracle',
    'aud-009-rc02-terminate-stacked-query-oracle',
    'Kill the session executing stacked SQL injection and enforce bind variables with single-statement execution in the application.',
    'critical',
    'AUD-009-RC02: Kill stacked query session - Oracle', 'immediate',
    'Kill the session: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE. Retrieve SQL_TEXT from V$SQL for the offending SQL_ID. Record V$SESSION USERNAME, PROGRAM, and MACHINE.',
    'high', false,
    'AUD-009-RC02: Enforce single-statement execution and SQL Firewall - Oracle', 'remediate',
    'Audit application use of DBMS_SQL.PARSE for multi-statement strings and replace with single bind-variable statements. Enable Oracle SQL Firewall in learning mode for the application account to build an approved SQL allow-list, then enforce it in blocking mode. Add a Unified Audit policy on the affected schema owner.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-009-RC03  UNION-based probing
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-009-RC03', 'postgresql',
    'Terminate UNION injection probing session - PostgreSQL',
    'aud-009-rc03-terminate-union-probe-pg',
    'Terminate the session performing UNION-based SQL injection and harden the application against column-count and type probing.',
    'critical',
    'AUD-009-RC03: Terminate UNION probe session - PostgreSQL', 'immediate',
    'Terminate: SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid = <target_pid>. Capture the UNION SELECT query from pg_stat_activity.query to identify which catalog tables or data columns were targeted.',
    'high', false,
    'AUD-009-RC03: Parameterise queries and restrict catalog access - PostgreSQL', 'remediate',
    'Replace all dynamic query construction with parameterised prepared statements. Revoke USAGE on information_schema from the application role if not required. Enable pg_audit with log = ''read'' to detect future catalog enumeration. Review application error messages to ensure column count and type errors are not returned to clients.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-009-RC03', 'sqlserver',
    'Terminate UNION injection probing session - SQL Server',
    'aud-009-rc03-terminate-union-probe-sqlserver',
    'Kill the session performing UNION-based SQL injection and restrict the login from accessing system catalog views.',
    'critical',
    'AUD-009-RC03: Kill UNION probe session - SQL Server', 'immediate',
    'Kill the session: KILL <spid>. Capture the UNION SELECT text from sys.dm_exec_sql_text. Note which system views (sys.objects, sys.columns, INFORMATION_SCHEMA) were referenced in the UNION arms.',
    'high', false,
    'AUD-009-RC03: Restrict catalog view access and parameterise - SQL Server', 'remediate',
    'Revoke VIEW DEFINITION and SELECT on INFORMATION_SCHEMA and sys schema views from the application login. Enforce stored procedure-only access for application queries. Configure SQL Server Audit to alert on UNION keyword in statements from application logins. Suppress detailed error messages at the application tier.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-009-RC03', 'mysql',
    'Terminate UNION injection probing session - MySQL',
    'aud-009-rc03-terminate-union-probe-mysql',
    'Kill the thread performing UNION-based SQL injection and restrict access to information_schema tables.',
    'critical',
    'AUD-009-RC03: Kill UNION probe thread - MySQL', 'immediate',
    'Kill the thread: KILL <process_id>. Preserve the UNION SELECT payload from INFORMATION_SCHEMA.PROCESSLIST INFO. Note which schema tables were targeted in the UNION arms.',
    'high', false,
    'AUD-009-RC03: Restrict information_schema access and enforce prepared statements - MySQL', 'remediate',
    'Revoke SELECT on information_schema from the application user. Ensure the application uses prepared statements exclusively. Enable audit_log plugin filtering on UNION keyword queries from the application account. Set sql_mode to STRICT_TRANS_TABLES to reduce information leakage via error messages.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-009-RC03', 'oracle',
    'Terminate UNION injection probing session - Oracle',
    'aud-009-rc03-terminate-union-probe-oracle',
    'Kill the session performing UNION-based SQL injection and restrict access to data dictionary views.',
    'critical',
    'AUD-009-RC03: Kill UNION probe session - Oracle', 'immediate',
    'Kill the session: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE. Retrieve V$SQL SQL_TEXT to identify which ALL_ or DBA_ dictionary views were probed in UNION SELECT arms.',
    'high', false,
    'AUD-009-RC03: Restrict dictionary access and enable SQL Firewall - Oracle', 'remediate',
    'Revoke SELECT on SYS.USER_TABLES, ALL_TABLES, and ALL_COLUMNS from the application schema if not required. Enable Oracle SQL Firewall allow-list enforcement for the application account. Set O7_DICTIONARY_ACCESSIBILITY = FALSE to prevent non-SYS users accessing SYS-owned objects. Review application error handling to suppress ORA- messages containing schema details.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-009-RC04  Time-delay injection functions
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-009-RC04', 'postgresql',
    'Terminate time-delay SQL injection session - PostgreSQL',
    'aud-009-rc04-terminate-timedelay-pg',
    'Terminate the session using pg_sleep or similar time-delay functions for blind SQL injection and set a statement timeout to prevent future abuse.',
    'critical',
    'AUD-009-RC04: Terminate time-delay injection session - PostgreSQL', 'immediate',
    'Terminate: SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid = <target_pid>. Note query containing pg_sleep() call, client_addr, and query_start timestamp to determine injection duration and baseline response-time attack pattern.',
    'high', false,
    'AUD-009-RC04: Set statement_timeout and restrict pg_sleep - PostgreSQL', 'remediate',
    'Set a statement timeout on the application role: ALTER ROLE <app_role> SET statement_timeout = ''5s''. Revoke EXECUTE on pg_sleep from PUBLIC if not required: REVOKE EXECUTE ON FUNCTION pg_sleep(float8) FROM PUBLIC. Enforce parameterised queries in the application. Add pg_audit logging on all function calls from the application role.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-009-RC04', 'sqlserver',
    'Terminate time-delay SQL injection session - SQL Server',
    'aud-009-rc04-terminate-timedelay-sqlserver',
    'Kill the session using WAITFOR DELAY for blind SQL injection and enforce query timeouts at the application and server level.',
    'critical',
    'AUD-009-RC04: Kill time-delay injection session - SQL Server', 'immediate',
    'Kill the session: KILL <spid>. Capture sys.dm_exec_sql_text to preserve the WAITFOR DELAY payload and confirm the delay duration used by the attacker for timing-based inference.',
    'high', false,
    'AUD-009-RC04: Enforce query timeout and restrict WAITFOR - SQL Server', 'remediate',
    'Set a resource governor timeout for the application workload group. Configure command_timeout in the application connection string (e.g. 30 seconds). Enable SQL Server Audit to alert on WAITFOR DELAY statements from application logins. Enforce parameterised stored procedure calls for all application database interaction.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-009-RC04', 'mysql',
    'Terminate time-delay SQL injection session - MySQL',
    'aud-009-rc04-terminate-timedelay-mysql',
    'Kill the thread using SLEEP() for blind SQL injection and enforce query execution time limits.',
    'critical',
    'AUD-009-RC04: Kill time-delay injection thread - MySQL', 'immediate',
    'Kill the thread: KILL <process_id>. Record the SLEEP() call payload from INFORMATION_SCHEMA.PROCESSLIST INFO and note the TIME column showing elapsed execution duration.',
    'high', false,
    'AUD-009-RC04: Set max_execution_time and enforce prepared statements - MySQL', 'remediate',
    'Set a per-user execution time limit: SET GLOBAL max_execution_time = 5000 (5 seconds). Apply per-connection: SET SESSION max_execution_time = 5000. Revoke EXECUTE on SLEEP if not required. Enforce prepared statements in all application queries. Add audit_log filter capturing SLEEP() function calls.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-009-RC04', 'oracle',
    'Terminate time-delay SQL injection session - Oracle',
    'aud-009-rc04-terminate-timedelay-oracle',
    'Kill the session using DBMS_LOCK.SLEEP or DBMS_PIPE.RECEIVE_MESSAGE for blind SQL injection and restrict time-delay package privileges.',
    'critical',
    'AUD-009-RC04: Kill time-delay injection session - Oracle', 'immediate',
    'Kill the session: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE. Retrieve V$SQL SQL_TEXT to confirm the time-delay function used (DBMS_LOCK.SLEEP, DBMS_PIPE.RECEIVE_MESSAGE) and the delay value.',
    'high', false,
    'AUD-009-RC04: Revoke time-delay package privileges and set resource limits - Oracle', 'remediate',
    'Revoke EXECUTE on DBMS_LOCK and DBMS_PIPE from the application schema if not required. Create a resource plan limit for the application service: DBMS_RESOURCE_MANAGER.CREATE_PLAN_DIRECTIVE with MAX_IDLE_TIME. Enable Oracle SQL Firewall allow-list to block non-approved function calls. Add Unified Audit policy on DBMS_LOCK.SLEEP execution.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-009-RC05  Comment-based obfuscation / encoding
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-009-RC05', 'postgresql',
    'Terminate obfuscated injection session - PostgreSQL',
    'aud-009-rc05-terminate-obfuscated-pg',
    'Terminate the session using comment or encoding obfuscation to bypass input validation and deploy WAF rules to detect future attempts.',
    'critical',
    'AUD-009-RC05: Terminate comment-obfuscated injection session - PostgreSQL', 'immediate',
    'Terminate: SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid = <target_pid>. Preserve the query text containing inline comments (/**/ or --), hex literals, or CHR() concatenation from pg_stat_activity.query for WAF rule development.',
    'high', false,
    'AUD-009-RC05: Deploy WAF obfuscation rules and enforce input validation - PostgreSQL', 'remediate',
    'Add WAF rules detecting /**/ comment sequences, hex string patterns (0x...), and CHR() concatenation chains in SQL input parameters. Enforce server-side parameterised queries to make client-supplied string structure irrelevant. Enable pg_audit to capture all statements from the affected application role for 30 days.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-009-RC05', 'sqlserver',
    'Terminate obfuscated injection session - SQL Server',
    'aud-009-rc05-terminate-obfuscated-sqlserver',
    'Kill the session using comment or encoding obfuscation and update WAF and input validation rules.',
    'critical',
    'AUD-009-RC05: Kill obfuscated injection session - SQL Server', 'immediate',
    'Kill the session: KILL <spid>. Capture the obfuscated SQL text from sys.dm_exec_sql_text. Identify encoding technique used: /**/ comments, CHAR() chains, or hex literals to inform WAF rule creation.',
    'high', false,
    'AUD-009-RC05: Update WAF rules and parameterise application queries - SQL Server', 'remediate',
    'Deploy Extended Events session capturing queries from the application login that contain CHAR(, 0x prefix, or /* sequences. Update WAF policies to decode and inspect URL-encoded parameters before forwarding. Replace all dynamic query construction with sp_executesql parameterised calls. Review application error output to suppress SQL error details.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-009-RC05', 'mysql',
    'Terminate obfuscated injection session - MySQL',
    'aud-009-rc05-terminate-obfuscated-mysql',
    'Kill the thread using comment or encoding obfuscation to bypass input validation and enforce prepared statements.',
    'critical',
    'AUD-009-RC05: Kill obfuscated injection thread - MySQL', 'immediate',
    'Kill the thread: KILL <process_id>. Preserve the INFO field from INFORMATION_SCHEMA.PROCESSLIST showing comment markers, hex strings, or CHAR() chains used for obfuscation.',
    'high', false,
    'AUD-009-RC05: Enforce prepared statements and WAF normalization - MySQL', 'remediate',
    'Configure WAF to normalize SQL before validation: strip inline comments, decode hex strings, and expand CHAR() calls. Enforce prepared statements in application code. Enable audit_log plugin with filter on the affected user. Set sql_mode = NO_BACKSLASH_ESCAPES to reduce escape-based obfuscation vectors.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-009-RC05', 'oracle',
    'Terminate obfuscated injection session - Oracle',
    'aud-009-rc05-terminate-obfuscated-oracle',
    'Kill the session using comment or encoding obfuscation and enforce SQL Firewall allow-list to block non-standard query structure.',
    'critical',
    'AUD-009-RC05: Kill obfuscated injection session - Oracle', 'immediate',
    'Kill the session: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE. Retrieve V$SQL SQL_TEXT to document the obfuscation technique used (CHR() chains, /**/ comments, or hex literals) for WAF rule and SQL Firewall policy development.',
    'high', false,
    'AUD-009-RC05: Enable SQL Firewall and enforce bind variables - Oracle', 'remediate',
    'Enable Oracle SQL Firewall in enforce mode for the application account, allowing only the specific SQL signatures approved during learning. Any obfuscated or structurally novel query will be blocked at the database tier regardless of WAF state. Replace all EXECUTE IMMEDIATE string-builds with bind variable equivalents. Add Unified Audit policy on the application schema owner.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-010-RC01  Excessive catalog enumeration
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-010-RC01', 'postgresql',
    'Terminate excessive catalog enumeration session - PostgreSQL',
    'aud-010-rc01-terminate-catalog-enum-pg',
    'Terminate the session performing automated information_schema enumeration and restrict catalog access for application roles.',
    'high',
    'AUD-010-RC01: Terminate catalog enumeration session - PostgreSQL', 'immediate',
    'Terminate: SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid = <target_pid>. Count recent catalog queries: SELECT count(*) FROM pg_stat_statements WHERE query ILIKE ''%information_schema%'' AND userid = <target_uid> to quantify enumeration scope.',
    'high', false,
    'AUD-010-RC01: Revoke catalog access from application role - PostgreSQL', 'remediate',
    'Revoke USAGE on information_schema from the application role if schema introspection is not a legitimate use case: REVOKE USAGE ON SCHEMA information_schema FROM <app_role>. Set a rate limit via pg_stat_statements monitoring and alerting. Enable pg_audit to log all catalog queries and alert when a single session exceeds a threshold within a 5-minute window.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-010-RC01', 'sqlserver',
    'Terminate excessive catalog enumeration session - SQL Server',
    'aud-010-rc01-terminate-catalog-enum-sqlserver',
    'Kill the session performing automated sys/INFORMATION_SCHEMA enumeration and revoke catalog view access from the login.',
    'high',
    'AUD-010-RC01: Kill catalog enumeration session - SQL Server', 'immediate',
    'Kill the session: KILL <spid>. Query sys.dm_exec_query_stats to count recent catalog queries from this login: filter on sql_text referencing sys.objects, sys.columns, or INFORMATION_SCHEMA within the last hour.',
    'high', false,
    'AUD-010-RC01: Revoke VIEW DEFINITION and catalog view access - SQL Server', 'remediate',
    'Revoke VIEW DEFINITION on the database from the application login. Deny SELECT on sys schema views not required by the application: DENY SELECT ON sys.columns TO <login>. Create a server audit specification alerting when any login queries sys or INFORMATION_SCHEMA more than 50 times per minute.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-010-RC01', 'mysql',
    'Terminate excessive catalog enumeration session - MySQL',
    'aud-010-rc01-terminate-catalog-enum-mysql',
    'Kill the thread performing automated information_schema enumeration and restrict catalog SELECT grants.',
    'high',
    'AUD-010-RC01: Kill catalog enumeration thread - MySQL', 'immediate',
    'Kill the thread: KILL <process_id>. Review INFORMATION_SCHEMA.PROCESSLIST for other active threads from the same USER and HOST. Count recent information_schema queries via performance_schema.events_statements_history_long filtered by SQL_TEXT.',
    'high', false,
    'AUD-010-RC01: Restrict information_schema access and set connection limits - MySQL', 'remediate',
    'Set MAX_QUERIES_PER_HOUR for the application user: ALTER USER ''<user>''@''<host>'' WITH MAX_QUERIES_PER_HOUR 1000. Revoke SELECT on information_schema from the user if not required. Enable audit_log plugin filtering on information_schema SELECT events from this account.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-010-RC01', 'oracle',
    'Terminate excessive catalog enumeration session - Oracle',
    'aud-010-rc01-terminate-catalog-enum-oracle',
    'Kill the session performing automated data dictionary enumeration and restrict dictionary view access.',
    'high',
    'AUD-010-RC01: Kill catalog enumeration session - Oracle', 'immediate',
    'Kill the session: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE. Query V$SQL to count dictionary queries from this session: SELECT count(*) FROM V$SQL WHERE PARSING_USER_ID = <uid> AND (SQL_TEXT LIKE ''%ALL_TABLES%'' OR SQL_TEXT LIKE ''%DBA_COLUMNS%'').',
    'high', false,
    'AUD-010-RC01: Restrict ALL_ view access and create resource limit - Oracle', 'remediate',
    'Revoke SELECT on ALL_TABLES, ALL_COLUMNS, ALL_OBJECTS from the application schema if not required by the application. Set O7_DICTIONARY_ACCESSIBILITY = FALSE. Create a Unified Audit policy on SELECT from the SYS schema by the application account and alert when query count exceeds threshold per hour.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-010-RC02  User enumeration by non-admin
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-010-RC02', 'postgresql',
    'Terminate user enumeration session - PostgreSQL',
    'aud-010-rc02-terminate-user-enum-pg',
    'Terminate the non-admin session querying pg_roles or pg_user and revoke access to system principal catalog views.',
    'high',
    'AUD-010-RC02: Terminate user enumeration session - PostgreSQL', 'immediate',
    'Terminate: SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid = <target_pid>. Record the query referencing pg_roles, pg_user, or pg_shadow and note client_addr for IP-based investigation.',
    'high', false,
    'AUD-010-RC02: Revoke access to principal catalog views - PostgreSQL', 'remediate',
    'Revoke SELECT on pg_roles from the application role: REVOKE SELECT ON pg_catalog.pg_roles FROM <app_role>. Revoke CREATEROLE from roles that do not need it. Enable pg_audit logging of all pg_catalog queries from non-superuser accounts and alert when pg_roles or pg_user are queried.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-010-RC02', 'sqlserver',
    'Terminate user enumeration session - SQL Server',
    'aud-010-rc02-terminate-user-enum-sqlserver',
    'Kill the non-admin session querying sys.server_principals and restrict access to server principal views.',
    'high',
    'AUD-010-RC02: Kill user enumeration session - SQL Server', 'immediate',
    'Kill the session: KILL <spid>. Capture the SQL text showing the sys.server_principals or sys.database_principals query from sys.dm_exec_sql_text.',
    'high', false,
    'AUD-010-RC02: Deny access to principal catalog views - SQL Server', 'remediate',
    'Deny SELECT on sys.server_principals and sys.database_principals to the application login: DENY SELECT ON sys.server_principals TO <login>. Revoke VIEW SERVER STATE if held. Create a SQL Server Audit specification alerting on access to principal system views by non-admin logins.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-010-RC02', 'mysql',
    'Terminate user enumeration session - MySQL',
    'aud-010-rc02-terminate-user-enum-mysql',
    'Kill the non-admin thread querying mysql.user and revoke access to the mysql system schema.',
    'high',
    'AUD-010-RC02: Kill user enumeration thread - MySQL', 'immediate',
    'Kill the thread: KILL <process_id>. Preserve the INFO from INFORMATION_SCHEMA.PROCESSLIST showing the mysql.user or performance_schema.users query. Note USER and HOST.',
    'high', false,
    'AUD-010-RC02: Revoke mysql schema access from application user - MySQL', 'remediate',
    'Revoke SELECT on mysql.user from the application user: REVOKE SELECT ON mysql.user FROM ''<user>''@''<host>''. FLUSH PRIVILEGES. Restrict access to mysql.* tables to DBA accounts only. Enable audit_log to alert on SELECT from mysql system tables by non-admin accounts.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-010-RC02', 'oracle',
    'Terminate user enumeration session - Oracle',
    'aud-010-rc02-terminate-user-enum-oracle',
    'Kill the non-DBA session querying DBA_USERS or ALL_USERS and restrict access to user administration views.',
    'high',
    'AUD-010-RC02: Kill user enumeration session - Oracle', 'immediate',
    'Kill the session: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE. Capture V$SQL SQL_TEXT showing the DBA_USERS or V$SESSION query used for principal enumeration.',
    'high', false,
    'AUD-010-RC02: Revoke DBA_ view access from application account - Oracle', 'remediate',
    'Revoke SELECT on DBA_USERS, DBA_ROLES, and DBA_ROLE_PRIVS from the application account. Grant only SELECT on ALL_USERS or SESSION_PRIVS if user context is genuinely needed. Add Unified Audit policy on SELECT from DBA_ views by non-DBA accounts and alert.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-010-RC03  Mass table/column listing
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-010-RC03', 'postgresql',
    'Terminate mass column inventory session - PostgreSQL',
    'aud-010-rc03-terminate-mass-column-pg',
    'Terminate the session performing mass information_schema.columns enumeration and restrict catalog read access.',
    'high',
    'AUD-010-RC03: Terminate mass column listing session - PostgreSQL', 'immediate',
    'Terminate: SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid = <target_pid>. Capture the query enumerating information_schema.columns or pg_attribute across all tables to understand the scope of schema data exposed.',
    'high', false,
    'AUD-010-RC03: Restrict column catalog access and enable query rate alerting - PostgreSQL', 'remediate',
    'Revoke SELECT on information_schema.columns from the application role. Grant access only to specific schema views required by the application. Add a pg_audit policy alerting when a single session queries information_schema more than 20 times in 1 minute. Review application code to confirm schema introspection is not a legitimate use.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-010-RC03', 'sqlserver',
    'Terminate mass column inventory session - SQL Server',
    'aud-010-rc03-terminate-mass-column-sqlserver',
    'Kill the session performing mass INFORMATION_SCHEMA.COLUMNS enumeration and revoke catalog view access.',
    'high',
    'AUD-010-RC03: Kill mass column listing session - SQL Server', 'immediate',
    'Kill the session: KILL <spid>. Count catalog queries from this session in sys.dm_exec_query_stats filtered by sql_text containing INFORMATION_SCHEMA.COLUMNS to quantify reconnaissance scope.',
    'high', false,
    'AUD-010-RC03: Revoke VIEW DEFINITION and catalog column access - SQL Server', 'remediate',
    'Revoke VIEW DEFINITION on the database from the application login. Deny SELECT on INFORMATION_SCHEMA.COLUMNS: DENY SELECT ON INFORMATION_SCHEMA.COLUMNS TO <login>. Create an Extended Events alert firing when more than 30 INFORMATION_SCHEMA queries occur in a single session within 60 seconds.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-010-RC03', 'mysql',
    'Terminate mass column inventory session - MySQL',
    'aud-010-rc03-terminate-mass-column-mysql',
    'Kill the thread performing mass information_schema.columns enumeration and restrict catalog SELECT.',
    'high',
    'AUD-010-RC03: Kill mass column listing thread - MySQL', 'immediate',
    'Kill the thread: KILL <process_id>. Query performance_schema.events_statements_history for the account to count recent information_schema.columns queries and identify the full scope of tables enumerated.',
    'high', false,
    'AUD-010-RC03: Restrict catalog access and set query rate limit - MySQL', 'remediate',
    'Set MAX_QUERIES_PER_HOUR 500 on the application account. Revoke SELECT on information_schema from the application user if not required. Enable audit_log_filter with a rule matching information_schema.columns queries by this account. Alert when query frequency from a single host exceeds threshold.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-010-RC03', 'oracle',
    'Terminate mass column inventory session - Oracle',
    'aud-010-rc03-terminate-mass-column-oracle',
    'Kill the session performing mass ALL_COLUMNS or DBA_COLUMNS enumeration and restrict dictionary view access.',
    'high',
    'AUD-010-RC03: Kill mass column listing session - Oracle', 'immediate',
    'Kill the session: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE. Query V$SQL for the SQL_TEXT pattern selecting from ALL_COLUMNS or DBA_TAB_COLUMNS to determine which schemas were mapped.',
    'high', false,
    'AUD-010-RC03: Revoke ALL_COLUMNS access and add rate-limit audit policy - Oracle', 'remediate',
    'Revoke SELECT on ALL_COLUMNS and DBA_TAB_COLUMNS from the application account. Grant SELECT on USER_TAB_COLUMNS scoped to the application owner schema only if column metadata is legitimately needed. Create a Unified Audit condition firing when the account executes more than 20 dictionary SELECT statements per minute.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-010-RC04  Stored procedure source enumeration
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-010-RC04', 'postgresql',
    'Terminate stored procedure source enumeration - PostgreSQL',
    'aud-010-rc04-terminate-proc-source-enum-pg',
    'Terminate the non-DBA session reading stored procedure definitions from pg_proc or information_schema.routines and restrict source code visibility.',
    'high',
    'AUD-010-RC04: Terminate procedure source enumeration session - PostgreSQL', 'immediate',
    'Terminate: SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid = <target_pid>. Capture the query against pg_proc.prosrc or information_schema.routines to identify which procedure definitions were accessed.',
    'medium', false,
    'AUD-010-RC04: Revoke procedure source visibility from application role - PostgreSQL', 'remediate',
    'Revoke SELECT on pg_catalog.pg_proc from the application role. Restrict information_schema.routines access. Use security-definer functions to expose only approved interfaces rather than raw procedure source. Enable pg_audit to alert on pg_proc queries from non-superuser accounts.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-010-RC04', 'sqlserver',
    'Terminate stored procedure source enumeration - SQL Server',
    'aud-010-rc04-terminate-proc-source-enum-sqlserver',
    'Kill the non-DBA session reading procedure definitions from sys.sql_modules and revoke VIEW DEFINITION on database objects.',
    'high',
    'AUD-010-RC04: Kill procedure source enumeration session - SQL Server', 'immediate',
    'Kill the session: KILL <spid>. Capture the query joining sys.sql_modules or sys.objects from sys.dm_exec_sql_text to identify which procedure definitions were read.',
    'medium', false,
    'AUD-010-RC04: Revoke VIEW DEFINITION from application login - SQL Server', 'remediate',
    'Revoke VIEW DEFINITION on the database: REVOKE VIEW DEFINITION ON DATABASE::<db> FROM <login>. Apply EXECUTE permission only on specific procedures the application calls. Use WITH ENCRYPTION on sensitive stored procedures. Create a SQL Server Audit alert on VIEW DEFINITION access by non-admin logins.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-010-RC04', 'mysql',
    'Terminate stored procedure source enumeration - MySQL',
    'aud-010-rc04-terminate-proc-source-enum-mysql',
    'Kill the non-DBA thread reading procedure definitions from information_schema.routines and restrict ROUTINE metadata access.',
    'high',
    'AUD-010-RC04: Kill procedure source enumeration thread - MySQL', 'immediate',
    'Kill the thread: KILL <process_id>. Note the information_schema.routines query in INFORMATION_SCHEMA.PROCESSLIST INFO to confirm which procedure bodies were read.',
    'medium', false,
    'AUD-010-RC04: Revoke SHOW_ROUTINE privilege from application user - MySQL', 'remediate',
    'Revoke the SHOW_ROUTINE privilege from the application user if held. In MySQL 8 this privilege controls visibility of procedure bodies in information_schema.routines. Grant only EXECUTE on specific procedures needed by the application. Enable audit_log filtering on ROUTINE_DEFINITION column access.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-010-RC04', 'oracle',
    'Terminate stored procedure source enumeration - Oracle',
    'aud-010-rc04-terminate-proc-source-enum-oracle',
    'Kill the non-DBA session querying ALL_SOURCE or DBA_SOURCE for procedure bodies and restrict source code view access.',
    'high',
    'AUD-010-RC04: Kill procedure source enumeration session - Oracle', 'immediate',
    'Kill the session: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE. Query V$SQL for SQL_TEXT referencing ALL_SOURCE or DBA_SOURCE to identify which procedure or package bodies were read.',
    'medium', false,
    'AUD-010-RC04: Revoke ALL_SOURCE access and use WRAPPED packages - Oracle', 'remediate',
    'Revoke SELECT on ALL_SOURCE and DBA_SOURCE from the application account. Use DBMS_DDL.WRAP or obfuscated packages for sensitive business logic to prevent source recovery even if catalog access is regained. Add Unified Audit policy on SELECT from ALL_SOURCE by non-DBA accounts.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-010-RC05  Permission / privilege discovery queries
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-010-RC05', 'postgresql',
    'Terminate privilege discovery session - PostgreSQL',
    'aud-010-rc05-terminate-priv-discovery-pg',
    'Terminate the session systematically calling HAS_TABLE_PRIVILEGE or querying information_schema.role_table_grants to map accessible objects.',
    'high',
    'AUD-010-RC05: Terminate privilege discovery session - PostgreSQL', 'immediate',
    'Terminate: SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid = <target_pid>. Record queries referencing HAS_TABLE_PRIVILEGE, has_schema_privilege, or information_schema.role_table_grants to understand the scope of privilege mapping performed.',
    'medium', false,
    'AUD-010-RC05: Restrict privilege introspection functions - PostgreSQL', 'remediate',
    'Revoke EXECUTE on has_table_privilege and related privilege-check functions from PUBLIC if not required by the application. Restrict access to information_schema.role_table_grants. Enable pg_audit to log all privilege function calls from non-superuser accounts and alert on bulk invocation patterns.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-010-RC05', 'sqlserver',
    'Terminate privilege discovery session - SQL Server',
    'aud-010-rc05-terminate-priv-discovery-sqlserver',
    'Kill the session using fn_my_permissions or sys.database_permissions to map privilege landscape and restrict access.',
    'high',
    'AUD-010-RC05: Kill privilege discovery session - SQL Server', 'immediate',
    'Kill the session: KILL <spid>. Capture the SQL text from sys.dm_exec_sql_text showing fn_my_permissions, sys.database_permissions, or sys.server_permissions queries used for privilege mapping.',
    'medium', false,
    'AUD-010-RC05: Restrict permission view access and audit - SQL Server', 'remediate',
    'Deny SELECT on sys.database_permissions and sys.server_permissions to the application login. Revoke VIEW SERVER STATE. Create an Extended Events alert firing when fn_my_permissions is called more than 10 times per minute from a single login. Review whether the application has any legitimate need for privilege introspection.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-010-RC05', 'mysql',
    'Terminate privilege discovery session - MySQL',
    'aud-010-rc05-terminate-priv-discovery-mysql',
    'Kill the thread querying information_schema.schema_privileges or SHOW GRANTS to map privilege landscape.',
    'high',
    'AUD-010-RC05: Kill privilege discovery thread - MySQL', 'immediate',
    'Kill the thread: KILL <process_id>. Preserve the INFORMATION_SCHEMA.SCHEMA_PRIVILEGES or SHOW GRANTS query from INFORMATION_SCHEMA.PROCESSLIST INFO. Note USER and HOST.',
    'medium', false,
    'AUD-010-RC05: Restrict schema_privileges access and audit - MySQL', 'remediate',
    'Revoke SELECT on information_schema.schema_privileges and table_privileges from the application user if not required. Set MAX_QUERIES_PER_HOUR to limit bulk enumeration. Enable audit_log filtering on schema_privileges and table_privileges queries from this account. Alert when SHOW GRANTS is executed by non-admin accounts.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-010-RC05', 'oracle',
    'Terminate privilege discovery session - Oracle',
    'aud-010-rc05-terminate-priv-discovery-oracle',
    'Kill the session querying SESSION_PRIVS, DBA_SYS_PRIVS, or DBA_TAB_PRIVS to map the privilege landscape.',
    'high',
    'AUD-010-RC05: Kill privilege discovery session - Oracle', 'immediate',
    'Kill the session: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE. Query V$SQL for SQL_TEXT referencing SESSION_PRIVS, DBA_SYS_PRIVS, DBA_TAB_PRIVS, or DBA_ROLE_PRIVS to identify the scope of privilege mapping.',
    'medium', false,
    'AUD-010-RC05: Revoke privilege view access and audit - Oracle', 'remediate',
    'Revoke SELECT on DBA_SYS_PRIVS, DBA_TAB_PRIVS, and DBA_ROLE_PRIVS from the application account. Grant SELECT only on USER_SYS_PRIVS and SESSION_PRIVS if the application genuinely requires its own privilege context. Add Unified Audit policy on DBA_ privilege view access by non-DBA accounts.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-011-RC01  Direct DML on audit / log tables
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-011-RC01', 'postgresql',
    'Terminate and reverse audit table DML - PostgreSQL',
    'aud-011-rc01-terminate-audit-dml-pg',
    'Immediately terminate the session executing DML on audit tables, restore tampered audit records from backup, and restrict write access to audit tables.',
    'critical',
    'AUD-011-RC01: Terminate audit table DML session - PostgreSQL', 'immediate',
    'Terminate: SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid = <target_pid>. Record the exact DML query (INSERT/UPDATE/DELETE) targeting the audit table from pg_stat_activity.query. Capture usename and client_addr. Immediately freeze the audit table by setting it read-only via a protective trigger.',
    'high', false,
    'AUD-011-RC01: Restore tampered audit records and lock audit tables - PostgreSQL', 'remediate',
    'Restore audit records from the most recent WAL-based backup or pg_audit secondary log stored off-system. Revoke INSERT, UPDATE, DELETE on all audit tables from every role except the dedicated audit writer service account. Enable row-level security on audit tables allowing only INSERT from the audit service role. Alert on any future DML on audit tables from non-audit accounts.',
    'high', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-011-RC01', 'sqlserver',
    'Terminate and reverse audit table DML - SQL Server',
    'aud-011-rc01-terminate-audit-dml-sqlserver',
    'Kill the session executing DML on audit tables, restore tampered records from backup, and lock down audit table permissions.',
    'critical',
    'AUD-011-RC01: Kill audit table DML session - SQL Server', 'immediate',
    'Kill the session: KILL <spid>. Capture the DML statement from sys.dm_exec_sql_text. If CDC is enabled use cdc.fn_cdc_get_all_changes() to identify exact rows modified in the audit table before termination.',
    'high', false,
    'AUD-011-RC01: Restore audit data and restrict audit table permissions - SQL Server', 'remediate',
    'Restore modified audit rows from the transaction log using fn_dblog() or a log reader. Revoke INSERT, UPDATE, DELETE on audit tables from all logins except the designated audit service account. Enable SQL Server Audit itself to log all DML on audit tables. Consider redirecting audit output to an immutable external target such as an Azure Storage account or Splunk forwarder.',
    'high', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-011-RC01', 'mysql',
    'Terminate and reverse audit table DML - MySQL',
    'aud-011-rc01-terminate-audit-dml-mysql',
    'Kill the thread executing DML on audit log tables, restore records from binary log, and restrict write access.',
    'critical',
    'AUD-011-RC01: Kill audit table DML thread - MySQL', 'immediate',
    'Kill the thread: KILL <process_id>. Capture the DML query from INFORMATION_SCHEMA.PROCESSLIST INFO. Identify the rows modified using mysqlbinlog with --start-datetime and --stop-datetime covering the incident window.',
    'high', false,
    'AUD-011-RC01: Restore audit records and lock audit table permissions - MySQL', 'remediate',
    'Use mysqlbinlog point-in-time restore to recover deleted or modified audit rows from binary logs. Revoke INSERT, UPDATE, DELETE on audit log tables from all users except the audit service account. Enable MySQL Enterprise Audit with output to a remote syslog or SIEM to maintain an off-system copy that cannot be tampered via DML.',
    'high', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-011-RC01', 'oracle',
    'Terminate and reverse audit table DML - Oracle',
    'aud-011-rc01-terminate-audit-dml-oracle',
    'Kill the session executing DML on AUD$ or UNIFIED_AUDIT_TRAIL, restore records via Flashback, and restrict audit table DML.',
    'critical',
    'AUD-011-RC01: Kill audit table DML session - Oracle', 'immediate',
    'Kill the session: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE. Retrieve V$SQL SQL_TEXT showing the DML targeting AUD$, FGA_LOG$, or UNIFIED_AUDIT_TRAIL. Note the USERNAME and OSUSER for the incident record.',
    'high', false,
    'AUD-011-RC01: Restore audit records via Flashback and restrict DML - Oracle', 'remediate',
    'Use Flashback Query to compare AUD$ or FGA_LOG$ state before the incident: SELECT * FROM AUD$ AS OF TIMESTAMP (SYSTIMESTAMP - INTERVAL ''1'' HOUR). Restore deleted rows from Flashback Versions Query if undo retention allows. Revoke DELETE and UPDATE on AUD$ from PUBLIC and all non-SYS accounts. Configure audit trail to write to OS-level files or a remote syslog to prevent in-database tampering.',
    'high', true
  );

-- ============================================================
-- SEC-SQL-AUD-011-RC02  Audit settings disabled mid-session
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-011-RC02', 'postgresql',
    'Restore audit settings disabled mid-session - PostgreSQL',
    'aud-011-rc02-restore-audit-settings-pg',
    'Re-enable audit logging that was disabled via ALTER SYSTEM or SET SESSION commands and investigate what activity occurred during the audit blind spot.',
    'critical',
    'AUD-011-RC02: Restore audit logging parameters - PostgreSQL', 'immediate',
    'Re-enable audit logging: ALTER SYSTEM SET log_statement = ''all'' and SELECT pg_reload_conf(). Check pg_settings to confirm the change is active. Query pg_stat_activity for any sessions that ran during the blind spot window between the SET command and now.',
    'high', true,
    'AUD-011-RC02: Restrict ALTER SYSTEM and audit config privileges - PostgreSQL', 'remediate',
    'Revoke SUPERUSER from accounts that modified audit settings if not required. Use postgresql.conf include_dir with a read-only audit configuration file that overrides session-level attempts. Enable alerting on SET log_statement or pg_reload_conf() calls from non-superuser accounts. Consider using a separate pgaudit-protected audit role.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-011-RC02', 'sqlserver',
    'Restore audit settings disabled mid-session - SQL Server',
    'aud-011-rc02-restore-audit-settings-sqlserver',
    'Re-enable SQL Server Audit specifications that were disabled and identify activity during the audit gap.',
    'critical',
    'AUD-011-RC02: Re-enable disabled audit specifications - SQL Server', 'immediate',
    'Re-enable the audit specification: ALTER SERVER AUDIT SPECIFICATION <spec_name> WITH (STATE = ON) or ALTER DATABASE AUDIT SPECIFICATION <spec_name> WITH (STATE = ON). Verify with SELECT * FROM sys.dm_server_audit_status. Query sys.dm_exec_query_stats for activity during the gap period.',
    'high', true,
    'AUD-011-RC02: Restrict audit specification modification privileges - SQL Server', 'remediate',
    'Revoke ALTER ANY SERVER AUDIT from logins that do not require it. Grant this right only to dedicated security administrator accounts. Enable an independent audit specification tracking changes to other audit specifications. Consider routing audit output to an immutable target such as Azure Blob Storage.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-011-RC02', 'mysql',
    'Restore audit settings disabled mid-session - MySQL',
    'aud-011-rc02-restore-audit-settings-mysql',
    'Re-enable general_log or audit_log plugin that was disabled and investigate activity during the audit gap.',
    'critical',
    'AUD-011-RC02: Re-enable MySQL audit logging - MySQL', 'immediate',
    'Re-enable logging: SET GLOBAL general_log = ON or SET GLOBAL audit_log_policy = ALL. Verify with SHOW VARIABLES LIKE ''general_log%''. Query performance_schema.events_statements_history_long for statements executed during the window when logging was OFF.',
    'high', true,
    'AUD-011-RC02: Restrict SUPER and AUDIT_ADMIN privileges - MySQL', 'remediate',
    'Revoke SUPER or AUDIT_ADMIN privilege from accounts that are not designated DBAs. In MySQL 8.0+ use the AUDIT_ADMIN privilege specifically to control who can modify audit settings. Enable audit_log plugin in READ_ONLY mode (audit_log_read_buffer_size) to prevent runtime disabling. Forward audit events to a remote syslog or SIEM.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-011-RC02', 'oracle',
    'Restore audit settings disabled mid-session - Oracle',
    'aud-011-rc02-restore-audit-settings-oracle',
    'Re-enable Unified Auditing or traditional audit policies that were disabled and investigate activity during the audit gap.',
    'critical',
    'AUD-011-RC02: Re-enable Oracle audit policies - Oracle', 'immediate',
    'Re-enable disabled unified audit policies: AUDIT POLICY <policy_name>. Verify with SELECT * FROM AUDIT_UNIFIED_ENABLED_POLICIES. For traditional audit use AUDIT ALL BY SESSION. Check UNIFIED_AUDIT_TRAIL for any entries recorded during the gap period.',
    'high', true,
    'AUD-011-RC02: Restrict AUDIT SYSTEM privilege - Oracle', 'remediate',
    'Revoke the AUDIT SYSTEM privilege from all accounts except the designated security manager. Use Oracle Database Vault to prevent even DBA accounts from disabling audit policies without security officer approval. Configure audit trail to write to OS-level files or Oracle Audit Vault for tamper-resistant storage.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-011-RC03  Audit table truncated or dropped
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-011-RC03', 'postgresql',
    'Restore truncated audit table - PostgreSQL',
    'aud-011-rc03-restore-truncated-audit-pg',
    'Recover the truncated or dropped audit table from backup and prevent future DDL on audit objects.',
    'critical',
    'AUD-011-RC03: Recover audit table from backup - PostgreSQL', 'immediate',
    'Restore the truncated or dropped audit table using pg_restore from the most recent base backup combined with WAL replay up to the point before the TRUNCATE or DROP. Use pg_waldump to identify the exact LSN of the destructive command for precise PITR targeting.',
    'high', true,
    'AUD-011-RC03: Restrict DDL on audit tables and send logs off-system - PostgreSQL', 'remediate',
    'Revoke TRUNCATE and DROP TABLE on audit tables from all roles except a designated superuser backup account. Add a protective event trigger: CREATE EVENT TRIGGER block_audit_ddl ON ddl_command_start WHEN TAG IN (''DROP TABLE'',''TRUNCATE'') blocking any DDL on audit schema objects. Forward pgaudit logs to an external SIEM so in-database table destruction cannot erase the audit record.',
    'high', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-011-RC03', 'sqlserver',
    'Restore truncated audit table - SQL Server',
    'aud-011-rc03-restore-truncated-audit-sqlserver',
    'Recover the truncated or dropped audit table from transaction log or backup and restrict DDL on audit objects.',
    'critical',
    'AUD-011-RC03: Recover audit data from transaction log - SQL Server', 'immediate',
    'Use fn_dblog() or a certified log reader to recover rows deleted by TRUNCATE or identify the DROP TABLE LSN. Restore the table from the most recent differential or full backup if log-based recovery is insufficient. Document the time range of lost audit data for the incident report.',
    'high', true,
    'AUD-011-RC03: Restrict DDL on audit tables and route logs off-system - SQL Server', 'remediate',
    'Deny DROP TABLE and TRUNCATE TABLE permissions on audit tables for all logins except the security administrator. Create a DDL trigger: CREATE TRIGGER block_audit_ddl ON DATABASE FOR DROP_TABLE, TRUNCATE_TABLE blocking any DDL targeting audit schema objects. Route SQL Server Audit output to an Azure Blob immutable policy storage account.',
    'high', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-011-RC03', 'mysql',
    'Restore truncated audit table - MySQL',
    'aud-011-rc03-restore-truncated-audit-mysql',
    'Recover the truncated or dropped audit log table from binary logs or backup and prevent future DDL on audit objects.',
    'critical',
    'AUD-011-RC03: Recover audit table from binary log - MySQL', 'immediate',
    'Use mysqlbinlog with --start-datetime before the incident to replay transactions and recover rows. For a DROP TABLE use PITR restore from the last backup taken before the drop. Identify the exact position of the destructive statement in the binary log for accurate recovery targeting.',
    'high', true,
    'AUD-011-RC03: Restrict DROP and TRUNCATE on audit tables - MySQL', 'remediate',
    'Revoke DROP privilege on the audit log database from all accounts except the DBA backup user. Set the audit_log table to use a storage engine that blocks TRUNCATE, or redirect audit output to a file rotated off-system via audit_log_file. Forward audit events to a remote syslog so in-database destruction cannot erase them.',
    'high', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-011-RC03', 'oracle',
    'Restore truncated audit table - Oracle',
    'aud-011-rc03-restore-truncated-audit-oracle',
    'Recover AUD$ or FGA_LOG$ data after TRUNCATE or DROP and prevent future DDL on audit objects.',
    'critical',
    'AUD-011-RC03: Recover audit records via Flashback or RMAN - Oracle', 'immediate',
    'If undo retention allows use FLASHBACK TABLE AUD$ TO TIMESTAMP (SYSTIMESTAMP - INTERVAL ''2'' HOUR) to recover truncated rows. If flashback is insufficient use RMAN RECOVER TABLE to restore from backup. Document the audit gap period for the incident report.',
    'high', true,
    'AUD-011-RC03: Protect audit tables from DDL and route to Audit Vault - Oracle', 'remediate',
    'Revoke DELETE TABLE and DROP TABLE on AUD$ and FGA_LOG$ from all accounts including DBAs using Database Vault controls. Configure Oracle Audit Vault and Database Firewall to receive audit streams off-database so in-database table destruction cannot erase the record. Set AUDIT_TRAIL = OS or DB,EXTENDED with write-once OS file rotation.',
    'high', true
  );

-- ============================================================
-- SEC-SQL-AUD-011-RC04  Trigger disabled before DML
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-011-RC04', 'postgresql',
    'Re-enable disabled audit trigger and investigate bypassed DML - PostgreSQL',
    'aud-011-rc04-reenable-trigger-pg',
    'Re-enable the audit trigger that was disabled before DML, assess what rows were modified without audit coverage, and restrict TRIGGER privilege.',
    'high',
    'AUD-011-RC04: Re-enable disabled trigger - PostgreSQL', 'immediate',
    'Re-enable the trigger: ALTER TABLE <table_name> ENABLE TRIGGER <trigger_name>. Identify rows modified during the trigger-disabled window by comparing WAL or pg_audit logs to the row state visible now. Use pg_stat_user_tables.n_mod_since_analyze for a rough change count estimate.',
    'high', true,
    'AUD-011-RC04: Revoke ALTER TABLE privilege and add DDL event trigger - PostgreSQL', 'remediate',
    'Revoke ALTER TABLE privilege on monitored tables from all roles except DBAs. Add a PostgreSQL event trigger: CREATE EVENT TRIGGER block_trigger_disable ON ddl_command_start WHEN TAG IN (''ALTER TABLE'') to detect and optionally block DISABLE TRIGGER operations on audit-relevant tables. Add pg_audit policy alerting on DISABLE TRIGGER commands from any account.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-011-RC04', 'sqlserver',
    'Re-enable disabled audit trigger and investigate bypassed DML - SQL Server',
    'aud-011-rc04-reenable-trigger-sqlserver',
    'Re-enable the trigger disabled before DML, assess bypassed changes, and restrict ALTER TABLE permissions.',
    'high',
    'AUD-011-RC04: Re-enable disabled trigger - SQL Server', 'immediate',
    'Re-enable: ENABLE TRIGGER <trigger_name> ON <table_name>. Use fn_dblog() or CDC to enumerate DML executed on the table during the trigger-disabled window. Correlate with sys.dm_exec_query_stats to identify the session responsible.',
    'high', true,
    'AUD-011-RC04: Restrict DISABLE TRIGGER and alert on trigger DDL - SQL Server', 'remediate',
    'Revoke ALTER permission on tables carrying audit triggers from application logins. Create a DDL trigger: CREATE TRIGGER block_trigger_disable ON DATABASE FOR DISABLE_TRIGGER alerting the security team. Enable SQL Server Audit to capture DISABLE_TRIGGER events on the affected table. Document the list of monitored tables with triggers that must never be disabled.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-011-RC04', 'mysql',
    'Re-enable disabled audit trigger and investigate bypassed DML - MySQL',
    'aud-011-rc04-reenable-trigger-mysql',
    'Restore the dropped trigger (MySQL has no DISABLE TRIGGER, only DROP TRIGGER), assess bypassed DML, and restrict TRIGGER privilege.',
    'high',
    'AUD-011-RC04: Restore dropped audit trigger - MySQL', 'immediate',
    'Recreate the dropped trigger from source control or information_schema.triggers backup. Use mysqlbinlog to enumerate DML on the affected table during the gap between the DROP TRIGGER and trigger restoration. Document rows modified without audit coverage.',
    'high', true,
    'AUD-011-RC04: Revoke TRIGGER privilege and protect trigger definitions - MySQL', 'remediate',
    'Revoke TRIGGER privilege on the affected table from all accounts except the designated DBA. Store trigger definitions in source control and implement a nightly check that recreates any missing triggers. Enable audit_log plugin to alert when DROP TRIGGER is executed by any account on monitored tables.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-011-RC04', 'oracle',
    'Re-enable disabled audit trigger and investigate bypassed DML - Oracle',
    'aud-011-rc04-reenable-trigger-oracle',
    'Re-enable the audit trigger disabled before DML, assess bypassed changes via Flashback, and restrict ALTER TRIGGER privilege.',
    'high',
    'AUD-011-RC04: Re-enable disabled trigger - Oracle', 'immediate',
    'Re-enable: ALTER TRIGGER <trigger_name> ENABLE. Use Flashback Versions Query on the affected table to identify rows changed during the trigger-disabled window: SELECT VERSIONS_OPERATION, VERSIONS_STARTTIME FROM <table> VERSIONS BETWEEN TIMESTAMP <start> AND <end>.',
    'high', true,
    'AUD-011-RC04: Restrict ALTER TRIGGER privilege and add DDL audit - Oracle', 'remediate',
    'Revoke ALTER ANY TRIGGER from accounts that do not require it. Use Database Vault to prevent schema-owner accounts from disabling triggers on monitored tables without security officer approval. Add Unified Audit policy on ALTER TRIGGER commands by non-DBA accounts to alert on future bypass attempts.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-011-RC05  Error log / event buffer cleared
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-011-RC05', 'postgresql',
    'Investigate log rotation used to clear evidence - PostgreSQL',
    'aud-011-rc05-investigate-log-clear-pg',
    'Determine what activity was concealed by the log rotation event and recover log data from off-system SIEM or log forwarder.',
    'high',
    'AUD-011-RC05: Recover log data from off-system forwarder - PostgreSQL', 'immediate',
    'Retrieve log events from the external log destination (Splunk, Elasticsearch, or syslog forwarder) for the period preceding and following the pg_reload_conf() or logrotate invocation. Cross-reference with WAL records for the same window to identify activity not captured in local logs. Document the gap period.',
    'high', false,
    'AUD-011-RC05: Restrict log rotation commands and forward logs off-system - PostgreSQL', 'remediate',
    'Revoke SUPERUSER from accounts that called pg_reload_conf() or invoked logrotate if not required. Configure rsyslog or Filebeat to forward PostgreSQL log lines to a SIEM in real time so local log rotation cannot destroy the evidentiary record. Enable alerting when pg_rotate_logfile() or pg_reload_conf() is called outside a maintenance window.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-011-RC05', 'sqlserver',
    'Investigate error log cycle used to clear evidence - SQL Server',
    'aud-011-rc05-investigate-log-clear-sqlserver',
    'Determine what activity was concealed by the sp_cycle_errorlog call and recover evidence from external SIEM.',
    'high',
    'AUD-011-RC05: Recover evidence from SIEM after log cycle - SQL Server', 'immediate',
    'Retrieve SQL Server error log events from the external SIEM or Windows Event Log forwarder for the period before and after the sp_cycle_errorlog invocation. Query the Windows Application Event Log for SQL Server source events which are written separately from the SQL error log and may preserve evidence of the cycle.',
    'high', false,
    'AUD-011-RC05: Restrict sp_cycle_errorlog and forward logs - SQL Server', 'remediate',
    'Revoke EXECUTE on sp_cycle_errorlog from logins that are not members of sysadmin or securityadmin. Forward SQL Server error log and audit log to a SIEM in real time using SQL Server Audit with an external file target combined with a log shipping agent. Alert when sp_cycle_errorlog is invoked outside a scheduled maintenance window.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-011-RC05', 'mysql',
    'Investigate FLUSH LOGS used to clear evidence - MySQL',
    'aud-011-rc05-investigate-log-clear-mysql',
    'Determine what activity was concealed by the FLUSH LOGS command and recover evidence from binary logs and SIEM.',
    'high',
    'AUD-011-RC05: Recover evidence after FLUSH LOGS - MySQL', 'immediate',
    'Identify the binary log file created immediately after the FLUSH LOGS event using SHOW BINARY LOGS. Review the prior binary log file (if not purged) for DML executed by the account that issued FLUSH LOGS. Retrieve general_log or audit_log events from the external SIEM forwarder covering the flush window.',
    'high', false,
    'AUD-011-RC05: Restrict RELOAD privilege and forward logs - MySQL', 'remediate',
    'Revoke the RELOAD privilege from all accounts except designated DBAs since FLUSH LOGS requires this privilege. Set expire_logs_days or binlog_expire_logs_seconds to retain binary logs long enough for forensic review. Forward audit_log and general_log to a remote syslog or SIEM so FLUSH LOGS cannot destroy the off-system record.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-011-RC05', 'oracle',
    'Investigate redo log switch used to clear evidence - Oracle',
    'aud-011-rc05-investigate-log-clear-oracle',
    'Determine what activity was concealed by the ALTER SYSTEM SWITCH LOGFILE command and recover evidence from archived redo logs and Audit Vault.',
    'high',
    'AUD-011-RC05: Recover evidence from archived redo logs - Oracle', 'immediate',
    'Query V$LOG_HISTORY to find the log switch event triggered by the incident command. Use LogMiner (DBMS_LOGMNR) to mine the archived redo log files covering the window around the switch for DML or DDL not captured in the online audit trail. Retrieve events from Oracle Audit Vault or SIEM forwarder covering the same window.',
    'high', false,
    'AUD-011-RC05: Restrict ALTER SYSTEM privilege and use Audit Vault - Oracle', 'remediate',
    'Revoke ALTER SYSTEM privilege from non-DBA accounts. Restrict EXECUTE on DBMS_SYSTEM to SYS only. Configure Oracle Audit Vault to receive audit events from all database instances so log file switches at the database level cannot destroy the centralized audit record. Add Unified Audit policy on ALTER SYSTEM commands by any account outside the scheduled maintenance SID.',
    'low', true
  );

END;
$BODY$;

DROP PROCEDURE IF EXISTS rootcause.add_resolution_path(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT,
  TEXT, TEXT, TEXT, TEXT, BOOLEAN,
  TEXT, TEXT, TEXT, TEXT, BOOLEAN
);

COMMIT;
