-- ============================================================
-- 7160  HLTH-SQL-SYS-043-RC01  Server services status captured (sqlserver)
--   HEALTH system series root cause.
--   Replaces the base xp_servicecontrol / xp_instance_regread approach,
--   which is WINDOWS-ONLY and returns a message result the collector cannot
--   read:
--     * sys.dm_server_services is cross-platform (2008 R2 SP1+) and returns
--       a clean rowset for every SQL service (engine/agent/full-text) with
--       status, startup type, account, clustering and binary path
--     * guarded with an empty shape on servers predating the DMV
--   Requires VIEW SERVER STATE.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-043','HLTH','SQL','SYS','SQL Server Services Status','server-services-status',
        'State, startup type and service account of the SQL Server services (Engine, Agent, Full-Text) via the cross-platform dm_server_services.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-043-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-043-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-043-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-043-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-043-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-043-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-043-RC01', 'HLTH-SQL-SYS-043', 'Server services status captured',
    'server-services-status-rc01',
    'Each SQL Server service the instance knows about (Database Engine, SQL Agent, Full-Text) with running status, startup type (Automatic/Manual/Disabled), process id, last startup time, the service account it runs under, clustering flag/node and the binary path. Cross-platform (works on Linux). Surfaces a stopped or disabled Agent, unexpected startup types and the service-account identity for least-privilege review.',
    ARRAY['health', 'services', 'agent', 'startup', 'inventory'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-043-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nIF OBJECT_ID(N''sys.dm_server_services'') IS NULL\nBEGIN\n    SELECT CAST(NULL AS nvarchar(256)) AS servicename, CAST(NULL AS nvarchar(60)) AS status,\n           CAST(NULL AS nvarchar(60)) AS startup_type, CAST(NULL AS int) AS process_id,\n           CAST(NULL AS varchar(19)) AS last_startup_time, CAST(NULL AS nvarchar(256)) AS service_account,\n           CAST(NULL AS int) AS is_clustered, CAST(NULL AS nvarchar(256)) AS cluster_nodename,\n           CAST(NULL AS nvarchar(512)) AS filename\n    WHERE 1 = 0;\n    RETURN;\nEND;\nSELECT\n    servicename,\n    status_desc AS status,\n    startup_type_desc AS startup_type,\n    process_id,\n    CONVERT(varchar(19), last_startup_time, 120) AS last_startup_time,\n    service_account,\n    CASE WHEN is_clustered = N''Y'' THEN 1 ELSE 0 END AS is_clustered,\n    cluster_nodename,\n    filename\nFROM sys.dm_server_services"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Server services captured (empty on pre-2008R2SP1 where the DMV is absent)"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-043-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-043-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-043-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-043-RC01 (sqlserver)', 'Server services status captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-043-RC01 (sqlserver)', '{"action": "SQL Agent service Stopped or startup_type Manual/Disabled explains why scheduled jobs are not running (this is exactly the SYS-006/029 gap on this instance) - set Automatic and start it; a service_account that is a high-privilege domain admin or LocalSystem is a least-privilege finding (use a dedicated MSA/gMSA); last_startup_time jumping unexpectedly means the service restarted (correlate the errorlog SYS-026 and the instance uptime in SYS-001); startup_type Manual on the Engine risks the instance not coming back after a host reboot."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-043-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-043-RC01 (sqlserver)', 'resolve-hlth_sql_sys_043_rc01-sqlserver', 'Server services status captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_043_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_043_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'servicename')                 AS servicename,
    (j.value ->> 'status')                      AS status,
    (j.value ->> 'startup_type')                AS startup_type,
    (j.value ->> 'process_id')::int             AS process_id,
    (j.value ->> 'last_startup_time')           AS last_startup_time,
    (j.value ->> 'service_account')             AS service_account,
    (j.value ->> 'is_clustered')::int           AS is_clustered,
    (j.value ->> 'cluster_nodename')            AS cluster_nodename,
    (j.value ->> 'filename')                    AS filename,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-043-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_043_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_043_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-043-RC01';

COMMIT;
