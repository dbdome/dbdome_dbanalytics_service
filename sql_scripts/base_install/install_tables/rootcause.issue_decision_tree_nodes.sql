-- Idempotent install for rootcause.issue_decision_tree_nodes
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS rootcause;

CREATE SEQUENCE IF NOT EXISTS rootcause.issue_decision_tree_nodes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS rootcause.issue_decision_tree_nodes (
    id integer NOT NULL,
    tree_id integer NOT NULL,
    parent_node_id integer,
    tier integer NOT NULL,
    sequence integer NOT NULL,
    gate_label text NOT NULL,
    gate_question text NOT NULL,
    gate_detection_step_id integer,
    on_match_rc_id character varying(40),
    on_match_terminate boolean DEFAULT false NOT NULL,
    on_match_drill_rc_ids character varying(40)[],
    notes text,
    is_active boolean DEFAULT true NOT NULL,
    on_no_match_terminate boolean DEFAULT false NOT NULL
);

ALTER TABLE rootcause.issue_decision_tree_nodes ALTER COLUMN id SET DEFAULT nextval('rootcause.issue_decision_tree_nodes_id_seq'::regclass);
ALTER SEQUENCE rootcause.issue_decision_tree_nodes_id_seq OWNED BY rootcause.issue_decision_tree_nodes.id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE rootcause.issue_decision_tree_nodes);
COPY _stg_load (id, tree_id, parent_node_id, tier, sequence, gate_label, gate_question, gate_detection_step_id, on_match_rc_id, on_match_terminate, on_match_drill_rc_ids, notes, is_active, on_no_match_terminate) FROM stdin;
37	1	\N	1	1	T1.1 blocked-now	Is the slow session currently blocked by another session?	2239	PERF-SQL-QE-001-RC08	t	\N	Active blocking is almost always THE cause; stop here.	t	f
38	1	\N	1	2	T1.2 missing-index-hint	Does the cached plan have <MissingIndexes> hints (sys.dm_db_missing_index_*)?	2225	PERF-SQL-QE-001-RC01	t	\N	DTA-grade hint = strong signal; engine is asking for an index.	t	f
39	1	\N	2	1	T2.1 stale-stats	Are stats older than 7d AND mod_pct > 20% on a referenced table?	2227	PERF-SQL-QE-001-RC02	f	\N	High-confidence cause when query plan was built off bad cardinality.	t	f
40	1	\N	2	2	T2.2 low-PLE	Is Page Life Expectancy < 300s OR buffer cache hit ratio < 95%?	2250	PERF-SQL-QE-001-RC14	f	{PERF-SQL-QE-001-RC03}	Memory pressure; drill into RC03 (hardware) to confirm root.	t	f
41	1	\N	3	1	T3.0 expensive-query	Is the query in Top-20 by avg_cpu_ms / avg_elapsed_ms in dm_exec_query_stats?	2231	PERF-SQL-QE-001-RC04	f	\N	Default RC if no sub-branch fires.	t	f
42	1	41	3	11	T3.1 full-scan-no-where	Plan shows full table scan with no SARGable predicate?	2243	PERF-SQL-QE-001-RC10	f	\N	Sub-branch under T3.0.	t	f
43	1	41	3	12	T3.2 high-complexity	Joins > 5 OR subtree_cost > 50?	2247	PERF-SQL-QE-001-RC12	f	\N	Sub-branch under T3.0.	t	f
44	1	41	3	13	T3.3 sort-or-hash-spill	Plan shows spill warnings (hash/sort to tempdb)?	2241	PERF-SQL-QE-001-RC09	f	\N	Sub-branch under T3.0.	t	f
45	1	41	3	14	T3.4 join-type-mismatch	Hash join chosen where merge/loop would be cheaper, or vice-versa?	2245	PERF-SQL-QE-001-RC11	f	{PERF-SQL-QE-001-RC06}	Sub-branch under T3.0; drill RC06 (suboptimal join order).	t	f
46	1	\N	4	1	T4.1 large-unpartitioned	Target table > 10M rows with no partition scheme?	2237	PERF-SQL-QE-001-RC07	f	\N	Often only meaningful for warehouse / archive tables.	t	f
47	1	\N	4	2	T4.2 fragmented-index	avg_fragmentation_in_percent > 30 on a hot index of the referenced table?	2233	PERF-SQL-QE-001-RC05	f	\N	Modern engines mostly self-heal; rare to be the lone cause.	t	f
48	1	\N	5	1	T5.1 config-drift	sp_configure deviates from best-practice baseline (MAXDOP, cost threshold, etc)?	2249	PERF-SQL-QE-001-RC13	f	\N	Last resort; rarely THE cause but cheap to check.	t	f
49	5	\N	1	1	T1.1 sensitive-cols-in-schema	Does the schema contain any column whose name suggests PII (password, ssn, credit_card, email, phone, etc.)?	12203	SEC-SQL-PRI-001-RC12	f	\N	Foundation gate: if no sensitive cols anywhere, entire issue ruled out — skip remaining tiers.	t	t
50	5	\N	1	2	T1.2 unsecured-backups	Are recent backups stored without encryption / on the same volume as data?	3337	SEC-SQL-PRI-001-RC11	f	\N	High-priority signal — even encrypted DB exposes PII via unsecured backups.	t	f
51	5	\N	2	1	T2.1 actively-queried	Are sensitive columns being actively read (DMV index usage stats > 0)?	12207	SEC-SQL-PRI-001-RC13	f	\N	Live read activity on PII tables.	t	f
52	5	\N	2	2	T2.2 active-tx-pii	Is a currently-running session executing a query that touches a sensitive column?	12736	SEC-SQL-PRI-001-RC14	f	\N	Snapshot of dm_exec_requests joined to PII tables.	t	f
53	5	\N	2	3	T2.3 cached-plans-and-active-tx	Do cached query plans (dm_exec_query_stats) or active transactions reference sensitive columns?	13065	SEC-SQL-PRI-001-RC15	f	\N	Broader historical view than RC14 + uncommitted transactions.	t	f
54	5	\N	3	1	T3.1 tde-misunderstanding	Is TDE missing/disabled on a database that holds PII?	3314	SEC-SQL-PRI-001-RC01	f	\N	TDE protects at-rest only; common misunderstanding that it covers more.	t	f
55	5	\N	3	2	T3.2 incorrect-data-types	Are sensitive columns stored as plain VARCHAR/NVARCHAR instead of an encrypted/binary type?	3321	SEC-SQL-PRI-001-RC04	f	\N	PII in plain text types defeats encryption later.	t	f
56	5	\N	3	3	T3.3 no-native-masking	Is the SQL Server version too old for Dynamic Data Masking / Always Encrypted?	3335	SEC-SQL-PRI-001-RC10	f	\N	DDM requires SQL Server 2016+; Always Encrypted requires 2016+.	t	f
57	5	\N	4	1	T4.1 key-management	Are encryption keys stored insecurely (in DB itself, no rotation, weak protection)?	3333	SEC-SQL-PRI-001-RC09	f	\N	Even encrypted PII is exposed if keys are weak.	t	f
58	5	\N	4	2	T4.2 in-house-masking-failed	Are columns purportedly masked by application logic still containing detectable PII patterns?	3327	SEC-SQL-PRI-001-RC06	f	\N	Self-rolled masking often leaks (XXXXXXX1234, partial hashing, etc.).	t	f
59	5	\N	4	3	T4.3 etl-stripping	Are ETL pipelines copying PII into staging / warehouse without stripping?	3330	SEC-SQL-PRI-001-RC07	f	\N	Downstream systems often inherit PII unintentionally.	t	f
60	5	\N	4	4	T4.4 legacy-schema	Is the schema constrained by legacy app contracts (FK to plain VARCHAR, indexes on PII)?	3324	SEC-SQL-PRI-001-RC05	f	\N	Legacy constraints often block adding encryption.	t	f
61	5	\N	5	1	T5.1 performance-fears	Was encryption avoided due to performance overhead concerns (proxied by query latency)?	3319	SEC-SQL-PRI-001-RC03	f	\N	Often unfounded with modern hardware; surface for policy review.	t	f
62	5	\N	5	2	T5.2 searchability-concerns	Are sensitive columns indexed / used in WHERE clauses (suggesting plain-text needs)?	3316	SEC-SQL-PRI-001-RC02	f	\N	Indexed PII often blocks encryption; consider deterministic encryption / hashed lookups.	t	f
63	6	\N	1	1	T1.1 sensitive-cols-in-schema	Does the schema contain any column whose name suggests PII?	12204	SEC-SQL-PRI-001-RC12	f	\N	Foundation: if no sensitive cols anywhere, entire issue ruled out.	t	t
64	6	\N	1	2	T1.2 unsecured-backups	Are backups stored without encryption / on the same volume as data?	9707	SEC-SQL-PRI-001-RC11	f	\N	High-priority signal — encrypted DB still leaks via unsecured backups.	t	f
65	6	\N	2	1	T2.1 actively-queried	Are sensitive columns being actively read by user queries?	12208	SEC-SQL-PRI-001-RC13	f	\N	Live read activity on PII tables.	t	f
66	6	\N	2	2	T2.2 active-tx-pii	Is a currently-running session executing a query that touches a sensitive column?	12737	SEC-SQL-PRI-001-RC14	f	\N	Snapshot of currently-running requests joined to PII tables.	t	f
67	6	\N	2	3	T2.3 cached-plans-and-active-tx	Do cached query plans or active transactions reference sensitive columns?	13066	SEC-SQL-PRI-001-RC15	f	\N	Broader historical view + uncommitted transactions.	t	f
68	6	\N	3	1	T3.1 tde-misunderstanding	Is database-level encryption (TDE) missing/disabled?	9692	SEC-SQL-PRI-001-RC01	f	\N	Common misunderstanding that TDE covers more than at-rest.	t	f
69	6	\N	3	2	T3.2 incorrect-data-types	Are sensitive columns stored as plain string types instead of binary/encrypted?	9697	SEC-SQL-PRI-001-RC04	f	\N	PII stored as plain text defeats later encryption.	t	f
70	6	\N	3	3	T3.3 no-native-masking	Is the engine version too old for native data masking features?	9705	SEC-SQL-PRI-001-RC10	f	\N	DDM / Always-Encrypted require recent versions.	t	f
71	6	\N	4	1	T4.1 key-management	Are encryption keys stored insecurely (in DB, no rotation, weak protection)?	9704	SEC-SQL-PRI-001-RC09	f	\N	Even encrypted PII is exposed if keys are weak.	t	f
72	6	\N	4	2	T4.2 in-house-masking-failed	Are application-masked columns still containing detectable PII patterns?	9699	SEC-SQL-PRI-001-RC06	f	\N	Self-rolled masking commonly leaks (XXXX1234, partial hashing).	t	f
73	6	\N	4	3	T4.3 etl-stripping	Are ETL pipelines copying PII into staging / warehouse without stripping?	9701	SEC-SQL-PRI-001-RC07	f	\N	Downstream systems often inherit PII unintentionally.	t	f
74	6	\N	4	4	T4.4 legacy-schema	Is schema constrained by legacy app contracts (FKs, indexes on PII)?	9698	SEC-SQL-PRI-001-RC05	f	\N	Legacy constraints often block adding encryption.	t	f
75	6	\N	5	1	T5.1 performance-fears	Was encryption avoided due to performance concerns (proxied by latency)?	9696	SEC-SQL-PRI-001-RC03	f	\N	Often unfounded with modern hardware; surface for policy review.	t	f
76	6	\N	5	2	T5.2 searchability-concerns	Are sensitive columns indexed / used in WHERE clauses?	9694	SEC-SQL-PRI-001-RC02	f	\N	Indexed PII often blocks encryption; consider deterministic encryption.	t	f
77	7	\N	1	1	T1.1 sensitive-cols-in-schema	Does the schema contain any column whose name suggests PII?	12205	SEC-SQL-PRI-001-RC12	f	\N	Foundation: if no sensitive cols anywhere, entire issue ruled out.	t	t
78	7	\N	1	2	T1.2 unsecured-backups	Are backups stored without encryption / on the same volume as data?	6170	SEC-SQL-PRI-001-RC11	f	\N	High-priority signal — encrypted DB still leaks via unsecured backups.	t	f
79	7	\N	2	1	T2.1 actively-queried	Are sensitive columns being actively read by user queries?	12209	SEC-SQL-PRI-001-RC13	f	\N	Live read activity on PII tables.	t	f
80	7	\N	2	2	T2.2 active-tx-pii	Is a currently-running session executing a query that touches a sensitive column?	12738	SEC-SQL-PRI-001-RC14	f	\N	Snapshot of currently-running requests joined to PII tables.	t	f
81	7	\N	2	3	T2.3 cached-plans-and-active-tx	Do cached query plans or active transactions reference sensitive columns?	13067	SEC-SQL-PRI-001-RC15	f	\N	Broader historical view + uncommitted transactions.	t	f
82	7	\N	3	1	T3.1 tde-misunderstanding	Is database-level encryption (TDE) missing/disabled?	6159	SEC-SQL-PRI-001-RC01	f	\N	Common misunderstanding that TDE covers more than at-rest.	t	f
83	7	\N	3	2	T3.2 incorrect-data-types	Are sensitive columns stored as plain string types instead of binary/encrypted?	6162	SEC-SQL-PRI-001-RC04	f	\N	PII stored as plain text defeats later encryption.	t	f
84	7	\N	3	3	T3.3 no-native-masking	Is the engine version too old for native data masking features?	6168	SEC-SQL-PRI-001-RC10	f	\N	DDM / Always-Encrypted require recent versions.	t	f
85	7	\N	4	1	T4.1 key-management	Are encryption keys stored insecurely (in DB, no rotation, weak protection)?	6167	SEC-SQL-PRI-001-RC09	f	\N	Even encrypted PII is exposed if keys are weak.	t	f
86	7	\N	4	2	T4.2 in-house-masking-failed	Are application-masked columns still containing detectable PII patterns?	6164	SEC-SQL-PRI-001-RC06	f	\N	Self-rolled masking commonly leaks (XXXX1234, partial hashing).	t	f
87	7	\N	4	3	T4.3 etl-stripping	Are ETL pipelines copying PII into staging / warehouse without stripping?	6165	SEC-SQL-PRI-001-RC07	f	\N	Downstream systems often inherit PII unintentionally.	t	f
88	7	\N	4	4	T4.4 legacy-schema	Is schema constrained by legacy app contracts (FKs, indexes on PII)?	6163	SEC-SQL-PRI-001-RC05	f	\N	Legacy constraints often block adding encryption.	t	f
89	7	\N	5	1	T5.1 performance-fears	Was encryption avoided due to performance concerns (proxied by latency)?	6161	SEC-SQL-PRI-001-RC03	f	\N	Often unfounded with modern hardware; surface for policy review.	t	f
90	7	\N	5	2	T5.2 searchability-concerns	Are sensitive columns indexed / used in WHERE clauses?	6160	SEC-SQL-PRI-001-RC02	f	\N	Indexed PII often blocks encryption; consider deterministic encryption.	t	f
91	8	\N	1	1	T1.1 sensitive-cols-in-schema	Does the schema contain any column whose name suggests PII?	12206	SEC-SQL-PRI-001-RC12	f	\N	Foundation: if no sensitive cols anywhere, entire issue ruled out.	t	t
92	8	\N	1	2	T1.2 unsecured-backups	Are backups stored without encryption / on the same volume as data?	11689	SEC-SQL-PRI-001-RC11	f	\N	High-priority signal — encrypted DB still leaks via unsecured backups.	t	f
93	8	\N	2	1	T2.1 actively-queried	Are sensitive columns being actively read by user queries?	12210	SEC-SQL-PRI-001-RC13	f	\N	Live read activity on PII tables.	t	f
94	8	\N	2	2	T2.2 active-tx-pii	Is a currently-running session executing a query that touches a sensitive column?	12739	SEC-SQL-PRI-001-RC14	f	\N	Snapshot of currently-running requests joined to PII tables.	t	f
95	8	\N	2	3	T2.3 cached-plans-and-active-tx	Do cached query plans or active transactions reference sensitive columns?	13068	SEC-SQL-PRI-001-RC15	f	\N	Broader historical view + uncommitted transactions.	t	f
96	8	\N	3	1	T3.1 tde-misunderstanding	Is database-level encryption (TDE) missing/disabled?	11680	SEC-SQL-PRI-001-RC01	f	\N	Common misunderstanding that TDE covers more than at-rest.	t	f
97	8	\N	3	2	T3.2 incorrect-data-types	Are sensitive columns stored as plain string types instead of binary/encrypted?	11682	SEC-SQL-PRI-001-RC04	f	\N	PII stored as plain text defeats later encryption.	t	f
98	8	\N	3	3	T3.3 no-native-masking	Is the engine version too old for native data masking features?	11687	SEC-SQL-PRI-001-RC10	f	\N	DDM / Always-Encrypted require recent versions.	t	f
99	8	\N	4	1	T4.1 key-management	Are encryption keys stored insecurely (in DB, no rotation, weak protection)?	11685	SEC-SQL-PRI-001-RC09	f	\N	Even encrypted PII is exposed if keys are weak.	t	f
100	8	\N	4	2	T4.2 in-house-masking-failed	Are application-masked columns still containing detectable PII patterns?	11684	SEC-SQL-PRI-001-RC06	f	\N	Self-rolled masking commonly leaks (XXXX1234, partial hashing).	t	f
101	8	\N	4	3	T4.3 etl-stripping	Are ETL pipelines copying PII into staging / warehouse without stripping?	\N	SEC-SQL-PRI-001-RC07	f	\N	Downstream systems often inherit PII unintentionally.	t	f
102	8	\N	4	4	T4.4 legacy-schema	Is schema constrained by legacy app contracts (FKs, indexes on PII)?	11683	SEC-SQL-PRI-001-RC05	f	\N	Legacy constraints often block adding encryption.	t	f
103	8	\N	5	1	T5.1 performance-fears	Was encryption avoided due to performance concerns (proxied by latency)?	\N	SEC-SQL-PRI-001-RC03	f	\N	Often unfounded with modern hardware; surface for policy review.	t	f
104	8	\N	5	2	T5.2 searchability-concerns	Are sensitive columns indexed / used in WHERE clauses?	11681	SEC-SQL-PRI-001-RC02	f	\N	Indexed PII often blocks encryption; consider deterministic encryption.	t	f
105	9	\N	1	1	T1.1 no-classification	Is the database missing PPL security-level classification metadata?	12957	SEC-SQL-PRI-003-RC01	f	\N	Foundation: without metadata, level-specific controls cannot be assessed.	t	f
106	9	\N	2	1	T2.1 high-criteria-misclassified	Does the database meet High-level criteria (>100k rows in PII tables) but is classified lower?	12961	SEC-SQL-PRI-003-RC02	f	\N	Schema indicators suggest High-level requirements regardless of declared level.	t	f
107	9	\N	2	2	T2.2 external-access-without-high-controls	Is external/remote access enabled without High-level encryption + audit controls?	12965	SEC-SQL-PRI-003-RC03	f	\N	External exposure mandates stricter controls.	t	f
108	10	\N	1	1	T1.1 no-classification	Is the database missing PPL security-level classification metadata?	12958	SEC-SQL-PRI-003-RC01	f	\N	Foundation: without metadata, level-specific controls cannot be assessed.	t	f
109	10	\N	2	1	T2.1 high-criteria-misclassified	Does the database meet High-level criteria (>100k rows in PII tables) but is classified lower?	12962	SEC-SQL-PRI-003-RC02	f	\N	Schema indicators suggest High-level requirements regardless of declared level.	t	f
110	10	\N	2	2	T2.2 external-access-without-high-controls	Is external/remote access enabled without High-level encryption + audit controls?	12966	SEC-SQL-PRI-003-RC03	f	\N	External exposure mandates stricter controls.	t	f
111	11	\N	1	1	T1.1 no-classification	Is the database missing PPL security-level classification metadata?	12959	SEC-SQL-PRI-003-RC01	f	\N	Foundation: without metadata, level-specific controls cannot be assessed.	t	f
112	11	\N	2	1	T2.1 high-criteria-misclassified	Does the database meet High-level criteria (>100k rows in PII tables) but is classified lower?	12963	SEC-SQL-PRI-003-RC02	f	\N	Schema indicators suggest High-level requirements regardless of declared level.	t	f
113	11	\N	2	2	T2.2 external-access-without-high-controls	Is external/remote access enabled without High-level encryption + audit controls?	12967	SEC-SQL-PRI-003-RC03	f	\N	External exposure mandates stricter controls.	t	f
114	12	\N	1	1	T1.1 no-classification	Is the database missing PPL security-level classification metadata?	12960	SEC-SQL-PRI-003-RC01	f	\N	Foundation: without metadata, level-specific controls cannot be assessed.	t	f
115	12	\N	2	1	T2.1 high-criteria-misclassified	Does the database meet High-level criteria (>100k rows in PII tables) but is classified lower?	12964	SEC-SQL-PRI-003-RC02	f	\N	Schema indicators suggest High-level requirements regardless of declared level.	t	f
116	12	\N	2	2	T2.2 external-access-without-high-controls	Is external/remote access enabled without High-level encryption + audit controls?	12968	SEC-SQL-PRI-003-RC03	f	\N	External exposure mandates stricter controls.	t	f
117	13	\N	1	1	T1.1 tde-not-enabled	Is database-level / tablespace encryption disabled?	12969	SEC-SQL-PRI-004-RC01	f	\N	TDE / TDE-equivalent is the highest-impact at-rest control.	t	f
118	13	\N	2	1	T2.1 cols-not-encrypted	Are individual sensitive columns stored without column-level encryption?	12973	SEC-SQL-PRI-004-RC02	f	\N	Defence-in-depth on top of TDE.	t	f
119	13	\N	2	2	T2.2 tls-not-forced	Are connections allowed without TLS / SSL?	12977	SEC-SQL-PRI-004-RC03	f	\N	In-transit encryption complements at-rest.	t	f
120	14	\N	1	1	T1.1 tde-not-enabled	Is database-level / tablespace encryption disabled?	12970	SEC-SQL-PRI-004-RC01	f	\N	TDE / TDE-equivalent is the highest-impact at-rest control.	t	f
121	14	\N	2	1	T2.1 cols-not-encrypted	Are individual sensitive columns stored without column-level encryption?	12974	SEC-SQL-PRI-004-RC02	f	\N	Defence-in-depth on top of TDE.	t	f
122	14	\N	2	2	T2.2 tls-not-forced	Are connections allowed without TLS / SSL?	12978	SEC-SQL-PRI-004-RC03	f	\N	In-transit encryption complements at-rest.	t	f
123	15	\N	1	1	T1.1 tde-not-enabled	Is database-level / tablespace encryption disabled?	12971	SEC-SQL-PRI-004-RC01	f	\N	TDE / TDE-equivalent is the highest-impact at-rest control.	t	f
124	15	\N	2	1	T2.1 cols-not-encrypted	Are individual sensitive columns stored without column-level encryption?	12975	SEC-SQL-PRI-004-RC02	f	\N	Defence-in-depth on top of TDE.	t	f
125	15	\N	2	2	T2.2 tls-not-forced	Are connections allowed without TLS / SSL?	12979	SEC-SQL-PRI-004-RC03	f	\N	In-transit encryption complements at-rest.	t	f
126	16	\N	1	1	T1.1 tde-not-enabled	Is database-level / tablespace encryption disabled?	12972	SEC-SQL-PRI-004-RC01	f	\N	TDE / TDE-equivalent is the highest-impact at-rest control.	t	f
127	16	\N	2	1	T2.1 cols-not-encrypted	Are individual sensitive columns stored without column-level encryption?	12976	SEC-SQL-PRI-004-RC02	f	\N	Defence-in-depth on top of TDE.	t	f
128	16	\N	2	2	T2.2 tls-not-forced	Are connections allowed without TLS / SSL?	12980	SEC-SQL-PRI-004-RC03	f	\N	In-transit encryption complements at-rest.	t	f
129	17	\N	1	1	T1.1 no-audit	Is auditing disabled / not configured at all?	12981	SEC-SQL-PRI-005-RC01	t	\N	Terminating: if no audit at all, RC02/RC03 are trivially true — surface RC01 only.	t	f
130	17	\N	2	1	T2.1 audit-not-covering-pii-select	Does the audit fail to capture SELECT on PII tables?	12985	SEC-SQL-PRI-005-RC02	f	\N	Read access is the most common exposure path.	t	f
131	17	\N	2	2	T2.2 audit-retention-too-short	Is audit log retention shorter than 24 months (PPL Reg §6 minimum)?	12989	SEC-SQL-PRI-005-RC03	f	\N	Retention requirement applies to High-level databases.	t	f
132	18	\N	1	1	T1.1 no-audit	Is auditing disabled / not configured at all?	12982	SEC-SQL-PRI-005-RC01	t	\N	Terminating: if no audit at all, RC02/RC03 are trivially true — surface RC01 only.	t	f
133	18	\N	2	1	T2.1 audit-not-covering-pii-select	Does the audit fail to capture SELECT on PII tables?	12986	SEC-SQL-PRI-005-RC02	f	\N	Read access is the most common exposure path.	t	f
134	18	\N	2	2	T2.2 audit-retention-too-short	Is audit log retention shorter than 24 months (PPL Reg §6 minimum)?	12990	SEC-SQL-PRI-005-RC03	f	\N	Retention requirement applies to High-level databases.	t	f
135	19	\N	1	1	T1.1 no-audit	Is auditing disabled / not configured at all?	12983	SEC-SQL-PRI-005-RC01	t	\N	Terminating: if no audit at all, RC02/RC03 are trivially true — surface RC01 only.	t	f
136	19	\N	2	1	T2.1 audit-not-covering-pii-select	Does the audit fail to capture SELECT on PII tables?	12987	SEC-SQL-PRI-005-RC02	f	\N	Read access is the most common exposure path.	t	f
137	19	\N	2	2	T2.2 audit-retention-too-short	Is audit log retention shorter than 24 months (PPL Reg §6 minimum)?	12991	SEC-SQL-PRI-005-RC03	f	\N	Retention requirement applies to High-level databases.	t	f
138	20	\N	1	1	T1.1 no-audit	Is auditing disabled / not configured at all?	12984	SEC-SQL-PRI-005-RC01	t	\N	Terminating: if no audit at all, RC02/RC03 are trivially true — surface RC01 only.	t	f
139	20	\N	2	1	T2.1 audit-not-covering-pii-select	Does the audit fail to capture SELECT on PII tables?	12988	SEC-SQL-PRI-005-RC02	f	\N	Read access is the most common exposure path.	t	f
140	20	\N	2	2	T2.2 audit-retention-too-short	Is audit log retention shorter than 24 months (PPL Reg §6 minimum)?	12992	SEC-SQL-PRI-005-RC03	f	\N	Retention requirement applies to High-level databases.	t	f
141	21	\N	1	1	T1.1 public-select-on-pii	Does the public/PUBLIC role have SELECT on PII tables?	12993	SEC-SQL-PRI-006-RC01	f	\N	Most direct violation of least-privilege.	t	f
142	21	\N	1	2	T1.2 app-accounts-sysadmin	Do application service accounts hold sysadmin / DBA / superuser?	12997	SEC-SQL-PRI-006-RC02	f	\N	App accounts should never be admins.	t	f
143	21	\N	1	3	T1.3 stale-logins	Do logins inactive >90 days still hold access?	13001	SEC-SQL-PRI-006-RC03	f	\N	Stale accounts are an attack surface.	t	f
144	22	\N	1	1	T1.1 public-select-on-pii	Does the public/PUBLIC role have SELECT on PII tables?	12994	SEC-SQL-PRI-006-RC01	f	\N	Most direct violation of least-privilege.	t	f
145	22	\N	1	2	T1.2 app-accounts-sysadmin	Do application service accounts hold sysadmin / DBA / superuser?	12998	SEC-SQL-PRI-006-RC02	f	\N	App accounts should never be admins.	t	f
146	22	\N	1	3	T1.3 stale-logins	Do logins inactive >90 days still hold access?	13002	SEC-SQL-PRI-006-RC03	f	\N	Stale accounts are an attack surface.	t	f
147	23	\N	1	1	T1.1 public-select-on-pii	Does the public/PUBLIC role have SELECT on PII tables?	12995	SEC-SQL-PRI-006-RC01	f	\N	Most direct violation of least-privilege.	t	f
148	23	\N	1	2	T1.2 app-accounts-sysadmin	Do application service accounts hold sysadmin / DBA / superuser?	12999	SEC-SQL-PRI-006-RC02	f	\N	App accounts should never be admins.	t	f
149	23	\N	1	3	T1.3 stale-logins	Do logins inactive >90 days still hold access?	13003	SEC-SQL-PRI-006-RC03	f	\N	Stale accounts are an attack surface.	t	f
150	24	\N	1	1	T1.1 public-select-on-pii	Does the public/PUBLIC role have SELECT on PII tables?	12996	SEC-SQL-PRI-006-RC01	f	\N	Most direct violation of least-privilege.	t	f
151	24	\N	1	2	T1.2 app-accounts-sysadmin	Do application service accounts hold sysadmin / DBA / superuser?	13000	SEC-SQL-PRI-006-RC02	f	\N	App accounts should never be admins.	t	f
152	24	\N	1	3	T1.3 stale-logins	Do logins inactive >90 days still hold access?	13004	SEC-SQL-PRI-006-RC03	f	\N	Stale accounts are an attack surface.	t	f
153	25	\N	1	1	T1.1 sa-superuser-enabled	Is the built-in SA / SYS / postgres / root account enabled and active?	13013	SEC-SQL-PRI-007-RC03	f	\N	Easy fix; instant signal.	t	f
154	25	\N	1	2	T1.2 generic-logins	Are generic / shared login names (admin, app, svc, dba) in use?	13009	SEC-SQL-PRI-007-RC02	f	\N	Defeats per-user attribution required by Reg §6.	t	f
155	25	\N	1	3	T1.3 sql-logins-no-policy	Are SQL logins without password policy / expiration?	13005	SEC-SQL-PRI-007-RC01	f	\N	Lowest priority but broadest impact.	t	f
156	26	\N	1	1	T1.1 sa-superuser-enabled	Is the built-in SA / SYS / postgres / root account enabled and active?	13014	SEC-SQL-PRI-007-RC03	f	\N	Easy fix; instant signal.	t	f
157	26	\N	1	2	T1.2 generic-logins	Are generic / shared login names (admin, app, svc, dba) in use?	13010	SEC-SQL-PRI-007-RC02	f	\N	Defeats per-user attribution required by Reg §6.	t	f
158	26	\N	1	3	T1.3 sql-logins-no-policy	Are SQL logins without password policy / expiration?	13006	SEC-SQL-PRI-007-RC01	f	\N	Lowest priority but broadest impact.	t	f
159	27	\N	1	1	T1.1 sa-superuser-enabled	Is the built-in SA / SYS / postgres / root account enabled and active?	13015	SEC-SQL-PRI-007-RC03	f	\N	Easy fix; instant signal.	t	f
160	27	\N	1	2	T1.2 generic-logins	Are generic / shared login names (admin, app, svc, dba) in use?	13011	SEC-SQL-PRI-007-RC02	f	\N	Defeats per-user attribution required by Reg §6.	t	f
161	27	\N	1	3	T1.3 sql-logins-no-policy	Are SQL logins without password policy / expiration?	13007	SEC-SQL-PRI-007-RC01	f	\N	Lowest priority but broadest impact.	t	f
162	28	\N	1	1	T1.1 sa-superuser-enabled	Is the built-in SA / SYS / postgres / root account enabled and active?	13016	SEC-SQL-PRI-007-RC03	f	\N	Easy fix; instant signal.	t	f
163	28	\N	1	2	T1.2 generic-logins	Are generic / shared login names (admin, app, svc, dba) in use?	13012	SEC-SQL-PRI-007-RC02	f	\N	Defeats per-user attribution required by Reg §6.	t	f
164	28	\N	1	3	T1.3 sql-logins-no-policy	Are SQL logins without password policy / expiration?	13008	SEC-SQL-PRI-007-RC01	f	\N	Lowest priority but broadest impact.	t	f
165	29	\N	1	1	T1.1 no-recent-backup	Is there no full / differential backup in the last 7 days?	13017	SEC-SQL-PRI-008-RC01	t	\N	Terminating: no backup means RC02/RC03 are moot — surface RC01 first.	t	f
166	29	\N	2	1	T2.1 backups-not-encrypted	Are recent backups stored without encryption?	13021	SEC-SQL-PRI-008-RC02	f	\N	Encrypted DB still leaks via unencrypted backup.	t	f
167	29	\N	2	2	T2.2 backups-on-data-volume	Are backups stored on the same volume as live data files?	13025	SEC-SQL-PRI-008-RC03	f	\N	Defeats the disaster-recovery purpose of backup.	t	f
168	30	\N	1	1	T1.1 no-recent-backup	Is there no full / differential backup in the last 7 days?	13018	SEC-SQL-PRI-008-RC01	t	\N	Terminating: no backup means RC02/RC03 are moot — surface RC01 first.	t	f
169	30	\N	2	1	T2.1 backups-not-encrypted	Are recent backups stored without encryption?	13022	SEC-SQL-PRI-008-RC02	f	\N	Encrypted DB still leaks via unencrypted backup.	t	f
170	30	\N	2	2	T2.2 backups-on-data-volume	Are backups stored on the same volume as live data files?	13026	SEC-SQL-PRI-008-RC03	f	\N	Defeats the disaster-recovery purpose of backup.	t	f
171	31	\N	1	1	T1.1 no-recent-backup	Is there no full / differential backup in the last 7 days?	13019	SEC-SQL-PRI-008-RC01	t	\N	Terminating: no backup means RC02/RC03 are moot — surface RC01 first.	t	f
172	31	\N	2	1	T2.1 backups-not-encrypted	Are recent backups stored without encryption?	13023	SEC-SQL-PRI-008-RC02	f	\N	Encrypted DB still leaks via unencrypted backup.	t	f
173	31	\N	2	2	T2.2 backups-on-data-volume	Are backups stored on the same volume as live data files?	13027	SEC-SQL-PRI-008-RC03	f	\N	Defeats the disaster-recovery purpose of backup.	t	f
174	32	\N	1	1	T1.1 no-recent-backup	Is there no full / differential backup in the last 7 days?	13020	SEC-SQL-PRI-008-RC01	t	\N	Terminating: no backup means RC02/RC03 are moot — surface RC01 first.	t	f
175	32	\N	2	1	T2.1 backups-not-encrypted	Are recent backups stored without encryption?	13024	SEC-SQL-PRI-008-RC02	f	\N	Encrypted DB still leaks via unencrypted backup.	t	f
176	32	\N	2	2	T2.2 backups-on-data-volume	Are backups stored on the same volume as live data files?	13028	SEC-SQL-PRI-008-RC03	f	\N	Defeats the disaster-recovery purpose of backup.	t	f
177	33	\N	1	1	T1.1 old-pii-records	Do PII tables hold rows older than 7 years?	13029	SEC-SQL-PRI-009-RC01	f	\N	PPL §14: data must be deleted when no longer needed.	t	f
178	33	\N	1	2	T1.2 inactive-subjects	Are there customer/user records inactive >5 years still holding PII?	13033	SEC-SQL-PRI-009-RC02	f	\N	Inactive subjects should be archived/anonymised.	t	f
179	33	\N	1	3	T1.3 soft-deleted-not-purged	Are soft-deleted rows still present after >2 years?	13037	SEC-SQL-PRI-009-RC03	f	\N	Soft delete is not deletion under PPL §14.	t	f
180	34	\N	1	1	T1.1 old-pii-records	Do PII tables hold rows older than 7 years?	13030	SEC-SQL-PRI-009-RC01	f	\N	PPL §14: data must be deleted when no longer needed.	t	f
181	34	\N	1	2	T1.2 inactive-subjects	Are there customer/user records inactive >5 years still holding PII?	13034	SEC-SQL-PRI-009-RC02	f	\N	Inactive subjects should be archived/anonymised.	t	f
182	34	\N	1	3	T1.3 soft-deleted-not-purged	Are soft-deleted rows still present after >2 years?	13038	SEC-SQL-PRI-009-RC03	f	\N	Soft delete is not deletion under PPL §14.	t	f
183	35	\N	1	1	T1.1 old-pii-records	Do PII tables hold rows older than 7 years?	13031	SEC-SQL-PRI-009-RC01	f	\N	PPL §14: data must be deleted when no longer needed.	t	f
184	35	\N	1	2	T1.2 inactive-subjects	Are there customer/user records inactive >5 years still holding PII?	13035	SEC-SQL-PRI-009-RC02	f	\N	Inactive subjects should be archived/anonymised.	t	f
185	35	\N	1	3	T1.3 soft-deleted-not-purged	Are soft-deleted rows still present after >2 years?	13039	SEC-SQL-PRI-009-RC03	f	\N	Soft delete is not deletion under PPL §14.	t	f
186	36	\N	1	1	T1.1 old-pii-records	Do PII tables hold rows older than 7 years?	13032	SEC-SQL-PRI-009-RC01	f	\N	PPL §14: data must be deleted when no longer needed.	t	f
187	36	\N	1	2	T1.2 inactive-subjects	Are there customer/user records inactive >5 years still holding PII?	13036	SEC-SQL-PRI-009-RC02	f	\N	Inactive subjects should be archived/anonymised.	t	f
188	36	\N	1	3	T1.3 soft-deleted-not-purged	Are soft-deleted rows still present after >2 years?	13040	SEC-SQL-PRI-009-RC03	f	\N	Soft delete is not deletion under PPL §14.	t	f
189	37	\N	1	1	T1.1 privilege-escalation	Has a recent privilege-escalation event been detected?	13045	SEC-SQL-PRI-010-RC02	f	\N	Highest-severity incident type.	t	f
190	37	\N	1	2	T1.2 failed-login-spike	Are there >20 failed logins in the last hour from a single source?	13041	SEC-SQL-PRI-010-RC01	f	\N	Possible credential-stuffing / brute force.	t	f
191	37	\N	1	3	T1.3 after-hours-access	Are sensitive-data sessions running outside 06:00–22:00?	13049	SEC-SQL-PRI-010-RC03	f	\N	Possible exfiltration / compromised account.	t	f
192	38	\N	1	1	T1.1 privilege-escalation	Has a recent privilege-escalation event been detected?	13046	SEC-SQL-PRI-010-RC02	f	\N	Highest-severity incident type.	t	f
193	38	\N	1	2	T1.2 failed-login-spike	Are there >20 failed logins in the last hour from a single source?	13042	SEC-SQL-PRI-010-RC01	f	\N	Possible credential-stuffing / brute force.	t	f
194	38	\N	1	3	T1.3 after-hours-access	Are sensitive-data sessions running outside 06:00–22:00?	13050	SEC-SQL-PRI-010-RC03	f	\N	Possible exfiltration / compromised account.	t	f
195	39	\N	1	1	T1.1 privilege-escalation	Has a recent privilege-escalation event been detected?	13047	SEC-SQL-PRI-010-RC02	f	\N	Highest-severity incident type.	t	f
196	39	\N	1	2	T1.2 failed-login-spike	Are there >20 failed logins in the last hour from a single source?	13043	SEC-SQL-PRI-010-RC01	f	\N	Possible credential-stuffing / brute force.	t	f
197	39	\N	1	3	T1.3 after-hours-access	Are sensitive-data sessions running outside 06:00–22:00?	13051	SEC-SQL-PRI-010-RC03	f	\N	Possible exfiltration / compromised account.	t	f
198	40	\N	1	1	T1.1 privilege-escalation	Has a recent privilege-escalation event been detected?	13048	SEC-SQL-PRI-010-RC02	f	\N	Highest-severity incident type.	t	f
199	40	\N	1	2	T1.2 failed-login-spike	Are there >20 failed logins in the last hour from a single source?	13044	SEC-SQL-PRI-010-RC01	f	\N	Possible credential-stuffing / brute force.	t	f
200	40	\N	1	3	T1.3 after-hours-access	Are sensitive-data sessions running outside 06:00–22:00?	13052	SEC-SQL-PRI-010-RC03	f	\N	Possible exfiltration / compromised account.	t	f
201	41	\N	1	1	T1.1 teudat-zehut	Are Teudat-Zehut / national-ID columns stored unencrypted?	13053	SEC-SQL-PRI-011-RC01	f	\N	PPL §7 — Israeli national ID is sensitive.	t	f
202	41	\N	1	2	T1.2 medical-data	Are medical / health columns present without classification?	13057	SEC-SQL-PRI-011-RC02	f	\N	PPL §7 — health information.	t	f
203	41	\N	1	3	T1.3 religion-political-orientation	Are religion / political-opinion / orientation columns exposed?	13061	SEC-SQL-PRI-011-RC03	f	\N	PPL §7 — opinion / belief data.	t	f
204	42	\N	1	1	T1.1 teudat-zehut	Are Teudat-Zehut / national-ID columns stored unencrypted?	13054	SEC-SQL-PRI-011-RC01	f	\N	PPL §7 — Israeli national ID is sensitive.	t	f
205	42	\N	1	2	T1.2 medical-data	Are medical / health columns present without classification?	13058	SEC-SQL-PRI-011-RC02	f	\N	PPL §7 — health information.	t	f
206	42	\N	1	3	T1.3 religion-political-orientation	Are religion / political-opinion / orientation columns exposed?	13062	SEC-SQL-PRI-011-RC03	f	\N	PPL §7 — opinion / belief data.	t	f
207	43	\N	1	1	T1.1 teudat-zehut	Are Teudat-Zehut / national-ID columns stored unencrypted?	13055	SEC-SQL-PRI-011-RC01	f	\N	PPL §7 — Israeli national ID is sensitive.	t	f
208	43	\N	1	2	T1.2 medical-data	Are medical / health columns present without classification?	13059	SEC-SQL-PRI-011-RC02	f	\N	PPL §7 — health information.	t	f
209	43	\N	1	3	T1.3 religion-political-orientation	Are religion / political-opinion / orientation columns exposed?	13063	SEC-SQL-PRI-011-RC03	f	\N	PPL §7 — opinion / belief data.	t	f
210	44	\N	1	1	T1.1 teudat-zehut	Are Teudat-Zehut / national-ID columns stored unencrypted?	13056	SEC-SQL-PRI-011-RC01	f	\N	PPL §7 — Israeli national ID is sensitive.	t	f
211	44	\N	1	2	T1.2 medical-data	Are medical / health columns present without classification?	13060	SEC-SQL-PRI-011-RC02	f	\N	PPL §7 — health information.	t	f
212	44	\N	1	3	T1.3 religion-political-orientation	Are religion / political-opinion / orientation columns exposed?	13064	SEC-SQL-PRI-011-RC03	f	\N	PPL §7 — opinion / belief data.	t	f
\.
INSERT INTO rootcause.issue_decision_tree_nodes (id, tree_id, parent_node_id, tier, sequence, gate_label, gate_question, gate_detection_step_id, on_match_rc_id, on_match_terminate, on_match_drill_rc_ids, notes, is_active, on_no_match_terminate)
SELECT id, tree_id, parent_node_id, tier, sequence, gate_label, gate_question, gate_detection_step_id, on_match_rc_id, on_match_terminate, on_match_drill_rc_ids, notes, is_active, on_no_match_terminate FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM rootcause.issue_decision_tree_nodes);
DROP TABLE _stg_load;

SELECT setval('rootcause.issue_decision_tree_nodes_id_seq', GREATEST((SELECT COALESCE(max(id),0) FROM rootcause.issue_decision_tree_nodes),1), (SELECT count(*) FROM rootcause.issue_decision_tree_nodes) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'rootcause' AND c.relname = 'issue_decision_tree_nodes'
          AND con.conname = 'issue_decision_tree_nodes_pkey') THEN
        ALTER TABLE ONLY rootcause.issue_decision_tree_nodes
    ADD CONSTRAINT issue_decision_tree_nodes_pkey PRIMARY KEY (id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_idtn_parent ON rootcause.issue_decision_tree_nodes USING btree (parent_node_id);
CREATE INDEX IF NOT EXISTS idx_idtn_tree_tier_seq ON rootcause.issue_decision_tree_nodes USING btree (tree_id, tier, sequence);
