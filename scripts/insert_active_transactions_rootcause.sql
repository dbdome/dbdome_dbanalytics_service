-- =============================================================================
-- Register "Active Transactions" as a rootcause detection
-- Issue: SEC-SQL-ACC-011 (Active Transactions Present)
-- Root Cause: RC01 - Open / in-flight transactions detected
-- Vendors: oracle, sqlserver, postgresql, mysql
--
-- Companion to collection/oracle/active_transactions_oracle.py (the Oracle
-- v$transaction join) and the equivalent collectors for the other vendors.
-- Mirrors the structure of insert_transaction_anomaly_detection.sql:
--   issues -> root_causes -> detection_steps -> detection_paths
--   -> detection_path_steps, plus a monitoring.v_<rc> view.
--
-- Run on: dbanalytics PostgreSQL (port 5444)
-- Idempotent: ON CONFLICT DO NOTHING / guarded path inserts.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Issue
-- ---------------------------------------------------------------------------
INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description)
VALUES (
    'SEC-SQL-ACC-011', 'SEC', 'SQL', 'ACC',
    'Active Transactions Present',
    'active-transactions-present',
    'Sessions are holding open (in-flight) transactions. Surfacing the active transactions - who is running them, against which database, how long they have been open, and the SQL text - is the starting point for spotting long-running / abandoned transactions, blocking, and anomalous or unauthorized activity.'
)
ON CONFLICT (issue_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. Root cause
-- ---------------------------------------------------------------------------
INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'SEC-SQL-ACC-011-RC01', 'SEC-SQL-ACC-011',
    'Open / in-flight transactions detected',
    'open-in-flight-transactions-detected',
    'One or more sessions currently hold an open transaction. Each row identifies the session, login, host, program, target database, transaction start time, elapsed seconds, CPU and the SQL text so long-running, blocking or suspicious transactions can be triaged.',
    ARRAY['transactions','monitoring','blocking','anomaly-detection'],
    ARRAY['oracle','sqlserver','postgresql','mysql']
)
ON CONFLICT (root_cause_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. Detection steps + paths per vendor
-- ---------------------------------------------------------------------------

-- ======================= oracle =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('oracle', 'sql_query',
        'Retrieve active transactions (v$transaction join v$session)',
        $body${"sql": "SELECT sys_context('USERENV','SERVER_HOST') AS server, sys_context('USERENV','DB_NAME') AS database_name, s.sid AS session_id, s.blocking_session AS blocking_session, ROUND((SYSDATE - TO_DATE(t.start_time,'MM/DD/RR HH24:MI:SS')) * 86400) AS duration_secs, TO_DATE(t.start_time,'MM/DD/RR HH24:MI:SS') AS start_time, s.username AS login_name, s.program AS program, s.machine AS host_name, s.command AS command, s.last_call_et AS last_call_et, ROUND(NVL(q.cpu_time, 0) / 1000) AS cpu_time, (t.xidusn || '.' || t.xidslot || '.' || t.xidsqn) AS transaction_id, REPLACE(REPLACE(REPLACE(DBMS_LOB.SUBSTR(q.sql_fulltext, 4000, 1), CHR(0), ''), CHR(13), ' '), CHR(10), ' ') AS query_text FROM v$transaction t JOIN v$session s ON s.taddr = t.addr LEFT JOIN v$sql q ON q.sql_id = s.sql_id AND q.child_number = s.sql_child_number WHERE s.type = 'USER'"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Active (open) transactions found - review login_name, duration_secs and query_text", "severity": "medium"}$body$::jsonb
    )
    ON CONFLICT (vendor_slug, name) DO UPDATE
        SET content = EXCLUDED.content, expected = EXCLUDED.expected, step_type = EXCLUDED.step_type
    RETURNING id INTO v_step1_id;

    IF NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
                   WHERE root_cause_id = 'SEC-SQL-ACC-011-RC01' AND vendor_slug = 'oracle') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('SEC-SQL-ACC-011-RC01', 'oracle',
            'Detect open / in-flight transactions (oracle)',
            'Detection path for Open / in-flight transactions detected on oracle',
            'primary', true
        ) RETURNING id INTO v_path_id;

        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
    END IF;
END $$;

-- ======================= sqlserver =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('sqlserver', 'sql_query',
        'Retrieve active transactions (dm_tran_active_transactions)',
        $body${"sql": "SELECT @@SERVERNAME AS server, s.session_id AS session_id, r.blocking_session_id AS blocking_session_id, DATEDIFF(SECOND, s.last_request_start_time, GETDATE()) AS duration_secs, DB_NAME(s.database_id) AS database_name, s.last_request_start_time AS start_time, s.open_transaction_count AS open_transaction_count, s.cpu_time AS cpu_time, r.command AS command, s.login_name AS login_name, s.program_name AS program_name, s.host_name AS host_name, SUBSTRING(t.text, 1, 4000) AS query FROM sys.dm_exec_sessions s INNER JOIN sys.dm_tran_session_transactions tst ON s.session_id = tst.session_id INNER JOIN sys.dm_tran_active_transactions at ON tst.transaction_id = at.transaction_id LEFT JOIN sys.dm_exec_requests r ON s.session_id = r.session_id OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE s.is_user_process = 1"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Active (open) transactions found - review login_name, duration_secs and query", "severity": "medium"}$body$::jsonb
    )
    ON CONFLICT (vendor_slug, name) DO UPDATE
        SET content = EXCLUDED.content, expected = EXCLUDED.expected, step_type = EXCLUDED.step_type
    RETURNING id INTO v_step1_id;

    IF NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
                   WHERE root_cause_id = 'SEC-SQL-ACC-011-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('SEC-SQL-ACC-011-RC01', 'sqlserver',
            'Detect open / in-flight transactions (sqlserver)',
            'Detection path for Open / in-flight transactions detected on sqlserver',
            'primary', true
        ) RETURNING id INTO v_path_id;

        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
    END IF;
END $$;

-- ======================= postgresql =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('postgresql', 'sql_query',
        'Retrieve active transactions (pg_stat_activity)',
        $body${"sql": "SELECT usename AS login_name, datname AS database_name, pid AS session_id, client_addr AS host_name, application_name AS program_name, xact_start AS start_time, EXTRACT(EPOCH FROM (now() - xact_start))::int AS duration_secs, state, wait_event_type, wait_event, LEFT(query, 4000) AS query FROM pg_stat_activity WHERE xact_start IS NOT NULL AND pid <> pg_backend_pid() ORDER BY xact_start"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Active (open) transactions found - review login_name, duration_secs and query", "severity": "medium"}$body$::jsonb
    )
    ON CONFLICT (vendor_slug, name) DO UPDATE
        SET content = EXCLUDED.content, expected = EXCLUDED.expected, step_type = EXCLUDED.step_type
    RETURNING id INTO v_step1_id;

    IF NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
                   WHERE root_cause_id = 'SEC-SQL-ACC-011-RC01' AND vendor_slug = 'postgresql') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('SEC-SQL-ACC-011-RC01', 'postgresql',
            'Detect open / in-flight transactions (postgresql)',
            'Detection path for Open / in-flight transactions detected on postgresql',
            'primary', true
        ) RETURNING id INTO v_path_id;

        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
    END IF;
END $$;

-- ======================= mysql =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('mysql', 'sql_query',
        'Retrieve active transactions (information_schema.innodb_trx)',
        $body${"sql": "SELECT trx.trx_id AS transaction_id, trx.trx_mysql_thread_id AS session_id, p.user AS login_name, p.host AS host_name, p.db AS database_name, trx.trx_started AS start_time, TIMESTAMPDIFF(SECOND, trx.trx_started, NOW()) AS duration_secs, trx.trx_state, trx.trx_rows_locked, trx.trx_rows_modified, LEFT(trx.trx_query, 4000) AS query FROM information_schema.innodb_trx trx LEFT JOIN information_schema.processlist p ON trx.trx_mysql_thread_id = p.id ORDER BY trx.trx_started"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Active (open) transactions found - review login_name, duration_secs and query", "severity": "medium"}$body$::jsonb
    )
    ON CONFLICT (vendor_slug, name) DO UPDATE
        SET content = EXCLUDED.content, expected = EXCLUDED.expected, step_type = EXCLUDED.step_type
    RETURNING id INTO v_step1_id;

    IF NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
                   WHERE root_cause_id = 'SEC-SQL-ACC-011-RC01' AND vendor_slug = 'mysql') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('SEC-SQL-ACC-011-RC01', 'mysql',
            'Detect open / in-flight transactions (mysql)',
            'Detection path for Open / in-flight transactions detected on mysql',
            'primary', true
        ) RETURNING id INTO v_path_id;

        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 4. Monitoring view (expands metric_metadata captured under this root cause)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW monitoring.v_sec_sql_acc_011_rc01 AS
SELECT r.server,
    (j.value ->> 'session_id')      AS session_id,
    (j.value ->> 'login_name')      AS login_name,
    (j.value ->> 'host_name')       AS host_name,
    (j.value ->> 'database_name')   AS database_name,
    (j.value ->> 'start_time')      AS start_time,
    (j.value ->> 'duration_secs')   AS duration_secs,
    (j.value ->> 'query')           AS query,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'SEC-SQL-ACC-011-RC01';

-- ---------------------------------------------------------------------------
-- 5. Verify
-- ---------------------------------------------------------------------------
SELECT root_cause_id, name, vendors_applicable
FROM rootcause.root_causes
WHERE root_cause_id = 'SEC-SQL-ACC-011-RC01';

SELECT dp.vendor_slug, dp.name AS path_name, ds.name AS step_name
FROM rootcause.detection_paths dp
JOIN rootcause.detection_path_steps dps ON dps.detection_path_id = dp.id
JOIN rootcause.detection_steps ds ON ds.id = dps.detection_step_id
WHERE dp.root_cause_id = 'SEC-SQL-ACC-011-RC01'
ORDER BY dp.vendor_slug;

COMMIT;
