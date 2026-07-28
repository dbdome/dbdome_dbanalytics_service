-- Idempotent install for monitoring.user_risk_events
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.user_risk_events_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.user_risk_events (
    event_id bigint NOT NULL,
    event_time timestamp with time zone DEFAULT now() NOT NULL,
    server_name character varying(200) NOT NULL,
    db_user character varying(200) NOT NULL,
    risk_score smallint NOT NULL,
    risk_factors jsonb DEFAULT '{}'::jsonb NOT NULL,
    active_sessions integer DEFAULT 0 NOT NULL,
    active_queries integer DEFAULT 0 NOT NULL
);

ALTER TABLE monitoring.user_risk_events ALTER COLUMN event_id SET DEFAULT nextval('monitoring.user_risk_events_event_id_seq'::regclass);
ALTER SEQUENCE monitoring.user_risk_events_event_id_seq OWNED BY monitoring.user_risk_events.event_id;

SELECT setval('monitoring.user_risk_events_event_id_seq', GREATEST((SELECT COALESCE(max(event_id),0) FROM monitoring.user_risk_events),1), (SELECT count(*) FROM monitoring.user_risk_events) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'user_risk_events'
          AND con.conname = 'user_risk_events_pkey') THEN
        ALTER TABLE ONLY monitoring.user_risk_events
    ADD CONSTRAINT user_risk_events_pkey PRIMARY KEY (event_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_ure_risk_score ON monitoring.user_risk_events USING btree (risk_score DESC, event_time DESC);
CREATE INDEX IF NOT EXISTS idx_ure_server_user_time ON monitoring.user_risk_events USING btree (server_name, db_user, event_time DESC);
