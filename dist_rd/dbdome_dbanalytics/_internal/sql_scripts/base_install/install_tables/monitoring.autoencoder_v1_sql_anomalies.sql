-- Idempotent install for monitoring.autoencoder_v1_sql_anomalies
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.autoencoder_v1_sql_anomalies_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.autoencoder_v1_sql_anomalies (
    id integer NOT NULL,
    server text,
    query text,
    reconstruction_error double precision,
    cpu_time double precision,
    duration_secs double precision,
    anomaly_score double precision,
    detected_at timestamp with time zone DEFAULT now()
);

ALTER TABLE monitoring.autoencoder_v1_sql_anomalies ALTER COLUMN id SET DEFAULT nextval('monitoring.autoencoder_v1_sql_anomalies_id_seq'::regclass);
ALTER SEQUENCE monitoring.autoencoder_v1_sql_anomalies_id_seq OWNED BY monitoring.autoencoder_v1_sql_anomalies.id;

SELECT setval('monitoring.autoencoder_v1_sql_anomalies_id_seq', GREATEST((SELECT COALESCE(max(id),0) FROM monitoring.autoencoder_v1_sql_anomalies),1), (SELECT count(*) FROM monitoring.autoencoder_v1_sql_anomalies) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'autoencoder_v1_sql_anomalies'
          AND con.conname = 'autoencoder_v1_sql_anomalies_pkey') THEN
        ALTER TABLE ONLY monitoring.autoencoder_v1_sql_anomalies
    ADD CONSTRAINT autoencoder_v1_sql_anomalies_pkey PRIMARY KEY (id);
    END IF;
END $do$;
