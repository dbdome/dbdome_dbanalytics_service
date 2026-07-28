-- =============================================================================
-- 6660_alert_log_metric_result_row_id.sql
--
-- Link alerts.alert_log back to the monitoring.general_metric_metadata_results row
-- the alert came from (same idea as alerts.blocks / alerts.mail_alert_log, which
-- already carry metric_result_row_id). The app_login_guard and ransomware_guard
-- processes populate it from the collected metric-result row id.
-- =============================================================================

ALTER TABLE alerts.alert_log ADD COLUMN IF NOT EXISTS metric_result_row_id bigint;
COMMENT ON COLUMN alerts.alert_log.metric_result_row_id IS
    'id of the source monitoring.general_metric_metadata_results row that produced this alert';
