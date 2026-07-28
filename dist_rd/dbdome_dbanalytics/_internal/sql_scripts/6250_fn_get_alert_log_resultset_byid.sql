-- ============================================================
-- Function: monitoring.get_alert_log_resultset_byid(bigint)
--   Returns the alert-log row p_row_id exploded into one JSON object per
--   metadata element, merged with server / servername / risk_level / login_name,
--   for the Grafana alert-detail panel. Drives the panel keyed on alert_log.row_id.
--
-- Behaviour:
--   * Guards a NULL / unsubstituted Grafana variable (returns no rows).
--   * Normalises a.metadata whether it is stored as a jsonb array, a jsonb string
--     wrapping an array, or a single object/scalar.
--   * Lower-cases metadata keys (monitoring.jsonb_lower_keys) and drops JSON nulls.
--   * Excludes the monitoring account: rows whose effective login_name (column,
--     else metadata 'login_name') equals 'dbdome_mon_usr' are filtered out.
--
-- FIX vs the prior copy: the original WHERE clause had a stray ';' after
--   "a.row_id = p_row_id", which terminated the statement so the trailing
--   "AND ... IS DISTINCT FROM 'dbdome_mon_usr'" was a syntax error. The semicolon
--   is moved to the end of the (single) WHERE clause here.
--
-- Idempotent: CREATE OR REPLACE; safe to re-run.
-- ============================================================

CREATE OR REPLACE FUNCTION monitoring.get_alert_log_resultset_byid(
    p_row_id bigint
    )
    RETURNS TABLE(result json, entry_date timestamp without time zone)
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
    ROWS 1000

AS $BODY$
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
$BODY$;

ALTER FUNCTION monitoring.get_alert_log_resultset_byid(bigint)
    OWNER TO dbdome_adm;
