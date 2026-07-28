-- Idempotent install for public.vendors
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS public;

CREATE SEQUENCE IF NOT EXISTS public.vendors_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS public.vendors (
    id smallint NOT NULL,
    slug character varying(20) NOT NULL,
    name character varying(50) NOT NULL,
    database_type_id smallint NOT NULL
);

ALTER TABLE public.vendors ALTER COLUMN id SET DEFAULT nextval('public.vendors_id_seq'::regclass);
ALTER SEQUENCE public.vendors_id_seq OWNED BY public.vendors.id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE public.vendors);
COPY _stg_load (id, slug, name, database_type_id) FROM stdin;
1	postgresql	PostgreSQL	1
2	mysql	MySQL	1
3	mariadb	MariaDB	1
4	oracle	Oracle	1
5	sqlserver	SQL Server	1
6	vertica	Vertica	1
7	mongodb	MongoDB	2
8	couchbase	Couchbase	2
9	redis	Redis	3
10	chromadb	ChromaDB	4
11	milvus	Milvus	4
12	qdrant	Qdrant	4
13	weaviate	Weaviate	4
14	neon	Neon	1
15	supabase	Supabase	1
\.
INSERT INTO public.vendors (id, slug, name, database_type_id)
SELECT id, slug, name, database_type_id FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM public.vendors);
DROP TABLE _stg_load;

SELECT setval('public.vendors_id_seq', GREATEST((SELECT COALESCE(max(id),0) FROM public.vendors),1), (SELECT count(*) FROM public.vendors) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'vendors'
          AND con.conname = 'vendors_pkey') THEN
        ALTER TABLE ONLY public.vendors
    ADD CONSTRAINT vendors_pkey PRIMARY KEY (id);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'vendors'
          AND con.conname = 'vendors_slug_key') THEN
        ALTER TABLE ONLY public.vendors
    ADD CONSTRAINT vendors_slug_key UNIQUE (slug);
    END IF;
END $do$;
