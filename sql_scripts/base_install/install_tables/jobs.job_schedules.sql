-- Idempotent install for jobs.job_schedules
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS jobs;

CREATE SEQUENCE IF NOT EXISTS jobs.job_schedules_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS jobs.job_schedules (
    row_id integer NOT NULL,
    report_id integer NOT NULL,
    schedule_id integer NOT NULL,
    last_run timestamp without time zone,
    entry_date timestamp without time zone DEFAULT now() NOT NULL,
    next_run timestamp without time zone
);

ALTER TABLE jobs.job_schedules ALTER COLUMN row_id SET DEFAULT nextval('jobs.job_schedules_row_id_seq'::regclass);
ALTER SEQUENCE jobs.job_schedules_row_id_seq OWNED BY jobs.job_schedules.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE jobs.job_schedules);
COPY _stg_load (row_id, report_id, schedule_id, last_run, entry_date, next_run) FROM stdin;
3	2	1	2026-01-14 20:00:27.687444	2026-01-03 23:22:43.288453	2026-01-03 23:22:43.288453
5	2	1	2026-01-14 20:00:27.687444	2026-01-04 00:41:32.994615	2026-01-04 00:41:32.994615
7	2	1	2026-01-14 20:00:27.687444	2026-01-04 01:09:20.444522	2026-01-05 01:09:20.444522
1	1	1	2026-01-14 20:00:49.513877	2026-01-03 21:39:45.597909	2026-01-03 21:39:45.597909
2	1	1	2026-01-14 20:00:49.513877	2026-01-03 21:48:42.322883	2026-01-03 21:48:42.322883
4	1	1	2026-01-14 20:00:49.513877	2026-01-04 00:31:22.889717	2026-01-03 00:31:22.889717
6	1	1	2026-01-14 20:00:49.513877	2026-01-04 00:46:12.094122	2026-01-04 00:46:12.094122
8	1	1	2026-01-14 20:00:49.513877	2026-01-06 11:52:03.793713	2026-01-07 11:52:03.793713
11	18	4	\N	2026-04-15 06:20:03.10085	2026-04-20 06:00:00
9	2	1	2026-04-15 06:39:28.190597	2026-01-14 20:00:27.687444	2026-01-15 20:00:27.687444
10	1	1	2026-04-15 06:39:28.190597	2026-01-14 20:00:49.513877	2026-01-15 20:00:49.513877
13	19	1	2026-04-15 06:39:28.190597	2026-04-15 06:39:28.190597	2026-04-16 06:39:28.190597
\.
INSERT INTO jobs.job_schedules (row_id, report_id, schedule_id, last_run, entry_date, next_run)
SELECT row_id, report_id, schedule_id, last_run, entry_date, next_run FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM jobs.job_schedules);
DROP TABLE _stg_load;

SELECT setval('jobs.job_schedules_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM jobs.job_schedules),1), (SELECT count(*) FROM jobs.job_schedules) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'jobs' AND c.relname = 'job_schedules'
          AND con.conname = 'job_schedules_pkey') THEN
        ALTER TABLE ONLY jobs.job_schedules
    ADD CONSTRAINT job_schedules_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
