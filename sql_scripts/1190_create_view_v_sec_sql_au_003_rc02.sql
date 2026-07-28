DROP VIEW IF EXISTS monitoring.v_sec_sql_au_003_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_au_003_rc02
-- Root cause: SEC-SQL-AU-003-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc02 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'is_sysadmin' AS is_sysadmin,
    j.value ->> 'is_securityadmin' AS is_securityadmin,
    j.value ->> 'status' AS state,
    j.value ->> 'profile' AS profile,
    j.value ->> 'limit' AS limit,
    j.value ->> 'is_blank' AS is_blank,
    j.value ->> 'is_password' AS is_password,
    j.value ->> 'is_password1' AS is_password1,
    j.value ->> 'is_123456' AS is_123456,
    j.value ->> 'is_same_as_login' AS is_same_as_login,
    j.value ->> 'is_passw0rd' AS is_passw0rd,
    j.value ->> 'is_admin' AS is_admin,
    j.value ->> 'is_sa' AS is_sa,
    j.value ->> 'resource_name' AS resource_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-003-RC02'
