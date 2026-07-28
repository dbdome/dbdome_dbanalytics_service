-- Idempotent install for widget.indicators
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS widget;

CREATE SEQUENCE IF NOT EXISTS widget.indicators_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS widget.indicators (
    row_id integer NOT NULL,
    form_section_id integer NOT NULL,
    label character varying(255),
    risk character varying(255),
    icon character varying(255),
    goto character varying(255)
);

ALTER TABLE widget.indicators ALTER COLUMN row_id SET DEFAULT nextval('widget.indicators_row_id_seq'::regclass);
ALTER SEQUENCE widget.indicators_row_id_seq OWNED BY widget.indicators.row_id;

SELECT setval('widget.indicators_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM widget.indicators),1), (SELECT count(*) FROM widget.indicators) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'widget' AND c.relname = 'indicators'
          AND con.conname = 'indicators_pkey') THEN
        ALTER TABLE ONLY widget.indicators
    ADD CONSTRAINT indicators_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
