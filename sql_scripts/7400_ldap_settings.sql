-- =============================================================================
-- 7400_ldap_settings.sql
-- LDAP / Active Directory login for the DBDOME Grafana UI: config storage.
--
-- Single-row table (row_id=1 enforced) holding everything the /ldap_settings
-- page edits. The web service renders it into Grafana's ldap.toml + patches
-- custom.ini [auth.ldap] on "Apply" (utils/ldap_settings.py), then restarts
-- the DBDOME_Grafana service. Authentication itself is done BY GRAFANA against
-- the customer's directory - this table only feeds the config files.
--
-- bind_password is stored encrypted (enc:v1: Fernet, utils/secrets_crypto -
-- key in the service .env, outside any DB backup), same scheme as
-- metrics.servers passwords. root_ca_cert holds the PEM text of the
-- customer's CA chain for LDAPS/StartTLS; written to <conf>/ldap_ca.crt at
-- apply time.
--
-- group_mappings jsonb: [{"group_dn": "CN=DBAs,OU=...,DC=...",
--                         "org_role": "Admin|Editor|Viewer",
--                         "grafana_admin": false}, ...]
-- Order matters (first match wins in Grafana).
--
-- Idempotent (IF NOT EXISTS + ON CONFLICT DO NOTHING); guarded owner re-assert.
-- =============================================================================

CREATE TABLE IF NOT EXISTS config.ldap_settings
(
    row_id               smallint    NOT NULL DEFAULT 1 PRIMARY KEY CHECK (row_id = 1),
    enabled              boolean     NOT NULL DEFAULT false,
    host                 text        NOT NULL DEFAULT '',
    port                 integer     NOT NULL DEFAULT 636,
    encryption           text        NOT NULL DEFAULT 'ldaps'
                         CHECK (encryption IN ('none', 'ldaps', 'starttls')),
    ssl_skip_verify      boolean     NOT NULL DEFAULT false,
    root_ca_cert         text        NULL,
    bind_dn              text        NOT NULL DEFAULT '',
    bind_password        text        NULL,               -- enc:v1: ciphertext
    search_base_dns      text        NOT NULL DEFAULT '',-- one DN per line
    search_filter        text        NOT NULL DEFAULT '(sAMAccountName=%s)',
    group_search_base_dns text       NULL,               -- one DN per line (optional)
    attr_username        text        NOT NULL DEFAULT 'sAMAccountName',
    attr_name            text        NOT NULL DEFAULT 'givenName',
    attr_surname         text        NOT NULL DEFAULT 'sn',
    attr_email           text        NOT NULL DEFAULT 'mail',
    attr_member_of       text        NOT NULL DEFAULT 'memberOf',
    group_mappings       jsonb       NOT NULL DEFAULT '[]'::jsonb,
    updated_at           timestamptz NOT NULL DEFAULT now(),
    applied_at           timestamptz NULL                -- last successful Apply
);

INSERT INTO config.ldap_settings (row_id) VALUES (1)
ON CONFLICT (row_id) DO NOTHING;

COMMENT ON TABLE config.ldap_settings IS
  'LDAP/AD login config for the Grafana UI - rendered to ldap.toml + custom.ini [auth.ldap] by the /ldap_settings Apply action. bind_password is enc:v1: Fernet ciphertext.';

-- Guarded owner re-assert (same pattern as the numbered series: script may run
-- as postgres on a fresh install or as dbdome_adm on upgrade).
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_adm') THEN
        EXECUTE 'ALTER TABLE config.ldap_settings OWNER TO dbdome_adm';
    END IF;
END $$;
