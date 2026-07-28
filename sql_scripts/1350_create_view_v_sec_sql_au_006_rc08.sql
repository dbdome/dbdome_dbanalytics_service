DROP VIEW IF EXISTS monitoring.v_sec_sql_au_006_rc08;

-- ============================================================
-- View: monitoring.v_sec_sql_au_006_rc08
-- Root cause: SEC-SQL-AU-006-RC08
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_006_rc08 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'type_desc' AS type_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    j.value ->> 'is_disabled' AS is_disabled,
    to_timestamp((j.value ->> 'days_since_modified')::bigint / 3.0) AS days_since_modified,
    j.value ->> 'auth_method' AS auth_method,
    j.value ->> 'rule_count' AS rule_count,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    j.value ->> 'profile' AS profile,
    j.value ->> 'authentication_type' AS authentication_type,
    j.value ->> 'external_name' AS external_name,
    j.value ->> 'local_accounts' AS local_accounts,
    j.value ->> 'value' AS value,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-006-RC08'
