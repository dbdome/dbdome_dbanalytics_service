-- Idempotent install for config.siem
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.siem_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.siem (
    id integer NOT NULL,
    service_type text NOT NULL,
    service_name text NOT NULL,
    service_ip text NOT NULL,
    service_port integer,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE config.siem ALTER COLUMN id SET DEFAULT nextval('config.siem_id_seq'::regclass);
ALTER SEQUENCE config.siem_id_seq OWNED BY config.siem.id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE config.siem);
COPY _stg_load (id, service_type, service_name, service_ip, service_port, updated_at) FROM stdin;
1	rapid_7	ip	172.16.120.30	1025	2026-03-04 06:50:47.891325
\.
INSERT INTO config.siem (id, service_type, service_name, service_ip, service_port, updated_at)
SELECT id, service_type, service_name, service_ip, service_port, updated_at FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM config.siem);
DROP TABLE _stg_load;

SELECT setval('config.siem_id_seq', GREATEST((SELECT COALESCE(max(id),0) FROM config.siem),1), (SELECT count(*) FROM config.siem) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'siem'
          AND con.conname = 'siem_pkey') THEN
        ALTER TABLE ONLY config.siem
    ADD CONSTRAINT siem_pkey PRIMARY KEY (id);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'siem'
          AND con.conname = 'siem_service_type_service_name_key') THEN
        ALTER TABLE ONLY config.siem
    ADD CONSTRAINT siem_service_type_service_name_key UNIQUE (service_type, service_name);
    END IF;
END $do$;
