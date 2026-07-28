DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_002_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_002_rc02
-- Root cause: SEC-SQL-INJ-002-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc02 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'owner',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'object_name' AS object_name,
    j.value ->> 'object_type' AS object_type,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    to_timestamp((j.value ->> 'last_ddl_time')::bigint / 3.0) AS last_ddl_time,
    j.value ->> 'age_days' AS age_days,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'proname' AS proname,
    j.value ->> 'lanname' AS lanname,
    j.value ->> 'prosecdef' AS prosecdef,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'is_enabled' AS is_enabled,
    j.value ->> 'compatibility_level' AS compatibility_level,
    j.value ->> 'compat_version' AS compat_version,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC02'
