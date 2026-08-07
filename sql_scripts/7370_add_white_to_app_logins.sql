-- =============================================================================
-- 7370_add_white_to_app_logins.sql
--
-- Add the `white` whitelist flag to metrics.app_logins (base table created by
-- 6630_app_login_guard.sql). white=true marks an applicative login as an
-- APPROVED account.
--
-- app_login_guard now raises SEC-SQL-ACC-030-RC01 (and kills the session, still
-- gated by blocker_dry_run) for a session on a WATCHED program
-- (metrics.programs) whose login_name is NOT in the whitelist (app_logins where
-- white=true) -- and only when the Security/critical 'blocker' switch is enabled
-- in config.webook_alerts.
--
-- Idempotent (ADD COLUMN IF NOT EXISTS). Default true so existing rows keep
-- behaving as approved applicative logins until an admin changes them.
-- =============================================================================

ALTER TABLE metrics.app_logins
    ADD COLUMN IF NOT EXISTS white boolean DEFAULT true;

COMMENT ON COLUMN metrics.app_logins.white IS
    'Whitelist flag: true = approved applicative login. app_login_guard alerts on watched-program sessions whose login_name is NOT whitelisted (white=true).';
