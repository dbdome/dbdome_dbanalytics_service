-- Idempotent install for widget.category_detailfiles
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS widget;

CREATE SEQUENCE IF NOT EXISTS widget.category_detailfiles_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS widget.category_detailfiles (
    row_id integer NOT NULL,
    category_row_id integer NOT NULL,
    detailfile character varying(255) NOT NULL
);

ALTER TABLE widget.category_detailfiles ALTER COLUMN row_id SET DEFAULT nextval('widget.category_detailfiles_row_id_seq'::regclass);
ALTER SEQUENCE widget.category_detailfiles_row_id_seq OWNED BY widget.category_detailfiles.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE widget.category_detailfiles);
COPY _stg_load (row_id, category_row_id, detailfile) FROM stdin;
1	1	long_procedures.json
2	1	avg_duration_procedures.json
3	2	High_CPU_consuming_procedures.json
5	2	ad_hoc_cpu_cunsuming_queries.json
6	3	Query_execution_stats.json
7	3	execution_plans.json
8	4	parameter_sniffing.json
9	5	query_timeouts.json
10	7	OS_MEMORY.json
11	7	OS_PROCESS_MEMORY.json
12	8	Aggregate_IO_STATS.json
13	8	pending_io_requests.json
14	9	Latency.json
15	9	Network_io.json
16	10	Cache_Ratio.json
17	10	BufferManager.json
18	11	missing_indexes.json
19	13	index_usage_stats.json
20	12	index_fragmentation.json
21	15	duplicate_indexes.json
22	16	UnusedINDEXES.json
23	17	TEMPDBUSED.json
25	17	TempDbConsumer.json
26	17	TempDbConfig.json
28	18	Dead_Lock.json
29	18	locks.json
30	19	wait_stats.json
31	19	Waits.json
32	20	compilation_stats.json
33	21	Login_activity_monitoring.json
34	21	successful_logins.json
35	25	logins_permissions.json
38	25	service_account_permissions.json
39	25	Users_Excessive_Permissions.json
40	26	database_role_users.json
41	26	windows_logins.json
42	26	elevated_logins.json
43	27	elevated_query_execution.json
44	27	database_elevated_users.json
45	28	week_passwords.json
46	29	Backup_Encryption.json
47	30	database_unmasked_users.json
48	30	elevated_query_execution.json
49	31	data_masking.json
50	32	Backup_Encryption.json
51	33	Backup_Encryption.json
52	34	database_grants.json
53	38	product_version.json
54	39	elevated_query_execution.json
55	40	elevated_query_execution.json
57	41	database_grants.json
58	42	vulnerabilities.json
59	42	Login_activity_monitoring.json
60	42	product_version.json
61	43	Check_SQL_Server_Version_Service_Packs.json
62	48	data_masking.json
63	48	database_unmasked_users.json
64	49	Login_activity_monitoring.json
65	49	elevated_query_execution.json
66	51	vulnerabilities.json
67	51	elevated_query_execution_Bar.json
68	51	sql_injection_Bar.json
69	52	Last_Backups.json
70	52	Job_Success.json
71	53	Last_Backups.json
72	54	Last_Backups.json
73	55	Database_Info.json
74	55	GENERAL_INFO.json
75	56	Last_Backups.json
76	56	Missing_Backups.json
77	57	Database_growth_info.json
78	57	Data_Stats.json
79	58	Database_Info.json
80	58	Data_Stats.json
81	59	Disk_Space.json
82	59	Disk_Space_Reserve.json
83	60	Database_Info.json
84	60	Database_growth_info.json
85	61	TEMPDBUSED.json
86	61	TempDbConsumer.json
87	61	TempDbConfig.json
88	62	Replication_Latency.json
89	63	AlwaysOn_health.json
90	63	ALERTS.json
91	64	Mirroring_Status.json
92	65	Failover_Events.json
93	65	Error_Log.json
94	66	Log_Shipping.json
95	66	Job_Success.json
96	67	Job_Success.json
98	67	Error_Log.json
99	68	Statistics_Updates.json
100	68	Job_Success.json
101	69	DBCC_History.json
102	69	Job_Success.json
103	70	index_maintenance.json
104	70	Job_Success.json
105	71	Dead_Lock.json
106	71	locks.json
\.
INSERT INTO widget.category_detailfiles (row_id, category_row_id, detailfile)
SELECT row_id, category_row_id, detailfile FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM widget.category_detailfiles);
DROP TABLE _stg_load;

SELECT setval('widget.category_detailfiles_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM widget.category_detailfiles),1), (SELECT count(*) FROM widget.category_detailfiles) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'widget' AND c.relname = 'category_detailfiles'
          AND con.conname = 'pk_category_detailfiles') THEN
        ALTER TABLE ONLY widget.category_detailfiles
    ADD CONSTRAINT pk_category_detailfiles PRIMARY KEY (category_row_id, detailfile);
    END IF;
END $do$;
