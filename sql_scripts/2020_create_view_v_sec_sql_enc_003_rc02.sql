DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_003_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_003_rc02
-- Root cause: SEC-SQL-ENC-003-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc02 AS
SELECT
    r.server,
    j.value ->> 'banner' AS banner,
    j.value ->> 'name' AS username,
    j.value ->> 'is_encrypted' AS is_encrypted,
    j.value ->> 'encrypted_count' AS encrypted_count,
    j.value ->> 'comp_name' AS comp_name,
    j.value ->> 'status' AS state,
    j.value ->> 'version' AS version,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-003-RC02'
