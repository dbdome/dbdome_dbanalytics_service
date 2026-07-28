DROP VIEW IF EXISTS monitoring.v_sec_sql_az_003_rc12;

-- ============================================================
-- View: monitoring.v_sec_sql_az_003_rc12
-- Root cause: SEC-SQL-AZ-003-RC12
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc12 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'grantee',
        j.value ->> 'name'
    ) AS username,
    to_timestamp((j.value ->> 'granted_role')::bigint / 3.0) AS granted_role,
    j.value ->> 'admin_option' AS admin_option,
    j.value ->> 'delegate_option' AS delegate_option,
    j.value ->> 'default_role' AS default_role,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    j.value ->> 'role_membership' AS role_membership,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolvaliduntil' AS rolvaliduntil,
    j.value ->> 'rolconnlimit' AS rolconnlimit,
    j.value ->> 'description' AS description,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-003-RC12'
