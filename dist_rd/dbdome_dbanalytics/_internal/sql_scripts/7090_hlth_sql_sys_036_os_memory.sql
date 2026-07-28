-- ============================================================
-- 7090  HLTH-SQL-SYS-036-RC01  OS & process memory state captured (sqlserver)
--   HEALTH system series root cause.
--   Enriched from the base dm_os_sys_memory query:
--     * integer /(1024*1024) GB truncation replaced with MB + an exact
--       available percent
--     * added page file totals, system cache and the OS verdict
--       (system_memory_state_desc)
--     * CROSS JOINed dm_os_process_memory: SQL working set, locked pages
--       (LPIM proof), utilization percent, page faults and the two
--       process low-memory flags - OS and process sides in one row
--   2008+ (both DMVs). Requires VIEW SERVER STATE.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-036','HLTH','SQL','SYS','OS Memory State','os-memory-state',
        'Operating-system memory state paired with the SQL Server process footprint: the complete external memory-pressure picture.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-036-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-036-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-036-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-036-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-036-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-036-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-036-RC01', 'HLTH-SQL-SYS-036', 'OS & process memory state captured',
    'os-memory-state-rc01',
    'One row pairing the OS side (total/available physical memory and percent, page file, system cache, the OS pressure verdict system_memory_state_desc) with the SQL process side (physical memory in use, locked pages, working-set percent, page faults and the process low-memory flags). External pressure that HLTH-SQL-SYS-014 (internal buffer counters) cannot see: another process eating the box shows here first.',
    ARRAY['health', 'memory', 'os', 'pressure', 'capacity'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-036-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nSELECT\n    CONVERT(bigint, sm.total_physical_memory_kb/1024) AS os_total_memory_mb,\n    CONVERT(bigint, sm.available_physical_memory_kb/1024) AS os_available_memory_mb,\n    CAST(sm.available_physical_memory_kb * 100.0 / NULLIF(sm.total_physical_memory_kb, 0) AS decimal(5,2)) AS os_available_pct,\n    CONVERT(bigint, sm.total_page_file_kb/1024) AS os_total_page_file_mb,\n    CONVERT(bigint, sm.available_page_file_kb/1024) AS os_available_page_file_mb,\n    CONVERT(bigint, sm.system_cache_kb/1024) AS os_system_cache_mb,\n    sm.system_memory_state_desc,\n    CONVERT(bigint, pm.physical_memory_in_use_kb/1024) AS sql_memory_in_use_mb,\n    CONVERT(bigint, pm.locked_page_allocations_kb/1024) AS sql_locked_pages_mb,\n    pm.memory_utilization_percentage AS sql_working_set_pct,\n    CONVERT(bigint, pm.total_virtual_address_space_kb/1024) AS sql_total_vas_mb,\n    pm.page_fault_count,\n    pm.process_physical_memory_low,\n    pm.process_virtual_memory_low\nFROM sys.dm_os_sys_memory sm\nCROSS JOIN sys.dm_os_process_memory pm"}'::jsonb,
        '{"condition": "row_count > 0", "description": "OS and process memory state captured"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-036-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-036-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-036-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-036-RC01 (sqlserver)', 'OS & process memory state captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-036-RC01 (sqlserver)', '{"action": "system_memory_state_desc saying available memory is LOW while sql_memory_in_use_mb is stable means pressure from OUTSIDE SQL Server (find the other process); process_physical_memory_low = 1 is the direct trim signal - expect PLE collapse (HLTH-SQL-SYS-014) next; sql_locked_pages_mb > 0 confirms Locked Pages In Memory is active; a shrinking os_available_page_file_mb warns of commit exhaustion before out-of-memory errors hit the errorlog (HLTH-SQL-SYS-026); page_fault_count is cumulative - trend deltas."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-036-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-036-RC01 (sqlserver)', 'resolve-hlth_sql_sys_036_rc01-sqlserver', 'OS & process memory state captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_036_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_036_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'os_total_memory_mb')::bigint      AS os_total_memory_mb,
    (j.value ->> 'os_available_memory_mb')::bigint  AS os_available_memory_mb,
    (j.value ->> 'os_available_pct')::numeric       AS os_available_pct,
    (j.value ->> 'os_total_page_file_mb')::bigint   AS os_total_page_file_mb,
    (j.value ->> 'os_available_page_file_mb')::bigint AS os_available_page_file_mb,
    (j.value ->> 'os_system_cache_mb')::bigint      AS os_system_cache_mb,
    (j.value ->> 'system_memory_state_desc')        AS system_memory_state_desc,
    (j.value ->> 'sql_memory_in_use_mb')::bigint    AS sql_memory_in_use_mb,
    (j.value ->> 'sql_locked_pages_mb')::bigint     AS sql_locked_pages_mb,
    (j.value ->> 'sql_working_set_pct')::int        AS sql_working_set_pct,
    (j.value ->> 'sql_total_vas_mb')::bigint        AS sql_total_vas_mb,
    (j.value ->> 'page_fault_count')::bigint        AS page_fault_count,
    (j.value ->> 'process_physical_memory_low')::int AS process_physical_memory_low,
    (j.value ->> 'process_virtual_memory_low')::int AS process_virtual_memory_low,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-036-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_036_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_036_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-036-RC01';

COMMIT;
