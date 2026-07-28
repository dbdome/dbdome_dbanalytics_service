-- ============================================================
-- 6740  HLTH-SQL-SYS-001-RC01  NUMA node & CPU/memory configuration (sqlserver)
--   First of the HEALTH system-resource root causes ("all vendors" series;
--   sqlserver first, other vendors follow in later scripts).
--
--   Enriched from the base dm_os_sys_info query:
--     * fixed the memory unit bug (physical_memory_kb/1048576 is GB, not MB)
--     * added socket_count / cores_per_socket / numa_node_count (2016 SP1+)
--     * added committed vs target memory, max_workers_count, scheduler_count
--     * added softnuma_configuration_desc, sql_memory_model_desc (LPIM?),
--       virtual_machine_type_desc (VM detection) and uptime_hours
--     * one row PER NUMA NODE from sys.dm_os_nodes + dm_os_memory_nodes
--       (node state, online schedulers, active workers, load balance,
--       per-node memory) with the instance-level columns repeated,
--       DAC node excluded
--   Dropped WITH (NOLOCK) / OPTION (RECOMPILE): meaningless on DMVs.
--   Version-adaptive via sys.all_columns capability probes: one detection
--   works on every SQL Server version 2008 -> 2022+ (see step comment).
--   Requires VIEW SERVER STATE (the collector login already has it).
--
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

-- 0) AREA + ISSUE (SYS area does not exist yet for SQL) ---------------------
INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-001','HLTH','SQL','SYS','System Resource & NUMA Configuration','system-resource-numa-configuration',
        'Inventory and monitor host/instance compute topology: NUMA nodes, CPU counts, sockets, memory sizing and affinity. Baseline for capacity and misconfiguration health checks.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

-- cleanup of any prior HLTH-SQL-SYS-001-RC01 artifacts (idempotent rebuild)
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-001-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-001-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-001-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-001-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-001-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-001-RC01 %';

-- 1) ROOT CAUSE -------------------------------------------------------------
INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-001-RC01', 'HLTH-SQL-SYS-001', 'NUMA node & CPU/memory configuration captured',
    'numa-cpu-memory-configuration',
    'Captures the instance compute topology per NUMA node: logical/physical CPU counts, hyperthread ratio, sockets and cores per socket, NUMA node count and per-node scheduler/worker/memory state, physical vs committed memory, memory model (locked pages), CPU affinity and soft-NUMA configuration, VM type and uptime. Informational baseline; feeds capacity and misconfiguration checks (e.g. offline schedulers, unbalanced nodes, memory pressure).',
    ARRAY['health', 'numa', 'cpu', 'memory', 'capacity', 'configuration'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

-- 2) DETECTION STEP (sqlserver) --------------------------------------------
-- Version-adaptive for ALL SQL Server versions (2008 -> 2022+): probes
-- sys.all_columns for each capability and composes the SELECT dynamically.
--   * 2016 SP1+ : socket_count / cores_per_socket / numa_node_count /
--                 softnuma_configuration_desc / sql_memory_model_desc
--   * 2012+     : physical_memory_kb / committed_kb / committed_target_kb;
--                 older: physical_memory_in_bytes / bpool_committed(*8KB pages)
--   * 2008 R2+  : sqlserver_start_time / affinity_type_desc / virtual_machine_
--                 type_desc; older: tempdb create_date as start time, NULLs
--   * dm_os_memory_nodes: pages_kb (2012+) vs single+multi_pages_kb (2008)
-- Missing capabilities surface as NULL columns; shape is identical everywhere.
INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-001-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nDECLARE @c2016 bit, @c2012 bit, @cstart bit, @cvm bit, @caff bit, @cpages bit, @sql nvarchar(max);\nSELECT @c2016  = CASE WHEN EXISTS (SELECT 1 FROM sys.all_columns WHERE object_id=OBJECT_ID(''sys.dm_os_sys_info'') AND name=''socket_count'') THEN 1 ELSE 0 END,\n       @c2012  = CASE WHEN EXISTS (SELECT 1 FROM sys.all_columns WHERE object_id=OBJECT_ID(''sys.dm_os_sys_info'') AND name=''physical_memory_kb'') THEN 1 ELSE 0 END,\n       @cstart = CASE WHEN EXISTS (SELECT 1 FROM sys.all_columns WHERE object_id=OBJECT_ID(''sys.dm_os_sys_info'') AND name=''sqlserver_start_time'') THEN 1 ELSE 0 END,\n       @cvm    = CASE WHEN EXISTS (SELECT 1 FROM sys.all_columns WHERE object_id=OBJECT_ID(''sys.dm_os_sys_info'') AND name=''virtual_machine_type_desc'') THEN 1 ELSE 0 END,\n       @caff   = CASE WHEN EXISTS (SELECT 1 FROM sys.all_columns WHERE object_id=OBJECT_ID(''sys.dm_os_sys_info'') AND name=''affinity_type_desc'') THEN 1 ELSE 0 END,\n       @cpages = CASE WHEN EXISTS (SELECT 1 FROM sys.all_columns WHERE object_id=OBJECT_ID(''sys.dm_os_memory_nodes'') AND name=''pages_kb'') THEN 1 ELSE 0 END;\nSET @sql = ''SELECT n.node_id, n.node_state_desc, n.online_scheduler_count, n.active_worker_count, CAST(n.avg_load_balance AS int) AS avg_load_balance, ''\n + CASE WHEN @cpages=1 THEN ''CAST(mn.pages_kb/1024 AS bigint)'' ELSE ''CAST((mn.single_pages_kb + mn.multi_pages_kb)/1024 AS bigint)'' END + '' AS node_memory_mb, ''\n + ''i.cpu_count AS logical_cpu_count, i.hyperthread_ratio, i.cpu_count / i.hyperthread_ratio AS physical_cpu_count, ''\n + CASE WHEN @c2016=1 THEN ''i.socket_count, i.cores_per_socket, i.numa_node_count, ''\n        ELSE ''CAST(NULL AS int) AS socket_count, CAST(NULL AS int) AS cores_per_socket, (SELECT COUNT(*) FROM sys.dm_os_nodes WHERE node_state_desc NOT LIKE ''''%DAC%'''') AS numa_node_count, '' END\n + CASE WHEN @c2012=1 THEN ''CAST(i.physical_memory_kb/1024 AS bigint) AS physical_memory_mb, CAST(i.committed_kb/1024 AS bigint) AS sql_committed_mb, CAST(i.committed_target_kb/1024 AS bigint) AS sql_target_memory_mb, ''\n        ELSE ''CAST(i.physical_memory_in_bytes/1048576 AS bigint) AS physical_memory_mb, CAST(i.bpool_committed*8/1024 AS bigint) AS sql_committed_mb, CAST(i.bpool_commit_target*8/1024 AS bigint) AS sql_target_memory_mb, '' END\n + ''i.max_workers_count, i.scheduler_count, ''\n + CASE WHEN @caff=1 THEN ''i.affinity_type_desc, '' ELSE ''CAST(NULL AS nvarchar(60)) AS affinity_type_desc, '' END\n + CASE WHEN @c2016=1 THEN ''i.softnuma_configuration_desc, i.sql_memory_model_desc, ''\n        ELSE ''CAST(NULL AS nvarchar(60)) AS softnuma_configuration_desc, CAST(NULL AS nvarchar(60)) AS sql_memory_model_desc, '' END\n + CASE WHEN @cvm=1 THEN ''i.virtual_machine_type_desc, '' ELSE ''CAST(NULL AS nvarchar(60)) AS virtual_machine_type_desc, '' END\n + CASE WHEN @cstart=1 THEN ''CONVERT(varchar(19), i.sqlserver_start_time, 120) AS sqlserver_start_time, DATEDIFF(HOUR, i.sqlserver_start_time, GETDATE()) AS uptime_hours ''\n        ELSE ''(SELECT CONVERT(varchar(19), create_date, 120) FROM sys.databases WHERE database_id=2) AS sqlserver_start_time, (SELECT DATEDIFF(HOUR, create_date, GETDATE()) FROM sys.databases WHERE database_id=2) AS uptime_hours '' END\n + ''FROM sys.dm_os_sys_info i CROSS JOIN sys.dm_os_nodes n LEFT JOIN sys.dm_os_memory_nodes mn ON mn.memory_node_id = n.memory_node_id WHERE n.node_state_desc NOT LIKE ''''%DAC%'''' ORDER BY n.node_id'';\nEXEC(@sql);"}'::jsonb,
        '{"condition": "row_count > 0", "description": "NUMA/CPU/memory configuration rows returned (one per NUMA node)"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-001-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-001-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-001-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-001-RC01 (sqlserver)', 'NUMA node & CPU/memory configuration captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-001-RC01 (sqlserver)', '{"action": "Informational baseline. Review for: OFFLINE schedulers or node_state other than ONLINE (affinity/licensing limits), avg_load_balance skew between nodes (uneven NUMA load), sql_memory_model_desc = CONVENTIONAL on large-memory hosts (consider Locked Pages In Memory), sql_committed_mb at sql_target_memory_mb with low physical headroom (memory pressure / max server memory sizing), softnuma_configuration_desc vs core count, and unexpected virtual_machine_type_desc changes."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-001-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-001-RC01 (sqlserver)', 'resolve-hlth_sql_sys_001_rc01-sqlserver', 'Review NUMA/CPU/memory topology for offline schedulers, node imbalance, memory model and max-server-memory sizing issues.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

-- 4) MONITORING VIEW --------------------------------------------------------
CREATE OR REPLACE VIEW monitoring.v_hlth_sql_sys_001_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'node_id')::int                    AS node_id,
    (j.value ->> 'node_state_desc')                 AS node_state,
    (j.value ->> 'online_scheduler_count')::int     AS online_schedulers,
    (j.value ->> 'active_worker_count')::int        AS active_workers,
    (j.value ->> 'avg_load_balance')::int           AS avg_load_balance,
    (j.value ->> 'node_memory_mb')::bigint          AS node_memory_mb,
    (j.value ->> 'logical_cpu_count')::int          AS logical_cpu_count,
    (j.value ->> 'hyperthread_ratio')::int          AS hyperthread_ratio,
    (j.value ->> 'physical_cpu_count')::int         AS physical_cpu_count,
    (j.value ->> 'socket_count')::int               AS socket_count,
    (j.value ->> 'cores_per_socket')::int           AS cores_per_socket,
    (j.value ->> 'numa_node_count')::int            AS numa_node_count,
    (j.value ->> 'physical_memory_mb')::bigint      AS physical_memory_mb,
    (j.value ->> 'sql_committed_mb')::bigint        AS sql_committed_mb,
    (j.value ->> 'sql_target_memory_mb')::bigint    AS sql_target_memory_mb,
    (j.value ->> 'max_workers_count')::int          AS max_workers_count,
    (j.value ->> 'scheduler_count')::int            AS scheduler_count,
    (j.value ->> 'affinity_type_desc')              AS affinity_type,
    (j.value ->> 'softnuma_configuration_desc')     AS softnuma_configuration,
    (j.value ->> 'sql_memory_model_desc')           AS sql_memory_model,
    (j.value ->> 'virtual_machine_type_desc')       AS virtual_machine_type,
    (j.value ->> 'sqlserver_start_time')            AS sqlserver_start_time,
    (j.value ->> 'uptime_hours')::int               AS uptime_hours,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-001-RC01';

-- keep view/grants aligned with the 6690 hardening when the engine role exists
DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_001_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_001_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

-- 5) VERIFY ----------------------------------------------------------------
SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-001-RC01';

COMMIT;
