-- Idempotent install for meta.schema_migrations
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS meta;

CREATE SEQUENCE IF NOT EXISTS meta.schema_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS meta.schema_migrations (
    id bigint NOT NULL,
    filename text NOT NULL,
    checksum text NOT NULL,
    applied_at timestamp with time zone DEFAULT now() NOT NULL,
    execution_ms integer,
    success boolean DEFAULT true NOT NULL,
    error text
);

ALTER TABLE meta.schema_migrations ALTER COLUMN id SET DEFAULT nextval('meta.schema_migrations_id_seq'::regclass);
ALTER SEQUENCE meta.schema_migrations_id_seq OWNED BY meta.schema_migrations.id;

SELECT setval('meta.schema_migrations_id_seq', GREATEST((SELECT COALESCE(max(id),0) FROM meta.schema_migrations),1), (SELECT count(*) FROM meta.schema_migrations) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'meta' AND c.relname = 'schema_migrations'
          AND con.conname = 'schema_migrations_pkey') THEN
        ALTER TABLE ONLY meta.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS ix_schema_migrations_file ON meta.schema_migrations USING btree (filename, applied_at DESC);
