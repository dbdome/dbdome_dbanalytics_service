DROP VIEW IF EXISTS monitoring.v_sec_sql_au_006_rc15;

-- ============================================================
-- View: monitoring.v_sec_sql_au_006_rc15
-- Root cause: SEC-SQL-AU-006-RC15
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_006_rc15 AS
SELECT
    r.server,
    j.value ->> 'total_users' AS total_users,
    j.value ->> 'value' AS value_val,
    j.value ->> 'name' AS username,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'role_membership' AS role_membership,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'owned_objects' AS owned_objects,
    j.value ->> 'total_active_logins' AS total_active_logins,
    j.value ->> 'logins_no_current_session' AS logins_no_current_session,
    j.value ->> 'logins_stale_password' AS logins_stale_password,
    j.value ->> 'logins_older_than_1yr' AS logins_older_than_1yr,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-006-RC15'
