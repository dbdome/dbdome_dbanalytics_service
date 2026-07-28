DROP VIEW IF EXISTS monitoring.v_sec_sql_az_003_rc10;

-- ============================================================
-- View: monitoring.v_sec_sql_az_003_rc10
-- Root cause: SEC-SQL-AZ-003-RC10
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc10 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    to_timestamp((j.value ->> 'password_last_changed')::bigint / 3.0) AS password_last_changed,
    j.value ->> 'password_age_days' AS password_age_days,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'account_age_days' AS account_age_days,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolvaliduntil' AS rolvaliduntil,
    j.value ->> 'description' AS description,
    j.value ->> 'account_status' AS account_status,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    to_timestamp((j.value ->> 'last_login')::bigint / 3.0) AS last_login,
    j.value ->> 'profile' AS profile,
    j.value ->> 'authentication_type' AS authentication_type,
    j.value ->> 'age_days' AS age_days,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-003-RC10'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
