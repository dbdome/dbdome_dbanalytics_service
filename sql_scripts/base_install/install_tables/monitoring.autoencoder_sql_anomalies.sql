-- Idempotent install for monitoring.autoencoder_sql_anomalies
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE TABLE IF NOT EXISTS monitoring.autoencoder_sql_anomalies (
    server text,
    query text,
    cpu_time double precision,
    duration_secs double precision,
    wait_type text,
    login_name text,
    detected_anomaly double precision,
    anomaly_score double precision,
    command text,
    query_id bigint
);
