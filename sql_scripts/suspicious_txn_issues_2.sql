-- ============================================================
-- SEC-SQL-AUD-009 through SEC-SQL-AUD-014
-- Suspicious Transaction Root Causes — Part 2
-- ============================================================

BEGIN;

-- ── 1. ISSUES ────────────────────────────────────────────────
INSERT INTO rootcause.issues
  (issue_id, domain_code, database_type_code, area_code, name, slug, description)
VALUES
  ('SEC-SQL-AUD-009','SEC','SQL','AUD',
   'SQL Injection Runtime Indicators',
   'sql-injection-runtime-indicators',
   'Detection of live SQL injection patterns in active sessions: tautologies, stacked queries, UNION probing, time-delay functions, and comment-based obfuscation embedded in query text.'),

  ('SEC-SQL-AUD-010','SEC','SQL','AUD',
   'Database Reconnaissance Activity',
   'database-reconnaissance-activity',
   'Identifies schema enumeration behaviour typical of attackers mapping the database before exfiltration: excessive catalog queries, user/role listing by non-admin accounts, and mass column/permission discovery.'),

  ('SEC-SQL-AUD-011','SEC','SQL','AUD',
   'Audit and Log Tampering',
   'audit-and-log-tampering',
   'Detects attempts to cover tracks by issuing DML against audit tables, disabling audit settings, truncating log tables, modifying triggers, or clearing error buffers during an active session.'),

  ('SEC-SQL-AUD-012','SEC','SQL','AUD',
   'Long-Running Uncommitted Transactions',
   'long-running-uncommitted-transactions',
   'Flags transactions that remain open beyond a defined threshold without commit, idle-in-transaction sessions holding locks, and probe-and-revert rollback patterns consistent with ransomware or intentional lock abuse.'),

  ('SEC-SQL-AUD-013','SEC','SQL','AUD',
   'Security Configuration Change During Active Session',
   'security-configuration-change-active-session',
   'Detects runtime changes to security-relevant server or session parameters: ALTER SYSTEM, sp_configure, trigger disabling, audit parameter changes, and enabling dangerous features such as xp_cmdshell or UTL_FILE.'),

  ('SEC-SQL-AUD-014','SEC','SQL','AUD',
   'User and Role Manipulation During Session',
   'user-and-role-manipulation-during-session',
   'Identifies CREATE USER, role-grant, password-change, and external database-link creation commands issued mid-session, which are typical of privilege persistence, backdoor account creation, or lateral movement setup.');

-- ── 2. ROOT CAUSES — SEC-SQL-AUD-009 (SQL Injection Runtime) ─
INSERT INTO rootcause.root_causes
  (root_cause_id, issue_id, name, slug, description, vendors_applicable)
VALUES
  ('SEC-SQL-AUD-009-RC01','SEC-SQL-AUD-009',
   'Tautology patterns detected in active query text',
   'tautology-patterns-active-query',
   'Active queries contain always-true conditions such as OR 1=1, OR ''a''=''a'', or OR 1>0 that are characteristic of classic SQL injection payloads used to bypass WHERE-clause filtering.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-009-RC02','SEC-SQL-AUD-009',
   'Stacked or chained query execution detected',
   'stacked-chained-query-execution',
   'A single query string contains multiple statement terminators followed by additional SQL commands, indicating a stacked-query injection where the attacker appends arbitrary statements to a legitimate request.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-009-RC03','SEC-SQL-AUD-009',
   'UNION-based probing across unknown tables',
   'union-based-probing-unknown-tables',
   'Queries contain UNION SELECT constructs referencing system catalog tables or column counts inconsistent with the legitimate application, indicating UNION-based injection used to extract schema or data.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-009-RC04','SEC-SQL-AUD-009',
   'Time-delay injection functions detected in active queries',
   'time-delay-injection-functions',
   'Queries contain time-delay calls such as pg_sleep, WAITFOR DELAY, SLEEP(), or DBMS_LOCK.SLEEP, which are the hallmark of blind time-based SQL injection used to infer data without visible output.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-009-RC05','SEC-SQL-AUD-009',
   'Comment-based obfuscation or encoding in query text',
   'comment-obfuscation-encoding-query',
   'Queries contain inline SQL comments (/**/, --), hex-encoded strings, CHAR() concatenation, or URL-encoded characters used to obfuscate injection payloads and bypass input validation or WAF rules.',
   ARRAY['postgresql','sqlserver','mysql','oracle']);

-- ── 3. ROOT CAUSES — SEC-SQL-AUD-010 (Reconnaissance) ────────
INSERT INTO rootcause.root_causes
  (root_cause_id, issue_id, name, slug, description, vendors_applicable)
VALUES
  ('SEC-SQL-AUD-010-RC01','SEC-SQL-AUD-010',
   'Excessive information_schema or catalog enumeration',
   'excessive-information-schema-enumeration',
   'A single session issues an unusually high number of queries against information_schema, pg_catalog, sys.objects, or DBA_ views within a short window, consistent with automated schema mapping.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-010-RC02','SEC-SQL-AUD-010',
   'System principal and user enumeration by non-admin account',
   'system-principal-user-enumeration-non-admin',
   'A non-administrative account queries pg_roles, sys.server_principals, mysql.user, DBA_USERS, or equivalent views listing all database accounts, indicating attacker reconnaissance of the privilege landscape.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-010-RC03','SEC-SQL-AUD-010',
   'Mass table and column listing within a single session',
   'mass-table-column-listing-single-session',
   'A session queries information_schema.columns or equivalent for all tables in a database in rapid succession, typically indicating an automated tool mapping the full column inventory for targeted exfiltration.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-010-RC04','SEC-SQL-AUD-010',
   'Stored procedure and function source code enumeration',
   'stored-procedure-source-code-enumeration',
   'A non-DBA account retrieves the source definitions of stored procedures, functions, or packages from pg_proc, sys.sql_modules, information_schema.routines, or ALL_SOURCE, suggesting reconnaissance of business logic.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-010-RC05','SEC-SQL-AUD-010',
   'Permission and privilege discovery queries',
   'permission-privilege-discovery-queries',
   'Queries against HAS_TABLE_PRIVILEGE, fn_my_permissions, SESSION_PRIVS, information_schema.role_table_grants, or equivalent reveal an account systematically mapping what it is allowed to access.',
   ARRAY['postgresql','sqlserver','mysql','oracle']);

-- ── 4. ROOT CAUSES — SEC-SQL-AUD-011 (Audit Tampering) ───────
INSERT INTO rootcause.root_causes
  (root_cause_id, issue_id, name, slug, description, vendors_applicable)
VALUES
  ('SEC-SQL-AUD-011-RC01','SEC-SQL-AUD-011',
   'Direct DML executed on audit or log tables',
   'direct-dml-audit-log-tables',
   'INSERT, UPDATE, or DELETE statements target known audit or log tables (AUD$, pgaudit logs, sys.fn_get_audit_file targets, mysql.general_log), indicating an attempt to modify or erase the activity record.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-011-RC02','SEC-SQL-AUD-011',
   'Audit settings disabled or downgraded mid-session',
   'audit-settings-disabled-mid-session',
   'Commands such as ALTER SYSTEM SET log_statement=none, NOAUDIT, sp_configure audit level changes, or SET GLOBAL general_log=OFF are issued during an active session, reducing the audit coverage for subsequent actions.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-011-RC03','SEC-SQL-AUD-011',
   'Audit or log table truncated or dropped',
   'audit-log-table-truncated-dropped',
   'A TRUNCATE or DROP statement targets an audit, log, or event-history table, destroying the evidentiary record of prior database activity.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-011-RC04','SEC-SQL-AUD-011',
   'Trigger disabled immediately before DML operation',
   'trigger-disabled-before-dml',
   'An ALTER TABLE DISABLE TRIGGER or equivalent command is issued within the same session shortly before a DML statement on the same table, bypassing row-level audit or validation logic.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-011-RC05','SEC-SQL-AUD-011',
   'Error log or event buffer cleared during session',
   'error-log-event-buffer-cleared',
   'Commands such as sp_cycle_errorlog, ALTER SYSTEM SWITCH LOGFILE, FLUSH LOGS, or DBMS_SYSTEM.KSDWRT are executed, rotating or clearing the server error log to remove evidence of prior errors or suspicious activity.',
   ARRAY['postgresql','sqlserver','mysql','oracle']);

-- ── 5. ROOT CAUSES — SEC-SQL-AUD-012 (Uncommitted Txns) ──────
INSERT INTO rootcause.root_causes
  (root_cause_id, issue_id, name, slug, description, vendors_applicable)
VALUES
  ('SEC-SQL-AUD-012-RC01','SEC-SQL-AUD-012',
   'Transaction open beyond threshold with no activity',
   'transaction-open-beyond-threshold-no-activity',
   'A session has an active transaction that has not been committed or rolled back for longer than a configurable threshold (e.g. 30 minutes) with no recent query activity, suggesting an abandoned, stuck, or deliberately held transaction.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-012-RC02','SEC-SQL-AUD-012',
   'Exclusive locks held on large tables for extended period',
   'exclusive-locks-large-tables-extended',
   'A session holds exclusive or access-exclusive locks on tables with a significant row count for an unusually long time, blocking other operations and potentially indicating intentional lock-based denial of service.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-012-RC03','SEC-SQL-AUD-012',
   'Idle-in-transaction session blocking downstream operations',
   'idle-in-transaction-blocking-downstream',
   'A session in the idle in transaction state is holding locks that are blocking a queue of other waiting sessions, a pattern associated with application bugs, connection pool exhaustion, or deliberate resource starvation.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-012-RC04','SEC-SQL-AUD-012',
   'Large-volume rollback indicating probe-and-revert behaviour',
   'large-volume-rollback-probe-revert',
   'A transaction that modified a large number of rows is rolled back, with the same pattern repeated multiple times within a session, consistent with an attacker probing data constraints or testing injection payloads without committing.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-012-RC05','SEC-SQL-AUD-012',
   'Savepoint abuse with repeated partial rollbacks',
   'savepoint-abuse-repeated-partial-rollbacks',
   'A session creates and rolls back to savepoints in rapid repeated cycles, which is abnormal application behaviour and may indicate automated probing of data state or attempts to exploit MVCC timing windows.',
   ARRAY['postgresql','sqlserver','mysql','oracle']);

-- ── 6. ROOT CAUSES — SEC-SQL-AUD-013 (Config Changes) ────────
INSERT INTO rootcause.root_causes
  (root_cause_id, issue_id, name, slug, description, vendors_applicable)
VALUES
  ('SEC-SQL-AUD-013-RC01','SEC-SQL-AUD-013',
   'Security-relevant ALTER SYSTEM or SET executed by non-admin',
   'security-relevant-alter-system-non-admin',
   'A non-superuser or non-DBA account issues ALTER SYSTEM, SET SESSION, or sp_configure commands that change authentication, SSL, logging, or access-control parameters, undermining the server security posture.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-013-RC02','SEC-SQL-AUD-013',
   'Dangerous feature enabled during session',
   'dangerous-feature-enabled-session',
   'Commands enabling xp_cmdshell, UTL_FILE directory access, DBMS_SCHEDULER OS jobs, or LOAD DATA INFILE are issued during an active session, opening OS-level execution vectors from within the database.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-013-RC03','SEC-SQL-AUD-013',
   'Trigger disabled or dropped on monitored table',
   'trigger-disabled-dropped-monitored-table',
   'ALTER TABLE DISABLE TRIGGER, DROP TRIGGER, or equivalent commands target tables that carry audit, validation, or row-history triggers, removing controls that enforce data integrity or change tracking.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-013-RC04','SEC-SQL-AUD-013',
   'Audit or logging parameters changed mid-session',
   'audit-logging-parameters-changed-mid-session',
   'Session-level commands reduce or disable query logging, error reporting, or audit verbosity (e.g. SET log_min_duration_statement=-1, NOAUDIT ALL, SET GLOBAL slow_query_log=OFF), creating a blind spot for subsequent activity.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-013-RC05','SEC-SQL-AUD-013',
   'Network or authentication configuration modified at runtime',
   'network-auth-config-modified-runtime',
   'Commands that alter pg_hba.conf, firewall rules, linked-server definitions, or remote authentication providers are issued at runtime, potentially opening new access paths that bypass existing controls.',
   ARRAY['postgresql','sqlserver','mysql','oracle']);

-- ── 7. ROOT CAUSES — SEC-SQL-AUD-014 (User/Role Manip) ───────
INSERT INTO rootcause.root_causes
  (root_cause_id, issue_id, name, slug, description, vendors_applicable)
VALUES
  ('SEC-SQL-AUD-014-RC01','SEC-SQL-AUD-014',
   'New user or login created during application session',
   'new-user-login-created-application-session',
   'A CREATE USER, CREATE LOGIN, or CREATE ROLE statement is executed during what appears to be a normal application session, indicating possible backdoor account creation for persistent re-entry.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-014-RC02','SEC-SQL-AUD-014',
   'Account added to privileged role mid-session',
   'account-added-privileged-role-mid-session',
   'A GRANT ROLE, ALTER SERVER ROLE ADD MEMBER, or GRANT DBA command elevates an existing account to a highly privileged role (sysadmin, DBA, superuser) outside of a formal change-management process.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-014-RC03','SEC-SQL-AUD-014',
   'Password changed on another account during active session',
   'password-changed-other-account-active-session',
   'An ALTER USER ... PASSWORD or equivalent command changes the credential of an account other than the currently logged-in user, potentially resetting a dormant account for re-activation.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-014-RC04','SEC-SQL-AUD-014',
   'Database link or synonym to external system created',
   'database-link-synonym-external-system-created',
   'A CREATE DATABASE LINK, CREATE SYNONYM, sp_addlinkedserver, or CREATE FOREIGN DATA WRAPPER command establishes a connection pathway to an external database, which could be used to exfiltrate data or pivot to another system.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-014-RC05','SEC-SQL-AUD-014',
   'Account unlocked or expiry removed on dormant account',
   'account-unlocked-expiry-removed-dormant',
   'An ALTER USER ... ACCOUNT UNLOCK, ENABLE LOGIN, or password-expiry-removal command reactivates a previously locked or expired account, which may be an attacker restoring access to a previously compromised credential.',
   ARRAY['postgresql','sqlserver','mysql','oracle']);

COMMIT;
