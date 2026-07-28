-- Idempotent install for siem.fortianalyzer_ips_events
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS siem;

CREATE SEQUENCE IF NOT EXISTS siem.fortianalyzer_ips_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS siem.fortianalyzer_ips_events (
    id bigint NOT NULL,
    device_name text NOT NULL,
    event_time timestamp with time zone NOT NULL,
    attack_name text NOT NULL,
    cve_id text,
    intrusion_type text,
    severity text NOT NULL,
    action text NOT NULL,
    protocol text,
    src_ip inet,
    dst_ip inet,
    src_port integer,
    dst_port integer,
    count integer DEFAULT 1 NOT NULL,
    entry_date timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE siem.fortianalyzer_ips_events ALTER COLUMN id SET DEFAULT nextval('siem.fortianalyzer_ips_events_id_seq'::regclass);
ALTER SEQUENCE siem.fortianalyzer_ips_events_id_seq OWNED BY siem.fortianalyzer_ips_events.id;

SELECT setval('siem.fortianalyzer_ips_events_id_seq', GREATEST((SELECT COALESCE(max(id),0) FROM siem.fortianalyzer_ips_events),1), (SELECT count(*) FROM siem.fortianalyzer_ips_events) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'siem' AND c.relname = 'fortianalyzer_ips_events'
          AND con.conname = 'fortianalyzer_ips_events_pkey') THEN
        ALTER TABLE ONLY siem.fortianalyzer_ips_events
    ADD CONSTRAINT fortianalyzer_ips_events_pkey PRIMARY KEY (id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_faz_ips_action ON siem.fortianalyzer_ips_events USING btree (action);
CREATE INDEX IF NOT EXISTS idx_faz_ips_attack_name ON siem.fortianalyzer_ips_events USING btree (attack_name);
CREATE INDEX IF NOT EXISTS idx_faz_ips_device ON siem.fortianalyzer_ips_events USING btree (device_name);
CREATE INDEX IF NOT EXISTS idx_faz_ips_event_time ON siem.fortianalyzer_ips_events USING btree (event_time);
CREATE INDEX IF NOT EXISTS idx_faz_ips_severity ON siem.fortianalyzer_ips_events USING btree (severity);
