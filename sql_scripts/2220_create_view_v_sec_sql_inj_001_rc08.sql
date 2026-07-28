DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_001_rc08;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_001_rc08
-- Root cause: SEC-SQL-INJ-001-RC08
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_001_rc08 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'owner',
        j.value ->> 'schema_name',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'type' AS state,
    j.value ->> 'dynamic_sql_lines' AS dynamic_sql_lines,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'proname' AS proname,
    j.value ->> 'proc_name' AS proc_name,
    j.value ->> 'definition_length' AS definition_length,
    j.value ->> 'approx_concat_count' AS approx_concat_count,
    j.value ->> 'approx_if_count' AS approx_if_count,
    j.value ->> 'routine_schema' AS routine_schema,
    j.value ->> 'routine_name' AS routine_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-001-RC08'
