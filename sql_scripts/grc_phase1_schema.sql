-- GRC Phase 1: Firewall policy engine + immutable audit log
-- Run once against the dbanalytics database (EDB AS 17, port 5444)

-- ──────────────────────────────────────────────────────────────
-- 1. Firewall policy definitions
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS config.firewall_policies (
    policy_id       SERIAL          PRIMARY KEY,
    policy_name     VARCHAR(200)    NOT NULL,
    vendor          VARCHAR(50)     NOT NULL DEFAULT 'all',  -- mssql|postgres|mysql|oracle|mariadb|informix|all
    action          VARCHAR(20)     NOT NULL,                -- ALLOW|BLOCK|ALERT|MASK
    condition_type  VARCHAR(50)     NOT NULL,                -- user|role|ip|query_pattern|table_name|schema_name|time_range
    condition_value TEXT            NOT NULL,
    severity        VARCHAR(20)     NOT NULL DEFAULT 'MEDIUM', -- LOW|MEDIUM|HIGH|CRITICAL
    regulation      VARCHAR(50),                             -- PCI-DSS|HIPAA|GDPR|SOC2|internal
    priority        INTEGER         NOT NULL DEFAULT 100,    -- lower = evaluated first
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_by      VARCHAR(100),
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fw_policies_active_vendor
    ON config.firewall_policies (is_active, vendor, priority);

-- ──────────────────────────────────────────────────────────────
-- 2. Immutable audit trail (append-only — never UPDATE/DELETE)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS log.firewall_audit_log (
    audit_id        BIGSERIAL       PRIMARY KEY,
    event_time      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    server_name     VARCHAR(200),
    vendor          VARCHAR(50),
    db_user         VARCHAR(200),
    client_ip       VARCHAR(50),
    db_name         VARCHAR(200),
    sql_statement   TEXT,
    matched_policy  INTEGER         REFERENCES config.firewall_policies (policy_id),
    action_taken    VARCHAR(20)     NOT NULL,   -- ALLOWED|BLOCKED|ALERTED|MASKED
    regulation      VARCHAR(50),
    session_id      VARCHAR(100),
    risk_score      INTEGER         NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_fw_audit_event_time
    ON log.firewall_audit_log (event_time DESC);

CREATE INDEX IF NOT EXISTS idx_fw_audit_server_user
    ON log.firewall_audit_log (server_name, db_user, event_time DESC);

CREATE INDEX IF NOT EXISTS idx_fw_audit_action
    ON log.firewall_audit_log (action_taken, event_time DESC);

-- ──────────────────────────────────────────────────────────────
-- 3. Regulation → policy mapping
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS config.regulation_profiles (
    profile_id      SERIAL          PRIMARY KEY,
    regulation      VARCHAR(50)     NOT NULL UNIQUE,  -- PCI-DSS|HIPAA|GDPR|SOC2
    description     TEXT,
    policy_ids      INTEGER[]       NOT NULL DEFAULT '{}'
);

-- ──────────────────────────────────────────────────────────────
-- 4. Seed: built-in regulation profiles
-- ──────────────────────────────────────────────────────────────
INSERT INTO config.regulation_profiles (regulation, description) VALUES
  ('PCI-DSS', 'Payment Card Industry Data Security Standard'),
  ('HIPAA',   'Health Insurance Portability and Accountability Act'),
  ('GDPR',    'General Data Protection Regulation'),
  ('SOC2',    'Service Organization Control 2')
ON CONFLICT (regulation) DO NOTHING;

-- ──────────────────────────────────────────────────────────────
-- 5. Seed: default policies per regulation
-- ──────────────────────────────────────────────────────────────

-- PCI-DSS Req 8: block anonymous / guest logins
INSERT INTO config.firewall_policies
  (policy_name, vendor, action, condition_type, condition_value, severity, regulation, priority)
VALUES
  ('PCI-DSS: Block anonymous logins',    'all', 'BLOCK', 'user', 'anonymous|guest|public', 'HIGH',     'PCI-DSS', 10),
  ('PCI-DSS: Alert bulk SELECT (>1000)', 'all', 'ALERT', 'query_pattern', 'SELECT.{0,300}(TOP\s+[1-9]\d{3,}|LIMIT\s+[1-9]\d{3,}|FETCH\s+FIRST\s+[1-9]\d{3,})', 'HIGH', 'PCI-DSS', 20),
  ('PCI-DSS: Block SELECT INTO OUTFILE', 'all', 'BLOCK', 'query_pattern', 'INTO\s+OUTFILE|INTO\s+DUMPFILE|xp_cmdshell|OPENROWSET|BULK\s+INSERT', 'CRITICAL', 'PCI-DSS', 5),

-- HIPAA §164.312: alert on access to PHI tables
  ('HIPAA: Alert PHI table access',      'all', 'ALERT', 'table_name',    'patient|medical_record|phi|health_data|diagnosis|prescription', 'HIGH', 'HIPAA', 15),
  ('HIPAA: Block after-hours SA access', 'all', 'BLOCK', 'time_range',    '00:00-06:00', 'HIGH', 'HIPAA', 10),

-- GDPR Art.32: alert on sensitive personal data queries
  ('GDPR: Alert PII column SELECT',      'all', 'ALERT', 'query_pattern', 'ssn|social_security|passport|credit_card|card_number|date_of_birth', 'MEDIUM', 'GDPR', 20),
  ('GDPR: Block DROP on PII tables',     'all', 'BLOCK', 'query_pattern', '^\s*DROP\s+(TABLE|DATABASE|SCHEMA)', 'CRITICAL', 'GDPR', 5),

-- SOC2 CC6: alert privileged role activity
  ('SOC2: Alert sysadmin/DBA activity',  'all', 'ALERT', 'role',          'sysadmin|db_owner|DBA|SYSDBA|rdsadmin|sa', 'MEDIUM', 'SOC2', 30)

ON CONFLICT DO NOTHING;

-- ──────────────────────────────────────────────────────────────
-- 6. Reporting views
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW log.v_pci_dss_audit AS
SELECT  audit_id, event_time, server_name, vendor, db_user, client_ip,
        db_name, LEFT(sql_statement,500) AS sql_preview,
        action_taken, risk_score
FROM    log.firewall_audit_log
WHERE   regulation = 'PCI-DSS'
ORDER BY event_time DESC;

CREATE OR REPLACE VIEW log.v_hipaa_audit AS
SELECT  audit_id, event_time, server_name, vendor, db_user, client_ip,
        db_name, LEFT(sql_statement,500) AS sql_preview,
        action_taken, risk_score
FROM    log.firewall_audit_log
WHERE   regulation = 'HIPAA'
ORDER BY event_time DESC;

CREATE OR REPLACE VIEW log.v_gdpr_audit AS
SELECT  audit_id, event_time, server_name, vendor, db_user, client_ip,
        db_name, LEFT(sql_statement,500) AS sql_preview,
        action_taken, risk_score
FROM    log.firewall_audit_log
WHERE   regulation = 'GDPR'
ORDER BY event_time DESC;

CREATE OR REPLACE VIEW log.v_soc2_audit AS
SELECT  audit_id, event_time, server_name, vendor, db_user, client_ip,
        db_name, LEFT(sql_statement,500) AS sql_preview,
        action_taken, risk_score
FROM    log.firewall_audit_log
WHERE   regulation = 'SOC2'
ORDER BY event_time DESC;

CREATE OR REPLACE VIEW log.v_blocked_events AS
SELECT  audit_id, event_time, server_name, vendor, db_user, client_ip,
        db_name, LEFT(sql_statement,500) AS sql_preview,
        matched_policy, regulation, risk_score
FROM    log.firewall_audit_log
WHERE   action_taken = 'BLOCKED'
ORDER BY event_time DESC;
