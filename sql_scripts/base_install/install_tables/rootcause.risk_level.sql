-- Idempotent install for rootcause.risk_level
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS rootcause;

CREATE SEQUENCE IF NOT EXISTS rootcause.risk_level_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS rootcause.risk_level (
    row_id integer NOT NULL,
    risk_level character(10) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE rootcause.risk_level ALTER COLUMN row_id SET DEFAULT nextval('rootcause.risk_level_row_id_seq'::regclass);
ALTER SEQUENCE rootcause.risk_level_row_id_seq OWNED BY rootcause.risk_level.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE rootcause.risk_level);
COPY _stg_load (row_id, risk_level, is_active, entry_date) FROM stdin;
2	critical  	t	2026-04-13 13:14:03.023711
3	high      	t	2026-04-13 13:14:03.023711
1	medium    	t	2026-04-13 13:14:03.023711
4	low       	t	2026-04-13 13:14:03.023711
\.
INSERT INTO rootcause.risk_level (row_id, risk_level, is_active, entry_date)
SELECT row_id, risk_level, is_active, entry_date FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM rootcause.risk_level);
DROP TABLE _stg_load;

SELECT setval('rootcause.risk_level_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM rootcause.risk_level),1), (SELECT count(*) FROM rootcause.risk_level) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'rootcause' AND c.relname = 'risk_level'
          AND con.conname = 'risk_level_pkey') THEN
        ALTER TABLE ONLY rootcause.risk_level
    ADD CONSTRAINT risk_level_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
