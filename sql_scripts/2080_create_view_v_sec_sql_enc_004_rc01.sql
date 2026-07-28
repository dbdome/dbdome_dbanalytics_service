DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_004_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_004_rc01
-- Root cause: SEC-SQL-ENC-004-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc01 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'conf' AS conf,
    j.value ->> 'value' AS value_val,
    j.value ->> 'database_name' AS db,
    to_timestamp((j.value ->> 'backup_start_date')::bigint / 3.0) AS backup_start_date,
    COALESCE(
        j.value ->> 'status',
        j.value ->> 'type'
    ) AS state_val,
    j.value ->> 'compressed_backup_size___1024___1024' AS compressed_backup_size___1024___1024,
    j.value ->> 'encryption_status' AS encryption_status,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'encryptor_type' AS encryptor_type,
    j.value ->> 'is_encrypted' AS is_encrypted,
    j.value ->> 'input_type' AS input_type,
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    j.value ->> 'output_bytes_display' AS output_bytes_display,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-004-RC01'
