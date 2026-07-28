DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_003_rc04;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_003_rc04
-- Root cause: SEC-SQL-ENC-003-RC04
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc04 AS
SELECT
    r.server,
    j.value ->> 'wrl_type' AS wrl_type,
    j.value ->> 'wrl_parameter' AS wrl_parameter,
    j.value ->> 'status' AS state,
    j.value ->> 'wallet_type' AS wallet_type,
    j.value ->> 'keystore_mode' AS keystore_mode,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'plugin_type' AS plugin_type,
    j.value ->> 'extname' AS extname,
    j.value ->> 'name' AS username,
    j.value ->> 'is_encrypted' AS is_encrypted,
    j.value ->> 'encryption_state' AS encryption_state,
    j.value ->> 'setting' AS setting,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-003-RC04'
