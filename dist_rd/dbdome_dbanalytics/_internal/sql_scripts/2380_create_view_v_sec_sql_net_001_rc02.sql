DROP VIEW IF EXISTS monitoring.v_sec_sql_net_001_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_net_001_rc02
-- Root cause: SEC-SQL-NET-001-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_001_rc02 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'login_name',
        j.value ->> 'user'
    ) AS username,
    COALESCE(
        j.value ->> 'host_name',
        j.value ->> 'host'
    ) AS host,
    j.value ->> 'source_host' AS source_host,
    COALESCE(
        j.value ->> 'program_name',
        j.value ->> 'program'
    ) AS application_name,
    j.value ->> 'session_count' AS session_count,
    to_timestamp((j.value ->> 'event_time')::bigint / 3.0) AS event_time,
    j.value ->> 'error_number' AS error_number,
    j.value ->> 'error_message' AS error_message,
    j.value ->> 'authentication_string' AS authentication_string,
    j.value ->> 'line_number' AS line_number,
    j.value ->> 'type' AS state_val,
    j.value ->> 'database' AS database_val,
    j.value ->> 'user_name' AS user_name,
    j.value ->> 'address' AS address,
    j.value ->> 'netmask' AS netmask,
    j.value ->> 'auth_method' AS auth_method,
    j.value ->> 'client_net_address' AS client_net_address,
    j.value ->> 'auth_scheme' AS auth_scheme,
    j.value ->> 'encrypt_option' AS encrypt_option,
    to_timestamp((j.value ->> 'login_time')::bigint / 3.0) AS login_time,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'ip_address' AS ip_address,
    j.value ->> 'port' AS port,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'state_desc' AS state_desc,
    j.value ->> 'userhost' AS userhost,
    j.value ->> 'failed_attempts' AS failed_attempts,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-NET-001-RC02'
