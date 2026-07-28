-- Idempotent install for monitoring.metric_query_parsing
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.metric_query_parsing_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.metric_query_parsing (
    row_id integer NOT NULL,
    server character varying(255) NOT NULL,
    query_id integer DEFAULT '-1'::integer NOT NULL,
    query text DEFAULT 'empty'::text NOT NULL,
    observed_at text,
    columns text DEFAULT 'empty'::text NOT NULL,
    tables text DEFAULT 'empty'::text NOT NULL,
    literal text DEFAULT 'empty'::text NOT NULL,
    condition text DEFAULT 'empty'::text NOT NULL,
    joins text DEFAULT 'empty'::text NOT NULL,
    func text DEFAULT 'empty'::text NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL,
    table_name character varying(50)
);

ALTER TABLE monitoring.metric_query_parsing ALTER COLUMN row_id SET DEFAULT nextval('monitoring.metric_query_parsing_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.metric_query_parsing_row_id_seq OWNED BY monitoring.metric_query_parsing.row_id;

SELECT setval('monitoring.metric_query_parsing_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.metric_query_parsing),1), (SELECT count(*) FROM monitoring.metric_query_parsing) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'metric_query_parsing'
          AND con.conname = 'metric_query_parsing_pkey') THEN
        ALTER TABLE ONLY monitoring.metric_query_parsing
    ADD CONSTRAINT metric_query_parsing_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
