-- ============================================================
-- Resolution paths + steps for SEC-SQL-AUD-012 through SEC-SQL-AUD-014
-- Covers all root causes RC01-RC05 across postgresql, sqlserver,
-- mysql, oracle.  60 resolution paths total.
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
-- SEC-SQL-AUD-012-RC01  Transaction open beyond threshold
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-012-RC01', 'postgresql',
    'Terminate idle abandoned transaction - PostgreSQL',
    'aud-012-rc01-terminate-idle-txn-pg',
    'Terminate the session with a long-open uncommitted transaction and configure idle transaction timeout to prevent recurrence.',
    'medium',
    'AUD-012-RC01: Terminate long-open idle transaction - PostgreSQL', 'immediate',
    'Identify: SELECT pid, usename, state, xact_start, now() - xact_start AS age FROM pg_stat_activity WHERE state IN (''idle in transaction'',''idle in transaction (aborted)'') AND now() - xact_start > interval ''30 minutes''. Terminate: SELECT pg_terminate_backend(pid). Record xact_start, usename, and client_addr.',
    'medium', false,
    'AUD-012-RC01: Set idle_in_transaction_session_timeout - PostgreSQL', 'configure',
    'Set the timeout: ALTER SYSTEM SET idle_in_transaction_session_timeout = ''1800000'' (30 minutes in ms). SELECT pg_reload_conf(). Optionally tighten per role: ALTER ROLE <app_role> SET idle_in_transaction_session_timeout = ''300000''. Verify with SHOW idle_in_transaction_session_timeout.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-012-RC01', 'sqlserver',
    'Terminate idle abandoned transaction - SQL Server',
    'aud-012-rc01-terminate-idle-txn-sqlserver',
    'Kill the session with a long-open uncommitted transaction and configure a query timeout at the application level.',
    'medium',
    'AUD-012-RC01: Kill long-open idle transaction - SQL Server', 'immediate',
    'Identify open transactions: SELECT session_id, login_name, open_transaction_count, last_request_start_time, status FROM sys.dm_exec_sessions WHERE open_transaction_count > 0 AND DATEDIFF(minute, last_request_start_time, GETDATE()) > 30. Kill: KILL <session_id>.',
    'medium', false,
    'AUD-012-RC01: Configure connection and command timeout - SQL Server', 'configure',
    'Set a session timeout in the application connection string: Connection Timeout=30 and CommandTimeout on each command object. Enable Resource Governor to kill sessions in the application workload group that hold open transactions beyond a threshold. Consider setting KILL_AFTER_N_SECONDS on the workload group.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-012-RC01', 'mysql',
    'Terminate idle abandoned transaction - MySQL',
    'aud-012-rc01-terminate-idle-txn-mysql',
    'Kill the thread with a long-open uncommitted transaction and set wait_timeout to prevent recurrence.',
    'medium',
    'AUD-012-RC01: Kill long-open idle transaction thread - MySQL', 'immediate',
    'Identify: SELECT trx_id, trx_started, trx_state, trx_mysql_thread_id FROM information_schema.innodb_trx WHERE trx_state = ''RUNNING'' AND TIMESTAMPDIFF(MINUTE, trx_started, NOW()) > 30. Kill: KILL <trx_mysql_thread_id>.',
    'medium', false,
    'AUD-012-RC01: Set wait_timeout and interactive_timeout - MySQL', 'configure',
    'Set: SET GLOBAL wait_timeout = 1800 and SET GLOBAL interactive_timeout = 1800 (30 minutes). For application connections also set SET GLOBAL innodb_lock_wait_timeout = 50 to fail-fast on lock contention. Verify with SHOW GLOBAL VARIABLES LIKE ''wait_timeout''.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-012-RC01', 'oracle',
    'Terminate idle abandoned transaction - Oracle',
    'aud-012-rc01-terminate-idle-txn-oracle',
    'Kill the session with a long-open uncommitted transaction and configure idle time limits in the connection profile.',
    'medium',
    'AUD-012-RC01: Kill long-open idle transaction session - Oracle', 'immediate',
    'Identify: SELECT s.sid, s.serial#, s.username, t.start_time FROM v$transaction t JOIN v$session s ON t.ses_addr = s.saddr WHERE (SYSDATE - t.start_date) * 24 * 60 > 30. Kill: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE.',
    'medium', false,
    'AUD-012-RC01: Set IDLE_TIME in profile and configure resource plan - Oracle', 'configure',
    'Set an idle time limit on the application profile: ALTER PROFILE <app_profile> LIMIT IDLE_TIME 30 (minutes). Create a resource plan consumer group directive with MAX_IDLE_TIME for the application service. Verify with SELECT * FROM DBA_PROFILES WHERE PROFILE = ''<app_profile>'' AND RESOURCE_NAME = ''IDLE_TIME''.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-012-RC02  Exclusive locks held on large tables
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-012-RC02', 'postgresql',
    'Terminate session holding extended exclusive lock - PostgreSQL',
    'aud-012-rc02-terminate-exclusive-lock-pg',
    'Terminate the session holding an extended exclusive lock on a large table that is blocking downstream operations.',
    'high',
    'AUD-012-RC02: Terminate exclusive lock holder - PostgreSQL', 'immediate',
    'Identify the blocker: SELECT pid, usename, query, now() - pg_stat_activity.query_start AS duration FROM pg_stat_activity JOIN pg_locks ON pg_stat_activity.pid = pg_locks.pid WHERE pg_locks.granted AND pg_locks.mode LIKE ''%ExclusiveLock%''. Terminate: SELECT pg_terminate_backend(<blocking_pid>). Record the query and xact_start.',
    'high', false,
    'AUD-012-RC02: Set lock_timeout and investigate application lock patterns - PostgreSQL', 'configure',
    'Set a lock acquisition timeout to prevent future indefinite blocking: ALTER ROLE <app_role> SET lock_timeout = ''30s''. Review the application query causing the exclusive lock to determine whether it can be rewritten to use a lighter lock mode (e.g. using SHARE UPDATE EXCLUSIVE instead of ACCESS EXCLUSIVE for concurrent-safe DDL). Alert on pg_locks entries older than 10 minutes.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-012-RC02', 'sqlserver',
    'Terminate session holding extended exclusive lock - SQL Server',
    'aud-012-rc02-terminate-exclusive-lock-sqlserver',
    'Kill the session holding an extended exclusive table lock that is blocking downstream operations.',
    'high',
    'AUD-012-RC02: Kill exclusive lock holder - SQL Server', 'immediate',
    'Identify: SELECT request_session_id, resource_type, resource_description, request_mode, request_status FROM sys.dm_tran_locks WHERE request_mode IN (''X'',''SCH-M'') AND resource_type = ''OBJECT''. Kill the blocking session: KILL <session_id>. Capture the SQL from sys.dm_exec_sql_text before killing.',
    'high', false,
    'AUD-012-RC02: Set lock timeout in application and review isolation level - SQL Server', 'configure',
    'Set SET LOCK_TIMEOUT 30000 (30 seconds) in the application connection. Review whether operations causing the exclusive lock can use READ_COMMITTED_SNAPSHOT isolation to avoid reader blocking. Enable Blocked Process Threshold: sp_configure ''blocked process threshold'', 30. Alert when the threshold is crossed.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-012-RC02', 'mysql',
    'Terminate session holding extended exclusive lock - MySQL',
    'aud-012-rc02-terminate-exclusive-lock-mysql',
    'Kill the thread holding an extended InnoDB exclusive lock that is blocking downstream operations.',
    'high',
    'AUD-012-RC02: Kill exclusive lock holder thread - MySQL', 'immediate',
    'Identify: SELECT r.trx_id waiting_trx, r.trx_mysql_thread_id waiting_thread, b.trx_id blocking_trx, b.trx_mysql_thread_id blocking_thread FROM information_schema.innodb_lock_waits w JOIN information_schema.innodb_trx b ON b.trx_id = w.blocking_trx_id JOIN information_schema.innodb_trx r ON r.trx_id = w.requesting_trx_id. Kill: KILL <blocking_thread>.',
    'high', false,
    'AUD-012-RC02: Set innodb_lock_wait_timeout and review application locking - MySQL', 'configure',
    'Set: SET GLOBAL innodb_lock_wait_timeout = 30 to cause waiting transactions to fail after 30 seconds rather than wait indefinitely. Review the application operation causing the exclusive lock to determine if it can be broken into smaller batches. Enable performance_schema.events_waits_history_long to monitor lock wait patterns.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-012-RC02', 'oracle',
    'Terminate session holding extended exclusive lock - Oracle',
    'aud-012-rc02-terminate-exclusive-lock-oracle',
    'Kill the session holding an extended exclusive lock on a large table that is blocking downstream operations.',
    'high',
    'AUD-012-RC02: Kill exclusive lock holder - Oracle', 'immediate',
    'Identify: SELECT s.sid, s.serial#, s.username, l.type, l.lmode FROM v$lock l JOIN v$session s ON l.sid = s.sid WHERE l.lmode = 6 AND l.type = ''TM'' ORDER BY s.last_call_et DESC. Kill: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE.',
    'high', false,
    'AUD-012-RC02: Set LOCK_TIMEOUT in profile and review DML batching - Oracle', 'configure',
    'Set a distributed lock timeout limit using the DISTRIBUTED_LOCK_TIMEOUT init parameter. For application sessions set a resource plan CPU and I/O limit. Review the DML operation causing the exclusive lock to batch large updates using ROWNUM or partition-based iteration to minimize lock duration.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-012-RC03  Idle-in-transaction blocking downstream
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-012-RC03', 'postgresql',
    'Clear idle-in-transaction session blocking queue - PostgreSQL',
    'aud-012-rc03-clear-idle-txn-blocking-pg',
    'Terminate the idle-in-transaction session holding locks that are blocking a downstream queue of sessions.',
    'high',
    'AUD-012-RC03: Terminate idle-in-transaction blocking session - PostgreSQL', 'immediate',
    'Identify the idle blocker: SELECT pid, usename, state, xact_start, now() - xact_start AS idle_age, wait_event FROM pg_stat_activity WHERE state = ''idle in transaction'' ORDER BY xact_start. Count blocked sessions: SELECT count(*) FROM pg_stat_activity WHERE wait_event_type = ''Lock''. Terminate: SELECT pg_terminate_backend(<blocker_pid>).',
    'high', false,
    'AUD-012-RC03: Set idle_in_transaction_session_timeout globally - PostgreSQL', 'configure',
    'Apply immediately: SET idle_in_transaction_session_timeout = ''300000'' for the session. Apply permanently: ALTER SYSTEM SET idle_in_transaction_session_timeout = ''300000'' then SELECT pg_reload_conf(). Review application connection pool configuration to ensure connections are released back to the pool promptly after each transaction.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-012-RC03', 'sqlserver',
    'Clear idle-in-transaction session blocking queue - SQL Server',
    'aud-012-rc03-clear-idle-txn-blocking-sqlserver',
    'Kill the idle session with an open transaction blocking a queue of downstream requests.',
    'high',
    'AUD-012-RC03: Kill idle transaction blocking session - SQL Server', 'immediate',
    'Find the head blocker: SELECT blocking_session_id, session_id, wait_type, wait_time, status FROM sys.dm_exec_requests WHERE blocking_session_id <> 0 ORDER BY wait_time DESC. Check if the blocker is idle: SELECT status FROM sys.dm_exec_sessions WHERE session_id = <blocker_id>. Kill: KILL <blocking_session_id>.',
    'high', false,
    'AUD-012-RC03: Enable connection timeout and review connection pool - SQL Server', 'configure',
    'Configure Connection Timeout and CommandTimeout in the application connection string. Enable the blocked process report via sp_configure ''blocked process threshold'', 5 to alert immediately when blocking exceeds 5 seconds. Review the connection pool max size and idle lifetime to prevent pool exhaustion feeding idle transactions.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-012-RC03', 'mysql',
    'Clear idle-in-transaction session blocking queue - MySQL',
    'aud-012-rc03-clear-idle-txn-blocking-mysql',
    'Kill the idle thread with an open InnoDB transaction blocking downstream lock waiters.',
    'high',
    'AUD-012-RC03: Kill idle transaction blocking thread - MySQL', 'immediate',
    'Identify the blocker: SELECT blocking_pid, blocking_query, waiting_pid, waiting_query FROM sys.innodb_lock_waits. Kill the blocking thread: KILL <blocking_pid>. Record trx_started from information_schema.innodb_trx for the killed thread to document the lock duration.',
    'high', false,
    'AUD-012-RC03: Set wait_timeout and review connection pool lifecycle - MySQL', 'configure',
    'Set: SET GLOBAL wait_timeout = 300 and SET GLOBAL interactive_timeout = 300 (5 minutes) to auto-close idle connections. Review the application connection pool min-evictable-idle-time-millis to ensure idle connections are released. Enable performance_schema.events_transactions_history to monitor transaction open times.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-012-RC03', 'oracle',
    'Clear idle-in-transaction session blocking queue - Oracle',
    'aud-012-rc03-clear-idle-txn-blocking-oracle',
    'Kill the idle Oracle session holding locks that are creating a downstream blocking chain.',
    'high',
    'AUD-012-RC03: Kill idle blocking session - Oracle', 'immediate',
    'Find the blocking chain: SELECT DECODE(request,0,''Holder:'',''Waiter:'') lock_type, sid, id1, id2, lmode, request FROM v$lock WHERE (id1,id2) IN (SELECT id1,id2 FROM v$lock WHERE request > 0). Kill the holder: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE.',
    'high', false,
    'AUD-012-RC03: Set IDLE_TIME profile limit and review connection pool - Oracle', 'configure',
    'Tighten the application connection profile: ALTER PROFILE <app_profile> LIMIT IDLE_TIME 5. Review Oracle UCP or application connection pool idle-timeout settings to ensure idle connections are closed before the idle session timeout triggers at the database level. Alert via a resource manager plan when idle sessions exceed 10 minutes.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-012-RC04  Large-volume rollback probe-and-revert
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-012-RC04', 'postgresql',
    'Terminate probe-and-revert rollback session - PostgreSQL',
    'aud-012-rc04-terminate-probe-rollback-pg',
    'Terminate the session exhibiting repeated large-volume rollback patterns consistent with data state probing and restrict the account.',
    'high',
    'AUD-012-RC04: Terminate repeated rollback session - PostgreSQL', 'immediate',
    'Identify: SELECT pid, usename, xact_start, query FROM pg_stat_activity WHERE query ILIKE ''%ROLLBACK%'' OR state = ''idle in transaction (aborted)''. Terminate: SELECT pg_terminate_backend(pid). Review pg_stat_user_tables.n_dead_tup on affected tables for evidence of large repeated DML that was rolled back.',
    'high', false,
    'AUD-012-RC04: Lock account and review for injection probe patterns - PostgreSQL', 'remediate',
    'Temporarily revoke LOGIN from the account: ALTER ROLE <user> NOLOGIN until the session is investigated. Review pg_audit logs for the pattern of DML-then-ROLLBACK sequences. Check whether the account is an application service account that should only use parameterised queries. Enforce prepared statements and set a statement_timeout to limit each transaction scope.',
    'medium', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-012-RC04', 'sqlserver',
    'Terminate probe-and-revert rollback session - SQL Server',
    'aud-012-rc04-terminate-probe-rollback-sqlserver',
    'Kill the session exhibiting repeated large-volume rollback patterns and investigate for injection or ransomware probe activity.',
    'high',
    'AUD-012-RC04: Kill repeated rollback session - SQL Server', 'immediate',
    'Identify sessions with high rollback activity: SELECT session_id, login_name, open_transaction_count, transaction_isolation_level FROM sys.dm_exec_sessions WHERE open_transaction_count > 0. Cross-reference sys.dm_tran_database_transactions for large transaction log space usage. Kill: KILL <session_id>.',
    'high', false,
    'AUD-012-RC04: Disable login and audit for probe patterns - SQL Server', 'remediate',
    'Temporarily disable the login: ALTER LOGIN <login_name> DISABLE. Review SQL Server Audit or Extended Events for the repeated DML-ROLLBACK pattern in recent sessions. Determine if the account is an application account that should be restricted to specific stored procedures. Re-enable after investigation and remediation of the application path.',
    'medium', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-012-RC04', 'mysql',
    'Terminate probe-and-revert rollback session - MySQL',
    'aud-012-rc04-terminate-probe-rollback-mysql',
    'Kill the thread exhibiting repeated large-volume rollback patterns and lock the account pending investigation.',
    'high',
    'AUD-012-RC04: Kill repeated rollback thread - MySQL', 'immediate',
    'Identify threads with repeated rollback patterns using information_schema.innodb_trx and performance_schema.events_transactions_history_long. Kill: KILL <trx_mysql_thread_id>. Note the NUMBER_OF_SAVEPOINTS and ROLLBACKS_TO_SAVEPOINT counts for evidence.',
    'high', false,
    'AUD-012-RC04: Lock account and enforce MAX_USER_CONNECTIONS - MySQL', 'remediate',
    'Lock the account: ALTER USER ''<user>''@''<host>'' ACCOUNT LOCK. Review binary logs for the DML-ROLLBACK patterns using mysqlbinlog. Set MAX_USER_CONNECTIONS 1 on the account after investigation to limit parallel probing. Enforce prepared statements to reduce data-probing opportunities. Unlock after investigation: ALTER USER ''<user>''@''<host>'' ACCOUNT UNLOCK.',
    'medium', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-012-RC04', 'oracle',
    'Terminate probe-and-revert rollback session - Oracle',
    'aud-012-rc04-terminate-probe-rollback-oracle',
    'Kill the session exhibiting repeated large-volume ROLLBACK patterns and review for ransomware probe or injection testing behaviour.',
    'high',
    'AUD-012-RC04: Kill repeated rollback session - Oracle', 'immediate',
    'Identify sessions with high undo generation and repeated rollbacks: SELECT s.sid, s.serial#, s.username, t.used_ublk FROM v$transaction t JOIN v$session s ON t.ses_addr = s.saddr ORDER BY t.used_ublk DESC. Kill: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE.',
    'high', false,
    'AUD-012-RC04: Lock account and review session history - Oracle', 'remediate',
    'Lock the Oracle account: ALTER USER <username> ACCOUNT LOCK. Review UNIFIED_AUDIT_TRAIL for the DML-ROLLBACK pattern from this session. Use Flashback Transaction Query on the affected tables to recover any partial changes. Unlock after investigation: ALTER USER <username> ACCOUNT UNLOCK. Enforce bind variables and statement_timeout via resource plan.',
    'medium', true
  );

-- ============================================================
-- SEC-SQL-AUD-012-RC05  Savepoint abuse with repeated partial rollbacks
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-012-RC05', 'postgresql',
    'Terminate savepoint abuse session - PostgreSQL',
    'aud-012-rc05-terminate-savepoint-abuse-pg',
    'Terminate the session performing abnormal rapid savepoint-rollback cycles consistent with MVCC timing probing.',
    'high',
    'AUD-012-RC05: Terminate savepoint abuse session - PostgreSQL', 'immediate',
    'Identify: SELECT pid, usename, query, state FROM pg_stat_activity WHERE query ILIKE ''%SAVEPOINT%'' OR query ILIKE ''%ROLLBACK TO%''. Use pg_audit logs to count SAVEPOINT and ROLLBACK TO SAVEPOINT events per session in the last 5 minutes. Terminate suspicious sessions: SELECT pg_terminate_backend(pid).',
    'high', false,
    'AUD-012-RC05: Set transaction timeout and audit savepoint frequency - PostgreSQL', 'configure',
    'Set a statement and idle transaction timeout for the application role: ALTER ROLE <app_role> SET statement_timeout = ''30s'' AND idle_in_transaction_session_timeout = ''120000''. Enable pg_audit to alert when SAVEPOINT statements exceed a threshold per session. Review the application for any legitimate use of savepoints to confirm anomaly.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-012-RC05', 'sqlserver',
    'Terminate savepoint abuse session - SQL Server',
    'aud-012-rc05-terminate-savepoint-abuse-sqlserver',
    'Kill the session performing abnormal SAVE TRANSACTION and ROLLBACK TO SAVEPOINT cycles.',
    'high',
    'AUD-012-RC05: Kill savepoint abuse session - SQL Server', 'immediate',
    'Use Extended Events or SQL Trace to capture SAVE TRANSACTION and ROLLBACK events from the suspicious session. Identify the session via sys.dm_exec_sessions and sys.dm_exec_requests. Kill: KILL <session_id>. Record the frequency of savepoint events from the Extended Events data.',
    'high', false,
    'AUD-012-RC05: Monitor savepoint frequency and enforce transaction scope - SQL Server', 'configure',
    'Create an Extended Events session alerting when SAVE TRANSACTION is executed more than 20 times per minute from a single session. Review the application code for any legitimate use of nested transactions with savepoints. Consider restricting the login to specific stored procedures that do not expose savepoint operations.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-012-RC05', 'mysql',
    'Terminate savepoint abuse session - MySQL',
    'aud-012-rc05-terminate-savepoint-abuse-mysql',
    'Kill the thread performing abnormal rapid SAVEPOINT and ROLLBACK TO SAVEPOINT cycles.',
    'high',
    'AUD-012-RC05: Kill savepoint abuse thread - MySQL', 'immediate',
    'Query performance_schema.events_transactions_history_long for the account and check NUMBER_OF_SAVEPOINTS and ROLLBACKS_TO_SAVEPOINT counts per transaction. Identify the thread via INFORMATION_SCHEMA.PROCESSLIST. Kill: KILL <process_id>.',
    'high', false,
    'AUD-012-RC05: Set transaction timeout and audit savepoint frequency - MySQL', 'configure',
    'Set: SET GLOBAL innodb_lock_wait_timeout = 30 to limit how long savepoint-held locks can block. Enable performance_schema and write a monitoring query that alerts when NUMBER_OF_SAVEPOINTS from a single user exceeds 30 in a 1-minute window. Review the application for legitimate savepoint use.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-012-RC05', 'oracle',
    'Terminate savepoint abuse session - Oracle',
    'aud-012-rc05-terminate-savepoint-abuse-oracle',
    'Kill the Oracle session performing abnormal rapid SAVEPOINT and ROLLBACK TO SAVEPOINT cycles.',
    'high',
    'AUD-012-RC05: Kill savepoint abuse session - Oracle', 'immediate',
    'Query UNIFIED_AUDIT_TRAIL for SAVEPOINT and ROLLBACK TO SAVEPOINT frequency from the session: SELECT count(*), db_username FROM unified_audit_trail WHERE action_name IN (''SAVEPOINT'',''ROLLBACK TO SAVEPOINT'') AND event_timestamp > systimestamp - interval ''5'' minute GROUP BY db_username. Kill: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE.',
    'high', false,
    'AUD-012-RC05: Add Unified Audit policy on savepoint frequency and set resource limit - Oracle', 'configure',
    'Create a Unified Audit condition alerting when SAVEPOINT events exceed a threshold per session per minute. Set a resource plan CPU limit for the application consumer group to bound the damage of tight savepoint loops. Review the application for any legitimate nested transaction patterns that could be rewritten.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-013-RC01  Security-relevant ALTER SYSTEM by non-admin
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-013-RC01', 'postgresql',
    'Revert unauthorized ALTER SYSTEM parameter change - PostgreSQL',
    'aud-013-rc01-revert-alter-system-pg',
    'Revert the security-relevant parameter changed via ALTER SYSTEM by a non-superuser account and restrict the privilege.',
    'critical',
    'AUD-013-RC01: Revert unauthorized ALTER SYSTEM change - PostgreSQL', 'immediate',
    'Identify the changed parameter in pg_settings by comparing current value to the expected baseline. Revert: ALTER SYSTEM SET <parameter> = <expected_value>. SELECT pg_reload_conf() to apply. Terminate any sessions that connected after the unauthorized change that may have exploited the modified setting.',
    'high', true,
    'AUD-013-RC01: Revoke superuser and restrict ALTER SYSTEM access - PostgreSQL', 'remediate',
    'Revoke SUPERUSER from the account that issued ALTER SYSTEM if not required: ALTER ROLE <user> NOSUPERUSER. In PostgreSQL 15+ use pg_read_all_settings and pg_write_all_settings roles granularly instead of full superuser. Enable alerting on any ALTER SYSTEM command from non-superuser accounts via pg_audit event trigger.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-013-RC01', 'sqlserver',
    'Revert unauthorized sp_configure change - SQL Server',
    'aud-013-rc01-revert-sp-configure-sqlserver',
    'Revert the security-relevant server configuration changed by a non-sysadmin account and restrict the privilege.',
    'critical',
    'AUD-013-RC01: Revert unauthorized sp_configure change - SQL Server', 'immediate',
    'Identify the changed option: SELECT name, value_in_use FROM sys.configurations WHERE is_advanced = 1 and compare to baseline. Revert: EXEC sp_configure ''<option>'', <expected_value>; RECONFIGURE WITH OVERRIDE. Terminate sessions started after the unauthorized change that may have benefited from the modified configuration.',
    'high', true,
    'AUD-013-RC01: Revoke CONTROL SERVER and restrict sp_configure - SQL Server', 'remediate',
    'Revoke CONTROL SERVER and ALTER SETTINGS from the login that made the unauthorized change. Ensure only sysadmin members can execute sp_configure. Create a SQL Server Audit specification alerting on sp_configure execution by any non-sysadmin login. Enable the Policy-Based Management policy checking critical server configurations match baseline on a scheduled basis.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-013-RC01', 'mysql',
    'Revert unauthorized SET GLOBAL security parameter change - MySQL',
    'aud-013-rc01-revert-set-global-mysql',
    'Revert the security-relevant global variable changed by a non-DBA account and restrict the SYSTEM_VARIABLES_ADMIN privilege.',
    'critical',
    'AUD-013-RC01: Revert unauthorized SET GLOBAL change - MySQL', 'immediate',
    'Identify changed variables by comparing SHOW GLOBAL VARIABLES output to the known baseline. Revert: SET GLOBAL <variable_name> = <expected_value>. Verify with SHOW GLOBAL VARIABLES LIKE ''<variable_name>''. Terminate sessions that connected after the unauthorized change.',
    'high', true,
    'AUD-013-RC01: Revoke SYSTEM_VARIABLES_ADMIN privilege - MySQL', 'remediate',
    'Revoke SYSTEM_VARIABLES_ADMIN from the account that made the unauthorized change: REVOKE SYSTEM_VARIABLES_ADMIN ON *.* FROM ''<user>''@''<host>''. In MySQL 8.0 use SET PERSIST_ONLY to protect critical variables from runtime modification. Enable audit_log filtering on SET GLOBAL events from non-DBA accounts.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-013-RC01', 'oracle',
    'Revert unauthorized ALTER SYSTEM security parameter change - Oracle',
    'aud-013-rc01-revert-alter-system-oracle',
    'Revert the security-relevant initialization parameter changed by a non-DBA account and restrict ALTER SYSTEM privilege.',
    'critical',
    'AUD-013-RC01: Revert unauthorized ALTER SYSTEM change - Oracle', 'immediate',
    'Identify the changed parameter: SELECT name, value FROM v$parameter WHERE name IN (<list of security-relevant params>) and compare to the baseline. Revert: ALTER SYSTEM SET <parameter> = <expected_value> SCOPE = BOTH. Kill the session that made the change: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE.',
    'high', true,
    'AUD-013-RC01: Revoke ALTER SYSTEM privilege and use Database Vault - Oracle', 'remediate',
    'Revoke ALTER SYSTEM from the account. Grant only the specific system-level privileges required by the account role. Use Oracle Database Vault command rules to enforce two-person integrity for critical ALTER SYSTEM changes. Add Unified Audit policy on ALTER SYSTEM by non-SYS, non-DBA accounts.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-013-RC02  Dangerous feature enabled during session
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-013-RC02', 'postgresql',
    'Disable dangerous feature enabled mid-session - PostgreSQL',
    'aud-013-rc02-disable-dangerous-feature-pg',
    'Immediately disable any dangerous runtime feature enabled mid-session (such as untrusted language extensions) and revoke the privilege that allowed it.',
    'critical',
    'AUD-013-RC02: Disable dangerous feature and terminate session - PostgreSQL', 'immediate',
    'Terminate the session that enabled the dangerous feature: SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid = <target_pid>. Revert the feature: ALTER SYSTEM SET <feature_parameter> = <safe_default> and SELECT pg_reload_conf(). Check pg_extension and pg_proc for any objects created by the session.',
    'high', true,
    'AUD-013-RC02: Revoke privilege enabling dangerous features - PostgreSQL', 'remediate',
    'Revoke SUPERUSER or the specific CREATE EXTENSION privilege from the account. Maintain a whitelist of permitted extensions via PostgreSQL extension allow-listing. Enable pg_audit to alert on any LOAD, CREATE EXTENSION, or ALTER SYSTEM commands from non-superuser accounts.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-013-RC02', 'sqlserver',
    'Disable xp_cmdshell or dangerous feature enabled mid-session - SQL Server',
    'aud-013-rc02-disable-dangerous-feature-sqlserver',
    'Immediately disable xp_cmdshell or other dangerous feature enabled via sp_configure and revoke the privilege.',
    'critical',
    'AUD-013-RC02: Disable xp_cmdshell and kill enabling session - SQL Server', 'immediate',
    'Disable the feature: EXEC sp_configure ''xp_cmdshell'', 0; RECONFIGURE. Kill the session that enabled it: KILL <spid>. Check sys.dm_os_ring_buffers and SQL Server error log for any OS commands already executed via xp_cmdshell during the window the feature was enabled.',
    'high', true,
    'AUD-013-RC02: Restrict sp_configure dangerous options and audit - SQL Server', 'remediate',
    'Revoke ALTER SETTINGS from the login. Remove from sysadmin if not required. Set a Policy-Based Management policy enforcing xp_cmdshell = 0 and evaluate on schedule. Create an Extended Events alert firing immediately when xp_cmdshell or Ole Automation Procedures are enabled by any account.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-013-RC02', 'mysql',
    'Disable dangerous plugin or LOAD DATA INFILE enabled mid-session - MySQL',
    'aud-013-rc02-disable-dangerous-feature-mysql',
    'Immediately disable the dangerous feature enabled at runtime (e.g. LOAD DATA LOCAL INFILE) and revoke the privilege.',
    'critical',
    'AUD-013-RC02: Disable dangerous feature and kill enabling thread - MySQL', 'immediate',
    'Disable: SET GLOBAL local_infile = OFF or SET GLOBAL <feature_variable> = OFF. Kill the thread that enabled it: KILL <process_id>. Review general_log or binary log for any LOAD DATA INFILE commands executed during the window the feature was enabled.',
    'high', true,
    'AUD-013-RC02: Restrict SYSTEM_VARIABLES_ADMIN and audit feature toggles - MySQL', 'remediate',
    'Revoke SYSTEM_VARIABLES_ADMIN from the account. Set local_infile = OFF in my.cnf and protect with SET PERSIST. Enable audit_log to alert on changes to security-relevant global variables. Review the list of loaded plugins for any unauthorized additions made during the session.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-013-RC02', 'oracle',
    'Disable dangerous package or UTL_FILE access enabled mid-session - Oracle',
    'aud-013-rc02-disable-dangerous-feature-oracle',
    'Revoke the dangerous package privilege (UTL_FILE, DBMS_SCHEDULER OS jobs) enabled during the session and audit OS-level activity.',
    'critical',
    'AUD-013-RC02: Revoke dangerous package privilege and kill session - Oracle', 'immediate',
    'Kill the session: ALTER SYSTEM KILL SESSION ''<sid>,<serial#>'' IMMEDIATE. Revoke the privilege: REVOKE EXECUTE ON UTL_FILE FROM <account> or REVOKE CREATE JOB FROM <account>. Review DBA_SCHEDULER_JOBS and DBA_SCHEDULER_JOB_LOG for any OS jobs created or run during the incident window.',
    'high', true,
    'AUD-013-RC02: Restrict powerful package grants and use Database Vault - Oracle', 'remediate',
    'Review DBA_TAB_PRIVS for all EXECUTE grants on UTL_FILE, UTL_HTTP, DBMS_SCHEDULER, and DBMS_ADVISOR and revoke from accounts that do not have a business need. Use Oracle Database Vault to enforce command rules requiring dual approval before granting OS-execution-capable package access. Add Unified Audit policy on EXECUTE of UTL_FILE and DBMS_SCHEDULER.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-013-RC03  Trigger disabled/dropped on monitored table
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-013-RC03', 'postgresql',
    'Restore audit trigger dropped or disabled on monitored table - PostgreSQL',
    'aud-013-rc03-restore-audit-trigger-pg',
    'Restore the audit or validation trigger that was disabled or dropped on a monitored table and restrict the ALTER TABLE privilege.',
    'high',
    'AUD-013-RC03: Re-enable or recreate dropped trigger - PostgreSQL', 'immediate',
    'Re-enable: ALTER TABLE <table_name> ENABLE TRIGGER <trigger_name>. If the trigger was dropped, recreate it from source control. Review WAL or pg_audit logs for DML on the table during the window the trigger was absent to identify any unaudited changes.',
    'high', true,
    'AUD-013-RC03: Restrict ALTER TABLE on monitored tables and add event trigger - PostgreSQL', 'remediate',
    'Revoke ALTER TABLE on monitored tables from the application role. Create an event trigger alerting on DISABLE TRIGGER and DROP TRIGGER DDL events on monitored table names. Store all trigger definitions in source control and implement a nightly drift detection job.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-013-RC03', 'sqlserver',
    'Restore audit trigger dropped or disabled on monitored table - SQL Server',
    'aud-013-rc03-restore-audit-trigger-sqlserver',
    'Re-enable or recreate the trigger disabled or dropped on a monitored table and restrict ALTER TABLE permissions.',
    'high',
    'AUD-013-RC03: Re-enable or recreate trigger - SQL Server', 'immediate',
    'Re-enable: ENABLE TRIGGER <trigger_name> ON <table_name>. If dropped, recreate from source control. Review CDC or the transaction log for DML on the table during the trigger absence window using fn_dblog() or cdc.fn_cdc_get_all_changes().',
    'high', true,
    'AUD-013-RC03: Restrict DISABLE TRIGGER and add DDL alert - SQL Server', 'remediate',
    'Deny ALTER permission on monitored tables to all application logins. Create a DDL trigger: CREATE TRIGGER protect_audit_triggers ON DATABASE FOR DISABLE_TRIGGER, DROP_TRIGGER alerting the security team. Enable SQL Server Audit tracking DISABLE_TRIGGER events on production databases.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-013-RC03', 'mysql',
    'Restore audit trigger dropped on monitored table - MySQL',
    'aud-013-rc03-restore-audit-trigger-mysql',
    'Recreate the dropped audit trigger on the monitored table (MySQL has no DISABLE TRIGGER) and restrict TRIGGER privilege.',
    'high',
    'AUD-013-RC03: Recreate dropped trigger from source control - MySQL', 'immediate',
    'Recreate the trigger from source control or information_schema.triggers backup. Use mysqlbinlog to enumerate DML on the affected table during the gap between DROP TRIGGER and trigger restoration to identify unaudited changes.',
    'high', true,
    'AUD-013-RC03: Revoke TRIGGER privilege and protect trigger definitions - MySQL', 'remediate',
    'Revoke TRIGGER privilege on the affected table from all accounts except the designated DBA: REVOKE TRIGGER ON <db>.<table> FROM ''<user>''@''<host>''. Store trigger definitions in source control. Enable audit_log to alert on DROP TRIGGER commands on monitored tables.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-013-RC03', 'oracle',
    'Restore audit trigger dropped or disabled on monitored table - Oracle',
    'aud-013-rc03-restore-audit-trigger-oracle',
    'Re-enable or recreate the trigger disabled or dropped on a monitored Oracle table and restrict ALTER TRIGGER privilege.',
    'high',
    'AUD-013-RC03: Re-enable or recreate trigger - Oracle', 'immediate',
    'Re-enable: ALTER TRIGGER <trigger_name> ENABLE. If dropped, recreate from source control or use DBMS_METADATA.GET_DDL from a backup schema. Use Flashback Versions Query on the affected table for the gap period to identify rows changed without trigger coverage.',
    'high', true,
    'AUD-013-RC03: Restrict ALTER ANY TRIGGER and add DDL audit policy - Oracle', 'remediate',
    'Revoke ALTER ANY TRIGGER from accounts that do not require it. Use Database Vault command rules to require dual approval for disabling triggers on tables in protected schemas. Add Unified Audit policy on ALTER TRIGGER and DROP TRIGGER commands by non-DBA accounts.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-013-RC04  Audit/logging parameters changed mid-session
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-013-RC04', 'postgresql',
    'Restore audit verbosity reduced mid-session - PostgreSQL',
    'aud-013-rc04-restore-audit-verbosity-pg',
    'Restore audit logging verbosity reduced by a session-level SET command and investigate activity during the reduced-logging window.',
    'critical',
    'AUD-013-RC04: Restore audit logging verbosity - PostgreSQL', 'immediate',
    'Check current session settings: SELECT name, setting FROM pg_settings WHERE name LIKE ''log%''. Restore: ALTER SYSTEM SET log_statement = ''all'' and SELECT pg_reload_conf(). Terminate sessions that reduced their own logging: identify via pg_stat_activity where state is active and note client_addr.',
    'high', true,
    'AUD-013-RC04: Restrict SET log_statement and enforce configuration baseline - PostgreSQL', 'remediate',
    'Prevent application roles from overriding log settings: use ALTER ROLE <app_role> SET log_statement = ''all'' to enforce the setting cannot be lowered. In PostgreSQL 16+ use the pg_parameter_acl system catalog to restrict per-parameter SET rights. Add pg_audit alerts on any SET log_statement or SET log_min_duration commands.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-013-RC04', 'sqlserver',
    'Restore audit verbosity reduced mid-session - SQL Server',
    'aud-013-rc04-restore-audit-verbosity-sqlserver',
    'Re-enable SQL Server Audit specifications or Extended Events sessions that were altered to reduce logging.',
    'critical',
    'AUD-013-RC04: Re-enable reduced audit specifications - SQL Server', 'immediate',
    'Check audit state: SELECT name, is_state_enabled FROM sys.server_audit_specifications. Re-enable: ALTER SERVER AUDIT SPECIFICATION <spec_name> WITH (STATE = ON). Review sys.dm_exec_query_stats for activity during the reduced-logging window.',
    'high', true,
    'AUD-013-RC04: Restrict ALTER ANY SERVER AUDIT and use immutable audit target - SQL Server', 'remediate',
    'Revoke ALTER ANY SERVER AUDIT from logins that do not require it. Route SQL Server Audit output to an Azure Blob immutable storage container so no session-level command can reduce the external audit record. Create a dedicated audit specification that monitors changes to other audit specifications.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-013-RC04', 'mysql',
    'Restore audit verbosity reduced mid-session - MySQL',
    'aud-013-rc04-restore-audit-verbosity-mysql',
    'Re-enable audit_log or general_log that was disabled and investigate activity during the blind spot.',
    'critical',
    'AUD-013-RC04: Re-enable MySQL audit logging - MySQL', 'immediate',
    'Re-enable: SET GLOBAL audit_log_policy = ALL or SET GLOBAL general_log = ON. Verify with SHOW GLOBAL VARIABLES LIKE ''audit_log_policy''. Query performance_schema.events_statements_history_long for statements executed during the window when logging was reduced.',
    'high', true,
    'AUD-013-RC04: Restrict AUDIT_ADMIN privilege and use remote syslog - MySQL', 'remediate',
    'Revoke AUDIT_ADMIN from all accounts except designated security administrators. Configure audit_log plugin with audit_log_format = JSON and forward to a remote syslog or SIEM where session-level commands cannot affect the external record. Set audit_log_rotate_on_size to rotate locally without loss.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-013-RC04', 'oracle',
    'Restore audit verbosity reduced mid-session - Oracle',
    'aud-013-rc04-restore-audit-verbosity-oracle',
    'Re-enable Unified Audit policies or traditional audit settings reduced mid-session and investigate the blind-spot window.',
    'critical',
    'AUD-013-RC04: Re-enable audit policies - Oracle', 'immediate',
    'Re-enable: AUDIT POLICY <policy_name>. Verify: SELECT policy_name, enabled_option, success, failure FROM audit_unified_enabled_policies. Query UNIFIED_AUDIT_TRAIL for any entries during the gap period to assess what was not captured.',
    'high', true,
    'AUD-013-RC04: Restrict AUDIT SYSTEM privilege and use Audit Vault - Oracle', 'remediate',
    'Revoke AUDIT SYSTEM privilege from all accounts except the designated security manager. Use Database Vault to prevent even DBAs from disabling audit policies without security officer approval. Route UNIFIED_AUDIT_TRAIL output to Oracle Audit Vault for tamper-resistant off-database storage.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-013-RC05  Network/auth config modified at runtime
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-013-RC05', 'postgresql',
    'Revert runtime network or auth config change - PostgreSQL',
    'aud-013-rc05-revert-network-auth-config-pg',
    'Revert unauthorized changes to pg_hba.conf or authentication parameters applied at runtime and audit new connections made through the unauthorized path.',
    'critical',
    'AUD-013-RC05: Revert pg_hba.conf or auth parameter change - PostgreSQL', 'immediate',
    'Restore pg_hba.conf from the last approved backup or source-controlled copy. Run SELECT pg_reload_conf() to apply. Terminate any sessions that connected via the unauthorized authentication rule: identify them by auth_method in pg_stat_activity or connection logs. Review pg_settings for any SSL or authentication parameters changed via ALTER SYSTEM.',
    'high', true,
    'AUD-013-RC05: Protect pg_hba.conf from runtime modification - PostgreSQL', 'remediate',
    'Store pg_hba.conf in a version-controlled repository with file integrity monitoring. Restrict OS-level write access to the PostgreSQL data directory to the postgres service account. Enable alerts when pg_hba.conf file modification time changes. Revoke SUPERUSER from accounts that modified the configuration.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-013-RC05', 'sqlserver',
    'Revert runtime linked server or auth config change - SQL Server',
    'aud-013-rc05-revert-network-auth-config-sqlserver',
    'Remove unauthorized linked server definitions or authentication configuration changes made at runtime.',
    'critical',
    'AUD-013-RC05: Drop unauthorized linked server - SQL Server', 'immediate',
    'Identify new linked servers: SELECT name, data_source, provider, modify_date FROM sys.servers WHERE is_linked = 1 ORDER BY modify_date DESC. Drop unauthorized entries: EXEC sp_dropserver ''<linked_server_name>'', ''droplogins''. Check sys.dm_exec_sessions for connections made through the unauthorized server.',
    'high', true,
    'AUD-013-RC05: Restrict linked server management and audit server changes - SQL Server', 'remediate',
    'Revoke ALTER ANY LINKED SERVER from logins that do not require it. Restrict to sysadmin only. Create a SQL Server Audit specification alerting on linked server creation by any account. Review existing linked servers against an approved inventory and remove any undocumented entries.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-013-RC05', 'mysql',
    'Revert runtime auth or network configuration change - MySQL',
    'aud-013-rc05-revert-network-auth-config-mysql',
    'Revert unauthorized changes to MySQL authentication plugins or network bind address made at runtime.',
    'critical',
    'AUD-013-RC05: Revert unauthorized auth plugin or bind change - MySQL', 'immediate',
    'Check for unauthorized authentication plugin changes: SELECT user, host, plugin FROM mysql.user ORDER BY password_changed_time DESC LIMIT 20. Revert unauthorized plugin assignments: ALTER USER ''<user>''@''<host>'' IDENTIFIED WITH caching_sha2_password. FLUSH PRIVILEGES. Check for bind-address or skip-networking changes in SHOW GLOBAL VARIABLES.',
    'high', true,
    'AUD-013-RC05: Restrict SYSTEM_VARIABLES_ADMIN and protect auth configuration - MySQL', 'remediate',
    'Revoke SYSTEM_VARIABLES_ADMIN from non-DBA accounts. Store my.cnf under version control with file integrity monitoring. Enable audit_log filtering on ALTER USER and changes to authentication-related global variables. Review all user plugin assignments against the approved baseline.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-013-RC05', 'oracle',
    'Revert runtime authentication or network configuration change - Oracle',
    'aud-013-rc05-revert-network-auth-config-oracle',
    'Revert unauthorized changes to Oracle authentication parameters or sqlnet.ora made at runtime and remove unauthorized database links.',
    'critical',
    'AUD-013-RC05: Revert auth parameter and remove unauthorized DB links - Oracle', 'immediate',
    'Identify changed authentication parameters: SELECT name, value FROM v$parameter WHERE name LIKE ''%auth%'' OR name LIKE ''%wallet%'' and compare to baseline. Revert via ALTER SYSTEM SET <param> = <baseline_value> SCOPE = BOTH. List and drop unauthorized database links: SELECT db_link, username FROM dba_db_links ORDER BY last_ddl_time DESC.',
    'high', true,
    'AUD-013-RC05: Restrict ALTER SYSTEM and DB link creation - Oracle', 'remediate',
    'Revoke CREATE DATABASE LINK and ALTER SYSTEM from accounts that do not require them. Use Database Vault command rules for dual approval on authentication parameter changes. Add Unified Audit policy on CREATE DATABASE LINK, DROP DATABASE LINK, and ALTER SYSTEM authentication parameter changes.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-014-RC01  New user/login created during session
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-014-RC01', 'postgresql',
    'Drop backdoor account created during application session - PostgreSQL',
    'aud-014-rc01-drop-backdoor-account-pg',
    'Drop the unauthorized account created mid-session and revoke the CREATEROLE or SUPERUSER privilege that allowed it.',
    'critical',
    'AUD-014-RC01: Drop unauthorized account - PostgreSQL', 'immediate',
    'Identify recently created roles: SELECT rolname, rolcreatedb, rolcreaterole, rolcanlogin, pg_postmaster_start_time() AS server_start FROM pg_roles ORDER BY oid DESC LIMIT 10. Drop the unauthorized account: DROP ROLE <new_role>. Terminate any sessions already connected as the new role: SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = ''<new_role>''.',
    'high', true,
    'AUD-014-RC01: Revoke CREATEROLE from application role - PostgreSQL', 'remediate',
    'Revoke CREATEROLE from the account that created the backdoor: ALTER ROLE <compromised_role> NOCREATEROLE. Review all roles with CREATEROLE and SUPERUSER against the approved list. Enable pg_audit to alert on CREATE ROLE and CREATE USER commands from non-superuser accounts. Implement a daily drift check comparing pg_roles to the approved role inventory.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-014-RC01', 'sqlserver',
    'Drop backdoor login created during application session - SQL Server',
    'aud-014-rc01-drop-backdoor-account-sqlserver',
    'Drop the unauthorized SQL login or database user created mid-session and restrict the privilege.',
    'critical',
    'AUD-014-RC01: Drop unauthorized login and user - SQL Server', 'immediate',
    'Identify recently created logins: SELECT name, create_date, type_desc FROM sys.server_principals WHERE type IN (''S'',''U'') ORDER BY create_date DESC. Drop the unauthorized login: DROP LOGIN <login_name>. Drop the associated database user: DROP USER <username>. Terminate any active sessions for the new login: KILL <spid>.',
    'high', true,
    'AUD-014-RC01: Revoke CREATE LOGIN privilege and audit account creation - SQL Server', 'remediate',
    'Revoke ALTER ANY LOGIN from the login that created the backdoor. Restrict CREATE LOGIN to sysadmin and securityadmin. Create a SQL Server Audit specification alerting on CREATE_LOGIN and CREATE_USER events from any non-sysadmin account. Implement a scheduled Policy-Based Management check comparing sys.server_principals to an approved baseline.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-014-RC01', 'mysql',
    'Drop backdoor account created during application session - MySQL',
    'aud-014-rc01-drop-backdoor-account-mysql',
    'Drop the unauthorized MySQL user created mid-session and revoke CREATE USER privilege.',
    'critical',
    'AUD-014-RC01: Drop unauthorized MySQL user - MySQL', 'immediate',
    'Identify recently created users: SELECT user, host, password_changed_time FROM mysql.user ORDER BY password_changed_time DESC LIMIT 10. Drop the unauthorized account: DROP USER ''<user>''@''<host>''. FLUSH PRIVILEGES. Kill any active connections for the new user: SELECT id FROM information_schema.processlist WHERE user = ''<new_user>'' -- then KILL each.',
    'high', true,
    'AUD-014-RC01: Revoke CREATE USER privilege and audit account creation - MySQL', 'remediate',
    'Revoke CREATE USER from the account that created the backdoor: REVOKE CREATE USER ON *.* FROM ''<compromised_user>''@''<host>''. FLUSH PRIVILEGES. Enable audit_log filtering on CREATE USER and GRANT events from non-DBA accounts. Implement a daily script comparing mysql.user to the approved user inventory and alerting on any new entries.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-014-RC01', 'oracle',
    'Drop backdoor account created during application session - Oracle',
    'aud-014-rc01-drop-backdoor-account-oracle',
    'Drop the unauthorized Oracle user created mid-session and revoke CREATE USER privilege.',
    'critical',
    'AUD-014-RC01: Drop unauthorized Oracle user - Oracle', 'immediate',
    'Identify recently created accounts: SELECT username, created FROM dba_users ORDER BY created DESC FETCH FIRST 10 ROWS ONLY. Drop the unauthorized account: DROP USER <new_username> CASCADE. Kill any active sessions for the new user: SELECT sid, serial# FROM v$session WHERE username = ''<new_username>'' -- then ALTER SYSTEM KILL SESSION.',
    'high', true,
    'AUD-014-RC01: Revoke CREATE USER privilege and add audit policy - Oracle', 'remediate',
    'Revoke CREATE USER from the account that created the backdoor. Restrict CREATE USER to DBA-level accounts only. Use Database Vault to require security officer approval for user creation outside maintenance windows. Add Unified Audit policy on CREATE USER and CREATE ROLE commands by all accounts.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-014-RC02  Account added to privileged role mid-session
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-014-RC02', 'postgresql',
    'Revoke unauthorized privilege escalation role grant - PostgreSQL',
    'aud-014-rc02-revoke-privilege-escalation-pg',
    'Revoke the unauthorized role grant that elevated an account to superuser or DBA-level privileges during an active session.',
    'critical',
    'AUD-014-RC02: Revoke unauthorized role grant - PostgreSQL', 'immediate',
    'Identify recent role grants: SELECT grantor, grantee, admin_option FROM information_schema.applicable_roles ORDER BY grantee. Revoke the unauthorized grant: REVOKE <privileged_role> FROM <grantee>. Terminate any sessions currently running with the escalated privilege: SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = ''<grantee>''.',
    'high', true,
    'AUD-014-RC02: Restrict GRANT privilege and audit role membership - PostgreSQL', 'remediate',
    'Revoke CREATEROLE and the GRANT OPTION from the account that issued the unauthorized grant. Restrict privileged role membership changes to superuser accounts only. Enable pg_audit to alert on GRANT commands involving privileged roles. Implement a daily drift check comparing pg_auth_members to the approved role membership baseline.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-014-RC02', 'sqlserver',
    'Revoke unauthorized server role membership grant - SQL Server',
    'aud-014-rc02-revoke-privilege-escalation-sqlserver',
    'Remove the unauthorized login from the sysadmin or db_owner role added mid-session.',
    'critical',
    'AUD-014-RC02: Remove login from privileged role - SQL Server', 'immediate',
    'Identify recent role membership changes via SQL Server Audit or system table history. Remove from role: ALTER SERVER ROLE sysadmin DROP MEMBER <login_name> or ALTER ROLE db_owner DROP MEMBER <username>. Terminate active sessions for the escalated login: KILL <spid>.',
    'high', true,
    'AUD-014-RC02: Restrict ALTER SERVER ROLE and audit role membership changes - SQL Server', 'remediate',
    'Revoke ALTER ANY SERVER ROLE and ALTER ANY ROLE from the login that made the unauthorized change. Restrict sysadmin and securityadmin membership changes to existing sysadmin members. Create a SQL Server Audit specification alerting on server role membership changes. Implement scheduled comparison of sys.server_role_members to the approved baseline.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-014-RC02', 'mysql',
    'Revoke unauthorized privilege grant to application account - MySQL',
    'aud-014-rc02-revoke-privilege-escalation-mysql',
    'Revoke the unauthorized GRANT that elevated an application account to DBA-level privileges mid-session.',
    'critical',
    'AUD-014-RC02: Revoke unauthorized privilege grant - MySQL', 'immediate',
    'Identify recent grants: SELECT * FROM information_schema.user_privileges WHERE grantee = ''<escalated_user>'' ORDER BY privilege_type. Revoke excess privileges: REVOKE ALL PRIVILEGES ON *.* FROM ''<user>''@''<host>''. Re-grant only the approved minimum set. FLUSH PRIVILEGES. Kill active sessions for the escalated user.',
    'high', true,
    'AUD-014-RC02: Restrict GRANT OPTION and audit privilege changes - MySQL', 'remediate',
    'Revoke GRANT OPTION from the account that issued the unauthorized grant: REVOKE GRANT OPTION FOR ALL PRIVILEGES ON *.* FROM ''<compromised_user>''@''<host>''. FLUSH PRIVILEGES. Enable audit_log to alert on GRANT statements from non-DBA accounts. Review all accounts with GRANT OPTION against the approved list.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-014-RC02', 'oracle',
    'Revoke unauthorized DBA role grant during session - Oracle',
    'aud-014-rc02-revoke-privilege-escalation-oracle',
    'Revoke the DBA or privileged role granted to an account during an active application session.',
    'critical',
    'AUD-014-RC02: Revoke unauthorized role grant - Oracle', 'immediate',
    'Identify recent grants: SELECT grantee, granted_role, admin_option, default_role FROM dba_role_privs WHERE granted_role IN (''DBA'',''SYSDBA'',''SYSOPER'') ORDER BY grantee. Revoke: REVOKE DBA FROM <grantee>. Kill sessions running with the escalated role: SELECT sid, serial# FROM v$session WHERE username = ''<grantee>'' -- then ALTER SYSTEM KILL SESSION.',
    'high', true,
    'AUD-014-RC02: Restrict GRANT ANY ROLE and use Database Vault - Oracle', 'remediate',
    'Revoke GRANT ANY ROLE from the account that issued the unauthorized grant. Use Oracle Database Vault to require dual approval for DBA role grants. Add Unified Audit policy on GRANT and REVOKE commands for all privileged roles. Implement nightly comparison of DBA_ROLE_PRIVS to the approved role grant baseline.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-014-RC03  Password changed on another account
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-014-RC03', 'postgresql',
    'Reset password changed on another account mid-session - PostgreSQL',
    'aud-014-rc03-reset-hijacked-password-pg',
    'Reset the password changed on another account during the incident session and investigate whether the target account was used after the change.',
    'critical',
    'AUD-014-RC03: Reset hijacked account password - PostgreSQL', 'immediate',
    'Reset the password to a new secure value: ALTER ROLE <target_account> PASSWORD ''<new_secure_password>''. Immediately terminate any sessions authenticated as the target account: SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = ''<target_account>''. Review pg_audit logs for activity by the target account after the password change.',
    'high', true,
    'AUD-014-RC03: Restrict ALTER ROLE password change and enforce MFA - PostgreSQL', 'remediate',
    'Revoke CREATEROLE from the account that changed another account''s password. In PostgreSQL only superusers and roles with CREATEROLE can change another role''s password - review and remove excess CREATEROLE grants. Add pg_audit alerting on ALTER ROLE statements that include the PASSWORD keyword targeting any account other than the current_user.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-014-RC03', 'sqlserver',
    'Reset password changed on another login mid-session - SQL Server',
    'aud-014-rc03-reset-hijacked-password-sqlserver',
    'Reset the SQL login password changed during the incident and investigate whether the target login was used after the change.',
    'critical',
    'AUD-014-RC03: Reset hijacked login password - SQL Server', 'immediate',
    'Reset the password: ALTER LOGIN <target_login> WITH PASSWORD = ''<new_secure_password>'' MUST_CHANGE. Kill any active sessions for the target login: KILL <spid>. Review SQL Server Audit for any activity by the target login after the unauthorized password change.',
    'high', true,
    'AUD-014-RC03: Restrict ALTER ANY LOGIN and audit password changes - SQL Server', 'remediate',
    'Revoke ALTER ANY LOGIN from the login that changed another login''s password. Restrict this right to sysadmin and securityadmin members only. Create a SQL Server Audit specification alerting on ALTER_LOGIN events involving password changes for any login other than the current login. Enforce multi-factor authentication for privileged SQL logins where possible.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-014-RC03', 'mysql',
    'Reset password changed on another account mid-session - MySQL',
    'aud-014-rc03-reset-hijacked-password-mysql',
    'Reset the MySQL user password changed during the incident and investigate activity by the target account after the change.',
    'critical',
    'AUD-014-RC03: Reset hijacked account password - MySQL', 'immediate',
    'Reset: ALTER USER ''<target_user>''@''<host>'' IDENTIFIED BY ''<new_secure_password>'' PASSWORD EXPIRE. FLUSH PRIVILEGES. Kill any active sessions for the target user. Review audit_log or general_log for activity by the target account after the unauthorized password change.',
    'high', true,
    'AUD-014-RC03: Restrict password change privilege and audit ALTER USER - MySQL', 'remediate',
    'Revoke the ability to change other users'' passwords: ensure the compromised account does not hold CREATE USER or super-level UPDATE on mysql.user. Enable audit_log to alert on ALTER USER ... IDENTIFIED BY events that change a different user''s credentials. Enforce password validation policy: INSTALL COMPONENT ''file://component_validate_password''.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-014-RC03', 'oracle',
    'Reset password changed on another account mid-session - Oracle',
    'aud-014-rc03-reset-hijacked-password-oracle',
    'Reset the Oracle account password changed during the incident and lock the target account pending investigation.',
    'critical',
    'AUD-014-RC03: Reset and lock hijacked Oracle account - Oracle', 'immediate',
    'Lock and reset: ALTER USER <target_account> IDENTIFIED BY <new_secure_password> ACCOUNT LOCK. Kill any sessions for the target account: SELECT sid, serial# FROM v$session WHERE username = ''<target_account>'' -- then ALTER SYSTEM KILL SESSION for each. Review UNIFIED_AUDIT_TRAIL for activity by the target account after the unauthorized password change.',
    'high', true,
    'AUD-014-RC03: Restrict ALTER USER privilege and add audit policy - Oracle', 'remediate',
    'Revoke ALTER USER from the account that changed another account''s password. Restrict this privilege to DBAs only. Use Database Vault to require dual approval for password changes on privileged accounts. Add Unified Audit policy on ALTER USER ... IDENTIFIED BY events for all accounts. Unlock the target account only after confirming no additional compromise.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-014-RC04  Database link or synonym to external system created
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-014-RC04', 'postgresql',
    'Drop unauthorized foreign data wrapper created mid-session - PostgreSQL',
    'aud-014-rc04-drop-fdw-pg',
    'Drop the unauthorized foreign data wrapper or server object created mid-session that establishes a pathway to an external system.',
    'critical',
    'AUD-014-RC04: Drop unauthorized FDW server and user mapping - PostgreSQL', 'immediate',
    'List foreign servers: SELECT srvname, srvowner::regrole, srvoptions FROM pg_foreign_server. Drop the unauthorized entry: DROP SERVER <server_name> CASCADE which also removes associated user mappings and foreign tables. Terminate the session that created it: SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = ''<creator>''.',
    'high', true,
    'AUD-014-RC04: Revoke CREATE FOREIGN SERVER and restrict FDW usage - PostgreSQL', 'remediate',
    'Revoke CREATE on the public schema and USAGE on foreign data wrapper extensions from the application role. Allow FDW creation only for designated integration accounts. Enable pg_audit to alert on CREATE SERVER and CREATE FOREIGN TABLE commands from non-superuser accounts. Maintain an approved inventory of foreign server definitions.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-014-RC04', 'sqlserver',
    'Drop unauthorized linked server created mid-session - SQL Server',
    'aud-014-rc04-drop-linked-server-sqlserver',
    'Drop the unauthorized linked server created mid-session that could be used to pivot to or exfiltrate data to an external system.',
    'critical',
    'AUD-014-RC04: Drop unauthorized linked server - SQL Server', 'immediate',
    'Identify: SELECT name, data_source, create_date FROM sys.servers WHERE is_linked = 1 ORDER BY create_date DESC. Drop: EXEC sp_dropserver ''<linked_server_name>'', ''droplogins''. Terminate the session that created it: KILL <spid>. Review sys.dm_exec_query_stats for any queries already executed against the unauthorized linked server.',
    'high', true,
    'AUD-014-RC04: Restrict linked server creation and audit - SQL Server', 'remediate',
    'Revoke ALTER ANY LINKED SERVER from the login that created it. Restrict this right to sysadmin members only. Create a SQL Server Audit specification alerting on linked server creation. Maintain an approved linked server inventory and run a scheduled check comparing sys.servers to the baseline.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-014-RC04', 'mysql',
    'Drop unauthorized external connection pathway created mid-session - MySQL',
    'aud-014-rc04-drop-external-pathway-mysql',
    'Remove unauthorized external connection objects (federated tables or file-level import definitions) created mid-session in MySQL.',
    'critical',
    'AUD-014-RC04: Drop unauthorized federated table or external import object - MySQL', 'immediate',
    'Identify recently created FEDERATED tables: SELECT table_schema, table_name, engine, create_time FROM information_schema.tables WHERE engine = ''FEDERATED'' ORDER BY create_time DESC. Drop: DROP TABLE <schema>.<federated_table>. Kill the session that created it. Review binary logs for any data transferred via the unauthorized table.',
    'high', true,
    'AUD-014-RC04: Restrict FEDERATED engine usage and revoke FILE privilege - MySQL', 'remediate',
    'Disable the FEDERATED storage engine: add federated=OFF to my.cnf under [mysqld]. Revoke FILE privilege from all application accounts: REVOKE FILE ON *.* FROM ''<user>''@''<host>''. FLUSH PRIVILEGES. Enable audit_log to alert on CREATE TABLE with ENGINE=FEDERATED or LOAD DATA INFILE from application accounts.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-014-RC04', 'oracle',
    'Drop unauthorized database link created mid-session - Oracle',
    'aud-014-rc04-drop-database-link-oracle',
    'Drop the unauthorized database link created mid-session that establishes a pathway to an external Oracle instance.',
    'critical',
    'AUD-014-RC04: Drop unauthorized database link - Oracle', 'immediate',
    'List recently created links: SELECT db_link, username, host, created FROM dba_db_links ORDER BY created DESC FETCH FIRST 10 ROWS ONLY. Drop: DROP DATABASE LINK <link_name> or as the owning schema: DROP PUBLIC DATABASE LINK <link_name>. Kill the session that created it. Review V$SQL for any queries already executed via the link (SQL_TEXT containing the @link_name syntax).',
    'high', true,
    'AUD-014-RC04: Restrict CREATE DATABASE LINK and audit link creation - Oracle', 'remediate',
    'Revoke CREATE DATABASE LINK and CREATE PUBLIC DATABASE LINK from application accounts. Restrict to DBA-level accounts only. Use Database Vault command rules requiring dual approval for database link creation. Add Unified Audit policy on CREATE DATABASE LINK and DROP DATABASE LINK commands. Maintain an approved database link inventory.',
    'low', true
  );

-- ============================================================
-- SEC-SQL-AUD-014-RC05  Account unlocked or expiry removed on dormant account
-- ============================================================
  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-014-RC05', 'postgresql',
    'Re-lock dormant account reactivated mid-session - PostgreSQL',
    'aud-014-rc05-relock-dormant-account-pg',
    'Re-lock the dormant PostgreSQL account that was reactivated by removing the NOLOGIN restriction and investigate whether it was used before detection.',
    'critical',
    'AUD-014-RC05: Re-lock reactivated dormant account - PostgreSQL', 'immediate',
    'Disable login on the dormant account: ALTER ROLE <dormant_account> NOLOGIN. Terminate any sessions already connected as the dormant account: SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = ''<dormant_account>''. Review pg_audit for activity by the account between its reactivation and re-locking.',
    'high', true,
    'AUD-014-RC05: Enforce dormant account policy and alert on unlock events - PostgreSQL', 'remediate',
    'Revoke CREATEROLE from the account that reactivated the dormant role. Implement a scheduled job that identifies roles with NOLOGIN that have been changed to LOGIN and alerts the security team. Add pg_audit alerting on ALTER ROLE ... LOGIN events. Review all currently inactive accounts and verify their login state matches the approved account inventory.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-014-RC05', 'sqlserver',
    'Re-disable dormant login reactivated mid-session - SQL Server',
    'aud-014-rc05-redisable-dormant-login-sqlserver',
    'Re-disable the dormant SQL login that was re-enabled mid-session and investigate whether it was used before detection.',
    'critical',
    'AUD-014-RC05: Re-disable reactivated dormant login - SQL Server', 'immediate',
    'Disable: ALTER LOGIN <dormant_login> DISABLE. Kill any active sessions for the dormant login: KILL <spid>. Review SQL Server Audit for any activity by the login between the ENABLE LOGIN event and now. Check sys.dm_exec_sessions.last_request_start_time for the dormant login.',
    'high', true,
    'AUD-014-RC05: Restrict ALTER ANY LOGIN and monitor dormant account state - SQL Server', 'remediate',
    'Revoke ALTER ANY LOGIN from the login that re-enabled the dormant account. Restrict login enable/disable to sysadmin and securityadmin. Create a SQL Server Audit specification alerting on ALTER_LOGIN ENABLE events for any login in the dormant accounts list. Implement a scheduled Policy-Based Management policy verifying is_disabled = 1 for all accounts in the dormant inventory.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-014-RC05', 'mysql',
    'Re-lock dormant account reactivated mid-session - MySQL',
    'aud-014-rc05-relock-dormant-account-mysql',
    'Re-lock the dormant MySQL account that was unlocked mid-session and investigate its activity before detection.',
    'critical',
    'AUD-014-RC05: Re-lock reactivated dormant MySQL account - MySQL', 'immediate',
    'Lock: ALTER USER ''<dormant_user>''@''<host>'' ACCOUNT LOCK. FLUSH PRIVILEGES. Kill any active sessions: SELECT id FROM information_schema.processlist WHERE user = ''<dormant_user>'' -- then KILL each. Review audit_log for activity by the account between the ACCOUNT UNLOCK event and now.',
    'high', true,
    'AUD-014-RC05: Restrict account unlock privilege and audit reactivation - MySQL', 'remediate',
    'Revoke CREATE USER privilege from the account that unlocked the dormant user if it is not a designated DBA. Enable audit_log to alert on ALTER USER ... ACCOUNT UNLOCK events for any account in the dormant user list. Implement a nightly script checking mysql.user for account_locked = N on accounts that should remain locked and re-locking any unauthorized activations.',
    'low', true
  );

  CALL rootcause.add_resolution_path(
    'SEC-SQL-AUD-014-RC05', 'oracle',
    'Re-lock dormant account reactivated mid-session - Oracle',
    'aud-014-rc05-relock-dormant-account-oracle',
    'Re-lock the dormant Oracle account whose lock or password expiry was removed mid-session and investigate its activity.',
    'critical',
    'AUD-014-RC05: Re-lock and expire reactivated dormant account - Oracle', 'immediate',
    'Lock and expire: ALTER USER <dormant_account> ACCOUNT LOCK PASSWORD EXPIRE. Kill any active sessions: SELECT sid, serial# FROM v$session WHERE username = ''<dormant_account>'' -- then ALTER SYSTEM KILL SESSION for each. Review UNIFIED_AUDIT_TRAIL for any actions taken by the account between its unlock and re-locking.',
    'high', true,
    'AUD-014-RC05: Restrict ALTER USER ACCOUNT UNLOCK and audit dormant account changes - Oracle', 'remediate',
    'Revoke ALTER USER from the account that unlocked the dormant user. Restrict ACCOUNT UNLOCK operations to designated DBA accounts. Use Database Vault to require dual approval before unlocking any account in the dormant account register. Add Unified Audit policy on ALTER USER ... ACCOUNT UNLOCK for all accounts. Maintain a dormant account register and run nightly verification.',
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
