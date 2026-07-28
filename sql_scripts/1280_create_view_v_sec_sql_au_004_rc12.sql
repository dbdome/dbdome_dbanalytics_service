DROP VIEW IF EXISTS monitoring.v_sec_sql_au_004_rc12;

-- ============================================================
-- View: monitoring.v_sec_sql_au_004_rc12
-- Root cause: SEC-SQL-AU-004-RC12
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_004_rc12 AS
SELECT
    r.server,
    j.value ->> 'os_auth_audit_count' AS os_auth_audit_count,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'policy_name' AS policy_name,
    j.value ->> 'audit_option' AS audit_option,
    j.value ->> 'audit_condition' AS audit_condition,
    j.value ->> 'plugin' AS plugin,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-004-RC12'
