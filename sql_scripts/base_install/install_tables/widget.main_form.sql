-- Idempotent install for widget.main_form
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS widget;

CREATE SEQUENCE IF NOT EXISTS widget.main_form_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS widget.main_form (
    row_id integer NOT NULL,
    form_name character varying(255),
    form_location character varying(255)
);

ALTER TABLE widget.main_form ALTER COLUMN row_id SET DEFAULT nextval('widget.main_form_row_id_seq'::regclass);
ALTER SEQUENCE widget.main_form_row_id_seq OWNED BY widget.main_form.row_id;

SELECT setval('widget.main_form_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM widget.main_form),1), (SELECT count(*) FROM widget.main_form) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'widget' AND c.relname = 'main_form'
          AND con.conname = 'main_form_pkey') THEN
        ALTER TABLE ONLY widget.main_form
    ADD CONSTRAINT main_form_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
