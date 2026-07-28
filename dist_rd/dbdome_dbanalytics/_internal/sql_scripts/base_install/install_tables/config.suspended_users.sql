-- Idempotent install for config.suspended_users
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.suspended_users_suspension_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.suspended_users (
    suspension_id integer NOT NULL,
    server_name character varying(200) NOT NULL,
    login_name character varying(200) NOT NULL,
    reason text,
    suspended_by character varying(100) DEFAULT 'threat_response'::character varying NOT NULL,
    suspended_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone,
    is_active boolean DEFAULT true NOT NULL
);

ALTER TABLE config.suspended_users ALTER COLUMN suspension_id SET DEFAULT nextval('config.suspended_users_suspension_id_seq'::regclass);
ALTER SEQUENCE config.suspended_users_suspension_id_seq OWNED BY config.suspended_users.suspension_id;

SELECT setval('config.suspended_users_suspension_id_seq', GREATEST((SELECT COALESCE(max(suspension_id),0) FROM config.suspended_users),1), (SELECT count(*) FROM config.suspended_users) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'suspended_users'
          AND con.conname = 'suspended_users_pkey') THEN
        ALTER TABLE ONLY config.suspended_users
    ADD CONSTRAINT suspended_users_pkey PRIMARY KEY (suspension_id);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'suspended_users'
          AND con.conname = 'suspended_users_server_name_login_name_key') THEN
        ALTER TABLE ONLY config.suspended_users
    ADD CONSTRAINT suspended_users_server_name_login_name_key UNIQUE (server_name, login_name);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_suspended_users_active ON config.suspended_users USING btree (server_name, login_name) WHERE (is_active = true);
