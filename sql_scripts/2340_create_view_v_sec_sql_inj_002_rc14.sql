DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_002_rc14;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_002_rc14
-- Root cause: SEC-SQL-INJ-002-RC14
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc14 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'schema_name',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'permission_set_desc' AS permission_set_desc,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'is_user_defined' AS is_user_defined,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'definition' AS definition,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC14'
