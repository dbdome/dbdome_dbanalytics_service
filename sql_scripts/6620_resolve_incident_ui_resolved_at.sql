-- =============================================================================
-- 6620_resolve_incident_ui_resolved_at.sql
--
-- Extend alerts.resolve_incident_ui (migration 6610) with an optional
-- p_resolved_at so the "Open Alerts" resolve form can record WHEN the alert was
-- resolved (the resolver picks the date/time; NULL -> LOCALTIMESTAMP = now).
-- Drops the old 4-arg signature so there is no ambiguous overload.
-- =============================================================================

DROP FUNCTION IF EXISTS alerts.resolve_incident_ui(bigint, text, text, text);

CREATE OR REPLACE FUNCTION alerts.resolve_incident_ui(
        p_incident_id            bigint,
        p_resolved_by            text,
        p_resolution_type        text,
        p_resolution_description text,
        p_resolved_at            timestamp DEFAULT NULL)
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
           resolved_at            = COALESCE(p_resolved_at, LOCALTIMESTAMP),
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
