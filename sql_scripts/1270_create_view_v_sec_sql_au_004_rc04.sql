DROP VIEW IF EXISTS monitoring.v_sec_sql_au_004_rc04;

-- ============================================================
-- View: monitoring.v_sec_sql_au_004_rc04
-- Root cause: SEC-SQL-AU-004-RC04
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_004_rc04 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'plugin' AS plugin,
    j.value ->> 'authentication_type' AS authentication_type,
    j.value ->> 'external_name' AS external_name,
    j.value ->> 'account_status' AS account_status,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'domain_name' AS domain_name,
    j.value ->> 'is_sysadmin' AS is_sysadmin,
    j.value ->> 'is_securityadmin' AS is_securityadmin,
    j.value ->> 'is_dbcreator' AS is_dbcreator,
    j.value ->> 'value' AS value,
    j.value ->> 'is_disabled' AS is_disabled,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'default_database_name' AS default_database_name,
    j.value ->> 'line_number' AS line_number,
    j.value ->> 'type' AS state,
    j.value ->> 'database' AS database,
    j.value ->> 'user_name' AS user_name,
    j.value ->> 'address' AS address,
    j.value ->> 'auth_method' AS auth_method,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-004-RC04'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
