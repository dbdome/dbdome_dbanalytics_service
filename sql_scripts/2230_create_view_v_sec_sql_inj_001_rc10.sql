DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_001_rc10;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_001_rc10
-- Root cause: SEC-SQL-INJ-001-RC10
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_001_rc10 AS
SELECT
    r.server,
    j.value ->> 'query_hash' AS query_hash,
    j.value ->> 'plan_count' AS plan_count,
    j.value ->> 'sample_query' AS sample_query,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'proname' AS proname,
    j.value ->> 'adhoc_plans' AS adhoc_plans,
    j.value ->> 'prepared_plans' AS prepared_plans,
    j.value ->> 'proc_plans' AS proc_plans,
    j.value ->> 'total_plans' AS total_plans,
    j.value ->> 'adhoc_pct' AS adhoc_pct,
    j.value ->> 'total_cursors' AS total_cursors,
    j.value ->> 'distinct_patterns' AS distinct_patterns,
    j.value ->> 'avg_versions' AS avg_versions,
    j.value ->> 'name' AS username,
    j.value ->> 'value' AS value,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-001-RC10'
