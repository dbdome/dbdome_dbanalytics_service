DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_014_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_014_rc03
-- Root cause: SEC-SQL-AUD-014-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_014_rc03 AS
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
    to_timestamp((j.value ->> 'password_changed_time')::bigint / 3.0) AS password_changed_time,
    j.value ->> 'plugin' AS plugin,
    j.value ->> 'account_locked' AS account_locked,
    j.value ->> 'passwd' AS passwd,
    j.value ->> 'valuntil' AS valuntil,
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
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'is_disabled' AS is_disabled,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    j.value ->> 'default_database_name' AS default_database_name,
    j.value ->> 'account_status' AS account_status,
    to_timestamp((j.value ->> 'expiry_date')::bigint / 3.0) AS expiry_date,
    to_timestamp((j.value ->> 'last_login')::bigint / 3.0) AS last_login,
    j.value ->> 'profile' AS profile,
    j.value ->> 'db' AS db,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time,
    to_timestamp((j.value ->> 'last_active_time')::bigint / 3.0) AS last_active_time,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-014-RC03'
