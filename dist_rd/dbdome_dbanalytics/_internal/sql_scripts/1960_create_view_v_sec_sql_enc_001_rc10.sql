DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_001_rc10;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_001_rc10
-- Root cause: SEC-SQL-ENC-001-RC10
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc10 AS
SELECT
    r.server,
    j.value ->> 'unencrypted_connections' AS unencrypted_connections,
    j.value ->> 'name' AS username,
    j.value ->> 'value' AS value,
    j.value ->> 'type' AS state,
    j.value ->> 'rule_count' AS rule_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-001-RC10'
