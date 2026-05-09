-- =============================================================================
-- Insert Transaction Anomaly Detection Data into rootcause schema
-- Issue: SEC-SQL-ACC-010 (Anomalous Transaction Activity)
-- Root Causes: RC01-RC13
-- Vendors: sqlserver, postgresql, oracle, mysql
--
-- Generated from: insert_transaction_anomaly_detection.py
-- Each vendor+RC combination inserts detection_steps, detection_paths,
-- and detection_path_steps in a DO $$ block with captured IDs.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Insert the issue
-- ---------------------------------------------------------------------------
INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description)
VALUES (
    'SEC-SQL-ACC-010', 'SEC', 'SQL', 'ACC',
    'Anomalous Transaction Activity',
    'anomalous-transaction-activity',
    'Running transactions show unusual patterns compared to expected baseline - unknown logins, unexpected programs, unusual databases, or suspicious query patterns that may indicate unauthorized access or compromised accounts.'
)
ON CONFLICT (issue_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. Insert all 13 root causes
-- ---------------------------------------------------------------------------
INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'SEC-SQL-ACC-010-RC01', 'SEC-SQL-ACC-010',
    'Unknown login executing queries',
    'unknown-login-executing-queries',
    'A login name not in the expected baseline is actively running transactions. This may indicate a newly created unauthorized account, a compromised credential, or a misconfigured application.',
    ARRAY['security','authentication','anomaly-detection'],
    ARRAY['sqlserver','postgresql','oracle','mysql']
)
ON CONFLICT (root_cause_id) DO NOTHING;

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'SEC-SQL-ACC-010-RC02', 'SEC-SQL-ACC-010',
    'Unexpected program or application connected',
    'unexpected-program-or-application-connected',
    'Transactions are being executed by a program/application name not in the expected baseline. This may indicate unauthorized tooling, SQL injection via a web app, or direct database access bypassing application controls.',
    ARRAY['security','application-control','anomaly-detection'],
    ARRAY['sqlserver','postgresql','oracle','mysql']
)
ON CONFLICT (root_cause_id) DO NOTHING;

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'SEC-SQL-ACC-010-RC03', 'SEC-SQL-ACC-010',
    'Query activity on unexpected database',
    'query-activity-on-unexpected-database',
    'Transactions target a database not in the expected baseline. This may indicate lateral movement, data exfiltration attempts, or misconfigured applications accessing the wrong database.',
    ARRAY['security','data-access','anomaly-detection'],
    ARRAY['sqlserver','postgresql','oracle','mysql']
)
ON CONFLICT (root_cause_id) DO NOTHING;

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'SEC-SQL-ACC-010-RC04', 'SEC-SQL-ACC-010',
    'Suspicious query patterns detected',
    'suspicious-query-patterns-detected',
    'Running transactions contain suspicious SQL patterns such as bulk data extraction, schema discovery, privilege escalation attempts, or data modification from unexpected sources.',
    ARRAY['security','sql-injection','anomaly-detection'],
    ARRAY['sqlserver','postgresql','oracle','mysql']
)
ON CONFLICT (root_cause_id) DO NOTHING;

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'SEC-SQL-ACC-010-RC05', 'SEC-SQL-ACC-010',
    'Sensitive data (PII) accessed in active transactions',
    'sensitive-data-(pii)-accessed-in-active-transactions',
    'Active transactions are querying columns identified as containing sensitive/PII data (names, emails, SSN, credit cards, addresses, phone numbers, dates of birth). First identifies PII columns via schema inspection, then checks if any running transaction references those columns or tables.',
    ARRAY['security','data-privacy','PII','anomaly-detection'],
    ARRAY['sqlserver','postgresql','oracle','mysql']
)
ON CONFLICT (root_cause_id) DO NOTHING;

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'SEC-SQL-ACC-010-RC06', 'SEC-SQL-ACC-010',
    'SQL injection patterns in active transactions',
    'sql-injection-patterns-in-active-transactions',
    'Active transactions contain classic SQL injection signatures such as tautology attacks (OR 1=1), UNION-based injection, stacked queries with semicolons, comment-based truncation, time-based blind injection (WAITFOR/SLEEP/BENCHMARK), and error-based extraction attempts.',
    ARRAY['security','sql-injection','anomaly-detection'],
    ARRAY['sqlserver','postgresql','oracle','mysql']
)
ON CONFLICT (root_cause_id) DO NOTHING;

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'SEC-SQL-ACC-010-RC07', 'SEC-SQL-ACC-010',
    'After-hours transaction activity',
    'after-hours-transaction-activity',
    'Transactions are running outside normal business hours (before 06:00 or after 22:00 server local time). After-hours database activity is a common indicator of compromised credentials, insider threats, or unauthorized batch processes.',
    ARRAY['security','after-hours','anomaly-detection'],
    ARRAY['sqlserver','postgresql','oracle','mysql']
)
ON CONFLICT (root_cause_id) DO NOTHING;

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'SEC-SQL-ACC-010-RC08', 'SEC-SQL-ACC-010',
    'Privilege escalation attempts in transactions',
    'privilege-escalation-attempts-in-transactions',
    'Non-admin users are executing DDL or DCL statements (CREATE, ALTER, DROP, GRANT, REVOKE, DENY) that modify database structure or permissions. This may indicate privilege abuse, lateral movement, or a compromised application account attempting escalation.',
    ARRAY['security','privilege-escalation','anomaly-detection'],
    ARRAY['sqlserver','postgresql','oracle','mysql']
)
ON CONFLICT (root_cause_id) DO NOTHING;

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'SEC-SQL-ACC-010-RC09', 'SEC-SQL-ACC-010',
    'Data exfiltration patterns in transactions',
    'data-exfiltration-patterns-in-transactions',
    'Active transactions show patterns consistent with data exfiltration: large result set extractions, bulk export operations (BCP, COPY, INTO OUTFILE), linked server/foreign data wrapper queries, or systematic table-by-table reads indicating data harvesting.',
    ARRAY['security','data-exfiltration','anomaly-detection'],
    ARRAY['sqlserver','postgresql','oracle','mysql']
)
ON CONFLICT (root_cause_id) DO NOTHING;

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'SEC-SQL-ACC-010-RC10', 'SEC-SQL-ACC-010',
    'Same login active from multiple hosts',
    'same-login-active-from-multiple-hosts',
    'A single login name has concurrent active sessions originating from two or more different client hosts. This may indicate credential sharing, stolen credentials being used in parallel, or a brute-force attack that has succeeded.',
    ARRAY['security','credential-compromise','anomaly-detection'],
    ARRAY['sqlserver','postgresql','oracle','mysql']
)
ON CONFLICT (root_cause_id) DO NOTHING;

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'SEC-SQL-ACC-010-RC11', 'SEC-SQL-ACC-010',
    'Schema reconnaissance activity',
    'schema-reconnaissance-activity',
    'Active transactions are querying system catalogs, metadata views, or information_schema tables to enumerate database objects, columns, permissions, or configurations. This is a common first step in database attacks — mapping the target before exploitation.',
    ARRAY['security','reconnaissance','anomaly-detection'],
    ARRAY['sqlserver','postgresql','oracle','mysql']
)
ON CONFLICT (root_cause_id) DO NOTHING;

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'SEC-SQL-ACC-010-RC12', 'SEC-SQL-ACC-010',
    'Dormant account suddenly active',
    'dormant-account-suddenly-active',
    'An account that has had no login activity for an extended period (30+ days) is now executing transactions. Dormant accounts that suddenly become active are high-risk indicators of credential compromise or unauthorized reactivation.',
    ARRAY['security','dormant-account','anomaly-detection'],
    ARRAY['sqlserver','postgresql','oracle','mysql']
)
ON CONFLICT (root_cause_id) DO NOTHING;

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'SEC-SQL-ACC-010-RC13', 'SEC-SQL-ACC-010',
    'Mass data modification in transactions',
    'mass-data-modification-in-transactions',
    'Active transactions are performing bulk UPDATE or DELETE operations affecting a large number of rows. This may indicate ransomware activity, data sabotage, unauthorized data manipulation, or a destructive script running against production.',
    ARRAY['security','data-destruction','anomaly-detection'],
    ARRAY['sqlserver','postgresql','oracle','mysql']
)
ON CONFLICT (root_cause_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. Insert detection steps, paths, and path_steps per vendor+RC
-- ---------------------------------------------------------------------------

-- ======================= sqlserver RC01 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('sqlserver', 'sql_query',
        'Retrieve active transactions with login details',
        $body${"sql": "SELECT s.login_name, s.host_name, s.program_name, DB_NAME(r.database_id) AS database_name, r.status, r.command, r.wait_type, r.total_elapsed_time / 1000 AS elapsed_sec, SUBSTRING(t.text, (r.statement_start_offset/2)+1, ((CASE r.statement_end_offset WHEN -1 THEN DATALENGTH(t.text) ELSE r.statement_end_offset END - r.statement_start_offset)/2)+1) AS query_text FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE s.is_user_process = 1 AND s.login_name NOT IN ('sa','NT AUTHORITY\\SYSTEM','NT SERVICE\\MSSQLSERVER')"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Active user transactions found - check login_name against baseline", "severity": "high"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC01', 'sqlserver',
        'Detect unknown login executing queries (sqlserver)',
        'Detection path for Unknown login executing queries on sqlserver',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= sqlserver RC02 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('sqlserver', 'sql_query',
        'Detect transactions from unexpected programs',
        $body${"sql": "SELECT s.login_name, s.program_name, s.host_name, DB_NAME(r.database_id) AS database_name, COUNT(*) AS active_requests, SUM(r.total_elapsed_time) / 1000 AS total_elapsed_sec FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id WHERE s.is_user_process = 1 GROUP BY s.login_name, s.program_name, s.host_name, DB_NAME(r.database_id) ORDER BY active_requests DESC"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Active programs found - verify program_name against known applications", "severity": "high"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC02', 'sqlserver',
        'Detect unexpected program or application connected (sqlserver)',
        'Detection path for Unexpected program or application connected on sqlserver',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= sqlserver RC03 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('sqlserver', 'sql_query',
        'Detect transactions targeting unexpected databases',
        $body${"sql": "SELECT DISTINCT s.login_name, s.program_name, DB_NAME(r.database_id) AS database_name, COUNT(*) AS request_count FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id WHERE s.is_user_process = 1 AND DB_NAME(r.database_id) NOT IN ('master','tempdb','msdb','model') GROUP BY s.login_name, s.program_name, DB_NAME(r.database_id)"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "User transactions on non-system databases - verify database access is expected", "severity": "medium"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC03', 'sqlserver',
        'Detect query activity on unexpected database (sqlserver)',
        'Detection path for Query activity on unexpected database on sqlserver',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= sqlserver RC04 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('sqlserver', 'sql_query',
        'Detect suspicious query patterns in active transactions',
        $body${"sql": "SELECT s.login_name, s.program_name, s.host_name, DB_NAME(r.database_id) AS database_name, r.total_elapsed_time / 1000 AS elapsed_sec, SUBSTRING(t.text, 1, 500) AS query_text FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE s.is_user_process = 1 AND (t.text LIKE '%xp_cmdshell%' OR t.text LIKE '%OPENROWSET%' OR t.text LIKE '%sp_configure%' OR t.text LIKE '%ALTER LOGIN%' OR t.text LIKE '%CREATE LOGIN%' OR t.text LIKE '%sysadmin%' OR t.text LIKE '%BULK INSERT%' OR t.text LIKE '%information_schema%' OR t.text LIKE '%sysobjects%')"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Suspicious SQL patterns detected in active transactions - potential security threat", "severity": "critical"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC04', 'sqlserver',
        'Detect suspicious query patterns detected (sqlserver)',
        'Detection path for Suspicious query patterns detected on sqlserver',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= sqlserver RC05 (2 steps) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
    v_step2_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('sqlserver', 'sql_query',
        'Identify sensitive (PII) columns in database',
        $body${"sql": "SELECT s.name AS schema_name, t.name AS table_name, c.name AS column_name, ty.name AS data_type FROM sys.columns c JOIN sys.tables t ON c.object_id = t.object_id JOIN sys.schemas s ON t.schema_id = s.schema_id JOIN sys.types ty ON c.user_type_id = ty.user_type_id WHERE s.name NOT IN ('sys','INFORMATION_SCHEMA') AND (LOWER(c.name) LIKE '%ssn%' OR LOWER(c.name) LIKE '%social_sec%' OR LOWER(c.name) LIKE '%national_id%' OR LOWER(c.name) LIKE '%tax_id%' OR LOWER(c.name) LIKE '%passport%' OR LOWER(c.name) LIKE '%credit_card%' OR LOWER(c.name) LIKE '%card_num%' OR LOWER(c.name) LIKE '%cvv%' OR LOWER(c.name) LIKE '%email%' OR LOWER(c.name) LIKE '%phone%' OR LOWER(c.name) LIKE '%mobile%' OR LOWER(c.name) LIKE '%birth_date%' OR LOWER(c.name) LIKE '%dob%' OR LOWER(c.name) LIKE '%date_of_birth%' OR LOWER(c.name) LIKE '%first_name%' OR LOWER(c.name) LIKE '%last_name%' OR LOWER(c.name) LIKE '%full_name%' OR LOWER(c.name) LIKE '%surname%' OR LOWER(c.name) LIKE '%address%' OR LOWER(c.name) LIKE '%salary%' OR LOWER(c.name) LIKE '%income%' OR LOWER(c.name) LIKE '%bank_account%' OR LOWER(c.name) LIKE '%iban%' OR LOWER(c.name) LIKE '%password%' OR LOWER(c.name) LIKE '%secret%') ORDER BY s.name, t.name"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "PII/sensitive columns identified in the database schema", "severity": "medium"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('sqlserver', 'sql_query',
        'Detect active transactions accessing PII tables',
        $body${"sql": "SELECT s.login_name, s.host_name, s.program_name, DB_NAME(r.database_id) AS database_name, r.total_elapsed_time / 1000 AS elapsed_sec, SUBSTRING(t.text, 1, 500) AS query_text FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t JOIN sys.columns c ON 1=1 JOIN sys.tables tbl ON c.object_id = tbl.object_id JOIN sys.schemas sch ON tbl.schema_id = sch.schema_id WHERE s.is_user_process = 1 AND sch.name NOT IN ('sys','INFORMATION_SCHEMA') AND t.text LIKE '%' + tbl.name + '%' AND (LOWER(c.name) LIKE '%ssn%' OR LOWER(c.name) LIKE '%social_sec%' OR LOWER(c.name) LIKE '%credit_card%' OR LOWER(c.name) LIKE '%email%' OR LOWER(c.name) LIKE '%phone%' OR LOWER(c.name) LIKE '%birth_date%' OR LOWER(c.name) LIKE '%first_name%' OR LOWER(c.name) LIKE '%last_name%' OR LOWER(c.name) LIKE '%salary%' OR LOWER(c.name) LIKE '%password%' OR LOWER(c.name) LIKE '%bank_account%')"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Active transactions are accessing tables containing PII/sensitive columns - potential data exposure", "severity": "critical"}$body$::jsonb
    ) RETURNING id INTO v_step2_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC05', 'sqlserver',
        'Detect sensitive data (pii) accessed in active transactions (sqlserver)',
        'Detection path for Sensitive data (PII) accessed in active transactions on sqlserver',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'next', 'ruled_out');
    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step2_id, 2, 'confirmed', 'ruled_out');
END $$;

-- ======================= sqlserver RC06 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('sqlserver', 'sql_query',
        'Detect SQL injection patterns in active transactions',
        $body${"sql": "SELECT s.login_name, s.host_name, s.program_name, DB_NAME(r.database_id) AS database_name, r.total_elapsed_time / 1000 AS elapsed_sec, SUBSTRING(t.text, 1, 500) AS query_text, CASE WHEN t.text LIKE '%OR 1=1%' OR t.text LIKE '%OR ''1''=''1%' THEN 'tautology' WHEN t.text LIKE '%UNION%SELECT%' THEN 'union-based' WHEN t.text LIKE '%;%DROP%' OR t.text LIKE '%;%DELETE%' OR t.text LIKE '%;%INSERT%' THEN 'stacked-query' WHEN t.text LIKE '%--%' AND (t.text LIKE '%''%--' OR t.text LIKE '%OR%--%') THEN 'comment-truncation' WHEN t.text LIKE '%WAITFOR%DELAY%' THEN 'time-based-blind' WHEN t.text LIKE '%CONVERT(int%' OR t.text LIKE '%CAST(%AS%varchar%' THEN 'error-based' ELSE 'other' END AS injection_type FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE s.is_user_process = 1 AND (t.text LIKE '%OR 1=1%' OR t.text LIKE '%OR ''1''=''1%' OR t.text LIKE '%UNION%SELECT%' OR (t.text LIKE '%;%' AND (t.text LIKE '%DROP %' OR t.text LIKE '%DELETE %' OR t.text LIKE '%INSERT %')) OR t.text LIKE '%WAITFOR%DELAY%' OR t.text LIKE '%xp_cmdshell%' OR t.text LIKE '%EXEC(%' OR t.text LIKE '%EXECUTE(%')"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "SQL injection patterns detected in active transactions - active attack in progress", "severity": "critical"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC06', 'sqlserver',
        'Detect sql injection patterns in active transactions (sqlserver)',
        'Detection path for SQL injection patterns in active transactions on sqlserver',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= sqlserver RC07 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('sqlserver', 'sql_query',
        'Detect after-hours transaction activity',
        $body${"sql": "SELECT s.login_name, s.host_name, s.program_name, DB_NAME(r.database_id) AS database_name, r.total_elapsed_time / 1000 AS elapsed_sec, DATEPART(HOUR, GETDATE()) AS current_hour, SUBSTRING(t.text, 1, 500) AS query_text FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE s.is_user_process = 1 AND (DATEPART(HOUR, GETDATE()) < 6 OR DATEPART(HOUR, GETDATE()) >= 22)"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "User transactions running outside business hours (before 06:00 or after 22:00) - potential unauthorized access", "severity": "high"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC07', 'sqlserver',
        'Detect after-hours transaction activity (sqlserver)',
        'Detection path for After-hours transaction activity on sqlserver',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= sqlserver RC08 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('sqlserver', 'sql_query',
        'Detect privilege escalation in active transactions',
        $body${"sql": "SELECT s.login_name, s.host_name, s.program_name, DB_NAME(r.database_id) AS database_name, r.total_elapsed_time / 1000 AS elapsed_sec, SUBSTRING(t.text, 1, 500) AS query_text, CASE WHEN t.text LIKE '%CREATE LOGIN%' OR t.text LIKE '%CREATE USER%' THEN 'create-account' WHEN t.text LIKE '%ALTER LOGIN%' OR t.text LIKE '%ALTER USER%' OR t.text LIKE '%ALTER ROLE%' THEN 'alter-account' WHEN t.text LIKE '%GRANT%' THEN 'grant-privilege' WHEN t.text LIKE '%sp_addsrvrolemember%' OR t.text LIKE '%sp_addrolemember%' THEN 'role-membership' WHEN t.text LIKE '%DROP TABLE%' OR t.text LIKE '%DROP DATABASE%' OR t.text LIKE '%ALTER TABLE%' THEN 'ddl-modification' WHEN t.text LIKE '%DENY%' OR t.text LIKE '%REVOKE%' THEN 'revoke-deny' ELSE 'other-ddl' END AS escalation_type FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE s.is_user_process = 1 AND s.login_name NOT IN ('sa') AND (t.text LIKE '%CREATE LOGIN%' OR t.text LIKE '%CREATE USER%' OR t.text LIKE '%ALTER LOGIN%' OR t.text LIKE '%ALTER USER%' OR t.text LIKE '%ALTER ROLE%' OR t.text LIKE '%GRANT%' OR t.text LIKE '%DENY%' OR t.text LIKE '%REVOKE%' OR t.text LIKE '%sp_addsrvrolemember%' OR t.text LIKE '%sp_addrolemember%' OR t.text LIKE '%DROP TABLE%' OR t.text LIKE '%DROP DATABASE%' OR t.text LIKE '%ALTER TABLE%')"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Non-admin user executing DDL/DCL statements - potential privilege escalation", "severity": "critical"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC08', 'sqlserver',
        'Detect privilege escalation attempts in transactions (sqlserver)',
        'Detection path for Privilege escalation attempts in transactions on sqlserver',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= sqlserver RC09 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('sqlserver', 'sql_query',
        'Detect data exfiltration patterns in transactions',
        $body${"sql": "SELECT s.login_name, s.host_name, s.program_name, DB_NAME(r.database_id) AS database_name, r.total_elapsed_time / 1000 AS elapsed_sec, r.row_count AS rows_affected, r.granted_query_memory * 8 AS memory_kb, SUBSTRING(t.text, 1, 500) AS query_text, CASE WHEN t.text LIKE '%BULK INSERT%' OR t.text LIKE '%bcp%' THEN 'bulk-export' WHEN t.text LIKE '%OPENROWSET%' OR t.text LIKE '%OPENDATASOURCE%' OR t.text LIKE '%OPENQUERY%' THEN 'linked-server' WHEN t.text LIKE '%INTO%FROM%' AND t.text LIKE '%SELECT%*%' THEN 'select-into' WHEN r.row_count > 10000 THEN 'large-result-set' ELSE 'other' END AS exfil_type FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE s.is_user_process = 1 AND (r.row_count > 10000 OR t.text LIKE '%BULK INSERT%' OR t.text LIKE '%bcp%' OR t.text LIKE '%OPENROWSET%' OR t.text LIKE '%OPENDATASOURCE%' OR t.text LIKE '%OPENQUERY%' OR (t.text LIKE '%SELECT%*%FROM%' AND r.granted_query_memory * 8 > 50000))"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Data exfiltration patterns detected - bulk export, linked server access, or large data extraction", "severity": "critical"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC09', 'sqlserver',
        'Detect data exfiltration patterns in transactions (sqlserver)',
        'Detection path for Data exfiltration patterns in transactions on sqlserver',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= sqlserver RC10 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('sqlserver', 'sql_query',
        'Detect same login active from multiple hosts',
        $body${"sql": "SELECT s.login_name, COUNT(DISTINCT s.host_name) AS distinct_hosts, STRING_AGG(DISTINCT s.host_name, ', ') AS hosts, COUNT(*) AS total_sessions FROM sys.dm_exec_sessions s WHERE s.is_user_process = 1 AND s.status = 'running' GROUP BY s.login_name HAVING COUNT(DISTINCT s.host_name) > 1"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Same login has concurrent sessions from multiple hosts - possible credential compromise", "severity": "high"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC10', 'sqlserver',
        'Detect same login active from multiple hosts (sqlserver)',
        'Detection path for Same login active from multiple hosts on sqlserver',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= sqlserver RC11 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('sqlserver', 'sql_query',
        'Detect schema reconnaissance in active transactions',
        $body${"sql": "SELECT s.login_name, s.host_name, s.program_name, DB_NAME(r.database_id) AS database_name, r.total_elapsed_time / 1000 AS elapsed_sec, SUBSTRING(t.text, 1, 500) AS query_text, CASE WHEN t.text LIKE '%sys.objects%' OR t.text LIKE '%sysobjects%' THEN 'object-enumeration' WHEN t.text LIKE '%sys.columns%' OR t.text LIKE '%syscolumns%' THEN 'column-enumeration' WHEN t.text LIKE '%sys.server_principals%' OR t.text LIKE '%sys.database_principals%' THEN 'principal-enumeration' WHEN t.text LIKE '%sys.server_permissions%' OR t.text LIKE '%sys.database_permissions%' THEN 'permission-enumeration' WHEN t.text LIKE '%INFORMATION_SCHEMA%' THEN 'information-schema' WHEN t.text LIKE '%sys.configurations%' OR t.text LIKE '%sp_configure%' THEN 'config-enumeration' ELSE 'other-recon' END AS recon_type FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE s.is_user_process = 1 AND (t.text LIKE '%sys.objects%' OR t.text LIKE '%sysobjects%' OR t.text LIKE '%sys.columns%' OR t.text LIKE '%syscolumns%' OR t.text LIKE '%sys.server_principals%' OR t.text LIKE '%sys.database_principals%' OR t.text LIKE '%sys.server_permissions%' OR t.text LIKE '%sys.database_permissions%' OR t.text LIKE '%INFORMATION_SCHEMA.TABLES%' OR t.text LIKE '%INFORMATION_SCHEMA.COLUMNS%' OR t.text LIKE '%sys.configurations%' OR t.text LIKE '%sp_configure%')"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Schema reconnaissance detected - user querying system catalogs to enumerate objects, columns, or permissions", "severity": "high"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC11', 'sqlserver',
        'Detect schema reconnaissance activity (sqlserver)',
        'Detection path for Schema reconnaissance activity on sqlserver',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= sqlserver RC12 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('sqlserver', 'sql_query',
        'Detect dormant accounts with active transactions',
        $body${"sql": "SELECT s.login_name, s.host_name, s.program_name, DB_NAME(r.database_id) AS database_name, l.login_time AS session_start, DATEDIFF(DAY, p.modify_date, GETDATE()) AS days_since_last_modification, SUBSTRING(t.text, 1, 500) AS query_text FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t JOIN sys.dm_exec_sessions l ON r.session_id = l.session_id JOIN sys.server_principals p ON s.login_name = p.name WHERE s.is_user_process = 1 AND p.type IN ('S','U') AND DATEDIFF(DAY, p.modify_date, GETDATE()) > 30"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Account not modified in 30+ days is now running transactions - dormant account reactivation", "severity": "high"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC12', 'sqlserver',
        'Detect dormant account suddenly active (sqlserver)',
        'Detection path for Dormant account suddenly active on sqlserver',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= sqlserver RC13 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('sqlserver', 'sql_query',
        'Detect mass data modification in active transactions',
        $body${"sql": "SELECT s.login_name, s.host_name, s.program_name, DB_NAME(r.database_id) AS database_name, r.total_elapsed_time / 1000 AS elapsed_sec, r.row_count AS rows_affected, r.command, SUBSTRING(t.text, 1, 500) AS query_text FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE s.is_user_process = 1 AND r.command IN ('UPDATE','DELETE') AND r.row_count > 1000"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Mass UPDATE/DELETE affecting 1000+ rows in active transaction - potential data destruction or unauthorized modification", "severity": "critical"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC13', 'sqlserver',
        'Detect mass data modification in transactions (sqlserver)',
        'Detection path for Mass data modification in transactions on sqlserver',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= postgresql RC01 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('postgresql', 'sql_query',
        'Retrieve active transactions with login details',
        $body${"sql": "SELECT usename AS login_name, client_addr AS host_name, application_name AS program_name, datname AS database_name, state, wait_event_type, wait_event, EXTRACT(EPOCH FROM (now() - xact_start))::int AS elapsed_sec, LEFT(query, 500) AS query_text FROM pg_stat_activity WHERE state != 'idle' AND usename NOT IN ('postgres','replication') AND pid != pg_backend_pid()"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Active user transactions found - check login_name against baseline", "severity": "high"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC01', 'postgresql',
        'Detect unknown login executing queries (postgresql)',
        'Detection path for Unknown login executing queries on postgresql',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= postgresql RC02 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('postgresql', 'sql_query',
        'Detect transactions from unexpected applications',
        $body${"sql": "SELECT usename AS login_name, application_name AS program_name, client_addr AS host_name, datname AS database_name, COUNT(*) AS active_requests FROM pg_stat_activity WHERE state != 'idle' AND pid != pg_backend_pid() GROUP BY usename, application_name, client_addr, datname ORDER BY active_requests DESC"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Active applications found - verify application_name against known programs", "severity": "high"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC02', 'postgresql',
        'Detect unexpected program or application connected (postgresql)',
        'Detection path for Unexpected program or application connected on postgresql',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= postgresql RC03 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('postgresql', 'sql_query',
        'Detect transactions targeting unexpected databases',
        $body${"sql": "SELECT DISTINCT usename AS login_name, application_name AS program_name, datname AS database_name, COUNT(*) AS request_count FROM pg_stat_activity WHERE state != 'idle' AND pid != pg_backend_pid() AND datname NOT IN ('postgres','template0','template1') GROUP BY usename, application_name, datname"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "User transactions on non-system databases - verify database access is expected", "severity": "medium"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC03', 'postgresql',
        'Detect query activity on unexpected database (postgresql)',
        'Detection path for Query activity on unexpected database on postgresql',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= postgresql RC04 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('postgresql', 'sql_query',
        'Detect suspicious query patterns in active transactions',
        $body${"sql": "SELECT usename AS login_name, application_name AS program_name, client_addr AS host_name, datname AS database_name, EXTRACT(EPOCH FROM (now() - xact_start))::int AS elapsed_sec, LEFT(query, 500) AS query_text FROM pg_stat_activity WHERE state != 'idle' AND pid != pg_backend_pid() AND (query ILIKE '%pg_shadow%' OR query ILIKE '%pg_authid%' OR query ILIKE '%COPY%TO%' OR query ILIKE '%pg_read_file%' OR query ILIKE '%ALTER ROLE%' OR query ILIKE '%CREATE ROLE%' OR query ILIKE '%pg_execute_server_program%' OR query ILIKE '%information_schema%')"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Suspicious SQL patterns detected in active transactions - potential security threat", "severity": "critical"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC04', 'postgresql',
        'Detect suspicious query patterns detected (postgresql)',
        'Detection path for Suspicious query patterns detected on postgresql',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= postgresql RC05 (2 steps) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
    v_step2_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('postgresql', 'sql_query',
        'Identify sensitive (PII) columns in database',
        $body${"sql": "SELECT table_schema, table_name, column_name, data_type FROM information_schema.columns WHERE table_schema NOT IN ('pg_catalog','information_schema') AND (lower(column_name) ~ '(ssn|social_sec|national_id|tax_id|passport|credit_card|card_num|cvv|email|e_mail|phone|mobile|cell|birth_date|dob|date_of_birth|first_name|last_name|full_name|surname|address|street|zip_code|postal|salary|income|wage|bank_account|iban|routing_num|password|pwd|secret)') ORDER BY table_schema, table_name"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "PII/sensitive columns identified in the database schema", "severity": "medium"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('postgresql', 'sql_query',
        'Detect active transactions accessing PII tables',
        $body${"sql": "SELECT a.usename AS login_name, a.client_addr AS host_name, a.application_name AS program_name, a.datname AS database_name, EXTRACT(EPOCH FROM (now() - a.xact_start))::int AS elapsed_sec, LEFT(a.query, 500) AS query_text, c.table_name AS pii_table, c.column_name AS pii_column FROM pg_stat_activity a JOIN information_schema.columns c ON a.datname = current_database() AND a.query ILIKE '%' || c.table_name || '%' WHERE a.state != 'idle' AND a.pid != pg_backend_pid() AND a.query IS NOT NULL AND c.table_schema NOT IN ('pg_catalog','information_schema') AND (lower(c.column_name) ~ '(ssn|social_sec|national_id|tax_id|passport|credit_card|card_num|cvv|email|e_mail|phone|mobile|birth_date|dob|date_of_birth|first_name|last_name|full_name|surname|address|salary|income|bank_account|iban|password|pwd|secret)')"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Active transactions are accessing tables containing PII/sensitive columns - potential data exposure", "severity": "critical"}$body$::jsonb
    ) RETURNING id INTO v_step2_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC05', 'postgresql',
        'Detect sensitive data (pii) accessed in active transactions (postgresql)',
        'Detection path for Sensitive data (PII) accessed in active transactions on postgresql',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'next', 'ruled_out');
    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step2_id, 2, 'confirmed', 'ruled_out');
END $$;

-- ======================= postgresql RC06 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('postgresql', 'sql_query',
        'Detect SQL injection patterns in active transactions',
        $body${"sql": "SELECT usename AS login_name, client_addr AS host_name, application_name AS program_name, datname AS database_name, EXTRACT(EPOCH FROM (now() - xact_start))::int AS elapsed_sec, LEFT(query, 500) AS query_text, CASE WHEN query ILIKE '%OR 1=1%' OR query ILIKE '%OR ''1''=''1%' OR query ILIKE '%OR true%' THEN 'tautology' WHEN query ILIKE '%UNION%SELECT%' THEN 'union-based' WHEN query LIKE '%;%' AND (query ILIKE '%DROP %' OR query ILIKE '%DELETE %' OR query ILIKE '%INSERT %') THEN 'stacked-query' WHEN query LIKE '%--%' AND (query LIKE '%''%--%' OR query ILIKE '%OR%--%') THEN 'comment-truncation' WHEN query ILIKE '%pg_sleep%' THEN 'time-based-blind' WHEN query ILIKE '%CAST(%AS%text%' THEN 'error-based' ELSE 'other' END AS injection_type FROM pg_stat_activity WHERE state != 'idle' AND pid != pg_backend_pid() AND query IS NOT NULL AND (query ILIKE '%OR 1=1%' OR query ILIKE '%OR ''1''=''1%' OR query ILIKE '%OR true%' OR query ILIKE '%UNION%SELECT%' OR (query LIKE '%;%' AND (query ILIKE '%DROP %' OR query ILIKE '%DELETE %' OR query ILIKE '%INSERT %')) OR query ILIKE '%pg_sleep%' OR query ILIKE '%COPY%TO%PROGRAM%')"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "SQL injection patterns detected in active transactions - active attack in progress", "severity": "critical"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC06', 'postgresql',
        'Detect sql injection patterns in active transactions (postgresql)',
        'Detection path for SQL injection patterns in active transactions on postgresql',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= postgresql RC07 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('postgresql', 'sql_query',
        'Detect after-hours transaction activity',
        $body${"sql": "SELECT usename AS login_name, client_addr AS host_name, application_name AS program_name, datname AS database_name, EXTRACT(EPOCH FROM (now() - xact_start))::int AS elapsed_sec, EXTRACT(HOUR FROM now()) AS current_hour, LEFT(query, 500) AS query_text FROM pg_stat_activity WHERE state != 'idle' AND pid != pg_backend_pid() AND (EXTRACT(HOUR FROM now()) < 6 OR EXTRACT(HOUR FROM now()) >= 22)"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "User transactions running outside business hours (before 06:00 or after 22:00) - potential unauthorized access", "severity": "high"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC07', 'postgresql',
        'Detect after-hours transaction activity (postgresql)',
        'Detection path for After-hours transaction activity on postgresql',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= postgresql RC08 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('postgresql', 'sql_query',
        'Detect privilege escalation in active transactions',
        $body${"sql": "SELECT usename AS login_name, client_addr AS host_name, application_name AS program_name, datname AS database_name, EXTRACT(EPOCH FROM (now() - xact_start))::int AS elapsed_sec, LEFT(query, 500) AS query_text, CASE WHEN query ILIKE '%CREATE ROLE%' OR query ILIKE '%CREATE USER%' THEN 'create-account' WHEN query ILIKE '%ALTER ROLE%' OR query ILIKE '%ALTER USER%' THEN 'alter-account' WHEN query ILIKE '%GRANT%' THEN 'grant-privilege' WHEN query ILIKE '%DROP TABLE%' OR query ILIKE '%DROP SCHEMA%' OR query ILIKE '%ALTER TABLE%' THEN 'ddl-modification' WHEN query ILIKE '%REVOKE%' THEN 'revoke' ELSE 'other-ddl' END AS escalation_type FROM pg_stat_activity WHERE state != 'idle' AND pid != pg_backend_pid() AND usename != 'postgres' AND (query ILIKE '%CREATE ROLE%' OR query ILIKE '%CREATE USER%' OR query ILIKE '%ALTER ROLE%' OR query ILIKE '%ALTER USER%' OR query ILIKE '%GRANT%' OR query ILIKE '%REVOKE%' OR query ILIKE '%DROP TABLE%' OR query ILIKE '%DROP SCHEMA%' OR query ILIKE '%DROP DATABASE%' OR query ILIKE '%ALTER TABLE%')"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Non-admin user executing DDL/DCL statements - potential privilege escalation", "severity": "critical"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC08', 'postgresql',
        'Detect privilege escalation attempts in transactions (postgresql)',
        'Detection path for Privilege escalation attempts in transactions on postgresql',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= postgresql RC09 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('postgresql', 'sql_query',
        'Detect data exfiltration patterns in transactions',
        $body${"sql": "SELECT usename AS login_name, client_addr AS host_name, application_name AS program_name, datname AS database_name, EXTRACT(EPOCH FROM (now() - xact_start))::int AS elapsed_sec, LEFT(query, 500) AS query_text, CASE WHEN query ILIKE '%COPY%TO%' THEN 'copy-export' WHEN query ILIKE '%dblink%' OR query ILIKE '%postgres_fdw%' THEN 'foreign-data' WHEN query ILIKE '%pg_dump%' THEN 'dump' WHEN query ILIKE '%SELECT%*%FROM%' AND EXTRACT(EPOCH FROM (now() - xact_start)) > 60 THEN 'long-running-extract' ELSE 'other' END AS exfil_type FROM pg_stat_activity WHERE state != 'idle' AND pid != pg_backend_pid() AND (query ILIKE '%COPY%TO%' OR query ILIKE '%dblink%' OR query ILIKE '%postgres_fdw%' OR query ILIKE '%pg_dump%' OR (query ILIKE '%SELECT%*%FROM%' AND EXTRACT(EPOCH FROM (now() - xact_start)) > 60))"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Data exfiltration patterns detected - COPY export, foreign data wrappers, or long-running bulk reads", "severity": "critical"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC09', 'postgresql',
        'Detect data exfiltration patterns in transactions (postgresql)',
        'Detection path for Data exfiltration patterns in transactions on postgresql',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= postgresql RC10 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('postgresql', 'sql_query',
        'Detect same login active from multiple hosts',
        $body${"sql": "SELECT usename AS login_name, COUNT(DISTINCT client_addr) AS distinct_hosts, STRING_AGG(DISTINCT client_addr::text, ', ') AS hosts, COUNT(*) AS total_sessions FROM pg_stat_activity WHERE state != 'idle' AND pid != pg_backend_pid() AND client_addr IS NOT NULL GROUP BY usename HAVING COUNT(DISTINCT client_addr) > 1"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Same login has concurrent sessions from multiple hosts - possible credential compromise", "severity": "high"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC10', 'postgresql',
        'Detect same login active from multiple hosts (postgresql)',
        'Detection path for Same login active from multiple hosts on postgresql',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= postgresql RC11 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('postgresql', 'sql_query',
        'Detect schema reconnaissance in active transactions',
        $body${"sql": "SELECT usename AS login_name, client_addr AS host_name, application_name AS program_name, datname AS database_name, EXTRACT(EPOCH FROM (now() - xact_start))::int AS elapsed_sec, LEFT(query, 500) AS query_text, CASE WHEN query ILIKE '%pg_catalog.pg_tables%' OR query ILIKE '%pg_class%' THEN 'object-enumeration' WHEN query ILIKE '%pg_catalog.pg_attribute%' OR query ILIKE '%information_schema.columns%' THEN 'column-enumeration' WHEN query ILIKE '%pg_roles%' OR query ILIKE '%pg_authid%' THEN 'role-enumeration' WHEN query ILIKE '%pg_catalog.pg_hba%' THEN 'auth-enumeration' WHEN query ILIKE '%information_schema.table_privileges%' OR query ILIKE '%pg_catalog.pg_default_acl%' THEN 'permission-enumeration' WHEN query ILIKE '%pg_settings%' THEN 'config-enumeration' ELSE 'other-recon' END AS recon_type FROM pg_stat_activity WHERE state != 'idle' AND pid != pg_backend_pid() AND (query ILIKE '%pg_catalog.pg_tables%' OR query ILIKE '%pg_class%' OR query ILIKE '%pg_catalog.pg_attribute%' OR query ILIKE '%information_schema.columns%' OR query ILIKE '%information_schema.tables%' OR query ILIKE '%pg_roles%' OR query ILIKE '%pg_authid%' OR query ILIKE '%pg_catalog.pg_hba%' OR query ILIKE '%information_schema.table_privileges%' OR query ILIKE '%pg_settings%')"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Schema reconnaissance detected - user querying system catalogs to enumerate objects, columns, or permissions", "severity": "high"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC11', 'postgresql',
        'Detect schema reconnaissance activity (postgresql)',
        'Detection path for Schema reconnaissance activity on postgresql',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= postgresql RC12 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('postgresql', 'sql_query',
        'Detect dormant accounts with active transactions',
        $body${"sql": "WITH last_activity AS (SELECT usename, MAX(backend_start) AS last_seen FROM pg_stat_activity GROUP BY usename) SELECT a.usename AS login_name, a.client_addr AS host_name, a.application_name AS program_name, a.datname AS database_name, EXTRACT(EPOCH FROM (now() - a.xact_start))::int AS elapsed_sec, LEFT(a.query, 500) AS query_text, r.rolvaliduntil, CASE WHEN r.rolconnlimit = 0 THEN 'restricted' ELSE 'normal' END AS account_status FROM pg_stat_activity a JOIN pg_roles r ON a.usename = r.rolname WHERE a.state != 'idle' AND a.pid != pg_backend_pid() AND (r.rolvaliduntil IS NOT NULL AND r.rolvaliduntil < now() + interval '30 days')"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Account with expiring or expired credentials is running transactions - verify legitimacy", "severity": "high"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC12', 'postgresql',
        'Detect dormant account suddenly active (postgresql)',
        'Detection path for Dormant account suddenly active on postgresql',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= postgresql RC13 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('postgresql', 'sql_query',
        'Detect mass data modification in active transactions',
        $body${"sql": "SELECT usename AS login_name, client_addr AS host_name, application_name AS program_name, datname AS database_name, EXTRACT(EPOCH FROM (now() - xact_start))::int AS elapsed_sec, LEFT(query, 500) AS query_text, CASE WHEN query ILIKE 'UPDATE%' THEN 'UPDATE' WHEN query ILIKE 'DELETE%' THEN 'DELETE' WHEN query ILIKE 'TRUNCATE%' THEN 'TRUNCATE' END AS operation FROM pg_stat_activity WHERE state = 'active' AND pid != pg_backend_pid() AND (query ILIKE 'DELETE%' OR query ILIKE 'TRUNCATE%' OR (query ILIKE 'UPDATE%' AND EXTRACT(EPOCH FROM (now() - xact_start)) > 30))"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Mass DELETE/UPDATE/TRUNCATE detected in active transactions - potential data destruction", "severity": "critical"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC13', 'postgresql',
        'Detect mass data modification in transactions (postgresql)',
        'Detection path for Mass data modification in transactions on postgresql',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= oracle RC01 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('oracle', 'sql_query',
        'Retrieve active transactions with login details',
        $body${"sql": "SELECT s.username AS login_name, s.machine AS host_name, s.program AS program_name, s.schemaname AS database_name, s.status, s.state, s.event AS wait_event, s.last_call_et AS elapsed_sec, SUBSTR(q.sql_text, 1, 500) AS query_text FROM v$session s LEFT JOIN v$sql q ON s.sql_id = q.sql_id AND s.sql_child_number = q.child_number WHERE s.type = 'USER' AND s.status = 'ACTIVE' AND s.username NOT IN ('SYS','SYSTEM','DBSNMP','SYSMAN')"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Active user transactions found - check login_name against baseline", "severity": "high"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC01', 'oracle',
        'Detect unknown login executing queries (oracle)',
        'Detection path for Unknown login executing queries on oracle',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= oracle RC02 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('oracle', 'sql_query',
        'Detect transactions from unexpected programs',
        $body${"sql": "SELECT s.username AS login_name, s.program AS program_name, s.machine AS host_name, s.schemaname AS database_name, COUNT(*) AS active_requests FROM v$session s WHERE s.type = 'USER' AND s.status = 'ACTIVE' GROUP BY s.username, s.program, s.machine, s.schemaname ORDER BY active_requests DESC"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Active programs found - verify program against known applications", "severity": "high"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC02', 'oracle',
        'Detect unexpected program or application connected (oracle)',
        'Detection path for Unexpected program or application connected on oracle',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= oracle RC03 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('oracle', 'sql_query',
        'Detect transactions targeting unexpected schemas',
        $body${"sql": "SELECT DISTINCT s.username AS login_name, s.program AS program_name, s.schemaname AS database_name, COUNT(*) AS request_count FROM v$session s WHERE s.type = 'USER' AND s.status = 'ACTIVE' AND s.schemaname NOT IN ('SYS','SYSTEM','DBSNMP','OUTLN','XDB') GROUP BY s.username, s.program, s.schemaname"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "User transactions on non-system schemas - verify access is expected", "severity": "medium"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC03', 'oracle',
        'Detect query activity on unexpected database (oracle)',
        'Detection path for Query activity on unexpected database on oracle',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= oracle RC04 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('oracle', 'sql_query',
        'Detect suspicious query patterns in active transactions',
        $body${"sql": "SELECT s.username AS login_name, s.program AS program_name, s.machine AS host_name, s.schemaname AS database_name, s.last_call_et AS elapsed_sec, SUBSTR(q.sql_text, 1, 500) AS query_text FROM v$session s JOIN v$sql q ON s.sql_id = q.sql_id AND s.sql_child_number = q.child_number WHERE s.type = 'USER' AND s.status = 'ACTIVE' AND (q.sql_text LIKE '%DBA_USERS%' OR q.sql_text LIKE '%ALL_TAB_PRIVS%' OR q.sql_text LIKE '%ALTER USER%' OR q.sql_text LIKE '%CREATE USER%' OR q.sql_text LIKE '%GRANT%DBA%' OR q.sql_text LIKE '%UTL_FILE%' OR q.sql_text LIKE '%DBMS_SCHEDULER%' OR q.sql_text LIKE '%UTL_HTTP%')"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Suspicious SQL patterns detected in active transactions - potential security threat", "severity": "critical"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC04', 'oracle',
        'Detect suspicious query patterns detected (oracle)',
        'Detection path for Suspicious query patterns detected on oracle',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= oracle RC05 (2 steps) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
    v_step2_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('oracle', 'sql_query',
        'Identify sensitive (PII) columns in database',
        $body${"sql": "SELECT owner AS schema_name, table_name, column_name, data_type FROM all_tab_columns WHERE owner NOT IN ('SYS','SYSTEM','DBSNMP','OUTLN','XDB','WMSYS','CTXSYS','MDSYS','ORDDATA','ORDSYS') AND (LOWER(column_name) LIKE '%SSN%' OR LOWER(column_name) LIKE '%SOCIAL_SEC%' OR LOWER(column_name) LIKE '%NATIONAL_ID%' OR LOWER(column_name) LIKE '%TAX_ID%' OR LOWER(column_name) LIKE '%PASSPORT%' OR LOWER(column_name) LIKE '%CREDIT_CARD%' OR LOWER(column_name) LIKE '%CARD_NUM%' OR LOWER(column_name) LIKE '%EMAIL%' OR LOWER(column_name) LIKE '%PHONE%' OR LOWER(column_name) LIKE '%MOBILE%' OR LOWER(column_name) LIKE '%BIRTH_DATE%' OR LOWER(column_name) LIKE '%DOB%' OR LOWER(column_name) LIKE '%FIRST_NAME%' OR LOWER(column_name) LIKE '%LAST_NAME%' OR LOWER(column_name) LIKE '%FULL_NAME%' OR LOWER(column_name) LIKE '%SURNAME%' OR LOWER(column_name) LIKE '%ADDRESS%' OR LOWER(column_name) LIKE '%SALARY%' OR LOWER(column_name) LIKE '%INCOME%' OR LOWER(column_name) LIKE '%BANK_ACCOUNT%' OR LOWER(column_name) LIKE '%IBAN%' OR LOWER(column_name) LIKE '%PASSWORD%' OR LOWER(column_name) LIKE '%SECRET%') ORDER BY owner, table_name"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "PII/sensitive columns identified in the database schema", "severity": "medium"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('oracle', 'sql_query',
        'Detect active transactions accessing PII tables',
        $body${"sql": "SELECT s.username AS login_name, s.machine AS host_name, s.program AS program_name, s.schemaname AS database_name, s.last_call_et AS elapsed_sec, SUBSTR(q.sql_text, 1, 500) AS query_text FROM v$session s JOIN v$sql q ON s.sql_id = q.sql_id AND s.sql_child_number = q.child_number JOIN all_tab_columns c ON s.schemaname = c.owner AND q.sql_text LIKE '%' || c.table_name || '%' WHERE s.type = 'USER' AND s.status = 'ACTIVE' AND c.owner NOT IN ('SYS','SYSTEM','DBSNMP','OUTLN','XDB') AND (LOWER(c.column_name) LIKE '%SSN%' OR LOWER(c.column_name) LIKE '%CREDIT_CARD%' OR LOWER(c.column_name) LIKE '%EMAIL%' OR LOWER(c.column_name) LIKE '%PHONE%' OR LOWER(c.column_name) LIKE '%BIRTH_DATE%' OR LOWER(c.column_name) LIKE '%FIRST_NAME%' OR LOWER(c.column_name) LIKE '%LAST_NAME%' OR LOWER(c.column_name) LIKE '%SALARY%' OR LOWER(c.column_name) LIKE '%PASSWORD%' OR LOWER(c.column_name) LIKE '%BANK_ACCOUNT%')"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Active transactions are accessing tables containing PII/sensitive columns - potential data exposure", "severity": "critical"}$body$::jsonb
    ) RETURNING id INTO v_step2_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC05', 'oracle',
        'Detect sensitive data (pii) accessed in active transactions (oracle)',
        'Detection path for Sensitive data (PII) accessed in active transactions on oracle',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'next', 'ruled_out');
    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step2_id, 2, 'confirmed', 'ruled_out');
END $$;

-- ======================= oracle RC06 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('oracle', 'sql_query',
        'Detect SQL injection patterns in active transactions',
        $body${"sql": "SELECT s.username AS login_name, s.machine AS host_name, s.program AS program_name, s.schemaname AS database_name, s.last_call_et AS elapsed_sec, SUBSTR(q.sql_text, 1, 500) AS query_text, CASE WHEN q.sql_text LIKE '%OR 1=1%' OR q.sql_text LIKE '%OR ''1''=''1%' THEN 'tautology' WHEN q.sql_text LIKE '%UNION%SELECT%' THEN 'union-based' WHEN q.sql_text LIKE '%;%' AND (q.sql_text LIKE '%DROP %' OR q.sql_text LIKE '%DELETE %') THEN 'stacked-query' WHEN q.sql_text LIKE '%--%' AND q.sql_text LIKE '%''%--%' THEN 'comment-truncation' WHEN q.sql_text LIKE '%DBMS_LOCK.SLEEP%' THEN 'time-based-blind' WHEN q.sql_text LIKE '%UTL_INADDR%' OR q.sql_text LIKE '%CTXSYS.DRITHSX%' THEN 'error-based' ELSE 'other' END AS injection_type FROM v$session s JOIN v$sql q ON s.sql_id = q.sql_id AND s.sql_child_number = q.child_number WHERE s.type = 'USER' AND s.status = 'ACTIVE' AND (q.sql_text LIKE '%OR 1=1%' OR q.sql_text LIKE '%OR ''1''=''1%' OR q.sql_text LIKE '%UNION%SELECT%' OR (q.sql_text LIKE '%;%' AND (q.sql_text LIKE '%DROP %' OR q.sql_text LIKE '%DELETE %')) OR q.sql_text LIKE '%DBMS_LOCK.SLEEP%' OR q.sql_text LIKE '%UTL_INADDR%' OR q.sql_text LIKE '%CTXSYS.DRITHSX%' OR q.sql_text LIKE '%EXECUTE IMMEDIATE%')"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "SQL injection patterns detected in active transactions - active attack in progress", "severity": "critical"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC06', 'oracle',
        'Detect sql injection patterns in active transactions (oracle)',
        'Detection path for SQL injection patterns in active transactions on oracle',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= oracle RC07 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('oracle', 'sql_query',
        'Detect after-hours transaction activity',
        $body${"sql": "SELECT s.username AS login_name, s.machine AS host_name, s.program AS program_name, s.schemaname AS database_name, s.last_call_et AS elapsed_sec, TO_NUMBER(TO_CHAR(SYSDATE, 'HH24')) AS current_hour, SUBSTR(q.sql_text, 1, 500) AS query_text FROM v$session s LEFT JOIN v$sql q ON s.sql_id = q.sql_id AND s.sql_child_number = q.child_number WHERE s.type = 'USER' AND s.status = 'ACTIVE' AND (TO_NUMBER(TO_CHAR(SYSDATE, 'HH24')) < 6 OR TO_NUMBER(TO_CHAR(SYSDATE, 'HH24')) >= 22)"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "User transactions running outside business hours (before 06:00 or after 22:00) - potential unauthorized access", "severity": "high"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC07', 'oracle',
        'Detect after-hours transaction activity (oracle)',
        'Detection path for After-hours transaction activity on oracle',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= oracle RC08 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('oracle', 'sql_query',
        'Detect privilege escalation in active transactions',
        $body${"sql": "SELECT s.username AS login_name, s.machine AS host_name, s.program AS program_name, s.schemaname AS database_name, s.last_call_et AS elapsed_sec, SUBSTR(q.sql_text, 1, 500) AS query_text FROM v$session s JOIN v$sql q ON s.sql_id = q.sql_id AND s.sql_child_number = q.child_number WHERE s.type = 'USER' AND s.status = 'ACTIVE' AND s.username NOT IN ('SYS','SYSTEM') AND (q.sql_text LIKE '%CREATE USER%' OR q.sql_text LIKE '%ALTER USER%' OR q.sql_text LIKE '%GRANT%' OR q.sql_text LIKE '%REVOKE%' OR q.sql_text LIKE '%DROP TABLE%' OR q.sql_text LIKE '%DROP USER%' OR q.sql_text LIKE '%ALTER TABLE%' OR q.sql_text LIKE '%CREATE ROLE%')"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Non-admin user executing DDL/DCL statements - potential privilege escalation", "severity": "critical"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC08', 'oracle',
        'Detect privilege escalation attempts in transactions (oracle)',
        'Detection path for Privilege escalation attempts in transactions on oracle',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= oracle RC09 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('oracle', 'sql_query',
        'Detect data exfiltration patterns in transactions',
        $body${"sql": "SELECT s.username AS login_name, s.machine AS host_name, s.program AS program_name, s.schemaname AS database_name, s.last_call_et AS elapsed_sec, SUBSTR(q.sql_text, 1, 500) AS query_text FROM v$session s JOIN v$sql q ON s.sql_id = q.sql_id AND s.sql_child_number = q.child_number WHERE s.type = 'USER' AND s.status = 'ACTIVE' AND (q.sql_text LIKE '%UTL_FILE%' OR q.sql_text LIKE '%UTL_HTTP%' OR q.sql_text LIKE '%DBMS_LOB%' OR q.sql_text LIKE '%CREATE%DATABASE LINK%' OR q.sql_text LIKE '%SELECT%*%FROM%' AND s.last_call_et > 60)"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Data exfiltration patterns detected - UTL_FILE, UTL_HTTP, DB link, or long-running bulk reads", "severity": "critical"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC09', 'oracle',
        'Detect data exfiltration patterns in transactions (oracle)',
        'Detection path for Data exfiltration patterns in transactions on oracle',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= oracle RC10 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('oracle', 'sql_query',
        'Detect same login active from multiple hosts',
        $body${"sql": "SELECT username AS login_name, COUNT(DISTINCT machine) AS distinct_hosts, LISTAGG(DISTINCT machine, ', ') WITHIN GROUP (ORDER BY machine) AS hosts, COUNT(*) AS total_sessions FROM v$session WHERE type = 'USER' AND status = 'ACTIVE' AND machine IS NOT NULL GROUP BY username HAVING COUNT(DISTINCT machine) > 1"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Same login has concurrent sessions from multiple hosts - possible credential compromise", "severity": "high"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC10', 'oracle',
        'Detect same login active from multiple hosts (oracle)',
        'Detection path for Same login active from multiple hosts on oracle',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= oracle RC11 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('oracle', 'sql_query',
        'Detect schema reconnaissance in active transactions',
        $body${"sql": "SELECT s.username AS login_name, s.machine AS host_name, s.program AS program_name, s.schemaname AS database_name, s.last_call_et AS elapsed_sec, SUBSTR(q.sql_text, 1, 500) AS query_text FROM v$session s JOIN v$sql q ON s.sql_id = q.sql_id AND s.sql_child_number = q.child_number WHERE s.type = 'USER' AND s.status = 'ACTIVE' AND s.username NOT IN ('SYS','SYSTEM') AND (q.sql_text LIKE '%ALL_TABLES%' OR q.sql_text LIKE '%ALL_TAB_COLUMNS%' OR q.sql_text LIKE '%DBA_TABLES%' OR q.sql_text LIKE '%DBA_TAB_COLUMNS%' OR q.sql_text LIKE '%DBA_USERS%' OR q.sql_text LIKE '%DBA_ROLE_PRIVS%' OR q.sql_text LIKE '%DBA_SYS_PRIVS%' OR q.sql_text LIKE '%ALL_TAB_PRIVS%' OR q.sql_text LIKE '%V$PARAMETER%')"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Schema reconnaissance detected - user querying data dictionary to enumerate objects, users, or privileges", "severity": "high"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC11', 'oracle',
        'Detect schema reconnaissance activity (oracle)',
        'Detection path for Schema reconnaissance activity on oracle',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= oracle RC12 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('oracle', 'sql_query',
        'Detect dormant accounts with active transactions',
        $body${"sql": "SELECT s.username AS login_name, s.machine AS host_name, s.program AS program_name, s.schemaname AS database_name, s.last_call_et AS elapsed_sec, SUBSTR(q.sql_text, 1, 500) AS query_text, u.expiry_date, u.lock_date, TRUNC(SYSDATE - NVL(u.expiry_date, SYSDATE)) AS days_past_expiry FROM v$session s JOIN v$sql q ON s.sql_id = q.sql_id AND s.sql_child_number = q.child_number JOIN dba_users u ON s.username = u.username WHERE s.type = 'USER' AND s.status = 'ACTIVE' AND (u.account_status LIKE '%EXPIRED%' OR (u.expiry_date IS NOT NULL AND u.expiry_date < SYSDATE + 30))"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Account with expired or soon-expiring credentials is running transactions - possible dormant account reuse", "severity": "high"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC12', 'oracle',
        'Detect dormant account suddenly active (oracle)',
        'Detection path for Dormant account suddenly active on oracle',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= oracle RC13 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('oracle', 'sql_query',
        'Detect mass data modification in active transactions',
        $body${"sql": "SELECT s.username AS login_name, s.machine AS host_name, s.program AS program_name, s.schemaname AS database_name, s.last_call_et AS elapsed_sec, t.used_ublk AS undo_blocks, SUBSTR(q.sql_text, 1, 500) AS query_text FROM v$session s JOIN v$sql q ON s.sql_id = q.sql_id AND s.sql_child_number = q.child_number JOIN v$transaction t ON s.taddr = t.addr WHERE s.type = 'USER' AND s.status = 'ACTIVE' AND t.used_ublk > 1000 AND (q.sql_text LIKE '%UPDATE%' OR q.sql_text LIKE '%DELETE%' OR q.sql_text LIKE '%TRUNCATE%')"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Mass data modification using 1000+ undo blocks - potential data destruction or unauthorized bulk change", "severity": "critical"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC13', 'oracle',
        'Detect mass data modification in transactions (oracle)',
        'Detection path for Mass data modification in transactions on oracle',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= mysql RC01 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('mysql', 'sql_query',
        'Retrieve active transactions with login details',
        $body${"sql": "SELECT USER AS login_name, HOST AS host_name, DB AS database_name, COMMAND, STATE AS wait_event, TIME AS elapsed_sec, LEFT(INFO, 500) AS query_text FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep' AND USER NOT IN ('system user','event_scheduler','root') AND ID != CONNECTION_ID()"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Active user transactions found - check login_name against baseline", "severity": "high"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC01', 'mysql',
        'Detect unknown login executing queries (mysql)',
        'Detection path for Unknown login executing queries on mysql',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= mysql RC02 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('mysql', 'sql_query',
        'Detect transactions from unexpected hosts',
        $body${"sql": "SELECT USER AS login_name, SUBSTRING_INDEX(HOST, ':', 1) AS host_name, DB AS database_name, COUNT(*) AS active_requests FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep' AND ID != CONNECTION_ID() GROUP BY USER, SUBSTRING_INDEX(HOST, ':', 1), DB ORDER BY active_requests DESC"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Active connections found - verify host and user against known sources", "severity": "high"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC02', 'mysql',
        'Detect unexpected program or application connected (mysql)',
        'Detection path for Unexpected program or application connected on mysql',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= mysql RC03 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('mysql', 'sql_query',
        'Detect transactions targeting unexpected databases',
        $body${"sql": "SELECT DISTINCT USER AS login_name, DB AS database_name, COUNT(*) AS request_count FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep' AND ID != CONNECTION_ID() AND DB NOT IN ('mysql','information_schema','performance_schema','sys') AND DB IS NOT NULL GROUP BY USER, DB"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "User transactions on non-system databases - verify database access is expected", "severity": "medium"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC03', 'mysql',
        'Detect query activity on unexpected database (mysql)',
        'Detection path for Query activity on unexpected database on mysql',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= mysql RC04 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('mysql', 'sql_query',
        'Detect suspicious query patterns in active transactions',
        $body${"sql": "SELECT USER AS login_name, HOST AS host_name, DB AS database_name, TIME AS elapsed_sec, LEFT(INFO, 500) AS query_text FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep' AND ID != CONNECTION_ID() AND (INFO LIKE '%mysql.user%' OR INFO LIKE '%INTO OUTFILE%' OR INFO LIKE '%INTO DUMPFILE%' OR INFO LIKE '%LOAD_FILE%' OR INFO LIKE '%CREATE USER%' OR INFO LIKE '%GRANT%ALL%' OR INFO LIKE '%information_schema.columns%')"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Suspicious SQL patterns detected in active transactions - potential security threat", "severity": "critical"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC04', 'mysql',
        'Detect suspicious query patterns detected (mysql)',
        'Detection path for Suspicious query patterns detected on mysql',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= mysql RC05 (2 steps) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
    v_step2_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('mysql', 'sql_query',
        'Identify sensitive (PII) columns in database',
        $body${"sql": "SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, DATA_TYPE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys') AND (LOWER(COLUMN_NAME) REGEXP '(ssn|social_sec|national_id|tax_id|passport|credit_card|card_num|cvv|email|e_mail|phone|mobile|cell|birth_date|dob|date_of_birth|first_name|last_name|full_name|surname|address|street|zip_code|postal|salary|income|wage|bank_account|iban|routing_num|password|pwd|secret)') ORDER BY TABLE_SCHEMA, TABLE_NAME"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "PII/sensitive columns identified in the database schema", "severity": "medium"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('mysql', 'sql_query',
        'Detect active transactions accessing PII tables',
        $body${"sql": "SELECT p.USER AS login_name, p.HOST AS host_name, p.DB AS database_name, p.TIME AS elapsed_sec, LEFT(p.INFO, 500) AS query_text, c.TABLE_NAME AS pii_table, c.COLUMN_NAME AS pii_column FROM information_schema.PROCESSLIST p JOIN information_schema.COLUMNS c ON p.DB = c.TABLE_SCHEMA AND p.INFO LIKE CONCAT('%', c.TABLE_NAME, '%') WHERE p.COMMAND != 'Sleep' AND p.ID != CONNECTION_ID() AND p.INFO IS NOT NULL AND c.TABLE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys') AND (LOWER(c.COLUMN_NAME) REGEXP '(ssn|social_sec|national_id|tax_id|passport|credit_card|card_num|cvv|email|e_mail|phone|mobile|cell|birth_date|dob|date_of_birth|first_name|last_name|full_name|surname|address|salary|income|bank_account|iban|password|pwd|secret)')"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Active transactions are accessing tables containing PII/sensitive columns - potential data exposure", "severity": "critical"}$body$::jsonb
    ) RETURNING id INTO v_step2_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC05', 'mysql',
        'Detect sensitive data (pii) accessed in active transactions (mysql)',
        'Detection path for Sensitive data (PII) accessed in active transactions on mysql',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'next', 'ruled_out');
    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step2_id, 2, 'confirmed', 'ruled_out');
END $$;

-- ======================= mysql RC06 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('mysql', 'sql_query',
        'Detect SQL injection patterns in active transactions',
        $body${"sql": "SELECT USER AS login_name, HOST AS host_name, DB AS database_name, TIME AS elapsed_sec, LEFT(INFO, 500) AS query_text, CASE WHEN INFO LIKE '%OR 1=1%' OR INFO LIKE '%OR ''1''=''1%' OR INFO LIKE '%OR true%' THEN 'tautology' WHEN INFO LIKE '%UNION%SELECT%' THEN 'union-based' WHEN INFO LIKE '%;%DROP%' OR INFO LIKE '%;%DELETE%' OR INFO LIKE '%;%INSERT%' OR INFO LIKE '%;%UPDATE%' THEN 'stacked-query' WHEN INFO LIKE '%--%' OR INFO LIKE '%#%' OR INFO LIKE '%/*%' THEN 'comment-truncation' WHEN INFO LIKE '%SLEEP(%' OR INFO LIKE '%BENCHMARK(%' THEN 'time-based-blind' WHEN INFO LIKE '%EXTRACTVALUE%' OR INFO LIKE '%UPDATEXML%' OR INFO LIKE '%CONVERT(%' THEN 'error-based' ELSE 'other' END AS injection_type FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep' AND ID != CONNECTION_ID() AND INFO IS NOT NULL AND (INFO LIKE '%OR 1=1%' OR INFO LIKE '%OR ''1''=''1%' OR INFO LIKE '%OR true%' OR INFO LIKE '%UNION%SELECT%' OR (INFO LIKE '%;%' AND (INFO LIKE '%DROP %' OR INFO LIKE '%DELETE %' OR INFO LIKE '%INSERT %' OR INFO LIKE '%UPDATE %')) OR INFO LIKE '%SLEEP(%' OR INFO LIKE '%BENCHMARK(%' OR INFO LIKE '%EXTRACTVALUE%' OR INFO LIKE '%UPDATEXML%')"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "SQL injection patterns detected in active transactions - active attack in progress", "severity": "critical"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC06', 'mysql',
        'Detect sql injection patterns in active transactions (mysql)',
        'Detection path for SQL injection patterns in active transactions on mysql',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= mysql RC07 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('mysql', 'sql_query',
        'Detect after-hours transaction activity',
        $body${"sql": "SELECT USER AS login_name, HOST AS host_name, DB AS database_name, TIME AS elapsed_sec, HOUR(NOW()) AS current_hour, LEFT(INFO, 500) AS query_text FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep' AND ID != CONNECTION_ID() AND (HOUR(NOW()) < 6 OR HOUR(NOW()) >= 22)"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "User transactions running outside business hours (before 06:00 or after 22:00) - potential unauthorized access", "severity": "high"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC07', 'mysql',
        'Detect after-hours transaction activity (mysql)',
        'Detection path for After-hours transaction activity on mysql',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= mysql RC08 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('mysql', 'sql_query',
        'Detect privilege escalation in active transactions',
        $body${"sql": "SELECT USER AS login_name, HOST AS host_name, DB AS database_name, TIME AS elapsed_sec, LEFT(INFO, 500) AS query_text FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep' AND ID != CONNECTION_ID() AND USER != 'root' AND (INFO LIKE '%CREATE USER%' OR INFO LIKE '%ALTER USER%' OR INFO LIKE '%GRANT%' OR INFO LIKE '%REVOKE%' OR INFO LIKE '%DROP TABLE%' OR INFO LIKE '%DROP DATABASE%' OR INFO LIKE '%ALTER TABLE%' OR INFO LIKE '%CREATE ROLE%')"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Non-admin user executing DDL/DCL statements - potential privilege escalation", "severity": "critical"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC08', 'mysql',
        'Detect privilege escalation attempts in transactions (mysql)',
        'Detection path for Privilege escalation attempts in transactions on mysql',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= mysql RC09 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('mysql', 'sql_query',
        'Detect data exfiltration patterns in transactions',
        $body${"sql": "SELECT USER AS login_name, HOST AS host_name, DB AS database_name, TIME AS elapsed_sec, LEFT(INFO, 500) AS query_text, CASE WHEN INFO LIKE '%INTO OUTFILE%' OR INFO LIKE '%INTO DUMPFILE%' THEN 'file-export' WHEN INFO LIKE '%LOAD_FILE%' THEN 'file-read' WHEN INFO LIKE '%SELECT%*%FROM%' AND TIME > 60 THEN 'long-running-extract' ELSE 'other' END AS exfil_type FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep' AND ID != CONNECTION_ID() AND (INFO LIKE '%INTO OUTFILE%' OR INFO LIKE '%INTO DUMPFILE%' OR INFO LIKE '%LOAD_FILE%' OR (INFO LIKE '%SELECT%*%FROM%' AND TIME > 60))"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Data exfiltration patterns detected - file export, file read, or long-running bulk reads", "severity": "critical"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC09', 'mysql',
        'Detect data exfiltration patterns in transactions (mysql)',
        'Detection path for Data exfiltration patterns in transactions on mysql',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= mysql RC10 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('mysql', 'sql_query',
        'Detect same login active from multiple hosts',
        $body${"sql": "SELECT USER AS login_name, COUNT(DISTINCT SUBSTRING_INDEX(HOST, ':', 1)) AS distinct_hosts, GROUP_CONCAT(DISTINCT SUBSTRING_INDEX(HOST, ':', 1)) AS hosts, COUNT(*) AS total_sessions FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep' AND ID != CONNECTION_ID() GROUP BY USER HAVING COUNT(DISTINCT SUBSTRING_INDEX(HOST, ':', 1)) > 1"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Same login has concurrent sessions from multiple hosts - possible credential compromise", "severity": "high"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC10', 'mysql',
        'Detect same login active from multiple hosts (mysql)',
        'Detection path for Same login active from multiple hosts on mysql',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= mysql RC11 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('mysql', 'sql_query',
        'Detect schema reconnaissance in active transactions',
        $body${"sql": "SELECT USER AS login_name, HOST AS host_name, DB AS database_name, TIME AS elapsed_sec, LEFT(INFO, 500) AS query_text FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep' AND ID != CONNECTION_ID() AND USER != 'root' AND (INFO LIKE '%information_schema.TABLES%' OR INFO LIKE '%information_schema.COLUMNS%' OR INFO LIKE '%information_schema.USER_PRIVILEGES%' OR INFO LIKE '%information_schema.SCHEMA_PRIVILEGES%' OR INFO LIKE '%mysql.user%' OR INFO LIKE '%mysql.db%' OR INFO LIKE '%SHOW GRANTS%' OR INFO LIKE '%SHOW CREATE TABLE%')"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Schema reconnaissance detected - user querying system tables to enumerate objects, users, or privileges", "severity": "high"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC11', 'mysql',
        'Detect schema reconnaissance activity (mysql)',
        'Detection path for Schema reconnaissance activity on mysql',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= mysql RC12 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('mysql', 'sql_query',
        'Detect dormant accounts with active transactions',
        $body${"sql": "SELECT p.USER AS login_name, p.HOST AS host_name, p.DB AS database_name, p.TIME AS elapsed_sec, LEFT(p.INFO, 500) AS query_text, u.password_last_changed, DATEDIFF(NOW(), u.password_last_changed) AS days_since_pwd_change FROM information_schema.PROCESSLIST p JOIN mysql.user u ON p.USER = u.User WHERE p.COMMAND != 'Sleep' AND p.ID != CONNECTION_ID() AND u.password_last_changed IS NOT NULL AND DATEDIFF(NOW(), u.password_last_changed) > 90"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Account with password unchanged for 90+ days is running transactions - possible dormant account", "severity": "high"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC12', 'mysql',
        'Detect dormant account suddenly active (mysql)',
        'Detection path for Dormant account suddenly active on mysql',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;

-- ======================= mysql RC13 (1 step) =======================
DO $$
DECLARE
    v_path_id int;
    v_step1_id int;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('mysql', 'sql_query',
        'Detect mass data modification in active transactions',
        $body${"sql": "SELECT p.USER AS login_name, p.HOST AS host_name, p.DB AS database_name, p.TIME AS elapsed_sec, LEFT(p.INFO, 500) AS query_text, CASE WHEN p.INFO LIKE 'UPDATE%' THEN 'UPDATE' WHEN p.INFO LIKE 'DELETE%' THEN 'DELETE' WHEN p.INFO LIKE 'TRUNCATE%' THEN 'TRUNCATE' END AS operation FROM information_schema.PROCESSLIST p WHERE p.COMMAND != 'Sleep' AND p.ID != CONNECTION_ID() AND p.INFO IS NOT NULL AND (p.INFO LIKE 'DELETE%' OR p.INFO LIKE 'TRUNCATE%' OR (p.INFO LIKE 'UPDATE%' AND p.TIME > 30))"}$body$::jsonb,
        $body${"condition": "row_count > 0", "description": "Mass DELETE/UPDATE/TRUNCATE detected in active transactions - potential data destruction", "severity": "critical"}$body$::jsonb
    ) RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-ACC-010-RC13', 'mysql',
        'Detect mass data modification in transactions (mysql)',
        'Detection path for Mass data modification in transactions on mysql',
        'primary', true
    ) RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES (v_path_id, v_step1_id, 1, 'confirmed', 'ruled_out');
END $$;


-- =============================================================================
-- 4. RESOLUTION PATHS, STEPS, AND PATH_STEPS
--    For each root cause (RC01-RC13), per vendor, define how to resolve/mitigate
-- =============================================================================

-- ======================= RC01: Unknown login — Resolution =======================
-- sqlserver
DO $$
DECLARE v_path_id int; v_s1 int; v_s2 int; v_s3 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, rollback, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('sqlserver', 'investigate', 'Identify unknown logins and their source',
        $body${"sql": "SELECT s.login_name, s.host_name, s.program_name, s.login_time, s.status, COUNT(*) AS session_count FROM sys.dm_exec_sessions s WHERE s.is_user_process = 1 AND s.login_name NOT IN (SELECT name FROM sys.server_principals WHERE is_disabled = 0 AND type IN ('S','U','G')) GROUP BY s.login_name, s.host_name, s.program_name, s.login_time, s.status", "description": "List all active sessions from logins not in the known principals list"}$body$::jsonb,
        NULL, 'low', false, true, '5 minutes')
    RETURNING id INTO v_s1;

    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, rollback, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('sqlserver', 'execute', 'Disable the unknown login',
        $body${"sql": "ALTER LOGIN [{login_name}] DISABLE;", "parameters": ["login_name"], "description": "Disable the unauthorized login to prevent further access"}$body$::jsonb,
        $body${"sql": "ALTER LOGIN [{login_name}] ENABLE;"}$body$::jsonb,
        'medium', true, true, '1 minute')
    RETURNING id INTO v_s2;

    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, rollback, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('sqlserver', 'verify', 'Verify unknown login sessions are terminated',
        $body${"sql": "SELECT session_id, login_name, status FROM sys.dm_exec_sessions WHERE login_name = '{login_name}' AND is_user_process = 1", "description": "Confirm no active sessions remain for the disabled login"}$body$::jsonb,
        NULL, 'low', false, true, '2 minutes')
    RETURNING id INTO v_s3;

    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC01', 'sqlserver', 'Disable unknown login and terminate sessions', 'disable-unknown-login-sqlserver',
        'Identify, disable, and verify removal of unknown logins executing queries', 'semi_automatic', 'medium', 'active', true)
    RETURNING id INTO v_path_id;

    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'next', 'stop');
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s2, 2, 'next', 'stop');
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s3, 3, 'done', 'stop');
END $$;

-- postgresql
DO $$
DECLARE v_path_id int; v_s1 int; v_s2 int; v_s3 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, rollback, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('postgresql', 'investigate', 'Identify unknown logins and their source',
        $body${"sql": "SELECT usename, client_addr, application_name, backend_start, state, COUNT(*) AS session_count FROM pg_stat_activity WHERE usename NOT IN (SELECT rolname FROM pg_roles WHERE rolcanlogin = true) AND pid != pg_backend_pid() GROUP BY usename, client_addr, application_name, backend_start, state", "description": "List sessions from logins not in pg_roles"}$body$::jsonb,
        NULL, 'low', false, true, '5 minutes')
    RETURNING id INTO v_s1;

    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, rollback, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('postgresql', 'execute', 'Revoke login and terminate sessions',
        $body${"sql": "ALTER ROLE {login_name} NOLOGIN; SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = '{login_name}';", "parameters": ["login_name"], "description": "Revoke login privilege and kill active sessions"}$body$::jsonb,
        $body${"sql": "ALTER ROLE {login_name} LOGIN;"}$body$::jsonb,
        'medium', true, true, '1 minute')
    RETURNING id INTO v_s2;

    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, rollback, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('postgresql', 'verify', 'Verify unknown login sessions are terminated',
        $body${"sql": "SELECT pid, usename, state FROM pg_stat_activity WHERE usename = '{login_name}'", "description": "Confirm no active sessions remain"}$body$::jsonb,
        NULL, 'low', false, true, '2 minutes')
    RETURNING id INTO v_s3;

    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC01', 'postgresql', 'Revoke unknown login and terminate sessions', 'disable-unknown-login-postgresql',
        'Identify, revoke login, and verify removal of unknown logins', 'semi_automatic', 'medium', 'active', true)
    RETURNING id INTO v_path_id;

    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'next', 'stop');
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s2, 2, 'next', 'stop');
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s3, 3, 'done', 'stop');
END $$;

-- oracle
DO $$
DECLARE v_path_id int; v_s1 int; v_s2 int; v_s3 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, rollback, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('oracle', 'investigate', 'Identify unknown logins and their source',
        $body${"sql": "SELECT s.username, s.machine, s.program, s.logon_time, s.status, COUNT(*) AS session_count FROM v$session s WHERE s.type = 'USER' AND s.username NOT IN (SELECT username FROM dba_users WHERE account_status = 'OPEN') GROUP BY s.username, s.machine, s.program, s.logon_time, s.status", "description": "List sessions from accounts not in dba_users as OPEN"}$body$::jsonb,
        NULL, 'low', false, true, '5 minutes')
    RETURNING id INTO v_s1;

    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, rollback, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('oracle', 'execute', 'Lock the unknown account and kill sessions',
        $body${"sql": "ALTER USER {login_name} ACCOUNT LOCK;", "parameters": ["login_name"], "description": "Lock the unauthorized account"}$body$::jsonb,
        $body${"sql": "ALTER USER {login_name} ACCOUNT UNLOCK;"}$body$::jsonb,
        'medium', true, true, '1 minute')
    RETURNING id INTO v_s2;

    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, rollback, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('oracle', 'verify', 'Verify unknown login sessions are terminated',
        $body${"sql": "SELECT sid, serial#, username, status FROM v$session WHERE username = '{login_name}'", "description": "Confirm no active sessions remain"}$body$::jsonb,
        NULL, 'low', false, true, '2 minutes')
    RETURNING id INTO v_s3;

    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC01', 'oracle', 'Lock unknown account and terminate sessions', 'disable-unknown-login-oracle',
        'Identify, lock, and verify removal of unknown logins', 'semi_automatic', 'medium', 'active', true)
    RETURNING id INTO v_path_id;

    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'next', 'stop');
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s2, 2, 'next', 'stop');
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s3, 3, 'done', 'stop');
END $$;

-- mysql
DO $$
DECLARE v_path_id int; v_s1 int; v_s2 int; v_s3 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, rollback, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('mysql', 'investigate', 'Identify unknown logins and their source',
        $body${"sql": "SELECT USER, HOST, DB, COMMAND, TIME FROM information_schema.PROCESSLIST WHERE USER NOT IN (SELECT User FROM mysql.user) AND COMMAND != 'Sleep'", "description": "List sessions from logins not in mysql.user"}$body$::jsonb,
        NULL, 'low', false, true, '5 minutes')
    RETURNING id INTO v_s1;

    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, rollback, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('mysql', 'execute', 'Lock the unknown account',
        $body${"sql": "ALTER USER '{login_name}'@'%' ACCOUNT LOCK;", "parameters": ["login_name"], "description": "Lock the unauthorized account"}$body$::jsonb,
        $body${"sql": "ALTER USER '{login_name}'@'%' ACCOUNT UNLOCK;"}$body$::jsonb,
        'medium', true, true, '1 minute')
    RETURNING id INTO v_s2;

    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, rollback, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('mysql', 'verify', 'Verify unknown login sessions are terminated',
        $body${"sql": "SELECT ID, USER, HOST, DB FROM information_schema.PROCESSLIST WHERE USER = '{login_name}'", "description": "Confirm no active sessions remain"}$body$::jsonb,
        NULL, 'low', false, true, '2 minutes')
    RETURNING id INTO v_s3;

    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC01', 'mysql', 'Lock unknown account and terminate sessions', 'disable-unknown-login-mysql',
        'Identify, lock, and verify removal of unknown logins', 'semi_automatic', 'medium', 'active', true)
    RETURNING id INTO v_path_id;

    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'next', 'stop');
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s2, 2, 'next', 'stop');
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s3, 3, 'done', 'stop');
END $$;

-- ======================= RC02: Unexpected program — Resolution =======================
-- All vendors: Investigate, block program, verify
DO $$
DECLARE v_path_id int; v_s1 int; v_s2 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('sqlserver', 'investigate', 'Identify unexpected programs and kill their sessions',
        $body${"sql": "SELECT s.session_id, s.login_name, s.program_name, s.host_name FROM sys.dm_exec_sessions s WHERE s.is_user_process = 1 AND s.program_name NOT IN ('Microsoft SQL Server Management Studio','SQLAgent - TSQL JobStep','Report Server') ORDER BY s.program_name", "description": "List sessions from non-whitelisted programs. Kill suspicious ones with KILL {session_id}"}$body$::jsonb,
        'medium', true, true, '10 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('sqlserver', 'instruct', 'Configure login trigger to block unauthorized programs',
        $body${"sql": "CREATE OR ALTER TRIGGER trg_block_unauthorized_apps ON ALL SERVER FOR LOGON AS BEGIN IF APP_NAME() NOT IN ('Microsoft SQL Server Management Studio','SQLAgent - TSQL JobStep','Report Server','YourApp') ROLLBACK; END;", "description": "Create a logon trigger that rejects connections from unauthorized program names. Customize the whitelist."}$body$::jsonb,
        'high', true, true, '15 minutes')
    RETURNING id INTO v_s2;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC02', 'sqlserver', 'Block unexpected programs via logon trigger', 'block-unexpected-programs-sqlserver',
        'Kill suspicious sessions and optionally create a logon trigger to block unauthorized programs', 'manual', 'high', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'next', 'stop');
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s2, 2, 'done', 'stop');
END $$;

DO $$
DECLARE v_path_id int; v_s1 int; v_s2 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('postgresql', 'investigate', 'Identify unexpected applications and terminate sessions',
        $body${"sql": "SELECT pid, usename, application_name, client_addr FROM pg_stat_activity WHERE application_name NOT IN ('psql','pgAdmin','DBeaver','your_app') AND state != 'idle' AND pid != pg_backend_pid()", "description": "List sessions from non-whitelisted applications. Terminate with SELECT pg_terminate_backend(pid)"}$body$::jsonb,
        'medium', true, true, '10 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('postgresql', 'instruct', 'Configure pg_hba.conf to restrict application access',
        $body${"sql": null, "description": "Edit pg_hba.conf to restrict connections by application name or source IP. Add rules like: hostssl mydb myuser 10.0.0.0/8 scram-sha-256. Reload with SELECT pg_reload_conf();"}$body$::jsonb,
        'high', true, true, '15 minutes')
    RETURNING id INTO v_s2;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC02', 'postgresql', 'Terminate unexpected applications and restrict access', 'block-unexpected-programs-postgresql',
        'Kill suspicious sessions and restrict access via pg_hba.conf', 'manual', 'high', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'next', 'stop');
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s2, 2, 'done', 'stop');
END $$;

DO $$
DECLARE v_path_id int; v_s1 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('oracle', 'instruct', 'Identify and kill unexpected program sessions, restrict via profile',
        $body${"sql": "SELECT sid, serial#, username, program, machine FROM v$session WHERE type = 'USER' AND status = 'ACTIVE' AND program NOT IN ('sqlplus.exe','JDBC Thin Client','your_app')", "description": "List unexpected programs. Kill with ALTER SYSTEM KILL SESSION 'sid,serial#'. Use Oracle profiles to restrict program access."}$body$::jsonb,
        'medium', true, true, '15 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC02', 'oracle', 'Kill unexpected program sessions', 'block-unexpected-programs-oracle',
        'Identify and terminate sessions from unauthorized programs', 'manual', 'medium', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;

DO $$
DECLARE v_path_id int; v_s1 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('mysql', 'instruct', 'Identify and kill unexpected program sessions',
        $body${"sql": "SELECT ID, USER, HOST, DB, COMMAND, INFO FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep' AND ID != CONNECTION_ID()", "description": "List all active sessions. Kill suspicious ones with KILL {ID}. Use bind-address and firewall rules to restrict access by source."}$body$::jsonb,
        'medium', true, true, '10 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC02', 'mysql', 'Kill unexpected program sessions', 'block-unexpected-programs-mysql',
        'Identify and terminate sessions from unauthorized programs', 'manual', 'medium', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;

-- ======================= RC03: Unexpected database — Resolution =======================
-- All vendors: instruct to review and restrict database-level permissions
DO $$
DECLARE v_path_id int; v_s1 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('sqlserver', 'instruct', 'Review and restrict database access permissions',
        $body${"sql": "SELECT dp.name AS principal, dp.type_desc, dbp.permission_name, dbp.state_desc FROM sys.database_permissions dbp JOIN sys.database_principals dp ON dbp.grantee_principal_id = dp.principal_id WHERE dbp.state_desc = 'GRANT'", "description": "Review database-level permissions. Revoke unnecessary access with REVOKE CONNECT FROM [{login}]. Ensure least-privilege model."}$body$::jsonb,
        'medium', true, true, '15 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC03', 'sqlserver', 'Review and restrict database access', 'restrict-db-access-sqlserver',
        'Audit and restrict which logins can access which databases', 'manual', 'medium', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;

DO $$
DECLARE v_path_id int; v_s1 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('postgresql', 'instruct', 'Review and restrict database access permissions',
        $body${"sql": "SELECT grantee, privilege_type, table_catalog FROM information_schema.role_table_grants WHERE grantee NOT IN ('postgres') ORDER BY grantee", "description": "Review grants. Revoke access with REVOKE CONNECT ON DATABASE {db} FROM {role}. Use pg_hba.conf for IP-level restrictions."}$body$::jsonb,
        'medium', true, true, '15 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC03', 'postgresql', 'Review and restrict database access', 'restrict-db-access-postgresql',
        'Audit and restrict which roles can access which databases', 'manual', 'medium', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;

DO $$
DECLARE v_path_id int; v_s1 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('oracle', 'instruct', 'Review and restrict schema access permissions',
        $body${"sql": "SELECT grantee, privilege, table_name FROM dba_tab_privs WHERE grantee NOT IN ('SYS','SYSTEM') ORDER BY grantee", "description": "Review schema grants. Revoke with REVOKE {privilege} ON {schema}.{table} FROM {user}. Use Oracle profiles for access control."}$body$::jsonb,
        'medium', true, true, '15 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC03', 'oracle', 'Review and restrict schema access', 'restrict-db-access-oracle',
        'Audit and restrict which users can access which schemas', 'manual', 'medium', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;

DO $$
DECLARE v_path_id int; v_s1 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('mysql', 'instruct', 'Review and restrict database access permissions',
        $body${"sql": "SELECT User, Host, Db, Select_priv, Insert_priv, Update_priv, Delete_priv FROM mysql.db ORDER BY User", "description": "Review database grants. Revoke with REVOKE ALL ON {db}.* FROM '{user}'@'{host}'. Use GRANT with specific privileges only."}$body$::jsonb,
        'medium', true, true, '15 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC03', 'mysql', 'Review and restrict database access', 'restrict-db-access-mysql',
        'Audit and restrict which users can access which databases', 'manual', 'medium', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;

-- ======================= RC04: Suspicious patterns — Resolution =======================
-- All vendors: Kill session, investigate, enable auditing
DO $$
DECLARE v_path_id int; v_s1 int; v_s2 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('sqlserver', 'execute', 'Kill sessions with suspicious query patterns',
        $body${"sql": "-- Kill specific session: KILL {session_id}\n-- Review first with:\nSELECT s.session_id, s.login_name, s.program_name, SUBSTRING(t.text, 1, 200) AS query_text FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE s.is_user_process = 1", "description": "Review and kill sessions executing suspicious queries"}$body$::jsonb,
        'high', true, false, '5 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('sqlserver', 'instruct', 'Enable Extended Events auditing for suspicious activity',
        $body${"sql": null, "description": "Enable SQL Server Audit or Extended Events to capture suspicious queries. Create an audit specification targeting SELECT, EXECUTE on sensitive objects. Review audit logs regularly."}$body$::jsonb,
        'low', false, true, '30 minutes')
    RETURNING id INTO v_s2;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC04', 'sqlserver', 'Kill suspicious sessions and enable auditing', 'kill-suspicious-sqlserver',
        'Terminate suspicious queries and enable audit trail', 'semi_automatic', 'high', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'next', 'stop');
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s2, 2, 'done', 'stop');
END $$;

DO $$
DECLARE v_path_id int; v_s1 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('postgresql', 'instruct', 'Terminate suspicious sessions and enable pgaudit',
        $body${"sql": "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid != pg_backend_pid() AND state != 'idle' AND (query ILIKE '%pg_shadow%' OR query ILIKE '%pg_authid%' OR query ILIKE '%COPY%TO%')", "description": "Kill suspicious sessions. Install and configure pgaudit extension for ongoing monitoring: shared_preload_libraries = 'pgaudit', pgaudit.log = 'ddl,role,write'"}$body$::jsonb,
        'high', true, false, '30 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC04', 'postgresql', 'Terminate suspicious sessions and enable auditing', 'kill-suspicious-postgresql',
        'Kill suspicious queries and enable pgaudit', 'semi_automatic', 'high', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;

DO $$
DECLARE v_path_id int; v_s1 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('oracle', 'instruct', 'Kill suspicious sessions and enable unified auditing',
        $body${"sql": "-- Kill: ALTER SYSTEM KILL SESSION 'sid,serial#' IMMEDIATE;\n-- Enable unified audit: CREATE AUDIT POLICY suspicious_activity ACTIONS SELECT ON SYS.DBA_USERS, EXECUTE ON SYS.UTL_FILE; AUDIT POLICY suspicious_activity;", "description": "Kill suspicious sessions and enable Oracle Unified Auditing for sensitive operations"}$body$::jsonb,
        'high', true, false, '30 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC04', 'oracle', 'Kill suspicious sessions and enable auditing', 'kill-suspicious-oracle',
        'Kill suspicious queries and enable unified auditing', 'semi_automatic', 'high', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;

DO $$
DECLARE v_path_id int; v_s1 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('mysql', 'instruct', 'Kill suspicious sessions and enable general log',
        $body${"sql": "-- Kill: KILL {process_id};\n-- Enable audit: SET GLOBAL general_log = 'ON'; SET GLOBAL log_output = 'TABLE';\n-- Or install audit_log plugin for enterprise", "description": "Kill suspicious sessions and enable general query log or audit plugin for monitoring"}$body$::jsonb,
        'high', true, false, '15 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC04', 'mysql', 'Kill suspicious sessions and enable auditing', 'kill-suspicious-mysql',
        'Kill suspicious queries and enable query logging', 'semi_automatic', 'high', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;

-- ======================= RC05: PII access — Resolution (all vendors same pattern) =======================
DO $$
DECLARE v_path_id int; v_s1 int; v_s2 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('sqlserver', 'instruct', 'Apply dynamic data masking to PII columns',
        $body${"sql": "ALTER TABLE {schema}.{table} ALTER COLUMN {column} ADD MASKED WITH (FUNCTION = 'partial(1,\"***\",1)');", "parameters": ["schema","table","column"], "description": "Apply SQL Server Dynamic Data Masking to identified PII columns. Non-privileged users will see masked values."}$body$::jsonb,
        'medium', true, true, '30 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('sqlserver', 'instruct', 'Restrict UNMASK permission',
        $body${"sql": "REVOKE UNMASK FROM [{user}];", "parameters": ["user"], "description": "Ensure only authorized users have UNMASK permission to see actual PII data"}$body$::jsonb,
        'medium', true, true, '10 minutes')
    RETURNING id INTO v_s2;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC05', 'sqlserver', 'Apply data masking to PII columns', 'mask-pii-sqlserver',
        'Apply dynamic data masking and restrict UNMASK permissions', 'manual', 'medium', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'next', 'stop');
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s2, 2, 'done', 'stop');
END $$;

DO $$
DECLARE v_path_id int; v_s1 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('postgresql', 'instruct', 'Restrict PII column access with column-level privileges',
        $body${"sql": "REVOKE SELECT ({column}) ON {schema}.{table} FROM {role};", "parameters": ["schema","table","column","role"], "description": "Revoke SELECT on PII columns from non-authorized roles. Consider using row-level security or views that exclude PII columns."}$body$::jsonb,
        'medium', true, true, '30 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC05', 'postgresql', 'Restrict PII column access', 'restrict-pii-postgresql',
        'Revoke column-level SELECT on PII columns from non-authorized roles', 'manual', 'medium', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;

DO $$
DECLARE v_path_id int; v_s1 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('oracle', 'instruct', 'Apply Oracle Data Redaction to PII columns',
        $body${"sql": "BEGIN DBMS_REDACT.ADD_POLICY(object_schema => '{schema}', object_name => '{table}', column_name => '{column}', policy_name => 'redact_{column}', function_type => DBMS_REDACT.PARTIAL, expression => '1=1'); END;", "parameters": ["schema","table","column"], "description": "Apply Oracle Data Redaction to mask PII columns for non-privileged users"}$body$::jsonb,
        'medium', true, true, '30 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC05', 'oracle', 'Apply data redaction to PII columns', 'redact-pii-oracle',
        'Apply Oracle Data Redaction policies to mask PII', 'manual', 'medium', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;

DO $$
DECLARE v_path_id int; v_s1 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('mysql', 'instruct', 'Restrict PII access via views and column grants',
        $body${"sql": "-- Create a view excluding PII columns:\n-- CREATE VIEW {schema}.v_{table}_safe AS SELECT non_pii_col1, non_pii_col2 FROM {schema}.{table};\n-- Grant access to view only:\n-- GRANT SELECT ON {schema}.v_{table}_safe TO '{user}'@'%';", "description": "Create views that exclude PII columns and grant access to views instead of base tables"}$body$::jsonb,
        'medium', true, true, '30 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC05', 'mysql', 'Restrict PII access via views', 'restrict-pii-mysql',
        'Create PII-safe views and restrict direct table access', 'manual', 'medium', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;

-- ======================= RC06: SQL injection — Resolution (all vendors) =======================
DO $$
DECLARE v_path_id int; v_s1 int; v_s2 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('sqlserver', 'execute', 'Kill sessions with SQL injection patterns immediately',
        $body${"sql": "-- KILL {session_id} for each session identified by detection\n-- Review with:\nSELECT s.session_id, s.login_name, s.host_name, SUBSTRING(t.text,1,200) FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE s.is_user_process = 1", "description": "Immediately kill sessions exhibiting SQL injection patterns"}$body$::jsonb,
        'high', true, false, '2 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('sqlserver', 'instruct', 'Block source IP and notify security team',
        $body${"sql": null, "description": "Block the source IP at firewall level. Disable the compromised login if application account. Notify security team for incident response. Review application for parameterized query usage."}$body$::jsonb,
        'high', true, false, '15 minutes')
    RETURNING id INTO v_s2;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC06', 'sqlserver', 'Kill injection sessions and block source', 'block-sqli-sqlserver',
        'Immediately terminate SQL injection sessions and block source', 'semi_automatic', 'critical', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'next', 'stop');
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s2, 2, 'done', 'stop');
END $$;

DO $$
DECLARE v_path_id int; v_s1 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('postgresql', 'instruct', 'Terminate injection sessions and block source',
        $body${"sql": "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state != 'idle' AND pid != pg_backend_pid() AND (query ILIKE '%OR 1=1%' OR query ILIKE '%UNION%SELECT%' OR query ILIKE '%pg_sleep%')", "description": "Kill injection sessions. Block source IP via pg_hba.conf with reject rule. Notify security team."}$body$::jsonb,
        'high', true, false, '5 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC06', 'postgresql', 'Terminate injection sessions and block source', 'block-sqli-postgresql',
        'Kill SQL injection sessions and block source IP', 'semi_automatic', 'critical', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;

DO $$
DECLARE v_path_id int; v_s1 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('oracle', 'instruct', 'Kill injection sessions and block source',
        $body${"sql": "-- Kill: ALTER SYSTEM KILL SESSION 'sid,serial#' IMMEDIATE;\n-- Block via Oracle Net listener.ora or firewall", "description": "Immediately kill injection sessions. Block source via Oracle Net or firewall. Enable unified auditing for forensics."}$body$::jsonb,
        'high', true, false, '5 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC06', 'oracle', 'Kill injection sessions and block source', 'block-sqli-oracle',
        'Kill SQL injection sessions and block source', 'semi_automatic', 'critical', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;

DO $$
DECLARE v_path_id int; v_s1 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('mysql', 'instruct', 'Kill injection sessions and block source',
        $body${"sql": "-- Kill: KILL {process_id};\n-- Block source IP via firewall or MySQL bind-address restriction", "description": "Kill injection sessions. Block source IP at firewall. Review application for prepared statements usage."}$body$::jsonb,
        'high', true, false, '5 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC06', 'mysql', 'Kill injection sessions and block source', 'block-sqli-mysql',
        'Kill SQL injection sessions and block source', 'semi_automatic', 'critical', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;

-- ======================= RC07-RC13: Simplified resolutions (all vendors, instruct type) =======================
-- RC07: After-hours — instruct to review and set up time-based access restrictions
-- RC08: Privilege escalation — instruct to revoke privileges and audit
-- RC09: Data exfiltration — instruct to kill, block, and investigate
-- RC10: Multi-host login — instruct to force password reset and enable MFA
-- RC11: Schema recon — instruct to restrict catalog access and enable audit
-- RC12: Dormant account — instruct to disable account and review
-- RC13: Mass modification — instruct to kill transaction, restore from backup if needed

DO $$
DECLARE v_path_id int; v_s1 int;
BEGIN
    -- RC07 sqlserver
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('sqlserver', 'instruct', 'Restrict after-hours access via logon trigger',
        $body${"sql": "CREATE OR ALTER TRIGGER trg_restrict_after_hours ON ALL SERVER FOR LOGON AS BEGIN IF DATEPART(HOUR, GETDATE()) < 6 OR DATEPART(HOUR, GETDATE()) >= 22 BEGIN IF ORIGINAL_LOGIN() NOT IN ('sa','scheduled_job_account') ROLLBACK; END; END;", "description": "Create logon trigger to reject non-service connections outside business hours. Customize the whitelist of allowed after-hours accounts."}$body$::jsonb,
        'high', true, true, '15 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC07', 'sqlserver', 'Restrict after-hours database access', 'restrict-after-hours-sqlserver', 'Create logon trigger to block after-hours access', 'manual', 'high', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;

DO $$
DECLARE v_path_id int; v_s1 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('postgresql', 'instruct', 'Restrict after-hours access via pg_hba.conf time rules',
        $body${"sql": null, "description": "PostgreSQL does not natively support time-based access. Use a cron job to modify pg_hba.conf and reload, or use a connection pooler (pgbouncer) with time-based rules. Alternatively create a function called on login that checks the hour."}$body$::jsonb,
        'medium', true, true, '30 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC07', 'postgresql', 'Restrict after-hours database access', 'restrict-after-hours-postgresql', 'Implement time-based access controls', 'manual', 'medium', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;

DO $$
DECLARE v_path_id int; v_s1 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('oracle', 'instruct', 'Restrict after-hours access via Oracle profile',
        $body${"sql": "CREATE PROFILE restrict_hours LIMIT CONNECT_TIME 960; ALTER USER {username} PROFILE restrict_hours;", "parameters": ["username"], "description": "Use Oracle profiles and database triggers to restrict logon outside business hours. Create an AFTER LOGON trigger that checks SYSDATE."}$body$::jsonb,
        'medium', true, true, '20 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC07', 'oracle', 'Restrict after-hours database access', 'restrict-after-hours-oracle', 'Use profiles and triggers for time-based access', 'manual', 'medium', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;

DO $$
DECLARE v_path_id int; v_s1 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('mysql', 'instruct', 'Restrict after-hours access via connection control plugin',
        $body${"sql": null, "description": "Use MySQL connection control plugin or firewall rules to restrict access outside business hours. Alternatively use ProxySQL or MySQL Router with time-based routing rules."}$body$::jsonb,
        'medium', true, true, '20 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC07', 'mysql', 'Restrict after-hours database access', 'restrict-after-hours-mysql', 'Implement time-based access restrictions', 'manual', 'medium', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;

-- RC08: Privilege escalation — all vendors
DO $$
DECLARE v_path_id int; v_s1 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('sqlserver', 'instruct', 'Revoke excessive privileges and audit DDL/DCL',
        $body${"sql": "-- Revoke: REVOKE ALTER ANY LOGIN FROM [{user}];\n-- Enable DDL trigger: CREATE TRIGGER trg_audit_ddl ON DATABASE FOR DDL_DATABASE_LEVEL_EVENTS AS BEGIN INSERT INTO audit.ddl_log SELECT EVENTDATA(); END;", "description": "Revoke excessive privileges from the offending account. Create DDL triggers to audit future privilege changes."}$body$::jsonb,
        'high', true, true, '15 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC08', 'sqlserver', 'Revoke privileges and enable DDL audit', 'revoke-privesc-sqlserver', 'Revoke excessive privileges and audit DDL changes', 'manual', 'high', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;

DO $$
DECLARE v_path_id int; v_s1 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('postgresql', 'instruct', 'Revoke excessive privileges and enable event triggers',
        $body${"sql": "-- Revoke: REVOKE CREATE ON DATABASE {db} FROM {role};\n-- Event trigger: CREATE EVENT TRIGGER audit_ddl ON ddl_command_end EXECUTE FUNCTION log_ddl_event();", "description": "Revoke DDL/DCL privileges. Create event triggers to audit schema changes."}$body$::jsonb,
        'high', true, true, '15 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC08', 'postgresql', 'Revoke privileges and enable event triggers', 'revoke-privesc-postgresql', 'Revoke excessive privileges and audit DDL', 'manual', 'high', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;

DO $$
DECLARE v_path_id int; v_s1 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('oracle', 'instruct', 'Revoke excessive privileges and enable privilege auditing',
        $body${"sql": "-- Revoke: REVOKE CREATE USER FROM {user}; REVOKE ALTER USER FROM {user};\n-- Audit: AUDIT CREATE USER, ALTER USER, GRANT BY ACCESS;", "description": "Revoke excessive system privileges. Enable auditing on privilege-related operations."}$body$::jsonb,
        'high', true, true, '15 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC08', 'oracle', 'Revoke privileges and enable audit', 'revoke-privesc-oracle', 'Revoke excessive privileges and audit changes', 'manual', 'high', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;

DO $$
DECLARE v_path_id int; v_s1 int;
BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration)
    VALUES ('mysql', 'instruct', 'Revoke excessive privileges',
        $body${"sql": "-- Revoke: REVOKE ALL PRIVILEGES, GRANT OPTION FROM '{user}'@'{host}';\n-- Re-grant minimum required: GRANT SELECT, INSERT ON {db}.* TO '{user}'@'{host}';", "description": "Revoke all privileges and re-grant minimum required. Review mysql.user for excessive SUPER or GRANT privileges."}$body$::jsonb,
        'high', true, true, '15 minutes')
    RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
    VALUES ('SEC-SQL-ACC-010-RC08', 'mysql', 'Revoke excessive privileges', 'revoke-privesc-mysql', 'Revoke and re-grant minimum privileges', 'manual', 'high', 'active', true)
    RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;

-- RC09-RC13: Generic resolution pattern per vendor (investigate + remediate)
-- Using a simplified approach: one instruct step per vendor per RC

-- RC09: Data exfiltration
DO $$ DECLARE v_path_id int; v_s1 int; BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration) VALUES ('sqlserver', 'instruct', 'Kill exfiltration sessions, block source, investigate', $body${"sql": null, "description": "1) Kill sessions: KILL {session_id}. 2) Block source IP at firewall. 3) Disable linked servers if abused: EXEC sp_dropserver '{linked_server}'. 4) Review and restrict BULK INSERT, BCP permissions. 5) Engage incident response."}$body$::jsonb, 'critical', true, false, '30 minutes') RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active) VALUES ('SEC-SQL-ACC-010-RC09', 'sqlserver', 'Stop data exfiltration and investigate', 'stop-exfil-sqlserver', 'Kill sessions, block source, disable linked servers', 'manual', 'critical', 'active', true) RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;
DO $$ DECLARE v_path_id int; v_s1 int; BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration) VALUES ('postgresql', 'instruct', 'Kill exfiltration sessions, block source, investigate', $body${"sql": null, "description": "1) Kill sessions: SELECT pg_terminate_backend(pid). 2) Block source IP in pg_hba.conf. 3) Revoke COPY permissions. 4) Disable foreign data wrappers if abused. 5) Engage incident response."}$body$::jsonb, 'critical', true, false, '30 minutes') RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active) VALUES ('SEC-SQL-ACC-010-RC09', 'postgresql', 'Stop data exfiltration and investigate', 'stop-exfil-postgresql', 'Kill sessions, block source, restrict COPY', 'manual', 'critical', 'active', true) RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;
DO $$ DECLARE v_path_id int; v_s1 int; BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration) VALUES ('oracle', 'instruct', 'Kill exfiltration sessions, block source, investigate', $body${"sql": null, "description": "1) Kill sessions: ALTER SYSTEM KILL SESSION. 2) Block source via listener.ora or firewall. 3) Revoke UTL_FILE, UTL_HTTP execute grants. 4) Drop unauthorized database links. 5) Engage incident response."}$body$::jsonb, 'critical', true, false, '30 minutes') RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active) VALUES ('SEC-SQL-ACC-010-RC09', 'oracle', 'Stop data exfiltration and investigate', 'stop-exfil-oracle', 'Kill sessions, block source, revoke UTL grants', 'manual', 'critical', 'active', true) RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;
DO $$ DECLARE v_path_id int; v_s1 int; BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration) VALUES ('mysql', 'instruct', 'Kill exfiltration sessions, block source, investigate', $body${"sql": null, "description": "1) Kill sessions: KILL {process_id}. 2) Block source IP at firewall. 3) Revoke FILE privilege: REVOKE FILE ON *.* FROM user. 4) Disable LOAD_FILE, INTO OUTFILE via secure_file_priv. 5) Engage incident response."}$body$::jsonb, 'critical', true, false, '30 minutes') RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active) VALUES ('SEC-SQL-ACC-010-RC09', 'mysql', 'Stop data exfiltration and investigate', 'stop-exfil-mysql', 'Kill sessions, block source, revoke FILE privilege', 'manual', 'critical', 'active', true) RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;

-- RC10: Multi-host login
DO $$ DECLARE v_path_id int; v_s1 int; BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration) VALUES ('sqlserver', 'instruct', 'Force password reset and investigate multi-host sessions', $body${"sql": "ALTER LOGIN [{login_name}] WITH PASSWORD = '{new_password}' MUST_CHANGE;", "parameters": ["login_name","new_password"], "description": "Force password reset for the compromised login. Kill all existing sessions. Investigate source IPs. Enable MFA if supported."}$body$::jsonb, 'high', true, true, '15 minutes') RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active) VALUES ('SEC-SQL-ACC-010-RC10', 'sqlserver', 'Force password reset for multi-host login', 'reset-multihost-sqlserver', 'Reset password and investigate credential compromise', 'semi_automatic', 'high', 'active', true) RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;
DO $$ DECLARE v_path_id int; v_s1 int; BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration) VALUES ('postgresql', 'instruct', 'Force password reset and restrict hosts', $body${"sql": "ALTER ROLE {login_name} PASSWORD '{new_password}' VALID UNTIL now() + interval '24 hours';", "parameters": ["login_name","new_password"], "description": "Reset password with short expiry. Terminate all sessions. Restrict source IPs in pg_hba.conf."}$body$::jsonb, 'high', true, true, '15 minutes') RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active) VALUES ('SEC-SQL-ACC-010-RC10', 'postgresql', 'Force password reset for multi-host login', 'reset-multihost-postgresql', 'Reset password and restrict hosts', 'semi_automatic', 'high', 'active', true) RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;
DO $$ DECLARE v_path_id int; v_s1 int; BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration) VALUES ('oracle', 'instruct', 'Force password reset and investigate', $body${"sql": "ALTER USER {login_name} IDENTIFIED BY {new_password} PASSWORD EXPIRE;", "parameters": ["login_name","new_password"], "description": "Reset and expire password. Kill all sessions. Review v$session for source machines."}$body$::jsonb, 'high', true, true, '15 minutes') RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active) VALUES ('SEC-SQL-ACC-010-RC10', 'oracle', 'Force password reset for multi-host login', 'reset-multihost-oracle', 'Reset password and investigate', 'semi_automatic', 'high', 'active', true) RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;
DO $$ DECLARE v_path_id int; v_s1 int; BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration) VALUES ('mysql', 'instruct', 'Force password reset and restrict hosts', $body${"sql": "ALTER USER '{login_name}'@'%' IDENTIFIED BY '{new_password}' PASSWORD EXPIRE;", "parameters": ["login_name","new_password"], "description": "Reset and expire password. Kill sessions. Restrict host in user grants."}$body$::jsonb, 'high', true, true, '15 minutes') RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active) VALUES ('SEC-SQL-ACC-010-RC10', 'mysql', 'Force password reset for multi-host login', 'reset-multihost-mysql', 'Reset password and restrict hosts', 'semi_automatic', 'high', 'active', true) RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;

-- RC11: Schema recon
DO $$ DECLARE v_path_id int; v_s1 int; BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration) VALUES ('sqlserver', 'instruct', 'Restrict catalog access and enable auditing', $body${"sql": null, "description": "1) Deny VIEW DEFINITION: DENY VIEW ANY DEFINITION TO [{user}]. 2) Enable metadata visibility configuration. 3) Set up Extended Events to audit catalog queries. 4) Investigate the user intent."}$body$::jsonb, 'medium', true, true, '20 minutes') RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active) VALUES ('SEC-SQL-ACC-010-RC11', 'sqlserver', 'Restrict catalog access', 'restrict-recon-sqlserver', 'Deny VIEW DEFINITION and audit catalog access', 'manual', 'medium', 'active', true) RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;
DO $$ DECLARE v_path_id int; v_s1 int; BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration) VALUES ('postgresql', 'instruct', 'Restrict catalog access and enable pgaudit', $body${"sql": null, "description": "1) Revoke SELECT on pg_catalog tables from non-admin roles where possible. 2) Use pgaudit to log catalog access. 3) Consider using security-barrier views. 4) Investigate user intent."}$body$::jsonb, 'medium', true, true, '20 minutes') RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active) VALUES ('SEC-SQL-ACC-010-RC11', 'postgresql', 'Restrict catalog access', 'restrict-recon-postgresql', 'Restrict and audit catalog access', 'manual', 'medium', 'active', true) RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;
DO $$ DECLARE v_path_id int; v_s1 int; BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration) VALUES ('oracle', 'instruct', 'Restrict data dictionary access', $body${"sql": "ALTER SYSTEM SET O7_DICTIONARY_ACCESSIBILITY = FALSE;", "description": "Ensure O7_DICTIONARY_ACCESSIBILITY is FALSE. Revoke SELECT ANY DICTIONARY from non-DBA users. Audit dictionary access with unified auditing."}$body$::jsonb, 'medium', true, true, '15 minutes') RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active) VALUES ('SEC-SQL-ACC-010-RC11', 'oracle', 'Restrict dictionary access', 'restrict-recon-oracle', 'Restrict data dictionary access', 'manual', 'medium', 'active', true) RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;
DO $$ DECLARE v_path_id int; v_s1 int; BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration) VALUES ('mysql', 'instruct', 'Restrict information_schema access', $body${"sql": null, "description": "1) MySQL limits information_schema visibility by default to objects the user has access to. 2) Ensure users have minimal grants. 3) Enable general_log or audit_log plugin to track catalog queries. 4) Investigate user intent."}$body$::jsonb, 'medium', true, true, '15 minutes') RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active) VALUES ('SEC-SQL-ACC-010-RC11', 'mysql', 'Restrict schema metadata access', 'restrict-recon-mysql', 'Restrict and audit metadata access', 'manual', 'medium', 'active', true) RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;

-- RC12: Dormant account
DO $$ DECLARE v_path_id int; v_s1 int; BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration) VALUES ('sqlserver', 'instruct', 'Disable dormant account and investigate', $body${"sql": "ALTER LOGIN [{login_name}] DISABLE;", "parameters": ["login_name"], "description": "Disable the dormant login. Kill active sessions. Review login history in sys.dm_exec_sessions and SQL Server error log. Investigate if this is a legitimate reactivation or compromise."}$body$::jsonb, 'medium', true, true, '10 minutes') RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active) VALUES ('SEC-SQL-ACC-010-RC12', 'sqlserver', 'Disable dormant account', 'disable-dormant-sqlserver', 'Disable dormant login and investigate', 'semi_automatic', 'medium', 'active', true) RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;
DO $$ DECLARE v_path_id int; v_s1 int; BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration) VALUES ('postgresql', 'instruct', 'Disable dormant account and investigate', $body${"sql": "ALTER ROLE {login_name} NOLOGIN;", "parameters": ["login_name"], "description": "Revoke login. Terminate sessions. Check pg_stat_activity and PostgreSQL logs for activity history."}$body$::jsonb, 'medium', true, true, '10 minutes') RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active) VALUES ('SEC-SQL-ACC-010-RC12', 'postgresql', 'Disable dormant account', 'disable-dormant-postgresql', 'Revoke login and investigate', 'semi_automatic', 'medium', 'active', true) RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;
DO $$ DECLARE v_path_id int; v_s1 int; BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration) VALUES ('oracle', 'instruct', 'Lock dormant account and investigate', $body${"sql": "ALTER USER {login_name} ACCOUNT LOCK;", "parameters": ["login_name"], "description": "Lock the dormant account. Kill sessions. Check dba_audit_trail or unified audit for activity. Investigate reactivation cause."}$body$::jsonb, 'medium', true, true, '10 minutes') RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active) VALUES ('SEC-SQL-ACC-010-RC12', 'oracle', 'Lock dormant account', 'disable-dormant-oracle', 'Lock account and investigate', 'semi_automatic', 'medium', 'active', true) RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;
DO $$ DECLARE v_path_id int; v_s1 int; BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration) VALUES ('mysql', 'instruct', 'Lock dormant account and investigate', $body${"sql": "ALTER USER '{login_name}'@'%' ACCOUNT LOCK;", "parameters": ["login_name"], "description": "Lock the dormant account. Kill sessions. Check general log or audit log for activity history."}$body$::jsonb, 'medium', true, true, '10 minutes') RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active) VALUES ('SEC-SQL-ACC-010-RC12', 'mysql', 'Lock dormant account', 'disable-dormant-mysql', 'Lock account and investigate', 'semi_automatic', 'medium', 'active', true) RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;

-- RC13: Mass data modification
DO $$ DECLARE v_path_id int; v_s1 int; v_s2 int; BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration) VALUES ('sqlserver', 'execute', 'Kill mass modification transaction', $body${"sql": "KILL {session_id};", "parameters": ["session_id"], "description": "Immediately kill the session performing mass data modification. The transaction will be rolled back."}$body$::jsonb, 'critical', true, true, '1 minute') RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration) VALUES ('sqlserver', 'instruct', 'Verify data integrity and restore if needed', $body${"sql": null, "description": "1) Check if rollback completed: SELECT * FROM sys.dm_tran_active_transactions. 2) If data was corrupted, restore from backup: RESTORE DATABASE {db} FROM DISK. 3) Investigate root cause and disable the responsible account."}$body$::jsonb, 'critical', true, false, '60 minutes') RETURNING id INTO v_s2;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active) VALUES ('SEC-SQL-ACC-010-RC13', 'sqlserver', 'Kill mass modification and verify data', 'stop-mass-mod-sqlserver', 'Kill destructive transaction, verify integrity, restore if needed', 'semi_automatic', 'critical', 'active', true) RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'next', 'stop');
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s2, 2, 'done', 'stop');
END $$;
DO $$ DECLARE v_path_id int; v_s1 int; BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration) VALUES ('postgresql', 'instruct', 'Cancel mass modification and verify data', $body${"sql": "SELECT pg_cancel_backend(pid) FROM pg_stat_activity WHERE state = 'active' AND (query ILIKE 'DELETE%' OR query ILIKE 'TRUNCATE%' OR query ILIKE 'UPDATE%') AND pid != pg_backend_pid();", "description": "Cancel destructive queries (pg_cancel_backend for graceful, pg_terminate_backend for force). Verify data integrity. Restore from backup with pg_restore if needed."}$body$::jsonb, 'critical', true, true, '30 minutes') RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active) VALUES ('SEC-SQL-ACC-010-RC13', 'postgresql', 'Cancel mass modification and verify', 'stop-mass-mod-postgresql', 'Cancel destructive queries and verify integrity', 'semi_automatic', 'critical', 'active', true) RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;
DO $$ DECLARE v_path_id int; v_s1 int; BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration) VALUES ('oracle', 'instruct', 'Kill mass modification and verify data', $body${"sql": "ALTER SYSTEM KILL SESSION 'sid,serial#' IMMEDIATE;", "parameters": ["sid","serial"], "description": "Kill the destructive session. Oracle will rollback the transaction. Verify with: SELECT * FROM v$transaction. Restore with RMAN if data was committed before detection."}$body$::jsonb, 'critical', true, true, '30 minutes') RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active) VALUES ('SEC-SQL-ACC-010-RC13', 'oracle', 'Kill mass modification and verify', 'stop-mass-mod-oracle', 'Kill session and verify data integrity', 'semi_automatic', 'critical', 'active', true) RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;
DO $$ DECLARE v_path_id int; v_s1 int; BEGIN
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible, estimated_duration) VALUES ('mysql', 'instruct', 'Kill mass modification and verify data', $body${"sql": "KILL {process_id};", "parameters": ["process_id"], "description": "Kill the destructive process. InnoDB will rollback uncommitted changes. Verify with: SHOW ENGINE INNODB STATUS. Restore from backup with mysqlbinlog for point-in-time recovery if needed."}$body$::jsonb, 'critical', true, true, '30 minutes') RETURNING id INTO v_s1;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active) VALUES ('SEC-SQL-ACC-010-RC13', 'mysql', 'Kill mass modification and verify', 'stop-mass-mod-mysql', 'Kill process and verify data integrity', 'semi_automatic', 'critical', 'active', true) RETURNING id INTO v_path_id;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, on_success, on_failure) VALUES (v_path_id, v_s1, 1, 'done', 'stop');
END $$;

COMMIT;
