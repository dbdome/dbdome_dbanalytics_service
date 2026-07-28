-- =============================================================================
-- 6580_get_alert_incidents_resultset_byid.sql
--
-- monitoring.get_alert_incidents_resultset_byid(p_row_id bigint)
--   -> TABLE(result json, entry_date timestamp)
--
-- Returns the alert detail rows for a single alert (alerts.alert_log by row_id),
-- one JSON object per metadata element, enriched with server/servername/
-- risk_level/login_name and lower-cased keys. Excludes DBDOME's own monitoring user
-- (dbdome_mon_usr). Consumed by the alert drill-down panel (advb58n p130, arg ${alert_id}).
--
-- NOTE: the body reads alerts.alert_log (which has row_id/metadata/entry_date/login_name).
-- A prior definition had FROM alerts.alert_incidents, whose columns are incident_id/
-- last_metadata/opened_at with no login_name, so every call errored internally and the
-- trailing EXCEPTION WHEN OTHERS THEN RETURN swallowed it -> the function always returned
-- empty. The function name keeps '_incidents_' for compatibility with the calling panel.
--
-- Idempotent (CREATE OR REPLACE). Depends on monitoring.jsonb_lower_keys(jsonb),
-- alerts.alert_log and metrics.servers (created by earlier migrations).
-- =============================================================================

CREATE OR REPLACE FUNCTION monitoring.get_alert_incidents_resultset_byid(p_row_id bigint)
 RETURNS TABLE(result json, entry_date timestamp without time zone)
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Guard empty / unsubstituted Grafana variable.
    IF p_row_id IS NULL
    THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        (
            SELECT jsonb_object_agg(k, v)
            FROM jsonb_each(
                monitoring.jsonb_lower_keys(elem)
                || jsonb_build_object('server',     a.server,
                                      'servername', sv.servername,   -- shown beside server
                                      'risk_level', a.risk_level,
                                      'login_name', a.login_name)
            ) t(k, v)
            WHERE v IS DISTINCT FROM 'null'::jsonb
        )::json AS result,
        a.entry_date
    FROM alerts.alert_log a
    -- de-duplicated so the join yields one servername per server (metrics.servers
    -- can have several rows per host - one per monitored database).
    LEFT JOIN (
        SELECT server, max(servername) AS servername
        FROM metrics.servers
        GROUP BY server
    ) sv ON sv.server = a.server
    CROSS JOIN LATERAL jsonb_array_elements(
        CASE
            WHEN jsonb_typeof(a.metadata) = 'array'  THEN a.metadata
            WHEN jsonb_typeof(a.metadata) = 'string' THEN
                 CASE WHEN jsonb_typeof((a.metadata #>> '{}')::jsonb) = 'array'
                      THEN (a.metadata #>> '{}')::jsonb
                      ELSE jsonb_build_array((a.metadata #>> '{}')::jsonb)
                 END
            ELSE jsonb_build_array(a.metadata)   -- object / scalar -> single element
        END
    ) elem
    WHERE a.row_id = p_row_id
      AND COALESCE(NULLIF(a.login_name, ''),
                   monitoring.jsonb_lower_keys(elem) ->> 'login_name')
            IS DISTINCT FROM 'dbdome_mon_usr';

EXCEPTION
    WHEN OTHERS THEN RETURN;
END;
$function$
;
