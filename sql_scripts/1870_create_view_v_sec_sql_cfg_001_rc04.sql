DROP VIEW IF EXISTS monitoring.v_sec_sql_cfg_001_rc04;

-- ============================================================
-- View: monitoring.v_sec_sql_cfg_001_rc04
-- Root cause: SEC-SQL-CFG-001-RC04
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc04 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'value' AS value,
    j.value ->> 'isdefault' AS isdefault,
    j.value ->> 'ismodified' AS ismodified,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'configured_value' AS configured_value,
    j.value ->> 'runtime_value' AS runtime_value,
    j.value ->> 'drift_status' AS drift_status,
    j.value ->> 'policy_name' AS policy_name,
    j.value ->> 'audit_option' AS audit_option,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-CFG-001-RC04'
