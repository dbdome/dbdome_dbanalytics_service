-- Idempotent install for metrics.registered_processes
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS metrics;

CREATE SEQUENCE IF NOT EXISTS metrics.registered_processes_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS metrics.registered_processes (
    row_id integer NOT NULL,
    process_name character varying(50) NOT NULL,
    is_active boolean,
    entry_date timestamp without time zone DEFAULT now() NOT NULL,
    "interval" integer DEFAULT 10 NOT NULL,
    description text
);

ALTER TABLE metrics.registered_processes ALTER COLUMN row_id SET DEFAULT nextval('metrics.registered_processes_row_id_seq'::regclass);
ALTER SEQUENCE metrics.registered_processes_row_id_seq OWNED BY metrics.registered_processes.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE metrics.registered_processes);
COPY _stg_load (row_id, process_name, is_active, entry_date, "interval", description) FROM stdin;
5	save_servers	f	2025-07-05 20:45:02.142801	10	\N
6	save_mail	f	2025-07-05 20:45:13.713057	10	\N
7	process_json_to_home_db	f	2025-07-05 20:45:25.281101	10	\N
4	widget_dashboard_json_export	f	2025-07-05 20:44:48.271429	10	\N
3	export_nested_report_operation	f	2025-07-05 20:44:36.205478	10	\N
9	metrics_advisories	f	2025-10-30 17:36:40.470596	10	\N
2	analyse_metrics_operation	f	2025-07-05 20:44:19.762643	10	\N
12	category_definitions	f	2026-02-28 20:59:43.248311	10	\N
1	collect_metrics_operation_sec	t	2025-07-05 20:44:07.625382	10	\N
13	alerts	f	2026-03-07 19:07:10.179789	10	\N
15	detection_tree_build	f	2026-04-01 22:31:41.787135	10	\N
16	detection_tree_oracle	f	2026-04-02 11:01:49.16967	10	\N
14	process_update	f	2026-03-14 18:15:18.126287	6	\N
11	report_job	f	2026-01-01 23:09:40.261802	600	\N
19	dashboard_data_export	f	2026-04-04 21:38:56.275701	10	\N
26	collect_metrics_operation_critical	t	2026-05-03 10:38:38.058822	30	\N
20	collect_metrics_operation_perf	t	2026-04-10 08:17:42.511341	10	\N
21	collect_metrics_operation_hlth	t	2026-04-10 08:17:42.511341	10	\N
22	collect_metrics_operation_other	t	2026-04-10 08:17:42.511341	10	\N
27	grc_firewall_scan	t	2026-05-09 16:50:39.301568	60	GRC Phase 1: firewall policy evaluation and audit logging
35	ddl_audit_scan	t	2026-05-10 18:15:01.233839	120	GRC: Scan for DDL events and write to log.ddl_audit_log
28	compliance_reports_daily	t	2026-05-09 16:51:26.259959	86400	GRC Phase 2: Daily PCI-DSS and HIPAA PDF reports
29	compliance_reports_weekly	t	2026-05-09 16:51:26.259959	604800	GRC Phase 2: Weekly GDPR and SOC2 PDF reports
32	user_risk_scoring	t	2026-05-09 16:51:47.653104	300	GRC Phase 3: user behaviour baseline learning and risk scoring (5-min interval)
33	sync_masking_rules	t	2026-05-09 16:51:58.421076	3600	GRC Phase 4: sync config.masking_rules from monitoring.sensitive_schema (hourly)
34	run_threat_response	t	2026-05-09 16:52:08.503488	60	GRC Phase 6: automated threat response engine (runs every 60s)
41	attestation_scheduler	t	2026-05-10 21:23:53.776973	86400	GRC: Open new attestation periods and create PENDING rows for due controls (daily)
42	cross_border_scan	t	2026-05-10 21:29:51.995195	900	GRC: Detect cross-border data transfers without legal basis (every 15 min)
44	hash_chain_write	t	2026-05-10 22:05:28.562989	60	GRC: Hash new firewall_audit_log rows into SHA-256 chain (every 60 s)
45	hash_chain_verify	t	2026-05-10 22:05:28.562989	86400	GRC: Verify full hash chain integrity and store checkpoint (daily)
46	incident_gdpr_timer	t	2026-05-10 22:12:34.987004	300	GRC: Fire GDPR 72h breach notification alerts for overdue incidents (every 5 min)
47	sod_violation_scan	t	2026-05-10 22:39:31.335215	3600	GRC: Check user privileges against config.sod_rules; write log.sod_violations
48	gmmr_maintain	t	2026-06-11 06:49:02.620584	3600	Partition maintenance + duplicate cleanup for general_metric_metadata_results
49	sensitive_column_access_scan	t	2026-07-08 18:00:00	60	SEC-SQL-PRI-001-RC15: flag captured queries referencing a known sensitive table/column (metrics.sensitive_columns via v_sec_sql_pri_001_rc12 x v_sec_sql_acc_011_rc02)
\.
INSERT INTO metrics.registered_processes (row_id, process_name, is_active, entry_date, "interval", description)
SELECT row_id, process_name, is_active, entry_date, "interval", description FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM metrics.registered_processes);
DROP TABLE _stg_load;

SELECT setval('metrics.registered_processes_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM metrics.registered_processes),1), (SELECT count(*) FROM metrics.registered_processes) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'metrics' AND c.relname = 'registered_processes'
          AND con.conname = 'registered_processes_pkey') THEN
        ALTER TABLE ONLY metrics.registered_processes
    ADD CONSTRAINT registered_processes_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'metrics' AND c.relname = 'registered_processes'
          AND con.conname = 'registered_processes_process_name_key') THEN
        ALTER TABLE ONLY metrics.registered_processes
    ADD CONSTRAINT registered_processes_process_name_key UNIQUE (process_name);
    END IF;
END $do$;
