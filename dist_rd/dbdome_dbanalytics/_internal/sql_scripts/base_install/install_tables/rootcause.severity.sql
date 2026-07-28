-- Idempotent install for rootcause.severity
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS rootcause;

CREATE SEQUENCE IF NOT EXISTS rootcause.severity_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS rootcause.severity (
    row_id integer NOT NULL,
    severity text NOT NULL,
    is_enabled boolean DEFAULT true
);

ALTER TABLE rootcause.severity ALTER COLUMN row_id SET DEFAULT nextval('rootcause.severity_row_id_seq'::regclass);
ALTER SEQUENCE rootcause.severity_row_id_seq OWNED BY rootcause.severity.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE rootcause.severity);
COPY _stg_load (row_id, severity, is_enabled) FROM stdin;
1	critical	t
2	high	f
3	low	f
4	medium	f
\.
INSERT INTO rootcause.severity (row_id, severity, is_enabled)
SELECT row_id, severity, is_enabled FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM rootcause.severity);
DROP TABLE _stg_load;

SELECT setval('rootcause.severity_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM rootcause.severity),1), (SELECT count(*) FROM rootcause.severity) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'rootcause' AND c.relname = 'severity'
          AND con.conname = 'severity_pkey') THEN
        ALTER TABLE ONLY rootcause.severity
    ADD CONSTRAINT severity_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
