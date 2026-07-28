-- Idempotent install for monitoring.sensitive_schema
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.sensitive_schema_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.sensitive_schema (
    row_id integer NOT NULL,
    server character varying(50) NOT NULL,
    database_name character varying(50),
    table_schema character varying(50),
    table_name character varying(50),
    column_name character varying(50),
    data_type character varying(50),
    entry_date timestamp without time zone DEFAULT now() NOT NULL,
    pii_type character varying(50),
    mask_type character varying(20),
    is_masked boolean DEFAULT false NOT NULL
);

ALTER TABLE monitoring.sensitive_schema ALTER COLUMN row_id SET DEFAULT nextval('monitoring.sensitive_schema_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.sensitive_schema_row_id_seq OWNED BY monitoring.sensitive_schema.row_id;

SELECT setval('monitoring.sensitive_schema_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.sensitive_schema),1), (SELECT count(*) FROM monitoring.sensitive_schema) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'sensitive_schema'
          AND con.conname = 'sensitive_schema_pkey') THEN
        ALTER TABLE ONLY monitoring.sensitive_schema
    ADD CONSTRAINT sensitive_schema_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
