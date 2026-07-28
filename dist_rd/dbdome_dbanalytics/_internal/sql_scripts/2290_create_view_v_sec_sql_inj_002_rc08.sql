DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_002_rc08;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_002_rc08
-- Root cause: SEC-SQL-INJ-002-RC08
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc08 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'event_name' AS event_name,
    j.value ->> 'extname' AS extname,
    j.value ->> 'extversion' AS extversion,
    j.value ->> 'is_enabled' AS is_enabled,
    j.value ->> 'is_state_enabled' AS is_state_enabled,
    j.value ->> 'audit_action_name' AS audit_action_name,
    j.value ->> 'class_desc' AS class_desc,
    j.value ->> 'policy_name' AS policy_name,
    j.value ->> 'enabled_option' AS enabled_option,
    j.value ->> 'setting' AS setting,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'non_bind_sql_count' AS non_bind_sql_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC08'
