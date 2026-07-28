-- Idempotent install for monitoring.sql_injection_suspicious_activity
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.sql_injection_suspicious_activity_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.sql_injection_suspicious_activity (
    row_id integer NOT NULL,
    servername character varying(50),
    last_execution_time timestamp without time zone,
    last_ideal_grant integer,
    last_rows integer,
    sql_text text,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE monitoring.sql_injection_suspicious_activity ALTER COLUMN row_id SET DEFAULT nextval('monitoring.sql_injection_suspicious_activity_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.sql_injection_suspicious_activity_row_id_seq OWNED BY monitoring.sql_injection_suspicious_activity.row_id;

SELECT setval('monitoring.sql_injection_suspicious_activity_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.sql_injection_suspicious_activity),1), (SELECT count(*) FROM monitoring.sql_injection_suspicious_activity) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'sql_injection_suspicious_activity'
          AND con.conname = 'sql_injection_suspicious_activity_pkey') THEN
        ALTER TABLE ONLY monitoring.sql_injection_suspicious_activity
    ADD CONSTRAINT sql_injection_suspicious_activity_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
