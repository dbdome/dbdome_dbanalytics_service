-- =============================================================================
-- SEC-SQL-ACC-010-RC07 — After-hours transaction activity
-- ADD program_name filter: also exclude APPLICATION-DRIVER connections
-- (the strongest "applicative" signal) on top of the login-based exclusion.
-- =============================================================================
-- Applies to vendors that expose the connecting program:
--   sqlserver (program_name), oracle (program), postgresql (application_name),
--   informix (progname). MySQL/MariaDB PROCESSLIST has no program column, so
--   they remain login-only (unchanged).
--
-- NULL/empty program names are KEPT (COALESCE -> '') so unknown/interactive
-- clients are not hidden. EDIT the driver patterns / login list for your env.
--
-- ALSO excludes connections whose program_name is a (case-insensitive) substring
-- of the user/login name — the common "service account named after its app"
-- pattern, e.g. program 'ern' connecting as login 'ERNNO1\ErnSqlServerUser'.
-- Match is `LOWER(user) LIKE '%' || LOWER(program) || '%'`, guarded so an empty
-- program_name never matches everyone. Per vendor: sqlserver login_name,
-- oracle/informix username, postgresql usename.
-- Note: excluding app drivers can also hide a COMPROMISED app credential used
-- after-hours — this is the documented trade-off you asked for.
-- Idempotent: sets the full canonical SQL. Run on dbanalytics PG (5432).
-- =============================================================================

BEGIN;

-- 1. SQL Server (12121) — login exclusion + app-driver program_name exclusion
UPDATE rootcause.detection_steps
SET content = '{"sql": "SELECT s.session_id, s.login_name, s.host_name, s.program_name, t.transaction_id, tat.transaction_begin_time, DATEDIFF(SECOND, tat.transaction_begin_time, GETDATE()) AS duration_seconds, DATEPART(HOUR, tat.transaction_begin_time) AS start_hour FROM sys.dm_exec_sessions s JOIN sys.dm_tran_session_transactions t ON t.session_id = s.session_id JOIN sys.dm_tran_active_transactions tat ON tat.transaction_id = t.transaction_id WHERE s.is_user_process = 1 AND (DATEPART(HOUR, tat.transaction_begin_time) < 7 OR DATEPART(HOUR, tat.transaction_begin_time) >= 19) AND s.login_name NOT IN (''sa'', ''app_user'', ''svc_app'', ''etl_service'') AND s.login_name NOT LIKE ''##%'' AND s.login_name NOT LIKE ''%$'' AND NOT (COALESCE(s.program_name, '''') LIKE ''%.Net SqlClient Data Provider%'' OR COALESCE(s.program_name, '''') LIKE ''%JDBC%'' OR COALESCE(s.program_name, '''') LIKE ''%jTDS%'' OR COALESCE(s.program_name, '''') LIKE ''%ODBC%'' OR COALESCE(s.program_name, '''') LIKE ''SQLAlchemy%'' OR COALESCE(s.program_name, '''') LIKE ''pyodbc%'' OR COALESCE(s.program_name, '''') LIKE ''python%'' OR COALESCE(s.program_name, '''') LIKE ''PHP%'' OR COALESCE(s.program_name, '''') LIKE ''node%'' OR (COALESCE(s.program_name, '''') <> '''' AND LOWER(s.login_name) LIKE ''%'' + LOWER(s.program_name) + ''%'')) ORDER BY tat.transaction_begin_time"}'::jsonb
WHERE id = 12121;

-- 2. Oracle (12149) — s.program
UPDATE rootcause.detection_steps
SET content = '{"sql": "SELECT s.sid, s.serial#, s.username, s.osuser, s.machine, s.program, t.start_time, ROUND((SYSDATE - TO_DATE(t.start_time, ''MM/DD/YY HH24:MI:SS'')) * 86400) AS duration_seconds, TO_NUMBER(TO_CHAR(TO_DATE(t.start_time, ''MM/DD/YY HH24:MI:SS''), ''HH24'')) AS start_hour FROM v$session s JOIN v$transaction t ON t.ses_addr = s.saddr WHERE s.type = ''USER'' AND (TO_NUMBER(TO_CHAR(TO_DATE(t.start_time, ''MM/DD/YY HH24:MI:SS''), ''HH24'')) < 7 OR TO_NUMBER(TO_CHAR(TO_DATE(t.start_time, ''MM/DD/YY HH24:MI:SS''), ''HH24'')) >= 19) AND UPPER(s.username) NOT IN (''SYS'',''SYSTEM'',''DBSNMP'',''SYSMAN'',''XDB'',''GSMADMIN_INTERNAL'',''APP_USER'',''SVC_APP'',''ETL_SERVICE'') AND NOT (UPPER(COALESCE(s.program, '''')) LIKE ''%JDBC%'' OR UPPER(COALESCE(s.program, '''')) LIKE ''W3WP%'' OR UPPER(COALESCE(s.program, '''')) LIKE ''%ODBC%'' OR UPPER(COALESCE(s.program, '''')) LIKE ''PYTHON%'' OR UPPER(COALESCE(s.program, '''')) LIKE ''NODE%'' OR (COALESCE(s.program, '''') <> '''' AND UPPER(s.username) LIKE ''%'' || UPPER(s.program) || ''%'')) ORDER BY t.start_time"}'::jsonb
WHERE id = 12149;

-- 3. PostgreSQL (12135) — application_name
UPDATE rootcause.detection_steps
SET content = '{"sql": "SELECT pid, usename, client_addr, application_name, backend_start, xact_start, EXTRACT(EPOCH FROM (now() - xact_start))::int AS duration_seconds, EXTRACT(HOUR FROM xact_start)::int AS start_hour, state, query FROM pg_stat_activity WHERE xact_start IS NOT NULL AND backend_type = ''client backend'' AND (EXTRACT(HOUR FROM xact_start) < 7 OR EXTRACT(HOUR FROM xact_start) >= 19) AND usename NOT IN (''postgres'',''rdsadmin'',''replication'',''app_user'',''svc_app'',''etl_service'') AND NOT (COALESCE(application_name, '''') LIKE ''%JDBC%'' OR COALESCE(application_name, '''') LIKE ''psycopg%'' OR COALESCE(application_name, '''') LIKE ''SQLAlchemy%'' OR COALESCE(application_name, '''') LIKE ''Npgsql%'' OR COALESCE(application_name, '''') LIKE ''node-postgres%'' OR COALESCE(application_name, '''') LIKE ''PHP%'' OR (COALESCE(application_name, '''') <> '''' AND LOWER(usename) LIKE ''%'' || LOWER(application_name) || ''%'')) ORDER BY xact_start"}'::jsonb
WHERE id = 12135;

-- 4. Informix (12201) — s.progname
UPDATE rootcause.detection_steps
SET content = '{"sql": "SELECT s.sid, s.username, s.hostname, s.progname, s.connected, EXTEND(CURRENT, HOUR TO HOUR)::INT AS current_hour FROM sysmaster:syssessions s WHERE s.sid > 0 AND (EXTEND(CURRENT, HOUR TO HOUR)::INT < 7 OR EXTEND(CURRENT, HOUR TO HOUR)::INT >= 19) AND UPPER(s.username) NOT IN (''INFORMIX'',''ROOT'',''APP_USER'',''SVC_APP'',''ETL_SERVICE'') AND NOT (UPPER(COALESCE(s.progname, '''')) LIKE ''%JDBC%'' OR UPPER(COALESCE(s.progname, '''')) LIKE ''%ODBC%'' OR UPPER(COALESCE(s.progname, '''')) LIKE ''PYTHON%'' OR UPPER(COALESCE(s.progname, '''')) LIKE ''NODE%'' OR (COALESCE(s.progname, '''') <> '''' AND UPPER(s.username) LIKE ''%'' || UPPER(s.progname) || ''%'')) ORDER BY s.sid"}'::jsonb
WHERE id = 12201;

-- Verify (mysql/mariadb intentionally login-only: no program column)
SELECT ds.id, ds.vendor_slug,
       (ds.content->>'sql' LIKE '%NOT IN%')              AS has_login_excl,
       (ds.content->>'sql' LIKE '%program%' OR ds.content->>'sql' LIKE '%application_name%'
        OR ds.content->>'sql' LIKE '%progname%')          AS has_program_col,
       (ds.content->>'sql' LIKE '%NOT (COALESCE%')        AS has_program_excl
FROM rootcause.detection_steps ds
WHERE ds.id IN (12121, 12149, 12135, 12163, 15462, 12201)
ORDER BY ds.vendor_slug;

COMMIT;
