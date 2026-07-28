-- Idempotent install for alerts.blocker_log
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS alerts;

CREATE TABLE IF NOT EXISTS alerts.blocker_log (
    log_id bigint NOT NULL,
    entry_date timestamp with time zone DEFAULT now() NOT NULL,
    server text,
    db_vendor text,
    root_cause_id text,
    session_id text,
    action text,
    detail text
);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_attribute a
        JOIN pg_class c ON c.oid = a.attrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'alerts' AND c.relname = 'blocker_log'
          AND a.attname = 'log_id' AND a.attidentity <> '') THEN
        EXECUTE $cmd$ ALTER TABLE alerts.blocker_log ALTER COLUMN log_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME alerts.blocker_log_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
); $cmd$;
    END IF;
END $do$;

SELECT setval('alerts.blocker_log_log_id_seq', GREATEST((SELECT COALESCE(max(log_id),0) FROM alerts.blocker_log),1), (SELECT count(*) FROM alerts.blocker_log) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'alerts' AND c.relname = 'blocker_log'
          AND con.conname = 'blocker_log_pkey') THEN
        ALTER TABLE ONLY alerts.blocker_log
    ADD CONSTRAINT blocker_log_pkey PRIMARY KEY (log_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS ix_blocker_log_date ON alerts.blocker_log USING btree (entry_date DESC);
CREATE INDEX IF NOT EXISTS ix_blocker_log_server_sid ON alerts.blocker_log USING btree (server, session_id, entry_date DESC);
