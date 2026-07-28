-- Idempotent install for rootcause.issues
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS rootcause;

CREATE TABLE IF NOT EXISTS rootcause.issues (
    issue_id character varying(30) NOT NULL,
    domain_code character varying(10) NOT NULL,
    database_type_code character varying(10) NOT NULL,
    area_code character varying(10) NOT NULL,
    name character varying(300) NOT NULL,
    slug character varying(300) NOT NULL,
    description text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    category_id character(4)
);

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE rootcause.issues);
COPY _stg_load (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at, category_id) FROM stdin;
PERF-SQL-TX-010	PERF	SQL	TX	Active Transactions Monitoring	active-transactions-monitoring	Retrieves all currently running transactions with login, program, database, query text, and duration. Provides baseline visibility into what is executing on the server at any point in time.	2026-04-05 08:15:50.318997	2026-04-05 08:15:50.318997	\N
PERF-SQL-CN-010	PERF	SQL	CN	Active Connections Monitoring	active-connections-monitoring	Retrieves all current database connections with login, host, program, status, and connection time. Provides baseline visibility into who is connected to the server.	2026-04-05 08:15:56.749579	2026-04-05 08:15:56.749579	\N
HLTH-KV-STOR-002	HLTH	KV	STOR	SSD Wear	ssd-wear	\N	2026-02-23 20:18:30.398783	2026-02-23 20:18:30.398783	c002
PERF-SQL-QE-001	PERF	SQL	QE	Slow Query Execution	slow-query-execution	\N	2026-02-23 20:18:30.398336	2026-02-23 20:18:30.398341	c001
PERF-SQL-QE-002	PERF	SQL	QE	Full Table Scan	full-table-scan	\N	2026-02-23 20:18:30.398343	2026-02-23 20:18:30.398344	c002
PERF-SQL-QE-003	PERF	SQL	QE	Suboptimal Execution Plan	suboptimal-execution-plan	\N	2026-02-23 20:18:30.398345	2026-02-23 20:18:30.398345	c003
PERF-SQL-QE-004	PERF	SQL	QE	Parameter Sniffing	parameter-sniffing	\N	2026-02-23 20:18:30.398346	2026-02-23 20:18:30.398346	c004
PERF-SQL-QE-005	PERF	SQL	QE	Implicit Data Type Conversion	implicit-data-type-conversion	\N	2026-02-23 20:18:30.398347	2026-02-23 20:18:30.398348	c005
PERF-SQL-QE-006	PERF	SQL	QE	Correlated Subquery	correlated-subquery	\N	2026-02-23 20:18:30.398348	2026-02-23 20:18:30.398349	c006
PERF-SQL-QE-007	PERF	SQL	QE	Inefficient JOIN	inefficient-join	\N	2026-02-23 20:18:30.398349	2026-02-23 20:18:30.39835	c007
PERF-SQL-QE-008	PERF	SQL	QE	Sort/Hash Spill to Disk	sorthash-spill-to-disk-qe-008	\N	2026-02-23 20:18:30.398351	2026-02-23 20:18:30.398351	c008
PERF-SQL-IX-001	PERF	SQL	IX	Missing Index	missing-index	\N	2026-02-23 20:18:30.398352	2026-02-23 20:18:30.398352	c001
PERF-SQL-IX-002	PERF	SQL	IX	Unused Index	unused-index	\N	2026-02-23 20:18:30.398353	2026-02-23 20:18:30.398353	c002
PERF-SQL-IX-003	PERF	SQL	IX	Index Fragmentation	index-fragmentation	\N	2026-02-23 20:18:30.398354	2026-02-23 20:18:30.398355	c003
PERF-SQL-IX-004	PERF	SQL	IX	Redundant/Duplicate Index	redundantduplicate-index	\N	2026-02-23 20:18:30.398355	2026-02-23 20:18:30.398356	c004
PERF-SQL-IX-005	PERF	SQL	IX	Non-Selective Index	non-selective-index	\N	2026-02-23 20:18:30.398356	2026-02-23 20:18:30.398357	c005
PERF-SQL-IX-006	PERF	SQL	IX	Over-Indexing	over-indexing	\N	2026-02-23 20:18:30.398358	2026-02-23 20:18:30.398358	c006
PERF-SQL-IX-007	PERF	SQL	IX	Index Key Too Wide	index-key-too-wide	\N	2026-02-23 20:18:30.398359	2026-02-23 20:18:30.398359	c007
PERF-SQL-LC-001	PERF	SQL	LC	Deadlock	deadlock	\N	2026-02-23 20:18:30.39836	2026-02-23 20:18:30.39836	c001
PERF-SQL-LC-002	PERF	SQL	LC	Lock Wait Timeout	lock-wait-timeout	\N	2026-02-23 20:18:30.398361	2026-02-23 20:18:30.398361	c002
PERF-SQL-LC-003	PERF	SQL	LC	Blocking Query	blocking-query	\N	2026-02-23 20:18:30.398362	2026-02-23 20:18:30.398363	c003
PERF-SQL-LC-004	PERF	SQL	LC	Latch Contention	latch-contention	\N	2026-02-23 20:18:30.398363	2026-02-23 20:18:30.398364	c004
PERF-SQL-LC-005	PERF	SQL	LC	Long-Running Transaction	long-running-transaction-lc-005	\N	2026-02-23 20:18:30.398365	2026-02-23 20:18:30.398365	c005
PERF-SQL-CPU-001	PERF	SQL	CPU	High CPU Utilization	high-cpu-utilization	\N	2026-02-23 20:18:30.398366	2026-02-23 20:18:30.398366	c001
PERF-SQL-CPU-002	PERF	SQL	CPU	Excessive Compilation/Recompilation	excessive-compilationrecompilation	\N	2026-02-23 20:18:30.398367	2026-02-23 20:18:30.398367	c002
PERF-SQL-CPU-003	PERF	SQL	CPU	Inefficient Parallelism	inefficient-parallelism	\N	2026-02-23 20:18:30.398368	2026-02-23 20:18:30.398369	c003
PERF-SQL-CPU-004	PERF	SQL	CPU	Outdated Statistics	outdated-statistics	\N	2026-02-23 20:18:30.398369	2026-02-23 20:18:30.39837	c004
PERF-SQL-MEM-001	PERF	SQL	MEM	Memory Pressure	memory-pressure	\N	2026-02-23 20:18:30.39837	2026-02-23 20:18:30.398371	c001
PERF-SQL-MEM-002	PERF	SQL	MEM	Sort/Hash Spill to Disk	sorthash-spill-to-disk-mem-002	\N	2026-02-23 20:18:30.398371	2026-02-23 20:18:30.398372	c002
PERF-SQL-MEM-003	PERF	SQL	MEM	Low Buffer Cache Hit Ratio	low-buffer-cache-hit-ratio	\N	2026-02-23 20:18:30.398373	2026-02-23 20:18:30.398373	c003
PERF-SQL-MEM-004	PERF	SQL	MEM	Memory Grant Overestimation	memory-grant-overestimation	\N	2026-02-23 20:18:30.398374	2026-02-23 20:18:30.398374	c004
PERF-SQL-IO-001	PERF	SQL	IO	High Disk Latency	high-disk-latency	\N	2026-02-23 20:18:30.398375	2026-02-23 20:18:30.398375	c001
PERF-SQL-IO-002	PERF	SQL	IO	Transaction Log Contention	transaction-log-contention	\N	2026-02-23 20:18:30.398376	2026-02-23 20:18:30.398377	c002
PERF-SQL-IO-003	PERF	SQL	IO	Checkpoint I/O Spikes	checkpoint-io-spikes	\N	2026-02-23 20:18:30.398377	2026-02-23 20:18:30.398378	c003
PERF-SQL-CN-001	PERF	SQL	CN	Connection Pool Exhaustion	connection-pool-exhaustion-cn-001	\N	2026-02-23 20:18:30.398379	2026-02-23 20:18:30.39838	c001
PERF-SQL-CN-002	PERF	SQL	CN	Connection Leak	connection-leak	\N	2026-02-23 20:18:30.398381	2026-02-23 20:18:30.398381	c002
PERF-SQL-CN-003	PERF	SQL	CN	Excessive Connection Churn	excessive-connection-churn	\N	2026-02-23 20:18:30.398382	2026-02-23 20:18:30.398382	c003
PERF-SQL-CN-004	PERF	SQL	CN	Max Connections Reached	max-connections-reached	\N	2026-02-23 20:18:30.398383	2026-02-23 20:18:30.398383	c004
PERF-SQL-CE-001	PERF	SQL	CE	Buffer Pool Pressure	buffer-pool-pressure	\N	2026-02-23 20:18:30.398384	2026-02-23 20:18:30.398384	c001
PERF-SQL-CE-002	PERF	SQL	CE	Plan Cache Bloat	plan-cache-bloat	\N	2026-02-23 20:18:30.398385	2026-02-23 20:18:30.398386	c002
PERF-SQL-CE-003	PERF	SQL	CE	Table Bloat	table-bloat	\N	2026-02-23 20:18:30.398386	2026-02-23 20:18:30.398387	c003
PERF-SQL-CE-004	PERF	SQL	CE	Query Cache Inefficiency	query-cache-inefficiency	\N	2026-02-23 20:18:30.398387	2026-02-23 20:18:30.398388	c004
PERF-SQL-CE-005	PERF	SQL	CE	Page Splits	page-splits	\N	2026-02-23 20:18:30.398388	2026-02-23 20:18:30.398389	c005
PERF-SQL-PL-001	PERF	SQL	PL	Excessive Parallelism	excessive-parallelism	\N	2026-02-23 20:18:30.39839	2026-02-23 20:18:30.39839	c001
PERF-SQL-PL-002	PERF	SQL	PL	Parallel Thread Imbalance	parallel-thread-imbalance	\N	2026-02-23 20:18:30.398391	2026-02-23 20:18:30.398391	c002
PERF-SQL-PL-003	PERF	SQL	PL	Worker Thread Starvation	worker-thread-starvation	\N	2026-02-23 20:18:30.398392	2026-02-23 20:18:30.398392	c003
PERF-SQL-PL-004	PERF	SQL	PL	Parallel Exchange Spills	parallel-exchange-spills	\N	2026-02-23 20:18:30.398393	2026-02-23 20:18:30.398394	c004
PERF-SQL-TX-001	PERF	SQL	TX	Long-Running Transaction	long-running-transaction-tx-001	\N	2026-02-23 20:18:30.398394	2026-02-23 20:18:30.398395	c001
PERF-SQL-TX-002	PERF	SQL	TX	Transaction Log Growth	transaction-log-growth	\N	2026-02-23 20:18:30.398395	2026-02-23 20:18:30.398396	c002
PERF-SQL-TX-003	PERF	SQL	TX	Orphaned Transaction	orphaned-transaction	\N	2026-02-23 20:18:30.398396	2026-02-23 20:18:30.398397	c003
PERF-SQL-TX-004	PERF	SQL	TX	Excessive Rollbacks	excessive-rollbacks	\N	2026-02-23 20:18:30.398398	2026-02-23 20:18:30.398398	c004
PERF-SQL-VS-003	PERF	SQL	VS	ROS Pushback (Vertica)	ros-pushback-vertica	\N	2026-02-23 20:18:30.398401	2026-02-23 20:18:30.398401	c003
PERF-SQL-VS-004	PERF	SQL	VS	WOS Spill (Vertica)	wos-spill-vertica	\N	2026-02-23 20:18:30.398402	2026-02-23 20:18:30.398403	c004
HLTH-SQL-BR-001	HLTH	SQL	BR	Backup Job Failure	backup-job-failure	\N	2026-02-23 20:18:30.398403	2026-02-23 20:18:30.398404	c001
HLTH-SQL-BR-002	HLTH	SQL	BR	Backup Validation Failure	backup-validation-failure	\N	2026-02-23 20:18:30.398404	2026-02-23 20:18:30.398405	c002
HLTH-SQL-BR-003	HLTH	SQL	BR	Recovery Point Gap	recovery-point-gap	\N	2026-02-23 20:18:30.398406	2026-02-23 20:18:30.398406	c003
HLTH-SQL-BR-004	HLTH	SQL	BR	PITR Unavailable	pitr-unavailable	\N	2026-02-23 20:18:30.398407	2026-02-23 20:18:30.398407	c004
HLTH-SQL-BR-005	HLTH	SQL	BR	Backup Retention Policy Violation	backup-retention-policy-violation	\N	2026-02-23 20:18:30.398408	2026-02-23 20:18:30.398408	c005
HLTH-SQL-BR-006	HLTH	SQL	BR	Backup Chain Broken	backup-chain-broken	\N	2026-02-23 20:18:30.398409	2026-02-23 20:18:30.398409	c006
HLTH-SQL-BR-007	HLTH	SQL	BR	Backup Storage Critical	backup-storage-critical	\N	2026-02-23 20:18:30.39841	2026-02-23 20:18:30.398411	c007
HLTH-SQL-RP-001	HLTH	SQL	RP	Replication Lag Excessive	replication-lag-excessive	\N	2026-02-23 20:18:30.398411	2026-02-23 20:18:30.398412	c001
HLTH-SQL-RP-002	HLTH	SQL	RP	Replication Stopped/Broken	replication-stoppedbroken	\N	2026-02-23 20:18:30.398412	2026-02-23 20:18:30.398413	c002
HLTH-SQL-RP-003	HLTH	SQL	RP	Split-Brain Scenario	split-brain-scenario	\N	2026-02-23 20:18:30.398413	2026-02-23 20:18:30.398414	c003
HLTH-SQL-RP-005	HLTH	SQL	RP	Synchronous Replication Timeout	synchronous-replication-timeout	\N	2026-02-23 20:18:30.398415	2026-02-23 20:18:30.398415	c005
HLTH-SQL-RP-006	HLTH	SQL	RP	Replication Conflict	replication-conflict	\N	2026-02-23 20:18:30.398416	2026-02-23 20:18:30.398416	c006
HLTH-SQL-SM-001	HLTH	SQL	SM	Disk Space Critical	disk-space-critical	\N	2026-02-23 20:18:30.398417	2026-02-23 20:18:30.398417	c001
HLTH-SQL-SM-002	HLTH	SQL	SM	Tablespace Growth Abnormal	tablespace-growth-abnormal	\N	2026-02-23 20:18:30.398418	2026-02-23 20:18:30.398419	c002
HLTH-SQL-SM-003	HLTH	SQL	SM	Data File Auto-Growth Excessive	data-file-auto-growth-excessive	\N	2026-02-23 20:18:30.398419	2026-02-23 20:18:30.39842	c003
HLTH-SQL-SM-005	HLTH	SQL	SM	Data File Corruption	data-file-corruption	\N	2026-02-23 20:18:30.398421	2026-02-23 20:18:30.398422	c005
HLTH-SQL-SM-006	HLTH	SQL	SM	I/O Latency Degradation	io-latency-degradation	\N	2026-02-23 20:18:30.398423	2026-02-23 20:18:30.398423	c006
HLTH-SQL-SM-007	HLTH	SQL	SM	Log File Growth Uncontrolled	log-file-growth-uncontrolled	\N	2026-02-23 20:18:30.398424	2026-02-23 20:18:30.398424	c007
HLTH-SQL-HA-001	HLTH	SQL	HA	Failover Readiness Degraded	failover-readiness-degraded	\N	2026-02-23 20:18:30.398425	2026-02-23 20:18:30.398426	c001
HLTH-SQL-HA-002	HLTH	SQL	HA	Cluster Node Down	cluster-node-down	\N	2026-02-23 20:18:30.398426	2026-02-23 20:18:30.398427	c002
HLTH-SQL-HA-003	HLTH	SQL	HA	Automatic Failover Failed	automatic-failover-failed	\N	2026-02-23 20:18:30.398427	2026-02-23 20:18:30.398428	c003
HLTH-SQL-HA-004	HLTH	SQL	HA	Load Balancer Health Check Failing	load-balancer-health-check-failing	\N	2026-02-23 20:18:30.398428	2026-02-23 20:18:30.398429	c004
HLTH-SQL-HA-005	HLTH	SQL	HA	Quorum Loss	quorum-loss	\N	2026-02-23 20:18:30.39843	2026-02-23 20:18:30.39843	c005
HLTH-SQL-HA-006	HLTH	SQL	HA	Witness/Arbiter Unavailable	witnessarbiter-unavailable	\N	2026-02-23 20:18:30.398431	2026-02-23 20:18:30.398431	c006
HLTH-SQL-DM-002	HLTH	SQL	DM	Statistics Stale	statistics-stale	\N	2026-02-23 20:18:30.398432	2026-02-23 20:18:30.398432	c002
HLTH-SQL-DM-003	HLTH	SQL	DM	Table/Index Bloat	tableindex-bloat	\N	2026-02-23 20:18:30.398433	2026-02-23 20:18:30.398433	c003
HLTH-SQL-DM-004	HLTH	SQL	DM	Index Fragmentation High	index-fragmentation-high	\N	2026-02-23 20:18:30.398434	2026-02-23 20:18:30.398435	c004
HLTH-SQL-DM-006	HLTH	SQL	DM	Integrity Check Overdue	integrity-check-overdue	\N	2026-02-23 20:18:30.398436	2026-02-23 20:18:30.398437	c006
HLTH-SQL-DM-007	HLTH	SQL	DM	Maintenance Plan Failed	maintenance-plan-failed	\N	2026-02-23 20:18:30.398438	2026-02-23 20:18:30.398438	c007
HLTH-SQL-LM-001	HLTH	SQL	LM	Transaction Log Space Critical	transaction-log-space-critical	\N	2026-02-23 20:18:30.398439	2026-02-23 20:18:30.398439	c001
HLTH-SQL-LM-006	HLTH	SQL	LM	PITR Disabled	pitr-disabled	\N	2026-02-23 20:18:30.398443	2026-02-23 20:18:30.398444	c006
HLTH-SQL-SJ-001	HLTH	SQL	SJ	Critical Job Failure	critical-job-failure	\N	2026-02-23 20:18:30.398444	2026-02-23 20:18:30.398445	c001
HLTH-SQL-SJ-002	HLTH	SQL	SJ	Job Missed/Skipped	job-missedskipped	\N	2026-02-23 20:18:30.398445	2026-02-23 20:18:30.398446	c002
HLTH-SQL-SJ-003	HLTH	SQL	SJ	Job Duration Exceeded	job-duration-exceeded	\N	2026-02-23 20:18:30.398447	2026-02-23 20:18:30.398447	c003
HLTH-SQL-SJ-004	HLTH	SQL	SJ	Jobs Overlapping Peak Hours	jobs-overlapping-peak-hours	\N	2026-02-23 20:18:30.398448	2026-02-23 20:18:30.398448	c004
HLTH-SQL-SJ-005	HLTH	SQL	SJ	ETL Job Failure	etl-job-failure	\N	2026-02-23 20:18:30.398449	2026-02-23 20:18:30.398449	c005
HLTH-SQL-UP-001	HLTH	SQL	UP	Version Out of Support	version-out-of-support	\N	2026-02-23 20:18:30.39845	2026-02-23 20:18:30.398451	c001
HLTH-SQL-UP-002	HLTH	SQL	UP	Critical Security Patch Missing	critical-security-patch-missing	\N	2026-02-23 20:18:30.398451	2026-02-23 20:18:30.398452	c002
HLTH-SQL-UP-003	HLTH	SQL	UP	Patch Level Inconsistent	patch-level-inconsistent	\N	2026-02-23 20:18:30.398452	2026-02-23 20:18:30.398453	c003
HLTH-SQL-UP-004	HLTH	SQL	UP	Upgrade/Patch Failed	upgradepatch-failed	\N	2026-02-23 20:18:30.398453	2026-02-23 20:18:30.398454	c004
HLTH-SQL-CD-001	HLTH	SQL	CD	Parameter Changed	parameter-changed	\N	2026-02-23 20:18:30.398455	2026-02-23 20:18:30.398455	c001
HLTH-SQL-CD-002	HLTH	SQL	CD	Critical Parameter Misconfigured	critical-parameter-misconfigured	\N	2026-02-23 20:18:30.398456	2026-02-23 20:18:30.398456	c002
HLTH-SQL-CD-003	HLTH	SQL	CD	Cluster Config Inconsistent	cluster-config-inconsistent	\N	2026-02-23 20:18:30.398457	2026-02-23 20:18:30.398457	c003
HLTH-SQL-CD-004	HLTH	SQL	CD	Security Config Weakened	security-config-weakened	\N	2026-02-23 20:18:30.398458	2026-02-23 20:18:30.398458	c004
HLTH-SQL-CD-005	HLTH	SQL	CD	Privilege Escalation Detected	privilege-escalation-detected	\N	2026-02-23 20:18:30.398459	2026-02-23 20:18:30.39846	c005
HLTH-SQL-AD-001	HLTH	SQL	AD	Connection Pool Exhaustion	connection-pool-exhaustion-ad-001	\N	2026-02-23 20:18:30.39846	2026-02-23 20:18:30.398461	c001
HLTH-SQL-AD-002	HLTH	SQL	AD	Deadlock Frequency Elevated	deadlock-frequency-elevated	\N	2026-02-23 20:18:30.398461	2026-02-23 20:18:30.398462	c002
HLTH-SQL-AD-003	HLTH	SQL	AD	Unexpected Instance Restart	unexpected-instance-restart	\N	2026-02-23 20:18:30.398462	2026-02-23 20:18:30.398463	c003
SEC-SQL-AU-001	SEC	SQL	AU	Default Admin Accounts Enabled	default-admin-accounts-enabled	\N	2026-02-23 20:18:30.398464	2026-02-23 20:18:30.398465	c001
SEC-SQL-AU-002	SEC	SQL	AU	Empty/Blank Passwords Allowed	emptyblank-passwords-allowed	\N	2026-02-23 20:18:30.398465	2026-02-23 20:18:30.398466	c002
SEC-SQL-AU-003	SEC	SQL	AU	Weak Password Policy	weak-password-policy	\N	2026-02-23 20:18:30.398466	2026-02-23 20:18:30.398467	c003
SEC-SQL-AU-004	SEC	SQL	AU	Remote OS Authentication Enabled	remote-os-authentication-enabled	\N	2026-02-23 20:18:30.398468	2026-02-23 20:18:30.398468	c004
SEC-SQL-AU-005	SEC	SQL	AU	Mixed Mode Authentication	mixed-mode-authentication	\N	2026-02-23 20:18:30.398469	2026-02-23 20:18:30.398469	c005
SEC-SQL-AU-006	SEC	SQL	AU	Dormant/Unused Accounts	dormantunused-accounts	\N	2026-02-23 20:18:30.39847	2026-02-23 20:18:30.39847	c006
SEC-SQL-AU-007	SEC	SQL	AU	Trust Authentication Enabled	trust-authentication-enabled	\N	2026-02-23 20:18:30.398471	2026-02-23 20:18:30.398472	c007
SEC-SQL-AZ-001	SEC	SQL	AZ	Excessive Administrative Privileges	excessive-administrative-privileges	\N	2026-02-23 20:18:30.398472	2026-02-23 20:18:30.398473	c001
SEC-SQL-AZ-002	SEC	SQL	AZ	rootcause Role Excessive Access	rootcause-role-excessive-access	\N	2026-02-23 20:18:30.398473	2026-02-23 20:18:30.398474	c002
SEC-SQL-AZ-003	SEC	SQL	AZ	Orphaned User Accounts	orphaned-user-accounts	\N	2026-02-23 20:18:30.398474	2026-02-23 20:18:30.398475	c003
SEC-SQL-AZ-004	SEC	SQL	AZ	File System Access Privilege	file-system-access-privilege	\N	2026-02-23 20:18:30.398476	2026-02-23 20:18:30.398476	c004
SEC-SQL-AZ-005	SEC	SQL	AZ	Cross-Database Ownership Chaining	cross-database-ownership-chaining	\N	2026-02-23 20:18:30.398477	2026-02-23 20:18:30.398477	c005
SEC-SQL-AZ-006	SEC	SQL	AZ	Grant Option Abuse	grant-option-abuse	\N	2026-02-23 20:18:30.398478	2026-02-23 20:18:30.398478	c006
SEC-SQL-ENC-001	SEC	SQL	ENC	Data-in-Transit Unencrypted	data-in-transit-unencrypted	\N	2026-02-23 20:18:30.398479	2026-02-23 20:18:30.39848	c001
SEC-SQL-ENC-002	SEC	SQL	ENC	Obsolete TLS Versions	obsolete-tls-versions	\N	2026-02-23 20:18:30.39848	2026-02-23 20:18:30.398481	c002
SEC-SQL-ENC-003	SEC	SQL	ENC	Transparent Data Encryption Disabled	transparent-data-encryption-disabled	\N	2026-02-23 20:18:30.398481	2026-02-23 20:18:30.398482	c003
SEC-SQL-ENC-004	SEC	SQL	ENC	Unencrypted Backups	unencrypted-backups	\N	2026-02-23 20:18:30.398482	2026-02-23 20:18:30.398483	c004
SEC-SQL-ENC-005	SEC	SQL	ENC	Weak Encryption Keys/Ciphers	weak-encryption-keysciphers	\N	2026-02-23 20:18:30.398484	2026-02-23 20:18:30.398484	c005
SEC-SQL-AUD-001	SEC	SQL	AUD	Audit Logging Disabled	audit-logging-disabled	\N	2026-02-23 20:18:30.398485	2026-02-23 20:18:30.398485	c001
SEC-SQL-AUD-002	SEC	SQL	AUD	Inadequate Log Retention	inadequate-log-retention	\N	2026-02-23 20:18:30.398486	2026-02-23 20:18:30.398487	c002
SEC-SQL-AUD-003	SEC	SQL	AUD	Audit Trail Modification Risk	audit-trail-modification-risk	\N	2026-02-23 20:18:30.398487	2026-02-23 20:18:30.398488	c003
SEC-SQL-AUD-004	SEC	SQL	AUD	Missing Login Failure Logs	missing-login-failure-logs	\N	2026-02-23 20:18:30.398488	2026-02-23 20:18:30.398489	c004
SEC-SQL-AUD-005	SEC	SQL	AUD	DDL Logging Disabled	ddl-logging-disabled	\N	2026-02-23 20:18:30.39849	2026-02-23 20:18:30.39849	c005
SEC-SQL-NET-001	SEC	SQL	NET	Database Exposed to rootcause Internet	database-exposed-to-rootcause-internet	\N	2026-02-23 20:18:30.398491	2026-02-23 20:18:30.398491	c001
SEC-SQL-NET-002	SEC	SQL	NET	Default Ports in Use	default-ports-in-use	\N	2026-02-23 20:18:30.398492	2026-02-23 20:18:30.398492	c002
SEC-SQL-NET-003	SEC	SQL	NET	Unrestricted Outbound Connections	unrestricted-outbound-connections	\N	2026-02-23 20:18:30.398493	2026-02-23 20:18:30.398493	c003
SEC-SQL-CFG-003	SEC	SQL	CFG	Sample/Test Databases Present	sampletest-databases-present	\N	2026-02-23 20:18:30.398496	2026-02-23 20:18:30.398497	c003
SEC-SQL-CFG-005	SEC	SQL	CFG	Debug/Trace Flags Enabled	debugtrace-flags-enabled	\N	2026-02-23 20:18:30.398499	2026-02-23 20:18:30.398499	c005
SEC-SQL-CFG-006	SEC	SQL	CFG	Database Links Unsecured	database-links-unsecured	\N	2026-02-23 20:18:30.3985	2026-02-23 20:18:30.3985	c006
SEC-SQL-INJ-001	SEC	SQL	INJ	Dynamic SQL in Stored Procedures	dynamic-sql-in-stored-procedures	\N	2026-02-23 20:18:30.398501	2026-02-23 20:18:30.398501	c001
SEC-SQL-INJ-002	SEC	SQL	INJ	Extended Stored Procedures in Use	extended-stored-procedures-in-use	\N	2026-02-23 20:18:30.398502	2026-02-23 20:18:30.398503	c002
SEC-SQL-PAT-001	SEC	SQL	PAT	End-of-Life Database Version	end-of-life-database-version	\N	2026-02-23 20:18:30.398503	2026-02-23 20:18:30.398504	c001
SEC-SQL-PAT-002	SEC	SQL	PAT	Missing Critical Security Patches	missing-critical-security-patches	\N	2026-02-23 20:18:30.398504	2026-02-23 20:18:30.398505	c002
SEC-SQL-PRI-001	SEC	SQL	PRI	PII Exposed in Clear Text	pii-exposed-in-clear-text	\N	2026-02-23 20:18:30.398506	2026-02-23 20:18:30.398506	c001
SEC-SQL-PRI-002	SEC	SQL	PRI	Sensitive Data in Logs	sensitive-data-in-logs	\N	2026-02-23 20:18:30.398507	2026-02-23 20:18:30.398507	c002
PERF-DOC-QRY-001	PERF	DOC	QRY	Slow Query Execution	slow-query-execution	\N	2026-02-23 20:18:30.398511	2026-02-23 20:18:30.398512	c001
PERF-DOC-QRY-002	PERF	DOC	QRY	Collection Scan (COLLSCAN)	collection-scan-collscan	\N	2026-02-23 20:18:30.398512	2026-02-23 20:18:30.398513	c002
PERF-DOC-QRY-003	PERF	DOC	QRY	Inefficient Aggregation Pipeline	inefficient-aggregation-pipeline	\N	2026-02-23 20:18:30.398513	2026-02-23 20:18:30.398514	c003
PERF-DOC-QRY-004	PERF	DOC	QRY	Missing Projection Optimization	missing-projection-optimization	\N	2026-02-23 20:18:30.398515	2026-02-23 20:18:30.398515	c004
PERF-DOC-QRY-005	PERF	DOC	QRY	Regex Query Without Index	regex-query-without-index	\N	2026-02-23 20:18:30.398516	2026-02-23 20:18:30.398516	c005
PERF-DOC-QRY-006	PERF	DOC	QRY	Inefficient Sort Operation	inefficient-sort-operation	\N	2026-02-23 20:18:30.398517	2026-02-23 20:18:30.398517	c006
PERF-DOC-QRY-007	PERF	DOC	QRY	Excessive Skip/Limit Offset	excessive-skiplimit-offset	\N	2026-02-23 20:18:30.398518	2026-02-23 20:18:30.398519	c007
PERF-DOC-QRY-008	PERF	DOC	QRY	Query Result Set Too Large	query-result-set-too-large	\N	2026-02-23 20:18:30.398519	2026-02-23 20:18:30.39852	c008
HLTH-KV-STOR-003	HLTH	KV	STOR	I/O Bottleneck	io-bottleneck	\N	2026-02-23 20:18:30.398784	2026-02-23 20:18:30.398785	c003
PERF-DOC-QRY-009	PERF	DOC	QRY	\\$where JavaScript Evaluation	where-javascript-evaluation	\N	2026-02-23 20:18:30.39852	2026-02-23 20:18:30.398521	c009
PERF-DOC-QRY-010	PERF	DOC	QRY	Unoptimized \\$lookup Operations	unoptimized-lookup-operations	\N	2026-02-23 20:18:30.398521	2026-02-23 20:18:30.398522	c010
PERF-DOC-IDX-001	PERF	DOC	IDX	Missing Required Indexes	missing-required-indexes	\N	2026-02-23 20:18:30.398523	2026-02-23 20:18:30.398523	c001
PERF-DOC-IDX-002	PERF	DOC	IDX	Unused Indexes	unused-indexes	\N	2026-02-23 20:18:30.398524	2026-02-23 20:18:30.398524	c002
PERF-DOC-IDX-003	PERF	DOC	IDX	Redundant/Duplicate Indexes	redundantduplicate-indexes	\N	2026-02-23 20:18:30.398525	2026-02-23 20:18:30.398525	c003
PERF-DOC-IDX-004	PERF	DOC	IDX	Non-Covered Query	non-covered-query	\N	2026-02-23 20:18:30.398526	2026-02-23 20:18:30.398527	c004
PERF-DOC-IDX-005	PERF	DOC	IDX	Wrong Index Selected	wrong-index-selected	\N	2026-02-23 20:18:30.398527	2026-02-23 20:18:30.398528	c005
PERF-DOC-IDX-006	PERF	DOC	IDX	Compound Index Wrong Order	compound-index-wrong-order	\N	2026-02-23 20:18:30.398528	2026-02-23 20:18:30.398529	c006
PERF-DOC-IDX-007	PERF	DOC	IDX	Index Selectivity Too Low	index-selectivity-too-low	\N	2026-02-23 20:18:30.398529	2026-02-23 20:18:30.39853	c007
PERF-DOC-IDX-008	PERF	DOC	IDX	Index Bloat/Fragmentation	index-bloatfragmentation	\N	2026-02-23 20:18:30.398531	2026-02-23 20:18:30.398531	c008
PERF-DOC-IDX-009	PERF	DOC	IDX	Missing Text/FTS Index	missing-textfts-index	\N	2026-02-23 20:18:30.398532	2026-02-23 20:18:30.398532	c009
PERF-DOC-IDX-010	PERF	DOC	IDX	Index Build In Progress	index-build-in-progress	\N	2026-02-23 20:18:30.398533	2026-02-23 20:18:30.398533	c010
PERF-DOC-IDX-011	PERF	DOC	IDX	Array Index Inefficiency	array-index-inefficiency	\N	2026-02-23 20:18:30.398534	2026-02-23 20:18:30.398535	c011
PERF-DOC-IDX-012	PERF	DOC	IDX	Partial Index Not Utilized	partial-index-not-utilized	\N	2026-02-23 20:18:30.398535	2026-02-23 20:18:30.398536	c012
PERF-DOC-DOC-001	PERF	DOC	DOC	Unbounded Array Growth	unbounded-array-growth	\N	2026-02-23 20:18:30.398536	2026-02-23 20:18:30.398537	c001
PERF-DOC-DOC-002	PERF	DOC	DOC	Document Size Exceeds Limit	document-size-exceeds-limit	\N	2026-02-23 20:18:30.398537	2026-02-23 20:18:30.398538	c002
PERF-DOC-DOC-003	PERF	DOC	DOC	Bloated Documents	bloated-documents	\N	2026-02-23 20:18:30.398539	2026-02-23 20:18:30.398539	c003
PERF-DOC-DOC-004	PERF	DOC	DOC	Over-Normalization	over-normalization	\N	2026-02-23 20:18:30.39854	2026-02-23 20:18:30.39854	c004
PERF-DOC-DOC-005	PERF	DOC	DOC	Over-Embedding	over-embedding	\N	2026-02-23 20:18:30.398541	2026-02-23 20:18:30.398541	c005
PERF-DOC-DOC-006	PERF	DOC	DOC	Missing Extended Reference	missing-extended-reference	\N	2026-02-23 20:18:30.398542	2026-02-23 20:18:30.398542	c006
PERF-DOC-DOC-007	PERF	DOC	DOC	Inefficient Array Updates	inefficient-array-updates	\N	2026-02-23 20:18:30.398543	2026-02-23 20:18:30.398544	c007
PERF-DOC-DOC-008	PERF	DOC	DOC	Large String Fields	large-string-fields	\N	2026-02-23 20:18:30.398544	2026-02-23 20:18:30.398545	c008
PERF-DOC-DOC-009	PERF	DOC	DOC	Polymorphic Schema Issues	polymorphic-schema-issues	\N	2026-02-23 20:18:30.398545	2026-02-23 20:18:30.398546	c009
PERF-DOC-DOC-010	PERF	DOC	DOC	Missing Schema Validation	missing-schema-validation	\N	2026-02-23 20:18:30.398547	2026-02-23 20:18:30.398547	c010
PERF-DOC-SHD-001	PERF	DOC	SHD	Hot Shard/Partition	hot-shardpartition	\N	2026-02-23 20:18:30.398548	2026-02-23 20:18:30.398548	c001
PERF-DOC-SHD-002	PERF	DOC	SHD	Poor Shard Key Selection	poor-shard-key-selection	\N	2026-02-23 20:18:30.398549	2026-02-23 20:18:30.398549	c002
PERF-DOC-SHD-003	PERF	DOC	SHD	Jumbo Chunks	jumbo-chunks	\N	2026-02-23 20:18:30.39855	2026-02-23 20:18:30.398551	c003
PERF-DOC-SHD-004	PERF	DOC	SHD	Unbalanced Chunk Distribution	unbalanced-chunk-distribution	\N	2026-02-23 20:18:30.398551	2026-02-23 20:18:30.398552	c004
PERF-DOC-SHD-005	PERF	DOC	SHD	Scatter-Gather Queries	scatter-gather-queries	\N	2026-02-23 20:18:30.398552	2026-02-23 20:18:30.398553	c005
PERF-DOC-SHD-006	PERF	DOC	SHD	Orphaned Documents	orphaned-documents	\N	2026-02-23 20:18:30.398553	2026-02-23 20:18:30.398554	c006
PERF-DOC-SHD-007	PERF	DOC	SHD	Excessive Chunk Migrations	excessive-chunk-migrations	\N	2026-02-23 20:18:30.398555	2026-02-23 20:18:30.398555	c007
PERF-DOC-SHD-008	PERF	DOC	SHD	Range-Based Sharding Issues	range-based-sharding-issues	\N	2026-02-23 20:18:30.398556	2026-02-23 20:18:30.398556	c008
PERF-DOC-SHD-009	PERF	DOC	SHD	Cross-Partition Queries	cross-partition-queries	\N	2026-02-23 20:18:30.398557	2026-02-23 20:18:30.398557	c009
PERF-DOC-SHD-010	PERF	DOC	SHD	Hot Partition Write Throttling	hot-partition-write-throttling	\N	2026-02-23 20:18:30.398558	2026-02-23 20:18:30.398558	c010
PERF-DOC-CON-001	PERF	DOC	CON	Connection Pool Exhaustion	connection-pool-exhaustion	\N	2026-02-23 20:18:30.398559	2026-02-23 20:18:30.39856	c001
PERF-DOC-CON-002	PERF	DOC	CON	Connection Storm	connection-storm	\N	2026-02-23 20:18:30.39856	2026-02-23 20:18:30.398561	c002
PERF-DOC-CON-003	PERF	DOC	CON	Connection Leak	connection-leak	\N	2026-02-23 20:18:30.398562	2026-02-23 20:18:30.398562	c003
PERF-DOC-CON-004	PERF	DOC	CON	Too Many Open Connections	too-many-open-connections	\N	2026-02-23 20:18:30.398563	2026-02-23 20:18:30.398563	c004
PERF-DOC-CON-005	PERF	DOC	CON	Connection Timeout Errors	connection-timeout-errors	\N	2026-02-23 20:18:30.398564	2026-02-23 20:18:30.398564	c005
PERF-DOC-CON-006	PERF	DOC	CON	Inefficient Connection Usage	inefficient-connection-usage	\N	2026-02-23 20:18:30.398565	2026-02-23 20:18:30.398566	c006
PERF-DOC-CON-007	PERF	DOC	CON	Transaction Connection Starvation	transaction-connection-starvation	\N	2026-02-23 20:18:30.398566	2026-02-23 20:18:30.398567	c007
PERF-DOC-CON-008	PERF	DOC	CON	Cursor Timeout Issues	cursor-timeout-issues	\N	2026-02-23 20:18:30.398567	2026-02-23 20:18:30.398568	c008
PERF-DOC-MEM-001	PERF	DOC	MEM	WiredTiger Cache Pressure	wiredtiger-cache-pressure	\N	2026-02-23 20:18:30.398568	2026-02-23 20:18:30.398569	c001
PERF-DOC-MEM-002	PERF	DOC	MEM	Working Set Exceeds Memory	working-set-exceeds-memory	\N	2026-02-23 20:18:30.39857	2026-02-23 20:18:30.39857	c002
PERF-DOC-MEM-003	PERF	DOC	MEM	Memory Fragmentation	memory-fragmentation	\N	2026-02-23 20:18:30.398571	2026-02-23 20:18:30.398571	c003
PERF-DOC-MEM-004	PERF	DOC	MEM	Page Fault Frequency High	page-fault-frequency-high	\N	2026-02-23 20:18:30.398572	2026-02-23 20:18:30.398572	c004
PERF-DOC-MEM-005	PERF	DOC	MEM	Insufficient Cache Hit Ratio	insufficient-cache-hit-ratio	\N	2026-02-23 20:18:30.398573	2026-02-23 20:18:30.398574	c005
PERF-DOC-MEM-006	PERF	DOC	MEM	Memory Leak in Application	memory-leak-in-application	\N	2026-02-23 20:18:30.398574	2026-02-23 20:18:30.398575	c006
PERF-DOC-MEM-007	PERF	DOC	MEM	Query Result Set Memory Overflow	query-result-set-memory-overflow	\N	2026-02-23 20:18:30.398575	2026-02-23 20:18:30.398576	c007
PERF-DOC-MEM-008	PERF	DOC	MEM	Index Memory Overhead	index-memory-overhead	\N	2026-02-23 20:18:30.398576	2026-02-23 20:18:30.398577	c008
PERF-DOC-WRT-001	PERF	DOC	WRT	Write Concern Overhead	write-concern-overhead	\N	2026-02-23 20:18:30.398578	2026-02-23 20:18:30.398578	c001
PERF-DOC-WRT-002	PERF	DOC	WRT	Journal Commit Latency	journal-commit-latency	\N	2026-02-23 20:18:30.398579	2026-02-23 20:18:30.398579	c002
PERF-DOC-WRT-003	PERF	DOC	WRT	Write Lock Contention	write-lock-contention	\N	2026-02-23 20:18:30.39858	2026-02-23 20:18:30.39858	c003
PERF-DOC-WRT-004	PERF	DOC	WRT	Bulk Write Not Optimized	bulk-write-not-optimized	\N	2026-02-23 20:18:30.398581	2026-02-23 20:18:30.398582	c004
PERF-DOC-WRT-005	PERF	DOC	WRT	In-Place Update Impossible	in-place-update-impossible	\N	2026-02-23 20:18:30.398582	2026-02-23 20:18:30.398583	c005
PERF-DOC-WRT-006	PERF	DOC	WRT	Index Overhead on Writes	index-overhead-on-writes	\N	2026-02-23 20:18:30.398583	2026-02-23 20:18:30.398584	c006
PERF-DOC-WRT-007	PERF	DOC	WRT	Unacknowledged Writes	unacknowledged-writes	\N	2026-02-23 20:18:30.398584	2026-02-23 20:18:30.398585	c007
PERF-DOC-WRT-008	PERF	DOC	WRT	Write Throughput Throttling	write-throughput-throttling	\N	2026-02-23 20:18:30.398586	2026-02-23 20:18:30.398586	c008
HLTH-DOC-BAK-001	HLTH	DOC	BAK	Backup Failure	backup-failure	\N	2026-02-23 20:18:30.398587	2026-02-23 20:18:30.398587	c001
HLTH-DOC-BAK-002	HLTH	DOC	BAK	Backup Incomplete	backup-incomplete	\N	2026-02-23 20:18:30.398588	2026-02-23 20:18:30.398588	c002
HLTH-DOC-BAK-003	HLTH	DOC	BAK	Oplog Window Too Small	oplog-window-too-small	\N	2026-02-23 20:18:30.398589	2026-02-23 20:18:30.39859	c003
HLTH-DOC-BAK-004	HLTH	DOC	BAK	PITR Gap Detected	pitr-gap-detected	\N	2026-02-23 20:18:30.39859	2026-02-23 20:18:30.398591	c004
HLTH-DOC-BAK-005	HLTH	DOC	BAK	Backup Retention Not Met	backup-retention-not-met	\N	2026-02-23 20:18:30.398591	2026-02-23 20:18:30.398592	c005
HLTH-DOC-BAK-006	HLTH	DOC	BAK	Slow Backup Performance	slow-backup-performance	\N	2026-02-23 20:18:30.398592	2026-02-23 20:18:30.398593	c006
HLTH-DOC-BAK-007	HLTH	DOC	BAK	Restore Test Failure	restore-test-failure	\N	2026-02-23 20:18:30.398594	2026-02-23 20:18:30.398594	c007
HLTH-DOC-BAK-008	HLTH	DOC	BAK	Backup Storage Full	backup-storage-full	\N	2026-02-23 20:18:30.398595	2026-02-23 20:18:30.398595	c008
HLTH-DOC-BAK-009	HLTH	DOC	BAK	Change Stream Lag	change-stream-lag	\N	2026-02-23 20:18:30.398596	2026-02-23 20:18:30.398596	c009
HLTH-DOC-BAK-010	HLTH	DOC	BAK	Corrupted Backup Detected	corrupted-backup-detected	\N	2026-02-23 20:18:30.398597	2026-02-23 20:18:30.398598	c010
HLTH-DOC-REP-001	HLTH	DOC	REP	Replica Lag Excessive	replica-lag-excessive	\N	2026-02-23 20:18:30.398598	2026-02-23 20:18:30.398599	c001
HLTH-DOC-REP-002	HLTH	DOC	REP	Replication Stopped/Failed	replication-stoppedfailed	\N	2026-02-23 20:18:30.398599	2026-02-23 20:18:30.3986	c002
HLTH-DOC-REP-003	HLTH	DOC	REP	Sync Source Unavailable	sync-source-unavailable	\N	2026-02-23 20:18:30.3986	2026-02-23 20:18:30.398601	c003
HLTH-DOC-REP-004	HLTH	DOC	REP	Election Failure	election-failure	\N	2026-02-23 20:18:30.398602	2026-02-23 20:18:30.398602	c004
HLTH-DOC-REP-005	HLTH	DOC	REP	Split-Brain Scenario	split-brain-scenario	\N	2026-02-23 20:18:30.398603	2026-02-23 20:18:30.398603	c005
HLTH-DOC-REP-006	HLTH	DOC	REP	Rollback Required	rollback-required	\N	2026-02-23 20:18:30.398604	2026-02-23 20:18:30.398604	c006
HLTH-DOC-REP-007	HLTH	DOC	REP	Secondary Falling Too Far Behind	secondary-falling-too-far-behind	\N	2026-02-23 20:18:30.398605	2026-02-23 20:18:30.398606	c007
HLTH-DOC-REP-008	HLTH	DOC	REP	Initial Sync Failure	initial-sync-failure	\N	2026-02-23 20:18:30.398606	2026-02-23 20:18:30.398607	c008
HLTH-DOC-REP-009	HLTH	DOC	REP	Heartbeat Failure	heartbeat-failure	\N	2026-02-23 20:18:30.398607	2026-02-23 20:18:30.398608	c009
HLTH-DOC-REP-010	HLTH	DOC	REP	Arbiter Voting Issues	arbiter-voting-issues	\N	2026-02-23 20:18:30.398609	2026-02-23 20:18:30.398609	c010
HLTH-DOC-REP-011	HLTH	DOC	REP	XDCR Conflict Accumulation	xdcr-conflict-accumulation	\N	2026-02-23 20:18:30.39861	2026-02-23 20:18:30.39861	c011
HLTH-DOC-REP-012	HLTH	DOC	REP	Chained Replication Lag	chained-replication-lag	\N	2026-02-23 20:18:30.398611	2026-02-23 20:18:30.398612	c012
HLTH-DOC-STG-001	HLTH	DOC	STG	Disk Space Critical	disk-space-critical	\N	2026-02-23 20:18:30.398612	2026-02-23 20:18:30.398613	c001
HLTH-DOC-STG-002	HLTH	DOC	STG	Storage Fragmentation High	storage-fragmentation-high	\N	2026-02-23 20:18:30.398613	2026-02-23 20:18:30.398614	c002
HLTH-DOC-STG-003	HLTH	DOC	STG	Compaction Needed	compaction-needed	\N	2026-02-23 20:18:30.398614	2026-02-23 20:18:30.398615	c003
HLTH-DOC-STG-004	HLTH	DOC	STG	Storage Engine Inefficiency	storage-engine-inefficiency	\N	2026-02-23 20:18:30.398616	2026-02-23 20:18:30.398616	c004
HLTH-DOC-STG-005	HLTH	DOC	STG	Data File Corruption	data-file-corruption	\N	2026-02-23 20:18:30.398617	2026-02-23 20:18:30.398617	c005
HLTH-DOC-STG-006	HLTH	DOC	STG	Storage I/O Saturation	storage-io-saturation	\N	2026-02-23 20:18:30.398618	2026-02-23 20:18:30.398618	c006
HLTH-DOC-STG-007	HLTH	DOC	STG	Journal File Growth	journal-file-growth	\N	2026-02-23 20:18:30.398619	2026-02-23 20:18:30.39862	c007
HLTH-DOC-STG-008	HLTH	DOC	STG	High Water Mark Issue	high-water-mark-issue	\N	2026-02-23 20:18:30.39862	2026-02-23 20:18:30.398621	c008
HLTH-DOC-STG-009	HLTH	DOC	STG	Storage Quota Exceeded	storage-quota-exceeded	\N	2026-02-23 20:18:30.398621	2026-02-23 20:18:30.398622	c009
HLTH-DOC-HA-001	HLTH	DOC	HA	Single Point of Failure	single-point-of-failure	\N	2026-02-23 20:18:30.398622	2026-02-23 20:18:30.398623	c001
HLTH-DOC-HA-002	HLTH	DOC	HA	Insufficient Voting Members	insufficient-voting-members	\N	2026-02-23 20:18:30.398624	2026-02-23 20:18:30.398624	c002
HLTH-DOC-HA-003	HLTH	DOC	HA	Node Health Check Failure	node-health-check-failure	\N	2026-02-23 20:18:30.398625	2026-02-23 20:18:30.398625	c003
HLTH-DOC-HA-004	HLTH	DOC	HA	Failover Readiness Untested	failover-readiness-untested	\N	2026-02-23 20:18:30.398626	2026-02-23 20:18:30.398626	c004
HLTH-DOC-HA-005	HLTH	DOC	HA	Geographic Distribution Lacking	geographic-distribution-lacking	\N	2026-02-23 20:18:30.398627	2026-02-23 20:18:30.398628	c005
HLTH-DOC-HA-006	HLTH	DOC	HA	Improper Priority Configuration	improper-priority-configuration	\N	2026-02-23 20:18:30.398628	2026-02-23 20:18:30.398629	c006
HLTH-DOC-HA-007	HLTH	DOC	HA	Connection String Misconfiguration	connection-string-misconfiguration	\N	2026-02-23 20:18:30.398629	2026-02-23 20:18:30.39863	c007
HLTH-DOC-HA-008	HLTH	DOC	HA	Disaster Recovery Plan Missing	disaster-recovery-plan-missing	\N	2026-02-23 20:18:30.39863	2026-02-23 20:18:30.398631	c008
HLTH-DOC-CLU-001	HLTH	DOC	CLU	Balancer Disabled	balancer-disabled	\N	2026-02-23 20:18:30.398632	2026-02-23 20:18:30.398632	c001
HLTH-DOC-CLU-002	HLTH	DOC	CLU	Chunk Migration Failure	chunk-migration-failure	\N	2026-02-23 20:18:30.398633	2026-02-23 20:18:30.398633	c002
HLTH-DOC-CLU-003	HLTH	DOC	CLU	Config Server Unavailable	config-server-unavailable	\N	2026-02-23 20:18:30.398634	2026-02-23 20:18:30.398634	c003
HLTH-DOC-CLU-004	HLTH	DOC	CLU	Shard Unresponsive	shard-unresponsive	\N	2026-02-23 20:18:30.398635	2026-02-23 20:18:30.398636	c004
HLTH-DOC-CLU-005	HLTH	DOC	CLU	Router (mongos) Failure	router-mongos-failure	\N	2026-02-23 20:18:30.398636	2026-02-23 20:18:30.398637	c005
HLTH-DOC-CLU-006	HLTH	DOC	CLU	Metadata Inconsistency	metadata-inconsistency	\N	2026-02-23 20:18:30.398637	2026-02-23 20:18:30.398638	c006
HLTH-DOC-CLU-007	HLTH	DOC	CLU	Balancing Window Misconfigured	balancing-window-misconfigured	\N	2026-02-23 20:18:30.398638	2026-02-23 20:18:30.398639	c007
HLTH-DOC-CLU-008	HLTH	DOC	CLU	Shard Draining Incomplete	shard-draining-incomplete	\N	2026-02-23 20:18:30.39864	2026-02-23 20:18:30.39864	c008
HLTH-DOC-MNT-001	HLTH	DOC	MNT	Index Rebuild Required	index-rebuild-required	\N	2026-02-23 20:18:30.398641	2026-02-23 20:18:30.398641	c001
HLTH-DOC-MNT-002	HLTH	DOC	MNT	Compaction Overdue	compaction-overdue	\N	2026-02-23 20:18:30.398642	2026-02-23 20:18:30.398642	c002
HLTH-DOC-MNT-003	HLTH	DOC	MNT	Repair Operation Needed	repair-operation-needed	\N	2026-02-23 20:18:30.398643	2026-02-23 20:18:30.398644	c003
HLTH-DOC-MNT-004	HLTH	DOC	MNT	Statistics Out of Date	statistics-out-of-date	\N	2026-02-23 20:18:30.398644	2026-02-23 20:18:30.398645	c004
HLTH-DOC-MNT-005	HLTH	DOC	MNT	Upgrade Available	upgrade-available	\N	2026-02-23 20:18:30.398645	2026-02-23 20:18:30.398646	c005
HLTH-DOC-MNT-006	HLTH	DOC	MNT	Index Defragmentation Needed	index-defragmentation-needed	\N	2026-02-23 20:18:30.398646	2026-02-23 20:18:30.398647	c006
HLTH-DOC-LOG-001	HLTH	DOC	LOG	Log Rotation Not Configured	log-rotation-not-configured	\N	2026-02-23 20:18:30.398648	2026-02-23 20:18:30.398648	c001
HLTH-DOC-LOG-002	HLTH	DOC	LOG	Log Disk Full	log-disk-full	\N	2026-02-23 20:18:30.398649	2026-02-23 20:18:30.398649	c002
HLTH-DOC-LOG-003	HLTH	DOC	LOG	Log Level Too Verbose	log-level-too-verbose	\N	2026-02-23 20:18:30.39865	2026-02-23 20:18:30.39865	c003
HLTH-DOC-LOG-004	HLTH	DOC	LOG	Missing Critical Log Events	missing-critical-log-events	\N	2026-02-23 20:18:30.398651	2026-02-23 20:18:30.398652	c004
HLTH-DOC-UPG-001	HLTH	DOC	UPG	Version Incompatibility	version-incompatibility	\N	2026-02-23 20:18:30.398652	2026-02-23 20:18:30.398653	c001
HLTH-DOC-UPG-002	HLTH	DOC	UPG	Rolling Upgrade Failure	rolling-upgrade-failure	\N	2026-02-23 20:18:30.398653	2026-02-23 20:18:30.398654	c002
HLTH-DOC-UPG-003	HLTH	DOC	UPG	Feature Compatibility Version Wrong	feature-compatibility-version-wrong	\N	2026-02-23 20:18:30.398654	2026-02-23 20:18:30.398655	c003
HLTH-DOC-UPG-004	HLTH	DOC	UPG	Deprecated Feature Usage	deprecated-feature-usage	\N	2026-02-23 20:18:30.398656	2026-02-23 20:18:30.398656	c004
HLTH-DOC-UPG-005	HLTH	DOC	UPG	Patch Not Applied	patch-not-applied	\N	2026-02-23 20:18:30.398657	2026-02-23 20:18:30.398657	c005
SEC-DOC-AUTH-001	SEC	DOC	AUTH	Default Credentials in Use	default-credentials-in-use	\N	2026-02-23 20:18:30.398658	2026-02-23 20:18:30.398658	c001
SEC-DOC-AUTH-002	SEC	DOC	AUTH	Weak Password Policy	weak-password-policy	\N	2026-02-23 20:18:30.398659	2026-02-23 20:18:30.39866	c002
SEC-DOC-AUTH-003	SEC	DOC	AUTH	Admin Party Enabled	admin-party-enabled	\N	2026-02-23 20:18:30.39866	2026-02-23 20:18:30.398661	c003
SEC-DOC-AUTH-004	SEC	DOC	AUTH	Authentication Disabled	authentication-disabled	\N	2026-02-23 20:18:30.398662	2026-02-23 20:18:30.398662	c004
SEC-DOC-AUTH-005	SEC	DOC	AUTH	Failed Authentication Attempts High	failed-authentication-attempts-high	\N	2026-02-23 20:18:30.398663	2026-02-23 20:18:30.398663	c005
SEC-DOC-AUTH-006	SEC	DOC	AUTH	LDAP/AD Integration Broken	ldapad-integration-broken	\N	2026-02-23 20:18:30.398664	2026-02-23 20:18:30.398664	c006
SEC-DOC-AUTH-007	SEC	DOC	AUTH	Certificate Authentication Issues	certificate-authentication-issues	\N	2026-02-23 20:18:30.398665	2026-02-23 20:18:30.398666	c007
SEC-DOC-AUTH-008	SEC	DOC	AUTH	OIDC Authentication Vulnerability	oidc-authentication-vulnerability	\N	2026-02-23 20:18:30.398666	2026-02-23 20:18:30.398667	c008
SEC-DOC-AUTH-009	SEC	DOC	AUTH	Account Lockout Not Configured	account-lockout-not-configured	\N	2026-02-23 20:18:30.398667	2026-02-23 20:18:30.398668	c009
SEC-DOC-AUTH-010	SEC	DOC	AUTH	Session Timeout Too Long	session-timeout-too-long	\N	2026-02-23 20:18:30.398669	2026-02-23 20:18:30.398669	c010
SEC-DOC-AUTHZ-001	SEC	DOC	AUTHZ	Excessive Privileges Granted	excessive-privileges-granted	\N	2026-02-23 20:18:30.39867	2026-02-23 20:18:30.39867	c001
SEC-DOC-AUTHZ-002	SEC	DOC	AUTHZ	Missing Role-Based Access Control	missing-role-based-access-control	\N	2026-02-23 20:18:30.398671	2026-02-23 20:18:30.398671	c002
SEC-DOC-AUTHZ-003	SEC	DOC	AUTHZ	Database-Level vs Collection-Level Permissions	database-level-vs-collection-level-permissions	\N	2026-02-23 20:18:30.398672	2026-02-23 20:18:30.398672	c003
SEC-DOC-AUTHZ-004	SEC	DOC	AUTHZ	Unauthorized Data Access	unauthorized-data-access	\N	2026-02-23 20:18:30.398673	2026-02-23 20:18:30.398674	c004
SEC-DOC-AUTHZ-005	SEC	DOC	AUTHZ	Application Using Root/Admin Credentials	application-using-rootadmin-credentials	\N	2026-02-23 20:18:30.398674	2026-02-23 20:18:30.398675	c005
SEC-DOC-AUTHZ-006	SEC	DOC	AUTHZ	No Audit of Permission Changes	no-audit-of-permission-changes	\N	2026-02-23 20:18:30.398675	2026-02-23 20:18:30.398676	c006
SEC-DOC-ENC-001	SEC	DOC	ENC	TLS/SSL Not Enabled	tlsssl-not-enabled	\N	2026-02-23 20:18:30.398677	2026-02-23 20:18:30.398677	c001
SEC-DOC-ENC-002	SEC	DOC	ENC	Weak TLS Version/Cipher	weak-tls-versioncipher	\N	2026-02-23 20:18:30.398678	2026-02-23 20:18:30.398678	c002
SEC-DOC-ENC-003	SEC	DOC	ENC	Encryption at Rest Disabled	encryption-at-rest-disabled	\N	2026-02-23 20:18:30.398679	2026-02-23 20:18:30.398679	c003
SEC-DOC-ENC-004	SEC	DOC	ENC	Field-Level Encryption Missing	field-level-encryption-missing	\N	2026-02-23 20:18:30.39868	2026-02-23 20:18:30.39868	c004
SEC-DOC-ENC-005	SEC	DOC	ENC	Certificate Expired	certificate-expired	\N	2026-02-23 20:18:30.398681	2026-02-23 20:18:30.398682	c005
SEC-DOC-ENC-006	SEC	DOC	ENC	Self-Signed Certificates in Production	self-signed-certificates-in-production	\N	2026-02-23 20:18:30.398682	2026-02-23 20:18:30.398683	c006
SEC-DOC-ENC-007	SEC	DOC	ENC	Key Management Issues	key-management-issues	\N	2026-02-23 20:18:30.398683	2026-02-23 20:18:30.398684	c007
SEC-DOC-ENC-008	SEC	DOC	ENC	Certificate Validation Bypass	certificate-validation-bypass	\N	2026-02-23 20:18:30.398685	2026-02-23 20:18:30.398685	c008
SEC-DOC-AUD-001	SEC	DOC	AUD	Audit Logging Disabled	audit-logging-disabled	\N	2026-02-23 20:18:30.398686	2026-02-23 20:18:30.398686	c001
SEC-DOC-AUD-002	SEC	DOC	AUD	Insufficient Audit Coverage	insufficient-audit-coverage	\N	2026-02-23 20:18:30.398687	2026-02-23 20:18:30.398687	c002
SEC-DOC-AUD-003	SEC	DOC	AUD	Audit Log Retention Too Short	audit-log-retention-too-short	\N	2026-02-23 20:18:30.398688	2026-02-23 20:18:30.398688	c003
SEC-DOC-AUD-004	SEC	DOC	AUD	Audit Logs Not Protected	audit-logs-not-protected	\N	2026-02-23 20:18:30.398689	2026-02-23 20:18:30.39869	c004
SEC-DOC-AUD-005	SEC	DOC	AUD	CloudWatch Export Not Configured	cloudwatch-export-not-configured	\N	2026-02-23 20:18:30.39869	2026-02-23 20:18:30.398691	c005
SEC-DOC-AUD-006	SEC	DOC	AUD	Compliance Audit Gaps	compliance-audit-gaps	\N	2026-02-23 20:18:30.398691	2026-02-23 20:18:30.398692	c006
SEC-DOC-NET-001	SEC	DOC	NET	Database rootcausely Exposed	database-rootcausely-exposed	\N	2026-02-23 20:18:30.398693	2026-02-23 20:18:30.398693	c001
SEC-DOC-NET-002	SEC	DOC	NET	Bind IP Misconfigured	bind-ip-misconfigured	\N	2026-02-23 20:18:30.398694	2026-02-23 20:18:30.398694	c002
SEC-DOC-NET-003	SEC	DOC	NET	Firewall Rules Too Permissive	firewall-rules-too-permissive	\N	2026-02-23 20:18:30.398695	2026-02-23 20:18:30.398695	c003
SEC-DOC-NET-004	SEC	DOC	NET	VPC/VNet Not Used	vpcvnet-not-used	\N	2026-02-23 20:18:30.398696	2026-02-23 20:18:30.398696	c004
SEC-DOC-NET-005	SEC	DOC	NET	Private Endpoint Not Configured	private-endpoint-not-configured	\N	2026-02-23 20:18:30.398697	2026-02-23 20:18:30.398698	c005
SEC-DOC-NET-006	SEC	DOC	NET	Network Segmentation Missing	network-segmentation-missing	\N	2026-02-23 20:18:30.398698	2026-02-23 20:18:30.398699	c006
SEC-DOC-INJ-001	SEC	DOC	INJ	NoSQL Injection Vulnerability	nosql-injection-vulnerability	\N	2026-02-23 20:18:30.398699	2026-02-23 20:18:30.3987	c001
SEC-DOC-INJ-002	SEC	DOC	INJ	Query Operator Injection	query-operator-injection	\N	2026-02-23 20:18:30.3987	2026-02-23 20:18:30.398701	c002
SEC-DOC-INJ-003	SEC	DOC	INJ	JavaScript Injection via \\$where	javascript-injection-via-where	\N	2026-02-23 20:18:30.398702	2026-02-23 20:18:30.398702	c003
SEC-DOC-INJ-004	SEC	DOC	INJ	Authentication Bypass via Injection	authentication-bypass-via-injection	\N	2026-02-23 20:18:30.398703	2026-02-23 20:18:30.398703	c004
SEC-DOC-INJ-005	SEC	DOC	INJ	Regex DoS (ReDoS)	regex-dos-redos	\N	2026-02-23 20:18:30.398704	2026-02-23 20:18:30.398704	c005
SEC-DOC-DAT-001	SEC	DOC	DAT	PII Stored Unencrypted	pii-stored-unencrypted	\N	2026-02-23 20:18:30.398705	2026-02-23 20:18:30.398706	c001
SEC-DOC-DAT-002	SEC	DOC	DAT	Data Masking Not Implemented	data-masking-not-implemented	\N	2026-02-23 20:18:30.398706	2026-02-23 20:18:30.398707	c002
SEC-DOC-DAT-003	SEC	DOC	DAT	Backup Encryption Disabled	backup-encryption-disabled	\N	2026-02-23 20:18:30.398708	2026-02-23 20:18:30.398708	c003
SEC-DOC-DAT-004	SEC	DOC	DAT	Data Retention Policy Violation	data-retention-policy-violation	\N	2026-02-23 20:18:30.398709	2026-02-23 20:18:30.398709	c004
SEC-DOC-DAT-005	SEC	DOC	DAT	Cross-Region Replication Security	cross-region-replication-security	\N	2026-02-23 20:18:30.39871	2026-02-23 20:18:30.39871	c005
PERF-KV-KEY-001	PERF	KV	KEY	Hot Key Concentration	hot-key-concentration	\N	2026-02-23 20:18:30.398711	2026-02-23 20:18:30.398712	c001
PERF-KV-KEY-002	PERF	KV	KEY	Large Key Size	large-key-size	\N	2026-02-23 20:18:30.398712	2026-02-23 20:18:30.398713	c002
PERF-KV-KEY-003	PERF	KV	KEY	Poor Key Distribution	poor-key-distribution	\N	2026-02-23 20:18:30.398713	2026-02-23 20:18:30.398714	c003
PERF-KV-KEY-004	PERF	KV	KEY	Cross-Slot Multi-Key Operations	cross-slot-multi-key-operations	\N	2026-02-23 20:18:30.398714	2026-02-23 20:18:30.398715	c004
PERF-KV-KEY-005	PERF	KV	KEY	Key Naming Pattern Overhead	key-naming-pattern-overhead	\N	2026-02-23 20:18:30.398716	2026-02-23 20:18:30.398716	c005
PERF-KV-MEM-001	PERF	KV	MEM	Memory Fragmentation	memory-fragmentation	\N	2026-02-23 20:18:30.398717	2026-02-23 20:18:30.398717	c001
PERF-KV-MEM-002	PERF	KV	MEM	Memory Overhead	memory-overhead	\N	2026-02-23 20:18:30.398718	2026-02-23 20:18:30.398718	c002
PERF-KV-MEM-003	PERF	KV	MEM	Eviction Thrashing	eviction-thrashing	\N	2026-02-23 20:18:30.398719	2026-02-23 20:18:30.398719	c003
PERF-KV-MEM-004	PERF	KV	MEM	Swap Usage	swap-usage	\N	2026-02-23 20:18:30.39872	2026-02-23 20:18:30.398721	c004
PERF-KV-MEM-005	PERF	KV	MEM	OOM Conditions	oom-conditions	\N	2026-02-23 20:18:30.398721	2026-02-23 20:18:30.398722	c005
PERF-KV-MEM-006	PERF	KV	MEM	Slab Allocation Imbalance	slab-allocation-imbalance	\N	2026-02-23 20:18:30.398722	2026-02-23 20:18:30.398723	c006
PERF-KV-MEM-007	PERF	KV	MEM	Internal Fragmentation	internal-fragmentation	\N	2026-02-23 20:18:30.398723	2026-02-23 20:18:30.398724	c007
PERF-KV-EVICT-001	PERF	KV	EVICT	Inappropriate Eviction Policy	inappropriate-eviction-policy	\N	2026-02-23 20:18:30.398725	2026-02-23 20:18:30.398725	c001
PERF-KV-EVICT-002	PERF	KV	EVICT	Premature Eviction	premature-eviction	\N	2026-02-23 20:18:30.398726	2026-02-23 20:18:30.398726	c002
PERF-KV-EVICT-003	PERF	KV	EVICT	Cache Miss Storm	cache-miss-storm	\N	2026-02-23 20:18:30.398727	2026-02-23 20:18:30.398727	c003
PERF-KV-EVICT-004	PERF	KV	EVICT	Eviction Policy Mismatch	eviction-policy-mismatch	\N	2026-02-23 20:18:30.398728	2026-02-23 20:18:30.398729	c004
PERF-KV-THRU-001	PERF	KV	THRU	Request Rate Throttling	request-rate-throttling	\N	2026-02-23 20:18:30.398729	2026-02-23 20:18:30.39873	c001
PERF-KV-THRU-002	PERF	KV	THRU	Partition-Level Throttling	partition-level-throttling	\N	2026-02-23 20:18:30.39873	2026-02-23 20:18:30.398731	c002
PERF-KV-THRU-003	PERF	KV	THRU	GSI Write Throttling	gsi-write-throttling	\N	2026-02-23 20:18:30.398732	2026-02-23 20:18:30.398732	c003
PERF-KV-THRU-004	PERF	KV	THRU	Bandwidth Saturation	bandwidth-saturation	\N	2026-02-23 20:18:30.398733	2026-02-23 20:18:30.398733	c004
PERF-KV-THRU-005	PERF	KV	THRU	Operations per Second Limit	operations-per-second-limit	\N	2026-02-23 20:18:30.398734	2026-02-23 20:18:30.398734	c005
PERF-KV-LAT-001	PERF	KV	LAT	Blocking Commands	blocking-commands	\N	2026-02-23 20:18:30.398735	2026-02-23 20:18:30.398736	c001
PERF-KV-LAT-002	PERF	KV	LAT	Large Value Operations	large-value-operations	\N	2026-02-23 20:18:30.398736	2026-02-23 20:18:30.398737	c002
PERF-KV-LAT-003	PERF	KV	LAT	Network Round-Trip Latency	network-round-trip-latency	\N	2026-02-23 20:18:30.398737	2026-02-23 20:18:30.398738	c003
PERF-KV-LAT-004	PERF	KV	LAT	Disk I/O Latency	disk-io-latency	\N	2026-02-23 20:18:30.398738	2026-02-23 20:18:30.398739	c004
PERF-KV-LAT-005	PERF	KV	LAT	Slow Complex Commands	slow-complex-commands	\N	2026-02-23 20:18:30.39874	2026-02-23 20:18:30.39874	c005
PERF-KV-LAT-006	PERF	KV	LAT	AOF Fsync Blocking	aof-fsync-blocking	\N	2026-02-23 20:18:30.398741	2026-02-23 20:18:30.398741	c006
PERF-KV-CONN-001	PERF	KV	CONN	Connection Pool Exhaustion	connection-pool-exhaustion	\N	2026-02-23 20:18:30.398742	2026-02-23 20:18:30.398742	c001
PERF-KV-CONN-002	PERF	KV	CONN	Connection Overhead	connection-overhead	\N	2026-02-23 20:18:30.398743	2026-02-23 20:18:30.398744	c002
PERF-KV-CONN-003	PERF	KV	CONN	Connection Limit Reached	connection-limit-reached	\N	2026-02-23 20:18:30.398744	2026-02-23 20:18:30.398745	c003
PERF-KV-CONN-004	PERF	KV	CONN	Pipelining Underutilization	pipelining-underutilization	\N	2026-02-23 20:18:30.398745	2026-02-23 20:18:30.398746	c004
PERF-KV-DATA-001	PERF	KV	DATA	Inefficient Data Structure Selection	inefficient-data-structure-selection	\N	2026-02-23 20:18:30.398746	2026-02-23 20:18:30.398747	c001
PERF-KV-DATA-002	PERF	KV	DATA	Large Set/List Operations	large-setlist-operations	\N	2026-02-23 20:18:30.398748	2026-02-23 20:18:30.398748	c002
PERF-KV-DATA-003	PERF	KV	DATA	Big Key Problem	big-key-problem	\N	2026-02-23 20:18:30.398749	2026-02-23 20:18:30.398749	c003
PERF-KV-CLUST-001	PERF	KV	CLUST	Cross-Slot Query Limitations	cross-slot-query-limitations	\N	2026-02-23 20:18:30.39875	2026-02-23 20:18:30.39875	c001
PERF-KV-CLUST-002	PERF	KV	CLUST	Resharding Performance Impact	resharding-performance-impact	\N	2026-02-23 20:18:30.398751	2026-02-23 20:18:30.398751	c002
PERF-KV-CLUST-003	PERF	KV	CLUST	Node Imbalance	node-imbalance	\N	2026-02-23 20:18:30.398752	2026-02-23 20:18:30.398753	c003
PERF-KV-CLUST-004	PERF	KV	CLUST	Slot Migration Delays	slot-migration-delays	\N	2026-02-23 20:18:30.398753	2026-02-23 20:18:30.398754	c004
PERF-KV-PUBSUB-001	PERF	KV	PUBSUB	Subscriber Backlog	subscriber-backlog	\N	2026-02-23 20:18:30.398754	2026-02-23 20:18:30.398755	c001
PERF-KV-PUBSUB-002	PERF	KV	PUBSUB	Channel Overhead	channel-overhead	\N	2026-02-23 20:18:30.398755	2026-02-23 20:18:30.398756	c002
PERF-KV-PUBSUB-003	PERF	KV	PUBSUB	Message Loss	message-loss	\N	2026-02-23 20:18:30.398757	2026-02-23 20:18:30.398757	c003
PERF-KV-TTL-001	PERF	KV	TTL	Excessive Key Expiration Load	excessive-key-expiration-load	\N	2026-02-23 20:18:30.398758	2026-02-23 20:18:30.398758	c001
PERF-KV-TTL-002	PERF	KV	TTL	Expiration Backlog	expiration-backlog	\N	2026-02-23 20:18:30.398759	2026-02-23 20:18:30.398759	c002
HLTH-KV-PERS-001	HLTH	KV	PERS	RDB Snapshot Failures	rdb-snapshot-failures	\N	2026-02-23 20:18:30.39876	2026-02-23 20:18:30.398761	c001
HLTH-KV-PERS-002	HLTH	KV	PERS	AOF Corruption	aof-corruption	\N	2026-02-23 20:18:30.398761	2026-02-23 20:18:30.398762	c002
HLTH-KV-PERS-003	HLTH	KV	PERS	AOF Rewrite Failures	aof-rewrite-failures	\N	2026-02-23 20:18:30.398762	2026-02-23 20:18:30.398763	c003
HLTH-KV-PERS-004	HLTH	KV	PERS	Fork Overhead	fork-overhead	\N	2026-02-23 20:18:30.398764	2026-02-23 20:18:30.398764	c004
HLTH-KV-PERS-005	HLTH	KV	PERS	Persistence Disk Space Exhaustion	persistence-disk-space-exhaustion	\N	2026-02-23 20:18:30.398765	2026-02-23 20:18:30.398765	c005
HLTH-KV-PERS-006	HLTH	KV	PERS	Snapshot Performance Degradation	snapshot-performance-degradation	\N	2026-02-23 20:18:30.398766	2026-02-23 20:18:30.398766	c006
HLTH-KV-REP-001	HLTH	KV	REP	Replica Lag	replica-lag	\N	2026-02-23 20:18:30.398767	2026-02-23 20:18:30.398767	c001
HLTH-KV-REP-002	HLTH	KV	REP	Replication Sync Failures	replication-sync-failures	\N	2026-02-23 20:18:30.398768	2026-02-23 20:18:30.398769	c002
HLTH-KV-REP-003	HLTH	KV	REP	Partial Resync Failures	partial-resync-failures	\N	2026-02-23 20:18:30.398769	2026-02-23 20:18:30.39877	c003
HLTH-KV-REP-004	HLTH	KV	REP	Full Resync Impact	full-resync-impact	\N	2026-02-23 20:18:30.39877	2026-02-23 20:18:30.398771	c004
HLTH-KV-REP-005	HLTH	KV	REP	Replica Promotion Delays	replica-promotion-delays	\N	2026-02-23 20:18:30.398771	2026-02-23 20:18:30.398772	c005
HLTH-KV-REP-006	HLTH	KV	REP	Replication Timeout	replication-timeout	\N	2026-02-23 20:18:30.398773	2026-02-23 20:18:30.398773	c006
HLTH-KV-TOPO-001	HLTH	KV	TOPO	Quorum Loss	quorum-loss	\N	2026-02-23 20:18:30.398774	2026-02-23 20:18:30.398774	c001
HLTH-KV-TOPO-002	HLTH	KV	TOPO	Split-Brain Scenario	split-brain-scenario	\N	2026-02-23 20:18:30.398775	2026-02-23 20:18:30.398775	c002
HLTH-KV-TOPO-003	HLTH	KV	TOPO	Slot Coverage Incomplete	slot-coverage-incomplete	\N	2026-02-23 20:18:30.398776	2026-02-23 20:18:30.398777	c003
HLTH-KV-TOPO-004	HLTH	KV	TOPO	Node Failure Detection Delays	node-failure-detection-delays	\N	2026-02-23 20:18:30.398777	2026-02-23 20:18:30.398778	c004
HLTH-KV-TOPO-005	HLTH	KV	TOPO	Membership Change Failures	membership-change-failures	\N	2026-02-23 20:18:30.398778	2026-02-23 20:18:30.398779	c005
HLTH-KV-MEM-001	HLTH	KV	MEM	Maxmemory Limit Reached	maxmemory-limit-reached	\N	2026-02-23 20:18:30.398779	2026-02-23 20:18:30.39878	c001
HLTH-KV-MEM-002	HLTH	KV	MEM	Memory Limit Enforcement Failures	memory-limit-enforcement-failures	\N	2026-02-23 20:18:30.398781	2026-02-23 20:18:30.398781	c002
HLTH-KV-STOR-001	HLTH	KV	STOR	Disk Space for Persistence	disk-space-for-persistence	\N	2026-02-23 20:18:30.398782	2026-02-23 20:18:30.398782	c001
HLTH-KV-STOR-004	HLTH	KV	STOR	Defragmentation Issues	defragmentation-issues	\N	2026-02-23 20:18:30.398785	2026-02-23 20:18:30.398786	c004
HLTH-KV-STOR-005	HLTH	KV	STOR	Storage Engine Misconfiguration	storage-engine-misconfiguration	\N	2026-02-23 20:18:30.398786	2026-02-23 20:18:30.398787	c005
HLTH-KV-BACKUP-001	HLTH	KV	BACKUP	Backup Failures	backup-failures	\N	2026-02-23 20:18:30.398787	2026-02-23 20:18:30.398788	c001
HLTH-KV-BACKUP-002	HLTH	KV	BACKUP	Restore Time Excessive	restore-time-excessive	\N	2026-02-23 20:18:30.398789	2026-02-23 20:18:30.398789	c002
HLTH-KV-BACKUP-003	HLTH	KV	BACKUP	Point-in-Time Recovery Limitations	point-in-time-recovery-limitations	\N	2026-02-23 20:18:30.39879	2026-02-23 20:18:30.39879	c003
HLTH-KV-BACKUP-004	HLTH	KV	BACKUP	Backup Storage Exhaustion	backup-storage-exhaustion	\N	2026-02-23 20:18:30.398791	2026-02-23 20:18:30.398791	c004
HLTH-KV-BACKUP-005	HLTH	KV	BACKUP	Snapshot Integrity Issues	snapshot-integrity-issues	\N	2026-02-23 20:18:30.398792	2026-02-23 20:18:30.398793	c005
HLTH-KV-BACKUP-006	HLTH	KV	BACKUP	Cross-Region Backup Failures	cross-region-backup-failures	\N	2026-02-23 20:18:30.398793	2026-02-23 20:18:30.398794	c006
HLTH-KV-HA-001	HLTH	KV	HA	Failover Detection Delays	failover-detection-delays	\N	2026-02-23 20:18:30.398794	2026-02-23 20:18:30.398795	c001
HLTH-KV-HA-002	HLTH	KV	HA	Automatic Failover Failures	automatic-failover-failures	\N	2026-02-23 20:18:30.398796	2026-02-23 20:18:30.398796	c002
HLTH-KV-HA-003	HLTH	KV	HA	Sentinel Configuration Issues	sentinel-configuration-issues	\N	2026-02-23 20:18:30.398797	2026-02-23 20:18:30.398797	c003
HLTH-KV-MAINT-001	HLTH	KV	MAINT	Background Task Interference	background-task-interference	\N	2026-02-23 20:18:30.398798	2026-02-23 20:18:30.398798	c001
HLTH-KV-MAINT-002	HLTH	KV	MAINT	Defragmentation CPU Impact	defragmentation-cpu-impact	\N	2026-02-23 20:18:30.398799	2026-02-23 20:18:30.398799	c002
HLTH-KV-MAINT-003	HLTH	KV	MAINT	Key Expiration Backlog	key-expiration-backlog	\N	2026-02-23 20:18:30.3988	2026-02-23 20:18:30.398801	c003
HLTH-KV-UPGR-001	HLTH	KV	UPGR	Version Compatibility Issues	version-compatibility-issues	\N	2026-02-23 20:18:30.398801	2026-02-23 20:18:30.398802	c001
HLTH-KV-UPGR-002	HLTH	KV	UPGR	Rolling Upgrade Failures	rolling-upgrade-failures	\N	2026-02-23 20:18:30.398802	2026-02-23 20:18:30.398803	c002
HLTH-KV-UPGR-003	HLTH	KV	UPGR	Extended Support Costs	extended-support-costs	\N	2026-02-23 20:18:30.398803	2026-02-23 20:18:30.398804	c003
HLTH-KV-UPGR-004	HLTH	KV	UPGR	Protocol Changes	protocol-changes	\N	2026-02-23 20:18:30.398805	2026-02-23 20:18:30.398805	c004
SEC-KV-AUTH-001	SEC	KV	AUTH	No Authentication Configured	no-authentication-configured	\N	2026-02-23 20:18:30.398806	2026-02-23 20:18:30.398806	c001
SEC-KV-AUTH-002	SEC	KV	AUTH	Weak Password Configuration	weak-password-configuration	\N	2026-02-23 20:18:30.398807	2026-02-23 20:18:30.398807	c002
SEC-KV-AUTH-003	SEC	KV	AUTH	Default Credentials Exposed	default-credentials-exposed	\N	2026-02-23 20:18:30.398808	2026-02-23 20:18:30.398809	c003
SEC-KV-AUTH-004	SEC	KV	AUTH	Authentication Bypass	authentication-bypass	\N	2026-02-23 20:18:30.398809	2026-02-23 20:18:30.39881	c004
SEC-KV-AUTHZ-001	SEC	KV	AUTHZ	No ACL Configuration	no-acl-configuration	\N	2026-02-23 20:18:30.39881	2026-02-23 20:18:30.398811	c001
SEC-KV-AUTHZ-002	SEC	KV	AUTHZ	Overly Permissive ACLs	overly-permissive-acls	\N	2026-02-23 20:18:30.398811	2026-02-23 20:18:30.398812	c002
SEC-KV-AUTHZ-003	SEC	KV	AUTHZ	Missing Command Restrictions	missing-command-restrictions	\N	2026-02-23 20:18:30.398813	2026-02-23 20:18:30.398813	c003
SEC-KV-AUTHZ-004	SEC	KV	AUTHZ	Key Pattern Permission Issues	key-pattern-permission-issues	\N	2026-02-23 20:18:30.398814	2026-02-23 20:18:30.398814	c004
SEC-KV-AUTHZ-005	SEC	KV	AUTHZ	IAM Policy Misconfigurations	iam-policy-misconfigurations	\N	2026-02-23 20:18:30.398815	2026-02-23 20:18:30.398815	c005
SEC-KV-NET-001	SEC	KV	NET	rootcausely Accessible Instance	rootcausely-accessible-instance	\N	2026-02-23 20:18:30.398816	2026-02-23 20:18:30.398816	c001
SEC-KV-NET-002	SEC	KV	NET	Unprotected Ports	unprotected-ports	\N	2026-02-23 20:18:30.398817	2026-02-23 20:18:30.398818	c002
SEC-KV-NET-003	SEC	KV	NET	Bind to 0.0.0.0	bind-to-0000	\N	2026-02-23 20:18:30.398818	2026-02-23 20:18:30.398819	c003
SEC-KV-NET-004	SEC	KV	NET	Protected Mode Disabled	protected-mode-disabled	\N	2026-02-23 20:18:30.398819	2026-02-23 20:18:30.39882	c004
SEC-KV-NET-005	SEC	KV	NET	Missing Network Segmentation	missing-network-segmentation	\N	2026-02-23 20:18:30.39882	2026-02-23 20:18:30.398821	c005
SEC-KV-ENC-001	SEC	KV	ENC	No TLS/SSL Configured	no-tlsssl-configured	\N	2026-02-23 20:18:30.398822	2026-02-23 20:18:30.398822	c001
SEC-KV-ENC-002	SEC	KV	ENC	Weak TLS Configuration	weak-tls-configuration	\N	2026-02-23 20:18:30.398823	2026-02-23 20:18:30.398823	c002
SEC-KV-ENC-003	SEC	KV	ENC	No Encryption at Rest	no-encryption-at-rest	\N	2026-02-23 20:18:30.398824	2026-02-23 20:18:30.398824	c003
SEC-KV-ENC-004	SEC	KV	ENC	Unencrypted Data in Transit	unencrypted-data-in-transit	\N	2026-02-23 20:18:30.398825	2026-02-23 20:18:30.398826	c004
SEC-KV-ENC-005	SEC	KV	ENC	Customer-Managed Key Issues	customer-managed-key-issues	\N	2026-02-23 20:18:30.398826	2026-02-23 20:18:30.398827	c005
SEC-KV-CMD-001	SEC	KV	CMD	FLUSHALL Command Enabled	flushall-command-enabled	\N	2026-02-23 20:18:30.398827	2026-02-23 20:18:30.398828	c001
SEC-KV-CMD-002	SEC	KV	CMD	CONFIG Command Accessible	config-command-accessible	\N	2026-02-23 20:18:30.398828	2026-02-23 20:18:30.398829	c002
SEC-KV-CMD-003	SEC	KV	CMD	DEBUG Commands Enabled	debug-commands-enabled	\N	2026-02-23 20:18:30.39883	2026-02-23 20:18:30.39883	c003
SEC-KV-CMD-004	SEC	KV	CMD	KEYS Command in Production	keys-command-in-production	\N	2026-02-23 20:18:30.398831	2026-02-23 20:18:30.398831	c004
SEC-KV-CMD-005	SEC	KV	CMD	Dangerous Lua Commands (EVAL/EVALSHA)	dangerous-lua-commands-evalevalsha	\N	2026-02-23 20:18:30.398832	2026-02-23 20:18:30.398832	c005
SEC-KV-CMD-006	SEC	KV	CMD	Module Loading Enabled	module-loading-enabled	\N	2026-02-23 20:18:30.398833	2026-02-23 20:18:30.398834	c006
SEC-KV-DATA-001	SEC	KV	DATA	Sensitive Data in Keys	sensitive-data-in-keys	\N	2026-02-23 20:18:30.398834	2026-02-23 20:18:30.398835	c001
SEC-KV-DATA-002	SEC	KV	DATA	PII Without Encryption	pii-without-encryption	\N	2026-02-23 20:18:30.398835	2026-02-23 20:18:30.398836	c002
SEC-KV-DATA-003	SEC	KV	DATA	Unmasked Sensitive Values	unmasked-sensitive-values	\N	2026-02-23 20:18:30.398837	2026-02-23 20:18:30.398837	c003
SEC-KV-INJ-001	SEC	KV	INJ	Lua Script Injection	lua-script-injection	\N	2026-02-23 20:18:30.398838	2026-02-23 20:18:30.398838	c001
SEC-KV-INJ-002	SEC	KV	INJ	EVAL Command Exploitation	eval-command-exploitation	\N	2026-02-23 20:18:30.398839	2026-02-23 20:18:30.398839	c002
SEC-KV-INJ-003	SEC	KV	INJ	Sandbox Escape Vulnerabilities	sandbox-escape-vulnerabilities	\N	2026-02-23 20:18:30.39884	2026-02-23 20:18:30.398841	c003
SEC-KV-INJ-004	SEC	KV	INJ	Metatable Manipulation	metatable-manipulation	\N	2026-02-23 20:18:30.398841	2026-02-23 20:18:30.398842	c004
SEC-KV-AUDIT-001	SEC	KV	AUDIT	No Audit Logging	no-audit-logging	\N	2026-02-23 20:18:30.398842	2026-02-23 20:18:30.398843	c001
SEC-KV-AUDIT-002	SEC	KV	AUDIT	Insufficient Command Logging	insufficient-command-logging	\N	2026-02-23 20:18:30.398843	2026-02-23 20:18:30.398844	c002
SEC-KV-AUDIT-003	SEC	KV	AUDIT	No Access Tracking	no-access-tracking	\N	2026-02-23 20:18:30.398845	2026-02-23 20:18:30.398845	c003
SEC-KV-AUDIT-004	SEC	KV	AUDIT	Missing Security Monitoring	missing-security-monitoring	\N	2026-02-23 20:18:30.398846	2026-02-23 20:18:30.398846	c004
PERF-VEC-IDX-001	PERF	VEC	IDX	HNSW Graph Connectivity Low	hnsw-graph-connectivity-low	\N	2026-02-23 20:18:30.398847	2026-02-23 20:18:30.398847	c001
PERF-VEC-IDX-002	PERF	VEC	IDX	IVF Centroid Under-training	ivf-centroid-under-training	\N	2026-02-23 20:18:30.398848	2026-02-23 20:18:30.398848	c002
PERF-VEC-IDX-003	PERF	VEC	IDX	Index Build Memory OOM	index-build-memory-oom	\N	2026-02-23 20:18:30.398849	2026-02-23 20:18:30.39885	c003
PERF-VEC-IDX-004	PERF	VEC	IDX	Stale Index Statistics	stale-index-statistics	\N	2026-02-23 20:18:30.39885	2026-02-23 20:18:30.398851	c004
PERF-VEC-IDX-005	PERF	VEC	IDX	Vector Dimension Mismatch	vector-dimension-mismatch	\N	2026-02-23 20:18:30.398851	2026-02-23 20:18:30.398852	c005
PERF-VEC-QRY-001	PERF	VEC	QRY	Cold Start Latency (Mmap)	cold-start-latency-mmap	\N	2026-02-23 20:18:30.398853	2026-02-23 20:18:30.398853	c001
PERF-VEC-QRY-002	PERF	VEC	QRY	Excessive Filtering (Pre-filter)	excessive-filtering-pre-filter	\N	2026-02-23 20:18:30.398854	2026-02-23 20:18:30.398854	c002
PERF-VEC-QRY-003	PERF	VEC	QRY	IVF Probe Exhaustion	ivf-probe-exhaustion	\N	2026-02-23 20:18:30.398855	2026-02-23 20:18:30.398856	c003
PERF-VEC-QRY-004	PERF	VEC	QRY	Result Set Jitter	result-set-jitter	\N	2026-02-23 20:18:30.398856	2026-02-23 20:18:30.398857	c004
PERF-VEC-QRY-005	PERF	VEC	QRY	Cross-Shard Fanout Lag	cross-shard-fanout-lag	\N	2026-02-23 20:18:30.398857	2026-02-23 20:18:30.398858	c005
PERF-VEC-QRY-006	PERF	VEC	QRY	Embedding Model Bottleneck	embedding-model-bottleneck	\N	2026-02-23 20:18:30.398858	2026-02-23 20:18:30.398859	c006
PERF-VEC-QRY-007	PERF	VEC	QRY	Distance Metric Miscalculation	distance-metric-miscalculation	\N	2026-02-23 20:18:30.39886	2026-02-23 20:18:30.39886	c007
PERF-VEC-ING-001	PERF	VEC	ING	Small Batch Insert Overhead	small-batch-insert-overhead	\N	2026-02-23 20:18:30.398861	2026-02-23 20:18:30.398861	c001
PERF-VEC-ING-002	PERF	VEC	ING	Write-Heavy Locking	write-heavy-locking	\N	2026-02-23 20:18:30.398862	2026-02-23 20:18:30.398863	c002
PERF-VEC-ING-003	PERF	VEC	ING	Embedder Pipeline Timeout	embedder-pipeline-timeout	\N	2026-02-23 20:18:30.398863	2026-02-23 20:18:30.398864	c003
PERF-VEC-MEM-001	PERF	VEC	MEM	Index Size vs RAM Mismatch	index-size-vs-ram-mismatch	\N	2026-02-23 20:18:30.398865	2026-02-23 20:18:30.398865	c001
PERF-VEC-MEM-002	PERF	VEC	MEM	Unreleased Memory Bloat	unreleased-memory-bloat	\N	2026-02-23 20:18:30.398866	2026-02-23 20:18:30.398866	c002
PERF-VEC-MEM-003	PERF	VEC	MEM	Metadata High Cardinality	metadata-high-cardinality	\N	2026-02-23 20:18:30.398867	2026-02-23 20:18:30.398867	c003
PERF-VEC-DIM-001	PERF	VEC	DIM	Curse of Dimensionality	curse-of-dimensionality	\N	2026-02-23 20:18:30.398868	2026-02-23 20:18:30.398869	c001
PERF-VEC-OPT-001	PERF	VEC	OPT	Missing SIMD Acceleration	missing-simd-acceleration	\N	2026-02-23 20:18:30.398869	2026-02-23 20:18:30.39887	c001
PERF-VEC-HYB-001	PERF	VEC	HYB	Keyword-Vector Score Skew	keyword-vector-score-skew	\N	2026-02-23 20:18:30.39887	2026-02-23 20:18:30.398871	c001
PERF-VEC-HYB-002	PERF	VEC	HYB	Post-Filter Empty Set	post-filter-empty-set	\N	2026-02-23 20:18:30.398872	2026-02-23 20:18:30.398872	c002
PERF-VEC-SCL-001	PERF	VEC	SCL	Hot Partition/Shard	hot-partitionshard	\N	2026-02-23 20:18:30.398873	2026-02-23 20:18:30.398873	c001
PERF-VEC-SCL-002	PERF	VEC	SCL	Global Limit Throttling	global-limit-throttling	\N	2026-02-23 20:18:30.398874	2026-02-23 20:18:30.398874	c002
HLTH-VEC-IDX-001	HLTH	VEC	IDX	Index Corruption	index-corruption	\N	2026-02-23 20:18:30.398875	2026-02-23 20:18:30.398875	c001
HLTH-VEC-IDX-002	HLTH	VEC	IDX	Stale/Dead Tuples	staledead-tuples	\N	2026-02-23 20:18:30.398876	2026-02-23 20:18:30.398877	c002
HLTH-VEC-IDX-003	HLTH	VEC	IDX	Unmerged Segments	unmerged-segments	\N	2026-02-23 20:18:30.398877	2026-02-23 20:18:30.398878	c003
HLTH-VEC-STG-001	HLTH	VEC	STG	Vector Storage Exhaustion	vector-storage-exhaustion	\N	2026-02-23 20:18:30.398878	2026-02-23 20:18:30.398879	c001
HLTH-VEC-STG-002	HLTH	VEC	STG	WAL/Log Growth	wallog-growth	\N	2026-02-23 20:18:30.398879	2026-02-23 20:18:30.39888	c002
HLTH-VEC-REP-001	HLTH	VEC	REP	Replication Lag	replication-lag	\N	2026-02-23 20:18:30.398881	2026-02-23 20:18:30.398881	c001
HLTH-VEC-REP-002	HLTH	VEC	REP	Split Brain / Quorum Loss	split-brain-quorum-loss	\N	2026-02-23 20:18:30.398882	2026-02-23 20:18:30.398882	c002
HLTH-VEC-REP-003	HLTH	VEC	REP	Ghost Data (Deletes)	ghost-data-deletes	\N	2026-02-23 20:18:30.398883	2026-02-23 20:18:30.398883	c003
HLTH-VEC-BKP-001	HLTH	VEC	BKP	Snapshot Consistency	snapshot-consistency	\N	2026-02-23 20:18:30.398884	2026-02-23 20:18:30.398885	c001
HLTH-VEC-BKP-002	HLTH	VEC	BKP	Index Restore Timeout	index-restore-timeout	\N	2026-02-23 20:18:30.398885	2026-02-23 20:18:30.398886	c002
HLTH-VEC-RES-001	HLTH	VEC	RES	Collection Limit Reached	collection-limit-reached	\N	2026-02-23 20:18:30.398886	2026-02-23 20:18:30.398887	c001
HLTH-VEC-RES-002	HLTH	VEC	RES	Namespace Sprawl	namespace-sprawl	\N	2026-02-23 20:18:30.398887	2026-02-23 20:18:30.398888	c002
HLTH-VEC-MNT-001	HLTH	VEC	MNT	Compaction Stall	compaction-stall	\N	2026-02-23 20:18:30.398889	2026-02-23 20:18:30.398889	c001
HLTH-VEC-MNT-002	HLTH	VEC	MNT	Schema Drift	schema-drift	\N	2026-02-23 20:18:30.39889	2026-02-23 20:18:30.39889	c002
HLTH-VEC-UPG-001	HLTH	VEC	UPG	Embedding Model Drift	embedding-model-drift	\N	2026-02-23 20:18:30.398891	2026-02-23 20:18:30.398891	c001
HLTH-VEC-UPG-002	HLTH	VEC	UPG	Extension/Version Mismatch	extensionversion-mismatch	\N	2026-02-23 20:18:30.398892	2026-02-23 20:18:30.398893	c002
HLTH-VEC-INT-001	HLTH	VEC	INT	API Rate Limiting	api-rate-limiting	\N	2026-02-23 20:18:30.398893	2026-02-23 20:18:30.398894	c001
HLTH-VEC-INT-002	HLTH	VEC	INT	Orphaned Vectors	orphaned-vectors	\N	2026-02-23 20:18:30.398894	2026-02-23 20:18:30.398895	c002
HLTH-VEC-INT-003	HLTH	VEC	INT	Duplicate Vectors	duplicate-vectors	\N	2026-02-23 20:18:30.398895	2026-02-23 20:18:30.398896	c003
HLTH-VEC-SYS-001	HLTH	VEC	SYS	File Descriptor Exhaustion	file-descriptor-exhaustion	\N	2026-02-23 20:18:30.398897	2026-02-23 20:18:30.398897	c001
SEC-VEC-AUTH-001	SEC	VEC	AUTH	API Key Exposure	api-key-exposure	\N	2026-02-23 20:18:30.398898	2026-02-23 20:18:30.398898	c001
SEC-VEC-AUTH-002	SEC	VEC	AUTH	Default Credentials	default-credentials	\N	2026-02-23 20:18:30.398899	2026-02-23 20:18:30.398899	c002
SEC-VEC-AUTH-003	SEC	VEC	AUTH	Missing TLS/SSL	missing-tlsssl	\N	2026-02-23 20:18:30.3989	2026-02-23 20:18:30.398901	c003
SEC-VEC-ACC-001	SEC	VEC	ACC	Cross-Tenant Leakage	cross-tenant-leakage	\N	2026-02-23 20:18:30.398901	2026-02-23 20:18:30.398902	c001
SEC-VEC-ACC-002	SEC	VEC	ACC	Over-Permissive Scope	over-permissive-scope	\N	2026-02-23 20:18:30.398903	2026-02-23 20:18:30.398903	c002
SEC-VEC-ACC-003	SEC	VEC	ACC	Metadata Injection	metadata-injection	\N	2026-02-23 20:18:30.398904	2026-02-23 20:18:30.398904	c003
SEC-VEC-DAT-001	SEC	VEC	DAT	Embedding Inversion	embedding-inversion	\N	2026-02-23 20:18:30.398905	2026-02-23 20:18:30.398905	c001
SEC-VEC-DAT-002	SEC	VEC	DAT	Unencrypted At-Rest	unencrypted-at-rest	\N	2026-02-23 20:18:30.398906	2026-02-23 20:18:30.398907	c002
SEC-VEC-DAT-003	SEC	VEC	DAT	PII in Metadata	pii-in-metadata	\N	2026-02-23 20:18:30.398907	2026-02-23 20:18:30.398908	c003
SEC-VEC-ATK-001	SEC	VEC	ATK	Prompt Injection (Retrieval)	prompt-injection-retrieval	\N	2026-02-23 20:18:30.398908	2026-02-23 20:18:30.398909	c001
SEC-VEC-ATK-002	SEC	VEC	ATK	Data Poisoning	data-poisoning	\N	2026-02-23 20:18:30.39891	2026-02-23 20:18:30.39891	c002
SEC-VEC-ATK-003	SEC	VEC	ATK	DoS via Dimension	dos-via-dimension	\N	2026-02-23 20:18:30.398911	2026-02-23 20:18:30.398911	c003
SEC-VEC-NET-001	SEC	VEC	NET	rootcause Endpoint Exposure	rootcause-endpoint-exposure	\N	2026-02-23 20:18:30.398912	2026-02-23 20:18:30.398912	c001
SEC-VEC-NET-002	SEC	VEC	NET	Man-in-the-Middle	man-in-the-middle	\N	2026-02-23 20:18:30.398913	2026-02-23 20:18:30.398914	c002
SEC-VEC-LOG-001	SEC	VEC	LOG	Query Logging Missing	query-logging-missing	\N	2026-02-23 20:18:30.398914	2026-02-23 20:18:30.398915	c001
SEC-VEC-LOG-002	SEC	VEC	LOG	Sensitive Query Leak	sensitive-query-leak	\N	2026-02-23 20:18:30.398915	2026-02-23 20:18:30.398916	c002
HLTH-SQL-DM-001	HLTH	SQL	DM	Background Cleanup Not Running	background-cleanup-not-running	\N	2026-02-23 20:18:30.398916	2026-02-23 20:18:30.398917	c001
HLTH-SQL-LM-005	HLTH	SQL	LM	Transaction Log Growth Uncontrolled	transaction-log-growth-uncontrolled	\N	2026-02-23 20:18:30.398918	2026-02-23 20:18:30.398918	c005
HLTH-SQL-RP-004	HLTH	SQL	RP	Change Distribution Stalled	change-distribution-stalled	\N	2026-02-23 20:18:30.398919	2026-02-23 20:18:30.398919	c004
HLTH-SQL-DM-005	HLTH	SQL	DM	Transaction ID Wraparound Risk	transaction-id-wraparound-risk-postgresql	\N	2026-02-23 20:18:30.398435	2026-02-23 20:18:30.398436	c005
HLTH-SQL-LM-002	HLTH	SQL	LM	Log Shipping Delay	log-shipping-delay-sql-server	\N	2026-02-23 20:18:30.39844	2026-02-23 20:18:30.39844	c002
HLTH-SQL-LM-003	HLTH	SQL	LM	Archive Log Gap	archive-log-gap-oracle	\N	2026-02-23 20:18:30.398441	2026-02-23 20:18:30.398441	c003
HLTH-SQL-LM-004	HLTH	SQL	LM	Transaction Log Archiving Failure	wal-archiving-failure-postgresql	\N	2026-02-23 20:18:30.398442	2026-02-23 20:18:30.398443	c004
HLTH-SQL-SM-004	HLTH	SQL	SM	Temporary Tablespace Growth Uncontrolled	tempdb-growth-uncontrolled	\N	2026-02-23 20:18:30.39842	2026-02-23 20:18:30.398421	c004
PERF-SQL-IO-004	PERF	SQL	IO	Temporary Tablespace Contention	tempdb-contention-sql-server-specific	\N	2026-02-23 20:18:30.398378	2026-02-23 20:18:30.398379	c004
PERF-SQL-VS-001	PERF	SQL	VS	Transaction ID Wraparound	transaction-id-wraparound-postgresql	\N	2026-02-23 20:18:30.398399	2026-02-23 20:18:30.398399	c001
PERF-SQL-VS-002	PERF	SQL	VS	Oversized-Attribute Storage Bloat	toast-table-bloat-postgresql	\N	2026-02-23 20:18:30.3984	2026-02-23 20:18:30.3984	c002
SEC-SQL-CFG-001	SEC	SQL	CFG	OS Command Execution Enabled	xp-cmdshell-enabled-sql-server	\N	2026-02-23 20:18:30.398494	2026-02-23 20:18:30.398495	c001
SEC-SQL-CFG-002	SEC	SQL	CFG	Local File Loading Enabled	local-infile-enabled-mysqlmariadb	\N	2026-02-23 20:18:30.398495	2026-02-23 20:18:30.398496	c002
SEC-SQL-CFG-004	SEC	SQL	CFG	In-Database Code Execution Enabled	clrjava-enabled-sql-serveroracle	\N	2026-02-23 20:18:30.398498	2026-02-23 20:18:30.398498	c004
SEC-SQL-VS-001	SEC	SQL	VS	Management UI/Database Privilege Overlap	vertica-uidb-privilege-overlap	\N	2026-02-23 20:18:30.398508	2026-02-23 20:18:30.398508	c001
SEC-SQL-VS-002	SEC	SQL	VS	Insecure Extensions Loaded	postgresql-insecure-extensions	\N	2026-02-23 20:18:30.398509	2026-02-23 20:18:30.398509	c002
SEC-SQL-VS-003	SEC	SQL	VS	Default/Factory Passwords Active	oracle-default-passwords	\N	2026-02-23 20:18:30.39851	2026-02-23 20:18:30.398511	c003
SEC-SQL-ACC-010	SEC	SQL	ACC	Anomalous Transaction Activity	anomalous-transaction-activity	Running transactions show unusual patterns compared to expected baseline - unknown logins, unexpected programs, unusual databases, or suspicious query patterns that may indicate unauthorized access or compromised accounts.	2026-04-03 08:12:12.944489	2026-04-03 08:12:12.944489	c010
SEC-SQL-AUD-006	SEC	SQL	AUD	High Privilege User Suspicious Transactions	high-privilege-user-suspicious-transactions	Suspicious database transactions executed by superusers, DBAs, or administrative roles that may indicate insider threat, credential compromise, or policy violation.	2026-04-17 11:04:21.762974	2026-04-17 11:04:21.762974	\N
SEC-SQL-AUD-007	SEC	SQL	AUD	Unknown Transaction Patterns	unknown-transaction-patterns	Transactions that do not match known application baselines: unrecognized query signatures, unexpected source connections, or off-hours activity suggesting unauthorized access.	2026-04-17 11:04:21.762974	2026-04-17 11:04:21.762974	\N
SEC-SQL-AUD-008	SEC	SQL	AUD	Risky Transaction Execution	risky-transaction-execution	High-impact operations such as bulk data exports, mass deletions, production DDL changes, or access to credential and encryption tables that represent significant data-loss or integrity risk.	2026-04-17 11:04:21.762974	2026-04-17 11:04:21.762974	\N
SEC-SQL-AUD-009	SEC	SQL	AUD	SQL Injection Runtime Indicators	sql-injection-runtime-indicators	Detection of live SQL injection patterns in active sessions: tautologies, stacked queries, UNION probing, time-delay functions, and comment-based obfuscation embedded in query text.	2026-04-17 11:04:30.372803	2026-04-17 11:04:30.372803	\N
SEC-SQL-AUD-010	SEC	SQL	AUD	Database Reconnaissance Activity	database-reconnaissance-activity	Identifies schema enumeration behaviour typical of attackers mapping the database before exfiltration: excessive catalog queries, user/role listing by non-admin accounts, and mass column/permission discovery.	2026-04-17 11:04:30.372803	2026-04-17 11:04:30.372803	\N
SEC-SQL-AUD-011	SEC	SQL	AUD	Audit and Log Tampering	audit-and-log-tampering	Detects attempts to cover tracks by issuing DML against audit tables, disabling audit settings, truncating log tables, modifying triggers, or clearing error buffers during an active session.	2026-04-17 11:04:30.372803	2026-04-17 11:04:30.372803	\N
SEC-SQL-AUD-012	SEC	SQL	AUD	Long-Running Uncommitted Transactions	long-running-uncommitted-transactions	Flags transactions that remain open beyond a defined threshold without commit, idle-in-transaction sessions holding locks, and probe-and-revert rollback patterns consistent with ransomware or intentional lock abuse.	2026-04-17 11:04:30.372803	2026-04-17 11:04:30.372803	\N
SEC-SQL-AUD-013	SEC	SQL	AUD	Security Configuration Change During Active Session	security-configuration-change-active-session	Detects runtime changes to security-relevant server or session parameters: ALTER SYSTEM, sp_configure, trigger disabling, audit parameter changes, and enabling dangerous features such as xp_cmdshell or UTL_FILE.	2026-04-17 11:04:30.372803	2026-04-17 11:04:30.372803	\N
SEC-SQL-AUD-014	SEC	SQL	AUD	User and Role Manipulation During Session	user-and-role-manipulation-during-session	Identifies CREATE USER, role-grant, password-change, and external database-link creation commands issued mid-session, which are typical of privilege persistence, backdoor account creation, or lateral movement setup.	2026-04-17 11:04:30.372803	2026-04-17 11:04:30.372803	\N
SEC-SQL-PRI-003	SEC	SQL	PRI	Database security level not classified	database-security-level-not-classified	Israel PPL Privacy Protection Regulations §2 require databases holding personal data to be classified as Basic, Medium, or High security level based on data sensitivity, number of data subjects, and authorised users. Detect databases lacking documented classification or whose configuration does not match the inferred level.	2026-05-01 10:25:16.76145	2026-05-01 10:39:23.565956	\N
SEC-SQL-PRI-004	SEC	SQL	PRI	Personal data not encrypted at rest	personal-data-not-encrypted-at-rest	PPL Regulations §9 require encryption of personal data at rest in High-level databases (and recommend it for Medium). Detect databases or sensitive columns stored without TDE / column-level encryption / encrypted backups.	2026-05-01 10:25:16.76145	2026-05-01 10:39:23.565956	\N
SEC-SQL-PRI-005	SEC	SQL	PRI	Audit trail missing on personal-data tables	audit-trail-missing-personal-data	PPL Regulations §6 require logging access events to personal data, retained for at least 24 months. Detect databases without audit configured, or sensitive tables not covered by an audit specification.	2026-05-01 10:25:16.76145	2026-05-01 10:39:23.565956	\N
SEC-SQL-PRI-006	SEC	SQL	PRI	Excessive privileges on personal data	excessive-privileges-personal-data	PPL Regulations §4–5 require least-privilege access to personal data. Detect public-role grants on PII tables, sysadmin/db_owner sprawl on application accounts, stale logins still having access, and direct grants bypassing role hierarchy.	2026-05-01 10:25:16.76145	2026-05-01 10:39:23.565956	\N
SEC-SQL-PRI-007	SEC	SQL	PRI	Weak authentication / shared accounts	weak-authentication-shared-accounts	PPL Regulations §6 require identity verification of all users accessing personal data. Detect SQL logins without password policy, shared/generic logins (admin, app, svc), enabled SA login, and concurrent logins from multiple hosts.	2026-05-01 10:25:16.76145	2026-05-01 10:39:23.565956	\N
SEC-SQL-PRI-008	SEC	SQL	PRI	Backup hygiene & encryption	backup-hygiene-encryption	PPL Regulations §15 require regular, encrypted, recoverable backups of personal data. Detect missing recent backups, unencrypted backup files, backups stored on the same volume as live data, and short backup-history retention.	2026-05-01 10:25:16.76145	2026-05-01 10:39:23.565956	\N
SEC-SQL-PRI-009	SEC	SQL	PRI	Personal data retained beyond purpose	personal-data-retained-beyond-purpose	PPL §14 and Regulations §14 limit retention of personal data to the period strictly necessary for the registered purpose. Detect very old records in PII tables, inactive customers with persistent records, soft-deleted rows never purged, and audit logs kept beyond legal minimum + safety margin.	2026-05-01 10:25:16.76145	2026-05-01 10:39:23.565956	\N
SEC-SQL-PRI-010	SEC	SQL	PRI	Security incident detection signals	security-incident-detection-signals	PPL Regulations §11 require detection and notification of security incidents involving personal data. Surface signals that may indicate an incident: failed login spikes, privilege escalation events, unusual data export volume, and after-hours sensitive-data access.	2026-05-01 10:25:16.76145	2026-05-01 10:39:23.565956	\N
SEC-SQL-PRI-011	SEC	SQL	PRI	Israeli-specific sensitive data exposure	israeli-specific-sensitive-data	PPL §7 defines additional sensitive categories specific to Israeli context (Teudat Zehut / national ID, medical, religious, political opinion, sexual orientation, criminal record). Detect columns in these categories stored without encryption or with broad access.	2026-05-01 10:25:16.76145	2026-05-01 10:39:23.565956	\N
SEC-SQL-AUD-015	SEC	SQL	AUD	Schema and DML Activity Tracking	schema-and-dml-activity-tracking	Tracks every CREATE/ALTER/DROP and every INSERT/UPDATE/DELETE/TRUNCATE recorded by the SQL Server Audit subsystem. The detection auto-provisions the server audit and per-database audit specifications when missing so coverage is consistent across all online databases including master.	2026-05-08 12:22:30.4148	2026-05-08 12:22:30.4148	\N
SEC-SQL-QE-001	SEC	SQL	QE	Anomalous Query/Procedure Execution	anomalous-query-procedure-execution	Queries or stored procedures executing abnormally relative to their baseline (e.g. running far longer than their historical average), which may indicate performance regressions or anomalous/abusive activity.	2026-06-10 09:08:07.902339	2026-06-10 09:08:07.902339	c001
SEC-SQL-AUTHZ-001	SEC	SQL	AUTHZ	Database Access & Privilege Inventory	database-access-privilege-inventory	Inventory of database access: server logins, database users, role memberships and explicit permission grants across all user databases, for access review and least-privilege auditing.	2026-06-10 10:41:19.763449	2026-06-10 10:41:19.763449	c001
\.
INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at, category_id)
SELECT issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at, category_id FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM rootcause.issues);
DROP TABLE _stg_load;


DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'rootcause' AND c.relname = 'issues'
          AND con.conname = 'issues_pkey') THEN
        ALTER TABLE ONLY rootcause.issues
    ADD CONSTRAINT issues_pkey PRIMARY KEY (issue_id);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'rootcause' AND c.relname = 'issues'
          AND con.conname = 'uq_issue_dbtype_slug') THEN
        ALTER TABLE ONLY rootcause.issues
    ADD CONSTRAINT uq_issue_dbtype_slug UNIQUE (database_type_code, slug);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS ix_issues_database_type_code ON rootcause.issues USING btree (database_type_code);
CREATE INDEX IF NOT EXISTS ix_issues_domain_code ON rootcause.issues USING btree (domain_code);
CREATE INDEX IF NOT EXISTS ix_issues_slug ON rootcause.issues USING btree (slug);
