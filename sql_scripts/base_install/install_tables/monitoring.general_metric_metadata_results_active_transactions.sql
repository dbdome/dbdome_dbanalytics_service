-- Idempotent install for monitoring.general_metric_metadata_results_active_transactions
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE TABLE IF NOT EXISTS monitoring.general_metric_metadata_results_active_transactions (
    row_id integer,
    server character varying(50),
    category_id integer,
    metric_name character varying(255),
    metric_config json,
    metric_metadata jsonb,
    entry_date timestamp without time zone
);
