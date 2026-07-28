-- Idempotent install for monitoring.os_memory
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.os_memory_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.os_memory (
    row_id integer NOT NULL,
    server character varying(50),
    total_os_memory_gb integer,
    available_os_memory_gb integer,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE monitoring.os_memory ALTER COLUMN row_id SET DEFAULT nextval('monitoring.os_memory_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.os_memory_row_id_seq OWNED BY monitoring.os_memory.row_id;

SELECT setval('monitoring.os_memory_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.os_memory),1), (SELECT count(*) FROM monitoring.os_memory) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'os_memory'
          AND con.conname = 'os_memory_pkey') THEN
        ALTER TABLE ONLY monitoring.os_memory
    ADD CONSTRAINT os_memory_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
