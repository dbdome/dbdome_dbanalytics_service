-- Idempotent install for public.issues
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS public;

CREATE SEQUENCE IF NOT EXISTS public.issues_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS public.issues (
    id integer NOT NULL,
    issue_id character varying(30) NOT NULL,
    domain_id smallint NOT NULL,
    database_type_id smallint NOT NULL,
    area_id smallint,
    issue_number smallint NOT NULL,
    name character varying(200) NOT NULL
);

ALTER TABLE public.issues ALTER COLUMN id SET DEFAULT nextval('public.issues_id_seq'::regclass);
ALTER SEQUENCE public.issues_id_seq OWNED BY public.issues.id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE public.issues);
COPY _stg_load (id, issue_id, domain_id, database_type_id, area_id, issue_number, name) FROM stdin;
1	PERF-SQL-QE-001	1	1	1	1	Slow Query Execution
2	PERF-SQL-QE-002	1	1	1	2	Full Table Scan
3	PERF-SQL-QE-003	1	1	1	3	Suboptimal Execution Plan
4	PERF-SQL-QE-004	1	1	1	4	Parameter Sniffing
5	PERF-SQL-QE-005	1	1	1	5	Implicit Data Type Conversion
6	PERF-SQL-QE-006	1	1	1	6	Correlated Subquery
7	PERF-SQL-QE-007	1	1	1	7	Inefficient JOIN
8	PERF-SQL-QE-008	1	1	1	8	Sort/Hash Spill to Disk
9	PERF-SQL-IX-001	1	1	2	1	Missing Index
10	PERF-SQL-IX-002	1	1	2	2	Unused Index
11	PERF-SQL-IX-003	1	1	2	3	Index Fragmentation
12	PERF-SQL-IX-004	1	1	2	4	Redundant/Duplicate Index
13	PERF-SQL-IX-005	1	1	2	5	Non-Selective Index
14	PERF-SQL-IX-006	1	1	2	6	Over-Indexing
15	PERF-SQL-IX-007	1	1	2	7	Index Key Too Wide
16	PERF-SQL-LC-001	1	1	3	1	Deadlock
17	PERF-SQL-LC-002	1	1	3	2	Lock Wait Timeout
18	PERF-SQL-LC-003	1	1	3	3	Blocking Query
19	PERF-SQL-LC-004	1	1	3	4	Latch Contention
20	PERF-SQL-LC-005	1	1	3	5	Long-Running Transaction
21	PERF-SQL-CPU-001	1	1	4	1	High CPU Utilization
22	PERF-SQL-CPU-002	1	1	4	2	Excessive Compilation/Recompilation
23	PERF-SQL-CPU-003	1	1	4	3	Inefficient Parallelism
24	PERF-SQL-CPU-004	1	1	4	4	Outdated Statistics
25	PERF-SQL-MEM-001	1	1	5	1	Memory Pressure
26	PERF-SQL-MEM-002	1	1	5	2	Sort/Hash Spill to Disk
27	PERF-SQL-MEM-003	1	1	5	3	Low Buffer Cache Hit Ratio
28	PERF-SQL-MEM-004	1	1	5	4	Memory Grant Overestimation
29	PERF-SQL-IO-001	1	1	6	1	High Disk Latency
30	PERF-SQL-IO-002	1	1	6	2	Transaction Log Contention
31	PERF-SQL-IO-003	1	1	6	3	Checkpoint I/O Spikes
32	PERF-SQL-IO-004	1	1	6	4	TempDB Contention (SQL Server Specific)
33	PERF-SQL-CN-001	1	1	7	1	Connection Pool Exhaustion
34	PERF-SQL-CN-002	1	1	7	2	Connection Leak
35	PERF-SQL-CN-003	1	1	7	3	Excessive Connection Churn
36	PERF-SQL-CN-004	1	1	7	4	Max Connections Reached
37	PERF-SQL-CE-001	1	1	8	1	Buffer Pool Pressure
38	PERF-SQL-CE-002	1	1	8	2	Plan Cache Bloat
39	PERF-SQL-CE-003	1	1	8	3	Table Bloat
40	PERF-SQL-CE-004	1	1	8	4	Query Cache Inefficiency
41	PERF-SQL-CE-005	1	1	8	5	Page Splits
42	PERF-SQL-PL-001	1	1	9	1	Excessive Parallelism
43	PERF-SQL-PL-002	1	1	9	2	Parallel Thread Imbalance
44	PERF-SQL-PL-003	1	1	9	3	Worker Thread Starvation
45	PERF-SQL-PL-004	1	1	9	4	Parallel Exchange Spills
46	PERF-SQL-TX-001	1	1	10	1	Long-Running Transaction
47	PERF-SQL-TX-002	1	1	10	2	Transaction Log Growth
48	PERF-SQL-TX-003	1	1	10	3	Orphaned Transaction
49	PERF-SQL-TX-004	1	1	10	4	Excessive Rollbacks
50	PERF-SQL-VS-001	1	1	11	1	Transaction ID Wraparound (PostgreSQL)
51	PERF-SQL-VS-002	1	1	11	2	TOAST Table Bloat (PostgreSQL)
52	PERF-SQL-VS-003	1	1	11	3	ROS Pushback (Vertica)
53	PERF-SQL-VS-004	1	1	11	4	WOS Spill (Vertica)
54	HLTH-SQL-BR-001	2	1	12	1	Backup Job Failure
55	HLTH-SQL-BR-002	2	1	12	2	Backup Validation Failure
56	HLTH-SQL-BR-003	2	1	12	3	Recovery Point Gap
57	HLTH-SQL-BR-004	2	1	12	4	PITR Unavailable
58	HLTH-SQL-BR-005	2	1	12	5	Backup Retention Policy Violation
59	HLTH-SQL-BR-006	2	1	12	6	Backup Chain Broken
60	HLTH-SQL-BR-007	2	1	12	7	Backup Storage Critical
61	HLTH-SQL-RP-001	2	1	13	1	Replication Lag Excessive
62	HLTH-SQL-RP-002	2	1	13	2	Replication Stopped/Broken
63	HLTH-SQL-RP-003	2	1	13	3	Split-Brain Scenario
65	HLTH-SQL-RP-005	2	1	13	5	Synchronous Replication Timeout
66	HLTH-SQL-RP-006	2	1	13	6	Replication Conflict
67	HLTH-SQL-SM-001	2	1	14	1	Disk Space Critical
68	HLTH-SQL-SM-002	2	1	14	2	Tablespace Growth Abnormal
69	HLTH-SQL-SM-003	2	1	14	3	Data File Auto-Growth Excessive
70	HLTH-SQL-SM-004	2	1	14	4	TempDB Growth Uncontrolled
71	HLTH-SQL-SM-005	2	1	14	5	Data File Corruption
72	HLTH-SQL-SM-006	2	1	14	6	I/O Latency Degradation
73	HLTH-SQL-SM-007	2	1	14	7	Log File Growth Uncontrolled
74	HLTH-SQL-HA-001	2	1	15	1	Failover Readiness Degraded
75	HLTH-SQL-HA-002	2	1	15	2	Cluster Node Down
76	HLTH-SQL-HA-003	2	1	15	3	Automatic Failover Failed
77	HLTH-SQL-HA-004	2	1	15	4	Load Balancer Health Check Failing
78	HLTH-SQL-HA-005	2	1	15	5	Quorum Loss
79	HLTH-SQL-HA-006	2	1	15	6	Witness/Arbiter Unavailable
81	HLTH-SQL-DM-002	2	1	16	2	Statistics Stale
82	HLTH-SQL-DM-003	2	1	16	3	Table/Index Bloat
83	HLTH-SQL-DM-004	2	1	16	4	Index Fragmentation High
84	HLTH-SQL-DM-005	2	1	16	5	Transaction ID Wraparound Risk (PostgreSQL)
85	HLTH-SQL-DM-006	2	1	16	6	Integrity Check Overdue
86	HLTH-SQL-DM-007	2	1	16	7	Maintenance Plan Failed
87	HLTH-SQL-LM-001	2	1	17	1	Transaction Log Space Critical
88	HLTH-SQL-LM-002	2	1	17	2	Log Shipping Delay (SQL Server)
89	HLTH-SQL-LM-003	2	1	17	3	Archive Log Gap (Oracle)
90	HLTH-SQL-LM-004	2	1	17	4	WAL Archiving Failure (PostgreSQL)
92	HLTH-SQL-LM-006	2	1	17	6	PITR Disabled
93	HLTH-SQL-SJ-001	2	1	18	1	Critical Job Failure
94	HLTH-SQL-SJ-002	2	1	18	2	Job Missed/Skipped
95	HLTH-SQL-SJ-003	2	1	18	3	Job Duration Exceeded
96	HLTH-SQL-SJ-004	2	1	18	4	Jobs Overlapping Peak Hours
97	HLTH-SQL-SJ-005	2	1	18	5	ETL Job Failure
98	HLTH-SQL-UP-001	2	1	19	1	Version Out of Support
99	HLTH-SQL-UP-002	2	1	19	2	Critical Security Patch Missing
100	HLTH-SQL-UP-003	2	1	19	3	Patch Level Inconsistent
101	HLTH-SQL-UP-004	2	1	19	4	Upgrade/Patch Failed
102	HLTH-SQL-CD-001	2	1	20	1	Parameter Changed
103	HLTH-SQL-CD-002	2	1	20	2	Critical Parameter Misconfigured
104	HLTH-SQL-CD-003	2	1	20	3	Cluster Config Inconsistent
105	HLTH-SQL-CD-004	2	1	20	4	Security Config Weakened
106	HLTH-SQL-CD-005	2	1	20	5	Privilege Escalation Detected
107	HLTH-SQL-AD-001	2	1	21	1	Connection Pool Exhaustion
108	HLTH-SQL-AD-002	2	1	21	2	Deadlock Frequency Elevated
109	HLTH-SQL-AD-003	2	1	21	3	Unexpected Instance Restart
110	SEC-SQL-AU-001	3	1	22	1	Default Admin Accounts Enabled
111	SEC-SQL-AU-002	3	1	22	2	Empty/Blank Passwords Allowed
112	SEC-SQL-AU-003	3	1	22	3	Weak Password Policy
113	SEC-SQL-AU-004	3	1	22	4	Remote OS Authentication Enabled
114	SEC-SQL-AU-005	3	1	22	5	Mixed Mode Authentication
115	SEC-SQL-AU-006	3	1	22	6	Dormant/Unused Accounts
116	SEC-SQL-AU-007	3	1	22	7	Trust Authentication Enabled
117	SEC-SQL-AZ-001	3	1	23	1	Excessive Administrative Privileges
118	SEC-SQL-AZ-002	3	1	23	2	PUBLIC Role Excessive Access
119	SEC-SQL-AZ-003	3	1	23	3	Orphaned User Accounts
120	SEC-SQL-AZ-004	3	1	23	4	File System Access Privilege
121	SEC-SQL-AZ-005	3	1	23	5	Cross-Database Ownership Chaining
122	SEC-SQL-AZ-006	3	1	23	6	Grant Option Abuse
123	SEC-SQL-ENC-001	3	1	24	1	Data-in-Transit Unencrypted
124	SEC-SQL-ENC-002	3	1	24	2	Obsolete TLS Versions
125	SEC-SQL-ENC-003	3	1	24	3	Transparent Data Encryption Disabled
126	SEC-SQL-ENC-004	3	1	24	4	Unencrypted Backups
127	SEC-SQL-ENC-005	3	1	24	5	Weak Encryption Keys/Ciphers
128	SEC-SQL-AUD-001	3	1	25	1	Audit Logging Disabled
129	SEC-SQL-AUD-002	3	1	25	2	Inadequate Log Retention
130	SEC-SQL-AUD-003	3	1	25	3	Audit Trail Modification Risk
131	SEC-SQL-AUD-004	3	1	25	4	Missing Login Failure Logs
132	SEC-SQL-AUD-005	3	1	25	5	DDL Logging Disabled
133	SEC-SQL-NET-001	3	1	26	1	Database Exposed to Public Internet
134	SEC-SQL-NET-002	3	1	26	2	Default Ports in Use
135	SEC-SQL-NET-003	3	1	26	3	Unrestricted Outbound Connections
136	SEC-SQL-CFG-001	3	1	27	1	xp_cmdshell Enabled (SQL Server)
137	SEC-SQL-CFG-002	3	1	27	2	local_infile Enabled (MySQL/MariaDB)
138	SEC-SQL-CFG-003	3	1	27	3	Sample/Test Databases Present
139	SEC-SQL-CFG-004	3	1	27	4	CLR/Java Enabled (SQL Server/Oracle)
140	SEC-SQL-CFG-005	3	1	27	5	Debug/Trace Flags Enabled
141	SEC-SQL-CFG-006	3	1	27	6	Database Links Unsecured
142	SEC-SQL-INJ-001	3	1	28	1	Dynamic SQL in Stored Procedures
143	SEC-SQL-INJ-002	3	1	28	2	Extended Stored Procedures in Use
144	SEC-SQL-PAT-001	3	1	29	1	End-of-Life Database Version
145	SEC-SQL-PAT-002	3	1	29	2	Missing Critical Security Patches
146	SEC-SQL-PRI-001	3	1	30	1	PII Exposed in Clear Text
147	SEC-SQL-PRI-002	3	1	30	2	Sensitive Data in Logs
148	SEC-SQL-VS-001	3	1	11	1	Vertica UI/DB Privilege Overlap
149	SEC-SQL-VS-002	3	1	11	2	PostgreSQL Insecure Extensions
150	SEC-SQL-VS-003	3	1	11	3	Oracle Default Passwords
151	PERF-DOC-QRY-001	1	2	31	1	Slow Query Execution
152	PERF-DOC-QRY-002	1	2	31	2	Collection Scan (COLLSCAN)
153	PERF-DOC-QRY-003	1	2	31	3	Inefficient Aggregation Pipeline
154	PERF-DOC-QRY-004	1	2	31	4	Missing Projection Optimization
155	PERF-DOC-QRY-005	1	2	31	5	Regex Query Without Index
156	PERF-DOC-QRY-006	1	2	31	6	Inefficient Sort Operation
157	PERF-DOC-QRY-007	1	2	31	7	Excessive Skip/Limit Offset
158	PERF-DOC-QRY-008	1	2	31	8	Query Result Set Too Large
159	PERF-DOC-QRY-009	1	2	31	9	\\$where JavaScript Evaluation
160	PERF-DOC-QRY-010	1	2	31	10	Unoptimized \\$lookup Operations
161	PERF-DOC-IDX-001	1	2	32	1	Missing Required Indexes
162	PERF-DOC-IDX-002	1	2	32	2	Unused Indexes
163	PERF-DOC-IDX-003	1	2	32	3	Redundant/Duplicate Indexes
164	PERF-DOC-IDX-004	1	2	32	4	Non-Covered Query
165	PERF-DOC-IDX-005	1	2	32	5	Wrong Index Selected
166	PERF-DOC-IDX-006	1	2	32	6	Compound Index Wrong Order
167	PERF-DOC-IDX-007	1	2	32	7	Index Selectivity Too Low
168	PERF-DOC-IDX-008	1	2	32	8	Index Bloat/Fragmentation
169	PERF-DOC-IDX-009	1	2	32	9	Missing Text/FTS Index
170	PERF-DOC-IDX-010	1	2	32	10	Index Build In Progress
171	PERF-DOC-IDX-011	1	2	32	11	Array Index Inefficiency
172	PERF-DOC-IDX-012	1	2	32	12	Partial Index Not Utilized
173	PERF-DOC-DOC-001	1	2	33	1	Unbounded Array Growth
174	PERF-DOC-DOC-002	1	2	33	2	Document Size Exceeds Limit
175	PERF-DOC-DOC-003	1	2	33	3	Bloated Documents
176	PERF-DOC-DOC-004	1	2	33	4	Over-Normalization
177	PERF-DOC-DOC-005	1	2	33	5	Over-Embedding
178	PERF-DOC-DOC-006	1	2	33	6	Missing Extended Reference
179	PERF-DOC-DOC-007	1	2	33	7	Inefficient Array Updates
180	PERF-DOC-DOC-008	1	2	33	8	Large String Fields
181	PERF-DOC-DOC-009	1	2	33	9	Polymorphic Schema Issues
182	PERF-DOC-DOC-010	1	2	33	10	Missing Schema Validation
183	PERF-DOC-SHD-001	1	2	34	1	Hot Shard/Partition
184	PERF-DOC-SHD-002	1	2	34	2	Poor Shard Key Selection
185	PERF-DOC-SHD-003	1	2	34	3	Jumbo Chunks
186	PERF-DOC-SHD-004	1	2	34	4	Unbalanced Chunk Distribution
187	PERF-DOC-SHD-005	1	2	34	5	Scatter-Gather Queries
188	PERF-DOC-SHD-006	1	2	34	6	Orphaned Documents
189	PERF-DOC-SHD-007	1	2	34	7	Excessive Chunk Migrations
190	PERF-DOC-SHD-008	1	2	34	8	Range-Based Sharding Issues
191	PERF-DOC-SHD-009	1	2	34	9	Cross-Partition Queries
192	PERF-DOC-SHD-010	1	2	34	10	Hot Partition Write Throttling
202	PERF-DOC-CON-001	1	2	35	1	Connection Pool Exhaustion
203	PERF-DOC-CON-002	1	2	35	2	Connection Storm
204	PERF-DOC-CON-003	1	2	35	3	Connection Leak
205	PERF-DOC-CON-004	1	2	35	4	Too Many Open Connections
206	PERF-DOC-CON-005	1	2	35	5	Connection Timeout Errors
207	PERF-DOC-CON-006	1	2	35	6	Inefficient Connection Usage
208	PERF-DOC-CON-007	1	2	35	7	Transaction Connection Starvation
209	PERF-DOC-CON-008	1	2	35	8	Cursor Timeout Issues
210	PERF-DOC-MEM-001	1	2	36	1	WiredTiger Cache Pressure
211	PERF-DOC-MEM-002	1	2	36	2	Working Set Exceeds Memory
212	PERF-DOC-MEM-003	1	2	36	3	Memory Fragmentation
213	PERF-DOC-MEM-004	1	2	36	4	Page Fault Frequency High
214	PERF-DOC-MEM-005	1	2	36	5	Insufficient Cache Hit Ratio
215	PERF-DOC-MEM-006	1	2	36	6	Memory Leak in Application
216	PERF-DOC-MEM-007	1	2	36	7	Query Result Set Memory Overflow
217	PERF-DOC-MEM-008	1	2	36	8	Index Memory Overhead
218	PERF-DOC-WRT-001	1	2	37	1	Write Concern Overhead
219	PERF-DOC-WRT-002	1	2	37	2	Journal Commit Latency
220	PERF-DOC-WRT-003	1	2	37	3	Write Lock Contention
221	PERF-DOC-WRT-004	1	2	37	4	Bulk Write Not Optimized
222	PERF-DOC-WRT-005	1	2	37	5	In-Place Update Impossible
223	PERF-DOC-WRT-006	1	2	37	6	Index Overhead on Writes
224	PERF-DOC-WRT-007	1	2	37	7	Unacknowledged Writes
225	PERF-DOC-WRT-008	1	2	37	8	Write Throughput Throttling
226	HLTH-DOC-BAK-001	2	2	38	1	Backup Failure
227	HLTH-DOC-BAK-002	2	2	38	2	Backup Incomplete
228	HLTH-DOC-BAK-003	2	2	38	3	Oplog Window Too Small
229	HLTH-DOC-BAK-004	2	2	38	4	PITR Gap Detected
230	HLTH-DOC-BAK-005	2	2	38	5	Backup Retention Not Met
231	HLTH-DOC-BAK-006	2	2	38	6	Slow Backup Performance
232	HLTH-DOC-BAK-007	2	2	38	7	Restore Test Failure
233	HLTH-DOC-BAK-008	2	2	38	8	Backup Storage Full
234	HLTH-DOC-BAK-009	2	2	38	9	Change Stream Lag
235	HLTH-DOC-BAK-010	2	2	38	10	Corrupted Backup Detected
236	HLTH-DOC-REP-001	2	2	39	1	Replica Lag Excessive
237	HLTH-DOC-REP-002	2	2	39	2	Replication Stopped/Failed
238	HLTH-DOC-REP-003	2	2	39	3	Sync Source Unavailable
239	HLTH-DOC-REP-004	2	2	39	4	Election Failure
240	HLTH-DOC-REP-005	2	2	39	5	Split-Brain Scenario
241	HLTH-DOC-REP-006	2	2	39	6	Rollback Required
242	HLTH-DOC-REP-007	2	2	39	7	Secondary Falling Too Far Behind
243	HLTH-DOC-REP-008	2	2	39	8	Initial Sync Failure
244	HLTH-DOC-REP-009	2	2	39	9	Heartbeat Failure
245	HLTH-DOC-REP-010	2	2	39	10	Arbiter Voting Issues
246	HLTH-DOC-REP-011	2	2	39	11	XDCR Conflict Accumulation
247	HLTH-DOC-REP-012	2	2	39	12	Chained Replication Lag
248	HLTH-DOC-STG-001	2	2	40	1	Disk Space Critical
249	HLTH-DOC-STG-002	2	2	40	2	Storage Fragmentation High
250	HLTH-DOC-STG-003	2	2	40	3	Compaction Needed
251	HLTH-DOC-STG-004	2	2	40	4	Storage Engine Inefficiency
252	HLTH-DOC-STG-005	2	2	40	5	Data File Corruption
253	HLTH-DOC-STG-006	2	2	40	6	Storage I/O Saturation
254	HLTH-DOC-STG-007	2	2	40	7	Journal File Growth
255	HLTH-DOC-STG-008	2	2	40	8	High Water Mark Issue
256	HLTH-DOC-STG-009	2	2	40	9	Storage Quota Exceeded
257	HLTH-DOC-HA-001	2	2	41	1	Single Point of Failure
258	HLTH-DOC-HA-002	2	2	41	2	Insufficient Voting Members
259	HLTH-DOC-HA-003	2	2	41	3	Node Health Check Failure
260	HLTH-DOC-HA-004	2	2	41	4	Failover Readiness Untested
261	HLTH-DOC-HA-005	2	2	41	5	Geographic Distribution Lacking
262	HLTH-DOC-HA-006	2	2	41	6	Improper Priority Configuration
263	HLTH-DOC-HA-007	2	2	41	7	Connection String Misconfiguration
264	HLTH-DOC-HA-008	2	2	41	8	Disaster Recovery Plan Missing
272	HLTH-DOC-CLU-001	2	2	42	1	Balancer Disabled
273	HLTH-DOC-CLU-002	2	2	42	2	Chunk Migration Failure
274	HLTH-DOC-CLU-003	2	2	42	3	Config Server Unavailable
275	HLTH-DOC-CLU-004	2	2	42	4	Shard Unresponsive
276	HLTH-DOC-CLU-005	2	2	42	5	Router (mongos) Failure
277	HLTH-DOC-CLU-006	2	2	42	6	Metadata Inconsistency
278	HLTH-DOC-CLU-007	2	2	42	7	Balancing Window Misconfigured
279	HLTH-DOC-CLU-008	2	2	42	8	Shard Draining Incomplete
280	HLTH-DOC-MNT-001	2	2	43	1	Index Rebuild Required
281	HLTH-DOC-MNT-002	2	2	43	2	Compaction Overdue
282	HLTH-DOC-MNT-003	2	2	43	3	Repair Operation Needed
283	HLTH-DOC-MNT-004	2	2	43	4	Statistics Out of Date
284	HLTH-DOC-MNT-005	2	2	43	5	Upgrade Available
285	HLTH-DOC-MNT-006	2	2	43	6	Index Defragmentation Needed
286	HLTH-DOC-LOG-001	2	2	44	1	Log Rotation Not Configured
287	HLTH-DOC-LOG-002	2	2	44	2	Log Disk Full
288	HLTH-DOC-LOG-003	2	2	44	3	Log Level Too Verbose
289	HLTH-DOC-LOG-004	2	2	44	4	Missing Critical Log Events
290	HLTH-DOC-UPG-001	2	2	45	1	Version Incompatibility
291	HLTH-DOC-UPG-002	2	2	45	2	Rolling Upgrade Failure
292	HLTH-DOC-UPG-003	2	2	45	3	Feature Compatibility Version Wrong
293	HLTH-DOC-UPG-004	2	2	45	4	Deprecated Feature Usage
294	HLTH-DOC-UPG-005	2	2	45	5	Patch Not Applied
295	SEC-DOC-AUTH-001	3	2	46	1	Default Credentials in Use
296	SEC-DOC-AUTH-002	3	2	46	2	Weak Password Policy
297	SEC-DOC-AUTH-003	3	2	46	3	Admin Party Enabled
298	SEC-DOC-AUTH-004	3	2	46	4	Authentication Disabled
299	SEC-DOC-AUTH-005	3	2	46	5	Failed Authentication Attempts High
300	SEC-DOC-AUTH-006	3	2	46	6	LDAP/AD Integration Broken
301	SEC-DOC-AUTH-007	3	2	46	7	Certificate Authentication Issues
302	SEC-DOC-AUTH-008	3	2	46	8	OIDC Authentication Vulnerability
303	SEC-DOC-AUTH-009	3	2	46	9	Account Lockout Not Configured
304	SEC-DOC-AUTH-010	3	2	46	10	Session Timeout Too Long
305	SEC-DOC-AUTHZ-001	3	2	47	1	Excessive Privileges Granted
306	SEC-DOC-AUTHZ-002	3	2	47	2	Missing Role-Based Access Control
307	SEC-DOC-AUTHZ-003	3	2	47	3	Database-Level vs Collection-Level Permissions
308	SEC-DOC-AUTHZ-004	3	2	47	4	Unauthorized Data Access
309	SEC-DOC-AUTHZ-005	3	2	47	5	Application Using Root/Admin Credentials
310	SEC-DOC-AUTHZ-006	3	2	47	6	No Audit of Permission Changes
311	SEC-DOC-ENC-001	3	2	48	1	TLS/SSL Not Enabled
312	SEC-DOC-ENC-002	3	2	48	2	Weak TLS Version/Cipher
313	SEC-DOC-ENC-003	3	2	48	3	Encryption at Rest Disabled
314	SEC-DOC-ENC-004	3	2	48	4	Field-Level Encryption Missing
315	SEC-DOC-ENC-005	3	2	48	5	Certificate Expired
316	SEC-DOC-ENC-006	3	2	48	6	Self-Signed Certificates in Production
317	SEC-DOC-ENC-007	3	2	48	7	Key Management Issues
318	SEC-DOC-ENC-008	3	2	48	8	Certificate Validation Bypass
319	SEC-DOC-AUD-001	3	2	49	1	Audit Logging Disabled
320	SEC-DOC-AUD-002	3	2	49	2	Insufficient Audit Coverage
321	SEC-DOC-AUD-003	3	2	49	3	Audit Log Retention Too Short
322	SEC-DOC-AUD-004	3	2	49	4	Audit Logs Not Protected
323	SEC-DOC-AUD-005	3	2	49	5	CloudWatch Export Not Configured
324	SEC-DOC-AUD-006	3	2	49	6	Compliance Audit Gaps
325	SEC-DOC-NET-001	3	2	50	1	Database Publicly Exposed
326	SEC-DOC-NET-002	3	2	50	2	Bind IP Misconfigured
327	SEC-DOC-NET-003	3	2	50	3	Firewall Rules Too Permissive
328	SEC-DOC-NET-004	3	2	50	4	VPC/VNet Not Used
329	SEC-DOC-NET-005	3	2	50	5	Private Endpoint Not Configured
330	SEC-DOC-NET-006	3	2	50	6	Network Segmentation Missing
331	SEC-DOC-INJ-001	3	2	51	1	NoSQL Injection Vulnerability
332	SEC-DOC-INJ-002	3	2	51	2	Query Operator Injection
333	SEC-DOC-INJ-003	3	2	51	3	JavaScript Injection via \\$where
334	SEC-DOC-INJ-004	3	2	51	4	Authentication Bypass via Injection
335	SEC-DOC-INJ-005	3	2	51	5	Regex DoS (ReDoS)
336	SEC-DOC-DAT-001	3	2	52	1	PII Stored Unencrypted
337	SEC-DOC-DAT-002	3	2	52	2	Data Masking Not Implemented
338	SEC-DOC-DAT-003	3	2	52	3	Backup Encryption Disabled
339	SEC-DOC-DAT-004	3	2	52	4	Data Retention Policy Violation
340	SEC-DOC-DAT-005	3	2	52	5	Cross-Region Replication Security
350	PERF-KV-KEY-001	1	3	53	1	Hot Key Concentration
351	PERF-KV-KEY-002	1	3	53	2	Large Key Size
352	PERF-KV-KEY-003	1	3	53	3	Poor Key Distribution
353	PERF-KV-KEY-004	1	3	53	4	Cross-Slot Multi-Key Operations
354	PERF-KV-KEY-005	1	3	53	5	Key Naming Pattern Overhead
355	PERF-KV-MEM-001	1	3	54	1	Memory Fragmentation
356	PERF-KV-MEM-002	1	3	54	2	Memory Overhead
357	PERF-KV-MEM-003	1	3	54	3	Eviction Thrashing
358	PERF-KV-MEM-004	1	3	54	4	Swap Usage
359	PERF-KV-MEM-005	1	3	54	5	OOM Conditions
360	PERF-KV-MEM-006	1	3	54	6	Slab Allocation Imbalance
361	PERF-KV-MEM-007	1	3	54	7	Internal Fragmentation
362	PERF-KV-EVICT-001	1	3	55	1	Inappropriate Eviction Policy
363	PERF-KV-EVICT-002	1	3	55	2	Premature Eviction
364	PERF-KV-EVICT-003	1	3	55	3	Cache Miss Storm
365	PERF-KV-EVICT-004	1	3	55	4	Eviction Policy Mismatch
366	PERF-KV-THRU-001	1	3	56	1	Request Rate Throttling
367	PERF-KV-THRU-002	1	3	56	2	Partition-Level Throttling
368	PERF-KV-THRU-003	1	3	56	3	GSI Write Throttling
369	PERF-KV-THRU-004	1	3	56	4	Bandwidth Saturation
370	PERF-KV-THRU-005	1	3	56	5	Operations per Second Limit
371	PERF-KV-LAT-001	1	3	57	1	Blocking Commands
372	PERF-KV-LAT-002	1	3	57	2	Large Value Operations
373	PERF-KV-LAT-003	1	3	57	3	Network Round-Trip Latency
374	PERF-KV-LAT-004	1	3	57	4	Disk I/O Latency
375	PERF-KV-LAT-005	1	3	57	5	Slow Complex Commands
376	PERF-KV-LAT-006	1	3	57	6	AOF Fsync Blocking
377	PERF-KV-CONN-001	1	3	58	1	Connection Pool Exhaustion
378	PERF-KV-CONN-002	1	3	58	2	Connection Overhead
379	PERF-KV-CONN-003	1	3	58	3	Connection Limit Reached
380	PERF-KV-CONN-004	1	3	58	4	Pipelining Underutilization
381	PERF-KV-DATA-001	1	3	59	1	Inefficient Data Structure Selection
382	PERF-KV-DATA-002	1	3	59	2	Large Set/List Operations
383	PERF-KV-DATA-003	1	3	59	3	Big Key Problem
384	PERF-KV-CLUST-001	1	3	60	1	Cross-Slot Query Limitations
385	PERF-KV-CLUST-002	1	3	60	2	Resharding Performance Impact
386	PERF-KV-CLUST-003	1	3	60	3	Node Imbalance
387	PERF-KV-CLUST-004	1	3	60	4	Slot Migration Delays
388	PERF-KV-PUBSUB-001	1	3	61	1	Subscriber Backlog
389	PERF-KV-PUBSUB-002	1	3	61	2	Channel Overhead
390	PERF-KV-PUBSUB-003	1	3	61	3	Message Loss
391	PERF-KV-TTL-001	1	3	62	1	Excessive Key Expiration Load
392	PERF-KV-TTL-002	1	3	62	2	Expiration Backlog
393	HLTH-KV-PERS-001	2	3	63	1	RDB Snapshot Failures
394	HLTH-KV-PERS-002	2	3	63	2	AOF Corruption
395	HLTH-KV-PERS-003	2	3	63	3	AOF Rewrite Failures
396	HLTH-KV-PERS-004	2	3	63	4	Fork Overhead
397	HLTH-KV-PERS-005	2	3	63	5	Persistence Disk Space Exhaustion
398	HLTH-KV-PERS-006	2	3	63	6	Snapshot Performance Degradation
399	HLTH-KV-REP-001	2	3	64	1	Replica Lag
400	HLTH-KV-REP-002	2	3	64	2	Replication Sync Failures
401	HLTH-KV-REP-003	2	3	64	3	Partial Resync Failures
402	HLTH-KV-REP-004	2	3	64	4	Full Resync Impact
403	HLTH-KV-REP-005	2	3	64	5	Replica Promotion Delays
404	HLTH-KV-REP-006	2	3	64	6	Replication Timeout
405	HLTH-KV-TOPO-001	2	3	65	1	Quorum Loss
406	HLTH-KV-TOPO-002	2	3	65	2	Split-Brain Scenario
407	HLTH-KV-TOPO-003	2	3	65	3	Slot Coverage Incomplete
408	HLTH-KV-TOPO-004	2	3	65	4	Node Failure Detection Delays
409	HLTH-KV-TOPO-005	2	3	65	5	Membership Change Failures
410	HLTH-KV-MEM-001	2	3	54	1	Maxmemory Limit Reached
411	HLTH-KV-MEM-002	2	3	54	2	Memory Limit Enforcement Failures
412	HLTH-KV-STOR-001	2	3	66	1	Disk Space for Persistence
413	HLTH-KV-STOR-002	2	3	66	2	SSD Wear
414	HLTH-KV-STOR-003	2	3	66	3	I/O Bottleneck
415	HLTH-KV-STOR-004	2	3	66	4	Defragmentation Issues
416	HLTH-KV-STOR-005	2	3	66	5	Storage Engine Misconfiguration
417	HLTH-KV-BACKUP-001	2	3	67	1	Backup Failures
418	HLTH-KV-BACKUP-002	2	3	67	2	Restore Time Excessive
419	HLTH-KV-BACKUP-003	2	3	67	3	Point-in-Time Recovery Limitations
420	HLTH-KV-BACKUP-004	2	3	67	4	Backup Storage Exhaustion
421	HLTH-KV-BACKUP-005	2	3	67	5	Snapshot Integrity Issues
422	HLTH-KV-BACKUP-006	2	3	67	6	Cross-Region Backup Failures
423	HLTH-KV-HA-001	2	3	68	1	Failover Detection Delays
424	HLTH-KV-HA-002	2	3	68	2	Automatic Failover Failures
425	HLTH-KV-HA-003	2	3	68	3	Sentinel Configuration Issues
426	HLTH-KV-MAINT-001	2	3	69	1	Background Task Interference
427	HLTH-KV-MAINT-002	2	3	69	2	Defragmentation CPU Impact
428	HLTH-KV-MAINT-003	2	3	69	3	Key Expiration Backlog
429	HLTH-KV-UPGR-001	2	3	70	1	Version Compatibility Issues
430	HLTH-KV-UPGR-002	2	3	70	2	Rolling Upgrade Failures
431	HLTH-KV-UPGR-003	2	3	70	3	Extended Support Costs
432	HLTH-KV-UPGR-004	2	3	70	4	Protocol Changes
433	SEC-KV-AUTH-001	3	3	71	1	No Authentication Configured
434	SEC-KV-AUTH-002	3	3	71	2	Weak Password Configuration
435	SEC-KV-AUTH-003	3	3	71	3	Default Credentials Exposed
436	SEC-KV-AUTH-004	3	3	71	4	Authentication Bypass
437	SEC-KV-AUTHZ-001	3	3	72	1	No ACL Configuration
438	SEC-KV-AUTHZ-002	3	3	72	2	Overly Permissive ACLs
439	SEC-KV-AUTHZ-003	3	3	72	3	Missing Command Restrictions
440	SEC-KV-AUTHZ-004	3	3	72	4	Key Pattern Permission Issues
441	SEC-KV-AUTHZ-005	3	3	72	5	IAM Policy Misconfigurations
442	SEC-KV-NET-001	3	3	73	1	Publicly Accessible Instance
443	SEC-KV-NET-002	3	3	73	2	Unprotected Ports
444	SEC-KV-NET-003	3	3	73	3	Bind to 0.0.0.0
445	SEC-KV-NET-004	3	3	73	4	Protected Mode Disabled
446	SEC-KV-NET-005	3	3	73	5	Missing Network Segmentation
447	SEC-KV-ENC-001	3	3	74	1	No TLS/SSL Configured
448	SEC-KV-ENC-002	3	3	74	2	Weak TLS Configuration
449	SEC-KV-ENC-003	3	3	74	3	No Encryption at Rest
450	SEC-KV-ENC-004	3	3	74	4	Unencrypted Data in Transit
451	SEC-KV-ENC-005	3	3	74	5	Customer-Managed Key Issues
452	SEC-KV-CMD-001	3	3	75	1	FLUSHALL Command Enabled
453	SEC-KV-CMD-002	3	3	75	2	CONFIG Command Accessible
454	SEC-KV-CMD-003	3	3	75	3	DEBUG Commands Enabled
455	SEC-KV-CMD-004	3	3	75	4	KEYS Command in Production
456	SEC-KV-CMD-005	3	3	75	5	Dangerous Lua Commands (EVAL/EVALSHA)
457	SEC-KV-CMD-006	3	3	75	6	Module Loading Enabled
458	SEC-KV-DATA-001	3	3	59	1	Sensitive Data in Keys
459	SEC-KV-DATA-002	3	3	59	2	PII Without Encryption
460	SEC-KV-DATA-003	3	3	59	3	Unmasked Sensitive Values
461	SEC-KV-INJ-001	3	3	76	1	Lua Script Injection
462	SEC-KV-INJ-002	3	3	76	2	EVAL Command Exploitation
463	SEC-KV-INJ-003	3	3	76	3	Sandbox Escape Vulnerabilities
464	SEC-KV-INJ-004	3	3	76	4	Metatable Manipulation
465	SEC-KV-AUDIT-001	3	3	77	1	No Audit Logging
466	SEC-KV-AUDIT-002	3	3	77	2	Insufficient Command Logging
467	SEC-KV-AUDIT-003	3	3	77	3	No Access Tracking
468	SEC-KV-AUDIT-004	3	3	77	4	Missing Security Monitoring
469	PERF-VEC-IDX-001	1	4	78	1	HNSW Graph Connectivity Low
470	PERF-VEC-IDX-002	1	4	78	2	IVF Centroid Under-training
471	PERF-VEC-IDX-003	1	4	78	3	Index Build Memory OOM
472	PERF-VEC-IDX-004	1	4	78	4	Stale Index Statistics
473	PERF-VEC-IDX-005	1	4	78	5	Vector Dimension Mismatch
474	PERF-VEC-QRY-001	1	4	79	1	Cold Start Latency (Mmap)
475	PERF-VEC-QRY-002	1	4	79	2	Excessive Filtering (Pre-filter)
476	PERF-VEC-QRY-003	1	4	79	3	IVF Probe Exhaustion
477	PERF-VEC-QRY-004	1	4	79	4	Result Set Jitter
478	PERF-VEC-QRY-005	1	4	79	5	Cross-Shard Fanout Lag
479	PERF-VEC-QRY-006	1	4	79	6	Embedding Model Bottleneck
480	PERF-VEC-QRY-007	1	4	79	7	Distance Metric Miscalculation
481	PERF-VEC-ING-001	1	4	80	1	Small Batch Insert Overhead
482	PERF-VEC-ING-002	1	4	80	2	Write-Heavy Locking
483	PERF-VEC-ING-003	1	4	80	3	Embedder Pipeline Timeout
484	PERF-VEC-MEM-001	1	4	81	1	Index Size vs RAM Mismatch
485	PERF-VEC-MEM-002	1	4	81	2	Unreleased Memory Bloat
486	PERF-VEC-MEM-003	1	4	81	3	Metadata High Cardinality
487	PERF-VEC-DIM-001	1	4	82	1	Curse of Dimensionality
488	PERF-VEC-OPT-001	1	4	83	1	Missing SIMD Acceleration
489	PERF-VEC-HYB-001	1	4	84	1	Keyword-Vector Score Skew
490	PERF-VEC-HYB-002	1	4	84	2	Post-Filter Empty Set
491	PERF-VEC-SCL-001	1	4	85	1	Hot Partition/Shard
492	PERF-VEC-SCL-002	1	4	85	2	Global Limit Throttling
493	HLTH-VEC-IDX-001	2	4	78	1	Index Corruption
494	HLTH-VEC-IDX-002	2	4	78	2	Stale/Dead Tuples
495	HLTH-VEC-IDX-003	2	4	78	3	Unmerged Segments
496	HLTH-VEC-STG-001	2	4	86	1	Vector Storage Exhaustion
497	HLTH-VEC-STG-002	2	4	86	2	WAL/Log Growth
498	HLTH-VEC-REP-001	2	4	87	1	Replication Lag
499	HLTH-VEC-REP-002	2	4	87	2	Split Brain / Quorum Loss
500	HLTH-VEC-REP-003	2	4	87	3	Ghost Data (Deletes)
501	HLTH-VEC-BKP-001	2	4	88	1	Snapshot Consistency
502	HLTH-VEC-BKP-002	2	4	88	2	Index Restore Timeout
503	HLTH-VEC-RES-001	2	4	89	1	Collection Limit Reached
504	HLTH-VEC-RES-002	2	4	89	2	Namespace Sprawl
505	HLTH-VEC-MNT-001	2	4	90	1	Compaction Stall
506	HLTH-VEC-MNT-002	2	4	90	2	Schema Drift
507	HLTH-VEC-UPG-001	2	4	91	1	Embedding Model Drift
508	HLTH-VEC-UPG-002	2	4	91	2	Extension/Version Mismatch
509	HLTH-VEC-INT-001	2	4	92	1	API Rate Limiting
510	HLTH-VEC-INT-002	2	4	92	2	Orphaned Vectors
511	HLTH-VEC-INT-003	2	4	92	3	Duplicate Vectors
512	HLTH-VEC-SYS-001	2	4	93	1	File Descriptor Exhaustion
513	SEC-VEC-AUTH-001	3	4	94	1	API Key Exposure
514	SEC-VEC-AUTH-002	3	4	94	2	Default Credentials
515	SEC-VEC-AUTH-003	3	4	94	3	Missing TLS/SSL
516	SEC-VEC-ACC-001	3	4	95	1	Cross-Tenant Leakage
517	SEC-VEC-ACC-002	3	4	95	2	Over-Permissive Scope
518	SEC-VEC-ACC-003	3	4	95	3	Metadata Injection
519	SEC-VEC-DAT-001	3	4	96	1	Embedding Inversion
520	SEC-VEC-DAT-002	3	4	96	2	Unencrypted At-Rest
521	SEC-VEC-DAT-003	3	4	96	3	PII in Metadata
522	SEC-VEC-ATK-001	3	4	97	1	Prompt Injection (Retrieval)
523	SEC-VEC-ATK-002	3	4	97	2	Data Poisoning
524	SEC-VEC-ATK-003	3	4	97	3	DoS via Dimension
525	SEC-VEC-NET-001	3	4	98	1	Public Endpoint Exposure
526	SEC-VEC-NET-002	3	4	98	2	Man-in-the-Middle
527	SEC-VEC-LOG-001	3	4	99	1	Query Logging Missing
528	SEC-VEC-LOG-002	3	4	99	2	Sensitive Query Leak
80	HLTH-SQL-DM-001	2	1	16	1	Background Cleanup Not Running
91	HLTH-SQL-LM-005	2	1	17	5	Transaction Log Growth Uncontrolled
64	HLTH-SQL-RP-004	2	1	13	4	Change Distribution Stalled
\.
INSERT INTO public.issues (id, issue_id, domain_id, database_type_id, area_id, issue_number, name)
SELECT id, issue_id, domain_id, database_type_id, area_id, issue_number, name FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM public.issues);
DROP TABLE _stg_load;

SELECT setval('public.issues_id_seq', GREATEST((SELECT COALESCE(max(id),0) FROM public.issues),1), (SELECT count(*) FROM public.issues) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'issues'
          AND con.conname = 'issues_issue_id_key') THEN
        ALTER TABLE ONLY public.issues
    ADD CONSTRAINT issues_issue_id_key UNIQUE (issue_id);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'issues'
          AND con.conname = 'issues_pkey') THEN
        ALTER TABLE ONLY public.issues
    ADD CONSTRAINT issues_pkey PRIMARY KEY (id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_issues_database_type ON public.issues USING btree (database_type_id);
CREATE INDEX IF NOT EXISTS idx_issues_domain ON public.issues USING btree (domain_id);
