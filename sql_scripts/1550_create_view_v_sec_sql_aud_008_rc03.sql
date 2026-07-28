DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_008_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_008_rc03
-- Root cause: SEC-SQL-AUD-008-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_008_rc03 AS
SELECT
    r.server,
    j.value ->> 'rolname' AS rolname,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'user',
        j.value ->> 'grantee',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'privilege' AS privilege,
    j.value ->> 'admin_option' AS admin_option,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'id'
    ) AS session_id,
    COALESCE(
        j.value ->> 'client_addr',
        j.value ->> 'host'
    ) AS host,
    j.value ->> 'db' AS db,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time,
    COALESCE(
        j.value ->> 'query',
        j.value ->> 'info',
        j.value ->> 'text'
    ) AS query_text,
    j.value ->> 'command' AS state,
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    j.value ->> 'db_name' AS db_name,
    j.value ->> 'role_principal_id' AS role_principal_id,
    j.value ->> 'table_schema' AS table_schema,
    j.value ->> 'privilege_type' AS privilege_type,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    j.value ->> 'db_user' AS db_user,
    j.value ->> 'action_name' AS action_name,
    j.value ->> 'obj_owner' AS obj_owner,
    j.value ->> 'obj_name' AS obj_name,
    j.value ->> 'timestamp' AS timestamp,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-008-RC03'
