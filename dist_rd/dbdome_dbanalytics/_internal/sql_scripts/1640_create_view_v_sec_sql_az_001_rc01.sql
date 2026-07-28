DROP VIEW IF EXISTS monitoring.v_sec_sql_az_001_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_az_001_rc01
-- Root cause: SEC-SQL-AZ-001-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc01 AS
SELECT
    r.server,
    j.value ->> 'role_grants' AS role_grants,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'grantee'
    ) AS username,
    j.value ->> 'usertype' AS usertype,
    j.value ->> 'direct_user_grants' AS direct_user_grants,
    j.value ->> 'total_grants' AS total_grants,
    j.value ->> 'host' AS host,
    j.value ->> 'super_users' AS super_users,
    j.value ->> 'direct_privs' AS direct_privs,
    j.value ->> 'direct_grants' AS direct_grants,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-001-RC01'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
