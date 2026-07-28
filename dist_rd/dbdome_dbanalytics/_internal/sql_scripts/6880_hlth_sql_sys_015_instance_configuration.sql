-- ============================================================
-- 6880  HLTH-SQL-SYS-015-RC01  Instance configuration captured (sqlserver)
--   HEALTH system series root cause.
--   Enriched from the base sys.configurations dump:
--     * pending_change flag: value <> value_in_use is the actionable finding
--       (RECONFIGURE pending on dynamic options, restart pending otherwise)
--     * sql_variant columns cast to bigint so they serialize cleanly
--     * NOLOCK / OPTION (RECOMPILE) dropped
--   2005+. No special permission needed beyond VIEW SERVER STATE-level access.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-015','HLTH','SQL','SYS','Instance Configuration Baseline','instance-configuration',
        'Full sys.configurations inventory each collection cycle: the baseline for configuration-drift detection and pending-change alerts.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-015-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-015-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-015-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-015-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-015-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-015-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-015-RC01', 'HLTH-SQL-SYS-015', 'Instance configuration captured',
    'instance-configuration-rc01',
    'Every sp_configure setting with configured vs in-use value, a pending_change flag (configured but not yet applied - RECONFIGURE pending or restart needed), min/max bounds, description, and whether the option is dynamic or advanced. Snapshots over time give configuration-drift detection (correlates with HLTH-SQL-CD change-detection issues).',
    ARRAY['health', 'configuration', 'drift', 'baseline'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-015-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nSELECT TOP 300\n    name,\n    CONVERT(bigint, value) AS configured_value,\n    CONVERT(bigint, value_in_use) AS value_in_use,\n    CASE WHEN CONVERT(bigint, value) <> CONVERT(bigint, value_in_use) THEN 1 ELSE 0 END AS pending_change,\n    CONVERT(bigint, minimum) AS minimum,\n    CONVERT(bigint, maximum) AS maximum,\n    description,\n    is_dynamic,\n    is_advanced\nFROM sys.configurations\nORDER BY name"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Instance configuration captured"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-015-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-015-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-015-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-015-RC01 (sqlserver)', 'Instance configuration captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-015-RC01 (sqlserver)', '{"action": "pending_change = 1 means someone changed a value that is not live: is_dynamic = 1 needs only RECONFIGURE, is_dynamic = 0 waits for an instance restart - either way it is an unfinished change to resolve deliberately; diff snapshots between collections to catch drift (max server memory, max degree of parallelism, cost threshold, xp_cmdshell and other security-sensitive toggles deserve alerts on ANY change)."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-015-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-015-RC01 (sqlserver)', 'resolve-hlth_sql_sys_015_rc01-sqlserver', 'Instance configuration captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_015_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_015_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'name')                        AS name,
    (j.value ->> 'configured_value')::bigint    AS configured_value,
    (j.value ->> 'value_in_use')::bigint        AS value_in_use,
    (j.value ->> 'pending_change')::int         AS pending_change,
    (j.value ->> 'minimum')::bigint             AS minimum,
    (j.value ->> 'maximum')::bigint             AS maximum,
    (j.value ->> 'description')                 AS description,
    (j.value ->> 'is_dynamic')::int             AS is_dynamic,
    (j.value ->> 'is_advanced')::int            AS is_advanced,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-015-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_015_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_015_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-015-RC01';

COMMIT;
