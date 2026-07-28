DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_007_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_pri_007_rc01
-- Root cause: SEC-SQL-PRI-007-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_007_rc01 AS
SELECT
    r.server,
    j.value ->> 'variable_name' AS variable_name,
    j.value ->> 'variable_value' AS variable_value,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'profile' AS profile,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-007-RC01'
