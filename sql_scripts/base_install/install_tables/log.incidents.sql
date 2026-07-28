-- Idempotent install for log.incidents
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS log;

CREATE SEQUENCE IF NOT EXISTS log.incidents_incident_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS log.incidents (
    incident_id bigint NOT NULL,
    title character varying(400) NOT NULL,
    description text,
    severity character varying(20) DEFAULT 'MEDIUM'::character varying NOT NULL,
    category character varying(50) DEFAULT 'OTHER'::character varying NOT NULL,
    state character varying(30) DEFAULT 'OPEN'::character varying NOT NULL,
    regulation text[] DEFAULT '{}'::text[] NOT NULL,
    server_name text[] DEFAULT '{}'::text[] NOT NULL,
    assigned_to character varying(200),
    created_by character varying(200) DEFAULT 'system'::character varying NOT NULL,
    affected_records_count integer,
    involves_personal_data boolean DEFAULT false NOT NULL,
    detected_at timestamp with time zone DEFAULT now() NOT NULL,
    gdpr_notification_due timestamp with time zone,
    gdpr_notified_at timestamp with time zone,
    resolved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    closed_at timestamp without time zone
);

ALTER TABLE log.incidents ALTER COLUMN incident_id SET DEFAULT nextval('log.incidents_incident_id_seq'::regclass);
ALTER SEQUENCE log.incidents_incident_id_seq OWNED BY log.incidents.incident_id;

SELECT setval('log.incidents_incident_id_seq', GREATEST((SELECT COALESCE(max(incident_id),0) FROM log.incidents),1), (SELECT count(*) FROM log.incidents) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'log' AND c.relname = 'incidents'
          AND con.conname = 'incidents_pkey') THEN
        ALTER TABLE ONLY log.incidents
    ADD CONSTRAINT incidents_pkey PRIMARY KEY (incident_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_incidents_gdpr ON log.incidents USING btree (gdpr_notification_due, gdpr_notified_at) WHERE (involves_personal_data = true);
CREATE INDEX IF NOT EXISTS idx_incidents_state ON log.incidents USING btree (state, severity, created_at DESC);
