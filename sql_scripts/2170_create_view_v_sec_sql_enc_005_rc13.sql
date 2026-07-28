DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_005_rc13;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_005_rc13
-- Root cause: SEC-SQL-ENC-005-RC13
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_005_rc13 AS
SELECT
    r.server,
    j.value ->> 'wrl_type' AS wrl_type,
    j.value ->> 'status' AS state,
    j.value ->> 'wallet_type' AS wallet_type,
    j.value ->> 'keystore_mode' AS keystore_mode,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'algorithm_desc' AS algorithm_desc,
    j.value ->> 'key_length' AS key_length,
    j.value ->> 'pvt_key_encryption_type_desc' AS pvt_key_encryption_type_desc,
    j.value ->> 'strength_assessment' AS strength_assessment,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-005-RC13'
