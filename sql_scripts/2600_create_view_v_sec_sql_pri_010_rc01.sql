DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_010_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_pri_010_rc01
-- Root cause: SEC-SQL-PRI-010-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_010_rc01 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'client_addr',
        j.value ->> 'host'
    ) AS host,
    j.value ->> 'conn_count' AS conn_count,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user'
    ) AS username,
    j.value ->> 'failed_count' AS failed_count,
    j.value ->> 'os_username' AS os_username,
    to_timestamp((j.value ->> 'last_failure')::bigint / 3.0) AS last_failure,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-010-RC01'
