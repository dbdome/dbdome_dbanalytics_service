-- Idempotent install for config.regulation_profiles
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.regulation_profiles_profile_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.regulation_profiles (
    profile_id integer NOT NULL,
    regulation character varying(50) NOT NULL,
    description text,
    policy_ids integer[] DEFAULT '{}'::integer[] NOT NULL
);

ALTER TABLE config.regulation_profiles ALTER COLUMN profile_id SET DEFAULT nextval('config.regulation_profiles_profile_id_seq'::regclass);
ALTER SEQUENCE config.regulation_profiles_profile_id_seq OWNED BY config.regulation_profiles.profile_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE config.regulation_profiles);
COPY _stg_load (profile_id, regulation, description, policy_ids) FROM stdin;
1	PCI-DSS	Payment Card Industry Data Security Standard	{}
2	HIPAA	Health Insurance Portability and Accountability Act	{}
3	GDPR	General Data Protection Regulation	{}
4	SOC2	Service Organization Control 2	{}
\.
INSERT INTO config.regulation_profiles (profile_id, regulation, description, policy_ids)
SELECT profile_id, regulation, description, policy_ids FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM config.regulation_profiles);
DROP TABLE _stg_load;

SELECT setval('config.regulation_profiles_profile_id_seq', GREATEST((SELECT COALESCE(max(profile_id),0) FROM config.regulation_profiles),1), (SELECT count(*) FROM config.regulation_profiles) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'regulation_profiles'
          AND con.conname = 'regulation_profiles_pkey') THEN
        ALTER TABLE ONLY config.regulation_profiles
    ADD CONSTRAINT regulation_profiles_pkey PRIMARY KEY (profile_id);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'regulation_profiles'
          AND con.conname = 'regulation_profiles_regulation_key') THEN
        ALTER TABLE ONLY config.regulation_profiles
    ADD CONSTRAINT regulation_profiles_regulation_key UNIQUE (regulation);
    END IF;
END $do$;
