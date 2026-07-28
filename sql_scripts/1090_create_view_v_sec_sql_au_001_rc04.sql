DROP VIEW IF EXISTS monitoring.v_sec_sql_au_001_rc04;

-- ============================================================
-- View: monitoring.v_sec_sql_au_001_rc04
-- Root cause: SEC-SQL-AU-001-RC04
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc04 AS
SELECT
    r.server,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'rolcreaterole' AS rolcreaterole,
    j.value ->> 'rolcreatedb' AS rolcreatedb,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'default_passwords' AS default_passwords,
    j.value ->> 'issue_count' AS issue_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-001-RC04'
