DROP VIEW IF EXISTS monitoring.v_sec_sql_aud_015_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_aud_015_rc01
-- Root cause: SEC-SQL-AUD-015-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_015_rc01 AS
SELECT
    r.server,
    to_timestamp((j.value ->> 'event_time')::bigint / 3.0) AS event_time,
    COALESCE(
        j.value ->> 'login_name',
        j.value ->> 'schema_name'
    ) AS username,
    j.value ->> 'database_name' AS db,
    j.value ->> 'null' AS null_val,
    j.value ->> 'action_id' AS action_id,
    j.value ->> 'action' AS action_val,
    j.value ->> 'change_kind' AS change_kind,
    COALESCE(
        j.value ->> 'sql_text',
        j.value ->> 'statement'
    ) AS query_text,
    j.value ->> 'setup_ok' AS setup_ok,
    j.value ->> 'enabled_server_audits' AS enabled_server_audits,
    j.value ->> 'enabled_server_specs' AS enabled_server_specs,
    j.value ->> 'dbdome_dml_pol' AS dbdome_dml_pol,
    j.value ->> 'dbdome_ddl_pol' AS dbdome_ddl_pol,
    j.value ->> 'unified_audit_trail' AS unified_audit_trail,
    j.value ->> 'error_message' AS error_message,
    j.value ->> 'col_1' AS col_1,
    j.value ->> 'dbusername' AS dbusername,
    j.value ->> 'object_schema' AS object_schema,
    j.value ->> 'object_name' AS object_name,
    j.value ->> 'action_name' AS action_name,
    j.value ->> 'client_program_name' AS client_program_name,
    j.value ->> 'event_time_at_time_zone__utc__at_time_zone__asia_jerusalem' AS event_time_at_time_zone__utc__at_time_zone__asia_jerusalem,
    j.value ->> 'client_ip' AS client_ip,
    j.value ->> 'application_name' AS application_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUD-015-RC01'
