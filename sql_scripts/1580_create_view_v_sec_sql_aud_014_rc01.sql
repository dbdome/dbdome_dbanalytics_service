DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_014_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_014_rc01
-- Root cause: SEC-SQL-AUD-014-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_014_rc01 AS
SELECT
    r.server,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'rolcreatedb' AS rolcreatedb,
    j.value ->> 'rolcreaterole' AS rolcreaterole,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'oid' AS oid,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'is_disabled' AS is_disabled,
    COALESCE(
        j.value ->> 'client_addr',
        j.value ->> 'host'
    ) AS host,
    j.value ->> 'plugin' AS plugin,
    to_timestamp((j.value ->> 'password_changed_time')::bigint / 3.0) AS password_changed_time,
    j.value ->> 'account_locked' AS account_locked,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'sid',
        j.value ->> 'id'
    ) AS session_id,
    COALESCE(
        j.value ->> 'query',
        j.value ->> 'info',
        j.value ->> 'sql_text',
        j.value ->> 'text'
    ) AS query_text,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    to_timestamp((j.value ->> 'last_active_time')::bigint / 3.0) AS last_active_time,
    j.value ->> 'account_status' AS account_status,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    j.value ->> 'profile' AS profile,
    j.value ->> 'db' AS db,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time,
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-014-RC01'
