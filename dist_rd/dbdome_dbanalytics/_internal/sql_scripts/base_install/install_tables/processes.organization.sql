-- Idempotent install for processes.organization
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS processes;

CREATE SEQUENCE IF NOT EXISTS processes.organization_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS processes.organization (
    row_id integer NOT NULL,
    organization_name text NOT NULL,
    api_url text NOT NULL,
    api_key text DEFAULT gen_random_uuid(),
    activity text NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE processes.organization ALTER COLUMN row_id SET DEFAULT nextval('processes.organization_row_id_seq'::regclass);
ALTER SEQUENCE processes.organization_row_id_seq OWNED BY processes.organization.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE processes.organization);
COPY _stg_load (row_id, organization_name, api_url, api_key, activity, entry_date) FROM stdin;
2	Bait Balev	https://dbexpertai.com/api/ingest	dbe_6f6sIK66_84QtacrwamkxcNhzOCRb4rmK-U94PgKUx0	store	2026-03-28 22:49:40.28979
1	dbexpertAI	https://dbexpertai.com/api/ingest	dbe_VHr3_wxOoiyBdSSlVKTdp-MMQ3I9ZbtUZMkK5QGNoxs	store_true	2026-03-14 12:06:44.273397
\.
INSERT INTO processes.organization (row_id, organization_name, api_url, api_key, activity, entry_date)
SELECT row_id, organization_name, api_url, api_key, activity, entry_date FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM processes.organization);
DROP TABLE _stg_load;

SELECT setval('processes.organization_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM processes.organization),1), (SELECT count(*) FROM processes.organization) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'processes' AND c.relname = 'organization'
          AND con.conname = 'pk_organization') THEN
        ALTER TABLE ONLY processes.organization
    ADD CONSTRAINT pk_organization PRIMARY KEY (organization_name);
    END IF;
END $do$;
