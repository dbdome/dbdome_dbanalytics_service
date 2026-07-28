-- Idempotent install for jobs.monitoring_jobs
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS jobs;

CREATE SEQUENCE IF NOT EXISTS jobs.monitoring_jobs_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS jobs.monitoring_jobs (
    row_id integer NOT NULL,
    job_name text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    entry_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);

ALTER TABLE jobs.monitoring_jobs ALTER COLUMN row_id SET DEFAULT nextval('jobs.monitoring_jobs_row_id_seq'::regclass);
ALTER SEQUENCE jobs.monitoring_jobs_row_id_seq OWNED BY jobs.monitoring_jobs.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE jobs.monitoring_jobs);
COPY _stg_load (row_id, job_name, is_active, entry_date) FROM stdin;
1	operations	t	2025-04-15 22:06:04.464096
\.
INSERT INTO jobs.monitoring_jobs (row_id, job_name, is_active, entry_date)
SELECT row_id, job_name, is_active, entry_date FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM jobs.monitoring_jobs);
DROP TABLE _stg_load;

SELECT setval('jobs.monitoring_jobs_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM jobs.monitoring_jobs),1), (SELECT count(*) FROM jobs.monitoring_jobs) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'jobs' AND c.relname = 'monitoring_jobs'
          AND con.conname = 'monitoring_jobs_pkey') THEN
        ALTER TABLE ONLY jobs.monitoring_jobs
    ADD CONSTRAINT monitoring_jobs_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
