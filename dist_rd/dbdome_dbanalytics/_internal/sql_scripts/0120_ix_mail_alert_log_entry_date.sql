-- ============================================================
-- Index: alerts.mail_alert_log (entry_date)
-- Speeds up time-range filtering / ordering of the mail alert log.
-- NOTE: index names are unique PER SCHEMA in Postgres, and
-- 'ix_entry_date' is already used by alerts.alert_log — so this
-- index is named ix_mail_alert_log_entry_date to avoid a silent
-- IF-NOT-EXISTS no-op collision.
-- Idempotent (IF NOT EXISTS). Re-applied by sql_script_runner
-- only if this file's checksum changes.
-- ============================================================

CREATE INDEX IF NOT EXISTS ix_mail_alert_log_entry_date ON alerts.mail_alert_log (entry_date);
