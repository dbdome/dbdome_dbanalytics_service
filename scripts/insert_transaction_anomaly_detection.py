"""
Insert transaction anomaly detection data into rootcause schema.
Adds issue SEC-SQL-ACC-010 with 4 root causes, detection paths for all 4 vendors.
"""
import psycopg2
import json
import sys
sys.path.insert(0, "C:/dev/dbanalytics")
from utils.config_dotenv import get_connection_string

conn = psycopg2.connect(get_connection_string())
conn.autocommit = False
cur = conn.cursor()

# 1. Create issue
cur.execute("""
    INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description)
    VALUES (
        'SEC-SQL-ACC-010', 'SEC', 'SQL', 'ACC',
        'Anomalous Transaction Activity',
        'anomalous-transaction-activity',
        'Running transactions show unusual patterns compared to expected baseline - unknown logins, unexpected programs, unusual databases, or suspicious query patterns that may indicate unauthorized access or compromised accounts.'
    )
    ON CONFLICT (issue_id) DO NOTHING
""")

# 2. Create root causes
root_causes = [
    {
        "id": "SEC-SQL-ACC-010-RC01",
        "name": "Unknown login executing queries",
        "desc": "A login name not in the expected baseline is actively running transactions. This may indicate a newly created unauthorized account, a compromised credential, or a misconfigured application.",
        "topics": ["security", "authentication", "anomaly-detection"],
    },
    {
        "id": "SEC-SQL-ACC-010-RC02",
        "name": "Unexpected program or application connected",
        "desc": "Transactions are being executed by a program/application name not in the expected baseline. This may indicate unauthorized tooling, SQL injection via a web app, or direct database access bypassing application controls.",
        "topics": ["security", "application-control", "anomaly-detection"],
    },
    {
        "id": "SEC-SQL-ACC-010-RC03",
        "name": "Query activity on unexpected database",
        "desc": "Transactions target a database not in the expected baseline. This may indicate lateral movement, data exfiltration attempts, or misconfigured applications accessing the wrong database.",
        "topics": ["security", "data-access", "anomaly-detection"],
    },
    {
        "id": "SEC-SQL-ACC-010-RC04",
        "name": "Suspicious query patterns detected",
        "desc": "Running transactions contain suspicious SQL patterns such as bulk data extraction, schema discovery, privilege escalation attempts, or data modification from unexpected sources.",
        "topics": ["security", "sql-injection", "anomaly-detection"],
    },
    {
        "id": "SEC-SQL-ACC-010-RC05",
        "name": "Sensitive data (PII) accessed in active transactions",
        "desc": "Active transactions are querying columns identified as containing sensitive/PII data (names, emails, SSN, credit cards, addresses, phone numbers, dates of birth). First identifies PII columns via schema inspection, then checks if any running transaction references those columns or tables.",
        "topics": ["security", "data-privacy", "PII", "anomaly-detection"],
    },
    {
        "id": "SEC-SQL-ACC-010-RC06",
        "name": "SQL injection patterns in active transactions",
        "desc": "Active transactions contain classic SQL injection signatures such as tautology attacks (OR 1=1), UNION-based injection, stacked queries with semicolons, comment-based truncation, time-based blind injection (WAITFOR/SLEEP/BENCHMARK), and error-based extraction attempts.",
        "topics": ["security", "sql-injection", "anomaly-detection"],
    },
    {
        "id": "SEC-SQL-ACC-010-RC07",
        "name": "After-hours transaction activity",
        "desc": "Transactions are running outside normal business hours (before 06:00 or after 22:00 server local time). After-hours database activity is a common indicator of compromised credentials, insider threats, or unauthorized batch processes.",
        "topics": ["security", "after-hours", "anomaly-detection"],
    },
    {
        "id": "SEC-SQL-ACC-010-RC08",
        "name": "Privilege escalation attempts in transactions",
        "desc": "Non-admin users are executing DDL or DCL statements (CREATE, ALTER, DROP, GRANT, REVOKE, DENY) that modify database structure or permissions. This may indicate privilege abuse, lateral movement, or a compromised application account attempting escalation.",
        "topics": ["security", "privilege-escalation", "anomaly-detection"],
    },
    {
        "id": "SEC-SQL-ACC-010-RC09",
        "name": "Data exfiltration patterns in transactions",
        "desc": "Active transactions show patterns consistent with data exfiltration: large result set extractions, bulk export operations (BCP, COPY, INTO OUTFILE), linked server/foreign data wrapper queries, or systematic table-by-table reads indicating data harvesting.",
        "topics": ["security", "data-exfiltration", "anomaly-detection"],
    },
    {
        "id": "SEC-SQL-ACC-010-RC10",
        "name": "Same login active from multiple hosts",
        "desc": "A single login name has concurrent active sessions originating from two or more different client hosts. This may indicate credential sharing, stolen credentials being used in parallel, or a brute-force attack that has succeeded.",
        "topics": ["security", "credential-compromise", "anomaly-detection"],
    },
    {
        "id": "SEC-SQL-ACC-010-RC11",
        "name": "Schema reconnaissance activity",
        "desc": "Active transactions are querying system catalogs, metadata views, or information_schema tables to enumerate database objects, columns, permissions, or configurations. This is a common first step in database attacks — mapping the target before exploitation.",
        "topics": ["security", "reconnaissance", "anomaly-detection"],
    },
    {
        "id": "SEC-SQL-ACC-010-RC12",
        "name": "Dormant account suddenly active",
        "desc": "An account that has had no login activity for an extended period (30+ days) is now executing transactions. Dormant accounts that suddenly become active are high-risk indicators of credential compromise or unauthorized reactivation.",
        "topics": ["security", "dormant-account", "anomaly-detection"],
    },
    {
        "id": "SEC-SQL-ACC-010-RC13",
        "name": "Mass data modification in transactions",
        "desc": "Active transactions are performing bulk UPDATE or DELETE operations affecting a large number of rows. This may indicate ransomware activity, data sabotage, unauthorized data manipulation, or a destructive script running against production.",
        "topics": ["security", "data-destruction", "anomaly-detection"],
    },
]

for rc in root_causes:
    cur.execute("""
        INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
        VALUES (%s, 'SEC-SQL-ACC-010', %s, %s, %s, %s, %s)
        ON CONFLICT (root_cause_id) DO NOTHING
    """, (
        rc["id"], rc["name"], rc["name"].lower().replace(" ", "-"),
        rc["desc"], rc["topics"],
        ["sqlserver", "postgresql", "oracle", "mysql"]
    ))

# 3. Vendor-specific detection queries
vendor_queries = {
    "sqlserver": {
        "RC01": [
            {
                "name": "Retrieve active transactions with login details",
                "content": {"sql": "SELECT s.login_name, s.host_name, s.program_name, DB_NAME(r.database_id) AS database_name, r.status, r.command, r.wait_type, r.total_elapsed_time / 1000 AS elapsed_sec, SUBSTRING(t.text, (r.statement_start_offset/2)+1, ((CASE r.statement_end_offset WHEN -1 THEN DATALENGTH(t.text) ELSE r.statement_end_offset END - r.statement_start_offset)/2)+1) AS query_text FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE s.is_user_process = 1 AND s.login_name NOT IN ('sa','NT AUTHORITY\\SYSTEM','NT SERVICE\\MSSQLSERVER')"},
                "expected": {"condition": "row_count > 0", "description": "Active user transactions found - check login_name against baseline", "severity": "high"},
            },
        ],
        "RC02": [
            {
                "name": "Detect transactions from unexpected programs",
                "content": {"sql": "SELECT s.login_name, s.program_name, s.host_name, DB_NAME(r.database_id) AS database_name, COUNT(*) AS active_requests, SUM(r.total_elapsed_time) / 1000 AS total_elapsed_sec FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id WHERE s.is_user_process = 1 GROUP BY s.login_name, s.program_name, s.host_name, DB_NAME(r.database_id) ORDER BY active_requests DESC"},
                "expected": {"condition": "row_count > 0", "description": "Active programs found - verify program_name against known applications", "severity": "high"},
            },
        ],
        "RC03": [
            {
                "name": "Detect transactions targeting unexpected databases",
                "content": {"sql": "SELECT DISTINCT s.login_name, s.program_name, DB_NAME(r.database_id) AS database_name, COUNT(*) AS request_count FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id WHERE s.is_user_process = 1 AND DB_NAME(r.database_id) NOT IN ('master','tempdb','msdb','model') GROUP BY s.login_name, s.program_name, DB_NAME(r.database_id)"},
                "expected": {"condition": "row_count > 0", "description": "User transactions on non-system databases - verify database access is expected", "severity": "medium"},
            },
        ],
        "RC04": [
            {
                "name": "Detect suspicious query patterns in active transactions",
                "content": {"sql": "SELECT s.login_name, s.program_name, s.host_name, DB_NAME(r.database_id) AS database_name, r.total_elapsed_time / 1000 AS elapsed_sec, SUBSTRING(t.text, 1, 500) AS query_text FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE s.is_user_process = 1 AND (t.text LIKE '%xp_cmdshell%' OR t.text LIKE '%OPENROWSET%' OR t.text LIKE '%sp_configure%' OR t.text LIKE '%ALTER LOGIN%' OR t.text LIKE '%CREATE LOGIN%' OR t.text LIKE '%sysadmin%' OR t.text LIKE '%BULK INSERT%' OR t.text LIKE '%information_schema%' OR t.text LIKE '%sysobjects%')"},
                "expected": {"condition": "row_count > 0", "description": "Suspicious SQL patterns detected in active transactions - potential security threat", "severity": "critical"},
            },
        ],
    },
    "postgresql": {
        "RC01": [
            {
                "name": "Retrieve active transactions with login details",
                "content": {"sql": "SELECT usename AS login_name, client_addr AS host_name, application_name AS program_name, datname AS database_name, state, wait_event_type, wait_event, EXTRACT(EPOCH FROM (now() - xact_start))::int AS elapsed_sec, LEFT(query, 500) AS query_text FROM pg_stat_activity WHERE state != 'idle' AND usename NOT IN ('postgres','replication') AND pid != pg_backend_pid()"},
                "expected": {"condition": "row_count > 0", "description": "Active user transactions found - check login_name against baseline", "severity": "high"},
            },
        ],
        "RC02": [
            {
                "name": "Detect transactions from unexpected applications",
                "content": {"sql": "SELECT usename AS login_name, application_name AS program_name, client_addr AS host_name, datname AS database_name, COUNT(*) AS active_requests FROM pg_stat_activity WHERE state != 'idle' AND pid != pg_backend_pid() GROUP BY usename, application_name, client_addr, datname ORDER BY active_requests DESC"},
                "expected": {"condition": "row_count > 0", "description": "Active applications found - verify application_name against known programs", "severity": "high"},
            },
        ],
        "RC03": [
            {
                "name": "Detect transactions targeting unexpected databases",
                "content": {"sql": "SELECT DISTINCT usename AS login_name, application_name AS program_name, datname AS database_name, COUNT(*) AS request_count FROM pg_stat_activity WHERE state != 'idle' AND pid != pg_backend_pid() AND datname NOT IN ('postgres','template0','template1') GROUP BY usename, application_name, datname"},
                "expected": {"condition": "row_count > 0", "description": "User transactions on non-system databases - verify database access is expected", "severity": "medium"},
            },
        ],
        "RC04": [
            {
                "name": "Detect suspicious query patterns in active transactions",
                "content": {"sql": "SELECT usename AS login_name, application_name AS program_name, client_addr AS host_name, datname AS database_name, EXTRACT(EPOCH FROM (now() - xact_start))::int AS elapsed_sec, LEFT(query, 500) AS query_text FROM pg_stat_activity WHERE state != 'idle' AND pid != pg_backend_pid() AND (query ILIKE '%pg_shadow%' OR query ILIKE '%pg_authid%' OR query ILIKE '%COPY%TO%' OR query ILIKE '%pg_read_file%' OR query ILIKE '%ALTER ROLE%' OR query ILIKE '%CREATE ROLE%' OR query ILIKE '%pg_execute_server_program%' OR query ILIKE '%information_schema%')"},
                "expected": {"condition": "row_count > 0", "description": "Suspicious SQL patterns detected in active transactions - potential security threat", "severity": "critical"},
            },
        ],
    },
    "oracle": {
        "RC01": [
            {
                "name": "Retrieve active transactions with login details",
                "content": {"sql": "SELECT s.username AS login_name, s.machine AS host_name, s.program AS program_name, s.schemaname AS database_name, s.status, s.state, s.event AS wait_event, s.last_call_et AS elapsed_sec, SUBSTR(q.sql_text, 1, 500) AS query_text FROM v$session s LEFT JOIN v$sql q ON s.sql_id = q.sql_id AND s.sql_child_number = q.child_number WHERE s.type = 'USER' AND s.status = 'ACTIVE' AND s.username NOT IN ('SYS','SYSTEM','DBSNMP','SYSMAN')"},
                "expected": {"condition": "row_count > 0", "description": "Active user transactions found - check login_name against baseline", "severity": "high"},
            },
        ],
        "RC02": [
            {
                "name": "Detect transactions from unexpected programs",
                "content": {"sql": "SELECT s.username AS login_name, s.program AS program_name, s.machine AS host_name, s.schemaname AS database_name, COUNT(*) AS active_requests FROM v$session s WHERE s.type = 'USER' AND s.status = 'ACTIVE' GROUP BY s.username, s.program, s.machine, s.schemaname ORDER BY active_requests DESC"},
                "expected": {"condition": "row_count > 0", "description": "Active programs found - verify program against known applications", "severity": "high"},
            },
        ],
        "RC03": [
            {
                "name": "Detect transactions targeting unexpected schemas",
                "content": {"sql": "SELECT DISTINCT s.username AS login_name, s.program AS program_name, s.schemaname AS database_name, COUNT(*) AS request_count FROM v$session s WHERE s.type = 'USER' AND s.status = 'ACTIVE' AND s.schemaname NOT IN ('SYS','SYSTEM','DBSNMP','OUTLN','XDB') GROUP BY s.username, s.program, s.schemaname"},
                "expected": {"condition": "row_count > 0", "description": "User transactions on non-system schemas - verify access is expected", "severity": "medium"},
            },
        ],
        "RC04": [
            {
                "name": "Detect suspicious query patterns in active transactions",
                "content": {"sql": "SELECT s.username AS login_name, s.program AS program_name, s.machine AS host_name, s.schemaname AS database_name, s.last_call_et AS elapsed_sec, SUBSTR(q.sql_text, 1, 500) AS query_text FROM v$session s JOIN v$sql q ON s.sql_id = q.sql_id AND s.sql_child_number = q.child_number WHERE s.type = 'USER' AND s.status = 'ACTIVE' AND (q.sql_text LIKE '%DBA_USERS%' OR q.sql_text LIKE '%ALL_TAB_PRIVS%' OR q.sql_text LIKE '%ALTER USER%' OR q.sql_text LIKE '%CREATE USER%' OR q.sql_text LIKE '%GRANT%DBA%' OR q.sql_text LIKE '%UTL_FILE%' OR q.sql_text LIKE '%DBMS_SCHEDULER%' OR q.sql_text LIKE '%UTL_HTTP%')"},
                "expected": {"condition": "row_count > 0", "description": "Suspicious SQL patterns detected in active transactions - potential security threat", "severity": "critical"},
            },
        ],
    },
    "mysql": {
        "RC01": [
            {
                "name": "Retrieve active transactions with login details",
                "content": {"sql": "SELECT USER AS login_name, HOST AS host_name, DB AS database_name, COMMAND, STATE AS wait_event, TIME AS elapsed_sec, LEFT(INFO, 500) AS query_text FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep' AND USER NOT IN ('system user','event_scheduler','root') AND ID != CONNECTION_ID()"},
                "expected": {"condition": "row_count > 0", "description": "Active user transactions found - check login_name against baseline", "severity": "high"},
            },
        ],
        "RC02": [
            {
                "name": "Detect transactions from unexpected hosts",
                "content": {"sql": "SELECT USER AS login_name, SUBSTRING_INDEX(HOST, ':', 1) AS host_name, DB AS database_name, COUNT(*) AS active_requests FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep' AND ID != CONNECTION_ID() GROUP BY USER, SUBSTRING_INDEX(HOST, ':', 1), DB ORDER BY active_requests DESC"},
                "expected": {"condition": "row_count > 0", "description": "Active connections found - verify host and user against known sources", "severity": "high"},
            },
        ],
        "RC03": [
            {
                "name": "Detect transactions targeting unexpected databases",
                "content": {"sql": "SELECT DISTINCT USER AS login_name, DB AS database_name, COUNT(*) AS request_count FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep' AND ID != CONNECTION_ID() AND DB NOT IN ('mysql','information_schema','performance_schema','sys') AND DB IS NOT NULL GROUP BY USER, DB"},
                "expected": {"condition": "row_count > 0", "description": "User transactions on non-system databases - verify database access is expected", "severity": "medium"},
            },
        ],
        "RC04": [
            {
                "name": "Detect suspicious query patterns in active transactions",
                "content": {"sql": "SELECT USER AS login_name, HOST AS host_name, DB AS database_name, TIME AS elapsed_sec, LEFT(INFO, 500) AS query_text FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep' AND ID != CONNECTION_ID() AND (INFO LIKE '%mysql.user%' OR INFO LIKE '%INTO OUTFILE%' OR INFO LIKE '%INTO DUMPFILE%' OR INFO LIKE '%LOAD_FILE%' OR INFO LIKE '%CREATE USER%' OR INFO LIKE '%GRANT%ALL%' OR INFO LIKE '%information_schema.columns%')"},
                "expected": {"condition": "row_count > 0", "description": "Suspicious SQL patterns detected in active transactions - potential security threat", "severity": "critical"},
            },
        ],
        "RC05": [
            {
                "name": "Identify sensitive (PII) columns in database",
                "content": {"sql": "SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, DATA_TYPE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys') AND (LOWER(COLUMN_NAME) REGEXP '(ssn|social_sec|national_id|tax_id|passport|credit_card|card_num|cvv|email|e_mail|phone|mobile|cell|birth_date|dob|date_of_birth|first_name|last_name|full_name|surname|address|street|zip_code|postal|salary|income|wage|bank_account|iban|routing_num|password|pwd|secret)') ORDER BY TABLE_SCHEMA, TABLE_NAME"},
                "expected": {"condition": "row_count > 0", "description": "PII/sensitive columns identified in the database schema", "severity": "medium"},
            },
            {
                "name": "Detect active transactions accessing PII tables",
                "content": {"sql": "SELECT p.USER AS login_name, p.HOST AS host_name, p.DB AS database_name, p.TIME AS elapsed_sec, LEFT(p.INFO, 500) AS query_text, c.TABLE_NAME AS pii_table, c.COLUMN_NAME AS pii_column FROM information_schema.PROCESSLIST p JOIN information_schema.COLUMNS c ON p.DB = c.TABLE_SCHEMA AND p.INFO LIKE CONCAT('%', c.TABLE_NAME, '%') WHERE p.COMMAND != 'Sleep' AND p.ID != CONNECTION_ID() AND p.INFO IS NOT NULL AND c.TABLE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys') AND (LOWER(c.COLUMN_NAME) REGEXP '(ssn|social_sec|national_id|tax_id|passport|credit_card|card_num|cvv|email|e_mail|phone|mobile|cell|birth_date|dob|date_of_birth|first_name|last_name|full_name|surname|address|salary|income|bank_account|iban|password|pwd|secret)')"},
                "expected": {"condition": "row_count > 0", "description": "Active transactions are accessing tables containing PII/sensitive columns - potential data exposure", "severity": "critical"},
            },
        ],
        "RC06": [
            {
                "name": "Detect SQL injection patterns in active transactions",
                "content": {"sql": "SELECT USER AS login_name, HOST AS host_name, DB AS database_name, TIME AS elapsed_sec, LEFT(INFO, 500) AS query_text, CASE WHEN INFO LIKE '%OR 1=1%' OR INFO LIKE '%OR ''1''=''1%' OR INFO LIKE '%OR true%' THEN 'tautology' WHEN INFO LIKE '%UNION%SELECT%' THEN 'union-based' WHEN INFO LIKE '%;%DROP%' OR INFO LIKE '%;%DELETE%' OR INFO LIKE '%;%INSERT%' OR INFO LIKE '%;%UPDATE%' THEN 'stacked-query' WHEN INFO LIKE '%--%' OR INFO LIKE '%#%' OR INFO LIKE '%/*%' THEN 'comment-truncation' WHEN INFO LIKE '%SLEEP(%' OR INFO LIKE '%BENCHMARK(%' THEN 'time-based-blind' WHEN INFO LIKE '%EXTRACTVALUE%' OR INFO LIKE '%UPDATEXML%' OR INFO LIKE '%CONVERT(%' THEN 'error-based' ELSE 'other' END AS injection_type FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep' AND ID != CONNECTION_ID() AND INFO IS NOT NULL AND (INFO LIKE '%OR 1=1%' OR INFO LIKE '%OR ''1''=''1%' OR INFO LIKE '%OR true%' OR INFO LIKE '%UNION%SELECT%' OR (INFO LIKE '%;%' AND (INFO LIKE '%DROP %' OR INFO LIKE '%DELETE %' OR INFO LIKE '%INSERT %' OR INFO LIKE '%UPDATE %')) OR INFO LIKE '%SLEEP(%' OR INFO LIKE '%BENCHMARK(%' OR INFO LIKE '%EXTRACTVALUE%' OR INFO LIKE '%UPDATEXML%')"},
                "expected": {"condition": "row_count > 0", "description": "SQL injection patterns detected in active transactions - active attack in progress", "severity": "critical"},
            },
        ],
    },
}

# Add RC05 and RC06 for sqlserver
vendor_queries["sqlserver"]["RC05"] = [
    {
        "name": "Identify sensitive (PII) columns in database",
        "content": {"sql": "SELECT s.name AS schema_name, t.name AS table_name, c.name AS column_name, ty.name AS data_type FROM sys.columns c JOIN sys.tables t ON c.object_id = t.object_id JOIN sys.schemas s ON t.schema_id = s.schema_id JOIN sys.types ty ON c.user_type_id = ty.user_type_id WHERE s.name NOT IN ('sys','INFORMATION_SCHEMA') AND (LOWER(c.name) LIKE '%ssn%' OR LOWER(c.name) LIKE '%social_sec%' OR LOWER(c.name) LIKE '%national_id%' OR LOWER(c.name) LIKE '%tax_id%' OR LOWER(c.name) LIKE '%passport%' OR LOWER(c.name) LIKE '%credit_card%' OR LOWER(c.name) LIKE '%card_num%' OR LOWER(c.name) LIKE '%cvv%' OR LOWER(c.name) LIKE '%email%' OR LOWER(c.name) LIKE '%phone%' OR LOWER(c.name) LIKE '%mobile%' OR LOWER(c.name) LIKE '%birth_date%' OR LOWER(c.name) LIKE '%dob%' OR LOWER(c.name) LIKE '%date_of_birth%' OR LOWER(c.name) LIKE '%first_name%' OR LOWER(c.name) LIKE '%last_name%' OR LOWER(c.name) LIKE '%full_name%' OR LOWER(c.name) LIKE '%surname%' OR LOWER(c.name) LIKE '%address%' OR LOWER(c.name) LIKE '%salary%' OR LOWER(c.name) LIKE '%income%' OR LOWER(c.name) LIKE '%bank_account%' OR LOWER(c.name) LIKE '%iban%' OR LOWER(c.name) LIKE '%password%' OR LOWER(c.name) LIKE '%secret%') ORDER BY s.name, t.name"},
        "expected": {"condition": "row_count > 0", "description": "PII/sensitive columns identified in the database schema", "severity": "medium"},
    },
    {
        "name": "Detect active transactions accessing PII tables",
        "content": {"sql": "SELECT s.login_name, s.host_name, s.program_name, DB_NAME(r.database_id) AS database_name, r.total_elapsed_time / 1000 AS elapsed_sec, SUBSTRING(t.text, 1, 500) AS query_text FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t JOIN sys.columns c ON 1=1 JOIN sys.tables tbl ON c.object_id = tbl.object_id JOIN sys.schemas sch ON tbl.schema_id = sch.schema_id WHERE s.is_user_process = 1 AND sch.name NOT IN ('sys','INFORMATION_SCHEMA') AND t.text LIKE '%' + tbl.name + '%' AND (LOWER(c.name) LIKE '%ssn%' OR LOWER(c.name) LIKE '%social_sec%' OR LOWER(c.name) LIKE '%credit_card%' OR LOWER(c.name) LIKE '%email%' OR LOWER(c.name) LIKE '%phone%' OR LOWER(c.name) LIKE '%birth_date%' OR LOWER(c.name) LIKE '%first_name%' OR LOWER(c.name) LIKE '%last_name%' OR LOWER(c.name) LIKE '%salary%' OR LOWER(c.name) LIKE '%password%' OR LOWER(c.name) LIKE '%bank_account%')"},
        "expected": {"condition": "row_count > 0", "description": "Active transactions are accessing tables containing PII/sensitive columns - potential data exposure", "severity": "critical"},
    },
]

vendor_queries["sqlserver"]["RC06"] = [
    {
        "name": "Detect SQL injection patterns in active transactions",
        "content": {"sql": "SELECT s.login_name, s.host_name, s.program_name, DB_NAME(r.database_id) AS database_name, r.total_elapsed_time / 1000 AS elapsed_sec, SUBSTRING(t.text, 1, 500) AS query_text, CASE WHEN t.text LIKE '%OR 1=1%' OR t.text LIKE '%OR ''1''=''1%' THEN 'tautology' WHEN t.text LIKE '%UNION%SELECT%' THEN 'union-based' WHEN t.text LIKE '%;%DROP%' OR t.text LIKE '%;%DELETE%' OR t.text LIKE '%;%INSERT%' THEN 'stacked-query' WHEN t.text LIKE '%--%' AND (t.text LIKE '%''%--' OR t.text LIKE '%OR%--%') THEN 'comment-truncation' WHEN t.text LIKE '%WAITFOR%DELAY%' THEN 'time-based-blind' WHEN t.text LIKE '%CONVERT(int%' OR t.text LIKE '%CAST(%AS%varchar%' THEN 'error-based' ELSE 'other' END AS injection_type FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE s.is_user_process = 1 AND (t.text LIKE '%OR 1=1%' OR t.text LIKE '%OR ''1''=''1%' OR t.text LIKE '%UNION%SELECT%' OR (t.text LIKE '%;%' AND (t.text LIKE '%DROP %' OR t.text LIKE '%DELETE %' OR t.text LIKE '%INSERT %')) OR t.text LIKE '%WAITFOR%DELAY%' OR t.text LIKE '%xp_cmdshell%' OR t.text LIKE '%EXEC(%' OR t.text LIKE '%EXECUTE(%')"},
        "expected": {"condition": "row_count > 0", "description": "SQL injection patterns detected in active transactions - active attack in progress", "severity": "critical"},
    },
]

# Add RC05 and RC06 for postgresql
vendor_queries["postgresql"]["RC05"] = [
    {
        "name": "Identify sensitive (PII) columns in database",
        "content": {"sql": "SELECT table_schema, table_name, column_name, data_type FROM information_schema.columns WHERE table_schema NOT IN ('pg_catalog','information_schema') AND (lower(column_name) ~ '(ssn|social_sec|national_id|tax_id|passport|credit_card|card_num|cvv|email|e_mail|phone|mobile|cell|birth_date|dob|date_of_birth|first_name|last_name|full_name|surname|address|street|zip_code|postal|salary|income|wage|bank_account|iban|routing_num|password|pwd|secret)') ORDER BY table_schema, table_name"},
        "expected": {"condition": "row_count > 0", "description": "PII/sensitive columns identified in the database schema", "severity": "medium"},
    },
    {
        "name": "Detect active transactions accessing PII tables",
        "content": {"sql": "SELECT a.usename AS login_name, a.client_addr AS host_name, a.application_name AS program_name, a.datname AS database_name, EXTRACT(EPOCH FROM (now() - a.xact_start))::int AS elapsed_sec, LEFT(a.query, 500) AS query_text, c.table_name AS pii_table, c.column_name AS pii_column FROM pg_stat_activity a JOIN information_schema.columns c ON a.datname = current_database() AND a.query ILIKE '%' || c.table_name || '%' WHERE a.state != 'idle' AND a.pid != pg_backend_pid() AND a.query IS NOT NULL AND c.table_schema NOT IN ('pg_catalog','information_schema') AND (lower(c.column_name) ~ '(ssn|social_sec|national_id|tax_id|passport|credit_card|card_num|cvv|email|e_mail|phone|mobile|birth_date|dob|date_of_birth|first_name|last_name|full_name|surname|address|salary|income|bank_account|iban|password|pwd|secret)')"},
        "expected": {"condition": "row_count > 0", "description": "Active transactions are accessing tables containing PII/sensitive columns - potential data exposure", "severity": "critical"},
    },
]

vendor_queries["postgresql"]["RC06"] = [
    {
        "name": "Detect SQL injection patterns in active transactions",
        "content": {"sql": "SELECT usename AS login_name, client_addr AS host_name, application_name AS program_name, datname AS database_name, EXTRACT(EPOCH FROM (now() - xact_start))::int AS elapsed_sec, LEFT(query, 500) AS query_text, CASE WHEN query ILIKE '%OR 1=1%' OR query ILIKE '%OR ''1''=''1%' OR query ILIKE '%OR true%' THEN 'tautology' WHEN query ILIKE '%UNION%SELECT%' THEN 'union-based' WHEN query LIKE '%;%' AND (query ILIKE '%DROP %' OR query ILIKE '%DELETE %' OR query ILIKE '%INSERT %') THEN 'stacked-query' WHEN query LIKE '%--%' AND (query LIKE '%''%--%' OR query ILIKE '%OR%--%') THEN 'comment-truncation' WHEN query ILIKE '%pg_sleep%' THEN 'time-based-blind' WHEN query ILIKE '%CAST(%AS%text%' THEN 'error-based' ELSE 'other' END AS injection_type FROM pg_stat_activity WHERE state != 'idle' AND pid != pg_backend_pid() AND query IS NOT NULL AND (query ILIKE '%OR 1=1%' OR query ILIKE '%OR ''1''=''1%' OR query ILIKE '%OR true%' OR query ILIKE '%UNION%SELECT%' OR (query LIKE '%;%' AND (query ILIKE '%DROP %' OR query ILIKE '%DELETE %' OR query ILIKE '%INSERT %')) OR query ILIKE '%pg_sleep%' OR query ILIKE '%COPY%TO%PROGRAM%')"},
        "expected": {"condition": "row_count > 0", "description": "SQL injection patterns detected in active transactions - active attack in progress", "severity": "critical"},
    },
]

# Add RC05 and RC06 for oracle
vendor_queries["oracle"]["RC05"] = [
    {
        "name": "Identify sensitive (PII) columns in database",
        "content": {"sql": "SELECT owner AS schema_name, table_name, column_name, data_type FROM all_tab_columns WHERE owner NOT IN ('SYS','SYSTEM','DBSNMP','OUTLN','XDB','WMSYS','CTXSYS','MDSYS','ORDDATA','ORDSYS') AND (LOWER(column_name) LIKE '%SSN%' OR LOWER(column_name) LIKE '%SOCIAL_SEC%' OR LOWER(column_name) LIKE '%NATIONAL_ID%' OR LOWER(column_name) LIKE '%TAX_ID%' OR LOWER(column_name) LIKE '%PASSPORT%' OR LOWER(column_name) LIKE '%CREDIT_CARD%' OR LOWER(column_name) LIKE '%CARD_NUM%' OR LOWER(column_name) LIKE '%EMAIL%' OR LOWER(column_name) LIKE '%PHONE%' OR LOWER(column_name) LIKE '%MOBILE%' OR LOWER(column_name) LIKE '%BIRTH_DATE%' OR LOWER(column_name) LIKE '%DOB%' OR LOWER(column_name) LIKE '%FIRST_NAME%' OR LOWER(column_name) LIKE '%LAST_NAME%' OR LOWER(column_name) LIKE '%FULL_NAME%' OR LOWER(column_name) LIKE '%SURNAME%' OR LOWER(column_name) LIKE '%ADDRESS%' OR LOWER(column_name) LIKE '%SALARY%' OR LOWER(column_name) LIKE '%INCOME%' OR LOWER(column_name) LIKE '%BANK_ACCOUNT%' OR LOWER(column_name) LIKE '%IBAN%' OR LOWER(column_name) LIKE '%PASSWORD%' OR LOWER(column_name) LIKE '%SECRET%') ORDER BY owner, table_name"},
        "expected": {"condition": "row_count > 0", "description": "PII/sensitive columns identified in the database schema", "severity": "medium"},
    },
    {
        "name": "Detect active transactions accessing PII tables",
        "content": {"sql": "SELECT s.username AS login_name, s.machine AS host_name, s.program AS program_name, s.schemaname AS database_name, s.last_call_et AS elapsed_sec, SUBSTR(q.sql_text, 1, 500) AS query_text FROM v$session s JOIN v$sql q ON s.sql_id = q.sql_id AND s.sql_child_number = q.child_number JOIN all_tab_columns c ON s.schemaname = c.owner AND q.sql_text LIKE '%' || c.table_name || '%' WHERE s.type = 'USER' AND s.status = 'ACTIVE' AND c.owner NOT IN ('SYS','SYSTEM','DBSNMP','OUTLN','XDB') AND (LOWER(c.column_name) LIKE '%SSN%' OR LOWER(c.column_name) LIKE '%CREDIT_CARD%' OR LOWER(c.column_name) LIKE '%EMAIL%' OR LOWER(c.column_name) LIKE '%PHONE%' OR LOWER(c.column_name) LIKE '%BIRTH_DATE%' OR LOWER(c.column_name) LIKE '%FIRST_NAME%' OR LOWER(c.column_name) LIKE '%LAST_NAME%' OR LOWER(c.column_name) LIKE '%SALARY%' OR LOWER(c.column_name) LIKE '%PASSWORD%' OR LOWER(c.column_name) LIKE '%BANK_ACCOUNT%')"},
        "expected": {"condition": "row_count > 0", "description": "Active transactions are accessing tables containing PII/sensitive columns - potential data exposure", "severity": "critical"},
    },
]

vendor_queries["oracle"]["RC06"] = [
    {
        "name": "Detect SQL injection patterns in active transactions",
        "content": {"sql": "SELECT s.username AS login_name, s.machine AS host_name, s.program AS program_name, s.schemaname AS database_name, s.last_call_et AS elapsed_sec, SUBSTR(q.sql_text, 1, 500) AS query_text, CASE WHEN q.sql_text LIKE '%OR 1=1%' OR q.sql_text LIKE '%OR ''1''=''1%' THEN 'tautology' WHEN q.sql_text LIKE '%UNION%SELECT%' THEN 'union-based' WHEN q.sql_text LIKE '%;%' AND (q.sql_text LIKE '%DROP %' OR q.sql_text LIKE '%DELETE %') THEN 'stacked-query' WHEN q.sql_text LIKE '%--%' AND q.sql_text LIKE '%''%--%' THEN 'comment-truncation' WHEN q.sql_text LIKE '%DBMS_LOCK.SLEEP%' THEN 'time-based-blind' WHEN q.sql_text LIKE '%UTL_INADDR%' OR q.sql_text LIKE '%CTXSYS.DRITHSX%' THEN 'error-based' ELSE 'other' END AS injection_type FROM v$session s JOIN v$sql q ON s.sql_id = q.sql_id AND s.sql_child_number = q.child_number WHERE s.type = 'USER' AND s.status = 'ACTIVE' AND (q.sql_text LIKE '%OR 1=1%' OR q.sql_text LIKE '%OR ''1''=''1%' OR q.sql_text LIKE '%UNION%SELECT%' OR (q.sql_text LIKE '%;%' AND (q.sql_text LIKE '%DROP %' OR q.sql_text LIKE '%DELETE %')) OR q.sql_text LIKE '%DBMS_LOCK.SLEEP%' OR q.sql_text LIKE '%UTL_INADDR%' OR q.sql_text LIKE '%CTXSYS.DRITHSX%' OR q.sql_text LIKE '%EXECUTE IMMEDIATE%')"},
        "expected": {"condition": "row_count > 0", "description": "SQL injection patterns detected in active transactions - active attack in progress", "severity": "critical"},
    },
]

# ---------------------------------------------------------------
# RC07: After-hours activity
# ---------------------------------------------------------------
vendor_queries["sqlserver"]["RC07"] = [
    {
        "name": "Detect after-hours transaction activity",
        "content": {"sql": "SELECT s.login_name, s.host_name, s.program_name, DB_NAME(r.database_id) AS database_name, r.total_elapsed_time / 1000 AS elapsed_sec, DATEPART(HOUR, GETDATE()) AS current_hour, SUBSTRING(t.text, 1, 500) AS query_text FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE s.is_user_process = 1 AND (DATEPART(HOUR, GETDATE()) < 6 OR DATEPART(HOUR, GETDATE()) >= 22)"},
        "expected": {"condition": "row_count > 0", "description": "User transactions running outside business hours (before 06:00 or after 22:00) - potential unauthorized access", "severity": "high"},
    },
]
vendor_queries["postgresql"]["RC07"] = [
    {
        "name": "Detect after-hours transaction activity",
        "content": {"sql": "SELECT usename AS login_name, client_addr AS host_name, application_name AS program_name, datname AS database_name, EXTRACT(EPOCH FROM (now() - xact_start))::int AS elapsed_sec, EXTRACT(HOUR FROM now()) AS current_hour, LEFT(query, 500) AS query_text FROM pg_stat_activity WHERE state != 'idle' AND pid != pg_backend_pid() AND (EXTRACT(HOUR FROM now()) < 6 OR EXTRACT(HOUR FROM now()) >= 22)"},
        "expected": {"condition": "row_count > 0", "description": "User transactions running outside business hours (before 06:00 or after 22:00) - potential unauthorized access", "severity": "high"},
    },
]
vendor_queries["oracle"]["RC07"] = [
    {
        "name": "Detect after-hours transaction activity",
        "content": {"sql": "SELECT s.username AS login_name, s.machine AS host_name, s.program AS program_name, s.schemaname AS database_name, s.last_call_et AS elapsed_sec, TO_NUMBER(TO_CHAR(SYSDATE, 'HH24')) AS current_hour, SUBSTR(q.sql_text, 1, 500) AS query_text FROM v$session s LEFT JOIN v$sql q ON s.sql_id = q.sql_id AND s.sql_child_number = q.child_number WHERE s.type = 'USER' AND s.status = 'ACTIVE' AND (TO_NUMBER(TO_CHAR(SYSDATE, 'HH24')) < 6 OR TO_NUMBER(TO_CHAR(SYSDATE, 'HH24')) >= 22)"},
        "expected": {"condition": "row_count > 0", "description": "User transactions running outside business hours (before 06:00 or after 22:00) - potential unauthorized access", "severity": "high"},
    },
]
vendor_queries["mysql"]["RC07"] = [
    {
        "name": "Detect after-hours transaction activity",
        "content": {"sql": "SELECT USER AS login_name, HOST AS host_name, DB AS database_name, TIME AS elapsed_sec, HOUR(NOW()) AS current_hour, LEFT(INFO, 500) AS query_text FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep' AND ID != CONNECTION_ID() AND (HOUR(NOW()) < 6 OR HOUR(NOW()) >= 22)"},
        "expected": {"condition": "row_count > 0", "description": "User transactions running outside business hours (before 06:00 or after 22:00) - potential unauthorized access", "severity": "high"},
    },
]

# ---------------------------------------------------------------
# RC08: Privilege escalation attempts
# ---------------------------------------------------------------
vendor_queries["sqlserver"]["RC08"] = [
    {
        "name": "Detect privilege escalation in active transactions",
        "content": {"sql": "SELECT s.login_name, s.host_name, s.program_name, DB_NAME(r.database_id) AS database_name, r.total_elapsed_time / 1000 AS elapsed_sec, SUBSTRING(t.text, 1, 500) AS query_text, CASE WHEN t.text LIKE '%CREATE LOGIN%' OR t.text LIKE '%CREATE USER%' THEN 'create-account' WHEN t.text LIKE '%ALTER LOGIN%' OR t.text LIKE '%ALTER USER%' OR t.text LIKE '%ALTER ROLE%' THEN 'alter-account' WHEN t.text LIKE '%GRANT%' THEN 'grant-privilege' WHEN t.text LIKE '%sp_addsrvrolemember%' OR t.text LIKE '%sp_addrolemember%' THEN 'role-membership' WHEN t.text LIKE '%DROP TABLE%' OR t.text LIKE '%DROP DATABASE%' OR t.text LIKE '%ALTER TABLE%' THEN 'ddl-modification' WHEN t.text LIKE '%DENY%' OR t.text LIKE '%REVOKE%' THEN 'revoke-deny' ELSE 'other-ddl' END AS escalation_type FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE s.is_user_process = 1 AND s.login_name NOT IN ('sa') AND (t.text LIKE '%CREATE LOGIN%' OR t.text LIKE '%CREATE USER%' OR t.text LIKE '%ALTER LOGIN%' OR t.text LIKE '%ALTER USER%' OR t.text LIKE '%ALTER ROLE%' OR t.text LIKE '%GRANT%' OR t.text LIKE '%DENY%' OR t.text LIKE '%REVOKE%' OR t.text LIKE '%sp_addsrvrolemember%' OR t.text LIKE '%sp_addrolemember%' OR t.text LIKE '%DROP TABLE%' OR t.text LIKE '%DROP DATABASE%' OR t.text LIKE '%ALTER TABLE%')"},
        "expected": {"condition": "row_count > 0", "description": "Non-admin user executing DDL/DCL statements - potential privilege escalation", "severity": "critical"},
    },
]
vendor_queries["postgresql"]["RC08"] = [
    {
        "name": "Detect privilege escalation in active transactions",
        "content": {"sql": "SELECT usename AS login_name, client_addr AS host_name, application_name AS program_name, datname AS database_name, EXTRACT(EPOCH FROM (now() - xact_start))::int AS elapsed_sec, LEFT(query, 500) AS query_text, CASE WHEN query ILIKE '%CREATE ROLE%' OR query ILIKE '%CREATE USER%' THEN 'create-account' WHEN query ILIKE '%ALTER ROLE%' OR query ILIKE '%ALTER USER%' THEN 'alter-account' WHEN query ILIKE '%GRANT%' THEN 'grant-privilege' WHEN query ILIKE '%DROP TABLE%' OR query ILIKE '%DROP SCHEMA%' OR query ILIKE '%ALTER TABLE%' THEN 'ddl-modification' WHEN query ILIKE '%REVOKE%' THEN 'revoke' ELSE 'other-ddl' END AS escalation_type FROM pg_stat_activity WHERE state != 'idle' AND pid != pg_backend_pid() AND usename != 'postgres' AND (query ILIKE '%CREATE ROLE%' OR query ILIKE '%CREATE USER%' OR query ILIKE '%ALTER ROLE%' OR query ILIKE '%ALTER USER%' OR query ILIKE '%GRANT%' OR query ILIKE '%REVOKE%' OR query ILIKE '%DROP TABLE%' OR query ILIKE '%DROP SCHEMA%' OR query ILIKE '%DROP DATABASE%' OR query ILIKE '%ALTER TABLE%')"},
        "expected": {"condition": "row_count > 0", "description": "Non-admin user executing DDL/DCL statements - potential privilege escalation", "severity": "critical"},
    },
]
vendor_queries["oracle"]["RC08"] = [
    {
        "name": "Detect privilege escalation in active transactions",
        "content": {"sql": "SELECT s.username AS login_name, s.machine AS host_name, s.program AS program_name, s.schemaname AS database_name, s.last_call_et AS elapsed_sec, SUBSTR(q.sql_text, 1, 500) AS query_text FROM v$session s JOIN v$sql q ON s.sql_id = q.sql_id AND s.sql_child_number = q.child_number WHERE s.type = 'USER' AND s.status = 'ACTIVE' AND s.username NOT IN ('SYS','SYSTEM') AND (q.sql_text LIKE '%CREATE USER%' OR q.sql_text LIKE '%ALTER USER%' OR q.sql_text LIKE '%GRANT%' OR q.sql_text LIKE '%REVOKE%' OR q.sql_text LIKE '%DROP TABLE%' OR q.sql_text LIKE '%DROP USER%' OR q.sql_text LIKE '%ALTER TABLE%' OR q.sql_text LIKE '%CREATE ROLE%')"},
        "expected": {"condition": "row_count > 0", "description": "Non-admin user executing DDL/DCL statements - potential privilege escalation", "severity": "critical"},
    },
]
vendor_queries["mysql"]["RC08"] = [
    {
        "name": "Detect privilege escalation in active transactions",
        "content": {"sql": "SELECT USER AS login_name, HOST AS host_name, DB AS database_name, TIME AS elapsed_sec, LEFT(INFO, 500) AS query_text FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep' AND ID != CONNECTION_ID() AND USER != 'root' AND (INFO LIKE '%CREATE USER%' OR INFO LIKE '%ALTER USER%' OR INFO LIKE '%GRANT%' OR INFO LIKE '%REVOKE%' OR INFO LIKE '%DROP TABLE%' OR INFO LIKE '%DROP DATABASE%' OR INFO LIKE '%ALTER TABLE%' OR INFO LIKE '%CREATE ROLE%')"},
        "expected": {"condition": "row_count > 0", "description": "Non-admin user executing DDL/DCL statements - potential privilege escalation", "severity": "critical"},
    },
]

# ---------------------------------------------------------------
# RC09: Data exfiltration patterns
# ---------------------------------------------------------------
vendor_queries["sqlserver"]["RC09"] = [
    {
        "name": "Detect data exfiltration patterns in transactions",
        "content": {"sql": "SELECT s.login_name, s.host_name, s.program_name, DB_NAME(r.database_id) AS database_name, r.total_elapsed_time / 1000 AS elapsed_sec, r.row_count AS rows_affected, r.granted_query_memory * 8 AS memory_kb, SUBSTRING(t.text, 1, 500) AS query_text, CASE WHEN t.text LIKE '%BULK INSERT%' OR t.text LIKE '%bcp%' THEN 'bulk-export' WHEN t.text LIKE '%OPENROWSET%' OR t.text LIKE '%OPENDATASOURCE%' OR t.text LIKE '%OPENQUERY%' THEN 'linked-server' WHEN t.text LIKE '%INTO%FROM%' AND t.text LIKE '%SELECT%*%' THEN 'select-into' WHEN r.row_count > 10000 THEN 'large-result-set' ELSE 'other' END AS exfil_type FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE s.is_user_process = 1 AND (r.row_count > 10000 OR t.text LIKE '%BULK INSERT%' OR t.text LIKE '%bcp%' OR t.text LIKE '%OPENROWSET%' OR t.text LIKE '%OPENDATASOURCE%' OR t.text LIKE '%OPENQUERY%' OR (t.text LIKE '%SELECT%*%FROM%' AND r.granted_query_memory * 8 > 50000))"},
        "expected": {"condition": "row_count > 0", "description": "Data exfiltration patterns detected - bulk export, linked server access, or large data extraction", "severity": "critical"},
    },
]
vendor_queries["postgresql"]["RC09"] = [
    {
        "name": "Detect data exfiltration patterns in transactions",
        "content": {"sql": "SELECT usename AS login_name, client_addr AS host_name, application_name AS program_name, datname AS database_name, EXTRACT(EPOCH FROM (now() - xact_start))::int AS elapsed_sec, LEFT(query, 500) AS query_text, CASE WHEN query ILIKE '%COPY%TO%' THEN 'copy-export' WHEN query ILIKE '%dblink%' OR query ILIKE '%postgres_fdw%' THEN 'foreign-data' WHEN query ILIKE '%pg_dump%' THEN 'dump' WHEN query ILIKE '%SELECT%*%FROM%' AND EXTRACT(EPOCH FROM (now() - xact_start)) > 60 THEN 'long-running-extract' ELSE 'other' END AS exfil_type FROM pg_stat_activity WHERE state != 'idle' AND pid != pg_backend_pid() AND (query ILIKE '%COPY%TO%' OR query ILIKE '%dblink%' OR query ILIKE '%postgres_fdw%' OR query ILIKE '%pg_dump%' OR (query ILIKE '%SELECT%*%FROM%' AND EXTRACT(EPOCH FROM (now() - xact_start)) > 60))"},
        "expected": {"condition": "row_count > 0", "description": "Data exfiltration patterns detected - COPY export, foreign data wrappers, or long-running bulk reads", "severity": "critical"},
    },
]
vendor_queries["oracle"]["RC09"] = [
    {
        "name": "Detect data exfiltration patterns in transactions",
        "content": {"sql": "SELECT s.username AS login_name, s.machine AS host_name, s.program AS program_name, s.schemaname AS database_name, s.last_call_et AS elapsed_sec, SUBSTR(q.sql_text, 1, 500) AS query_text FROM v$session s JOIN v$sql q ON s.sql_id = q.sql_id AND s.sql_child_number = q.child_number WHERE s.type = 'USER' AND s.status = 'ACTIVE' AND (q.sql_text LIKE '%UTL_FILE%' OR q.sql_text LIKE '%UTL_HTTP%' OR q.sql_text LIKE '%DBMS_LOB%' OR q.sql_text LIKE '%CREATE%DATABASE LINK%' OR q.sql_text LIKE '%SELECT%*%FROM%' AND s.last_call_et > 60)"},
        "expected": {"condition": "row_count > 0", "description": "Data exfiltration patterns detected - UTL_FILE, UTL_HTTP, DB link, or long-running bulk reads", "severity": "critical"},
    },
]
vendor_queries["mysql"]["RC09"] = [
    {
        "name": "Detect data exfiltration patterns in transactions",
        "content": {"sql": "SELECT USER AS login_name, HOST AS host_name, DB AS database_name, TIME AS elapsed_sec, LEFT(INFO, 500) AS query_text, CASE WHEN INFO LIKE '%INTO OUTFILE%' OR INFO LIKE '%INTO DUMPFILE%' THEN 'file-export' WHEN INFO LIKE '%LOAD_FILE%' THEN 'file-read' WHEN INFO LIKE '%SELECT%*%FROM%' AND TIME > 60 THEN 'long-running-extract' ELSE 'other' END AS exfil_type FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep' AND ID != CONNECTION_ID() AND (INFO LIKE '%INTO OUTFILE%' OR INFO LIKE '%INTO DUMPFILE%' OR INFO LIKE '%LOAD_FILE%' OR (INFO LIKE '%SELECT%*%FROM%' AND TIME > 60))"},
        "expected": {"condition": "row_count > 0", "description": "Data exfiltration patterns detected - file export, file read, or long-running bulk reads", "severity": "critical"},
    },
]

# ---------------------------------------------------------------
# RC10: Same login from multiple hosts
# ---------------------------------------------------------------
vendor_queries["sqlserver"]["RC10"] = [
    {
        "name": "Detect same login active from multiple hosts",
        "content": {"sql": "SELECT s.login_name, COUNT(DISTINCT s.host_name) AS distinct_hosts, STRING_AGG(DISTINCT s.host_name, ', ') AS hosts, COUNT(*) AS total_sessions FROM sys.dm_exec_sessions s WHERE s.is_user_process = 1 AND s.status = 'running' GROUP BY s.login_name HAVING COUNT(DISTINCT s.host_name) > 1"},
        "expected": {"condition": "row_count > 0", "description": "Same login has concurrent sessions from multiple hosts - possible credential compromise", "severity": "high"},
    },
]
vendor_queries["postgresql"]["RC10"] = [
    {
        "name": "Detect same login active from multiple hosts",
        "content": {"sql": "SELECT usename AS login_name, COUNT(DISTINCT client_addr) AS distinct_hosts, STRING_AGG(DISTINCT client_addr::text, ', ') AS hosts, COUNT(*) AS total_sessions FROM pg_stat_activity WHERE state != 'idle' AND pid != pg_backend_pid() AND client_addr IS NOT NULL GROUP BY usename HAVING COUNT(DISTINCT client_addr) > 1"},
        "expected": {"condition": "row_count > 0", "description": "Same login has concurrent sessions from multiple hosts - possible credential compromise", "severity": "high"},
    },
]
vendor_queries["oracle"]["RC10"] = [
    {
        "name": "Detect same login active from multiple hosts",
        "content": {"sql": "SELECT username AS login_name, COUNT(DISTINCT machine) AS distinct_hosts, LISTAGG(DISTINCT machine, ', ') WITHIN GROUP (ORDER BY machine) AS hosts, COUNT(*) AS total_sessions FROM v$session WHERE type = 'USER' AND status = 'ACTIVE' AND machine IS NOT NULL GROUP BY username HAVING COUNT(DISTINCT machine) > 1"},
        "expected": {"condition": "row_count > 0", "description": "Same login has concurrent sessions from multiple hosts - possible credential compromise", "severity": "high"},
    },
]
vendor_queries["mysql"]["RC10"] = [
    {
        "name": "Detect same login active from multiple hosts",
        "content": {"sql": "SELECT USER AS login_name, COUNT(DISTINCT SUBSTRING_INDEX(HOST, ':', 1)) AS distinct_hosts, GROUP_CONCAT(DISTINCT SUBSTRING_INDEX(HOST, ':', 1)) AS hosts, COUNT(*) AS total_sessions FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep' AND ID != CONNECTION_ID() GROUP BY USER HAVING COUNT(DISTINCT SUBSTRING_INDEX(HOST, ':', 1)) > 1"},
        "expected": {"condition": "row_count > 0", "description": "Same login has concurrent sessions from multiple hosts - possible credential compromise", "severity": "high"},
    },
]

# ---------------------------------------------------------------
# RC11: Schema reconnaissance
# ---------------------------------------------------------------
vendor_queries["sqlserver"]["RC11"] = [
    {
        "name": "Detect schema reconnaissance in active transactions",
        "content": {"sql": "SELECT s.login_name, s.host_name, s.program_name, DB_NAME(r.database_id) AS database_name, r.total_elapsed_time / 1000 AS elapsed_sec, SUBSTRING(t.text, 1, 500) AS query_text, CASE WHEN t.text LIKE '%sys.objects%' OR t.text LIKE '%sysobjects%' THEN 'object-enumeration' WHEN t.text LIKE '%sys.columns%' OR t.text LIKE '%syscolumns%' THEN 'column-enumeration' WHEN t.text LIKE '%sys.server_principals%' OR t.text LIKE '%sys.database_principals%' THEN 'principal-enumeration' WHEN t.text LIKE '%sys.server_permissions%' OR t.text LIKE '%sys.database_permissions%' THEN 'permission-enumeration' WHEN t.text LIKE '%INFORMATION_SCHEMA%' THEN 'information-schema' WHEN t.text LIKE '%sys.configurations%' OR t.text LIKE '%sp_configure%' THEN 'config-enumeration' ELSE 'other-recon' END AS recon_type FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE s.is_user_process = 1 AND (t.text LIKE '%sys.objects%' OR t.text LIKE '%sysobjects%' OR t.text LIKE '%sys.columns%' OR t.text LIKE '%syscolumns%' OR t.text LIKE '%sys.server_principals%' OR t.text LIKE '%sys.database_principals%' OR t.text LIKE '%sys.server_permissions%' OR t.text LIKE '%sys.database_permissions%' OR t.text LIKE '%INFORMATION_SCHEMA.TABLES%' OR t.text LIKE '%INFORMATION_SCHEMA.COLUMNS%' OR t.text LIKE '%sys.configurations%' OR t.text LIKE '%sp_configure%')"},
        "expected": {"condition": "row_count > 0", "description": "Schema reconnaissance detected - user querying system catalogs to enumerate objects, columns, or permissions", "severity": "high"},
    },
]
vendor_queries["postgresql"]["RC11"] = [
    {
        "name": "Detect schema reconnaissance in active transactions",
        "content": {"sql": "SELECT usename AS login_name, client_addr AS host_name, application_name AS program_name, datname AS database_name, EXTRACT(EPOCH FROM (now() - xact_start))::int AS elapsed_sec, LEFT(query, 500) AS query_text, CASE WHEN query ILIKE '%pg_catalog.pg_tables%' OR query ILIKE '%pg_class%' THEN 'object-enumeration' WHEN query ILIKE '%pg_catalog.pg_attribute%' OR query ILIKE '%information_schema.columns%' THEN 'column-enumeration' WHEN query ILIKE '%pg_roles%' OR query ILIKE '%pg_authid%' THEN 'role-enumeration' WHEN query ILIKE '%pg_catalog.pg_hba%' THEN 'auth-enumeration' WHEN query ILIKE '%information_schema.table_privileges%' OR query ILIKE '%pg_catalog.pg_default_acl%' THEN 'permission-enumeration' WHEN query ILIKE '%pg_settings%' THEN 'config-enumeration' ELSE 'other-recon' END AS recon_type FROM pg_stat_activity WHERE state != 'idle' AND pid != pg_backend_pid() AND (query ILIKE '%pg_catalog.pg_tables%' OR query ILIKE '%pg_class%' OR query ILIKE '%pg_catalog.pg_attribute%' OR query ILIKE '%information_schema.columns%' OR query ILIKE '%information_schema.tables%' OR query ILIKE '%pg_roles%' OR query ILIKE '%pg_authid%' OR query ILIKE '%pg_catalog.pg_hba%' OR query ILIKE '%information_schema.table_privileges%' OR query ILIKE '%pg_settings%')"},
        "expected": {"condition": "row_count > 0", "description": "Schema reconnaissance detected - user querying system catalogs to enumerate objects, columns, or permissions", "severity": "high"},
    },
]
vendor_queries["oracle"]["RC11"] = [
    {
        "name": "Detect schema reconnaissance in active transactions",
        "content": {"sql": "SELECT s.username AS login_name, s.machine AS host_name, s.program AS program_name, s.schemaname AS database_name, s.last_call_et AS elapsed_sec, SUBSTR(q.sql_text, 1, 500) AS query_text FROM v$session s JOIN v$sql q ON s.sql_id = q.sql_id AND s.sql_child_number = q.child_number WHERE s.type = 'USER' AND s.status = 'ACTIVE' AND s.username NOT IN ('SYS','SYSTEM') AND (q.sql_text LIKE '%ALL_TABLES%' OR q.sql_text LIKE '%ALL_TAB_COLUMNS%' OR q.sql_text LIKE '%DBA_TABLES%' OR q.sql_text LIKE '%DBA_TAB_COLUMNS%' OR q.sql_text LIKE '%DBA_USERS%' OR q.sql_text LIKE '%DBA_ROLE_PRIVS%' OR q.sql_text LIKE '%DBA_SYS_PRIVS%' OR q.sql_text LIKE '%ALL_TAB_PRIVS%' OR q.sql_text LIKE '%V$PARAMETER%')"},
        "expected": {"condition": "row_count > 0", "description": "Schema reconnaissance detected - user querying data dictionary to enumerate objects, users, or privileges", "severity": "high"},
    },
]
vendor_queries["mysql"]["RC11"] = [
    {
        "name": "Detect schema reconnaissance in active transactions",
        "content": {"sql": "SELECT USER AS login_name, HOST AS host_name, DB AS database_name, TIME AS elapsed_sec, LEFT(INFO, 500) AS query_text FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep' AND ID != CONNECTION_ID() AND USER != 'root' AND (INFO LIKE '%information_schema.TABLES%' OR INFO LIKE '%information_schema.COLUMNS%' OR INFO LIKE '%information_schema.USER_PRIVILEGES%' OR INFO LIKE '%information_schema.SCHEMA_PRIVILEGES%' OR INFO LIKE '%mysql.user%' OR INFO LIKE '%mysql.db%' OR INFO LIKE '%SHOW GRANTS%' OR INFO LIKE '%SHOW CREATE TABLE%')"},
        "expected": {"condition": "row_count > 0", "description": "Schema reconnaissance detected - user querying system tables to enumerate objects, users, or privileges", "severity": "high"},
    },
]

# ---------------------------------------------------------------
# RC12: Dormant account suddenly active
# ---------------------------------------------------------------
vendor_queries["sqlserver"]["RC12"] = [
    {
        "name": "Detect dormant accounts with active transactions",
        "content": {"sql": "SELECT s.login_name, s.host_name, s.program_name, DB_NAME(r.database_id) AS database_name, l.login_time AS session_start, DATEDIFF(DAY, p.modify_date, GETDATE()) AS days_since_last_modification, SUBSTRING(t.text, 1, 500) AS query_text FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t JOIN sys.dm_exec_sessions l ON r.session_id = l.session_id JOIN sys.server_principals p ON s.login_name = p.name WHERE s.is_user_process = 1 AND p.type IN ('S','U') AND DATEDIFF(DAY, p.modify_date, GETDATE()) > 30"},
        "expected": {"condition": "row_count > 0", "description": "Account not modified in 30+ days is now running transactions - dormant account reactivation", "severity": "high"},
    },
]
vendor_queries["postgresql"]["RC12"] = [
    {
        "name": "Detect dormant accounts with active transactions",
        "content": {"sql": "WITH last_activity AS (SELECT usename, MAX(backend_start) AS last_seen FROM pg_stat_activity GROUP BY usename) SELECT a.usename AS login_name, a.client_addr AS host_name, a.application_name AS program_name, a.datname AS database_name, EXTRACT(EPOCH FROM (now() - a.xact_start))::int AS elapsed_sec, LEFT(a.query, 500) AS query_text, r.rolvaliduntil, CASE WHEN r.rolconnlimit = 0 THEN 'restricted' ELSE 'normal' END AS account_status FROM pg_stat_activity a JOIN pg_roles r ON a.usename = r.rolname WHERE a.state != 'idle' AND a.pid != pg_backend_pid() AND (r.rolvaliduntil IS NOT NULL AND r.rolvaliduntil < now() + interval '30 days')"},
        "expected": {"condition": "row_count > 0", "description": "Account with expiring or expired credentials is running transactions - verify legitimacy", "severity": "high"},
    },
]
vendor_queries["oracle"]["RC12"] = [
    {
        "name": "Detect dormant accounts with active transactions",
        "content": {"sql": "SELECT s.username AS login_name, s.machine AS host_name, s.program AS program_name, s.schemaname AS database_name, s.last_call_et AS elapsed_sec, SUBSTR(q.sql_text, 1, 500) AS query_text, u.expiry_date, u.lock_date, TRUNC(SYSDATE - NVL(u.expiry_date, SYSDATE)) AS days_past_expiry FROM v$session s JOIN v$sql q ON s.sql_id = q.sql_id AND s.sql_child_number = q.child_number JOIN dba_users u ON s.username = u.username WHERE s.type = 'USER' AND s.status = 'ACTIVE' AND (u.account_status LIKE '%EXPIRED%' OR (u.expiry_date IS NOT NULL AND u.expiry_date < SYSDATE + 30))"},
        "expected": {"condition": "row_count > 0", "description": "Account with expired or soon-expiring credentials is running transactions - possible dormant account reuse", "severity": "high"},
    },
]
vendor_queries["mysql"]["RC12"] = [
    {
        "name": "Detect dormant accounts with active transactions",
        "content": {"sql": "SELECT p.USER AS login_name, p.HOST AS host_name, p.DB AS database_name, p.TIME AS elapsed_sec, LEFT(p.INFO, 500) AS query_text, u.password_last_changed, DATEDIFF(NOW(), u.password_last_changed) AS days_since_pwd_change FROM information_schema.PROCESSLIST p JOIN mysql.user u ON p.USER = u.User WHERE p.COMMAND != 'Sleep' AND p.ID != CONNECTION_ID() AND u.password_last_changed IS NOT NULL AND DATEDIFF(NOW(), u.password_last_changed) > 90"},
        "expected": {"condition": "row_count > 0", "description": "Account with password unchanged for 90+ days is running transactions - possible dormant account", "severity": "high"},
    },
]

# ---------------------------------------------------------------
# RC13: Mass data modification
# ---------------------------------------------------------------
vendor_queries["sqlserver"]["RC13"] = [
    {
        "name": "Detect mass data modification in active transactions",
        "content": {"sql": "SELECT s.login_name, s.host_name, s.program_name, DB_NAME(r.database_id) AS database_name, r.total_elapsed_time / 1000 AS elapsed_sec, r.row_count AS rows_affected, r.command, SUBSTRING(t.text, 1, 500) AS query_text FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE s.is_user_process = 1 AND r.command IN ('UPDATE','DELETE') AND r.row_count > 1000"},
        "expected": {"condition": "row_count > 0", "description": "Mass UPDATE/DELETE affecting 1000+ rows in active transaction - potential data destruction or unauthorized modification", "severity": "critical"},
    },
]
vendor_queries["postgresql"]["RC13"] = [
    {
        "name": "Detect mass data modification in active transactions",
        "content": {"sql": "SELECT usename AS login_name, client_addr AS host_name, application_name AS program_name, datname AS database_name, EXTRACT(EPOCH FROM (now() - xact_start))::int AS elapsed_sec, LEFT(query, 500) AS query_text, CASE WHEN query ILIKE 'UPDATE%' THEN 'UPDATE' WHEN query ILIKE 'DELETE%' THEN 'DELETE' WHEN query ILIKE 'TRUNCATE%' THEN 'TRUNCATE' END AS operation FROM pg_stat_activity WHERE state = 'active' AND pid != pg_backend_pid() AND (query ILIKE 'DELETE%' OR query ILIKE 'TRUNCATE%' OR (query ILIKE 'UPDATE%' AND EXTRACT(EPOCH FROM (now() - xact_start)) > 30))"},
        "expected": {"condition": "row_count > 0", "description": "Mass DELETE/UPDATE/TRUNCATE detected in active transactions - potential data destruction", "severity": "critical"},
    },
]
vendor_queries["oracle"]["RC13"] = [
    {
        "name": "Detect mass data modification in active transactions",
        "content": {"sql": "SELECT s.username AS login_name, s.machine AS host_name, s.program AS program_name, s.schemaname AS database_name, s.last_call_et AS elapsed_sec, t.used_ublk AS undo_blocks, SUBSTR(q.sql_text, 1, 500) AS query_text FROM v$session s JOIN v$sql q ON s.sql_id = q.sql_id AND s.sql_child_number = q.child_number JOIN v$transaction t ON s.taddr = t.addr WHERE s.type = 'USER' AND s.status = 'ACTIVE' AND t.used_ublk > 1000 AND (q.sql_text LIKE '%UPDATE%' OR q.sql_text LIKE '%DELETE%' OR q.sql_text LIKE '%TRUNCATE%')"},
        "expected": {"condition": "row_count > 0", "description": "Mass data modification using 1000+ undo blocks - potential data destruction or unauthorized bulk change", "severity": "critical"},
    },
]
vendor_queries["mysql"]["RC13"] = [
    {
        "name": "Detect mass data modification in active transactions",
        "content": {"sql": "SELECT p.USER AS login_name, p.HOST AS host_name, p.DB AS database_name, p.TIME AS elapsed_sec, LEFT(p.INFO, 500) AS query_text, CASE WHEN p.INFO LIKE 'UPDATE%' THEN 'UPDATE' WHEN p.INFO LIKE 'DELETE%' THEN 'DELETE' WHEN p.INFO LIKE 'TRUNCATE%' THEN 'TRUNCATE' END AS operation FROM information_schema.PROCESSLIST p WHERE p.COMMAND != 'Sleep' AND p.ID != CONNECTION_ID() AND p.INFO IS NOT NULL AND (p.INFO LIKE 'DELETE%' OR p.INFO LIKE 'TRUNCATE%' OR (p.INFO LIKE 'UPDATE%' AND p.TIME > 30))"},
        "expected": {"condition": "row_count > 0", "description": "Mass DELETE/UPDATE/TRUNCATE detected in active transactions - potential data destruction", "severity": "critical"},
    },
]

# 4. Insert detection steps, paths, path_steps
rc_map = {}
for i in range(len(root_causes)):
    key = f"RC0{i+1}" if i < 9 else f"RC{i+1}"
    rc_map[key] = root_causes[i]

for vendor_slug, rcs in vendor_queries.items():
    for rc_key, steps in rcs.items():
        rc_id = rc_map[rc_key]["id"]

        cur.execute("""
            INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
            VALUES (%s, %s, %s, %s, 'primary', true)
            RETURNING id
        """, (
            rc_id, vendor_slug,
            f"Detect {rc_map[rc_key]['name'].lower()} ({vendor_slug})",
            f"Detection path for {rc_map[rc_key]['name']} on {vendor_slug}"
        ))
        path_id = cur.fetchone()[0]

        for idx, step in enumerate(steps):
            cur.execute("""
                INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
                VALUES (%s, 'sql_query', %s, %s, %s)
                RETURNING id
            """, (
                vendor_slug, step["name"],
                json.dumps(step["content"]),
                json.dumps(step["expected"])
            ))
            step_id = cur.fetchone()[0]

            on_match = "confirmed" if idx == len(steps) - 1 else "next"
            cur.execute("""
                INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
                VALUES (%s, %s, %s, %s, 'ruled_out')
            """, (path_id, step_id, idx + 1, on_match))

conn.commit()

# Verify
cur.execute("""
    SELECT v.root_cause_id, v.root_cause_name, v.vendor_name, v.step_name,
           v.expected->>'severity' AS severity
    FROM rootcause.v_rootcauses v
    WHERE v.issue_id = 'SEC-SQL-ACC-010'
    ORDER BY v.root_cause_id, v.vendor_name
""")
rows = cur.fetchall()
print(f"Inserted {len(rows)} detection entries:\n")
for r in rows:
    print(f"  {r[0]} | {r[2]:12s} | {r[4]:8s} | {r[3]}")

conn.close()
print("\nDone!")
