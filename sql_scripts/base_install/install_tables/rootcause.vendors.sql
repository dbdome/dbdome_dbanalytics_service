-- Idempotent install for rootcause.vendors
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS rootcause;

CREATE TABLE IF NOT EXISTS rootcause.vendors (
    slug character varying(50) NOT NULL,
    name character varying(100) NOT NULL,
    database_type_code character varying(10) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE rootcause.vendors);
COPY _stg_load (slug, name, database_type_code, created_at) FROM stdin;
postgresql	PostgreSQL	SQL	2026-02-23 20:18:30.386075
mysql	MySQL	SQL	2026-02-23 20:18:30.386082
mariadb	MariaDB	SQL	2026-02-23 20:18:30.386083
oracle	Oracle	SQL	2026-02-23 20:18:30.386084
sqlserver	SQL Server	SQL	2026-02-23 20:18:30.386084
vertica	Vertica	SQL	2026-02-23 20:18:30.386085
mongodb	MongoDB	DOC	2026-02-23 20:18:30.386086
couchbase	Couchbase	DOC	2026-02-23 20:18:30.386086
redis	Redis	KV	2026-02-23 20:18:30.386087
chromadb	ChromaDB	VEC	2026-02-23 20:18:30.386088
milvus	Milvus	VEC	2026-02-23 20:18:30.386088
qdrant	Qdrant	VEC	2026-02-23 20:18:30.386089
weaviate	Weaviate	VEC	2026-02-23 20:18:30.386089
neon	Neon	SQL	2026-02-23 20:18:30.38609
supabase	Supabase	SQL	2026-02-23 20:18:30.386091
MSSQL	MSSQL	SQL	2026-03-08 17:41:34.109028
informix	IBM Informix	SQL	2026-04-10 05:38:44.839449
dbanalytics	DBDOME dbanalytics catalog (self)	SQL	2026-05-03 12:25:15.685849
\.
INSERT INTO rootcause.vendors (slug, name, database_type_code, created_at)
SELECT slug, name, database_type_code, created_at FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM rootcause.vendors);
DROP TABLE _stg_load;


DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'rootcause' AND c.relname = 'vendors'
          AND con.conname = 'vendors_pkey') THEN
        ALTER TABLE ONLY rootcause.vendors
    ADD CONSTRAINT vendors_pkey PRIMARY KEY (slug);
    END IF;
END $do$;
