DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_007_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_007_rc01
-- Root cause: SEC-SQL-AUD-007-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_007_rc01 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'session_id'
    ) AS session_id,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user'
    ) AS username,
    COALESCE(
        j.value ->> 'application_name',
        j.value ->> 'program_name',
        j.value ->> 'program'
    ) AS application_name,
    COALESCE(
        j.value ->> 'client_addr',
        j.value ->> 'host_name',
        j.value ->> 'machine',
        j.value ->> 'host'
    ) AS host,
    j.value ->> 'client_interface_name' AS client_interface_name,
    j.value ->> 'current_connections' AS current_connections,
    j.value ->> 'total_connections' AS total_connections,
    j.value ->> 'db' AS db,
    COALESCE(
        j.value ->> 'state',
        j.value ->> 'command'
    ) AS state,
    j.value ->> 'info' AS query_text,
    j.value ->> 'client_info' AS client_info,
    j.value ->> 'sessions' AS sessions,
    j.value ->> 'module' AS module,
    to_timestamp((j.value ->> 'logon_time')::bigint / 3.0) AS logon_time,
    j.value ->> 'session_count' AS session_count,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-007-RC01'
