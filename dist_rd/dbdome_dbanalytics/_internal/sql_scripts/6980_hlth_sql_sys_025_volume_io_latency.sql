-- ============================================================
-- 6980  HLTH-SQL-SYS-025-RC01  Per-volume I/O latency captured (sqlserver)
--   HEALTH system series root cause.
--   Rebuilt from the base drive-latency query:
--     * THE BUG: io_stall_read_ms/num_of_reads etc. used INTEGER division -
--       truncated averages (9.9ms reads as 9); now * 1.0 with NULLIF (and
--       NULL, not fake 0, when a volume has no reads/writes)
--     * grouped by dm_os_volume_stats mount point with the drive-letter
--       prefix only as fallback (LEFT(physical_name,2) is meaningless on
--       Linux paths); added read/written MB
--   2008 R2+ (dm_os_volume_stats). Requires VIEW SERVER STATE.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-025','HLTH','SQL','SYS','Volume I/O Latency','volume-io-latency',
        'Average I/O latency and transfer size aggregated per volume/drive - the storage-tier health rollup.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-025-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-025-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-025-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-025-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-025-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-025-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-025-RC01', 'HLTH-SQL-SYS-025', 'Per-volume I/O latency captured',
    'volume-io-latency-rc01',
    'I/O statistics rolled up per volume (mount point, or drive-letter prefix as fallback): average read/write/overall latency, average bytes per read/write/transfer, operation counts and MB moved. The tier between per-database (HLTH-SQL-SYS-008) and per-file (HLTH-SQL-SYS-011): if all files on one volume are slow, the volume is the problem.',
    ARRAY['health', 'io', 'storage', 'latency', 'volumes'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-025-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nSELECT\n    tab.volume,\n    tab.volume_mount_point,\n    CAST(tab.io_stall_read_ms * 1.0 / NULLIF(tab.num_of_reads, 0) AS decimal(12,1)) AS avg_read_latency_ms,\n    CAST(tab.io_stall_write_ms * 1.0 / NULLIF(tab.num_of_writes, 0) AS decimal(12,1)) AS avg_write_latency_ms,\n    CAST(tab.io_stall * 1.0 / NULLIF(tab.num_of_reads + tab.num_of_writes, 0) AS decimal(12,1)) AS avg_latency_ms,\n    CONVERT(bigint, tab.num_of_bytes_read / NULLIF(tab.num_of_reads, 0)) AS avg_bytes_per_read,\n    CONVERT(bigint, tab.num_of_bytes_written / NULLIF(tab.num_of_writes, 0)) AS avg_bytes_per_write,\n    CONVERT(bigint, (tab.num_of_bytes_read + tab.num_of_bytes_written) / NULLIF(tab.num_of_reads + tab.num_of_writes, 0)) AS avg_bytes_per_transfer,\n    tab.num_of_reads,\n    tab.num_of_writes,\n    CONVERT(bigint, tab.num_of_bytes_read/1048576) AS read_mb,\n    CONVERT(bigint, tab.num_of_bytes_written/1048576) AS written_mb\nFROM (\n    SELECT COALESCE(vs.volume_mount_point, LEFT(UPPER(mf.physical_name), 2)) AS volume,\n           vs.volume_mount_point,\n           SUM(vfs.num_of_reads) AS num_of_reads,\n           SUM(vfs.io_stall_read_ms) AS io_stall_read_ms,\n           SUM(vfs.num_of_writes) AS num_of_writes,\n           SUM(vfs.io_stall_write_ms) AS io_stall_write_ms,\n           SUM(vfs.num_of_bytes_read) AS num_of_bytes_read,\n           SUM(vfs.num_of_bytes_written) AS num_of_bytes_written,\n           SUM(vfs.io_stall) AS io_stall\n    FROM sys.dm_io_virtual_file_stats(NULL, NULL) vfs\n    JOIN sys.master_files mf ON mf.database_id = vfs.database_id AND mf.file_id = vfs.file_id\n    CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) vs\n    GROUP BY COALESCE(vs.volume_mount_point, LEFT(UPPER(mf.physical_name), 2)), vs.volume_mount_point\n) tab\nORDER BY avg_latency_ms DESC"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Per-volume I/O latency captured"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-025-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-025-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-025-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-025-RC01 (sqlserver)', 'Per-volume I/O latency captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-025-RC01 (sqlserver)', '{"action": "Compare volumes: one slow volume under files from many databases indicts the storage tier, not the workload; avg_bytes_per_transfer distinguishes random OLTP (8-64K) from sequential scan/backup IO (larger) - latency norms differ; counters are cumulative since instance start, so trend deltas between snapshots."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-025-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-025-RC01 (sqlserver)', 'resolve-hlth_sql_sys_025_rc01-sqlserver', 'Per-volume I/O latency captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_025_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_025_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'volume')                          AS volume,
    (j.value ->> 'volume_mount_point')              AS volume_mount_point,
    (j.value ->> 'avg_read_latency_ms')::numeric    AS avg_read_latency_ms,
    (j.value ->> 'avg_write_latency_ms')::numeric   AS avg_write_latency_ms,
    (j.value ->> 'avg_latency_ms')::numeric         AS avg_latency_ms,
    (j.value ->> 'avg_bytes_per_read')::bigint      AS avg_bytes_per_read,
    (j.value ->> 'avg_bytes_per_write')::bigint     AS avg_bytes_per_write,
    (j.value ->> 'avg_bytes_per_transfer')::bigint  AS avg_bytes_per_transfer,
    (j.value ->> 'num_of_reads')::bigint            AS num_of_reads,
    (j.value ->> 'num_of_writes')::bigint           AS num_of_writes,
    (j.value ->> 'read_mb')::bigint                 AS read_mb,
    (j.value ->> 'written_mb')::bigint              AS written_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-025-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_025_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_025_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-025-RC01';

COMMIT;
