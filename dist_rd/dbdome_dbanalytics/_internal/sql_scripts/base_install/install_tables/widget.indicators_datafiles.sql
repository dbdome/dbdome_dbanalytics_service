-- Idempotent install for widget.indicators_datafiles
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS widget;

CREATE SEQUENCE IF NOT EXISTS widget.indicators_datafiles_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS widget.indicators_datafiles (
    row_id integer NOT NULL,
    indicator_id integer NOT NULL,
    json_file_name character varying(255) NOT NULL
);

ALTER TABLE widget.indicators_datafiles ALTER COLUMN row_id SET DEFAULT nextval('widget.indicators_datafiles_row_id_seq'::regclass);
ALTER SEQUENCE widget.indicators_datafiles_row_id_seq OWNED BY widget.indicators_datafiles.row_id;

SELECT setval('widget.indicators_datafiles_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM widget.indicators_datafiles),1), (SELECT count(*) FROM widget.indicators_datafiles) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'widget' AND c.relname = 'indicators_datafiles'
          AND con.conname = 'indicators_datafiles_pkey') THEN
        ALTER TABLE ONLY widget.indicators_datafiles
    ADD CONSTRAINT indicators_datafiles_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
