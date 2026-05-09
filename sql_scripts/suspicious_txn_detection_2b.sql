-- Detection paths: SEC-SQL-AUD-010, 011, 012
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
-- SEC-SQL-AUD-010-RC01  Excessive catalog enumeration
-- ============================================================
CALL rootcause.add_detection_path('SEC-SQL-AUD-010-RC01','postgresql',
  'Detect excessive catalog enumeration - PostgreSQL',
  'Counts information_schema and pg_catalog queries per session in a short window to identify automated schema mapping',
  'Count catalog queries per session in last 5 minutes',
  'SELECT usename, count(*) AS catalog_queries, max(query_start) AS last_seen
   FROM pg_stat_activity
   WHERE state IN (''active'',''idle in transaction'')
     AND (query ILIKE ''%information_schema%'' OR query ILIKE ''%pg_catalog%'' OR query ILIKE ''%pg_class%'')
     AND query_start > now() - interval ''5 minutes''
   GROUP BY usename
   HAVING count(*) > 20',
  '{"condition":"row_count > 0","description":"Session queried catalog objects more than 20 times in 5 minutes  -- automated enumeration pattern"}',
  'Check pg_stat_statements for catalog query frequency by account',
  'SELECT userid::regrole AS username, count(*) AS distinct_catalog_queries, sum(calls) AS total_calls
   FROM pg_stat_statements
   WHERE (query ILIKE ''%information_schema%'' OR query ILIKE ''%pg_catalog%'')
   GROUP BY userid
   ORDER BY total_calls DESC
   LIMIT 10',
  '{"condition":"row_count > 0","description":"Account shows high catalog query frequency in statement history  -- confirm enumeration scope"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-010-RC01','sqlserver',
  'Detect excessive catalog enumeration - SQL Server',
  'Identifies sessions with a high volume of INFORMATION_SCHEMA or sys object queries in a short window',
  'Count catalog queries per login in recent history',
  'SELECT s.login_name, count(*) AS catalog_queries, max(r.start_time) AS last_seen
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_query_stats qs ON s.session_id = qs.last_execution_time
   CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) t
   WHERE (t.text LIKE ''%INFORMATION_SCHEMA%'' OR t.text LIKE ''%sys.objects%''
          OR t.text LIKE ''%sys.columns%'' OR t.text LIKE ''%sys.tables%'')
     AND qs.last_execution_time > DATEADD(minute,-5,GETDATE())
   GROUP BY s.login_name
   HAVING count(*) > 20',
  '{"condition":"row_count > 0","description":"Login executed more than 20 catalog queries in 5 minutes  -- schema enumeration pattern"}',
  'Check Query Store for catalog query volume by login',
  'SELECT TOP 10 s.login_name, count(DISTINCT qt.query_sql_text) AS catalog_query_variants
   FROM sys.query_store_query_text qt
   JOIN sys.query_store_query q ON q.query_text_id = qt.query_text_id
   JOIN sys.query_store_runtime_stats rs ON rs.plan_id IN (SELECT plan_id FROM sys.query_store_plan WHERE query_id = q.query_id)
   JOIN sys.dm_exec_sessions s ON s.session_id = rs.last_execution_time
   WHERE qt.query_sql_text LIKE ''%INFORMATION_SCHEMA%'' OR qt.query_sql_text LIKE ''%sys.columns%''
   GROUP BY s.login_name
   ORDER BY catalog_query_variants DESC',
  '{"condition":"row_count > 0","description":"Login has many distinct catalog query variants  -- automated schema mapping confirmed"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-010-RC01','mysql',
  'Detect excessive catalog enumeration - MySQL',
  'Identifies accounts with abnormally high information_schema query counts in performance_schema',
  'Check active queries against information_schema',
  'SELECT USER, HOST, count(*) AS active_catalog_queries
   FROM INFORMATION_SCHEMA.PROCESSLIST
   WHERE COMMAND = ''Query''
     AND (INFO LIKE ''%information_schema%'' OR INFO LIKE ''%SHOW TABLES%'' OR INFO LIKE ''%SHOW DATABASES%'')
   GROUP BY USER, HOST
   HAVING count(*) > 5',
  '{"condition":"row_count > 0","description":"Account has 5+ concurrent catalog queries  -- automated enumeration pattern"}',
  'Check statement digest for high-frequency catalog queries',
  'SELECT CURRENT_USER_HOST, DIGEST_TEXT, COUNT_STAR, LAST_SEEN
   FROM performance_schema.events_statements_summary_by_digest
   WHERE (DIGEST_TEXT LIKE ''%information_schema%'' OR DIGEST_TEXT LIKE ''%SHOW TABLES%'')
     AND COUNT_STAR > 50
   ORDER BY COUNT_STAR DESC
   LIMIT 10',
  '{"condition":"row_count > 0","description":"Catalog query digest count exceeds 50  -- confirms systematic enumeration"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-010-RC01','oracle',
  'Detect excessive catalog enumeration - Oracle',
  'Finds sessions with unusually high ALL_ or DBA_ dictionary query counts',
  'Count dictionary queries per session in last 10 minutes',
  'SELECT s.username, s.sid, count(*) AS dict_queries
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE (UPPER(q.sql_text) LIKE ''%ALL_TABLES%'' OR UPPER(q.sql_text) LIKE ''%DBA_COLUMNS%''
          OR UPPER(q.sql_text) LIKE ''%ALL_OBJECTS%'' OR UPPER(q.sql_text) LIKE ''%DBA_TAB_COLUMNS%'')
     AND q.last_active_time > SYSDATE - 10/1440
   GROUP BY s.username, s.sid
   HAVING count(*) > 20',
  '{"condition":"row_count > 0","description":"Session issued 20+ dictionary queries in 10 minutes  -- automated catalog mapping pattern"}',
  'Confirm via unified audit trail',
  'SELECT db_username, count(*) AS dict_accesses, max(event_timestamp) AS last_seen
   FROM unified_audit_trail
   WHERE (object_name LIKE ''ALL_TABLES'' OR object_name LIKE ''DBA_COLUMNS'' OR object_name LIKE ''ALL_OBJECTS'')
     AND event_timestamp > systimestamp - interval ''1'' hour
   GROUP BY db_username
   HAVING count(*) > 50',
  '{"condition":"row_count > 0","description":"Unified audit confirms high-volume dictionary access  -- schema enumeration"}'
);

-- ============================================================
-- SEC-SQL-AUD-010-RC02  User enumeration by non-admin
-- ============================================================
CALL rootcause.add_detection_path('SEC-SQL-AUD-010-RC02','postgresql',
  'Detect user enumeration by non-admin - PostgreSQL',
  'Finds non-superuser sessions querying pg_roles, pg_user, or pg_shadow',
  'Scan active queries for principal catalog access by non-superuser',
  'SELECT pid, usename, query, client_addr, query_start
   FROM pg_stat_activity
   WHERE state = ''active''
     AND (query ILIKE ''%pg_roles%'' OR query ILIKE ''%pg_user%'' OR query ILIKE ''%pg_shadow%'')
     AND usename NOT IN (SELECT rolname FROM pg_roles WHERE rolsuper)',
  '{"condition":"row_count > 0","description":"Non-superuser account is querying principal catalog views  -- user enumeration pattern"}',
  'Confirm in pg_stat_statements history',
  'SELECT userid::regrole AS username, query, calls
   FROM pg_stat_statements
   WHERE (query ILIKE ''%pg_roles%'' OR query ILIKE ''%pg_user%'' OR query ILIKE ''%pg_shadow%'')
   ORDER BY calls DESC
   LIMIT 10',
  '{"condition":"row_count > 0","description":"pg_roles / pg_user queries found in statement history  -- user enumeration confirmed"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-010-RC02','sqlserver',
  'Detect user enumeration by non-admin - SQL Server',
  'Identifies non-sysadmin sessions querying sys.server_principals or sys.database_principals',
  'Check active requests for principal view access by non-sysadmin',
  'SELECT s.login_name, s.is_sysadmin, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE s.is_sysadmin = 0
     AND (t.text LIKE ''%sys.server_principals%'' OR t.text LIKE ''%sys.database_principals%''
          OR t.text LIKE ''%sys.sql_logins%'')',
  '{"condition":"row_count > 0","description":"Non-sysadmin login querying principal views  -- user enumeration pattern"}',
  'Check Query Store for principal view query history',
  'SELECT qt.query_sql_text, rs.count_executions, rs.last_execution_time
   FROM sys.query_store_query_text qt
   JOIN sys.query_store_query q ON q.query_text_id = qt.query_text_id
   JOIN sys.query_store_plan qp ON qp.query_id = q.query_id
   JOIN sys.query_store_runtime_stats rs ON rs.plan_id = qp.plan_id
   WHERE qt.query_sql_text LIKE ''%sys.server_principals%'' OR qt.query_sql_text LIKE ''%sys.database_principals%''
   ORDER BY rs.last_execution_time DESC',
  '{"condition":"row_count > 0","description":"Principal view queries in Query Store  -- user enumeration history confirmed"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-010-RC02','mysql',
  'Detect user enumeration by non-admin - MySQL',
  'Identifies non-DBA accounts querying mysql.user or performance_schema user tables',
  'Check active queries for mysql.user access by non-admin',
  'SELECT ID, USER, HOST, DB, TIME, INFO
   FROM INFORMATION_SCHEMA.PROCESSLIST
   WHERE COMMAND = ''Query''
     AND (INFO LIKE ''%mysql.user%'' OR INFO LIKE ''%SHOW GRANTS%'' OR INFO LIKE ''%performance_schema%users%'')
     AND USER NOT IN (SELECT user FROM mysql.user WHERE Super_priv = ''Y'')',
  '{"condition":"row_count > 0","description":"Non-admin account querying mysql.user or user grant tables  -- user enumeration pattern"}',
  'Check digest history for mysql.user access patterns',
  'SELECT DIGEST_TEXT, COUNT_STAR, LAST_SEEN
   FROM performance_schema.events_statements_summary_by_digest
   WHERE DIGEST_TEXT LIKE ''%mysql . user%'' OR DIGEST_TEXT LIKE ''%SHOW GRANTS%''
   ORDER BY LAST_SEEN DESC
   LIMIT 10',
  '{"condition":"row_count > 0","description":"mysql.user access pattern in statement digest history  -- user enumeration confirmed"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-010-RC02','oracle',
  'Detect user enumeration by non-admin - Oracle',
  'Finds non-DBA sessions querying DBA_USERS, ALL_USERS, or V$SESSION for user listing',
  'Scan V$SQL for DBA_USERS access by non-DBA accounts',
  'SELECT s.username, s.sid, s.osuser, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE (UPPER(q.sql_text) LIKE ''%DBA_USERS%'' OR UPPER(q.sql_text) LIKE ''%ALL_USERS%'')
     AND s.username NOT IN (SELECT grantee FROM dba_sys_privs WHERE privilege = ''CREATE USER'')
     AND q.last_active_time > SYSDATE - 1/24',
  '{"condition":"row_count > 0","description":"Non-admin account accessed DBA_USERS or ALL_USERS within last hour  -- user enumeration pattern"}',
  'Confirm in unified audit trail',
  'SELECT db_username, count(*) AS user_view_accesses, max(event_timestamp) AS last_seen
   FROM unified_audit_trail
   WHERE object_name IN (''DBA_USERS'',''ALL_USERS'')
     AND event_timestamp > systimestamp - interval ''1'' hour
   GROUP BY db_username
   ORDER BY user_view_accesses DESC',
  '{"condition":"row_count > 0","description":"User view access confirmed in unified audit trail"}'
);

-- ============================================================
-- SEC-SQL-AUD-010-RC03  Mass table / column listing
-- ============================================================
CALL rootcause.add_detection_path('SEC-SQL-AUD-010-RC03','postgresql',
  'Detect mass column listing - PostgreSQL',
  'Finds sessions querying information_schema.columns across all tables in rapid succession',
  'Scan active queries for information_schema.columns enumeration',
  'SELECT pid, usename, query, client_addr, query_start
   FROM pg_stat_activity
   WHERE state = ''active''
     AND (query ILIKE ''%information_schema.columns%'' OR query ILIKE ''%pg_attribute%'')
     AND query NOT LIKE ''%table_name = %''',
  '{"condition":"row_count > 0","description":"Active query enumerates columns without table filter  -- mass column listing pattern"}',
  'Check pg_stat_statements for broad column listing queries',
  'SELECT userid::regrole AS username, query, calls, rows
   FROM pg_stat_statements
   WHERE (query ILIKE ''%information_schema.columns%'' OR query ILIKE ''%pg_attribute%'')
     AND rows > 500
   ORDER BY rows DESC
   LIMIT 10',
  '{"condition":"row_count > 0","description":"Column listing queries returning 500+ rows in statement history  -- mass enumeration confirmed"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-010-RC03','sqlserver',
  'Detect mass column listing - SQL Server',
  'Identifies sessions running broad INFORMATION_SCHEMA.COLUMNS queries without table filter',
  'Check active requests for unfiltered COLUMNS enumeration',
  'SELECT s.login_name, t.text, r.start_time, r.row_count
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE ''%INFORMATION_SCHEMA%COLUMNS%''
     AND t.text NOT LIKE ''%TABLE_NAME%=% ''',
  '{"condition":"row_count > 0","description":"Active request enumerates all columns without table filter  -- mass listing pattern"}',
  'Check Query Store for broad column enumeration history',
  'SELECT qt.query_sql_text, rs.count_executions, rs.avg_rowcount
   FROM sys.query_store_query_text qt
   JOIN sys.query_store_query q ON q.query_text_id = qt.query_text_id
   JOIN sys.query_store_plan qp ON qp.query_id = q.query_id
   JOIN sys.query_store_runtime_stats rs ON rs.plan_id = qp.plan_id
   WHERE qt.query_sql_text LIKE ''%INFORMATION_SCHEMA%COLUMNS%'' AND rs.avg_rowcount > 500',
  '{"condition":"row_count > 0","description":"Mass column listing queries with high row count in Query Store history"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-010-RC03','mysql',
  'Detect mass column listing - MySQL',
  'Identifies accounts querying information_schema.columns for all tables without a specific table filter',
  'Check active queries for unfiltered column enumeration',
  'SELECT ID, USER, HOST, DB, TIME, INFO
   FROM INFORMATION_SCHEMA.PROCESSLIST
   WHERE COMMAND = ''Query''
     AND INFO LIKE ''%information_schema%columns%''
     AND INFO NOT REGEXP ''TABLE_NAME\s*=\s*''',
  '{"condition":"row_count > 0","description":"Active query enumerates all columns without table restriction  -- mass listing indicator"}',
  'Check performance_schema for bulk column query digests',
  'SELECT DIGEST_TEXT, COUNT_STAR, SUM_ROWS_SENT, LAST_SEEN
   FROM performance_schema.events_statements_summary_by_digest
   WHERE DIGEST_TEXT LIKE ''%information_schema%columns%'' AND SUM_ROWS_SENT > 1000
   ORDER BY SUM_ROWS_SENT DESC
   LIMIT 10',
  '{"condition":"row_count > 0","description":"Column enumeration queries with 1000+ rows sent  -- mass listing confirmed"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-010-RC03','oracle',
  'Detect mass column listing - Oracle',
  'Finds sessions querying ALL_COLUMNS or DBA_TAB_COLUMNS without an owner or table filter',
  'Scan V$SQL for unfiltered ALL_COLUMNS access',
  'SELECT s.username, s.sid, q.sql_text, q.rows_processed, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE (UPPER(q.sql_text) LIKE ''%ALL_COLUMNS%'' OR UPPER(q.sql_text) LIKE ''%DBA_TAB_COLUMNS%'')
     AND q.sql_text NOT LIKE ''%OWNER =''
     AND q.sql_text NOT LIKE ''%TABLE_NAME =''
     AND q.last_active_time > SYSDATE - 1/24
   ORDER BY q.rows_processed DESC',
  '{"condition":"row_count > 0","description":"Unfiltered ALL_COLUMNS access in V$SQL  -- mass column inventory pattern"}',
  'Confirm via unified audit trail with high row counts',
  'SELECT db_username, count(*) AS accesses, max(event_timestamp) AS last_seen
   FROM unified_audit_trail
   WHERE object_name IN (''ALL_COLUMNS'',''DBA_TAB_COLUMNS'')
     AND event_timestamp > systimestamp - interval ''30'' minute
   GROUP BY db_username
   HAVING count(*) > 10',
  '{"condition":"row_count > 0","description":"Repeated ALL_COLUMNS access in audit trail  -- mass enumeration confirmed"}'
);

-- ============================================================
-- SEC-SQL-AUD-010-RC04  Stored procedure source enumeration
-- ============================================================
CALL rootcause.add_detection_path('SEC-SQL-AUD-010-RC04','postgresql',
  'Detect stored procedure source enumeration - PostgreSQL',
  'Identifies non-superuser sessions reading pg_proc.prosrc or information_schema.routines',
  'Scan active queries for pg_proc or routines source access',
  'SELECT pid, usename, query, client_addr, query_start
   FROM pg_stat_activity
   WHERE state = ''active''
     AND (query ILIKE ''%pg_proc%'' OR query ILIKE ''%information_schema.routines%'')
     AND (query ILIKE ''%prosrc%'' OR query ILIKE ''%routine_definition%'')
     AND usename NOT IN (SELECT rolname FROM pg_roles WHERE rolsuper)',
  '{"condition":"row_count > 0","description":"Non-superuser reading procedure source code from catalog  -- source enumeration pattern"}',
  'Check pg_stat_statements for procedure source read history',
  'SELECT userid::regrole AS username, query, calls
   FROM pg_stat_statements
   WHERE (query ILIKE ''%pg_proc%'' AND query ILIKE ''%prosrc%'')
      OR (query ILIKE ''%information_schema.routines%'' AND query ILIKE ''%routine_definition%'')
   ORDER BY calls DESC
   LIMIT 10',
  '{"condition":"row_count > 0","description":"Procedure source read queries in statement history  -- enumeration activity confirmed"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-010-RC04','sqlserver',
  'Detect stored procedure source enumeration - SQL Server',
  'Finds non-sysadmin sessions reading sys.sql_modules or INFORMATION_SCHEMA.ROUTINES',
  'Check active requests for procedure definition access',
  'SELECT s.login_name, s.is_sysadmin, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE s.is_sysadmin = 0
     AND (t.text LIKE ''%sys.sql_modules%'' OR t.text LIKE ''%INFORMATION_SCHEMA%ROUTINES%'')',
  '{"condition":"row_count > 0","description":"Non-sysadmin login reading procedure definitions  -- source enumeration pattern"}',
  'Check Query Store for routine definition query history',
  'SELECT qt.query_sql_text, rs.count_executions, rs.last_execution_time
   FROM sys.query_store_query_text qt
   JOIN sys.query_store_query q ON q.query_text_id = qt.query_text_id
   JOIN sys.query_store_plan qp ON qp.query_id = q.query_id
   JOIN sys.query_store_runtime_stats rs ON rs.plan_id = qp.plan_id
   WHERE qt.query_sql_text LIKE ''%sys.sql_modules%'' OR qt.query_sql_text LIKE ''%INFORMATION_SCHEMA%ROUTINES%''
   ORDER BY rs.last_execution_time DESC',
  '{"condition":"row_count > 0","description":"Procedure definition queries in Query Store  -- source enumeration history confirmed"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-010-RC04','mysql',
  'Detect stored procedure source enumeration - MySQL',
  'Identifies accounts accessing ROUTINE_DEFINITION in information_schema.routines',
  'Check active queries for routine definition access',
  'SELECT ID, USER, HOST, DB, TIME, INFO
   FROM INFORMATION_SCHEMA.PROCESSLIST
   WHERE COMMAND = ''Query''
     AND INFO LIKE ''%ROUTINE_DEFINITION%''
     AND USER NOT IN (SELECT user FROM mysql.user WHERE Super_priv = ''Y'')',
  '{"condition":"row_count > 0","description":"Non-admin account reading ROUTINE_DEFINITION from information_schema  -- procedure source enumeration"}',
  'Check digest history for routine definition queries',
  'SELECT DIGEST_TEXT, COUNT_STAR, LAST_SEEN
   FROM performance_schema.events_statements_summary_by_digest
   WHERE DIGEST_TEXT LIKE ''%ROUTINE_DEFINITION%''
   ORDER BY LAST_SEEN DESC
   LIMIT 10',
  '{"condition":"row_count > 0","description":"ROUTINE_DEFINITION access in digest history  -- procedure source reading confirmed"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-010-RC04','oracle',
  'Detect stored procedure source enumeration - Oracle',
  'Finds non-DBA sessions querying ALL_SOURCE or DBA_SOURCE for procedure bodies',
  'Scan V$SQL for ALL_SOURCE or DBA_SOURCE access',
  'SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE (UPPER(q.sql_text) LIKE ''%ALL_SOURCE%'' OR UPPER(q.sql_text) LIKE ''%DBA_SOURCE%'')
     AND s.username NOT IN (SELECT grantee FROM dba_sys_privs WHERE privilege = ''CREATE ANY PROCEDURE'')
     AND q.last_active_time > SYSDATE - 1/24',
  '{"condition":"row_count > 0","description":"Non-DBA account accessed ALL_SOURCE or DBA_SOURCE in last hour  -- procedure source enumeration"}',
  'Confirm in unified audit trail',
  'SELECT db_username, count(*) AS source_accesses, max(event_timestamp) AS last_seen
   FROM unified_audit_trail
   WHERE object_name IN (''ALL_SOURCE'',''DBA_SOURCE'')
     AND event_timestamp > systimestamp - interval ''1'' hour
   GROUP BY db_username
   ORDER BY source_accesses DESC',
  '{"condition":"row_count > 0","description":"ALL_SOURCE / DBA_SOURCE access in unified audit trail  -- confirmed"}'
);

-- ============================================================
-- SEC-SQL-AUD-010-RC05  Permission / privilege discovery
-- ============================================================
CALL rootcause.add_detection_path('SEC-SQL-AUD-010-RC05','postgresql',
  'Detect privilege discovery queries - PostgreSQL',
  'Finds sessions systematically calling has_table_privilege or querying role_table_grants',
  'Scan active queries for privilege introspection functions',
  'SELECT pid, usename, query, client_addr, query_start
   FROM pg_stat_activity
   WHERE state = ''active''
     AND (query ILIKE ''%has_table_privilege%'' OR query ILIKE ''%has_schema_privilege%''
          OR query ILIKE ''%role_table_grants%'' OR query ILIKE ''%information_schema%privileges%'')',
  '{"condition":"row_count > 0","description":"Active session calling privilege introspection functions  -- privilege mapping pattern"}',
  'Check pg_stat_statements for privilege query frequency',
  'SELECT userid::regrole AS username, query, calls
   FROM pg_stat_statements
   WHERE (query ILIKE ''%has_table_privilege%'' OR query ILIKE ''%role_table_grants%'')
   ORDER BY calls DESC
   LIMIT 10',
  '{"condition":"row_count > 0","description":"Privilege introspection queries in statement history  -- systematic privilege mapping confirmed"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-010-RC05','sqlserver',
  'Detect privilege discovery queries - SQL Server',
  'Identifies sessions calling fn_my_permissions or querying sys.database_permissions',
  'Check active requests for permission discovery functions',
  'SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE ''%fn_my_permissions%'' OR t.text LIKE ''%sys.database_permissions%''
      OR t.text LIKE ''%sys.server_permissions%''',
  '{"condition":"row_count > 0","description":"Active request using permission discovery functions  -- privilege mapping pattern"}',
  'Confirm via Query Store history',
  'SELECT qt.query_sql_text, rs.count_executions
   FROM sys.query_store_query_text qt
   JOIN sys.query_store_query q ON q.query_text_id = qt.query_text_id
   JOIN sys.query_store_plan qp ON qp.query_id = q.query_id
   JOIN sys.query_store_runtime_stats rs ON rs.plan_id = qp.plan_id
   WHERE qt.query_sql_text LIKE ''%fn_my_permissions%'' OR qt.query_sql_text LIKE ''%sys.database_permissions%''
   ORDER BY rs.count_executions DESC',
  '{"condition":"row_count > 0","description":"Permission discovery queries in Query Store  -- systematic privilege mapping confirmed"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-010-RC05','mysql',
  'Detect privilege discovery queries - MySQL',
  'Finds accounts querying information_schema privilege views or running SHOW GRANTS',
  'Check active queries for privilege discovery',
  'SELECT ID, USER, HOST, DB, TIME, INFO
   FROM INFORMATION_SCHEMA.PROCESSLIST
   WHERE COMMAND = ''Query''
     AND (INFO LIKE ''%schema_privileges%'' OR INFO LIKE ''%table_privileges%''
          OR INFO LIKE ''%user_privileges%'' OR INFO REGEXP ''SHOW[[:space:]]+GRANTS'')',
  '{"condition":"row_count > 0","description":"Active query accessing privilege information views  -- privilege discovery pattern"}',
  'Check digest history for privilege view access frequency',
  'SELECT DIGEST_TEXT, COUNT_STAR, LAST_SEEN
   FROM performance_schema.events_statements_summary_by_digest
   WHERE (DIGEST_TEXT LIKE ''%schema_privileges%'' OR DIGEST_TEXT LIKE ''%table_privileges%''
          OR DIGEST_TEXT REGEXP ''SHOW GRANTS'')
   ORDER BY COUNT_STAR DESC
   LIMIT 10',
  '{"condition":"row_count > 0","description":"Privilege discovery pattern in digest history  -- systematic mapping confirmed"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-010-RC05','oracle',
  'Detect privilege discovery queries - Oracle',
  'Finds sessions querying DBA_SYS_PRIVS, DBA_TAB_PRIVS, or SESSION_PRIVS in bulk',
  'Scan V$SQL for privilege view access patterns',
  'SELECT s.username, s.sid, q.sql_text, q.executions, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE (UPPER(q.sql_text) LIKE ''%DBA_SYS_PRIVS%'' OR UPPER(q.sql_text) LIKE ''%DBA_TAB_PRIVS%''
          OR UPPER(q.sql_text) LIKE ''%DBA_ROLE_PRIVS%'' OR UPPER(q.sql_text) LIKE ''%SESSION_PRIVS%'')
     AND s.username NOT IN (SELECT grantee FROM dba_sys_privs WHERE privilege = ''CREATE USER'')
     AND q.last_active_time > SYSDATE - 1/24',
  '{"condition":"row_count > 0","description":"Non-admin account accessing DBA privilege views in last hour  -- privilege discovery pattern"}',
  'Check unified audit trail for privilege view query burst',
  'SELECT db_username, count(*) AS priv_view_accesses, max(event_timestamp) AS last_seen
   FROM unified_audit_trail
   WHERE object_name IN (''DBA_SYS_PRIVS'',''DBA_TAB_PRIVS'',''DBA_ROLE_PRIVS'')
     AND event_timestamp > systimestamp - interval ''30'' minute
   GROUP BY db_username
   HAVING count(*) > 10',
  '{"condition":"row_count > 0","description":"Burst of privilege view accesses in audit trail  -- systematic privilege mapping confirmed"}'
);

-- ============================================================
-- SEC-SQL-AUD-011-RC01  Direct DML on audit / log tables
-- ============================================================
CALL rootcause.add_detection_path('SEC-SQL-AUD-011-RC01','postgresql',
  'Detect DML on audit log tables - PostgreSQL',
  'Identifies INSERT, UPDATE, or DELETE statements targeting known pgaudit or custom audit tables',
  'Scan active queries for DML targeting audit schema tables',
  'SELECT pid, usename, query, client_addr, query_start
   FROM pg_stat_activity
   WHERE state = ''active''
     AND query ~* ''^\s*(INSERT|UPDATE|DELETE)\s+''
     AND (query ILIKE ''%audit%'' OR query ILIKE ''%log%event%'' OR query ILIKE ''%operation_log%'')',
  '{"condition":"row_count > 0","description":"Active DML statement targeting audit or log table  -- potential audit tampering"}',
  'Check pg_stat_statements for recent DML on audit tables',
  'SELECT userid::regrole AS username, query, calls, last_exec_time
   FROM pg_stat_statements
   WHERE (query ~* ''^\s*(INSERT|UPDATE|DELETE)\s+'')
     AND (query ILIKE ''%audit%'' OR query ILIKE ''%operation_log%'')
   ORDER BY last_exec_time DESC
   LIMIT 10',
  '{"condition":"row_count > 0","description":"DML on audit table found in statement history  -- tampering activity confirmed"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-011-RC01','sqlserver',
  'Detect DML on audit log tables - SQL Server',
  'Finds INSERT, UPDATE, or DELETE statements against audit or event log tables in active sessions',
  'Check active requests for DML on audit tables',
  'SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE (t.text LIKE ''%INSERT%'' OR t.text LIKE ''%UPDATE%'' OR t.text LIKE ''%DELETE%'')
     AND (t.text LIKE ''%audit%'' OR t.text LIKE ''%event_log%'' OR t.text LIKE ''%trace_log%'')',
  '{"condition":"row_count > 0","description":"Active DML statement targeting audit or trace log table  -- tampering attempt"}',
  'Check Query Store for recent DML on audit tables',
  'SELECT qt.query_sql_text, rs.count_executions, rs.last_execution_time
   FROM sys.query_store_query_text qt
   JOIN sys.query_store_query q ON q.query_text_id = qt.query_text_id
   JOIN sys.query_store_plan qp ON qp.query_id = q.query_id
   JOIN sys.query_store_runtime_stats rs ON rs.plan_id = qp.plan_id
   WHERE (qt.query_sql_text LIKE ''%INSERT%'' OR qt.query_sql_text LIKE ''%DELETE%'')
     AND (qt.query_sql_text LIKE ''%audit%'' OR qt.query_sql_text LIKE ''%event_log%'')
   ORDER BY rs.last_execution_time DESC',
  '{"condition":"row_count > 0","description":"DML on audit table found in Query Store  -- tampering activity confirmed"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-011-RC01','mysql',
  'Detect DML on audit log tables - MySQL',
  'Identifies INSERT, UPDATE, or DELETE statements targeting mysql.general_log or audit log tables',
  'Check active queries for DML on log tables',
  'SELECT ID, USER, HOST, DB, TIME, INFO
   FROM INFORMATION_SCHEMA.PROCESSLIST
   WHERE COMMAND = ''Query''
     AND (INFO REGEXP ''^[[:space:]]*(INSERT|UPDATE|DELETE)[[:space:]]'')
     AND (INFO LIKE ''%general_log%'' OR INFO LIKE ''%audit_log%'' OR INFO LIKE ''%slow_log%'')',
  '{"condition":"row_count > 0","description":"Active DML targeting MySQL log tables  -- audit tampering attempt"}',
  'Check performance_schema history for log table DML',
  'SELECT DIGEST_TEXT, COUNT_STAR, LAST_SEEN
   FROM performance_schema.events_statements_summary_by_digest
   WHERE (DIGEST_TEXT REGEXP ''INSERT|UPDATE|DELETE'')
     AND (DIGEST_TEXT LIKE ''%general_log%'' OR DIGEST_TEXT LIKE ''%audit_log%'')
   ORDER BY LAST_SEEN DESC
   LIMIT 10',
  '{"condition":"row_count > 0","description":"Log table DML found in digest history  -- audit tampering confirmed"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-011-RC01','oracle',
  'Detect DML on audit log tables - Oracle',
  'Finds INSERT, UPDATE, or DELETE statements targeting AUD$, FGA_LOG$, or unified audit trail tables',
  'Scan V$SQL for DML on Oracle audit tables',
  'SELECT s.username, s.sid, q.sql_text, q.executions, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE REGEXP_LIKE(UPPER(q.sql_text), ''^\s*(INSERT|UPDATE|DELETE)\s'')
     AND (UPPER(q.sql_text) LIKE ''%AUD$%'' OR UPPER(q.sql_text) LIKE ''%FGA_LOG$%''
          OR UPPER(q.sql_text) LIKE ''%UNIFIED_AUDIT_TRAIL%'')
     AND q.last_active_time > SYSDATE - 1/24',
  '{"condition":"row_count > 0","description":"DML targeting Oracle audit tables AUD$ or FGA_LOG$ detected  -- tampering attempt"}',
  'Confirm in unified audit trail',
  'SELECT db_username, action_name, object_name, event_timestamp
   FROM unified_audit_trail
   WHERE action_name IN (''INSERT'',''UPDATE'',''DELETE'')
     AND object_name IN (''AUD$'',''FGA_LOG$'',''AUDSYS.AUD$UNIFIED'')
   ORDER BY event_timestamp DESC
   FETCH FIRST 20 ROWS ONLY',
  '{"condition":"row_count > 0","description":"DML on Oracle audit tables confirmed in unified audit trail"}'
);

-- ============================================================
-- SEC-SQL-AUD-011-RC02  Audit settings disabled mid-session
-- ============================================================
CALL rootcause.add_detection_path('SEC-SQL-AUD-011-RC02','postgresql',
  'Detect audit settings disabled mid-session - PostgreSQL',
  'Identifies SET log_statement or ALTER SYSTEM commands that reduce audit verbosity',
  'Scan active queries for log_statement reduction commands',
  'SELECT pid, usename, query, client_addr, query_start
   FROM pg_stat_activity
   WHERE state = ''active''
     AND (query ILIKE ''%SET log_statement%none%'' OR query ILIKE ''%SET log_statement%ddl%''
          OR query ILIKE ''%ALTER SYSTEM SET log_statement%''
          OR query ILIKE ''%SET log_min_duration_statement%'')',
  '{"condition":"row_count > 0","description":"Active command reducing log_statement verbosity  -- audit disabling pattern"}',
  'Check current pg_settings for reduced audit configuration',
  'SELECT name, setting, source
   FROM pg_settings
   WHERE name IN (''log_statement'',''log_min_duration_statement'',''log_connections'',''log_disconnections'')
     AND source NOT IN (''configuration file'',''default'')',
  '{"condition":"row_count > 0","description":"Audit parameters overridden at session or system level  -- audit verbosity reduced"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-011-RC02','sqlserver',
  'Detect audit specification disabled mid-session - SQL Server',
  'Finds ALTER AUDIT SPECIFICATION STATE=OFF or sp_configure audit level changes in active sessions',
  'Check active requests for audit disabling commands',
  'SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE ''%ALTER%AUDIT%STATE%OFF%''
      OR t.text LIKE ''%sp_configure%audit%''',
  '{"condition":"row_count > 0","description":"Active request disabling SQL Server audit specification  -- tampering pattern"}',
  'Check audit specification state for disabled entries',
  'SELECT name, is_state_enabled, modify_date
   FROM sys.server_audit_specifications
   WHERE is_state_enabled = 0
   UNION ALL
   SELECT name, is_state_enabled, modify_date
   FROM sys.database_audit_specifications
   WHERE is_state_enabled = 0',
  '{"condition":"row_count > 0","description":"One or more audit specifications are currently disabled  -- confirm tampering"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-011-RC02','mysql',
  'Detect audit logging disabled mid-session - MySQL',
  'Identifies SET GLOBAL commands turning off general_log or audit_log_policy',
  'Check active queries for audit log disabling commands',
  'SELECT ID, USER, HOST, DB, TIME, INFO
   FROM INFORMATION_SCHEMA.PROCESSLIST
   WHERE COMMAND = ''Query''
     AND (INFO REGEXP ''SET[[:space:]]+GLOBAL[[:space:]]+general_log[[:space:]]*=''
          OR INFO REGEXP ''SET[[:space:]]+GLOBAL[[:space:]]+audit_log_policy'')',
  '{"condition":"row_count > 0","description":"Active command modifying audit log global variables  -- audit disabling pattern"}',
  'Check current audit logging variable state',
  'SELECT VARIABLE_NAME, VARIABLE_VALUE
   FROM performance_schema.global_variables
   WHERE VARIABLE_NAME IN (''general_log'',''audit_log_policy'',''slow_query_log'',''log_output'')',
  '{"condition":"value_check","description":"Verify general_log=ON and audit_log_policy=ALL  -- check for unexpected OFF values"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-011-RC02','oracle',
  'Detect audit settings disabled mid-session - Oracle',
  'Identifies NOAUDIT commands or ALTER AUDIT POLICY DISABLE in active sessions',
  'Scan V$SQL for audit disabling commands',
  'SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE (UPPER(q.sql_text) LIKE ''%NOAUDIT%'' OR UPPER(q.sql_text) LIKE ''%DISABLE POLICY%''
          OR UPPER(q.sql_text) LIKE ''%ALTER SYSTEM SET AUDIT_TRAIL%'')
     AND q.last_active_time > SYSDATE - 1/24',
  '{"condition":"row_count > 0","description":"NOAUDIT or audit policy disable command found in V$SQL  -- audit tampering pattern"}',
  'Check for disabled unified audit policies',
  'SELECT policy_name, enabled_option, entity_name
   FROM audit_unified_enabled_policies
   WHERE enabled_option = ''NONE''
   UNION ALL
   SELECT policy_name, NULL, NULL
   FROM audit_unified_policies
   WHERE policy_name NOT IN (SELECT policy_name FROM audit_unified_enabled_policies)',
  '{"condition":"row_count > 0","description":"Unified audit policies found disabled or inactive  -- confirm tampering"}'
);

-- ============================================================
-- SEC-SQL-AUD-011-RC03  Audit table truncated or dropped
-- ============================================================
CALL rootcause.add_detection_path('SEC-SQL-AUD-011-RC03','postgresql',
  'Detect audit table truncation or drop - PostgreSQL',
  'Identifies TRUNCATE or DROP TABLE commands targeting audit schema objects',
  'Scan active queries for TRUNCATE or DROP on audit tables',
  'SELECT pid, usename, query, client_addr, query_start
   FROM pg_stat_activity
   WHERE state = ''active''
     AND query ~* ''\s*(TRUNCATE|DROP\s+TABLE)\s+''
     AND (query ILIKE ''%audit%'' OR query ILIKE ''%operation_log%'' OR query ILIKE ''%event_log%'')',
  '{"condition":"row_count > 0","description":"Active TRUNCATE or DROP targeting audit table  -- evidence destruction pattern"}',
  'Check pg_stat_statements for recent DDL on audit tables',
  'SELECT userid::regrole AS username, query, calls
   FROM pg_stat_statements
   WHERE (query ~* ''TRUNCATE'' OR query ~* ''DROP\s+TABLE'')
     AND (query ILIKE ''%audit%'' OR query ILIKE ''%log%'')
   ORDER BY calls DESC
   LIMIT 10',
  '{"condition":"row_count > 0","description":"TRUNCATE or DROP on audit tables in statement history  -- destruction attempt confirmed"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-011-RC03','sqlserver',
  'Detect audit table truncation or drop - SQL Server',
  'Finds TRUNCATE TABLE or DROP TABLE targeting audit or log tables in active sessions',
  'Check active requests for audit table destruction',
  'SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE (t.text LIKE ''%TRUNCATE%TABLE%'' OR t.text LIKE ''%DROP%TABLE%'')
     AND (t.text LIKE ''%audit%'' OR t.text LIKE ''%event_log%'' OR t.text LIKE ''%trace%'')',
  '{"condition":"row_count > 0","description":"Active TRUNCATE or DROP targeting audit table  -- evidence destruction attempt"}',
  'Verify audit table existence in system catalog',
  'SELECT OBJECT_NAME(object_id) AS table_name, create_date, modify_date
   FROM sys.tables
   WHERE OBJECT_NAME(object_id) LIKE ''%audit%'' OR OBJECT_NAME(object_id) LIKE ''%event_log%''
   ORDER BY create_date DESC',
  '{"condition":"row_count >= 0","description":"Audit tables present  -- cross-reference with expected baseline to detect drops"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-011-RC03','mysql',
  'Detect audit table truncation or drop - MySQL',
  'Identifies TRUNCATE or DROP TABLE commands targeting audit log tables',
  'Check active queries for audit table truncation or drop',
  'SELECT ID, USER, HOST, DB, TIME, INFO
   FROM INFORMATION_SCHEMA.PROCESSLIST
   WHERE COMMAND = ''Query''
     AND (INFO REGEXP ''TRUNCATE[[:space:]]'' OR INFO REGEXP ''DROP[[:space:]]+TABLE[[:space:]]'')
     AND (INFO LIKE ''%general_log%'' OR INFO LIKE ''%audit_log%'' OR INFO LIKE ''%slow_log%'')',
  '{"condition":"row_count > 0","description":"Active TRUNCATE or DROP targeting MySQL log tables  -- audit destruction pattern"}',
  'Check information_schema for audit table existence',
  'SELECT TABLE_SCHEMA, TABLE_NAME, TABLE_ROWS, CREATE_TIME
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_NAME IN (''general_log'',''slow_log'')
     AND TABLE_SCHEMA = ''mysql''',
  '{"condition":"row_count >= 0","description":"Audit tables present  -- verify TABLE_ROWS not zero indicating unexpected truncation"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-011-RC03','oracle',
  'Detect audit table truncation or drop - Oracle',
  'Finds TRUNCATE or DROP commands targeting AUD$, FGA_LOG$, or audit schema tables',
  'Scan V$SQL for destructive DDL on audit tables',
  'SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE (UPPER(q.sql_text) LIKE ''%TRUNCATE%TABLE%AUD%'' OR UPPER(q.sql_text) LIKE ''%DROP%TABLE%AUD%''
          OR UPPER(q.sql_text) LIKE ''%TRUNCATE%FGA_LOG%'')
     AND q.last_active_time > SYSDATE - 1/24',
  '{"condition":"row_count > 0","description":"TRUNCATE or DROP targeting AUD$ or FGA_LOG$ in V$SQL  -- audit destruction attempt"}',
  'Check AUD$ row count for unexpected emptiness',
  'SELECT count(*) AS aud_row_count, max(ntimestamp#) AS latest_entry
   FROM sys.aud$',
  '{"condition":"value_check","description":"Verify AUD$ row count is not unexpectedly zero  -- zero rows may indicate recent truncation"}'
);

-- ============================================================
-- SEC-SQL-AUD-011-RC04  Trigger disabled before DML
-- ============================================================
CALL rootcause.add_detection_path('SEC-SQL-AUD-011-RC04','postgresql',
  'Detect trigger disable followed by DML - PostgreSQL',
  'Identifies ALTER TABLE DISABLE TRIGGER commands followed by DML on the same table within the same session',
  'Scan active queries for DISABLE TRIGGER commands',
  'SELECT pid, usename, query, client_addr, query_start
   FROM pg_stat_activity
   WHERE state = ''active''
     AND query ~* ''ALTER\s+TABLE\s+.+DISABLE\s+TRIGGER''',
  '{"condition":"row_count > 0","description":"Active ALTER TABLE DISABLE TRIGGER command  -- potential audit bypass before DML"}',
  'Check pg_stat_statements for DISABLE TRIGGER and subsequent DML',
  'SELECT userid::regrole AS username, query, calls
   FROM pg_stat_statements
   WHERE query ~* ''ALTER\s+TABLE\s+.+DISABLE\s+TRIGGER''
   ORDER BY calls DESC
   LIMIT 10',
  '{"condition":"row_count > 0","description":"DISABLE TRIGGER in statement history  -- correlate with DML on same table to confirm bypass"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-011-RC04','sqlserver',
  'Detect trigger disable followed by DML - SQL Server',
  'Finds DISABLE TRIGGER commands in active sessions',
  'Check active requests for DISABLE TRIGGER',
  'SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE ''%DISABLE%TRIGGER%''',
  '{"condition":"row_count > 0","description":"Active DISABLE TRIGGER command  -- potential audit bypass before DML operation"}',
  'Check for currently disabled triggers on monitored tables',
  'SELECT t.name AS trigger_name, OBJECT_NAME(t.parent_id) AS table_name, t.is_disabled, t.modify_date
   FROM sys.triggers t
   WHERE t.is_disabled = 1
   ORDER BY t.modify_date DESC',
  '{"condition":"row_count > 0","description":"Disabled triggers found on tables  -- verify disable was authorized and correlate with recent DML"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-011-RC04','mysql',
  'Detect trigger drop before DML - MySQL',
  'Identifies DROP TRIGGER commands in active sessions (MySQL has no DISABLE TRIGGER)',
  'Check active queries for DROP TRIGGER',
  'SELECT ID, USER, HOST, DB, TIME, INFO
   FROM INFORMATION_SCHEMA.PROCESSLIST
   WHERE COMMAND = ''Query''
     AND INFO REGEXP ''DROP[[:space:]]+TRIGGER[[:space:]]''',
  '{"condition":"row_count > 0","description":"Active DROP TRIGGER command  -- potential audit bypass before DML operation"}',
  'Verify trigger existence on monitored tables',
  'SELECT TRIGGER_SCHEMA, TRIGGER_NAME, EVENT_OBJECT_TABLE, ACTION_TIMING, EVENT_MANIPULATION
   FROM INFORMATION_SCHEMA.TRIGGERS
   WHERE EVENT_OBJECT_SCHEMA NOT IN (''information_schema'',''performance_schema'',''mysql'',''sys'')
   ORDER BY EVENT_OBJECT_TABLE',
  '{"condition":"row_count >= 0","description":"Audit trigger inventory  -- verify expected triggers are present on all monitored tables"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-011-RC04','oracle',
  'Detect trigger disable before DML - Oracle',
  'Finds ALTER TRIGGER DISABLE or ALTER TABLE DISABLE ALL TRIGGERS in active sessions',
  'Scan V$SQL for trigger disable commands',
  'SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE (UPPER(q.sql_text) LIKE ''%ALTER%TRIGGER%DISABLE%'' OR UPPER(q.sql_text) LIKE ''%DISABLE ALL TRIGGERS%'')
     AND q.last_active_time > SYSDATE - 1/24',
  '{"condition":"row_count > 0","description":"ALTER TRIGGER DISABLE command in V$SQL  -- potential audit bypass in last hour"}',
  'Check for currently disabled triggers on application tables',
  'SELECT owner, trigger_name, table_name, status, last_change
   FROM dba_triggers
   WHERE status = ''DISABLED''
     AND owner NOT IN (''SYS'',''SYSTEM'')
   ORDER BY last_change DESC',
  '{"condition":"row_count > 0","description":"Disabled triggers on non-system tables found  -- verify authorization and correlate with DML"}'
);

-- ============================================================
-- SEC-SQL-AUD-011-RC05  Error log / event buffer cleared
-- ============================================================
CALL rootcause.add_detection_path('SEC-SQL-AUD-011-RC05','postgresql',
  'Detect log rotation commands used to clear evidence - PostgreSQL',
  'Identifies pg_rotate_logfile() or pg_reload_conf() calls outside maintenance windows',
  'Scan active queries for log rotation functions',
  'SELECT pid, usename, query, client_addr, query_start
   FROM pg_stat_activity
   WHERE state = ''active''
     AND (query ILIKE ''%pg_rotate_logfile%'' OR query ILIKE ''%pg_reload_conf%'')',
  '{"condition":"row_count > 0","description":"Active log rotation or reload command  -- potential evidence clearing during incident"}',
  'Check pg_stat_statements for log rotation call history',
  'SELECT userid::regrole AS username, query, calls
   FROM pg_stat_statements
   WHERE (query ILIKE ''%pg_rotate_logfile%'' OR query ILIKE ''%pg_reload_conf%'')
   ORDER BY calls DESC
   LIMIT 10',
  '{"condition":"row_count > 0","description":"Log rotation calls found in statement history  -- correlate with incident timeline"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-011-RC05','sqlserver',
  'Detect error log cycle used to clear evidence - SQL Server',
  'Finds sp_cycle_errorlog execution in active sessions or recent history',
  'Check active requests for sp_cycle_errorlog',
  'SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE ''%sp_cycle_errorlog%''',
  '{"condition":"row_count > 0","description":"Active sp_cycle_errorlog call  -- potential error log evidence clearing"}',
  'Confirm in Query Store history',
  'SELECT qt.query_sql_text, rs.count_executions, rs.last_execution_time
   FROM sys.query_store_query_text qt
   JOIN sys.query_store_query q ON q.query_text_id = qt.query_text_id
   JOIN sys.query_store_plan qp ON qp.query_id = q.query_id
   JOIN sys.query_store_runtime_stats rs ON rs.plan_id = qp.plan_id
   WHERE qt.query_sql_text LIKE ''%sp_cycle_errorlog%''
   ORDER BY rs.last_execution_time DESC',
  '{"condition":"row_count > 0","description":"sp_cycle_errorlog executions in Query Store  -- correlate with incident timeline"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-011-RC05','mysql',
  'Detect FLUSH LOGS used to clear evidence - MySQL',
  'Identifies FLUSH LOGS or FLUSH BINARY LOGS commands in active queries',
  'Check active queries for FLUSH LOGS',
  'SELECT ID, USER, HOST, DB, TIME, INFO
   FROM INFORMATION_SCHEMA.PROCESSLIST
   WHERE COMMAND = ''Query''
     AND INFO REGEXP ''FLUSH[[:space:]]+(BINARY[[:space:]]+)?LOGS''',
  '{"condition":"row_count > 0","description":"Active FLUSH LOGS command  -- potential evidence clearing during incident"}',
  'Check performance_schema for FLUSH LOGS digest history',
  'SELECT DIGEST_TEXT, COUNT_STAR, LAST_SEEN
   FROM performance_schema.events_statements_summary_by_digest
   WHERE DIGEST_TEXT REGEXP ''FLUSH.+LOGS''
   ORDER BY LAST_SEEN DESC
   LIMIT 10',
  '{"condition":"row_count > 0","description":"FLUSH LOGS in statement digest history  -- correlate with incident timeline"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-011-RC05','oracle',
  'Detect redo log switch used to clear evidence - Oracle',
  'Finds ALTER SYSTEM SWITCH LOGFILE or DBMS_SYSTEM log management calls in V$SQL',
  'Scan V$SQL for log switch commands',
  'SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE (UPPER(q.sql_text) LIKE ''%ALTER SYSTEM SWITCH LOGFILE%''
          OR UPPER(q.sql_text) LIKE ''%DBMS_SYSTEM.KSDWRT%'')
     AND q.last_active_time > SYSDATE - 1/24',
  '{"condition":"row_count > 0","description":"ALTER SYSTEM SWITCH LOGFILE detected in V$SQL  -- potential log evidence clearing"}',
  'Check V$LOG_HISTORY for recent unexpected log switches',
  'SELECT sequence#, first_time, next_time, blocks, block_size
   FROM v$log_history
   WHERE first_time > SYSDATE - 1/24
   ORDER BY first_time DESC',
  '{"condition":"row_count > 3","description":"More than 3 log switches in last hour  -- unusually high frequency may indicate deliberate log cycling"}'
);

-- ============================================================
-- SEC-SQL-AUD-012-RC01  Transaction open beyond threshold
-- ============================================================
CALL rootcause.add_detection_path('SEC-SQL-AUD-012-RC01','postgresql',
  'Detect long-open uncommitted transactions - PostgreSQL',
  'Finds sessions with active transactions open beyond 30 minutes with no recent query activity',
  'Find idle-in-transaction sessions older than 30 minutes',
  'SELECT pid, usename, state, xact_start, now() - xact_start AS txn_age,
          query, client_addr
   FROM pg_stat_activity
   WHERE state IN (''idle in transaction'',''idle in transaction (aborted)'')
     AND now() - xact_start > interval ''30 minutes''
   ORDER BY xact_start',
  '{"condition":"row_count > 0","description":"Session has had an open uncommitted transaction for over 30 minutes  -- abandoned transaction pattern"}',
  'Check for blocked sessions caused by the long transaction',
  'SELECT count(*) AS blocked_sessions
   FROM pg_stat_activity
   WHERE wait_event_type = ''Lock''',
  '{"condition":"row_count > 0","description":"Blocked sessions exist  -- long-open transaction is actively causing contention"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-012-RC01','sqlserver',
  'Detect long-open uncommitted transactions - SQL Server',
  'Identifies sessions with open transactions idle for more than 30 minutes',
  'Find sessions with open transactions idle over 30 minutes',
  'SELECT s.session_id, s.login_name, s.open_transaction_count,
          s.last_request_start_time,
          DATEDIFF(minute, s.last_request_start_time, GETDATE()) AS idle_minutes,
          s.host_name, s.program_name
   FROM sys.dm_exec_sessions s
   WHERE s.open_transaction_count > 0
     AND DATEDIFF(minute, s.last_request_start_time, GETDATE()) > 30
   ORDER BY idle_minutes DESC',
  '{"condition":"row_count > 0","description":"Session has open uncommitted transaction idle for over 30 minutes  -- abandoned transaction"}',
  'Count sessions blocked by the long transaction',
  'SELECT count(*) AS blocked_sessions
   FROM sys.dm_exec_requests
   WHERE blocking_session_id <> 0',
  '{"condition":"row_count > 0","description":"Blocked sessions exist downstream of long-open transaction  -- active contention confirmed"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-012-RC01','mysql',
  'Detect long-open uncommitted transactions - MySQL',
  'Finds InnoDB transactions open for more than 30 minutes',
  'Find InnoDB transactions open over 30 minutes',
  'SELECT trx_id, trx_started, trx_state, trx_mysql_thread_id,
          trx_query, TIMESTAMPDIFF(MINUTE, trx_started, NOW()) AS open_minutes
   FROM information_schema.innodb_trx
   WHERE trx_state IN (''RUNNING'',''LOCK WAIT'')
     AND TIMESTAMPDIFF(MINUTE, trx_started, NOW()) > 30
   ORDER BY trx_started',
  '{"condition":"row_count > 0","description":"InnoDB transaction open for over 30 minutes without commit  -- abandoned transaction pattern"}',
  'Count threads waiting on locks held by the long transaction',
  'SELECT count(*) AS waiting_threads
   FROM information_schema.innodb_lock_waits',
  '{"condition":"row_count > 0","description":"Lock waiters exist  -- long transaction is actively blocking downstream operations"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-012-RC01','oracle',
  'Detect long-open uncommitted transactions - Oracle',
  'Finds Oracle transactions open for more than 30 minutes',
  'Find transactions open over 30 minutes',
  'SELECT s.sid, s.serial#, s.username, s.status,
          t.start_date, ROUND((SYSDATE - t.start_date) * 24 * 60) AS open_minutes,
          s.last_call_et, s.machine
   FROM v$transaction t
   JOIN v$session s ON t.ses_addr = s.saddr
   WHERE ROUND((SYSDATE - t.start_date) * 24 * 60) > 30
   ORDER BY t.start_date',
  '{"condition":"row_count > 0","description":"Oracle session has had open uncommitted transaction for over 30 minutes  -- abandoned transaction"}',
  'Check for blocked sessions caused by the long transaction',
  'SELECT count(*) AS blocked_sessions
   FROM v$session
   WHERE blocking_session IS NOT NULL',
  '{"condition":"row_count > 0","description":"Blocked Oracle sessions exist  -- long-open transaction is causing active lock contention"}'
);

-- ============================================================
-- SEC-SQL-AUD-012-RC02  Exclusive locks held on large tables
-- ============================================================
CALL rootcause.add_detection_path('SEC-SQL-AUD-012-RC02','postgresql',
  'Detect extended exclusive lock on large table - PostgreSQL',
  'Identifies sessions holding ExclusiveLock or AccessExclusiveLock on large tables for over 10 minutes',
  'Find sessions holding exclusive locks on large tables',
  'SELECT l.pid, a.usename, c.relname, c.reltuples::bigint AS est_rows,
          l.mode, now() - a.query_start AS lock_age
   FROM pg_locks l
   JOIN pg_class c ON c.oid = l.relation
   JOIN pg_stat_activity a ON a.pid = l.pid
   WHERE l.granted
     AND l.mode IN (''ExclusiveLock'',''AccessExclusiveLock'',''RowExclusiveLock'')
     AND c.reltuples > 100000
     AND now() - a.query_start > interval ''10 minutes''
   ORDER BY c.reltuples DESC',
  '{"condition":"row_count > 0","description":"Session holds exclusive lock on large table for over 10 minutes  -- potential lock abuse"}',
  'Count sessions blocked by the lock holder',
  'SELECT count(*) AS blocked_count
   FROM pg_stat_activity
   WHERE wait_event_type = ''Lock''',
  '{"condition":"row_count > 0","description":"Blocked sessions downstream of lock holder  -- exclusive lock causing active contention"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-012-RC02','sqlserver',
  'Detect extended exclusive lock on large table - SQL Server',
  'Finds sessions holding exclusive or schema-modification locks on large tables for extended periods',
  'Find extended exclusive locks on large tables',
  'SELECT tl.request_session_id AS spid, s.login_name,
          OBJECT_NAME(tl.resource_associated_entity_id) AS table_name,
          p.rows AS est_rows, tl.request_mode, tl.request_status,
          DATEDIFF(minute, s.last_request_start_time, GETDATE()) AS lock_minutes
   FROM sys.dm_tran_locks tl
   JOIN sys.dm_exec_sessions s ON s.session_id = tl.request_session_id
   JOIN sys.partitions p ON p.object_id = tl.resource_associated_entity_id
   WHERE tl.resource_type = ''OBJECT''
     AND tl.request_mode IN (''X'',''SCH-M'')
     AND p.rows > 100000
     AND DATEDIFF(minute, s.last_request_start_time, GETDATE()) > 10',
  '{"condition":"row_count > 0","description":"Exclusive lock held on large table for over 10 minutes  -- lock abuse pattern"}',
  'Count waiting sessions blocked by the lock',
  'SELECT count(*) AS blocked_sessions
   FROM sys.dm_exec_requests
   WHERE blocking_session_id <> 0',
  '{"condition":"row_count > 0","description":"Active blocked sessions confirm lock is causing downstream contention"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-012-RC02','mysql',
  'Detect extended exclusive lock on large table - MySQL',
  'Identifies InnoDB exclusive locks held for over 10 minutes on large tables',
  'Find extended InnoDB exclusive locks',
  'SELECT r.trx_id waiting_trx, b.trx_id blocking_trx,
          b.trx_mysql_thread_id blocking_thread,
          b.trx_started, TIMESTAMPDIFF(MINUTE, b.trx_started, NOW()) AS lock_minutes,
          lw.blocking_lock_id
   FROM information_schema.innodb_lock_waits lw
   JOIN information_schema.innodb_trx b ON b.trx_id = lw.blocking_trx_id
   JOIN information_schema.innodb_trx r ON r.trx_id = lw.requesting_trx_id
   WHERE TIMESTAMPDIFF(MINUTE, b.trx_started, NOW()) > 10',
  '{"condition":"row_count > 0","description":"InnoDB exclusive lock held for over 10 minutes  -- extended lock abuse pattern"}',
  'Confirm with count of all InnoDB lock waiters',
  'SELECT count(*) AS total_lock_waiters
   FROM information_schema.innodb_lock_waits',
  '{"condition":"row_count > 0","description":"Multiple lock waiters confirm extended exclusive lock is causing broad contention"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-012-RC02','oracle',
  'Detect extended exclusive lock on large table - Oracle',
  'Finds sessions holding TM exclusive locks (mode 6) on tables with many rows for over 10 minutes',
  'Find extended exclusive TM locks on large tables',
  'SELECT s.sid, s.serial#, s.username, t.name AS table_name,
          stat.num_rows AS est_rows, l.lmode, s.last_call_et AS lock_seconds
   FROM v$lock l
   JOIN v$session s ON l.sid = s.sid
   JOIN v$object_dependency od ON od.to_owner||''.''||od.to_name = l.id1||''.''||l.id2
   JOIN all_tables t ON t.owner||''.''||t.table_name = od.to_owner||''.''||od.to_name
   JOIN all_tab_statistics stat ON stat.owner = t.owner AND stat.table_name = t.table_name
   WHERE l.type = ''TM'' AND l.lmode = 6
     AND stat.num_rows > 100000
     AND s.last_call_et > 600',
  '{"condition":"row_count > 0","description":"Exclusive TM lock on large table held for over 10 minutes  -- potential lock-based DoS"}',
  'Count blocked sessions in Oracle lock wait chain',
  'SELECT count(*) AS blocked_sessions
   FROM v$session
   WHERE blocking_session IS NOT NULL',
  '{"condition":"row_count > 0","description":"Blocked Oracle sessions confirm exclusive lock is causing active downstream contention"}'
);

-- ============================================================
-- SEC-SQL-AUD-012-RC03  Idle-in-transaction blocking downstream
-- ============================================================
CALL rootcause.add_detection_path('SEC-SQL-AUD-012-RC03','postgresql',
  'Detect idle-in-transaction session blocking downstream - PostgreSQL',
  'Finds sessions in idle-in-transaction state that are the root cause of a blocked session queue',
  'Find idle-in-transaction sessions with downstream waiters',
  'SELECT a.pid, a.usename, a.state, a.xact_start,
          now() - a.xact_start AS idle_age,
          count(w.pid) AS waiting_sessions
   FROM pg_stat_activity a
   LEFT JOIN pg_stat_activity w ON w.wait_event_type = ''Lock''
   WHERE a.state = ''idle in transaction''
     AND now() - a.xact_start > interval ''5 minutes''
   GROUP BY a.pid, a.usename, a.state, a.xact_start
   HAVING count(w.pid) > 0',
  '{"condition":"row_count > 0","description":"Idle-in-transaction session has been blocking downstream sessions for over 5 minutes"}',
  'Get total blocked session count and oldest wait',
  'SELECT count(*) AS blocked_count,
          max(now() - query_start) AS longest_wait
   FROM pg_stat_activity
   WHERE wait_event_type = ''Lock''',
  '{"condition":"row_count > 0","description":"Blocked session queue size confirmed  -- idle transaction is causing active contention"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-012-RC03','sqlserver',
  'Detect idle-in-transaction session blocking downstream - SQL Server',
  'Identifies idle sessions with open transactions that are the head of a blocking chain',
  'Find idle sessions causing blocking chains',
  'SELECT s.session_id, s.login_name, s.status, s.open_transaction_count,
          DATEDIFF(second, s.last_request_end_time, GETDATE()) AS idle_seconds,
          count(r.session_id) AS blocked_sessions
   FROM sys.dm_exec_sessions s
   LEFT JOIN sys.dm_exec_requests r ON r.blocking_session_id = s.session_id
   WHERE s.open_transaction_count > 0
     AND s.status = ''sleeping''
     AND DATEDIFF(second, s.last_request_end_time, GETDATE()) > 300
   GROUP BY s.session_id, s.login_name, s.status, s.open_transaction_count, s.last_request_end_time
   HAVING count(r.session_id) > 0',
  '{"condition":"row_count > 0","description":"Idle sleeping session with open transaction is the head of a blocking chain"}',
  'Get full downstream blocking chain depth',
  'SELECT count(*) AS total_blocked
   FROM sys.dm_exec_requests
   WHERE blocking_session_id <> 0',
  '{"condition":"row_count > 0","description":"Active blocked request queue confirmed  -- idle transaction causing systemic contention"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-012-RC03','mysql',
  'Detect idle-in-transaction session blocking downstream - MySQL',
  'Identifies sleeping threads with long-open InnoDB transactions that have active lock waiters',
  'Find sleeping threads with open transactions and lock waiters',
  'SELECT trx.trx_mysql_thread_id, pl.USER, pl.HOST, pl.COMMAND,
          trx.trx_started,
          TIMESTAMPDIFF(MINUTE, trx.trx_started, NOW()) AS open_minutes,
          count(lw.requesting_trx_id) AS waiting_txns
   FROM information_schema.innodb_trx trx
   JOIN information_schema.processlist pl ON pl.ID = trx.trx_mysql_thread_id
   LEFT JOIN information_schema.innodb_lock_waits lw ON lw.blocking_trx_id = trx.trx_id
   WHERE pl.COMMAND = ''Sleep''
     AND TIMESTAMPDIFF(MINUTE, trx.trx_started, NOW()) > 5
   GROUP BY trx.trx_mysql_thread_id, pl.USER, pl.HOST, pl.COMMAND, trx.trx_started
   HAVING count(lw.requesting_trx_id) > 0',
  '{"condition":"row_count > 0","description":"Sleeping thread with open transaction has active lock waiters  -- idle-in-transaction blocking pattern"}',
  'Get total InnoDB lock waiter count',
  'SELECT count(*) AS total_lock_waiters
   FROM information_schema.innodb_lock_waits',
  '{"condition":"row_count > 0","description":"Total lock waiters confirmed  -- idle transaction is causing downstream lock contention"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-012-RC03','oracle',
  'Detect idle-in-transaction session blocking downstream - Oracle',
  'Finds inactive Oracle sessions holding locks that have a downstream blocking chain',
  'Find inactive sessions with locks and downstream waiters',
  'SELECT s.sid, s.serial#, s.username, s.status, s.last_call_et,
          count(w.sid) AS blocked_sessions
   FROM v$session s
   JOIN v$lock l ON l.sid = s.sid
   LEFT JOIN v$session w ON w.blocking_session = s.sid
   WHERE s.status = ''INACTIVE''
     AND l.block = 1
     AND s.last_call_et > 300
   GROUP BY s.sid, s.serial#, s.username, s.status, s.last_call_et
   HAVING count(w.sid) > 0',
  '{"condition":"row_count > 0","description":"Inactive Oracle session holding locks with downstream waiters  -- idle-in-transaction blocking pattern"}',
  'Get total downstream blocked session count',
  'SELECT count(*) AS blocked_sessions
   FROM v$session
   WHERE blocking_session IS NOT NULL',
  '{"condition":"row_count > 0","description":"Active blocked session queue confirmed  -- inactive session causing systemic lock contention"}'
);

-- ============================================================
-- SEC-SQL-AUD-012-RC04  Large-volume rollback probe-and-revert
-- ============================================================
CALL rootcause.add_detection_path('SEC-SQL-AUD-012-RC04','postgresql',
  'Detect probe-and-revert rollback pattern - PostgreSQL',
  'Identifies sessions with high rollback rates and large transaction sizes consistent with data-state probing',
  'Check pg_stat_user_tables for high dead tuple counts indicating repeated rollbacks',
  'SELECT schemaname, relname, n_dead_tup, n_mod_since_analyze,
          last_analyze, last_autoanalyze
   FROM pg_stat_user_tables
   WHERE n_dead_tup > 10000
     AND (last_analyze IS NULL OR last_analyze < now() - interval ''10 minutes'')
   ORDER BY n_dead_tup DESC
   LIMIT 10',
  '{"condition":"row_count > 0","description":"High dead tuple count on tables suggests repeated large DML rollbacks  -- probe-and-revert pattern"}',
  'Check pg_stat_activity for sessions with aborted transaction state',
  'SELECT pid, usename, state, xact_start, query
   FROM pg_stat_activity
   WHERE state = ''idle in transaction (aborted)''
   ORDER BY xact_start',
  '{"condition":"row_count > 0","description":"Sessions in aborted transaction state confirm repeated rollback activity"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-012-RC04','sqlserver',
  'Detect probe-and-revert rollback pattern - SQL Server',
  'Finds sessions with high transaction log space usage followed by rollback indicating probe behaviour',
  'Check for sessions with high log generation and pending rollback',
  'SELECT session_id, database_id, database_transaction_begin_time,
          database_transaction_log_bytes_used,
          database_transaction_log_bytes_reserved,
          database_transaction_type
   FROM sys.dm_tran_database_transactions
   WHERE database_transaction_log_bytes_used > 10485760
   ORDER BY database_transaction_log_bytes_used DESC',
  '{"condition":"row_count > 0","description":"Sessions with over 10 MB of transaction log usage  -- large DML potentially staged for rollback"}',
  'Check rollback-in-progress indicators in active sessions',
  'SELECT session_id, command, percent_complete, estimated_completion_time
   FROM sys.dm_exec_requests
   WHERE command = ''ROLLBACK''',
  '{"condition":"row_count > 0","description":"Active ROLLBACK operations confirm probe-and-revert behaviour in progress"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-012-RC04','mysql',
  'Detect probe-and-revert rollback pattern - MySQL',
  'Identifies InnoDB transactions with high undo log usage indicating large uncommitted DML',
  'Find InnoDB transactions with large undo log allocation',
  'SELECT trx_id, trx_started, trx_state, trx_mysql_thread_id,
          trx_rows_modified, trx_rows_locked,
          TIMESTAMPDIFF(MINUTE, trx_started, NOW()) AS open_minutes
   FROM information_schema.innodb_trx
   WHERE trx_rows_modified > 10000
   ORDER BY trx_rows_modified DESC',
  '{"condition":"row_count > 0","description":"InnoDB transaction with over 10000 modified rows still uncommitted  -- large staged DML probe pattern"}',
  'Check performance_schema transaction rollback counts',
  'SELECT user, host, count_rollback, count_commit,
          ROUND(count_rollback / (count_commit + count_rollback + 0.001) * 100, 1) AS rollback_pct
   FROM performance_schema.events_transactions_summary_by_user_by_event_name
   WHERE count_rollback > 0
   ORDER BY rollback_pct DESC
   LIMIT 10',
  '{"condition":"row_count > 0","description":"High rollback percentage for account confirms repeated DML-rollback probe cycle"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-012-RC04','oracle',
  'Detect probe-and-revert rollback pattern - Oracle',
  'Finds Oracle sessions with high undo block usage indicating large uncommitted DML staged for rollback',
  'Find sessions with high undo block consumption',
  'SELECT s.sid, s.serial#, s.username, t.used_ublk, t.used_urec,
          t.start_date, ROUND((SYSDATE - t.start_date) * 24 * 60) AS txn_minutes
   FROM v$transaction t
   JOIN v$session s ON t.ses_addr = s.saddr
   WHERE t.used_ublk > 1000
   ORDER BY t.used_ublk DESC',
  '{"condition":"row_count > 0","description":"Session consuming over 1000 undo blocks  -- large staged DML consistent with probe-and-revert pattern"}',
  'Check unified audit trail for repeated DML-ROLLBACK sequences',
  'SELECT db_username, action_name, count(*) AS occurrences
   FROM unified_audit_trail
   WHERE action_name IN (''INSERT'',''UPDATE'',''DELETE'',''ROLLBACK'')
     AND event_timestamp > systimestamp - interval ''30'' minute
   GROUP BY db_username, action_name
   ORDER BY db_username, action_name',
  '{"condition":"row_count > 0","description":"DML and ROLLBACK counts in audit trail  -- compare to identify disproportionate rollback ratio"}'
);

-- ============================================================
-- SEC-SQL-AUD-012-RC05  Savepoint abuse with repeated partial rollbacks
-- ============================================================
CALL rootcause.add_detection_path('SEC-SQL-AUD-012-RC05','postgresql',
  'Detect savepoint abuse - PostgreSQL',
  'Identifies sessions issuing abnormally high numbers of SAVEPOINT and ROLLBACK TO SAVEPOINT commands',
  'Scan active queries for SAVEPOINT or ROLLBACK TO patterns',
  'SELECT pid, usename, query, query_start, state
   FROM pg_stat_activity
   WHERE state = ''active''
     AND (query ~* ''\bSAVEPOINT\b'' OR query ~* ''\bROLLBACK\s+TO\b'')',
  '{"condition":"row_count > 0","description":"Active SAVEPOINT or ROLLBACK TO SAVEPOINT command  -- check frequency for abuse pattern"}',
  'Check pg_stat_statements for high savepoint usage frequency',
  'SELECT userid::regrole AS username, query, calls
   FROM pg_stat_statements
   WHERE query ~* ''\bSAVEPOINT\b'' OR query ~* ''\bROLLBACK\s+TO\b''
   ORDER BY calls DESC
   LIMIT 10',
  '{"condition":"row_count > 0","description":"High savepoint command frequency in statement history  -- correlate with timing for abuse pattern"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-012-RC05','sqlserver',
  'Detect savepoint abuse - SQL Server',
  'Finds active requests containing SAVE TRANSACTION or ROLLBACK TO SAVEPOINT patterns',
  'Check active requests for SAVE TRANSACTION usage',
  'SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE ''%SAVE%TRANSACTION%'' OR t.text LIKE ''%ROLLBACK%TRAN%'' AND t.text LIKE ''%SAVE%''',
  '{"condition":"row_count > 0","description":"Active SAVE TRANSACTION usage detected  -- monitor frequency for savepoint abuse pattern"}',
  'Check Query Store for savepoint command frequency',
  'SELECT qt.query_sql_text, rs.count_executions, rs.last_execution_time
   FROM sys.query_store_query_text qt
   JOIN sys.query_store_query q ON q.query_text_id = qt.query_text_id
   JOIN sys.query_store_plan qp ON qp.query_id = q.query_id
   JOIN sys.query_store_runtime_stats rs ON rs.plan_id = qp.plan_id
   WHERE qt.query_sql_text LIKE ''%SAVE%TRANSACTION%''
   ORDER BY rs.count_executions DESC',
  '{"condition":"row_count > 0","description":"Savepoint commands in Query Store  -- high frequency indicates abnormal usage pattern"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-012-RC05','mysql',
  'Detect savepoint abuse - MySQL',
  'Identifies accounts with abnormally high savepoint and rollback-to-savepoint counts in performance_schema',
  'Check performance_schema transaction stats for savepoint abuse',
  'SELECT user, host, count_savepoint, count_rollback_to_savepoint,
          count_release_savepoint, count_rollback
   FROM performance_schema.events_transactions_summary_by_user_by_event_name
   WHERE count_savepoint > 50
     OR count_rollback_to_savepoint > 20
   ORDER BY count_savepoint DESC',
  '{"condition":"row_count > 0","description":"Account shows high savepoint and rollback-to-savepoint counts  -- abnormal savepoint abuse pattern"}',
  'Check active processes for SAVEPOINT or ROLLBACK TO SAVEPOINT',
  'SELECT ID, USER, HOST, DB, TIME, INFO
   FROM INFORMATION_SCHEMA.PROCESSLIST
   WHERE COMMAND = ''Query''
     AND (INFO REGEXP ''[[:space:]]*SAVEPOINT[[:space:]]'' OR INFO REGEXP ''ROLLBACK[[:space:]]+TO[[:space:]]+SAVEPOINT'')',
  '{"condition":"row_count > 0","description":"Active savepoint commands confirm in-progress savepoint abuse"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-012-RC05','oracle',
  'Detect savepoint abuse - Oracle',
  'Finds sessions with high SAVEPOINT and ROLLBACK TO SAVEPOINT frequency in unified audit trail',
  'Check unified audit trail for savepoint command burst',
  'SELECT db_username, action_name, count(*) AS event_count, max(event_timestamp) AS last_seen
   FROM unified_audit_trail
   WHERE action_name IN (''SAVEPOINT'',''ROLLBACK TO SAVEPOINT'')
     AND event_timestamp > systimestamp - interval ''10'' minute
   GROUP BY db_username, action_name
   HAVING count(*) > 20
   ORDER BY db_username',
  '{"condition":"row_count > 0","description":"More than 20 SAVEPOINT or ROLLBACK TO SAVEPOINT events in 10 minutes  -- savepoint abuse pattern"}',
  'Check V$SQL for savepoint-heavy query patterns',
  'SELECT parsing_user_id, sql_text, executions, last_active_time
   FROM v$sql
   WHERE UPPER(sql_text) LIKE ''%SAVEPOINT%''
     AND last_active_time > SYSDATE - 1/24
   ORDER BY executions DESC
   FETCH FIRST 10 ROWS ONLY',
  '{"condition":"row_count > 0","description":"High-execution savepoint statements in V$SQL  -- confirms abnormal savepoint cycling behaviour"}'
);

DROP PROCEDURE IF EXISTS rootcause.add_detection_path(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT);

COMMIT;
