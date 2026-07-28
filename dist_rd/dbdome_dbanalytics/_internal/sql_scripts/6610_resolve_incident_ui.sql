-- =============================================================================
-- 6610_resolve_incident_ui.sql
--
-- alerts.resolve_incident_ui(incident_id, resolved_by, resolution_type, description)
--
-- Resolve an OPEN incident from the Grafana "Open Alerts" dashboard. Unlike the
-- customer-API alerts.resolve_incident() (which validates resolved_by against
-- web.users and hard-codes resolution_type='manual'), this UI path:
--   * records resolved_by = the Grafana logged-in username (${__user.login}) as-is
--     (the gate is Grafana authentication, not the web.users customer table), and
--   * accepts a caller-chosen resolution_type and resolution_description.
-- Only flips a currently-open incident; description is required. Idempotent DDL.
--
-- resolution_type was CHECK-constrained to ('manual','auto') — a mechanism marker.
-- The UI lets the resolver pick a category, so widen the constraint to also allow
-- the dropdown values (must stay in sync with _RESOLUTION_TYPES in http_server.py).
-- NULL stays allowed for the pre-existing open/never-set rows.
-- =============================================================================

ALTER TABLE alerts.alert_incidents DROP CONSTRAINT IF EXISTS alert_incidents_resolution_type_check;
ALTER TABLE alerts.alert_incidents ADD CONSTRAINT alert_incidents_resolution_type_check
    CHECK (resolution_type IS NULL OR resolution_type IN
        ('manual','auto','Fixed','False Positive','Mitigated','Acknowledged','Other'));

CREATE OR REPLACE FUNCTION alerts.resolve_incident_ui(
        p_incident_id           bigint,
        p_resolved_by           text,
        p_resolution_type       text,
        p_resolution_description text)
 RETURNS alerts.alert_incidents
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_row alerts.alert_incidents;
BEGIN
    IF p_resolved_by IS NULL OR btrim(p_resolved_by) = '' THEN
        RAISE EXCEPTION 'resolved_by (Grafana user) is required';
    END IF;
    IF p_resolution_description IS NULL OR btrim(p_resolution_description) = '' THEN
        RAISE EXCEPTION 'A resolution description is required';
    END IF;

    UPDATE alerts.alert_incidents
       SET status                 = 'resolved',
           resolved_at            = LOCALTIMESTAMP,
           resolved_by            = btrim(p_resolved_by),
           resolution_type        = COALESCE(NULLIF(btrim(p_resolution_type), ''), 'manual'),
           resolution_description = btrim(p_resolution_description),
           updated_at             = LOCALTIMESTAMP
     WHERE incident_id = p_incident_id
       AND status = 'open'
    RETURNING * INTO v_row;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Incident % is not open (already resolved or does not exist)', p_incident_id;
    END IF;
    RETURN v_row;
END $function$;
