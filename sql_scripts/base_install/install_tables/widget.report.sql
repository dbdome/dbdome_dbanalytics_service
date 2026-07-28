-- Idempotent install for widget.report
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS widget;

CREATE SEQUENCE IF NOT EXISTS widget.report_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS widget.report (
    row_id integer NOT NULL,
    sequence integer NOT NULL,
    item_id integer NOT NULL
);

ALTER TABLE widget.report ALTER COLUMN row_id SET DEFAULT nextval('widget.report_row_id_seq'::regclass);
ALTER SEQUENCE widget.report_row_id_seq OWNED BY widget.report.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE widget.report);
COPY _stg_load (row_id, sequence, item_id) FROM stdin;
1	1	1
2	2	2
3	3	3
\.
INSERT INTO widget.report (row_id, sequence, item_id)
SELECT row_id, sequence, item_id FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM widget.report);
DROP TABLE _stg_load;

SELECT setval('widget.report_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM widget.report),1), (SELECT count(*) FROM widget.report) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'widget' AND c.relname = 'report'
          AND con.conname = 'report_pkey') THEN
        ALTER TABLE ONLY widget.report
    ADD CONSTRAINT report_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
