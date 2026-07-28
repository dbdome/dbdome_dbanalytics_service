DROP VIEW IF EXISTS monitoring.v_sec_sql_az_006_rc12;

-- ============================================================
-- View: monitoring.v_sec_sql_az_006_rc12
-- Root cause: SEC-SQL-AZ-006-RC12
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_006_rc12 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'grantee',
        j.value ->> 'owner'
    ) AS username,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'privilege' AS privilege,
    j.value ->> 'any_priv_count' AS any_priv_count,
    j.value ->> 'any_privileges' AS any_privileges,
    j.value ->> 'total_grantable' AS total_grantable,
    j.value ->> 'distinct_delegators' AS distinct_delegators,
    j.value ->> 'windows_auth_only' AS windows_auth_only,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AZ-006-RC12'
