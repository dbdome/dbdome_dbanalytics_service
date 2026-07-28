-- ============================================================
-- 6460  Fix self-referential false positive in SEC-SQL-AUD-020-RC03 (sqlserver)
--
-- Sibling of 6440 (which fixed the same class of bug for oracle/v$session).
-- The two sqlserver detection steps flag "destructive DDL" by scanning for text
-- LIKE '%DROP%LOGIN/USER/ROLE%':
--   * live step  - sys.dm_exec_requests + dm_exec_sql_text (running sessions)
--   * audit step - sys.fn_get_audit_file (the SQL Server audit trail)
-- But DBDOME's OWN monitoring queries contain those very literals - e.g. this
-- RC03 detection query itself, the fn_get_audit_file audit scans, the default-
-- trace reader (which spells out 'DROP LOGIN'/'DROP ROLE' in a CASE), and the
-- #access privilege-inventory query (DROP TABLE #access ... database_user ...
-- sys.database_role_members). Those monitors run concurrently as the target's
-- own login (here 'sa', NOT a DBDOME% login, so the existing NOT LIKE '%dbdome%'
-- filter misses them) - so the detector captures itself and its siblings: a
-- permanent false alarm (alerts 8912568/69/70), which the self-activity agent
-- correctly flagged.
--
-- Fix (mirrors 6440): exclude DBDOME's own monitoring footprint - any statement
-- that references the DMVs / functions / temp-tables the collectors use. A real
-- attacker's DROP LOGIN/USER/ROLE DDL references none of these, so it is still
-- caught. The DROP pattern itself is left unchanged (no loss of sensitivity).
-- Targets by step name (portable across localhost + VM). Idempotent.
-- ============================================================
BEGIN;

-- 1) live step: sys.dm_exec_requests / dm_exec_sql_text
UPDATE rootcause.detection_steps
SET content = jsonb_build_object('sql', $aud020ss$SELECT TOP 500 CAST(GETDATE() AS DATETIME) AS event_time, s.login_name AS login_name,
       DB_NAME(r.database_id) AS database_name, CAST(NULL AS NVARCHAR(128)) AS object_name,
       CAST(qt.text AS NVARCHAR(MAX)) AS statement
FROM sys.dm_exec_requests AS r WITH (NOLOCK)
JOIN sys.dm_exec_sessions AS s WITH (NOLOCK) ON s.session_id = r.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS qt
WHERE s.session_id <> @@SPID AND ISNULL(s.login_name,'') NOT LIKE '%dbdome%'
  AND qt.text IS NOT NULL AND (qt.text LIKE '%DROP%LOGIN%' OR qt.text LIKE '%DROP%USER%' OR qt.text LIKE '%DROP%ROLE%')
  AND qt.text NOT LIKE '%dm_exec_%'
  AND qt.text NOT LIKE '%fn_get_audit_file%'
  AND qt.text NOT LIKE '%fn_trace_gettable%'
  AND qt.text NOT LIKE '%sys.traces%'
  AND qt.text NOT LIKE '%database_role_members%'
  AND qt.text NOT LIKE '%#access%'$aud020ss$)
WHERE vendor_slug = 'sqlserver'
  AND name = 'Detect SEC-SQL-AUD-020-RC03 (sqlserver)';

-- 2) audit-trail step: sys.fn_get_audit_file
UPDATE rootcause.detection_steps
SET content = jsonb_build_object('sql', $aud020ssa$SET NOCOUNT ON;
BEGIN TRY
  SELECT TOP 500 event_time, server_principal_name AS login_name, database_name, object_name, statement
  FROM sys.fn_get_audit_file(N'C:\Audit\dbdome_audit*.sqlaudit', DEFAULT, DEFAULT)
  WHERE event_time > DATEADD(DAY,-1, SYSUTCDATETIME())
    AND (statement LIKE '%DROP%LOGIN%' OR statement LIKE '%DROP%USER%' OR statement LIKE '%DROP%ROLE%')
    AND statement NOT LIKE '%dm_exec_%'
    AND statement NOT LIKE '%fn_get_audit_file%'
    AND statement NOT LIKE '%fn_trace_gettable%'
    AND statement NOT LIKE '%sys.traces%'
    AND statement NOT LIKE '%database_role_members%'
    AND statement NOT LIKE '%#access%'
  ORDER BY event_time DESC;
END TRY
BEGIN CATCH
  SELECT CAST(NULL AS DATETIME2) AS event_time, CAST(NULL AS SYSNAME) AS login_name,
         CAST(NULL AS SYSNAME) AS database_name, CAST(NULL AS SYSNAME) AS object_name,
         CAST(NULL AS NVARCHAR(MAX)) AS statement
  WHERE 1=0;
END CATCH$aud020ssa$)
WHERE vendor_slug = 'sqlserver'
  AND name = 'Detect SEC-SQL-AUD-020-RC03 (sqlserver) - audit trail (fn_get_audit_file)';

-- verify: both steps now carry the monitoring-footprint exclusions
SELECT id, name,
       (content->>'sql') LIKE '%dm\_exec\_%' ESCAPE '\' AS excl_dmexec,
       (content->>'sql') LIKE '%fn_get_audit_file%'     AS excl_audit,
       (content->>'sql') LIKE '%#access%'               AS excl_access
FROM rootcause.detection_steps
WHERE vendor_slug = 'sqlserver'
  AND name IN ('Detect SEC-SQL-AUD-020-RC03 (sqlserver)',
               'Detect SEC-SQL-AUD-020-RC03 (sqlserver) - audit trail (fn_get_audit_file)')
ORDER BY id;

COMMIT;
