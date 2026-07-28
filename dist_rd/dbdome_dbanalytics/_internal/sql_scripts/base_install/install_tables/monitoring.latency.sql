-- Idempotent install for monitoring.latency
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.latency_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.latency (
    row_id integer NOT NULL,
    server character varying(50),
    drive character varying(20),
    volume_mount_point character varying(20),
    read_latency character varying(20),
    write_latency character varying(20),
    overall_latency integer,
    avg_bytes_per_read character varying(20),
    avg_bytes_per_write character varying(20),
    avg_bytes_transfer character varying(20),
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE monitoring.latency ALTER COLUMN row_id SET DEFAULT nextval('monitoring.latency_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.latency_row_id_seq OWNED BY monitoring.latency.row_id;

SELECT setval('monitoring.latency_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.latency),1), (SELECT count(*) FROM monitoring.latency) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'latency'
          AND con.conname = 'latency_pkey') THEN
        ALTER TABLE ONLY monitoring.latency
    ADD CONSTRAINT latency_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
