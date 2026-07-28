DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_006_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_pri_006_rc03
-- Root cause: SEC-SQL-PRI-006-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_006_rc03 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    to_timestamp((j.value ->> 'password_last_changed')::bigint / 3.0) AS password_last_changed,
    to_timestamp((j.value ->> 'last_login')::bigint / 3.0) AS last_login,
    j.value ->> 'rolname' AS rolname,
    to_timestamp((j.value ->> 'last_seen')::bigint / 3.0) AS last_seen,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-006-RC03'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
