-- Idempotent install for config.alerts_reports
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.alerts_reports_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.alerts_reports (
    row_id integer NOT NULL,
    report_id integer NOT NULL,
    alert_id integer NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE config.alerts_reports ALTER COLUMN row_id SET DEFAULT nextval('config.alerts_reports_row_id_seq'::regclass);
ALTER SEQUENCE config.alerts_reports_row_id_seq OWNED BY config.alerts_reports.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE config.alerts_reports);
COPY _stg_load (row_id, report_id, alert_id, entry_date) FROM stdin;
1	2	1	2026-01-03 20:12:16.391116
2	19	336	2026-02-14 22:16:02.520569
\.
INSERT INTO config.alerts_reports (row_id, report_id, alert_id, entry_date)
SELECT row_id, report_id, alert_id, entry_date FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM config.alerts_reports);
DROP TABLE _stg_load;

SELECT setval('config.alerts_reports_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM config.alerts_reports),1), (SELECT count(*) FROM config.alerts_reports) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'alerts_reports'
          AND con.conname = 'alerts_reports_pkey') THEN
        ALTER TABLE ONLY config.alerts_reports
    ADD CONSTRAINT alerts_reports_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
