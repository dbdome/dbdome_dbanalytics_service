-- Idempotent install for monitoring.service_account_permissions
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.service_account_permissions_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.service_account_permissions (
    row_id integer NOT NULL,
    server character varying(50),
    servicename character varying(50),
    startup_type_desc character varying(50),
    service_account character varying(50),
    entry_date timestamp without time zone NOT NULL
);

ALTER TABLE monitoring.service_account_permissions ALTER COLUMN row_id SET DEFAULT nextval('monitoring.service_account_permissions_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.service_account_permissions_row_id_seq OWNED BY monitoring.service_account_permissions.row_id;

SELECT setval('monitoring.service_account_permissions_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.service_account_permissions),1), (SELECT count(*) FROM monitoring.service_account_permissions) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'service_account_permissions'
          AND con.conname = 'service_account_permissions_pkey') THEN
        ALTER TABLE ONLY monitoring.service_account_permissions
    ADD CONSTRAINT service_account_permissions_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
