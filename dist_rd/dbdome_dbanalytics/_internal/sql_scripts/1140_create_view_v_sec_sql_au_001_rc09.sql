DROP VIEW IF EXISTS monitoring.v_sec_sql_au_001_rc09;

-- ============================================================
-- View: monitoring.v_sec_sql_au_001_rc09
-- Root cause: SEC-SQL-AU-001-RC09
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc09 AS
SELECT
    r.server,
    j.value ->> 'authentication_type' AS authentication_type,
    j.value ->> 'account_count' AS account_count,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'login_audit_specs' AS login_audit_specs,
    j.value ->> 'name' AS username,
    j.value ->> 'value' AS value,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'password_age_days' AS password_age_days,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-001-RC09'
