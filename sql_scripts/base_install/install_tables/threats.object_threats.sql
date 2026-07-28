-- Idempotent install for threats.object_threats
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS threats;

CREATE SEQUENCE IF NOT EXISTS threats.object_threats_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS threats.object_threats (
    row_id integer NOT NULL,
    server character varying(50) NOT NULL,
    category character varying(20) NOT NULL,
    object_name character varying(50) NOT NULL,
    status character varying(52) NOT NULL,
    entry_date timestamp without time zone NOT NULL
);

ALTER TABLE threats.object_threats ALTER COLUMN row_id SET DEFAULT nextval('threats.object_threats_row_id_seq'::regclass);
ALTER SEQUENCE threats.object_threats_row_id_seq OWNED BY threats.object_threats.row_id;

SELECT setval('threats.object_threats_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM threats.object_threats),1), (SELECT count(*) FROM threats.object_threats) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'threats' AND c.relname = 'object_threats'
          AND con.conname = 'object_threats_pkey') THEN
        ALTER TABLE ONLY threats.object_threats
    ADD CONSTRAINT object_threats_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
