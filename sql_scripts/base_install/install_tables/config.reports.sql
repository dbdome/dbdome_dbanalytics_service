-- Idempotent install for config.reports
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.reports_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.reports (
    row_id integer NOT NULL,
    report_name text NOT NULL,
    report_query text NOT NULL,
    is_active boolean DEFAULT true,
    entry_date timestamp without time zone DEFAULT now(),
    report_url text
);

ALTER TABLE config.reports ALTER COLUMN row_id SET DEFAULT nextval('config.reports_row_id_seq'::regclass);
ALTER SEQUENCE config.reports_row_id_seq OWNED BY config.reports.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE config.reports);
COPY _stg_load (row_id, report_name, report_query, is_active, entry_date, report_url) FROM stdin;
2	DAM_report	select server , duration_secs , database_name , start_time , Last_request_End_time ,  command , login_name , program_name , host_name  , SUBSTRING(query FROM 1 FOR 100) query   from monitoring.active_transactions where last_request_end_time between Now() - interval '1 day' and Now()  	t	2026-01-03 20:08:40.760616	\N
1	records by matrics	select  "Number of records" * 100 /\n((\nselect count(*) "Number of records" from monitoring.active_transactions\n)+\n(\nselect count(*) "Number of records" from monitoring.general_metric_metadata_results\n)) "Percentage"\n, server  , metric_name   from \n(\nselect count(*) "Number of records" , server  , 'Active transactions' metric_name from monitoring.active_transactions\ngroup by server\nunion all\nselect count(*) ,  server , metric_name from monitoring.general_metric_metadata_results\ngroup by server , metric_name\n)\norder by "Percentage" desc	t	2026-01-03 20:08:05.986281	\N
3	transaction_report	select server, session_id, duration_secs, database_name, last_request_end_time, command, program_name, query from monitoring.v_combined_transactions  WHERE TO_CHAR(last_request_end_time, 'YYYY-MM-DD') between %s and %s and server = %s  order by last_request_end_time desc	t	2026-01-10 15:03:45.343438	\N
4	audit_expired_report	select  *  from monitoring.v_oracle_audit_expired where server = %s	t	2026-01-11 16:01:47.927348	\N
5	blocking_transaction_report	select  *  from monitoring.v_blocking_transactions where server = %s  and TO_CHAR(to_timestamp(start_time::bigint / 1000 ), 'YYYY-MM-DD') between %s and %s	t	2026-01-11 16:05:43.999755	\N
6	block_in_transactions_report	select * from monitoring.v_mssql_blocking_sessiond  where server = %s 	t	2026-01-11 16:30:46.638691	\N
7	credentials_stored_in_tables_report	select * from monitoring.v_mssql_credentials_stored_in_tables where server = %s 	t	2026-01-11 16:47:19.176281	\N
8	database_connections_per_user_report	select * from monitoring.connection_count  where server = %s 	t	2026-01-11 16:49:19.627945	\N
9	database_restored_report	select  * from monitoring.v_database_restored   where server = %s	t	2026-01-11 17:29:35.266772	\N
10	enabled_sysadmin_report	select * from monitoring.v_enabled_sysadmin  where server = %s	t	2026-01-12 04:16:09.875061	\N
11	linked_server_report	select * from monitoring.linked_servers_hidden_credentials where server = %s\n	t	2026-01-12 04:18:18.700096	\N
12	locked_accounts_report	select server , username , account_status , to_timestamp(lock_date::bigint / 1000) lock_date from monitoring.v_oracle_locked_accounts	t	2026-01-12 04:23:59.752153	\N
13	policy_not_enforeced_report	select  * from monitoring.v_policy_enforeced\n	t	2026-01-12 04:25:28.759483	\N
14	scanned_jobs_report	select  * from monitoring.v_scan_jobs_for_leak	t	2026-01-12 04:26:41.40407	\N
15	sensitive_schema_report	select at.server , at.query , last_request_end_time, c.column_name , c.table_name from monitoring.v_combined_transactions at\njoin(\nselect TABLE_NAME ,  column_name from monitoring.v_sensitive_columns \n) c on at.query like '%'||c.column_name ||'%'\nand last_request_end_time > Now() - interval '15 minutes'	t	2026-01-12 04:33:37.097065	\N
16	sysadmin_report	select * from monitoring.v_mssql_superuser 	t	2026-01-12 04:36:49.892568	\N
17	week_passwords	select  * from monitoring.v_sysadmin_accounts_with_weakpassword_enforcement	t	2026-01-12 04:38:43.093421	\N
19	open_alerts	C:\\ProgramData\\dbdome\\bin\\templates\\report_config_example.json	t	2026-02-12 05:47:12.056722	C:\\ProgramData\\dbdome\\bin\\templates\\report_daily_executive_alert_summary.json
20	Privileged Access Oversight Report	JSON-based report - see report_url for template	t	2026-04-03 15:01:58.576976	templates/report_privileged_access_oversight.json
21	rpt_alerts_alerts_sent_by_mail	JSON report for: Alerts Sent by Mail	t	2026-04-06 10:45:19.120041	templates/rpt_alerts_alerts_sent_by_mail.json
22	rpt_alerts_active_detection_findings	JSON report for: Active Detection Findings	t	2026-04-06 10:45:19.120041	templates/rpt_alerts_active_detection_findings.json
23	rpt_sql_injection_-_boolean-based_injections_comment_based_injections	JSON report for: comment based injections	t	2026-04-06 10:45:19.120041	templates/rpt_sql_injection_-_boolean-based_injections_comment_based_injections.json
24	rpt_sql_injection_-_comment_based_comment_based_injections	JSON report for: comment based injections	t	2026-04-06 10:45:19.120041	templates/rpt_sql_injection_-_comment_based_comment_based_injections.json
25	rpt_sql_injection_-_information_schema_probing_information_schema_probing	JSON report for: Information schema probing	t	2026-04-06 10:45:19.120041	templates/rpt_sql_injection_-_information_schema_probing_information_schema_probing.json
26	rpt_sql_injection_-_stacked_queries_stacked_query_injections	JSON report for: Stacked query injections	t	2026-04-06 10:45:19.120041	templates/rpt_sql_injection_-_stacked_queries_stacked_query_injections.json
27	rpt_sql_injection_-_time_based_stacked_query_injections	JSON report for: Stacked query injections	t	2026-04-06 10:45:19.120041	templates/rpt_sql_injection_-_time_based_stacked_query_injections.json
28	rpt_sql_injection_-_time_based_blind_injection_time_based_blind_injections	JSON report for: Time based blind injections	t	2026-04-06 10:45:19.120041	templates/rpt_sql_injection_-_time_based_blind_injection_time_based_blind_injections.json
29	rpt_sql_injection_-_union_based_union_based_injections	JSON report for: Union based injections	t	2026-04-06 10:45:19.120041	templates/rpt_sql_injection_-_union_based_union_based_injections.json
30	rpt_sql_injection_-_tautology_with_comments_comment_based_injections	JSON report for: comment based injections	t	2026-04-06 10:45:19.120041	templates/rpt_sql_injection_-_tautology_with_comments_comment_based_injections.json
31	rpt_sql_injection_-authentication_bypass_authentication_bypass	JSON report for: Authentication bypass	t	2026-04-06 10:45:19.120041	templates/rpt_sql_injection_-authentication_bypass_authentication_bypass.json
32	rpt_sql_injection_-encoding_encoding_injection	JSON report for: Encoding injection	t	2026-04-06 10:45:19.120041	templates/rpt_sql_injection_-encoding_encoding_injection.json
33	rpt_sql_injection_-error_based_injection_error_based_injections	JSON report for: Error based injections	t	2026-04-06 10:45:19.120041	templates/rpt_sql_injection_-error_based_injection_error_based_injections.json
34	rpt_sql_injection_-shell_function_shell_commands	JSON report for: Shell commands	t	2026-04-06 10:45:19.120041	templates/rpt_sql_injection_-shell_function_shell_commands.json
35	rpt_sql_injection_-order_group_by_order_group_by	JSON report for: Order / Group by	t	2026-04-06 10:45:19.120041	templates/rpt_sql_injection_-order_group_by_order_group_by.json
36	rpt_sql_injection_board_sql_injection_-_sleep_time	JSON report for: SQL injection - Sleep time	t	2026-04-06 10:45:19.120041	templates/rpt_sql_injection_board_sql_injection_-_sleep_time.json
37	rpt_1_data_discovery_classification_sensitive_data_pii	JSON report for: Sensitive data (PII)	t	2026-04-06 10:45:19.120041	templates/rpt_1_data_discovery_classification_sensitive_data_pii.json
38	rpt_1_data_discovery_classification_sensitive_columns_and_schema_pii	JSON report for: Sensitive columns and schema (PII)	t	2026-04-06 10:45:19.120041	templates/rpt_1_data_discovery_classification_sensitive_columns_and_schema_pii.json
115	rpt_processes_processes	JSON report for: Processes	t	2026-04-06 10:45:19.120041	templates/rpt_processes_processes.json
39	rpt_1_data_discovery_classification_1_data_discovery_classification	JSON report for: 1. Data Discovery & Classification	t	2026-04-06 10:45:19.120041	templates/rpt_1_data_discovery_classification_1_data_discovery_classification.json
40	rpt_1_data_discovery_classification_1_data_discovery_classification_11	JSON report for: 1. Data Discovery & Classification	t	2026-04-06 10:45:19.120041	templates/rpt_1_data_discovery_classification_1_data_discovery_classification_11.json
41	rpt_1_data_discovery_classification_1_data_discovery_classification_12	JSON report for: 1. Data Discovery & Classification	t	2026-04-06 10:45:19.120041	templates/rpt_1_data_discovery_classification_1_data_discovery_classification_12.json
42	rpt_1_data_discovery_classification_1_data_discovery_classification_16	JSON report for: 1. Data Discovery & Classification	t	2026-04-06 10:45:19.120041	templates/rpt_1_data_discovery_classification_1_data_discovery_classification_16.json
43	rpt_1_data_discovery_classification_1_data_discovery_classification_17	JSON report for: 1. Data Discovery & Classification	t	2026-04-06 10:45:19.120041	templates/rpt_1_data_discovery_classification_1_data_discovery_classification_17.json
44	rpt_1_data_discovery_classification_1_data_discovery_classification_18	JSON report for: 1. Data Discovery & Classification	t	2026-04-06 10:45:19.120041	templates/rpt_1_data_discovery_classification_1_data_discovery_classification_18.json
45	rpt_1_data_discovery_classification_audit_trails	JSON report for: Audit trails	t	2026-04-06 10:45:19.120041	templates/rpt_1_data_discovery_classification_audit_trails.json
46	rpt_2_activity_monitoring_audit_transactions	JSON report for: Transactions	t	2026-04-06 10:45:19.120041	templates/rpt_2_activity_monitoring_audit_transactions.json
47	rpt_3_threat_detection_behavioral_analytics_sql_injection_by_patterns	JSON report for: SQL injection by patterns	t	2026-04-06 10:45:19.120041	templates/rpt_3_threat_detection_behavioral_analytics_sql_injection_by_patterns.json
48	rpt_3_threat_detection_behavioral_analytics_credentials_stored_in_database_tables	JSON report for: Credentials stored in database tables	t	2026-04-06 10:45:19.120041	templates/rpt_3_threat_detection_behavioral_analytics_credentials_stored_in_database_tables.json
49	rpt_3_threat_detection_behavioral_analytics_database_restored	JSON report for: Database restored	t	2026-04-06 10:45:19.120041	templates/rpt_3_threat_detection_behavioral_analytics_database_restored.json
50	rpt_3_threat_detection_behavioral_analytics_blocking_transactions	JSON report for: Blocking transactions	t	2026-04-06 10:45:19.120041	templates/rpt_3_threat_detection_behavioral_analytics_blocking_transactions.json
51	rpt_3_threat_detection_behavioral_analytics_enabled_sysadmin	JSON report for: Enabled sysadmin	t	2026-04-06 10:45:19.120041	templates/rpt_3_threat_detection_behavioral_analytics_enabled_sysadmin.json
52	rpt_3_threat_detection_behavioral_analytics_sysadmin_accounts_with_weak_password_enforcement	JSON report for: sysadmin accounts with weak password enforcement	t	2026-04-06 10:45:19.120041	templates/rpt_3_threat_detection_behavioral_analytics_sysadmin_accounts_with_weak_password_enforcement.json
53	rpt_3_threat_detection_behavioral_analytics_linked_server_dblinks_hidden_credentials	JSON report for: Linked server / DBLINKS Hidden credentials	t	2026-04-06 10:45:19.120041	templates/rpt_3_threat_detection_behavioral_analytics_linked_server_dblinks_hidden_credentials.json
54	rpt_3_threat_detection_behavioral_analytics_locked_accounts	JSON report for: Locked accounts	t	2026-04-06 10:45:19.120041	templates/rpt_3_threat_detection_behavioral_analytics_locked_accounts.json
55	rpt_3_threat_detection_behavioral_analytics_scanned_jobs_for_leaks	JSON report for: Scanned jobs for leaks	t	2026-04-06 10:45:19.120041	templates/rpt_3_threat_detection_behavioral_analytics_scanned_jobs_for_leaks.json
56	rpt_3_threat_detection_behavioral_analytics_policy_not_enforced	JSON report for: Policy not enforced	t	2026-04-06 10:45:19.120041	templates/rpt_3_threat_detection_behavioral_analytics_policy_not_enforced.json
57	rpt_4_policy_enforcement_protection_credentials_stored_in_database_tables	JSON report for: Credentials stored in database tables	t	2026-04-06 10:45:19.120041	templates/rpt_4_policy_enforcement_protection_credentials_stored_in_database_tables.json
58	rpt_4_policy_enforcement_protection_4_policy_enforcement_protection	JSON report for: 4. Policy Enforcement & Protection	t	2026-04-06 10:45:19.120041	templates/rpt_4_policy_enforcement_protection_4_policy_enforcement_protection.json
59	rpt_4_policy_enforcement_protection_4_policy_enforcement_protection_29	JSON report for: 4. Policy Enforcement & Protection	t	2026-04-06 10:45:19.120041	templates/rpt_4_policy_enforcement_protection_4_policy_enforcement_protection_29.json
60	rpt_4_policy_enforcement_protection_enabled_sysadmin	JSON report for: Enabled sysadmin	t	2026-04-06 10:45:19.120041	templates/rpt_4_policy_enforcement_protection_enabled_sysadmin.json
61	rpt_4_policy_enforcement_protection_4_policy_enforcement_protection_30	JSON report for: 4. Policy Enforcement & Protection	t	2026-04-06 10:45:19.120041	templates/rpt_4_policy_enforcement_protection_4_policy_enforcement_protection_30.json
62	rpt_4_policy_enforcement_protection_sysadmin_accounts_with_weak_password_enforcement	JSON report for: sysadmin accounts with weak password enforcement	t	2026-04-06 10:45:19.120041	templates/rpt_4_policy_enforcement_protection_sysadmin_accounts_with_weak_password_enforcement.json
63	rpt_4_policy_enforcement_protection_linked_server_dblinks_hidden_credentials	JSON report for: Linked server / DBLINKS Hidden credentials	t	2026-04-06 10:45:19.120041	templates/rpt_4_policy_enforcement_protection_linked_server_dblinks_hidden_credentials.json
64	rpt_4_policy_enforcement_protection_locked_accounts	JSON report for: Locked accounts	t	2026-04-06 10:45:19.120041	templates/rpt_4_policy_enforcement_protection_locked_accounts.json
65	rpt_4_policy_enforcement_protection_scanned_jobs_for_leaks	JSON report for: Scanned jobs for leaks	t	2026-04-06 10:45:19.120041	templates/rpt_4_policy_enforcement_protection_scanned_jobs_for_leaks.json
66	rpt_4_policy_enforcement_protection_policy_not_enforced	JSON report for: Policy not enforced	t	2026-04-06 10:45:19.120041	templates/rpt_4_policy_enforcement_protection_policy_not_enforced.json
67	rpt_5_data_protection_data_protection_-_unmasked_columns	JSON report for: Data Protection - Unmasked columns	t	2026-04-06 10:45:19.120041	templates/rpt_5_data_protection_data_protection_-_unmasked_columns.json
68	rpt_6_vulnerability_assessment_data_protection_-_privileged_logins	JSON report for: Data Protection  - Privileged logins	t	2026-04-06 10:45:19.120041	templates/rpt_6_vulnerability_assessment_data_protection_-_privileged_logins.json
69	rpt_7_automation_workflows_configure_servers	JSON report for: Configure servers	t	2026-04-06 10:45:19.120041	templates/rpt_7_automation_workflows_configure_servers.json
70	rpt_7_automation_workflows_root_causes	JSON report for: Root causes	t	2026-04-06 10:45:19.120041	templates/rpt_7_automation_workflows_root_causes.json
71	rpt_7_automation_workflows_enable_disable_metrics_per_server	JSON report for: Enable  / Disable metrics per server	t	2026-04-06 10:45:19.120041	templates/rpt_7_automation_workflows_enable_disable_metrics_per_server.json
72	rpt_7_automation_workflows_active_transactions	JSON report for: Active_transactions	t	2026-04-06 10:45:19.120041	templates/rpt_7_automation_workflows_active_transactions.json
73	rpt_7_automation_workflows_custom_metrics	JSON report for: Custom metrics	t	2026-04-06 10:45:19.120041	templates/rpt_7_automation_workflows_custom_metrics.json
74	rpt_7_automation_workflows_email_configuration	JSON report for: Email configuration	t	2026-04-06 10:45:19.120041	templates/rpt_7_automation_workflows_email_configuration.json
75	rpt_7_automation_workflows_all_metrics	JSON report for: all metrics	t	2026-04-06 10:45:19.120041	templates/rpt_7_automation_workflows_all_metrics.json
76	rpt_7_automation_workflows_log	JSON report for: Log	t	2026-04-06 10:45:19.120041	templates/rpt_7_automation_workflows_log.json
77	rpt_audit_expired_audit_expired	JSON report for: Audit expired	t	2026-04-06 10:45:19.120041	templates/rpt_audit_expired_audit_expired.json
78	rpt_blocking_transactions_blocking_transactions	JSON report for: Blocking transactions	t	2026-04-06 10:45:19.120041	templates/rpt_blocking_transactions_blocking_transactions.json
79	rpt_blocking_transactions_blocking_transactions_16	JSON report for: Blocking transactions	t	2026-04-06 10:45:19.120041	templates/rpt_blocking_transactions_blocking_transactions_16.json
80	rpt_blocking_transactions_blocking_transactions_17	JSON report for: Blocking transactions	t	2026-04-06 10:45:19.120041	templates/rpt_blocking_transactions_blocking_transactions_17.json
81	rpt_blocking_transactions_sql_injection_by_patterns	JSON report for: SQL injection by patterns	t	2026-04-06 10:45:19.120041	templates/rpt_blocking_transactions_sql_injection_by_patterns.json
82	rpt_blocks_in_databases_blocks_in_databases	JSON report for: Blocks in databases	t	2026-04-06 10:45:19.120041	templates/rpt_blocks_in_databases_blocks_in_databases.json
83	rpt_blocks_in_databases_database_blocks	JSON report for: Database blocks	t	2026-04-06 10:45:19.120041	templates/rpt_blocks_in_databases_database_blocks.json
84	rpt_configuration_root_causes	JSON report for: Root causes	t	2026-04-06 10:45:19.120041	templates/rpt_configuration_root_causes.json
85	rpt_configuration_configure_servers	JSON report for: Configure servers	t	2026-04-06 10:45:19.120041	templates/rpt_configuration_configure_servers.json
86	rpt_configuration_enable_disable_metrics_per_server	JSON report for: Enable  / Disable metrics per server	t	2026-04-06 10:45:19.120041	templates/rpt_configuration_enable_disable_metrics_per_server.json
87	rpt_configuration_enable_disable_metrics_for_all_servers	JSON report for: Enable / Disable metrics for all servers	t	2026-04-06 10:45:19.120041	templates/rpt_configuration_enable_disable_metrics_for_all_servers.json
88	rpt_configuration_configure_metrics_to_a_server	JSON report for: Configure metrics to a server	t	2026-04-06 10:45:19.120041	templates/rpt_configuration_configure_metrics_to_a_server.json
89	rpt_configuration_already_engaged_metrics	JSON report for: Already engaged metrics	t	2026-04-06 10:45:19.120041	templates/rpt_configuration_already_engaged_metrics.json
90	rpt_configuration_custom_metrics	JSON report for: Custom metrics	t	2026-04-06 10:45:19.120041	templates/rpt_configuration_custom_metrics.json
91	rpt_configuration_engage_custom_metrics_to_servers	JSON report for: Engage custom metrics to servers	t	2026-04-06 10:45:19.120041	templates/rpt_configuration_engage_custom_metrics_to_servers.json
92	rpt_configuration_engaged_custom_metrics_to_servers	JSON report for: Engaged custom metrics to servers	t	2026-04-06 10:45:19.120041	templates/rpt_configuration_engaged_custom_metrics_to_servers.json
93	rpt_configuration_configure_servers_6	JSON report for: Configure servers	t	2026-04-06 10:45:19.120041	templates/rpt_configuration_configure_servers_6.json
94	rpt_configuration_email_configuration	JSON report for: Email configuration	t	2026-04-06 10:45:19.120041	templates/rpt_configuration_email_configuration.json
95	rpt_configuration_email_configuration_22	JSON report for: Email configuration	t	2026-04-06 10:45:19.120041	templates/rpt_configuration_email_configuration_22.json
96	rpt_configuration_server_panel	JSON report for: Server panel	t	2026-04-06 10:45:19.120041	templates/rpt_configuration_server_panel.json
97	rpt_connectivity_connectivity	JSON report for: Connectivity	t	2026-04-06 10:45:19.120041	templates/rpt_connectivity_connectivity.json
98	rpt_connectivity_connectivity_13	JSON report for: Connectivity	t	2026-04-06 10:45:19.120041	templates/rpt_connectivity_connectivity_13.json
99	rpt_credentials_stored_in_tables_credentials_stored_in_tables	JSON report for: Credentials stored in tables	t	2026-04-06 10:45:19.120041	templates/rpt_credentials_stored_in_tables_credentials_stored_in_tables.json
100	rpt_credentials_stored_in_tables_credentials_stored_in_database_tables	JSON report for: Credentials stored in database tables	t	2026-04-06 10:45:19.120041	templates/rpt_credentials_stored_in_tables_credentials_stored_in_database_tables.json
101	rpt_custom_metrics_custom_metrics	JSON report for: Custom metrics	t	2026-04-06 10:45:19.120041	templates/rpt_custom_metrics_custom_metrics.json
102	rpt_database_connections_per_user_database_connections_per_user	JSON report for: Database connections per user	t	2026-04-06 10:45:19.120041	templates/rpt_database_connections_per_user_database_connections_per_user.json
103	rpt_database_connections_per_user_connections_per_user	JSON report for: Connections per user	t	2026-04-06 10:45:19.120041	templates/rpt_database_connections_per_user_connections_per_user.json
104	rpt_database_restored_database_restored	JSON report for: Database restored	t	2026-04-06 10:45:19.120041	templates/rpt_database_restored_database_restored.json
105	rpt_database_restored_database_restored_9	JSON report for: Database restored	t	2026-04-06 10:45:19.120041	templates/rpt_database_restored_database_restored_9.json
106	rpt_email_configuration_email_configuration	JSON report for: Email configuration	t	2026-04-06 10:45:19.120041	templates/rpt_email_configuration_email_configuration.json
107	rpt_enabled_sysadmin_enabled_sysadmin	JSON report for: Enabled sysadmin	t	2026-04-06 10:45:19.120041	templates/rpt_enabled_sysadmin_enabled_sysadmin.json
108	rpt_enabled_sysadmin_enabled_sysadmin_9	JSON report for: Enabled sysadmin	t	2026-04-06 10:45:19.120041	templates/rpt_enabled_sysadmin_enabled_sysadmin_9.json
109	rpt_linked_servers_dblinks_-_hidden_credentials_linked_servers_dblinks_-_hidden_credentials	JSON report for: Linked servers  / DBLINKS - Hidden credentials	t	2026-04-06 10:45:19.120041	templates/rpt_linked_servers_dblinks_-_hidden_credentials_linked_servers_dblinks_-_hidden_credentials.json
110	rpt_linked_servers_dblinks_-_hidden_credentials_linked_server_dblinks_hidden_credentials	JSON report for: Linked server / DBLINKS Hidden credentials	t	2026-04-06 10:45:19.120041	templates/rpt_linked_servers_dblinks_-_hidden_credentials_linked_server_dblinks_hidden_credentials.json
111	rpt_locked_accounts_locked_accounts	JSON report for: Locked accounts	t	2026-04-06 10:45:19.120041	templates/rpt_locked_accounts_locked_accounts.json
112	rpt_locked_accounts_locked_accounts_1	JSON report for: Locked accounts	t	2026-04-06 10:45:19.120041	templates/rpt_locked_accounts_locked_accounts_1.json
113	rpt_policy_not_enforced_policy_not_enforced	JSON report for: Policy not enforced	t	2026-04-06 10:45:19.120041	templates/rpt_policy_not_enforced_policy_not_enforced.json
114	rpt_policy_not_enforced_policy_not_enforced_1	JSON report for: Policy not enforced	t	2026-04-06 10:45:19.120041	templates/rpt_policy_not_enforced_policy_not_enforced_1.json
116	rpt_recent_alerts_security_dashboard	JSON report for: Security dashboard	t	2026-04-06 10:45:19.120041	templates/rpt_recent_alerts_security_dashboard.json
117	rpt_recent_alerts_critical_issues	JSON report for: Critical issues	t	2026-04-06 10:45:19.120041	templates/rpt_recent_alerts_critical_issues.json
118	rpt_recent_alerts_active_threats	JSON report for: Active threats	t	2026-04-06 10:45:19.120041	templates/rpt_recent_alerts_active_threats.json
119	rpt_recent_alerts_active_threats_5	JSON report for: Active threats	t	2026-04-06 10:45:19.120041	templates/rpt_recent_alerts_active_threats_5.json
120	rpt_recent_alerts_active_users	JSON report for: Active users	t	2026-04-06 10:45:19.120041	templates/rpt_recent_alerts_active_users.json
121	rpt_recent_alerts_cyber_attacks	JSON report for: Cyber attacks	t	2026-04-06 10:45:19.120041	templates/rpt_recent_alerts_cyber_attacks.json
122	rpt_recent_alerts_recent_alerts	JSON report for: Recent alerts	t	2026-04-06 10:45:19.120041	templates/rpt_recent_alerts_recent_alerts.json
123	rpt_recent_alerts_sensitivity_reports	JSON report for: Sensitivity reports	t	2026-04-06 10:45:19.120041	templates/rpt_recent_alerts_sensitivity_reports.json
124	rpt_recent_alerts_sql_injection_analysis	JSON report for: SQL Injection analysis	t	2026-04-06 10:45:19.120041	templates/rpt_recent_alerts_sql_injection_analysis.json
125	rpt_recent_alerts_data_activity_monitoring	JSON report for: Data activity monitoring	t	2026-04-06 10:45:19.120041	templates/rpt_recent_alerts_data_activity_monitoring.json
126	rpt_recent_alerts_connectivity_reports	JSON report for: Connectivity reports	t	2026-04-06 10:45:19.120041	templates/rpt_recent_alerts_connectivity_reports.json
127	rpt_retention_policy_retention_policy	JSON report for: Retention policy	t	2026-04-06 10:45:19.120041	templates/rpt_retention_policy_retention_policy.json
128	rpt_siem_configuration_siem	JSON report for: SIEM	t	2026-04-06 10:45:19.120041	templates/rpt_siem_configuration_siem.json
129	rpt_sql_injection_sql_injections_-_injection_prevention	JSON report for: SQL Injections  - Injection prevention	t	2026-04-06 10:45:19.120041	templates/rpt_sql_injection_sql_injections_-_injection_prevention.json
130	rpt_scan_jobs_for_leaks_scan_jobs_for_leaks	JSON report for: Scan jobs for leaks	t	2026-04-06 10:45:19.120041	templates/rpt_scan_jobs_for_leaks_scan_jobs_for_leaks.json
131	rpt_scan_jobs_for_leaks_scanned_jobs_for_leaks	JSON report for: Scanned jobs for leaks	t	2026-04-06 10:45:19.120041	templates/rpt_scan_jobs_for_leaks_scanned_jobs_for_leaks.json
132	rpt_send_report_by_mail_send_report_by_mail	JSON report for: Send report by mail	t	2026-04-06 10:45:19.120041	templates/rpt_send_report_by_mail_send_report_by_mail.json
133	rpt_send_report_by_mail_send_report_by_mail_4	JSON report for: Send report by mail	t	2026-04-06 10:45:19.120041	templates/rpt_send_report_by_mail_send_report_by_mail_4.json
134	rpt_send_report_by_mail_send_report_by_mail_5	JSON report for: Send report by mail	t	2026-04-06 10:45:19.120041	templates/rpt_send_report_by_mail_send_report_by_mail_5.json
135	rpt_sensitivity_report_sensitive_data_pii	JSON report for: Sensitive data (PII)	t	2026-04-06 10:45:19.120041	templates/rpt_sensitivity_report_sensitive_data_pii.json
136	rpt_sensitivity_report_sensitivity_report	JSON report for: Sensitivity report	t	2026-04-06 10:45:19.120041	templates/rpt_sensitivity_report_sensitivity_report.json
137	rpt_sensitivity_report_sensitivity_report_11	JSON report for: Sensitivity report	t	2026-04-06 10:45:19.120041	templates/rpt_sensitivity_report_sensitivity_report_11.json
138	rpt_sensitivity_report_sensitivity_report_12	JSON report for: Sensitivity report	t	2026-04-06 10:45:19.120041	templates/rpt_sensitivity_report_sensitivity_report_12.json
139	rpt_sensitivity_report_sensitive_columns_and_schema_pii	JSON report for: Sensitive columns and schema (PII)	t	2026-04-06 10:45:19.120041	templates/rpt_sensitivity_report_sensitive_columns_and_schema_pii.json
140	rpt_server_panel_server_panel	JSON report for: Server panel	t	2026-04-06 10:45:19.120041	templates/rpt_server_panel_server_panel.json
141	rpt_super_users_sysadmin_sysdba_super_users_sysadmin_sysdba	JSON report for: Super users (sysadmin / sysDBA)	t	2026-04-06 10:45:19.120041	templates/rpt_super_users_sysadmin_sysdba_super_users_sysadmin_sysdba.json
142	rpt_super_users_sysadmin_sysdba_credentials_stored_in_database_tables	JSON report for: Credentials stored in database tables	t	2026-04-06 10:45:19.120041	templates/rpt_super_users_sysadmin_sysdba_credentials_stored_in_database_tables.json
143	rpt_take_action_take_action	JSON report for: Take action	t	2026-04-06 10:45:19.120041	templates/rpt_take_action_take_action.json
144	rpt_transaction_report_transaction_report	JSON report for: Transaction report	t	2026-04-06 10:45:19.120041	templates/rpt_transaction_report_transaction_report.json
145	rpt_transaction_report_transaction_report_15	JSON report for: Transaction report	t	2026-04-06 10:45:19.120041	templates/rpt_transaction_report_transaction_report_15.json
146	rpt_transaction_report_transaction_report_16	JSON report for: Transaction report	t	2026-04-06 10:45:19.120041	templates/rpt_transaction_report_transaction_report_16.json
147	rpt_transaction_report_transactions	JSON report for: Transactions	t	2026-04-06 10:45:19.120041	templates/rpt_transaction_report_transactions.json
148	rpt_user_panel_user_panel	JSON report for: User panel	t	2026-04-06 10:45:19.120041	templates/rpt_user_panel_user_panel.json
149	rpt_sysadmin_accounts_with_weak_password_enforcement_sysadmin_accounts_with_weak_password_enforcement	JSON report for: sysadmin accounts with weak password enforcement	t	2026-04-06 10:45:19.120041	templates/rpt_sysadmin_accounts_with_weak_password_enforcement_sysadmin_accounts_with_weak_password_enforcement.json
150	rpt_sysadmin_accounts_with_weak_password_enforcement_sysadmin_accounts_with_weak_password_enforcement_1	JSON report for: sysadmin accounts with weak password enforcement	t	2026-04-06 10:45:19.120041	templates/rpt_sysadmin_accounts_with_weak_password_enforcement_sysadmin_accounts_with_weak_password_enforcement_1.json
18	DAM Compliance Report	JSON-based report - see report_url for template	t	2026-04-03 15:01:19.620528	templates/report_dam_compliance.json
\.
INSERT INTO config.reports (row_id, report_name, report_query, is_active, entry_date, report_url)
SELECT row_id, report_name, report_query, is_active, entry_date, report_url FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM config.reports);
DROP TABLE _stg_load;

SELECT setval('config.reports_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM config.reports),1), (SELECT count(*) FROM config.reports) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'reports'
          AND con.conname = 'reports_pkey') THEN
        ALTER TABLE ONLY config.reports
    ADD CONSTRAINT reports_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'reports'
          AND con.conname = 'reports_report_name_key') THEN
        ALTER TABLE ONLY config.reports
    ADD CONSTRAINT reports_report_name_key UNIQUE (report_name);
    END IF;
END $do$;
