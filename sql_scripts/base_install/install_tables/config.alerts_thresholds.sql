-- Idempotent install for config.alerts_thresholds
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.alerts_thresholds_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.alerts_thresholds (
    row_id integer NOT NULL,
    alert_id integer NOT NULL,
    threshold_id integer NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE config.alerts_thresholds ALTER COLUMN row_id SET DEFAULT nextval('config.alerts_thresholds_row_id_seq'::regclass);
ALTER SEQUENCE config.alerts_thresholds_row_id_seq OWNED BY config.alerts_thresholds.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE config.alerts_thresholds);
COPY _stg_load (row_id, alert_id, threshold_id, entry_date) FROM stdin;
1	1	1	2026-01-03 20:11:32.922949
2	336	2	2026-02-14 22:14:20.504009
\.
INSERT INTO config.alerts_thresholds (row_id, alert_id, threshold_id, entry_date)
SELECT row_id, alert_id, threshold_id, entry_date FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM config.alerts_thresholds);
DROP TABLE _stg_load;

SELECT setval('config.alerts_thresholds_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM config.alerts_thresholds),1), (SELECT count(*) FROM config.alerts_thresholds) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'alerts_thresholds'
          AND con.conname = 'alerts_thresholds_pkey') THEN
        ALTER TABLE ONLY config.alerts_thresholds
    ADD CONSTRAINT alerts_thresholds_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
