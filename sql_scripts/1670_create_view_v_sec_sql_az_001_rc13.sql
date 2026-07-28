DROP VIEW IF EXISTS monitoring.v_sec_sql_az_001_rc13;

-- ============================================================
-- View: monitoring.v_sec_sql_az_001_rc13
-- Root cause: SEC-SQL-AZ-001-RC13
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc13 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'authentication_type' AS authentication_type,
    j.value ->> 'external_name' AS external_name,
    j.value ->> 'plugin' AS plugin,
    j.value ->> 'user_count' AS user_count,
    j.value ->> 'auth_method' AS auth_method,
    j.value ->> 'rule_count' AS rule_count,
    j.value ->> 'sql_logins' AS sql_logins,
    j.value ->> 'windows_logins' AS windows_logins,
    j.value ->> 'windows_groups' AS windows_groups,
    j.value ->> 'azure_ad_principals' AS azure_ad_principals,
    j.value ->> 'windows_only_auth' AS windows_only_auth,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'value' AS value,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-001-RC13'
