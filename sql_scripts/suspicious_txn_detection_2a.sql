-- Detection paths: SEC-SQL-AUD-009 (SQL Injection Runtime Indicators)
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

-- RC01 Tautology patterns
CALL rootcause.add_detection_path('SEC-SQL-AUD-009-RC01','postgresql',
  'Detect tautology injection patterns – PostgreSQL',
  'Scans pg_stat_activity for OR 1=1 and equivalent always-true conditions',
  'Scan active queries for tautology patterns',
  'SELECT pid, usename, query, client_addr, query_start
   FROM pg_stat_activity
   WHERE state = ''active''
     AND (query ~* ''OR\s+1\s*=\s*1'' OR query ~* ''OR\s+1\s*>\s*0''
          OR query ~* ''OR\s+true''    OR query ~* ''\)\s+OR\s+\('')',
  '{"condition":"row_count > 0","description":"Active query contains tautology injection pattern"}',
  'Check pg_stat_statements for recurring tautology digest',
  'SELECT query, calls, userid::regrole AS username
   FROM pg_stat_statements
   WHERE query ~* ''OR\s+1\s*=\s*1'' OR query ~* ''OR\s+true''
   ORDER BY calls DESC LIMIT 10',
  '{"condition":"row_count > 0","description":"Tautology pattern in statement history — not a one-off"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-009-RC01','sqlserver',
  'Detect tautology injection patterns – SQL Server',
  'Scans dm_exec_requests for OR 1=1 predicates',
  'Check active requests for tautology predicates',
  'SELECT s.login_name, t.text, r.start_time, s.host_name
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE ''%OR 1=1%'' OR t.text LIKE ''%OR 1>0%'' OR t.text LIKE ''%OR TRUE%''',
  '{"condition":"row_count > 0","description":"Active SQL Server request contains tautology injection pattern"}',
  'Check Query Store for tautology queries',
  'SELECT qt.query_sql_text, rs.count_executions, rs.first_execution_time
   FROM sys.query_store_query_text qt
   JOIN sys.query_store_query q ON q.query_text_id = qt.query_text_id
   JOIN sys.query_store_plan qp ON qp.query_id = q.query_id
   JOIN sys.query_store_runtime_stats rs ON rs.plan_id = qp.plan_id
   WHERE qt.query_sql_text LIKE ''%OR 1=1%'' OR qt.query_sql_text LIKE ''%OR 1>0%''',
  '{"condition":"row_count > 0","description":"Tautology queries found in Query Store — confirm injection attempts"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-009-RC01','mysql',
  'Detect tautology injection patterns – MySQL',
  'Scans PROCESSLIST for OR 1=1 and always-true conditions',
  'Check active queries for tautology patterns',
  'SELECT ID, USER, HOST, DB, TIME, INFO
   FROM INFORMATION_SCHEMA.PROCESSLIST
   WHERE COMMAND = ''Query''
     AND (INFO REGEXP ''OR[[:space:]]+1[[:space:]]*=[[:space:]]*1''
          OR INFO REGEXP ''OR[[:space:]]+1[[:space:]]*>[[:space:]]*0''
          OR INFO REGEXP ''OR[[:space:]]+TRUE'')',
  '{"condition":"row_count > 0","description":"Active MySQL query contains tautology injection pattern"}',
  'Check performance_schema digest for recurring tautology',
  'SELECT DIGEST_TEXT, COUNT_STAR, LAST_SEEN
   FROM performance_schema.events_statements_summary_by_digest
   WHERE DIGEST_TEXT REGEXP ''OR 1 = 1'' OR DIGEST_TEXT REGEXP ''OR TRUE''
   ORDER BY LAST_SEEN DESC LIMIT 10',
  '{"condition":"row_count > 0","description":"Tautology pattern in statement digest history"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-009-RC01','oracle',
  'Detect tautology injection patterns – Oracle',
  'Uses V$SQL to find OR 1=1 predicates in recent statements',
  'Scan V$SQL for tautology patterns',
  'SELECT sql_id, sql_text, executions, last_active_time
   FROM V$SQL
   WHERE (UPPER(sql_text) LIKE ''%OR 1=1%'' OR UPPER(sql_text) LIKE ''%OR 1>0%''
          OR UPPER(sql_text) LIKE ''%OR TRUE%'')
     AND last_active_time > SYSDATE - 1/24
   ORDER BY last_active_time DESC',
  '{"condition":"row_count > 0","description":"Tautology injection pattern found in V$SQL within last hour"}',
  'Check DBA_AUDIT_TRAIL for same patterns',
  'SELECT DB_USER, SQL_TEXT, TIMESTAMP, RETURN_CODE
   FROM DBA_AUDIT_TRAIL
   WHERE (UPPER(SQL_TEXT) LIKE ''%OR 1=1%'' OR UPPER(SQL_TEXT) LIKE ''%OR TRUE%'')
     AND TIMESTAMP > SYSDATE - 1',
  '{"condition":"row_count > 0","description":"Tautology SQL confirmed in Oracle audit trail"}'
);

-- RC02 Stacked queries
CALL rootcause.add_detection_path('SEC-SQL-AUD-009-RC02','postgresql',
  'Detect stacked query injection – PostgreSQL',
  'Identifies queries with multiple statement terminators suggesting stacked injection',
  'Scan active queries for stacked statement patterns',
  'SELECT pid, usename, query, client_addr, query_start
   FROM pg_stat_activity
   WHERE state = ''active''
     AND query ~ '';\s*(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|EXEC)''',
  '{"condition":"row_count > 0","description":"Active query contains stacked statement pattern after semicolon"}',
  'Check pg_stat_statements for stacked statement history',
  'SELECT query, calls, userid::regrole
   FROM pg_stat_statements
   WHERE query ~ '';\s*(SELECT|INSERT|UPDATE|DELETE|DROP|EXEC)''
   ORDER BY calls DESC LIMIT 10',
  '{"condition":"row_count > 0","description":"Stacked query pattern in statement history — confirm injection source"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-009-RC02','sqlserver',
  'Detect stacked query injection – SQL Server',
  'Finds requests containing semicolon-separated appended statements',
  'Check active requests for stacked SQL',
  'SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE ''%;%SELECT%'' OR t.text LIKE ''%;%DROP%''
      OR t.text LIKE ''%;%INSERT%'' OR t.text LIKE ''%;%EXEC%''',
  '{"condition":"row_count > 0","description":"Active request contains stacked SQL statement pattern"}',
  'Check Query Store for stacked query history',
  'SELECT qt.query_sql_text, rs.count_executions
   FROM sys.query_store_query_text qt
   JOIN sys.query_store_query q ON q.query_text_id = qt.query_text_id
   JOIN sys.query_store_plan qp ON qp.query_id = q.query_id
   JOIN sys.query_store_runtime_stats rs ON rs.plan_id = qp.plan_id
   WHERE qt.query_sql_text LIKE ''%;%DROP%'' OR qt.query_sql_text LIKE ''%;%EXEC%''',
  '{"condition":"row_count > 0","description":"Stacked query patterns in Query Store — persistence confirmed"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-009-RC02','mysql',
  'Detect stacked query injection – MySQL',
  'Identifies stacked statement patterns in PROCESSLIST',
  'Check PROCESSLIST for semicolon-appended statements',
  'SELECT ID, USER, HOST, DB, TIME, INFO
   FROM INFORMATION_SCHEMA.PROCESSLIST
   WHERE COMMAND = ''Query''
     AND INFO REGEXP '';\s*(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|CALL)''',
  '{"condition":"row_count > 0","description":"Active MySQL query contains stacked statement separator"}',
  'Check performance_schema for stacked query digests',
  'SELECT DIGEST_TEXT, COUNT_STAR, LAST_SEEN
   FROM performance_schema.events_statements_summary_by_digest
   WHERE DIGEST_TEXT REGEXP '';\s*(SELECT|DROP|INSERT)''
   ORDER BY LAST_SEEN DESC LIMIT 10',
  '{"condition":"row_count > 0","description":"Stacked query digests found in statement history"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-009-RC02','oracle',
  'Detect stacked query injection – Oracle',
  'Uses V$SQL to find stacked statement patterns',
  'Scan V$SQL for stacked query indicators',
  'SELECT sql_id, sql_text, executions, last_active_time
   FROM V$SQL
   WHERE REGEXP_LIKE(UPPER(sql_text), '';\s*(SELECT|INSERT|UPDATE|DELETE|DROP|EXEC)'')
     AND last_active_time > SYSDATE - 1/24',
  '{"condition":"row_count > 0","description":"Stacked SQL pattern detected in V$SQL within last hour"}',
  'Check audit trail for stacked statement execution',
  'SELECT DB_USER, SQL_TEXT, TIMESTAMP
   FROM DBA_AUDIT_TRAIL
   WHERE REGEXP_LIKE(UPPER(SQL_TEXT), '';\s*(SELECT|DROP|INSERT)'')
     AND TIMESTAMP > SYSDATE - 1',
  '{"condition":"row_count > 0","description":"Stacked query confirmed in Oracle audit trail"}'
);

-- RC03 UNION-based probing
CALL rootcause.add_detection_path('SEC-SQL-AUD-009-RC03','postgresql',
  'Detect UNION-based injection probing – PostgreSQL',
  'Finds UNION SELECT targeting system catalog tables in active queries',
  'Scan active queries for UNION SELECT with catalog tables',
  'SELECT pid, usename, query, client_addr, query_start
   FROM pg_stat_activity
   WHERE state = ''active''
     AND query ~* ''UNION\s+(ALL\s+)?SELECT''
     AND (query ~* ''information_schema'' OR query ~* ''pg_catalog'' OR query ~* ''pg_user'')',
  '{"condition":"row_count > 0","description":"Active query uses UNION SELECT targeting system catalog — injection pattern"}',
  'Check pg_stat_statements for UNION catalog probing history',
  'SELECT query, calls, userid::regrole
   FROM pg_stat_statements
   WHERE query ~* ''UNION\s+(ALL\s+)?SELECT'' AND query ~* ''information_schema''
   ORDER BY calls DESC LIMIT 10',
  '{"condition":"row_count > 0","description":"UNION-based catalog probing found in statement history"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-009-RC03','sqlserver',
  'Detect UNION-based injection probing – SQL Server',
  'Identifies UNION SELECT referencing sys.* or INFORMATION_SCHEMA in active sessions',
  'Check active requests for UNION catalog probing',
  'SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE (t.text LIKE ''%UNION%SELECT%'') AND (t.text LIKE ''%sys.%'' OR t.text LIKE ''%INFORMATION_SCHEMA%'')',
  '{"condition":"row_count > 0","description":"UNION SELECT targeting system objects found in active session"}',
  'Check Query Store for UNION catalog probing history',
  'SELECT qt.query_sql_text, rs.count_executions
   FROM sys.query_store_query_text qt
   JOIN sys.query_store_query q ON q.query_text_id = qt.query_text_id
   JOIN sys.query_store_plan qp ON qp.query_id = q.query_id
   JOIN sys.query_store_runtime_stats rs ON rs.plan_id = qp.plan_id
   WHERE qt.query_sql_text LIKE ''%UNION%SELECT%sys.%'' OR qt.query_sql_text LIKE ''%UNION%INFORMATION_SCHEMA%''',
  '{"condition":"row_count > 0","description":"UNION injection probing pattern in Query Store history"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-009-RC03','mysql',
  'Detect UNION-based injection probing – MySQL',
  'Scans PROCESSLIST for UNION SELECT targeting information_schema',
  'Check active queries for UNION information_schema probing',
  'SELECT ID, USER, HOST, DB, TIME, INFO
   FROM INFORMATION_SCHEMA.PROCESSLIST
   WHERE COMMAND = ''Query''
     AND INFO REGEXP ''UNION[[:space:]]+(ALL[[:space:]]+)?SELECT''
     AND (INFO LIKE ''%information_schema%'' OR INFO LIKE ''%mysql.user%'')',
  '{"condition":"row_count > 0","description":"Active UNION SELECT targeting MySQL system schemas"}',
  'Check performance_schema for UNION catalog probing digests',
  'SELECT DIGEST_TEXT, COUNT_STAR, LAST_SEEN
   FROM performance_schema.events_statements_summary_by_digest
   WHERE DIGEST_TEXT REGEXP ''UNION.*(ALL.+)?SELECT'' AND DIGEST_TEXT LIKE ''%information_schema%''
   ORDER BY LAST_SEEN DESC LIMIT 10',
  '{"condition":"row_count > 0","description":"UNION catalog probing in statement digest history"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-009-RC03','oracle',
  'Detect UNION-based injection probing – Oracle',
  'Uses V$SQL to find UNION SELECT against ALL_TABLES or DBA_ views',
  'Scan V$SQL for UNION targeting Oracle catalog',
  'SELECT sql_id, sql_text, executions, last_active_time
   FROM V$SQL
   WHERE REGEXP_LIKE(UPPER(sql_text), ''UNION\s+(ALL\s+)?SELECT'')
     AND (UPPER(sql_text) LIKE ''%ALL_TABLES%'' OR UPPER(sql_text) LIKE ''%DBA_USERS%''
          OR UPPER(sql_text) LIKE ''%V$%''      OR UPPER(sql_text) LIKE ''%ALL_COLUMNS%'')
     AND last_active_time > SYSDATE - 1/24',
  '{"condition":"row_count > 0","description":"UNION SELECT targeting Oracle catalog views detected"}',
  'Check audit trail for UNION catalog probe execution',
  'SELECT DB_USER, SQL_TEXT, TIMESTAMP
   FROM DBA_AUDIT_TRAIL
   WHERE REGEXP_LIKE(UPPER(SQL_TEXT), ''UNION.+SELECT'')
     AND (UPPER(SQL_TEXT) LIKE ''%ALL_TABLES%'' OR UPPER(SQL_TEXT) LIKE ''%DBA_USERS%'')
     AND TIMESTAMP > SYSDATE - 1',
  '{"condition":"row_count > 0","description":"UNION injection targeting Oracle catalog confirmed in audit trail"}'
);

-- RC04 Time-delay injection
CALL rootcause.add_detection_path('SEC-SQL-AUD-009-RC04','postgresql',
  'Detect time-delay injection – PostgreSQL',
  'Identifies pg_sleep() calls in active queries running longer than expected',
  'Check active sessions for pg_sleep usage',
  'SELECT pid, usename, query, client_addr, now() - query_start AS duration
   FROM pg_stat_activity
   WHERE state = ''active''
     AND query ~* ''pg_sleep\s*\('' AND query_start < now() - interval ''3 seconds''',
  '{"condition":"row_count > 0","description":"Active query calling pg_sleep — time-based blind injection indicator"}',
  'Check pg_stat_statements for pg_sleep with high mean execution time',
  'SELECT query, calls, mean_exec_time, userid::regrole
   FROM pg_stat_statements
   WHERE query ~* ''pg_sleep\s*\('' AND mean_exec_time > 2000
   ORDER BY mean_exec_time DESC LIMIT 10',
  '{"condition":"row_count > 0","description":"pg_sleep with high mean execution time — blind injection pattern confirmed"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-009-RC04','sqlserver',
  'Detect time-delay injection – SQL Server',
  'Finds WAITFOR DELAY in active requests',
  'Check active requests for WAITFOR DELAY',
  'SELECT s.login_name, t.text, r.start_time, r.wait_type, r.wait_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE ''%WAITFOR%DELAY%'' OR t.text LIKE ''%WAITFOR%TIME%''',
  '{"condition":"row_count > 0","description":"Active SQL Server request contains WAITFOR DELAY — time-based injection"}',
  'Check Query Store for WAITFOR DELAY history',
  'SELECT qt.query_sql_text, rs.avg_duration/1000000.0 AS avg_sec, rs.count_executions
   FROM sys.query_store_query_text qt
   JOIN sys.query_store_query q ON q.query_text_id = qt.query_text_id
   JOIN sys.query_store_plan qp ON qp.query_id = q.query_id
   JOIN sys.query_store_runtime_stats rs ON rs.plan_id = qp.plan_id
   WHERE qt.query_sql_text LIKE ''%WAITFOR%DELAY%''
   ORDER BY rs.avg_duration DESC',
  '{"condition":"row_count > 0","description":"WAITFOR DELAY queries in Query Store — time-based injection confirmed"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-009-RC04','mysql',
  'Detect time-delay injection – MySQL',
  'Identifies SLEEP() calls in active processlist queries',
  'Check PROCESSLIST for SLEEP() usage',
  'SELECT ID, USER, HOST, DB, TIME, INFO
   FROM INFORMATION_SCHEMA.PROCESSLIST
   WHERE COMMAND = ''Query''
     AND INFO REGEXP ''SLEEP[[:space:]]*\([0-9]'' AND TIME > 2',
  '{"condition":"row_count > 0","description":"Active MySQL query calling SLEEP() and running > 2 seconds"}',
  'Check performance_schema for high-latency SLEEP digest',
  'SELECT DIGEST_TEXT, COUNT_STAR, AVG_TIMER_WAIT/1000000000 AS avg_sec, LAST_SEEN
   FROM performance_schema.events_statements_summary_by_digest
   WHERE DIGEST_TEXT REGEXP ''SLEEP\s*\('' AND AVG_TIMER_WAIT/1000000000 > 2
   ORDER BY AVG_TIMER_WAIT DESC LIMIT 10',
  '{"condition":"row_count > 0","description":"SLEEP() with high average latency — blind injection pattern confirmed"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-009-RC04','oracle',
  'Detect time-delay injection – Oracle',
  'Finds DBMS_LOCK.SLEEP or DBMS_PIPE.RECEIVE_MESSAGE in V$SQL',
  'Scan V$SQL for Oracle time-delay injection calls',
  'SELECT sql_id, sql_text, executions, elapsed_time/1000000 AS elapsed_sec, last_active_time
   FROM V$SQL
   WHERE (UPPER(sql_text) LIKE ''%DBMS_LOCK.SLEEP%'' OR UPPER(sql_text) LIKE ''%DBMS_PIPE.RECEIVE_MESSAGE%''
          OR UPPER(sql_text) LIKE ''%DBMS_SESSION.SLEEP%'')
     AND last_active_time > SYSDATE - 1/24
   ORDER BY elapsed_time DESC',
  '{"condition":"row_count > 0","description":"Oracle time-delay package call in V$SQL — blind injection indicator"}',
  'Check active sessions stalled on delay packages',
  'SELECT USERNAME, STATUS, LAST_CALL_ET, PROGRAM, SQL_ID
   FROM V$SESSION
   WHERE STATUS = ''ACTIVE'' AND LAST_CALL_ET > 3
     AND SQL_ID IN (
         SELECT sql_id FROM V$SQL
         WHERE UPPER(sql_text) LIKE ''%DBMS_LOCK.SLEEP%'' OR UPPER(sql_text) LIKE ''%DBMS_PIPE%'')',
  '{"condition":"row_count > 0","description":"Active session stalled on Oracle delay package — time-based injection in progress"}'
);

-- RC05 Comment-based obfuscation
CALL rootcause.add_detection_path('SEC-SQL-AUD-009-RC05','postgresql',
  'Detect comment-based obfuscation – PostgreSQL',
  'Finds inline comments, CHR() concatenation, or hex encoding in active queries',
  'Scan active queries for obfuscation patterns',
  'SELECT pid, usename, query, client_addr, query_start
   FROM pg_stat_activity
   WHERE state = ''active''
     AND (query ~ ''/\*.*\*/'' OR query ~* ''CHR\s*\('' OR query ~ ''0x[0-9a-fA-F]{4,}'')',
  '{"condition":"row_count > 0","description":"Active query contains inline comment, CHR(), or hex encoding — obfuscation pattern"}',
  'Check pg_stat_statements for recurring obfuscated queries',
  'SELECT query, calls, userid::regrole
   FROM pg_stat_statements
   WHERE query ~ ''/\*.*\*/'' OR query ~* ''CHR\s*\(''
   ORDER BY calls DESC LIMIT 10',
  '{"condition":"row_count > 0","description":"Obfuscated query pattern recurring in statement history"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-009-RC05','sqlserver',
  'Detect comment-based obfuscation – SQL Server',
  'Identifies CHAR() concatenation or inline comments in active requests',
  'Check active requests for CHAR() obfuscation or inline comments',
  'SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE ''%CHAR(%+CHAR(%'' OR t.text LIKE ''%/*%*/%''',
  '{"condition":"row_count > 0","description":"Active SQL request uses CHAR() chaining or inline comments — obfuscation indicator"}',
  'Confirm obfuscated patterns in Query Store',
  'SELECT qt.query_sql_text, rs.count_executions
   FROM sys.query_store_query_text qt
   JOIN sys.query_store_query q ON q.query_text_id = qt.query_text_id
   JOIN sys.query_store_plan qp ON qp.query_id = q.query_id
   JOIN sys.query_store_runtime_stats rs ON rs.plan_id = qp.plan_id
   WHERE qt.query_sql_text LIKE ''%CHAR(%+CHAR(%'' OR qt.query_sql_text LIKE ''%/*%*/%''',
  '{"condition":"row_count > 0","description":"Obfuscated query patterns found in Query Store"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-009-RC05','mysql',
  'Detect comment-based obfuscation – MySQL',
  'Scans PROCESSLIST for inline comments or CHAR() encoding',
  'Check active queries for obfuscation indicators',
  'SELECT ID, USER, HOST, DB, TIME, INFO
   FROM INFORMATION_SCHEMA.PROCESSLIST
   WHERE COMMAND = ''Query''
     AND (INFO LIKE ''%/*!%'' OR INFO LIKE ''%/*%*/%''
          OR INFO REGEXP ''CHAR\s*\([0-9]+\)\s*,\s*CHAR\s*\('')',
  '{"condition":"row_count > 0","description":"Active MySQL query contains inline comment or CHAR() obfuscation"}',
  'Check performance_schema digest for recurring obfuscated patterns',
  'SELECT DIGEST_TEXT, COUNT_STAR, LAST_SEEN
   FROM performance_schema.events_statements_summary_by_digest
   WHERE DIGEST_TEXT REGEXP ''CHAR\s*\(.+\)\s*,\s*CHAR'' OR DIGEST_TEXT LIKE ''%/*%*/%''
   ORDER BY LAST_SEEN DESC LIMIT 10',
  '{"condition":"row_count > 0","description":"Obfuscated query pattern recurring in MySQL digest history"}'
);

CALL rootcause.add_detection_path('SEC-SQL-AUD-009-RC05','oracle',
  'Detect comment-based obfuscation – Oracle',
  'Uses V$SQL to find CHR() concatenation or inline comment obfuscation',
  'Scan V$SQL for CHR() or inline comment obfuscation',
  'SELECT sql_id, sql_text, executions, last_active_time
   FROM V$SQL
   WHERE (REGEXP_LIKE(sql_text, ''CHR\s*\([0-9]+\)\s*\|\|'', ''i'') OR sql_text LIKE ''%/*%*/%'')
     AND last_active_time > SYSDATE - 1/24',
  '{"condition":"row_count > 0","description":"CHR() concatenation or inline comment obfuscation in V$SQL"}',
  'Check audit trail for obfuscated SQL execution',
  'SELECT DB_USER, SQL_TEXT, TIMESTAMP
   FROM DBA_AUDIT_TRAIL
   WHERE (REGEXP_LIKE(SQL_TEXT, ''CHR\s*\([0-9]+\)\s*\|\|'', ''i'') OR SQL_TEXT LIKE ''%/*%*/%'')
     AND TIMESTAMP > SYSDATE - 1',
  '{"condition":"row_count > 0","description":"Obfuscated SQL confirmed in Oracle audit trail"}'
);

COMMIT;
