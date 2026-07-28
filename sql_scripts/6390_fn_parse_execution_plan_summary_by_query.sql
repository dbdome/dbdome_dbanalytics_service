-- ============================================================
-- Function: monitoring.parse_execution_plan_summary(query text)   [BY QUERY]
--   Self-contained: give it a SQL query (substring, case-insensitive), it finds the
--   most recent stored ShowPlanXML for that query (p_plan, captured by
--   PERF-SQL-TX-010-RC02 in monitoring.general_metric_metadata_results) and returns
--   the full statement-level summary (one row per StmtSimple) by parsing that plan.
--
--   The raw-plan-XML parser lives separately in
--   monitoring.parse_execution_plan_summary_xml(text) (6290), used by
--   find_execution_plan(6300). This function inlines the same XMLTABLE over the
--   plan it locates BY QUERY.
--
-- Usage
--   SELECT * FROM monitoring.parse_execution_plan_summary('DB_NAME(database_id)');
--   SELECT statement_type, subtree_cost, missing_index_count
--   FROM monitoring.parse_execution_plan_summary('WHERE order_id =');
--
-- Idempotent (DROP+CREATE). Drops the prior 3-arg overload and old raw-XML 1-arg.
-- ============================================================

DROP FUNCTION IF EXISTS monitoring.parse_execution_plan_summary(text, integer, text);
DROP FUNCTION IF EXISTS monitoring.parse_execution_plan_summary(text);

CREATE OR REPLACE FUNCTION monitoring.parse_execution_plan_summary(query text)
RETURNS TABLE (
    statement_id          integer,
    statement_text        text,
    statement_type        text,
    subtree_cost          numeric,
    est_rows              numeric,
    optm_level            text,
    early_abort_reason    text,
    cardinality_model     text,
    query_hash            text,
    query_plan_hash       text,
    cached_plan_size_kb   integer,
    compile_time_ms       integer,
    compile_cpu_ms        integer,
    compile_memory_kb     integer,
    degree_of_parallelism integer,
    nonparallel_reason    text,
    serial_required_kb    numeric,
    serial_desired_kb     numeric,
    granted_kb            numeric,
    max_used_kb           numeric,
    missing_index_count   integer,
    missing_index_impact  numeric,
    missing_index_table   text,
    convert_warning_count integer,
    convert_issue         text
)
LANGUAGE sql
STABLE
AS $BODY$
    -- 1) find p_plan (execution_plan_xml) for the given query
    WITH plan AS (
        SELECT elem->>'execution_plan_xml' AS p_plan
        FROM   monitoring.general_metric_metadata_results r
        CROSS  JOIN LATERAL jsonb_array_elements(r.metric_metadata) elem
        WHERE  r.metric_name = 'PERF-SQL-TX-010-RC02'
          AND  elem->>'execution_plan_xml' IS NOT NULL
          AND  elem->>'query_text' ILIKE '%' || query || '%'
        ORDER  BY r.entry_date DESC
        LIMIT  1                       -- the most recent plan for the matching query
    )
    -- 2) parse that plan (same XMLTABLE as parse_execution_plan_summary_xml)
    SELECT x.*
    FROM plan
    CROSS JOIN LATERAL XMLTABLE(
        XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp),
        '//sp:StmtSimple'
        PASSING (xmlparse(document plan.p_plan))
        COLUMNS
            statement_id          integer PATH '@StatementId',
            statement_text        text    PATH '@StatementText',
            statement_type        text    PATH '@StatementType',
            subtree_cost          numeric PATH '@StatementSubTreeCost',
            est_rows              numeric PATH '@StatementEstRows',
            optm_level            text    PATH '@StatementOptmLevel',
            early_abort_reason    text    PATH '@StatementOptmEarlyAbortReason',
            cardinality_model     text    PATH '@CardinalityEstimationModelVersion',
            query_hash            text    PATH '@QueryHash',
            query_plan_hash       text    PATH '@QueryPlanHash',
            cached_plan_size_kb   integer PATH '(./sp:QueryPlan/@CachedPlanSize)[1]',
            compile_time_ms       integer PATH '(./sp:QueryPlan/@CompileTime)[1]',
            compile_cpu_ms        integer PATH '(./sp:QueryPlan/@CompileCPU)[1]',
            compile_memory_kb     integer PATH '(./sp:QueryPlan/@CompileMemory)[1]',
            degree_of_parallelism integer PATH '(./sp:QueryPlan/@DegreeOfParallelism)[1]',
            nonparallel_reason    text    PATH '(./sp:QueryPlan/@NonParallelPlanReason)[1]',
            serial_required_kb    numeric PATH '(.//sp:MemoryGrantInfo/@SerialRequiredMemory)[1]',
            serial_desired_kb     numeric PATH '(.//sp:MemoryGrantInfo/@SerialDesiredMemory)[1]',
            granted_kb            numeric PATH '(.//sp:MemoryGrantInfo/@GrantedMemory)[1]',
            max_used_kb           numeric PATH '(.//sp:MemoryGrantInfo/@MaxUsedMemory)[1]',
            missing_index_count   integer PATH 'count(.//sp:MissingIndex)',
            missing_index_impact  numeric PATH '(.//sp:MissingIndexGroup/@Impact)[1]',
            missing_index_table   text    PATH '(.//sp:MissingIndex/@Table)[1]',
            convert_warning_count integer PATH 'count(./sp:QueryPlan/sp:Warnings/sp:PlanAffectingConvert)',
            convert_issue         text    PATH '(./sp:QueryPlan/sp:Warnings/sp:PlanAffectingConvert/@ConvertIssue)[1]'
    ) AS x
$BODY$;

ALTER FUNCTION monitoring.parse_execution_plan_summary(text) OWNER TO dbdome_adm;
