-- ============================================================
-- 7140  HLTH-SQL-SYS-041-RC01  Processor hardware identity captured (sqlserver)
--   HEALTH system series root cause.
--   Built from the base xp_instance_regread(ProcessorNameString) call:
--     * GATED behind a dm_os_host_info platform check - xp_instance_regread
--       is Windows-only and on Linux emits a non-rowset result that breaks
--       the collector''s bare fetchall; skipped off Windows (pre-2017 = no
--       host_info = Windows anyway), then TRY/CATCH for registry ACL denials
--     * paired with dm_os_sys_info (cross-platform) so CPU counts, memory,
--       affinity, VM type and clock (~MHz, also registry) always return
--   2005+. Requires sysadmin for xp_instance_regread; dm_os_sys_info needs
--   VIEW SERVER STATE.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-041','HLTH','SQL','SYS','Processor Hardware Identity','processor-hardware',
        'The physical CPU model string (and clock speed) paired with the logical/physical CPU topology - the hardware baseline for capacity and licensing.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-041-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-041-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-041-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-041-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-041-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-041-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-041-RC01', 'HLTH-SQL-SYS-041', 'Processor hardware identity captured',
    'processor-hardware-rc01',
    'The CPU model name and clock speed read from the registry (Windows only), paired with the always-available dm_os_sys_info topology: logical and physical CPU counts, hyperthread ratio, physical memory, affinity type, VM type and start time. On SQL Server on Linux the registry read is not available so processor_name reads as unavailable while the CPU-count columns still populate. Baseline for hardware-change and CPU-licensing checks.',
    ARRAY['health', 'hardware', 'cpu', 'processor', 'inventory'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-041-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nDECLARE @processor_name nvarchar(256) = NULL;\nDECLARE @mhz int = NULL;\nDECLARE @is_windows bit = 1;\nIF OBJECT_ID(N''sys.dm_os_host_info'') IS NOT NULL\n    SELECT @is_windows = CASE WHEN host_platform = N''Windows'' THEN 1 ELSE 0 END FROM sys.dm_os_host_info;\nIF @is_windows = 1\nBEGIN TRY\n    EXEC master.sys.xp_instance_regread N''HKEY_LOCAL_MACHINE'',\n        N''HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0'', N''ProcessorNameString'', @processor_name OUTPUT;\n    EXEC master.sys.xp_instance_regread N''HKEY_LOCAL_MACHINE'',\n        N''HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0'', N''~MHz'', @mhz OUTPUT;\nEND TRY\nBEGIN CATCH\n    SET @processor_name = NULL;\nEND CATCH;\nSELECT\n    LTRIM(RTRIM(ISNULL(@processor_name, N''(unavailable - non-Windows or registry access denied)''))) AS processor_name,\n    @mhz AS processor_mhz,\n    i.cpu_count AS logical_cpu_count,\n    i.hyperthread_ratio,\n    i.cpu_count / NULLIF(i.hyperthread_ratio, 0) AS physical_cpu_count,\n    CONVERT(bigint, i.physical_memory_kb/1024) AS physical_memory_mb,\n    i.affinity_type_desc,\n    i.virtual_machine_type_desc,\n    CONVERT(varchar(19), i.sqlserver_start_time, 120) AS sqlserver_start_time\nFROM sys.dm_os_sys_info i"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Processor hardware identity captured"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-041-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-041-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-041-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-041-RC01 (sqlserver)', 'Processor hardware identity captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-041-RC01 (sqlserver)', '{"action": "A changed processor_name between snapshots means the instance moved hosts (VM migration or hardware refresh) - re-validate CPU licensing (physical_cpu_count x core factor) and any affinity settings; virtual_machine_type_desc = HYPERVISOR with a high logical_cpu_count risks NUMA-unaware vCPU layout (correlate SYS-001 node balance); processor_mhz well below the CPU spec can indicate host-level power throttling; unavailable processor_name simply flags a non-Windows host, not a fault."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-041-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-041-RC01 (sqlserver)', 'resolve-hlth_sql_sys_041_rc01-sqlserver', 'Processor hardware identity captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_041_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_041_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'processor_name')              AS processor_name,
    (j.value ->> 'processor_mhz')::int          AS processor_mhz,
    (j.value ->> 'logical_cpu_count')::int      AS logical_cpu_count,
    (j.value ->> 'hyperthread_ratio')::int      AS hyperthread_ratio,
    (j.value ->> 'physical_cpu_count')::int     AS physical_cpu_count,
    (j.value ->> 'physical_memory_mb')::bigint  AS physical_memory_mb,
    (j.value ->> 'affinity_type_desc')          AS affinity_type,
    (j.value ->> 'virtual_machine_type_desc')   AS virtual_machine_type,
    (j.value ->> 'sqlserver_start_time')        AS sqlserver_start_time,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-041-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_041_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_041_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-041-RC01';

COMMIT;
