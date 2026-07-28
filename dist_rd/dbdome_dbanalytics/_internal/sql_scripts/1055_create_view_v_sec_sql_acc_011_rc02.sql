-- ============================================================
-- View: monitoring.v_sec_sql_acc_011_rc02
-- Root cause: SEC-SQL-ACC-011-RC02
--   "Who is active" snapshot (single-SELECT WhoIsActive detection): running
--   requests, sleeping sessions holding an open transaction, sessions whose
--   last request finished in the last 60s, plus a plan-cache branch for
--   statements that ran in the last 60s after their session disconnected.
-- Projects that detection's per-row JSON output into the SAME flat columns this
-- view exposed before, so the dependent monitoring.v_all_active_transactions
-- (2700) keeps working unchanged. Column names AND types are identical to the
-- previous version, so this is a plain CREATE OR REPLACE (no CASCADE / no 2700
-- rebuild needed).
--
-- Key mapping (WhoIsActive output key -> view column):
--   session_id    -> session_id          login_name -> login_name
--   host_name     -> host_name           program_name -> program_name
--   database_name -> database_name       sql_text   -> query_text
--   tran_begin_time (epoch ms) -> transaction_begin_time
--   elapsed_ms (ms) -> duration_seconds (converted to seconds)
--   activity (running / sleeping (open tran) / recently completed /
--             completed (plan cache)) -> transaction_state
-- WhoIsActive exposes no transaction id, so transaction_id is NULL.
-- server / entry_date come from the collector result row (r.*).
-- pandas to_json serialises datetimes as epoch MILLISECONDS, hence the
-- to_timestamp(... / 1000) conversions. Idempotent.
-- ============================================================

CREATE OR REPLACE VIEW monitoring.v_sec_sql_acc_011_rc02 AS
SELECT
    r.server,
    j.value ->> 'session_id'             AS session_id,
    j.value ->> 'login_name'             AS login_name,
    j.value ->> 'host_name'              AS host_name,
    j.value ->> 'program_name'           AS program_name,
    j.value ->> 'database_name'          AS database_name,
    NULL::text                           AS transaction_id,
    (to_timestamp(NULLIF(j.value ->> 'tran_begin_time','')::bigint / 1000.0)
        AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Jerusalem'  AS transaction_begin_time,
    (NULLIF(j.value ->> 'elapsed_ms','')::numeric / 1000.0)::text  AS duration_seconds,
    j.value ->> 'activity'               AS transaction_state,
    j.value ->> 'sql_text'               AS query_text,
    r.entry_date,
    -- after_hours: access observed outside Sun-Thu 08:00-18:00 (Asia/Jerusalem).
    -- EXTRACT(DOW): Sun=0..Sat=6, so weekend = 5 (Fri), 6 (Sat).
    (
        EXTRACT(DOW  FROM (r.entry_date::timestamptz AT TIME ZONE 'Asia/Jerusalem')) IN (5, 6)
        OR EXTRACT(HOUR FROM (r.entry_date::timestamptz AT TIME ZONE 'Asia/Jerusalem')) < 8
        OR EXTRACT(HOUR FROM (r.entry_date::timestamptz AT TIME ZONE 'Asia/Jerusalem')) >= 18
    )                                                          AS after_hours,
    -- in_transaction: the session is holding an open transaction.
    -- ::numeric (not ::int) because pandas serialises int columns with NULLs as
    -- floats, so the JSON value can be "1.0" (which "1.0"::int rejects).
    (COALESCE(NULLIF(j.value ->> 'open_tran_count','')::numeric, 0) > 0)  AS in_transaction
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-ACC-011-RC02';
