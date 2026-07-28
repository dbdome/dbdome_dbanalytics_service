DROP VIEW IF EXISTS monitoring.v_sec_sql_au_003_rc07;

-- ============================================================
-- View: monitoring.v_sec_sql_au_003_rc07
-- Root cause: SEC-SQL-AU-003-RC07
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc07 AS
SELECT
    r.server,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolvaliduntil' AS rolvaliduntil,
    j.value ->> 'profile' AS profile,
    j.value ->> 'resource_name' AS resource_name,
    j.value ->> 'limit' AS limit,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'password_age_days' AS password_age_days,
    j.value ->> 'host' AS host,
    to_timestamp((j.value ->> 'password_last_changed')::bigint / 3.0) AS password_last_changed,
    j.value ->> 'days_since_change' AS days_since_change,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'hash_algorithm' AS hash_algorithm,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-003-RC07'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
