DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_005_rc14;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_005_rc14
-- Root cause: SEC-SQL-ENC-005-RC14
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_005_rc14 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'setting' AS setting,
    j.value ->> 'event_name' AS event_name,
    j.value ->> 'cipher_count' AS cipher_count,
    j.value ->> 'ssl_connections' AS ssl_connections,
    j.value ->> 'encrypted_connections' AS encrypted_connections,
    j.value ->> 'extname' AS extname,
    j.value ->> 'is_state_enabled' AS is_state_enabled,
    j.value ->> 'audit_action_name' AS audit_action_name,
    j.value ->> 'class_desc' AS class_desc,
    j.value ->> 'policy_name' AS policy_name,
    j.value ->> 'audit_option' AS audit_option,
    j.value ->> 'network_service_banner' AS network_service_banner,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-005-RC14'
