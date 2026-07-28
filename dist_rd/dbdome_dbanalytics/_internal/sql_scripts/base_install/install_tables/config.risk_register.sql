-- Idempotent install for config.risk_register
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.risk_register_risk_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.risk_register (
    risk_id integer NOT NULL,
    asset_name character varying(300) NOT NULL,
    risk_category character varying(50) DEFAULT 'other'::character varying NOT NULL,
    risk_title character varying(400) NOT NULL,
    risk_description text,
    likelihood smallint DEFAULT 1 NOT NULL,
    impact smallint DEFAULT 1 NOT NULL,
    inherent_risk_score smallint GENERATED ALWAYS AS ((likelihood * impact)) STORED,
    control_effectiveness smallint DEFAULT 0 NOT NULL,
    residual_risk_score numeric(5,2) GENERATED ALWAYS AS ((((likelihood * impact))::numeric * (1.0 - ((control_effectiveness)::numeric / 100.0)))) STORED,
    treatment_strategy character varying(20) DEFAULT 'MITIGATE'::character varying NOT NULL,
    risk_owner character varying(200),
    treatment_notes text,
    regulation text[] DEFAULT '{}'::text[] NOT NULL,
    review_date date,
    status character varying(20) DEFAULT 'OPEN'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT risk_register_control_effectiveness_check CHECK (((control_effectiveness >= 0) AND (control_effectiveness <= 100))),
    CONSTRAINT risk_register_impact_check CHECK (((impact >= 1) AND (impact <= 5))),
    CONSTRAINT risk_register_likelihood_check CHECK (((likelihood >= 1) AND (likelihood <= 5)))
);

ALTER TABLE config.risk_register ALTER COLUMN risk_id SET DEFAULT nextval('config.risk_register_risk_id_seq'::regclass);
ALTER SEQUENCE config.risk_register_risk_id_seq OWNED BY config.risk_register.risk_id;

SELECT setval('config.risk_register_risk_id_seq', GREATEST((SELECT COALESCE(max(risk_id),0) FROM config.risk_register),1), (SELECT count(*) FROM config.risk_register) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'risk_register'
          AND con.conname = 'risk_register_pkey') THEN
        ALTER TABLE ONLY config.risk_register
    ADD CONSTRAINT risk_register_pkey PRIMARY KEY (risk_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_risk_register_asset ON config.risk_register USING btree (asset_name);
CREATE INDEX IF NOT EXISTS idx_risk_register_status ON config.risk_register USING btree (status, inherent_risk_score DESC);
