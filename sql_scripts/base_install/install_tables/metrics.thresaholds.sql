-- Idempotent install for metrics.thresaholds
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS metrics;

CREATE SEQUENCE IF NOT EXISTS metrics.thresaholds_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS metrics.thresaholds (
    row_id integer NOT NULL,
    routine_id integer NOT NULL,
    day_of_event integer NOT NULL,
    hour_of_event integer NOT NULL,
    value_from numeric(10,2) DEFAULT 0 NOT NULL,
    value_to numeric(10,2) DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE metrics.thresaholds ALTER COLUMN row_id SET DEFAULT nextval('metrics.thresaholds_row_id_seq'::regclass);
ALTER SEQUENCE metrics.thresaholds_row_id_seq OWNED BY metrics.thresaholds.row_id;

SELECT setval('metrics.thresaholds_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM metrics.thresaholds),1), (SELECT count(*) FROM metrics.thresaholds) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'metrics' AND c.relname = 'thresaholds'
          AND con.conname = 'thresaholds_pkey') THEN
        ALTER TABLE ONLY metrics.thresaholds
    ADD CONSTRAINT thresaholds_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
