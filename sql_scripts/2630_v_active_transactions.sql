-- View: monitoring.v_active_transactions

-- DROP VIEW monitoring.v_active_transactions;

-- Must match 6060_fix_v_active_transactions_start_time_tz.sql exactly (same
-- columns/order/types) so v_all_active_transactions builds on the final shape and
-- 6060's later CREATE OR REPLACE is an in-place no-op.
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
    r.entry_date  AS entry_date,
    r.server_id
   FROM monitoring.general_metric_metadata_results r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
  WHERE r.metric_name::text = 'Active transactions'::text;

ALTER TABLE monitoring.v_active_transactions
    OWNER TO dbdome_adm;

