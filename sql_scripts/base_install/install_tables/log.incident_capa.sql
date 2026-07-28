-- Idempotent install for log.incident_capa
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS log;

CREATE SEQUENCE IF NOT EXISTS log.incident_capa_capa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS log.incident_capa (
    capa_id bigint NOT NULL,
    incident_id bigint NOT NULL,
    capa_type character varying(20) DEFAULT 'CORRECTIVE'::character varying NOT NULL,
    description text NOT NULL,
    assigned_to character varying(200),
    due_date date,
    status character varying(20) DEFAULT 'OPEN'::character varying NOT NULL,
    completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE log.incident_capa ALTER COLUMN capa_id SET DEFAULT nextval('log.incident_capa_capa_id_seq'::regclass);
ALTER SEQUENCE log.incident_capa_capa_id_seq OWNED BY log.incident_capa.capa_id;

SELECT setval('log.incident_capa_capa_id_seq', GREATEST((SELECT COALESCE(max(capa_id),0) FROM log.incident_capa),1), (SELECT count(*) FROM log.incident_capa) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'log' AND c.relname = 'incident_capa'
          AND con.conname = 'incident_capa_pkey') THEN
        ALTER TABLE ONLY log.incident_capa
    ADD CONSTRAINT incident_capa_pkey PRIMARY KEY (capa_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_incident_capa_incident ON log.incident_capa USING btree (incident_id, status);
