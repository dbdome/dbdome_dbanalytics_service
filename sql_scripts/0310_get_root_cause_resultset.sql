-- ============================================================
-- Function: monitoring.get_root_cause_resultset(p_root_cause_id text, p_time_from timestamp)
-- Mirrors monitoring.get_alert_log_resultset: returns a TABLE (one row per
-- metric_metadata element) instead of a single json_agg. Each row's `result` is
-- the element's JSON with keys lowercased (Oracle/MSSQL emit UPPERCASE), with
-- server + servername merged in and null values stripped; entry_date is a
-- separate column.
--
-- p_time_from (optional, default NULL): only rows with entry_date > p_time_from
-- are returned (pass $__timeFrom() from Grafana).
--
-- Usage (Grafana):
--   SELECT * FROM monitoring.get_root_cause_resultset('${root_cause_id}', $__timeFrom());
-- ============================================================

DROP FUNCTION IF EXISTS monitoring.get_root_cause_resultset(text);
DROP FUNCTION IF EXISTS monitoring.get_root_cause_resultset(text, timestamp);

CREATE FUNCTION monitoring.get_root_cause_resultset(
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
            COALESCE((
                SELECT jsonb_object_agg(k, v)
                FROM jsonb_each(
                    monitoring.jsonb_lower_keys(elem)
                    || jsonb_build_object('server',     r.server,
                                          'servername', sv.servername)   -- shown beside server
                ) t(k, v)
                WHERE v IS DISTINCT FROM 'null'::jsonb
            ), '{}'::jsonb)
            -- Always expose login_name even when null: it is null on cached_plan
            -- rows (no session), and stripping it makes Grafana drop the column
            -- entirely when the visible rows happen to be cached_plan.
            || jsonb_build_object('login_name', monitoring.jsonb_lower_keys(elem) -> 'login_name')
        )::json AS result,
        r.entry_date
    FROM monitoring.general_metric_metadata_results r
    -- de-duplicated so the join yields one servername per server (metrics.servers
    -- can have several rows per host - one per monitored database).
    LEFT JOIN (
        SELECT server, max(servername) AS servername
        FROM metrics.servers
        GROUP BY server
    ) sv ON sv.server = r.server
    CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) elem
    WHERE r.metric_name = p_root_cause_id
      AND (p_time_from IS NULL OR r.entry_date > p_time_from);

EXCEPTION
    -- Degrade to no rows rather than erroring the panel.
    WHEN OTHERS THEN RETURN;
END;
$$;
