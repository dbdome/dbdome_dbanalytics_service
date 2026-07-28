-- Idempotent install for public.domains
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS public;

CREATE SEQUENCE IF NOT EXISTS public.domains_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS public.domains (
    id smallint NOT NULL,
    code character varying(4) NOT NULL,
    name character varying(50) NOT NULL
);

ALTER TABLE public.domains ALTER COLUMN id SET DEFAULT nextval('public.domains_id_seq'::regclass);
ALTER SEQUENCE public.domains_id_seq OWNED BY public.domains.id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE public.domains);
COPY _stg_load (id, code, name) FROM stdin;
1	PERF	Performance
2	HLTH	Health
3	SEC	Security
\.
INSERT INTO public.domains (id, code, name)
SELECT id, code, name FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM public.domains);
DROP TABLE _stg_load;

SELECT setval('public.domains_id_seq', GREATEST((SELECT COALESCE(max(id),0) FROM public.domains),1), (SELECT count(*) FROM public.domains) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'domains'
          AND con.conname = 'domains_code_key') THEN
        ALTER TABLE ONLY public.domains
    ADD CONSTRAINT domains_code_key UNIQUE (code);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'domains'
          AND con.conname = 'domains_name_key') THEN
        ALTER TABLE ONLY public.domains
    ADD CONSTRAINT domains_name_key UNIQUE (name);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'domains'
          AND con.conname = 'domains_pkey') THEN
        ALTER TABLE ONLY public.domains
    ADD CONSTRAINT domains_pkey PRIMARY KEY (id);
    END IF;
END $do$;
