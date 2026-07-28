DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_003_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_003_rc01
-- Root cause: SEC-SQL-ENC-003-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc01 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'database_id' AS database_id,
    j.value ->> 'is_encrypted' AS is_encrypted,
    j.value ->> 'state_desc' AS state_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'encrypted_count' AS encrypted_count,
    j.value ->> 'encryption_state' AS encryption_state,
    j.value ->> 'encryption_state_desc' AS encryption_state_desc,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'key_length' AS key_length,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'tablespace_name' AS tablespace_name,
    j.value ->> 'encrypted' AS encrypted,
    j.value ->> 'setting' AS setting,
    j.value ->> 'extname' AS extname,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'column_name' AS column_name,
    j.value ->> 'encryption_alg' AS encryption_alg,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-003-RC01'
