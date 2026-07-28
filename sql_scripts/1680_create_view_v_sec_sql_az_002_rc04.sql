DROP VIEW IF EXISTS monitoring.v_sec_sql_az_002_rc04;

-- ============================================================
-- View: monitoring.v_sec_sql_az_002_rc04
-- Root cause: SEC-SQL-AZ-002-RC04
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_002_rc04 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'compatibility_level' AS compatibility_level,
    j.value ->> 'compat_version' AS compat_version,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'proname' AS proname,
    j.value ->> 'proacl' AS proacl,
    COALESCE(
        j.value ->> 'db',
        j.value ->> 'database_name'
    ) AS db,
    j.value ->> 'host' AS host,
    j.value ->> 'select_priv' AS select_priv,
    j.value ->> 'insert_priv' AS insert_priv,
    j.value ->> 'update_priv' AS update_priv,
    j.value ->> 'delete_priv' AS delete_priv,
    j.value ->> 'create_priv' AS create_priv,
    j.value ->> 'drop_priv' AS drop_priv,
    j.value ->> 'permission_name' AS permission_name,
    j.value ->> 'class_desc' AS class_desc,
    j.value ->> 'object_name' AS object_name,
    j.value ->> 'grant_count' AS grant_count,
    to_timestamp((j.value ->> 'granted_role')::bigint / 3.0) AS granted_role,
    j.value ->> 'admin_option' AS admin_option,
    j.value ->> 'default_role' AS default_role,
    j.value ->> 'nspacl' AS nspacl,
    j.value ->> 'total_public_grants' AS total_public_grants,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-002-RC04'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
