DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_005_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_005_rc03
-- Root cause: SEC-SQL-ENC-005-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_005_rc03 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'plugin' AS plugin,
    j.value ->> 'setting' AS setting,
    j.value ->> 'algorithm_desc' AS algorithm_desc,
    j.value ->> 'key_length' AS key_length,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'password_versions' AS password_versions,
    j.value ->> 'tablespace_name' AS tablespace_name,
    j.value ->> 'encrypted' AS encrypted,
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
WHERE r.metric_name = 'SEC-SQL-ENC-005-RC03'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
