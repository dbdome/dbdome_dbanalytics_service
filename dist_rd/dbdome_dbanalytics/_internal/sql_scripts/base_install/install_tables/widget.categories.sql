-- Idempotent install for widget.categories
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS widget;

CREATE SEQUENCE IF NOT EXISTS widget.categories_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS widget.categories (
    row_id integer NOT NULL,
    domain_id character(4) NOT NULL,
    area_id character(4) NOT NULL,
    id character(4) NOT NULL,
    name character varying(50) NOT NULL,
    icon character varying(50) NOT NULL,
    description text,
    entry_date timestamp without time zone DEFAULT now() NOT NULL,
    main_category character(12),
    sequence integer DEFAULT '-1'::integer NOT NULL
);

ALTER TABLE widget.categories ALTER COLUMN row_id SET DEFAULT nextval('widget.categories_row_id_seq'::regclass);
ALTER SEQUENCE widget.categories_row_id_seq OWNED BY widget.categories.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE widget.categories);
COPY _stg_load (row_id, domain_id, area_id, id, name, icon, description, entry_date, main_category, sequence) FROM stdin;
1	d001	a001	c001	Long Running Queries	Hourglass	Analysis of queries exceeding execution time thresholds	2025-10-23 11:08:33.373534	\N	-1
7	d001	a002	c002	Memory Pressure	Memory	Analysis of memory usage and pressure points	2025-10-23 16:52:41.407639	\N	-1
8	d001	a002	c003	Disk I/O	HddStack	Analysis of disk input/output performance	2025-10-23 17:00:43.489794	\N	-1
9	d001	a002	c004	Network Latency	Diagram3	Analysis of network performance and latency	2025-10-23 17:05:34.374993	\N	-1
10	d001	a002	c005	Buffer Cache Hits	Lightning	Analysis of buffer cache efficiency	2025-10-23 17:16:47.178205	\N	-1
11	d001	a003	c001	Missing Indexes	PlusCircle	Detection of potentially beneficial missing indexes	2025-10-23 17:18:53.964642	\N	-1
12	d001	a003	c003	Index Usage Statistics	BarChart	Analysis of index usage patterns	2025-10-23 17:25:08.36458	\N	-1
13	d001	a003	c002	Index Fragmentation	Puzzle	Analysis of index fragmentation levels	2025-10-23 17:25:27.501592	\N	-1
15	d001	a003	c004	Duplicate Indexes	Files	Detection of redundant indexes	2025-10-23 17:27:22.906632	\N	-1
16	d001	a003	c005	Unused Indexes	Trash	Identification of unused or rarely used indexes	2025-10-23 18:12:56.359228	\N	-1
17	d001	a004	c001	TempDB Performance	Database	Analysis of TempDB efficiency and contention	2025-10-23 18:14:55.284791	\N	-1
18	d001	a004	c003	Locking and Blocking	Lock	Analysis of database locking patterns	2025-10-23 18:22:09.448072	\N	-1
23	d002	a001	c001	Login Attempts	PersonCheck	Analysis of authentication attempts and patterns	2025-10-23 19:56:57.43252	\N	-1
25	d002	a001	c002	Permission Changes	Gear	Tracking of permission and privilege modifications	2025-10-23 20:08:44.349726	\N	-1
26	d002	a001	c003	User/Role Management	People	Analysis of user and role administration activities	2025-10-23 20:16:46.2568	\N	-1
27	d002	a001	c004	Privilege Escalations	ArrowUp	Detection of privilege escalation patterns	2025-10-23 20:19:19.498317	\N	-1
28	d002	a001	c005	Password Policies	Shield	Analysis of password policy compliance	2025-10-23 20:21:20.677156	\N	-1
29	d002	a002	c001	Encryption Status	LockFill	Analysis of database encryption configuration	2025-10-23 20:22:54.556092	\N	-1
30	d002	a002	c002	Sensitive Data Access	EyeFill	Monitoring of sensitive data access patterns	2025-10-23 20:24:30.887899	\N	-1
32	d002	a002	c003	Data Masking	EyeSlash	Analysis of data masking implementation	2025-10-23 20:27:21.363634	\N	-1
33	d002	a002	c004	Certificate Management	FileEarmarkLock	Monitoring of certificate lifecycle	2025-10-23 20:28:53.727915	\N	-1
35	d002	a002	c005	Backup Encryption	CloudLockFill	Analysis of backup encryption status	2025-10-23 20:30:33.959988	\N	-1
36	d002	a003	c001	Schema Changes	Diagram2	Tracking of database schema modifications	2025-10-23 20:32:17.022781	\N	-1
38	d002	a003	c002	Configuration Changes	Gear	Monitoring of system configuration changes	2025-10-23 20:38:48.520767	\N	-1
39	d002	a003	c003	System Object Access	Database	Analysis of system object usage patterns	2025-10-23 20:41:06.405518	\N	-1
40	d002	a003	c004	DDL Triggers	Lightning	Monitoring of DDL trigger activities	2025-10-23 20:42:53.581413	\N	-1
42	d002	a003	c005	Policy Changes	Clipboard	Tracking of security policy modifications	2025-10-23 20:44:46.980588	\N	-1
44	d002	a004	c001	Audit Policy Status	Clipboard2Check	Analysis of audit policy implementation	2025-10-23 20:46:44.225571	\N	-1
46	d002	a004	c002	Security Patches	Shield	Monitoring of security patch status	2025-10-23 20:48:58.335203	\N	-1
48	d002	a004	c003	Regulatory Requirements	FileEarmarkRuled	Analysis of regulatory compliance status	2025-10-23 20:51:13.851795	\N	-1
49	d002	a004	c004	Audit Logs	JournalText	Analysis of audit log content	2025-10-23 20:54:18.292651	\N	-1
51	d002	a004	c005	Security Reports	FileBarGraph	Compilation of security status reports	2025-10-23 20:56:47.9286	\N	-1
52	d003	a001	c001	Backup Status	Check2Circle	Analysis of backup operation success rates	2025-10-23 21:00:13.511552	\N	-1
53	d003	a001	c002	Backup Duration	Stopwatch	Analysis of backup completion times	2025-10-23 21:02:27.081735	\N	-1
54	d003	a001	c003	Last Backup Time	ClockHistory	Tracking of most recent backup timestamps	2025-10-23 21:05:48.256122	\N	-1
55	d003	a001	c004	Recovery Models	Gear	Analysis of database recovery configurations	2025-10-23 21:07:21.934965	\N	-1
56	d003	a001	c005	Log Backup Chain	Link	Validation of transaction log backup sequences	2025-10-23 21:09:53.137636	\N	-1
57	d003	a002	c001	Database Growth	GraphUp	Analysis of database size trends	2025-10-24 09:22:51.865518	\N	-1
58	d003	a002	c002	Log File Usage	FileText	Monitoring of transaction log space utilization	2025-10-24 09:30:09.560632	\N	-1
59	d003	a002	c003	Free Space	HddFill	Analysis of available storage space	2025-10-24 09:33:34.500845	\N	-1
60	d003	a002	c004	Autogrowth Events	ArrowRepeat	Tracking of database autogrowth occurrences	2025-10-24 09:36:15.28172	\N	-1
61	d003	a002	c005	TempDB Usage	Database	Analysis of TempDB space utilization	2025-10-24 09:43:50.213026	\N	-1
62	d003	a003	c001	Replication Latency	Clock	Monitoring of replication lag times	2025-10-24 09:46:05.886227	\N	-1
63	d003	a003	c002	AlwaysOn Health	HeartPulse	Analysis of AlwaysOn availability status	2025-10-24 09:49:37.840283	\N	-1
64	d003	a003	c003	Mirroring Status	ArrowsAngleExpand	Monitoring of database mirroring health	2025-10-24 09:54:05.540747	\N	-1
2	d001	a001	c002	CPU Time per Query	Cpu	Analysis of CPU consumption by queries	2025-10-23 11:23:30.184496	d001a001c001	-1
4	d001	a001	c003	Execution Plan Health	Diagram2	Analysis of query execution plan efficiency	2025-10-23 12:07:43.771083	d001a001c001	-1
5	d001	a001	c004	Parameter Sniffing	Funnel	Detection of parameter sniffing issues	2025-10-23 12:11:35.97614	d001a001c001	-1
6	d001	a001	c005	Query Timeouts	Clock	Analysis of query timeout occurrences	2025-10-23 12:15:00.723246	d001a001c001	-1
65	d003	a003	c004	Failover Events	ExclamationTriangle	Tracking of failover occurrences	2025-10-24 09:58:17.017822	\N	-1
66	d003	a003	c005	Log Shipping Status	Truck	Analysis of log shipping performance	2025-10-24 10:00:19.484892	\N	-1
67	d003	a004	c001	Job Status	Check2All	Monitoring of maintenance job execution	2025-10-24 10:09:27.089626	\N	-1
68	d003	a004	c002	Statistics Updates	BarChart	Tracking of statistics maintenance	2025-10-24 10:11:27.695004	\N	-1
69	d003	a004	c003	DBCC Checks	ShieldCheck	Analysis of database consistency checks	2025-10-24 10:13:14.241344	\N	-1
70	d003	a004	c004	Index Maintenance	ListOl	Tracking of index maintenance operations	2025-10-24 10:19:23.435945	\N	-1
77	d001	a005	c009	condition	Hourglass	Condition is:	2025-10-26 13:36:37.312063	d003a004c005	-1
76	d001	a005	c008	WAIT_TYPE	Hourglass	lock type is:	2025-10-26 13:35:40.083241	d003a004c005	-1
75	d001	a005	c007	TABLE	Hourglass	Table to be locked:	2025-10-25 19:47:34.575804	d003a004c005	-1
72	d001	a005	c006	DELETE	Lock	Lock ocures by delete command	2025-10-24 10:48:55.043374	d003a004c005	-1
73	d001	a005	c005	Lock	Hourglass	Lock occurs on following query:	2025-10-25 16:54:27.400621	d003a004c005	-1
71	d001	a004	c005	Deadlocks and Blocks	Lock	Analysis of deadlock and blocking patterns	2025-10-24 10:22:16.454401	\N	-1
78	d001	a001	c006	TABLE	Hourglass	Query on Table:	2025-11-05 04:15:48.464655	d001a001c001	-1
79	d001	a001	c007	Column	Hourglass	Query on column:	2025-11-05 04:25:32.680745	d001a001c001	-1
80	d001	a001	c008	Missing index on table	Hourglass	Missing index on table:	2025-11-05 04:28:51.682401	d001a001c001	-1
81	d002	a005	c001	Threats	Shield	Threats	2025-11-12 21:46:09.129348	\N	-1
82	d002	a005	c002	SQL injection	Shield	SQL injection	2025-11-12 21:55:19.41981	\N	-1
\.
INSERT INTO widget.categories (row_id, domain_id, area_id, id, name, icon, description, entry_date, main_category, sequence)
SELECT row_id, domain_id, area_id, id, name, icon, description, entry_date, main_category, sequence FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM widget.categories);
DROP TABLE _stg_load;

SELECT setval('widget.categories_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM widget.categories),1), (SELECT count(*) FROM widget.categories) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'widget' AND c.relname = 'categories'
          AND con.conname = 'pk_categories') THEN
        ALTER TABLE ONLY widget.categories
    ADD CONSTRAINT pk_categories PRIMARY KEY (domain_id, area_id, id);
    END IF;
END $do$;
