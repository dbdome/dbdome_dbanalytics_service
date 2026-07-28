DROP VIEW IF EXISTS monitoring.v_sec_sql_cfg_001_rc11;

-- ============================================================
-- View: monitoring.v_sec_sql_cfg_001_rc11
-- Root cause: SEC-SQL-CFG-001-RC11
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc11 AS
SELECT
    r.server,
    j.value ->> 'xp_cmdshell_enabled' AS xp_cmdshell_enabled,
    COALESCE(
        j.value ->> 'owner',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'enabled' AS enabled,
    to_timestamp((j.value ->> 'date_created')::bigint / 3.0) AS date_created,
    to_timestamp((j.value ->> 'date_modified')::bigint / 3.0) AS date_modified,
    j.value ->> 'step_name' AS step_name,
    j.value ->> 'subsystem' AS subsystem,
    j.value ->> 'cmdshell_pattern' AS cmdshell_pattern,
    j.value ->> 'job_name' AS job_name,
    j.value ->> 'job_type' AS job_type,
    COALESCE(
        j.value ->> 'state',
        j.value ->> 'status',
        j.value ->> 'command'
    ) AS state,
    j.value ->> 'repeat_interval' AS repeat_interval,
    j.value ->> 'job_action' AS job_action,
    j.value ->> 'lanname' AS lanname,
    j.value ->> 'lanpltrusted' AS lanpltrusted,
    j.value ->> 'extname' AS extname,
    j.value ->> 'trigger_name' AS trigger_name,
    j.value ->> 'trigger_type' AS trigger_type,
    j.value ->> 'triggering_event' AS triggering_event,
    j.value ->> 'recency' AS recency,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-CFG-001-RC11'
