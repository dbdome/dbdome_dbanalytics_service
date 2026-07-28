DROP VIEW IF EXISTS monitoring.v_sec_sql_az_004_rc08;

-- ============================================================
-- View: monitoring.v_sec_sql_az_004_rc08
-- Root cause: SEC-SQL-AZ-004-RC08
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc08 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'grantee',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'privilege' AS privilege,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'directory_path' AS directory_path,
    j.value ->> 'host' AS host,
    j.value ->> 'file_priv' AS file_priv,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    to_timestamp((j.value ->> 'granted_roles')::bigint / 3.0) AS granted_roles,
    j.value ->> 'product' AS product,
    j.value ->> 'provider' AS provider,
    j.value ->> 'data_source' AS data_source,
    j.value ->> 'is_data_access_enabled' AS is_data_access_enabled,
    j.value ->> 'is_rpc_out_enabled' AS is_rpc_out_enabled,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-004-RC08'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
