-- Idempotent install for public.report_items_indicators_detailfiles
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS public;

CREATE SEQUENCE IF NOT EXISTS public.report_items_indicators_detailfiles_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS public.report_items_indicators_detailfiles (
    row_id integer NOT NULL,
    json_fileid integer NOT NULL,
    report_items_indicators_id integer CONSTRAINT report_items_indicators_det_report_items_indicators_id_not_null NOT NULL,
    widget_id integer NOT NULL,
    date_entry timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.report_items_indicators_detailfiles ALTER COLUMN row_id SET DEFAULT nextval('public.report_items_indicators_detailfiles_row_id_seq'::regclass);
ALTER SEQUENCE public.report_items_indicators_detailfiles_row_id_seq OWNED BY public.report_items_indicators_detailfiles.row_id;

SELECT setval('public.report_items_indicators_detailfiles_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM public.report_items_indicators_detailfiles),1), (SELECT count(*) FROM public.report_items_indicators_detailfiles) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'report_items_indicators_detailfiles'
          AND con.conname = 'report_items_indicators_detailfiles_pkey') THEN
        ALTER TABLE ONLY public.report_items_indicators_detailfiles
    ADD CONSTRAINT report_items_indicators_detailfiles_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
