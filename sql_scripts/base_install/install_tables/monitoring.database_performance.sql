-- Idempotent install for monitoring.database_performance
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.database_performance_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.database_performance (
    row_id integer NOT NULL,
    server character varying(50) NOT NULL,
    database_name character varying(255),
    avg_read_stall_ms integer,
    avg_write_stall_ms integer,
    avg_io_stall_ms integer,
    file_size integer,
    physical_name character varying(255),
    type_desc character varying(100),
    io_stall_read_ms integer,
    num_of_reads integer,
    io_stall_write_ms integer,
    num_of_writes integer,
    io_stalls integer,
    total_io integer,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE monitoring.database_performance ALTER COLUMN row_id SET DEFAULT nextval('monitoring.database_performance_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.database_performance_row_id_seq OWNED BY monitoring.database_performance.row_id;

SELECT setval('monitoring.database_performance_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.database_performance),1), (SELECT count(*) FROM monitoring.database_performance) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'database_performance'
          AND con.conname = 'database_performance_pkey') THEN
        ALTER TABLE ONLY monitoring.database_performance
    ADD CONSTRAINT database_performance_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
