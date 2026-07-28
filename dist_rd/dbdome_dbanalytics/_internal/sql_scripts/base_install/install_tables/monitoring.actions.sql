-- Idempotent install for monitoring.actions
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.actions_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.actions (
    row_id integer NOT NULL,
    activity_type integer NOT NULL,
    metric_result_row_id integer,
    tcp_connection_row_id integer,
    entry_date timestamp without time zone NOT NULL
);

ALTER TABLE monitoring.actions ALTER COLUMN row_id SET DEFAULT nextval('monitoring.actions_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.actions_row_id_seq OWNED BY monitoring.actions.row_id;

SELECT setval('monitoring.actions_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.actions),1), (SELECT count(*) FROM monitoring.actions) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'actions'
          AND con.conname = 'actions_pkey') THEN
        ALTER TABLE ONLY monitoring.actions
    ADD CONSTRAINT actions_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
