-- Idempotent install for monitoring.ad_hoc_cpu_consuming_queries
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.ad_hoc_cpu_consuming_queries_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.ad_hoc_cpu_consuming_queries (
    row_id integer NOT NULL,
    server character varying(50) NOT NULL,
    query text,
    execution_count integer,
    total_logical_reads bigint,
    last_logical_reads bigint,
    total_logical_writes integer,
    last_logical_writes bigint,
    total_worker_time bigint,
    last_worker_time bigint,
    total_elapsed_time_in_s bigint,
    last_elapsed_time_in_s bigint,
    last_execution_time timestamp without time zone,
    entry_date timestamp without time zone DEFAULT now()
);

ALTER TABLE monitoring.ad_hoc_cpu_consuming_queries ALTER COLUMN row_id SET DEFAULT nextval('monitoring.ad_hoc_cpu_consuming_queries_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.ad_hoc_cpu_consuming_queries_row_id_seq OWNED BY monitoring.ad_hoc_cpu_consuming_queries.row_id;

SELECT setval('monitoring.ad_hoc_cpu_consuming_queries_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.ad_hoc_cpu_consuming_queries),1), (SELECT count(*) FROM monitoring.ad_hoc_cpu_consuming_queries) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'ad_hoc_cpu_consuming_queries'
          AND con.conname = 'ad_hoc_cpu_consuming_queries_pkey') THEN
        ALTER TABLE ONLY monitoring.ad_hoc_cpu_consuming_queries
    ADD CONSTRAINT ad_hoc_cpu_consuming_queries_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
