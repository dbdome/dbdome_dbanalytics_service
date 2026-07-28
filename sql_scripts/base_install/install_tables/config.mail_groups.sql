-- Idempotent install for config.mail_groups
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.mail_groups_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.mail_groups (
    row_id integer NOT NULL,
    mail_config_id integer,
    group_name text NOT NULL,
    recipients text,
    is_active boolean DEFAULT true,
    entry_date timestamp without time zone DEFAULT now()
);

ALTER TABLE config.mail_groups ALTER COLUMN row_id SET DEFAULT nextval('config.mail_groups_row_id_seq'::regclass);
ALTER SEQUENCE config.mail_groups_row_id_seq OWNED BY config.mail_groups.row_id;

SELECT setval('config.mail_groups_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM config.mail_groups),1), (SELECT count(*) FROM config.mail_groups) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'mail_groups'
          AND con.conname = 'mail_groups_group_name_key') THEN
        ALTER TABLE ONLY config.mail_groups
    ADD CONSTRAINT mail_groups_group_name_key UNIQUE (group_name);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'mail_groups'
          AND con.conname = 'mail_groups_pkey') THEN
        ALTER TABLE ONLY config.mail_groups
    ADD CONSTRAINT mail_groups_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
