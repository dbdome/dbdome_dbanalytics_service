DROP VIEW IF EXISTS monitoring.v_sec_sql_net_002_rc08;

-- ============================================================
-- View: monitoring.v_sec_sql_net_002_rc08
-- Root cause: SEC-SQL-NET-002-RC08
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_002_rc08 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'value' AS value_val,
    j.value ->> 'servicename' AS servicename,
    j.value ->> 'status_desc' AS status_desc,
    j.value ->> 'startup_type_desc' AS startup_type_desc,
    j.value ->> 'local_tcp_port' AS local_tcp_port,
    j.value ->> 'setting' AS setting,
    j.value ->> 'source' AS source,
    j.value ->> 'port' AS port,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-NET-002-RC08'
