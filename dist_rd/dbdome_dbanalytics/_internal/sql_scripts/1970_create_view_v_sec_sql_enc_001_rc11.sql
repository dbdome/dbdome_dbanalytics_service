DROP VIEW IF EXISTS monitoring.v_sec_sql_enc_001_rc11;

-- ============================================================
-- View: monitoring.v_sec_sql_enc_001_rc11
-- Root cause: SEC-SQL-ENC-001-RC11
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc11 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'application_name',
        j.value ->> 'program_name',
        j.value ->> 'program'
    ) AS application_name,
    COALESCE(
        j.value ->> 'client_addr',
        j.value ->> 'host_name',
        j.value ->> 'machine'
    ) AS host,
    j.value ->> 'login_name' AS username,
    j.value ->> 'encrypt_option' AS encrypt_option,
    j.value ->> 'auth_scheme' AS auth_scheme,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'encrypted_count' AS encrypted_count,
    j.value ->> 'unencrypted_count' AS unencrypted_count,
    j.value ->> 'variable_name' AS variable_name,
    j.value ->> 'variable_value' AS variable_value,
    j.value ->> 'connection_type' AS connection_type,
    j.value ->> 'conn_count' AS conn_count,
    j.value ->> 'session_count' AS session_count,
    j.value ->> 'encryption_info' AS encryption_info,
    j.value ->> 'ssl' AS ssl,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ENC-001-RC11'
