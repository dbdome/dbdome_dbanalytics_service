-- Idempotent install for widget.report_items_indicators_detailfiles
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS widget;

CREATE SEQUENCE IF NOT EXISTS widget.report_items_indicators_detailfiles_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS widget.report_items_indicators_detailfiles (
    row_id integer NOT NULL,
    json_fileid integer NOT NULL,
    report_items_indicators_id integer CONSTRAINT report_items_indicators_det_report_items_indicators_id_not_null NOT NULL,
    widget_id integer NOT NULL,
    date_entry timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE widget.report_items_indicators_detailfiles ALTER COLUMN row_id SET DEFAULT nextval('widget.report_items_indicators_detailfiles_row_id_seq'::regclass);
ALTER SEQUENCE widget.report_items_indicators_detailfiles_row_id_seq OWNED BY widget.report_items_indicators_detailfiles.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE widget.report_items_indicators_detailfiles);
COPY _stg_load (row_id, json_fileid, report_items_indicators_id, widget_id, date_entry) FROM stdin;
1	1	1	1187	2025-04-17 20:18:10.712396
2	2	2	1188	2025-04-17 20:18:19.462583
3	3	3	1189	2025-04-17 20:18:51.236468
4	4	4	1190	2025-04-17 20:18:55.37541
5	5	5	1191	2025-04-17 20:18:55.37541
6	6	6	1192	2025-04-17 20:18:55.37541
7	7	7	1193	2025-04-17 20:19:21.598895
8	8	8	1194	2025-04-17 20:19:21.598895
9	9	9	1195	2025-04-17 20:19:21.598895
10	10	10	1196	2025-04-17 20:19:21.598895
11	11	11	1197	2025-04-17 20:19:21.598895
12	12	12	1198	2025-04-17 20:19:21.598895
13	13	13	1199	2025-04-17 20:19:21.598895
\.
INSERT INTO widget.report_items_indicators_detailfiles (row_id, json_fileid, report_items_indicators_id, widget_id, date_entry)
SELECT row_id, json_fileid, report_items_indicators_id, widget_id, date_entry FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM widget.report_items_indicators_detailfiles);
DROP TABLE _stg_load;

SELECT setval('widget.report_items_indicators_detailfiles_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM widget.report_items_indicators_detailfiles),1), (SELECT count(*) FROM widget.report_items_indicators_detailfiles) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'widget' AND c.relname = 'report_items_indicators_detailfiles'
          AND con.conname = 'report_items_indicators_detailfiles_pkey') THEN
        ALTER TABLE ONLY widget.report_items_indicators_detailfiles
    ADD CONSTRAINT report_items_indicators_detailfiles_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
