-- Idempotent install for monitoring.query_embeddings_json
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.query_embeddings_json_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.query_embeddings_json (
    id integer NOT NULL,
    query_id bigint,
    embedding jsonb,
    created_at timestamp without time zone DEFAULT now(),
    query text,
    prediction text
);

ALTER TABLE monitoring.query_embeddings_json ALTER COLUMN id SET DEFAULT nextval('monitoring.query_embeddings_json_id_seq'::regclass);
ALTER SEQUENCE monitoring.query_embeddings_json_id_seq OWNED BY monitoring.query_embeddings_json.id;

SELECT setval('monitoring.query_embeddings_json_id_seq', GREATEST((SELECT COALESCE(max(id),0) FROM monitoring.query_embeddings_json),1), (SELECT count(*) FROM monitoring.query_embeddings_json) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'query_embeddings_json'
          AND con.conname = 'query_embeddings_json_pkey') THEN
        ALTER TABLE ONLY monitoring.query_embeddings_json
    ADD CONSTRAINT query_embeddings_json_pkey PRIMARY KEY (id);
    END IF;
END $do$;
