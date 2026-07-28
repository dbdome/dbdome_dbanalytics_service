-- Idempotent install for monitoring.active_sessions
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.active_sessions_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.active_sessions (
    row_id integer NOT NULL,
    server character varying(100) NOT NULL,
    session_id integer,
    blocking_session_id integer,
    wait_time integer,
    wait_type character varying(200),
    last_wait_type character varying(200),
    wait_resource character varying(200),
    transaction_isolation_level character varying(100),
    lock_timeout integer DEFAULT 0 NOT NULL,
    date_entry timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE monitoring.active_sessions ALTER COLUMN row_id SET DEFAULT nextval('monitoring.active_sessions_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.active_sessions_row_id_seq OWNED BY monitoring.active_sessions.row_id;

SELECT setval('monitoring.active_sessions_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.active_sessions),1), (SELECT count(*) FROM monitoring.active_sessions) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'active_sessions'
          AND con.conname = 'active_sessions_pkey') THEN
        ALTER TABLE ONLY monitoring.active_sessions
    ADD CONSTRAINT active_sessions_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
