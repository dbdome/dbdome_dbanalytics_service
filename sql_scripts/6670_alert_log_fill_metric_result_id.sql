-- =============================================================================
-- 6670_alert_log_fill_metric_result_id.sql
--
-- Populate alerts.alert_log.metric_result_row_id on EVERY insert. The many
-- collector paths (collection/*/monitoring_metrics_*_generic_query.py), the
-- anomaly agent and other inserters do not set it, and they bulk-insert the
-- metric results so the id is not readily available at the alert insert. A
-- BEFORE INSERT trigger fills it from the most recent
-- monitoring.general_metric_metadata_results row for the same (server,
-- root_cause_id) -- but only when the inserter did not already set it, so the
-- guards (app_login_guard / ransomware_guard), whose source metric_name differs
-- from the alert's root_cause_id, keep their exact explicit id.
--
-- Fast: ix_gmmr_server_metric_date covers (server, metric_name, entry_date).
-- =============================================================================

CREATE OR REPLACE FUNCTION alerts.trg_alert_log_fill_metric_result_id()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF NEW.metric_result_row_id IS NULL THEN
        NEW.metric_result_row_id := (
            SELECT g.id
            FROM monitoring.general_metric_metadata_results g
            WHERE g.server = NEW.server
              AND g.metric_name = NEW.root_cause_id
            ORDER BY g.entry_date DESC, g.id DESC
            LIMIT 1);
    END IF;
    RETURN NEW;
END $function$;

DROP TRIGGER IF EXISTS trg_alert_log_fill_metric_result_id ON alerts.alert_log;
CREATE TRIGGER trg_alert_log_fill_metric_result_id
    BEFORE INSERT ON alerts.alert_log
    FOR EACH ROW EXECUTE FUNCTION alerts.trg_alert_log_fill_metric_result_id();
