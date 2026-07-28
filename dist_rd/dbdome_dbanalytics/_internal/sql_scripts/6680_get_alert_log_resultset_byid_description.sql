-- =============================================================================
-- 6680_get_alert_log_resultset_byid_description.sql
--
-- monitoring.get_alert_log_resultset_byid(p_row_id) now also exposes a
-- "description" key on each result row, taken from the source metric result's
-- metric_metadata_vs_expected (the expected.description of the detection, e.g.
-- "Human account active outside 06:00-20:00 UTC"). Enabled by the new
-- alerts.alert_log.metric_result_row_id link (migration 6660) -> join to
-- monitoring.general_metric_metadata_results. Absent when there is no linked
-- metric row (the null value is dropped by the jsonb_object_agg filter).
-- Same signature, so CREATE OR REPLACE is sufficient.
-- =============================================================================

CREATE OR REPLACE FUNCTION monitoring.get_alert_log_resultset_byid(p_row_id bigint)
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
                || jsonb_build_object('server',      a.server,
                                      'servername',  sv.servername,   -- shown beside server
                                      'risk_level',  a.risk_level,
                                      'login_name',  a.login_name,
                                      'description', COALESCE(
                                          g.metric_metadata_vs_expected ->> 'description',
                                          g.metric_metadata_vs_expected -> 'expected' ->> 'description'))
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
    -- source metric result (migration 6660 link) -> its expected description
    LEFT JOIN monitoring.general_metric_metadata_results g
           ON g.id = a.metric_result_row_id
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
$function$;

-- Backfill metric_result_row_id for recent alerts (last 30 days) so the new
-- description resolves for current drill-downs; new alerts get an exact link via
-- the 6670 BEFORE INSERT trigger. The expected.description is per-root-cause and
-- stable, so linking to the latest metric row for (server, root_cause_id) yields
-- the correct description even for slightly older alerts.
UPDATE alerts.alert_log a
   SET metric_result_row_id = (
        SELECT g.id
        FROM monitoring.general_metric_metadata_results g
        WHERE g.server = a.server
          AND g.metric_name = a.root_cause_id
        ORDER BY g.entry_date DESC, g.id DESC
        LIMIT 1)
 WHERE a.metric_result_row_id IS NULL
   AND a.entry_date > now() - interval '30 days';
