DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_004_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_pri_004_rc01
-- Root cause: SEC-SQL-PRI-004-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_004_rc01 AS
SELECT
    r.server,
    j.value ->> 'database_name' AS db,
    j.value ->> 'encryption_state' AS encryption_state,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'variable_name' AS variable_name,
    j.value ->> 'variable_value' AS variable_value,
    j.value ->> 'tablespace_name' AS tablespace_name,
    j.value ->> 'encrypted' AS encrypted,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-004-RC01'
