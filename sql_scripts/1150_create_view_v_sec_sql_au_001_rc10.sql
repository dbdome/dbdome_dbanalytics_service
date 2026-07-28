DROP VIEW IF EXISTS monitoring.v_sec_sql_au_001_rc10;

-- ============================================================
-- View: monitoring.v_sec_sql_au_001_rc10
-- Root cause: SEC-SQL-AU-001-RC10
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc10 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    to_timestamp((j.value ->> 'last_login')::bigint / 3.0) AS last_login,
    j.value ->> 'host' AS host,
    j.value ->> 'select_priv' AS select_priv,
    j.value ->> 'insert_priv' AS insert_priv,
    j.value ->> 'update_priv' AS update_priv,
    j.value ->> 'delete_priv' AS delete_priv,
    j.value ->> 'create_priv' AS create_priv,
    j.value ->> 'drop_priv' AS drop_priv,
    j.value ->> 'grant_priv' AS grant_priv,
    j.value ->> 'super_priv' AS super_priv,
    j.value ->> 'create_user_priv' AS create_user_priv,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'server_roles' AS server_roles,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'object_count' AS object_count,
    j.value ->> 'db' AS db,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-001-RC10'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
