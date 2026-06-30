-- ============================================================
-- Function: monitoring.parse_execution_plan_summary(text)
--   Statement-level companion to monitoring.parse_execution_plan(text): one row per
--   statement (StmtSimple) in a SQL Server ShowPlanXML — the whole-plan facts that do
--   NOT live on a RelOp: query text/type, total cost, query & plan hash, optimization
--   level + early-abort reason, compile metrics, memory grant, missing-index
--   recommendations, and plan-level PlanAffectingConvert warnings.
--
--   Built and validated against ALL stored execution_plan_xml from PERF-SQL-TX-010-RC02
--   (168 plans, 0 failures; 557 plan-level convert warnings surfaced).
--
--   Note: PostgreSQL XMLTABLE has no DEFAULT namespace -> bound to prefix `sp`.
--
-- Usage
--   SELECT * FROM monitoring.parse_execution_plan_summary('<ShowPlanXML ...>…</ShowPlanXML>');
--
--   -- summarise the stored RC02 plans:
--   SELECT r.server, r.entry_date, s.*
--   FROM monitoring.general_metric_metadata_results r
--   CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) e(elem)
--   CROSS JOIN LATERAL monitoring.parse_execution_plan_summary(e.elem->>'execution_plan_xml') s
--   WHERE r.metric_name = 'PERF-SQL-TX-010-RC02'
--     AND e.elem->>'execution_plan_xml' IS NOT NULL
--   ORDER BY s.subtree_cost DESC;
--
-- Idempotent (DROP+CREATE).
-- ============================================================

DROP FUNCTION IF EXISTS monitoring.parse_execution_plan_summary(text);

CREATE OR REPLACE FUNCTION monitoring.parse_execution_plan_summary(p_plan text)
RETURNS TABLE (
    statement_id          integer,
    statement_text        text,
    statement_type        text,
    subtree_cost          numeric,   -- StatementSubTreeCost (whole statement)
    est_rows              numeric,
    optm_level            text,      -- TRIVIAL / FULL
    early_abort_reason    text,      -- e.g. TimeOut, GoodEnoughPlanFound
    cardinality_model     text,
    query_hash            text,
    query_plan_hash       text,
    cached_plan_size_kb   integer,
    compile_time_ms       integer,
    compile_cpu_ms        integer,
    compile_memory_kb     integer,
    degree_of_parallelism integer,
    nonparallel_reason    text,
    serial_required_kb    numeric,   -- MemoryGrantInfo
    serial_desired_kb     numeric,
    granted_kb            numeric,
    max_used_kb           numeric,
    missing_index_count   integer,   -- # MissingIndex recommendations
    missing_index_impact  numeric,   -- first group Impact %
    missing_index_table   text,      -- first recommended table
    convert_warning_count integer,   -- # PlanAffectingConvert (implicit conversions)
    convert_issue         text       -- first ConvertIssue (e.g. Cardinality Estimate)
)
LANGUAGE sql
STABLE
AS $fn$
    SELECT * FROM XMLTABLE(
        XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp),
        '//sp:StmtSimple'
        PASSING (xmlparse(document p_plan))
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
$fn$;

ALTER FUNCTION monitoring.parse_execution_plan_summary(text) OWNER TO dbdome_adm;
