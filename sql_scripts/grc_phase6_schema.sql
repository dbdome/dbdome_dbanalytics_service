-- GRC Phase 6: Automated Threat Response
-- Run after grc_phase1_schema.sql

-- ──────────────────────────────────────────────────────────────
-- 1. Response playbooks
--    Each row defines: when to trigger + what response to execute
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS config.threat_response_playbooks (
    playbook_id         SERIAL          PRIMARY KEY,
    playbook_name       VARCHAR(200)    NOT NULL UNIQUE,
    description         TEXT,
    -- Trigger conditions
    trigger_type        VARCHAR(50)     NOT NULL,    -- high_risk_user|blocked_event|regulation_breach|ip_attack
    trigger_threshold   INTEGER         NOT NULL DEFAULT 70,  -- risk score (for high_risk_user) or event count (for others)
    trigger_regulation  VARCHAR(50),                -- filter to a specific regulation (NULL = any)
    trigger_severity    VARCHAR(20),                -- filter to severity level (NULL = any)
    -- Response
    response_type       VARCHAR(50)     NOT NULL,    -- NOTIFY|BLOCK_IP|SUSPEND_USER|ESCALATE|WEBHOOK
    response_params     JSONB           NOT NULL DEFAULT '{}',
        -- NOTIFY:       {"recipients": "a@b.com,c@d.com", "subject_prefix": "ALERT"}
        -- BLOCK_IP:     {"duration_mins": 60, "reason": "Auto-blocked"}
        -- SUSPEND_USER: {"duration_mins": 30, "reason": "Auto-suspended"}
        -- ESCALATE:     {"severity": "HIGH"}
        -- WEBHOOK:      {"url": "https://hooks.slack.com/..."}
    cooldown_mins       INTEGER         NOT NULL DEFAULT 60,   -- min gap between triggers for the same subject
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- ──────────────────────────────────────────────────────────────
-- 2. Immutable response log
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS log.threat_response_log (
    response_id         BIGSERIAL       PRIMARY KEY,
    triggered_at        TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    playbook_id         INTEGER,
    playbook_name       VARCHAR(200),
    trigger_type        VARCHAR(50),
    subject             VARCHAR(400),   -- the IP / user / server that triggered
    response_type       VARCHAR(50),
    response_detail     JSONB,
    success             BOOLEAN         NOT NULL DEFAULT TRUE,
    error_message       TEXT
);

CREATE INDEX IF NOT EXISTS idx_threat_response_log_triggered_at
    ON log.threat_response_log (triggered_at DESC);

CREATE INDEX IF NOT EXISTS idx_threat_response_log_subject
    ON log.threat_response_log (subject, triggered_at DESC);

-- ──────────────────────────────────────────────────────────────
-- 3. Dynamic IP blocklist
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS config.blocked_ips (
    block_id            SERIAL          PRIMARY KEY,
    ip_address          INET            NOT NULL,
    reason              TEXT,
    blocked_by          VARCHAR(100)    NOT NULL DEFAULT 'threat_response',
    blocked_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    expires_at          TIMESTAMPTZ,                -- NULL = permanent
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    UNIQUE (ip_address)
);

CREATE INDEX IF NOT EXISTS idx_blocked_ips_active
    ON config.blocked_ips (ip_address) WHERE is_active = TRUE;

-- ──────────────────────────────────────────────────────────────
-- 4. Suspended user accounts
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS config.suspended_users (
    suspension_id       SERIAL          PRIMARY KEY,
    server_name         VARCHAR(200)    NOT NULL,
    login_name          VARCHAR(200)    NOT NULL,
    reason              TEXT,
    suspended_by        VARCHAR(100)    NOT NULL DEFAULT 'threat_response',
    suspended_at        TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    expires_at          TIMESTAMPTZ,                -- NULL = permanent
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    UNIQUE (server_name, login_name)
);

CREATE INDEX IF NOT EXISTS idx_suspended_users_active
    ON config.suspended_users (server_name, login_name) WHERE is_active = TRUE;

-- ──────────────────────────────────────────────────────────────
-- 5. Security incidents (ESCALATE target)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS log.security_incidents (
    incident_id         SERIAL          PRIMARY KEY,
    title               VARCHAR(500)    NOT NULL,
    severity            VARCHAR(20)     NOT NULL DEFAULT 'HIGH',
    regulation          VARCHAR(50),
    server_name         VARCHAR(200),
    db_user             VARCHAR(200),
    client_ip           VARCHAR(50),
    description         TEXT,
    status              VARCHAR(20)     NOT NULL DEFAULT 'OPEN',  -- OPEN|ACKNOWLEDGED|RESOLVED
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    resolved_at         TIMESTAMPTZ,
    resolved_by         VARCHAR(100)
);

CREATE INDEX IF NOT EXISTS idx_security_incidents_status
    ON log.security_incidents (status, created_at DESC);

-- ──────────────────────────────────────────────────────────────
-- 6. Seed default playbooks
-- ──────────────────────────────────────────────────────────────
INSERT INTO config.threat_response_playbooks
    (playbook_name, description, trigger_type, trigger_threshold,
     response_type, response_params, cooldown_mins)
VALUES
    ('Critical risk user: escalate',
     'Create security incident when a user reaches critical risk (score ≥ 90)',
     'high_risk_user', 90,
     'ESCALATE',
     '{"severity": "CRITICAL"}',
     120),

    ('High risk user: notify security',
     'Email security team when a user sustained risk ≥ 70',
     'high_risk_user', 70,
     'NOTIFY',
     '{"subject_prefix": "[GRC-ALERT] High-risk database user"}',
     60),

    ('High consecutive risk: suspend user',
     'Auto-suspend user when consecutive_high_risk ≥ 5 (30 min)',
     'high_risk_user', 70,
     'SUSPEND_USER',
     '{"duration_mins": 30, "reason": "Automated: consecutive high-risk sessions"}',
     240),

    ('CRITICAL blocked event: escalate',
     'Create incident on any CRITICAL-severity BLOCKED audit event',
     'blocked_event', 1,
     'ESCALATE',
     '{"severity": "CRITICAL"}',
     30),

    ('Repeated BLOCK from same IP: block IP',
     'Auto-block a client IP after 5 BLOCKED events in 10 minutes (60-min block)',
     'ip_attack', 5,
     'BLOCK_IP',
     '{"duration_mins": 60, "reason": "Automated: repeated blocked events"}',
     120),

    ('PCI-DSS breach: notify',
     'Notify on any PCI-DSS BLOCKED or ALERTED event',
     'regulation_breach', 1,
     'NOTIFY',
     '{"subject_prefix": "[PCI-DSS BREACH]", "regulation": "PCI-DSS"}',
     30),

    ('HIPAA breach: notify',
     'Notify on any HIPAA BLOCKED or ALERTED event',
     'regulation_breach', 1,
     'NOTIFY',
     '{"subject_prefix": "[HIPAA BREACH]", "regulation": "HIPAA"}',
     30)

ON CONFLICT (playbook_name) DO NOTHING;

-- ──────────────────────────────────────────────────────────────
-- 7. Useful views
-- ──────────────────────────────────────────────────────────────

-- Active threats overview
CREATE OR REPLACE VIEW log.v_active_threats AS
SELECT
    i.incident_id,
    i.title,
    i.severity,
    i.regulation,
    i.server_name,
    i.db_user,
    i.client_ip,
    i.status,
    i.created_at
FROM log.security_incidents i
WHERE i.status IN ('OPEN', 'ACKNOWLEDGED')
ORDER BY
    CASE i.severity WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 ELSE 4 END,
    i.created_at DESC;

-- Response activity (last 24h)
CREATE OR REPLACE VIEW log.v_response_activity_24h AS
SELECT
    DATE_TRUNC('hour', triggered_at) AS hour,
    response_type,
    COUNT(*) AS response_count,
    SUM(CASE WHEN success THEN 1 ELSE 0 END) AS successes,
    SUM(CASE WHEN NOT success THEN 1 ELSE 0 END) AS failures
FROM log.threat_response_log
WHERE triggered_at >= NOW() - INTERVAL '24 hours'
GROUP BY 1, 2
ORDER BY 1 DESC, 2;

-- Blocked IPs (currently active)
CREATE OR REPLACE VIEW config.v_blocked_ips_active AS
SELECT
    block_id, ip_address::text, reason, blocked_by, blocked_at,
    expires_at,
    CASE WHEN expires_at IS NULL THEN 'Permanent'
         ELSE EXTRACT(EPOCH FROM (expires_at - NOW()))::int || 's remaining'
    END AS remaining
FROM config.blocked_ips
WHERE is_active = TRUE
  AND (expires_at IS NULL OR expires_at > NOW())
ORDER BY blocked_at DESC;

-- Suspended users (currently active)
CREATE OR REPLACE VIEW config.v_suspended_users_active AS
SELECT
    suspension_id, server_name, login_name, reason, suspended_by, suspended_at,
    expires_at,
    CASE WHEN expires_at IS NULL THEN 'Permanent'
         ELSE EXTRACT(EPOCH FROM (expires_at - NOW()))::int || 's remaining'
    END AS remaining
FROM config.suspended_users
WHERE is_active = TRUE
  AND (expires_at IS NULL OR expires_at > NOW())
ORDER BY suspended_at DESC;

-- ──────────────────────────────────────────────────────────────
-- 8. Register job in scheduler
-- ──────────────────────────────────────────────────────────────
INSERT INTO metrics.registered_processes (process_name, interval, is_active, description)
VALUES ('run_threat_response', 60, TRUE,
        'GRC Phase 6: automated threat response engine (runs every 60s)')
ON CONFLICT (process_name) DO UPDATE
    SET interval    = EXCLUDED.interval,
        is_active   = EXCLUDED.is_active,
        description = EXCLUDED.description;
