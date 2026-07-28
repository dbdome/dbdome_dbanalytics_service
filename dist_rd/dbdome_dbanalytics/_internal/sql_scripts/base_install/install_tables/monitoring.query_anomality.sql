-- Idempotent install for monitoring.query_anomality
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.query_anomality_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.query_anomality (
    row_id integer NOT NULL,
    server character varying(50) NOT NULL,
    anomaly_score numeric(12,2) NOT NULL,
    command character varying(50),
    duration_secs integer NOT NULL,
    query text NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE monitoring.query_anomality ALTER COLUMN row_id SET DEFAULT nextval('monitoring.query_anomality_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.query_anomality_row_id_seq OWNED BY monitoring.query_anomality.row_id;

SELECT setval('monitoring.query_anomality_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.query_anomality),1), (SELECT count(*) FROM monitoring.query_anomality) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'query_anomality'
          AND con.conname = 'pk_query_anomality') THEN
        ALTER TABLE ONLY monitoring.query_anomality
    ADD CONSTRAINT pk_query_anomality PRIMARY KEY (server, query);
    END IF;
END $do$;
