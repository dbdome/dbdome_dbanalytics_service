DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_008_rc02;

-- ============================================================
-- View: monitoring.v_sec_sql_pri_008_rc02
-- Root cause: SEC-SQL-PRI-008-RC02
-- Generated automatically – do not edit by hand
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_008_rc02 AS
SELECT
    r.server,
    j.value ->> 'variable_name' AS variable_name,
    j.value ->> 'variable_value' AS variable_value,
    j.value ->> 'bs_key' AS bs_key,
    to_timestamp((j.value ->> 'completion_time')::bigint / 3.0) AS completion_time,
    j.value ->> 'encrypted' AS encrypted,
    j.value ->> 'database_name' AS db,
    j.value ->> 'database_name' AS database_name,
    to_timestamp((j.value ->> 'backup_finish_date')::bigint / 3.0) AS backup_finish_date,
    j.value ->> 'encryptor_type' AS encryptor_type,
    j.value ->> 'has_backup_checksums' AS has_backup_checksums,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-008-RC02'
