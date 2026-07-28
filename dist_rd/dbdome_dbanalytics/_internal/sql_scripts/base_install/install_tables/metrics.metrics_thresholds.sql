-- Idempotent install for metrics.metrics_thresholds
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS metrics;

CREATE SEQUENCE IF NOT EXISTS metrics.metrics_thresholds_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS metrics.metrics_thresholds (
    row_id integer NOT NULL,
    metric_id integer NOT NULL,
    server_id integer DEFAULT '-1'::integer NOT NULL,
    severity integer DEFAULT 1 NOT NULL,
    hour_in_day integer DEFAULT '-1'::integer NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE metrics.metrics_thresholds ALTER COLUMN row_id SET DEFAULT nextval('metrics.metrics_thresholds_row_id_seq'::regclass);
ALTER SEQUENCE metrics.metrics_thresholds_row_id_seq OWNED BY metrics.metrics_thresholds.row_id;

SELECT setval('metrics.metrics_thresholds_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM metrics.metrics_thresholds),1), (SELECT count(*) FROM metrics.metrics_thresholds) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'metrics' AND c.relname = 'metrics_thresholds'
          AND con.conname = 'metrics_thresholds_pkey') THEN
        ALTER TABLE ONLY metrics.metrics_thresholds
    ADD CONSTRAINT metrics_thresholds_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
