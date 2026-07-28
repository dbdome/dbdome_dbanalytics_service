-- Idempotent install for users.user_panel
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS users;

CREATE SEQUENCE IF NOT EXISTS users.user_panel_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS users.user_panel (
    user_id integer NOT NULL,
    username character varying(255) NOT NULL,
    fname character varying(255),
    lname character varying(255),
    email character varying(255),
    "position" character varying(255),
    password_hash character varying(255) NOT NULL,
    is_superuser boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    last_login timestamp without time zone,
    is_active boolean DEFAULT true,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE users.user_panel ALTER COLUMN user_id SET DEFAULT nextval('users.user_panel_user_id_seq'::regclass);
ALTER SEQUENCE users.user_panel_user_id_seq OWNED BY users.user_panel.user_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE users.user_panel);
COPY _stg_load (user_id, username, fname, lname, email, "position", password_hash, is_superuser, created_at, updated_at, last_login, is_active, entry_date) FROM stdin;
1	admin	Admin	User	admin@dbdome.com	Administrator	$2a$06$6kbSKHYHXvEjpOxq/XcIruKGWLgXU3pvFvaz4NF8r2MfU.gm6W0qG	t	2025-10-03 19:20:23.718052	2025-10-03 19:20:23.718052	\N	t	2025-10-03 19:20:23.718052
\.
INSERT INTO users.user_panel (user_id, username, fname, lname, email, "position", password_hash, is_superuser, created_at, updated_at, last_login, is_active, entry_date)
SELECT user_id, username, fname, lname, email, "position", password_hash, is_superuser, created_at, updated_at, last_login, is_active, entry_date FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM users.user_panel);
DROP TABLE _stg_load;

SELECT setval('users.user_panel_user_id_seq', GREATEST((SELECT COALESCE(max(user_id),0) FROM users.user_panel),1), (SELECT count(*) FROM users.user_panel) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'users' AND c.relname = 'user_panel'
          AND con.conname = 'user_panel_pkey') THEN
        ALTER TABLE ONLY users.user_panel
    ADD CONSTRAINT user_panel_pkey PRIMARY KEY (user_id);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'users' AND c.relname = 'user_panel'
          AND con.conname = 'user_panel_username_key') THEN
        ALTER TABLE ONLY users.user_panel
    ADD CONSTRAINT user_panel_username_key UNIQUE (username);
    END IF;
END $do$;
