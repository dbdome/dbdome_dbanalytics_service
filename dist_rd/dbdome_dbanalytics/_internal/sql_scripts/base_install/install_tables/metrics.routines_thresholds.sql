-- Idempotent install for metrics.routines_thresholds
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS metrics;

CREATE SEQUENCE IF NOT EXISTS metrics.routines_thresholds_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS metrics.routines_thresholds (
    row_id integer NOT NULL,
    routine_id integer NOT NULL,
    threshold_id integer NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE metrics.routines_thresholds ALTER COLUMN row_id SET DEFAULT nextval('metrics.routines_thresholds_row_id_seq'::regclass);
ALTER SEQUENCE metrics.routines_thresholds_row_id_seq OWNED BY metrics.routines_thresholds.row_id;

SELECT setval('metrics.routines_thresholds_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM metrics.routines_thresholds),1), (SELECT count(*) FROM metrics.routines_thresholds) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'metrics' AND c.relname = 'routines_thresholds'
          AND con.conname = 'pk_routines_thresholds') THEN
        ALTER TABLE ONLY metrics.routines_thresholds
    ADD CONSTRAINT pk_routines_thresholds PRIMARY KEY (routine_id, threshold_id);
    END IF;
END $do$;
