-- ============================================================
-- 7050  HLTH-SQL-SYS-032-RC01  Server permissions & role memberships captured (sqlserver)
--   HEALTH system series root cause.
--   Enriched from the base server_permissions query:
--     * UNIONed sys.server_role_members - role memberships (sysadmin etc.)
--       do NOT appear in server_permissions, so the base query missed the
--       highest privileges on the instance
--     * added is_disabled and the permission class_desc (scope: server,
--       endpoint, login, availability group)
--   2005+ (2012+ for user-defined server roles). No special permission
--   needed beyond VIEW ANY DEFINITION-level metadata access.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-032','HLTH','SQL','SYS','Server Permission Inventory','server-permissions-inventory',
        'Server-level permissions AND server role memberships per principal - the complete instance-level privilege picture.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-032-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-032-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-032-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-032-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-032-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-032-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-032-RC01', 'HLTH-SQL-SYS-032', 'Server permissions & role memberships captured',
    'server-permissions-inventory-rc01',
    'Every server principal with both its explicit server permissions (name, GRANT/DENY/GRANT_WITH_GRANT state, scope class) and its server ROLE memberships (sysadmin, securityadmin, ...) - the roles never show in sys.server_permissions, so the base query missed the most powerful grants entirely. Includes the disabled flag. Baseline for privilege-drift detection; correlates with the SEC-SQL access-control families.',
    ARRAY['health', 'security', 'permissions', 'logins', 'roles'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-032-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nSELECT TOP 1000 login_name, login_type, is_disabled, grant_kind, granted, state_or_role, scope\nFROM (\n    SELECT pr.name COLLATE DATABASE_DEFAULT AS login_name,\n           pr.type_desc COLLATE DATABASE_DEFAULT AS login_type,\n           pr.is_disabled,\n           ''PERMISSION'' AS grant_kind,\n           pe.permission_name COLLATE DATABASE_DEFAULT AS granted,\n           pe.state_desc COLLATE DATABASE_DEFAULT AS state_or_role,\n           pe.class_desc COLLATE DATABASE_DEFAULT AS scope\n    FROM sys.server_permissions pe\n    JOIN sys.server_principals pr ON pr.principal_id = pe.grantee_principal_id\n    UNION ALL\n    SELECT pr.name COLLATE DATABASE_DEFAULT,\n           pr.type_desc COLLATE DATABASE_DEFAULT,\n           pr.is_disabled,\n           ''SERVER_ROLE'',\n           r.name COLLATE DATABASE_DEFAULT,\n           ''MEMBER'',\n           ''SERVER''\n    FROM sys.server_role_members rm\n    JOIN sys.server_principals pr ON pr.principal_id = rm.member_principal_id\n    JOIN sys.server_principals r ON r.principal_id = rm.role_principal_id\n) x\nORDER BY login_name, grant_kind, granted"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Server principals with permissions or roles captured"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-032-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-032-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-032-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-032-RC01 (sqlserver)', 'Server permissions & role memberships captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-032-RC01 (sqlserver)', '{"action": "Review SERVER_ROLE rows first - sysadmin/securityadmin membership dwarfs any explicit permission; CONTROL SERVER granted as a PERMISSION is sysadmin in disguise; GRANT_WITH_GRANT_OPTION lets the grantee re-grant (privilege sprawl); disabled logins retaining permissions are dormant risk (drop or document); diff snapshots between collections to catch privilege drift and correlate with SEC-SQL-AUD-026 privilege-escalation detections."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-032-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-032-RC01 (sqlserver)', 'resolve-hlth_sql_sys_032_rc01-sqlserver', 'Server permissions & role memberships captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_032_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_032_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'login_name')                  AS login_name,
    (j.value ->> 'login_type')                  AS login_type,
    (j.value ->> 'is_disabled')::int            AS is_disabled,
    (j.value ->> 'grant_kind')                  AS grant_kind,
    (j.value ->> 'granted')                     AS granted,
    (j.value ->> 'state_or_role')               AS state_or_role,
    (j.value ->> 'scope')                       AS scope,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-032-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_032_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_032_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-032-RC01';

COMMIT;
