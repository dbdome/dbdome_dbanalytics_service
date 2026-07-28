-- ============================================================
-- 7100  HLTH-SQL-SYS-037-RC01  SQL login password hygiene captured (sqlserver)
--   HEALTH system series root cause.
--   Enriched from the base sys.sql_logins policy-flags query:
--     * LOGINPROPERTY facts: password last-set time + age in days,
--       IsLocked, IsMustChange, BadPasswordCount
--     * PWDCOMPARE weakness probes: blank password and password = login
--       name (needs password_hash visibility - sysadmin/CONTROL SERVER,
--       which the collector has); NULL hashes compare safely to 0
--     * disabled flag, default database, create/modify dates
--     * weakest-first ordering
--   2005+. Requires CONTROL SERVER-level access for password_hash.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-037','HLTH','SQL','SYS','SQL Login Password Hygiene','sql-login-password-policy',
        'Password policy, age and weakness audit for every SQL login: policy/expiration enforcement, password age, lockout state, blank and name-equal passwords.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-037-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-037-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-037-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-037-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-037-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-037-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-037-RC01', 'HLTH-SQL-SYS-037', 'SQL login password hygiene captured',
    'sql-login-password-policy-rc01',
    'Every SQL login with: policy and expiration enforcement flags, disabled state, default database, creation/modification dates, password last-set time and AGE in days, locked-out / must-change / bad-password-count state, and two direct weakness probes via PWDCOMPARE - has_blank_password and password_equals_name. Weakest logins sort first. Correlates with the SEC-SQL authentication families.',
    ARRAY['health', 'security', 'logins', 'passwords', 'policy'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-037-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nSELECT TOP 500\n    l.name AS login_name,\n    l.is_disabled,\n    l.is_policy_checked,\n    l.is_expiration_checked,\n    l.default_database_name,\n    CONVERT(varchar(19), l.create_date, 120) AS create_date,\n    CONVERT(varchar(19), l.modify_date, 120) AS modify_date,\n    CONVERT(varchar(19), CONVERT(datetime, LOGINPROPERTY(l.name, ''PasswordLastSetTime'')), 120) AS password_last_set,\n    DATEDIFF(DAY, CONVERT(datetime, LOGINPROPERTY(l.name, ''PasswordLastSetTime'')), GETDATE()) AS password_age_days,\n    CONVERT(int, LOGINPROPERTY(l.name, ''IsLocked'')) AS is_locked,\n    CONVERT(int, LOGINPROPERTY(l.name, ''IsMustChange'')) AS must_change,\n    CONVERT(int, LOGINPROPERTY(l.name, ''BadPasswordCount'')) AS bad_password_count,\n    CASE WHEN PWDCOMPARE(N'''', l.password_hash) = 1 THEN 1 ELSE 0 END AS has_blank_password,\n    CASE WHEN PWDCOMPARE(l.name, l.password_hash) = 1 THEN 1 ELSE 0 END AS password_equals_name\nFROM sys.sql_logins l\nORDER BY has_blank_password DESC, password_equals_name DESC, l.is_policy_checked ASC, l.name"}'::jsonb,
        '{"condition": "row_count > 0", "description": "SQL logins present (zero rows = no SQL logins, Windows-auth only)"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-037-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-037-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-037-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-037-RC01 (sqlserver)', 'SQL login password hygiene captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-037-RC01 (sqlserver)', '{"action": "has_blank_password = 1 or password_equals_name = 1 on an ENABLED login is a drop-everything finding; is_policy_checked = 0 means complexity/lockout rules do not apply to that login (fix with ALTER LOGIN ... CHECK_POLICY = ON - note it only takes effect on the next password change); password_age_days in the thousands on service accounts deserves a rotation plan; rising bad_password_count on sa suggests a brute-force attempt (correlate SEC-SQL-AUD-022 failed logins); consider disabling sa entirely and renaming it."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-037-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-037-RC01 (sqlserver)', 'resolve-hlth_sql_sys_037_rc01-sqlserver', 'SQL login password hygiene captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_037_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_037_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'login_name')                  AS login_name,
    (j.value ->> 'is_disabled')::int            AS is_disabled,
    (j.value ->> 'is_policy_checked')::int      AS is_policy_checked,
    (j.value ->> 'is_expiration_checked')::int  AS is_expiration_checked,
    (j.value ->> 'default_database_name')       AS default_database_name,
    (j.value ->> 'create_date')                 AS create_date,
    (j.value ->> 'modify_date')                 AS modify_date,
    (j.value ->> 'password_last_set')           AS password_last_set,
    (j.value ->> 'password_age_days')::int      AS password_age_days,
    (j.value ->> 'is_locked')::int              AS is_locked,
    (j.value ->> 'must_change')::int            AS must_change,
    (j.value ->> 'bad_password_count')::int     AS bad_password_count,
    (j.value ->> 'has_blank_password')::int     AS has_blank_password,
    (j.value ->> 'password_equals_name')::int   AS password_equals_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-037-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_037_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_037_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-037-RC01';

COMMIT;
