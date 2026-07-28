-- ============================================================
-- 7110  HLTH-SQL-SYS-038-RC01  Scheduler health captured per scheduler (sqlserver)
--   HEALTH system series root cause.
--   Expanded from the base SUM(pending_disk_io_count) single number:
--     * per-scheduler rows instead of one aggregate - pressure on ONE
--       scheduler (affinity skew) vanishes inside a sum
--     * added the surrounding health signals: runnable tasks (CPU
--       pressure), task/worker counts, work queue depth, load factor,
--       online/idle state
--     * scheduler_id < 255 keeps visible user schedulers (hidden/DAC out)
--   2005+. Requires VIEW SERVER STATE.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-038','HLTH','SQL','SYS','Scheduler Health','scheduler-health',
        'Per-scheduler task, worker and queue state: CPU pressure (runnable tasks), pending disk I/O stuck at schedulers, and offline-scheduler detection.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-038-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-038-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-038-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-038-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-038-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-038-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-038-RC01', 'HLTH-SQL-SYS-038', 'Scheduler health captured per scheduler',
    'scheduler-health-rc01',
    'One row per visible scheduler (user schedulers, id < 255): status and online/idle flags, current and runnable task counts, active vs current workers, work queue depth, pending disk I/O count and load factor. runnable_tasks_count is the purest CPU-pressure signal (tasks with a CPU ready to run but waiting for it); pending_disk_io_count elevated across schedulers indicts the I/O path.',
    ARRAY['health', 'cpu', 'schedulers', 'workers', 'pressure'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-038-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nSELECT\n    scheduler_id,\n    cpu_id,\n    status,\n    CONVERT(int, is_online) AS is_online,\n    CONVERT(int, is_idle) AS is_idle,\n    current_tasks_count,\n    runnable_tasks_count,\n    active_workers_count,\n    current_workers_count,\n    work_queue_count,\n    pending_disk_io_count,\n    load_factor\nFROM sys.dm_os_schedulers\nWHERE scheduler_id < 255\nORDER BY scheduler_id"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Visible schedulers captured"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-038-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-038-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-038-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-038-RC01 (sqlserver)', 'Scheduler health captured per scheduler', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-038-RC01 (sqlserver)', '{"action": "Sustained runnable_tasks_count above ~1 per scheduler = CPU pressure (correlate HLTH-SQL-SYS-017 utilization and SOS_SCHEDULER_YIELD waits in SYS-002); pending_disk_io_count persistently above 0 means I/O completions are lagging (correlate volume latency, SYS-025); an is_online = 0 scheduler wastes a licensed core (affinity/licensing - check SYS-001 node state); work_queue_count growing while workers are maxed suggests raising max worker threads only AFTER ruling out blocking."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-038-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-038-RC01 (sqlserver)', 'resolve-hlth_sql_sys_038_rc01-sqlserver', 'Scheduler health captured per scheduler: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_038_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_038_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'scheduler_id')::int           AS scheduler_id,
    (j.value ->> 'cpu_id')::int                 AS cpu_id,
    (j.value ->> 'status')                      AS status,
    (j.value ->> 'is_online')::int              AS is_online,
    (j.value ->> 'is_idle')::int                AS is_idle,
    (j.value ->> 'current_tasks_count')::int    AS current_tasks_count,
    (j.value ->> 'runnable_tasks_count')::int   AS runnable_tasks_count,
    (j.value ->> 'active_workers_count')::int   AS active_workers_count,
    (j.value ->> 'current_workers_count')::int  AS current_workers_count,
    (j.value ->> 'work_queue_count')::int       AS work_queue_count,
    (j.value ->> 'pending_disk_io_count')::int  AS pending_disk_io_count,
    (j.value ->> 'load_factor')::int            AS load_factor,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-038-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_038_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_038_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-038-RC01';

COMMIT;
