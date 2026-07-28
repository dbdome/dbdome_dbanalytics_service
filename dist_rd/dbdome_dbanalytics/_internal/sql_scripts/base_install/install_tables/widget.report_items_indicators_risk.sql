-- Idempotent install for widget.report_items_indicators_risk
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS widget;

CREATE SEQUENCE IF NOT EXISTS widget.report_items_indicators_risk_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS widget.report_items_indicators_risk (
    row_id integer NOT NULL,
    report_items_indicator_id integer NOT NULL,
    valuefrom integer NOT NULL,
    valueto integer NOT NULL,
    risk integer NOT NULL,
    date_entry timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE widget.report_items_indicators_risk ALTER COLUMN row_id SET DEFAULT nextval('widget.report_items_indicators_risk_row_id_seq'::regclass);
ALTER SEQUENCE widget.report_items_indicators_risk_row_id_seq OWNED BY widget.report_items_indicators_risk.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE widget.report_items_indicators_risk);
COPY _stg_load (row_id, report_items_indicator_id, valuefrom, valueto, risk, date_entry) FROM stdin;
1	1	0	1	2	2025-04-18 07:14:05.199813
2	1	2	10	1	2025-04-18 07:14:09.706607
3	1	11	99999	0	2025-04-18 07:14:13.522539
4	2	1	99999	2	2025-04-18 07:15:06.258254
5	2	0	0	0	2025-04-18 07:15:06.258254
6	3	0	0	2	2025-04-18 07:15:06.258254
7	3	2	9999	0	2025-04-18 07:15:06.258254
8	3	1	1	1	2025-04-18 07:15:06.258254
9	14	1	9999	2	2025-04-18 07:15:06.258254
10	14	0	0	0	2025-04-18 07:15:06.258254
11	4	0	0	0	2025-04-18 07:15:06.258254
12	4	1	9999	2	2025-04-18 07:15:06.258254
\.
INSERT INTO widget.report_items_indicators_risk (row_id, report_items_indicator_id, valuefrom, valueto, risk, date_entry)
SELECT row_id, report_items_indicator_id, valuefrom, valueto, risk, date_entry FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM widget.report_items_indicators_risk);
DROP TABLE _stg_load;

SELECT setval('widget.report_items_indicators_risk_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM widget.report_items_indicators_risk),1), (SELECT count(*) FROM widget.report_items_indicators_risk) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'widget' AND c.relname = 'report_items_indicators_risk'
          AND con.conname = 'report_items_indicators_risk_pkey') THEN
        ALTER TABLE ONLY widget.report_items_indicators_risk
    ADD CONSTRAINT report_items_indicators_risk_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
