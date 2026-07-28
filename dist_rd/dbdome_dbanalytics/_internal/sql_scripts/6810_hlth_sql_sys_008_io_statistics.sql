-- ============================================================
-- 6810  HLTH-SQL-SYS-008-RC01  I/O statistics by database (sqlserver)
--   Eighth HEALTH system root cause (series: 6740-6800).
--   Cumulative I/O per database from sys.dm_io_virtual_file_stats.
--
--   Enriched from the base query:
--     * read_mb / written_mb split (a single total hides read/write skew)
--     * average READ and WRITE latency per database (io_stall / operations)
--       -- the actual storage-health signal, not just volume
--     * data-file vs log-file I/O split via sys.master_files, including
--       avg_log_write_latency_ms (slow log writes = slow commits)
--     * operation counts (num_of_reads / num_of_writes)
--     * ResourceDB (32767) excluded (DB_NAME is NULL for it),
--       NULLIF guards on every division, OPTION (RECOMPILE) dropped
--   Counters are CUMULATIVE SINCE INSTANCE START -- rank shifts and latency
--   trends matter more than absolute totals; compare snapshots over time.
--   Every object/column is SQL Server 2005+ -- fits all versions.
--   Requires VIEW SERVER STATE.
--
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

-- 0) AREA + ISSUE -----------------------------------------------------------
INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-008','HLTH','SQL','SYS','I/O Distribution & Latency','io-distribution-latency',
        'Track which databases drive the I/O load and what latency they experience, split by data and log files, to spot I/O hogs and storage bottlenecks.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

-- cleanup of any prior HLTH-SQL-SYS-008-RC01 artifacts (idempotent rebuild)
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-008-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-008-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-008-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-008-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-008-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-008-RC01 %';

-- 1) ROOT CAUSE -------------------------------------------------------------
INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-008-RC01', 'HLTH-SQL-SYS-008', 'Per-database I/O volume & latency captured',
    'io-volume-latency-per-database',
    'Per-database cumulative I/O since instance start: rank and percent of total, read/written MB, operation counts, average read and write latency, data-file vs log-file I/O split and average log-write latency. Feeds I/O-hog, storage-bottleneck and slow-commit health checks.',
    ARRAY['health', 'io', 'storage', 'latency', 'capacity'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

-- 2) DETECTION STEP (sqlserver) --------------------------------------------
INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-008-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nWITH io AS (\n    SELECT vfs.database_id,\n        CAST(SUM(vfs.num_of_bytes_read)/1048576.0 AS decimal(12,2)) AS read_mb,\n        CAST(SUM(vfs.num_of_bytes_written)/1048576.0 AS decimal(12,2)) AS written_mb,\n        SUM(vfs.num_of_reads) AS num_of_reads,\n        SUM(vfs.num_of_writes) AS num_of_writes,\n        CAST(SUM(vfs.io_stall_read_ms) * 1.0 / NULLIF(SUM(vfs.num_of_reads), 0) AS decimal(12,2)) AS avg_read_latency_ms,\n        CAST(SUM(vfs.io_stall_write_ms) * 1.0 / NULLIF(SUM(vfs.num_of_writes), 0) AS decimal(12,2)) AS avg_write_latency_ms,\n        CAST(SUM(CASE WHEN mf.type = 0 THEN vfs.num_of_bytes_read + vfs.num_of_bytes_written ELSE 0 END)/1048576.0 AS decimal(12,2)) AS data_io_mb,\n        CAST(SUM(CASE WHEN mf.type = 1 THEN vfs.num_of_bytes_read + vfs.num_of_bytes_written ELSE 0 END)/1048576.0 AS decimal(12,2)) AS log_io_mb,\n        CAST(SUM(CASE WHEN mf.type = 1 THEN vfs.io_stall_write_ms ELSE 0 END) * 1.0 / NULLIF(SUM(CASE WHEN mf.type = 1 THEN vfs.num_of_writes ELSE 0 END), 0) AS decimal(12,2)) AS avg_log_write_latency_ms\n    FROM sys.dm_io_virtual_file_stats(NULL, NULL) vfs\n    LEFT JOIN sys.master_files mf ON mf.database_id = vfs.database_id AND mf.file_id = vfs.file_id\n    WHERE vfs.database_id <> 32767\n    GROUP BY vfs.database_id\n)\nSELECT ROW_NUMBER() OVER (ORDER BY read_mb + written_mb DESC) AS io_rank,\n       DB_NAME(database_id) AS database_name,\n       CAST(read_mb + written_mb AS decimal(12,2)) AS total_io_mb,\n       CAST((read_mb + written_mb) / NULLIF(SUM(read_mb + written_mb) OVER(), 0) * 100.0 AS decimal(5,2)) AS io_percent,\n       read_mb,\n       written_mb,\n       num_of_reads,\n       num_of_writes,\n       avg_read_latency_ms,\n       avg_write_latency_ms,\n       data_io_mb,\n       log_io_mb,\n       avg_log_write_latency_ms\nFROM io\nORDER BY io_rank"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Per-database I/O volume and latency captured"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-008-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-008-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-008-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-008-RC01 (sqlserver)', 'Per-database I/O volume & latency captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-008-RC01 (sqlserver)', '{"action": "Latency is the health signal, volume is context: avg_read_latency_ms persistently above ~20ms (data) or avg_log_write_latency_ms above ~5ms points at storage or contention problems - correlate PAGEIOLATCH_/WRITELOG waits (HLTH-SQL-SYS-002); a database whose io_percent jumps between snapshots has a changed working set (new scan-heavy workload, missing index - correlate HLTH-SQL-SYS-005); high read_mb with low buffer-pool share (HLTH-SQL-SYS-007) means the working set does not fit in cache; counters reset on instance restart, so compare trends, not absolutes."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-008-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-008-RC01 (sqlserver)', 'resolve-hlth_sql_sys_008_rc01-sqlserver', 'Watch per-database I/O latency and share shifts; correlate with waits, top queries and buffer pool.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

-- 4) MONITORING VIEW --------------------------------------------------------
CREATE OR REPLACE VIEW monitoring.v_hlth_sql_sys_008_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'io_rank')::int                    AS io_rank,
    (j.value ->> 'database_name')                   AS database_name,
    (j.value ->> 'total_io_mb')::numeric            AS total_io_mb,
    (j.value ->> 'io_percent')::numeric             AS io_percent,
    (j.value ->> 'read_mb')::numeric                AS read_mb,
    (j.value ->> 'written_mb')::numeric             AS written_mb,
    (j.value ->> 'num_of_reads')::bigint            AS num_of_reads,
    (j.value ->> 'num_of_writes')::bigint           AS num_of_writes,
    (j.value ->> 'avg_read_latency_ms')::numeric    AS avg_read_latency_ms,
    (j.value ->> 'avg_write_latency_ms')::numeric   AS avg_write_latency_ms,
    (j.value ->> 'data_io_mb')::numeric             AS data_io_mb,
    (j.value ->> 'log_io_mb')::numeric              AS log_io_mb,
    (j.value ->> 'avg_log_write_latency_ms')::numeric AS avg_log_write_latency_ms,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-008-RC01';

-- keep view/grants aligned with the 6690 hardening when the engine role exists
DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_008_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_008_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

-- 5) VERIFY ----------------------------------------------------------------
SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-008-RC01';

COMMIT;
