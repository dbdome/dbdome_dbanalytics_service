-- Idempotent install for metrics.sql_injection_patterns
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS metrics;

CREATE SEQUENCE IF NOT EXISTS metrics.sql_injection_patterns_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS metrics.sql_injection_patterns (
    row_id integer NOT NULL,
    pattern_name character varying(50) NOT NULL,
    pattern_clause character varying(50) NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE metrics.sql_injection_patterns ALTER COLUMN row_id SET DEFAULT nextval('metrics.sql_injection_patterns_row_id_seq'::regclass);
ALTER SEQUENCE metrics.sql_injection_patterns_row_id_seq OWNED BY metrics.sql_injection_patterns.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE metrics.sql_injection_patterns);
COPY _stg_load (row_id, pattern_name, pattern_clause, entry_date) FROM stdin;
1	Always true condition	 OR '1'='1	2025-06-25 07:00:00.222014
2	Multiple queries with comment	; DROP TABLE users;--	2025-06-25 07:00:34.326711
4	Execution od system commands	EXEC xp_cmdshell('dir');	2025-06-25 07:01:20.764298
5	Execution od system commands	shell	2025-06-25 07:01:42.612162
6	Data extraction	UNION all	2025-06-25 07:02:41.721951
7	Bypassing input logic	LIKE '% or = ''	2025-06-25 07:02:41.721951
\.
INSERT INTO metrics.sql_injection_patterns (row_id, pattern_name, pattern_clause, entry_date)
SELECT row_id, pattern_name, pattern_clause, entry_date FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM metrics.sql_injection_patterns);
DROP TABLE _stg_load;

SELECT setval('metrics.sql_injection_patterns_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM metrics.sql_injection_patterns),1), (SELECT count(*) FROM metrics.sql_injection_patterns) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'metrics' AND c.relname = 'sql_injection_patterns'
          AND con.conname = 'sql_injection_patterns_pkey') THEN
        ALTER TABLE ONLY metrics.sql_injection_patterns
    ADD CONSTRAINT sql_injection_patterns_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
