DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_006_rc05;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_006_rc05
-- Root cause: SEC-SQL-AUD-006-RC05
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_006_rc05 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'session_id',
        j.value ->> 'id'
    ) AS session_id,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'grantee'
    ) AS username,
    COALESCE(
        j.value ->> 'client_addr',
        j.value ->> 'host'
    ) AS host,
    j.value ->> 'db' AS db,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time,
    COALESCE(
        j.value ->> 'query',
        j.value ->> 'info',
        j.value ->> 'sql_text',
        j.value ->> 'text'
    ) AS query_text,
    j.value ->> 'privilege_type' AS privilege_type,
    j.value ->> 'is_grantable' AS is_grantable,
    to_timestamp((j.value ->> 'logon_time')::bigint / 3.0) AS logon_time,
    j.value ->> 'status' AS state,
    j.value ->> 'original_login_name' AS original_login_name,
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    j.value ->> 'db_user' AS db_user,
    j.value ->> 'action_name' AS action_name,
    j.value ->> 'obj_name' AS obj_name,
    j.value ->> 'timestamp' AS timestamp,
    j.value ->> 'return_code' AS return_code,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-006-RC05'
