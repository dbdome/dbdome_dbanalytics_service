-- Idempotent install for log.sod_violations
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS log;

CREATE SEQUENCE IF NOT EXISTS log.sod_violations_violation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS log.sod_violations (
    violation_id bigint NOT NULL,
    rule_id integer NOT NULL,
    rule_name character varying(200) NOT NULL,
    action_type character varying(100) NOT NULL,
    attempted_by character varying(200) NOT NULL,
    resource_id character varying(200),
    resource_owner character varying(200),
    violation_reason text,
    acknowledged_at timestamp with time zone,
    acknowledged_by character varying(200),
    detected_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE log.sod_violations ALTER COLUMN violation_id SET DEFAULT nextval('log.sod_violations_violation_id_seq'::regclass);
ALTER SEQUENCE log.sod_violations_violation_id_seq OWNED BY log.sod_violations.violation_id;

SELECT setval('log.sod_violations_violation_id_seq', GREATEST((SELECT COALESCE(max(violation_id),0) FROM log.sod_violations),1), (SELECT count(*) FROM log.sod_violations) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'log' AND c.relname = 'sod_violations'
          AND con.conname = 'sod_violations_pkey') THEN
        ALTER TABLE ONLY log.sod_violations
    ADD CONSTRAINT sod_violations_pkey PRIMARY KEY (violation_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_sod_violations_action ON log.sod_violations USING btree (action_type, detected_at DESC);
CREATE INDEX IF NOT EXISTS idx_sod_violations_unacked ON log.sod_violations USING btree (detected_at DESC) WHERE (acknowledged_at IS NULL);
CREATE INDEX IF NOT EXISTS idx_sod_violations_user ON log.sod_violations USING btree (attempted_by, detected_at DESC);
