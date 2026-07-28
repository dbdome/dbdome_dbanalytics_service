-- Idempotent install for monitoring.alert_actions
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.alert_actions_action_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.alert_actions (
    action_id integer NOT NULL,
    action_type text NOT NULL,
    config jsonb NOT NULL
);

ALTER TABLE monitoring.alert_actions ALTER COLUMN action_id SET DEFAULT nextval('monitoring.alert_actions_action_id_seq'::regclass);
ALTER SEQUENCE monitoring.alert_actions_action_id_seq OWNED BY monitoring.alert_actions.action_id;

SELECT setval('monitoring.alert_actions_action_id_seq', GREATEST((SELECT COALESCE(max(action_id),0) FROM monitoring.alert_actions),1), (SELECT count(*) FROM monitoring.alert_actions) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'alert_actions'
          AND con.conname = 'alert_actions_pkey') THEN
        ALTER TABLE ONLY monitoring.alert_actions
    ADD CONSTRAINT alert_actions_pkey PRIMARY KEY (action_id);
    END IF;
END $do$;
