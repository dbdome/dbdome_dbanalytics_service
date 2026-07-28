-- ============================================================
-- View: monitoring.v_sec_sql_pri_001_rc14
-- Root cause: SEC-SQL-PRI-001-RC14
--   Active transactions/sessions touching sensitive columns.
-- Projects the detection's per-row JSON output (one element per
-- sensitive-column hit) into flat columns, including login_name.
-- COALESCE absorbs cross-vendor key variants:
--   status  <- status (mssql/oracle) | state (postgres)
--   started <- start_time (mssql) | query_start (postgres)
-- Idempotent (CREATE OR REPLACE); re-applied by sql_script_runner
-- when this file's checksum changes.
-- ============================================================

DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_001_rc14;

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc14 AS
SELECT
    r.server,
    j.value ->> 'session_id'                    AS session_id,
    j.value ->> 'login_name'                    AS login_name,
    j.value ->> 'host_name'                     AS host_name,
    j.value ->> 'program_name'                  AS program_name,
    j.value ->> 'database_name'                 AS database_name,
    j.value ->> 'schema_name'                   AS schema_name,
    j.value ->> 'table_name'                    AS table_name,
    j.value ->> 'column_name'                   AS column_name,
    j.value ->> 'pii_category'                  AS pii_category,
    COALESCE(j.value ->> 'status',
             j.value ->> 'state')               AS status,
    COALESCE(j.value ->> 'start_time',
             j.value ->> 'query_start')         AS started_at,
    j.value ->> 'duration_secs'                 AS duration_secs,
    j.value ->> 'query_text'                    AS query_text,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-001-RC14';
