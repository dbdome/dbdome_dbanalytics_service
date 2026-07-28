-- Idempotent install for config.dumps
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE TABLE IF NOT EXISTS config.dumps (
    row_id bigint NOT NULL,
    metric_name character varying(255) NOT NULL,
    month integer NOT NULL,
    year integer NOT NULL,
    dump_location text NOT NULL,
    row_count bigint,
    entry_date timestamp with time zone DEFAULT now() NOT NULL
);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_attribute a
        JOIN pg_class c ON c.oid = a.attrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'dumps'
          AND a.attname = 'row_id' AND a.attidentity <> '') THEN
        EXECUTE $cmd$ ALTER TABLE config.dumps ALTER COLUMN row_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME config.dumps_row_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
); $cmd$;
    END IF;
END $do$;

SELECT setval('config.dumps_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM config.dumps),1), (SELECT count(*) FROM config.dumps) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'dumps'
          AND con.conname = 'dumps_pkey') THEN
        ALTER TABLE ONLY config.dumps
    ADD CONSTRAINT dumps_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;

CREATE UNIQUE INDEX IF NOT EXISTS ux_dumps_metric_month_year ON config.dumps USING btree (metric_name, month, year);
