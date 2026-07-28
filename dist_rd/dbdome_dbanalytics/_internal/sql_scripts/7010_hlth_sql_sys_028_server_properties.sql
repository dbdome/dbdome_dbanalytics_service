-- ============================================================
-- 7010  HLTH-SQL-SYS-028-RC01  Server properties captured (sqlserver)
--   HEALTH system series root cause.
--   Enriched from the base SERVERPROPERTY list:
--     * added ProductUpdateLevel (CU), IsHadrEnabled/HadrManagerStatus,
--       IsXTPSupported, FilestreamEffectiveLevel, default data/log paths,
--       LicenseType/NumLicenses
--     * every value CONVERTed to nvarchar so the sql_variant column
--       serializes consistently; @@VERSION flattened to one line
--     * install-date subquery returns ONE row (MIN over the two NT service
--       principals - the base could emit two rows)
--   2008+ (ProductUpdateLevel returns NULL where unsupported).
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-028','HLTH','SQL','SYS','Instance Identity & Properties','server-properties',
        'SERVERPROPERTY inventory: identity, edition, version/patch level, HA state, security mode, default paths and install date.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-028-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-028-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-028-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-028-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-028-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-028-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-028-RC01', 'HLTH-SQL-SYS-028', 'Server properties captured',
    'server-properties-rc01',
    'Instance identity and capability inventory as (property, value) rows: machine/server/instance names, physical NetBIOS node (detects failover movement on clusters), edition, product level/update/version, process id, collation, clustering and AlwaysOn state, full-text, authentication mode, XTP support, filestream level, default data/log paths, license info, @@VERSION and the install date (derived from the NT service principals creation time). Baseline for drift and patch-level checks.',
    ARRAY['health', 'inventory', 'version', 'edition', 'baseline'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-028-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nSELECT ''MachineName'' AS property_name, CONVERT(nvarchar(512), SERVERPROPERTY(''MachineName'')) AS property_value\nUNION ALL SELECT ''ServerName'' AS property_name, CONVERT(nvarchar(512), SERVERPROPERTY(''ServerName'')) AS property_value\nUNION ALL SELECT ''InstanceName'' AS property_name, CONVERT(nvarchar(512), SERVERPROPERTY(''InstanceName'')) AS property_value\nUNION ALL SELECT ''ComputerNamePhysicalNetBIOS'' AS property_name, CONVERT(nvarchar(512), SERVERPROPERTY(''ComputerNamePhysicalNetBIOS'')) AS property_value\nUNION ALL SELECT ''Edition'' AS property_name, CONVERT(nvarchar(512), SERVERPROPERTY(''Edition'')) AS property_value\nUNION ALL SELECT ''ProductLevel'' AS property_name, CONVERT(nvarchar(512), SERVERPROPERTY(''ProductLevel'')) AS property_value\nUNION ALL SELECT ''ProductUpdateLevel'' AS property_name, CONVERT(nvarchar(512), SERVERPROPERTY(''ProductUpdateLevel'')) AS property_value\nUNION ALL SELECT ''ProductVersion'' AS property_name, CONVERT(nvarchar(512), SERVERPROPERTY(''ProductVersion'')) AS property_value\nUNION ALL SELECT ''ProcessID'' AS property_name, CONVERT(nvarchar(512), SERVERPROPERTY(''ProcessID'')) AS property_value\nUNION ALL SELECT ''Collation'' AS property_name, CONVERT(nvarchar(512), SERVERPROPERTY(''Collation'')) AS property_value\nUNION ALL SELECT ''IsClustered'' AS property_name, CONVERT(nvarchar(512), SERVERPROPERTY(''IsClustered'')) AS property_value\nUNION ALL SELECT ''IsHadrEnabled'' AS property_name, CONVERT(nvarchar(512), SERVERPROPERTY(''IsHadrEnabled'')) AS property_value\nUNION ALL SELECT ''HadrManagerStatus'' AS property_name, CONVERT(nvarchar(512), SERVERPROPERTY(''HadrManagerStatus'')) AS property_value\nUNION ALL SELECT ''IsFullTextInstalled'' AS property_name, CONVERT(nvarchar(512), SERVERPROPERTY(''IsFullTextInstalled'')) AS property_value\nUNION ALL SELECT ''IsIntegratedSecurityOnly'' AS property_name, CONVERT(nvarchar(512), SERVERPROPERTY(''IsIntegratedSecurityOnly'')) AS property_value\nUNION ALL SELECT ''IsXTPSupported'' AS property_name, CONVERT(nvarchar(512), SERVERPROPERTY(''IsXTPSupported'')) AS property_value\nUNION ALL SELECT ''FilestreamEffectiveLevel'' AS property_name, CONVERT(nvarchar(512), SERVERPROPERTY(''FilestreamEffectiveLevel'')) AS property_value\nUNION ALL SELECT ''InstanceDefaultDataPath'' AS property_name, CONVERT(nvarchar(512), SERVERPROPERTY(''InstanceDefaultDataPath'')) AS property_value\nUNION ALL SELECT ''InstanceDefaultLogPath'' AS property_name, CONVERT(nvarchar(512), SERVERPROPERTY(''InstanceDefaultLogPath'')) AS property_value\nUNION ALL SELECT ''LicenseType'' AS property_name, CONVERT(nvarchar(512), SERVERPROPERTY(''LicenseType'')) AS property_value\nUNION ALL SELECT ''NumLicenses'' AS property_name, CONVERT(nvarchar(512), SERVERPROPERTY(''NumLicenses'')) AS property_value\nUNION ALL SELECT ''Version'', LEFT(REPLACE(REPLACE(@@VERSION, CHAR(13), '' ''), CHAR(10), '' ''), 512)\nUNION ALL SELECT ''InstallDate'',\n    (SELECT CONVERT(nvarchar(19), MIN(create_date), 120)\n     FROM sys.server_principals\n     WHERE name IN (N''NT AUTHORITY\\SYSTEM'', N''NT AUTHORITY\\NETWORK SERVICE''))"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Server properties captured"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-028-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-028-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-028-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-028-RC01 (sqlserver)', 'Server properties captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-028-RC01 (sqlserver)', '{"action": "ProductVersion/ProductUpdateLevel against the vendor CU list feeds patch-currency checks (HLTH-SQL-UP-002); a changed ComputerNamePhysicalNetBIOS between snapshots means the clustered instance failed over; IsIntegratedSecurityOnly = 0 means SQL logins are allowed - verify that is intended; watch Edition downgrades/upgrades and IsHadrEnabled flips as change-detection events."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-028-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-028-RC01 (sqlserver)', 'resolve-hlth_sql_sys_028_rc01-sqlserver', 'Server properties captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_sys_028_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'property_name')               AS property_name,
    (j.value ->> 'property_value')              AS property_value,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-028-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_028_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_028_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-028-RC01';

COMMIT;
