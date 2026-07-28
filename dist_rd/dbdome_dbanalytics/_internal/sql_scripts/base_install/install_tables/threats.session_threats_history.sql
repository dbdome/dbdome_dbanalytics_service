-- Idempotent install for threats.session_threats_history
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS threats;

CREATE SEQUENCE IF NOT EXISTS threats.session_threats_history_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS threats.session_threats_history (
    row_id integer NOT NULL,
    server character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    category character varying(20) NOT NULL,
    session_id integer NOT NULL,
    status character varying(52) NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE threats.session_threats_history ALTER COLUMN row_id SET DEFAULT nextval('threats.session_threats_history_row_id_seq'::regclass);
ALTER SEQUENCE threats.session_threats_history_row_id_seq OWNED BY threats.session_threats_history.row_id;

SELECT setval('threats.session_threats_history_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM threats.session_threats_history),1), (SELECT count(*) FROM threats.session_threats_history) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'threats' AND c.relname = 'session_threats_history'
          AND con.conname = 'session_threats_history_pkey') THEN
        ALTER TABLE ONLY threats.session_threats_history
    ADD CONSTRAINT session_threats_history_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
