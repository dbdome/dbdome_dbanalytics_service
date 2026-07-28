DROP VIEW IF EXISTS monitoring.v_sec_sql_az_004_rc07;

-- ============================================================
-- View: monitoring.v_sec_sql_az_004_rc07
-- Root cause: SEC-SQL-AZ-004-RC07
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc07 AS
SELECT
    r.server,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'text' AS query_text,
    j.value ->> 'execution_count' AS execution_count,
    to_timestamp((j.value ->> 'last_execution_time')::bigint / 3.0) AS last_execution_time,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'grantee',
        j.value ->> 'owner',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'file_priv' AS file_priv,
    j.value ->> 'super_priv' AS super_priv,
    to_timestamp((j.value ->> 'password_last_changed')::bigint / 3.0) AS password_last_changed,
    j.value ->> 'is_enabled' AS is_enabled,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'privilege' AS privilege,
    j.value ->> 'grantor' AS grantor,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-004-RC07'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
