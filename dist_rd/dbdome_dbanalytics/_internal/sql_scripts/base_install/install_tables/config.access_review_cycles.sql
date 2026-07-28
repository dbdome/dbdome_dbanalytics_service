-- Idempotent install for config.access_review_cycles
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.access_review_cycles_cycle_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.access_review_cycles (
    cycle_id integer NOT NULL,
    cycle_name character varying(200) NOT NULL,
    frequency character varying(20) DEFAULT 'QUARTERLY'::character varying NOT NULL,
    scope_servers text[] DEFAULT '{}'::text[] NOT NULL,
    scope_regulations text[] DEFAULT '{}'::text[] NOT NULL,
    reviewer_email character varying(400) NOT NULL,
    reminder_days_before integer DEFAULT 7 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    last_cycle_started_at timestamp with time zone,
    next_cycle_due_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE config.access_review_cycles ALTER COLUMN cycle_id SET DEFAULT nextval('config.access_review_cycles_cycle_id_seq'::regclass);
ALTER SEQUENCE config.access_review_cycles_cycle_id_seq OWNED BY config.access_review_cycles.cycle_id;

SELECT setval('config.access_review_cycles_cycle_id_seq', GREATEST((SELECT COALESCE(max(cycle_id),0) FROM config.access_review_cycles),1), (SELECT count(*) FROM config.access_review_cycles) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'access_review_cycles'
          AND con.conname = 'access_review_cycles_cycle_name_key') THEN
        ALTER TABLE ONLY config.access_review_cycles
    ADD CONSTRAINT access_review_cycles_cycle_name_key UNIQUE (cycle_name);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'access_review_cycles'
          AND con.conname = 'access_review_cycles_pkey') THEN
        ALTER TABLE ONLY config.access_review_cycles
    ADD CONSTRAINT access_review_cycles_pkey PRIMARY KEY (cycle_id);
    END IF;
END $do$;
