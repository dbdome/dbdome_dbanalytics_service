DROP VIEW IF EXISTS monitoring.v_sec_sql_net_002_rc13;

-- ============================================================
-- View: monitoring.v_sec_sql_net_002_rc13
-- Root cause: SEC-SQL-NET-002-RC13
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_002_rc13 AS
SELECT
    r.server,
    j.value ->> 'failed_login_count' AS failed_login_count,
    j.value ->> 'earliest_failure' AS earliest_failure,
    j.value ->> 'latest_failure' AS latest_failure,
    j.value ->> 'port' AS port,
    j.value ->> 'max_connect_errors' AS max_connect_errors,
    j.value ->> 'policy_name' AS policy_name,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'profile' AS profile,
    j.value ->> 'resource_name' AS resource_name,
    j.value ->> 'limit' AS limit_val,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-NET-002-RC13'
