DROP VIEW IF EXISTS monitoring.v_sec_sql_az_001_rc12;

-- ============================================================
-- View: monitoring.v_sec_sql_az_001_rc12
-- Root cause: SEC-SQL-AZ-001-RC12
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc12 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'grantee',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'authentication_string' AS authentication_string,
    j.value ->> 'profile' AS profile,
    j.value ->> 'resource_name' AS resource_name,
    j.value ->> 'limit' AS limit,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'rolvaliduntil' AS rolvaliduntil,
    j.value ->> 'rolconnlimit' AS rolconnlimit,
    j.value ->> 'current_value' AS current_value,
    j.value ->> 'hardened_value' AS hardened_value,
    j.value ->> 'status' AS state,
    j.value ->> 'account_status' AS account_status,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    j.value ->> 'authentication_type' AS authentication_type,
    j.value ->> 'privilege' AS privilege,
    j.value ->> 'test_db_exists' AS test_db_exists,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-001-RC12'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
