DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_010_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_pri_010_rc03
-- Root cause: SEC-SQL-PRI-010-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_010_rc03 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'session_id',
        j.value ->> 'sid',
        j.value ->> 'id'
    ) AS session_id,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user'
    ) AS username,
    COALESCE(
        j.value ->> 'client_addr',
        j.value ->> 'host_name',
        j.value ->> 'machine',
        j.value ->> 'host'
    ) AS host,
    COALESCE(
        j.value ->> 'application_name',
        j.value ->> 'program_name',
        j.value ->> 'program'
    ) AS application_name,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    j.value ->> 'db' AS db,
    j.value ->> 'command' AS state,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time,
    j.value ->> 'info' AS query_text,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-010-RC03'
