-- ============================================================
-- 7120  HLTH-SQL-SYS-039-RC01  Pending I/O requests captured (sqlserver)
--   HEALTH system series root cause.
--   Rebuilt from the base dm_io_pending_io_requests query:
--     * the base selected io_handle_path, which does not exist on the DMV -
--       the FILE is resolved by joining io_handle to
--       dm_io_virtual_file_stats.file_handle and then master_files
--     * ordered by time pending; TOP 200; io_pending kept front and center
--       (OS-stuck vs completion-pending are different diagnoses)
--   2005+. Requires VIEW SERVER STATE.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-039','HLTH','SQL','SYS','In-Flight I/O Requests','pending-io-requests',
        'Point-in-time list of I/O requests currently outstanding, resolved to the database file, with how long each has been pending and WHERE it is stuck.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-039-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-039-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-039-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-039-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-039-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-039-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-039-RC01', 'HLTH-SQL-SYS-039', 'Pending I/O requests captured',
    'pending-io-requests-rc01',
    'Every I/O request in flight at snapshot time: type, milliseconds pending, offset, and - resolved via the io_handle/file_handle join - the database, logical file and physical path it targets. io_pending distinguishes the guilty layer: 1 = still stuck at the OS/storage level, 0 = completed but SQL Server has not processed it yet (scheduler/CPU side). Zero rows = nothing stuck right now (healthy snapshot).',
    ARRAY['health', 'io', 'storage', 'pending', 'stalls'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-039-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nSELECT TOP 200\n    p.io_type,\n    CONVERT(int, p.io_pending) AS io_pending,\n    p.io_pending_ms_ticks,\n    p.io_offset,\n    DB_NAME(vfs.database_id) AS database_name,\n    mf.name AS logical_file_name,\n    mf.physical_name,\n    mf.type_desc AS file_type\nFROM sys.dm_io_pending_io_requests p\nLEFT JOIN sys.dm_io_virtual_file_stats(NULL, NULL) vfs ON vfs.file_handle = p.io_handle\nLEFT JOIN sys.master_files mf ON mf.database_id = vfs.database_id AND mf.file_id = vfs.file_id\nORDER BY p.io_pending_ms_ticks DESC"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Pending I/O requests present (zero rows = clean snapshot)"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-039-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-039-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-039-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-039-RC01 (sqlserver)', 'Pending I/O requests captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-039-RC01 (sqlserver)', '{"action": "io_pending = 1 with high ms_ticks is the storage stack (HBA/driver/SAN path - correlate the 15-second-I/O errorlog warnings in SYS-026 and volume latency in SYS-025); io_pending = 0 rows piling up means completions wait on busy schedulers (correlate runnable tasks in SYS-038); many requests against ONE file = hot file (consider spreading - SYS-011 confirms); this is a point-in-time view - persistent appearances across collector snapshots matter, single sightings on a busy system are normal."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-039-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-039-RC01 (sqlserver)', 'resolve-hlth_sql_sys_039_rc01-sqlserver', 'Pending I/O requests captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_039_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_039_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'io_type')                     AS io_type,
    (j.value ->> 'io_pending')::int             AS io_pending,
    (j.value ->> 'io_pending_ms_ticks')::bigint AS io_pending_ms_ticks,
    (j.value ->> 'io_offset')::bigint           AS io_offset,
    (j.value ->> 'database_name')               AS database_name,
    (j.value ->> 'logical_file_name')           AS logical_file_name,
    (j.value ->> 'physical_name')               AS physical_name,
    (j.value ->> 'file_type')                   AS file_type,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-039-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_039_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_039_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-039-RC01';

COMMIT;
