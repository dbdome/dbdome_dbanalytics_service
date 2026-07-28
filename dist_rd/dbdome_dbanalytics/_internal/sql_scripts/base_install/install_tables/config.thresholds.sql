-- Idempotent install for config.thresholds
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.thresholds_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.thresholds (
    row_id integer NOT NULL,
    level integer NOT NULL,
    value_start numeric(10,2),
    value_end numeric(10,2),
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE config.thresholds ALTER COLUMN row_id SET DEFAULT nextval('config.thresholds_row_id_seq'::regclass);
ALTER SEQUENCE config.thresholds_row_id_seq OWNED BY config.thresholds.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE config.thresholds);
COPY _stg_load (row_id, level, value_start, value_end, entry_date) FROM stdin;
1	3	-10.00	40.00	2026-01-03 20:05:53.326424
2	3	1.00	99999.00	2026-02-14 22:13:51.301419
\.
INSERT INTO config.thresholds (row_id, level, value_start, value_end, entry_date)
SELECT row_id, level, value_start, value_end, entry_date FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM config.thresholds);
DROP TABLE _stg_load;

SELECT setval('config.thresholds_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM config.thresholds),1), (SELECT count(*) FROM config.thresholds) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'thresholds'
          AND con.conname = 'thresholds_pkey') THEN
        ALTER TABLE ONLY config.thresholds
    ADD CONSTRAINT thresholds_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
