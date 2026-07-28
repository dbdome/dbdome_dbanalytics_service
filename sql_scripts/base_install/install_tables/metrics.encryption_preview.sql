-- Idempotent install for metrics.encryption_preview
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS metrics;

CREATE TABLE IF NOT EXISTS metrics.encryption_preview (
    preview_id bigint NOT NULL,
    entry_date timestamp with time zone DEFAULT now() NOT NULL,
    server text,
    db_name text,
    schema_name text,
    table_name text,
    column_name text,
    row_no integer,
    original_value text,
    token_value text
);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_attribute a
        JOIN pg_class c ON c.oid = a.attrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'metrics' AND c.relname = 'encryption_preview'
          AND a.attname = 'preview_id' AND a.attidentity <> '') THEN
        EXECUTE $cmd$ ALTER TABLE metrics.encryption_preview ALTER COLUMN preview_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME metrics.encryption_preview_preview_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
); $cmd$;
    END IF;
END $do$;

SELECT setval('metrics.encryption_preview_preview_id_seq', GREATEST((SELECT COALESCE(max(preview_id),0) FROM metrics.encryption_preview),1), (SELECT count(*) FROM metrics.encryption_preview) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'metrics' AND c.relname = 'encryption_preview'
          AND con.conname = 'encryption_preview_pkey') THEN
        ALTER TABLE ONLY metrics.encryption_preview
    ADD CONSTRAINT encryption_preview_pkey PRIMARY KEY (preview_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS ix_encryption_preview_col ON metrics.encryption_preview USING btree (server, db_name, schema_name, table_name, column_name);
