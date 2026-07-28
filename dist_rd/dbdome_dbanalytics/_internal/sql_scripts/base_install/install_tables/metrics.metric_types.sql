-- Idempotent install for metrics.metric_types
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS metrics;

CREATE SEQUENCE IF NOT EXISTS metrics.metric_types_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS metrics.metric_types (
    row_id integer NOT NULL,
    metric_type character varying(50) NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE metrics.metric_types ALTER COLUMN row_id SET DEFAULT nextval('metrics.metric_types_row_id_seq'::regclass);
ALTER SEQUENCE metrics.metric_types_row_id_seq OWNED BY metrics.metric_types.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE metrics.metric_types);
COPY _stg_load (row_id, metric_type, entry_date) FROM stdin;
2	Security-Threats	2025-04-21 18:26:38.641061
3	Security-Roles & Authentication	2025-04-21 18:26:41.151389
4	Security-TCP Connection	2025-04-21 18:26:43.400129
\.
INSERT INTO metrics.metric_types (row_id, metric_type, entry_date)
SELECT row_id, metric_type, entry_date FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM metrics.metric_types);
DROP TABLE _stg_load;

SELECT setval('metrics.metric_types_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM metrics.metric_types),1), (SELECT count(*) FROM metrics.metric_types) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'metrics' AND c.relname = 'metric_types'
          AND con.conname = 'metric_types_pkey') THEN
        ALTER TABLE ONLY metrics.metric_types
    ADD CONSTRAINT metric_types_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
