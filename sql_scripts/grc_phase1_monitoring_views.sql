-- GRC Phase 1: Monitoring views consumed by grc_firewall_scanner.py
-- These normalise existing monitoring tables into a uniform schema
-- that the scanner can query regardless of vendor.
-- Adjust column mappings if your monitoring.metric_results columns differ.

-- ──────────────────────────────────────────────────────────────
-- 1. Recent active sessions (all vendors)
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW monitoring.v_recent_active_sessions AS
SELECT
    mr.server_name,
    m.vendor,
    mr.string_value_1   AS db_user,
    mr.string_value_2   AS client_ip,
    mr.string_value_3   AS db_name,
    mr.string_value_4   AS sql_text,
    mr.string_value_5   AS session_id,
    mr.collected_at
FROM   monitoring.metric_results mr
JOIN   metrics.metrics            m  ON m.metric_id = mr.metric_id
WHERE  m.category IN ('active_sessions', 'active_transactions', 'stat_activity')
AND    mr.collected_at >= NOW() - INTERVAL '2 minutes';

-- ──────────────────────────────────────────────────────────────
-- 2. Recent SQL injection events
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW monitoring.v_recent_sql_injection AS
SELECT
    mr.server_name,
    m.vendor,
    mr.string_value_1   AS db_user,
    mr.string_value_2   AS client_ip,
    mr.string_value_3   AS db_name,
    mr.string_value_4   AS sql_text,
    mr.collected_at
FROM   monitoring.metric_results mr
JOIN   metrics.metrics            m  ON m.metric_id = mr.metric_id
WHERE  m.category = 'sql_injection'
AND    mr.collected_at >= NOW() - INTERVAL '2 minutes';

-- ──────────────────────────────────────────────────────────────
-- 3. Recent privileged login events
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW monitoring.v_recent_privileged_logins AS
SELECT
    mr.server_name,
    m.vendor,
    mr.string_value_1   AS db_user,
    mr.string_value_2   AS client_ip,
    mr.string_value_3   AS db_name,
    mr.string_value_4   AS role_name,
    mr.collected_at
FROM   monitoring.metric_results mr
JOIN   metrics.metrics            m  ON m.metric_id = mr.metric_id
WHERE  m.category IN ('privileged_logins', 'privileged_access')
AND    mr.collected_at >= NOW() - INTERVAL '2 minutes';

-- ──────────────────────────────────────────────────────────────
-- 4. Register the GRC firewall scanner as a scheduled process
--    (60-second interval — evaluates last 70 seconds of activity)
-- ──────────────────────────────────────────────────────────────
INSERT INTO metrics.registered_processes (process_name, interval, is_active, description)
VALUES ('grc_firewall_scan', 60, TRUE, 'GRC Phase 1: firewall policy evaluation and audit logging')
ON CONFLICT (process_name) DO UPDATE
    SET interval   = EXCLUDED.interval,
        is_active  = EXCLUDED.is_active,
        description = EXCLUDED.description;
