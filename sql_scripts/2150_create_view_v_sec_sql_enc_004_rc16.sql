DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_004_rc16;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_004_rc16
-- Root cause: SEC-SQL-ENC-004-RC16
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc16 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'conf' AS conf,
    j.value ->> 'value' AS value_val,
    j.value ->> 'step_name' AS step_name,
    COALESCE(
        j.value ->> 'command',
        j.value ->> 'type'
    ) AS state_val,
    to_timestamp((j.value ->> 'date_created')::bigint / 3.0) AS date_created,
    to_timestamp((j.value ->> 'date_modified')::bigint / 3.0) AS date_modified,
    j.value ->> 'database_name' AS db,
    to_timestamp((j.value ->> 'backup_start_date')::bigint / 3.0) AS backup_start_date,
    j.value ->> 'compressed_backup_size___1024___1024' AS compressed_backup_size___1024___1024,
    j.value ->> 'encryption_status' AS encryption_status,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'encryptor_type' AS encryptor_type,
    j.value ->> 'is_encrypted' AS is_encrypted,
    j.value ->> 'total_backups' AS total_backups,
    j.value ->> 'unencrypted' AS unencrypted,
    j.value ->> 'encrypted' AS encrypted,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-004-RC16'
