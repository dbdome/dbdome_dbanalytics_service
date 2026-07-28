DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_002_rc06;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_002_rc06
-- Root cause: SEC-SQL-INJ-002-RC06
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc06 AS
SELECT
    r.server,
    j.value ->> 'event_schema' AS event_schema,
    j.value ->> 'event_name' AS event_name,
    j.value ->> 'event_definition' AS event_definition,
    j.value ->> 'routine_schema' AS routine_schema,
    j.value ->> 'routine_name' AS routine_name,
    COALESCE(
        j.value ->> 'owner',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'job_name' AS job_name,
    j.value ->> 'job_type' AS job_type,
    j.value ->> 'job_action' AS job_action,
    j.value ->> 'enabled' AS enabled,
    COALESCE(
        j.value ->> 'state',
        j.value ->> 'command'
    ) AS state,
    to_timestamp((j.value ->> 'last_start_date')::bigint / 3.0) AS last_start_date,
    to_timestamp((j.value ->> 'next_run_date')::bigint / 3.0) AS next_run_date,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'proname' AS proname,
    j.value ->> 'lanname' AS lanname,
    j.value ->> 'step_name' AS step_name,
    j.value ->> 'subsystem' AS subsystem,
    j.value ->> 'xproc_used' AS xproc_used,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC06'
