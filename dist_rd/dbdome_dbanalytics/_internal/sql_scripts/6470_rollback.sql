-- 6470 ROLLBACK: restore original SEC-SQL-AUD detection SQL (undo 6470)
BEGIN;

UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r15481$SELECT ID, USER, HOST, DB, TIME, INFO
     FROM INFORMATION_SCHEMA.PROCESSLIST
     WHERE COMMAND = 'Query'
       AND (INFO LIKE '%GRANT %' OR INFO LIKE '%SET ROLE%'
            OR INFO LIKE '%CREATE USER%' OR INFO LIKE '%ALTER USER%')$r15481$) WHERE vendor_slug = 'mariadb' AND name = 'Check PROCESSLIST for active GRANT or privilege-changing statements';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r15482$SELECT GRANTEE, PRIVILEGE_TYPE, IS_GRANTABLE
     FROM INFORMATION_SCHEMA.USER_PRIVILEGES
     WHERE GRANTEE IN (
         SELECT CONCAT('''',USER,'''','@',''',HOST,'''')
         FROM INFORMATION_SCHEMA.PROCESSLIST
         WHERE INFO LIKE '%GRANT %'
     )
     AND IS_GRANTABLE = 'NO'$r15482$) WHERE vendor_slug = 'mariadb' AND name = 'Check if the issuing account itself lacks GRANT OPTION';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r15856$SELECT DATE_FORMAT(LAST_SEEN,'%Y-%m-%d %H:%i:%s') AS event_time, CAST(NULL AS CHAR) AS login_name,
       @@hostname AS host_name, CAST(NULL AS CHAR) AS os_user, CONCAT('count=',COUNT_STAR) AS auth_info,
       LEFT(DIGEST_TEXT,4000) AS statement
FROM performance_schema.events_statements_summary_by_digest
WHERE DIGEST_TEXT IS NOT NULL AND (DIGEST_TEXT LIKE '%CREATE USER%' OR DIGEST_TEXT LIKE '%CREATE ROLE%')
ORDER BY LAST_SEEN DESC LIMIT 500$r15856$) WHERE vendor_slug = 'mariadb' AND name = 'Detect SEC-SQL-AUD-023-RC01 (mariadb)';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r15860$SELECT DATE_FORMAT(LAST_SEEN,'%Y-%m-%d %H:%i:%s') AS event_time, CAST(NULL AS CHAR) AS login_name,
       @@hostname AS host_name, CAST(NULL AS CHAR) AS os_user, CONCAT('count=',COUNT_STAR) AS auth_info,
       LEFT(DIGEST_TEXT,4000) AS statement
FROM performance_schema.events_statements_summary_by_digest
WHERE DIGEST_TEXT IS NOT NULL AND (DIGEST_TEXT LIKE '%GRANT%')
ORDER BY LAST_SEEN DESC LIMIT 500$r15860$) WHERE vendor_slug = 'mariadb' AND name = 'Detect SEC-SQL-AUD-023-RC02 (mariadb)';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r15864$SELECT DATE_FORMAT(LAST_SEEN,'%Y-%m-%d %H:%i:%s') AS event_time, CAST(NULL AS CHAR) AS login_name,
       @@hostname AS host_name, CAST(NULL AS CHAR) AS os_user, CONCAT('count=',COUNT_STAR) AS auth_info,
       LEFT(DIGEST_TEXT,4000) AS statement
FROM performance_schema.events_statements_summary_by_digest
WHERE DIGEST_TEXT IS NOT NULL AND (DIGEST_TEXT LIKE '%DROP USER%' OR DIGEST_TEXT LIKE '%DROP ROLE%')
ORDER BY LAST_SEEN DESC LIMIT 500$r15864$) WHERE vendor_slug = 'mariadb' AND name = 'Detect SEC-SQL-AUD-023-RC03 (mariadb)';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12247$SELECT ID, USER, HOST, DB, TIME, INFO
     FROM INFORMATION_SCHEMA.PROCESSLIST
     WHERE COMMAND = 'Query'
       AND (INFO LIKE '%GRANT %' OR INFO LIKE '%SET ROLE%'
            OR INFO LIKE '%CREATE USER%' OR INFO LIKE '%ALTER USER%')$r12247$) WHERE vendor_slug = 'mysql' AND name = 'Check PROCESSLIST for active GRANT or privilege-changing statements';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12248$SELECT GRANTEE, PRIVILEGE_TYPE, IS_GRANTABLE
     FROM INFORMATION_SCHEMA.USER_PRIVILEGES
     WHERE GRANTEE IN (
         SELECT CONCAT('''',USER,'''','@',''',HOST,'''')
         FROM INFORMATION_SCHEMA.PROCESSLIST
         WHERE INFO LIKE '%GRANT %'
     )
     AND IS_GRANTABLE = 'NO'$r12248$) WHERE vendor_slug = 'mysql' AND name = 'Check if the issuing account itself lacks GRANT OPTION';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r15855$SELECT DATE_FORMAT(LAST_SEEN,'%Y-%m-%d %H:%i:%s') AS event_time, CAST(NULL AS CHAR) AS login_name,
       @@hostname AS host_name, CAST(NULL AS CHAR) AS os_user, CONCAT('count=',COUNT_STAR) AS auth_info,
       LEFT(DIGEST_TEXT,4000) AS statement
FROM performance_schema.events_statements_summary_by_digest
WHERE DIGEST_TEXT IS NOT NULL AND (DIGEST_TEXT LIKE '%CREATE USER%' OR DIGEST_TEXT LIKE '%CREATE ROLE%')
ORDER BY LAST_SEEN DESC LIMIT 500$r15855$) WHERE vendor_slug = 'mysql' AND name = 'Detect SEC-SQL-AUD-023-RC01 (mysql)';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r15859$SELECT DATE_FORMAT(LAST_SEEN,'%Y-%m-%d %H:%i:%s') AS event_time, CAST(NULL AS CHAR) AS login_name,
       @@hostname AS host_name, CAST(NULL AS CHAR) AS os_user, CONCAT('count=',COUNT_STAR) AS auth_info,
       LEFT(DIGEST_TEXT,4000) AS statement
FROM performance_schema.events_statements_summary_by_digest
WHERE DIGEST_TEXT IS NOT NULL AND (DIGEST_TEXT LIKE '%GRANT%')
ORDER BY LAST_SEEN DESC LIMIT 500$r15859$) WHERE vendor_slug = 'mysql' AND name = 'Detect SEC-SQL-AUD-023-RC02 (mysql)';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r15863$SELECT DATE_FORMAT(LAST_SEEN,'%Y-%m-%d %H:%i:%s') AS event_time, CAST(NULL AS CHAR) AS login_name,
       @@hostname AS host_name, CAST(NULL AS CHAR) AS os_user, CONCAT('count=',COUNT_STAR) AS auth_info,
       LEFT(DIGEST_TEXT,4000) AS statement
FROM performance_schema.events_statements_summary_by_digest
WHERE DIGEST_TEXT IS NOT NULL AND (DIGEST_TEXT LIKE '%DROP USER%' OR DIGEST_TEXT LIKE '%DROP ROLE%')
ORDER BY LAST_SEEN DESC LIMIT 500$r15863$) WHERE vendor_slug = 'mysql' AND name = 'Detect SEC-SQL-AUD-023-RC03 (mysql)';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12249$SELECT s.USERNAME, q.SQL_TEXT, s.LOGON_TIME, s.STATUS
     FROM V$SESSION s JOIN V$SQL q ON s.SQL_ID = q.SQL_ID
     WHERE (UPPER(q.SQL_TEXT) LIKE '%GRANT %'
            OR UPPER(q.SQL_TEXT) LIKE '%ALTER SESSION SET ROLE%'
            OR UPPER(q.SQL_TEXT) LIKE '%DBMS_PRIVILEGE_CAPTURE%')$r12249$) WHERE vendor_slug = 'oracle' AND name = 'Check V$SQL for recent GRANT or ALTER SESSION SET ROLE statements';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12565$SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE (UPPER(q.sql_text) LIKE '%NOAUDIT%' OR UPPER(q.sql_text) LIKE '%DISABLE POLICY%'
          OR UPPER(q.sql_text) LIKE '%ALTER SYSTEM SET AUDIT_TRAIL%')
     AND q.last_active_time > SYSDATE - 1/24$r12565$) WHERE vendor_slug = 'oracle' AND name = 'Scan V$SQL for audit disabling commands';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12573$SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE (UPPER(q.sql_text) LIKE '%TRUNCATE%TABLE%AUD%' OR UPPER(q.sql_text) LIKE '%DROP%TABLE%AUD%'
          OR UPPER(q.sql_text) LIKE '%TRUNCATE%FGA_LOG%')
     AND q.last_active_time > SYSDATE - 1/24$r12573$) WHERE vendor_slug = 'oracle' AND name = 'Scan V$SQL for destructive DDL on audit tables';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12581$SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE (UPPER(q.sql_text) LIKE '%ALTER%TRIGGER%DISABLE%' OR UPPER(q.sql_text) LIKE '%DISABLE ALL TRIGGERS%')
     AND q.last_active_time > SYSDATE - 1/24$r12581$) WHERE vendor_slug = 'oracle' AND name = 'Scan V$SQL for trigger disable commands';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12589$SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE (UPPER(q.sql_text) LIKE '%ALTER SYSTEM SWITCH LOGFILE%'
          OR UPPER(q.sql_text) LIKE '%DBMS_SYSTEM.KSDWRT%')
     AND q.last_active_time > SYSDATE - 1/24$r12589$) WHERE vendor_slug = 'oracle' AND name = 'Scan V$SQL for log switch commands';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12637$SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE UPPER(q.sql_text) LIKE '%ALTER SYSTEM SET%'
     AND s.username NOT IN (SELECT grantee FROM dba_sys_privs WHERE privilege = 'ALTER SYSTEM')
     AND q.last_active_time > SYSDATE - 1/24$r12637$) WHERE vendor_slug = 'oracle' AND name = 'Scan V$SQL for ALTER SYSTEM by non-DBA account';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12645$SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE UPPER(q.sql_text) LIKE '%GRANT%EXECUTE%'
     AND (UPPER(q.sql_text) LIKE '%UTL_FILE%' OR UPPER(q.sql_text) LIKE '%UTL_HTTP%'
          OR UPPER(q.sql_text) LIKE '%DBMS_SCHEDULER%' OR UPPER(q.sql_text) LIKE '%DBMS_ADVISOR%'
          OR UPPER(q.sql_text) LIKE '%DBMS_JAVA%')
     AND q.last_active_time > SYSDATE - 1/24$r12645$) WHERE vendor_slug = 'oracle' AND name = 'Scan V$SQL for GRANT on dangerous Oracle packages';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12653$SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE (UPPER(q.sql_text) LIKE '%ALTER%TRIGGER%DISABLE%' OR UPPER(q.sql_text) LIKE '%DROP%TRIGGER%')
     AND s.username NOT IN ('SYS','SYSTEM')
     AND q.last_active_time > SYSDATE - 1/24$r12653$) WHERE vendor_slug = 'oracle' AND name = 'Scan V$SQL for trigger disable or drop in application schemas';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12661$SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE (UPPER(q.sql_text) LIKE '%NOAUDIT%' OR UPPER(q.sql_text) LIKE '%ALTER AUDIT POLICY%DISABLE%'
          OR UPPER(q.sql_text) LIKE '%ALTER SYSTEM SET AUDIT_TRAIL%NONE%')
     AND q.last_active_time > SYSDATE - 1/24$r12661$) WHERE vendor_slug = 'oracle' AND name = 'Scan V$SQL for audit policy disabling commands';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12669$SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE (UPPER(q.sql_text) LIKE '%ALTER SYSTEM SET REMOTE_LOGIN_PASSWORDFILE%'
          OR UPPER(q.sql_text) LIKE '%ALTER SYSTEM SET OS_AUTHENT_PREFIX%'
          OR UPPER(q.sql_text) LIKE '%CREATE DATABASE LINK%'
          OR UPPER(q.sql_text) LIKE '%ALTER SYSTEM SET REMOTE_OS_AUTHENT%')
     AND q.last_active_time > SYSDATE - 1/24$r12669$) WHERE vendor_slug = 'oracle' AND name = 'Scan V$SQL for authentication or network parameter changes';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12677$SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE UPPER(q.sql_text) LIKE '%CREATE USER%'
     AND q.last_active_time > SYSDATE - 1/24$r12677$) WHERE vendor_slug = 'oracle' AND name = 'Scan V$SQL for CREATE USER commands';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12685$SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE UPPER(q.sql_text) LIKE '%GRANT%DBA%'
      OR UPPER(q.sql_text) LIKE '%GRANT%SYSDBA%'
      OR UPPER(q.sql_text) LIKE '%GRANT%SYSOPER%'
     AND q.last_active_time > SYSDATE - 1/24$r12685$) WHERE vendor_slug = 'oracle' AND name = 'Scan V$SQL for privileged role grant commands';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12693$SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE UPPER(q.sql_text) LIKE '%ALTER USER%IDENTIFIED BY%'
     AND q.last_active_time > SYSDATE - 1/24$r12693$) WHERE vendor_slug = 'oracle' AND name = 'Scan V$SQL for ALTER USER IDENTIFIED BY commands';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12701$SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE (UPPER(q.sql_text) LIKE '%CREATE%DATABASE LINK%' OR UPPER(q.sql_text) LIKE '%CREATE%PUBLIC DATABASE LINK%')
     AND q.last_active_time > SYSDATE - 1/24$r12701$) WHERE vendor_slug = 'oracle' AND name = 'Scan V$SQL for CREATE DATABASE LINK commands';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12709$SELECT s.username, s.sid, q.sql_text, q.last_active_time
   FROM v$sql q
   JOIN v$session s ON q.parsing_user_id = s.user#
   WHERE (UPPER(q.sql_text) LIKE '%ALTER USER%ACCOUNT UNLOCK%'
          OR UPPER(q.sql_text) LIKE '%ALTER USER%ENABLE%'
          OR UPPER(q.sql_text) LIKE '%ALTER USER%PASSWORD EXPIRE%')
     AND q.last_active_time > SYSDATE - 1/24$r12709$) WHERE vendor_slug = 'oracle' AND name = 'Scan V$SQL for account unlock or expiry removal commands';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r15641$SELECT event_timestamp AS event_time, dbusername AS login_name, object_schema AS database_name, object_name, sql_text AS statement
FROM unified_audit_trail
WHERE event_timestamp > SYSTIMESTAMP - INTERVAL '1' DAY
  AND (action_name IN ('DROP PLUGGABLE DATABASE','DROP TABLESPACE') OR UPPER(sql_text) LIKE '%DROP DATABASE%')
ORDER BY event_timestamp DESC FETCH FIRST 500 ROWS ONLY$r15641$) WHERE vendor_slug = 'oracle' AND name = 'Detect SEC-SQL-AUD-020-RC01 (oracle)';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r15673$SELECT
  TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD HH24:MI:SS') AS event_time,
  s.username AS login_name,
  SYS_CONTEXT('USERENV','DB_NAME') AS database_name,
  CAST(NULL AS VARCHAR2(128)) AS object_name,
  SUBSTR(sq.sql_text,1,4000) AS statement
FROM v$session s
JOIN v$sql sq ON sq.sql_id = s.sql_id
WHERE s.type = 'USER' AND s.username IS NOT NULL
  AND s.username NOT IN ('SYS','SYSTEM','DBSNMP','SYSMAN','XDB')
  AND (UPPER(sq.sql_text) LIKE '%DROP DATABASE%' OR UPPER(sq.sql_text) LIKE '%DROP PLUGGABLE DATABASE%' OR UPPER(sq.sql_text) LIKE '%DROP TABLESPACE%' OR UPPER(sq.sql_text) LIKE '%DROP SCHEMA%')$r15673$) WHERE vendor_slug = 'oracle' AND name = 'Detect SEC-SQL-AUD-020-RC01 (oracle) - live activity (v$session)';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r15675$SELECT
  TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD HH24:MI:SS') AS event_time,
  s.username AS login_name,
  SYS_CONTEXT('USERENV','DB_NAME') AS database_name,
  CAST(NULL AS VARCHAR2(128)) AS object_name,
  SUBSTR(sq.sql_text,1,4000) AS statement
FROM v$session s
JOIN v$sql sq ON sq.sql_id = s.sql_id
WHERE s.type = 'USER' AND s.username IS NOT NULL
  AND s.username NOT IN ('SYS','SYSTEM','DBSNMP','SYSMAN','XDB')
  AND (UPPER(sq.sql_text) LIKE '%DROP TABLE%')$r15675$) WHERE vendor_slug = 'oracle' AND name = 'Detect SEC-SQL-AUD-020-RC02 (oracle) - live activity (v$session)';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r15679$SELECT
  TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD HH24:MI:SS') AS event_time,
  s.username AS login_name,
  SYS_CONTEXT('USERENV','DB_NAME') AS database_name,
  CAST(NULL AS VARCHAR2(128)) AS object_name,
  SUBSTR(sq.sql_text,1,4000) AS statement
FROM v$session s
JOIN v$sql sq ON sq.sql_id = s.sql_id
WHERE s.type = 'USER' AND s.username IS NOT NULL
  AND s.username NOT IN ('SYS','SYSTEM','DBSNMP','SYSMAN','XDB')
  AND (UPPER(sq.sql_text) LIKE '%DELETE %' OR UPPER(sq.sql_text) LIKE '%TRUNCATE TABLE%')$r15679$) WHERE vendor_slug = 'oracle' AND name = 'Detect SEC-SQL-AUD-020-RC04 (oracle) - live activity (v$session)';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r15857$SELECT TO_CHAR(event_timestamp,'YYYY-MM-DD HH24:MI:SS') AS event_time, dbusername AS login_name,
       userhost AS host_name, os_username AS os_user, action_name AS auth_info, sql_text AS statement
FROM unified_audit_trail WHERE (action_name LIKE '%GRANT%')
  AND event_timestamp > SYSTIMESTAMP - INTERVAL '1' DAY
ORDER BY event_timestamp DESC FETCH FIRST 500 ROWS ONLY$r15857$) WHERE vendor_slug = 'oracle' AND name = 'Detect SEC-SQL-AUD-023-RC02 (oracle)';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12559$SELECT pid, usename, query, client_addr, query_start
   FROM pg_stat_activity
   WHERE state = 'active'
     AND (query ILIKE '%SET log_statement%none%' OR query ILIKE '%SET log_statement%ddl%'
          OR query ILIKE '%ALTER SYSTEM SET log_statement%'
          OR query ILIKE '%SET log_min_duration_statement%')$r12559$) WHERE vendor_slug = 'postgresql' AND name = 'Scan active queries for log_statement reduction commands';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12245$SELECT s.login_name, s.original_login_name, t.text, r.start_time
     FROM sys.dm_exec_sessions s
     JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
     CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
     WHERE t.text LIKE '%EXECUTE AS%'
        OR t.text LIKE '%GRANT%SERVER ROLE%'
        OR t.text LIKE '%ALTER SERVER ROLE%'$r12245$) WHERE vendor_slug = 'sqlserver' AND name = 'Check running requests for EXECUTE AS or GRANT statements';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12310$SELECT dp.name AS login, drm.role_principal_id,
            dp2.name AS role_name
     FROM sys.database_principals dp
     JOIN sys.database_role_members drm ON drm.member_principal_id = dp.principal_id
     JOIN sys.database_principals dp2 ON dp2.principal_id = drm.role_principal_id
     WHERE dp.name IN (
         SELECT s2.login_name FROM sys.dm_exec_sessions s2
         JOIN sys.dm_exec_requests r2 ON r2.session_id = s2.session_id
         WHERE r2.command LIKE '%CREATE%' OR r2.command LIKE '%ALTER%' OR r2.command LIKE '%DROP%'
     )$r12310$) WHERE vendor_slug = 'sqlserver' AND name = 'Check if the login holds any DDL-enabling database roles';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12553$SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE (t.text LIKE '%INSERT%' OR t.text LIKE '%UPDATE%' OR t.text LIKE '%DELETE%')
     AND (t.text LIKE '%audit%' OR t.text LIKE '%event_log%' OR t.text LIKE '%trace_log%')$r12553$) WHERE vendor_slug = 'sqlserver' AND name = 'Check active requests for DML on audit tables';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12561$SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE '%ALTER%AUDIT%STATE%OFF%'
      OR t.text LIKE '%sp_configure%audit%'$r12561$) WHERE vendor_slug = 'sqlserver' AND name = 'Check active requests for audit disabling commands';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12569$SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE (t.text LIKE '%TRUNCATE%TABLE%' OR t.text LIKE '%DROP%TABLE%')
     AND (t.text LIKE '%audit%' OR t.text LIKE '%event_log%' OR t.text LIKE '%trace%')$r12569$) WHERE vendor_slug = 'sqlserver' AND name = 'Check active requests for audit table destruction';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12649$SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE '%DISABLE%TRIGGER%' OR t.text LIKE '%DROP%TRIGGER%'$r12649$) WHERE vendor_slug = 'sqlserver' AND name = 'Check active requests for trigger disable or drop';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12657$SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE '%ALTER%SERVER%AUDIT%' OR t.text LIKE '%ALTER%AUDIT%SPECIFICATION%'$r12657$) WHERE vendor_slug = 'sqlserver' AND name = 'Check active requests for audit specification modification';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12673$SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE '%CREATE%LOGIN%' OR t.text LIKE '%CREATE%USER%'$r12673$) WHERE vendor_slug = 'sqlserver' AND name = 'Check active requests for CREATE LOGIN or CREATE USER';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12681$SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE '%ALTER%SERVER%ROLE%ADD%MEMBER%'
      OR t.text LIKE '%sp_addsrvrolemember%'$r12681$) WHERE vendor_slug = 'sqlserver' AND name = 'Check active requests for privileged role membership changes';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12689$SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE '%ALTER%LOGIN%PASSWORD%'$r12689$) WHERE vendor_slug = 'sqlserver' AND name = 'Check active requests for ALTER LOGIN password changes';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12697$SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE '%sp_addlinkedserver%' OR t.text LIKE '%CREATE%SYNONYM%'$r12697$) WHERE vendor_slug = 'sqlserver' AND name = 'Check active requests for linked server or synonym creation';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r12705$SELECT s.login_name, t.text, r.start_time
   FROM sys.dm_exec_sessions s
   JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE t.text LIKE '%ALTER%LOGIN%ENABLE%'$r12705$) WHERE vendor_slug = 'sqlserver' AND name = 'Check active requests for ALTER LOGIN ENABLE commands';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r15672$SET NOCOUNT ON;
BEGIN TRY
  SELECT TOP 500 event_time, server_principal_name AS login_name, database_name, object_name, statement
  FROM sys.fn_get_audit_file(N'C:\Audit\dbdome_audit*.sqlaudit', DEFAULT, DEFAULT)
  WHERE event_time > DATEADD(DAY,-1, SYSUTCDATETIME())
    AND (statement LIKE '%DROP%DATABASE%' OR statement LIKE '%DROP%SCHEMA%')
  ORDER BY event_time DESC;
END TRY
BEGIN CATCH
  SELECT CAST(NULL AS DATETIME2) AS event_time, CAST(NULL AS SYSNAME) AS login_name,
         CAST(NULL AS SYSNAME) AS database_name, CAST(NULL AS SYSNAME) AS object_name,
         CAST(NULL AS NVARCHAR(MAX)) AS statement
  WHERE 1=0;
END CATCH$r15672$) WHERE vendor_slug = 'sqlserver' AND name = 'Detect SEC-SQL-AUD-020-RC01 (sqlserver) - audit trail (fn_get_audit_file)';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r15674$SET NOCOUNT ON;
BEGIN TRY
  SELECT TOP 500 event_time, server_principal_name AS login_name, database_name, object_name, statement
  FROM sys.fn_get_audit_file(N'C:\Audit\dbdome_audit*.sqlaudit', DEFAULT, DEFAULT)
  WHERE event_time > DATEADD(DAY,-1, SYSUTCDATETIME())
    AND (statement LIKE '%DROP%TABLE%')
  ORDER BY event_time DESC;
END TRY
BEGIN CATCH
  SELECT CAST(NULL AS DATETIME2) AS event_time, CAST(NULL AS SYSNAME) AS login_name,
         CAST(NULL AS SYSNAME) AS database_name, CAST(NULL AS SYSNAME) AS object_name,
         CAST(NULL AS NVARCHAR(MAX)) AS statement
  WHERE 1=0;
END CATCH$r15674$) WHERE vendor_slug = 'sqlserver' AND name = 'Detect SEC-SQL-AUD-020-RC02 (sqlserver) - audit trail (fn_get_audit_file)';
UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', $r15678$SET NOCOUNT ON;
BEGIN TRY
  SELECT TOP 500 event_time, server_principal_name AS login_name, database_name, object_name, statement
  FROM sys.fn_get_audit_file(N'C:\Audit\dbdome_audit*.sqlaudit', DEFAULT, DEFAULT)
  WHERE event_time > DATEADD(DAY,-1, SYSUTCDATETIME())
    AND (statement LIKE '%DELETE%FROM%' OR statement LIKE '%TRUNCATE%TABLE%')
  ORDER BY event_time DESC;
END TRY
BEGIN CATCH
  SELECT CAST(NULL AS DATETIME2) AS event_time, CAST(NULL AS SYSNAME) AS login_name,
         CAST(NULL AS SYSNAME) AS database_name, CAST(NULL AS SYSNAME) AS object_name,
         CAST(NULL AS NVARCHAR(MAX)) AS statement
  WHERE 1=0;
END CATCH$r15678$) WHERE vendor_slug = 'sqlserver' AND name = 'Detect SEC-SQL-AUD-020-RC04 (sqlserver) - audit trail (fn_get_audit_file)';

COMMIT;
