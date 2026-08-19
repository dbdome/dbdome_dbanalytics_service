-- =============================================================================
-- 7510_ldap_ad_sync.sql
-- Scheduled Active Directory -> Grafana synchronisation (processes/ldap_group_sync.py).
--
-- WHY
--   Grafana OSS has no background LDAP sync (active_sync_enabled is Enterprise).
--   It resolves group -> org role only inside the login handler, so a user who has
--   never logged in does not exist in Grafana, and an AD group change lands at that
--   user's NEXT login. This adds the missing reconciler: on a timer, enumerate the
--   users matched by config.ldap_settings.group_mappings and push them into Grafana
--   through its admin HTTP API.
--
-- Adds to config.ldap_settings (7400):
--   sync_enabled       master switch for the scheduled sync (login-time LDAP is
--                      unaffected by it and keeps working either way)
--   sync_dry_run       DEFAULT TRUE - logs what it would do, writes nothing.
--                      Deliberately opt-OUT: the first run of a directory sync on a
--                      real estate should never be the one that changes access.
--   sync_deprovision   none | viewer | remove | disable - what happens to a Grafana
--                      user who no longer matches any mapping. Default 'none':
--                      removing access is a policy decision, not a default.
--   grafana_url        admin API base (default the local instance)
--   grafana_token      service-account token, enc:v1: - the PREFERRED credential
--   grafana_admin_user/_password  basic-auth fallback, password enc:v1:
--   last_sync_at / last_sync_result / last_sync_error  for the /ldap_settings page
--
-- Idempotent.
-- =============================================================================

ALTER TABLE config.ldap_settings
    ADD COLUMN IF NOT EXISTS sync_enabled            boolean     NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS sync_dry_run            boolean     NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS sync_deprovision        text        NOT NULL DEFAULT 'none',
    ADD COLUMN IF NOT EXISTS grafana_url             text        NOT NULL DEFAULT 'http://127.0.0.1:3000',
    ADD COLUMN IF NOT EXISTS grafana_token           text        NULL,
    ADD COLUMN IF NOT EXISTS grafana_admin_user      text        NULL,
    ADD COLUMN IF NOT EXISTS grafana_admin_password  text        NULL,
    ADD COLUMN IF NOT EXISTS last_sync_at            timestamptz NULL,
    ADD COLUMN IF NOT EXISTS last_sync_result        jsonb       NULL,
    ADD COLUMN IF NOT EXISTS last_sync_error         text        NULL;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ldap_settings_deprovision_chk') THEN
        ALTER TABLE config.ldap_settings
            ADD CONSTRAINT ldap_settings_deprovision_chk
            CHECK (sync_deprovision IN ('none', 'viewer', 'remove', 'disable'));
    END IF;
END $$;

COMMENT ON COLUMN config.ldap_settings.sync_dry_run IS
  'TRUE = the scheduled AD sync only logs what it would do. Default TRUE on purpose: the first run against a real directory must not be the one that changes who can log in.';
COMMENT ON COLUMN config.ldap_settings.sync_deprovision IS
  'What happens to a Grafana user no longer matched by any group mapping: none (leave alone), viewer (downgrade), remove (drop from org), disable (disable the account). Never applies to admin/dbdome_user.';
COMMENT ON COLUMN config.ldap_settings.grafana_token IS
  'Grafana service-account token (enc:v1:) with Admin role - preferred over admin basic auth, and revocable without changing the admin password.';

-- Register the process. is_active=false: it is switched on from /ldap_settings once
-- a Grafana credential is configured. The 30s config_watcher picks the change up
-- without a service restart.
INSERT INTO metrics.registered_processes (process_name, is_active, interval, description)
SELECT 'ldap_group_sync', false, 600,
       'Replicate AD users/groups into Grafana (create users, apply org role + admin flag from group_mappings, optional deprovision). Fills the gap left by Grafana OSS having no background LDAP sync.'
WHERE NOT EXISTS (SELECT 1 FROM metrics.registered_processes WHERE process_name = 'ldap_group_sync');

-- -----------------------------------------------------------------------------
-- ENABLING IT (in this order)
--   1) create a Grafana service account with the Admin role, mint a token, then:
--        UPDATE config.ldap_settings
--           SET grafana_token = <enc:v1: via utils.secrets_crypto.encrypt_secret>
--         WHERE row_id = 1;
--   2) UPDATE config.ldap_settings SET sync_enabled = true WHERE row_id = 1;
--      -- still dry-run; watch a full cycle:
--      SELECT entry_date, message FROM log.operation_log
--       WHERE routine_name = 'run_ldap_group_sync' ORDER BY entry_date DESC LIMIT 20;
--   3) UPDATE metrics.registered_processes SET is_active = true
--       WHERE process_name = 'ldap_group_sync';
--   4) only when the dry-run log matches expectations:
--      UPDATE config.ldap_settings SET sync_dry_run = false WHERE row_id = 1;
--   5) deprovisioning is separate and last:
--      UPDATE config.ldap_settings SET sync_deprovision = 'viewer' WHERE row_id = 1;
-- -----------------------------------------------------------------------------
