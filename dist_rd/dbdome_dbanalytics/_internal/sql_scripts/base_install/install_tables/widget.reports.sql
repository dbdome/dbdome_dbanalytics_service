-- Idempotent install for widget.reports
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS widget;

CREATE SEQUENCE IF NOT EXISTS widget.reports_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS widget.reports (
    row_id integer NOT NULL,
    file_name character varying(255) NOT NULL,
    file_path text NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE widget.reports ALTER COLUMN row_id SET DEFAULT nextval('widget.reports_row_id_seq'::regclass);
ALTER SEQUENCE widget.reports_row_id_seq OWNED BY widget.reports.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE widget.reports);
COPY _stg_load (row_id, file_name, file_path, entry_date) FROM stdin;
1	Reports.JSON	C:\\home\\dbdome\\DBDOME\\uptime	2025-06-23 17:31:16.094321
\.
INSERT INTO widget.reports (row_id, file_name, file_path, entry_date)
SELECT row_id, file_name, file_path, entry_date FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM widget.reports);
DROP TABLE _stg_load;

SELECT setval('widget.reports_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM widget.reports),1), (SELECT count(*) FROM widget.reports) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'widget' AND c.relname = 'reports'
          AND con.conname = 'reports_pkey') THEN
        ALTER TABLE ONLY widget.reports
    ADD CONSTRAINT reports_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
