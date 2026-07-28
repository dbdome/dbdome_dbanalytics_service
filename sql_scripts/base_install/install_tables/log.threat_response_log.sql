-- Idempotent install for log.threat_response_log
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS log;

CREATE SEQUENCE IF NOT EXISTS log.threat_response_log_response_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS log.threat_response_log (
    response_id bigint NOT NULL,
    triggered_at timestamp with time zone DEFAULT now() NOT NULL,
    playbook_id integer,
    playbook_name character varying(200),
    trigger_type character varying(50),
    subject character varying(400),
    response_type character varying(50),
    response_detail jsonb,
    success boolean DEFAULT true NOT NULL,
    error_message text
);

ALTER TABLE log.threat_response_log ALTER COLUMN response_id SET DEFAULT nextval('log.threat_response_log_response_id_seq'::regclass);
ALTER SEQUENCE log.threat_response_log_response_id_seq OWNED BY log.threat_response_log.response_id;

SELECT setval('log.threat_response_log_response_id_seq', GREATEST((SELECT COALESCE(max(response_id),0) FROM log.threat_response_log),1), (SELECT count(*) FROM log.threat_response_log) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'log' AND c.relname = 'threat_response_log'
          AND con.conname = 'threat_response_log_pkey') THEN
        ALTER TABLE ONLY log.threat_response_log
    ADD CONSTRAINT threat_response_log_pkey PRIMARY KEY (response_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_threat_response_log_subject ON log.threat_response_log USING btree (subject, triggered_at DESC);
CREATE INDEX IF NOT EXISTS idx_threat_response_log_triggered_at ON log.threat_response_log USING btree (triggered_at DESC);
