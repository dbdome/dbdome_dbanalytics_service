-- Idempotent install for processes.organizations_servers
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS processes;

CREATE SEQUENCE IF NOT EXISTS processes.organizations_servers_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS processes.organizations_servers (
    row_id integer NOT NULL,
    organization_id integer NOT NULL,
    server_row_id integer NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE processes.organizations_servers ALTER COLUMN row_id SET DEFAULT nextval('processes.organizations_servers_row_id_seq'::regclass);
ALTER SEQUENCE processes.organizations_servers_row_id_seq OWNED BY processes.organizations_servers.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE processes.organizations_servers);
COPY _stg_load (row_id, organization_id, server_row_id, entry_date) FROM stdin;
1	1	13	2026-04-02 19:24:10.575869
2	1	18	2026-04-02 19:24:10.575869
3	1	19	2026-04-02 19:24:10.575869
4	1	20	2026-04-02 19:24:10.575869
5	1	21	2026-04-02 19:24:10.575869
6	1	22	2026-04-02 19:24:10.575869
7	1	23	2026-04-02 19:24:10.575869
8	1	24	2026-04-02 19:24:10.575869
9	1	25	2026-04-02 19:24:10.575869
10	1	26	2026-04-02 19:24:10.575869
11	1	27	2026-04-02 19:24:10.575869
12	1	28	2026-04-02 19:24:10.575869
13	1	29	2026-04-02 19:24:10.575869
14	1	30	2026-04-02 19:24:10.575869
15	1	31	2026-04-02 19:24:10.575869
16	1	32	2026-04-02 22:56:59.090944
17	1	33	2026-04-02 22:56:59.090944
18	1	34	2026-04-02 22:56:59.090944
\.
INSERT INTO processes.organizations_servers (row_id, organization_id, server_row_id, entry_date)
SELECT row_id, organization_id, server_row_id, entry_date FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM processes.organizations_servers);
DROP TABLE _stg_load;

SELECT setval('processes.organizations_servers_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM processes.organizations_servers),1), (SELECT count(*) FROM processes.organizations_servers) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'processes' AND c.relname = 'organizations_servers'
          AND con.conname = 'pk_organizations_servers') THEN
        ALTER TABLE ONLY processes.organizations_servers
    ADD CONSTRAINT pk_organizations_servers PRIMARY KEY (organization_id, server_row_id);
    END IF;
END $do$;
