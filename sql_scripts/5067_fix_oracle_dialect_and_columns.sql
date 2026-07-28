-- =============================================================================
-- 5067_fix_oracle_dialect_and_columns.sql
-- Fix Oracle detection queries surfaced by oracle_rootcause_tester. Two classes:
--   * dialect/structural: postgres LIKE ANY(ARRAY[...]), infix REGEXP_LIKE,
--     '--' comments and multi-statement bodies (LETHAL: the collector flattens
--     newlines to spaces, so '--' comments out the rest of the query).
--   * wrong identifiers: RETURN_CODE->RETURNCODE (DBA_AUDIT_TRAIL),
--     dba_audit_object_opts->dba_obj_audit_opts (+ owner col),
--     proxy_name/user_name/enabled_opt -> entity_name/enabled_option
--     (audit_unified_enabled_policies, per the sibling step's valid columns).
-- Each UPDATE is scoped by vendor_slug='oracle' + exact step name (seed data,
-- identical in dbanalytics and dbanalytics_install). No '--' inside the stored
-- SQL, no trailing ';'. Idempotent. The two DBA_JAVA_POLICY detections
-- (CFG-004-RC07, VS-002-RC09) are NOT touched: they require the Oracle JVM and
-- legitimately raise ORA-00942 on instances without it.
-- =============================================================================

-- 1) AUD-004-RC08 "ora-check-audit-exclusions-configured": proxy_name/user_name/
--    enabled_opt don't exist; use entity_name/policy_name/enabled_option.
UPDATE rootcause.detection_steps
SET content = jsonb_set(content, '{sql}', to_jsonb($q$SELECT entity_name, policy_name, enabled_option
FROM audit_unified_enabled_policies
WHERE entity_type = 'USER'
  AND enabled_option LIKE 'EXCEPT%'
ORDER BY entity_name$q$::text))
WHERE vendor_slug='oracle' AND name='ora-check-audit-exclusions-configured';

-- 2) AUD-006-RC01 step: strip inline '-- INSERT,UPDATE,...' comment.
UPDATE rootcause.detection_steps
SET content = jsonb_set(content, '{sql}', to_jsonb($q$SELECT s.SID, s.SERIAL#, s.USERNAME, s.OSUSER, s.MACHINE,
       s.STATUS, q.SQL_TEXT, s.LOGON_TIME
FROM V$SESSION s
JOIN V$SQL q ON s.SQL_ID = q.SQL_ID
WHERE s.STATUS = 'ACTIVE'
  AND q.COMMAND_TYPE IN (2,6,7,9)
  AND s.USERNAME IN (
      SELECT GRANTEE FROM DBA_ROLE_PRIVS WHERE GRANTED_ROLE = 'DBA'
  )$q$::text))
WHERE vendor_slug='oracle' AND name='Check V$SESSION for DML by DBA-role accounts';

-- 3) AUD-006-RC04 step 1: LIKE ANY(ARRAY[...]) -> OR-chain of LIKEs.
UPDATE rootcause.detection_steps
SET content = jsonb_set(content, '{sql}', to_jsonb($q$SELECT USERNAME, PROGRAM, MACHINE, TERMINAL, LOGON_TIME, STATUS
FROM V$SESSION
WHERE (UPPER(PROGRAM) LIKE '%SQLPLUS%' OR UPPER(PROGRAM) LIKE '%SQLDEV%'
       OR UPPER(PROGRAM) LIKE '%TOAD%' OR UPPER(PROGRAM) LIKE '%DBEAVER%')
  AND (UPPER(USERNAME) LIKE '%SVC%' OR UPPER(USERNAME) LIKE '%SERVICE%'
       OR UPPER(USERNAME) LIKE '%APP%' OR UPPER(USERNAME) LIKE '%API%'
       OR UPPER(USERNAME) LIKE '%ETL%')$q$::text))
WHERE vendor_slug='oracle' AND name='Check V$SESSION for service accounts with interactive program names';

-- 4) AUD-006-RC04 step 2: infix REGEXP_LIKE -> function form.
UPDATE rootcause.detection_steps
SET content = jsonb_set(content, '{sql}', to_jsonb($q$SELECT GRANTEE, GRANTED_ROLE, ADMIN_OPTION, DEFAULT_ROLE
FROM DBA_ROLE_PRIVS
WHERE REGEXP_LIKE(GRANTEE, '(SVC|SERVICE|APP|API|ETL)')
  AND GRANTED_ROLE NOT IN ('CONNECT','RESOURCE')$q$::text))
WHERE vendor_slug='oracle' AND name='Verify account has application-only role assignments';

-- 5) AUD-007-RC04 step 1: infix REGEXP_LIKE in subquery -> function form.
UPDATE rootcause.detection_steps
SET content = jsonb_set(content, '{sql}', to_jsonb($q$SELECT USERNAME, PROGRAM, MACHINE, LOGON_TIME, STATUS,
       TO_NUMBER(TO_CHAR(SYS_EXTRACT_UTC(SYSTIMESTAMP),'HH24')) AS utc_hour
FROM V$SESSION
WHERE TYPE = 'USER'
  AND STATUS = 'ACTIVE'
  AND USERNAME NOT IN (
      SELECT USERNAME FROM DBA_USERS
      WHERE REGEXP_LIKE(USERNAME, '(SVC|SERVICE|APP|ETL|BATCH|MONITOR|BACKUP)')
  )
  AND TO_NUMBER(TO_CHAR(SYS_EXTRACT_UTC(SYSTIMESTAMP),'HH24')) NOT BETWEEN 6 AND 20$q$::text))
WHERE vendor_slug='oracle' AND name='Check V$SESSION for human accounts outside business hours';

-- 6) AUD-008-RC04 step 2: two statements + '-- second query:' comment jammed
--    together; keep the single wallet-status statement.
UPDATE rootcause.detection_steps
SET content = jsonb_set(content, '{sql}', to_jsonb($q$SELECT * FROM V$ENCRYPTION_WALLET$q$::text))
WHERE vendor_slug='oracle' AND name='Check TDE wallet status and encryption key objects';

-- 7) AUD-009-RC01 step 2: DBA_AUDIT_TRAIL column is RETURNCODE (no underscore).
UPDATE rootcause.detection_steps
SET content = jsonb_set(content, '{sql}', to_jsonb($q$SELECT DB_USER, SQL_TEXT, TIMESTAMP, RETURNCODE
FROM DBA_AUDIT_TRAIL
WHERE (UPPER(SQL_TEXT) LIKE '%OR 1=1%' OR UPPER(SQL_TEXT) LIKE '%OR TRUE%')
  AND TIMESTAMP > SYSDATE - 1$q$::text))
WHERE vendor_slug='oracle' AND name='Check DBA_AUDIT_TRAIL for same patterns';

-- 8) AUD-015-RC01 step 2: strip inline '-- no client_ip column' comment.
UPDATE rootcause.detection_steps
SET content = jsonb_set(content, '{sql}', to_jsonb($q$SELECT
    CAST(event_timestamp AT TIME ZONE 'Asia/Jerusalem' AS TIMESTAMP) AS event_time,
    dbusername                                     AS login_name,
    SYS_CONTEXT('USERENV','DB_NAME')               AS database_name,
    object_schema                                  AS schema_name,
    object_name                                    AS object_name,
    SUBSTR(action_name, 1, 2)                      AS action_id,
    action_name                                    AS action,
    CASE WHEN action_name IN ('INSERT','UPDATE','DELETE','TRUNCATE TABLE') THEN 'DML'
         WHEN action_name LIKE 'CREATE%'
           OR action_name LIKE 'ALTER%'
           OR action_name LIKE 'DROP%'             THEN 'SCHEMA'
         ELSE 'OTHER' END                          AS change_kind,
    client_program_name                            AS client_ip,
    client_program_name                            AS application_name,
    sql_text                                       AS statement
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '1' DAY
  AND (action_name IN ('INSERT','UPDATE','DELETE','TRUNCATE TABLE')
       OR action_name LIKE 'CREATE%'
       OR action_name LIKE 'ALTER%'
       OR action_name LIKE 'DROP%')
ORDER BY event_timestamp DESC
FETCH FIRST 5000 ROWS ONLY$q$::text))
WHERE vendor_slug='oracle' AND name='Read schema and DML events from Oracle unified_audit_trail (last 24h)';

-- 9) PRI-005-RC02: dba_audit_object_opts is not a view; correct view is
--    dba_obj_audit_opts (owner/object_name/alt). Also de-dupe table list.
UPDATE rootcause.detection_steps
SET content = jsonb_set(content, '{sql}', to_jsonb($q$SELECT DISTINCT c.owner, c.table_name
FROM all_tab_columns c
WHERE c.owner NOT IN ('SYS','SYSTEM','DBSNMP')
  AND (LOWER(c.column_name) LIKE '%password%'
       OR LOWER(c.column_name) LIKE '%ssn%'
       OR LOWER(c.column_name) LIKE '%credit_card%'
       OR LOWER(c.column_name) LIKE '%email%')
  AND NOT EXISTS (
      SELECT 1 FROM dba_obj_audit_opts a
      WHERE a.object_name = c.table_name
        AND a.owner = c.owner
        AND a.alt = 'A/A'
  )$q$::text))
WHERE vendor_slug='oracle' AND name='PRI-005-RC02 SELECT on PII not audited (oracle)';

-- VERIFY: none of the fixed oracle steps still carry the bad patterns
SELECT name,
       CASE
         WHEN content->>'sql' ~ '--'                              THEN 'STILL-COMMENT'
         WHEN content->>'sql' ~* 'like\s+any\s*\(\s*array'        THEN 'STILL-LIKE-ANY-ARRAY'
         WHEN content->>'sql' ~* 'regexp_like\s+[a-z_"]'          THEN 'STILL-INFIX-REGEXP'
         WHEN content->>'sql' ~* 'return_code'                    THEN 'STILL-RETURN_CODE'
         WHEN content->>'sql' ~* 'dba_audit_object_opts'          THEN 'STILL-BAD-VIEW'
         WHEN content->>'sql' ~* 'proxy_name'                     THEN 'STILL-PROXY_NAME'
         ELSE 'fixed'
       END AS state
FROM rootcause.detection_steps
WHERE vendor_slug='oracle' AND name IN (
  'ora-check-audit-exclusions-configured',
  'Check V$SESSION for DML by DBA-role accounts',
  'Check V$SESSION for service accounts with interactive program names',
  'Verify account has application-only role assignments',
  'Check V$SESSION for human accounts outside business hours',
  'Check TDE wallet status and encryption key objects',
  'Check DBA_AUDIT_TRAIL for same patterns',
  'Read schema and DML events from Oracle unified_audit_trail (last 24h)',
  'PRI-005-RC02 SELECT on PII not audited (oracle)')
ORDER BY name;
