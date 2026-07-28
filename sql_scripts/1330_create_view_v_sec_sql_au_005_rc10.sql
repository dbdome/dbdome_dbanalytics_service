DROP VIEW IF EXISTS monitoring.v_sec_sql_au_005_rc10;

-- ============================================================
-- View: monitoring.v_sec_sql_au_005_rc10
-- Root cause: SEC-SQL-AU-005-RC10
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc10 AS
SELECT
    r.server,
    j.value ->> 'windows_auth_only' AS windows_auth_only,
    j.value ->> 'name' AS username,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'is_sysadmin' AS is_sysadmin,
    j.value ->> 'is_securityadmin' AS is_securityadmin,
    j.value ->> 'is_serveradmin' AS is_serveradmin,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'profile' AS profile,
    j.value ->> 'resource_name' AS resource_name,
    j.value ->> 'limit' AS limit,
    j.value ->> 'distinct_hosts' AS distinct_hosts,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-005-RC10'
