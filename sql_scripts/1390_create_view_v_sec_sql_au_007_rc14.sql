DROP VIEW IF EXISTS monitoring.v_sec_sql_au_007_rc14;

-- ============================================================
-- View: monitoring.v_sec_sql_au_007_rc14
-- Root cause: SEC-SQL-AU-007-RC14
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_007_rc14 AS
SELECT
    r.server,
    j.value ->> 'empty_passwords' AS empty_passwords,
    j.value ->> 'anonymous_users' AS anonymous_users,
    j.value ->> 'remote_root' AS remote_root,
    j.value ->> 'socket_auth' AS socket_auth,
    j.value ->> 'name' AS username,
    j.value ->> 'is_state_enabled' AS is_state_enabled,
    j.value ->> 'audit_action_name' AS audit_action_name,
    j.value ->> 'value' AS value,
    j.value ->> 'isdefault' AS isdefault,
    j.value ->> 'ismodified' AS ismodified,
    j.value ->> 'line_number' AS line_number,
    j.value ->> 'type' AS state,
    j.value ->> 'database' AS database,
    j.value ->> 'user_name' AS user_name,
    j.value ->> 'address' AS address,
    j.value ->> 'auth_method' AS auth_method,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-007-RC14'
