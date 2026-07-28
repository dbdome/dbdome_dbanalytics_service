-- Idempotent install for config.action_types
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.action_types_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.action_types (
    row_id integer NOT NULL,
    action_name character varying(50) NOT NULL,
    action_description character varying(255) NOT NULL,
    server character varying(50) NOT NULL,
    is_active boolean DEFAULT false NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE config.action_types ALTER COLUMN row_id SET DEFAULT nextval('config.action_types_row_id_seq'::regclass);
ALTER SEQUENCE config.action_types_row_id_seq OWNED BY config.action_types.row_id;

SELECT setval('config.action_types_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM config.action_types),1), (SELECT count(*) FROM config.action_types) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'action_types'
          AND con.conname = 'action_types_pkey') THEN
        ALTER TABLE ONLY config.action_types
    ADD CONSTRAINT action_types_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
