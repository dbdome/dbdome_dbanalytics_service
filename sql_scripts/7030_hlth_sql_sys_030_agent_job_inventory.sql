-- ============================================================
-- 7030  HLTH-SQL-SYS-030-RC01  Agent job inventory captured (sqlserver)
--   HEALTH system series root cause.
--   Enriched from the base sysjobs inventory query:
--     * notify_email_operator_id resolved to the OPERATOR NAME and
--       notify_level_email decoded (Never/OnSuccess/OnFailure/Always)
--     * schedule name + next_run added (agent_datetime over
--       sysjobschedules.next_run_date/time, NULL when never scheduled)
--     * description capped at 1000 chars; NOLOCK/RECOMPILE dropped
--   2005+. Requires msdb read (SQLAgentReaderRole or sysadmin).
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-030','HLTH','SQL','SYS','Agent Job Inventory','agent-job-inventory',
        'Definition-level inventory of SQL Agent jobs: owner, category, enabled state, failure notification wiring and schedules.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-030-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-030-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-030-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-030-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-030-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-030-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-030-RC01', 'HLTH-SQL-SYS-030', 'Agent job inventory captured',
    'agent-job-inventory-rc01',
    'Every Agent job with its description, OWNER (resolved from the sid), creation date, enabled flag, category, the notification operator and when email fires (decoded), and each attached schedule with its enabled state and next run time. One row per job-schedule pair; schedule columns NULL for unscheduled jobs. Completes the Agent trio: SYS-006 failures, SYS-029 run history, SYS-030 definitions.',
    ARRAY['health', 'agent', 'jobs', 'inventory', 'configuration'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-030-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nSELECT TOP 500\n    j.name AS job_name,\n    LEFT(j.description, 1000) AS job_description,\n    SUSER_SNAME(j.owner_sid) AS job_owner,\n    CONVERT(varchar(19), j.date_created, 120) AS date_created,\n    j.enabled AS job_enabled,\n    c.name AS category_name,\n    o.name AS notify_operator,\n    CASE j.notify_level_email WHEN 0 THEN ''Never'' WHEN 1 THEN ''OnSuccess'' WHEN 2 THEN ''OnFailure'' WHEN 3 THEN ''Always'' ELSE CONVERT(varchar(10), j.notify_level_email) END AS notify_email_when,\n    s.name AS schedule_name,\n    s.enabled AS schedule_enabled,\n    CASE WHEN js.next_run_date > 0 THEN CONVERT(varchar(19), msdb.dbo.agent_datetime(js.next_run_date, js.next_run_time), 120) END AS next_run\nFROM msdb.dbo.sysjobs j\nJOIN msdb.dbo.syscategories c ON c.category_id = j.category_id\nLEFT JOIN msdb.dbo.sysoperators o ON o.id = j.notify_email_operator_id\nLEFT JOIN msdb.dbo.sysjobschedules js ON js.job_id = j.job_id\nLEFT JOIN msdb.dbo.sysschedules s ON s.schedule_id = js.schedule_id\nORDER BY j.name"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Agent jobs defined (zero rows = no jobs on this instance)"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-030-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-030-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-030-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-030-RC01 (sqlserver)', 'Agent job inventory captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-030-RC01 (sqlserver)', '{"action": "job_owner resolving to NULL means the owning login was dropped - the job runs under a dead identity and will fail on ownership checks (re-own to sa or a service account); an enabled job with notify_email_when = Never and no operator fails silently (wire OnFailure at minimum, cross-check HLTH-SQL-SYS-009); job_enabled = 1 with schedule_enabled = 0 (or no schedule) means it only runs manually - verify that is intended; next_run far in the past means the Agent is not picking the schedule up."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-030-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-030-RC01 (sqlserver)', 'resolve-hlth_sql_sys_030_rc01-sqlserver', 'Agent job inventory captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_030_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_030_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'job_name')                    AS job_name,
    (j.value ->> 'job_description')             AS job_description,
    (j.value ->> 'job_owner')                   AS job_owner,
    (j.value ->> 'date_created')                AS date_created,
    (j.value ->> 'job_enabled')::int            AS job_enabled,
    (j.value ->> 'category_name')               AS category_name,
    (j.value ->> 'notify_operator')             AS notify_operator,
    (j.value ->> 'notify_email_when')           AS notify_email_when,
    (j.value ->> 'schedule_name')               AS schedule_name,
    (j.value ->> 'schedule_enabled')::int       AS schedule_enabled,
    (j.value ->> 'next_run')                    AS next_run,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-030-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_030_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_030_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-030-RC01';

COMMIT;
