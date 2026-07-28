DROP VIEW IF EXISTS monitoring.v_sec_sql_az_003_rc08;

-- ============================================================
-- View: monitoring.v_sec_sql_az_003_rc08
-- Root cause: SEC-SQL-AZ-003-RC08
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc08 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'source_hosts' AS source_hosts,
    j.value ->> 'current_conns' AS current_conns,
    j.value ->> 'distinct_machines' AS distinct_machines,
    j.value ->> 'distinct_programs' AS distinct_programs,
    j.value ->> 'current_sessions' AS current_sessions,
    j.value ->> 'total_sessions' AS total_sessions,
    j.value ->> 'distinct_hosts' AS distinct_hosts,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'distinct_sources' AS distinct_sources,
    j.value ->> 'source_ips' AS source_ips,
    j.value ->> 'host' AS host,
    j.value ->> 'select_priv' AS select_priv,
    j.value ->> 'insert_priv' AS insert_priv,
    j.value ->> 'super_priv' AS super_priv,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-003-RC08'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
