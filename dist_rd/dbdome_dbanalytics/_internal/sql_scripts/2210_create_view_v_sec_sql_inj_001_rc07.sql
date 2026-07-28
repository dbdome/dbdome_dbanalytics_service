DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_001_rc07;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_001_rc07
-- Root cause: SEC-SQL-INJ-001-RC07
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_001_rc07 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'owner',
        j.value ->> 'schema_name',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'type' AS state,
    j.value ->> 'line' AS line,
    j.value ->> 'text' AS query_text,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'proname' AS proname,
    j.value ->> 'routine_schema' AS routine_schema,
    j.value ->> 'routine_name' AS routine_name,
    j.value ->> 'proc_name' AS proc_name,
    j.value ->> 'has_exec_concat' AS has_exec_concat,
    j.value ->> 'mixed_pattern_count' AS mixed_pattern_count,
    j.value ->> 'unprotected_mixed_count' AS unprotected_mixed_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-001-RC07'
