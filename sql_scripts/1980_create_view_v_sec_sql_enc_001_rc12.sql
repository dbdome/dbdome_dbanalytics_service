DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_001_rc12;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_001_rc12
-- Root cause: SEC-SQL-ENC-001-RC12
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc12 AS
SELECT
    r.server,
    j.value ->> 'require_secure_transport' AS require_secure_transport,
    j.value ->> 'no_ssl_users' AS no_ssl_users,
    j.value ->> 'name' AS username,
    j.value ->> 'value' AS value_val,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-001-RC12'
