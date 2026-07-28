-- Idempotent install for monitoring.alerts_open
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.alerts_open_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.alerts_open (
    row_id integer NOT NULL,
    server character varying(50) NOT NULL,
    transaction_row_id bigint NOT NULL,
    table_name text NOT NULL,
    root_cause character varying(255) NOT NULL,
    issue_id character varying(50) NOT NULL,
    rootcause_number integer NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL,
    state character varying(50) DEFAULT 'open'::character varying NOT NULL,
    query text
);

ALTER TABLE monitoring.alerts_open ALTER COLUMN row_id SET DEFAULT nextval('monitoring.alerts_open_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.alerts_open_row_id_seq OWNED BY monitoring.alerts_open.row_id;

SELECT setval('monitoring.alerts_open_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.alerts_open),1), (SELECT count(*) FROM monitoring.alerts_open) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'alerts_open'
          AND con.conname = 'alerts_open_pkey') THEN
        ALTER TABLE ONLY monitoring.alerts_open
    ADD CONSTRAINT alerts_open_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS ix_root_cause ON monitoring.alerts_open USING btree (root_cause);
CREATE INDEX IF NOT EXISTS ix_state ON monitoring.alerts_open USING btree (state);
