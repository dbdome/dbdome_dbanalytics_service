-- Idempotent install for log.firewall_audit_log
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS log;

CREATE SEQUENCE IF NOT EXISTS log.firewall_audit_log_audit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS log.firewall_audit_log (
    audit_id bigint NOT NULL,
    event_time timestamp with time zone DEFAULT now() NOT NULL,
    server_name character varying(200),
    vendor character varying(50),
    db_user character varying(200),
    client_ip character varying(50),
    db_name character varying(200),
    sql_statement text,
    matched_policy integer,
    action_taken character varying(20) NOT NULL,
    regulation character varying(50),
    session_id character varying(100),
    risk_score integer DEFAULT 0 NOT NULL,
    row_hash character varying(64),
    prev_hash character varying(64)
);

ALTER TABLE log.firewall_audit_log ALTER COLUMN audit_id SET DEFAULT nextval('log.firewall_audit_log_audit_id_seq'::regclass);
ALTER SEQUENCE log.firewall_audit_log_audit_id_seq OWNED BY log.firewall_audit_log.audit_id;

SELECT setval('log.firewall_audit_log_audit_id_seq', GREATEST((SELECT COALESCE(max(audit_id),0) FROM log.firewall_audit_log),1), (SELECT count(*) FROM log.firewall_audit_log) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'log' AND c.relname = 'firewall_audit_log'
          AND con.conname = 'firewall_audit_log_pkey') THEN
        ALTER TABLE ONLY log.firewall_audit_log
    ADD CONSTRAINT firewall_audit_log_pkey PRIMARY KEY (audit_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_firewall_audit_log_row_hash ON log.firewall_audit_log USING btree (audit_id) WHERE (row_hash IS NULL);
CREATE INDEX IF NOT EXISTS idx_fw_audit_action ON log.firewall_audit_log USING btree (action_taken, event_time DESC);
CREATE INDEX IF NOT EXISTS idx_fw_audit_event_time ON log.firewall_audit_log USING btree (event_time DESC);
CREATE INDEX IF NOT EXISTS idx_fw_audit_server_user ON log.firewall_audit_log USING btree (server_name, db_user, event_time DESC);
