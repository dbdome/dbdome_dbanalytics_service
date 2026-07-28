-- =============================================================================
-- 6550_alert_incident_lifecycle.sql
-- Customer-facing alert lifecycle: open -> resolved (manual by a customer user,
-- with a description) OR auto-resolved after a configurable time.
--
-- WHY A SEPARATE TABLE (not columns on alerts.alert_log):
--   alerts.alert_log is deduplicated to ONE row per (server, root_cause_id) per
--   HOUR — every collector DELETEs the prior row in the current hour and INSERTs
--   the latest. Putting a status column on alert_log would erase the customer's
--   resolution every hour the condition persists. alert_incidents is the durable
--   lifecycle record; alert_log stays the raw firing log that feeds it.
--
-- HOW IT FILLS:
--   An AFTER INSERT trigger on alert_log upserts the incident, so all six vendor
--   collectors feed the lifecycle with no collector code change. First firing of
--   a (server, root_cause_id) with no OPEN incident opens one (status='open');
--   subsequent firings bump last_seen_at / occurrences on that open incident.
--   After it is resolved, a new firing opens a FRESH incident (immutable history,
--   and a recurring security condition rightly re-alerts).
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS alerts;

-- ── 1. lifecycle record ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS alerts.alert_incidents (
    incident_id            bigserial PRIMARY KEY,
    server                 varchar      NOT NULL,
    root_cause_id          varchar      NOT NULL,
    risk_level             varchar,
    status                 varchar      NOT NULL DEFAULT 'open'
                                        CHECK (status IN ('open','resolved')),
    opened_at              timestamp    NOT NULL DEFAULT LOCALTIMESTAMP,
    last_seen_at           timestamp    NOT NULL DEFAULT LOCALTIMESTAMP,
    occurrences            integer      NOT NULL DEFAULT 1,
    resolved_at            timestamp,
    resolved_by            text,                       -- web.users.email, or 'system' for auto
    resolution_type        varchar      CHECK (resolution_type IN ('manual','auto')),
    resolution_description text,
    last_metadata          jsonb,
    updated_at             timestamp    NOT NULL DEFAULT LOCALTIMESTAMP
);

-- one OPEN incident per (server, root_cause_id); resolved rows are unconstrained
-- so history accumulates.
DROP INDEX IF EXISTS alerts.ux_alert_incident_open;
CREATE UNIQUE INDEX ux_alert_incident_open
    ON alerts.alert_incidents (server, root_cause_id)
    WHERE status = 'open';
CREATE INDEX IF NOT EXISTS ix_alert_incident_status   ON alerts.alert_incidents (status, risk_level);
CREATE INDEX IF NOT EXISTS ix_alert_incident_lastseen ON alerts.alert_incidents (last_seen_at);

-- ── 2. auto-resolve config (per severity, with a 'default' fallback) ──────────
CREATE TABLE IF NOT EXISTS alerts.alert_lifecycle_config (
    risk_level              text PRIMARY KEY,          -- 'critical'|'high'|'medium'|'low'|'default'
    auto_resolve_enabled    boolean NOT NULL DEFAULT true,
    auto_resolve_after_hours integer NOT NULL DEFAULT 72 CHECK (auto_resolve_after_hours > 0),
    updated_at              timestamp NOT NULL DEFAULT LOCALTIMESTAMP
);

-- Seed: 72h default; criticals are NOT auto-resolved (a human must acknowledge).
INSERT INTO alerts.alert_lifecycle_config (risk_level, auto_resolve_enabled, auto_resolve_after_hours)
VALUES ('default',  true, 72),
       ('critical', false, 72),
       ('high',     true, 72),
       ('medium',   true, 48),
       ('low',      true, 24)
ON CONFLICT (risk_level) DO NOTHING;

-- ── 3. upsert trigger: alert_log INSERT -> open/refresh incident ─────────────
CREATE OR REPLACE FUNCTION alerts.trg_alert_incident_upsert()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    -- refresh the currently OPEN incident for this (server, root cause)...
    UPDATE alerts.alert_incidents
       SET last_seen_at  = NEW.entry_date,
           occurrences   = occurrences + 1,
           risk_level    = COALESCE(NEW.risk_level, risk_level),
           last_metadata = NEW.metadata,
           updated_at    = LOCALTIMESTAMP
     WHERE server = NEW.server
       AND root_cause_id = NEW.root_cause_id
       AND status = 'open';

    -- ...or open a new one if none is currently open (first firing, or the
    -- previous incident was already resolved and this is a recurrence).
    IF NOT FOUND THEN
        INSERT INTO alerts.alert_incidents
            (server, root_cause_id, risk_level, status, opened_at, last_seen_at,
             occurrences, last_metadata)
        VALUES
            (NEW.server, NEW.root_cause_id, NEW.risk_level, 'open',
             NEW.entry_date, NEW.entry_date, 1, NEW.metadata)
        ON CONFLICT (server, root_cause_id) WHERE (status = 'open') DO NOTHING;
    END IF;
    RETURN NULL;   -- AFTER trigger
END $$;

DROP TRIGGER IF EXISTS trg_alert_incident_upsert ON alerts.alert_log;
CREATE TRIGGER trg_alert_incident_upsert
    AFTER INSERT ON alerts.alert_log
    FOR EACH ROW EXECUTE FUNCTION alerts.trg_alert_incident_upsert();

-- ── 4. manual resolve — ONLY a valid customer user may resolve ───────────────
-- Enforces the "only the customer could change to resolved, with a description"
-- rule: the resolver must be an active web.users account, and a description is
-- mandatory. Raises (does not silently no-op) so the API returns a real error.
CREATE OR REPLACE FUNCTION alerts.resolve_incident(
    p_incident_id  bigint,
    p_user_email   text,
    p_description  text)
RETURNS alerts.alert_incidents
LANGUAGE plpgsql AS $$
DECLARE
    v_row alerts.alert_incidents;
BEGIN
    IF p_description IS NULL OR btrim(p_description) = '' THEN
        RAISE EXCEPTION 'A resolution description is required';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM web.users
                    WHERE lower(email) = lower(btrim(p_user_email)) AND is_active) THEN
        RAISE EXCEPTION 'Only an active customer user may resolve an alert (unknown or inactive user: %)', p_user_email;
    END IF;

    UPDATE alerts.alert_incidents
       SET status = 'resolved',
           resolved_at = LOCALTIMESTAMP,
           resolved_by = lower(btrim(p_user_email)),
           resolution_type = 'manual',
           resolution_description = btrim(p_description),
           updated_at = LOCALTIMESTAMP
     WHERE incident_id = p_incident_id
       AND status = 'open'
    RETURNING * INTO v_row;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Incident % is not open (already resolved or does not exist)', p_incident_id;
    END IF;
    RETURN v_row;
END $$;

-- ── 5. automatic resolve after the configured time ───────────────────────────
-- Resolves OPEN incidents that have not recurred within their severity's window.
-- Called by the alert_auto_resolve scheduled process. Returns the count closed.
CREATE OR REPLACE FUNCTION alerts.auto_resolve_incidents()
RETURNS integer
LANGUAGE plpgsql AS $$
DECLARE
    v_count integer;
BEGIN
    WITH cfg AS (
        SELECT COALESCE(c.risk_level, 'default') AS risk_level,
               c.auto_resolve_enabled, c.auto_resolve_after_hours
        FROM alerts.alert_lifecycle_config c
    ),
    resolvable AS (
        SELECT i.incident_id,
               COALESCE(sev.auto_resolve_after_hours, def.auto_resolve_after_hours) AS hours,
               COALESCE(sev.auto_resolve_enabled,     def.auto_resolve_enabled)     AS enabled
        FROM alerts.alert_incidents i
        LEFT JOIN cfg sev ON sev.risk_level = lower(i.risk_level)
        CROSS JOIN LATERAL (SELECT * FROM cfg WHERE risk_level = 'default' LIMIT 1) def
        WHERE i.status = 'open'
    )
    UPDATE alerts.alert_incidents i
       SET status = 'resolved',
           resolved_at = LOCALTIMESTAMP,
           resolved_by = 'system',
           resolution_type = 'auto',
           resolution_description =
               format('Auto-resolved after %s h without recurrence', r.hours),
           updated_at = LOCALTIMESTAMP
      FROM resolvable r
     WHERE i.incident_id = r.incident_id
       AND r.enabled
       AND i.last_seen_at < LOCALTIMESTAMP - make_interval(hours => r.hours);

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END $$;

-- ── 6. dashboard view ────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW alerts.v_alert_incidents AS
SELECT i.incident_id, i.server, i.root_cause_id, i.risk_level, i.status,
       rc.issue_name, rc.area_name, rc.domain_name,
       i.opened_at, i.last_seen_at, i.occurrences,
       i.resolved_at, i.resolved_by, i.resolution_type, i.resolution_description,
       CASE WHEN i.status = 'open' AND COALESCE(sev.auto_resolve_enabled, def.auto_resolve_enabled)
            THEN i.last_seen_at + make_interval(
                 hours => COALESCE(sev.auto_resolve_after_hours, def.auto_resolve_after_hours))
       END AS auto_resolve_at,
       EXTRACT(EPOCH FROM (LOCALTIMESTAMP - i.opened_at))/3600.0 AS age_hours
FROM alerts.alert_incidents i
LEFT JOIN (SELECT DISTINCT ON (root_cause_id) root_cause_id, issue_name, area_name, domain_name
           FROM rootcause.v_rootcauses) rc ON rc.root_cause_id = i.root_cause_id
LEFT JOIN alerts.alert_lifecycle_config sev ON sev.risk_level = lower(i.risk_level)
CROSS JOIN LATERAL (SELECT * FROM alerts.alert_lifecycle_config WHERE risk_level='default' LIMIT 1) def;

-- ── 7. register the auto-resolve scheduled process (every 5 min) ─────────────
INSERT INTO metrics.registered_processes (process_name, is_active, interval)
SELECT 'alert_auto_resolve', true, 300
WHERE NOT EXISTS (SELECT 1 FROM metrics.registered_processes WHERE process_name = 'alert_auto_resolve');

-- ── 8. ownership ─────────────────────────────────────────────────────────────
ALTER TABLE alerts.alert_incidents          OWNER TO dbdome_adm;
ALTER TABLE alerts.alert_lifecycle_config   OWNER TO dbdome_adm;
ALTER FUNCTION alerts.trg_alert_incident_upsert() OWNER TO dbdome_adm;
ALTER FUNCTION alerts.resolve_incident(bigint, text, text) OWNER TO dbdome_adm;
ALTER FUNCTION alerts.auto_resolve_incidents() OWNER TO dbdome_adm;
ALTER VIEW  alerts.v_alert_incidents        OWNER TO dbdome_adm;

-- ── 9. backfill: open an incident for every root cause currently alerting ────
-- so the customer sees today's active alerts as open incidents immediately,
-- not only ones that fire after this migration.
INSERT INTO alerts.alert_incidents (server, root_cause_id, risk_level, status,
                                    opened_at, last_seen_at, occurrences, last_metadata)
SELECT l.server, l.root_cause_id, MAX(l.risk_level),
       'open', MIN(l.entry_date), MAX(l.entry_date), COUNT(*), (array_agg(l.metadata ORDER BY l.entry_date DESC))[1]
FROM alerts.alert_log l
WHERE l.entry_date > LOCALTIMESTAMP - interval '24 hours'
  AND NOT EXISTS (SELECT 1 FROM alerts.alert_incidents i
                  WHERE i.server = l.server AND i.root_cause_id = l.root_cause_id AND i.status='open')
GROUP BY l.server, l.root_cause_id
ON CONFLICT (server, root_cause_id) WHERE (status='open') DO NOTHING;
