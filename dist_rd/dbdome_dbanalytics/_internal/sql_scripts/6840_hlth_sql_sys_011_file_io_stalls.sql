-- ============================================================
-- 6840  HLTH-SQL-SYS-011-RC01  Per-file I/O stall latency captured (sqlserver)
--   HEALTH system series root cause.
--   Enriched from the base per-file stall query:
--     * NULLIF instead of the (1.0 + n) fudge -- exact averages, NULL when a
--       file has had no reads/writes instead of a diluted number
--     * added logical file name alongside physical path
--     * NOLOCK / OPTION (RECOMPILE) dropped; TOP 200
--   Complements 6810 (per-database): this is the per-FILE drill-down.
--   2005+. Requires VIEW SERVER STATE.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-011','HLTH','SQL','SYS','File-Level I/O Stalls','file-io-stalls',
        'Per-file average I/O stall latency -- the drill-down under the per-database view: which specific data or log file sits on slow storage.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-011-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-011-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-011-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-011-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-011-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-011-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-011-RC01', 'HLTH-SQL-SYS-011', 'Per-file I/O stall latency captured',
    'file-io-stalls-rc01',
    'Every database file with its average read/write/total stall latency, cumulative stall and operation counters, logical/physical name, type and size. The file-level drill-down for HLTH-SQL-SYS-008: pinpoints WHICH file (and therefore which volume) is slow.',
    ARRAY['health', 'io', 'storage', 'latency', 'files'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-011-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nSELECT TOP 200\n    DB_NAME(fs.database_id) AS database_name,\n    mf.name AS logical_file_name,\n    mf.physical_name,\n    mf.type_desc,\n    CONVERT(decimal(18,2), mf.size/128.0) AS file_size_mb,\n    CAST(fs.io_stall_read_ms * 1.0 / NULLIF(fs.num_of_reads, 0) AS numeric(12,1)) AS avg_read_stall_ms,\n    CAST(fs.io_stall_write_ms * 1.0 / NULLIF(fs.num_of_writes, 0) AS numeric(12,1)) AS avg_write_stall_ms,\n    CAST((fs.io_stall_read_ms + fs.io_stall_write_ms) * 1.0 / NULLIF(fs.num_of_reads + fs.num_of_writes, 0) AS numeric(12,1)) AS avg_io_stall_ms,\n    fs.io_stall_read_ms,\n    fs.num_of_reads,\n    fs.io_stall_write_ms,\n    fs.num_of_writes,\n    fs.io_stall_read_ms + fs.io_stall_write_ms AS io_stalls_ms,\n    fs.num_of_reads + fs.num_of_writes AS total_io_ops\nFROM sys.dm_io_virtual_file_stats(NULL, NULL) fs\nJOIN sys.master_files mf ON mf.database_id = fs.database_id AND mf.file_id = fs.file_id\nORDER BY avg_io_stall_ms DESC"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Per-file I/O stall statistics captured"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-011-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-011-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-011-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-011-RC01 (sqlserver)', 'Per-file I/O stall latency captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-011-RC01 (sqlserver)', '{"action": "Files sharing a slow volume show correlated stalls -- move the hot file or fix the storage tier; a LOG file with avg_write_stall_ms above ~5ms slows every commit in that database (correlate WRITELOG waits in HLTH-SQL-SYS-002); NULL averages mean the file has had no IO of that kind; counters are cumulative since instance start -- trend them."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-011-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-011-RC01 (sqlserver)', 'resolve-hlth_sql_sys_011_rc01-sqlserver', 'Per-file I/O stall latency captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_sys_011_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'database_name')               AS database_name,
    (j.value ->> 'logical_file_name')           AS logical_file_name,
    (j.value ->> 'physical_name')               AS physical_name,
    (j.value ->> 'type_desc')                   AS type_desc,
    (j.value ->> 'file_size_mb')::numeric       AS file_size_mb,
    (j.value ->> 'avg_read_stall_ms')::numeric  AS avg_read_stall_ms,
    (j.value ->> 'avg_write_stall_ms')::numeric AS avg_write_stall_ms,
    (j.value ->> 'avg_io_stall_ms')::numeric    AS avg_io_stall_ms,
    (j.value ->> 'io_stall_read_ms')::bigint    AS io_stall_read_ms,
    (j.value ->> 'num_of_reads')::bigint        AS num_of_reads,
    (j.value ->> 'io_stall_write_ms')::bigint   AS io_stall_write_ms,
    (j.value ->> 'num_of_writes')::bigint       AS num_of_writes,
    (j.value ->> 'io_stalls_ms')::bigint        AS io_stalls_ms,
    (j.value ->> 'total_io_ops')::bigint        AS total_io_ops,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-011-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_011_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_011_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-011-RC01';

COMMIT;
