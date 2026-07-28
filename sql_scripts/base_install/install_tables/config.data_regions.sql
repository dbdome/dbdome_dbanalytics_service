-- Idempotent install for config.data_regions
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.data_regions_region_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.data_regions (
    region_id integer NOT NULL,
    server_name character varying(200) NOT NULL,
    country_code character varying(10) NOT NULL,
    country_name character varying(200) NOT NULL,
    data_residency_zone character varying(50) DEFAULT 'OTHER'::character varying NOT NULL,
    is_adequate boolean DEFAULT false NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE config.data_regions ALTER COLUMN region_id SET DEFAULT nextval('config.data_regions_region_id_seq'::regclass);
ALTER SEQUENCE config.data_regions_region_id_seq OWNED BY config.data_regions.region_id;

SELECT setval('config.data_regions_region_id_seq', GREATEST((SELECT COALESCE(max(region_id),0) FROM config.data_regions),1), (SELECT count(*) FROM config.data_regions) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'data_regions'
          AND con.conname = 'data_regions_pkey') THEN
        ALTER TABLE ONLY config.data_regions
    ADD CONSTRAINT data_regions_pkey PRIMARY KEY (region_id);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'data_regions'
          AND con.conname = 'data_regions_server_name_key') THEN
        ALTER TABLE ONLY config.data_regions
    ADD CONSTRAINT data_regions_server_name_key UNIQUE (server_name);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_data_regions_zone ON config.data_regions USING btree (data_residency_zone, is_adequate);
