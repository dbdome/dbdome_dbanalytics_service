-- Idempotent install for config.alerts
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.alerts_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.alerts (
    row_id integer NOT NULL,
    alert_name text NOT NULL,
    alert_query text NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE config.alerts ALTER COLUMN row_id SET DEFAULT nextval('config.alerts_row_id_seq'::regclass);
ALTER SEQUENCE config.alerts_row_id_seq OWNED BY config.alerts.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE config.alerts);
COPY _stg_load (row_id, alert_name, alert_query, entry_date) FROM stdin;
1	disk space	SELECT  \n(( select value from config.global_params where key = 'disk_size')::int   - \nsum(pg_tablespace_size(spcname))/(1024*1024) )  / ( select value from config.global_params where key = 'disk_size')::int * 100     FROM pg_tablespace;	2026-01-03 20:15:28.112273
2	String concatenation for query building	 	2026-01-13 00:54:44.219287
3	Inadequate input validation and sanitization	 	2026-01-13 00:54:44.219287
4	Lack of awareness and training	 	2026-01-13 00:54:44.219287
5	Legacy code and technical debt	 	2026-01-13 00:54:44.219287
6	Time pressure and deadline constraints	 	2026-01-13 00:54:44.219287
7	Insufficient security code reviews	 	2026-01-13 00:54:44.219287
8	Mixing static and dynamic SQL constructs	 	2026-01-13 00:54:44.219287
9	Complex business requirements	 	2026-01-13 00:54:44.219287
10	Performance optimization assumptions	 	2026-01-13 00:54:44.219287
11	ORM framework misuse	 	2026-01-13 00:54:44.219287
12	Absence of security testing tools	 	2026-01-13 00:54:44.219287
13	Third-party library dependencies	 	2026-01-13 00:54:44.219287
14	Operator control issues	 	2026-01-13 00:54:44.219287
15	Implicit trust in framework defaults	 	2026-01-13 00:54:44.219287
16	Incomplete parameter binding	 	2026-01-13 00:54:44.219287
17	Legacy system constraints	 	2026-01-13 00:54:44.219287
18	Backward compatibility requirements	 	2026-01-13 00:54:44.219287
19	Microsoft deprecation lag	 	2026-01-13 00:54:44.219287
20	Lack of modern alternatives awareness	 	2026-01-13 00:54:44.219287
21	High barrier to refactoring	 	2026-01-13 00:54:44.219287
22	Operational automation dependencies	 	2026-01-13 00:54:44.219287
23	Insufficient privilege controls	 	2026-01-13 00:54:44.219287
24	Missing monitoring and enforcement	 	2026-01-13 00:54:44.219287
25	Assumption of network isolation	 	2026-01-13 00:54:44.219287
26	Security compliance misalignment	 	2026-01-13 00:54:44.219287
27	Service account privilege excess	 	2026-01-13 00:54:44.219287
28	Third-party application requirements	 	2026-01-13 00:54:44.219287
29	Knowledge loss and staff turnover	 	2026-01-13 00:54:44.219287
30	DLL file vulnerabilities	 	2026-01-13 00:54:44.219287
31	SQL injection chaining	 	2026-01-13 00:54:44.219287
32	Insufficient removal validation	 	2026-01-13 00:54:44.219287
33	Vendor-supplied defaults remain unchanged	SELECT\n    name,\n    'SQL logins that are enabled (potential default targets)' Risk_pattern \nFROM sys.sql_logins\nWHERE is_disabled = 0\nunion all \nSELECT\n    name,\n    'logins NOT enforcing password policy (high risk)'    \nFROM sys.sql_logins\nWHERE is_policy_checked = 0\n   OR is_expiration_checked = 0\nunion all \nSELECT\n    name,\n    'logins with passwords never changed'\nFROM sys.sql_logins\nWHERE create_date = modify_date\n  AND is_disabled = 0\nunion all \nSELECT name , \n'common vendor / default account names'\nFROM sys.sql_logins\nWHERE name IN (\n    'admin',\n    'administrator',\n    'sa',\n    'root',\n    'test',\n    'guest'\n)\nunion all \nSELECT\n    name , \n    'sa login is enabled (major red flag)'\nFROM sys.sql_logins\nWHERE name = 'sa'\nunion all \nSELECT\n    name,\n    'SQL-auth logins (higher risk than Windows auth)'\nFROM sys.sql_logins\nWHERE type_desc = 'SQL_LOGIN';	2026-01-13 01:11:38.36505
34	Rushed deployment without security hardening	SELECT name, 'Detect SQL Server Default Logins (e.g., sa, admin)' Risk_Pattern\nFROM sys.sql_logins\nWHERE name IN ('sa', 'admin', 'root', 'guest', 'test')\nunion all \nSELECT name, 'Logins with Weak or Default Password Policies'\nFROM sys.sql_logins\nWHERE is_policy_checked = 0 OR is_expiration_checked = 0\nunion all \nSELECT name, 'sa Login is Enabled'\nFROM sys.sql_logins\nWHERE name = 'sa'\nunion all \nSELECT SERVERPROPERTY('IsIntegratedSecurityOnly') AS IsWindowsAuthenticationOnly  ,  'SQL Server Authentication Mode'\nunion all \nSELECT name, 'Unchanged sa Password'\nFROM sys.sql_logins\nWHERE name = 'sa'\nunion all \nSELECT name, 'Default Database (master) is In Use for Non-System Users'\nFROM sys.sql_logins\nWHERE default_database_name = 'master'\nunion all\nSELECT \n    dp.name AS principal_name  , 'Missing or Default Permissions on Critical Databases'\nFROM sys.database_permissions p\nJOIN sys.objects o ON p.major_id = o.object_id\nJOIN sys.database_principals dp ON p.grantee_principal_id = dp.principal_id\nWHERE o.name IN ('master', 'msdb')	2026-01-13 01:11:38.36505
35	Lack of post-installation checklist	SELECT\n    name,'built-in sa login is enabled (high-risk)' risk_pattern\nFROM sys.sql_logins\nWHERE name NOT LIKE '##%'\nunion all \nSELECT\n    name , \n    'SQL logins enforce password policy'\nFROM sys.server_principals\nWHERE type_desc = 'SQL_LOGIN'\n  AND name IN ('sa', 'admin', 'test', 'user', 'sqladmin')\nunion all \nSELECT\n    name,\n'well-known default or vendor logins'\nFROM sys.server_principals\nWHERE type_desc = 'SQL_LOGIN'\n  AND name IN ('sa', 'admin', 'test', 'user', 'sqladmin')\nunion all \nSELECT\n    name,\n    'SQL logins created immediately after installation'\nFROM sys.sql_logins\nunion all \nSELECT\n    sp.name , \n    'SQL logins with sysadmin privileges'\nFROM sys.server_principals sp\nJOIN sys.server_role_members srm\n    ON sp.principal_id = srm.member_principal_id\nJOIN sys.server_principals sr\n    ON srm.role_principal_id = sr.principal_id\nWHERE sr.name = 'sysadmin'\n	2026-01-13 01:11:38.36505
36	Missing automated enforcement	 	2026-01-13 01:11:38.36505
37	Poor documentation handoff	 	2026-01-13 01:11:38.36505
38	Test/development credentials promoted to production	 	2026-01-13 01:11:38.36505
39	Multiple administrators with unclear ownership	 	2026-01-13 01:11:38.36505
40	Legacy systems never updated	 	2026-01-13 01:11:38.36505
41	Vendor trust assumption	 	2026-01-13 01:11:38.36505
42	No security scanning or compliance checks	 	2026-01-13 01:11:38.36505
43	Complex multi-database environments	 	2026-01-13 01:11:38.36505
44	Inadequate handover during staff transitions	 	2026-01-13 01:11:38.36505
45	Containerized deployments with hardcoded defaults	 	2026-01-13 01:11:38.36505
46	Compliance checkbox mentality	 	2026-01-13 01:11:38.36505
47	Password complexity rules never configured	 	2026-01-13 01:11:38.36505
48	Default policy settings too permissive	 	2026-01-13 01:11:38.36505
49	No technical enforcement mechanism enabled	 	2026-01-13 01:11:38.36505
50	Legacy compatibility concerns	 	2026-01-13 01:11:38.36505
51	User convenience prioritized over security	 	2026-01-13 01:11:38.36505
52	Lack of integration with enterprise password policy	 	2026-01-13 01:11:38.36505
53	Missing password expiration/rotation requirements	 	2026-01-13 01:11:38.36505
54	No password history enforcement	 	2026-01-13 01:11:38.36505
55	Dictionary word acceptance	 	2026-01-13 01:11:38.36505
56	Inadequate administrator training	 	2026-01-13 01:11:38.36505
57	Testing credentials persist into production	 	2026-01-13 01:11:38.36505
58	No integration with password strength meters	 	2026-01-13 01:11:38.36505
59	Password policies not documented or communicated	 	2026-01-13 01:11:38.36505
60	Conflicting policies across authentication methods	 	2026-01-13 01:11:38.36505
61	API/service account exemptions	 	2026-01-13 01:11:38.36505
62	Default MongoDB installation without authentication	 	2026-01-13 01:11:38.36505
63	Security not enabled during initial configuration	 	2026-01-13 01:11:38.36505
64	Development convenience prioritized	 	2026-01-13 01:11:38.36505
65	Bind to 0.0.0.0 instead of localhost	 	2026-01-13 01:11:38.36505
66	Firewall relied upon as sole security control	 	2026-01-13 01:11:38.36505
67	Legacy deployment migrations	 	2026-01-13 01:11:38.36505
68	Incomplete security hardening guides	 	2026-01-13 01:11:38.36505
69	Testing/staging credentials not set for production	 	2026-01-13 01:11:38.36505
70	Container orchestration misconfigurations	 	2026-01-13 01:11:38.36505
71	"Internal network only" false security	 	2026-01-13 01:11:38.36505
72	Configuration management errors	 	2026-01-13 01:11:38.36505
73	Missing mandatory authentication enforcement	 	2026-01-13 01:11:38.36505
74	Lack of security scanning in CI/CD	 	2026-01-13 01:11:38.36505
75	Access control complexity avoidance	 	2026-01-13 01:11:38.36505
76	Principle of Least Privilege Not Applied	 	2026-01-13 01:11:38.36505
77	Lack of Access Review Process	 	2026-01-13 01:11:38.36505
78	Role-Level Over-Provisioning Instead of User-Level	 	2026-01-13 01:11:38.36505
79	Over-Privileged Service Accounts	 	2026-01-13 01:11:38.36505
80	Insufficient Understanding of Role Semantics	 	2026-01-13 01:11:38.36505
81	Migration Shortcuts and Temporary Solutions Becoming Permanent	 	2026-01-13 01:11:38.36505
82	Privilege Creep from Role Inheritance	 	2026-01-13 01:11:38.36505
83	Multiple Role Assignment	 	2026-01-13 01:11:38.36505
84	Custom Roles Not Properly Scoped	 	2026-01-13 01:11:38.36505
85	Lack of Separation of Duties (SoD) Enforcement	 	2026-01-13 01:11:38.36505
86	Insufficient Documentation of Permission Purpose	 	2026-01-13 01:11:38.36505
87	No Automated Privilege Analysis	 	2026-01-13 01:11:38.36505
88	Complexity of Nested Role Hierarchies	 	2026-01-13 01:11:38.36505
89	Legacy System Integration Requiring Broad Access	 	2026-01-13 01:11:38.36505
90	RBAC Not Enabled by Default	 	2026-01-13 01:11:38.36505
91	Authentication Disabled Entirely	 	2026-01-13 01:11:38.36505
92	Flat User Model Without Roles	 	2026-01-13 01:11:38.36505
93	All Users in Admin/Member Category	 	2026-01-13 01:11:38.36505
94	Documentation Gaps on RBAC Setup	 	2026-01-13 01:11:38.36505
95	Legacy Authentication-Only Design	 	2026-01-13 01:11:38.36505
96	Simple Credentials in Development Carrying to Production	 	2026-01-13 01:11:38.36505
97	Separation of Concerns Not Implemented	 	2026-01-13 01:11:38.36505
98	Misconfiguration During Initial Setup	 	2026-01-13 01:11:38.36505
99	Missing Formal Access Control Policy	 	2026-01-13 01:11:38.36505
100	Over-Simplification of Permission Model	 	2026-01-13 01:11:38.36505
101	No Role Definition Process	 	2026-01-13 01:11:38.36505
102	Insufficient IAM/RBAC Tooling	 	2026-01-13 01:11:38.36505
103	Multi-Tenancy Without Role Isolation	 	2026-01-13 01:11:38.36505
104	Insufficient Granularity Understanding	 	2026-01-13 01:11:38.36505
105	Insufficient Granularity Understanding	 	2026-01-13 01:11:38.36505
106	Default to Highest-Available Granularity	 	2026-01-13 01:11:38.36505
107	Default to Highest-Available Granularity	 	2026-01-13 01:11:38.36505
108	Tooling Limitations or Unfamiliarity	 	2026-01-13 01:11:38.36505
109	Tooling Limitations or Unfamiliarity	 	2026-01-13 01:11:38.36505
110	Role Incompatibility with Collection-Level Access	 	2026-01-13 01:11:38.36505
111	Role Incompatibility with Collection-Level Access	 	2026-01-13 01:11:38.36505
112	Database Schema Design Not Considering Access Control	 	2026-01-13 01:11:38.36505
113	Database Schema Design Not Considering Access Control	 	2026-01-13 01:11:38.36505
114	Multi-Application Sharing Single Database	 	2026-01-13 01:11:38.36505
115	Multi-Application Sharing Single Database	 	2026-01-13 01:11:38.36505
116	Legacy Database Structure	 	2026-01-13 01:11:38.36505
117	Legacy Database Structure	 	2026-01-13 01:11:38.36505
118	Performance Assumptions	 	2026-01-13 01:11:38.36505
119	Performance Assumptions	 	2026-01-13 01:11:38.36505
120	Over-Privileged Platform Teams	 	2026-01-13 01:11:38.36505
121	Over-Privileged Platform Teams	 	2026-01-13 01:11:38.36505
122	Lack of Access Control Planning	 	2026-01-13 01:11:38.36505
123	Lack of Access Control Planning	 	2026-01-13 01:11:38.36505
124	Inadequate Role Testing	 	2026-01-13 01:11:38.36505
125	Inadequate Role Testing	 	2026-01-13 01:11:38.36505
126	Evolution of Permission Requirements	 	2026-01-13 01:11:38.36505
127	Evolution of Permission Requirements	 	2026-01-13 01:11:38.36505
128	Scope Creep in Role Definitions	 	2026-01-13 01:11:38.36505
129	Scope Creep in Role Definitions	 	2026-01-13 01:11:38.36505
130	Missing Inventory of Data Sensitivity	 	2026-01-13 01:11:38.36505
131	Missing Inventory of Data Sensitivity	 	2026-01-13 01:11:38.36505
132	Shared Collections for Multiple Purposes	 	2026-01-13 01:11:38.36505
133	Shared Collections for Multiple Purposes	 	2026-01-13 01:11:38.36505
134	Installation defaults not changed	 	2026-01-13 01:11:38.36505
135	Installation mode misalignment	 	2026-01-13 01:11:38.36505
136	Database not in protected network	 	2026-01-13 01:11:38.36505
137	Lack of post-deployment hardening checklist	 	2026-01-13 01:11:38.36505
138	Knowledge gap on account purposes	 	2026-01-13 01:11:38.36505
139	Incomplete migration procedures	 	2026-01-13 01:11:38.36505
140	Recovery procedure reliance	 	2026-01-13 01:11:38.36505
141	Multi-vendor environment complexity	 	2026-01-13 01:11:38.36505
142	No integration with identity provisioning	 	2026-01-13 01:11:38.36505
143	Account privilege escalation over time	 	2026-01-13 01:11:38.36505
144	Inadequate change control	 	2026-01-13 01:11:38.36505
145	Assumption of "unused" protection	 	2026-01-13 01:11:38.36505
146	Initialization flag usage	 	2026-01-13 01:11:38.36505
147	SQL Server Windows Auth mode conversion	 	2026-01-13 01:11:38.36505
148	Installation interruption	 	2026-01-13 01:11:38.36505
149	Test account forgotten in production	 	2026-01-13 01:11:38.36505
150	Password never set in configuration	 	2026-01-13 01:11:38.36505
151	Identity provisioning tool failure	 	2026-01-13 01:11:38.36505
152	Configuration file permission bypass	 	2026-01-13 01:11:38.36505
153	SQL Server's legacy behavior	 	2026-01-13 01:11:38.36505
154	Application provisioning defaults	 	2026-01-13 01:11:38.36505
155	LDAP/directory integration incomplete	 	2026-01-13 01:11:38.36505
156	Batch user creation scripts	 	2026-01-13 01:11:38.36505
157	No pre-deployment security scanning	 	2026-01-13 01:11:38.36505
158	Default configuration never modified	 	2026-01-13 01:11:38.36505
159	Complexity enforcement disabled intentionally	 	2026-01-13 01:11:38.36505
160	Legacy system requirements	 	2026-01-13 01:11:38.36505
161	Regulatory compliance misinterpretation	 	2026-01-13 01:11:38.36505
162	Complexity vs. length tradeoff avoided	 	2026-01-13 01:11:38.36505
163	Performance concerns	 	2026-01-13 01:11:38.36505
164	User friction avoidance	 	2026-01-13 01:11:38.36505
165	Development environment settings bleeding to production	 	2026-01-13 01:11:38.36505
166	No centralized policy definition	 	2026-01-13 01:11:38.36505
167	Password manager unavailability	 	2026-01-13 01:11:38.36505
168	Lack of monitoring tools	 	2026-01-13 01:11:38.36505
169	Policy documentation missing	 	2026-01-13 01:11:38.36505
170	Account creation automation without validation	 	2026-01-13 01:11:38.36505
171	PostgreSQL ident authentication default	 	2026-01-13 01:11:38.36505
172	Oracle REMOTE_OS_ROLES enabled	 	2026-01-13 01:11:38.36505
173	OS service account access	 	2026-01-13 01:11:38.36505
174	Windows domain trust configuration	 	2026-01-13 01:11:38.36505
175	PAM authentication delegation	 	2026-01-13 01:11:38.36505
176	Kerberos/SSPI authentication without encryption	 	2026-01-13 01:11:38.36505
177	Cross-system domain trusts	 	2026-01-13 01:11:38.36505
178	No validation of OS identity	 	2026-01-13 01:11:38.36505
179	Legacy Unix ident server	 	2026-01-13 01:11:38.36505
180	Assume-inside-firewall security model	 	2026-01-13 01:11:38.36505
181	LDAP with weak connection security	 	2026-01-13 01:11:38.36505
182	No OS authentication logging	 	2026-01-13 01:11:38.36505
183	Lack of Role-Based Access Control (RBAC) implementation	 	2026-01-13 01:11:38.36505
184	Principle of least privilege not enforced	 	2026-01-13 01:11:38.36505
185	Developer environments influence production practices	 	2026-01-13 01:11:38.36505
186	Time pressure and perceived operational convenience	 	2026-01-13 01:11:38.36505
187	Inadequate permission analysis during application deployment	 	2026-01-13 01:11:38.36505
188	Multi-schema and cross-database application requirements	 	2026-01-13 01:11:38.36505
189	Third-party application vendor requirements	 	2026-01-13 01:11:38.36505
190	Absence of periodic access reviews and certification	 	2026-01-13 01:11:38.36505
191	Employee role transitions without privilege adjustment	 	2026-01-13 01:11:38.36505
192	Legacy applications with hardcoded privilege assumptions	 	2026-01-13 01:11:38.36505
193	Knowledge gaps and lack of training	 	2026-01-13 01:11:38.36505
194	Vendor default configurations	 	2026-01-13 01:11:38.36505
195	No centralized identity and access governance	 	2026-01-13 01:11:38.36505
196	Shared service and application accounts	 	2026-01-13 01:11:38.36505
197	Misunderstanding of PUBLIC role scope	 	2026-01-13 01:11:38.36505
198	Quick-fix troubleshooting approach	 	2026-01-13 01:11:38.36505
199	Temporary workarounds becoming permanent	 	2026-01-13 01:11:38.36505
200	Legacy database practices	 	2026-01-13 01:11:38.36505
201	Insufficient permission auditing on PUBLIC	 	2026-01-13 01:11:38.36505
202	Default view permissions in system objects	 	2026-01-13 01:11:38.36505
203	Confusion between schema and database-level PUBLIC	 	2026-01-13 01:11:38.36505
204	Testing/development configuration copied to production	 	2026-01-13 01:11:38.36505
205	Bulk permission scripts without proper restriction	 	2026-01-13 01:11:38.36505
206	Lack of role-based alternative	 	2026-01-13 01:11:38.36505
207	Incompletely implemented permission revocation	 	2026-01-13 01:11:38.36505
208	Tool or vendor recommendations that are unsafe	 	2026-01-13 01:11:38.36505
209	Emergency access during incidents	 	2026-01-13 01:11:38.36505
210	Absence of user lifecycle management automation	 	2026-01-13 01:11:38.36505
211	Manual offboarding processes with gaps	 	2026-01-13 01:11:38.36505
212	Delayed or forgotten deprovisioning	 	2026-01-13 01:11:38.36505
213	Lack of integration between HR systems and database access	 	2026-01-13 01:11:38.36505
214	No reconciliation process between database accounts and authorized users	 	2026-01-13 01:11:38.36505
215	Service and application accounts without ownership tracking	 	2026-01-13 01:11:38.36505
216	Contractor and vendor accounts without explicit end dates	 	2026-01-13 01:11:38.36505
217	Shared database accounts and credentials	 	2026-01-13 01:11:38.36505
218	Cross-database and application account complexity	 	2026-01-13 01:11:38.36505
219	Legacy account creation without documentation	 	2026-01-13 01:11:38.36505
220	Database environment fragmentation	 	2026-01-13 01:11:38.36505
221	Lack of privileged access management (PAM) systems	 	2026-01-13 01:11:38.36505
222	Application default accounts never updated	 	2026-01-13 01:11:38.36505
223	Failed or incomplete migration processes	 	2026-01-13 01:11:38.36505
224	Assumption that low-privilege accounts are harmless	 	2026-01-13 01:11:38.36505
225	Default Namespace Not Specified in Queries	 	2026-01-13 01:11:38.36505
226	Default Namespace Not Specified in Queries	 	2026-01-13 01:11:38.36505
227	Weak Namespace Isolation Logic	 	2026-01-13 01:11:38.36505
228	Weak Namespace Isolation Logic	 	2026-01-13 01:11:38.36505
229	Missing or Disabled Data Plane Authentication	 	2026-01-13 01:11:38.36505
230	Missing or Disabled Data Plane Authentication	 	2026-01-13 01:11:38.36505
231	Implicit Resource Access Without Explicit Grants	 	2026-01-13 01:11:38.36505
232	Implicit Resource Access Without Explicit Grants	 	2026-01-13 01:11:38.36505
233	JWT/Token Claims Unauthenticated Against Resource	 	2026-01-13 01:11:38.36505
234	JWT/Token Claims Unauthenticated Against Resource	 	2026-01-13 01:11:38.36505
235	Multi-Level Isolation Failure (Logical + Physical)	 	2026-01-13 01:11:38.36505
236	Multi-Level Isolation Failure (Logical + Physical)	 	2026-01-13 01:11:38.36505
237	Shared Data Structure with Misconfigured Access Control	 	2026-01-13 01:11:38.36505
238	Shared Data Structure with Misconfigured Access Control	 	2026-01-13 01:11:38.36505
239	API Key Scoped to Project Level Instead of Namespace	 	2026-01-13 01:11:38.36505
240	API Key Scoped to Project Level Instead of Namespace	 	2026-01-13 01:11:38.36505
241	Cross-Tenant Cache Collision	 	2026-01-13 01:11:38.36505
242	Cross-Tenant Cache Collision	 	2026-01-13 01:11:38.36505
243	Metadata-Based Tenant Confusion	 	2026-01-13 01:11:38.36505
244	Metadata-Based Tenant Confusion	 	2026-01-13 01:11:38.36505
245	Unvalidated Tenant Context in Application Middleware	 	2026-01-13 01:11:38.36505
246	Unvalidated Tenant Context in Application Middleware	 	2026-01-13 01:11:38.36505
247	Partition Key Omitted in Query Filters	 	2026-01-13 01:11:38.36505
248	Partition Key Omitted in Query Filters	 	2026-01-13 01:11:38.36505
249	Administrative Override Without Audit Trail	 	2026-01-13 01:11:38.36505
250	Administrative Override Without Audit Trail	 	2026-01-13 01:11:38.36505
251	Race Condition During Namespace Initialization	 	2026-01-13 01:11:38.36505
252	Race Condition During Namespace Initialization	 	2026-01-13 01:11:38.36505
253	Connection Pool Tenant Context Reuse	 	2026-01-13 01:11:38.36505
254	Connection Pool Tenant Context Reuse	 	2026-01-13 01:11:38.36505
255	Principle of Least Privilege Not Applied During Setup	 	2026-01-13 01:11:38.36505
256	Principle of Least Privilege Not Applied During Setup	 	2026-01-13 01:11:38.36505
257	Overly Broad Permission Templates	 	2026-01-13 01:11:38.36505
258	Overly Broad Permission Templates	 	2026-01-13 01:11:38.36505
259	No Automated Permission Audit Process	 	2026-01-13 01:11:38.36505
260	No Automated Permission Audit Process	 	2026-01-13 01:11:38.36505
261	Credentials Reused Across Multiple Services/Environments	 	2026-01-13 01:11:38.36505
262	Credentials Reused Across Multiple Services/Environments	 	2026-01-13 01:11:38.36505
263	Temporary Elevated Permissions Never Revoked	 	2026-01-13 01:11:38.36505
264	Temporary Elevated Permissions Never Revoked	 	2026-01-13 01:11:38.36505
265	Complex Permission UI Causing Misconfiguration	 	2026-01-13 01:11:38.36505
266	Complex Permission UI Causing Misconfiguration	 	2026-01-13 01:11:38.36505
267	Default Permissions in Infrastructure-as-Code Templates	 	2026-01-13 01:11:38.36505
268	Default Permissions in Infrastructure-as-Code Templates	 	2026-01-13 01:11:38.36505
269	No Distinction Between API Key Types	 	2026-01-13 01:11:38.36505
270	No Distinction Between API Key Types	 	2026-01-13 01:11:38.36505
271	Inheritance of Parent Resource Permissions	 	2026-01-13 01:11:38.36505
272	Inheritance of Parent Resource Permissions	 	2026-01-13 01:11:38.36505
273	Service Accounts Granted User-Level Admin Permissions	 	2026-01-13 01:11:38.36505
274	Service Accounts Granted User-Level Admin Permissions	 	2026-01-13 01:11:38.36505
275	API Key Not Scoped to Specific Collections/Indexes	 	2026-01-13 01:11:38.36505
276	API Key Not Scoped to Specific Collections/Indexes	 	2026-01-13 01:11:38.36505
277	Documentation Showing Overly Permissive Examples	 	2026-01-13 01:11:38.36505
278	Documentation Showing Overly Permissive Examples	 	2026-01-13 01:11:38.36505
279	Coarse Permission System Without Granularity	 	2026-01-13 01:11:38.36505
280	Coarse Permission System Without Granularity	 	2026-01-13 01:11:38.36505
281	Permission System Incompatible with Least Privilege	 	2026-01-13 01:11:38.36505
282	Permission System Incompatible with Least Privilege	 	2026-01-13 01:11:38.36505
283	Missing Resource-Level Permission Validation in SDK	 	2026-01-13 01:11:38.36505
284	Missing Resource-Level Permission Validation in SDK	 	2026-01-13 01:11:38.36505
285	Secret Manager Integration Not Enforcing Scope	 	2026-01-13 01:11:38.36505
286	Secret Manager Integration Not Enforcing Scope	 	2026-01-13 01:11:38.36505
287	Hardcoded credentials in source code	 	2026-01-13 01:11:38.36505
288	Hardcoded credentials in source code	 	2026-01-13 01:11:38.36505
289	Credentials in client-side code	 	2026-01-13 01:11:38.36505
290	Credentials in client-side code	 	2026-01-13 01:11:38.36505
291	Accidental commits to version control	 	2026-01-13 01:11:38.36505
292	Accidental commits to version control	 	2026-01-13 01:11:38.36505
293	Credentials in .env files tracked in Git	 	2026-01-13 01:11:38.36505
294	Credentials in .env files tracked in Git	 	2026-01-13 01:11:38.36505
295	API keys logged in application logs	 	2026-01-13 01:11:38.36505
296	API keys logged in application logs	 	2026-01-13 01:11:38.36505
297	Process memory and core dumps	 	2026-01-13 01:11:38.36505
298	Process memory and core dumps	 	2026-01-13 01:11:38.36505
299	Credentials in deployment artifacts	 	2026-01-13 01:11:38.36505
300	Credentials in deployment artifacts	 	2026-01-13 01:11:38.36505
301	Shared credentials across environments	 	2026-01-13 01:11:38.36505
302	Shared credentials across environments	 	2026-01-13 01:11:38.36505
303	API keys in API documentation or Postman collections	 	2026-01-13 01:11:38.36505
304	API keys in API documentation or Postman collections	 	2026-01-13 01:11:38.36505
305	Credentials in error messages and stack traces	 	2026-01-13 01:11:38.36505
306	Credentials in error messages and stack traces	 	2026-01-13 01:11:38.36505
307	Credentials in configuration management systems	 	2026-01-13 01:11:38.36505
308	Credentials in configuration management systems	 	2026-01-13 01:11:38.36505
309	API keys in browser history and Slack messages	 	2026-01-13 01:11:38.36505
310	API keys in browser history and Slack messages	 	2026-01-13 01:11:38.36505
311	Weak API key generation	 	2026-01-13 01:11:38.36505
312	Weak API key generation	 	2026-01-13 01:11:38.36505
313	No credential rotation policy	 	2026-01-13 01:11:38.36505
314	No credential rotation policy	 	2026-01-13 01:11:38.36505
315	Inadequate access controls on key storage	 	2026-01-13 01:11:38.36505
316	Inadequate access controls on key storage	 	2026-01-13 01:11:38.36505
317	Credentials in application backups and snapshots	 	2026-01-13 01:11:38.36505
318	Credentials in application backups and snapshots	 	2026-01-13 01:11:38.36505
319	Authentication disabled by default	 	2026-01-13 01:11:38.36505
320	Hardcoded default admin accounts	 	2026-01-13 01:11:38.36505
321	Default credentials in documentation	 	2026-01-13 01:11:38.36505
322	No password set for privileged accounts	 	2026-01-13 01:11:38.36505
323	Trust authentication method enabled	 	2026-01-13 01:11:38.36505
324	Peer/ident authentication without password fallback	 	2026-01-13 01:11:38.36505
325	Unauthenticated anonymous access	 	2026-01-13 01:11:38.36505
326	Service accounts without credentials	 	2026-01-13 01:11:38.36505
327	Development credentials in production	 	2026-01-13 01:11:38.36505
328	Redis AUTH requirement disabled	 	2026-01-13 01:11:38.36505
329	Milvus authentication flag not enabled	 	2026-01-13 01:11:38.36505
330	Chroma authentication provider not configured	 	2026-01-13 01:11:38.36505
331	Qdrant running without API key	 	2026-01-13 01:11:38.36505
332	Multi-tenant isolation not configured	 	2026-01-13 01:11:38.36505
333	Default certificate configurations	 	2026-01-13 01:11:38.36505
334	Minimal access controls on first deployment	 	2026-01-13 01:11:38.36505
335	Initial setup wizard completed with defaults	 	2026-01-13 01:11:38.36505
336	open alerts	select count(*) from monitoring.alerts_open where state = 'open'	2026-02-14 21:19:09.387766
\.
INSERT INTO config.alerts (row_id, alert_name, alert_query, entry_date)
SELECT row_id, alert_name, alert_query, entry_date FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM config.alerts);
DROP TABLE _stg_load;

SELECT setval('config.alerts_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM config.alerts),1), (SELECT count(*) FROM config.alerts) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'alerts'
          AND con.conname = 'alerts_pkey') THEN
        ALTER TABLE ONLY config.alerts
    ADD CONSTRAINT alerts_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
