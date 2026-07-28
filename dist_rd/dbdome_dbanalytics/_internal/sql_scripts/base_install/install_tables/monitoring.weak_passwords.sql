-- Idempotent install for monitoring.weak_passwords
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.weak_passwords_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.weak_passwords (
    row_id integer NOT NULL,
    server character varying(50),
    login_name character varying(50),
    is_policy_checked boolean,
    is_expiration_checked boolean,
    isintegratedsecurityonly boolean,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE monitoring.weak_passwords ALTER COLUMN row_id SET DEFAULT nextval('monitoring.weak_passwords_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.weak_passwords_row_id_seq OWNED BY monitoring.weak_passwords.row_id;

SELECT setval('monitoring.weak_passwords_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.weak_passwords),1), (SELECT count(*) FROM monitoring.weak_passwords) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'weak_passwords'
          AND con.conname = 'weak_passwords_pkey') THEN
        ALTER TABLE ONLY monitoring.weak_passwords
    ADD CONSTRAINT weak_passwords_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
