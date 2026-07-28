-- ============================================================
-- Index: alerts.alert_log (entry_date)
-- Speeds up time-range filtering / ordering of the alert log.
-- Idempotent (IF NOT EXISTS); runs after 0100_alerts_log.sql
-- creates the table. Re-applied by sql_script_runner only if
-- this file's checksum changes.
-- ============================================================

CREATE INDEX IF NOT EXISTS ix_entry_date ON alerts.alert_log (entry_date);
