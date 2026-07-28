-- Idempotent install for log.operation_log
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS log;

CREATE SEQUENCE IF NOT EXISTS log.operation_log_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS log.operation_log (
    row_id integer NOT NULL,
    message text NOT NULL,
    level integer DEFAULT 0 NOT NULL,
    routine_name text NOT NULL,
    entry_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    server_name character varying(50)
);

ALTER TABLE log.operation_log ALTER COLUMN row_id SET DEFAULT nextval('log.operation_log_row_id_seq'::regclass);
ALTER SEQUENCE log.operation_log_row_id_seq OWNED BY log.operation_log.row_id;

SELECT setval('log.operation_log_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM log.operation_log),1), (SELECT count(*) FROM log.operation_log) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'log' AND c.relname = 'operation_log'
          AND con.conname = 'operation_log_pkey') THEN
        ALTER TABLE ONLY log.operation_log
    ADD CONSTRAINT operation_log_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS ix_routine_name ON log.operation_log USING btree (routine_name);
