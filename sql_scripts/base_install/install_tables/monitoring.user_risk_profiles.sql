-- Idempotent install for monitoring.user_risk_profiles
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.user_risk_profiles_profile_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.user_risk_profiles (
    profile_id integer NOT NULL,
    server_name character varying(200) NOT NULL,
    db_user character varying(200) NOT NULL,
    avg_queries_per_hour numeric(10,2) DEFAULT 0 NOT NULL,
    typical_hour_start smallint DEFAULT 7 NOT NULL,
    typical_hour_end smallint DEFAULT 19 NOT NULL,
    typical_tables text[] DEFAULT '{}'::text[] NOT NULL,
    avg_duration_secs numeric(10,2) DEFAULT 0 NOT NULL,
    avg_logical_reads numeric(14,2) DEFAULT 0 NOT NULL,
    risk_score smallint DEFAULT 0 NOT NULL,
    observation_count integer DEFAULT 0 NOT NULL,
    consecutive_high_risk smallint DEFAULT 0 NOT NULL,
    first_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    last_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    last_updated timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE monitoring.user_risk_profiles ALTER COLUMN profile_id SET DEFAULT nextval('monitoring.user_risk_profiles_profile_id_seq'::regclass);
ALTER SEQUENCE monitoring.user_risk_profiles_profile_id_seq OWNED BY monitoring.user_risk_profiles.profile_id;

SELECT setval('monitoring.user_risk_profiles_profile_id_seq', GREATEST((SELECT COALESCE(max(profile_id),0) FROM monitoring.user_risk_profiles),1), (SELECT count(*) FROM monitoring.user_risk_profiles) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'user_risk_profiles'
          AND con.conname = 'user_risk_profiles_pkey') THEN
        ALTER TABLE ONLY monitoring.user_risk_profiles
    ADD CONSTRAINT user_risk_profiles_pkey PRIMARY KEY (profile_id);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'user_risk_profiles'
          AND con.conname = 'user_risk_profiles_server_name_db_user_key') THEN
        ALTER TABLE ONLY monitoring.user_risk_profiles
    ADD CONSTRAINT user_risk_profiles_server_name_db_user_key UNIQUE (server_name, db_user);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_urp_risk_score ON monitoring.user_risk_profiles USING btree (risk_score DESC);
CREATE INDEX IF NOT EXISTS idx_urp_server_user ON monitoring.user_risk_profiles USING btree (server_name, db_user);
