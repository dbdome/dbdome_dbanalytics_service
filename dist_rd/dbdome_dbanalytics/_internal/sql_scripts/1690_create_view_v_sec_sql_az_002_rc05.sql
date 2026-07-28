DROP VIEW IF EXISTS monitoring.v_sec_sql_az_002_rc05;

-- ============================================================
-- View: monitoring.v_sec_sql_az_002_rc05
-- Root cause: SEC-SQL-AZ-002-RC05
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_002_rc05 AS
SELECT
    r.server,
    j.value ->> 'event_timestamp' AS event_timestamp,
    j.value ->> 'dbusername' AS dbusername,
    j.value ->> 'action_name' AS action_name,
    j.value ->> 'object_schema' AS object_schema,
    j.value ->> 'object_name' AS object_name,
    j.value ->> 'sql_text' AS query_text,
    j.value ->> 'policy_name' AS policy_name,
    j.value ->> 'audit_option' AS audit_option,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'is_state_enabled' AS is_state_enabled,
    j.value ->> 'audit_action_name' AS audit_action_name,
    j.value ->> 'broad_grant_users' AS broad_grant_users,
    j.value ->> 'permission_name' AS permission_name,
    j.value ->> 'class_desc' AS class_desc,
    j.value ->> 'grant_count' AS grant_count,
    j.value ->> 'host' AS host,
    to_timestamp((j.value ->> 'password_last_changed')::bigint / 3.0) AS password_last_changed,
    j.value ->> 'schema_val' AS schema_val,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'nspacl' AS nspacl,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-002-RC05'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
