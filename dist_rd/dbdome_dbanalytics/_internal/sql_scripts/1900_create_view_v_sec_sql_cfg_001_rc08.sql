DROP VIEW IF EXISTS monitoring.v_sec_sql_cfg_001_rc08;

-- ============================================================
-- View: monitoring.v_sec_sql_cfg_001_rc08
-- Root cause: SEC-SQL-CFG-001-RC08
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc08 AS
SELECT
    r.server,
    j.value ->> 'xp_cmdshell_enabled' AS xp_cmdshell_enabled,
    j.value ->> 'name' AS username,
    j.value ->> 'value' AS value,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'member_count' AS member_count,
    j.value ->> 'usage_pattern' AS usage_pattern,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-CFG-001-RC08'
