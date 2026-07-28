-- Idempotent install for metrics.categories
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS metrics;

CREATE SEQUENCE IF NOT EXISTS metrics.categories_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS metrics.categories (
    row_id integer NOT NULL,
    category_name character varying(50) NOT NULL,
    description text,
    entry_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE metrics.categories ALTER COLUMN row_id SET DEFAULT nextval('metrics.categories_row_id_seq'::regclass);
ALTER SEQUENCE metrics.categories_row_id_seq OWNED BY metrics.categories.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE metrics.categories);
COPY _stg_load (row_id, category_name, description, entry_date) FROM stdin;
-1	general_results	general_results not for alerts	2025-08-13 10:03:47.346784
1	general alerts	general_results  for alerts	2025-08-13 10:04:39.11656
\.
INSERT INTO metrics.categories (row_id, category_name, description, entry_date)
SELECT row_id, category_name, description, entry_date FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM metrics.categories);
DROP TABLE _stg_load;

SELECT setval('metrics.categories_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM metrics.categories),1), (SELECT count(*) FROM metrics.categories) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'metrics' AND c.relname = 'categories'
          AND con.conname = 'categories_pkey') THEN
        ALTER TABLE ONLY metrics.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
