DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_001_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_001_rc01
-- Root cause: SEC-SQL-ENC-001-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc01 AS
SELECT
    r.server,
    j.value ->> 'unencrypted_connections' AS unencrypted_connections,
    j.value ->> 'encrypt_option' AS encrypt_option,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'pct' AS pct,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'cf_name' AS cf_name,
    j.value ->> 'cf_effective' AS cf_effective,
    j.value ->> 'value' AS value,
    j.value ->> 'network_service_banner' AS network_service_banner,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-001-RC01'
