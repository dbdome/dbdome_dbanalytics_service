-- Idempotent install for jobs.monitoring_job_history
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS jobs;

CREATE SEQUENCE IF NOT EXISTS jobs.monitoring_job_history_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS jobs.monitoring_job_history (
    row_id integer NOT NULL,
    job_id integer NOT NULL,
    run_time timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE jobs.monitoring_job_history ALTER COLUMN row_id SET DEFAULT nextval('jobs.monitoring_job_history_row_id_seq'::regclass);
ALTER SEQUENCE jobs.monitoring_job_history_row_id_seq OWNED BY jobs.monitoring_job_history.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE jobs.monitoring_job_history);
COPY _stg_load (row_id, job_id, run_time) FROM stdin;
1	1	2025-04-15 23:11:44.503828
\.
INSERT INTO jobs.monitoring_job_history (row_id, job_id, run_time)
SELECT row_id, job_id, run_time FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM jobs.monitoring_job_history);
DROP TABLE _stg_load;

SELECT setval('jobs.monitoring_job_history_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM jobs.monitoring_job_history),1), (SELECT count(*) FROM jobs.monitoring_job_history) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'jobs' AND c.relname = 'monitoring_job_history'
          AND con.conname = 'monitoring_job_history_pkey') THEN
        ALTER TABLE ONLY jobs.monitoring_job_history
    ADD CONSTRAINT monitoring_job_history_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
