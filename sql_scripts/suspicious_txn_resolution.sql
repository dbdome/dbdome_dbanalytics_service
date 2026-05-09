-- ============================================================
-- Resolution paths + steps for SEC-SQL-AUD-006/007/008
-- Covers all root causes RC01-RC05 across postgresql, sqlserver,
-- mysql, oracle.
-- ============================================================
SET client_encoding = 'UTF8';
BEGIN;

-- ============================================================
-- Helper procedure
-- ============================================================
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
-- SEC-SQL-AUD-006-RC01  Privileged DML outside maintenance window
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-006-RC01', 'postgresql',
    'Terminate unauthorized privileged DML session - PostgreSQL',
    'aud-006-rc01-terminate-privileged-dml-pg',
    'Terminate the superuser session executing DML outside the maintenance window and audit the scope of changes to determine whether rollback is required.',
    'high',
    'AUD-006-RC01: Terminate privileged DML session - PostgreSQL', 'immediate',
    'Terminate the offending session: SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid = <target_pid>. Record usename, client_addr, query, and query_start before terminating to preserve incident evidence.',
    'high', false,
    'AUD-006-RC01: Audit DML scope and assess rollback - PostgreSQL', 'verify',
    'Identify affected tables via pg_stat_user_tables checking n_mod_since_analyze. Review pgaudit log to enumerate changed rows. Decide whether a manual ROLLBACK of pending changes or point-in-time restore is required.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-006-RC01', 'sqlserver',
    'Terminate unauthorized privileged DML session - SQL Server',
    'aud-006-rc01-terminate-privileged-dml-sqlserver',
    'Kill the sysadmin session executing unauthorized DML, capture transaction log evidence, and assess rollback scope.',
    'high',
    'AUD-006-RC01: Kill privileged DML session - SQL Server', 'immediate',
    'Kill the session: KILL <spid>. Before killing, capture sys.dm_exec_sessions joined with sys.dm_exec_requests CROSS APPLY sys.dm_exec_sql_text to preserve SQL evidence including login_name, host_name, program_name, and start_time.',
    'high', false,
    'AUD-006-RC01: Audit DML changes via transaction log - SQL Server', 'verify',
    'Use fn_dblog() or a certified log reader to trace changed rows in the incident timeframe. If CDC is enabled query cdc.fn_cdc_get_all_changes() for affected tables. Determine whether ROLLBACK or a point-in-time restore is needed.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-006-RC01', 'mysql',
    'Terminate unauthorized privileged DML session - MySQL',
    'aud-006-rc01-terminate-privileged-dml-mysql',
    'Kill the super-privilege thread executing DML outside the maintenance window and review binary logs to assess the scope of changes.',
    'high',
    'AUD-006-RC01: Kill privileged DML thread - MySQL', 'immediate',
    'Kill the thread: KILL <process_id>. Before killing, record USER, HOST, DB, TIME, and INFO from INFORMATION_SCHEMA.PROCESSLIST for incident documentation.',
    'high', false,
    'AUD-006-RC01: Review binary log for unauthorized DML - MySQL', 'verify',
    'Use SHOW BINARY LOGS and mysqlbinlog with --start-datetime and --stop-datetime to extract DML statements in the incident window. Determine whether point-in-time restore from a pre-incident backup is required.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-006-RC01', 'oracle',
    'Terminate unauthorized privileged DML session - Oracle',
    'aud-006-rc01-terminate-privileged-dml-oracle',
    'Kill the DBA session executing DML outside the maintenance window and use Flashback Query to audit changes and restore data if undo retention allows.',
    'high',
    'AUD-006-RC01: Kill DBA DML session - Oracle', 'immediate',
    'Kill the session: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE. Record V$SESSION columns SID, SERIAL#, USERNAME, OSUSER, MACHINE, and SQL_ID before killing to preserve incident evidence.',
    'high', false,
    'AUD-006-RC01: Flashback audit and rollback assessment - Oracle', 'verify',
    'Use Flashback Query (SELECT * FROM <table> AS OF TIMESTAMP ...) to compare current vs prior state. Review UNIFIED_AUDIT_TRAIL or DBA_AUDIT_TRAIL for DML statements. Use FLASHBACK TABLE to restore if undo retention permits.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-006-RC02  Superuser ad-hoc queries on sensitive tables
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-006-RC02', 'postgresql',
    'Revoke direct superuser access to sensitive tables - PostgreSQL',
    'aud-006-rc02-revoke-sensitive-table-access-pg',
    'Revoke direct SELECT privileges on sensitive tables from admin roles and route access through audited views or application service accounts.',
    'high',
    'AUD-006-RC02: Revoke superuser direct table grants - PostgreSQL', 'remediate',
    'Revoke direct grants: REVOKE SELECT ON <sensitive_table> FROM <admin_role>. Force access through audited application views. Enable pg_audit for SELECT events on sensitive schemas to capture future access attempts.',
    'medium', true,
    'AUD-006-RC02: Implement row security and audit policy - PostgreSQL', 'configure',
    'Enable Row Level Security: ALTER TABLE <sensitive_table> ENABLE ROW LEVEL SECURITY. Create a restrictive default policy. Configure pgaudit.log = ''read'' to audit all future SELECT statements on the schema and alert on admin direct access.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-006-RC02', 'sqlserver',
    'Revoke direct sysadmin access to sensitive tables - SQL Server',
    'aud-006-rc02-revoke-sensitive-table-access-sqlserver',
    'Deny direct SELECT on sensitive tables for sysadmin logins and enforce access through audited stored procedures or application roles.',
    'high',
    'AUD-006-RC02: Deny direct SELECT on sensitive tables - SQL Server', 'remediate',
    'Apply DENY: DENY SELECT ON <schema>.<sensitive_table> TO <login>. Route access through signed stored procedures with EXECUTE AS a low-privilege account. Create a server audit specification to alert on direct table access by admin logins.',
    'medium', true,
    'AUD-006-RC02: Create audit specification for sensitive table access - SQL Server', 'configure',
    'Create a Database Audit Specification targeting SELECT on sensitive tables by admin principals. Enable Dynamic Data Masking or column-level encryption for columns containing PII. Review membership of sysadmin and db_owner to minimize unnecessary privilege.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-006-RC02', 'mysql',
    'Revoke SUPER account direct access to sensitive tables - MySQL',
    'aud-006-rc02-revoke-sensitive-table-access-mysql',
    'Revoke direct SELECT privileges on sensitive tables from accounts with SUPER privilege and enforce access through audited application users.',
    'high',
    'AUD-006-RC02: Revoke SUPER account table grants - MySQL', 'remediate',
    'Revoke direct access: REVOKE SELECT ON <db>.<sensitive_table> FROM ''<user>''@''%''. Route reads through application service accounts with minimal privilege. Flush privileges after changes. Enable general_log or audit_log plugin to capture future direct access attempts.',
    'medium', true,
    'AUD-006-RC02: Configure MySQL audit plugin for sensitive tables - MySQL', 'configure',
    'Enable the MySQL Enterprise Audit plugin or Percona Audit Log. Define an audit filter to capture SELECT events on sensitive table names by superuser accounts. Set up alerting to trigger on any future direct admin access to classified tables.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-006-RC02', 'oracle',
    'Revoke DBA direct access to sensitive tables - Oracle',
    'aud-006-rc02-revoke-sensitive-table-access-oracle',
    'Revoke direct object privileges on sensitive tables from DBA accounts and implement Virtual Private Database or Fine-Grained Auditing to protect classified data.',
    'high',
    'AUD-006-RC02: Revoke DBA object grants on sensitive tables - Oracle', 'remediate',
    'Revoke table-level grants: REVOKE SELECT ON <owner>.<sensitive_table> FROM <dba_account>. Use Database Vault to create a realm preventing DBA access to application schemas. Route access through invoker-rights procedures owned by the application schema.',
    'medium', true,
    'AUD-006-RC02: Implement Fine-Grained Auditing on sensitive tables - Oracle', 'configure',
    'Apply Fine-Grained Auditing: DBMS_FGA.ADD_POLICY on each sensitive table auditing SELECT by non-application accounts. Enable Virtual Private Database predicates to restrict rows returned to authorised sessions. Review DBA_COL_PRIVS for column-level overexposure.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-006-RC03  High privilege account accessing out-of-scope schema
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-006-RC03', 'postgresql',
    'Revoke cross-schema privileges from admin account - PostgreSQL',
    'aud-006-rc03-revoke-cross-schema-pg',
    'Terminate the out-of-scope session and revoke superuser privileges or schema grants that allowed lateral movement outside the expected boundary.',
    'high',
    'AUD-006-RC03: Terminate and revoke out-of-scope schema access - PostgreSQL', 'remediate',
    'Terminate the session and revoke unnecessary cross-schema grants: REVOKE ALL ON SCHEMA <schema> FROM <role>. Implement search_path restrictions: ALTER ROLE <role> SET search_path TO <allowed_schema>. Review pg_namespace grants for over-privileged roles.',
    'medium', true,
    'AUD-006-RC03: Audit schemas and data accessed - PostgreSQL', 'verify',
    'Review pg_stat_user_tables filtered by schemaname to identify which schemas were read or modified in the session. Cross-reference with pg_audit log for SELECT/DML statements. Document scope of lateral access for incident report.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-006-RC03', 'sqlserver',
    'Revoke cross-database schema privileges from admin - SQL Server',
    'aud-006-rc03-revoke-cross-schema-sqlserver',
    'Revoke cross-database or cross-schema privileges from the admin account and audit what data was accessed outside the expected scope.',
    'high',
    'AUD-006-RC03: Revoke cross-database access from admin login - SQL Server', 'remediate',
    'Revoke CONNECT and object-level grants on out-of-scope databases: REVOKE CONNECT ON DATABASE::<db> FROM <login>. Remove db_datareader membership in unauthorized databases. Enable contained database authentication to isolate schemas.',
    'medium', true,
    'AUD-006-RC03: Audit out-of-scope object access via DMVs - SQL Server', 'verify',
    'Query sys.dm_exec_query_stats and sys.objects to identify tables accessed by the login outside its authorized database. Review the SQL Server Audit log or default trace for schema access events in the incident timeframe.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-006-RC03', 'mysql',
    'Revoke cross-database grants from SUPER account - MySQL',
    'aud-006-rc03-revoke-cross-schema-mysql',
    'Revoke cross-database grants from the privileged account and restrict it to its expected database scope.',
    'high',
    'AUD-006-RC03: Revoke cross-database grants - MySQL', 'remediate',
    'Revoke wildcard database grants: REVOKE ALL PRIVILEGES ON <out_of_scope_db>.* FROM ''<user>''@''%''. Restrict to specific application database: GRANT SELECT, INSERT, UPDATE, DELETE ON <app_db>.* TO ''<user>''@''%''. Run FLUSH PRIVILEGES after changes.',
    'medium', true,
    'AUD-006-RC03: Review general log for cross-database queries - MySQL', 'verify',
    'Enable the general query log temporarily and review entries for the incident period. Check INFORMATION_SCHEMA.USER_PRIVILEGES and SCHEMA_PRIVILEGES to confirm no remaining cross-database grants exist for the affected account.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-006-RC03', 'oracle',
    'Revoke cross-schema grants from DBA account - Oracle',
    'aud-006-rc03-revoke-cross-schema-oracle',
    'Revoke cross-schema object privileges from the DBA account and implement Database Vault to enforce schema boundaries.',
    'high',
    'AUD-006-RC03: Revoke cross-schema object grants - Oracle', 'remediate',
    'Revoke explicit cross-schema grants: REVOKE SELECT, INSERT, UPDATE, DELETE ON <out_of_scope_schema>.<table> FROM <dba_account>. Review DBA_TAB_PRIVS for all cross-schema grants held by the account and revoke each. Create a Database Vault realm for the protected schema.',
    'medium', true,
    'AUD-006-RC03: Audit accessed objects in out-of-scope schema - Oracle', 'verify',
    'Query DBA_AUDIT_TRAIL or V$SQL filtered by parsing_user_id to identify all objects accessed in the out-of-scope schema during the incident window. Document accessed tables and columns for the data breach assessment.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-006-RC04  Service account performing interactive transactions
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-006-RC04', 'postgresql',
    'Terminate service account interactive session and rotate credentials - PostgreSQL',
    'aud-006-rc04-terminate-service-account-interactive-pg',
    'Terminate the interactive service account session, rotate its credentials, and restrict the account to application-only programmatic access.',
    'high',
    'AUD-006-RC04: Terminate interactive service account session - PostgreSQL', 'immediate',
    'Terminate the session: SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid = <target_pid>. Document usename, application_name, client_addr, and all query text from the session before terminating.',
    'high', false,
    'AUD-006-RC04: Rotate credentials and restrict service account - PostgreSQL', 'remediate',
    'Rotate the password: ALTER ROLE <service_account> PASSWORD ''<new_strong_password>''. Restrict connections: ALTER ROLE <service_account> CONNECTION LIMIT 10. Add a pg_hba.conf rule limiting the account to the application server IP range only. Reload config with SELECT pg_reload_conf().',
    'medium', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-006-RC04', 'sqlserver',
    'Terminate service account interactive session and rotate credentials - SQL Server',
    'aud-006-rc04-terminate-service-account-interactive-sqlserver',
    'Kill the interactive service account session, reset its password, and enforce programmatic-only access through application role or connection string restrictions.',
    'high',
    'AUD-006-RC04: Kill interactive service account session - SQL Server', 'immediate',
    'Kill the session: KILL <spid>. Capture sys.dm_exec_sessions details (login_name, host_name, program_name, client_interface_name) to identify how the interactive connection was established.',
    'high', false,
    'AUD-006-RC04: Reset password and restrict service login - SQL Server', 'remediate',
    'Reset the password: ALTER LOGIN <service_login> WITH PASSWORD = ''<new_password>''. Deny interactive logon by enforcing login via application role only. Consider switching to Windows-integrated authentication with a managed service account to eliminate password exposure.',
    'medium', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-006-RC04', 'mysql',
    'Terminate service account interactive session and rotate credentials - MySQL',
    'aud-006-rc04-terminate-service-account-interactive-mysql',
    'Kill the interactive service account thread, rotate credentials, and enforce host-restricted access for the service account.',
    'high',
    'AUD-006-RC04: Kill interactive service account thread - MySQL', 'immediate',
    'Kill the thread: KILL <process_id>. Record USER, HOST, DB, and INFO from INFORMATION_SCHEMA.PROCESSLIST to document how the interactive connection was made (client tool, source host).',
    'high', false,
    'AUD-006-RC04: Rotate password and restrict service account host - MySQL', 'remediate',
    'Rotate password: ALTER USER ''<service_user>''@''%'' IDENTIFIED BY ''<new_password>''. Restrict to application server: DROP USER ''<service_user>''@''%'' and CREATE USER ''<service_user>''@''<app_server_ip>''. FLUSH PRIVILEGES. Consider using mysql_native_password with a vault-managed secret.',
    'medium', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-006-RC04', 'oracle',
    'Terminate service account interactive session and rotate credentials - Oracle',
    'aud-006-rc04-terminate-service-account-interactive-oracle',
    'Kill the interactive service account session, rotate its password, and lock it to prevent future interactive connections.',
    'high',
    'AUD-006-RC04: Kill interactive service account session - Oracle', 'immediate',
    'Kill the session: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE. Document V$SESSION columns PROGRAM, MODULE, ACTION, and MACHINE to establish how the interactive session was initiated.',
    'high', false,
    'AUD-006-RC04: Rotate password and restrict service account - Oracle', 'remediate',
    'Rotate credentials: ALTER USER <service_account> IDENTIFIED BY <new_password>. Apply a profile that restricts LOGIN via password complexity and FAILED_LOGIN_ATTEMPTS. Use DBMS_NETWORK_ACL or logon trigger to block interactive tool connections and allow only the application server host.',
    'medium', true
  );

-- ============================================================
-- SEC-SQL-AUD-006-RC05  Privilege escalation during active session
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-006-RC05', 'postgresql',
    'Terminate escalated session and revoke unauthorized grants - PostgreSQL',
    'aud-006-rc05-terminate-escalated-session-pg',
    'Terminate the session that performed mid-session privilege escalation and revoke any roles granted or changes made during the escalated period.',
    'high',
    'AUD-006-RC05: Terminate privilege-escalated session - PostgreSQL', 'immediate',
    'Terminate the session: SELECT pg_terminate_backend(pid). Before killing, capture the session''s current role memberships via SELECT rolname FROM pg_roles JOIN pg_auth_members ON pg_roles.oid = pg_auth_members.roleid WHERE member = <session_user_oid> to identify what was escalated to.',
    'high', false,
    'AUD-006-RC05: Revoke unauthorized role grants - PostgreSQL', 'remediate',
    'Identify and revoke grants made during the escalated session: REVOKE <role> FROM <principal>. Review pg_audit log for SET ROLE, GRANT, and CREATE ROLE statements in the incident window. Reset all affected principals to their baseline privilege set.',
    'high', false
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-006-RC05', 'sqlserver',
    'Terminate escalated session and revoke unauthorized grants - SQL Server',
    'aud-006-rc05-terminate-escalated-session-sqlserver',
    'Kill the session that used EXECUTE AS or GRANT to escalate privileges mid-session and audit what actions were taken under the elevated context.',
    'high',
    'AUD-006-RC05: Kill impersonating or escalated session - SQL Server', 'immediate',
    'Kill the session: KILL <spid>. Capture sys.dm_exec_sessions columns login_name vs original_login_name to confirm impersonation was active. Document what commands were issued under the escalated context from the SQL audit log.',
    'high', false,
    'AUD-006-RC05: Revoke IMPERSONATE and unauthorized grants - SQL Server', 'remediate',
    'Revoke IMPERSONATE: REVOKE IMPERSONATE ON LOGIN::<target_login> FROM <principal>. Review sys.server_permissions and sys.database_permissions for any GRANT statements executed during the session. Remove all unauthorized permissions and audit server_role_members changes.',
    'high', false
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-006-RC05', 'mysql',
    'Terminate escalated session and revoke unauthorized grants - MySQL',
    'aud-006-rc05-terminate-escalated-session-mysql',
    'Kill the session that issued unauthorized GRANT statements and remove any privileges granted during the escalation.',
    'high',
    'AUD-006-RC05: Kill session that issued unauthorized GRANTs - MySQL', 'immediate',
    'Kill the thread: KILL <process_id>. Review INFORMATION_SCHEMA.USER_PRIVILEGES and SCHEMA_PRIVILEGES to identify any grants that were applied during the incident window using audit log timestamps.',
    'high', false,
    'AUD-006-RC05: Revoke unauthorized privileges - MySQL', 'remediate',
    'Revoke each unauthorized grant: REVOKE <privilege> ON <scope> FROM ''<user>''@''<host>''. Run FLUSH PRIVILEGES. Cross-reference mysql.general_log or audit_log_plugin entries for GRANT statements in the incident window. Confirm final privilege state matches the approved baseline.',
    'high', false
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-006-RC05', 'oracle',
    'Terminate escalated session and revoke unauthorized grants - Oracle',
    'aud-006-rc05-terminate-escalated-session-oracle',
    'Kill the session that used proxy activation or GRANT to escalate and revoke all privileges granted during the escalated period.',
    'high',
    'AUD-006-RC05: Kill privilege-escalated Oracle session - Oracle', 'immediate',
    'Kill the session: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE. Check V$SESSION for PROXY_USER (indicating proxy escalation) and review UNIFIED_AUDIT_TRAIL for GRANT, CREATE ROLE, and ALTER USER statements issued in the session.',
    'high', false,
    'AUD-006-RC05: Revoke unauthorized grants and proxy access - Oracle', 'remediate',
    'Revoke unauthorized system or object privileges: REVOKE <privilege> FROM <principal>. Revoke proxy: ALTER USER <target_user> REVOKE CONNECT THROUGH <proxy_user>. Audit DBA_SYS_PRIVS and DBA_ROLE_PRIVS against the approved baseline and remove all deviations.',
    'high', false
  );

-- ============================================================
-- SEC-SQL-AUD-007-RC01  Unregistered application signatures
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-007-RC01', 'postgresql',
    'Block unregistered application and update approved registry - PostgreSQL',
    'aud-007-rc01-block-unregistered-app-pg',
    'Terminate connections from the unregistered application, block it at the connection layer, and update the approved application registry.',
    'high',
    'AUD-007-RC01: Terminate and block unregistered application sessions - PostgreSQL', 'immediate',
    'Terminate all sessions from the unregistered application_name: SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE application_name = ''<unregistered_app>''. Add a pg_hba.conf REJECT rule for the client IP or application tag. Reload with SELECT pg_reload_conf().',
    'high', false,
    'AUD-007-RC01: Update approved application registry - PostgreSQL', 'configure',
    'Either add the application to the approved registry table (if it is legitimately new) or document the block in the change record. Review pg_stat_activity.application_name values for other sessions with unrecognised names and validate against the approved application list.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-007-RC01', 'sqlserver',
    'Block unregistered application and update approved registry - SQL Server',
    'aud-007-rc01-block-unregistered-app-sqlserver',
    'Kill sessions from the unregistered application, create a logon trigger to block future connections, and update the approved application list.',
    'high',
    'AUD-007-RC01: Kill and block unregistered application sessions - SQL Server', 'immediate',
    'Kill all sessions with the unregistered program_name: KILL <spid> for each. Create a logon trigger that rolls back the connection if APP_NAME() is not in the approved list. Test the trigger in a non-production environment before deploying to production.',
    'high', false,
    'AUD-007-RC01: Update application allowlist and audit connections - SQL Server', 'configure',
    'Update the approved application name table used by the logon trigger. Enable Server Audit to capture login events with program_name for ongoing monitoring. Review sys.dm_exec_sessions for any remaining unregistered application_names.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-007-RC01', 'mysql',
    'Block unregistered application and update approved registry - MySQL',
    'aud-007-rc01-block-unregistered-app-mysql',
    'Kill threads from the unregistered application, block its host, and update the allowed connection sources.',
    'high',
    'AUD-007-RC01: Kill threads from unregistered application - MySQL', 'immediate',
    'Kill each thread from the unregistered application: KILL <process_id>. Revoke connection privileges from the offending host: REVOKE ALL ON *.* FROM ''<user>''@''<unregistered_host>''. Use firewall rules or mysql_firewall plugin to block the source host at the network level.',
    'high', false,
    'AUD-007-RC01: Update approved connection registry - MySQL', 'configure',
    'Update the approved host list maintained by the mysql_firewall plugin or application registry table. Enable audit_log_plugin with filter on PROGRAM_NAME to flag future connections from unregistered sources. Review INFORMATION_SCHEMA.PROCESSLIST for any remaining unrecognised programs.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-007-RC01', 'oracle',
    'Block unregistered application and update approved registry - Oracle',
    'aud-007-rc01-block-unregistered-app-oracle',
    'Kill sessions from the unregistered application, implement a logon trigger to enforce application registration, and update the approved application registry.',
    'high',
    'AUD-007-RC01: Kill unregistered application sessions - Oracle', 'immediate',
    'Kill the session: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE. Identify all sessions with the unregistered MODULE or PROGRAM value in V$SESSION and terminate each. Document CLIENT_INFO and ACTION fields for the incident record.',
    'high', false,
    'AUD-007-RC01: Implement logon trigger for application validation - Oracle', 'configure',
    'Create an AFTER LOGON trigger that checks SYS_CONTEXT(''USERENV'',''MODULE'') against an approved_applications lookup table and calls RAISE_APPLICATION_ERROR to reject unregistered tools. Update the approved application registry with legitimately new applications after change-management approval.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-007-RC02  Query patterns not matching baseline
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-007-RC02', 'postgresql',
    'Terminate anomalous query session and capture forensics - PostgreSQL',
    'aud-007-rc02-terminate-anomalous-query-pg',
    'Terminate the session issuing queries that deviate from the known baseline and capture the query plan and statement text for forensic analysis.',
    'high',
    'AUD-007-RC02: Terminate anomalous query session - PostgreSQL', 'immediate',
    'Capture full query text and execution plan before terminating: SELECT query, query_start, state, client_addr FROM pg_stat_activity WHERE pid = <target_pid>. Run EXPLAIN ANALYZE on the anomalous query if safe to do so. Then terminate: SELECT pg_terminate_backend(<target_pid>).',
    'high', false,
    'AUD-007-RC02: Analyze query forensics and update baseline - PostgreSQL', 'verify',
    'Review pg_stat_statements for the query digest, call count, and mean execution time. Determine if the query accesses tables or columns outside the expected application workload. Update the workload baseline or block the query pattern via pg_query_settings or connection pooler rules if it is confirmed malicious.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-007-RC02', 'sqlserver',
    'Terminate anomalous query session and capture forensics - SQL Server',
    'aud-007-rc02-terminate-anomalous-query-sqlserver',
    'Kill the session running an anomalous query, preserve the execution plan and statement text, and update the query baseline.',
    'high',
    'AUD-007-RC02: Kill anomalous query session - SQL Server', 'immediate',
    'Capture the query plan: SELECT query_plan FROM sys.dm_exec_query_plan WHERE plan_handle = <handle>. Record sys.dm_exec_requests details. Kill the session: KILL <spid>. Preserve the plan XML and SQL text as evidence.',
    'high', false,
    'AUD-007-RC02: Forensic query analysis and baseline update - SQL Server', 'verify',
    'Review Query Store for the anomalous plan: SELECT * FROM sys.query_store_query WHERE is_internal_query = 0. Identify tables accessed outside the normal application schema. If the query is confirmed malicious, add it to a Resource Governor classifier or blocked process threshold alert.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-007-RC02', 'mysql',
    'Terminate anomalous query session and capture forensics - MySQL',
    'aud-007-rc02-terminate-anomalous-query-mysql',
    'Kill the thread issuing anomalous query patterns and analyze performance_schema history to update the baseline.',
    'high',
    'AUD-007-RC02: Kill anomalous query thread - MySQL', 'immediate',
    'Capture the statement from performance_schema.events_statements_history_long before killing. Record DIGEST, SQL_TEXT, ROWS_EXAMINED, ROWS_SENT, and TIMER_WAIT. Kill the thread: KILL <process_id>.',
    'high', false,
    'AUD-007-RC02: Analyze statement history and update allowlist - MySQL', 'verify',
    'Query performance_schema.events_statements_summary_by_digest filtering on DIGEST_TEXT for the anomalous pattern. Determine accessed tables via performance_schema.table_io_waits_summary_by_table. If confirmed malicious, add the DIGEST to a blocked-statement policy or update the connection firewall ruleset.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-007-RC02', 'oracle',
    'Terminate anomalous query session and capture forensics - Oracle',
    'aud-007-rc02-terminate-anomalous-query-oracle',
    'Kill the session issuing out-of-baseline queries and capture AWR or ASH evidence for forensic analysis.',
    'high',
    'AUD-007-RC02: Kill anomalous query session - Oracle', 'immediate',
    'Capture the execution plan: SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(''<sql_id>'',NULL,''ALLSTATS LAST'')) before killing. Kill the session: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE. Record V$SQL rows for the anomalous sql_id.',
    'high', false,
    'AUD-007-RC02: AWR and ASH forensic analysis - Oracle', 'verify',
    'Query DBA_HIST_SQLTEXT and V$SQL_MONITOR for the anomalous SQL ID. Use ASH report (DBMS_WORKLOAD_REPOSITORY.AWR_REPORT_HTML) to reconstruct session activity. If the query is confirmed malicious, create a SQL Profile or SQL Plan Baseline to prevent the execution plan from being reused.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-007-RC03  Connections from unexpected network addresses
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-007-RC03', 'postgresql',
    'Block unexpected network source and terminate sessions - PostgreSQL',
    'aud-007-rc03-block-unexpected-ip-pg',
    'Terminate active connections from the unexpected IP range and update pg_hba.conf to block future connections from unauthorized network addresses.',
    'high',
    'AUD-007-RC03: Terminate sessions from unexpected IP - PostgreSQL', 'immediate',
    'Terminate all sessions from the unauthorized IP: SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE client_addr <<= ''<cidr_range>''::inet. Reload pg_hba.conf after adding a REJECT rule for the IP range: SELECT pg_reload_conf().',
    'high', false,
    'AUD-007-RC03: Update pg_hba.conf and validate connection sources - PostgreSQL', 'configure',
    'Add a REJECT rule in pg_hba.conf for the unauthorized CIDR range before the permit-all rule. Coordinate with the network team to block the range at the perimeter firewall. Review pg_stat_activity.client_addr for any remaining sessions from unrecognised IP ranges.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-007-RC03', 'sqlserver',
    'Block unexpected network source and terminate sessions - SQL Server',
    'aud-007-rc03-block-unexpected-ip-sqlserver',
    'Kill sessions originating from unexpected IP addresses and create a firewall rule or logon trigger to block the IP range at the database level.',
    'high',
    'AUD-007-RC03: Kill sessions from unexpected IP - SQL Server', 'immediate',
    'Kill each session from the unauthorized host: KILL <spid> for each spid with client_net_address outside the approved CIDR in sys.dm_exec_sessions. Coordinate with the network team to add a Windows Firewall rule blocking the IP range on port 1433.',
    'high', false,
    'AUD-007-RC03: Add logon trigger to enforce IP allowlist - SQL Server', 'configure',
    'Create or update a LOGON trigger that checks EVENTDATA() for the ClientHost value and rejects connections from IP ranges not in the approved_networks table. Enable SQL Server Audit to log all future login events with client_net_address for ongoing monitoring.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-007-RC03', 'mysql',
    'Block unexpected network source and restrict MySQL access - MySQL',
    'aud-007-rc03-block-unexpected-ip-mysql',
    'Kill threads from unexpected source hosts, revoke connection grants for those hosts, and update the MySQL bind-address and firewall configuration.',
    'high',
    'AUD-007-RC03: Kill threads from unexpected host - MySQL', 'immediate',
    'Kill all threads from the unauthorized host: KILL <process_id> for each entry in INFORMATION_SCHEMA.PROCESSLIST where HOST matches the unauthorized IP. Revoke grants for that host: REVOKE ALL ON *.* FROM ''<user>''@''<unauthorized_host>''. FLUSH PRIVILEGES.',
    'high', false,
    'AUD-007-RC03: Update MySQL host allowlist and firewall - MySQL', 'configure',
    'Create user entries only for approved application server IPs. Use MySQL Enterprise Firewall or OS-level iptables to block port 3306 from the unauthorized network range. Set bind-address to the application network interface only in my.cnf if the server should not be reachable from external ranges.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-007-RC03', 'oracle',
    'Block unexpected network source and update Oracle access control - Oracle',
    'aud-007-rc03-block-unexpected-ip-oracle',
    'Kill sessions from unexpected IP addresses and configure valid-node-checking or a logon trigger to enforce the approved connection source list.',
    'high',
    'AUD-007-RC03: Kill sessions from unexpected IP - Oracle', 'immediate',
    'Kill the sessions: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE for each session in V$SESSION where MACHINE or TERMINAL maps to the unexpected IP. Collect MACHINE, TERMINAL, USERNAME, and PROGRAM for the incident record.',
    'high', false,
    'AUD-007-RC03: Enable valid-node-checking and firewall update - Oracle', 'configure',
    'Set sqlnet.ora parameters TCP.VALIDNODE_CHECKING=YES and TCP.INVITED_NODES to the approved IP list. Reload the listener. Coordinate with the network team to block the unexpected IP range at the OS firewall on the database server port. Review UNIFIED_AUDIT_TRAIL for all login events from the blocked range.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-007-RC04  Off-hours activity from non-automated accounts
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-007-RC04', 'postgresql',
    'Terminate off-hours human account session and investigate - PostgreSQL',
    'aud-007-rc04-terminate-off-hours-session-pg',
    'Terminate the human account session active outside business hours and investigate whether the access was authorised.',
    'medium',
    'AUD-007-RC04: Terminate off-hours session - PostgreSQL', 'immediate',
    'Terminate the session: SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid = <target_pid>. Capture usename, application_name, client_addr, query, and query_start. Notify the security team and the account owner for immediate investigation.',
    'medium', false,
    'AUD-007-RC04: Investigate off-hours access and review access policy - PostgreSQL', 'verify',
    'Review pg_audit log for all statements executed during the off-hours session. Check whether the access matches a known exception (on-call incident, approved maintenance). If unauthorised, escalate to the incident response process and enforce time-based access restrictions via a logon trigger.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-007-RC04', 'sqlserver',
    'Terminate off-hours human account session and investigate - SQL Server',
    'aud-007-rc04-terminate-off-hours-session-sqlserver',
    'Kill the human account session active outside business hours and determine whether a standing exception or compromise explains the access.',
    'medium',
    'AUD-007-RC04: Kill off-hours human account session - SQL Server', 'immediate',
    'Kill the session: KILL <spid>. Capture sys.dm_exec_sessions details including login_name, login_time, host_name, and program_name. Notify the security team with the session evidence for investigation.',
    'medium', false,
    'AUD-007-RC04: Investigate and enforce time-based access restrictions - SQL Server', 'verify',
    'Review SQL Server Audit logs for the full statement history of the off-hours session. Confirm whether the access matches an approved exception. Implement a LOGON trigger that restricts connection to business hours for non-service accounts. Update the incident playbook with findings.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-007-RC04', 'mysql',
    'Terminate off-hours human account session and investigate - MySQL',
    'aud-007-rc04-terminate-off-hours-session-mysql',
    'Kill the human account thread active during off-hours and assess whether the access was authorised.',
    'medium',
    'AUD-007-RC04: Kill off-hours human account thread - MySQL', 'immediate',
    'Kill the thread: KILL <process_id>. Record USER, HOST, DB, TIME, and INFO from INFORMATION_SCHEMA.PROCESSLIST. Notify the security team with the connection details and timeline for investigation.',
    'medium', false,
    'AUD-007-RC04: Review audit log and update access schedule policy - MySQL', 'verify',
    'Review audit_log_plugin entries for the full activity of the off-hours session. Confirm whether the access was authorised (emergency incident work). Implement a logon trigger or connection-control plugin to restrict non-service accounts to permitted hours. Update the account access schedule in the ITSM system.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-007-RC04', 'oracle',
    'Terminate off-hours human account session and investigate - Oracle',
    'aud-007-rc04-terminate-off-hours-session-oracle',
    'Kill the human account session active outside approved hours and evaluate whether a compromise or policy violation occurred.',
    'medium',
    'AUD-007-RC04: Kill off-hours human session - Oracle', 'immediate',
    'Kill the session: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE. Capture V$SESSION columns USERNAME, OSUSER, MACHINE, PROGRAM, LOGON_TIME, and last SQL_ID. Notify the DBA manager and security team immediately.',
    'medium', false,
    'AUD-007-RC04: UNIFIED_AUDIT_TRAIL review and access policy update - Oracle', 'verify',
    'Query UNIFIED_AUDIT_TRAIL for all actions in the off-hours session. Determine if they match a known emergency change request. If no authorisation exists escalate to incident response. Implement a logon trigger using DBMS_SESSION and SYSDATE to block non-service accounts outside approved hours.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-007-RC05  Execution of previously unseen stored procedures
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-007-RC05', 'postgresql',
    'Terminate session calling unseen function and quarantine the object - PostgreSQL',
    'aud-007-rc05-terminate-unseen-procedure-pg',
    'Terminate the session that called the previously unseen function and quarantine or drop the object pending security review.',
    'high',
    'AUD-007-RC05: Terminate session calling unseen function - PostgreSQL', 'immediate',
    'Terminate the session: SELECT pg_terminate_backend(pid). Record the function name, owner (pg_proc.proowner), source definition (pg_proc.prosrc), creation timestamp (obj_description), and calling session details before taking further action.',
    'high', false,
    'AUD-007-RC05: Quarantine and review unseen function - PostgreSQL', 'verify',
    'Revoke EXECUTE on the suspicious function: REVOKE EXECUTE ON FUNCTION <schema>.<func>(<args>) FROM PUBLIC. Inspect pg_proc.prosrc for malicious logic (shell commands, network calls, or data exfiltration patterns). If confirmed malicious, DROP the function and open a security incident. Review pg_audit for all callers.',
    'high', false
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-007-RC05', 'sqlserver',
    'Terminate session calling unseen procedure and quarantine the object - SQL Server',
    'aud-007-rc05-terminate-unseen-procedure-sqlserver',
    'Kill the session that executed the previously unseen stored procedure and review the object for malicious logic.',
    'high',
    'AUD-007-RC05: Kill session calling unseen procedure - SQL Server', 'immediate',
    'Kill the session: KILL <spid>. Capture the procedure name, schema, create_date, and last_execution_time from sys.objects and sys.dm_exec_procedure_stats. Review OBJECT_DEFINITION(<object_id>) for the full procedure source.',
    'high', false,
    'AUD-007-RC05: Review and disable unseen stored procedure - SQL Server', 'verify',
    'Inspect the procedure source for xp_cmdshell calls, OPENROWSET to external sources, or bulk export patterns. Revoke EXECUTE on the procedure: REVOKE EXECUTE ON <schema>.<procedure> FROM PUBLIC. If malicious, DROP the procedure and raise a security incident. Review Extended Events for all execution history.',
    'high', false
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-007-RC05', 'mysql',
    'Terminate session calling unseen routine and quarantine the object - MySQL',
    'aud-007-rc05-terminate-unseen-procedure-mysql',
    'Kill the thread that called the previously unseen routine and inspect the object for malicious content.',
    'high',
    'AUD-007-RC05: Kill thread calling unseen routine - MySQL', 'immediate',
    'Kill the thread: KILL <process_id>. Retrieve the routine definition: SELECT ROUTINE_DEFINITION FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_SCHEMA = ''<db>'' AND ROUTINE_NAME = ''<routine>''. Document the CREATED and LAST_ALTERED timestamps.',
    'high', false,
    'AUD-007-RC05: Inspect and drop suspicious routine - MySQL', 'verify',
    'Review the routine body for LOAD DATA INFILE, SELECT INTO OUTFILE, OS-level calls, or exfiltration patterns. Revoke EXECUTE on the routine: REVOKE EXECUTE ON PROCEDURE <db>.<routine> FROM ''%''. If malicious, DROP the routine and open a security incident. Review audit_log for all prior calls.',
    'high', false
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-007-RC05', 'oracle',
    'Terminate session calling unseen procedure and quarantine the object - Oracle',
    'aud-007-rc05-terminate-unseen-procedure-oracle',
    'Kill the session that executed the previously unseen procedure and review the object for malicious logic using DBA_SOURCE.',
    'high',
    'AUD-007-RC05: Kill session calling unseen procedure - Oracle', 'immediate',
    'Kill the session: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE. Record the procedure name and owner from V$SQL (OBJECT_NAME, PARSING_SCHEMA_NAME). Retrieve source: SELECT TEXT FROM DBA_SOURCE WHERE NAME = ''<proc>'' AND OWNER = ''<owner>'' ORDER BY LINE.',
    'high', false,
    'AUD-007-RC05: Review and revoke unseen procedure - Oracle', 'verify',
    'Inspect DBA_SOURCE for UTL_FILE, UTL_HTTP, DBMS_SCHEDULER, or Java callout usage indicating a backdoor or exfiltration mechanism. Revoke EXECUTE: REVOKE EXECUTE ON <owner>.<proc> FROM PUBLIC. If malicious, DROP the object and raise a P1 security incident. Search UNIFIED_AUDIT_TRAIL for all prior invocations.',
    'high', false
  );

-- ============================================================
-- SEC-SQL-AUD-008-RC01  Bulk data export on sensitive tables
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-008-RC01', 'postgresql',
    'Terminate bulk export session and assess data exposure - PostgreSQL',
    'aud-008-rc01-terminate-bulk-export-pg',
    'Terminate the session performing a large-volume SELECT from sensitive tables and assess whether data left the system.',
    'critical',
    'AUD-008-RC01: Terminate bulk export session - PostgreSQL', 'immediate',
    'Terminate the session: SELECT pg_terminate_backend(pid). Record usename, client_addr, application_name, and the full query text from pg_stat_activity. Capture bytes_sent from the session if available via connection-level metrics to estimate data volume transferred.',
    'high', false,
    'AUD-008-RC01: Assess data exposure and notify DPO - PostgreSQL', 'verify',
    'Query pg_stat_user_tables for n_live_tup on the affected sensitive tables to estimate the row count that may have been exported. Review pgaudit log for SELECT statement details and row counts. If PII or sensitive data was exported, notify the Data Protection Officer and initiate the data breach response procedure.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-008-RC01', 'sqlserver',
    'Terminate bulk export session and assess data exposure - SQL Server',
    'aud-008-rc01-terminate-bulk-export-sqlserver',
    'Kill the session performing a mass SELECT from sensitive tables and assess the volume and nature of data exported.',
    'critical',
    'AUD-008-RC01: Kill bulk export session - SQL Server', 'immediate',
    'Kill the session: KILL <spid>. Capture sys.dm_exec_sessions row_count, total_elapsed_time, logical_reads, and the SQL text via sys.dm_exec_sql_text before killing. Estimate exported row count from query results in memory.',
    'high', false,
    'AUD-008-RC01: Assess data exposure and invoke breach process - SQL Server', 'verify',
    'Review SQL Server Audit for the exact SELECT statement, row count, and client address. Cross-reference network logs for data volume sent to the client IP. If sensitive data was transferred notify the Data Protection Officer and follow the data breach notification procedure per GDPR or applicable regulation.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-008-RC01', 'mysql',
    'Terminate bulk export session and assess data exposure - MySQL',
    'aud-008-rc01-terminate-bulk-export-mysql',
    'Kill the thread performing a large-volume SELECT from sensitive tables and assess what data was transferred.',
    'critical',
    'AUD-008-RC01: Kill bulk export thread - MySQL', 'immediate',
    'Kill the thread: KILL <process_id>. Capture USER, HOST, DB, TIME, and INFO from INFORMATION_SCHEMA.PROCESSLIST. Check performance_schema.events_statements_history_long for ROWS_SENT on the matching DIGEST to estimate exported volume.',
    'high', false,
    'AUD-008-RC01: Assess data exposure and notify DPO - MySQL', 'verify',
    'Review audit_log_plugin entries for SELECT statements on the sensitive table with high ROWS_SENT counts. Correlate with network-level data transfer logs to the client HOST. If PII or regulated data was transferred, notify the Data Protection Officer and follow the incident response plan.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-008-RC01', 'oracle',
    'Terminate bulk export session and assess data exposure - Oracle',
    'aud-008-rc01-terminate-bulk-export-oracle',
    'Kill the session performing a mass SELECT from sensitive Oracle tables and use ASH and network logs to estimate data exposure.',
    'critical',
    'AUD-008-RC01: Kill bulk export session - Oracle', 'immediate',
    'Kill the session: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE. Capture V$SESSION and V$SQL_MONITOR columns FETCHES, ROWS_PROCESSED, IO_INTERCONNECT_BYTES, and SQL_TEXT to document the scope of the export.',
    'high', false,
    'AUD-008-RC01: ASH forensics and DPO notification - Oracle', 'verify',
    'Query V$ACTIVE_SESSION_HISTORY and DBA_HIST_ACTIVE_SESS_HISTORY for the session''s full activity timeline. Review UNIFIED_AUDIT_TRAIL SELECT audit records for the sensitive table and correlate ROWS_RETURNED with network transfer logs. If regulated data was exported initiate the data breach notification procedure.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-008-RC02  Mass DELETE or TRUNCATE without WHERE clause
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-008-RC02', 'postgresql',
    'Terminate mass deletion and assess recovery options - PostgreSQL',
    'aud-008-rc02-terminate-mass-deletion-pg',
    'Terminate or roll back the mass DELETE or TRUNCATE and initiate point-in-time recovery if the transaction was committed.',
    'critical',
    'AUD-008-RC02: Terminate or roll back mass deletion - PostgreSQL', 'immediate',
    'If the transaction is still open, terminate the session to trigger implicit ROLLBACK: SELECT pg_terminate_backend(pid). If already committed, identify the last known-good LSN from pg_current_wal_lsn() at backup time and prepare a point-in-time restore from the base backup plus WAL archive to that LSN.',
    'high', false,
    'AUD-008-RC02: Point-in-time restore or pg_dirtyread recovery - PostgreSQL', 'remediate',
    'Restore from the most recent logical backup (pg_dump) or from the PITR WAL archive to a point before the deletion. Alternatively use pg_dirtyread (if available) to recover rows from the heap file before vacuum reclaims them. Revoke DELETE and TRUNCATE privileges from the offending account after recovery.',
    'high', false
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-008-RC02', 'sqlserver',
    'Terminate mass deletion and initiate restore - SQL Server',
    'aud-008-rc02-terminate-mass-deletion-sqlserver',
    'Roll back or kill the mass DELETE transaction and restore deleted rows from transaction log backup or CDC if committed.',
    'critical',
    'AUD-008-RC02: Roll back or kill mass deletion session - SQL Server', 'immediate',
    'If the transaction is active, kill the session to trigger rollback: KILL <spid>. If committed, determine the LSN using fn_dblog() before the DELETE and prepare a WITH STOPAT restore to a point-in-time before the deletion.',
    'high', false,
    'AUD-008-RC02: Restore deleted rows from log or backup - SQL Server', 'remediate',
    'Use fn_dblog() or ApexSQL Log to extract the before-image of deleted rows and construct reverse INSERT statements. Alternatively restore to a secondary/standby database to point-in-time and export the missing rows for re-insertion. Revoke DELETE and TRUNCATE TABLE from the offending login after recovery.',
    'high', false
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-008-RC02', 'mysql',
    'Terminate mass deletion and initiate restore - MySQL',
    'aud-008-rc02-terminate-mass-deletion-mysql',
    'Kill the mass DELETE thread, roll back using binary log if InnoDB transaction is uncommitted, or restore from backup if committed.',
    'critical',
    'AUD-008-RC02: Kill mass deletion thread - MySQL', 'immediate',
    'Kill the thread: KILL <process_id>. If the DELETE is still running and in InnoDB, killing terminates the transaction with automatic rollback. Check INFORMATION_SCHEMA.INNODB_TRX for trx_state before killing to confirm rollback will occur.',
    'high', false,
    'AUD-008-RC02: Restore from binary log or backup - MySQL', 'remediate',
    'If committed, use mysqlbinlog with --start-position and --stop-position to extract the before-image and generate reverse INSERT statements using the row-based binlog format. Alternatively restore from the most recent mysqldump or XtraBackup to a recovery instance and re-insert the missing rows. Revoke DELETE on the sensitive tables from the offending account.',
    'high', false
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-008-RC02', 'oracle',
    'Terminate mass deletion and restore using Flashback - Oracle',
    'aud-008-rc02-terminate-mass-deletion-oracle',
    'Kill the session performing the mass DELETE and use Oracle Flashback to restore rows if undo retention or a Flashback Database restore point covers the incident window.',
    'critical',
    'AUD-008-RC02: Kill mass deletion session - Oracle', 'immediate',
    'Kill the session: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE. If the transaction was uncommitted, killing it triggers a rollback. Verify by querying V$TRANSACTION for remaining open transactions on the affected table. If committed, proceed to Flashback recovery.',
    'high', false,
    'AUD-008-RC02: Flashback Table or RMAN PITR recovery - Oracle', 'remediate',
    'Recover deleted rows: FLASHBACK TABLE <schema>.<table> TO TIMESTAMP (SYSTIMESTAMP - INTERVAL ''N'' MINUTE) if undo retention allows. Alternatively use RMAN RECOVER TABLE from a backup set for row-level granularity. After recovery, revoke DELETE and DROP on the table from the offending account and add ENABLE ROW MOVEMENT if Flashback Table is to be kept as a recovery option.',
    'high', false
  );

-- ============================================================
-- SEC-SQL-AUD-008-RC03  DDL executed by non-DBA accounts
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-008-RC03', 'postgresql',
    'Rollback unauthorized DDL and revoke DDL privileges - PostgreSQL',
    'aud-008-rc03-rollback-unauthorized-ddl-pg',
    'Reverse unauthorized DDL changes made by a non-DBA account and revoke the DDL privileges that allowed the violation.',
    'critical',
    'AUD-008-RC03: Reverse unauthorized DDL objects - PostgreSQL', 'remediate',
    'If DDL was in an open transaction, terminate the session to trigger rollback: SELECT pg_terminate_backend(pid). If committed, manually reverse: DROP or ALTER the object back to its prior state using the schema captured from information_schema at the last approved point. Use pg_dump --schema-only as the reference.',
    'high', false,
    'AUD-008-RC03: Revoke CREATE and DDL privileges from non-DBA account - PostgreSQL', 'remediate',
    'Revoke DDL grants: REVOKE CREATE ON SCHEMA <schema> FROM <non_dba_role>. Revoke object-level DDL: REVOKE ALL ON TABLE <obj> FROM <role> and reassign ownership. Implement a DDL event trigger to log and optionally block CREATE/ALTER/DROP from non-approved roles. Review all pg_class entries for objects created by the offending role.',
    'medium', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-008-RC03', 'sqlserver',
    'Rollback unauthorized DDL and revoke DDL privileges - SQL Server',
    'aud-008-rc03-rollback-unauthorized-ddl-sqlserver',
    'Reverse schema changes made without DBA approval and remove the DDL permissions that enabled the violation.',
    'critical',
    'AUD-008-RC03: Reverse unauthorized DDL changes - SQL Server', 'remediate',
    'If the transaction is open, kill the session to rollback. If committed, use fn_dblog() to identify the DDL LSN and restore the database to a pre-DDL state on a recovery server, then script the difference. Alternatively manually DROP, ALTER, or recreate objects to match the approved schema definition.',
    'high', false,
    'AUD-008-RC03: Revoke DDL permissions from non-DBA accounts - SQL Server', 'remediate',
    'Revoke: REVOKE CREATE TABLE, CREATE PROCEDURE, ALTER ANY SCHEMA FROM <non_dba_principal>. Review sys.database_permissions for CREATE and ALTER grants held by non-DBA database roles and remove all deviations from the approved permission matrix. Enable DDL triggers to audit future schema changes.',
    'medium', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-008-RC03', 'mysql',
    'Rollback unauthorized DDL and revoke DDL privileges - MySQL',
    'aud-008-rc03-rollback-unauthorized-ddl-mysql',
    'Undo schema changes executed without approval and remove CREATE/ALTER/DROP privileges from the non-DBA account.',
    'critical',
    'AUD-008-RC03: Reverse unauthorized DDL changes - MySQL', 'remediate',
    'MySQL DDL is auto-commit so in-flight kill is not possible. Identify the DDL statement from the binary log or audit log. Manually reverse: DROP TABLE, RENAME TABLE, or ALTER TABLE to restore the prior schema state using the last approved mysqldump --no-data as the reference.',
    'high', false,
    'AUD-008-RC03: Revoke CREATE and DDL privileges - MySQL', 'remediate',
    'Revoke DDL privileges: REVOKE CREATE, ALTER, DROP, CREATE ROUTINE, ALTER ROUTINE ON <db>.* FROM ''<non_dba>''@''%''. FLUSH PRIVILEGES. Audit INFORMATION_SCHEMA.USER_PRIVILEGES for any remaining CREATE or ALTER grants held by application or service accounts not in the approved DBA list.',
    'medium', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-008-RC03', 'oracle',
    'Rollback unauthorized DDL and revoke DDL privileges - Oracle',
    'aud-008-rc03-rollback-unauthorized-ddl-oracle',
    'Restore the schema to its approved state using Flashback DDL or RMAN and revoke DDL privileges from non-DBA accounts.',
    'critical',
    'AUD-008-RC03: Reverse unauthorized DDL using Flashback or RMAN - Oracle', 'remediate',
    'Check if DDL can be reversed via FLASHBACK TABLE <obj> TO BEFORE DROP (for DROP DDL) or Flashback Database to the SCN before the change. If Flashback is not available, restore the affected schema objects from the last RMAN backup on a recovery database and script the re-creation.',
    'high', false,
    'AUD-008-RC03: Revoke ANY DDL system privileges from non-DBA - Oracle', 'remediate',
    'Revoke dangerous system privileges: REVOKE CREATE ANY TABLE, CREATE ANY PROCEDURE, DROP ANY TABLE, ALTER ANY TABLE FROM <non_dba_account>. Review DBA_SYS_PRIVS for ALL ANY DDL privileges held by non-DBA accounts. Implement a DDL audit policy via UNIFIED_AUDIT_POLICY to alert on future unauthorized schema changes.',
    'medium', true
  );

-- ============================================================
-- SEC-SQL-AUD-008-RC04  Transactions accessing credential or encryption key tables
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-008-RC04', 'postgresql',
    'Terminate credential table access and rotate exposed secrets - PostgreSQL',
    'aud-008-rc04-terminate-credential-access-pg',
    'Terminate the session accessing credential or key material tables and rotate all credentials that may have been exposed.',
    'critical',
    'AUD-008-RC04: Terminate session accessing credential tables - PostgreSQL', 'immediate',
    'Terminate the session: SELECT pg_terminate_backend(pid). Record the full query text, usename, and client_addr from pg_stat_activity. Immediately notify the security team and application owners to begin credential rotation.',
    'high', false,
    'AUD-008-RC04: Rotate all potentially exposed credentials - PostgreSQL', 'remediate',
    'Rotate all API keys, password hashes, and encryption keys stored in the accessed tables. Revoke SELECT on the credential tables from all non-key-management roles. Implement RLS on the credential tables to restrict row-level access to the designated key management service account only. Review pgaudit for any prior access by the same account.',
    'high', false
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-008-RC04', 'sqlserver',
    'Terminate credential table access and rotate exposed secrets - SQL Server',
    'aud-008-rc04-terminate-credential-access-sqlserver',
    'Kill the session reading from credential or key tables and rotate all secrets that were potentially exposed.',
    'critical',
    'AUD-008-RC04: Kill session accessing credential tables - SQL Server', 'immediate',
    'Kill the session: KILL <spid>. Capture the full SQL text, login_name, host_name, and row_count from sys.dm_exec_sessions and sys.dm_exec_sql_text. Immediately notify the security and application teams to initiate credential rotation.',
    'high', false,
    'AUD-008-RC04: Rotate credentials and restrict table access - SQL Server', 'remediate',
    'Rotate all API keys, symmetric keys, and certificates stored in the accessed tables. Revoke SELECT on credential tables from all non-key-management principals. Enable Always Encrypted or column-level encryption on key material columns. Review the SQL Server Audit log for prior access by the same login.',
    'high', false
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-008-RC04', 'mysql',
    'Terminate credential table access and rotate exposed secrets - MySQL',
    'aud-008-rc04-terminate-credential-access-mysql',
    'Kill the thread reading credential or key tables and rotate all secrets that were potentially accessed.',
    'critical',
    'AUD-008-RC04: Kill thread accessing credential tables - MySQL', 'immediate',
    'Kill the thread: KILL <process_id>. Record USER, HOST, DB, TIME, and INFO from INFORMATION_SCHEMA.PROCESSLIST. Notify the security and application teams immediately to initiate secret rotation for all keys and credentials stored in the accessed table.',
    'high', false,
    'AUD-008-RC04: Rotate credentials and tighten table access - MySQL', 'remediate',
    'Rotate all API keys, tokens, and password hashes in the accessed tables. Revoke SELECT on the credential tables: REVOKE SELECT ON <db>.<credential_table> FROM all non-key-management accounts. Enable the keyring plugin for at-rest encryption of key material. Review audit_log entries for prior access patterns.',
    'high', false
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-008-RC04', 'oracle',
    'Terminate TDE key or credential access and rotate secrets - Oracle',
    'aud-008-rc04-terminate-credential-access-oracle',
    'Kill the session accessing TDE wallet or application credential tables and rotate all potentially exposed key material.',
    'critical',
    'AUD-008-RC04: Kill session accessing TDE or credential objects - Oracle', 'immediate',
    'Kill the session: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE. Record V$SESSION USERNAME, OSUSER, and SQL_ID. Query V$SQL for the full SQL_TEXT. Immediately notify the security team and key management officer to initiate key rotation.',
    'high', false,
    'AUD-008-RC04: Rotate TDE master key and revoke key management access - Oracle', 'remediate',
    'Re-key the TDE master encryption key: ADMINISTER KEY MANAGEMENT SET KEY USING TAG ''incident-rotation'' FORCE KEYSTORE IDENTIFIED BY <wallet_password>. Revoke access to V$ENCRYPTION_KEYS and application credential tables from all non-KMS accounts. Review DBA_AUDIT_TRAIL for prior access and assess the scope of key material exposure.',
    'high', false
  );

-- ============================================================
-- SEC-SQL-AUD-008-RC05  Cross-schema transactions outside application scope
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-008-RC05', 'postgresql',
    'Terminate cross-schema session and revoke out-of-scope grants - PostgreSQL',
    'aud-008-rc05-terminate-cross-schema-pg',
    'Terminate the session joining schemas outside the application boundary and revoke the cross-schema privileges that enabled the access.',
    'high',
    'AUD-008-RC05: Terminate cross-schema session - PostgreSQL', 'immediate',
    'Terminate the session: SELECT pg_terminate_backend(pid). Capture the full query text from pg_stat_activity showing the cross-schema JOIN and the usename and client_addr for the incident record.',
    'high', false,
    'AUD-008-RC05: Revoke cross-schema privileges and set search_path - PostgreSQL', 'remediate',
    'Revoke USAGE and SELECT on out-of-scope schemas: REVOKE USAGE ON SCHEMA <foreign_schema> FROM <app_role>. Pin the application role to its authorised schema: ALTER ROLE <app_role> SET search_path TO <allowed_schema>. Enable pgaudit log for cross-schema SELECT events to detect future violations.',
    'medium', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-008-RC05', 'sqlserver',
    'Terminate cross-database session and revoke out-of-scope access - SQL Server',
    'aud-008-rc05-terminate-cross-schema-sqlserver',
    'Kill the session performing cross-database queries and revoke the permissions that allowed access to out-of-scope databases.',
    'high',
    'AUD-008-RC05: Kill cross-database session - SQL Server', 'immediate',
    'Kill the session: KILL <spid>. Capture sys.dm_exec_sessions and the SQL text from sys.dm_exec_sql_text to document the cross-database object references and the login executing them.',
    'high', false,
    'AUD-008-RC05: Revoke cross-database access and enforce database boundaries - SQL Server', 'remediate',
    'Revoke CONNECT on out-of-scope databases: REVOKE CONNECT ON DATABASE::<out_of_scope_db> FROM <login>. Remove db_datareader from the login in unauthorised databases. Enable cross-database ownership chaining only where explicitly required. Audit sys.database_permissions for remaining out-of-scope grants.',
    'medium', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-008-RC05', 'mysql',
    'Terminate cross-database session and revoke out-of-scope grants - MySQL',
    'aud-008-rc05-terminate-cross-schema-mysql',
    'Kill the thread performing cross-database queries and revoke wildcard or out-of-scope database grants from the application account.',
    'high',
    'AUD-008-RC05: Kill cross-database thread - MySQL', 'immediate',
    'Kill the thread: KILL <process_id>. Review INFORMATION_SCHEMA.PROCESSLIST INFO column for the cross-database JOIN query and document the USER, HOST, and DB for the incident record.',
    'high', false,
    'AUD-008-RC05: Revoke wildcard grants and scope account to one database - MySQL', 'remediate',
    'Revoke wildcard grants: REVOKE ALL ON *.* FROM ''<app_user>''@''%''. Re-grant only on the authorised application database: GRANT SELECT, INSERT, UPDATE, DELETE ON <app_db>.* TO ''<app_user>''@''<app_host>''. FLUSH PRIVILEGES. Review INFORMATION_SCHEMA.SCHEMA_PRIVILEGES for remaining out-of-scope database grants.',
    'medium', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-008-RC05', 'oracle',
    'Terminate cross-schema session and revoke out-of-scope grants - Oracle',
    'aud-008-rc05-terminate-cross-schema-oracle',
    'Kill the session performing joins or queries across schemas outside the application boundary and revoke all cross-schema object grants.',
    'high',
    'AUD-008-RC05: Kill cross-schema session - Oracle', 'immediate',
    'Kill the session: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE. Capture V$SQL SQL_TEXT showing the cross-schema object references and the session USERNAME and MACHINE for the incident record.',
    'high', false,
    'AUD-008-RC05: Revoke cross-schema grants and create Database Vault realm - Oracle', 'remediate',
    'Revoke all cross-schema object privileges: REVOKE SELECT, INSERT ON <out_of_scope_schema>.<table> FROM <app_account>. Review DBA_TAB_PRIVS and DBA_COL_PRIVS for all grants from out-of-scope schema owners to the application account. Create a Database Vault realm around the out-of-scope schema to enforce the access boundary for future sessions.',
    'medium', true
  );

END;
$BODY$;

DROP PROCEDURE IF EXISTS rootcause.add_resolution_path(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT,
  TEXT, TEXT, TEXT, TEXT, BOOLEAN,
  TEXT, TEXT, TEXT, TEXT, BOOLEAN
);

COMMIT;
