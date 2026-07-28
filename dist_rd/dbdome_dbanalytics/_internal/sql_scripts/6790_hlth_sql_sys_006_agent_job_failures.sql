-- ============================================================
-- 6790  HLTH-SQL-SYS-006-RC01  Agent job failures (sqlserver)
--   Sixth HEALTH system root cause (series: 6740-6780).
--   Failed/canceled SQL Agent job runs in the last 24 hours.
--
--   Rebuilt from the base msdb sysjobhistory query:
--     * run_status <> 1 wrongly labeled Retry (2) and In-Progress (4) rows as
--       FAILED; now run_status IN (0,3) with the status decoded
--     * the run_date/run_time float arithmetic and string surgery replaced
--       with msdb.dbo.agent_datetime() (built-in since 2005)
--     * fixed "yesterday at 7am" window replaced with a rolling 24 hours
--       (cheap run_date prefilter + precise datetime filter)
--     * the step-level UNION job-outcome branch collapsed into one query
--       (LEFT JOIN sysjobsteps; step_id 0 shown as "(job outcome)")
--     * the dedupe kept only the EARLIEST failure per job; now the LATEST
--       failure per job+step is kept, with failure_rows_24h per job
--     * enriched: job enabled flag, run duration decoded to seconds
--       (HHMMSS format), retries_attempted, succeeded_since flag (did the
--       job complete successfully after this failure?)
--   Requires read on msdb job tables (SQLAgentReaderRole or sysadmin).
--   Zero rows = no job failures in the window (healthy / ruled_out).
--
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

-- 0) AREA + ISSUE -----------------------------------------------------------
INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-006','HLTH','SQL','SYS','Agent Job Failures','agent-job-failures',
        'Detect SQL Agent jobs that failed or were canceled in the last 24 hours, at step and job-outcome level, with recovery status. Complements the HLTH-SQL-SJ issue family.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

-- cleanup of any prior HLTH-SQL-SYS-006-RC01 artifacts (idempotent rebuild)
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-006-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-006-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-006-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-006-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-006-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-006-RC01 %';

-- 1) ROOT CAUSE -------------------------------------------------------------
INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-006-RC01', 'HLTH-SQL-SYS-006', 'Agent job failures in the last 24h captured',
    'agent-job-failures-24h',
    'Latest failed or canceled run per job/step in the last 24 hours: decoded status, run time, duration in seconds, retries, the failure message, whether the job is still enabled, how many failure rows the job produced in the window, and whether it has succeeded since (auto-recovered). Feeds job-reliability health checks and alerting.',
    ARRAY['health', 'agent', 'jobs', 'scheduling', 'failures'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

-- 2) DETECTION STEP (sqlserver) --------------------------------------------
INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-006-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nWITH H AS (\n    SELECT j.job_id, j.name AS job_name, j.enabled AS job_enabled, h.step_id,\n           ISNULL(s.step_name, CASE WHEN h.step_id = 0 THEN ''(job outcome)'' ELSE CONVERT(varchar(10), h.step_id) END) AS step_name,\n           msdb.dbo.agent_datetime(h.run_date, h.run_time) AS run_datetime,\n           h.run_status, h.run_duration, h.retries_attempted, h.message\n    FROM msdb.dbo.sysjobs j\n    JOIN msdb.dbo.sysjobhistory h ON h.job_id = j.job_id\n    LEFT JOIN msdb.dbo.sysjobsteps s ON s.job_id = j.job_id AND s.step_id = h.step_id\n    WHERE h.run_date >= CONVERT(int, CONVERT(varchar(8), DATEADD(HOUR, -25, GETDATE()), 112))\n      AND msdb.dbo.agent_datetime(h.run_date, h.run_time) >= DATEADD(HOUR, -24, GETDATE())\n), F AS (\n    SELECT *, ROW_NUMBER() OVER (PARTITION BY job_id, step_id ORDER BY run_datetime DESC) AS rn,\n           COUNT(*) OVER (PARTITION BY job_id) AS failure_rows_24h\n    FROM H WHERE run_status IN (0, 3)\n)\nSELECT TOP 200\n    f.job_name,\n    f.job_enabled,\n    CONVERT(varchar(10), f.step_id) AS step_id,\n    f.step_name,\n    CASE f.run_status WHEN 0 THEN ''FAILED'' WHEN 3 THEN ''CANCELED'' ELSE CONVERT(varchar(10), f.run_status) END AS status,\n    CONVERT(varchar(19), f.run_datetime, 120) AS run_datetime,\n    f.run_duration/10000*3600 + (f.run_duration%10000)/100*60 + f.run_duration%100 AS duration_sec,\n    f.retries_attempted,\n    CASE WHEN EXISTS (SELECT 1 FROM H h2 WHERE h2.job_id = f.job_id AND h2.step_id = 0 AND h2.run_status = 1 AND h2.run_datetime > f.run_datetime) THEN 1 ELSE 0 END AS succeeded_since,\n    f.failure_rows_24h,\n    LEFT(f.message, 4000) AS message\nFROM F f\nWHERE f.rn = 1\nORDER BY f.run_datetime DESC"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Agent job failures found in the last 24 hours (zero rows = all jobs healthy)"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET
    content = EXCLUDED.content, expected = EXCLUDED.expected;

-- 3) DETECTION PATH + RESOLUTION -------------------------------------------
DO $gen$
DECLARE
    v_step_id   bigint;
    v_path_id   bigint;
    v_res_step  bigint;
    v_res_path  bigint;
BEGIN
    SELECT id INTO v_step_id FROM rootcause.detection_steps
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-006-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-006-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-006-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-006-RC01 (sqlserver)', 'Agent job failures in the last 24h captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-006-RC01 (sqlserver)', '{"action": "Read the failing step message first (it names the real error); succeeded_since = 1 means the job auto-recovered - check for flakiness (retries_attempted rising) rather than firefighting; succeeded_since = 0 on an enabled job needs action now (rerun after fixing, or disable deliberately); repeated failure_rows_24h on backup/integrity jobs is a recovery-risk escalation (correlate HLTH-SQL-BR-001); verify the Agent service itself is running if history suddenly goes quiet."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-006-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-006-RC01 (sqlserver)', 'resolve-hlth_sql_sys_006_rc01-sqlserver', 'Triage failed Agent jobs: message, recovery status, flakiness and backup-job escalation.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

-- 4) MONITORING VIEW --------------------------------------------------------
CREATE OR REPLACE VIEW monitoring.v_hlth_sql_sys_006_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'job_name')                AS job_name,
    (j.value ->> 'job_enabled')::int        AS job_enabled,
    (j.value ->> 'step_id')                 AS step_id,
    (j.value ->> 'step_name')               AS step_name,
    (j.value ->> 'status')                  AS status,
    (j.value ->> 'run_datetime')            AS run_datetime,
    (j.value ->> 'duration_sec')::bigint    AS duration_sec,
    (j.value ->> 'retries_attempted')::int  AS retries_attempted,
    (j.value ->> 'succeeded_since')::int    AS succeeded_since,
    (j.value ->> 'failure_rows_24h')::int   AS failure_rows_24h,
    (j.value ->> 'message')                 AS message,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-006-RC01';

-- keep view/grants aligned with the 6690 hardening when the engine role exists
DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_006_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_006_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

-- 5) VERIFY ----------------------------------------------------------------
SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-006-RC01';

COMMIT;
