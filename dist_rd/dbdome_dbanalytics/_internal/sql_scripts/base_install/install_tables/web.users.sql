-- Idempotent install for web.users
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS web;

CREATE SEQUENCE IF NOT EXISTS web.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS web.users (
    id integer NOT NULL,
    email character varying(255) NOT NULL,
    full_name character varying(255) DEFAULT ''::character varying NOT NULL,
    password_hash character varying(255) NOT NULL,
    role character varying(20) DEFAULT 'viewer'::character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE web.users ALTER COLUMN id SET DEFAULT nextval('web.users_id_seq'::regclass);
ALTER SEQUENCE web.users_id_seq OWNED BY web.users.id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE web.users);
COPY _stg_load (id, email, full_name, password_hash, role, is_active, created_at, updated_at) FROM stdin;
1	yoram.dan@dbexpert.ai	Yoram Dan	$2b$12$6TvgUj.mwbtvnE/NK3VgSOs27xT8Yeuqrgodd5cpznNSe6G.7x1mK	admin	t	2026-04-13 21:19:40.947306+03	2026-04-13 21:19:40.947306+03
\.
INSERT INTO web.users (id, email, full_name, password_hash, role, is_active, created_at, updated_at)
SELECT id, email, full_name, password_hash, role, is_active, created_at, updated_at FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM web.users);
DROP TABLE _stg_load;

SELECT setval('web.users_id_seq', GREATEST((SELECT COALESCE(max(id),0) FROM web.users),1), (SELECT count(*) FROM web.users) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'web' AND c.relname = 'users'
          AND con.conname = 'users_email_key') THEN
        ALTER TABLE ONLY web.users
    ADD CONSTRAINT users_email_key UNIQUE (email);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'web' AND c.relname = 'users'
          AND con.conname = 'users_pkey') THEN
        ALTER TABLE ONLY web.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);
    END IF;
END $do$;
