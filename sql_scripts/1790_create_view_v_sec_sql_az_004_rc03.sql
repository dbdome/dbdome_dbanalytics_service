DROP VIEW IF EXISTS monitoring.v_sec_sql_az_004_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_az_004_rc03
-- Root cause: SEC-SQL-AZ-004-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc03 AS
SELECT
    r.server,
    j.value ->> 'directory_name' AS directory_name,
    j.value ->> 'directory_path' AS directory_path,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'grantee',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'privilege' AS privilege,
    COALESCE(
        j.value ->> 'host_name',
        j.value ->> 'host'
    ) AS host,
    j.value ->> 'file_priv' AS file_priv,
    j.value ->> 'select_priv' AS select_priv,
    j.value ->> 'db_access' AS db_access,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'program_name' AS application_name,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    to_timestamp((j.value ->> 'granted_roles')::bigint / 3.0) AS granted_roles,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-004-RC03'
