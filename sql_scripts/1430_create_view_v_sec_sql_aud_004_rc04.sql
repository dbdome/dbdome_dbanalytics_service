DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_004_rc04;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_004_rc04
-- Root cause: SEC-SQL-AUD-004-RC04
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_004_rc04 AS
SELECT
    r.server,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'policy_name' AS policy_name,
    j.value ->> 'extname' AS extname,
    j.value ->> 'extversion' AS extversion,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-004-RC04'
