-- Idempotent install for config.compliance_report_schedules
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.compliance_report_schedules_schedule_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.compliance_report_schedules (
    schedule_id integer NOT NULL,
    regulation character varying(50) NOT NULL,
    report_name character varying(200) NOT NULL,
    frequency character varying(20) DEFAULT 'daily'::character varying NOT NULL,
    lookback_days integer DEFAULT 1 NOT NULL,
    recipients text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    last_run_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE config.compliance_report_schedules ALTER COLUMN schedule_id SET DEFAULT nextval('config.compliance_report_schedules_schedule_id_seq'::regclass);
ALTER SEQUENCE config.compliance_report_schedules_schedule_id_seq OWNED BY config.compliance_report_schedules.schedule_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE config.compliance_report_schedules);
COPY _stg_load (schedule_id, regulation, report_name, frequency, lookback_days, recipients, is_active, last_run_at, created_at) FROM stdin;
3	GDPR	GDPR Weekly Compliance Report	weekly	7	security@dbdome.com	t	\N	2026-05-09 16:51:10.025708+03
4	SOC2	SOC2 Weekly Compliance Report	weekly	7	security@dbdome.com	t	\N	2026-05-09 16:51:10.025708+03
7	GDPR	GDPR Weekly Compliance Report	weekly	7	security@dbdome.com	t	\N	2026-05-10 18:16:01.430598+03
8	SOC2	SOC2 Weekly Compliance Report	weekly	7	security@dbdome.com	t	\N	2026-05-10 18:16:01.430598+03
11	GDPR	GDPR Weekly Compliance Report	weekly	7	security@dbdome.com	t	\N	2026-05-10 18:17:29.255692+03
12	SOC2	SOC2 Weekly Compliance Report	weekly	7	security@dbdome.com	t	\N	2026-05-10 18:17:29.255692+03
15	GDPR	GDPR Weekly Compliance Report	weekly	7	security@dbdome.com	t	\N	2026-05-10 18:18:21.337415+03
16	SOC2	SOC2 Weekly Compliance Report	weekly	7	security@dbdome.com	t	\N	2026-05-10 18:18:21.337415+03
1	PCI-DSS	PCI-DSS Daily Audit Report	daily	1	security@dbdome.com	t	2026-05-27 20:37:04.465624+03	2026-05-09 16:51:10.025708+03
2	HIPAA	HIPAA Daily Audit Report	daily	1	security@dbdome.com	t	2026-05-27 20:37:25.966067+03	2026-05-09 16:51:10.025708+03
5	PCI-DSS	PCI-DSS Daily Audit Report	daily	1	security@dbdome.com	t	2026-05-27 20:37:57.611939+03	2026-05-10 18:16:01.430598+03
6	HIPAA	HIPAA Daily Audit Report	daily	1	security@dbdome.com	t	2026-05-27 20:38:28.060229+03	2026-05-10 18:16:01.430598+03
9	PCI-DSS	PCI-DSS Daily Audit Report	daily	1	security@dbdome.com	t	2026-05-27 20:38:47.297168+03	2026-05-10 18:17:29.255692+03
10	HIPAA	HIPAA Daily Audit Report	daily	1	security@dbdome.com	t	2026-05-27 20:39:20.934152+03	2026-05-10 18:17:29.255692+03
13	PCI-DSS	PCI-DSS Daily Audit Report	daily	1	security@dbdome.com	t	2026-05-27 20:39:43.498593+03	2026-05-10 18:18:21.337415+03
14	HIPAA	HIPAA Daily Audit Report	daily	1	security@dbdome.com	t	2026-05-27 20:40:12.434862+03	2026-05-10 18:18:21.337415+03
\.
INSERT INTO config.compliance_report_schedules (schedule_id, regulation, report_name, frequency, lookback_days, recipients, is_active, last_run_at, created_at)
SELECT schedule_id, regulation, report_name, frequency, lookback_days, recipients, is_active, last_run_at, created_at FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM config.compliance_report_schedules);
DROP TABLE _stg_load;

SELECT setval('config.compliance_report_schedules_schedule_id_seq', GREATEST((SELECT COALESCE(max(schedule_id),0) FROM config.compliance_report_schedules),1), (SELECT count(*) FROM config.compliance_report_schedules) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'compliance_report_schedules'
          AND con.conname = 'compliance_report_schedules_pkey') THEN
        ALTER TABLE ONLY config.compliance_report_schedules
    ADD CONSTRAINT compliance_report_schedules_pkey PRIMARY KEY (schedule_id);
    END IF;
END $do$;
