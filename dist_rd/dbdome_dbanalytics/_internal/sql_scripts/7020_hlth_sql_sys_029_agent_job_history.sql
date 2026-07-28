-- ============================================================
-- 7020  HLTH-SQL-SYS-029-RC01  Agent job runs in the last 48h captured (sqlserver)
--   HEALTH system series root cause.
--   Rebuilt from the base sysjobs/sysjobhistory/sysjobsteps query:
--     * THE BUG: sysjobsteps joined on job_id ONLY - every history row
--       multiplied by every step of the job, masked by GROUP BY; now
--       LEFT JOIN on job_id AND step_id (outcome rows keep step_id 0)
--     * run_status decoded (all five states), run_duration HHMMSS decoded
--       to seconds, retries added, window via cheap run_date int compare
--   2005+. Requires msdb read (SQLAgentReaderRole or sysadmin).
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-029','HLTH','SQL','SYS','Agent Job Run History','agent-job-run-history',
        'Complete SQL Agent run history for the last 48 hours: every step of every run with status, duration and the command executed.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-029-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-029-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-029-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-029-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-029-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-029-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-029-RC01', 'HLTH-SQL-SYS-029', 'Agent job runs in the last 48h captured',
    'agent-job-run-history-rc01',
    'Every job/step execution from the last two days: job and step name, the step command text, run time, decoded status (all five states, not just failures), duration in seconds, retries and the outcome message. The full-timeline complement to HLTH-SQL-SYS-006 (failures only) - gives duration trends and schedule adherence for healthy jobs too.',
    ARRAY['health', 'agent', 'jobs', 'history', 'scheduling'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-029-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nSELECT TOP 500\n    j.name AS job_name,\n    j.enabled AS job_enabled,\n    CONVERT(varchar(10), h.step_id) AS step_id,\n    ISNULL(s.step_name, CASE WHEN h.step_id = 0 THEN ''(job outcome)'' ELSE CONVERT(varchar(10), h.step_id) END) AS step_name,\n    LEFT(s.command, 4000) AS step_command,\n    CONVERT(varchar(19), msdb.dbo.agent_datetime(h.run_date, h.run_time), 120) AS run_datetime,\n    CASE h.run_status WHEN 0 THEN ''FAILED'' WHEN 1 THEN ''SUCCEEDED'' WHEN 2 THEN ''RETRY'' WHEN 3 THEN ''CANCELED'' WHEN 4 THEN ''IN PROGRESS'' ELSE CONVERT(varchar(10), h.run_status) END AS status,\n    h.run_duration/10000*3600 + (h.run_duration%10000)/100*60 + h.run_duration%100 AS duration_sec,\n    h.retries_attempted,\n    LEFT(h.message, 1000) AS message\nFROM msdb.dbo.sysjobs j\nJOIN msdb.dbo.sysjobhistory h ON h.job_id = j.job_id\nLEFT JOIN msdb.dbo.sysjobsteps s ON s.job_id = j.job_id AND s.step_id = h.step_id\nWHERE h.run_date >= CONVERT(int, CONVERT(varchar(8), DATEADD(DAY, -2, GETDATE()), 112))\nORDER BY msdb.dbo.agent_datetime(h.run_date, h.run_time) DESC"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Agent job runs found in the last 48 hours (zero rows = nothing ran)"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-029-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-029-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-029-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-029-RC01 (sqlserver)', 'Agent job runs in the last 48h captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-029-RC01 (sqlserver)', '{"action": "Duration creep on a SUCCEEDED job is the early warning failures never give you - trend duration_sec per job/step; RETRY statuses that eventually succeed indicate flaky dependencies worth fixing before they harden into failures; gaps in the timeline for a scheduled job mean missed runs (Agent down or schedule disabled - cross-check HLTH-SQL-SYS-030); zero rows with jobs defined means nothing is running at all."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-029-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-029-RC01 (sqlserver)', 'resolve-hlth_sql_sys_029_rc01-sqlserver', 'Agent job runs in the last 48h captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_029_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_029_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'job_name')                    AS job_name,
    (j.value ->> 'job_enabled')::int            AS job_enabled,
    (j.value ->> 'step_id')                     AS step_id,
    (j.value ->> 'step_name')                   AS step_name,
    (j.value ->> 'step_command')                AS step_command,
    (j.value ->> 'run_datetime')                AS run_datetime,
    (j.value ->> 'status')                      AS status,
    (j.value ->> 'duration_sec')::bigint        AS duration_sec,
    (j.value ->> 'retries_attempted')::int      AS retries_attempted,
    (j.value ->> 'message')                     AS message,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-029-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_029_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_029_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-029-RC01';

COMMIT;
