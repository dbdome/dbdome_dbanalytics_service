DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_002_rc05;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_002_rc05
-- Root cause: SEC-SQL-AUD-002-RC05
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_002_rc05 AS
SELECT
    r.server,
    j.value ->> 'file_audit_count' AS file_audit_count,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'is_state_enabled' AS is_state_enabled,
    j.value ->> 'on_failure_desc' AS on_failure_desc,
    j.value ->> 'retention_risk' AS retention_risk,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-002-RC05'
