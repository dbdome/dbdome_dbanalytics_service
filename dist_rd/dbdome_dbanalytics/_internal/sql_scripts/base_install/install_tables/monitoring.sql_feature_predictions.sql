-- Idempotent install for monitoring.sql_feature_predictions
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.sql_feature_predictions_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.sql_feature_predictions (
    row_id integer NOT NULL,
    query_id integer NOT NULL,
    sql_text text NOT NULL,
    features jsonb NOT NULL,
    entry_date timestamp without time zone DEFAULT now(),
    update_status integer DEFAULT 1 NOT NULL,
    server character varying(50)
);

ALTER TABLE monitoring.sql_feature_predictions ALTER COLUMN row_id SET DEFAULT nextval('monitoring.sql_feature_predictions_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.sql_feature_predictions_row_id_seq OWNED BY monitoring.sql_feature_predictions.row_id;

SELECT setval('monitoring.sql_feature_predictions_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.sql_feature_predictions),1), (SELECT count(*) FROM monitoring.sql_feature_predictions) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'sql_feature_predictions'
          AND con.conname = 'pk_sql_feature_predictions') THEN
        ALTER TABLE ONLY monitoring.sql_feature_predictions
    ADD CONSTRAINT pk_sql_feature_predictions PRIMARY KEY (query_id);
    END IF;
END $do$;
