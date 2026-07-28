-- Idempotent install for monitoring.alert_instances
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.alert_instances_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.alert_instances (
    row_id integer NOT NULL,
    alert_id integer NOT NULL,
    first_seen timestamp with time zone NOT NULL,
    last_seen timestamp with time zone NOT NULL,
    fire_count integer DEFAULT 1 NOT NULL,
    status text NOT NULL,
    fingerprint text NOT NULL,
    context jsonb NOT NULL,
    CONSTRAINT alert_instances_status_check CHECK ((status = ANY (ARRAY['open'::text, 'ack'::text, 'closed'::text])))
);

ALTER TABLE monitoring.alert_instances ALTER COLUMN row_id SET DEFAULT nextval('monitoring.alert_instances_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.alert_instances_row_id_seq OWNED BY monitoring.alert_instances.row_id;

SELECT setval('monitoring.alert_instances_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.alert_instances),1), (SELECT count(*) FROM monitoring.alert_instances) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'alert_instances'
          AND con.conname = 'alert_instances_pkey') THEN
        ALTER TABLE ONLY monitoring.alert_instances
    ADD CONSTRAINT alert_instances_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_alert_dedupe ON monitoring.alert_instances USING btree (alert_id, fingerprint) WHERE (status = 'open'::text);
