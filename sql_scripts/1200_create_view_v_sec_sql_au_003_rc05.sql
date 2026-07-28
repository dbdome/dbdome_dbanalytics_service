DROP VIEW IF EXISTS monitoring.v_sec_sql_au_003_rc05;

-- ============================================================
-- View: monitoring.v_sec_sql_au_003_rc05
-- Root cause: SEC-SQL-AU-003-RC05
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc05 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'profile' AS profile,
    j.value ->> 'resource_name' AS resource_name,
    j.value ->> 'limit' AS limit,
    j.value ->> 'object_name' AS object_name,
    j.value ->> 'object_type' AS object_type,
    j.value ->> 'status' AS state,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'login_name_length' AS login_name_length,
    j.value ->> 'is_blank' AS is_blank,
    j.value ->> 'is_same_as_login' AS is_same_as_login,
    to_timestamp((j.value ->> 'password_last_set')::bigint / 3.0) AS password_last_set,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-003-RC05'
