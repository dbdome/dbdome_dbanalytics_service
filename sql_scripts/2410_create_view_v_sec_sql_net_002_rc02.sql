DROP VIEW IF EXISTS monitoring.v_sec_sql_net_002_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_net_002_rc02
-- Root cause: SEC-SQL-NET-002-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_002_rc02 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'default_count' AS default_count,
    j.value ->> 'port' AS port,
    j.value ->> 'value' AS value,
    j.value ->> 'isdefault' AS isdefault,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-NET-002-RC02'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
