DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_004_rc11;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_004_rc11
-- Root cause: SEC-SQL-ENC-004-RC11
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc11 AS
SELECT
    r.server,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'tde_wallet' AS tde_wallet,
    j.value ->> 'setting' AS setting,
    j.value ->> 'encrypted_tablespaces' AS encrypted_tablespaces,
    j.value ->> 'database_name' AS db,
    to_timestamp((j.value ->> 'backup_start_date')::bigint / 3.0) AS backup_start_date,
    j.value ->> 'type' AS state_val,
    j.value ->> 'compressed_backup_size___1024___1024' AS compressed_backup_size___1024___1024,
    j.value ->> 'encryption_status' AS encryption_status,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'encryptor_type' AS encryptor_type,
    j.value ->> 'is_encrypted' AS is_encrypted,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-004-RC11'
