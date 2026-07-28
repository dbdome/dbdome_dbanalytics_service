DROP VIEW IF EXISTS monitoring.v_sec_sql_net_001_rc12;

-- ============================================================
-- View: monitoring.v_sec_sql_net_001_rc12
-- Root cause: SEC-SQL-NET-001-RC12
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_001_rc12 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'days_until_expiration' AS days_until_expiration,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    j.value ->> 'is_expired' AS is_expired,
    j.value ->> 'is_locked' AS is_locked,
    j.value ->> 'must_change' AS must_change,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    j.value ->> 'is_disabled' AS is_disabled,
    to_timestamp((j.value ->> 'days_since_created')::bigint / 3.0) AS days_since_created,
    j.value ->> 'host' AS host,
    j.value ->> 'account_status' AS account_status,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    j.value ->> 'days_active' AS days_active,
    j.value ->> 'profile' AS profile,
    j.value ->> 'line_number' AS line_number,
    j.value ->> 'type' AS state,
    j.value ->> 'database' AS database,
    j.value ->> 'user_name' AS user_name,
    j.value ->> 'address' AS address,
    j.value ->> 'auth_method' AS auth_method,
    j.value ->> 'super_priv' AS super_priv,
    j.value ->> 'grant_priv' AS grant_priv,
    j.value ->> 'create_user_priv' AS create_user_priv,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-NET-001-RC12'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
