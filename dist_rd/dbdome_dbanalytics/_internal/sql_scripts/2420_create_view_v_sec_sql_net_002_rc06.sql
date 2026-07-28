DROP VIEW IF EXISTS monitoring.v_sec_sql_net_002_rc06;

-- ============================================================
-- View: monitoring.v_sec_sql_net_002_rc06
-- Root cause: SEC-SQL-NET-002-RC06
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_002_rc06 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'program_name',
        j.value ->> 'program'
    ) AS application_name,
    j.value ->> 'machine' AS host,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'setting' AS setting,
    j.value ->> 'source' AS source,
    j.value ->> 'port' AS port,
    j.value ->> 'ip_address' AS ip_address,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'local_tcp_port' AS local_tcp_port,
    j.value ->> 'distinct_hosts' AS distinct_hosts,
    j.value ->> 'distinct_programs' AS distinct_programs,
    j.value ->> 'distinct_machines' AS distinct_machines,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-NET-002-RC06'
  AND j.value ->> 'machine' IS DISTINCT FROM 'dbdome';
