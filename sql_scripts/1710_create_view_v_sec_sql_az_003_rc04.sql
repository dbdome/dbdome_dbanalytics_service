DROP VIEW IF EXISTS monitoring.v_sec_sql_az_003_rc04;

-- ============================================================
-- View: monitoring.v_sec_sql_az_003_rc04
-- Root cause: SEC-SQL-AZ-003-RC04
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc04 AS
SELECT
    r.server,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'name' AS username,
    j.value ->> 'value' AS value,
    j.value ->> 'plugin' AS plugin,
    j.value ->> 'user_count' AS user_count,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'authentication_type_desc' AS authentication_type_desc,
    j.value ->> 'auth_category' AS auth_category,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    j.value ->> 'database_name' AS db,
    j.value ->> 'auth_method' AS auth_method,
    j.value ->> 'rule_count' AS rule_count,
    j.value ->> 'sql_logins' AS sql_logins,
    j.value ->> 'windows_logins' AS windows_logins,
    j.value ->> 'windows_groups' AS windows_groups,
    j.value ->> 'total_logins' AS total_logins,
    j.value ->> 'pct_sql_auth' AS pct_sql_auth,
    j.value ->> 'authentication_type' AS authentication_type,
    j.value ->> 'local_login_roles' AS local_login_roles,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-003-RC04'
