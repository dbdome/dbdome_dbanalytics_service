DROP VIEW IF EXISTS monitoring.v_sec_sql_az_003_rc07;

-- ============================================================
-- View: monitoring.v_sec_sql_az_003_rc07
-- Root cause: SEC-SQL-AZ-003-RC07
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc07 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'password_expired' AS password_expired,
    j.value ->> 'password_lifetime' AS password_lifetime,
    to_timestamp((j.value ->> 'password_last_changed')::bigint / 3.0) AS password_last_changed,
    j.value ->> 'days_since_change' AS days_since_change,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolvaliduntil' AS rolvaliduntil,
    j.value ->> 'rolcreatedb' AS rolcreatedb,
    j.value ->> 'rolcreaterole' AS rolcreaterole,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'account_age_days' AS account_age_days,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    j.value ->> 'days_until_expiration' AS days_until_expiration,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'account_status' AS account_status,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    to_timestamp((j.value ->> 'expiry_date')::bigint / 3.0) AS expiry_date,
    j.value ->> 'profile' AS profile,
    j.value ->> 'limit' AS limit,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-003-RC07'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
