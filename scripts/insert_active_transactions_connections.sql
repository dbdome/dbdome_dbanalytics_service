-- Insert active transactions and active connections monitoring
-- Issues: PERF-SQL-TX-010 (Active Transactions), PERF-SQL-CN-010 (Active Connections)
-- Root causes with detection queries for all 4 vendors

BEGIN;

-- =========================================================================
-- 1. Issues
-- =========================================================================
INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description)
VALUES (
    'PERF-SQL-TX-010', 'PERF', 'SQL', 'TX',
    'Active Transactions Monitoring',
    'active-transactions-monitoring',
    'Retrieves all currently running transactions with login, program, database, query text, and duration. Provides baseline visibility into what is executing on the server at any point in time.'
)
ON CONFLICT (issue_id) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description)
VALUES (
    'PERF-SQL-CN-010', 'PERF', 'SQL', 'CN',
    'Active Connections Monitoring',
    'active-connections-monitoring',
    'Retrieves all current database connections with login, host, program, status, and connection time. Provides baseline visibility into who is connected to the server.'
)
ON CONFLICT (issue_id) DO NOTHING;

-- =========================================================================
-- 2. Root Causes — Active Transactions
-- =========================================================================
INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES ('PERF-SQL-TX-010-RC01', 'PERF-SQL-TX-010',
    'Active transactions snapshot',
    'active-transactions-snapshot',
    'Point-in-time snapshot of all running transactions showing login_name, program_name, database_name, host_name, elapsed time, wait type, and query text. Used as baseline for anomaly detection and performance monitoring.',
    ARRAY['performance','monitoring','transactions','baseline'],
    ARRAY['sqlserver','postgresql','oracle','mysql'])
ON CONFLICT (root_cause_id) DO NOTHING;

-- =========================================================================
-- 3. Root Causes — Active Connections
-- =========================================================================
INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES ('PERF-SQL-CN-010-RC01', 'PERF-SQL-CN-010',
    'Active connections snapshot',
    'active-connections-snapshot',
    'Point-in-time snapshot of all database connections showing login_name, host_name, program_name, database_name, connection status, and connect time. Used as baseline for connection monitoring and anomaly detection.',
    ARRAY['performance','monitoring','connections','baseline'],
    ARRAY['sqlserver','postgresql','oracle','mysql'])
ON CONFLICT (root_cause_id) DO NOTHING;

-- =========================================================================
-- 4. Detection Steps + Paths — Active Transactions per vendor
-- =========================================================================

-- SQL Server — Active Transactions
DO $$
DECLARE v_path_id int; v_step_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('sqlserver', 'sql_query', 'Retrieve all active transactions',
        $body${"sql": "SELECT s.session_id, s.login_name, s.host_name, s.program_name, DB_NAME(r.database_id) AS database_name, r.status, r.command, r.wait_type, r.wait_time, r.total_elapsed_time / 1000 AS elapsed_sec, r.cpu_time, r.reads, r.writes, r.row_count, SUBSTRING(t.text, (r.statement_start_offset/2)+1, ((CASE r.statement_end_offset WHEN -1 THEN DATALENGTH(t.text) ELSE r.statement_end_offset END - r.statement_start_offset)/2)+1) AS query_text FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE s.is_user_process = 1 ORDER BY r.total_elapsed_time DESC"}$body$::jsonb,
        $body${"condition": "row_count >= 0", "description": "Snapshot of all currently running transactions", "severity": "low"}$body$::jsonb
    ) RETURNING id INTO v_step_id;
    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('PERF-SQL-TX-010-RC01', 'sqlserver', 'Active transactions snapshot (sqlserver)', 'Retrieves all running transactions on SQL Server', 'primary', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
END $$;

-- PostgreSQL — Active Transactions
DO $$
DECLARE v_path_id int; v_step_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('postgresql', 'sql_query', 'Retrieve all active transactions',
        $body${"sql": "SELECT pid, usename AS login_name, client_addr AS host_name, application_name AS program_name, datname AS database_name, state, wait_event_type, wait_event, EXTRACT(EPOCH FROM (now() - xact_start))::int AS elapsed_sec, EXTRACT(EPOCH FROM (now() - query_start))::int AS query_elapsed_sec, LEFT(query, 1000) AS query_text FROM pg_stat_activity WHERE state != 'idle' AND pid != pg_backend_pid() ORDER BY xact_start NULLS LAST"}$body$::jsonb,
        $body${"condition": "row_count >= 0", "description": "Snapshot of all currently running transactions", "severity": "low"}$body$::jsonb
    ) RETURNING id INTO v_step_id;
    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('PERF-SQL-TX-010-RC01', 'postgresql', 'Active transactions snapshot (postgresql)', 'Retrieves all running transactions on PostgreSQL', 'primary', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
END $$;

-- Oracle — Active Transactions
DO $$
DECLARE v_path_id int; v_step_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('oracle', 'sql_query', 'Retrieve all active transactions',
        $body${"sql": "SELECT s.sid, s.serial#, s.username AS login_name, s.machine AS host_name, s.program AS program_name, s.schemaname AS database_name, s.status, s.state, s.event AS wait_event, s.last_call_et AS elapsed_sec, s.sql_id, SUBSTR(q.sql_text, 1, 1000) AS query_text FROM v$session s LEFT JOIN v$sql q ON s.sql_id = q.sql_id AND s.sql_child_number = q.child_number WHERE s.type = 'USER' AND s.status = 'ACTIVE' ORDER BY s.last_call_et DESC"}$body$::jsonb,
        $body${"condition": "row_count >= 0", "description": "Snapshot of all currently running transactions", "severity": "low"}$body$::jsonb
    ) RETURNING id INTO v_step_id;
    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('PERF-SQL-TX-010-RC01', 'oracle', 'Active transactions snapshot (oracle)', 'Retrieves all running transactions on Oracle', 'primary', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
END $$;

-- MySQL — Active Transactions
DO $$
DECLARE v_path_id int; v_step_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('mysql', 'sql_query', 'Retrieve all active transactions',
        $body${"sql": "SELECT ID AS session_id, USER AS login_name, HOST AS host_name, DB AS database_name, COMMAND, STATE AS wait_event, TIME AS elapsed_sec, LEFT(INFO, 1000) AS query_text FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep' AND COMMAND != 'Daemon' AND ID != CONNECTION_ID() ORDER BY TIME DESC"}$body$::jsonb,
        $body${"condition": "row_count >= 0", "description": "Snapshot of all currently running transactions", "severity": "low"}$body$::jsonb
    ) RETURNING id INTO v_step_id;
    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('PERF-SQL-TX-010-RC01', 'mysql', 'Active transactions snapshot (mysql)', 'Retrieves all running transactions on MySQL', 'primary', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
END $$;

-- =========================================================================
-- 5. Detection Steps + Paths — Active Connections per vendor
-- =========================================================================

-- SQL Server — Active Connections
DO $$
DECLARE v_path_id int; v_step_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('sqlserver', 'sql_query', 'Retrieve all active connections',
        $body${"sql": "SELECT s.session_id, s.login_name, s.host_name, s.program_name, DB_NAME(s.database_id) AS database_name, s.status, s.login_time, DATEDIFF(SECOND, s.login_time, GETDATE()) AS connected_sec, s.cpu_time, s.memory_usage, s.reads, s.writes, s.last_request_start_time, s.last_request_end_time, c.client_net_address, c.auth_scheme FROM sys.dm_exec_sessions s LEFT JOIN sys.dm_exec_connections c ON s.session_id = c.session_id WHERE s.is_user_process = 1 ORDER BY s.login_time"}$body$::jsonb,
        $body${"condition": "row_count >= 0", "description": "Snapshot of all current database connections", "severity": "low"}$body$::jsonb
    ) RETURNING id INTO v_step_id;
    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('PERF-SQL-CN-010-RC01', 'sqlserver', 'Active connections snapshot (sqlserver)', 'Retrieves all current connections on SQL Server', 'primary', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
END $$;

-- PostgreSQL — Active Connections
DO $$
DECLARE v_path_id int; v_step_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('postgresql', 'sql_query', 'Retrieve all active connections',
        $body${"sql": "SELECT pid, usename AS login_name, client_addr AS host_name, client_port, application_name AS program_name, datname AS database_name, state, backend_start, EXTRACT(EPOCH FROM (now() - backend_start))::int AS connected_sec, wait_event_type, wait_event, backend_type FROM pg_stat_activity WHERE pid != pg_backend_pid() ORDER BY backend_start"}$body$::jsonb,
        $body${"condition": "row_count >= 0", "description": "Snapshot of all current database connections", "severity": "low"}$body$::jsonb
    ) RETURNING id INTO v_step_id;
    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('PERF-SQL-CN-010-RC01', 'postgresql', 'Active connections snapshot (postgresql)', 'Retrieves all current connections on PostgreSQL', 'primary', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
END $$;

-- Oracle — Active Connections
DO $$
DECLARE v_path_id int; v_step_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('oracle', 'sql_query', 'Retrieve all active connections',
        $body${"sql": "SELECT s.sid, s.serial#, s.username AS login_name, s.machine AS host_name, s.program AS program_name, s.schemaname AS database_name, s.status, s.state, s.logon_time, ROUND((SYSDATE - s.logon_time) * 86400) AS connected_sec, s.server, s.osuser, s.process, s.port FROM v$session s WHERE s.type = 'USER' ORDER BY s.logon_time"}$body$::jsonb,
        $body${"condition": "row_count >= 0", "description": "Snapshot of all current database connections", "severity": "low"}$body$::jsonb
    ) RETURNING id INTO v_step_id;
    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('PERF-SQL-CN-010-RC01', 'oracle', 'Active connections snapshot (oracle)', 'Retrieves all current connections on Oracle', 'primary', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
END $$;

-- MySQL — Active Connections
DO $$
DECLARE v_path_id int; v_step_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('mysql', 'sql_query', 'Retrieve all active connections',
        $body${"sql": "SELECT ID AS session_id, USER AS login_name, HOST AS host_name, DB AS database_name, COMMAND, STATE, TIME AS elapsed_sec, LEFT(INFO, 500) AS query_text FROM information_schema.PROCESSLIST WHERE ID != CONNECTION_ID() ORDER BY TIME DESC"}$body$::jsonb,
        $body${"condition": "row_count >= 0", "description": "Snapshot of all current database connections", "severity": "low"}$body$::jsonb
    ) RETURNING id INTO v_step_id;
    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('PERF-SQL-CN-010-RC01', 'mysql', 'Active connections snapshot (mysql)', 'Retrieves all current connections on MySQL', 'primary', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
END $$;

-- =========================================================================
-- 6. Resolution Paths + Steps — Active Transactions (all vendors)
-- =========================================================================

-- SQL Server
DO $$
DECLARE v_path_id int; v_s1 int; v_s2 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('sqlserver', 'investigate', 'Review long-running transactions and identify blockers',
        $body${"sql": "SELECT s.session_id, s.login_name, s.host_name, s.program_name, DB_NAME(r.database_id) AS database_name, r.status, r.command, r.wait_type, r.blocking_session_id, r.total_elapsed_time / 1000 AS elapsed_sec, SUBSTRING(t.text, 1, 500) AS query_text FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE s.is_user_process = 1 AND r.total_elapsed_time > 30000 ORDER BY r.total_elapsed_time DESC", "description": "Identify transactions running longer than 30 seconds. Check for blocking chains via blocking_session_id."}$body$::jsonb,
        'low', false, true, '5 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('sqlserver', 'instruct', 'Kill problematic long-running transactions',
        $body${"sql": "KILL {session_id};", "parameters": ["session_id"], "description": "Kill specific long-running or blocking transactions. Use KILL {session_id} WITH STATUSONLY to check rollback progress first."}$body$::jsonb,
        'high', true, false, '2 minutes')
    RETURNING id INTO v_s2;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('PERF-SQL-TX-010-RC01', 'sqlserver', 'Review and manage active transactions', 'manage-active-tx-sqlserver',
        'Identify long-running transactions and kill if necessary', 'semi_automatic', 'medium', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'next', 'stop');
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s2, 2, 'done', 'stop');
END $$;

-- PostgreSQL
DO $$
DECLARE v_path_id int; v_s1 int; v_s2 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('postgresql', 'investigate', 'Review long-running transactions and locks',
        $body${"sql": "SELECT pid, usename, datname, state, wait_event_type, wait_event, EXTRACT(EPOCH FROM (now() - xact_start))::int AS tx_elapsed_sec, EXTRACT(EPOCH FROM (now() - query_start))::int AS query_elapsed_sec, LEFT(query, 500) AS query_text FROM pg_stat_activity WHERE state != 'idle' AND pid != pg_backend_pid() AND xact_start < now() - interval '30 seconds' ORDER BY xact_start", "description": "Identify transactions running longer than 30 seconds. Check pg_locks for blocking."}$body$::jsonb,
        'low', false, true, '5 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('postgresql', 'instruct', 'Cancel or terminate problematic transactions',
        $body${"sql": "SELECT pg_cancel_backend({pid}); -- graceful cancel\n-- or: SELECT pg_terminate_backend({pid}); -- force kill", "parameters": ["pid"], "description": "Use pg_cancel_backend for graceful cancel, pg_terminate_backend to force kill. Cancel is preferred as it allows cleanup."}$body$::jsonb,
        'high', true, false, '2 minutes')
    RETURNING id INTO v_s2;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('PERF-SQL-TX-010-RC01', 'postgresql', 'Review and manage active transactions', 'manage-active-tx-postgresql',
        'Identify long-running transactions and cancel if necessary', 'semi_automatic', 'medium', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'next', 'stop');
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s2, 2, 'done', 'stop');
END $$;

-- Oracle
DO $$
DECLARE v_path_id int; v_s1 int; v_s2 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('oracle', 'investigate', 'Review long-running transactions and locks',
        $body${"sql": "SELECT s.sid, s.serial#, s.username, s.machine, s.program, s.schemaname, s.status, s.last_call_et AS elapsed_sec, s.blocking_session, SUBSTR(q.sql_text, 1, 500) AS query_text FROM v$session s LEFT JOIN v$sql q ON s.sql_id = q.sql_id AND s.sql_child_number = q.child_number WHERE s.type = 'USER' AND s.status = 'ACTIVE' AND s.last_call_et > 30 ORDER BY s.last_call_et DESC", "description": "Identify transactions active for more than 30 seconds. Check blocking_session for lock chains."}$body$::jsonb,
        'low', false, true, '5 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('oracle', 'instruct', 'Kill problematic sessions',
        $body${"sql": "ALTER SYSTEM KILL SESSION '{sid},{serial}' IMMEDIATE;", "parameters": ["sid", "serial"], "description": "Kill the long-running session. IMMEDIATE forces rollback without waiting. Check v$transaction for rollback progress."}$body$::jsonb,
        'high', true, false, '2 minutes')
    RETURNING id INTO v_s2;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('PERF-SQL-TX-010-RC01', 'oracle', 'Review and manage active transactions', 'manage-active-tx-oracle',
        'Identify long-running transactions and kill if necessary', 'semi_automatic', 'medium', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'next', 'stop');
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s2, 2, 'done', 'stop');
END $$;

-- MySQL
DO $$
DECLARE v_path_id int; v_s1 int; v_s2 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('mysql', 'investigate', 'Review long-running transactions',
        $body${"sql": "SELECT ID, USER, HOST, DB, COMMAND, STATE, TIME AS elapsed_sec, LEFT(INFO, 500) AS query_text FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep' AND COMMAND != 'Daemon' AND ID != CONNECTION_ID() AND TIME > 30 ORDER BY TIME DESC", "description": "Identify transactions running longer than 30 seconds."}$body$::jsonb,
        'low', false, true, '5 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('mysql', 'instruct', 'Kill problematic transactions',
        $body${"sql": "KILL {process_id};", "parameters": ["process_id"], "description": "Kill the long-running process. InnoDB will automatically rollback uncommitted changes."}$body$::jsonb,
        'high', true, false, '2 minutes')
    RETURNING id INTO v_s2;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('PERF-SQL-TX-010-RC01', 'mysql', 'Review and manage active transactions', 'manage-active-tx-mysql',
        'Identify long-running transactions and kill if necessary', 'semi_automatic', 'medium', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'next', 'stop');
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s2, 2, 'done', 'stop');
END $$;

-- =========================================================================
-- 7. Resolution Paths + Steps — Active Connections (all vendors)
-- =========================================================================

-- SQL Server
DO $$
DECLARE v_path_id int; v_s1 int; v_s2 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('sqlserver', 'investigate', 'Review connections and identify idle/orphaned sessions',
        $body${"sql": "SELECT s.session_id, s.login_name, s.host_name, s.program_name, DB_NAME(s.database_id) AS database_name, s.status, s.login_time, DATEDIFF(MINUTE, s.last_request_end_time, GETDATE()) AS idle_minutes, s.open_transaction_count FROM sys.dm_exec_sessions s WHERE s.is_user_process = 1 ORDER BY s.last_request_end_time", "description": "Identify idle connections, orphaned sessions with open transactions, and connections consuming resources."}$body$::jsonb,
        'low', false, true, '5 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('sqlserver', 'instruct', 'Kill idle/orphaned connections',
        $body${"sql": "KILL {session_id};", "parameters": ["session_id"], "description": "Kill orphaned or idle connections holding resources. Consider configuring remote query timeout to auto-close idle sessions."}$body$::jsonb,
        'medium', true, false, '2 minutes')
    RETURNING id INTO v_s2;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('PERF-SQL-CN-010-RC01', 'sqlserver', 'Review and manage active connections', 'manage-connections-sqlserver',
        'Identify idle/orphaned connections and clean up', 'semi_automatic', 'medium', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'next', 'stop');
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s2, 2, 'done', 'stop');
END $$;

-- PostgreSQL
DO $$
DECLARE v_path_id int; v_s1 int; v_s2 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('postgresql', 'investigate', 'Review connections and identify idle/orphaned sessions',
        $body${"sql": "SELECT pid, usename, datname, client_addr, application_name, state, backend_start, EXTRACT(EPOCH FROM (now() - state_change))::int AS idle_sec, wait_event_type, wait_event FROM pg_stat_activity WHERE pid != pg_backend_pid() AND state = 'idle' AND state_change < now() - interval '30 minutes' ORDER BY state_change", "description": "Identify connections idle for more than 30 minutes. Check for idle in transaction states."}$body$::jsonb,
        'low', false, true, '5 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('postgresql', 'instruct', 'Terminate idle connections and configure timeouts',
        $body${"sql": "SELECT pg_terminate_backend({pid});", "parameters": ["pid"], "description": "Terminate idle connections. Configure idle_in_transaction_session_timeout and idle_session_timeout in postgresql.conf to auto-close idle sessions."}$body$::jsonb,
        'medium', true, false, '5 minutes')
    RETURNING id INTO v_s2;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('PERF-SQL-CN-010-RC01', 'postgresql', 'Review and manage active connections', 'manage-connections-postgresql',
        'Identify idle connections and configure timeouts', 'semi_automatic', 'medium', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'next', 'stop');
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s2, 2, 'done', 'stop');
END $$;

-- Oracle
DO $$
DECLARE v_path_id int; v_s1 int; v_s2 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('oracle', 'investigate', 'Review connections and identify inactive sessions',
        $body${"sql": "SELECT s.sid, s.serial#, s.username, s.machine, s.program, s.schemaname, s.status, s.logon_time, s.last_call_et AS inactive_sec FROM v$session s WHERE s.type = 'USER' AND s.status = 'INACTIVE' AND s.last_call_et > 1800 ORDER BY s.last_call_et DESC", "description": "Identify sessions inactive for more than 30 minutes. Check for sessions holding locks."}$body$::jsonb,
        'low', false, true, '5 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('oracle', 'instruct', 'Kill inactive sessions and configure resource limits',
        $body${"sql": "ALTER SYSTEM KILL SESSION '{sid},{serial}' IMMEDIATE;", "parameters": ["sid", "serial"], "description": "Kill inactive sessions. Configure Oracle profiles with IDLE_TIME limit to auto-disconnect idle sessions."}$body$::jsonb,
        'medium', true, false, '2 minutes')
    RETURNING id INTO v_s2;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('PERF-SQL-CN-010-RC01', 'oracle', 'Review and manage active connections', 'manage-connections-oracle',
        'Identify inactive connections and configure resource limits', 'semi_automatic', 'medium', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'next', 'stop');
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s2, 2, 'done', 'stop');
END $$;

-- MySQL
DO $$
DECLARE v_path_id int; v_s1 int; v_s2 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('mysql', 'investigate', 'Review connections and identify idle sessions',
        $body${"sql": "SELECT ID, USER, HOST, DB, COMMAND, STATE, TIME AS idle_sec, LEFT(INFO, 200) AS last_query FROM information_schema.PROCESSLIST WHERE COMMAND = 'Sleep' AND TIME > 1800 AND ID != CONNECTION_ID() ORDER BY TIME DESC", "description": "Identify connections sleeping for more than 30 minutes."}$body$::jsonb,
        'low', false, true, '5 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('mysql', 'instruct', 'Kill idle connections and configure wait_timeout',
        $body${"sql": "KILL {process_id};", "parameters": ["process_id"], "description": "Kill idle connections. Configure wait_timeout and interactive_timeout in my.cnf to auto-close idle sessions (default 28800s = 8 hours, consider reducing to 3600)."}$body$::jsonb,
        'medium', true, false, '5 minutes')
    RETURNING id INTO v_s2;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('PERF-SQL-CN-010-RC01', 'mysql', 'Review and manage active connections', 'manage-connections-mysql',
        'Identify idle connections and configure timeouts', 'semi_automatic', 'medium', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'next', 'stop');
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s2, 2, 'done', 'stop');
END $$;

COMMIT;
