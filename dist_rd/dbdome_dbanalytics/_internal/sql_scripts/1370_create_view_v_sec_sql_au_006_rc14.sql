DROP VIEW IF EXISTS monitoring.v_sec_sql_au_006_rc14;

-- ============================================================
-- View: monitoring.v_sec_sql_au_006_rc14
-- Root cause: SEC-SQL-AU-006-RC14
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_006_rc14 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'status' AS state,
    j.value ->> 'on_failure_desc' AS on_failure_desc,
    j.value ->> 'queue_delay' AS queue_delay,
    j.value ->> 'log_file_path' AS log_file_path,
    j.value ->> 'max_file_size' AS max_file_size,
    j.value ->> 'max_rollover_files' AS max_rollover_files,
    j.value ->> 'setting' AS setting,
    j.value ->> 'value' AS value,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'policy_name' AS policy_name,
    j.value ->> 'enabled_option' AS enabled_option,
    j.value ->> 'entity_name' AS entity_name,
    j.value ->> 'entity_type' AS entity_type,
    j.value ->> 'success' AS success,
    j.value ->> 'failure' AS failure,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-006-RC14'
