-- Idempotent install for monitoring.sql_suspicious
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.sql_suspicious_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.sql_suspicious (
    row_id integer NOT NULL,
    query text NOT NULL,
    query_id bigint NOT NULL,
    tables jsonb,
    columns jsonb,
    literals jsonb,
    has_union boolean,
    has_comment boolean,
    suspicious_or boolean,
    entry_date timestamp without time zone DEFAULT now() NOT NULL,
    update_status integer DEFAULT 1 NOT NULL
);

ALTER TABLE monitoring.sql_suspicious ALTER COLUMN row_id SET DEFAULT nextval('monitoring.sql_suspicious_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.sql_suspicious_row_id_seq OWNED BY monitoring.sql_suspicious.row_id;

SELECT setval('monitoring.sql_suspicious_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.sql_suspicious),1), (SELECT count(*) FROM monitoring.sql_suspicious) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'sql_suspicious'
          AND con.conname = 'pk_sql_suspicious') THEN
        ALTER TABLE ONLY monitoring.sql_suspicious
    ADD CONSTRAINT pk_sql_suspicious PRIMARY KEY (query_id);
    END IF;
END $do$;
