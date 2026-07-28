DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_004_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_pri_004_rc03
-- Root cause: SEC-SQL-PRI-004-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_004_rc03 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'pid',
        j.value ->> 'session_id'
    ) AS session_id,
    j.value ->> 'encrypt_option' AS encrypt_option,
    COALESCE(
        j.value ->> 'usename',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'value' AS value,
    j.value ->> 'host' AS host,
    j.value ->> 'ssl_type' AS ssl_type,
    j.value ->> 'ssl' AS ssl,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-004-RC03'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
