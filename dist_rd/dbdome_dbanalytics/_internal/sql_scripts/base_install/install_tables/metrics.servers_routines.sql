-- Idempotent install for metrics.servers_routines
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS metrics;

CREATE SEQUENCE IF NOT EXISTS metrics.servers_routines_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS metrics.servers_routines (
    row_id integer NOT NULL,
    server_id integer NOT NULL,
    routine_id integer NOT NULL,
    scheduler_id integer DEFAULT '-1'::integer NOT NULL,
    entry_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    is_active boolean DEFAULT true
);

ALTER TABLE metrics.servers_routines ALTER COLUMN row_id SET DEFAULT nextval('metrics.servers_routines_row_id_seq'::regclass);
ALTER SEQUENCE metrics.servers_routines_row_id_seq OWNED BY metrics.servers_routines.row_id;

SELECT setval('metrics.servers_routines_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM metrics.servers_routines),1), (SELECT count(*) FROM metrics.servers_routines) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'metrics' AND c.relname = 'servers_routines'
          AND con.conname = 'servers_routines_pkey') THEN
        ALTER TABLE ONLY metrics.servers_routines
    ADD CONSTRAINT servers_routines_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
