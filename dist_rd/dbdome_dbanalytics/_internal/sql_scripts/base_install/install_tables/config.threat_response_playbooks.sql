-- Idempotent install for config.threat_response_playbooks
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.threat_response_playbooks_playbook_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.threat_response_playbooks (
    playbook_id integer NOT NULL,
    playbook_name character varying(200) NOT NULL,
    description text,
    trigger_type character varying(50) NOT NULL,
    trigger_threshold integer DEFAULT 70 NOT NULL,
    trigger_regulation character varying(50),
    trigger_severity character varying(20),
    response_type character varying(50) NOT NULL,
    response_params jsonb DEFAULT '{}'::jsonb NOT NULL,
    cooldown_mins integer DEFAULT 60 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE config.threat_response_playbooks ALTER COLUMN playbook_id SET DEFAULT nextval('config.threat_response_playbooks_playbook_id_seq'::regclass);
ALTER SEQUENCE config.threat_response_playbooks_playbook_id_seq OWNED BY config.threat_response_playbooks.playbook_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE config.threat_response_playbooks);
COPY _stg_load (playbook_id, playbook_name, description, trigger_type, trigger_threshold, trigger_regulation, trigger_severity, response_type, response_params, cooldown_mins, is_active, created_at) FROM stdin;
1	Critical risk user: escalate	Create security incident when a user reaches critical risk (score ≥ 90)	high_risk_user	90	\N	\N	ESCALATE	{"severity": "CRITICAL"}	120	t	2026-05-09 16:52:08.503488+03
2	High risk user: notify security	Email security team when a user sustained risk ≥ 70	high_risk_user	70	\N	\N	NOTIFY	{"subject_prefix": "[GRC-ALERT] High-risk database user"}	60	t	2026-05-09 16:52:08.503488+03
3	High consecutive risk: suspend user	Auto-suspend user when consecutive_high_risk ≥ 5 (30 min)	high_risk_user	70	\N	\N	SUSPEND_USER	{"reason": "Automated: consecutive high-risk sessions", "duration_mins": 30}	240	t	2026-05-09 16:52:08.503488+03
4	CRITICAL blocked event: escalate	Create incident on any CRITICAL-severity BLOCKED audit event	blocked_event	1	\N	\N	ESCALATE	{"severity": "CRITICAL"}	30	t	2026-05-09 16:52:08.503488+03
5	Repeated BLOCK from same IP: block IP	Auto-block a client IP after 5 BLOCKED events in 10 minutes (60-min block)	ip_attack	5	\N	\N	BLOCK_IP	{"reason": "Automated: repeated blocked events", "duration_mins": 60}	120	t	2026-05-09 16:52:08.503488+03
6	PCI-DSS breach: notify	Notify on any PCI-DSS BLOCKED or ALERTED event	regulation_breach	1	\N	\N	NOTIFY	{"regulation": "PCI-DSS", "subject_prefix": "[PCI-DSS BREACH]"}	30	t	2026-05-09 16:52:08.503488+03
7	HIPAA breach: notify	Notify on any HIPAA BLOCKED or ALERTED event	regulation_breach	1	\N	\N	NOTIFY	{"regulation": "HIPAA", "subject_prefix": "[HIPAA BREACH]"}	30	t	2026-05-09 16:52:08.503488+03
\.
INSERT INTO config.threat_response_playbooks (playbook_id, playbook_name, description, trigger_type, trigger_threshold, trigger_regulation, trigger_severity, response_type, response_params, cooldown_mins, is_active, created_at)
SELECT playbook_id, playbook_name, description, trigger_type, trigger_threshold, trigger_regulation, trigger_severity, response_type, response_params, cooldown_mins, is_active, created_at FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM config.threat_response_playbooks);
DROP TABLE _stg_load;

SELECT setval('config.threat_response_playbooks_playbook_id_seq', GREATEST((SELECT COALESCE(max(playbook_id),0) FROM config.threat_response_playbooks),1), (SELECT count(*) FROM config.threat_response_playbooks) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'threat_response_playbooks'
          AND con.conname = 'threat_response_playbooks_pkey') THEN
        ALTER TABLE ONLY config.threat_response_playbooks
    ADD CONSTRAINT threat_response_playbooks_pkey PRIMARY KEY (playbook_id);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'threat_response_playbooks'
          AND con.conname = 'threat_response_playbooks_playbook_name_key') THEN
        ALTER TABLE ONLY config.threat_response_playbooks
    ADD CONSTRAINT threat_response_playbooks_playbook_name_key UNIQUE (playbook_name);
    END IF;
END $do$;
