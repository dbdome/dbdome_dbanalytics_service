-- Idempotent install for config.dump_metrics
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE TABLE IF NOT EXISTS config.dump_metrics (
    row_id bigint NOT NULL,
    metric_name character varying(255) NOT NULL,
    retention_months integer DEFAULT 12 NOT NULL,
    entry_date timestamp with time zone DEFAULT now() NOT NULL
);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_attribute a
        JOIN pg_class c ON c.oid = a.attrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'dump_metrics'
          AND a.attname = 'row_id' AND a.attidentity <> '') THEN
        EXECUTE $cmd$ ALTER TABLE config.dump_metrics ALTER COLUMN row_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME config.dump_metrics_row_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
); $cmd$;
    END IF;
END $do$;

SELECT setval('config.dump_metrics_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM config.dump_metrics),1), (SELECT count(*) FROM config.dump_metrics) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'dump_metrics'
          AND con.conname = 'dump_metrics_pkey') THEN
        ALTER TABLE ONLY config.dump_metrics
    ADD CONSTRAINT dump_metrics_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;

CREATE UNIQUE INDEX IF NOT EXISTS ux_dump_metrics_metric_name ON config.dump_metrics USING btree (metric_name);
