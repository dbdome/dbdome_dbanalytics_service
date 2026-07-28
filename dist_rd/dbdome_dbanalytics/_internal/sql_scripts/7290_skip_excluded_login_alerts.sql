-- =============================================================================
-- 7290_skip_excluded_login_alerts.sql
-- Guarantee: NO alert is raised for a login listed in metrics.exclude_logins.
--
-- alerts.alert_log is written from >10 paths (every vendor generic-query
-- collector + app_login_guard + ransomware_guard + sensitive-access/anomaly
-- analysis). Rather than trust each writer to filter, this BEFORE INSERT trigger
-- enforces the exclusion centrally at the single table every alert must pass
-- through: if the row's login_name matches an excluded login (case-insensitive,
-- trimmed - identical to the collector-side exclude semantics) the INSERT is
-- skipped, so no alert row and therefore no incident (trg_alert_incident_upsert
-- fires AFTER INSERT and never sees the skipped row) are created.
--
-- Rows with no login_name (host/service-level alerts, e.g. internal_health_monitor)
-- are unaffected. Idempotent (CREATE OR REPLACE + DROP TRIGGER IF EXISTS).
-- metrics.exclude_logins is tiny, so the per-row EXISTS check is negligible.
-- =============================================================================

CREATE OR REPLACE FUNCTION alerts.fn_skip_excluded_login_alerts()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.login_name IS NOT NULL
       AND btrim(NEW.login_name) <> ''
       AND EXISTS (
            SELECT 1 FROM metrics.exclude_logins e
            WHERE lower(btrim(e.login_name)) = lower(btrim(NEW.login_name))
       )
    THEN
        RETURN NULL;   -- excluded login -> skip the INSERT (no alert, no incident)
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_skip_excluded_login_alerts ON alerts.alert_log;
DROP TRIGGER IF EXISTS trg_00_skip_excluded_login_alerts ON alerts.alert_log;

-- Name sorts before the other BEFORE-INSERT trigger (trg_alert_log_fill_...) so
-- the exclusion is evaluated first and skipped rows do no further work.
CREATE TRIGGER trg_00_skip_excluded_login_alerts
    BEFORE INSERT ON alerts.alert_log
    FOR EACH ROW
    EXECUTE FUNCTION alerts.fn_skip_excluded_login_alerts();
