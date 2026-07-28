DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_006_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_006_rc02
-- Root cause: SEC-SQL-AUD-006-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_006_rc02 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'owner',
        j.value ->> 'schema_name',
        j.value ->> 'name'
    ) AS username,
    COALESCE(
        j.value ->> 'query',
        j.value ->> 'info',
        j.value ->> 'sql_text',
        j.value ->> 'text'
    ) AS query_text,
    COALESCE(
        j.value ->> 'client_addr',
        j.value ->> 'host_name',
        j.value ->> 'machine',
        j.value ->> 'host'
    ) AS host,
    to_timestamp((j.value ->> 'logon_time')::bigint / 3.0) AS logon_time,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'id'
    ) AS session_id,
    j.value ->> 'db' AS db,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time,
    j.value ->> 'table_schema' AS table_schema,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'table_comment' AS table_comment,
    j.value ->> 'object_name' AS object_name,
    j.value ->> 'column_name' AS column_name,
    j.value ->> 'sensitive_type' AS sensitive_type,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    j.value ->> 'relname' AS relname,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'comment' AS comment,
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    j.value ->> 'value' AS value,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-006-RC02'
