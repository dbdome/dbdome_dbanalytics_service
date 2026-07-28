-- Idempotent install for monitoring.table_usage
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.table_usage_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.table_usage (
    row_id integer NOT NULL,
    server character varying(255),
    table_name character varying(255),
    column_name character varying(255),
    inserts bigint,
    updates bigint,
    deletes bigint,
    live_rows bigint,
    size character varying(20),
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE monitoring.table_usage ALTER COLUMN row_id SET DEFAULT nextval('monitoring.table_usage_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.table_usage_row_id_seq OWNED BY monitoring.table_usage.row_id;

SELECT setval('monitoring.table_usage_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.table_usage),1), (SELECT count(*) FROM monitoring.table_usage) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'table_usage'
          AND con.conname = 'table_usage_pkey') THEN
        ALTER TABLE ONLY monitoring.table_usage
    ADD CONSTRAINT table_usage_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
