-- ============================================================
-- View: monitoring.v_perf_sql_tx_010_rc01   (compatible superset)
-- Root cause: PERF-SQL-TX-010-RC01 (sqlserver)
--   "Active transactions snapshot" that EXCLUDES the monitoring session
--   ( s.session_id <> @@SPID ) and the dbdome service account
--   ( login_name NOT LIKE '%dbdome%' ).
--
-- BACKGROUND: RC01's detection query was upgraded (6200) from the basic
-- active-transactions SELECT to the SEC-SQL-ACC-011-RC02 WhoIsActive-style
-- query. The two emit DIFFERENT json keys:
--   old keys: cpu_time, elapsed_sec, query_text, row_count, ...
--   new keys: cpu_ms, elapsed_ms, sql_text, activity, tran_begin_time,
--             open_tran_count, blocking_session_id, logical_reads,
--             percent_complete, request_start_time, last_request_end_time, ...
-- Existing collected data still uses the OLD keys; future collections use the
-- NEW keys. This view is a SUPERSET that works with BOTH:
--   * The original 17 columns are preserved verbatim (same names, order, text
--     type) so existing consumers / Grafana panels keep working. Where a column
--     has an old- and a new-key spelling, COALESCE(old, new) is used so it
--     populates regardless of which detection version produced the row:
--        cpu_time    = COALESCE(cpu_time, cpu_ms)
--        elapsed_sec = COALESCE(elapsed_sec, elapsed_ms / 1000)
--        query_text  = COALESCE(query_text, sql_text)
--        row_count   = old-only (NULL for new rows)
--   * New diagnostic columns are appended (NULL for old rows).
--
-- pandas to_json serialises datetimes as epoch MILLISECONDS, hence the
-- to_timestamp(... / 1000) conversions on the new timestamp keys.
-- jsonb_lower_keys() guards against vendor case variance (idempotent on the
-- already-lowercase keys). No dependents, so DROP + CREATE is safe.
-- ============================================================

DROP VIEW IF EXISTS monitoring.v_perf_sql_tx_010_rc01;

CREATE VIEW monitoring.v_perf_sql_tx_010_rc01 AS
SELECT
    -- ---- original 17 columns (preserved for backward compatibility) ----
    r.server,
    j.value ->> 'command'                                   AS command,
    COALESCE(j.value ->> 'cpu_time', j.value ->> 'cpu_ms')  AS cpu_time,
    j.value ->> 'database_name'                             AS database_name,
    COALESCE(j.value ->> 'elapsed_sec',
             (NULLIF(j.value ->> 'elapsed_ms','')::numeric / 1000.0)::text) AS elapsed_sec,
    j.value ->> 'host_name'                                 AS host_name,
    j.value ->> 'login_name'                                AS login_name,
    j.value ->> 'program_name'                              AS program_name,
    COALESCE(j.value ->> 'query_text', j.value ->> 'sql_text')  AS query_text,
    j.value ->> 'reads'                                     AS reads,
    j.value ->> 'row_count'                                 AS row_count,
    j.value ->> 'session_id'                                AS session_id,
    j.value ->> 'status'                                   AS status,
    j.value ->> 'wait_time'                                AS wait_time,
    j.value ->> 'wait_type'                                AS wait_type,
    j.value ->> 'writes'                                   AS writes,
    (r.entry_date AT TIME ZONE 'Asia/Jerusalem')           AS entry_date,
    -- ---- new diagnostic columns (NULL for old-format rows) ----
    j.value ->> 'activity'                                 AS transaction_state,
    NULLIF(j.value ->> 'blocking_session_id','')::numeric  AS blocking_session_id,
    NULLIF(j.value ->> 'cpu_ms','')::numeric               AS cpu_ms,
    NULLIF(j.value ->> 'elapsed_ms','')::numeric           AS elapsed_ms,
    NULLIF(j.value ->> 'logical_reads','')::numeric        AS logical_reads,
    NULLIF(j.value ->> 'percent_complete','')::numeric     AS percent_complete,
    NULLIF(j.value ->> 'open_tran_count','')::numeric      AS open_tran_count,
    (to_timestamp(NULLIF(j.value ->> 'tran_begin_time','')::bigint / 1000.0)
        AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Jerusalem'  AS transaction_begin_time,
    (to_timestamp(NULLIF(j.value ->> 'request_start_time','')::bigint / 1000.0)
        AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Jerusalem'  AS request_start_time,
    (to_timestamp(NULLIF(j.value ->> 'last_request_end_time','')::bigint / 1000.0)
        AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Jerusalem'  AS last_request_end_time,
    -- in_transaction: the session is holding an open transaction (new rows only).
    (COALESCE(NULLIF(j.value ->> 'open_tran_count','')::numeric, 0) > 0)  AS in_transaction,
    -- after_hours: observed outside Sun-Thu 08:00-18:00 (Asia/Jerusalem).
    -- EXTRACT(DOW): Sun=0..Sat=6, so weekend = 5 (Fri), 6 (Sat).
    (
        EXTRACT(DOW  FROM (r.entry_date::timestamptz AT TIME ZONE 'Asia/Jerusalem')) IN (5, 6)
        OR EXTRACT(HOUR FROM (r.entry_date::timestamptz AT TIME ZONE 'Asia/Jerusalem')) < 8
        OR EXTRACT(HOUR FROM (r.entry_date::timestamptz AT TIME ZONE 'Asia/Jerusalem')) >= 18
    )                                                          AS after_hours
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'PERF-SQL-TX-010-RC01';
