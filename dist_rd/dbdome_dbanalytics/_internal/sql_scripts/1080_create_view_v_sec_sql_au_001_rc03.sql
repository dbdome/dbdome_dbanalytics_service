DROP VIEW IF EXISTS monitoring.v_sec_sql_au_001_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_au_001_rc03
-- Root cause: SEC-SQL-AU-001-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc03 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'login_name',
        j.value ->> 'user',
        j.value ->> 'name'
    ) AS username,
    COALESCE(
        j.value ->> 'host_name',
        j.value ->> 'host'
    ) AS host,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'rolcanlogin' AS rolcanlogin,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'client_net_address' AS client_net_address,
    COALESCE(
        j.value ->> 'program_name',
        j.value ->> 'program'
    ) AS application_name,
    to_timestamp((j.value ->> 'login_time')::bigint / 3.0) AS login_time,
    j.value ->> 'machine' AS machine,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'value' AS value_val,
    j.value ->> 'protocol_desc' AS protocol_desc,
    j.value ->> 'state_desc' AS state_desc,
    j.value ->> 'port' AS port,
    j.value ->> 'is_dynamic_port' AS is_dynamic_port,
    j.value ->> 'is_admin_endpoint' AS is_admin_endpoint,
    j.value ->> 'setting' AS setting,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-001-RC03'
