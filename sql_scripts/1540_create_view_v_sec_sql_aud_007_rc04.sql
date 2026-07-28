DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_007_rc04;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_007_rc04
-- Root cause: SEC-SQL-AUD-007-RC04
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_007_rc04 AS
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
    COALESCE(
        j.value ->> 'application_name',
        j.value ->> 'program_name',
        j.value ->> 'program'
    ) AS application_name,
    COALESCE(
        j.value ->> 'host_name',
        j.value ->> 'machine',
        j.value ->> 'host'
    ) AS host,
    to_timestamp((j.value ->> 'login_time')::bigint / 3.0) AS login_time,
    COALESCE(
        j.value ->> 'state',
        j.value ->> 'status',
        j.value ->> 'command'
    ) AS state,
    j.value ->> 'utc_hour' AS utc_hour,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'id'
    ) AS session_id,
    j.value ->> 'db' AS db,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time,
    j.value ->> 'info' AS query_text,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    j.value ->> 'event_schema' AS event_schema,
    j.value ->> 'event_name' AS event_name,
    to_timestamp((j.value ->> 'execute_at')::bigint / 3.0) AS execute_at,
    j.value ->> 'interval_value' AS interval_value,
    j.value ->> 'interval_field' AS interval_field,
    j.value ->> 'definer' AS definer,
    j.value ->> 'job_name' AS job_name,
    to_timestamp((j.value ->> 'last_run_duration')::bigint / 3.0) AS last_run_duration,
    to_timestamp((j.value ->> 'next_run_date')::bigint / 3.0) AS next_run_date,
    to_timestamp((j.value ->> 'logon_time')::bigint / 3.0) AS logon_time,
    to_timestamp((j.value ->> 'active_start_time')::bigint / 3.0) AS active_start_time,
    to_timestamp((j.value ->> 'active_end_time')::bigint / 3.0) AS active_end_time,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'rolvaliduntil' AS rolvaliduntil,
    j.value ->> 'comment' AS comment,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-007-RC04'
