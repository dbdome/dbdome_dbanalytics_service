-- Idempotent install for config.firewall_policies
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.firewall_policies_policy_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.firewall_policies (
    policy_id integer NOT NULL,
    policy_name character varying(200) NOT NULL,
    vendor character varying(50) DEFAULT 'all'::character varying NOT NULL,
    action character varying(20) NOT NULL,
    condition_type character varying(50) NOT NULL,
    condition_value text NOT NULL,
    severity character varying(20) DEFAULT 'MEDIUM'::character varying NOT NULL,
    regulation character varying(50),
    priority integer DEFAULT 100 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_by character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE config.firewall_policies ALTER COLUMN policy_id SET DEFAULT nextval('config.firewall_policies_policy_id_seq'::regclass);
ALTER SEQUENCE config.firewall_policies_policy_id_seq OWNED BY config.firewall_policies.policy_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE config.firewall_policies);
COPY _stg_load (policy_id, policy_name, vendor, action, condition_type, condition_value, severity, regulation, priority, is_active, created_by, created_at, updated_at) FROM stdin;
1	PCI-DSS: Block anonymous logins	all	BLOCK	user	anonymous|guest|public	HIGH	PCI-DSS	10	t	\N	2026-05-09 13:03:42.546253+03	2026-05-09 13:03:42.546253+03
2	PCI-DSS: Alert bulk SELECT (>1000)	all	ALERT	query_pattern	SELECT.{0,300}(TOP\\s+[1-9]\\d{3,}|LIMIT\\s+[1-9]\\d{3,}|FETCH\\s+FIRST\\s+[1-9]\\d{3,})	HIGH	PCI-DSS	20	t	\N	2026-05-09 13:03:42.546253+03	2026-05-09 13:03:42.546253+03
3	PCI-DSS: Block SELECT INTO OUTFILE	all	BLOCK	query_pattern	INTO\\s+OUTFILE|INTO\\s+DUMPFILE|xp_cmdshell|OPENROWSET|BULK\\s+INSERT	CRITICAL	PCI-DSS	5	t	\N	2026-05-09 13:03:42.546253+03	2026-05-09 13:03:42.546253+03
4	HIPAA: Alert PHI table access	all	ALERT	table_name	patient|medical_record|phi|health_data|diagnosis|prescription	HIGH	HIPAA	15	t	\N	2026-05-09 13:03:42.546253+03	2026-05-09 13:03:42.546253+03
5	HIPAA: Block after-hours SA access	all	BLOCK	time_range	00:00-06:00	HIGH	HIPAA	10	t	\N	2026-05-09 13:03:42.546253+03	2026-05-09 13:03:42.546253+03
6	GDPR: Alert PII column SELECT	all	ALERT	query_pattern	ssn|social_security|passport|credit_card|card_number|date_of_birth	MEDIUM	GDPR	20	t	\N	2026-05-09 13:03:42.546253+03	2026-05-09 13:03:42.546253+03
7	GDPR: Block DROP on PII tables	all	BLOCK	query_pattern	^\\s*DROP\\s+(TABLE|DATABASE|SCHEMA)	CRITICAL	GDPR	5	t	\N	2026-05-09 13:03:42.546253+03	2026-05-09 13:03:42.546253+03
8	SOC2: Alert sysadmin/DBA activity	all	ALERT	role	sysadmin|db_owner|DBA|SYSDBA|rdsadmin|sa	MEDIUM	SOC2	30	t	\N	2026-05-09 13:03:42.546253+03	2026-05-09 13:03:42.546253+03
9	PCI-DSS: Block anonymous logins	all	BLOCK	user	anonymous|guest|public	HIGH	PCI-DSS	10	t	\N	2026-05-09 16:50:53.10519+03	2026-05-09 16:50:53.10519+03
10	PCI-DSS: Alert bulk SELECT (>1000)	all	ALERT	query_pattern	SELECT.{0,300}(TOP\\s+[1-9]\\d{3,}|LIMIT\\s+[1-9]\\d{3,}|FETCH\\s+FIRST\\s+[1-9]\\d{3,})	HIGH	PCI-DSS	20	t	\N	2026-05-09 16:50:53.10519+03	2026-05-09 16:50:53.10519+03
11	PCI-DSS: Block SELECT INTO OUTFILE	all	BLOCK	query_pattern	INTO\\s+OUTFILE|INTO\\s+DUMPFILE|xp_cmdshell|OPENROWSET|BULK\\s+INSERT	CRITICAL	PCI-DSS	5	t	\N	2026-05-09 16:50:53.10519+03	2026-05-09 16:50:53.10519+03
12	HIPAA: Alert PHI table access	all	ALERT	table_name	patient|medical_record|phi|health_data|diagnosis|prescription	HIGH	HIPAA	15	t	\N	2026-05-09 16:50:53.10519+03	2026-05-09 16:50:53.10519+03
13	HIPAA: Block after-hours SA access	all	BLOCK	time_range	00:00-06:00	HIGH	HIPAA	10	t	\N	2026-05-09 16:50:53.10519+03	2026-05-09 16:50:53.10519+03
14	GDPR: Alert PII column SELECT	all	ALERT	query_pattern	ssn|social_security|passport|credit_card|card_number|date_of_birth	MEDIUM	GDPR	20	t	\N	2026-05-09 16:50:53.10519+03	2026-05-09 16:50:53.10519+03
15	GDPR: Block DROP on PII tables	all	BLOCK	query_pattern	^\\s*DROP\\s+(TABLE|DATABASE|SCHEMA)	CRITICAL	GDPR	5	t	\N	2026-05-09 16:50:53.10519+03	2026-05-09 16:50:53.10519+03
16	SOC2: Alert sysadmin/DBA activity	all	ALERT	role	sysadmin|db_owner|DBA|SYSDBA|rdsadmin|sa	MEDIUM	SOC2	30	t	\N	2026-05-09 16:50:53.10519+03	2026-05-09 16:50:53.10519+03
17	PCI-DSS: Block anonymous logins	all	BLOCK	user	anonymous|guest|public	HIGH	PCI-DSS	10	t	\N	2026-05-10 18:15:30.724831+03	2026-05-10 18:15:30.724831+03
18	PCI-DSS: Alert bulk SELECT (>1000)	all	ALERT	query_pattern	SELECT.{0,300}(TOP\\s+[1-9]\\d{3,}|LIMIT\\s+[1-9]\\d{3,}|FETCH\\s+FIRST\\s+[1-9]\\d{3,})	HIGH	PCI-DSS	20	t	\N	2026-05-10 18:15:30.724831+03	2026-05-10 18:15:30.724831+03
19	PCI-DSS: Block SELECT INTO OUTFILE	all	BLOCK	query_pattern	INTO\\s+OUTFILE|INTO\\s+DUMPFILE|xp_cmdshell|OPENROWSET|BULK\\s+INSERT	CRITICAL	PCI-DSS	5	t	\N	2026-05-10 18:15:30.724831+03	2026-05-10 18:15:30.724831+03
20	HIPAA: Alert PHI table access	all	ALERT	table_name	patient|medical_record|phi|health_data|diagnosis|prescription	HIGH	HIPAA	15	t	\N	2026-05-10 18:15:30.724831+03	2026-05-10 18:15:30.724831+03
21	HIPAA: Block after-hours SA access	all	BLOCK	time_range	00:00-06:00	HIGH	HIPAA	10	t	\N	2026-05-10 18:15:30.724831+03	2026-05-10 18:15:30.724831+03
22	GDPR: Alert PII column SELECT	all	ALERT	query_pattern	ssn|social_security|passport|credit_card|card_number|date_of_birth	MEDIUM	GDPR	20	t	\N	2026-05-10 18:15:30.724831+03	2026-05-10 18:15:30.724831+03
23	GDPR: Block DROP on PII tables	all	BLOCK	query_pattern	^\\s*DROP\\s+(TABLE|DATABASE|SCHEMA)	CRITICAL	GDPR	5	t	\N	2026-05-10 18:15:30.724831+03	2026-05-10 18:15:30.724831+03
24	SOC2: Alert sysadmin/DBA activity	all	ALERT	role	sysadmin|db_owner|DBA|SYSDBA|rdsadmin|sa	MEDIUM	SOC2	30	t	\N	2026-05-10 18:15:30.724831+03	2026-05-10 18:15:30.724831+03
25	PCI-DSS: Block anonymous logins	all	BLOCK	user	anonymous|guest|public	HIGH	PCI-DSS	10	t	\N	2026-05-10 18:16:56.136429+03	2026-05-10 18:16:56.136429+03
26	PCI-DSS: Alert bulk SELECT (>1000)	all	ALERT	query_pattern	SELECT.{0,300}(TOP\\s+[1-9]\\d{3,}|LIMIT\\s+[1-9]\\d{3,}|FETCH\\s+FIRST\\s+[1-9]\\d{3,})	HIGH	PCI-DSS	20	t	\N	2026-05-10 18:16:56.136429+03	2026-05-10 18:16:56.136429+03
27	PCI-DSS: Block SELECT INTO OUTFILE	all	BLOCK	query_pattern	INTO\\s+OUTFILE|INTO\\s+DUMPFILE|xp_cmdshell|OPENROWSET|BULK\\s+INSERT	CRITICAL	PCI-DSS	5	t	\N	2026-05-10 18:16:56.136429+03	2026-05-10 18:16:56.136429+03
28	HIPAA: Alert PHI table access	all	ALERT	table_name	patient|medical_record|phi|health_data|diagnosis|prescription	HIGH	HIPAA	15	t	\N	2026-05-10 18:16:56.136429+03	2026-05-10 18:16:56.136429+03
29	HIPAA: Block after-hours SA access	all	BLOCK	time_range	00:00-06:00	HIGH	HIPAA	10	t	\N	2026-05-10 18:16:56.136429+03	2026-05-10 18:16:56.136429+03
30	GDPR: Alert PII column SELECT	all	ALERT	query_pattern	ssn|social_security|passport|credit_card|card_number|date_of_birth	MEDIUM	GDPR	20	t	\N	2026-05-10 18:16:56.136429+03	2026-05-10 18:16:56.136429+03
31	GDPR: Block DROP on PII tables	all	BLOCK	query_pattern	^\\s*DROP\\s+(TABLE|DATABASE|SCHEMA)	CRITICAL	GDPR	5	t	\N	2026-05-10 18:16:56.136429+03	2026-05-10 18:16:56.136429+03
32	SOC2: Alert sysadmin/DBA activity	all	ALERT	role	sysadmin|db_owner|DBA|SYSDBA|rdsadmin|sa	MEDIUM	SOC2	30	t	\N	2026-05-10 18:16:56.136429+03	2026-05-10 18:16:56.136429+03
33	PCI-DSS: Block anonymous logins	all	BLOCK	user	anonymous|guest|public	HIGH	PCI-DSS	10	t	\N	2026-05-10 18:17:17.988795+03	2026-05-10 18:17:17.988795+03
34	PCI-DSS: Alert bulk SELECT (>1000)	all	ALERT	query_pattern	SELECT.{0,300}(TOP\\s+[1-9]\\d{3,}|LIMIT\\s+[1-9]\\d{3,}|FETCH\\s+FIRST\\s+[1-9]\\d{3,})	HIGH	PCI-DSS	20	t	\N	2026-05-10 18:17:17.988795+03	2026-05-10 18:17:17.988795+03
35	PCI-DSS: Block SELECT INTO OUTFILE	all	BLOCK	query_pattern	INTO\\s+OUTFILE|INTO\\s+DUMPFILE|xp_cmdshell|OPENROWSET|BULK\\s+INSERT	CRITICAL	PCI-DSS	5	t	\N	2026-05-10 18:17:17.988795+03	2026-05-10 18:17:17.988795+03
36	HIPAA: Alert PHI table access	all	ALERT	table_name	patient|medical_record|phi|health_data|diagnosis|prescription	HIGH	HIPAA	15	t	\N	2026-05-10 18:17:17.988795+03	2026-05-10 18:17:17.988795+03
37	HIPAA: Block after-hours SA access	all	BLOCK	time_range	00:00-06:00	HIGH	HIPAA	10	t	\N	2026-05-10 18:17:17.988795+03	2026-05-10 18:17:17.988795+03
38	GDPR: Alert PII column SELECT	all	ALERT	query_pattern	ssn|social_security|passport|credit_card|card_number|date_of_birth	MEDIUM	GDPR	20	t	\N	2026-05-10 18:17:17.988795+03	2026-05-10 18:17:17.988795+03
39	GDPR: Block DROP on PII tables	all	BLOCK	query_pattern	^\\s*DROP\\s+(TABLE|DATABASE|SCHEMA)	CRITICAL	GDPR	5	t	\N	2026-05-10 18:17:17.988795+03	2026-05-10 18:17:17.988795+03
40	SOC2: Alert sysadmin/DBA activity	all	ALERT	role	sysadmin|db_owner|DBA|SYSDBA|rdsadmin|sa	MEDIUM	SOC2	30	t	\N	2026-05-10 18:17:17.988795+03	2026-05-10 18:17:17.988795+03
41	PCI-DSS: Block anonymous logins	all	BLOCK	user	anonymous|guest|public	HIGH	PCI-DSS	10	t	\N	2026-05-10 18:17:57.209372+03	2026-05-10 18:17:57.209372+03
42	PCI-DSS: Alert bulk SELECT (>1000)	all	ALERT	query_pattern	SELECT.{0,300}(TOP\\s+[1-9]\\d{3,}|LIMIT\\s+[1-9]\\d{3,}|FETCH\\s+FIRST\\s+[1-9]\\d{3,})	HIGH	PCI-DSS	20	t	\N	2026-05-10 18:17:57.209372+03	2026-05-10 18:17:57.209372+03
43	PCI-DSS: Block SELECT INTO OUTFILE	all	BLOCK	query_pattern	INTO\\s+OUTFILE|INTO\\s+DUMPFILE|xp_cmdshell|OPENROWSET|BULK\\s+INSERT	CRITICAL	PCI-DSS	5	t	\N	2026-05-10 18:17:57.209372+03	2026-05-10 18:17:57.209372+03
44	HIPAA: Alert PHI table access	all	ALERT	table_name	patient|medical_record|phi|health_data|diagnosis|prescription	HIGH	HIPAA	15	t	\N	2026-05-10 18:17:57.209372+03	2026-05-10 18:17:57.209372+03
45	HIPAA: Block after-hours SA access	all	BLOCK	time_range	00:00-06:00	HIGH	HIPAA	10	t	\N	2026-05-10 18:17:57.209372+03	2026-05-10 18:17:57.209372+03
46	GDPR: Alert PII column SELECT	all	ALERT	query_pattern	ssn|social_security|passport|credit_card|card_number|date_of_birth	MEDIUM	GDPR	20	t	\N	2026-05-10 18:17:57.209372+03	2026-05-10 18:17:57.209372+03
47	GDPR: Block DROP on PII tables	all	BLOCK	query_pattern	^\\s*DROP\\s+(TABLE|DATABASE|SCHEMA)	CRITICAL	GDPR	5	t	\N	2026-05-10 18:17:57.209372+03	2026-05-10 18:17:57.209372+03
48	SOC2: Alert sysadmin/DBA activity	all	ALERT	role	sysadmin|db_owner|DBA|SYSDBA|rdsadmin|sa	MEDIUM	SOC2	30	t	\N	2026-05-10 18:17:57.209372+03	2026-05-10 18:17:57.209372+03
49	PCI-DSS: Block anonymous logins	all	BLOCK	user	anonymous|guest|public	HIGH	PCI-DSS	10	t	\N	2026-05-10 18:20:29.933418+03	2026-05-10 18:20:29.933418+03
50	PCI-DSS: Alert bulk SELECT (>1000)	all	ALERT	query_pattern	SELECT.{0,300}(TOP\\s+[1-9]\\d{3,}|LIMIT\\s+[1-9]\\d{3,}|FETCH\\s+FIRST\\s+[1-9]\\d{3,})	HIGH	PCI-DSS	20	t	\N	2026-05-10 18:20:29.933418+03	2026-05-10 18:20:29.933418+03
51	PCI-DSS: Block SELECT INTO OUTFILE	all	BLOCK	query_pattern	INTO\\s+OUTFILE|INTO\\s+DUMPFILE|xp_cmdshell|OPENROWSET|BULK\\s+INSERT	CRITICAL	PCI-DSS	5	t	\N	2026-05-10 18:20:29.933418+03	2026-05-10 18:20:29.933418+03
52	HIPAA: Alert PHI table access	all	ALERT	table_name	patient|medical_record|phi|health_data|diagnosis|prescription	HIGH	HIPAA	15	t	\N	2026-05-10 18:20:29.933418+03	2026-05-10 18:20:29.933418+03
53	HIPAA: Block after-hours SA access	all	BLOCK	time_range	00:00-06:00	HIGH	HIPAA	10	t	\N	2026-05-10 18:20:29.933418+03	2026-05-10 18:20:29.933418+03
54	GDPR: Alert PII column SELECT	all	ALERT	query_pattern	ssn|social_security|passport|credit_card|card_number|date_of_birth	MEDIUM	GDPR	20	t	\N	2026-05-10 18:20:29.933418+03	2026-05-10 18:20:29.933418+03
55	GDPR: Block DROP on PII tables	all	BLOCK	query_pattern	^\\s*DROP\\s+(TABLE|DATABASE|SCHEMA)	CRITICAL	GDPR	5	t	\N	2026-05-10 18:20:29.933418+03	2026-05-10 18:20:29.933418+03
56	SOC2: Alert sysadmin/DBA activity	all	ALERT	role	sysadmin|db_owner|DBA|SYSDBA|rdsadmin|sa	MEDIUM	SOC2	30	t	\N	2026-05-10 18:20:29.933418+03	2026-05-10 18:20:29.933418+03
\.
INSERT INTO config.firewall_policies (policy_id, policy_name, vendor, action, condition_type, condition_value, severity, regulation, priority, is_active, created_by, created_at, updated_at)
SELECT policy_id, policy_name, vendor, action, condition_type, condition_value, severity, regulation, priority, is_active, created_by, created_at, updated_at FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM config.firewall_policies);
DROP TABLE _stg_load;

SELECT setval('config.firewall_policies_policy_id_seq', GREATEST((SELECT COALESCE(max(policy_id),0) FROM config.firewall_policies),1), (SELECT count(*) FROM config.firewall_policies) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'firewall_policies'
          AND con.conname = 'firewall_policies_pkey') THEN
        ALTER TABLE ONLY config.firewall_policies
    ADD CONSTRAINT firewall_policies_pkey PRIMARY KEY (policy_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_fw_policies_active_vendor ON config.firewall_policies USING btree (is_active, vendor, priority);
