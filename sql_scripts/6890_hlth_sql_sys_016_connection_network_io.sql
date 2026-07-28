-- ============================================================
-- 6890  HLTH-SQL-SYS-016-RC01  Connections with network I/O captured (sqlserver)
--   HEALTH system series root cause.
--   Enriched from the base connections/sessions join:
--     * added session_id (absent from the base column list), auth_scheme,
--       encrypt_option (unencrypted-connection finding), protocol_type,
--       connect_time, original_login_name kept for impersonation detection
--     * memory_usage pages converted to KB, times labeled as ms,
--       datetimes normalized; DB context via sysprocesses fallback (the
--       dm_exec_sessions.database_id column needs 2012+)
--     * excludes system sessions and the collector; TOP 500 by packet volume
--   2005+. Requires VIEW SERVER STATE.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-016','HLTH','SQL','SYS','Connection & Network I/O Profile','connection-network-io',
        'Inventory of live connections with their network transport, encryption, auth scheme and packet I/O counters: who is connected, over what, and how chatty.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-016-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-016-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-016-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-016-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-016-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-016-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-016-RC01', 'HLTH-SQL-SYS-016', 'Connections with network I/O captured',
    'connection-network-io-rc01',
    'Every user connection with session identity (login, original_login for impersonation, host, program, interface), transport/protocol, auth scheme, ENCRYPTION state, client address, packet size, network read/write counts and timestamps, per-session CPU/memory/elapsed/scheduled time and current database. Ordered by network packet volume. Feeds chatty-app, unencrypted-connection and idle-connection health checks.',
    ARRAY['health', 'connections', 'network', 'encryption', 'sessions'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-016-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nSELECT TOP 500\n    s.session_id,\n    s.host_name,\n    s.program_name,\n    s.client_interface_name,\n    c.net_transport,\n    c.protocol_type,\n    c.auth_scheme,\n    c.encrypt_option,\n    c.client_net_address,\n    c.local_net_address,\n    c.local_tcp_port,\n    c.net_packet_size,\n    c.num_reads,\n    c.num_writes,\n    CONVERT(varchar(19), c.connect_time, 120) AS connect_time,\n    CONVERT(varchar(19), c.last_read, 120) AS last_read,\n    CONVERT(varchar(19), c.last_write, 120) AS last_write,\n    CONVERT(varchar(19), s.login_time, 120) AS login_time,\n    s.login_name,\n    s.original_login_name,\n    s.cpu_time AS cpu_time_ms,\n    s.memory_usage * 8 AS memory_kb,\n    s.total_elapsed_time AS total_elapsed_ms,\n    s.total_scheduled_time AS total_scheduled_ms,\n    CONVERT(varchar(19), s.last_request_start_time, 120) AS last_request_start_time,\n    CONVERT(varchar(19), s.last_request_end_time, 120) AS last_request_end_time,\n    DB_NAME(sp.dbid) AS database_name\nFROM sys.dm_exec_connections c\nJOIN sys.dm_exec_sessions s ON s.session_id = c.session_id\nLEFT JOIN master.dbo.sysprocesses sp ON sp.spid = s.session_id AND sp.ecid = 0\nWHERE s.is_user_process = 1 AND s.session_id <> @@SPID\nORDER BY c.num_reads + c.num_writes DESC"}'::jsonb,
        '{"condition": "row_count > 0", "description": "User connections captured with network I/O detail"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-016-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-016-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-016-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-016-RC01 (sqlserver)', 'Connections with network I/O captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-016-RC01 (sqlserver)', '{"action": "num_reads/num_writes are packet counts: a top-ranked chatty app with tiny requests needs batching or fewer round-trips (compare net_packet_size); encrypt_option = FALSE on connections crossing untrusted networks is a security finding (force encryption or fix the client); original_login_name differing from login_name reveals impersonation chains worth auditing; last_read/last_write long ago on an open connection = idle connection pool candidates."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-016-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-016-RC01 (sqlserver)', 'resolve-hlth_sql_sys_016_rc01-sqlserver', 'Connections with network I/O captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_016_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_016_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'session_id')::int             AS session_id,
    (j.value ->> 'host_name')                   AS host_name,
    (j.value ->> 'program_name')                AS program_name,
    (j.value ->> 'client_interface_name')       AS client_interface_name,
    (j.value ->> 'net_transport')               AS net_transport,
    (j.value ->> 'protocol_type')               AS protocol_type,
    (j.value ->> 'auth_scheme')                 AS auth_scheme,
    (j.value ->> 'encrypt_option')              AS encrypt_option,
    (j.value ->> 'client_net_address')          AS client_net_address,
    (j.value ->> 'local_net_address')           AS local_net_address,
    (j.value ->> 'local_tcp_port')::int         AS local_tcp_port,
    (j.value ->> 'net_packet_size')::int        AS net_packet_size,
    (j.value ->> 'num_reads')::bigint           AS num_reads,
    (j.value ->> 'num_writes')::bigint          AS num_writes,
    (j.value ->> 'connect_time')                AS connect_time,
    (j.value ->> 'last_read')                   AS last_read,
    (j.value ->> 'last_write')                  AS last_write,
    (j.value ->> 'login_time')                  AS login_time,
    (j.value ->> 'login_name')                  AS login_name,
    (j.value ->> 'original_login_name')         AS original_login_name,
    (j.value ->> 'cpu_time_ms')::bigint         AS cpu_time_ms,
    (j.value ->> 'memory_kb')::bigint           AS memory_kb,
    (j.value ->> 'total_elapsed_ms')::bigint    AS total_elapsed_ms,
    (j.value ->> 'total_scheduled_ms')::bigint  AS total_scheduled_ms,
    (j.value ->> 'last_request_start_time')     AS last_request_start_time,
    (j.value ->> 'last_request_end_time')       AS last_request_end_time,
    (j.value ->> 'database_name')               AS database_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-016-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_016_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_016_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-016-RC01';

COMMIT;
