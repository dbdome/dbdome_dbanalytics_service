-- Idempotent install for monitoring.server_hardening_unused_inactive_sql_server_logins
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.server_hardening_unused_inactive_sql_server_logins_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.server_hardening_unused_inactive_sql_server_logins (
    row_id integer CONSTRAINT server_hardening_unused_inactive_sql_server_log_row_id_not_null NOT NULL,
    server character varying(50),
    loginname character varying(50),
    createddate timestamp without time zone,
    lastmodifieddate timestamp without time zone,
    lastlogintime timestamp without time zone,
    entry_date timestamp without time zone DEFAULT now() CONSTRAINT server_hardening_unused_inactive_sql_server_entry_date_not_null NOT NULL
);

ALTER TABLE monitoring.server_hardening_unused_inactive_sql_server_logins ALTER COLUMN row_id SET DEFAULT nextval('monitoring.server_hardening_unused_inactive_sql_server_logins_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.server_hardening_unused_inactive_sql_server_logins_row_id_seq OWNED BY monitoring.server_hardening_unused_inactive_sql_server_logins.row_id;

SELECT setval('monitoring.server_hardening_unused_inactive_sql_server_logins_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.server_hardening_unused_inactive_sql_server_logins),1), (SELECT count(*) FROM monitoring.server_hardening_unused_inactive_sql_server_logins) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'server_hardening_unused_inactive_sql_server_logins'
          AND con.conname = 'server_hardening_unused_inactive_sql_server_logins_pkey') THEN
        ALTER TABLE ONLY monitoring.server_hardening_unused_inactive_sql_server_logins
    ADD CONSTRAINT server_hardening_unused_inactive_sql_server_logins_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
