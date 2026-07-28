DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_010_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_pri_010_rc02
-- Root cause: SEC-SQL-PRI-010-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_010_rc02 AS
SELECT
    r.server,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'rolcreaterole' AS rolcreaterole,
    j.value ->> 'rolcreatedb' AS rolcreatedb,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'grantee',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'super_priv' AS super_priv,
    j.value ->> 'grant_priv' AS grant_priv,
    to_timestamp((j.value ->> 'granted_role')::bigint / 3.0) AS granted_role,
    j.value ->> 'default_role' AS default_role,
    j.value ->> 'admin_option' AS admin_option,
    j.value ->> 'role_principal_id' AS role_principal_id,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-010-RC02'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
