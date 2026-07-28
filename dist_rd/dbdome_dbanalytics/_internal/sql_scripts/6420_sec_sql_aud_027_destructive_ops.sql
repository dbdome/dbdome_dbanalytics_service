-- ============================================================
-- 6420  SEC-SQL-AUD-027-RC01  Destructive operation attempts
--   Detects destructive commands across ALL databases of the instance -
--   DROP TABLE / DROP DATABASE / DROP SCHEMA / DROP LOGIN / DROP USER /
--   DROP ROLE / TRUNCATE / BACKUP+RESTORE DATABASE - INCLUDING FAILED
--   attempts where the platform records them:
--     sqlserver : default trace (always on) - Object:Deleted, security-audit
--                 drop events (Success=0 -> failed attempt), BACKUP/RESTORE.
--                 tempdb excluded. TRUNCATE is not in the default trace.
--     oracle    : UNIFIED_AUDIT_TRAIL (DROP%/TRUNCATE%/PURGE%, return_code<>0
--                 -> failed) UNION dba_recyclebin (audit-config-free evidence
--                 of dropped tables). Needs AUDIT_VIEWER or SELECT ANY
--                 DICTIONARY; default ORA_SECURECONFIG policy covers
--                 DROP USER/ROLE; add a policy for DROP TABLE coverage.
--     mysql/mariadb : performance_schema statement digests (on by default in
--                 MySQL 5.7+); SUM_ERRORS>0 marks failed attempts. On MariaDB
--                 enable performance_schema for coverage.
--     postgresql: pg_stat_statements (extension required; successful
--                 statements only - PG does not retain failed statements).
--   24h window on event sources (digest tables report last-seen in window).
--   Verify: run DROP TABLE t_x / BACKUP DATABASE x TO DISK=... (or a denied
--   drop from an unprivileged login) and re-collect.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

-- 0) ISSUE + cleanup (idempotent rebuild) ------------------------------
INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('SEC-SQL-AUD-027','SEC','SQL','AUD','Destructive operation monitoring','destructive-operation-monitoring','Detect destructive command attempts (DROP TABLE/DATABASE/SCHEMA/LOGIN/USER/ROLE, TRUNCATE, BACKUP/RESTORE DATABASE) across all databases, including failed attempts where recorded.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description;
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='SEC-SQL-AUD-027-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='SEC-SQL-AUD-027-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect SEC-SQL-AUD-027-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='SEC-SQL-AUD-027-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='SEC-SQL-AUD-027-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect SEC-SQL-AUD-027-RC01 %';

-- 1) ROOT CAUSES -----------------------------------------------------------
INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'SEC-SQL-AUD-027-RC01', 'SEC-SQL-AUD-027', 'Destructive operation attempted - DROP/TRUNCATE/BACKUP command detected (including failed attempts)',
    'destructive-operation-attempt', 'Detects destructive command activity across ALL databases of the monitored instance: DROP TABLE, DROP DATABASE/SCHEMA, DROP LOGIN, DROP USER, DROP ROLE, TRUNCATE and BACKUP/RESTORE DATABASE (a backup taken by an attacker is data exfiltration). Failed attempts are included where the platform records them: SQL Server default-trace security-audit events carry Success=0 for denied drops of logins/users/roles; Oracle UNIFIED_AUDIT_TRAIL rows with return_code<>0 are failed attempts; MySQL/MariaDB performance_schema digests report SUM_ERRORS>0. Sources: SQL Server default trace (always on; tempdb excluded; TRUNCATE not captured), Oracle unified audit + recyclebin (recyclebin needs no audit config), MySQL/MariaDB statement digest summaries, PostgreSQL pg_stat_statements (extension required; successful statements only). An unexpected destructive command - especially a failed one - is a strong indicator of an attack in progress or an operator error about to become an outage; treat repeated failed attempts from one login as active hostile probing.',
    ARRAY['audit', 'destructive-operations', 'drop-table', 'drop-database', 'backup-exfiltration', 'ransomware', 'insider-threat', 'security'], ARRAY['sqlserver', 'oracle', 'postgresql', 'mysql', 'mariadb']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

-- 2) DETECTION STEPS (per vendor) ------------------------------------------
INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect SEC-SQL-AUD-027-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nDECLARE @tracefile nvarchar(260);\nSELECT @tracefile = SUBSTRING(path, 1, LEN(path) - CHARINDEX(''\\'', REVERSE(path))) + ''\\log.trc''\nFROM sys.traces WHERE is_default = 1;\nIF @tracefile IS NULL\nBEGIN\n    SELECT CONVERT(varchar(19), GETDATE(), 120) AS event_time, CAST(NULL AS nvarchar(128)) AS login_name,\n           CAST(@@SERVERNAME AS nvarchar(128)) AS host_name, CAST(NULL AS nvarchar(128)) AS os_user,\n           ''DEFAULT TRACE DISABLED'' AS auth_info,\n           ''The default trace is disabled - destructive operations cannot be audited; re-enable it (sp_configure default trace enabled, 1)'' AS statement;\n    RETURN;\nEND\nSELECT TOP 500\n    CONVERT(varchar(19), t.StartTime, 120) AS event_time,\n    t.LoginName AS login_name,\n    ISNULL(t.HostName, CAST(@@SERVERNAME AS nvarchar(128))) AS host_name,\n    t.NTUserName AS os_user,\n    CASE t.EventClass\n        WHEN 47  THEN ''DROP OBJECT''\n        WHEN 115 THEN CASE t.EventSubClass WHEN 1 THEN ''BACKUP DATABASE'' WHEN 2 THEN ''RESTORE DATABASE'' ELSE ''BACKUP/RESTORE'' END\n        WHEN 104 THEN CASE t.EventSubClass WHEN 2 THEN ''DROP LOGIN'' ELSE ''LOGIN MGMT'' END\n        WHEN 109 THEN CASE t.EventSubClass WHEN 2 THEN ''DROP DATABASE USER'' ELSE ''DB USER MGMT'' END\n        WHEN 111 THEN CASE t.EventSubClass WHEN 2 THEN ''DROP ROLE'' ELSE ''ROLE MGMT'' END\n        WHEN 108 THEN ''SERVER ROLE MEMBERSHIP CHANGE''\n        WHEN 110 THEN ''DB ROLE MEMBERSHIP CHANGE''\n        ELSE ''DESTRUCTIVE EVENT''\n    END + CASE WHEN t.Success = 0 THEN '' (FAILED ATTEMPT)'' ELSE '''' END AS auth_info,\n    ISNULL(t.DatabaseName, '''') + CASE WHEN t.ObjectName IS NOT NULL THEN ''.'' + t.ObjectName ELSE '''' END\n        + '' via '' + ISNULL(t.ApplicationName, ''unknown app'') AS statement\nFROM sys.fn_trace_gettable(@tracefile, DEFAULT) t\nWHERE t.EventClass IN (47, 104, 108, 109, 110, 111, 115)\n  AND t.StartTime >= DATEADD(day, -1, GETDATE())\n  AND ISNULL(t.DatabaseName, '''') <> ''tempdb''\nORDER BY t.StartTime DESC;"}'::jsonb,
        '{"condition": "row_count > 0", "description": "A destructive command (DROP/BACKUP/RESTORE, incl. failed attempts) was executed or attempted in the last 24 hours"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET
    content = EXCLUDED.content, expected = EXCLUDED.expected;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('oracle', 'query', 'Detect SEC-SQL-AUD-027-RC01 (oracle)',
        '{"sql": "SELECT * FROM (\n  SELECT TO_CHAR(event_timestamp, ''YYYY-MM-DD HH24:MI:SS'') AS event_time,\n         dbusername AS login_name,\n         SYS_CONTEXT(''USERENV'',''DB_NAME'') AS host_name,\n         os_username AS os_user,\n         action_name || CASE WHEN return_code <> 0 THEN '' (FAILED ORA-'' || return_code || '')'' ELSE '''' END AS auth_info,\n         NVL(object_schema || ''.'' || object_name, ''-'') || '' :: '' || NVL(SUBSTR(sql_text, 1, 200), ''-'') AS statement\n  FROM unified_audit_trail\n  WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL ''1'' DAY\n    AND (action_name LIKE ''DROP%'' OR action_name LIKE ''TRUNCATE%'' OR action_name LIKE ''PURGE%'')\n  UNION ALL\n  SELECT SUBSTR(droptime, 1, 10) || '' '' || SUBSTR(droptime, 12, 8),\n         owner,\n         SYS_CONTEXT(''USERENV'',''DB_NAME''),\n         CAST(NULL AS VARCHAR2(30)),\n         ''DROP '' || type || '' (recyclebin)'',\n         ''Dropped object '' || owner || ''.'' || original_name\n  FROM dba_recyclebin\n  WHERE TO_DATE(droptime, ''YYYY-MM-DD:HH24:MI:SS'') >= SYSDATE - 1\n) t\nORDER BY event_time DESC\nFETCH FIRST 500 ROWS ONLY"}'::jsonb,
        '{"condition": "row_count > 0", "description": "A destructive command (DROP/TRUNCATE/PURGE, incl. failed attempts) was executed or attempted in the last 24 hours"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET
    content = EXCLUDED.content, expected = EXCLUDED.expected;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('mysql', 'query', 'Detect SEC-SQL-AUD-027-RC01 (mysql)',
        '{"sql": "SELECT DATE_FORMAT(d.LAST_SEEN, ''%Y-%m-%d %H:%i:%s'') AS event_time,\n       ''digest-summary'' AS login_name,\n       @@hostname AS host_name,\n       CAST(NULL AS CHAR) AS os_user,\n       CONCAT(''DESTRUCTIVE STATEMENT x'', d.COUNT_STAR,\n              IF(d.SUM_ERRORS > 0, CONCAT('' ('', d.SUM_ERRORS, '' FAILED)''), '''')) AS auth_info,\n       CONCAT(IFNULL(d.SCHEMA_NAME, ''*''), '': '', LEFT(d.DIGEST_TEXT, 200)) AS statement\nFROM performance_schema.events_statements_summary_by_digest d\nWHERE d.LAST_SEEN >= NOW() - INTERVAL 1 DAY\n  AND (UPPER(d.DIGEST_TEXT) LIKE ''DROP TABLE%'' OR UPPER(d.DIGEST_TEXT) LIKE ''DROP DATABASE%''\n    OR UPPER(d.DIGEST_TEXT) LIKE ''DROP SCHEMA%'' OR UPPER(d.DIGEST_TEXT) LIKE ''DROP USER%''\n    OR UPPER(d.DIGEST_TEXT) LIKE ''DROP ROLE%'' OR UPPER(d.DIGEST_TEXT) LIKE ''TRUNCATE%'')\nORDER BY d.LAST_SEEN DESC\nLIMIT 500"}'::jsonb,
        '{"condition": "row_count > 0", "description": "A destructive command (DROP/TRUNCATE, incl. failed attempts) was executed or attempted in the last 24 hours"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET
    content = EXCLUDED.content, expected = EXCLUDED.expected;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('mariadb', 'query', 'Detect SEC-SQL-AUD-027-RC01 (mariadb)',
        '{"sql": "SELECT DATE_FORMAT(d.LAST_SEEN, ''%Y-%m-%d %H:%i:%s'') AS event_time,\n       ''digest-summary'' AS login_name,\n       @@hostname AS host_name,\n       CAST(NULL AS CHAR) AS os_user,\n       CONCAT(''DESTRUCTIVE STATEMENT x'', d.COUNT_STAR,\n              IF(d.SUM_ERRORS > 0, CONCAT('' ('', d.SUM_ERRORS, '' FAILED)''), '''')) AS auth_info,\n       CONCAT(IFNULL(d.SCHEMA_NAME, ''*''), '': '', LEFT(d.DIGEST_TEXT, 200)) AS statement\nFROM performance_schema.events_statements_summary_by_digest d\nWHERE d.LAST_SEEN >= NOW() - INTERVAL 1 DAY\n  AND (UPPER(d.DIGEST_TEXT) LIKE ''DROP TABLE%'' OR UPPER(d.DIGEST_TEXT) LIKE ''DROP DATABASE%''\n    OR UPPER(d.DIGEST_TEXT) LIKE ''DROP SCHEMA%'' OR UPPER(d.DIGEST_TEXT) LIKE ''DROP USER%''\n    OR UPPER(d.DIGEST_TEXT) LIKE ''DROP ROLE%'' OR UPPER(d.DIGEST_TEXT) LIKE ''TRUNCATE%'')\nORDER BY d.LAST_SEEN DESC\nLIMIT 500"}'::jsonb,
        '{"condition": "row_count > 0", "description": "A destructive command (DROP/TRUNCATE, incl. failed attempts) was executed or attempted in the last 24 hours"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET
    content = EXCLUDED.content, expected = EXCLUDED.expected;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('postgresql', 'query', 'Detect SEC-SQL-AUD-027-RC01 (postgresql)',
        '{"sql": "SELECT to_char(now(), ''YYYY-MM-DD HH24:MI:SS'') AS event_time,\n       r.rolname AS login_name,\n       current_database() AS host_name,\n       NULL::text AS os_user,\n       ''DESTRUCTIVE STATEMENT x'' || s.calls || '' (cumulative since stats reset)'' AS auth_info,\n       left(s.query, 200) AS statement\nFROM pg_stat_statements s\nJOIN pg_roles r ON r.oid = s.userid\nWHERE upper(ltrim(s.query)) LIKE ''DROP TABLE%'' OR upper(ltrim(s.query)) LIKE ''DROP DATABASE%''\n   OR upper(ltrim(s.query)) LIKE ''DROP SCHEMA%'' OR upper(ltrim(s.query)) LIKE ''DROP ROLE%''\n   OR upper(ltrim(s.query)) LIKE ''DROP USER%'' OR upper(ltrim(s.query)) LIKE ''TRUNCATE%''\nORDER BY s.calls DESC\nLIMIT 500"}'::jsonb,
        '{"condition": "row_count > 0", "description": "A destructive command (DROP/TRUNCATE) was executed (pg_stat_statements; successful statements only)"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET
    content = EXCLUDED.content, expected = EXCLUDED.expected;

-- 3) DETECTION PATHS + RESOLUTION (per root cause x vendor) ----------------
DO $gen$
DECLARE
    v_vendor    text;
    v_step_id   bigint;
    v_path_id   bigint;
    v_res_step  bigint;
    v_res_path  bigint;
    v_action    text := 'For each detected destructive operation confirm it was authorised (change ticket / scheduled maintenance / known backup job). If NOT: treat it as an incident - identify the login, host and application that issued it, disable or lock the account pending investigation, and assess impact (what was dropped/truncated/backed up). A FAILED attempt means the account tried and was denied - repeated failures from one login are active hostile probing; review that account''s other activity immediately. For unauthorised BACKUP/RESTORE treat the backup file as exfiltrated data (locate and secure it). Recover dropped objects from backups or the Oracle recyclebin (FLASHBACK TABLE ... TO BEFORE DROP). To improve coverage: keep the SQL Server default trace enabled, add an Oracle audit policy for DROP TABLE/TRUNCATE, enable performance_schema on MariaDB, and install pg_stat_statements on PostgreSQL.';
BEGIN
    FOREACH v_vendor IN ARRAY ARRAY['sqlserver','oracle','postgresql','mysql','mariadb'] LOOP
        SELECT id INTO v_step_id FROM rootcause.detection_steps
         WHERE vendor_slug = v_vendor AND name = 'Detect SEC-SQL-AUD-027-RC01 (' || v_vendor || ')'
         ORDER BY id DESC LIMIT 1;
        IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
           WHERE root_cause_id = 'SEC-SQL-AUD-027-RC01' AND vendor_slug = v_vendor) THEN
            INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
            VALUES ('SEC-SQL-AUD-027-RC01', v_vendor, 'Detect SEC-SQL-AUD-027-RC01 (' || v_vendor || ')',
                    'Destructive operation attempted - DROP/TRUNCATE/BACKUP command detected (including failed attempts)',
                    'diagnostic', true) RETURNING id INTO v_path_id;
            INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
            VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
            INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
            VALUES (v_vendor, 'recommendation', 'Resolve: Detect SEC-SQL-AUD-027-RC01 (' || v_vendor || ')',
                    jsonb_build_object('action', v_action), 'high', false, true) RETURNING id INTO v_res_step;
            INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
            VALUES ('SEC-SQL-AUD-027-RC01', v_vendor, 'Resolve: Detect SEC-SQL-AUD-027-RC01 (' || v_vendor || ')',
                    'resolve-sec_sql_aud_027_rc01-' || v_vendor, v_action, 'supervised', 'high', true) RETURNING id INTO v_res_path;
            INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order)
            VALUES (v_res_path, v_res_step, 1);
        END IF;
    END LOOP;
END
$gen$;

-- 4) MONITORING VIEW ---------------------------------------------------------
CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_027_rc01 AS
SELECT r.server,
    (j.value ->> 'event_time') AS event_time,
    (j.value ->> 'login_name') AS login_name,
    (j.value ->> 'host_name') AS host_name,
    (j.value ->> 'os_user') AS os_user,
    (j.value ->> 'auth_info') AS auth_info,
    (j.value ->> 'statement') AS statement,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'SEC-SQL-AUD-027-RC01';

-- 5) VERIFY ----------------------------------------------------------------
SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id IN ('SEC-SQL-AUD-027-RC01');

COMMIT;
