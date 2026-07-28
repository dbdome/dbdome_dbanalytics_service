-- Idempotent install for monitoring.active_transactions_locks
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE TABLE IF NOT EXISTS monitoring.active_transactions_locks (
    row_id integer,
    server character varying(128),
    session_id integer,
    blocking_session_id integer,
    duration_secs integer,
    database_name character varying(255),
    start_time timestamp without time zone,
    last_request_end_time timestamp without time zone,
    open_transaction_count integer,
    cpu_time integer,
    command character varying(255),
    logical_reads integer,
    reads integer,
    writes integer,
    wait_type character varying(50),
    last_wait_type character varying(50),
    login_name character varying(50),
    program_name character varying(255),
    host_name character varying(50),
    query text,
    object_name character varying(50),
    date_entry timestamp with time zone,
    table_name character varying(50)
);
