-- Idempotent install for config.mail_config
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.mail_config_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.mail_config (
    row_id integer NOT NULL,
    smtp_server character varying(50) NOT NULL,
    smtp_port integer NOT NULL,
    smtp_user character varying(50),
    smtp_password text NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL,
    tls boolean DEFAULT true NOT NULL,
    mail_sender text
);

ALTER TABLE config.mail_config ALTER COLUMN row_id SET DEFAULT nextval('config.mail_config_row_id_seq'::regclass);
ALTER SEQUENCE config.mail_config_row_id_seq OWNED BY config.mail_config.row_id;

SELECT setval('config.mail_config_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM config.mail_config),1), (SELECT count(*) FROM config.mail_config) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'mail_config'
          AND con.conname = 'mail_config_pkey') THEN
        ALTER TABLE ONLY config.mail_config
    ADD CONSTRAINT mail_config_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
