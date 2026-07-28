-- Idempotent install for monitoring.metric_latest_result
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE TABLE IF NOT EXISTS monitoring.metric_latest_result (
    server character varying(50) NOT NULL,
    metric_name character varying(255) NOT NULL,
    category_id integer,
    metric_config json,
    metric_metadata jsonb,
    entry_date timestamp without time zone
);


DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'metric_latest_result'
          AND con.conname = 'metric_latest_result_pkey') THEN
        ALTER TABLE ONLY monitoring.metric_latest_result
    ADD CONSTRAINT metric_latest_result_pkey PRIMARY KEY (server, metric_name);
    END IF;
END $do$;
