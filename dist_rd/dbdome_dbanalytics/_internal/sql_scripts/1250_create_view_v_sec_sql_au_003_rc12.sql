DROP VIEW IF EXISTS monitoring.v_sec_sql_au_003_rc12;

-- ============================================================
-- View: monitoring.v_sec_sql_au_003_rc12
-- Root cause: SEC-SQL-AU-003-RC12
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc12 AS
SELECT
    r.server,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'login_count' AS login_count,
    j.value ->> 'logins' AS logins,
    j.value ->> 'extname' AS extname,
    j.value ->> 'min_password_age_days' AS min_password_age_days,
    j.value ->> 'max_password_age_days' AS max_password_age_days,
    j.value ->> 'avg_password_age_days' AS avg_password_age_days,
    j.value ->> 'stdev_password_age_days' AS stdev_password_age_days,
    j.value ->> 'total_logins' AS total_logins,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-003-RC12'
