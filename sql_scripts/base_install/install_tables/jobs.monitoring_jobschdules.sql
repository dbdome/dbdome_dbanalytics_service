-- Idempotent install for jobs.monitoring_jobschdules
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS jobs;

CREATE SEQUENCE IF NOT EXISTS jobs.monitoring_jobschdules_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS jobs.monitoring_jobschdules (
    row_id integer NOT NULL,
    job_id integer NOT NULL,
    duration_secs integer DEFAULT 60 NOT NULL,
    next_run_time timestamp without time zone NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE jobs.monitoring_jobschdules ALTER COLUMN row_id SET DEFAULT nextval('jobs.monitoring_jobschdules_row_id_seq'::regclass);
ALTER SEQUENCE jobs.monitoring_jobschdules_row_id_seq OWNED BY jobs.monitoring_jobschdules.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE jobs.monitoring_jobschdules);
COPY _stg_load (row_id, job_id, duration_secs, next_run_time, entry_date) FROM stdin;
1	1	10	2026-06-02 03:55:28.359735	2025-06-24 12:26:22.586945
\.
INSERT INTO jobs.monitoring_jobschdules (row_id, job_id, duration_secs, next_run_time, entry_date)
SELECT row_id, job_id, duration_secs, next_run_time, entry_date FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM jobs.monitoring_jobschdules);
DROP TABLE _stg_load;

SELECT setval('jobs.monitoring_jobschdules_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM jobs.monitoring_jobschdules),1), (SELECT count(*) FROM jobs.monitoring_jobschdules) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'jobs' AND c.relname = 'monitoring_jobschdules'
          AND con.conname = 'monitoring_jobschdules_pkey') THEN
        ALTER TABLE ONLY jobs.monitoring_jobschdules
    ADD CONSTRAINT monitoring_jobschdules_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
