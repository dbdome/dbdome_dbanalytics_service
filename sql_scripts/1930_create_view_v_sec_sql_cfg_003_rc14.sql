DROP VIEW IF EXISTS monitoring.v_sec_sql_cfg_003_rc14;

-- ============================================================
-- View: monitoring.v_sec_sql_cfg_003_rc14
-- Root cause: SEC-SQL-CFG-003-RC14
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_003_rc14 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'user_access_desc' AS user_access_desc,
    j.value ->> 'is_db_chaining_on' AS is_db_chaining_on,
    j.value ->> 'is_trustworthy_on' AS is_trustworthy_on,
    j.value ->> 'common' AS common,
    j.value ->> 'account_status' AS account_status,
    j.value ->> 'authentication_type' AS authentication_type,
    j.value ->> 'user_db_count' AS user_db_count,
    j.value ->> 'datname' AS datname,
    j.value ->> 'numbackends' AS numbackends,
    j.value ->> 'stats_reset' AS stats_reset,
    j.value ->> 'datdba' AS datdba,
    j.value ->> 'table_schema' AS table_schema,
    to_timestamp((j.value ->> 'last_update')::bigint / 3.0) AS last_update,
    j.value ->> 'value' AS value_val,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-CFG-003-RC14'
