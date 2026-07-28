-- Idempotent install for rootcause.domains
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS rootcause;

CREATE TABLE IF NOT EXISTS rootcause.domains (
    code character varying(10) NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    is_enabled boolean DEFAULT true NOT NULL,
    category_id character(4)
);

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE rootcause.domains);
COPY _stg_load (code, name, description, created_at, is_enabled, category_id) FROM stdin;
SEC	Security	\N	2026-02-23 20:18:30.373914	t	d002
HLTH	Health	\N	2026-02-23 20:18:30.373913	t	d001
PERF	Performance	\N	2026-02-23 20:18:30.373907	t	d003
\.
INSERT INTO rootcause.domains (code, name, description, created_at, is_enabled, category_id)
SELECT code, name, description, created_at, is_enabled, category_id FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM rootcause.domains);
DROP TABLE _stg_load;


DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'rootcause' AND c.relname = 'domains'
          AND con.conname = 'domains_pkey') THEN
        ALTER TABLE ONLY rootcause.domains
    ADD CONSTRAINT domains_pkey PRIMARY KEY (code);
    END IF;
END $do$;
