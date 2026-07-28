-- Idempotent install for monitoring.transaction_requests
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.transaction_requests_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.transaction_requests (
    row_id integer NOT NULL,
    server character varying(100),
    start_time timestamp without time zone NOT NULL,
    command text,
    last_request_end_time timestamp without time zone NOT NULL,
    session_id integer NOT NULL,
    status character varying(25),
    blocking_session_id integer NOT NULL,
    wait_type character varying(25),
    wait_time integer,
    cpu_time integer,
    total_elapsed_time integer,
    reads integer,
    writes integer,
    logical_reads integer,
    login_name character varying(25),
    host_name character varying(25),
    program_name character varying(50),
    is_user_process boolean,
    sql_text text,
    connection_id character varying(50),
    database_name character varying(50),
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE monitoring.transaction_requests ALTER COLUMN row_id SET DEFAULT nextval('monitoring.transaction_requests_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.transaction_requests_row_id_seq OWNED BY monitoring.transaction_requests.row_id;

SELECT setval('monitoring.transaction_requests_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.transaction_requests),1), (SELECT count(*) FROM monitoring.transaction_requests) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'transaction_requests'
          AND con.conname = 'transaction_requests_pkey') THEN
        ALTER TABLE ONLY monitoring.transaction_requests
    ADD CONSTRAINT transaction_requests_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
