DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_003_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_003_rc03
-- Root cause: SEC-SQL-ENC-003-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc03 AS
SELECT
    r.server,
    j.value ->> 'unencrypted_db_count' AS unencrypted_db_count,
    j.value ->> 'name' AS username,
    j.value ->> 'detected_usages' AS detected_usages,
    j.value ->> 'currently_used' AS currently_used,
    to_timestamp((j.value ->> 'first_usage_date')::bigint / 3.0) AS first_usage_date,
    to_timestamp((j.value ->> 'last_usage_date')::bigint / 3.0) AS last_usage_date,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-003-RC03'
