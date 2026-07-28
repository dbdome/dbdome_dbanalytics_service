-- Idempotent install for rootcause.database_types
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS rootcause;

CREATE TABLE IF NOT EXISTS rootcause.database_types (
    code character varying(10) NOT NULL,
    slug character varying(50) NOT NULL,
    name character varying(100) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE rootcause.database_types);
COPY _stg_load (code, slug, name, created_at) FROM stdin;
SQL	relational	Relational	2026-02-23 20:18:30.376425
DOC	document	Document	2026-02-23 20:18:30.376433
KV	keyvalue	Key-Value	2026-02-23 20:18:30.376435
VEC	vector	Vector	2026-02-23 20:18:30.376436
\.
INSERT INTO rootcause.database_types (code, slug, name, created_at)
SELECT code, slug, name, created_at FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM rootcause.database_types);
DROP TABLE _stg_load;


DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'rootcause' AND c.relname = 'database_types'
          AND con.conname = 'database_types_pkey') THEN
        ALTER TABLE ONLY rootcause.database_types
    ADD CONSTRAINT database_types_pkey PRIMARY KEY (code);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'rootcause' AND c.relname = 'database_types'
          AND con.conname = 'database_types_slug_key') THEN
        ALTER TABLE ONLY rootcause.database_types
    ADD CONSTRAINT database_types_slug_key UNIQUE (slug);
    END IF;
END $do$;
