DROP VIEW IF EXISTS monitoring.v_sec_sql_au_005_rc01;

-- ============================================================
-- View: monitoring.v_sec_sql_au_005_rc01
-- Root cause: SEC-SQL-AU-005-RC01
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc01 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'login_name',
        j.value ->> 'username'
    ) AS username,
    j.value ->> 'authentication_type' AS authentication_type,
    j.value ->> 'account_status' AS account_status,
    j.value ->> 'profile' AS profile,
    to_timestamp((j.value ->> 'created')::bigint / 3.0) AS created,
    to_timestamp((j.value ->> 'last_login')::bigint / 3.0) AS last_login,
    j.value ->> 'common' AS common,
    j.value ->> 'program_name' AS application_name,
    j.value ->> 'host_name' AS host,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'session_count' AS session_count,
    j.value ->> 'windows_auth_only' AS windows_auth_only,
    j.value ->> 'auth_mode' AS auth_mode,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-005-RC01'
  AND j.value ->> 'host_name' IS DISTINCT FROM 'dbdome';
