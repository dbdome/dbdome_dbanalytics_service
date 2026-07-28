-- Idempotent install for monitoring.active_transactions
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.active_transactions_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.active_transactions (
    row_id integer NOT NULL,
    server character varying(128),
    session_id integer NOT NULL,
    blocking_session_id integer DEFAULT 0 NOT NULL,
    duration_secs integer DEFAULT 0 NOT NULL,
    database_name character varying(255),
    start_time timestamp without time zone DEFAULT now() NOT NULL,
    last_request_end_time timestamp without time zone DEFAULT now() NOT NULL,
    open_transaction_count integer DEFAULT 0 NOT NULL,
    cpu_time integer DEFAULT 0 NOT NULL,
    command character varying(255),
    logical_reads integer DEFAULT 0 NOT NULL,
    reads integer DEFAULT 0 NOT NULL,
    writes integer DEFAULT 0 NOT NULL,
    wait_type character varying(50),
    last_wait_type character varying(50),
    login_name character varying(50),
    program_name character varying(255),
    host_name character varying(50),
    query text,
    object_name character varying(50),
    date_entry timestamp with time zone DEFAULT now() NOT NULL,
    table_name character varying(50)
);

ALTER TABLE monitoring.active_transactions ALTER COLUMN row_id SET DEFAULT nextval('monitoring.active_transactions_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.active_transactions_row_id_seq OWNED BY monitoring.active_transactions.row_id;

SELECT setval('monitoring.active_transactions_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.active_transactions),1), (SELECT count(*) FROM monitoring.active_transactions) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'active_transactions'
          AND con.conname = 'active_transactions_pkey') THEN
        ALTER TABLE ONLY monitoring.active_transactions
    ADD CONSTRAINT active_transactions_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS fix_last_request_end_time ON monitoring.active_transactions USING btree (last_request_end_time);
CREATE INDEX IF NOT EXISTS ix_duration_secs ON monitoring.active_transactions USING btree (duration_secs) WHERE (duration_secs > 0);
CREATE INDEX IF NOT EXISTS ix_last_request_end_tim_server_database_name ON monitoring.active_transactions USING btree (last_request_end_time, server, database_name);
CREATE INDEX IF NOT EXISTS ix_last_request_end_time_start_time ON monitoring.active_transactions USING btree (start_time, last_request_end_time);
