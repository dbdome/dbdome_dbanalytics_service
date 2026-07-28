-- ============================================================
-- Fix the +3h skew on monitoring.v_active_transactions.start_time at the source.
--
-- start_time is a JSON epoch-millisecond value the collector derived from the
-- monitored server's LOCAL (UTC+3) clock as if it were UTC, so to_timestamp()
-- produces an instant 3 hours in the future. Wrapping the result with
--   (... AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Jerusalem'
-- re-interprets it to the correct instant (DST-safe via the named zone).
--
-- CREATE OR REPLACE keeps the column name/type/order identical (start_time stays
-- timestamptz), so the dependent view monitoring.v_all_active_transactions and
-- all panels keep working -- they now simply receive the correct time.
-- Panels that previously wrapped start_time themselves (adbcsrw panel 120) must
-- drop that wrapper to avoid double-correcting.
-- ============================================================
-- No DROP: CREATE OR REPLACE updates the view in place, keeping the dependent
-- monitoring.v_all_active_transactions valid. (A DROP fails once v_all exists, and
-- 2630 already created v_active_transactions with this exact shape.)
CREATE OR REPLACE VIEW monitoring.v_active_transactions AS
 SELECT r.server,
    j.value ->> 'session_id'        AS session_id,
    j.value ->> 'login_name'        AS login_name,
    j.value ->> 'host_name'         AS host_name,
    j.value ->> 'database_name'     AS database_name,
    j.value ->> 'status'            AS status,
    (to_timestamp((((j.value ->> 'start_time')::bigint)::numeric / 1000.0)::double precision)
        AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Jerusalem'  AS start_time,
    j.value ->> 'command'           AS command,
    j.value ->> 'cpu_time'          AS cpu_time,
    j.value ->> 'total_elapsed_time' AS total_elapsed_time,
    j.value ->> 'transaction_id'    AS transaction_id,
    j.value ->> 'transaction_name'  AS transaction_name,
    j.value ->> 'query_text'        AS query,
    -- entry_date is stored as NAIVE LOCAL (Asia/Jerusalem) time, but Grafana
    -- reads timestamp-without-tz as UTC -> it displayed 3h ahead. Re-express the
    -- value as UTC-naive so Grafana renders the correct local time. Type stays
    -- `timestamp without time zone`, so CREATE OR REPLACE keeps dependents valid.
    r.entry_date  AS entry_date,
    r.server_id
   FROM monitoring.general_metric_metadata_results r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
  WHERE r.metric_name::text = 'Active transactions'::text;


-- ============================================================
-- Fix the +3h skew on monitoring.v_active_transactions.start_time at the source.
--
-- start_time is a JSON epoch-millisecond value the collector derived from the
-- monitored server's LOCAL (UTC+3) clock as if it were UTC, so to_timestamp()
-- produces an instant 3 hours in the future. Wrapping the result with
--   (... AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Jerusalem'
-- re-interprets it to the correct instant (DST-safe via the named zone).
--
-- CREATE OR REPLACE keeps the column name/type/order identical (start_time stays
-- timestamptz), so the dependent view monitoring.v_all_active_transactions and
-- all panels keep working -- they now simply receive the correct time.
-- Panels that previously wrapped start_time themselves (adbcsrw panel 120) must
-- drop that wrapper to avoid double-correcting.
-- ============================================================
CREATE OR REPLACE VIEW monitoring.v_active_transactions AS
 SELECT r.server,
    j.value ->> 'session_id'        AS session_id,
    j.value ->> 'login_name'        AS login_name,
    j.value ->> 'host_name'         AS host_name,
    j.value ->> 'database_name'     AS database_name,
    j.value ->> 'status'            AS status,
    (to_timestamp((((j.value ->> 'start_time')::bigint)::numeric / 1000.0)::double precision)
        AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Jerusalem'  AS start_time,
    j.value ->> 'command'           AS command,
    j.value ->> 'cpu_time'          AS cpu_time,
    j.value ->> 'total_elapsed_time' AS total_elapsed_time,
    j.value ->> 'transaction_id'    AS transaction_id,
    j.value ->> 'transaction_name'  AS transaction_name,
    j.value ->> 'query_text'        AS query,
    -- entry_date is stored as NAIVE LOCAL (Asia/Jerusalem) time, but Grafana
    -- reads timestamp-without-tz as UTC -> it displayed 3h ahead. Re-express the
    -- value as UTC-naive so Grafana renders the correct local time. Type stays
    -- `timestamp without time zone`, so CREATE OR REPLACE keeps dependents valid.
    r.entry_date  AS entry_date,
    r.server_id
   FROM monitoring.general_metric_metadata_results r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
  WHERE r.metric_name::text = 'Active transactions'::text;
