-- Idempotent install for config.sod_rules
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.sod_rules_rule_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.sod_rules (
    rule_id integer NOT NULL,
    rule_name character varying(200) NOT NULL,
    description text,
    privilege_a character varying(200) NOT NULL,
    privilege_b character varying(200) NOT NULL,
    object_scope character varying(200),
    severity character varying(20) DEFAULT 'HIGH'::character varying NOT NULL,
    regulation character varying(50),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE config.sod_rules ALTER COLUMN rule_id SET DEFAULT nextval('config.sod_rules_rule_id_seq'::regclass);
ALTER SEQUENCE config.sod_rules_rule_id_seq OWNED BY config.sod_rules.rule_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE config.sod_rules);
COPY _stg_load (rule_id, rule_name, description, privilege_a, privilege_b, object_scope, severity, regulation, is_active, created_at) FROM stdin;
1	DBA + Auditor conflict	DBA role should not also hold audit/reporting access	db_owner	audit_reader	\N	HIGH	SOC2	t	2026-05-10 22:39:31.335215+03
2	Payment writer + approver	Cannot write to payments table and approve payments	INSERT on payments	EXECUTE on approve_payment	\N	CRITICAL	PCI-DSS	t	2026-05-10 22:39:31.335215+03
3	Sysadmin + application login	SA/sysadmin account also used as application login	sysadmin	app_login	\N	HIGH	SOC2	t	2026-05-10 22:39:31.335215+03
4	Sensitive read + schema alter	User can read PII data and also alter table structures	SELECT on sensitive	ALTER TABLE	\N	HIGH	GDPR	t	2026-05-10 22:39:31.335215+03
\.
INSERT INTO config.sod_rules (rule_id, rule_name, description, privilege_a, privilege_b, object_scope, severity, regulation, is_active, created_at)
SELECT rule_id, rule_name, description, privilege_a, privilege_b, object_scope, severity, regulation, is_active, created_at FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM config.sod_rules);
DROP TABLE _stg_load;

SELECT setval('config.sod_rules_rule_id_seq', GREATEST((SELECT COALESCE(max(rule_id),0) FROM config.sod_rules),1), (SELECT count(*) FROM config.sod_rules) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'sod_rules'
          AND con.conname = 'sod_rules_pkey') THEN
        ALTER TABLE ONLY config.sod_rules
    ADD CONSTRAINT sod_rules_pkey PRIMARY KEY (rule_id);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'sod_rules'
          AND con.conname = 'sod_rules_rule_name_key') THEN
        ALTER TABLE ONLY config.sod_rules
    ADD CONSTRAINT sod_rules_rule_name_key UNIQUE (rule_name);
    END IF;
END $do$;
