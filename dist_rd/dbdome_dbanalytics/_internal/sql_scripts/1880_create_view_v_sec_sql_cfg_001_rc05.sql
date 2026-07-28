DROP VIEW IF EXISTS monitoring.v_sec_sql_cfg_001_rc05;

-- ============================================================
-- View: monitoring.v_sec_sql_cfg_001_rc05
-- Root cause: SEC-SQL-CFG-001-RC05
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc05 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'grantee',
        j.value ->> 'owner',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'auth_type' AS auth_type,
    j.value ->> 'days_until_expiration' AS days_until_expiration,
    j.value ->> 'xp_cmdshell_enabled' AS xp_cmdshell_enabled,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'admin_status' AS admin_status,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'privilege' AS privilege,
    j.value ->> 'type' AS state,
    j.value ->> 'line' AS line,
    j.value ->> 'text' AS query_text,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-CFG-001-RC05'
