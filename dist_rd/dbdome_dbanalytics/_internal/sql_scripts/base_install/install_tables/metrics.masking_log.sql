-- Idempotent install for metrics.masking_log
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS metrics;

CREATE TABLE IF NOT EXISTS metrics.masking_log (
    log_id bigint NOT NULL,
    entry_date timestamp with time zone DEFAULT now() NOT NULL,
    server text,
    db_name text,
    schema_name text,
    table_name text,
    column_name text,
    mask_function text,
    action text,
    detail text
);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_attribute a
        JOIN pg_class c ON c.oid = a.attrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'metrics' AND c.relname = 'masking_log'
          AND a.attname = 'log_id' AND a.attidentity <> '') THEN
        EXECUTE $cmd$ ALTER TABLE metrics.masking_log ALTER COLUMN log_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME metrics.masking_log_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
); $cmd$;
    END IF;
END $do$;

SELECT setval('metrics.masking_log_log_id_seq', GREATEST((SELECT COALESCE(max(log_id),0) FROM metrics.masking_log),1), (SELECT count(*) FROM metrics.masking_log) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'metrics' AND c.relname = 'masking_log'
          AND con.conname = 'masking_log_pkey') THEN
        ALTER TABLE ONLY metrics.masking_log
    ADD CONSTRAINT masking_log_pkey PRIMARY KEY (log_id);
    END IF;
END $do$;
