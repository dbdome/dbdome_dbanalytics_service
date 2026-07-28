-- ============================================================
-- 6820  HLTH-SQL-SYS-009-RC01  Agent alert configuration (sqlserver)
--   Ninth HEALTH system root cause (series: 6740-6810).
--   Inventory of SQL Agent alerts (msdb.dbo.sysalerts).
--
--   Enriched from the base sysalerts query:
--     * alert_type decoded (SEVERITY / ERROR_NUMBER / PERFORMANCE; the
--       wmi_query column is absent on SQL Server on Linux, so WMI alerts
--       are not distinguished -- they are Windows-only anyway)
--     * last_occurrence_date + last_occurrence_time int pair combined into a
--       real timestamp via msdb.dbo.agent_datetime (NULL when never fired)
--     * notified_operators list (sysnotifications + sysoperators, with the
--       notification method) -- an enabled alert notifying NOBODY is a gap
--       the has_notification flag alone does not reveal
--     * response_job name (alerts can trigger a job), database scope,
--       performance_condition
--     * WITH (NOLOCK) / OPTION (RECOMPILE) dropped
--   Zero rows means NO Agent alerts are configured at all -- itself a
--   monitoring gap (see resolution: severity 17-25 + errors 823/824/825).
--   Requires read on msdb (SQLAgentReaderRole or sysadmin). 2005+.
--
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

-- 0) AREA + ISSUE -----------------------------------------------------------
INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-009','HLTH','SQL','SYS','Agent Alert Configuration','agent-alert-configuration',
        'Inventory SQL Agent alerts: what fires, on what condition, who gets notified and when each alert last fired. Surfaces disabled alerts, alerts notifying nobody, and instances with no alert coverage at all.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

-- cleanup of any prior HLTH-SQL-SYS-009-RC01 artifacts (idempotent rebuild)
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-009-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-009-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-009-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-009-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-009-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-009-RC01 %';

-- 1) ROOT CAUSE -------------------------------------------------------------
INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-009-RC01', 'HLTH-SQL-SYS-009', 'Agent alert inventory captured',
    'agent-alert-inventory',
    'Every SQL Agent alert with: decoded type (severity / error number / performance / WMI), condition, enabled state, database scope, the operators actually notified (and how), the response job if any, response delay, occurrence count and last fire time. Feeds alert-coverage and dead-alert health checks; zero rows means the instance has no Agent alert coverage at all.',
    ARRAY['health', 'agent', 'alerts', 'notifications', 'configuration'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

-- 2) DETECTION STEP (sqlserver) --------------------------------------------
INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-009-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nSELECT\n    a.name,\n    CASE WHEN a.performance_condition IS NOT NULL THEN ''PERFORMANCE''\n         WHEN a.severity > 0 THEN ''SEVERITY''\n         ELSE ''ERROR_NUMBER'' END AS alert_type,\n    a.event_source,\n    a.message_id,\n    a.severity,\n    a.enabled,\n    ISNULL(a.database_name, ''(all)'') AS database_scope,\n    a.performance_condition,\n    a.has_notification,\n    STUFF((SELECT '', '' + o.name + '' ('' +\n               CASE n.notification_method WHEN 1 THEN ''email'' WHEN 2 THEN ''pager'' WHEN 4 THEN ''netsend'' ELSE CONVERT(varchar(5), n.notification_method) END + '')''\n           FROM msdb.dbo.sysnotifications n\n           JOIN msdb.dbo.sysoperators o ON o.id = n.operator_id\n           WHERE n.alert_id = a.id\n           FOR XML PATH('''')), 1, 2, '''') AS notified_operators,\n    j.name AS response_job,\n    a.delay_between_responses,\n    a.occurrence_count,\n    CASE WHEN a.last_occurrence_date > 0\n         THEN CONVERT(varchar(19), msdb.dbo.agent_datetime(a.last_occurrence_date, a.last_occurrence_time), 120)\n         END AS last_occurrence\nFROM msdb.dbo.sysalerts a\nLEFT JOIN msdb.dbo.sysjobs j ON j.job_id = a.job_id\nORDER BY a.name"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Agent alerts configured (zero rows = no alert coverage on this instance)"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-009-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-009-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-009-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-009-RC01 (sqlserver)', 'Agent alert inventory captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-009-RC01 (sqlserver)', '{"action": "Audit for gaps: enabled = 0 on a severity alert, or notified_operators NULL while no response_job is set, means the alert fires into the void; best-practice coverage is severity 17-25 plus errors 823/824/825 (I/O corruption) -- zero rows on this check means none of it exists; occurrence_count rising with a recent last_occurrence deserves the same triage as the underlying error; delay_between_responses = 0 on a noisy alert can flood operators (set a sane delay)."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-009-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-009-RC01 (sqlserver)', 'resolve-hlth_sql_sys_009_rc01-sqlserver', 'Audit Agent alert coverage: disabled alerts, void notifications, missing severity/corruption alerts.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

-- 4) MONITORING VIEW --------------------------------------------------------
CREATE OR REPLACE VIEW monitoring.v_hlth_sql_sys_009_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'name')                        AS alert_name,
    (j.value ->> 'alert_type')                  AS alert_type,
    (j.value ->> 'event_source')                AS event_source,
    (j.value ->> 'message_id')::int             AS message_id,
    (j.value ->> 'severity')::int               AS severity,
    (j.value ->> 'enabled')::int                AS enabled,
    (j.value ->> 'database_scope')              AS database_scope,
    (j.value ->> 'performance_condition')       AS performance_condition,
    (j.value ->> 'has_notification')::int       AS has_notification,
    (j.value ->> 'notified_operators')          AS notified_operators,
    (j.value ->> 'response_job')                AS response_job,
    (j.value ->> 'delay_between_responses')::int AS delay_between_responses,
    (j.value ->> 'occurrence_count')::int       AS occurrence_count,
    (j.value ->> 'last_occurrence')             AS last_occurrence,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-009-RC01';

-- keep view/grants aligned with the 6690 hardening when the engine role exists
DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_009_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_009_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

-- 5) VERIFY ----------------------------------------------------------------
SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-009-RC01';

COMMIT;
