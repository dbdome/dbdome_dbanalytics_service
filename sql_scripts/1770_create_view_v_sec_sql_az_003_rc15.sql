DROP VIEW IF EXISTS monitoring.v_sec_sql_az_003_rc15;

-- ============================================================
-- View: monitoring.v_sec_sql_az_003_rc15
-- Root cause: SEC-SQL-AZ-003-RC15
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc15 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'schema_name',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'select_priv' AS select_priv,
    j.value ->> 'insert_priv' AS insert_priv,
    j.value ->> 'update_priv' AS update_priv,
    j.value ->> 'delete_priv' AS delete_priv,
    to_timestamp((j.value ->> 'password_last_changed')::bigint / 3.0) AS password_last_changed,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolvaliduntil' AS rolvaliduntil,
    j.value ->> 'account_status' AS account_status,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    to_timestamp((j.value ->> 'last_login')::bigint / 3.0) AS last_login,
    j.value ->> 'roles' AS roles,
    j.value ->> 'class_desc' AS class_desc,
    j.value ->> 'object_name' AS object_name,
    j.value ->> 'permission_name' AS permission_name,
    j.value ->> 'state_desc' AS state_desc,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-003-RC15'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
