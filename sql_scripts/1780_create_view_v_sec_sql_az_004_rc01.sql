DROP VIEW IF EXISTS monitoring.v_sec_sql_az_004_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_az_004_rc01
-- Root cause: SEC-SQL-AZ-004-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc01 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'grantee',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'permission_name' AS permission_name,
    j.value ->> 'state_desc' AS state_desc,
    j.value ->> 'object_name' AS object_name,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'roleid' AS roleid,
    j.value ->> 'host' AS host,
    j.value ->> 'file_priv' AS file_priv,
    j.value ->> 'privilege' AS privilege,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'is_enabled' AS is_enabled,
    j.value ->> 'description' AS description,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-004-RC01'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
