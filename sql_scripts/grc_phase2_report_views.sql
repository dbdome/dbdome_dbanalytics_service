-- GRC Phase 2: Compliance report views + schedule table
-- Run after grc_phase1_schema.sql

-- ──────────────────────────────────────────────────────────────
-- 1. Report schedule configuration table
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS config.compliance_report_schedules (
    schedule_id     SERIAL          PRIMARY KEY,
    regulation      VARCHAR(50)     NOT NULL,   -- PCI-DSS|HIPAA|GDPR|SOC2|ALL
    report_name     VARCHAR(200)    NOT NULL,
    frequency       VARCHAR(20)     NOT NULL DEFAULT 'daily',  -- daily|weekly|monthly
    lookback_days   INTEGER         NOT NULL DEFAULT 1,
    recipients      TEXT            NOT NULL,   -- comma-separated email list
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    last_run_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

INSERT INTO config.compliance_report_schedules
    (regulation, report_name, frequency, lookback_days, recipients)
VALUES
    ('PCI-DSS', 'PCI-DSS Daily Audit Report',   'daily',  1,  'security@dbdome.com'),
    ('HIPAA',   'HIPAA Daily Audit Report',      'daily',  1,  'security@dbdome.com'),
    ('GDPR',    'GDPR Weekly Compliance Report', 'weekly', 7,  'security@dbdome.com'),
    ('SOC2',    'SOC2 Weekly Compliance Report', 'weekly', 7,  'security@dbdome.com')
ON CONFLICT DO NOTHING;

-- ──────────────────────────────────────────────────────────────
-- 2. PCI-DSS report sections
-- ──────────────────────────────────────────────────────────────

-- Req 10.2: Summary by day and action
CREATE OR REPLACE VIEW log.v_rpt_pcidss_daily_summary AS
SELECT  DATE(event_time)          AS report_date,
        action_taken,
        COUNT(*)                  AS event_count,
        COUNT(DISTINCT db_user)   AS unique_users,
        COUNT(DISTINCT server_name) AS servers_affected,
        MAX(risk_score)           AS max_risk_score
FROM    log.firewall_audit_log
WHERE   regulation = 'PCI-DSS'
GROUP BY DATE(event_time), action_taken
ORDER BY report_date DESC, event_count DESC;

-- Req 10.2: Blocked events detail
CREATE OR REPLACE VIEW log.v_rpt_pcidss_blocked AS
SELECT  event_time,
        server_name,
        vendor,
        db_user,
        client_ip,
        db_name,
        LEFT(sql_statement, 300) AS sql_preview,
        risk_score
FROM    log.firewall_audit_log
WHERE   regulation = 'PCI-DSS'
AND     action_taken = 'BLOCKED'
ORDER BY event_time DESC;

-- Req 8.3: Privileged access (all alerted/blocked)
CREATE OR REPLACE VIEW log.v_rpt_pcidss_privileged_access AS
SELECT  event_time,
        server_name,
        db_user,
        client_ip,
        action_taken,
        risk_score
FROM    log.firewall_audit_log
WHERE   regulation IN ('PCI-DSS', 'SOC2')
AND     action_taken IN ('ALERTED', 'BLOCKED')
ORDER BY risk_score DESC, event_time DESC;

-- Req 6.4: SQL injection events
CREATE OR REPLACE VIEW log.v_rpt_pcidss_sqli AS
SELECT  event_time,
        server_name,
        vendor,
        db_user,
        client_ip,
        LEFT(sql_statement, 400) AS sql_preview,
        action_taken,
        risk_score
FROM    log.firewall_audit_log
WHERE   regulation = 'PCI-DSS'
AND     sql_statement ~* 'UNION|SELECT.*FROM.*WHERE|xp_cmdshell|INTO OUTFILE|SLEEP\(|BENCHMARK\('
ORDER BY event_time DESC;

-- ──────────────────────────────────────────────────────────────
-- 3. HIPAA report sections
-- ──────────────────────────────────────────────────────────────

-- §164.312(b): PHI access audit
CREATE OR REPLACE VIEW log.v_rpt_hipaa_phi_access AS
SELECT  event_time,
        server_name,
        vendor,
        db_user,
        client_ip,
        db_name,
        LEFT(sql_statement, 300) AS sql_preview,
        action_taken,
        risk_score
FROM    log.firewall_audit_log
WHERE   regulation = 'HIPAA'
ORDER BY event_time DESC;

-- §164.312(b): Access by user (access frequency)
CREATE OR REPLACE VIEW log.v_rpt_hipaa_user_access_freq AS
SELECT  db_user,
        server_name,
        COUNT(*)                AS total_accesses,
        SUM(CASE WHEN action_taken = 'BLOCKED' THEN 1 ELSE 0 END) AS blocked,
        MAX(risk_score)         AS max_risk,
        MIN(event_time)         AS first_access,
        MAX(event_time)         AS last_access
FROM    log.firewall_audit_log
WHERE   regulation = 'HIPAA'
GROUP BY db_user, server_name
ORDER BY total_accesses DESC;

-- §164.312(a): After-hours blocked access
CREATE OR REPLACE VIEW log.v_rpt_hipaa_afterhours AS
SELECT  event_time,
        server_name,
        db_user,
        client_ip,
        action_taken,
        risk_score
FROM    log.firewall_audit_log
WHERE   regulation = 'HIPAA'
AND     action_taken = 'BLOCKED'
AND     EXTRACT(HOUR FROM event_time AT TIME ZONE 'localtime') BETWEEN 0 AND 5
ORDER BY event_time DESC;

-- ──────────────────────────────────────────────────────────────
-- 4. GDPR report sections
-- ──────────────────────────────────────────────────────────────

-- Art.30: Records of processing activities
CREATE OR REPLACE VIEW log.v_rpt_gdpr_processing_log AS
SELECT  DATE(event_time)        AS activity_date,
        server_name,
        db_name,
        db_user,
        action_taken,
        COUNT(*)                AS access_count,
        MAX(risk_score)         AS max_risk_score
FROM    log.firewall_audit_log
WHERE   regulation = 'GDPR'
GROUP BY DATE(event_time), server_name, db_name, db_user, action_taken
ORDER BY activity_date DESC, access_count DESC;

-- Art.32: High-risk PII access events
CREATE OR REPLACE VIEW log.v_rpt_gdpr_high_risk AS
SELECT  event_time,
        server_name,
        vendor,
        db_user,
        client_ip,
        db_name,
        LEFT(sql_statement, 300) AS sql_preview,
        action_taken,
        risk_score
FROM    log.firewall_audit_log
WHERE   regulation = 'GDPR'
AND     risk_score >= 70
ORDER BY risk_score DESC, event_time DESC;

-- Art.32: DDL operations blocked (DROP/ALTER on PII tables)
CREATE OR REPLACE VIEW log.v_rpt_gdpr_ddl_blocked AS
SELECT  event_time,
        server_name,
        db_user,
        client_ip,
        LEFT(sql_statement, 400) AS sql_preview,
        risk_score
FROM    log.firewall_audit_log
WHERE   regulation = 'GDPR'
AND     action_taken = 'BLOCKED'
AND     sql_statement ~* '^\s*(DROP|ALTER|TRUNCATE)\s+'
ORDER BY event_time DESC;

-- ──────────────────────────────────────────────────────────────
-- 5. SOC2 report sections
-- ──────────────────────────────────────────────────────────────

-- CC6.3: Logical access monitoring
CREATE OR REPLACE VIEW log.v_rpt_soc2_logical_access AS
SELECT  event_time,
        server_name,
        vendor,
        db_user,
        client_ip,
        db_name,
        action_taken,
        risk_score
FROM    log.firewall_audit_log
WHERE   regulation = 'SOC2'
ORDER BY risk_score DESC, event_time DESC;

-- CC7.2: Policy violation summary
CREATE OR REPLACE VIEW log.v_rpt_soc2_policy_violations AS
SELECT  fp.policy_name,
        fp.severity,
        fp.regulation,
        COUNT(al.audit_id)          AS violation_count,
        COUNT(DISTINCT al.db_user)  AS unique_users,
        COUNT(DISTINCT al.server_name) AS servers,
        MAX(al.event_time)          AS last_seen
FROM    log.firewall_audit_log al
JOIN    config.firewall_policies fp ON fp.policy_id = al.matched_policy
WHERE   al.action_taken IN ('BLOCKED', 'ALERTED')
GROUP BY fp.policy_name, fp.severity, fp.regulation
ORDER BY violation_count DESC;

-- CC6: Privileged users activity
CREATE OR REPLACE VIEW log.v_rpt_soc2_privileged_users AS
SELECT  db_user,
        server_name,
        COUNT(*)                    AS total_events,
        SUM(CASE WHEN action_taken = 'BLOCKED' THEN 1 ELSE 0 END) AS blocked_count,
        MAX(risk_score)             AS max_risk,
        MAX(event_time)             AS last_activity
FROM    log.firewall_audit_log
WHERE   regulation = 'SOC2'
GROUP BY db_user, server_name
ORDER BY total_events DESC;
