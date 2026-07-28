-- ============================================================
-- 7180  HLTH-SQL-SYS-045-RC01  SQL login inventory captured (sqlserver)
--   HEALTH system series root cause.
--   Reworked from the base sys.sql_logins dump (which selected the raw
--   password_hash - never export credential material):
--     * password_hash replaced with LOGINPROPERTY PasswordHashAlgorithm
--       (weak-hash detection without exfiltrating the hash) + a
--       password_is_null flag
--     * credential_id resolved to the mapped credential NAME
--     * sid rendered as hex; ## system logins excluded as in the base
--   Overlaps SYS-037 on the policy flags but adds the identity/mapping
--   inventory. 2005+ (hash algorithm 2008+). Requires CONTROL SERVER-level.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-045','HLTH','SQL','SYS','SQL Login Inventory','sql-login-inventory',
        'Full inventory of SQL-authenticated logins: identity, SID, default database/language, mapped credential, policy flags and password hash algorithm.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-045-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-045-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-045-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-045-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-045-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-045-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-045-RC01', 'HLTH-SQL-SYS-045', 'SQL login inventory captured',
    'sql-login-inventory-rc01',
    'Every SQL login (system ## logins excluded) with: principal id, SID, type, disabled flag, create/modify dates, default database and language, any mapped server credential, the policy/expiration enforcement flags and the password HASH ALGORITHM (via LOGINPROPERTY - the raw hash is never exported). Complements SYS-037 (password hygiene scoring) with the identity/mapping inventory used for drift detection and least-privilege review.',
    ARRAY['health', 'security', 'logins', 'inventory', 'credentials'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-045-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nSELECT TOP 500\n    l.name AS login_name,\n    l.principal_id,\n    CONVERT(varchar(85), l.sid, 1) AS sid,\n    l.type_desc AS login_type,\n    l.is_disabled,\n    CONVERT(varchar(19), l.create_date, 120) AS create_date,\n    CONVERT(varchar(19), l.modify_date, 120) AS modify_date,\n    l.default_database_name,\n    l.default_language_name,\n    cr.name AS mapped_credential,\n    l.is_policy_checked,\n    l.is_expiration_checked,\n    CONVERT(int, LOGINPROPERTY(l.name, ''PasswordHashAlgorithm'')) AS password_hash_algorithm,\n    CASE WHEN l.password_hash IS NULL THEN 1 ELSE 0 END AS password_is_null\nFROM sys.sql_logins l\nLEFT JOIN sys.credentials cr ON cr.credential_id = l.credential_id\nWHERE l.name NOT LIKE ''##%''\nORDER BY l.name"}'::jsonb,
        '{"condition": "row_count > 0", "description": "SQL logins present (zero rows = Windows-auth only)"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-045-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-045-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-045-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-045-RC01 (sqlserver)', 'SQL login inventory captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-045-RC01 (sqlserver)', '{"action": "password_hash_algorithm below 2 means a pre-SQL-2012 SHA-1 hash (weak - force a password change to upgrade it to SHA-512); a mapped_credential ties the login to an external identity (Azure key vault, proxy account) - audit those grants; default_database of a dropped database silently fails logins; SID and create_date are the drift-detection anchors (a login reappearing with a new SID after a restore is the orphaned-user cause in SYS-035); the raw password_hash is deliberately NOT exported - only its algorithm."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-045-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-045-RC01 (sqlserver)', 'resolve-hlth_sql_sys_045_rc01-sqlserver', 'SQL login inventory captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_045_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_045_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'login_name')                  AS login_name,
    (j.value ->> 'principal_id')::bigint        AS principal_id,
    (j.value ->> 'sid')                         AS sid,
    (j.value ->> 'login_type')                  AS login_type,
    (j.value ->> 'is_disabled')::int            AS is_disabled,
    (j.value ->> 'create_date')                 AS create_date,
    (j.value ->> 'modify_date')                 AS modify_date,
    (j.value ->> 'default_database_name')       AS default_database_name,
    (j.value ->> 'default_language_name')       AS default_language_name,
    (j.value ->> 'mapped_credential')           AS mapped_credential,
    (j.value ->> 'is_policy_checked')::int      AS is_policy_checked,
    (j.value ->> 'is_expiration_checked')::int  AS is_expiration_checked,
    (j.value ->> 'password_hash_algorithm')::int AS password_hash_algorithm,
    (j.value ->> 'password_is_null')::int       AS password_is_null,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-045-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_045_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_045_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-045-RC01';

COMMIT;
