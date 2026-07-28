-- Idempotent install for config.masking_tokens
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.masking_tokens_token_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.masking_tokens (
    token_id bigint NOT NULL,
    pii_type character varying(50) NOT NULL,
    original_hash character varying(64) NOT NULL,
    token character varying(100) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE config.masking_tokens ALTER COLUMN token_id SET DEFAULT nextval('config.masking_tokens_token_id_seq'::regclass);
ALTER SEQUENCE config.masking_tokens_token_id_seq OWNED BY config.masking_tokens.token_id;

SELECT setval('config.masking_tokens_token_id_seq', GREATEST((SELECT COALESCE(max(token_id),0) FROM config.masking_tokens),1), (SELECT count(*) FROM config.masking_tokens) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'masking_tokens'
          AND con.conname = 'masking_tokens_pii_type_original_hash_key') THEN
        ALTER TABLE ONLY config.masking_tokens
    ADD CONSTRAINT masking_tokens_pii_type_original_hash_key UNIQUE (pii_type, original_hash);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'masking_tokens'
          AND con.conname = 'masking_tokens_pkey') THEN
        ALTER TABLE ONLY config.masking_tokens
    ADD CONSTRAINT masking_tokens_pkey PRIMARY KEY (token_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_masking_tokens_lookup ON config.masking_tokens USING btree (pii_type, original_hash);
