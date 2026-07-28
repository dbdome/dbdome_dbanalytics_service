-- Idempotent install for log.incident_timeline
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS log;

CREATE SEQUENCE IF NOT EXISTS log.incident_timeline_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS log.incident_timeline (
    event_id bigint NOT NULL,
    incident_id bigint NOT NULL,
    event_type character varying(50) NOT NULL,
    actor character varying(200),
    note text,
    event_time timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE log.incident_timeline ALTER COLUMN event_id SET DEFAULT nextval('log.incident_timeline_event_id_seq'::regclass);
ALTER SEQUENCE log.incident_timeline_event_id_seq OWNED BY log.incident_timeline.event_id;

SELECT setval('log.incident_timeline_event_id_seq', GREATEST((SELECT COALESCE(max(event_id),0) FROM log.incident_timeline),1), (SELECT count(*) FROM log.incident_timeline) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'log' AND c.relname = 'incident_timeline'
          AND con.conname = 'incident_timeline_pkey') THEN
        ALTER TABLE ONLY log.incident_timeline
    ADD CONSTRAINT incident_timeline_pkey PRIMARY KEY (event_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_incident_timeline_incident ON log.incident_timeline USING btree (incident_id, event_time DESC);
