-- ============================================================
-- 7250  HLTH-SQL-SYS-052-RC01  Windows & external logins captured (sqlserver)
--   HEALTH system series root cause.
--   Enriched from the base Windows-logins query:
--     * broadened beyond WINDOWS_LOGIN/GROUP to cover EXTERNAL (Azure AD)
--       and certificate/asymmetric-key-mapped logins - every non-SQL login
--       type (SQL logins are SYS-045)
--     * added is_group (a group = access for all its members), default
--       database/language, sysadmin/securityadmin flags and the fixed-server-
--       role list (IS_SRVROLEMEMBER + server_role_members)
--     * highest-privilege-first ordering; ## system logins excluded
--   2005+ (EXTERNAL types 2016+, harmless where absent). Metadata access.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-052','HLTH','SQL','SYS','Windows & External Login Inventory','windows-external-logins',
        'Inventory of every non-SQL login (Windows login/group, Azure AD, certificate/key-mapped) with disabled state, default database and fixed-server-role membership.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-052-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-052-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-052-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-052-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-052-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-052-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-052-RC01', 'HLTH-SQL-SYS-052', 'Windows & external logins captured',
    'windows-external-logins-rc01',
    'Every login that is NOT a SQL login (## system logins excluded): Windows logins and GROUPS, Azure AD external logins/groups, and certificate/asymmetric-key-mapped logins - with type, a group flag, disabled state, create/modify dates, default database and language, sysadmin/securityadmin flags and the full list of fixed server roles held. Highest-privilege first. The complement to SYS-045 (SQL logins) - together they inventory every login on the instance for least-privilege and drift review.',
    ARRAY['health', 'security', 'logins', 'windows', 'inventory'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-052-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nSELECT TOP 500\n    sp.name AS login_name,\n    sp.type_desc AS login_type,\n    CASE WHEN sp.type_desc IN (''WINDOWS_GROUP'', ''EXTERNAL_GROUP'') THEN 1 ELSE 0 END AS is_group,\n    sp.is_disabled,\n    CONVERT(varchar(19), sp.create_date, 120) AS create_date,\n    CONVERT(varchar(19), sp.modify_date, 120) AS modify_date,\n    sp.default_database_name,\n    sp.default_language_name,\n    CONVERT(int, IS_SRVROLEMEMBER(''sysadmin'', sp.name)) AS is_sysadmin,\n    CONVERT(int, IS_SRVROLEMEMBER(''securityadmin'', sp.name)) AS is_securityadmin,\n    STUFF((SELECT '', '' + r.name\n           FROM sys.server_role_members rm\n           JOIN sys.server_principals r ON r.principal_id = rm.role_principal_id\n           WHERE rm.member_principal_id = sp.principal_id\n           FOR XML PATH('''')), 1, 2, '''') AS server_roles\nFROM sys.server_principals sp\nWHERE sp.type_desc IN (''WINDOWS_LOGIN'', ''WINDOWS_GROUP'', ''EXTERNAL_LOGIN'', ''EXTERNAL_GROUP'',\n                       ''CERTIFICATE_MAPPED_LOGIN'', ''ASYMMETRIC_KEY_MAPPED_LOGIN'')\n  AND sp.name NOT LIKE ''##%''\nORDER BY is_sysadmin DESC, is_group DESC, sp.name"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Windows/external logins present (zero rows = SQL-auth only instance)"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-052-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-052-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-052-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-052-RC01 (sqlserver)', 'Windows & external logins captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-052-RC01 (sqlserver)', '{"action": "is_group = 1 is the highest-leverage row: a Windows/AD GROUP grants SQL access to EVERY current and future member - review the group membership in AD, not just here (a group in sysadmin is a standing backdoor); is_sysadmin = 1 on any login is the crown-jewel grant - keep the list short and named; disabled Windows logins whose AD account was deleted become orphaned SIDs (validate with xp_logininfo on Windows before dropping); a modify_date change on a privileged login is a change-detection event (correlate SEC-SQL-AUD-026); default_database of a dropped database silently fails the login."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-052-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-052-RC01 (sqlserver)', 'resolve-hlth_sql_sys_052_rc01-sqlserver', 'Windows & external logins captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_052_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_052_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'login_name')                  AS login_name,
    (j.value ->> 'login_type')                  AS login_type,
    (j.value ->> 'is_group')::int               AS is_group,
    (j.value ->> 'is_disabled')::int            AS is_disabled,
    (j.value ->> 'create_date')                 AS create_date,
    (j.value ->> 'modify_date')                 AS modify_date,
    (j.value ->> 'default_database_name')       AS default_database_name,
    (j.value ->> 'default_language_name')       AS default_language_name,
    (j.value ->> 'is_sysadmin')::int            AS is_sysadmin,
    (j.value ->> 'is_securityadmin')::int       AS is_securityadmin,
    (j.value ->> 'server_roles')                AS server_roles,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-052-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_052_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_052_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-052-RC01';

COMMIT;
