DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_002_rc15;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_002_rc15
-- Root cause: SEC-SQL-INJ-002-RC15
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc15 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'schema_name',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'proc_name' AS proc_name,
    j.value ->> 'injection_risk_level' AS injection_risk_level,
    j.value ->> 'is_enabled' AS is_enabled,
    j.value ->> 'state_desc' AS state_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC15'
