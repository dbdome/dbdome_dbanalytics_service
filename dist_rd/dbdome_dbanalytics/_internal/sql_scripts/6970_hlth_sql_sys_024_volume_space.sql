-- ============================================================
-- 6970  HLTH-SQL-SYS-024-RC01  Volume free space captured (sqlserver)
--   HEALTH system series root cause.
--   Merged from the disk_volums and Disk space base queries (same intent):
--     * THE BUG: the base labeled available_bytes/1073741824 as
--       FreeSpaceInMB - that computes GB; columns are now explicit _gb
--     * free_pct computed directly (the base CAST the ratio to
--       DECIMAL(18,2) BEFORE multiplying by 100, flooring the precision)
--     * DISTINCT replaced with GROUP BY, adding db_file_count and
--       db_files_mb per volume
--   2008 R2+ (dm_os_volume_stats). Requires VIEW SERVER STATE.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-024','HLTH','SQL','SYS','Volume Free Space','volume-space',
        'One row per volume hosting database files: capacity, free space and percent free, with the count and size of database files it hosts.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-024-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-024-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-024-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-024-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-024-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-024-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-024-RC01', 'HLTH-SQL-SYS-024', 'Volume free space captured',
    'volume-space-rc01',
    'Distinct volumes that host any database file: mount point, logical volume name, file system, total and available GB, percent free, how many database files live there and their combined size. The volume-level rollup under HLTH-SQL-SYS-021 (per-file) and companion to HLTH-SQL-SYS-025 (per-volume latency).',
    ARRAY['health', 'storage', 'volumes', 'capacity', 'disk-space'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-024-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nSELECT vs.volume_mount_point,\n    MAX(vs.logical_volume_name) AS logical_volume_name,\n    MAX(vs.file_system_type) AS file_system_type,\n    CONVERT(decimal(18,2), MAX(vs.total_bytes)/1073741824.0) AS total_gb,\n    CONVERT(decimal(18,2), MAX(vs.available_bytes)/1073741824.0) AS available_gb,\n    CAST(MAX(vs.available_bytes) * 100.0 / NULLIF(MAX(vs.total_bytes), 0) AS decimal(5,2)) AS free_pct,\n    COUNT(*) AS db_file_count,\n    CONVERT(bigint, SUM(mf.size)/128.0) AS db_files_mb\nFROM sys.master_files mf\nCROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) vs\nGROUP BY vs.volume_mount_point\nORDER BY free_pct ASC"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Volumes hosting database files captured"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-024-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-024-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-024-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-024-RC01 (sqlserver)', 'Volume free space captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-024-RC01 (sqlserver)', '{"action": "Alert on free_pct against a tiered threshold (e.g. warn 20, critical 10) - absolute GB matters too on huge volumes; db_files_mb near total_gb*1024 means the volume is dedicated and database growth is the only driver (use HLTH-SQL-SYS-021 days_to_full); a volume hosting files from MANY databases compounds growth risk and blast radius."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-024-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-024-RC01 (sqlserver)', 'resolve-hlth_sql_sys_024_rc01-sqlserver', 'Volume free space captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_024_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_024_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'volume_mount_point')          AS volume_mount_point,
    (j.value ->> 'logical_volume_name')         AS logical_volume_name,
    (j.value ->> 'file_system_type')            AS file_system_type,
    (j.value ->> 'total_gb')::numeric           AS total_gb,
    (j.value ->> 'available_gb')::numeric       AS available_gb,
    (j.value ->> 'free_pct')::numeric           AS free_pct,
    (j.value ->> 'db_file_count')::int          AS db_file_count,
    (j.value ->> 'db_files_mb')::bigint         AS db_files_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-024-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_024_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_024_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-024-RC01';

COMMIT;
