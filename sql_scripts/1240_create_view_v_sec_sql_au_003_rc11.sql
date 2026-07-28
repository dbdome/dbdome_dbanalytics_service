DROP VIEW IF EXISTS monitoring.v_sec_sql_au_003_rc11;

-- ============================================================
-- View: monitoring.v_sec_sql_au_003_rc11
-- Root cause: SEC-SQL-AU-003-RC11
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc11 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'bad_password_count' AS bad_password_count,
    to_timestamp((j.value ->> 'last_bad_password_time')::bigint / 3.0) AS last_bad_password_time,
    j.value ->> 'is_locked' AS is_locked,
    to_timestamp((j.value ->> 'lockout_time')::bigint / 3.0) AS lockout_time,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'policy_name' AS policy_name,
    j.value ->> 'enabled_option' AS enabled_option,
    j.value ->> 'entity_name' AS entity_name,
    j.value ->> 'entity_type' AS entity_type,
    j.value ->> 'parameter_name' AS parameter_name,
    j.value ->> 'parameter_value' AS parameter_value,
    j.value ->> 'setting' AS setting,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-003-RC11'
