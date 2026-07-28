DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_002_rc10;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_002_rc10
-- Root cause: SEC-SQL-INJ-002-RC10
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc10 AS
SELECT
    r.server,
    j.value ->> 'audit_enabled' AS audit_enabled,
    j.value ->> 'status' AS state_val,
    j.value ->> 'name' AS username,
    j.value ->> 'is_enabled' AS is_enabled,
    j.value ->> 'lanname' AS lanname,
    j.value ->> 'lanpltrusted' AS lanpltrusted,
    j.value ->> 'rolname' AS rolname,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC10'
