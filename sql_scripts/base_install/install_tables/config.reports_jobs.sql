-- Idempotent install for config.reports_jobs
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.reports_jobs_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.reports_jobs (
    row_id integer NOT NULL,
    report_id integer NOT NULL,
    job_id integer NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE config.reports_jobs ALTER COLUMN row_id SET DEFAULT nextval('config.reports_jobs_row_id_seq'::regclass);
ALTER SEQUENCE config.reports_jobs_row_id_seq OWNED BY config.reports_jobs.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE config.reports_jobs);
COPY _stg_load (row_id, report_id, job_id, entry_date) FROM stdin;
1	1	1	2026-01-03 20:06:42.573278
2	2	1	2026-01-03 20:06:54.792605
3	19	1	2026-02-12 06:18:16.658353
4	18	4	2026-04-15 06:20:03.10085
\.
INSERT INTO config.reports_jobs (row_id, report_id, job_id, entry_date)
SELECT row_id, report_id, job_id, entry_date FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM config.reports_jobs);
DROP TABLE _stg_load;

SELECT setval('config.reports_jobs_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM config.reports_jobs),1), (SELECT count(*) FROM config.reports_jobs) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'reports_jobs'
          AND con.conname = 'reports_jobs_pkey') THEN
        ALTER TABLE ONLY config.reports_jobs
    ADD CONSTRAINT reports_jobs_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
