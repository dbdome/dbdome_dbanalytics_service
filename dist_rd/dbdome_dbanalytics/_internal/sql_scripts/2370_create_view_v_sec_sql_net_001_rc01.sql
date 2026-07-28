DROP VIEW IF EXISTS monitoring.v_sec_sql_net_001_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_net_001_rc01
-- Root cause: SEC-SQL-NET-001-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_001_rc01 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    COALESCE(
        j.value ->> 'machine',
        j.value ->> 'host'
    ) AS host,
    j.value ->> 'listener_id' AS listener_id,
    j.value ->> 'ip_address' AS ip_address,
    j.value ->> 'port' AS port,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'state_desc' AS state_desc,
    to_timestamp((j.value ->> 'start_time')::bigint / 3.0) AS start_time,
    j.value ->> 'value' AS value_val,
    j.value ->> 'connections' AS connections,
    j.value ->> 'local_net_address' AS local_net_address,
    j.value ->> 'local_tcp_port' AS local_tcp_port,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'setting' AS setting,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-NET-001-RC01'
