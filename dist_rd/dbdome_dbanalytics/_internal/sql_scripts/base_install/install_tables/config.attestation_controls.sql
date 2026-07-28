-- Idempotent install for config.attestation_controls
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.attestation_controls_control_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.attestation_controls (
    control_id integer NOT NULL,
    control_name character varying(300) NOT NULL,
    control_description text,
    regulation character varying(50) NOT NULL,
    clause_reference character varying(100),
    attestation_frequency character varying(20) DEFAULT 'QUARTERLY'::character varying NOT NULL,
    owner_email character varying(400),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE config.attestation_controls ALTER COLUMN control_id SET DEFAULT nextval('config.attestation_controls_control_id_seq'::regclass);
ALTER SEQUENCE config.attestation_controls_control_id_seq OWNED BY config.attestation_controls.control_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE config.attestation_controls);
COPY _stg_load (control_id, control_name, control_description, regulation, clause_reference, attestation_frequency, owner_email, is_active, created_at) FROM stdin;
1	Access Control Review	Quarterly review of privileged access rights	SOC2	CC6.1	QUARTERLY	\N	t	2026-05-10 21:23:53.776973+03
2	Encryption at Rest	Verify encryption enabled on all sensitive data stores	SOC2	CC6.7	SEMI_ANNUAL	\N	t	2026-05-10 21:23:53.776973+03
3	Audit Log Integrity	Confirm audit logs are complete and tamper-evident	SOC2	CC7.2	QUARTERLY	\N	t	2026-05-10 21:23:53.776973+03
4	Change Management Review	Review all schema/DDL changes in the period	SOX	404	QUARTERLY	\N	t	2026-05-10 21:23:53.776973+03
5	Segregation of Duties	Confirm no user holds conflicting entitlements	SOX	302	QUARTERLY	\N	t	2026-05-10 21:23:53.776973+03
6	Financial Data Access	Review who can read/modify financial tables	SOX	404	SEMI_ANNUAL	\N	t	2026-05-10 21:23:53.776973+03
7	Cardholder Data Scope	Confirm PCI-DSS scope of cardholder data environment	PCI-DSS	Req 1.2	QUARTERLY	\N	t	2026-05-10 21:23:53.776973+03
8	Vulnerability Remediation	Verify critical vulnerabilities remediated within SLA	PCI-DSS	Req 6.3	QUARTERLY	\N	t	2026-05-10 21:23:53.776973+03
9	Data Retention Compliance	Confirm GDPR retention schedules enforced	GDPR	Art. 5(e)	SEMI_ANNUAL	\N	t	2026-05-10 21:23:53.776973+03
10	DSAR Response Timeliness	Confirm data subject requests handled within 30 days	GDPR	Art. 15	QUARTERLY	\N	t	2026-05-10 21:23:53.776973+03
11	Cross-Border Transfer Basis	Verify legal basis for all cross-border data transfers	GDPR	Art. 44	SEMI_ANNUAL	\N	t	2026-05-10 21:23:53.776973+03
12	PHI Access Audit	Review all access to Protected Health Information tables	HIPAA	164.312	QUARTERLY	\N	t	2026-05-10 21:23:53.776973+03
13	Minimum Necessary Access	Confirm users access only minimum necessary PHI	HIPAA	164.514	ANNUAL	\N	t	2026-05-10 21:23:53.776973+03
\.
INSERT INTO config.attestation_controls (control_id, control_name, control_description, regulation, clause_reference, attestation_frequency, owner_email, is_active, created_at)
SELECT control_id, control_name, control_description, regulation, clause_reference, attestation_frequency, owner_email, is_active, created_at FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM config.attestation_controls);
DROP TABLE _stg_load;

SELECT setval('config.attestation_controls_control_id_seq', GREATEST((SELECT COALESCE(max(control_id),0) FROM config.attestation_controls),1), (SELECT count(*) FROM config.attestation_controls) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'attestation_controls'
          AND con.conname = 'attestation_controls_control_name_regulation_key') THEN
        ALTER TABLE ONLY config.attestation_controls
    ADD CONSTRAINT attestation_controls_control_name_regulation_key UNIQUE (control_name, regulation);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'attestation_controls'
          AND con.conname = 'attestation_controls_pkey') THEN
        ALTER TABLE ONLY config.attestation_controls
    ADD CONSTRAINT attestation_controls_pkey PRIMARY KEY (control_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_attestation_controls_regulation ON config.attestation_controls USING btree (regulation, is_active);
