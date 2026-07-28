-- Idempotent install for monitoring.schema
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.schema_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.schema (
    row_id integer NOT NULL,
    table_catalog character varying(255),
    table_name character varying(255),
    column_name character varying(255),
    data_type character varying(255),
    endtry_date timestamp without time zone DEFAULT now() NOT NULL,
    server character varying(50),
    is_enabled boolean DEFAULT true
);

ALTER TABLE monitoring.schema ALTER COLUMN row_id SET DEFAULT nextval('monitoring.schema_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.schema_row_id_seq OWNED BY monitoring.schema.row_id;

SELECT setval('monitoring.schema_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.schema),1), (SELECT count(*) FROM monitoring.schema) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'schema'
          AND con.conname = 'schema_pkey') THEN
        ALTER TABLE ONLY monitoring.schema
    ADD CONSTRAINT schema_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
