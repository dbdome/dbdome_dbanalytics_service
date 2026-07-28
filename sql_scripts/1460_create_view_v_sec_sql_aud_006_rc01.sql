DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_006_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_006_rc01
-- Root cause: SEC-SQL-AUD-006-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_006_rc01 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user'
    ) AS username,
    COALESCE(
        j.value ->> 'state',
        j.value ->> 'status',
        j.value ->> 'command'
    ) AS state_val,
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    to_timestamp((j.value ->> 'start_hour')::bigint / 3.0) AS start_hour,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'session_id',
        j.value ->> 'sid',
        j.value ->> 'id'
    ) AS session_id,
    COALESCE(
        j.value ->> 'client_addr',
        j.value ->> 'host_name',
        j.value ->> 'machine',
        j.value ->> 'host'
    ) AS host,
    j.value ->> 'db' AS db,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time_val,
    COALESCE(
        j.value ->> 'query',
        j.value ->> 'info',
        j.value ->> 'sql_text',
        j.value ->> 'text'
    ) AS query_text,
    j.value ->> 'serial' AS serial,
    j.value ->> 'osuser' AS osuser,
    to_timestamp((j.value ->> 'logon_time')::bigint / 3.0) AS logon_time,
    COALESCE(
        j.value ->> 'application_name',
        j.value ->> 'program_name'
    ) AS application_name,
    j.value ->> 'current_hour' AS current_hour,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-006-RC01'
