-- ============================================================
-- 6900  HLTH-SQL-SYS-017-RC01  CPU utilization history captured (sqlserver)
--   HEALTH system series root cause.
--   Enriched from the base ring-buffer query:
--     * event_time normalized to varchar(19); rows capped at TOP 300
--       (the ring buffer keeps ~256 minute records = ~4h)
--     * record_id kept for stable ordering/dedup across snapshots
--     * documented the Linux caveat: SystemIdle is always 0 there, so
--       other_cpu_pct is inflated - use sql_cpu_pct for trending
--   2008+ (ring buffer XML shape). Requires VIEW SERVER STATE.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-017','HLTH','SQL','SYS','CPU Utilization History','cpu-utilization-history',
        'Minute-by-minute CPU utilization history from the scheduler-monitor ring buffer: SQL process vs other processes vs idle, up to ~4 hours back.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-017-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-017-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-017-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-017-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-017-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-017-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-017-RC01', 'HLTH-SQL-SYS-017', 'CPU utilization history captured',
    'cpu-utilization-history-rc01',
    'One row per scheduler-monitor heartbeat (about one per minute, ~256 kept): event time reconstructed from the tick delta, SQL Server process CPU percent, system idle percent and the derived other-process percent. Gives CPU trend context without OS access. Note: SQL Server on Linux reports SystemIdle as 0, which inflates other_cpu_pct there - trend sql_cpu_pct on Linux.',
    ARRAY['health', 'cpu', 'utilization', 'trend', 'ring-buffer'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-017-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nDECLARE @ts_now bigint;\nSELECT @ts_now = cpu_ticks/(cpu_ticks/ms_ticks) FROM sys.dm_os_sys_info;\nSELECT TOP 300\n    record_id,\n    CONVERT(varchar(19), DATEADD(ms, -1 * (@ts_now - [timestamp]), GETDATE()), 120) AS event_time,\n    SQLProcessUtilization AS sql_cpu_pct,\n    SystemIdle AS system_idle_pct,\n    100 - SystemIdle - SQLProcessUtilization AS other_cpu_pct\nFROM (\n    SELECT record.value(''(./Record/@id)[1]'', ''int'') AS record_id,\n           record.value(''(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]'', ''int'') AS SystemIdle,\n           record.value(''(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]'', ''int'') AS SQLProcessUtilization,\n           [timestamp]\n    FROM (\n        SELECT [timestamp], CONVERT(xml, record) AS record\n        FROM sys.dm_os_ring_buffers\n        WHERE ring_buffer_type = N''RING_BUFFER_SCHEDULER_MONITOR''\n          AND record LIKE ''%<SystemHealth>%'') AS x\n) AS y\nORDER BY record_id DESC"}'::jsonb,
        '{"condition": "row_count > 0", "description": "CPU utilization history rows captured"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-017-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-017-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-017-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-017-RC01 (sqlserver)', 'CPU utilization history captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-017-RC01 (sqlserver)', '{"action": "Sustained sql_cpu_pct above ~80 means SQL is the consumer - correlate HLTH-SQL-SYS-005 top CPU queries; high other_cpu_pct on Windows points OUTSIDE SQL Server (AV scans, backups, other services on the box); sawtooth patterns aligned with job schedules identify batch pressure; on Linux ignore system_idle/other (reported as 0)."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-017-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-017-RC01 (sqlserver)', 'resolve-hlth_sql_sys_017_rc01-sqlserver', 'CPU utilization history captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_sys_017_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'record_id')::bigint           AS record_id,
    (j.value ->> 'event_time')                  AS event_time,
    (j.value ->> 'sql_cpu_pct')::int            AS sql_cpu_pct,
    (j.value ->> 'system_idle_pct')::int        AS system_idle_pct,
    (j.value ->> 'other_cpu_pct')::int          AS other_cpu_pct,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-017-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_017_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_017_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-017-RC01';

COMMIT;
