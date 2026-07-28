-- ============================================================
-- 7170  HLTH-SQL-SYS-044-RC01  Wait statistics captured (sqlserver)
--   HEALTH system series root cause.
--   Built around the base signal_wait_time_ms ratio query, expanded to the
--   canonical wait-stats analysis:
--     * the 65+ benign/idle/background wait exclusion list (the base counted
--       LAZYWRITER_SLEEP, WAITFOR, XE timers etc. - they dwarf real waits)
--     * resource vs signal split (signal = post-ready CPU wait), pct of the
--       total wait budget, per-wait signal pct, avg wait per task
--     * ranked by wait_time, top 30
--   2005+ (later exclusions harmless on old versions). VIEW SERVER STATE.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-044','HLTH','SQL','SYS','Wait Statistics','wait-statistics',
        'Top cumulative waits since startup with the noise filtered out: resource vs signal (CPU) split, percent of total and average wait - the first stop in any performance triage.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-044-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-044-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-044-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-044-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-044-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-044-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-044-RC01', 'HLTH-SQL-SYS-044', 'Wait statistics captured',
    'wait-statistics-rc01',
    'The top 30 meaningful wait types (60+ benign/idle waits excluded) by cumulative wait time: waiting task count, total wait, the resource-wait vs signal-wait (time waiting for CPU AFTER the resource was ready) split, percent of the total wait budget, per-wait signal percent and average wait per task. signal_pct high across the board indicates CPU pressure; the top resource waits name the actual bottleneck. Counters are cumulative since last restart or DBCC SQLPERF clear - trend deltas.',
    ARRAY['health', 'waits', 'performance', 'cpu', 'bottleneck'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-044-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nWITH ws AS (\n    SELECT wait_type,\n           wait_time_ms,\n           wait_time_ms - signal_wait_time_ms AS resource_wait_ms,\n           signal_wait_time_ms,\n           waiting_tasks_count\n    FROM sys.dm_os_wait_stats\n    WHERE waiting_tasks_count > 0\n      AND wait_type NOT IN (\n          N''CLR_SEMAPHORE'', N''LAZYWRITER_SLEEP'', N''RESOURCE_QUEUE'', N''SLEEP_TASK'',\n          N''SLEEP_SYSTEMTASK'', N''SQLTRACE_BUFFER_FLUSH'', N''WAITFOR'', N''LOGMGR_QUEUE'',\n          N''CHECKPOINT_QUEUE'', N''REQUEST_FOR_DEADLOCK_SEARCH'', N''XE_TIMER_EVENT'',\n          N''BROKER_TO_FLUSH'', N''BROKER_TASK_STOP'', N''CLR_MANUAL_EVENT'', N''CLR_AUTO_EVENT'',\n          N''DISPATCHER_QUEUE_SEMAPHORE'', N''FT_IFTS_SCHEDULER_IDLE_WAIT'', N''XE_DISPATCHER_WAIT'',\n          N''XE_DISPATCHER_JOIN'', N''SQLTRACE_INCREMENTAL_FLUSH_SLEEP'', N''ONDEMAND_TASK_QUEUE'',\n          N''BROKER_EVENTHANDLER'', N''SLEEP_BPOOL_FLUSH'', N''SLEEP_DBSTARTUP'', N''DIRTY_PAGE_POLL'',\n          N''HADR_FILESTREAM_IOMGR_IOCOMPLETION'', N''SP_SERVER_DIAGNOSTICS_SLEEP'',\n          N''BROKER_RECEIVE_WAITFOR'', N''PWAIT_ALL_COMPONENTS_INITIALIZED'', N''QDS_PERSIST_TASK_MAIN_LOOP_SLEEP'',\n          N''QDS_ASYNC_QUEUE'', N''QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP'', N''HADR_CLUSAPI_CALL'',\n          N''HADR_LOGCAPTURE_WAIT'', N''HADR_WORK_QUEUE'', N''HADR_TIMER_TASK'', N''HADR_NOTIFICATION_DEQUEUE'',\n          N''PARALLEL_REDO_DRAIN_WORKER'', N''PARALLEL_REDO_LOG_CACHE'', N''PARALLEL_REDO_TRAN_LIST'',\n          N''PARALLEL_REDO_WORKER_SYNC'', N''PARALLEL_REDO_WORKER_WAIT_WORK'',\n          N''PREEMPTIVE_XE_GETTARGETSTATE'', N''PVS_PREALLOCATE'', N''VDI_CLIENT_OTHER'',\n          N''SOS_WORK_DISPATCHER'', N''PWAIT_EXTENSIBILITY_CLEANUP_TASK'', N''PREEMPTIVE_OS_FLUSHFILEBUFFERS'',\n          N''STARTUP_DEPENDENCY_MANAGER'', N''QDS_SHUTDOWN_QUEUE'', N''WAIT_XTP_HOST_WAIT'', N''WAIT_XTP_CKPT_CLOSE'')\n      AND wait_type NOT LIKE N''SLEEP_%''\n), tot AS (SELECT SUM(wait_time_ms) AS total_wait_ms FROM ws)\nSELECT TOP 30\n    ws.wait_type,\n    ws.waiting_tasks_count,\n    ws.wait_time_ms,\n    ws.resource_wait_ms,\n    ws.signal_wait_time_ms,\n    CAST(ws.wait_time_ms * 100.0 / NULLIF(tot.total_wait_ms, 0) AS decimal(5,2)) AS pct_of_total,\n    CAST(ws.signal_wait_time_ms * 100.0 / NULLIF(ws.wait_time_ms, 0) AS decimal(5,2)) AS signal_pct,\n    CAST(ws.wait_time_ms * 1.0 / NULLIF(ws.waiting_tasks_count, 0) AS decimal(12,1)) AS avg_wait_ms\nFROM ws CROSS JOIN tot\nORDER BY ws.wait_time_ms DESC"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Wait statistics captured"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-044-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-044-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-044-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-044-RC01 (sqlserver)', 'Wait statistics captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-044-RC01 (sqlserver)', '{"action": "Read the top resource waits by type family: PAGEIOLATCH_* = storage reads (correlate SYS-025 latency), WRITELOG = log write latency (SYS-011 log file), LCK_M_* = blocking (SYS-013), CXPACKET/CXCONSUMER = parallelism (review MAXDOP/cost threshold in SYS-015), RESOURCE_SEMAPHORE = memory grants (SYS-040 pending grants), SOS_SCHEDULER_YIELD + high overall signal_pct = CPU pressure (SYS-017/038), THREADPOOL = worker starvation (usually blocking). A high avg_wait_ms on a low-count wait is a different problem than many short waits - triage both. Clear with DBCC SQLPERF(Nsys.dm_os_wait_stats, CLEAR) to baseline a change window."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-044-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-044-RC01 (sqlserver)', 'resolve-hlth_sql_sys_044_rc01-sqlserver', 'Wait statistics captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_044_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_044_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'wait_type')                   AS wait_type,
    (j.value ->> 'waiting_tasks_count')::bigint AS waiting_tasks_count,
    (j.value ->> 'wait_time_ms')::bigint        AS wait_time_ms,
    (j.value ->> 'resource_wait_ms')::bigint    AS resource_wait_ms,
    (j.value ->> 'signal_wait_time_ms')::bigint AS signal_wait_time_ms,
    (j.value ->> 'pct_of_total')::numeric       AS pct_of_total,
    (j.value ->> 'signal_pct')::numeric         AS signal_pct,
    (j.value ->> 'avg_wait_ms')::numeric        AS avg_wait_ms,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-044-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_044_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_044_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-044-RC01';

COMMIT;
