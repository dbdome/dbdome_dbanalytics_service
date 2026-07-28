DROP VIEW IF EXISTS monitoring.v_sec_sql_acc_010_rc12;

-- ============================================================
-- View: monitoring.v_sec_sql_acc_010_rc12
-- Root cause: SEC-SQL-ACC-010-RC12
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_acc_010_rc12 AS
SELECT
    r.server,
    j.value ->> 'login_name' AS username,
    j.value ->> 'host_name' AS host,
    j.value ->> 'program_name' AS application_name,
    to_timestamp((j.value ->> 'login_time')::bigint / 3.0) AS login_time,
    to_timestamp((j.value ->> 'last_request_start_time')::bigint / 3.0) AS last_request_start_time,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    to_timestamp((j.value ->> 'days_since_modified')::bigint / 3.0) AS days_since_modified,
    COALESCE(
        j.value ->> 'sid',
        j.value ->> 'trx_id',
        j.value ->> 'trx_mysql_thread_id'
    ) AS session_id,
    COALESCE(
        j.value ->> 'status',
        j.value ->> 'trx_state'
    ) AS state,
    to_timestamp((j.value ->> 'logon_time')::bigint / 3.0) AS logon_time,
    j.value ->> 'seconds_in_wait' AS seconds_in_wait,
    j.value ->> 'sql_text' AS query_text,
    j.value ->> 'table_schema' AS table_schema,
    j.value ->> 'total_size_bytes' AS total_size_bytes,
    j.value ->> 'free_space_bytes' AS free_space_bytes,
    j.value ->> 'open_seconds' AS open_seconds,
    j.value ->> 'trx_query' AS trx_query,
    j.value ->> 'trx_rows_locked' AS trx_rows_locked,
    to_timestamp((j.value ->> 'trx_rows_modified')::bigint / 3.0) AS trx_rows_modified,
    j.value ->> 'trx_isolation_level' AS trx_isolation_level,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ACC-010-RC12'
  AND j.value ->> 'host_name' IS DISTINCT FROM 'dbdome';
