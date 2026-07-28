-- =============================================================================
-- Function: monitoring.get_alert_log_resultset(p_root_cause_id text)
-- Returns one JSON row per metadata element from alerts.alert_log for a given
-- root_cause_id, with server / servername / risk_level / login_name merged in,
-- null values stripped, and keys lowercased (Oracle/MSSQL emit UPPERCASE).
-- servername is the friendly name from metrics.servers (looked up by server).
--
-- alert_log.metadata is stored DOUBLE-ENCODED: a jsonb *string* whose text is a
-- JSON array (e.g. "[{...},{...}]"). It is unwrapped with #>>'{}' then re-parsed.
-- The CASE also tolerates a plain array / object, just in case.
--
-- Performance: pass p_time_from so the entry_date filter is applied INSIDE the
-- function (uses the ix_entry_date index) BEFORE the JSON array is expanded,
-- instead of expanding all history and filtering in the outer query. Optional —
-- defaults NULL = no time filter, so the 1-arg form still works.
--
-- Usage (Grafana):
--   SELECT * FROM monitoring.get_alert_log_resultset('${root_cause_id}', $__timeFrom())
--   WHERE '${root_cause_id}' <> '' LIMIT 10;
-- =============================================================================

DROP FUNCTION IF EXISTS monitoring.get_alert_log_resultset(text);
DROP FUNCTION IF EXISTS monitoring.get_alert_log_resultset(text, timestamp);

CREATE FUNCTION monitoring.get_alert_log_resultset(
    p_root_cause_id TEXT,
    p_time_from     TIMESTAMP DEFAULT NULL
)
RETURNS TABLE(result json, entry_date timestamp)
LANGUAGE plpgsql AS
$$
BEGIN
    -- Guard empty / unsubstituted Grafana variable.
    IF p_root_cause_id IS NULL
       OR p_root_cause_id = ''
       OR p_root_cause_id LIKE '${%}'
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
    WHERE a.root_cause_id = p_root_cause_id
      AND (p_time_from IS NULL OR a.entry_date > p_time_from)     -- pushed-down, index-friendly
      -- hide the dbdome monitoring account (its own collector session shows up
      -- in self-monitoring detections); checks both the column and the metadata.
      AND COALESCE(NULLIF(a.login_name, ''),
                   monitoring.jsonb_lower_keys(elem) ->> 'login_name')
            IS DISTINCT FROM 'dbdome_mon_usr';

EXCEPTION
    WHEN OTHERS THEN RETURN;
END;
$$;
