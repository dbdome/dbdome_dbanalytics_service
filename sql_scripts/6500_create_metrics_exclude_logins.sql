-- =============================================================================
-- 6500_create_metrics_exclude_logins.sql
-- metrics.exclude_logins: logins whose activity DBDOME treats as self-activity.
-- The hot-path filter (analysis/self_activity_filter.py) loads this table into
-- its TTL cache; every generic collector drops collected transaction rows whose
-- login_name is here BEFORE they reach gmmr / alerts.
-- Seeded with the service's own monitoring login. Idempotent.
-- =============================================================================
CREATE TABLE IF NOT EXISTS metrics.exclude_logins (
    row_id     serial PRIMARY KEY,
    login_name text NOT NULL UNIQUE,
    is_active  boolean NOT NULL DEFAULT true,
    entry_date timestamp without time zone NOT NULL DEFAULT now()
);

INSERT INTO metrics.exclude_logins (login_name)
SELECT v.login FROM (VALUES ('dbdome_mon_usr')) v(login)
WHERE NOT EXISTS (SELECT 1 FROM metrics.exclude_logins e WHERE e.login_name = v.login);
