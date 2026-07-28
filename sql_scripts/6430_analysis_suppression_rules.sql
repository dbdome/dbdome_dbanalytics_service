-- ============================================================
-- 6430  analysis.suppression_rules  -  self-activity / false-alarm filter
--
-- Some DBDOME detection queries are pure STATE inventories (e.g. "list every
-- non-DBMS-maintained user with their roles/privileges"). They ALWAYS return
-- rows, so a `row_count > 0` expected-condition ALWAYS matches -> the result is
-- stored in monitoring.general_metric_metadata_results AND raised as an alert
-- every collection cycle. That is a permanent FALSE ALARM: it is DBDOME reading
-- the catalog, not genuine sensitive-data usage or an incident.
--
-- This table lets an analyst (or the analysis/self_activity_agent.py Claude
-- reviewer) mark such (metric, query) combinations as "self-activity /
-- benign inventory". The vendor generic-query collectors consult it
-- (analysis.self_activity_filter.is_self_activity) and, on a match, SKIP both
-- the gmmr insert and the alert for that metric.
--
-- match_mode:
--   'query'            - suppress when the collected query fingerprint matches
--                        sample_query (whitespace/case/comment-insensitive)
--   'metric'           - suppress an entire metric_name (all its queries)
--   'query_and_metric' - both must match (most conservative)
-- vendor_slug / metric_name are optional scopes (NULL = any).
--
-- The filter fingerprints sample_query itself (normalises whitespace/case/
-- comments), so this script only stores the RAW query text - no hash here.
-- Idempotent.
-- ============================================================
BEGIN;

CREATE SCHEMA IF NOT EXISTS analysis;

CREATE TABLE IF NOT EXISTS analysis.suppression_rules (
    id            bigserial PRIMARY KEY,
    rule_name     text NOT NULL,
    match_mode    text NOT NULL DEFAULT 'query'
                  CHECK (match_mode IN ('query','metric','query_and_metric')),
    vendor_slug   text,
    metric_name   text,
    sample_query  text,
    reason        text NOT NULL,
    created_by    text NOT NULL DEFAULT 'analyst',
    is_active     boolean NOT NULL DEFAULT true,
    created_at    timestamp NOT NULL DEFAULT now(),
    updated_at    timestamp NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_suppression_rules_active
    ON analysis.suppression_rules (is_active, vendor_slug, metric_name);

-- Uniqueness guard so re-running the seed does not duplicate the rule.
CREATE UNIQUE INDEX IF NOT EXISTS ux_suppression_rules_rule_name
    ON analysis.suppression_rules (rule_name);

-- Retire the earlier per-vendor-query name if a prior run created it.
DELETE FROM analysis.suppression_rules WHERE rule_name = 'oracle-authz-user-privilege-inventory';

-- ---- SEED: the privilege/authorization inventory (SEC-SQL-AUTHZ-001-RC01) ----
-- This root cause is a pure STATE inventory (lists every non-maintained user
-- with their roles/privileges) for EVERY vendor - oracle, sqlserver, mysql,
-- mariadb, postgresql. It always returns rows, so it always "matches" and
-- alerts every cycle: a permanent false alarm. Suppress the whole metric
-- (match_mode='metric', vendor NULL = all vendors) rather than one vendor's
-- exact query text. sample_query is kept for documentation only.
INSERT INTO analysis.suppression_rules
    (rule_name, match_mode, vendor_slug, metric_name, sample_query, reason, created_by, is_active)
VALUES (
    'authz-user-privilege-inventory',
    'metric',
    NULL,
    'SEC-SQL-AUTHZ-001-RC01',
    $q$SELECT sys_context('USERENV','SERVER_HOST') AS server, sys_context('USERENV','DB_NAME') AS database_name, u.username AS login_name, u.username AS database_user, 'USER' AS principal_type, (SELECT LISTAGG(rp.granted_role, ', ') WITHIN GROUP (ORDER BY rp.granted_role) FROM dba_role_privs rp WHERE rp.grantee = u.username) AS roles, (SELECT LISTAGG(sp.privilege, ', ') WITHIN GROUP (ORDER BY sp.privilege) FROM dba_sys_privs sp WHERE sp.grantee = u.username) AS permissions, u.account_status AS login_status FROM dba_users u WHERE u.oracle_maintained = 'N' ORDER BY u.username$q$,
    'DBDOME self-introspection: DBDOME''s own privilege/authorization inventory detection (SEC-SQL-AUTHZ-001-RC01) for every vendor - lists every non-DBMS-maintained user/login with their roles and system privileges. A STATE inventory that always returns rows, so its row_count>0 condition always matches and it alerts every cycle. It reflects DBDOME reading the data dictionary, NOT actual sensitive-data usage or an incident - a false alarm. Suppressed from storage and alerting for all vendors.',
    'analyst',
    true
)
ON CONFLICT (rule_name) DO UPDATE SET
    match_mode = EXCLUDED.match_mode, vendor_slug = EXCLUDED.vendor_slug,
    metric_name = EXCLUDED.metric_name, sample_query = EXCLUDED.sample_query,
    reason = EXCLUDED.reason, is_active = EXCLUDED.is_active, updated_at = now();

-- ---- VERIFY ----
SELECT id, rule_name, match_mode, vendor_slug, metric_name, is_active
  FROM analysis.suppression_rules ORDER BY id;

COMMIT;
