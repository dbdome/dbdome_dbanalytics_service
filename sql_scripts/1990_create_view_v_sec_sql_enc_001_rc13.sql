DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_001_rc13;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_001_rc13
-- Root cause: SEC-SQL-ENC-001-RC13
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc13 AS
SELECT
    r.server,
    j.value ->> 'name' AS username,
    j.value ->> 'is_state_enabled' AS is_state_enabled,
    j.value ->> 'audit_action_name' AS audit_action_name,
    j.value ->> 'class_desc' AS class_desc,
    j.value ->> 'unencrypted_connections' AS unencrypted_connections,
    j.value ->> 'setting' AS setting,
    j.value ->> 'require_secure_transport' AS require_secure_transport,
    j.value ->> 'total' AS total,
    j.value ->> 'encrypted' AS encrypted,
    j.value ->> 'plaintext' AS plaintext,
    j.value ->> 'policy_name' AS policy_name,
    j.value ->> 'audit_condition' AS audit_condition,
    j.value ->> 'trigger_name' AS trigger_name,
    j.value ->> 'trigger_type' AS trigger_type,
    j.value ->> 'triggering_event' AS triggering_event,
    j.value ->> 'plugin_name' AS plugin_name,
    j.value ->> 'plugin_status' AS plugin_status,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-001-RC13'
