DROP VIEW IF EXISTS monitoring.v_sec_sql_au_001_rc08;

-- ============================================================
-- View: monitoring.v_sec_sql_au_001_rc08
-- Root cause: SEC-SQL-AU-001-RC08
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc08 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'owner',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'account_status' AS account_status,
    j.value ->> 'authentication_type' AS authentication_type,
    to_timestamp((j.value ->> 'last_login')::bigint / 3.0) AS last_login,
    j.value ->> 'days_inactive' AS days_inactive,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'auth_method' AS auth_method,
    j.value ->> 'address' AS address,
    j.value ->> 'db_link' AS db_link,
    j.value ->> 'host' AS host,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'password_age_days' AS password_age_days,
    j.value ->> 'enabled_sql_logins' AS enabled_sql_logins,
    j.value ->> 'enabled_windows_logins' AS enabled_windows_logins,
    j.value ->> 'enabled_windows_groups' AS enabled_windows_groups,
    j.value ->> 'enabled_external_logins' AS enabled_external_logins,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-001-RC08'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
