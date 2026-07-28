-- Idempotent install for metrics.sensitive_columns
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS metrics;

CREATE TABLE IF NOT EXISTS metrics.sensitive_columns (
    row_id bigint NOT NULL,
    server text,
    db_name text,
    schema_name text,
    table_name text,
    column_name text,
    pii_category text,
    entry_date timestamp with time zone DEFAULT now() NOT NULL
);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_attribute a
        JOIN pg_class c ON c.oid = a.attrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'metrics' AND c.relname = 'sensitive_columns'
          AND a.attname = 'row_id' AND a.attidentity <> '') THEN
        EXECUTE $cmd$ ALTER TABLE metrics.sensitive_columns ALTER COLUMN row_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME metrics.sensitive_columns_row_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
); $cmd$;
    END IF;
END $do$;

SELECT setval('metrics.sensitive_columns_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM metrics.sensitive_columns),1), (SELECT count(*) FROM metrics.sensitive_columns) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'metrics' AND c.relname = 'sensitive_columns'
          AND con.conname = 'sensitive_columns_pkey') THEN
        ALTER TABLE ONLY metrics.sensitive_columns
    ADD CONSTRAINT sensitive_columns_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;

CREATE UNIQUE INDEX IF NOT EXISTS ux_metrics_sensitive_columns ON metrics.sensitive_columns USING btree (server, db_name, schema_name, table_name, column_name);
