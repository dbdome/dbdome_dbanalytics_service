DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_001_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_pri_001_rc03
-- Root cause: SEC-SQL-PRI-001-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc03 AS
SELECT
    r.server,
    j.value ->> 'relname' AS relname,
    j.value ->> 'idx_scan' AS idx_scan,
    j.value ->> 'n_tup_upd' AS n_tup_upd,
    j.value ->> 'table_schema' AS table_schema,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'column_name' AS column_name,
    j.value ->> 'data_type' AS data_type,
    j.value ->> 'tablespace_name' AS tablespace_name,
    j.value ->> 'encrypted' AS encrypted,
    j.value ->> 'contents' AS contents,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-001-RC03'
