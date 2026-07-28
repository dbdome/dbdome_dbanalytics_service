-- Idempotent install for monitoring.general_metric_metadata_results
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE TABLE IF NOT EXISTS monitoring.general_metric_metadata_results (
    id bigint NOT NULL,
    row_id integer,
    server character varying(50),
    category_id integer,
    metric_name character varying(255),
    metric_config json,
    metric_metadata jsonb,
    entry_date timestamp without time zone DEFAULT now() NOT NULL,
    metric_metadata_vs_expected jsonb,
    server_id uuid
)
PARTITION BY RANGE (entry_date);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_attribute a
        JOIN pg_class c ON c.oid = a.attrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'general_metric_metadata_results'
          AND a.attname = 'id' AND a.attidentity <> '') THEN
        EXECUTE $cmd$ ALTER TABLE monitoring.general_metric_metadata_results ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME monitoring.general_metric_metadata_results_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
); $cmd$;
    END IF;
END $do$;

SELECT setval('monitoring.general_metric_metadata_results_id_seq', GREATEST((SELECT COALESCE(max(id),0) FROM monitoring.general_metric_metadata_results),1), (SELECT count(*) FROM monitoring.general_metric_metadata_results) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'general_metric_metadata_results'
          AND con.conname = 'general_metric_metadata_results_pkey1') THEN
        ALTER TABLE ONLY monitoring.general_metric_metadata_results
    ADD CONSTRAINT general_metric_metadata_results_pkey1 PRIMARY KEY (entry_date, id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS ix_gmmr_entry_brin ON ONLY monitoring.general_metric_metadata_results USING brin (entry_date);
CREATE INDEX IF NOT EXISTS ix_gmmr_metric_date ON ONLY monitoring.general_metric_metadata_results USING btree (metric_name, entry_date DESC);
CREATE INDEX IF NOT EXISTS ix_gmmr_server_metric_date ON ONLY monitoring.general_metric_metadata_results USING btree (server, metric_name, entry_date DESC);
