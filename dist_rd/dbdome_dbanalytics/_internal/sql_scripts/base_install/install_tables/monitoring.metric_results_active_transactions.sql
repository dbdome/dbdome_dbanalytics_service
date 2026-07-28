-- Idempotent install for monitoring.metric_results_active_transactions
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE TABLE IF NOT EXISTS monitoring.metric_results_active_transactions (
    row_id integer,
    server character varying(255),
    metric_id integer,
    transaction_type character varying(25),
    query text,
    metric_result numeric(18,2),
    metric_name character varying(50),
    low_range numeric(18,2),
    high_range numeric(18,2),
    entry_date timestamp without time zone
);
