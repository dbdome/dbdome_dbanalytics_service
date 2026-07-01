-- ============================================================
-- Function: monitoring.find_execution_plan(text, integer, text)
--   Find the stored SQL Server execution plan(s) for a given SQL text. Searches the
--   plans captured by PERF-SQL-TX-010-RC02 (per active request, in
--   monitoring.general_metric_metadata_results.metric_metadata -> 'query_text' /
--   'execution_plan_xml') and returns, for each match, the server, capture time, the
--   query text, a statement-level summary (via parse_execution_plan_summary) and the
--   raw plan XML — which can be fed straight into parse_execution_plan() for the
--   per-operator breakdown.
--
-- Params
--   p_sql_text  substring matched case-insensitively against query_text (ILIKE %..%)
--   p_limit     max plans to return (default 20, most recent first)
--   p_metric    source metric (default 'PERF-SQL-TX-010-RC02')
--
-- Usage
--   SELECT * FROM monitoring.find_execution_plan('ghost_record_count');
--
--   -- find a plan and break it into operators in one go:
--   SELECT f.server, f.entry_date, op.*
--   FROM monitoring.find_execution_plan('WHERE order_id =', 1) f
--   CROSS JOIN LATERAL monitoring.parse_execution_plan(f.execution_plan_xml) op
--   ORDER BY op.subtree_cost DESC;
--
-- Idempotent (DROP+CREATE).
-- ============================================================

DROP FUNCTION IF EXISTS monitoring.find_execution_plan(text, integer, text);

CREATE OR REPLACE FUNCTION monitoring.find_execution_plan(
    p_sql_text text,
    p_limit    integer DEFAULT 20,
    p_metric   text    DEFAULT 'PERF-SQL-TX-010-RC02'
)
RETURNS TABLE (
    server                text,
    entry_date            timestamp without time zone,
    query_text            text,
    statement_type        text,
    subtree_cost          numeric,
    optm_level            text,
    early_abort_reason    text,
    query_hash            text,
    missing_index_count   integer,
    convert_warning_count integer,
    execution_plan_xml    text
)
LANGUAGE sql
STABLE
AS $fn$
    SELECT m.server, m.entry_date, m.query_text,
           s.statement_type, s.subtree_cost, s.optm_level, s.early_abort_reason,
           s.query_hash, s.missing_index_count, s.convert_warning_count, m.plan
    FROM (
        SELECT r.server, r.entry_date,
               elem->>'query_text'         AS query_text,
               elem->>'execution_plan_xml' AS plan
        FROM monitoring.general_metric_metadata_results r
        CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) elem
        WHERE r.metric_name = p_metric
          AND elem->>'execution_plan_xml' IS NOT NULL
          AND elem->>'query_text' ILIKE '%' || p_sql_text || '%'
        ORDER BY r.entry_date DESC
        LIMIT p_limit
    ) m
    CROSS JOIN LATERAL monitoring.parse_execution_plan_summary(m.plan) s
$fn$;

ALTER FUNCTION monitoring.find_execution_plan(text, integer, text) OWNER TO dbdome_adm;
