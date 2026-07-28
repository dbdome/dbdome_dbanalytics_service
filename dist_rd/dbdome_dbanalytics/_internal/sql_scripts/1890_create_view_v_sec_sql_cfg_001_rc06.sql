DROP VIEW IF EXISTS monitoring.v_sec_sql_cfg_001_rc06;

-- ============================================================
-- View: monitoring.v_sec_sql_cfg_001_rc06
-- Root cause: SEC-SQL-CFG-001-RC06
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc06 AS
SELECT
    r.server,
    j.value ->> 'servicename' AS servicename,
    j.value ->> 'service_account' AS service_account,
    j.value ->> 'status_desc' AS status_desc,
    j.value ->> 'privilege_assessment' AS privilege_assessment,
    j.value ->> 'xp_cmdshell_enabled' AS xp_cmdshell_enabled,
    j.value ->> 'server_name' AS server_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-CFG-001-RC06'
