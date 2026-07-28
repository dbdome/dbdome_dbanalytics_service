DROP VIEW IF EXISTS monitoring.v_sec_sql_au_001_rc07;

-- ============================================================
-- View: monitoring.v_sec_sql_au_001_rc07
-- Root cause: SEC-SQL-AU-001-RC07
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc07 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'grantee',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'account_locked' AS account_locked,
    j.value ->> 'password_expired' AS password_expired,
    j.value ->> 'plugin' AS plugin,
    j.value ->> 'active_sa_sessions' AS active_sa_sessions,
    j.value ->> 'most_recent_sa_login' AS most_recent_sa_login,
    j.value ->> 'guarantee_flashback_database' AS guarantee_flashback_database,
    j.value ->> 'storage_size' AS storage_size,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'bad_password_count' AS bad_password_count,
    to_timestamp((j.value ->> 'lockout_time')::bigint / 3.0) AS lockout_time,
    j.value ->> 'privilege_type' AS privilege_type,
    j.value ->> 'privilege' AS privilege,
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
WHERE r.metric_name = 'SEC-SQL-AU-001-RC07'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
