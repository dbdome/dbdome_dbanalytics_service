DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_002_rc16;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_002_rc16
-- Root cause: SEC-SQL-INJ-002-RC16
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc16 AS
SELECT
    r.server,
    j.value ->> 'routine_schema' AS routine_schema,
    j.value ->> 'routine_name' AS routine_name,
    j.value ->> 'routine_type' AS routine_type,
    j.value ->> 'no_sql_firewall' AS no_sql_firewall,
    j.value ->> 'tgname' AS tgname,
    j.value ->> 'relname' AS relname,
    j.value ->> 'proname' AS proname,
    j.value ->> 'lanname' AS lanname,
    COALESCE(
        j.value ->> 'schema_name',
        j.value ->> 'name'
    ) AS username,
    to_timestamp((j.value ->> 'create_date')::bigint / 3.0) AS create_date,
    j.value ->> 'event_schema' AS event_schema,
    j.value ->> 'event_name' AS event_name,
    j.value ->> 'event' AS event,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC16'
