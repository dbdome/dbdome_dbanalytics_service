-- =============================================================================
-- View: monitoring.v_sec_sql_acc_010_rc07
-- Root cause: SEC-SQL-ACC-010-RC07 — After-hours transaction activity
-- Vendors: postgresql, sqlserver, oracle, mysql
-- =============================================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_acc_010_rc07 AS
SELECT
    r.server,
    COALESCE(
        j.value ->> 'usename',          -- postgresql
        j.value ->> 'login_name',       -- sqlserver
        j.value ->> 'username',         -- oracle
        j.value ->> 'trx_user'          -- mysql
    ) AS username,
    COALESCE(
        j.value ->> 'client_addr',      -- postgresql
        j.value ->> 'host_name',        -- sqlserver
        j.value ->> 'machine',          -- oracle
        j.value ->> 'trx_host'          -- mysql
    ) AS host,
    COALESCE(
        j.value ->> 'application_name', -- postgresql
        j.value ->> 'program_name',     -- sqlserver
        j.value ->> 'program'           -- oracle
    ) AS application_name,
    to_timestamp(COALESCE(
        j.value ->> 'xact_start',               -- postgresql
        j.value ->> 'transaction_begin_time',   -- sqlserver
        j.value ->> 'start_time',               -- oracle
        j.value ->> 'trx_started'               -- mysql
    )::bigint / 1000.0) AS transaction_start,
    (j.value ->> 'duration_seconds')::int                      AS duration_seconds,
    to_timestamp((j.value ->> 'start_hour')::bigint)           AS start_hour,
    COALESCE(
        j.value ->> 'state',            -- postgresql
        j.value ->> 'trx_state'         -- mysql
    ) AS state,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ACC-010-RC07'
  AND COALESCE(
        j.value ->> 'client_addr',
        j.value ->> 'host_name',
        j.value ->> 'machine',
        j.value ->> 'trx_host'
    ) != 'dbdome';
