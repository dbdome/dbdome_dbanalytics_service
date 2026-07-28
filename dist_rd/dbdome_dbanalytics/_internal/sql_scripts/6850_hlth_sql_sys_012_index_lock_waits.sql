-- ============================================================
-- 6850  HLTH-SQL-SYS-012-RC01  Index lock-wait hotspots captured (sqlserver)
--   HEALTH system series root cause.
--   Rebuilt from the base dm_db_index_operational_stats query:
--     * the sys.indexes JOIN matched on index_id ONLY (no object_id) -- every
--       index with the same index_id across all objects cross-matched,
--       producing wrong names that DISTINCT then masked; sys.indexes also
--       only covers the CONNECTED database while the stats are instance-wide.
--       Replaced with cross-database OBJECT_NAME(object_id, database_id) +
--       index_id, aggregated across partitions with GROUP BY
--     * added avg_block_wait_ms (wait ms / wait count) -- distinguishes
--       long-blocker from hot-row-churn contention
--     * the commented-out threshold became HAVING wait_count > 0: only
--       contended objects return; zero rows = healthy
--   2008+ (OBJECT_NAME with database_id). Requires VIEW SERVER STATE.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-012','HLTH','SQL','SYS','Lock Contention Hotspots','index-lock-waits',
        'Identify the exact tables/indexes where sessions wait on row and page locks, with cumulative and average block-wait times.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-012-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-012-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-012-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-012-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-012-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-012-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-012-RC01', 'HLTH-SQL-SYS-012', 'Index lock-wait hotspots captured',
    'index-lock-waits-rc01',
    'Objects/indexes that have made sessions WAIT for row or page locks: lock and wait counts, cumulative and average block-wait ms, aggregated across partitions, all databases, worst first. Only contended objects are returned -- zero rows means no lock contention since instance start.',
    ARRAY['health', 'locking', 'blocking', 'contention', 'indexes'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-012-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nSELECT TOP 100\n    DB_NAME(l.database_id) AS database_name,\n    OBJECT_NAME(l.object_id, l.database_id) AS object_name,\n    l.index_id,\n    SUM(l.row_lock_count) AS row_lock_count,\n    SUM(l.page_lock_count) AS page_lock_count,\n    SUM(l.row_lock_count + l.page_lock_count) AS total_locks,\n    SUM(l.row_lock_wait_count) AS row_lock_wait_count,\n    SUM(l.page_lock_wait_count) AS page_lock_wait_count,\n    SUM(l.row_lock_wait_count + l.page_lock_wait_count) AS total_lock_waits,\n    SUM(l.row_lock_wait_in_ms) AS row_lock_wait_ms,\n    SUM(l.page_lock_wait_in_ms) AS page_lock_wait_ms,\n    SUM(l.row_lock_wait_in_ms + l.page_lock_wait_in_ms) AS block_wait_ms,\n    CAST(SUM(l.row_lock_wait_in_ms + l.page_lock_wait_in_ms) * 1.0 / NULLIF(SUM(l.row_lock_wait_count + l.page_lock_wait_count), 0) AS decimal(12,1)) AS avg_block_wait_ms\nFROM sys.dm_db_index_operational_stats(NULL, NULL, NULL, NULL) l\nGROUP BY l.database_id, l.object_id, l.index_id\nHAVING SUM(l.row_lock_wait_count + l.page_lock_wait_count) > 0\nORDER BY block_wait_ms DESC"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Lock-contention hotspots found (zero rows = no lock waits recorded)"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-012-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-012-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-012-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-012-RC01 (sqlserver)', 'Index lock-wait hotspots captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-012-RC01 (sqlserver)', '{"action": "High block_wait_ms with high avg says long blockers (find them via HLTH-SQL-SYS-003 open transactions); high count with low avg says hot-row churn (consider index design, shorter transactions, or RCSI/snapshot isolation); index_id 0 is the heap, 1 the clustered index; counters are cumulative since instance start -- trend deltas, not absolutes."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-012-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-012-RC01 (sqlserver)', 'resolve-hlth_sql_sys_012_rc01-sqlserver', 'Index lock-wait hotspots captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_sys_012_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'database_name')               AS database_name,
    (j.value ->> 'object_name')                 AS object_name,
    (j.value ->> 'index_id')::int               AS index_id,
    (j.value ->> 'row_lock_count')::bigint      AS row_lock_count,
    (j.value ->> 'page_lock_count')::bigint     AS page_lock_count,
    (j.value ->> 'total_locks')::bigint         AS total_locks,
    (j.value ->> 'row_lock_wait_count')::bigint AS row_lock_wait_count,
    (j.value ->> 'page_lock_wait_count')::bigint AS page_lock_wait_count,
    (j.value ->> 'total_lock_waits')::bigint    AS total_lock_waits,
    (j.value ->> 'row_lock_wait_ms')::bigint    AS row_lock_wait_ms,
    (j.value ->> 'page_lock_wait_ms')::bigint   AS page_lock_wait_ms,
    (j.value ->> 'block_wait_ms')::bigint       AS block_wait_ms,
    (j.value ->> 'avg_block_wait_ms')::numeric  AS avg_block_wait_ms,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-012-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_012_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_012_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-012-RC01';

COMMIT;
