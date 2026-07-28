DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_003_rc15;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_003_rc15
-- Root cause: SEC-SQL-ENC-003-RC15
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc15 AS
SELECT
    r.server,
    j.value ->> 'tablespace_name' AS tablespace_name,
    j.value ->> 'encrypted' AS encrypted,
    j.value ->> 'name' AS username,
    j.value ->> 'default_version' AS default_version,
    j.value ->> 'encryption_state' AS encryption_state,
    j.value ->> 'state_desc' AS state_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'key_length' AS key_length,
    j.value ->> 'wrl_type' AS wrl_type,
    j.value ->> 'wrl_parameter' AS wrl_parameter,
    j.value ->> 'status' AS state,
    j.value ->> 'wallet_type' AS wallet_type,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-003-RC15'
