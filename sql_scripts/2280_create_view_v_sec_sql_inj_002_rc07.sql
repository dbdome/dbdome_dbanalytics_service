DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_002_rc07;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_002_rc07
-- Root cause: SEC-SQL-INJ-002-RC07
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc07 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'user',
        j.value ->> 'grantee',
        j.value ->> 'owner',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'host' AS host,
    j.value ->> 'super_priv' AS super_priv,
    j.value ->> 'credential_id' AS credential_id,
    j.value ->> 'credential_identity' AS credential_identity,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'file_priv' AS file_priv,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'permission_name' AS permission_name,
    j.value ->> 'state_desc' AS state_desc,
    j.value ->> 'xproc_name' AS xproc_name,
    j.value ->> 'privilege' AS privilege,
    j.value ->> 'nspname' AS nspname,
    j.value ->> 'proname' AS proname,
    j.value ->> 'lanname' AS lanname,
    j.value ->> 'proacl' AS proacl,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC07'
  AND j.value ->> 'host' IS DISTINCT FROM 'dbdome';
