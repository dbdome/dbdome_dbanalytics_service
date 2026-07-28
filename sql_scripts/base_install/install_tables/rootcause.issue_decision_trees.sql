-- Idempotent install for rootcause.issue_decision_trees
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS rootcause;

CREATE SEQUENCE IF NOT EXISTS rootcause.issue_decision_trees_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS rootcause.issue_decision_trees (
    id integer NOT NULL,
    issue_id character varying(30) NOT NULL,
    vendor_slug character varying(50) NOT NULL,
    name text NOT NULL,
    description text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE rootcause.issue_decision_trees ALTER COLUMN id SET DEFAULT nextval('rootcause.issue_decision_trees_id_seq'::regclass);
ALTER SEQUENCE rootcause.issue_decision_trees_id_seq OWNED BY rootcause.issue_decision_trees.id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE rootcause.issue_decision_trees);
COPY _stg_load (id, issue_id, vendor_slug, name, description, is_active, created_at, updated_at) FROM stdin;
42	SEC-SQL-PRI-011	oracle	SEC-SQL-PRI-011 triage (oracle)	PPL 1981 detection-tree for SEC-SQL-PRI-011 on oracle	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
43	SEC-SQL-PRI-011	postgresql	SEC-SQL-PRI-011 triage (postgresql)	PPL 1981 detection-tree for SEC-SQL-PRI-011 on postgresql	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
1	PERF-SQL-QE-001	sqlserver	Slow Query Execution — triage tree (sqlserver)	Cheap signals first, branch to expensive checks only when path is plausible. T1 paths terminate on match.	t	2026-05-01 09:27:49.914889+03	2026-05-01 10:16:22.835593+03
5	SEC-SQL-PRI-001	sqlserver	PII Exposed in Clear Text — triage tree (sqlserver)	Foundation gate (T1.1) rules out entire issue if no sensitive columns exist. Then active-exposure (T2), encryption gaps (T3), operational (T4), policy/org (T5).	t	2026-05-01 11:16:00.523172+03	2026-05-01 11:16:00.523172+03
6	SEC-SQL-PRI-001	oracle	PII Exposed in Clear Text — triage tree (oracle)	Foundation gate (T1.1) rules out entire issue if no sensitive columns. Mirrors sqlserver tree structure.	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
7	SEC-SQL-PRI-001	postgresql	PII Exposed in Clear Text — triage tree (postgresql)	Foundation gate (T1.1) rules out entire issue if no sensitive columns. Mirrors sqlserver tree structure.	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
8	SEC-SQL-PRI-001	mysql	PII Exposed in Clear Text — triage tree (mysql)	Foundation gate (T1.1) rules out entire issue if no sensitive columns. Mirrors sqlserver tree structure.	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
9	SEC-SQL-PRI-003	sqlserver	SEC-SQL-PRI-003 triage (sqlserver)	PPL 1981 detection-tree for SEC-SQL-PRI-003 on sqlserver	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
10	SEC-SQL-PRI-003	oracle	SEC-SQL-PRI-003 triage (oracle)	PPL 1981 detection-tree for SEC-SQL-PRI-003 on oracle	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
11	SEC-SQL-PRI-003	postgresql	SEC-SQL-PRI-003 triage (postgresql)	PPL 1981 detection-tree for SEC-SQL-PRI-003 on postgresql	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
12	SEC-SQL-PRI-003	mysql	SEC-SQL-PRI-003 triage (mysql)	PPL 1981 detection-tree for SEC-SQL-PRI-003 on mysql	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
13	SEC-SQL-PRI-004	sqlserver	SEC-SQL-PRI-004 triage (sqlserver)	PPL 1981 detection-tree for SEC-SQL-PRI-004 on sqlserver	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
14	SEC-SQL-PRI-004	oracle	SEC-SQL-PRI-004 triage (oracle)	PPL 1981 detection-tree for SEC-SQL-PRI-004 on oracle	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
15	SEC-SQL-PRI-004	postgresql	SEC-SQL-PRI-004 triage (postgresql)	PPL 1981 detection-tree for SEC-SQL-PRI-004 on postgresql	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
16	SEC-SQL-PRI-004	mysql	SEC-SQL-PRI-004 triage (mysql)	PPL 1981 detection-tree for SEC-SQL-PRI-004 on mysql	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
17	SEC-SQL-PRI-005	sqlserver	SEC-SQL-PRI-005 triage (sqlserver)	PPL 1981 detection-tree for SEC-SQL-PRI-005 on sqlserver	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
18	SEC-SQL-PRI-005	oracle	SEC-SQL-PRI-005 triage (oracle)	PPL 1981 detection-tree for SEC-SQL-PRI-005 on oracle	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
19	SEC-SQL-PRI-005	postgresql	SEC-SQL-PRI-005 triage (postgresql)	PPL 1981 detection-tree for SEC-SQL-PRI-005 on postgresql	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
20	SEC-SQL-PRI-005	mysql	SEC-SQL-PRI-005 triage (mysql)	PPL 1981 detection-tree for SEC-SQL-PRI-005 on mysql	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
21	SEC-SQL-PRI-006	sqlserver	SEC-SQL-PRI-006 triage (sqlserver)	PPL 1981 detection-tree for SEC-SQL-PRI-006 on sqlserver	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
22	SEC-SQL-PRI-006	oracle	SEC-SQL-PRI-006 triage (oracle)	PPL 1981 detection-tree for SEC-SQL-PRI-006 on oracle	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
23	SEC-SQL-PRI-006	postgresql	SEC-SQL-PRI-006 triage (postgresql)	PPL 1981 detection-tree for SEC-SQL-PRI-006 on postgresql	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
24	SEC-SQL-PRI-006	mysql	SEC-SQL-PRI-006 triage (mysql)	PPL 1981 detection-tree for SEC-SQL-PRI-006 on mysql	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
25	SEC-SQL-PRI-007	sqlserver	SEC-SQL-PRI-007 triage (sqlserver)	PPL 1981 detection-tree for SEC-SQL-PRI-007 on sqlserver	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
26	SEC-SQL-PRI-007	oracle	SEC-SQL-PRI-007 triage (oracle)	PPL 1981 detection-tree for SEC-SQL-PRI-007 on oracle	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
27	SEC-SQL-PRI-007	postgresql	SEC-SQL-PRI-007 triage (postgresql)	PPL 1981 detection-tree for SEC-SQL-PRI-007 on postgresql	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
28	SEC-SQL-PRI-007	mysql	SEC-SQL-PRI-007 triage (mysql)	PPL 1981 detection-tree for SEC-SQL-PRI-007 on mysql	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
29	SEC-SQL-PRI-008	sqlserver	SEC-SQL-PRI-008 triage (sqlserver)	PPL 1981 detection-tree for SEC-SQL-PRI-008 on sqlserver	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
30	SEC-SQL-PRI-008	oracle	SEC-SQL-PRI-008 triage (oracle)	PPL 1981 detection-tree for SEC-SQL-PRI-008 on oracle	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
31	SEC-SQL-PRI-008	postgresql	SEC-SQL-PRI-008 triage (postgresql)	PPL 1981 detection-tree for SEC-SQL-PRI-008 on postgresql	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
32	SEC-SQL-PRI-008	mysql	SEC-SQL-PRI-008 triage (mysql)	PPL 1981 detection-tree for SEC-SQL-PRI-008 on mysql	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
33	SEC-SQL-PRI-009	sqlserver	SEC-SQL-PRI-009 triage (sqlserver)	PPL 1981 detection-tree for SEC-SQL-PRI-009 on sqlserver	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
34	SEC-SQL-PRI-009	oracle	SEC-SQL-PRI-009 triage (oracle)	PPL 1981 detection-tree for SEC-SQL-PRI-009 on oracle	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
35	SEC-SQL-PRI-009	postgresql	SEC-SQL-PRI-009 triage (postgresql)	PPL 1981 detection-tree for SEC-SQL-PRI-009 on postgresql	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
36	SEC-SQL-PRI-009	mysql	SEC-SQL-PRI-009 triage (mysql)	PPL 1981 detection-tree for SEC-SQL-PRI-009 on mysql	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
37	SEC-SQL-PRI-010	sqlserver	SEC-SQL-PRI-010 triage (sqlserver)	PPL 1981 detection-tree for SEC-SQL-PRI-010 on sqlserver	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
38	SEC-SQL-PRI-010	oracle	SEC-SQL-PRI-010 triage (oracle)	PPL 1981 detection-tree for SEC-SQL-PRI-010 on oracle	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
39	SEC-SQL-PRI-010	postgresql	SEC-SQL-PRI-010 triage (postgresql)	PPL 1981 detection-tree for SEC-SQL-PRI-010 on postgresql	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
40	SEC-SQL-PRI-010	mysql	SEC-SQL-PRI-010 triage (mysql)	PPL 1981 detection-tree for SEC-SQL-PRI-010 on mysql	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
41	SEC-SQL-PRI-011	sqlserver	SEC-SQL-PRI-011 triage (sqlserver)	PPL 1981 detection-tree for SEC-SQL-PRI-011 on sqlserver	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
44	SEC-SQL-PRI-011	mysql	SEC-SQL-PRI-011 triage (mysql)	PPL 1981 detection-tree for SEC-SQL-PRI-011 on mysql	t	2026-05-01 11:29:34.575665+03	2026-05-01 11:29:34.575665+03
\.
INSERT INTO rootcause.issue_decision_trees (id, issue_id, vendor_slug, name, description, is_active, created_at, updated_at)
SELECT id, issue_id, vendor_slug, name, description, is_active, created_at, updated_at FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM rootcause.issue_decision_trees);
DROP TABLE _stg_load;

SELECT setval('rootcause.issue_decision_trees_id_seq', GREATEST((SELECT COALESCE(max(id),0) FROM rootcause.issue_decision_trees),1), (SELECT count(*) FROM rootcause.issue_decision_trees) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'rootcause' AND c.relname = 'issue_decision_trees'
          AND con.conname = 'issue_decision_trees_issue_id_vendor_slug_key') THEN
        ALTER TABLE ONLY rootcause.issue_decision_trees
    ADD CONSTRAINT issue_decision_trees_issue_id_vendor_slug_key UNIQUE (issue_id, vendor_slug);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'rootcause' AND c.relname = 'issue_decision_trees'
          AND con.conname = 'issue_decision_trees_pkey') THEN
        ALTER TABLE ONLY rootcause.issue_decision_trees
    ADD CONSTRAINT issue_decision_trees_pkey PRIMARY KEY (id);
    END IF;
END $do$;
