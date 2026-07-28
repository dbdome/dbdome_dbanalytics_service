-- =============================================================================
-- View: monitoring.v_sec_sql_acc_010_rc11
-- Root cause: SEC-SQL-ACC-010-RC11 — Schema reconnaissance activity
-- Detects: Active queries probing INFORMATION_SCHEMA or sys catalog
-- =============================================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_acc_010_rc11 AS
SELECT
    r.server,
    (j.value ->> 'session_id')    AS session_id,
    COALESCE(
        j.value ->> 'login_name', -- sqlserver
        j.value ->> 'usename',    -- postgresql
        j.value ->> 'username',   -- oracle
        j.value ->> 'user'        -- mysql
    ) AS username,
    COALESCE(
        j.value ->> 'host_name',  -- sqlserver
        j.value ->> 'client_addr',-- postgresql
        j.value ->> 'machine',    -- oracle
        j.value ->> 'host'        -- mysql
    ) AS host,
    COALESCE(
        j.value ->> 'program_name',   -- sqlserver
        j.value ->> 'application_name' -- postgresql
    ) AS application_name,
    to_timestamp((j.value ->> 'start_time')::bigint / 1000.0) AS start_time,
    COALESCE(
        j.value ->> 'query_text', -- sqlserver
        j.value ->> 'query'       -- postgresql / mysql
    ) AS query_text,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ACC-010-RC11'
  AND COALESCE(
        j.value ->> 'host_name',
        j.value ->> 'client_addr',
        j.value ->> 'machine',
        j.value ->> 'host'
    ) != 'dbdome';
