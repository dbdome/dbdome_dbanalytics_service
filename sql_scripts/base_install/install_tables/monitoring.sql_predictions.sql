-- Idempotent install for monitoring.sql_predictions
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.sql_predictions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.sql_predictions (
    id bigint NOT NULL,
    query_id bigint,
    predicted_label text,
    predicted_index integer,
    predicted_scores jsonb,
    detected_at timestamp with time zone DEFAULT now(),
    update_status integer DEFAULT 1 NOT NULL,
    server character varying(50)
);

ALTER TABLE monitoring.sql_predictions ALTER COLUMN id SET DEFAULT nextval('monitoring.sql_predictions_id_seq'::regclass);
ALTER SEQUENCE monitoring.sql_predictions_id_seq OWNED BY monitoring.sql_predictions.id;

SELECT setval('monitoring.sql_predictions_id_seq', GREATEST((SELECT COALESCE(max(id),0) FROM monitoring.sql_predictions),1), (SELECT count(*) FROM monitoring.sql_predictions) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'sql_predictions'
          AND con.conname = 'sql_predictions_pkey') THEN
        ALTER TABLE ONLY monitoring.sql_predictions
    ADD CONSTRAINT sql_predictions_pkey PRIMARY KEY (id);
    END IF;
END $do$;
