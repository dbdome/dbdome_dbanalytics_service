DROP VIEW IF EXISTS monitoring.v_sec_sql_au_001_rc11;

-- ============================================================
-- View: monitoring.v_sec_sql_au_001_rc11
-- Root cause: SEC-SQL-AU-001-RC11
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc11 AS
SELECT
    r.server,
    j.value ->> 'change_audit_specs' AS change_audit_specs,
    j.value ->> 'policy_name' AS policy_name,
    j.value ->> 'audit_option' AS audit_option,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'rolvaliduntil' AS rolvaliduntil,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'name'
    ) AS username,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    to_timestamp((j.value ->> 'last_login')::bigint / 3.0) AS last_login,
    j.value ->> 'account_status' AS account_status,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    to_timestamp((j.value ->> 'days_since_modified')::bigint / 3.0) AS days_since_modified,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-001-RC11'
