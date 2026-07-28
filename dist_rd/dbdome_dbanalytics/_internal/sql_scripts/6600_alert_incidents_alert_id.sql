-- =============================================================================
-- 6600_alert_incidents_alert_id.sql
--
-- Add alerts.alert_incidents.alert_id = the row_id of the alerts.alert_log row
-- that OPENED the incident, so an incident can be traced back to its originating
-- alert (and the drill-down function get_alert_incidents_resultset_byid, which
-- reads alert_log by row_id, can be driven from the incident).
--
-- 1) add the column (nullable; no FK so alert_log retention/purge can't block).
-- 2) the AFTER INSERT trigger on alert_log now records NEW.row_id into alert_id
--    on the "open a new incident" path only (the refresh/UPDATE path leaves the
--    original opener's alert_id intact).
-- 3) best-effort backfill for existing incidents: match the opener alert_log row
--    by (server, root_cause_id, entry_date = opened_at).
-- Idempotent.
-- =============================================================================

ALTER TABLE alerts.alert_incidents ADD COLUMN IF NOT EXISTS alert_id bigint;
COMMENT ON COLUMN alerts.alert_incidents.alert_id IS
    'row_id of the alerts.alert_log row that opened this incident';

CREATE OR REPLACE FUNCTION alerts.trg_alert_incident_upsert()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
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
             occurrences, last_metadata, alert_id)
        VALUES
            (NEW.server, NEW.root_cause_id, NEW.risk_level, 'open',
             NEW.entry_date, NEW.entry_date, 1, NEW.metadata, NEW.row_id)
        ON CONFLICT (server, root_cause_id) WHERE (status = 'open') DO NOTHING;
    END IF;
    RETURN NULL;   -- AFTER trigger
END $function$;

-- best-effort backfill: link each incident to the alert_log row that opened it.
UPDATE alerts.alert_incidents ai
   SET alert_id = sub.row_id
  FROM (
        SELECT server, root_cause_id, entry_date, min(row_id) AS row_id
        FROM alerts.alert_log
        GROUP BY server, root_cause_id, entry_date
       ) sub
 WHERE ai.alert_id IS NULL
   AND ai.server        = sub.server
   AND ai.root_cause_id = sub.root_cause_id
   AND ai.opened_at     = sub.entry_date;
