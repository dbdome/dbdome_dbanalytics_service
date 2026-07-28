DROP VIEW IF EXISTS monitoring.v_sec_sql_inj_002_rc09;

-- ============================================================
-- View: monitoring.v_sec_sql_inj_002_rc09
-- Root cause: SEC-SQL-INJ-002-RC09
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc09 AS
SELECT
    r.server,
    j.value ->> 'sql_firewall' AS sql_firewall,
    j.value ->> 'value' AS value_val,
    j.value ->> 'client_net_address' AS client_net_address,
    COALESCE(
        j.value ->> 'login_name',
        j.value ->> 'name'
    ) AS username,
    j.value ->> 'program_name' AS application_name,
    j.value ->> 'auth_scheme' AS auth_scheme,
    j.value ->> 'is_enabled' AS is_enabled,
    j.value ->> 'setting' AS setting,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC09'
