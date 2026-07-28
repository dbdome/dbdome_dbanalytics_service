DROP VIEW IF EXISTS monitoring.v_sec_sql_cfg_003_rc06;

-- ============================================================
-- View: monitoring.v_sec_sql_cfg_003_rc06
-- Root cause: SEC-SQL-CFG-003-RC06
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_003_rc06 AS
SELECT
    r.server,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'nspowner' AS nspowner,
    j.value ->> 'username' AS username,
    j.value ->> 'account_status' AS account_status,
    j.value ->> 'authentication_type' AS authentication_type,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-CFG-003-RC06'
