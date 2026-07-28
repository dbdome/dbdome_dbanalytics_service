-- Idempotent install for config.mail_alerts_schedule
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.mail_alerts_schedule_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.mail_alerts_schedule (
    row_id integer NOT NULL,
    mail_alert_id integer NOT NULL,
    interval_secs integer DEFAULT '-1'::integer NOT NULL,
    start_time time without time zone DEFAULT '09:00:00'::time without time zone NOT NULL,
    end_time time without time zone DEFAULT '09:00:00'::time without time zone NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE config.mail_alerts_schedule ALTER COLUMN row_id SET DEFAULT nextval('config.mail_alerts_schedule_row_id_seq'::regclass);
ALTER SEQUENCE config.mail_alerts_schedule_row_id_seq OWNED BY config.mail_alerts_schedule.row_id;

SELECT setval('config.mail_alerts_schedule_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM config.mail_alerts_schedule),1), (SELECT count(*) FROM config.mail_alerts_schedule) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'mail_alerts_schedule'
          AND con.conname = 'mail_alerts_schedule_pkey') THEN
        ALTER TABLE ONLY config.mail_alerts_schedule
    ADD CONSTRAINT mail_alerts_schedule_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
