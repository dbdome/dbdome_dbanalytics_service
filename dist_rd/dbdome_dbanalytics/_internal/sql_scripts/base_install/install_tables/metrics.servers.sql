-- Idempotent install for metrics.servers
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS metrics;

CREATE SEQUENCE IF NOT EXISTS metrics.servers_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS metrics.servers (
    row_id integer NOT NULL,
    server text,
    servername text,
    database text DEFAULT 'master'::text,
    username text,
    password text,
    driver text,
    is_active boolean DEFAULT false,
    port integer DEFAULT 1433,
    dsn character varying(50),
    db_vendor text,
    db_version text,
    auth_type text,
    service_name text,
    server_id uuid DEFAULT gen_random_uuid()
);

ALTER TABLE metrics.servers ALTER COLUMN row_id SET DEFAULT nextval('metrics.servers_row_id_seq'::regclass);
ALTER SEQUENCE metrics.servers_row_id_seq OWNED BY metrics.servers.row_id;

SELECT setval('metrics.servers_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM metrics.servers),1), (SELECT count(*) FROM metrics.servers) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'metrics' AND c.relname = 'servers'
          AND con.conname = 'servers_pkey') THEN
        ALTER TABLE ONLY metrics.servers
    ADD CONSTRAINT servers_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
