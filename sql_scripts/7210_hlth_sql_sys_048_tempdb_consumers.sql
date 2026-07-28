-- ============================================================
-- 7210  HLTH-SQL-SYS-048-RC01  TempDB space consumers captured (sqlserver)
--   HEALTH system series root cause.
--   Enriched from the base dm_db_task_space_usage query:
--     * page counts converted to MB; outstanding user vs internal split kept
--       (the key diagnostic: explicit temp objects vs spills)
--     * added request status, elapsed/CPU, granted_query_memory (spill
--       correlation) and excluded the collector''s own spid
--     * statement offsets fixed to include the last character (base dropped
--       one); text capped at 4000
--   2005+. Requires VIEW SERVER STATE.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-048','HLTH','SQL','SYS','TempDB Space Consumers','tempdb-consumers',
        'Live requests currently consuming tempdb, ranked by outstanding user + internal object space, with the statement and session behind each.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-048-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-048-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-048-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-048-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-048-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-048-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-048-RC01', 'HLTH-SQL-SYS-048', 'TempDB space consumers captured',
    'tempdb-consumers-rc01',
    'Every active request holding tempdb space right now: session identity, execution-context database, outstanding USER-object MB (explicit #temp tables / table variables) vs INTERNAL-object MB (sorts, hashes, spools, spills), the combined total, request status/elapsed/CPU, open transaction count, granted query memory and the running statement. Zero rows = nothing consuming tempdb. The live who/what behind the tempdb-file pressure seen in SYS-047 and internal-object growth in SYS-022.',
    ARRAY['health', 'tempdb', 'memory', 'spills', 'sessions'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-048-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nSELECT TOP 100\n    tsu.session_id,\n    tsu.request_id,\n    s.login_name,\n    s.host_name,\n    s.program_name,\n    DB_NAME(st.dbid) AS exec_context_db,\n    CONVERT(bigint, tsu.user_objects_alloc_page_count - tsu.user_objects_dealloc_page_count) * 8 / 1024 AS outstanding_user_obj_mb,\n    CONVERT(bigint, tsu.internal_objects_alloc_page_count - tsu.internal_objects_dealloc_page_count) * 8 / 1024 AS outstanding_internal_obj_mb,\n    CONVERT(bigint, (tsu.user_objects_alloc_page_count - tsu.user_objects_dealloc_page_count)\n                  + (tsu.internal_objects_alloc_page_count - tsu.internal_objects_dealloc_page_count)) * 8 / 1024 AS outstanding_total_mb,\n    r.command,\n    r.status,\n    CONVERT(varchar(19), r.start_time, 120) AS start_time,\n    r.total_elapsed_time AS elapsed_ms,\n    r.cpu_time AS cpu_ms,\n    r.open_transaction_count,\n    CONVERT(bigint, r.granted_query_memory) * 8 / 1024 AS granted_memory_mb,\n    LEFT(SUBSTRING(st.text, r.statement_start_offset/2 + 1,\n        (CASE WHEN r.statement_end_offset = -1 THEN LEN(CONVERT(nvarchar(max), st.text)) * 2\n              ELSE r.statement_end_offset END - r.statement_start_offset)/2 + 1), 4000) AS query_text\nFROM sys.dm_db_task_space_usage tsu\nJOIN sys.dm_exec_requests r ON r.session_id = tsu.session_id AND r.request_id = tsu.request_id\nJOIN sys.dm_exec_sessions s ON s.session_id = tsu.session_id\nOUTER APPLY sys.dm_exec_sql_text(r.sql_handle) st\nWHERE (tsu.internal_objects_alloc_page_count + tsu.user_objects_alloc_page_count) > 0\n  AND tsu.session_id <> @@SPID AND s.is_user_process = 1\nORDER BY outstanding_total_mb DESC"}'::jsonb,
        '{"condition": "row_count > 0", "description": "TempDB consumers present (zero rows = tempdb idle)"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-048-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-048-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-048-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-048-RC01 (sqlserver)', 'TempDB space consumers captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-048-RC01 (sqlserver)', '{"action": "Large outstanding_internal_obj_mb means the query is SPILLING sorts/hashes to tempdb - a memory-grant or plan problem (missing index forcing a scan, bad cardinality estimate; correlate RESOURCE_SEMAPHORE waits in SYS-044 and granted_memory_mb); large outstanding_user_obj_mb is explicit #temp/table-variable usage - review the code for oversized temp sets; a single session with a huge total is what fills tempdb and can stall EVERY other tempdb user (this is the query to KILL or tune when tempdb is full); high open_transaction_count keeps the space held longer."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-048-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-048-RC01 (sqlserver)', 'resolve-hlth_sql_sys_048_rc01-sqlserver', 'TempDB space consumers captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_048_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_048_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'session_id')::int                 AS session_id,
    (j.value ->> 'request_id')::int                 AS request_id,
    (j.value ->> 'login_name')                      AS login_name,
    (j.value ->> 'host_name')                       AS host_name,
    (j.value ->> 'program_name')                    AS program_name,
    (j.value ->> 'exec_context_db')                 AS exec_context_db,
    (j.value ->> 'outstanding_user_obj_mb')::bigint AS outstanding_user_obj_mb,
    (j.value ->> 'outstanding_internal_obj_mb')::bigint AS outstanding_internal_obj_mb,
    (j.value ->> 'outstanding_total_mb')::bigint    AS outstanding_total_mb,
    (j.value ->> 'command')                         AS command,
    (j.value ->> 'status')                          AS status,
    (j.value ->> 'start_time')                      AS start_time,
    (j.value ->> 'elapsed_ms')::bigint              AS elapsed_ms,
    (j.value ->> 'cpu_ms')::bigint                  AS cpu_ms,
    (j.value ->> 'open_transaction_count')::int     AS open_transaction_count,
    (j.value ->> 'granted_memory_mb')::bigint       AS granted_memory_mb,
    (j.value ->> 'query_text')                      AS query_text,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-048-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_048_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_048_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-048-RC01';

COMMIT;
