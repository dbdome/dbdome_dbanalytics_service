-- Idempotent install for log.ddl_audit_log
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS log;

CREATE SEQUENCE IF NOT EXISTS log.ddl_audit_log_ddl_audit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS log.ddl_audit_log (
    ddl_audit_id bigint NOT NULL,
    event_time timestamp with time zone DEFAULT now() NOT NULL,
    server_name character varying(200) NOT NULL,
    vendor character varying(50),
    db_user character varying(200),
    client_ip character varying(50),
    db_name character varying(200),
    object_schema character varying(200),
    object_name character varying(400),
    object_type character varying(50),
    ddl_command character varying(20) NOT NULL,
    ddl_statement text,
    regulation character varying(50),
    risk_level character varying(20) DEFAULT 'MEDIUM'::character varying NOT NULL,
    collected_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE log.ddl_audit_log ALTER COLUMN ddl_audit_id SET DEFAULT nextval('log.ddl_audit_log_ddl_audit_id_seq'::regclass);
ALTER SEQUENCE log.ddl_audit_log_ddl_audit_id_seq OWNED BY log.ddl_audit_log.ddl_audit_id;

SELECT setval('log.ddl_audit_log_ddl_audit_id_seq', GREATEST((SELECT COALESCE(max(ddl_audit_id),0) FROM log.ddl_audit_log),1), (SELECT count(*) FROM log.ddl_audit_log) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'log' AND c.relname = 'ddl_audit_log'
          AND con.conname = 'ddl_audit_log_pkey') THEN
        ALTER TABLE ONLY log.ddl_audit_log
    ADD CONSTRAINT ddl_audit_log_pkey PRIMARY KEY (ddl_audit_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_ddl_audit_command ON log.ddl_audit_log USING btree (ddl_command, event_time DESC);
CREATE INDEX IF NOT EXISTS idx_ddl_audit_event_time ON log.ddl_audit_log USING btree (event_time DESC);
CREATE INDEX IF NOT EXISTS idx_ddl_audit_server_user ON log.ddl_audit_log USING btree (server_name, db_user, event_time DESC);
