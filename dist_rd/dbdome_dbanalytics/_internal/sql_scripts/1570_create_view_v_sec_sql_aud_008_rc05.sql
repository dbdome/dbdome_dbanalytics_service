DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_008_rc05;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_008_rc05
-- Root cause: SEC-SQL-AUD-008-RC05
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_008_rc05 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'id'
    ) AS session_id,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'schema_name',
        j.value ->> 'name'
    ) AS username,
    COALESCE(
        j.value ->> 'query',
        j.value ->> 'info',
        j.value ->> 'sql_text',
        j.value ->> 'text'
    ) AS query_text,
    to_timestamp((j.value ->> 'query_start')::bigint / 3.0) AS query_start,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'default_character_set_name' AS default_character_set_name,
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    j.value ->> 'db' AS db,
    j.value ->> 'host' AS host,
    to_timestamp((j.value ->> 'time')::bigint / 3.0) AS time,
    j.value ->> 'executions' AS executions,
    to_timestamp((j.value ->> 'last_active_time')::bigint / 3.0) AS last_active_time,
    j.value ->> 'account_status' AS account_status,
    j.value ->> 'profile' AS profile,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    j.value ->> 'object_count' AS object_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-008-RC05'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
