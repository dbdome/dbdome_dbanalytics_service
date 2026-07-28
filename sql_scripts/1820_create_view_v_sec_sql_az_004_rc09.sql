DROP VIEW IF EXISTS monitoring.v_sec_sql_az_004_rc09;

-- ============================================================
-- View: monitoring.v_sec_sql_az_004_rc09
-- Root cause: SEC-SQL-AZ-004-RC09
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc09 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'grantee',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'privilege' AS privilege,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'directory_val' AS directory_val,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'account_age_days' AS account_age_days,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolvaliduntil' AS rolvaliduntil,
    j.value ->> 'description' AS description,
    j.value ->> 'host' AS host,
    j.value ->> 'file_priv' AS file_priv,
    to_timestamp((j.value ->> 'password_last_changed')::bigint / 3.0) AS password_last_changed,
    j.value ->> 'password_age_days' AS password_age_days,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-004-RC09'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
