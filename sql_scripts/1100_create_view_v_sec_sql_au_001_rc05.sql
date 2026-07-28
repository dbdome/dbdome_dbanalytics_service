DROP VIEW IF EXISTS monitoring.v_sec_sql_au_001_rc05;

-- ============================================================
-- View: monitoring.v_sec_sql_au_001_rc05
-- Root cause: SEC-SQL-AU-001-RC05
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc05 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'rolcreaterole' AS rolcreaterole,
    j.value ->> 'rolcreatedb' AS rolcreatedb,
    j.value ->> 'rolreplication' AS rolreplication,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'rolconnlimit' AS rolconnlimit,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'is_disabled' AS is_disabled,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    j.value ->> 'account_purpose' AS account_purpose,
    j.value ->> 'plugin' AS plugin,
    j.value ->> 'account_locked' AS account_locked,
    j.value ->> 'password_expired' AS password_expired,
    j.value ->> 'password_lifetime' AS password_lifetime,
    j.value ->> 'account_type' AS account_type,
    j.value ->> 'account_status' AS account_status,
    j.value ->> 'profile' AS profile,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    j.value ->> 'default_tablespace' AS default_tablespace,
    j.value ->> 'oracle_maintained' AS oracle_maintained,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-001-RC05'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
