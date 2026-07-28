DROP VIEW IF EXISTS monitoring.v_sec_sql_au_006_rc12;

-- ============================================================
-- View: monitoring.v_sec_sql_au_006_rc12
-- Root cause: SEC-SQL-AU-006-RC12
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_006_rc12 AS
SELECT
    r.server,
    j.value ->> 'extname' AS extname,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    COALESCE(
        j.value ->> 'username',
        j.value ->> 'name'
    ) AS username,
    to_timestamp((j.value ->> 'last_login')::bigint / 3.0) AS last_login,
    j.value ->> 'account_status' AS account_status,
    j.value ->> 'days_inactive' AS days_inactive,
    j.value ->> 'dormant_count' AS dormant_count,
    j.value ->> 'profile' AS profile,
    j.value ->> 'resource_name' AS resource_name,
    j.value ->> 'limit' AS limit,
    j.value ->> 'setting' AS setting,
    j.value ->> 'enabled' AS enabled,
    to_timestamp((j.value ->> 'date_created')::bigint / 3.0) AS date_created,
    j.value ->> 'step_name' AS step_name,
    j.value ->> 'command' AS state,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AU-006-RC12'
