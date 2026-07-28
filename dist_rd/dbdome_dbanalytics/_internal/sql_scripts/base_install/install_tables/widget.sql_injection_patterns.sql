-- Idempotent install for widget.sql_injection_patterns
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS widget;

CREATE SEQUENCE IF NOT EXISTS widget.sql_injection_patterns_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS widget.sql_injection_patterns (
    row_id integer NOT NULL,
    pattern_name character varying(50) NOT NULL,
    pattern_clause character varying(50) NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE widget.sql_injection_patterns ALTER COLUMN row_id SET DEFAULT nextval('widget.sql_injection_patterns_row_id_seq'::regclass);
ALTER SEQUENCE widget.sql_injection_patterns_row_id_seq OWNED BY widget.sql_injection_patterns.row_id;

SELECT setval('widget.sql_injection_patterns_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM widget.sql_injection_patterns),1), (SELECT count(*) FROM widget.sql_injection_patterns) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'widget' AND c.relname = 'sql_injection_patterns'
          AND con.conname = 'sql_injection_patterns_pkey') THEN
        ALTER TABLE ONLY widget.sql_injection_patterns
    ADD CONSTRAINT sql_injection_patterns_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
