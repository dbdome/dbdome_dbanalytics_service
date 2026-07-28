-- Idempotent install for widget.categories_queries_columns
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS widget;

CREATE SEQUENCE IF NOT EXISTS widget.categories_queries_columns_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS widget.categories_queries_columns (
    row_id integer NOT NULL,
    query_id integer NOT NULL,
    column_name character varying(50) NOT NULL,
    category_id integer NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE widget.categories_queries_columns ALTER COLUMN row_id SET DEFAULT nextval('widget.categories_queries_columns_row_id_seq'::regclass);
ALTER SEQUENCE widget.categories_queries_columns_row_id_seq OWNED BY widget.categories_queries_columns.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE widget.categories_queries_columns);
COPY _stg_load (row_id, query_id, column_name, category_id, entry_date) FROM stdin;
1	1	query	73	2025-10-30 07:30:08.86291
2	1	command	72	2025-10-30 07:30:54.092591
3	1	tables	75	2025-10-30 07:31:38.125343
4	1	wait_type	76	2025-10-30 07:35:09.7393
5	1	condition	77	2025-10-30 07:35:27.056668
6	2	query	1	2025-11-05 04:50:34.27853
7	2	cpu_time	2	2025-11-05 04:58:48.693906
8	2	tables	78	2025-11-05 04:59:15.610889
9	2	columns	79	2025-11-05 04:59:47.518009
\.
INSERT INTO widget.categories_queries_columns (row_id, query_id, column_name, category_id, entry_date)
SELECT row_id, query_id, column_name, category_id, entry_date FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM widget.categories_queries_columns);
DROP TABLE _stg_load;

SELECT setval('widget.categories_queries_columns_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM widget.categories_queries_columns),1), (SELECT count(*) FROM widget.categories_queries_columns) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'widget' AND c.relname = 'categories_queries_columns'
          AND con.conname = 'pk_categories_queries_columns') THEN
        ALTER TABLE ONLY widget.categories_queries_columns
    ADD CONSTRAINT pk_categories_queries_columns PRIMARY KEY (query_id, column_name);
    END IF;
END $do$;
