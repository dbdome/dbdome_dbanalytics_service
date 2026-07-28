DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_003_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_pri_003_rc01
-- Root cause: SEC-SQL-PRI-003-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_003_rc01 AS
SELECT
    r.server,
    j.value ->> 'database_name' AS db,
    j.value ->> 'missing_ppl_security_level_parameter' AS missing_ppl_security_level_parameter,
    j.value ->> 'missing_ppl_security_level_option' AS missing_ppl_security_level_option,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-003-RC01'
