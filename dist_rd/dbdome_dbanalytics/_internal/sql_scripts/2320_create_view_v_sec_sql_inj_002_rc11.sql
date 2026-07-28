DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_002_rc11;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_002_rc11
-- Root cause: SEC-SQL-INJ-002-RC11
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc11 AS
SELECT
    r.server,
    j.value ->> 'servicename' AS servicename,
    j.value ->> 'service_account' AS service_account,
    j.value ->> 'startup_type_desc' AS startup_type_desc,
    j.value ->> 'status_desc' AS status_desc,
    j.value ->> 'privilege_assessment' AS privilege_assessment,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC11'
