-- =============================================================================
-- 6540_fix_risk_level_case_and_alert_gate.sql
--
-- 1) RISK-LEVEL CASE BUG (severe, silent).
--    rootcause.resolution_steps stores risk_level in mixed case: 250 rows say
--    'Critical', 15 say 'critical'. Every consumer compares against
--    rootcause.risk_level / rootcause.severity, which hold LOWERCASE values, and
--    the vendor collectors INNER JOIN on it:
--
--        JOIN rootcause.risk_level rl ON rl.risk_level = rc.risk_level
--
--    'Critical' <> 'critical', so those root causes are dropped from the
--    collection set and their detection query is NEVER RUN. Verified against the
--    live estate: all 25 capital-'Critical' root causes have ZERO rows in
--    monitoring.general_metric_metadata_results over 30 days — they have never
--    executed. They are the highest-value attack detections:
--
--        SEC-SQL-AUD-009-*  SQL Injection Runtime Indicators
--        SEC-SQL-AUD-010-*  Database Reconnaissance Activity
--        SEC-SQL-AUD-011-*  Audit and Log Tampering        (attacker covering tracks)
--        SEC-SQL-AUD-012-*  Long-Running Uncommitted Transactions
--        SEC-SQL-AUD-013-*  Security Configuration Change During Activity
--
--    Normalise to lowercase, then constrain the column so it cannot regress.
--
-- 2) ALERT GATE. config.webook_alerts is the (domain, risk) matrix.
--    Security/high currently has send_siem_alert = false, so high-severity
--    security findings (unencrypted personal data, excessive privileges on PII,
--    weak authentication) reach mail but NEVER reach the SIEM. Enable it.
--
-- 3) rootcause.severity gates manage_alerts(); only 'critical' was enabled, so
--    every high-severity finding was discarded by that path. Enable 'high'.
--    medium/low stay disabled deliberately — they are the noise floor.
-- =============================================================================

-- 1) normalise the case ------------------------------------------------------
UPDATE rootcause.resolution_steps
   SET risk_level = lower(trim(risk_level))
 WHERE risk_level IS NOT NULL
   AND risk_level <> lower(trim(risk_level));

-- make the bug unrepeatable
ALTER TABLE rootcause.resolution_steps
  DROP CONSTRAINT IF EXISTS resolution_steps_risk_level_lowercase;
ALTER TABLE rootcause.resolution_steps
  ADD CONSTRAINT resolution_steps_risk_level_lowercase
  CHECK (risk_level IS NULL OR risk_level = lower(trim(risk_level)))
  NOT VALID;   -- NOT VALID: don't re-scan the whole table; new/updated rows are checked

-- same guard on the sibling table, which is clean today but shares the vocabulary
UPDATE rootcause.resolution_paths
   SET risk_level = lower(trim(risk_level))
 WHERE risk_level IS NOT NULL
   AND risk_level <> lower(trim(risk_level));

-- 2) let high-severity SECURITY findings reach the SIEM -----------------------
UPDATE config.webook_alerts
   SET send_siem_alert = true
 WHERE trim(lower(metric_type)) = 'security'
   AND trim(lower(risk_level))  = 'high'
   AND is_active IS TRUE;

-- 3) un-silence 'high' in the manage_alerts() severity gate -------------------
UPDATE rootcause.severity
   SET is_enabled = true
 WHERE trim(lower(severity)) = 'high';
