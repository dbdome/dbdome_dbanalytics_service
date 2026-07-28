-- Idempotent install for alerts.blocks
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS alerts;

CREATE SEQUENCE IF NOT EXISTS alerts.blocks_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS alerts.blocks (
    row_id integer NOT NULL,
    metric_result_row_id bigint,
    server character varying(50),
    transaction_type character varying(255),
    metric_name character varying(255),
    body text,
    recipients text,
    report_url text,
    subject text,
    interval_secs integer,
    start_time time without time zone,
    end_time time without time zone,
    entry_date timestamp without time zone DEFAULT now() NOT NULL,
    login_name text,
    metric_metadata_json jsonb,
    metric_query jsonb
);

ALTER TABLE alerts.blocks ALTER COLUMN row_id SET DEFAULT nextval('alerts.blocks_row_id_seq'::regclass);
ALTER SEQUENCE alerts.blocks_row_id_seq OWNED BY alerts.blocks.row_id;

SELECT setval('alerts.blocks_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM alerts.blocks),1), (SELECT count(*) FROM alerts.blocks) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'alerts' AND c.relname = 'blocks'
          AND con.conname = 'blocks_pkey') THEN
        ALTER TABLE ONLY alerts.blocks
    ADD CONSTRAINT blocks_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
