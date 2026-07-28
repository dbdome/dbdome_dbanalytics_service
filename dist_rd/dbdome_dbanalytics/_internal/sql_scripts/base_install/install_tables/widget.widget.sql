-- Idempotent install for widget.widget
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS widget;

CREATE SEQUENCE IF NOT EXISTS widget.widget_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS widget.widget (
    row_id integer NOT NULL,
    widget_name character varying(50) NOT NULL,
    widget_json_file_name character varying(50) NOT NULL,
    widget_json_file_location text NOT NULL,
    widget_count integer DEFAULT 1 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE widget.widget ALTER COLUMN row_id SET DEFAULT nextval('widget.widget_row_id_seq'::regclass);
ALTER SEQUENCE widget.widget_row_id_seq OWNED BY widget.widget.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE widget.widget);
COPY _stg_load (row_id, widget_name, widget_json_file_name, widget_json_file_location, widget_count, is_active, entry_date) FROM stdin;
1182	Activity.JSON	Activity.JSON	C:\\home\\pg\\dbexpertAi\\client	0	t	2025-04-18 08:03:02.134177
1196	Audit_logs.JSON	Audit_logs.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:40.241016
1197	Audit_trails.JSON	Audit_trails.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:40.241016
1205	Blocked_connections.JSON	Blocked_connections.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:45.413264
1190	Blocked_requests.JSON	Blocked_requests.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:45.413264
1194	Current_threats.JSON	Current_threats.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:49.807444
1198	Elevated_users.JSON	Elevated_users.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:53.856075
1	SQL_Injection_transactions.JSON	SQL_Injection_transactions.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-06-25 11:02:16.58895
1218	Number_of_event_logs.JSON	Number_of_event_logs.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-06-27 22:25:43.472059
1219	audit_trails_database_logs.JSON	audit_trails_database_logs.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-06-27 22:58:32.312452
1220	Number_of_Blocked_connections.JSON	Number_of_Blocked_connections.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-06-27 23:22:01.397688
1221	Number_of_sensitive_fields.JSON	Number_of_sensitive_fields.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-06-28 00:36:14.911218
1222	cases_of_sensitive_data_usage.JSON	cases_of_sensitive_data_usage.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-06-28 00:41:33.094365
1223	sensitive_schema.JSON	sensitive_schema.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-06-28 00:50:54.428691
1224	sensitive_schema_in_use.JSON	sensitive_schema_in_use.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-06-28 00:59:27.703412
1225	Number_of_unknown_tcp_connections.JSON	Number_of_unknown_tcp_connections.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-06-28 04:22:48.519001
1226	Unknown_tcp_connections.JSON	Unknown_tcp_connections.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-06-28 04:26:24.068716
1227	Number_of_suspicious_transactions.JSON	Number_of_suspicious_transactions.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-06-28 06:34:15.323406
1228	Suspicious_transactions.JSON	Suspicious_transactions.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-06-28 06:40:42.73059
1229	Number_of_threats.JSON	Number_of_threats.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-06-28 06:52:03.105906
80	Tracker.json	Tracker.json	C:\\home\\pg\\dbexpertAi\\client	1	t	2025-04-18 11:20:19.445109
1186	adminData.JSON	adminData.JSON	C:\\home\\dbdome\\DBDOME	1	t	2025-04-18 08:04:25.087652
1230	Suspicious_threats.JSON	Suspicious_threats.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-06-28 06:57:01.34907
1233	Access_log_report.JSON	Access_log_report.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-06-28 09:22:43.873778
1232	Number_of_cases_Access_log_report.JSON	Number_of_cases_Access_log_report.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-06-28 09:20:17.352621
1234	Unusual_transactions.JSON	Unusual_transactions.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-06-28 12:20:51.682844
1235	Unusual_query_patterns.JSON	Unusual_query_patterns.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-06-28 12:34:18.068934
1236	Failed_login_attempts.JSON	Failed_login_attempts.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-06-28 12:41:42.099996
1237	privileged_accounts_in_unexpected_manner.JSON	privileged_accounts_in_unexpected_manner.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-06-28 13:33:04.564027
1192	Allowed_requests.JSON	Allowed_requests.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:33.171814
1193	historical_threats.JSON	historical_threats.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:05:59.360087
1191	Total_Requests.JSON	Total_Requests.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 11:20:19.445109
1215	sql_injection_transactions.JSON	sql_injection_transactions.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-06-25 11:46:13.591156
1184	Action_History.JSON	Action_History.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:02:58.535766
1185	Actions_investigation.JSON	Actions_investigation.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:03:02.134177
35	Active_Sessions.JSON	Active_Sessions.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	2	t	2025-04-18 08:03:02.134177
69	Active_Transactions.JSON	Active_Transactions.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	2	t	2025-04-18 08:03:02.134177
75	ad_hoc_cpu_cunsuming_queries.JSON	ad_hoc_cpu_cunsuming_queries.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:03:02.134177
1170	anomaliy_detection_High_Resource_Queries.JSON	anomaliy_detection_High_Resource_Queries.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:40.241016
1171	anomaly_detection_Login_from_Unusual_Hosts.JSON	anomaly_detection_Login_from_Unusual_Hosts.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:40.241016
1167	Anomaly_detection_long_running_queries.JSON	Anomaly_detection_long_running_queries.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:40.241016
1172	anomaly_detection_performance_counters.JSON	anomaly_detection_performance_counters.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:40.241016
1088	Applicative_users.JSON	Applicative_users.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	2	t	2025-04-18 08:04:40.241016
1188	Attack_investigation.JSON	Attack_investigation.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:40.241016
1189	Attacks_By_Server.JSON	Attacks_By_Server.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:40.241016
62	averagestalls.JSON	averagestalls.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:45.413264
49	avg_duration_procedures.JSON	avg_duration_procedures.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:45.413264
1154	backup_encryption.JSON	backup_encryption.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:45.413264
1099	Block_waits.JSON	Block_waits.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	2	t	2025-04-18 08:04:45.413264
38	BufferManager.JSON	BufferManager.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:45.413264
45	bufferUsage.JSON	bufferUsage.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:45.413264
57	Cache_Ratio.JSON	Cache_Ratio.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	2	t	2025-04-18 08:04:45.413264
1120	Cache_Ratio_Bar.JSON	Cache_Ratio_Bar.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	2	t	2025-04-18 08:04:45.413264
1176	Check_SQL_Server_Version_Service_Packs.JSON	Check_SQL_Server_Version_Service_Packs.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:45.413264
1126	cpu_consuming_procedures.JSON	cpu_consuming_procedures.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	2	t	2025-04-18 08:04:45.413264
1127	cpu_consuming_procedures_table.JSON	cpu_consuming_procedures_table.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:49.807444
14	CPU_Stats.JSON	CPU_Stats.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	2	t	2025-04-18 08:04:49.807444
1151	data_masking.JSON	data_masking.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:49.807444
46	Data_Stats.JSON	Data_Stats.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:49.807444
1146	database_elevated_users.JSON	database_elevated_users.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:49.807444
1152	database_grants.JSON	database_grants.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:49.807444
1109	Database_growth_info.JSON	Database_growth_info.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:49.807444
41	Database_Info.JSON	Database_Info.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:49.807444
43	Database_Performance.JSON	Database_Performance.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:49.807444
1150	database_role_users.JSON	database_role_users.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:49.807444
1148	database_unmasked_users.JSON	database_unmasked_users.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:49.807444
52	Dead_Lock.JSON	Dead_Lock.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	2	t	2025-04-18 08:04:49.807444
1124	Dead_Lock_Bar.JSON	Dead_Lock_Bar.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	2	t	2025-04-18 08:04:49.807444
1133	Disk_queue.JSON	Disk_Queue.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:53.856075
1134	Disk_queue_Bar.JSON	Disk_queue_Bar.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	2	t	2025-04-18 08:04:53.856075
56	Disk_Space.JSON	Disk_Space.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	2	t	2025-04-18 08:04:53.856075
36	Disk_Space_Reserve.JSON	Disk_Space_Reserve.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:53.856075
1144	disk_space_table.JSON	disk_space_table.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:53.856075
1123	Disk_Volume_Bar.JSON	Disk_Volume_Bar.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	2	t	2025-04-18 08:04:53.856075
13	Disk_Volums.JSON	Disk_Volums.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	2	t	2025-04-18 08:04:53.856075
37	Drive_Level_Latency.JSON	Drive_Level_Latency.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	2	t	2025-04-18 08:04:53.856075
1156	elevated_logins.JSON	elevated_logins.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:53.856075
1157	elevated_query_execution.JSON	elevated_query_execution.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:53.856075
1158	elevated_query_execution_Bar.JSON	elevated_query_execution_Bar.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	2	t	2025-04-18 08:04:53.856075
1114	ERPDB_CPU_Utilization.JSON	ERPDB_CPU_Utilization.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	2	t	2025-04-18 08:04:53.856075
44	Error_Log.JSON	Error_Log.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	2	t	2025-04-18 08:04:53.856075
58	GENERAL_INFO.JSON	GENERAL_INFO.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:53.856075
1115	GeneralDB_CPU_Utilization.JSON	GeneralDB_CPU_Utilization.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	2	t	2025-04-18 08:04:53.856075
1163	generaldb_cpustats.JSON	generaldb_cpustats.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	2	t	2025-04-18 08:04:53.856075
65	Hardware_info.JSON	Hardware_info.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:53.856075
1102	High_CPU_consuming_procedures.JSON	High_CPU_consuming_procedures.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:05:39.673628
61	High_Latency_PerFile.JSON	High_Latency_PerFile.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:05:39.673628
19	Aggregate_BufferPool_Usage.JSON	Aggregate_BufferPool_Usage.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	2	t	2025-04-18 08:04:29.287109
3	Aggregate_IO_STATS.JSON	Aggregate_IO_STATS.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:29.287109
15	ALERTS.json	ALERTS.json	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:33.171814
1207	Allowed_Connections.JSON	Allowed_Connections.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 08:04:33.171814
1141	sql_Metric_Error_Bar.JSON	sql_Metric_Error_Bar.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	2	t	2025-04-18 11:20:19.445109
10	Waits.JSON	Waits.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 11:20:19.445109
1137	sql_Metric_Errors.JSON	sql_Metric_Errors.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 11:20:19.445109
1111	Storage_IOPS.JSON	Storage_IOPS.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 11:20:19.445109
1112	Storage_Stalls_iops.JSON	Storage_Stalls_iops.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 11:20:19.445109
1166	successful_logins.JSON	successful_logins.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 11:20:19.445109
72	TABLESIZE.JSON	TABLESIZE.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 11:20:19.445109
1165	TCP_connections.JSON	TCP_connections.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 11:20:19.445109
63	TempDbConfig.JSON	TempDbConfig.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 11:20:19.445109
60	TempDbConsumer.JSON	TempDbConsumer.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 11:20:19.445109
33	TEMPDBUSED.JSON	TEMPDBUSED.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 11:20:19.445109
1206	Total_Connections.JSON	Total_Connections.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 11:20:19.445109
1093	Transactions_anomality.JSON	Transactions_anomality.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	2	t	2025-04-18 11:20:19.445109
1214	Unused_Inactive_Server_Logins.JSON	Unused_Inactive_Server_Logins.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 11:20:19.445109
1180	Unused_Inactive_SQL_Server_Logins.JSON	Unused_Inactive_SQL_Server_Logins.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 11:20:19.445109
26	UnusedINDEXES.JSON	UnusedINDEXES.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 11:20:19.445109
1122	User_Connection_Bar.JSON	User_Connection_Bar.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	2	t	2025-04-18 11:20:19.445109
1101	User_connections.JSON	User_connections.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	2	t	2025-04-18 11:20:19.445109
1178	Users_Excessive_Permissions.JSON	Users_Excessive_Permissions.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 11:20:19.445109
1160	vulnerabilities.JSON	vulnerabilities.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 11:20:19.445109
17	wait_stats.JSON	wait_stats.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 11:20:19.445109
1082	Weak_passwords.JSON	Weak_passwords.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	2	t	2025-04-18 11:20:19.445109
1155	week_passwords.JSON	week_passwords.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 11:20:19.445109
1147	windows_logins.JSON	windows_logins.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-04-18 11:20:19.445109
1095	Write_Latency.JSON	Write_Latency.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	2	t	2025-04-18 11:20:19.445109
1216	SQL_injection_Transaction_requests.JSON	SQL_injection_Transaction_requests.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-06-25 12:35:29.298182
1217	Blocked_Transactions.JSON	Blocked_Transactions.JSON	C:\\home\\pg\\dbexpertAi\\client\\DashboardData	1	t	2025-06-25 23:17:49.588923
10006	locks.json	locks.json	/home/dbexpert/serverRoot/server_000/client/DashboardData	1	t	2025-11-01 19:35:52.519826
7	CategoryDefinitions.json	CategoryDefinitions.json	/home/dbexpert/serverRoot/server_000/data	1	t	2025-11-01 20:24:12.276575
5	Advisories.json	Advisories.json	C:\\installs\\dbexpert_setup\\DBEXPERT\\dbExpertAI-windows-x64-v1.1.6\\data	1	t	2025-11-01 12:30:52.746695
\.
INSERT INTO widget.widget (row_id, widget_name, widget_json_file_name, widget_json_file_location, widget_count, is_active, entry_date)
SELECT row_id, widget_name, widget_json_file_name, widget_json_file_location, widget_count, is_active, entry_date FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM widget.widget);
DROP TABLE _stg_load;

SELECT setval('widget.widget_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM widget.widget),1), (SELECT count(*) FROM widget.widget) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'widget' AND c.relname = 'widget'
          AND con.conname = 'widget_pkey') THEN
        ALTER TABLE ONLY widget.widget
    ADD CONSTRAINT widget_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
