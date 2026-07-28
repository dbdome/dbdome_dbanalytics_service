DROP VIEW IF EXISTS monitoring.v_sec_sql_au_003_rc08;

-- ============================================================
-- View: monitoring.v_sec_sql_au_003_rc08
-- Root cause: SEC-SQL-AU-003-RC08
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc08 AS
SELECT
    r.server,
    j.value ->> 'profile' AS profile,
    j.value ->> 'resource_name' AS resource_name,
    j.value ->> 'limit' AS limit,
    j.value ->> 'line_number' AS line_number,
    j.value ->> 'type' AS state,
    j.value ->> 'database' AS database,
    j.value ->> 'user_name' AS user_name,
    j.value ->> 'address' AS address,
    j.value ->> 'auth_method' AS auth_method,
    j.value ->> 'name' AS username,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_blank' AS is_blank,
    j.value ->> 'matches_login_name' AS matches_login_name,
    j.value ->> 'is_common_password' AS is_common_password,
    j.value ->> 'is_common_dev_password' AS is_common_dev_password,
    j.value ->> 'is_common_complex_password' AS is_common_complex_password,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'bad_password_count' AS bad_password_count,
    j.value ->> 'is_locked' AS is_locked,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-003-RC08'
