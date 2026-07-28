-- Idempotent install for widget.domains
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS widget;

CREATE SEQUENCE IF NOT EXISTS widget.domains_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS widget.domains (
    row_id integer NOT NULL,
    id character(4) NOT NULL,
    name character varying(50) NOT NULL,
    icon character varying(50) NOT NULL,
    description text NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE widget.domains ALTER COLUMN row_id SET DEFAULT nextval('widget.domains_row_id_seq'::regclass);
ALTER SEQUENCE widget.domains_row_id_seq OWNED BY widget.domains.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE widget.domains);
COPY _stg_load (row_id, id, name, icon, description, entry_date) FROM stdin;
1	d001	Performance	Speedometer	Metrics and analysis related to database speed, efficiency, and resource utilization	2025-10-22 07:55:47.030448
2	d002	Security	ShieldCheck	Metrics related to database protection, access controls, and vulnerability management	2025-10-22 07:55:47.030448
3	d003	Health	Activity	Metrics for overall database system health, reliability, and operational stability	2025-10-22 07:55:47.030448
\.
INSERT INTO widget.domains (row_id, id, name, icon, description, entry_date)
SELECT row_id, id, name, icon, description, entry_date FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM widget.domains);
DROP TABLE _stg_load;

SELECT setval('widget.domains_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM widget.domains),1), (SELECT count(*) FROM widget.domains) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'widget' AND c.relname = 'domains'
          AND con.conname = 'pk_domains') THEN
        ALTER TABLE ONLY widget.domains
    ADD CONSTRAINT pk_domains PRIMARY KEY (id);
    END IF;
END $do$;
