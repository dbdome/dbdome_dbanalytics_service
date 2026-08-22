-- =============================================================================
-- 7630_security_agent_resultset.sql
--
-- Read the security agent's verdict back out of an alert, as a table.
--
-- Sits beside monitoring.get_alert_log_resultset_byid() and follows its
-- conventions (monitoring schema, bigint row_id, NULL-safe for an unsubstituted
-- Grafana variable). Where that function returns the alert's evidence rows,
-- this returns the agent's JUDGEMENT of them:
--     reason          - the sentence a DBA reads on the alert
--     security_agent  - {verdict, confidence, decided_by, indicators,
--                        matched_precedent, precedent{...}, model, elapsed_ms}
--
-- TWO THINGS THIS GETS RIGHT THAT ARE EASY TO GET WRONG
--
-- 1. metadata is jsonb but is NOT reliably an object. Measured over the 5,000
--    newest rows on 2026-08-21: 4,493 string / 507 object. The collectors
--    json.dumps() a value that is already JSON text and cast the result to
--    jsonb, so most rows are a jsonb STRING SCALAR holding JSON - double
--    encoded. On those, `metadata -> 'security_agent'` is NULL. Anything
--    reading this column must unwrap first or it works on a hand-picked row and
--    returns nothing in production. get_alert_log_resultset_byid already
--    open-codes this; fn_metadata_object() below does it once, reusably.
--
-- 2. alert_log is RANGE-partitioned on entry_date. A lookup by row_id ALONE
--    cannot prune and touches every partition - measured: the sibling function
--    exceeded a 90s statement timeout for exactly this reason. p_entry_date is
--    therefore an optional second argument: pass it and the lookup hits one
--    partition. Callers that have the alert row already have this value.
--
-- Idempotent.
-- =============================================================================

-- ----------------------------------------------------------------------------
-- 1) Normalise alert_log.metadata into an object, whatever shape it arrived in.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION monitoring.fn_metadata_object(p_metadata jsonb)
RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
AS $fn$
DECLARE
    v jsonb;
BEGIN
    IF p_metadata IS NULL THEN
        RETURN NULL;
    END IF;

    CASE jsonb_typeof(p_metadata)
        WHEN 'object' THEN
            -- An object whose "value" key holds JSON *text* is the shape the
            -- agent produced before persist.merge_reason() learned to parse a
            -- string payload: the captured rows arrived stringified inside a
            -- wrapper. Those alerts are already written and will not be
            -- rewritten, so unwrap them here or they render as one unreadable
            -- cell. The sibling keys (reason, security_agent) are preserved.
            IF jsonb_typeof(p_metadata -> 'value') = 'string' THEN
                BEGIN
                    v := (p_metadata #>> '{value}')::jsonb;
                    IF jsonb_typeof(v) = 'array' THEN
                        RETURN (p_metadata - 'value')
                               || jsonb_build_object('sample_rows', v);
                    ELSIF jsonb_typeof(v) = 'object' THEN
                        RETURN (p_metadata - 'value') || v;
                    END IF;
                EXCEPTION WHEN others THEN
                    NULL;   -- not JSON: a genuine string value, leave it alone
                END;
            END IF;
            RETURN p_metadata;
        WHEN 'array' THEN
            -- Row-array payload: expose it under the key the object-shaped
            -- payloads already use for their rows.
            RETURN jsonb_build_object('sample_rows', p_metadata);
        WHEN 'string' THEN
            -- Double-encoded: the scalar's TEXT is itself json. #>>'{}' strips
            -- the surrounding quotes. If it does not parse it really was just a
            -- string, so keep it as one rather than losing it.
            BEGIN
                v := (p_metadata #>> '{}')::jsonb;
            EXCEPTION WHEN others THEN
                RETURN jsonb_build_object('value', p_metadata #>> '{}');
            END;
            -- One unwrap is not always enough.
            RETURN monitoring.fn_metadata_object(v);
        ELSE
            RETURN jsonb_build_object('value', p_metadata);
    END CASE;
END;
$fn$;

COMMENT ON FUNCTION monitoring.fn_metadata_object(jsonb) IS
    'alerts.alert_log.metadata as an object. Most rows are double-encoded jsonb '
    'string scalars; reading that column without this yields NULL for ~90% of them.';


-- ----------------------------------------------------------------------------
-- 2) The agent's verdict for one alert, as columns.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION monitoring.get_security_agent_byid(
    p_row_id     bigint,
    p_entry_date timestamp DEFAULT NULL
)
RETURNS TABLE (
    row_id              bigint,
    entry_date          timestamp,
    server              varchar,
    servername          varchar,
    root_cause_id       varchar,
    risk_level          varchar,
    login_name          text,
    triaged             boolean,
    verdict             text,
    confidence          numeric,
    decided_by          text,
    reason              text,
    indicators          text,
    matched_precedent   boolean,
    exact_matches       integer,
    distinct_shapes     integer,
    candidates_searched integer,
    retrieval_method    text,
    model               text,
    elapsed_ms          integer
)
-- LANGUAGE sql, deliberately, not plpgsql.
--
-- RETURNS TABLE declares OUT parameters, and in plpgsql those shadow column
-- names inside the body: a bare `server` in the servername sub-select resolves
-- ambiguously against the OUT parameter and the function fails at run time with
--     column reference "server" is ambiguous
-- A sql function has no such variables, so the whole class of bug disappears.
-- The NULL guard the sibling implements with an early RETURN is just a WHERE
-- predicate here.
LANGUAGE sql
STABLE
AS $fn$
    SELECT a.row_id::bigint,
           a.entry_date,
           a.server,
           sv.servername,
           a.root_cause_id,
           a.risk_level,
           a.login_name,
           -- FALSE means the alert predates the agent, or it was disabled or
           -- unavailable when the alert fired. That is a different statement
           -- from "triaged and found nothing", and the panel should show it as
           -- such rather than as an empty verdict.
           (md.o ? 'security_agent'),
           md.o #>> '{security_agent,verdict}',
           NULLIF(md.o #>> '{security_agent,confidence}', '')::numeric,
           md.o #>> '{security_agent,decided_by}',
           md.o ->> 'reason',
           -- indicators is an array; render one readable cell rather than
           -- making every caller unnest it.
           CASE WHEN jsonb_typeof(md.o #> '{security_agent,indicators}') = 'array'
                THEN (SELECT string_agg(x #>> '{}', '; ')
                        FROM jsonb_array_elements(md.o #> '{security_agent,indicators}') x)
           END,
           NULLIF(md.o #>> '{security_agent,matched_precedent}', '')::boolean,
           NULLIF(md.o #>> '{security_agent,precedent,exact_matches}',  '')::integer,
           NULLIF(md.o #>> '{security_agent,precedent,distinct_shapes}', '')::integer,
           NULLIF(md.o #>> '{security_agent,precedent,searched}',        '')::integer,
           md.o #>> '{security_agent,precedent,method}',
           md.o #>> '{security_agent,model}',
           NULLIF(md.o #>> '{security_agent,elapsed_ms}', '')::integer
    FROM alerts.alert_log a
    -- de-duplicated so the join yields one servername per server (metrics.servers
    -- can have several rows per host - one per monitored database).
    LEFT JOIN (
        SELECT ms.server, max(ms.servername) AS servername
        FROM metrics.servers ms
        GROUP BY ms.server
    ) sv ON sv.server = a.server
    CROSS JOIN LATERAL (SELECT monitoring.fn_metadata_object(a.metadata)) AS md(o)
    -- p_row_id IS NOT NULL guards an empty / unsubstituted Grafana variable,
    -- the same case the sibling function handles with an early RETURN.
    WHERE p_row_id IS NOT NULL
      AND a.row_id = p_row_id
      -- Partition pruning: alert_log is RANGE-partitioned on entry_date, so
      -- without this every partition is scanned.
      AND (p_entry_date IS NULL OR a.entry_date = p_entry_date);
$fn$;

COMMENT ON FUNCTION monitoring.get_security_agent_byid(bigint, timestamp) IS
    'Security-agent verdict for one alerts.alert_log row, as columns. Pass '
    'entry_date where known - alert_log is partitioned on it and row_id alone '
    'cannot prune.';


-- ----------------------------------------------------------------------------
-- 2b) The alert's own payload as field/value rows.
--
-- monitoring.get_alert_log_resultset_byid() already returns this content, but it
-- LEFT JOINs general_metric_metadata_results on g.id = a.metric_result_row_id to
-- pick up one description field. gmmr's primary key is (entry_date, id), so a
-- lookup by id ALONE cannot use it and the join scans 1.47M rows across every
-- partition: that call exceeded a 60s statement timeout when driving a panel.
--
-- This reads the alert's own metadata instead - no join, no scan - which is all
-- a "show me this alert's values" panel needs. Field/value rows rather than
-- fixed columns, because the payload shape differs per detection.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION monitoring.get_alert_value_byid(
    p_row_id     bigint,
    p_entry_date timestamp DEFAULT NULL
)
RETURNS TABLE (
    row_id     bigint,
    entry_date timestamp,
    field      text,
    value      text
)
LANGUAGE sql
STABLE
AS $fn$
    SELECT a.row_id::bigint,
           a.entry_date,
           t.k,
           t.v #>> '{}'
    FROM alerts.alert_log a
    CROSS JOIN LATERAL (SELECT monitoring.fn_metadata_object(a.metadata)) AS md(o)
    CROSS JOIN LATERAL jsonb_each(
        -- A row-array payload is wrapped under sample_rows by the normaliser;
        -- shred its FIRST row so the panel shows the captured values rather than
        -- a single cell containing the whole array.
        CASE WHEN jsonb_typeof(md.o -> 'sample_rows') = 'array'
              AND jsonb_array_length(md.o -> 'sample_rows') > 0
              AND jsonb_typeof(md.o #> '{sample_rows,0}') = 'object'
             THEN (md.o - 'sample_rows') || (md.o #> '{sample_rows,0}')
             ELSE md.o
        END
    ) AS t(k, v)
    WHERE p_row_id IS NOT NULL
      AND a.row_id = p_row_id
      AND (p_entry_date IS NULL OR a.entry_date = p_entry_date)
      -- security_agent is rendered by its own panel; keep it out of the value
      -- table so the agent's block does not drown the alert's own fields.
      AND t.k <> 'security_agent'
    ORDER BY t.k;
$fn$;

COMMENT ON FUNCTION monitoring.get_alert_value_byid(bigint, timestamp) IS
    'Alert payload as field/value rows, read from alert_log.metadata directly. '
    'Avoids the gmmr join in get_alert_log_resultset_byid, which scans 1.47M '
    'rows because gmmr is keyed (entry_date, id) and that join has only id.';


-- ----------------------------------------------------------------------------
-- 3) Recent alerts with their verdict, for a panel or a review query.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW monitoring.v_security_agent_alerts AS
SELECT a.row_id,
       a.entry_date,
       a.server,
       a.root_cause_id,
       a.risk_level,
       a.login_name,
       (md.o ? 'security_agent')                                        AS triaged,
       md.o #>> '{security_agent,verdict}'                              AS verdict,
       NULLIF(md.o #>> '{security_agent,confidence}', '')::numeric      AS confidence,
       md.o #>> '{security_agent,decided_by}'                           AS decided_by,
       md.o ->> 'reason'                                                AS reason,
       NULLIF(md.o #>> '{security_agent,precedent,exact_matches}', '')::integer
                                                                        AS exact_matches,
       NULLIF(md.o #>> '{security_agent,elapsed_ms}', '')::integer      AS elapsed_ms,
       md.o #>> '{security_agent,model}'                                AS model
FROM alerts.alert_log a
CROSS JOIN LATERAL (SELECT monitoring.fn_metadata_object(a.metadata)) AS md(o);

COMMENT ON VIEW monitoring.v_security_agent_alerts IS
    'Alerts with the security agent''s verdict and reason. triaged=false means '
    'the alert predates the agent or it was unavailable - not that it found nothing.';


-- ----------------------------------------------------------------------------
-- 4) Verify against real rows, not just that it compiles.
-- ----------------------------------------------------------------------------
DO $mig$
DECLARE
    v_rid  bigint;
    v_date timestamp;
    v_rows integer;
    v_obj  integer;
    v_str  integer;
BEGIN
    SET LOCAL statement_timeout = '30s';

    SELECT count(*) FILTER (WHERE jsonb_typeof(metadata) = 'object'),
           count(*) FILTER (WHERE jsonb_typeof(metadata) = 'string')
      INTO v_obj, v_str
      FROM (SELECT metadata FROM alerts.alert_log
             ORDER BY entry_date DESC LIMIT 500) s;

    SELECT row_id, entry_date INTO v_rid, v_date
      FROM alerts.alert_log ORDER BY entry_date DESC LIMIT 1;

    IF v_rid IS NULL THEN
        RAISE NOTICE '7630: objects created; alert_log is empty so nothing to test against.';
        RETURN;
    END IF;

    SELECT count(*) INTO v_rows
      FROM monitoring.get_security_agent_byid(v_rid, v_date);

    IF v_rows <> 1 THEN
        RAISE EXCEPTION '7630: get_security_agent_byid(%, %) returned % rows, expected 1',
                        v_rid, v_date, v_rows;
    END IF;

    RAISE NOTICE '7630: created. 500 newest alerts sampled: % object / % double-encoded '
                 'string metadata - the normaliser is why this works on both. '
                 'get_security_agent_byid(%) returned 1 row.', v_obj, v_str, v_rid;
END $mig$;
