DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_004_rc10;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_004_rc10
-- Root cause: SEC-SQL-ENC-004-RC10
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc10 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'key_id' AS key_id,
    to_timestamp((j.value ->> 'activation_time')::bigint / 3.0) AS activation_time,
    j.value ->> 'key_age_days' AS key_age_days,
    j.value ->> 'backed_up' AS backed_up,
    j.value ->> 'creator_dbname' AS creator_dbname,
    j.value ->> 'database_name' AS db,
    to_timestamp((j.value ->> 'backup_start_date')::bigint / 3.0) AS backup_start_date,
    j.value ->> 'type' AS state_val,
    j.value ->> 'compressed_backup_size___1024___1024' AS compressed_backup_size___1024___1024,
    j.value ->> 'encryption_status' AS encryption_status,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'encryptor_type' AS encryptor_type,
    j.value ->> 'is_encrypted' AS is_encrypted,
    j.value ->> 'extname' AS extname,
    to_timestamp((j.value ->> 'expiry_date')::bigint / 3.0) AS expiry_date,
    j.value ->> 'days_until_expiry' AS days_until_expiry,
    j.value ->> 'pvt_key_encryption_type_desc' AS pvt_key_encryption_type_desc,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-004-RC10'
