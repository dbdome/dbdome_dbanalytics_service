DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_006_rc04;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_006_rc04
-- Root cause: SEC-SQL-AUD-006-RC04
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_006_rc04 AS
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
    j.value ->> 'privilege_type' AS privilege_type,
    j.value ->> 'is_grantable' AS is_grantable,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'id'
    ) AS session_id,
    COALESCE(
        j.value ->> 'client_addr',
        j.value ->> 'host_name',
        j.value ->> 'machine',
        j.value ->> 'host'
    ) AS host,
    COALESCE(
        j.value ->> 'state',
        j.value ->> 'status',
        j.value ->> 'command'
    ) AS state,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time,
    COALESCE(
        j.value ->> 'query',
        j.value ->> 'info'
    ) AS query_text,
    COALESCE(
        j.value ->> 'application_name',
        j.value ->> 'program_name',
        j.value ->> 'program'
    ) AS application_name,
    j.value ->> 'client_interface_name' AS client_interface_name,
    to_timestamp((j.value ->> 'login_time')::bigint / 3.0) AS login_time,
    j.value ->> 'terminal' AS terminal,
    to_timestamp((j.value ->> 'logon_time')::bigint / 3.0) AS logon_time,
    to_timestamp((j.value ->> 'granted_role')::bigint / 3.0) AS granted_role,
    j.value ->> 'admin_option' AS admin_option,
    j.value ->> 'default_role' AS default_role,
    to_timestamp((j.value ->> 'backend_start')::bigint / 3.0) AS backend_start,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'description' AS description,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-006-RC04'
