DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_014_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_014_rc02
-- Root cause: SEC-SQL-AUD-014-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_014_rc02 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'grantee',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    COALESCE(
        j.value ->> 'client_addr',
        j.value ->> 'host'
    ) AS host,
    j.value ->> 'super_priv' AS super_priv,
    j.value ->> 'grant_priv' AS grant_priv,
    j.value ->> 'create_user_priv' AS create_user_priv,
    j.value ->> 'system_user_priv' AS system_user_priv,
    to_timestamp((j.value ->> 'granted_role')::bigint / 3.0) AS granted_role,
    j.value ->> 'admin_option' AS admin_option,
    j.value ->> 'default_role' AS default_role,
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
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    to_timestamp((j.value ->> 'last_active_time')::bigint / 3.0) AS last_active_time,
    j.value ->> 'rolname' AS rolname,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-014-RC02'
