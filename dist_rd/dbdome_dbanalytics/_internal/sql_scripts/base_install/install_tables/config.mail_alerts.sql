-- Idempotent install for config.mail_alerts
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.mail_alerts_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.mail_alerts (
    row_id integer NOT NULL,
    mail_config_id integer NOT NULL,
    alert_name character varying(255),
    transaction_type character varying(255) NOT NULL,
    recipients text,
    subject text,
    body text,
    report_url text,
    entry_date timestamp without time zone DEFAULT now() NOT NULL,
    report_user character varying(50),
    report_password character varying(50)
);

ALTER TABLE config.mail_alerts ALTER COLUMN row_id SET DEFAULT nextval('config.mail_alerts_row_id_seq'::regclass);
ALTER SEQUENCE config.mail_alerts_row_id_seq OWNED BY config.mail_alerts.row_id;

SELECT setval('config.mail_alerts_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM config.mail_alerts),1), (SELECT count(*) FROM config.mail_alerts) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'mail_alerts'
          AND con.conname = 'mail_alerts_pkey') THEN
        ALTER TABLE ONLY config.mail_alerts
    ADD CONSTRAINT mail_alerts_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
