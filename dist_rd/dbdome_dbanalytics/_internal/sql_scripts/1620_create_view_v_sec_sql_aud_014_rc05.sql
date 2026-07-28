DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_014_rc05;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_014_rc05
-- Root cause: SEC-SQL-AUD-014-RC05
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_014_rc05 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    COALESCE(
        j.value ->> 'client_addr',
        j.value ->> 'host'
    ) AS host,
    j.value ->> 'account_locked' AS account_locked,
    to_timestamp((j.value ->> 'password_changed_time')::bigint / 3.0) AS password_changed_time,
    j.value ->> 'password_expired' AS password_expired,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'sid',
        j.value ->> 'id'
    ) AS session_id,
    j.value ->> 'db' AS db,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time,
    COALESCE(
        j.value ->> 'query',
        j.value ->> 'info',
        j.value ->> 'sql_text',
        j.value ->> 'text'
    ) AS query_text,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'rolvaliduntil' AS rolvaliduntil,
    j.value ->> 'oid' AS oid,
    j.value ->> 'is_disabled' AS is_disabled,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'last_active_time')::bigint / 3.0) AS last_active_time,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    j.value ->> 'account_status' AS account_status,
    to_timestamp((j.value ->> 'expiry_date')::bigint / 3.0) AS expiry_date,
    to_timestamp((j.value ->> 'lock_date')::bigint / 3.0) AS lock_date,
    to_timestamp((j.value ->> 'last_login')::bigint / 3.0) AS last_login,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-014-RC05'
