-- Idempotent install for config.sime_interface
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.sime_interface_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.sime_interface (
    row_id integer NOT NULL,
    siem_interface_name character varying(255) NOT NULL,
    siem_url text NOT NULL,
    app_key character varying(255),
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE config.sime_interface ALTER COLUMN row_id SET DEFAULT nextval('config.sime_interface_row_id_seq'::regclass);
ALTER SEQUENCE config.sime_interface_row_id_seq OWNED BY config.sime_interface.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE config.sime_interface);
COPY _stg_load (row_id, siem_interface_name, siem_url, app_key, entry_date) FROM stdin;
1	rapid 7	IP:181.214.214.239	dbdome	2025-11-23 23:17:24.261197
\.
INSERT INTO config.sime_interface (row_id, siem_interface_name, siem_url, app_key, entry_date)
SELECT row_id, siem_interface_name, siem_url, app_key, entry_date FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM config.sime_interface);
DROP TABLE _stg_load;

SELECT setval('config.sime_interface_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM config.sime_interface),1), (SELECT count(*) FROM config.sime_interface) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'sime_interface'
          AND con.conname = 'sime_interface_pkey') THEN
        ALTER TABLE ONLY config.sime_interface
    ADD CONSTRAINT sime_interface_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
