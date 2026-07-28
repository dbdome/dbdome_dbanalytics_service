-- Idempotent install for siem_config.sime_interface
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS siem_config;

CREATE SEQUENCE IF NOT EXISTS siem_config.sime_interface_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS siem_config.sime_interface (
    row_id integer NOT NULL,
    siem_vendor character varying(50) NOT NULL,
    siem_url character varying(50) NOT NULL,
    api_key character varying(50) NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE siem_config.sime_interface ALTER COLUMN row_id SET DEFAULT nextval('siem_config.sime_interface_row_id_seq'::regclass);
ALTER SEQUENCE siem_config.sime_interface_row_id_seq OWNED BY siem_config.sime_interface.row_id;

SELECT setval('siem_config.sime_interface_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM siem_config.sime_interface),1), (SELECT count(*) FROM siem_config.sime_interface) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'siem_config' AND c.relname = 'sime_interface'
          AND con.conname = 'sime_interface_pkey') THEN
        ALTER TABLE ONLY siem_config.sime_interface
    ADD CONSTRAINT sime_interface_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
