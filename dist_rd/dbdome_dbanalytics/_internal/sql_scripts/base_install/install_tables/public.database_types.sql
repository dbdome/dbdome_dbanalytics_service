-- Idempotent install for public.database_types
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS public;

CREATE SEQUENCE IF NOT EXISTS public.database_types_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS public.database_types (
    id smallint NOT NULL,
    code character varying(10) NOT NULL,
    slug character varying(20) NOT NULL,
    name character varying(50) NOT NULL
);

ALTER TABLE public.database_types ALTER COLUMN id SET DEFAULT nextval('public.database_types_id_seq'::regclass);
ALTER SEQUENCE public.database_types_id_seq OWNED BY public.database_types.id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE public.database_types);
COPY _stg_load (id, code, slug, name) FROM stdin;
1	SQL	relational	Relational
2	DOC	document	Document
3	KV	keyvalue	Key-Value
4	VEC	vector	Vector
\.
INSERT INTO public.database_types (id, code, slug, name)
SELECT id, code, slug, name FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM public.database_types);
DROP TABLE _stg_load;

SELECT setval('public.database_types_id_seq', GREATEST((SELECT COALESCE(max(id),0) FROM public.database_types),1), (SELECT count(*) FROM public.database_types) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'database_types'
          AND con.conname = 'database_types_code_key') THEN
        ALTER TABLE ONLY public.database_types
    ADD CONSTRAINT database_types_code_key UNIQUE (code);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'database_types'
          AND con.conname = 'database_types_name_key') THEN
        ALTER TABLE ONLY public.database_types
    ADD CONSTRAINT database_types_name_key UNIQUE (name);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'database_types'
          AND con.conname = 'database_types_pkey') THEN
        ALTER TABLE ONLY public.database_types
    ADD CONSTRAINT database_types_pkey PRIMARY KEY (id);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'database_types'
          AND con.conname = 'database_types_slug_key') THEN
        ALTER TABLE ONLY public.database_types
    ADD CONSTRAINT database_types_slug_key UNIQUE (slug);
    END IF;
END $do$;
