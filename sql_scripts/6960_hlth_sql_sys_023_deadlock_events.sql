-- ============================================================
-- 6960  HLTH-SQL-SYS-023-RC01  Deadlock events captured from system_health (sqlserver)
--   HEALTH system series root cause.
--   Replaces the base dm_tran_locks/request_mode=IS query, which listed
--   ordinary intent-shared locks currently held - not deadlocks (held-lock
--   inventory is covered by HLTH-SQL-SYS-012/013). Real deadlock evidence:
--     * system_health EVENT FILE xml_deadlock_report events (the ring
--       buffer was observed holding ZERO deadlocks right after a real one -
--       its serialization cap silently drops them; the .xel files do not),
--       shredded to one row per deadlock: local-time timestamp, process
--       count, victim login/host/program/isolation/statement, full graph
--   2012+ (fn_xe_file_target_read_file with NULL path). VIEW SERVER STATE.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-023','HLTH','SQL','SYS','Deadlock Detection','deadlock-events',
        'Actual deadlock events from the system_health Extended Events session, with the victim identity and the full deadlock graph.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-023-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-023-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-023-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-023-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-023-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-023-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-023-RC01', 'HLTH-SQL-SYS-023', 'Deadlock events captured from system_health',
    'deadlock-events-rc01',
    'Every xml_deadlock_report in the system_health event files: event time (converted to server local time), number of processes involved, the VICTIM process identity (login, host, program, isolation level, last statement) and the complete deadlock graph XML for root-cause work. Zero rows = no deadlocks in the retained files. Event-file retention (typically 5 x 100MB rollover) far outlasts the ring buffer, which was observed dropping deadlock events entirely.',
    ARRAY['health', 'deadlocks', 'locking', 'xevents'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-023-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nSELECT TOP 100\n    CONVERT(varchar(19), DATEADD(MINUTE, DATEDIFF(MINUTE, GETUTCDATE(), GETDATE()), e.n.value(''@timestamp'', ''datetime'')), 120) AS event_time,\n    dl.n.value(''count(process-list/process)'', ''int'') AS process_count,\n    dl.n.value(''(victim-list/victimProcess/@id)[1]'', ''nvarchar(64)'') AS victim_process_id,\n    vp.n.value(''@loginname'', ''nvarchar(128)'') AS victim_login,\n    vp.n.value(''@hostname'', ''nvarchar(128)'') AS victim_host,\n    vp.n.value(''@clientapp'', ''nvarchar(256)'') AS victim_program,\n    vp.n.value(''@isolationlevel'', ''nvarchar(64)'') AS victim_isolation,\n    LEFT(vp.n.value(''(inputbuf/text())[1]'', ''nvarchar(4000)''), 4000) AS victim_statement,\n    LEFT(CONVERT(nvarchar(max), dl.n.query(''.'')), 4000) AS deadlock_graph\nFROM (\n    SELECT CAST(event_data AS xml) AS x\n    FROM sys.fn_xe_file_target_read_file(N''system_health*.xel'', NULL, NULL, NULL)\n    WHERE object_name = N''xml_deadlock_report''\n) f\nCROSS APPLY f.x.nodes(''event'') e(n)\nCROSS APPLY e.n.nodes(''data/value/deadlock'') dl(n)\nOUTER APPLY dl.n.nodes(''process-list/process[@id=(../../victim-list/victimProcess/@id)[1]]'') vp(n)\nORDER BY e.n.value(''@timestamp'', ''datetime'') DESC"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Deadlock events present in system_health files (zero rows = none recorded)"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-023-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-023-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-023-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-023-RC01 (sqlserver)', 'Deadlock events captured from system_health', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-023-RC01 (sqlserver)', '{"action": "Read the graph: the resources section names the objects/indexes both sides wanted - consistent lock ORDER in application code is the usual fix; victim_isolation above ReadCommitted widens lock footprints; frequent deadlocks on the same index pair may be resolved with a covering index that removes the lookup; the victim was chosen as cheapest to roll back - the OTHER process usually holds the design problem."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-023-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-023-RC01 (sqlserver)', 'resolve-hlth_sql_sys_023_rc01-sqlserver', 'Deadlock events captured from system_health: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_023_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_023_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'event_time')                  AS event_time,
    (j.value ->> 'process_count')::int          AS process_count,
    (j.value ->> 'victim_process_id')           AS victim_process_id,
    (j.value ->> 'victim_login')                AS victim_login,
    (j.value ->> 'victim_host')                 AS victim_host,
    (j.value ->> 'victim_program')              AS victim_program,
    (j.value ->> 'victim_isolation')            AS victim_isolation,
    (j.value ->> 'victim_statement')            AS victim_statement,
    (j.value ->> 'deadlock_graph')              AS deadlock_graph,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-023-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_023_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_023_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-023-RC01';

COMMIT;
