DROP VIEW IF EXISTS monitoring.v_sec_sql_net_001_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_net_001_rc03
-- Root cause: SEC-SQL-NET-001-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_001_rc03 AS
SELECT
    r.server,
    j.value ->> 'listener_id' AS listener_id,
    j.value ->> 'ip_address' AS ip_address,
    j.value ->> 'port' AS port,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'state_desc' AS state_desc,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'client_net_address' AS client_net_address,
    j.value ->> 'local_net_address' AS local_net_address,
    to_timestamp((j.value ->> 'connect_time')::bigint / 3.0) AS connect_time,
    j.value ->> 'login_name' AS username,
    j.value ->> 'host_name' AS host,
    COALESCE(
        j.value ->> 'program_name',
        j.value ->> 'program'
    ) AS application_name,
    j.value ->> 'host_pattern' AS host_pattern,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'extname' AS extname,
    j.value ->> 'machine' AS machine,
    j.value ->> 'osuser' AS osuser,
    j.value ->> 'setting' AS setting,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-NET-001-RC03'
  AND j.value ->> 'host_name' IS DISTINCT FROM 'dbdome';
