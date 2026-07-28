DROP VIEW IF EXISTS monitoring.v_sec_sql_au_005_rc13;

-- ============================================================
-- View: monitoring.v_sec_sql_au_005_rc13
-- Root cause: SEC-SQL-AU-005-RC13
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc13 AS
SELECT
    r.server,
    j.value ->> 'policy_name' AS policy_name,
    j.value ->> 'enabled_option' AS enabled_option,
    j.value ->> 'entity_name' AS entity_name,
    j.value ->> 'entity_type' AS entity_type,
    j.value ->> 'success' AS success,
    j.value ->> 'failure' AS failure,
    j.value ->> 'windows_auth_only' AS windows_auth_only,
    j.value ->> 'sql_version' AS sql_version,
    j.value ->> 'parameter' AS parameter,
    j.value ->> 'value' AS value,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-005-RC13'
