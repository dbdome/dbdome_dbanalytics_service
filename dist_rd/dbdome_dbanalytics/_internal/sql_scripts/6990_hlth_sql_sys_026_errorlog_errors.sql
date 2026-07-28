-- ============================================================
-- 6990  HLTH-SQL-SYS-026-RC01  Errorlog errors in the last 24h captured (sqlserver)
--   HEALTH system series root cause.
--   Completed from the base xp_readerrorlog fragment (it arrived as a
--   dynamic-SQL snippet with @LASTDAY):
--     * fixed rolling last-24h window via the start-date parameter
--     * scans for both ''Error'' and ''Severity'' lines, DISTINCT-merged
--       (a severity 17+ event often carries only one of the two words)
--     * INSERT..EXEC into #temp so the final SELECT is the first rowset
--       (collector does a bare fetchall); CHECKDB clean-report noise excluded
--   2005+. Requires sysadmin/securityadmin for xp_readerrorlog.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-026','HLTH','SQL','SYS','Errorlog Error Scan','errorlog-errors',
        'Error and severity lines from the SQL Server errorlog over the last 24 hours.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-026-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-026-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-026-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-026-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-026-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-026-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-026-RC01', 'HLTH-SQL-SYS-026', 'Errorlog errors in the last 24h captured',
    'errorlog-errors-rc01',
    'Lines from the current errorlog (last 24 hours) matching Error or Severity: timestamp, source process (spid/server) and the message text. Catches what only lands in the errorlog: stack dumps, severity 17+ errors, IO-subsystem warnings, memory pressure messages, failed logins if auditing writes there. Zero rows = clean log. Excludes CHECKDB "found 0 errors" noise.',
    ARRAY['health', 'errorlog', 'errors', 'diagnostics'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-026-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nIF OBJECT_ID(''tempdb..#el'') IS NOT NULL DROP TABLE #el;\nCREATE TABLE #el (log_date datetime, process_info nvarchar(100), log_text nvarchar(max));\nDECLARE @from datetime;\nSET @from = DATEADD(HOUR, -24, GETDATE());\nBEGIN TRY\n    INSERT #el EXEC master.sys.xp_readerrorlog 0, 1, N''Error'', NULL, @from, NULL, N''desc'';\nEND TRY BEGIN CATCH END CATCH;\nBEGIN TRY\n    INSERT #el EXEC master.sys.xp_readerrorlog 0, 1, N''Severity'', NULL, @from, NULL, N''desc'';\nEND TRY BEGIN CATCH END CATCH;\nSELECT DISTINCT TOP 200\n    CONVERT(varchar(19), log_date, 120) AS log_date,\n    process_info,\n    LEFT(log_text, 4000) AS log_text\nFROM #el\nWHERE log_text NOT LIKE ''%found 0 errors%'' AND log_text NOT LIKE ''%without errors%''\nORDER BY 1 DESC"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Errorlog error lines found (zero rows = clean errorlog window)"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET
    content = EXCLUDED.content, expected = EXCLUDED.expected;

DO $gen$
DECLARE
    v_step_id   bigint;
    v_path_id   bigint;
    v_res_step  bigint;
    v_res_path  bigint;
BEGIN
    SELECT id INTO v_step_id FROM rootcause.detection_steps
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-026-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-026-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-026-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-026-RC01 (sqlserver)', 'Errorlog errors in the last 24h captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-026-RC01 (sqlserver)', '{"action": "Severity 20+ lines are connection/instance-level failures - act immediately; repeated 823/824/825 messages mean storage corruption in progress (run CHECKDB, check HLTH-SQL-SYS-009 alert coverage for these errors); I/O-requests-taking-longer-than-15-seconds messages correlate with volume latency (HLTH-SQL-SYS-025); dumps (SQLDump*) warrant a support case with the dump files."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-026-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-026-RC01 (sqlserver)', 'resolve-hlth_sql_sys_026_rc01-sqlserver', 'Errorlog errors in the last 24h captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_026_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_026_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'log_date')                    AS log_date,
    (j.value ->> 'process_info')                AS process_info,
    (j.value ->> 'log_text')                    AS log_text,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-026-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_026_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_026_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-026-RC01';

COMMIT;
