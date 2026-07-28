-- Idempotent install for monitoring.metric_results
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.metric_results_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.metric_results (
    row_id integer NOT NULL,
    server character varying(255) NOT NULL,
    metric_id integer DEFAULT '-1'::integer NOT NULL,
    transaction_type character varying(25) NOT NULL,
    query text NOT NULL,
    metric_result numeric(18,2) DEFAULT 0 NOT NULL,
    metric_name character varying(50) NOT NULL,
    low_range numeric(18,2) DEFAULT 0 NOT NULL,
    high_range numeric(18,2) DEFAULT 0 NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE monitoring.metric_results ALTER COLUMN row_id SET DEFAULT nextval('monitoring.metric_results_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.metric_results_row_id_seq OWNED BY monitoring.metric_results.row_id;

SELECT setval('monitoring.metric_results_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.metric_results),1), (SELECT count(*) FROM monitoring.metric_results) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'metric_results'
          AND con.conname = 'metric_results_pkey') THEN
        ALTER TABLE ONLY monitoring.metric_results
    ADD CONSTRAINT metric_results_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
