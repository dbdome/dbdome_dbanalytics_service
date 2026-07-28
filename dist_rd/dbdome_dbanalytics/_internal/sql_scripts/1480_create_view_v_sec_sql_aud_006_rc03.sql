DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_006_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_006_rc03
-- Root cause: SEC-SQL-AUD-006-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_006_rc03 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'grantee',
        j.value ->> 'owner',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'db_name' AS db_name,
    COALESCE(
        j.value ->> 'query',
        j.value ->> 'info',
        j.value ->> 'sql_text',
        j.value ->> 'text'
    ) AS query_text,
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    j.value ->> 'table_schema' AS table_schema,
    j.value ->> 'privilege_type' AS privilege_type,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'privilege' AS privilege,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'id'
    ) AS session_id,
    j.value ->> 'db' AS db,
    j.value ->> 'host' AS host,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time_val,
    j.value ->> 'schemaname' AS schemaname,
    j.value ->> 'tablename' AS tablename,
    j.value ->> 'tableowner' AS tableowner,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    j.value ->> 'search_path' AS search_path,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-006-RC03'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
