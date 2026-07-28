-- Idempotent install for monitoring.injection_requests
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.injection_requests_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.injection_requests (
    row_id integer NOT NULL,
    server character varying(50),
    query text,
    status character varying(50),
    command character varying(50),
    cpu_time integer,
    total_elapsed_time integer,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE monitoring.injection_requests ALTER COLUMN row_id SET DEFAULT nextval('monitoring.injection_requests_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.injection_requests_row_id_seq OWNED BY monitoring.injection_requests.row_id;

SELECT setval('monitoring.injection_requests_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.injection_requests),1), (SELECT count(*) FROM monitoring.injection_requests) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'injection_requests'
          AND con.conname = 'injection_requests_pkey') THEN
        ALTER TABLE ONLY monitoring.injection_requests
    ADD CONSTRAINT injection_requests_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
