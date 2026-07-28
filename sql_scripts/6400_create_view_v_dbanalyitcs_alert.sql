-- ============================================================
-- View: monitoring.v_dbanalyitcs_alert
--
-- MISSING-VIEW FIX: alerts/alert_helper.py::manage_diagnosys_alerts() selects
--   server, issue_id, root_cause_id, query, mainstat, risk_level
-- FROM monitoring.v_dbanalyitcs_alert, but the view was never created --
-- causing ~88k "relation does not exist" errors per day and breaking the
-- diagnosis-evidence branch of alert dispatch.
--
-- NOTE: the view name is intentionally spelled "dbanalyitcs" to match the
-- deployed code. If the code is ever corrected to "dbanalytics", rename the
-- view (or create the corrected name) in the same release.
--
-- Semantics mirror rootcause.v_root_cause_alerts (same joins/vendor filter):
--   query    = rootcause_alert_query.query_resultset  (evidence resultset SQL,
--              executed against the catalog DB by manage_diagnosys_alerts)
--   mainstat = rootcause_alert_query_result_server.query_result (numeric alert
--              value per server, same source as execute_numeric_query)
-- ============================================================

DROP VIEW IF EXISTS monitoring.v_dbanalyitcs_alert;

CREATE OR REPLACE VIEW monitoring.v_dbanalyitcs_alert AS
SELECT DISTINCT
    raqrs.server,
    rc.issue_id,
    rc.root_cause_id,
    raq.query_resultset AS query,
    raqrs.query_result  AS mainstat,
    rc.risk_level
FROM rootcause.v_rootcauses rc
JOIN rootcause.rootcause_alert_query raq
  ON raq.root_cause_id = rc.root_cause_id::text
JOIN rootcause.rootcause_alert_query_result_server raqrs
  ON raqrs.root_cause_id = rc.root_cause_id::text
JOIN metrics.servers s
  ON s.server = raqrs.server
WHERE lower(rc.vendor_name::text) = lower(s.db_vendor)
   OR lower(rc.vendor_name::text) = 'sqlserver'::text;
