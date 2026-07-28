DROP VIEW IF EXISTS monitoring.v_sec_sql_cfg_001_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_cfg_001_rc01
-- Root cause: SEC-SQL-CFG-001-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc01 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'schema_name',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'is_enabled' AS is_enabled,
    j.value ->> 'description' AS description,
    j.value ->> 'compatibility_level' AS compatibility_level,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'age_years' AS age_years,
    j.value ->> 'stored_procedure' AS stored_procedure,
    to_timestamp((j.value ->> 'modify_date')::bigint / 3.0) AS modify_date,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-CFG-001-RC01'
