DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_014_rc04;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_014_rc04
-- Root cause: SEC-SQL-AUD-014-RC04
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_014_rc04 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'owner',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'db_link' AS db_link,
    COALESCE(
        j.value ->> 'client_addr',
        j.value ->> 'host'
    ) AS host,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'sid',
        j.value ->> 'id'
    ) AS session_id,
    j.value ->> 'db' AS db,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time_val,
    COALESCE(
        j.value ->> 'query',
        j.value ->> 'info',
        j.value ->> 'sql_text',
        j.value ->> 'text'
    ) AS query_text,
    j.value ->> 'data_source' AS data_source,
    j.value ->> 'provider' AS provider,
    j.value ->> 'catalog' AS catalog,
    j.value ->> 'is_linked' AS is_linked,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    j.value ->> 'srvname' AS srvname,
    j.value ->> 'srvowner' AS srvowner,
    j.value ->> 'umuser' AS umuser,
    j.value ->> 'srvoptions' AS srvoptions,
    j.value ->> 'table_schema' AS table_schema,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'engine' AS engine,
    to_timestamp((j.value ->> 'create_time')::bigint / 3.0) AS create_time,
    j.value ->> 'table_comment' AS table_comment,
    to_timestamp((j.value ->> 'last_active_time')::bigint / 3.0) AS last_active_time,
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-014-RC04'
