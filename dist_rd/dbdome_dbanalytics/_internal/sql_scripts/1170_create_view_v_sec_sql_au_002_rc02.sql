DROP VIEW IF EXISTS monitoring.v_sec_sql_au_002_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_au_002_rc02
-- Root cause: SEC-SQL-AU-002-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_002_rc02 AS
SELECT
    r.server,
    j.value ->> 'windows_auth_only' AS windows_auth_only,
    j.value ->> 'name' AS username,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-002-RC02'
