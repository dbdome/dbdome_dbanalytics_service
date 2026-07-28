DROP VIEW IF EXISTS monitoring.v_sec_sql_acc_010_rc13;

-- ============================================================
-- View: monitoring.v_sec_sql_acc_010_rc13
-- Root cause: SEC-SQL-ACC-010-RC13
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_acc_010_rc13 AS
SELECT
    r.server,
    j.value ->> 'object_name' AS object_name,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'constraint_name' AS constraint_name,
    j.value ->> 'variable_value' AS variable_value,
    j.value ->> 'variable_name' AS variable_name,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'login_name' AS username,
    j.value ->> 'host_name' AS host,
    j.value ->> 'program_name' AS application_name,
    j.value ->> 'transaction_id' AS transaction_id,
    to_timestamp((j.value ->> 'transaction_begin_time')::bigint / 3.0) AS transaction_begin_time,
    j.value ->> 'duration_seconds' AS duration_seconds,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ACC-010-RC13'
  AND j.value ->> 'host_name' IS DISTINCT FROM 'dbdome';
