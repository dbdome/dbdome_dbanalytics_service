-- =============================================================================
-- Function: monitoring.get_root_cause_resultset
-- Returns one JSON row per result from the matching monitoring view.
-- View naming convention: monitoring.v_<lower(replace(root_cause_id, '-', '_'))>
-- =============================================================================

DROP FUNCTION IF EXISTS monitoring.get_root_cause_resultset(text);

CREATE FUNCTION monitoring.get_root_cause_resultset(p_root_cause_id TEXT)
RETURNS TABLE(result json, entry_date timestamp)
LANGUAGE plpgsql AS
$$
BEGIN
    IF p_root_cause_id IS NULL
       OR p_root_cause_id = ''
       OR p_root_cause_id LIKE '${%}'
    THEN
        RETURN;
    END IF;

    -- Query general_metric_metadata_results directly and expand JSON keys dynamically.
    -- This works for any root cause without needing a static per-RC view.
    -- jsonb_lower_keys normalises uppercase keys (Oracle/MSSQL convention) to lowercase.
    RETURN QUERY
    SELECT
        -- Lowercase keys, add server, strip null values so Grafana shows only populated columns
        (
            SELECT jsonb_object_agg(k, v)
            FROM jsonb_each(
                monitoring.jsonb_lower_keys(elem)
                || jsonb_build_object('server', r.server)
            ) t(k, v)
            WHERE v IS DISTINCT FROM 'null'::jsonb
        )::json AS result,
        r.entry_date
    FROM monitoring.general_metric_metadata_results r
    CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) elem
    WHERE r.metric_name = p_root_cause_id;

EXCEPTION
    WHEN OTHERS THEN RETURN;
END;
$$;
