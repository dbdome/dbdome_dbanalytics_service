-- Idempotent install for metrics.server_log
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS metrics;

CREATE TABLE IF NOT EXISTS metrics.server_log (
    log_id bigint NOT NULL,
    operation text NOT NULL,
    changed_at timestamp with time zone DEFAULT now() NOT NULL,
    changed_by text DEFAULT CURRENT_USER NOT NULL,
    server_id uuid,
    servername text,
    old_data jsonb,
    new_data jsonb
);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_attribute a
        JOIN pg_class c ON c.oid = a.attrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'metrics' AND c.relname = 'server_log'
          AND a.attname = 'log_id' AND a.attidentity <> '') THEN
        EXECUTE $cmd$ ALTER TABLE metrics.server_log ALTER COLUMN log_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME metrics.server_log_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
); $cmd$;
    END IF;
END $do$;

SELECT setval('metrics.server_log_log_id_seq', GREATEST((SELECT COALESCE(max(log_id),0) FROM metrics.server_log),1), (SELECT count(*) FROM metrics.server_log) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'metrics' AND c.relname = 'server_log'
          AND con.conname = 'server_log_pkey') THEN
        ALTER TABLE ONLY metrics.server_log
    ADD CONSTRAINT server_log_pkey PRIMARY KEY (log_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS ix_server_log_changed_at ON metrics.server_log USING btree (changed_at DESC);
CREATE INDEX IF NOT EXISTS ix_server_log_server ON metrics.server_log USING btree (servername, changed_at DESC);
