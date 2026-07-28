-- Idempotent install for threats.login_threats_history
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS threats;

CREATE SEQUENCE IF NOT EXISTS threats.login_threats_history_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS threats.login_threats_history (
    row_id integer NOT NULL,
    server character varying(50) NOT NULL,
    category character varying(20) NOT NULL,
    login_name character varying(50) NOT NULL,
    status character varying(52) NOT NULL,
    entry_date timestamp without time zone NOT NULL
);

ALTER TABLE threats.login_threats_history ALTER COLUMN row_id SET DEFAULT nextval('threats.login_threats_history_row_id_seq'::regclass);
ALTER SEQUENCE threats.login_threats_history_row_id_seq OWNED BY threats.login_threats_history.row_id;

SELECT setval('threats.login_threats_history_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM threats.login_threats_history),1), (SELECT count(*) FROM threats.login_threats_history) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'threats' AND c.relname = 'login_threats_history'
          AND con.conname = 'login_threats_history_pkey') THEN
        ALTER TABLE ONLY threats.login_threats_history
    ADD CONSTRAINT login_threats_history_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
