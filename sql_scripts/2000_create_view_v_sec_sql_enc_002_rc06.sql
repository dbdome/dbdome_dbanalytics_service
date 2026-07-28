DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_002_rc06;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_002_rc06
-- Root cause: SEC-SQL-ENC-002-RC06
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_002_rc06 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'check__etc_crypto_policies_state_current_on_rhel_centos' AS check__etc_crypto_policies_state_current_on_rhel_centos,
    j.value ->> 'cnf_for_minprotocol' AS cnf_for_minprotocol,
    j.value ->> 'value' AS value_val,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-002-RC06'
