DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_003_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_pri_003_rc03
-- Root cause: SEC-SQL-PRI-003-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_003_rc03 AS
SELECT
    r.server,
    j.value ->> 'variable_name' AS variable_name,
    j.value ->> 'variable_value' AS variable_value,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'value_in_use' AS value_in_use,
    j.value ->> 'value' AS value,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-003-RC03'
