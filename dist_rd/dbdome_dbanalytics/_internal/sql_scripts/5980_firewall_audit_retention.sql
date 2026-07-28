-- 5980: configurable retention (DAYS) for the high-volume log.firewall_audit_log.
-- gmmr_maintain prunes rows older than this. Default 90 days. Adjust the value to
-- change the window (shows on the Configuration dashboard's Global Parameters).
INSERT INTO config.global_params (key, value)
SELECT 'firewall_audit_retention_days', '90'
WHERE NOT EXISTS (SELECT 1 FROM config.global_params WHERE key = 'firewall_audit_retention_days');
