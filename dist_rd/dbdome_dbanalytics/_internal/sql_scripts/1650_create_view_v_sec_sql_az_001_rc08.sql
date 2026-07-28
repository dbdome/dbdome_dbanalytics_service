DROP VIEW IF EXISTS monitoring.v_sec_sql_az_001_rc08;

-- ============================================================
-- View: monitoring.v_sec_sql_az_001_rc08
-- Root cause: SEC-SQL-AZ-001-RC08
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc08 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'super_priv' AS super_priv,
    j.value ->> 'create_priv' AS create_priv,
    j.value ->> 'grant_priv' AS grant_priv,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'rolcreatedb' AS rolcreatedb,
    j.value ->> 'rolvaliduntil' AS rolvaliduntil,
    to_timestamp((j.value ->> 'password_last_changed')::bigint / 3.0) AS password_last_changed,
    j.value ->> 'days_since_change' AS days_since_change,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    j.value ->> 'account_status' AS account_status,
    to_timestamp((j.value ->> 'last_login')::bigint / 3.0) AS last_login,
    j.value ->> 'days_since_login' AS days_since_login,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-001-RC08'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
