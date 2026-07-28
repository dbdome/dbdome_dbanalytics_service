DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_003_rc16;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_003_rc16
-- Root cause: SEC-SQL-ENC-003-RC16
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc16 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'subject' AS subject,
    to_timestamp((j.value ->> 'start_date')::bigint / 3.0) AS start_date,
    to_timestamp((j.value ->> 'expiry_date')::bigint / 3.0) AS expiry_date,
    j.value ->> 'pvt_key_encryption_type_desc' AS pvt_key_encryption_type_desc,
    j.value ->> 'days_expired' AS days_expired,
    j.value ->> 'setting' AS setting,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'wrl_type' AS wrl_type,
    j.value ->> 'wrl_parameter' AS wrl_parameter,
    j.value ->> 'status' AS state,
    j.value ->> 'wallet_type' AS wallet_type,
    j.value ->> 'wallet_order' AS wallet_order,
    j.value ->> 'key_id' AS key_id,
    to_timestamp((j.value ->> 'activation_time')::bigint / 3.0) AS activation_time,
    j.value ->> 'backed_up' AS backed_up,
    j.value ->> 'creator_dbname' AS creator_dbname,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-003-RC16'
