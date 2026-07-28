DROP VIEW IF EXISTS monitoring.v_sec_sql_au_003_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_au_003_rc01
-- Root cause: SEC-SQL-AU-003-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc01 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'resource_name' AS resource_name,
    j.value ->> 'limit' AS limit,
    j.value ->> 'total_sql_logins' AS total_sql_logins,
    j.value ->> 'no_policy' AS no_policy,
    j.value ->> 'no_expiration' AS no_expiration,
    j.value ->> 'no_both' AS no_both,
    j.value ->> 'pct_no_policy' AS pct_no_policy,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'is_sysadmin' AS is_sysadmin,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-003-RC01'
