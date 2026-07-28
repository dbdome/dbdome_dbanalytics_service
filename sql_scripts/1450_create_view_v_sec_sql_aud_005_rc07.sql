DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_005_rc07;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_005_rc07
-- Root cause: SEC-SQL-AUD-005-RC07
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_005_rc07 AS
SELECT
    r.server,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_version' AS plugin_version,
    j.value ->> 'plugin_type_version' AS plugin_type_version,
    j.value ->> 'plugin_library' AS plugin_library,
    COALESCE(
        j.value ->> 'grantee',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'policy_name' AS policy_name,
    j.value ->> 'audit_option' AS audit_option,
    j.value ->> 'extname' AS extname,
    j.value ->> 'extversion' AS extversion,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'privilege' AS privilege,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-005-RC07'
