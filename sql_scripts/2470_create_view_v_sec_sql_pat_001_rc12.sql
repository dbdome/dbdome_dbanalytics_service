DROP VIEW IF EXISTS monitoring.v_sec_sql_pat_001_rc12;

-- ============================================================
-- View: monitoring.v_sec_sql_pat_001_rc12
-- Root cause: SEC-SQL-PAT-001-RC12
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pat_001_rc12 AS
SELECT
    r.server,
    to_timestamp((j.value ->> 'last_patch_date')::bigint / 3.0) AS last_patch_date,
    j.value ->> 'days_since_patch' AS days_since_patch,
    j.value ->> 'banner_full' AS banner_full,
    to_timestamp((j.value ->> 'sqlserver_start_time')::bigint / 3.0) AS sqlserver_start_time,
    j.value ->> 'days_since_restart' AS days_since_restart,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PAT-001-RC12'
