-- Idempotent install for log.security_incidents
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS log;

CREATE SEQUENCE IF NOT EXISTS log.security_incidents_incident_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS log.security_incidents (
    incident_id integer NOT NULL,
    title character varying(500) NOT NULL,
    severity character varying(20) DEFAULT 'HIGH'::character varying NOT NULL,
    regulation character varying(50),
    server_name character varying(200),
    db_user character varying(200),
    client_ip character varying(50),
    description text,
    status character varying(20) DEFAULT 'OPEN'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    resolved_at timestamp with time zone,
    resolved_by character varying(100)
);

ALTER TABLE log.security_incidents ALTER COLUMN incident_id SET DEFAULT nextval('log.security_incidents_incident_id_seq'::regclass);
ALTER SEQUENCE log.security_incidents_incident_id_seq OWNED BY log.security_incidents.incident_id;

SELECT setval('log.security_incidents_incident_id_seq', GREATEST((SELECT COALESCE(max(incident_id),0) FROM log.security_incidents),1), (SELECT count(*) FROM log.security_incidents) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'log' AND c.relname = 'security_incidents'
          AND con.conname = 'security_incidents_pkey') THEN
        ALTER TABLE ONLY log.security_incidents
    ADD CONSTRAINT security_incidents_pkey PRIMARY KEY (incident_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_security_incidents_status ON log.security_incidents USING btree (status, created_at DESC);
