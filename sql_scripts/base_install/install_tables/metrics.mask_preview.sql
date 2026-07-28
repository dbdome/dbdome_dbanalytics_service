-- Idempotent install for metrics.mask_preview
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS metrics;

CREATE TABLE IF NOT EXISTS metrics.mask_preview (
    preview_id bigint NOT NULL,
    server text,
    db_name text,
    schema_name text,
    table_name text,
    column_name text,
    row_no integer,
    real_value text,
    masked_value text,
    entry_date timestamp with time zone DEFAULT now() NOT NULL
);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_attribute a
        JOIN pg_class c ON c.oid = a.attrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'metrics' AND c.relname = 'mask_preview'
          AND a.attname = 'preview_id' AND a.attidentity <> '') THEN
        EXECUTE $cmd$ ALTER TABLE metrics.mask_preview ALTER COLUMN preview_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME metrics.mask_preview_preview_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
); $cmd$;
    END IF;
END $do$;

SELECT setval('metrics.mask_preview_preview_id_seq', GREATEST((SELECT COALESCE(max(preview_id),0) FROM metrics.mask_preview),1), (SELECT count(*) FROM metrics.mask_preview) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'metrics' AND c.relname = 'mask_preview'
          AND con.conname = 'mask_preview_pkey') THEN
        ALTER TABLE ONLY metrics.mask_preview
    ADD CONSTRAINT mask_preview_pkey PRIMARY KEY (preview_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS ix_mask_preview_col ON metrics.mask_preview USING btree (server, db_name, schema_name, table_name, column_name);
