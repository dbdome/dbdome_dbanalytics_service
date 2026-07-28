DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_002_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_002_rc01
-- Root cause: SEC-SQL-INJ-002-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc01 AS
SELECT
    r.server,
    j.value ->> 'xproc_name' AS xproc_name,
    j.value ->> 'execution_count' AS execution_count,
    to_timestamp((j.value ->> 'last_execution_time')::bigint / 3.0) AS last_execution_time,
    to_timestamp((j.value ->> 'days_since_last_exec')::bigint / 3.0) AS days_since_last_exec,
    COALESCE(
        j.value ->> 'schema_name',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC01'
