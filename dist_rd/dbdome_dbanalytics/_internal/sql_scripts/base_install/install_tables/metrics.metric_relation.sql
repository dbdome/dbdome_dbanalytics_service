-- Idempotent install for metrics.metric_relation
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS metrics;

CREATE SEQUENCE IF NOT EXISTS metrics.metric_relation_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS metrics.metric_relation (
    row_id integer NOT NULL,
    metric_type_id integer NOT NULL,
    metric_id integer NOT NULL,
    sequence integer NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE metrics.metric_relation ALTER COLUMN row_id SET DEFAULT nextval('metrics.metric_relation_row_id_seq'::regclass);
ALTER SEQUENCE metrics.metric_relation_row_id_seq OWNED BY metrics.metric_relation.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE metrics.metric_relation);
COPY _stg_load (row_id, metric_type_id, metric_id, sequence, entry_date) FROM stdin;
13	2	99	2	2025-04-21 21:27:40.066167
16	2	102	3	2025-04-21 21:27:40.066167
18	2	103	4	2025-04-21 21:27:40.066167
19	2	104	5	2025-04-21 21:27:40.066167
21	2	105	6	2025-04-21 21:27:40.066167
28	2	108	7	2025-04-21 21:27:40.066167
31	2	113	9	2025-04-21 21:27:40.066167
32	2	114	9	2025-04-21 21:27:40.066167
33	2	115	10	2025-04-21 21:27:40.066167
34	2	116	11	2025-04-21 21:27:40.066167
35	2	117	12	2025-04-21 21:27:40.066167
36	2	118	13	2025-04-21 21:27:40.066167
14	3	100	1	2025-04-21 21:27:40.066167
15	3	101	2	2025-04-21 21:27:40.066167
29	3	110	7	2025-04-21 21:27:40.066167
30	3	111	8	2025-04-21 21:27:40.066167
2	4	98	1	2025-04-21 21:27:40.066167
\.
INSERT INTO metrics.metric_relation (row_id, metric_type_id, metric_id, sequence, entry_date)
SELECT row_id, metric_type_id, metric_id, sequence, entry_date FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM metrics.metric_relation);
DROP TABLE _stg_load;

SELECT setval('metrics.metric_relation_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM metrics.metric_relation),1), (SELECT count(*) FROM metrics.metric_relation) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'metrics' AND c.relname = 'metric_relation'
          AND con.conname = 'metric_relation_pkey') THEN
        ALTER TABLE ONLY metrics.metric_relation
    ADD CONSTRAINT metric_relation_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
