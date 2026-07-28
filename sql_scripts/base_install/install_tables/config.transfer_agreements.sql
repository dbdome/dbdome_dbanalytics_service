-- Idempotent install for config.transfer_agreements
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.transfer_agreements_agreement_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.transfer_agreements (
    agreement_id integer NOT NULL,
    source_server character varying(200) NOT NULL,
    destination_server character varying(200) NOT NULL,
    agreement_type character varying(50) NOT NULL,
    valid_from date DEFAULT CURRENT_DATE NOT NULL,
    valid_until date,
    document_reference character varying(400),
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE config.transfer_agreements ALTER COLUMN agreement_id SET DEFAULT nextval('config.transfer_agreements_agreement_id_seq'::regclass);
ALTER SEQUENCE config.transfer_agreements_agreement_id_seq OWNED BY config.transfer_agreements.agreement_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE config.transfer_agreements);
COPY _stg_load (agreement_id, source_server, destination_server, agreement_type, valid_from, valid_until, document_reference, notes, created_at) FROM stdin;
1	__placeholder__	__placeholder__	NONE	2026-05-10	\N	\N	Seed row — replace with real server pairs	2026-05-10 21:29:51.995195+03
\.
INSERT INTO config.transfer_agreements (agreement_id, source_server, destination_server, agreement_type, valid_from, valid_until, document_reference, notes, created_at)
SELECT agreement_id, source_server, destination_server, agreement_type, valid_from, valid_until, document_reference, notes, created_at FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM config.transfer_agreements);
DROP TABLE _stg_load;

SELECT setval('config.transfer_agreements_agreement_id_seq', GREATEST((SELECT COALESCE(max(agreement_id),0) FROM config.transfer_agreements),1), (SELECT count(*) FROM config.transfer_agreements) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'transfer_agreements'
          AND con.conname = 'transfer_agreements_pkey') THEN
        ALTER TABLE ONLY config.transfer_agreements
    ADD CONSTRAINT transfer_agreements_pkey PRIMARY KEY (agreement_id);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'transfer_agreements'
          AND con.conname = 'transfer_agreements_source_server_destination_server_key') THEN
        ALTER TABLE ONLY config.transfer_agreements
    ADD CONSTRAINT transfer_agreements_source_server_destination_server_key UNIQUE (source_server, destination_server);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_transfer_agreements_pair ON config.transfer_agreements USING btree (source_server, destination_server);
