-- Idempotent install for log.hash_chain_checkpoints
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS log;

CREATE SEQUENCE IF NOT EXISTS log.hash_chain_checkpoints_checkpoint_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS log.hash_chain_checkpoints (
    checkpoint_id bigint NOT NULL,
    table_name character varying(200) DEFAULT 'log.firewall_audit_log'::character varying NOT NULL,
    last_hashed_id bigint NOT NULL,
    last_hash character varying(64) NOT NULL,
    rows_hashed integer NOT NULL,
    verified_at timestamp with time zone DEFAULT now() NOT NULL,
    is_valid boolean NOT NULL,
    broken_at_id bigint,
    error_detail text
);

ALTER TABLE log.hash_chain_checkpoints ALTER COLUMN checkpoint_id SET DEFAULT nextval('log.hash_chain_checkpoints_checkpoint_id_seq'::regclass);
ALTER SEQUENCE log.hash_chain_checkpoints_checkpoint_id_seq OWNED BY log.hash_chain_checkpoints.checkpoint_id;

SELECT setval('log.hash_chain_checkpoints_checkpoint_id_seq', GREATEST((SELECT COALESCE(max(checkpoint_id),0) FROM log.hash_chain_checkpoints),1), (SELECT count(*) FROM log.hash_chain_checkpoints) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'log' AND c.relname = 'hash_chain_checkpoints'
          AND con.conname = 'hash_chain_checkpoints_pkey') THEN
        ALTER TABLE ONLY log.hash_chain_checkpoints
    ADD CONSTRAINT hash_chain_checkpoints_pkey PRIMARY KEY (checkpoint_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_hash_chain_checkpoints_table ON log.hash_chain_checkpoints USING btree (table_name, verified_at DESC);
