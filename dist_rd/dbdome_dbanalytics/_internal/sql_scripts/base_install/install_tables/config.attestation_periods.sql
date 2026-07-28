-- Idempotent install for config.attestation_periods
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.attestation_periods_period_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.attestation_periods (
    period_id integer NOT NULL,
    period_name character varying(100) NOT NULL,
    period_start date NOT NULL,
    period_end date NOT NULL,
    due_date date NOT NULL,
    regulation character varying(50) NOT NULL,
    status character varying(20) DEFAULT 'OPEN'::character varying NOT NULL,
    closed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE config.attestation_periods ALTER COLUMN period_id SET DEFAULT nextval('config.attestation_periods_period_id_seq'::regclass);
ALTER SEQUENCE config.attestation_periods_period_id_seq OWNED BY config.attestation_periods.period_id;

SELECT setval('config.attestation_periods_period_id_seq', GREATEST((SELECT COALESCE(max(period_id),0) FROM config.attestation_periods),1), (SELECT count(*) FROM config.attestation_periods) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'attestation_periods'
          AND con.conname = 'attestation_periods_pkey') THEN
        ALTER TABLE ONLY config.attestation_periods
    ADD CONSTRAINT attestation_periods_pkey PRIMARY KEY (period_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_attestation_periods_regulation ON config.attestation_periods USING btree (regulation, period_end DESC);
