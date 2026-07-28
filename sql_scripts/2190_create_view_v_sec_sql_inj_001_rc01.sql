DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_001_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_001_rc01
-- Root cause: SEC-SQL-INJ-001-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_001_rc01 AS
SELECT
    r.server,
    j.value ->> 'routine_schema' AS routine_schema,
    j.value ->> 'routine_name' AS routine_name,
    COALESCE(
        j.value ->> 'owner',
        j.value ->> 'schema_name',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'type' AS state,
    j.value ->> 'line' AS line,
    j.value ->> 'text' AS query_text,
    j.value ->> 'routine_type' AS routine_type,
    j.value ->> 'proc_name' AS proc_name,
    j.value ->> 'definition_length' AS definition_length,
    j.value ->> 'object_id' AS object_id,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'proname' AS proname,
    j.value ->> 'function_def' AS function_def,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-001-RC01'
