-- Idempotent install for monitoring.alert_case
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.alert_case_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.alert_case (
    row_id integer NOT NULL,
    config_alert_id integer,
    open timestamp with time zone,
    status text,
    context jsonb,
    entry_date timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE monitoring.alert_case ALTER COLUMN row_id SET DEFAULT nextval('monitoring.alert_case_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.alert_case_row_id_seq OWNED BY monitoring.alert_case.row_id;

SELECT setval('monitoring.alert_case_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.alert_case),1), (SELECT count(*) FROM monitoring.alert_case) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'alert_case'
          AND con.conname = 'alert_case_pkey') THEN
        ALTER TABLE ONLY monitoring.alert_case
    ADD CONSTRAINT alert_case_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
