DROP VIEW IF EXISTS monitoring.v_sec_sql_az_002_rc06;

-- ============================================================
-- View: monitoring.v_sec_sql_az_002_rc06
-- Root cause: SEC-SQL-AZ-002-RC06
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_002_rc06 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'owner',
        j.value ->> 'schema_name'
    ) AS username,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'privilege' AS privilege,
    j.value ->> 'host' AS host,
    j.value ->> 'db' AS db,
    j.value ->> 'select_priv' AS select_priv,
    j.value ->> 'insert_priv' AS insert_priv,
    j.value ->> 'permission_name' AS permission_name,
    j.value ->> 'class_desc' AS class_desc,
    j.value ->> 'object_name' AS object_name,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'schemaname' AS schemaname,
    j.value ->> 'tablename' AS tablename,
    j.value ->> 'scope' AS scope,
    j.value ->> 'state_desc' AS state_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-002-RC06'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
