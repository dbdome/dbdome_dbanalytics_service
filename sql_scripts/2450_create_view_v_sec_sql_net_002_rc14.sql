DROP VIEW IF EXISTS monitoring.v_sec_sql_net_002_rc14;

-- ============================================================
-- View: monitoring.v_sec_sql_net_002_rc14
-- Root cause: SEC-SQL-NET-002-RC14
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_002_rc14 AS
SELECT
    r.server,
    j.value ->> 'instance_name' AS instance_name,
    to_timestamp((j.value ->> 'startup_time')::bigint / 3.0) AS startup_time,
    j.value ->> 'uptime_days' AS uptime_days,
    j.value ->> 'version' AS version,
    j.value ->> 'setting' AS setting,
    j.value ->> 'source' AS source,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-NET-002-RC14'
