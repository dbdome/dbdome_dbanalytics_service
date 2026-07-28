-- ============================================================
-- 6870  HLTH-SQL-SYS-014-RC01  Buffer Manager counters captured (sqlserver)
--   HEALTH system series root cause.
--   Rebuilt from the base Buffer cache hit ratio query:
--     * THE BUG: the raw cntr_value of Buffer cache hit ratio is meaningless
--       on its own - it must be divided by Buffer cache hit ratio base (a
--       RAW_FRACTION/BASE counter pair); now computed as a true percent
--     * added the counters that actually diagnose memory pressure: Page life
--       expectancy, Lazy writes, Checkpoint pages, Page reads/writes,
--       Free list stalls, Database/Target pages
--     * object_name LIKE keeps it instance-name agnostic (named instances
--       prefix the object name)
--   2005+. Requires VIEW SERVER STATE.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-014','HLTH','SQL','SYS','Buffer Manager Health','buffer-manager-counters',
        'Buffer Manager performance counters: cache hit ratio computed correctly against its base counter, page life expectancy and memory-pressure indicators.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-014-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-014-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-014-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-014-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-014-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-014-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-014-RC01', 'HLTH-SQL-SYS-014', 'Buffer Manager counters captured',
    'buffer-manager-counters-rc01',
    'Key Buffer Manager counters as (counter, value) rows: buffer cache hit ratio CORRECTLY computed against its base counter (the raw cntr_value alone is meaningless), page life expectancy, lazy writes, checkpoint pages, page reads/writes, free-list stalls, database vs target pages. The /sec-named counters are cumulative ticks - rates come from deltas between collector snapshots.',
    ARRAY['health', 'memory', 'buffer-pool', 'counters', 'cache'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-014-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nWITH pc AS (\n    SELECT RTRIM(counter_name) AS cn, cntr_value AS v\n    FROM sys.dm_os_performance_counters\n    WHERE object_name LIKE ''%Buffer Manager%''\n)\nSELECT counter, value FROM (\n    SELECT ''buffer_cache_hit_ratio_pct'' AS counter,\n           CAST((SELECT v FROM pc WHERE cn = ''Buffer cache hit ratio'') * 100.0\n                / NULLIF((SELECT v FROM pc WHERE cn = ''Buffer cache hit ratio base''), 0) AS decimal(18,2)) AS value\n    UNION ALL SELECT ''page_life_expectancy_sec'', CAST((SELECT v FROM pc WHERE cn = ''Page life expectancy'') AS decimal(18,2))\n    UNION ALL SELECT ''lazy_writes_total'',        CAST((SELECT v FROM pc WHERE cn = ''Lazy writes/sec'') AS decimal(18,2))\n    UNION ALL SELECT ''checkpoint_pages_total'',   CAST((SELECT v FROM pc WHERE cn = ''Checkpoint pages/sec'') AS decimal(18,2))\n    UNION ALL SELECT ''page_reads_total'',         CAST((SELECT v FROM pc WHERE cn = ''Page reads/sec'') AS decimal(18,2))\n    UNION ALL SELECT ''page_writes_total'',        CAST((SELECT v FROM pc WHERE cn = ''Page writes/sec'') AS decimal(18,2))\n    UNION ALL SELECT ''free_list_stalls_total'',   CAST((SELECT v FROM pc WHERE cn = ''Free list stalls/sec'') AS decimal(18,2))\n    UNION ALL SELECT ''database_pages'',           CAST((SELECT v FROM pc WHERE cn = ''Database pages'') AS decimal(18,2))\n    UNION ALL SELECT ''target_pages'',             CAST((SELECT v FROM pc WHERE cn = ''Target pages'') AS decimal(18,2))\n) x\nWHERE value IS NOT NULL"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Buffer Manager counters captured"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-014-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-014-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-014-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-014-RC01 (sqlserver)', 'Buffer Manager counters captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-014-RC01 (sqlserver)', '{"action": "Page life expectancy is the primary signal: a sustained drop (rule of thumb: below ~300s per 4GB of buffer pool) plus rising lazy_writes deltas = memory pressure; hit ratio stays high even under pressure (readahead inflates it) - never rely on it alone; free_list_stalls deltas above 0 are direct waits for free pages; database_pages far below target_pages right after startup is normal warm-up, not pressure."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-014-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-014-RC01 (sqlserver)', 'resolve-hlth_sql_sys_014_rc01-sqlserver', 'Buffer Manager counters captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_sys_014_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'counter')                      AS counter,
    (j.value ->> 'value')::numeric               AS value,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-014-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_014_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_014_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-014-RC01';

COMMIT;
