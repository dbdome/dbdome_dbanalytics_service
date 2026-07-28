-- ============================================================
-- View: monitoring.v_sec_sql_pri_001_rc15
-- Root cause: SEC-SQL-PRI-001-RC15
--   Sensitive columns touched by cached plans / active transactions.
-- Projects the detection's per-row JSON output (one element per
-- sensitive-column hit) into flat columns, including login_name.
-- Idempotent (CREATE OR REPLACE); re-applied by sql_script_runner
-- when this file's checksum changes.
-- ============================================================

-- NOTE: no DROP -- monitoring.v_all_active_transactions (2700) depends on this
-- view. We only append columns, so a plain CREATE OR REPLACE is sufficient and
-- does not require dropping the dependent.
CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc15 AS
SELECT
    r.server,
    j.value ->> 'source'                       AS source,
    j.value ->> 'session_id'                    AS session_id,
    j.value ->> 'transaction_id'                AS transaction_id,
    j.value ->> 'login_name'                    AS login_name,
    COALESCE(j.value ->> 'schema_name',
             j.value ->> 'table_schema')        AS schema_name,
    j.value ->> 'table_name'                    AS table_name,
    j.value ->> 'column_name'                   AS column_name,
    j.value ->> 'pii_category'                  AS pii_category,
    j.value ->> 'execution_count'               AS execution_count,
    j.value ->> 'last_execution_time'           AS last_execution_time,
    j.value ->> 'avg_reads'                     AS avg_reads,
    j.value ->> 'avg_cpu_ms'                    AS avg_cpu_ms,
    j.value ->> 'transaction_begin_time'        AS transaction_begin_time,
    j.value ->> 'query_text'                    AS query_text,
    r.entry_date,
    -- after_hours: access observed outside Sun-Thu 08:00-18:00 (Asia/Jerusalem).
    -- EXTRACT(DOW): Sun=0..Sat=6, so weekend = 5 (Fri), 6 (Sat).
    (
        EXTRACT(DOW  FROM (r.entry_date::timestamptz AT TIME ZONE 'Asia/Jerusalem')) IN (5, 6)
        OR EXTRACT(HOUR FROM (r.entry_date::timestamptz AT TIME ZONE 'Asia/Jerusalem')) < 8
        OR EXTRACT(HOUR FROM (r.entry_date::timestamptz AT TIME ZONE 'Asia/Jerusalem')) >= 18
    )                                           AS after_hours,
    -- in_transaction: the sensitive access happened inside an open transaction
    -- (active_transaction branch, or a transaction id was attributed).
    (
        j.value ->> 'source' = 'active_transaction'
        OR NULLIF(j.value ->> 'transaction_id','') IS NOT NULL
    )                                           AS in_transaction
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-001-RC15';
