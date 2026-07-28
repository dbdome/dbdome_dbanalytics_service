DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_008_rc04;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_008_rc04
-- Root cause: SEC-SQL-AUD-008-RC04
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_008_rc04 AS
SELECT
    r.server,
    j.value ->> 'relname' AS relname,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'comment' AS comment,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    COALESCE(
        j.value ->> 'query',
        j.value ->> 'info',
        j.value ->> 'sql_text',
        j.value ->> 'text'
    ) AS query_text,
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    j.value ->> 'executions' AS executions,
    COALESCE(
        j.value ->> 'state',
        j.value ->> 'status'
    ) AS state,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'id'
    ) AS session_id,
    j.value ->> 'host' AS host,
    j.value ->> 'db' AS db,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time,
    j.value ->> 'symmetric_key_id' AS symmetric_key_id,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'key_length' AS key_length,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'plugin_type' AS plugin_type,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-008-RC04'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
