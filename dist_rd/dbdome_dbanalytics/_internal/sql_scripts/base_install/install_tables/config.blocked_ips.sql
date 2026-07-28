-- Idempotent install for config.blocked_ips
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.blocked_ips_block_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.blocked_ips (
    block_id integer NOT NULL,
    ip_address inet NOT NULL,
    reason text,
    blocked_by character varying(100) DEFAULT 'threat_response'::character varying NOT NULL,
    blocked_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone,
    is_active boolean DEFAULT true NOT NULL
);

ALTER TABLE config.blocked_ips ALTER COLUMN block_id SET DEFAULT nextval('config.blocked_ips_block_id_seq'::regclass);
ALTER SEQUENCE config.blocked_ips_block_id_seq OWNED BY config.blocked_ips.block_id;

SELECT setval('config.blocked_ips_block_id_seq', GREATEST((SELECT COALESCE(max(block_id),0) FROM config.blocked_ips),1), (SELECT count(*) FROM config.blocked_ips) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'blocked_ips'
          AND con.conname = 'blocked_ips_ip_address_key') THEN
        ALTER TABLE ONLY config.blocked_ips
    ADD CONSTRAINT blocked_ips_ip_address_key UNIQUE (ip_address);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'blocked_ips'
          AND con.conname = 'blocked_ips_pkey') THEN
        ALTER TABLE ONLY config.blocked_ips
    ADD CONSTRAINT blocked_ips_pkey PRIMARY KEY (block_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_blocked_ips_active ON config.blocked_ips USING btree (ip_address) WHERE (is_active = true);
