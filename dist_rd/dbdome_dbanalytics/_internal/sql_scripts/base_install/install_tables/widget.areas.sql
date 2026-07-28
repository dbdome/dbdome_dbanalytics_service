-- Idempotent install for widget.areas
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS widget;

CREATE SEQUENCE IF NOT EXISTS widget.areas_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS widget.areas (
    row_id integer NOT NULL,
    id character(4) NOT NULL,
    domain_id character(4) NOT NULL,
    name character varying(255) NOT NULL,
    icon character varying(50) NOT NULL,
    description text NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL,
    sequence integer DEFAULT '-1'::integer NOT NULL
);

ALTER TABLE widget.areas ALTER COLUMN row_id SET DEFAULT nextval('widget.areas_row_id_seq'::regclass);
ALTER SEQUENCE widget.areas_row_id_seq OWNED BY widget.areas.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE widget.areas);
COPY _stg_load (row_id, id, domain_id, name, icon, description, entry_date, sequence) FROM stdin;
15	a001	d002	Access Control	Key	User permissions, authentication methods, and authorization monitoring	2025-10-22 12:15:12.324756	-1
16	a002	d002	Data Protection	Lock	description": "Encryption, data masking, and sensitive information safeguards	2025-10-22 12:15:12.324756	-1
17	a003	d002	Change Tracking	ClockHistory	Monitoring of database schema, configuration, and permission changes	2025-10-22 12:15:12.324756	-1
18	a004	d002	Compliance	ClipboardCheck	Regulatory compliance status, audit trails, and security policy enforcement	2025-10-22 12:15:12.324756	-1
21	a001	d003	Backup & Recovery	CloudArrowUp	Backup operations, recovery readiness, and data protection strategies	2025-10-22 12:20:49.889744	-1
22	a002	d003	Space Management	HddStack	Database storage allocation, growth trends, and space utilization metrics	2025-10-22 12:20:52.814025	-1
23	a003	d003	High Availability	Shield	Replication, mirroring, clustering, and failover capabilities	2025-10-22 12:21:17.681232	-1
24	a004	d003	Maintenance	Tools	Regular maintenance operations, job scheduling, and database housekeeping tasks	2025-10-22 12:21:21.27301	-1
12	a001	d001	Query Efficiency	Search	Analysis of SQL query performance, optimization, and execution efficiency	2025-10-22 12:15:12.324756	2
13	a002	d001	Resource Usage	Speedometer	Monitoring of CPU, memory, disk, and network resource consumption	2025-10-22 12:15:12.324756	3
25	a005	d001	lock_analysis	Lock	Analysis of locks , lockers and deadlocks	2025-10-24 10:46:05.966571	1
26	a005	d002	Threats	ClockHistory	Threats	2025-11-12 21:43:23.995115	-1
\.
INSERT INTO widget.areas (row_id, id, domain_id, name, icon, description, entry_date, sequence)
SELECT row_id, id, domain_id, name, icon, description, entry_date, sequence FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM widget.areas);
DROP TABLE _stg_load;

SELECT setval('widget.areas_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM widget.areas),1), (SELECT count(*) FROM widget.areas) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'widget' AND c.relname = 'areas'
          AND con.conname = 'pk_areas') THEN
        ALTER TABLE ONLY widget.areas
    ADD CONSTRAINT pk_areas PRIMARY KEY (id, domain_id);
    END IF;
END $do$;
