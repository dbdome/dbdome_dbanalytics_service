-- Idempotent install for jobs.jobs
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS jobs;

CREATE SEQUENCE IF NOT EXISTS jobs.jobs_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS jobs.jobs (
    row_id integer NOT NULL,
    schedule_type integer,
    occurance text DEFAULT 'daily'::text NOT NULL,
    occurs_at time without time zone DEFAULT '00:00:00'::time without time zone,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE jobs.jobs ALTER COLUMN row_id SET DEFAULT nextval('jobs.jobs_row_id_seq'::regclass);
ALTER SEQUENCE jobs.jobs_row_id_seq OWNED BY jobs.jobs.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE jobs.jobs);
COPY _stg_load (row_id, schedule_type, occurance, occurs_at, entry_date) FROM stdin;
1	1	daily	00:00:00	2026-01-03 20:03:27.750901
2	1	minute	00:00:00	2026-01-03 20:04:06.306802
3	2	once	00:00:00	2026-01-03 20:04:40.201269
4	1	weekly	06:00:00	2026-04-15 06:20:03.10085
\.
INSERT INTO jobs.jobs (row_id, schedule_type, occurance, occurs_at, entry_date)
SELECT row_id, schedule_type, occurance, occurs_at, entry_date FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM jobs.jobs);
DROP TABLE _stg_load;

SELECT setval('jobs.jobs_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM jobs.jobs),1), (SELECT count(*) FROM jobs.jobs) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'jobs' AND c.relname = 'jobs'
          AND con.conname = 'jobs_pkey') THEN
        ALTER TABLE ONLY jobs.jobs
    ADD CONSTRAINT jobs_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
