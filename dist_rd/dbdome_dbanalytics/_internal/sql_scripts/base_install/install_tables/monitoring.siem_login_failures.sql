-- Idempotent install for monitoring.siem_login_failures
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.siem_login_failures_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.siem_login_failures (
    row_id integer NOT NULL,
    server character varying(50) NOT NULL,
    login_time timestamp without time zone,
    host_name character varying(50),
    client_net_address character varying(50),
    login_name character varying(50),
    status character varying(50),
    failurecount integer,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE monitoring.siem_login_failures ALTER COLUMN row_id SET DEFAULT nextval('monitoring.siem_login_failures_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.siem_login_failures_row_id_seq OWNED BY monitoring.siem_login_failures.row_id;

SELECT setval('monitoring.siem_login_failures_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.siem_login_failures),1), (SELECT count(*) FROM monitoring.siem_login_failures) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'siem_login_failures'
          AND con.conname = 'siem_login_failures_pkey') THEN
        ALTER TABLE ONLY monitoring.siem_login_failures
    ADD CONSTRAINT siem_login_failures_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
