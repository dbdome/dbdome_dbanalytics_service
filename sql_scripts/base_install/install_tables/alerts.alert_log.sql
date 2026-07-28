-- Idempotent install for alerts.alert_log
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS alerts;

CREATE SEQUENCE IF NOT EXISTS alerts.alert_log_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS alerts.alert_log (
    row_id integer NOT NULL,
    server character varying(100) NOT NULL,
    root_cause_id character varying(100) NOT NULL,
    risk_level character varying(50) NOT NULL,
    metadata jsonb NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL,
    login_name text,
    metric_query jsonb
);

ALTER TABLE alerts.alert_log ALTER COLUMN row_id SET DEFAULT nextval('alerts.alert_log_row_id_seq'::regclass);
ALTER SEQUENCE alerts.alert_log_row_id_seq OWNED BY alerts.alert_log.row_id;

SELECT setval('alerts.alert_log_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM alerts.alert_log),1), (SELECT count(*) FROM alerts.alert_log) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'alerts' AND c.relname = 'alert_log'
          AND con.conname = 'alert_log_pkey') THEN
        ALTER TABLE ONLY alerts.alert_log
    ADD CONSTRAINT alert_log_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS ix_date ON alerts.alert_log USING btree (entry_date);
CREATE INDEX IF NOT EXISTS ix_entry_date ON alerts.alert_log USING btree (entry_date);
