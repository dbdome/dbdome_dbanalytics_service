-- ============================================================
-- View: monitoring.v_dbanalytics_alert   (correctly-spelled successor of
-- monitoring.v_dbanalyitcs_alert created in 6400)
--
-- Used by alerts/alert_helper.py::manage_diagnosys_alerts() to fetch, per
-- root cause, everything the diagnosis-evidence dispatch needs in one query:
--   * the alert row (server, issue_id, root_cause_id, evidence query,
--     mainstat numeric result, risk_level) -- same semantics as
--     rootcause.v_root_cause_alerts
--   * the ingest-API coordinates (api_url, api_key via the server's
--     organization) and server identity (server_id, db_vendor, port) needed
--     by server_upsert() / send_results()
--
-- Organization joins are LEFT joins so alerts for servers without an
-- organization mapping still appear (api columns NULL -> callers skip send).
--
-- The misspelled 6400 view is kept until no deployed build references it.
-- ============================================================

DROP VIEW IF EXISTS monitoring.v_dbanalytics_alert;

CREATE OR REPLACE VIEW monitoring.v_dbanalytics_alert AS
SELECT DISTINCT
    raqrs.server,
    rc.issue_id,
    rc.root_cause_id,
    raq.query_resultset AS query,
    raqrs.query_result  AS mainstat,
    rc.risk_level,
    o.api_url,
    o.api_key,
    s.server_id,
    s.db_vendor,
    s.port
FROM rootcause.v_rootcauses rc
JOIN rootcause.rootcause_alert_query raq
  ON raq.root_cause_id = rc.root_cause_id::text
JOIN rootcause.rootcause_alert_query_result_server raqrs
  ON raqrs.root_cause_id = rc.root_cause_id::text
JOIN metrics.servers s
  ON s.server = raqrs.server
LEFT JOIN processes.organizations_servers os
  ON os.server_row_id = s.row_id
LEFT JOIN processes.organization o
  ON o.row_id = os.organization_id
WHERE lower(rc.vendor_name::text) = lower(s.db_vendor)
   OR lower(rc.vendor_name::text) = 'sqlserver'::text;
