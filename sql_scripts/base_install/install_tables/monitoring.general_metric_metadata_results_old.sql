-- Idempotent install for monitoring.general_metric_metadata_results_old
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.general_metric_metadata_results_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.general_metric_metadata_results_old (
    row_id integer CONSTRAINT general_metric_metadata_results_row_id_not_null NOT NULL,
    server character varying(50) CONSTRAINT general_metric_metadata_results_server_not_null NOT NULL,
    category_id integer CONSTRAINT general_metric_metadata_results_category_id_not_null NOT NULL,
    metric_name character varying(255) CONSTRAINT general_metric_metadata_results_metric_name_not_null NOT NULL,
    metric_config json,
    metric_metadata jsonb,
    entry_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    metric_metadata_vs_expected jsonb,
    server_id uuid
);

ALTER TABLE monitoring.general_metric_metadata_results_old ALTER COLUMN row_id SET DEFAULT nextval('monitoring.general_metric_metadata_results_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.general_metric_metadata_results_row_id_seq OWNED BY monitoring.general_metric_metadata_results_old.row_id;

SELECT setval('monitoring.general_metric_metadata_results_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.general_metric_metadata_results_old),1), (SELECT count(*) FROM monitoring.general_metric_metadata_results_old) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'general_metric_metadata_results_old'
          AND con.conname = 'general_metric_metadata_results_pkey') THEN
        ALTER TABLE ONLY monitoring.general_metric_metadata_results_old
    ADD CONSTRAINT general_metric_metadata_results_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS ix_metric_name ON monitoring.general_metric_metadata_results_old USING btree (metric_name);
