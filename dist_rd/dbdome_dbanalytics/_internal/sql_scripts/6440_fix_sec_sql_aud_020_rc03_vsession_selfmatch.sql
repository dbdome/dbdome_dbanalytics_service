-- ============================================================
-- 6440  Fix self-referential false positive in SEC-SQL-AUD-020-RC03 (oracle)
--
-- The "live activity (v$session)" detection step scans v$sql for any session
-- whose sql_text contains 'DROP USER' / 'DROP ROLE'. But the query's OWN text
-- contains those literals (in its LIKE predicates), and v$sql is Oracle's shared
-- SQL cache - so every time DBDOME runs the check (as dbdome_mon_usr, a USER
-- session NOT in the exclusion list), the query matches ITSELF: the captured
-- finding is login_name = dbdome_mon_usr, statement = this very query. A
-- permanent false alarm (the monitor seeing its own reflection), which the
-- self-activity agent correctly flagged.
--
-- Fix: exclude the detection's own footprint so it still catches a REAL
-- attacker's DROP USER/ROLE:
--   * s.sid <> our own detecting session
--   * s.username NOT LIKE 'DBDOME%'         (the monitoring account)
--   * sql_text NOT LIKE '%V$SQL%'/'%V$SESSION%'  (any meta-monitoring query)
--
-- Only the "live activity (v$session)" step is changed; the clean
-- unified_audit_trail step (which matches on action_name and never self-matches)
-- is left as-is. Targets by step name (portable). Idempotent.
-- ============================================================
BEGIN;

UPDATE rootcause.detection_steps
SET content = jsonb_build_object('sql', $aud020$SELECT
  TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD HH24:MI:SS') AS event_time,
  s.username AS login_name,
  SYS_CONTEXT('USERENV','DB_NAME') AS database_name,
  CAST(NULL AS VARCHAR2(128)) AS object_name,
  SUBSTR(sq.sql_text,1,4000) AS statement
FROM v$session s
JOIN v$sql sq ON sq.sql_id = s.sql_id
WHERE s.type = 'USER' AND s.username IS NOT NULL
  AND s.username NOT IN ('SYS','SYSTEM','DBSNMP','SYSMAN','XDB')
  AND s.username NOT LIKE 'DBDOME%'
  AND s.sid <> TO_NUMBER(SYS_CONTEXT('USERENV','SID'))
  AND UPPER(sq.sql_text) NOT LIKE '%V$SQL%'
  AND UPPER(sq.sql_text) NOT LIKE '%V$SESSION%'
  AND (UPPER(sq.sql_text) LIKE '%DROP USER%' OR UPPER(sq.sql_text) LIKE '%DROP ROLE%')$aud020$)
WHERE vendor_slug = 'oracle'
  AND name = 'Detect SEC-SQL-AUD-020-RC03 (oracle) - live activity (v$session)';

-- verify
SELECT id, name,
       (content->>'sql') ILIKE '%V$SQL%NOT LIKE%' OR (content->>'sql') ILIKE '%NOT LIKE ''%V$SQL%' AS has_meta_exclusion,
       (content->>'sql') ILIKE '%DBDOME%'   AS has_user_exclusion,
       (content->>'sql') ILIKE '%SYS_CONTEXT%SID%' AS has_sid_exclusion
FROM rootcause.detection_steps
WHERE vendor_slug = 'oracle'
  AND name = 'Detect SEC-SQL-AUD-020-RC03 (oracle) - live activity (v$session)';

COMMIT;
