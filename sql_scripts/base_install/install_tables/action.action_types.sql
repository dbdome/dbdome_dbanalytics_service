-- Idempotent install for action.action_types
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS action;

CREATE SEQUENCE IF NOT EXISTS action.action_types_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS action.action_types (
    row_id integer NOT NULL,
    action_type character varying(50) NOT NULL,
    entry_date timestamp without time zone NOT NULL
);

ALTER TABLE action.action_types ALTER COLUMN row_id SET DEFAULT nextval('action.action_types_row_id_seq'::regclass);
ALTER SEQUENCE action.action_types_row_id_seq OWNED BY action.action_types.row_id;

SELECT setval('action.action_types_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM action.action_types),1), (SELECT count(*) FROM action.action_types) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'action' AND c.relname = 'action_types'
          AND con.conname = 'pk_action_types') THEN
        ALTER TABLE ONLY action.action_types
    ADD CONSTRAINT pk_action_types PRIMARY KEY (action_type);
    END IF;
END $do$;
