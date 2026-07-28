DROP VIEW IF EXISTS monitoring.v_sec_sql_au_003_rc13;

-- ============================================================
-- View: monitoring.v_sec_sql_au_003_rc13
-- Root cause: SEC-SQL-AU-003-RC13
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc13 AS
SELECT
    r.server,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    to_timestamp((j.value ->> 'creation_date')::bigint / 3.0) AS creation_date,
    to_timestamp((j.value ->> 'accounts_created')::bigint / 3.0) AS accounts_created,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'secs_between_create_and_pwdset' AS secs_between_create_and_pwdset,
    to_timestamp((j.value ->> 'logins_created')::bigint / 3.0) AS logins_created,
    j.value ->> 'no_policy_count' AS no_policy_count,
    j.value ->> 'no_expiration_count' AS no_expiration_count,
    j.value ->> 'profile' AS profile,
    j.value ->> 'account_status' AS account_status,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    j.value ->> 'authentication_type' AS authentication_type,
    j.value ->> 'limit' AS limit,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-003-RC13'
