DROP VIEW IF EXISTS monitoring.v_sec_sql_au_001_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_au_001_rc01
-- Root cause: SEC-SQL-AU-001-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc01 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'account_locked' AS account_locked,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'rolcreaterole' AS rolcreaterole,
    j.value ->> 'rolcreatedb' AS rolcreatedb,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'rolvaliduntil' AS rolvaliduntil,
    j.value ->> 'usertype' AS usertype,
    j.value ->> 'password_expired' AS password_expired,
    to_timestamp((j.value ->> 'password_last_changed')::bigint / 3.0) AS password_last_changed,
    j.value ->> 'account_status' AS account_status,
    j.value ->> 'profile' AS profile,
    j.value ->> 'resource_name' AS resource_name,
    j.value ->> 'limit' AS limit,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'days_until_expiration' AS days_until_expiration,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-001-RC01'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
