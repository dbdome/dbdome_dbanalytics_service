DROP VIEW IF EXISTS monitoring.v_sec_sql_au_003_rc09;

-- ============================================================
-- View: monitoring.v_sec_sql_au_003_rc09
-- Root cause: SEC-SQL-AU-003-RC09
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc09 AS
SELECT
    r.server,
    j.value ->> 'plugin' AS plugin,
    j.value ->> 'account_count' AS account_count,
    j.value ->> 'auth_method' AS auth_method,
    j.value ->> 'rule_count' AS rule_count,
    j.value ->> 'total_sql_logins' AS total_sql_logins,
    j.value ->> 'policy_enforced_count' AS policy_enforced_count,
    j.value ->> 'policy_not_enforced_count' AS policy_not_enforced_count,
    j.value ->> 'expiration_enforced_count' AS expiration_enforced_count,
    j.value ->> 'expiration_not_enforced_count' AS expiration_not_enforced_count,
    j.value ->> 'pct_without_policy' AS pct_without_policy,
    j.value ->> 'profile' AS profile,
    j.value ->> 'user_count' AS user_count,
    j.value ->> 'active_users' AS active_users,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    j.value ->> 'resource_name' AS resource_name,
    j.value ->> 'limit' AS limit,
    j.value ->> 'name' AS username,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'password_age_days' AS password_age_days,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-003-RC09'
