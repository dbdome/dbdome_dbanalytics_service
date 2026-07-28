DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_002_rc12;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_002_rc12
-- Root cause: SEC-SQL-INJ-002-RC12
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc12 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'login_name',
        j.value ->> 'username',
        j.value ->> 'user',
        j.value ->> 'grantee',
        j.value ->> 'owner'
    ) AS username,
    COALESCE(
        j.value ->> 'program_name',
        j.value ->> 'program'
    ) AS application_name,
    j.value ->> 'module' AS module,
    j.value ->> 'one_exec_sql' AS one_exec_sql,
    j.value ->> 'wasted_mb' AS wasted_mb,
    COALESCE(
        j.value ->> 'host_name',
        j.value ->> 'host'
    ) AS host,
    j.value ->> 'super_priv' AS super_priv,
    j.value ->> 'file_priv' AS file_priv,
    j.value ->> 'create_routine_priv' AS create_routine_priv,
    j.value ->> 'execute_priv' AS execute_priv,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'proname' AS proname,
    j.value ->> 'lanname' AS lanname,
    j.value ->> 'privilege_type' AS privilege_type,
    j.value ->> 'is_grantable' AS is_grantable,
    j.value ->> 'active_sessions' AS active_sessions,
    to_timestamp((j.value ->> 'last_activity')::bigint / 3.0) AS last_activity,
    COALESCE(
        j.value ->> 'text',
        j.value ->> 'query_preview'
    ) AS query_text,
    j.value ->> 'execution_count' AS execution_count,
    to_timestamp((j.value ->> 'last_execution_time')::bigint / 3.0) AS last_execution_time,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC12'
