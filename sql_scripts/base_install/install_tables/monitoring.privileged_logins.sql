-- Idempotent install for monitoring.privileged_logins
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.privileged_logins_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.privileged_logins (
    row_id integer NOT NULL,
    server character varying(50) NOT NULL,
    loginname character varying(50) NOT NULL,
    logintype character varying(50) NOT NULL,
    serverrole character varying(50) NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE monitoring.privileged_logins ALTER COLUMN row_id SET DEFAULT nextval('monitoring.privileged_logins_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.privileged_logins_row_id_seq OWNED BY monitoring.privileged_logins.row_id;

SELECT setval('monitoring.privileged_logins_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.privileged_logins),1), (SELECT count(*) FROM monitoring.privileged_logins) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'privileged_logins'
          AND con.conname = 'privileged_logins_pkey') THEN
        ALTER TABLE ONLY monitoring.privileged_logins
    ADD CONSTRAINT privileged_logins_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
