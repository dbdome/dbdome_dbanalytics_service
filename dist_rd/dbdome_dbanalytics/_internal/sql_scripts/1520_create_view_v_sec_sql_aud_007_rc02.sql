DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_007_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_007_rc02
-- Root cause: SEC-SQL-AUD-007-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_007_rc02 AS
SELECT
    r.server,
    j.value ->> 'digest_text' AS digest_text,
    j.value ->> 'count_star' AS count_star,
    j.value ->> 'avg_timer_wait_1000000000' AS avg_timer_wait_1000000000,
    j.value ->> 'sum_rows_examined' AS sum_rows_examined,
    j.value ->> 'sum_rows_sent' AS sum_rows_sent,
    j.value ->> 'sql_id' AS sql_id,
    COALESCE(
        j.value ->> 'query',
        j.value ->> 'sql_text',
        j.value ->> 'text'
    ) AS query_text,
    j.value ->> 'executions' AS executions,
    j.value ->> 'buffer_gets' AS buffer_gets,
    j.value ->> 'disk_reads' AS disk_reads,
    to_timestamp((j.value ->> 'first_load_time')::bigint / 3.0) AS first_load_time,
    to_timestamp((j.value ->> 'last_active_time')::bigint / 3.0) AS last_active_time,
    j.value ->> 'digest' AS digest,
    j.value ->> 'query_sql_text' AS query_sql_text,
    j.value ->> 'count_executions' AS count_executions,
    j.value ->> 'avg_duration' AS avg_duration,
    j.value ->> 'query_plan' AS query_plan,
    j.value ->> 'calls' AS calls,
    to_timestamp((j.value ->> 'total_exec_time')::bigint / 3.0) AS total_exec_time,
    j.value ->> 'rows' AS rows_val,
    j.value ->> 'userid' AS userid,
    to_timestamp((j.value ->> 'elapsed_time_total')::bigint / 3.0) AS elapsed_time_total,
    j.value ->> 'executions_total' AS executions_total,
    j.value ->> 'buffer_gets_total' AS buffer_gets_total,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'queryid' AS queryid,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-007-RC02'
