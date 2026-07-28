DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_003_rc10;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_003_rc10
-- Root cause: SEC-SQL-ENC-003-RC10
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc10 AS
SELECT
    r.server,
    j.value ->> 'tablespace_name' AS tablespace_name,
    j.value ->> 'encrypted' AS encrypted,
    j.value ->> 'contents' AS contents,
    j.value ->> 'status' AS state,
    j.value ->> 'encrypted_count' AS encrypted_count,
    j.value ->> 'user_objects_mb' AS user_objects_mb,
    j.value ->> 'internal_objects_mb' AS internal_objects_mb,
    j.value ->> 'version_store_mb' AS version_store_mb,
    j.value ->> 'free_mb' AS free_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-003-RC10'
