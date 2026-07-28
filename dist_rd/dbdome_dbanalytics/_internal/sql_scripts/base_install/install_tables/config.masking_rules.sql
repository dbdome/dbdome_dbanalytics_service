-- Idempotent install for config.masking_rules
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.masking_rules_rule_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.masking_rules (
    rule_id integer NOT NULL,
    server_name character varying(200) NOT NULL,
    database_name character varying(200),
    schema_name character varying(200),
    table_name character varying(200) NOT NULL,
    column_name character varying(200) NOT NULL,
    pii_type character varying(50) DEFAULT 'GENERIC'::character varying NOT NULL,
    mask_type character varying(20) DEFAULT 'HASH'::character varying NOT NULL,
    allowed_roles text[] DEFAULT '{}'::text[] NOT NULL,
    regulation character varying(50),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE config.masking_rules ALTER COLUMN rule_id SET DEFAULT nextval('config.masking_rules_rule_id_seq'::regclass);
ALTER SEQUENCE config.masking_rules_rule_id_seq OWNED BY config.masking_rules.rule_id;

SELECT setval('config.masking_rules_rule_id_seq', GREATEST((SELECT COALESCE(max(rule_id),0) FROM config.masking_rules),1), (SELECT count(*) FROM config.masking_rules) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'masking_rules'
          AND con.conname = 'masking_rules_pkey') THEN
        ALTER TABLE ONLY config.masking_rules
    ADD CONSTRAINT masking_rules_pkey PRIMARY KEY (rule_id);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'masking_rules'
          AND con.conname = 'masking_rules_server_name_table_name_column_name_key') THEN
        ALTER TABLE ONLY config.masking_rules
    ADD CONSTRAINT masking_rules_server_name_table_name_column_name_key UNIQUE (server_name, table_name, column_name);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_masking_rules_server_table ON config.masking_rules USING btree (server_name, table_name, column_name) WHERE (is_active = true);
