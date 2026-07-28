-- Idempotent install for log.attestations
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS log;

CREATE SEQUENCE IF NOT EXISTS log.attestations_attestation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS log.attestations (
    attestation_id bigint NOT NULL,
    period_id integer NOT NULL,
    control_id integer NOT NULL,
    control_name character varying(300) NOT NULL,
    regulation character varying(50) NOT NULL,
    attestation_status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    attested_by character varying(200),
    attested_at timestamp with time zone,
    exception_description text,
    evidence_notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE log.attestations ALTER COLUMN attestation_id SET DEFAULT nextval('log.attestations_attestation_id_seq'::regclass);
ALTER SEQUENCE log.attestations_attestation_id_seq OWNED BY log.attestations.attestation_id;

SELECT setval('log.attestations_attestation_id_seq', GREATEST((SELECT COALESCE(max(attestation_id),0) FROM log.attestations),1), (SELECT count(*) FROM log.attestations) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'log' AND c.relname = 'attestations'
          AND con.conname = 'attestations_period_id_control_id_key') THEN
        ALTER TABLE ONLY log.attestations
    ADD CONSTRAINT attestations_period_id_control_id_key UNIQUE (period_id, control_id);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'log' AND c.relname = 'attestations'
          AND con.conname = 'attestations_pkey') THEN
        ALTER TABLE ONLY log.attestations
    ADD CONSTRAINT attestations_pkey PRIMARY KEY (attestation_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_attestations_control ON log.attestations USING btree (control_id, attested_at DESC);
CREATE INDEX IF NOT EXISTS idx_attestations_period ON log.attestations USING btree (period_id, attestation_status);
