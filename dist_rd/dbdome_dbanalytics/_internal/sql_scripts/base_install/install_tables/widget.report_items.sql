-- Idempotent install for widget.report_items
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS widget;

CREATE SEQUENCE IF NOT EXISTS widget.report_items_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS widget.report_items (
    row_id integer NOT NULL,
    title character varying(25) NOT NULL,
    goto character varying(25) NOT NULL,
    icon character varying(25) NOT NULL,
    risk integer DEFAULT 0 NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL,
    report_id integer DEFAULT '-1'::integer NOT NULL
);

ALTER TABLE widget.report_items ALTER COLUMN row_id SET DEFAULT nextval('widget.report_items_row_id_seq'::regclass);
ALTER SEQUENCE widget.report_items_row_id_seq OWNED BY widget.report_items.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE widget.report_items);
COPY _stg_load (row_id, title, goto, icon, risk, entry_date, report_id) FROM stdin;
1	Threats	Connections	ShieldLock	0	2025-04-17 18:46:44.103721	1
2	Regulations	Requests	ShieldLock	0	2025-04-17 18:47:04.306215	1
3	Activity	Audit	ShieldLock	0	2025-04-17 18:47:23.027577	1
\.
INSERT INTO widget.report_items (row_id, title, goto, icon, risk, entry_date, report_id)
SELECT row_id, title, goto, icon, risk, entry_date, report_id FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM widget.report_items);
DROP TABLE _stg_load;

SELECT setval('widget.report_items_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM widget.report_items),1), (SELECT count(*) FROM widget.report_items) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'widget' AND c.relname = 'report_items'
          AND con.conname = 'report_items_pkey') THEN
        ALTER TABLE ONLY widget.report_items
    ADD CONSTRAINT report_items_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
