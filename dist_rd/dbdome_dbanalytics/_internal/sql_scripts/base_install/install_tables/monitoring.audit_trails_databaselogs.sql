-- Idempotent install for monitoring.audit_trails_databaselogs
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.audit_trails_databaselogs_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.audit_trails_databaselogs (
    row_id integer NOT NULL,
    server character varying(50),
    databasename character varying(100) NOT NULL,
    posttime timestamp without time zone NOT NULL,
    loginname character varying(50) NOT NULL,
    eventtype character varying(25) NOT NULL,
    tsqlcommand text NOT NULL,
    entry_date timestamp without time zone NOT NULL,
    eventdata xml
);

ALTER TABLE monitoring.audit_trails_databaselogs ALTER COLUMN row_id SET DEFAULT nextval('monitoring.audit_trails_databaselogs_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.audit_trails_databaselogs_row_id_seq OWNED BY monitoring.audit_trails_databaselogs.row_id;

SELECT setval('monitoring.audit_trails_databaselogs_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.audit_trails_databaselogs),1), (SELECT count(*) FROM monitoring.audit_trails_databaselogs) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'audit_trails_databaselogs'
          AND con.conname = 'audit_trails_databaselogs_pkey') THEN
        ALTER TABLE ONLY monitoring.audit_trails_databaselogs
    ADD CONSTRAINT audit_trails_databaselogs_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
