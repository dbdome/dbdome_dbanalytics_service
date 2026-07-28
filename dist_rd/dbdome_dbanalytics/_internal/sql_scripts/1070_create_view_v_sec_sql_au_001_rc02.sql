DROP VIEW IF EXISTS monitoring.v_sec_sql_au_001_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_au_001_rc02
-- Root cause: SEC-SQL-AU-001-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc02 AS
SELECT
    r.server,
    j.value ->> 'banner' AS banner,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'plugin' AS plugin,
    j.value ->> 'authentication_string' AS authentication_string,
    j.value ->> 'parameter' AS parameter,
    j.value ->> 'value' AS value_val,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'rolpassword_is_not_null' AS rolpassword_is_not_null,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_disabled' AS is_disabled,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'bad_password_count' AS bad_password_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-001-RC02'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
