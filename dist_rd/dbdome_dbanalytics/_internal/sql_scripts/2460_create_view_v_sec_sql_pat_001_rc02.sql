DROP VIEW IF EXISTS monitoring.v_sec_sql_pat_001_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_pat_001_rc02
-- Root cause: SEC-SQL-PAT-001-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pat_001_rc02 AS
SELECT
    r.server,
    j.value ->> 'dbid' AS dbid,
    j.value ->> 'name' AS username,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    j.value ->> 'log_mode' AS log_mode,
    j.value ->> 'open_mode' AS open_mode,
    j.value ->> 'banner_full' AS banner_full,
    j.value ->> 'con_id' AS con_id,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PAT-001-RC02'
