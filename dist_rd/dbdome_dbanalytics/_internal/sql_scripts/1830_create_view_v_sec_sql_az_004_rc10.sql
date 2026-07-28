DROP VIEW IF EXISTS monitoring.v_sec_sql_az_004_rc10;

-- ============================================================
-- View: monitoring.v_sec_sql_az_004_rc10
-- Root cause: SEC-SQL-AZ-004-RC10
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc10 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'grantee',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'privilege' AS privilege,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'file_users' AS file_users,
    j.value ->> 'audit_option' AS audit_option,
    j.value ->> 'success' AS success,
    j.value ->> 'failure' AS failure,
    j.value ->> 'setting' AS setting,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-004-RC10'
