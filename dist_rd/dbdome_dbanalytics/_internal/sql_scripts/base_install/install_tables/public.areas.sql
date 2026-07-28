-- Idempotent install for public.areas
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS public;

CREATE SEQUENCE IF NOT EXISTS public.areas_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS public.areas (
    id smallint NOT NULL,
    code character varying(10) NOT NULL,
    database_type_id smallint NOT NULL,
    name character varying(100) NOT NULL
);

ALTER TABLE public.areas ALTER COLUMN id SET DEFAULT nextval('public.areas_id_seq'::regclass);
ALTER SEQUENCE public.areas_id_seq OWNED BY public.areas.id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE public.areas);
COPY _stg_load (id, code, database_type_id, name) FROM stdin;
1	QE	1	Query Execution
2	IX	1	Indexing
3	LC	1	Locking & Concurrency
4	CPU	1	CPU
5	MEM	1	Memory
6	IO	1	I/O
7	CN	1	Connection Management
8	CE	1	Consistency & Errors
9	PL	1	Partitioning & Large Tables
10	TX	1	Transactions
11	VS	1	Vector Search
12	BR	1	Backup & Recovery
13	RP	1	Resource Pooling
14	SM	1	Schema Management
15	HA	1	High Availability
16	DM	1	Data Modeling
17	LM	1	Lock Management
18	SJ	1	Schema & JSON
19	UP	1	Upgrades
20	CD	1	Change Detection
21	AD	1	Application & Driver
22	AU	1	Authentication
23	AZ	1	Authorization
24	ENC	1	Encryption
25	AUD	1	Auditing
26	NET	1	Networking
27	CFG	1	Configuration
28	INJ	1	Injection & Exploits
29	PAT	1	Patterns
30	PRI	1	Priority & Scheduling
31	QRY	2	Queries
32	IDX	2	Indexing
33	DOC	2	Document Operations
34	SHD	2	Sharding
35	CON	2	Consistency
36	MEM	2	Memory
37	WRT	2	Write Operations
38	BAK	2	Backup & Recovery
39	REP	2	Replication
40	STG	2	Storage
41	HA	2	High Availability
42	CLU	2	Clustering
43	MNT	2	Maintenance
44	LOG	2	Logging
45	UPG	2	Upgrades
46	AUTH	2	Authentication
47	AUTHZ	2	Authorization
48	ENC	2	Encryption
49	AUD	2	Auditing
50	NET	2	Networking
51	INJ	2	Injection & Exploits
52	DAT	2	Data Modeling
53	KEY	3	Key Management
54	MEM	3	Memory
55	EVICT	3	Eviction
56	THRU	3	Throughput
57	LAT	3	Latency
58	CONN	3	Connection Management
59	DATA	3	Data Management
60	CLUST	3	Clustering
61	PUBSUB	3	Pub/Sub
62	TTL	3	TTL & Expiry
63	PERS	3	Persistence
64	REP	3	Replication
65	TOPO	3	Topology
66	STOR	3	Storage
67	BACKUP	3	Backup & Recovery
68	HA	3	High Availability
69	MAINT	3	Maintenance
70	UPGR	3	Upgrades
71	AUTH	3	Authentication
72	AUTHZ	3	Authorization
73	NET	3	Networking
74	ENC	3	Encryption
75	CMD	3	Commands
76	INJ	3	Injection & Exploits
77	AUDIT	3	Auditing
78	IDX	4	Indexing
79	QRY	4	Queries
80	ING	4	Ingestion
81	MEM	4	Memory
82	DIM	4	Dimensionality
83	OPT	4	Optimization
84	HYB	4	Hybrid Search
85	SCL	4	Scalability
86	STG	4	Storage
87	REP	4	Replication
88	BKP	4	Backup & Recovery
89	RES	4	Resource Management
90	MNT	4	Maintenance
91	UPG	4	Upgrades
92	INT	4	Integration
93	SYS	4	System
94	AUTH	4	Authentication
95	ACC	4	Access Control
96	DAT	4	Data Modeling
97	ATK	4	Attack Prevention
98	NET	4	Networking
99	LOG	4	Logging
\.
INSERT INTO public.areas (id, code, database_type_id, name)
SELECT id, code, database_type_id, name FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM public.areas);
DROP TABLE _stg_load;

SELECT setval('public.areas_id_seq', GREATEST((SELECT COALESCE(max(id),0) FROM public.areas),1), (SELECT count(*) FROM public.areas) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'areas'
          AND con.conname = 'areas_code_database_type_id_key') THEN
        ALTER TABLE ONLY public.areas
    ADD CONSTRAINT areas_code_database_type_id_key UNIQUE (code, database_type_id);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'areas'
          AND con.conname = 'areas_pkey') THEN
        ALTER TABLE ONLY public.areas
    ADD CONSTRAINT areas_pkey PRIMARY KEY (id);
    END IF;
END $do$;
