DROP VIEW IF EXISTS monitoring.v_sec_sql_cfg_001_rc03;

-- ============================================================
-- View: monitoring.v_sec_sql_cfg_001_rc03
-- Root cause: SEC-SQL-CFG-001-RC03
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc03 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'grantee',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'enabled' AS enabled,
    j.value ->> 'privilege' AS privilege,
    j.value ->> 'rolname' AS rolname,
    j.value ->> 'rolsuper' AS rolsuper,
    j.value ->> 'value' AS value,
    j.value ->> 'isdefault' AS isdefault,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-CFG-001-RC03'
