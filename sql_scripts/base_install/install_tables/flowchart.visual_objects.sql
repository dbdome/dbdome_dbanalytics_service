-- Idempotent install for flowchart.visual_objects
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS flowchart;

CREATE SEQUENCE IF NOT EXISTS flowchart.visual_objects_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS flowchart.visual_objects (
    row_id integer NOT NULL,
    source_object text NOT NULL,
    target_object text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL,
    mainstat_query text,
    mainstat_threshold_id integer,
    alert_mail boolean DEFAULT false,
    alert_report boolean DEFAULT false,
    alert_siem boolean DEFAULT false,
    metric_name text,
    diagnosys boolean
);

ALTER TABLE flowchart.visual_objects ALTER COLUMN row_id SET DEFAULT nextval('flowchart.visual_objects_row_id_seq'::regclass);
ALTER SEQUENCE flowchart.visual_objects_row_id_seq OWNED BY flowchart.visual_objects.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE flowchart.visual_objects);
COPY _stg_load (row_id, source_object, target_object, is_active, entry_date, mainstat_query, mainstat_threshold_id, alert_mail, alert_report, alert_siem, metric_name, diagnosys) FROM stdin;
1	Open alerts	Access Control	t	2026-01-23 04:56:05.859038	\N	\N	f	f	f	\N	\N
2	Open alerts	Data Protection	t	2026-01-23 04:56:32.002238	\N	\N	f	f	f	\N	\N
3	Data Protection	Injection Prevention	t	2026-01-23 04:57:20.602097	\N	\N	f	f	f	\N	\N
4	Injection Prevention	SQL Injection	t	2026-01-23 04:57:56.410186	\N	\N	f	f	f	\N	\N
5	Data Protection	Network Security	t	2026-01-23 04:58:34.334528	\N	\N	f	f	f	\N	\N
6	Open alerts	Compliance	t	2026-01-23 05:18:26.952386	\N	\N	f	f	f	\N	\N
8	Compliance	Patch Management	t	2026-01-23 05:31:06.39649	\N	\N	f	f	f	\N	\N
9	Access Control	Authorization & Roles	t	2026-01-23 05:33:18.148388	\N	\N	f	f	f	\N	\N
10	Access Control	Authentication	t	2026-01-23 05:33:42.885281	\N	\N	f	f	f	\N	\N
11	Data Protection	Data Masking	t	2026-01-23 05:44:04.287062	\N	\N	f	f	f	\N	\N
12	Data Protection	Command Security	t	2026-01-23 05:44:53.514444	\N	\N	f	f	f	\N	\N
14	Command Security	Configuration Hardening	t	2026-01-23 05:45:39.955937	\N	\N	f	f	f	\N	\N
15	Command Security	Sql injection	t	2026-01-23 05:45:46.440982	\N	\N	f	f	f	\N	\N
16	Compliance	Regulatory Requirements	t	2026-01-23 05:46:28.583933	\N	\N	f	f	f	\N	\N
17	Sql injection	SQL Injection detected Classic Authentication Bypass	t	2026-01-23 06:13:18.92515	\N	\N	f	f	f	\N	\N
18	Sql injection	Comment Injection (MSSQL-specific)	t	2026-01-23 06:16:41.248464	\N	\N	f	f	f	\N	\N
19	Sql injection	UNION-Based Injection (Data Extraction)	t	2026-01-23 06:17:48.072182	\N	\N	f	f	f	\N	\N
20	Sql injection	MSSQL System Information Leakage	t	2026-01-23 06:19:14.339835	\N	\N	f	f	f	\N	\N
21	Sql injection	Error-Based Injection (MSSQL-style)	t	2026-01-23 06:20:25.469615	\N	\N	f	f	f	\N	\N
22	Sql injection	Boolean-Based Blind Injection	t	2026-01-23 06:21:11.855132	\N	\N	f	f	f	\N	\N
23	Sql injection	Stacked Queries (Very MSSQL-Specific)	t	2026-01-23 07:00:55.888437	\N	\N	f	f	f	\N	\N
24	Sql injection	xp_cmdshell & OS Command Injection	t	2026-01-23 07:01:23.444974	\N	\N	f	f	f	\N	\N
25	Sql injection	Metadata Enumeration (MSSQL Catalogs)	t	2026-01-23 07:01:51.683561	\N	\N	f	f	f	\N	\N
26	Sql injection	Overly broad delegation of grant rights	t	2026-01-23 07:02:29.869305	\N	\N	f	f	f	\N	\N
27	Sql injection	Hex / Char-Based Evasion	t	2026-01-23 07:03:20.078013	\N	\N	f	f	f	\N	\N
28	Sql injection	Typical WAF / IDS Detection Regex (High-Value)	t	2026-01-23 07:03:47.355959	\N	\N	f	f	f	\N	\N
29	Authentication	Default Admin Accounts Enabled	t	2026-03-04 21:57:41.334476	\N	\N	f	f	f	\N	\N
31	Authentication	Empty/Blank Passwords Allowed	t	2026-03-04 21:59:28.365903	\N	\N	f	f	f	\N	\N
33	Authentication	Weak Password Policy	t	2026-03-04 22:01:15.476988	\N	\N	f	f	f	\N	\N
34	Authentication	Remote OS Authentication Enabled	t	2026-03-04 22:01:15.476988	\N	\N	f	f	f	\N	\N
36	Authentication	Dormant/Unused Accounts	t	2026-03-04 22:01:15.476988	\N	\N	f	f	f	\N	\N
37	Authentication	Trust Authentication Enabled	t	2026-03-04 22:01:15.476988	\N	\N	f	f	f	\N	\N
38	Authentication	Excessive Administrative Privileges	t	2026-03-04 22:01:15.476988	\N	\N	f	f	f	\N	\N
39	Authentication	PUBLIC Role Excessive Access	t	2026-03-04 22:01:15.476988	\N	\N	f	f	f	\N	\N
40	Authentication	Orphaned User Accounts	t	2026-03-04 22:01:15.476988	\N	\N	f	f	f	\N	\N
41	Authentication	File System Access Privilege	t	2026-03-04 22:01:15.476988	\N	\N	f	f	f	\N	\N
42	Authentication	Cross-Database Ownership Chaining	t	2026-03-04 22:01:15.476988	\N	\N	f	f	f	\N	\N
43	Authentication	Grant Option Abuse	t	2026-03-04 22:01:15.476988	\N	\N	f	f	f	\N	\N
44	Authentication	Data-in-Transit Unencrypted	t	2026-03-04 22:01:15.476988	\N	\N	f	f	f	\N	\N
45	Authentication	Obsolete TLS Versions	t	2026-03-04 22:01:15.476988	\N	\N	f	f	f	\N	\N
46	Access Control	Inadequate Log Retention	t	2026-03-05 08:21:11.778667	\N	\N	f	f	f	\N	\N
47	Access Control	Audit Trail Modification Risk	t	2026-03-05 08:21:11.778667	\N	\N	f	f	f	\N	\N
48	Access Control	Missing Login Failure Logs	t	2026-03-05 08:21:11.778667	\N	\N	f	f	f	\N	\N
49	Access Control	DDL Logging Disabled	t	2026-03-05 08:21:11.778667	\N	\N	f	f	f	\N	\N
50	Access Control	Excessive Administrative Privileges	t	2026-03-05 08:21:11.778667	\N	\N	f	f	f	\N	\N
51	Access Control	PUBLIC Role Excessive Access	t	2026-03-05 08:21:11.778667	\N	\N	f	f	f	\N	\N
52	Access Control	Orphaned User Accounts	t	2026-03-05 08:21:11.778667	\N	\N	f	f	f	\N	\N
53	Access Control	File System Access Privilege	t	2026-03-05 08:21:11.778667	\N	\N	f	f	f	\N	\N
54	Access Control	Cross-Database Ownership Chaining	t	2026-03-05 08:21:11.778667	\N	\N	f	f	f	\N	\N
55	Access Control	Grant Option Abuse	t	2026-03-05 08:24:06.544291	\N	\N	f	f	f	\N	\N
56	SQL Injection	xp_cmdshell Enabled (SQL Server)	t	2026-03-05 08:26:18.190364	\N	\N	f	f	f	\N	\N
57	Compliance	Sample/Test Databases Present	t	2026-03-05 08:27:03.826572	\N	\N	f	f	f	\N	\N
58	Compliance	CLR/Java Enabled (SQL Server/Oracle)	t	2026-03-05 08:27:31.518257	\N	\N	f	f	f	\N	\N
59	Compliance	Debug/Trace Flags Enabled	t	2026-03-05 08:27:46.1338	\N	\N	f	f	f	\N	\N
60	Compliance	SEC-SQL-CFG-006"\t"Database Links Unsecured	t	2026-03-05 08:27:55.756405	\N	\N	f	f	f	\N	\N
61	Data Protection	Data-in-Transit Unencrypted	t	2026-03-05 08:28:39.71407	\N	\N	f	f	f	\N	\N
62	Data Protection	Obsolete TLS Versions	t	2026-03-05 08:29:04.878373	\N	\N	f	f	f	\N	\N
63	Data Protection	Transparent Data Encryption Disabled	t	2026-03-05 08:29:19.957266	\N	\N	f	f	f	\N	\N
64	Data Protection	Unencrypted Backups	t	2026-03-05 08:29:34.772559	\N	\N	f	f	f	\N	\N
65	Data Protection	Weak Encryption Keys/Ciphers	t	2026-03-05 08:29:49.756506	\N	\N	f	f	f	\N	\N
66	SQL Injection	Dynamic SQL in Stored Procedures	t	2026-03-05 08:31:21.231357	\N	\N	f	f	f	\N	\N
67	SQL Injection	Extended Stored Procedures in Use	t	2026-03-05 08:31:40.30904	\N	\N	f	f	f	\N	\N
68	Data Protection	Database Exposed to Public Internet	t	2026-03-05 08:32:11.555933	\N	\N	f	f	f	\N	\N
69	Data Protection	Default Ports in Use	t	2026-03-05 08:32:31.234404	\N	\N	f	f	f	\N	\N
70	Data Protection	Unrestricted Outbound Connections	t	2026-03-05 08:32:43.27688	\N	\N	f	f	f	\N	\N
71	Compliance	End-of-Life Database Version	t	2026-03-05 08:33:30.470058	\N	\N	f	f	f	\N	\N
72	Compliance	Missing Critical Security Patches	t	2026-03-05 08:33:52.654327	\N	\N	f	f	f	\N	\N
73	Data Protection	PII Exposed in Clear Text	t	2026-03-05 08:36:40.858309	\N	\N	f	f	f	\N	\N
74	Data Protection	Sensitive Data in Logs	t	2026-03-05 08:37:11.210978	\N	\N	f	f	f	\N	\N
424	Default Admin Accounts Enabled	Database not in protected network	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-001-RC03-3	\N
425	Default Admin Accounts Enabled	Lack of post-deployment hardening checklist	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-001-RC04-4	\N
426	Default Admin Accounts Enabled	Knowledge gap on account purposes	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-001-RC05-5	\N
427	Default Admin Accounts Enabled	Incomplete migration procedures	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-001-RC06-6	\N
428	Default Admin Accounts Enabled	Recovery procedure reliance	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-001-RC07-7	\N
429	Default Admin Accounts Enabled	Multi-vendor environment complexity	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-001-RC08-8	\N
430	Default Admin Accounts Enabled	No integration with identity provisioning	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-001-RC09-9	\N
431	Default Admin Accounts Enabled	Account privilege escalation over time	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-001-RC10-10	\N
432	Default Admin Accounts Enabled	Inadequate change control	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-001-RC11-11	\N
433	Default Admin Accounts Enabled	Assumption of "unused" protection	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-001-RC12-12	\N
434	Empty/Blank Passwords Allowed	Initialization flag usage	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-002-RC01-1	\N
435	Empty/Blank Passwords Allowed	SQL Server Windows Auth mode conversion	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-002-RC02-2	\N
436	Empty/Blank Passwords Allowed	Installation interruption	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-002-RC03-3	\N
437	Empty/Blank Passwords Allowed	Test account forgotten in production	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-002-RC04-4	\N
438	Empty/Blank Passwords Allowed	Password never set in configuration	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-002-RC05-5	\N
439	Empty/Blank Passwords Allowed	Identity provisioning tool failure	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-002-RC06-6	\N
440	Empty/Blank Passwords Allowed	Configuration file permission bypass	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-002-RC07-7	\N
441	Empty/Blank Passwords Allowed	SQL Server's legacy behavior	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-002-RC08-8	\N
442	Empty/Blank Passwords Allowed	Application provisioning defaults	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-002-RC09-9	\N
443	Empty/Blank Passwords Allowed	LDAP/directory integration incomplete	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-002-RC10-10	\N
444	Empty/Blank Passwords Allowed	Batch user creation scripts	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-002-RC11-11	\N
445	Empty/Blank Passwords Allowed	No pre-deployment security scanning	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-002-RC12-12	\N
446	Weak Password Policy	Default configuration never modified	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-003-RC01-1	\N
447	Weak Password Policy	Complexity enforcement disabled intentionally	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-003-RC02-2	\N
448	Weak Password Policy	Legacy system requirements	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-003-RC03-3	\N
449	Weak Password Policy	Regulatory compliance misinterpretation	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-003-RC04-4	\N
450	Weak Password Policy	Complexity vs. length tradeoff avoided	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-003-RC05-5	\N
451	Weak Password Policy	Performance concerns	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-003-RC06-6	\N
452	Weak Password Policy	User friction avoidance	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-003-RC07-7	\N
453	Weak Password Policy	Development environment settings bleeding to production	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-003-RC08-8	\N
454	Weak Password Policy	No centralized policy definition	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-003-RC09-9	\N
455	Weak Password Policy	Password manager unavailability	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-003-RC10-10	\N
456	Weak Password Policy	Lack of monitoring tools	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-003-RC11-11	\N
457	Weak Password Policy	Policy documentation missing	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-003-RC12-12	\N
458	Weak Password Policy	Account creation automation without validation	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-003-RC13-13	\N
459	Remote OS Authentication Enabled	OS service account access	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-004-RC03-3	\N
460	Remote OS Authentication Enabled	OS-integrated authentication trust configuration	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-004-RC04-4	\N
461	Remote OS Authentication Enabled	Kerberos/SSPI authentication without encryption	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-004-RC06-6	\N
462	Remote OS Authentication Enabled	Cross-system domain trusts	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-004-RC07-7	\N
463	Remote OS Authentication Enabled	No validation of OS identity	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-004-RC08-8	\N
464	Remote OS Authentication Enabled	Assume-inside-firewall security model	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-004-RC10-10	\N
465	Remote OS Authentication Enabled	LDAP with weak connection security	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-004-RC11-11	\N
466	Remote OS Authentication Enabled	No OS authentication logging	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-004-RC12-12	\N
467	Mixed Mode Authentication	Application compatibility requirement	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-005-RC01-1	\N
468	Mixed Mode Authentication	Multi-tenancy needs	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-005-RC02-2	\N
469	Mixed Mode Authentication	Misguided "flexibility" goal	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-005-RC03-3	\N
470	Mixed Mode Authentication	Incomplete migration	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-005-RC04-4	\N
471	Mixed Mode Authentication	External contractor access	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-005-RC05-5	\N
472	Mixed Mode Authentication	Development environment consistency	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-005-RC06-6	\N
473	Mixed Mode Authentication	Post-installation guidance misunderstood	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-005-RC07-7	\N
474	Mixed Mode Authentication	Service account password storage	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-005-RC08-8	\N
475	Mixed Mode Authentication	No policy mandating Windows Auth	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-005-RC09-9	\N
476	Mixed Mode Authentication	Kerberos delegation configuration complexity	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-005-RC11-11	\N
477	Mixed Mode Authentication	Application connection string defaults	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-005-RC12-12	\N
478	Mixed Mode Authentication	No automated compliance scanning	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-005-RC13-13	\N
479	Dormant/Unused Accounts	No activity monitoring	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-006-RC01-1	\N
480	Dormant/Unused Accounts	Offboarding process incomplete	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-006-RC02-2	\N
481	Dormant/Unused Accounts	Service account lifecycle unknown	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-006-RC03-3	\N
482	Dormant/Unused Accounts	Contractor account cleanup forgotten	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-006-RC04-4	\N
483	Dormant/Unused Accounts	Temporary project access never revoked	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-006-RC05-5	\N
484	Dormant/Unused Accounts	Test/dev accounts migrated to production	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-006-RC06-6	\N
485	Dormant/Unused Accounts	No formal account inventory	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-006-RC07-7	\N
486	Dormant/Unused Accounts	HR/Identity integration absent	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-006-RC08-8	\N
487	Dormant/Unused Accounts	Quarterly reviews too infrequent	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-006-RC09-9	\N
488	Dormant/Unused Accounts	Account ownership unclear	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-006-RC11-11	\N
489	Dormant/Unused Accounts	No automated dormancy detection	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-006-RC12-12	\N
490	Dormant/Unused Accounts	Audit trails insufficient	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-006-RC14-14	\N
491	Dormant/Unused Accounts	Remediation effort underestimated	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-006-RC15-15	\N
492	Trust Authentication Enabled	Development environment settings	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-007-RC04-4	\N
493	Trust Authentication Enabled	Remote access addition overlooked	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-007-RC05-5	\N
494	Trust Authentication Enabled	Configuration file management tools	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-007-RC07-7	\N
495	Trust Authentication Enabled	Recovery procedure reliance	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-007-RC09-9	\N
496	Trust Authentication Enabled	Administrator password forgotten or locked	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-007-RC12-12	\N
497	Trust Authentication Enabled	No configuration drift detection	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AU-007-RC14-14	\N
498	Audit Logging Disabled	Global logging switch is disabled	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-001-RC01-1	\N
499	Audit Logging Disabled	Missing audit plugin/extension	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-001-RC02-2	\N
500	Audit Logging Disabled	Audit policy set to "NONE"	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-001-RC03-3	\N
501	Audit Logging Disabled	License restrictions	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-001-RC04-4	\N
502	Audit Logging Disabled	Performance-based disablement	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-001-RC06-6	\N
503	Audit Logging Disabled	Default "Secure by Default" settings	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-001-RC08-8	\N
504	Audit Logging Disabled	Conflicting configuration files	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-001-RC09-9	\N
505	Audit Logging Disabled	Audit process crash	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-001-RC12-12	\N
506	Inadequate Log Retention	Aggressive rotation configuration	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-002-RC01-1	\N
507	Inadequate Log Retention	Insufficient disk space	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-002-RC02-2	\N
508	Inadequate Log Retention	Lack of external archival	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-002-RC03-3	\N
509	Inadequate Log Retention	Memory-only logging	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-002-RC05-5	\N
510	Inadequate Log Retention	File system quotas	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-002-RC07-7	\N
511	Inadequate Log Retention	Manual deletion by admins	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-002-RC10-10	\N
512	Audit Trail Modification Risk	Insecure file permissions	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-003-RC01-1	\N
513	Audit Trail Modification Risk	Internal audit tables are mutable	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-003-RC02-2	\N
514	Audit Trail Modification Risk	Service account ownership	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-003-RC04-4	\N
515	Audit Trail Modification Risk	Non-repudiation features disabled	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-003-RC07-7	\N
516	Audit Trail Modification Risk	Admin accounts shared/untracked	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-003-RC08-8	\N
517	Audit Trail Modification Risk	Audit disablement capability	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-003-RC09-9	\N
518	Missing Login Failure Logs	Logging level set to "Errors Only"	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-004-RC01-1	\N
519	Missing Login Failure Logs	"Successful Logins Only" filter	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-004-RC02-2	\N
520	Missing Login Failure Logs	Generic "Audit All" disabled	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-004-RC04-4	\N
521	Missing Login Failure Logs	Misinterpreted Error Codes	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-004-RC06-6	\N
522	Missing Login Failure Logs	Internal vs External Authentication	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-004-RC07-7	\N
523	Missing Login Failure Logs	Application-side suppression	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-004-RC08-8	\N
524	DDL Logging Disabled	DML-focused Audit Policy	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-005-RC01-1	\N
525	DDL Logging Disabled	Granularity settings	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-005-RC02-2	\N
526	DDL Logging Disabled	Privileged User Exclusion	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-005-RC03-3	\N
527	DDL Logging Disabled	Logging "Write" vs "DDL"	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-005-RC04-4	\N
528	DDL Logging Disabled	Deployment via Scripts	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-005-RC05-5	\N
529	DDL Logging Disabled	Temporary Table Exclusion	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-005-RC06-6	\N
530	DDL Logging Disabled	Extension/Plugin Limitations	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AUD-005-RC07-7	\N
531	Excessive Administrative Privileges	Lack of Role-Based Access Control (RBAC) implementation	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-001-RC01-1	\N
532	Excessive Administrative Privileges	Developer environments influence production practices	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-001-RC03-3	\N
533	Excessive Administrative Privileges	Time pressure and perceived operational convenience	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-001-RC04-4	\N
534	Excessive Administrative Privileges	Inadequate permission analysis during application deployment	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-001-RC05-5	\N
535	Excessive Administrative Privileges	Multi-schema and cross-database application requirements	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-001-RC06-6	\N
536	Excessive Administrative Privileges	Third-party application vendor requirements	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-001-RC07-7	\N
537	Excessive Administrative Privileges	Absence of periodic access reviews and certification	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-001-RC08-8	\N
538	Excessive Administrative Privileges	Legacy applications with hardcoded privilege assumptions	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-001-RC10-10	\N
539	Excessive Administrative Privileges	Knowledge gaps and lack of training	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-001-RC11-11	\N
540	Excessive Administrative Privileges	Vendor default configurations	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-001-RC12-12	\N
541	Excessive Administrative Privileges	No centralized identity and access governance	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-001-RC13-13	\N
542	Excessive Administrative Privileges	Shared service and application accounts	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-001-RC14-14	\N
543	PUBLIC Role Excessive Access	Misunderstanding of PUBLIC role scope	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-002-RC01-1	\N
544	PUBLIC Role Excessive Access	Quick-fix troubleshooting approach	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-002-RC02-2	\N
545	PUBLIC Role Excessive Access	Temporary workarounds becoming permanent	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-002-RC03-3	\N
546	PUBLIC Role Excessive Access	Legacy database practices	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-002-RC04-4	\N
547	PUBLIC Role Excessive Access	Insufficient permission auditing on PUBLIC	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-002-RC05-5	\N
548	PUBLIC Role Excessive Access	Default view permissions in system objects	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-002-RC06-6	\N
549	PUBLIC Role Excessive Access	Confusion between schema and database-level PUBLIC	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-002-RC07-7	\N
550	PUBLIC Role Excessive Access	Testing/development configuration copied to production	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-002-RC08-8	\N
551	PUBLIC Role Excessive Access	Bulk permission scripts without proper restriction	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-002-RC09-9	\N
552	PUBLIC Role Excessive Access	Lack of role-based alternative	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-002-RC10-10	\N
553	PUBLIC Role Excessive Access	Incompletely implemented permission revocation	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-002-RC11-11	\N
554	PUBLIC Role Excessive Access	Tool or vendor recommendations that are unsafe	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-002-RC12-12	\N
555	PUBLIC Role Excessive Access	Emergency access during incidents	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-002-RC13-13	\N
556	Orphaned User Accounts	Absence of user lifecycle management automation	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-003-RC01-1	\N
557	Orphaned User Accounts	Manual offboarding processes with gaps	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-003-RC02-2	\N
558	Orphaned User Accounts	Delayed or forgotten deprovisioning	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-003-RC03-3	\N
559	Orphaned User Accounts	Lack of integration between HR systems and database access	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-003-RC04-4	\N
560	Orphaned User Accounts	No reconciliation process between database accounts and authorized users	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-003-RC05-5	\N
561	Orphaned User Accounts	Service and application accounts without ownership tracking	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-003-RC06-6	\N
562	Orphaned User Accounts	Contractor and vendor accounts without explicit end dates	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-003-RC07-7	\N
563	Orphaned User Accounts	Shared database accounts and credentials	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-003-RC08-8	\N
564	Orphaned User Accounts	Cross-database and application account complexity	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-003-RC09-9	\N
565	Orphaned User Accounts	Legacy account creation without documentation	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-003-RC10-10	\N
566	Orphaned User Accounts	Database environment fragmentation	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-003-RC11-11	\N
567	Orphaned User Accounts	Lack of privileged access management (PAM) systems	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-003-RC12-12	\N
568	Orphaned User Accounts	Application default accounts never updated	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-003-RC13-13	\N
569	Orphaned User Accounts	Failed or incomplete migration processes	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-003-RC14-14	\N
570	Orphaned User Accounts	Assumption that low-privilege accounts are harmless	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-003-RC15-15	\N
571	File System Access Privilege	Application requirements for file export functionality	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-004-RC01-1	\N
572	File System Access Privilege	Business intelligence and reporting tool requirements	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-004-RC03-3	\N
573	File System Access Privilege	Inadequate file operation path restrictions	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-004-RC04-4	\N
574	File System Access Privilege	Default configuration not hardened during installation	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-004-RC05-5	\N
575	File System Access Privilege	Developer convenience during development	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-004-RC06-6	\N
576	File System Access Privilege	Troubleshooting and ad-hoc data extraction	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-004-RC07-7	\N
577	File System Access Privilege	Third-party tool or vendor requirements	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-004-RC08-8	\N
578	File System Access Privilege	Historical privilege accumulation	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-004-RC09-9	\N
579	File System Access Privilege	Insufficient monitoring of FILE privilege usage	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-004-RC10-10	\N
580	File System Access Privilege	Shared service accounts with FILE privilege	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-004-RC11-11	\N
581	File System Access Privilege	Configuration management errors	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-004-RC12-12	\N
582	File System Access Privilege	Privilege grants during emergency scenarios	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-004-RC13-13	\N
583	File System Access Privilege	Misunderstanding of attack vectors	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-004-RC14-14	\N
584	Cross-Database Ownership Chaining	Insufficient understanding of ownership chaining mechanics	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-005-RC01-1	\N
585	Cross-Database Ownership Chaining	Convenience over security principle	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-005-RC02-2	\N
586	Cross-Database Ownership Chaining	Legacy application design assuming ownership chaining	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-005-RC03-3	\N
587	Cross-Database Ownership Chaining	Multi-database applications without explicit permission architecture	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-005-RC05-5	\N
588	Cross-Database Ownership Chaining	Migration from single-database to multi-database environments	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-005-RC06-6	\N
589	Cross-Database Ownership Chaining	Lack of audit or monitoring of cross-database access	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-005-RC08-8	\N
590	Cross-Database Ownership Chaining	Testing configurations carried forward to production	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-005-RC09-9	\N
591	Cross-Database Ownership Chaining	Third-party vendor requirements or recommendations	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-005-RC10-10	\N
592	Cross-Database Ownership Chaining	Incomplete understanding of risk when owner differs	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-005-RC11-11	\N
593	Cross-Database Ownership Chaining	Database isolation principle not enforced	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-005-RC12-12	\N
594	Grant Option Abuse	Overly broad delegation of grant rights	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-006-RC01-1	\N
595	Grant Option Abuse	Inadequate understanding of WITH GRANT OPTION implications	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-006-RC02-2	\N
596	Grant Option Abuse	Convenience for distributed access management	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-006-RC03-3	\N
597	Grant Option Abuse	No approval workflow for permission delegation	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-006-RC04-4	\N
598	Grant Option Abuse	Inadequate monitoring of grant activity	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-006-RC05-5	\N
599	Grant Option Abuse	Lack of restrictions on re-delegation	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-006-RC06-6	\N
600	Grant Option Abuse	Grant option on sensitive privileges	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-006-RC07-7	\N
601	Grant Option Abuse	Default role configurations including grant option	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-006-RC08-8	\N
602	Grant Option Abuse	Privilege escalation through role membership	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-006-RC09-9	\N
603	Grant Option Abuse	Separation of duties violations	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-006-RC10-10	\N
604	Grant Option Abuse	Compliance framework gaps	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-006-RC12-12	\N
605	Grant Option Abuse	Inherited permissions from legacy systems	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-006-RC13-13	\N
606	Grant Option Abuse	Confusion between intent and capability	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-AZ-006-RC14-14	\N
607	xp_cmdshell Enabled (SQL Server)	Legacy Application Compatibility	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-001-RC01-1	\N
608	xp_cmdshell Enabled (SQL Server)	Third-Party Vendor Requirements	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-001-RC02-2	\N
609	xp_cmdshell Enabled (SQL Server)	Administrative Troubleshooting Convenience	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-001-RC03-3	\N
610	xp_cmdshell Enabled (SQL Server)	Inadequate Change Control	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-001-RC04-4	\N
611	xp_cmdshell Enabled (SQL Server)	SQL Injection Vulnerability	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-001-RC05-5	\N
612	xp_cmdshell Enabled (SQL Server)	Excessive Service Account Privileges	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-001-RC06-6	\N
613	xp_cmdshell Enabled (SQL Server)	Lack of Monitoring and Auditing	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-001-RC07-7	\N
614	xp_cmdshell Enabled (SQL Server)	Knowledge Gap on Alternatives	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-001-RC08-8	\N
615	xp_cmdshell Enabled (SQL Server)	Lateral Movement Capability	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-001-RC10-10	\N
616	xp_cmdshell Enabled (SQL Server)	Backup Restoration from Compromised Environments	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-001-RC12-12	\N
617	Sample/Test Databases Present	Default Installation Artifacts	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-003-RC01-1	\N
618	Sample/Test Databases Present	Development Environment Cloning	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-003-RC02-2	\N
619	Sample/Test Databases Present	Backup Restoration Error	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-003-RC03-3	\N
620	Sample/Test Databases Present	Migration Process Gaps	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-003-RC04-4	\N
621	Sample/Test Databases Present	Knowledge Loss During Transitions	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-003-RC05-5	\N
622	Sample/Test Databases Present	Inadequate Cleanup Procedures	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-003-RC06-6	\N
623	Sample/Test Databases Present	Application Configuration Pointing to Wrong Database	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-003-RC07-7	\N
624	Sample/Test Databases Present	Demonstration and Training Use	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-003-RC08-8	\N
625	Sample/Test Databases Present	Insufficient RBAC Controls	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-003-RC10-10	\N
626	Sample/Test Databases Present	Compliance Scope Confusion	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-003-RC11-11	\N
627	Sample/Test Databases Present	Weak Object Naming Conventions	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-003-RC13-13	\N
628	Sample/Test Databases Present	Multi-Tenant Instance Management	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-003-RC14-14	\N
629	CLR/Java Enabled (SQL Server/Oracle)	Application Code Execution Requirement	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-004-RC01-1	\N
630	CLR/Java Enabled (SQL Server/Oracle)	Performance Optimization	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-004-RC02-2	\N
631	CLR/Java Enabled (SQL Server/Oracle)	Third-Party Tool Dependencies	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-004-RC03-3	\N
632	CLR/Java Enabled (SQL Server/Oracle)	Unsigned Assembly Bypass	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-004-RC04-4	\N
633	CLR/Java Enabled (SQL Server/Oracle)	Lack of Assembly Vetting	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-004-RC05-5	\N
634	CLR/Java Enabled (SQL Server/Oracle)	Privilege Escalation via CLR	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-004-RC06-6	\N
635	CLR/Java Enabled (SQL Server/Oracle)	Sandbox Escape	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-004-RC07-7	\N
636	CLR/Java Enabled (SQL Server/Oracle)	Registry Modification	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-004-RC08-8	\N
637	CLR/Java Enabled (SQL Server/Oracle)	Network-Based Attacks	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-004-RC09-9	\N
638	CLR/Java Enabled (SQL Server/Oracle)	External Library Access	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-004-RC10-10	\N
639	CLR/Java Enabled (SQL Server/Oracle)	Post-Exploitation Persistence	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-004-RC11-11	\N
640	CLR/Java Enabled (SQL Server/Oracle)	Insufficient Configuration Segregation	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-004-RC12-12	\N
641	CLR/Java Enabled (SQL Server/Oracle)	Monitoring Gaps	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-004-RC13-13	\N
642	Debug/Trace Flags Enabled	Experimentation in Production	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-005-RC06-6	\N
643	Debug/Trace Flags Enabled	Deprecated Flag Persistence	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-005-RC11-11	\N
644	Debug/Trace Flags Enabled	Lazy Optimization	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-005-RC12-12	\N
645	Database Links Unsecured	Privilege Escalation via Link	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-006-RC04-4	\N
646	Database Links Unsecured	Inadequate Access Control	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-006-RC05-5	\N
647	Database Links Unsecured	Cross-Database Privilege Inheritance	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-006-RC06-6	\N
648	Database Links Unsecured	Unvalidated Dynamic Queries	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-006-RC07-7	\N
649	Database Links Unsecured	Remote Database Exploitation	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-006-RC08-8	\N
650	Database Links Unsecured	Credential Exposure via Monitoring	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-006-RC09-9	\N
651	Database Links Unsecured	Long-Lived Credentials	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-006-RC10-10	\N
652	Database Links Unsecured	Scope Confusion	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-006-RC11-11	\N
653	Database Links Unsecured	Linked Server Configuration Persistence	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-006-RC13-13	\N
654	Database Links Unsecured	Missing Encryption	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-006-RC14-14	\N
655	Database Links Unsecured	Mutual Authentication Gaps	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-006-RC15-15	\N
656	Database Links Unsecured	Catalog-Level Exposure	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-CFG-006-RC16-16	\N
657	Data-in-Transit Unencrypted	Default Configuration Not Changed	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-001-RC01-1	\N
658	Data-in-Transit Unencrypted	Missing Encryption Parameter in Connection Strings	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-001-RC02-2	\N
659	Data-in-Transit Unencrypted	Backward Compatibility Requirements	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-001-RC03-3	\N
660	Data-in-Transit Unencrypted	Client Driver Version Mismatch	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-001-RC04-4	\N
661	Data-in-Transit Unencrypted	Certificate Management Complexity	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-001-RC07-7	\N
662	Data-in-Transit Unencrypted	Self-Signed Certificate Issues	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-001-RC08-8	\N
663	Data-in-Transit Unencrypted	Network Architecture Assumptions	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-001-RC09-9	\N
664	Data-in-Transit Unencrypted	Lack of Security Requirements	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-001-RC10-10	\N
665	Data-in-Transit Unencrypted	Application Middleware Bypass	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-001-RC11-11	\N
666	Data-in-Transit Unencrypted	Testing and Development Environment Carryover	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-001-RC12-12	\N
667	Data-in-Transit Unencrypted	Inadequate Monitoring and Visibility	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-001-RC13-13	\N
668	Obsolete TLS Versions	Legacy Application Dependency on TLS 1.0/1.1	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-002-RC01-1	\N
669	Obsolete TLS Versions	Deprecated Client Libraries in Use	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-002-RC02-2	\N
670	Obsolete TLS Versions	.NET Framework Constraints	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-002-RC03-3	\N
671	Obsolete TLS Versions	Java/JDK Version Limitations	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-002-RC04-4	\N
672	Obsolete TLS Versions	Configuration Oversight	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-002-RC09-9	\N
673	Obsolete TLS Versions	Intentional Compatibility Decisions	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-002-RC10-10	\N
674	Obsolete TLS Versions	No Automated Configuration Audit	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-002-RC11-11	\N
675	Obsolete TLS Versions	Database Version Limitations	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-002-RC12-12	\N
676	Transparent Data Encryption Disabled	Not Aware of TDE Feature	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-003-RC01-1	\N
677	Transparent Data Encryption Disabled	Licensing Restrictions	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-003-RC02-2	\N
678	Transparent Data Encryption Disabled	Missing License Entitlements	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-003-RC03-3	\N
679	Transparent Data Encryption Disabled	Key Management System Not Available	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-003-RC04-4	\N
680	Transparent Data Encryption Disabled	Database Design Incompatibility	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-003-RC06-6	\N
681	Transparent Data Encryption Disabled	Temporary workspace encryption complications	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-003-RC10-10	\N
682	Transparent Data Encryption Disabled	Development/Test Database Assumption	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-003-RC13-13	\N
683	Transparent Data Encryption Disabled	Previous Failed Implementation Attempt	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-003-RC15-15	\N
684	Transparent Data Encryption Disabled	Wallets and Key Storage Issues	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-003-RC16-16	\N
685	Unencrypted Backups	Feature Not Enabled at Backup Time	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-004-RC01-1	\N
686	Unencrypted Backups	Key Management for Backups Not Established	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-004-RC03-3	\N
687	Unencrypted Backups	Certificate and Key Expiration on Backups	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-004-RC10-10	\N
688	Unencrypted Backups	Database Encryption Complexity Misunderstood	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-004-RC11-11	\N
689	Weak Encryption Keys/Ciphers	Default/Legacy Cipher Suites Not Disabled	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-005-RC01-1	\N
690	Weak Encryption Keys/Ciphers	Short Key Lengths Selected for Performance	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-005-RC02-2	\N
691	Weak Encryption Keys/Ciphers	Deprecated Algorithm Still in Use	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-005-RC03-3	\N
692	Weak Encryption Keys/Ciphers	Certificate Signed with Weak Hash	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-005-RC04-4	\N
693	Weak Encryption Keys/Ciphers	CBC Mode Still Allowed in Configuration	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-005-RC10-10	\N
694	Weak Encryption Keys/Ciphers	Key Rotation Policy Not Implemented	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-005-RC12-12	\N
695	Weak Encryption Keys/Ciphers	Asymmetric Key Weak Parameters	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-005-RC13-13	\N
696	Weak Encryption Keys/Ciphers	No Monitoring of Negotiated Ciphers	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-ENC-005-RC14-14	\N
697	Dynamic SQL in Stored Procedures	String concatenation for query building	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-INJ-001-RC01-1	\N
698	Dynamic SQL in Stored Procedures	Inadequate input validation and sanitization	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-INJ-001-RC02-2	\N
699	Dynamic SQL in Stored Procedures	Mixing static and dynamic SQL constructs	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-INJ-001-RC07-7	\N
700	Dynamic SQL in Stored Procedures	ORM framework misuse	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-INJ-001-RC10-10	\N
701	Dynamic SQL in Stored Procedures	Operator control issues	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-INJ-001-RC13-13	\N
702	Dynamic SQL in Stored Procedures	Implicit trust in framework defaults	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-INJ-001-RC14-14	\N
703	Dynamic SQL in Stored Procedures	Incomplete parameter binding	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-INJ-001-RC15-15	\N
704	Extended Stored Procedures in Use	Legacy system constraints	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-INJ-002-RC01-1	\N
705	Extended Stored Procedures in Use	Backward compatibility requirements	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-INJ-002-RC02-2	\N
706	Extended Stored Procedures in Use	Insufficient privilege controls	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-INJ-002-RC07-7	\N
707	Extended Stored Procedures in Use	Missing monitoring and enforcement	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-INJ-002-RC08-8	\N
708	Extended Stored Procedures in Use	Assumption of network isolation	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-INJ-002-RC09-9	\N
709	Extended Stored Procedures in Use	Security compliance misalignment	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-INJ-002-RC10-10	\N
710	Extended Stored Procedures in Use	Service account privilege excess	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-INJ-002-RC11-11	\N
711	Extended Stored Procedures in Use	Third-party application requirements	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-INJ-002-RC12-12	\N
712	Extended Stored Procedures in Use	DLL file vulnerabilities	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-INJ-002-RC14-14	\N
713	Extended Stored Procedures in Use	SQL injection chaining	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-INJ-002-RC15-15	\N
714	Extended Stored Procedures in Use	Insufficient removal validation	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-INJ-002-RC16-16	\N
715	Database Exposed to Public Internet	Bind Address Misconfiguration	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-NET-001-RC01-1	\N
716	Database Exposed to Public Internet	Overly Permissive Security Group/Firewall Rules	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-NET-001-RC02-2	\N
717	Database Exposed to Public Internet	Public Cloud Instance Configuration	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-NET-001-RC03-3	\N
718	Database Exposed to Public Internet	Lack of IP Allowlist/Whitelist Enforcement	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-NET-001-RC05-5	\N
719	Database Exposed to Public Internet	Temporary Access Left Permanently	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-NET-001-RC12-12	\N
720	Default Ports in Use	Default Configuration Never Changed	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-NET-002-RC01-1	\N
721	Default Ports in Use	Lack of Security Hardening Process	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-NET-002-RC02-2	\N
722	Default Ports in Use	Convenience and Standardization	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-NET-002-RC03-3	\N
723	Default Ports in Use	Documentation Focuses on Default Values	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-NET-002-RC04-4	\N
724	Default Ports in Use	Port Scanning Facilitation	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-NET-002-RC05-5	\N
725	Default Ports in Use	Application Connection String Hardcoding	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-NET-002-RC06-6	\N
726	Default Ports in Use	No Port Randomization or Obscurity Strategy	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-NET-002-RC08-8	\N
727	Default Ports in Use	Assumption Port Numbers Alone Provide Security	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-NET-002-RC10-10	\N
728	Default Ports in Use	Version Disclosure via Banners	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-NET-002-RC12-12	\N
729	Default Ports in Use	Lack of Port Rotation Practices	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-NET-002-RC14-14	\N
730	Unrestricted Outbound Connections	Database Features Requiring Internet Access	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-NET-003-RC03-3	\N
731	Unrestricted Outbound Connections	External data access configuration	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-NET-003-RC04-4	\N
732	Unrestricted Outbound Connections	External Data Source Integration	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-NET-003-RC05-5	\N
733	Unrestricted Outbound Connections	Package Manager and Repository Access	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-NET-003-RC06-6	\N
734	Unrestricted Outbound Connections	Database Replication to Cloud	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-NET-003-RC14-14	\N
735	Unrestricted Outbound Connections	Monitoring and Logging Exfiltration	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-NET-003-RC15-15	\N
736	End-of-Life Database Version	Lack of proactive EOL tracking and monitoring	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-PAT-001-RC01-1	\N
737	End-of-Life Database Version	Deferred major version upgrades due to technical complexity	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-PAT-001-RC02-2	\N
738	End-of-Life Database Version	Application dependency on deprecated database features	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-PAT-001-RC05-5	\N
739	End-of-Life Database Version	Client and driver compatibility concerns	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-PAT-001-RC09-9	\N
740	End-of-Life Database Version	Legacy application portfolio constraints	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-PAT-001-RC11-11	\N
741	End-of-Life Database Version	Incremental neglect over multiple release cycles	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-PAT-001-RC12-12	\N
742	Missing Critical Security Patches	Extended CVE disclosure-to-patch timelines	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-PAT-002-RC02-2	\N
743	Missing Critical Security Patches	Incompatible dependency chains	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-PAT-002-RC09-9	\N
744	Missing Critical Security Patches	Active database usage preventing maintenance windows	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-PAT-002-RC10-10	\N
745	Missing Critical Security Patches	Critical patches for rarely-exploited vulnerabilities	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-PAT-002-RC12-12	\N
746	PII Exposed in Clear Text	Misunderstanding of "Encryption at Rest" (TDE)	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-PRI-001-RC01-1	\N
747	PII Exposed in Clear Text	Searchability \\& Indexing Requirements	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-PRI-001-RC02-2	\N
748	PII Exposed in Clear Text	Performance Overhead Fears	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-PRI-001-RC03-3	\N
749	PII Exposed in Clear Text	Incorrect Data Types	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-PRI-001-RC04-4	\N
750	PII Exposed in Clear Text	Legacy Schema Constraints	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-PRI-001-RC05-5	\N
751	PII Exposed in Clear Text	In-House "Masking" Logic Failure	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-PRI-001-RC06-6	\N
752	PII Exposed in Clear Text	ETL \\& Data Warehousing Stripping	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-PRI-001-RC07-7	\N
753	PII Exposed in Clear Text	Key Management Complexity	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-PRI-001-RC09-9	\N
754	PII Exposed in Clear Text	Lack of Native Masking Features (Old Versions)	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-PRI-001-RC10-10	\N
755	PII Exposed in Clear Text	Unsecured Backups/Snapshots	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-PRI-001-RC11-11	\N
756	Sensitive Data in Logs	Unparameterized Queries (String Concatenation)	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-PRI-002-RC02-2	\N
757	Sensitive Data in Logs	Verbose Error Logging	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-PRI-002-RC03-3	\N
758	Sensitive Data in Logs	Audit Trail Over-Configuration	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-PRI-002-RC04-4	\N
759	Sensitive Data in Logs	Sensitive Functions in Logs	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-PRI-002-RC05-5	\N
760	Sensitive Data in Logs	Crash Dumps and Core Files	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-PRI-002-RC06-6	\N
761	Sensitive Data in Logs	Insufficient Log Rotation/Permissions	t	2026-03-05 16:08:54.604399	\N	\N	f	f	f	SEC-SQL-PRI-002-RC11-11	\N
423	Default Admin Accounts Enabled	Installation defaults not changed	t	2026-03-05 16:08:54.604399	SELECT case when COUNT(*) >0 then 0 else 1 end cnt  from monitoring.v_sec_sql_au_001_rc01_1  WHERE ENTRY_DATE  = (select max(ENTRY_DATE) FROM monitoring.v_sec_sql_au_001_rc01_1)	2	f	f	f	SEC-SQL-AU-001-RC01-1	\N
\.
INSERT INTO flowchart.visual_objects (row_id, source_object, target_object, is_active, entry_date, mainstat_query, mainstat_threshold_id, alert_mail, alert_report, alert_siem, metric_name, diagnosys)
SELECT row_id, source_object, target_object, is_active, entry_date, mainstat_query, mainstat_threshold_id, alert_mail, alert_report, alert_siem, metric_name, diagnosys FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM flowchart.visual_objects);
DROP TABLE _stg_load;

SELECT setval('flowchart.visual_objects_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM flowchart.visual_objects),1), (SELECT count(*) FROM flowchart.visual_objects) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'flowchart' AND c.relname = 'visual_objects'
          AND con.conname = 'pk_visual_objects') THEN
        ALTER TABLE ONLY flowchart.visual_objects
    ADD CONSTRAINT pk_visual_objects PRIMARY KEY (source_object, target_object);
    END IF;
END $do$;
