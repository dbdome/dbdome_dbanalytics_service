DROP VIEW IF EXISTS monitoring.v_sec_sql_au_005_rc06;

-- ============================================================
-- View: monitoring.v_sec_sql_au_005_rc06
-- Root cause: SEC-SQL-AU-005-RC06
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc06 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'account_status' AS account_status,
    j.value ->> 'profile' AS profile,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    to_timestamp((j.value ->> 'last_login')::bigint / 3.0) AS last_login,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'windows_auth_only' AS windows_auth_only,
    j.value ->> 'server_name' AS server_name,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-005-RC06'
