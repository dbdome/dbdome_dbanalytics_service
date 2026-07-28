DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_001_rc12;

-- ============================================================
-- View: monitoring.v_sec_sql_pri_001_rc12
-- Root cause: SEC-SQL-PRI-001-RC12
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc12 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'owner',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'max_length' AS max_length,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'column_name' AS column_name,
    j.value ->> 'data_type' AS data_type,
    j.value ->> 'data_length' AS data_length,
    j.value ->> 'pii_category' AS pii_category,
    j.value ->> 'table_schema' AS table_schema,
    j.value ->> 'character_maximum_length' AS character_maximum_length,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-001-RC12'
