-- Idempotent install for monitoring.alerts
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.alerts_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.alerts (
    row_id integer NOT NULL,
    server character varying(50),
    name character varying(50),
    event_source character varying(50),
    message_id integer,
    severity character varying(50),
    enabled boolean,
    has_notification bit(1),
    delay_between_responses character varying(50),
    occurrence_count integer,
    last_occurrence_date date,
    last_occurrence_time time without time zone,
    entry_date timestamp without time zone DEFAULT now()
);

ALTER TABLE monitoring.alerts ALTER COLUMN row_id SET DEFAULT nextval('monitoring.alerts_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.alerts_row_id_seq OWNED BY monitoring.alerts.row_id;

SELECT setval('monitoring.alerts_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.alerts),1), (SELECT count(*) FROM monitoring.alerts) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'alerts'
          AND con.conname = 'alerts_pkey') THEN
        ALTER TABLE ONLY monitoring.alerts
    ADD CONSTRAINT alerts_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
