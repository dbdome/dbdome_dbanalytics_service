-- Idempotent install for widget.categories_queries
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS widget;

CREATE SEQUENCE IF NOT EXISTS widget.categories_queries_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS widget.categories_queries (
    row_id integer NOT NULL,
    category_id integer NOT NULL,
    query text NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE widget.categories_queries ALTER COLUMN row_id SET DEFAULT nextval('widget.categories_queries_row_id_seq'::regclass);
ALTER SEQUENCE widget.categories_queries_row_id_seq OWNED BY widget.categories_queries.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE widget.categories_queries);
COPY _stg_load (row_id, category_id, query, entry_date) FROM stdin;
2	1	select  * from monitoring.v_duration	2025-11-03 13:57:07.353573
1	71	select  * from monitoring.v_locks	2025-10-30 06:52:31.524582
3	81	select * from monitoring.v_active_transactions	2025-11-12 21:50:38.912973
4	82	select * from monitoring.v_sql_injection	2025-11-12 21:59:34.137344
\.
INSERT INTO widget.categories_queries (row_id, category_id, query, entry_date)
SELECT row_id, category_id, query, entry_date FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM widget.categories_queries);
DROP TABLE _stg_load;

SELECT setval('widget.categories_queries_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM widget.categories_queries),1), (SELECT count(*) FROM widget.categories_queries) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'widget' AND c.relname = 'categories_queries'
          AND con.conname = 'pk_categories_queries') THEN
        ALTER TABLE ONLY widget.categories_queries
    ADD CONSTRAINT pk_categories_queries PRIMARY KEY (category_id);
    END IF;
END $do$;
