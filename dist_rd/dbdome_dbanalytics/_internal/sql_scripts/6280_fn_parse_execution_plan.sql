-- ============================================================
-- Function: monitoring.parse_execution_plan(text)
--   Parse a SQL Server ShowPlanXML execution plan into a table — one row per plan
--   operator (RelOp), each enriched with the context of the STATEMENT and QUERY
--   PLAN it belongs to (looked up via the XML ancestor axis).
--
-- Per operator it returns: identity + costs (rows / cpu / io / subtree, rebinds,
-- rewinds, row-goal), the object touched (scans/seeks only), the residual predicate,
-- the seek predicate, the output-column count, any operator-level Warnings, PLUS the
-- statement-level fields (statement id / text / type, est rows, optimisation level,
-- early-abort reason, cardinality model, query & plan hash) and query-plan-level
-- fields (cached plan size, compile time / cpu / memory, DOP, non-parallel reason,
-- memory grant, missing-index summary, plan-affecting-convert warnings).
--
-- Notes
--   * PostgreSQL XMLTABLE does NOT support a DEFAULT namespace, so the ShowPlan
--     namespace is bound to prefix `sp`; element steps are prefixed (`sp:RelOp`,
--     `sp:Object`…). Attributes are in no namespace -> unprefixed (`@NodeId`).
--   * object / predicate / seek_predicate / operator Warnings are read from the
--     operator's OWN child elements (`./sp:*/…`) so a parent join/sort/aggregate
--     shows NULL object while leaf Index Scan/Seek rows carry table + index + filter.
--   * statement- and plan-level columns are read from the RelOp's ANCESTORS
--     (`ancestor::sp:StmtSimple/…`, `ancestor::sp:QueryPlan/…`) — NOT from the RelOp
--     itself, where those attributes do not exist and would return NULL. Every
--     operator row therefore repeats the context of the statement it belongs to; in
--     a multi-statement batch each operator resolves to its own statement.
--
-- Usage
--   SELECT * FROM monitoring.parse_execution_plan('<ShowPlanXML ...>…</ShowPlanXML>')
--   ORDER BY subtree_cost DESC;
--
--   -- break out the stored RC02 plans (one row per operator per active request):
--   SELECT r.server, r.entry_date, op.*
--   FROM monitoring.general_metric_metadata_results r
--   CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) e(elem)
--   CROSS JOIN LATERAL monitoring.parse_execution_plan(e.elem->>'execution_plan_xml') op
--   WHERE r.metric_name = 'PERF-SQL-TX-010-RC02'
--     AND e.elem->>'execution_plan_xml' IS NOT NULL
--   ORDER BY r.entry_date DESC, op.subtree_cost DESC;
--
-- Idempotent (DROP+CREATE; the return type evolves).
-- ============================================================

DROP FUNCTION IF EXISTS monitoring.parse_execution_plan(text);

CREATE OR REPLACE FUNCTION monitoring.parse_execution_plan(p_plan text)
RETURNS TABLE (
    -- ---- operator (RelOp) level ----
    node_id             integer,   -- RelOp NodeId
    physical_op         text,      -- e.g. Clustered Index Seek, Nested Loops, Sort
    logical_op          text,
    estimate_rows       numeric,
    est_rows_norowgoal  numeric,   -- EstimateRowsWithoutRowGoal
    est_rows_read       numeric,   -- scans/seeks only
    estimate_cpu        numeric,
    estimate_io         numeric,
    subtree_cost        numeric,   -- EstimatedTotalSubtreeCost
    avg_row_size        integer,
    table_cardinality   numeric,   -- scans/seeks only
    est_rebinds         numeric,
    est_rewinds         numeric,
    parallel            boolean,
    exec_mode           text,      -- Row / Batch
    output_cols         integer,   -- # of columns in OutputList
    object_database     text,      -- the operator's own object (leaf ops)
    object_schema       text,
    object_table        text,
    object_index        text,
    index_kind          text,      -- Clustered / NonClustered / Heap
    predicate           text,      -- residual/filter predicate (first ScalarString)
    seek_predicate      text,      -- seek predicate (first ScalarString)
    has_warning         boolean,   -- operator-level Warnings present
    warning_detail      text,      -- first warning element name (e.g. SpillToTempDb)
    -- ---- statement (StmtSimple ancestor) level ----
    statement_id        integer,
    statement_text      text,
    statement_type      text,
    est_rows            numeric,   -- StatementEstRows
    optm_level          text,      -- StatementOptmLevel (FULL / TRIVIAL)
    early_abort_reason  text,      -- StatementOptmEarlyAbortReason
    cardinality_model   text,      -- CardinalityEstimationModelVersion
    query_hash          text,
    query_plan_hash     text,
    -- ---- query-plan (QueryPlan ancestor) level ----
    cached_plan_size_kb   integer,
    compile_time_ms       integer,
    compile_cpu_ms        integer,
    compile_memory_kb     integer,
    degree_of_parallelism integer,
    nonparallel_reason    text,
    serial_required_kb    numeric,  -- MemoryGrantInfo
    serial_desired_kb     numeric,
    granted_kb            numeric,
    max_used_kb           numeric,
    missing_index_count   integer,  -- # of MissingIndex entries in the plan
    missing_index_impact  numeric,  -- MissingIndexGroup Impact (first)
    missing_index_table   text,     -- MissingIndex Table (first)
    convert_warning_count integer,  -- # of PlanAffectingConvert warnings
    convert_issue         text      -- first PlanAffectingConvert ConvertIssue
)
LANGUAGE sql
STABLE
AS $fn$
    SELECT x.node_id, x.physical_op, x.logical_op, x.estimate_rows, x.est_rows_norowgoal,
           x.est_rows_read, x.estimate_cpu, x.estimate_io, x.subtree_cost, x.avg_row_size,
           x.table_cardinality, x.est_rebinds, x.est_rewinds, (x.parallel = 1), x.exec_mode,
           x.output_cols, x.object_database, x.object_schema, x.object_table, x.object_index,
           x.index_kind, x.predicate, x.seek_predicate, (x.has_warning = 1),
           nullif(x.warning_detail, ''), x.statement_id,
           x.statement_text, x.statement_type, x.est_rows, x.optm_level, x.early_abort_reason,
           x.cardinality_model, x.query_hash, x.query_plan_hash, x.cached_plan_size_kb,
           x.compile_time_ms, x.compile_cpu_ms, x.compile_memory_kb, x.degree_of_parallelism,
           x.nonparallel_reason, x.serial_required_kb, x.serial_desired_kb, x.granted_kb,
           x.max_used_kb, x.missing_index_count, x.missing_index_impact, x.missing_index_table,
           x.convert_warning_count, x.convert_issue
    FROM XMLTABLE(
        XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp),
        '//sp:RelOp'
        PASSING (xmlparse(document p_plan))
        COLUMNS
            node_id            integer PATH '@NodeId',
            physical_op        text    PATH '@PhysicalOp',
            logical_op         text    PATH '@LogicalOp',
            estimate_rows      numeric PATH '@EstimateRows',
            est_rows_norowgoal numeric PATH '@EstimateRowsWithoutRowGoal',
            est_rows_read      numeric PATH '@EstimatedRowsRead',
            estimate_cpu       numeric PATH '@EstimateCPU',
            estimate_io        numeric PATH '@EstimateIO',
            subtree_cost       numeric PATH '@EstimatedTotalSubtreeCost',
            avg_row_size       integer PATH '@AvgRowSize',
            table_cardinality  numeric PATH '@TableCardinality',
            est_rebinds        numeric PATH '@EstimateRebinds',
            est_rewinds        numeric PATH '@EstimateRewinds',
            parallel           integer PATH '@Parallel',
            exec_mode          text    PATH '@EstimatedExecutionMode',
            output_cols        integer PATH 'count(./sp:OutputList/sp:ColumnReference)',
            object_database    text    PATH '(./sp:*/sp:Object/@Database)[1]',
            object_schema      text    PATH '(./sp:*/sp:Object/@Schema)[1]',
            object_table       text    PATH '(./sp:*/sp:Object/@Table)[1]',
            object_index       text    PATH '(./sp:*/sp:Object/@Index)[1]',
            index_kind         text    PATH '(./sp:*/sp:Object/@IndexKind)[1]',
            predicate          text    PATH '(./sp:*/sp:Predicate//@ScalarString)[1]',
            seek_predicate     text    PATH '(./sp:*/sp:SeekPredicates//@ScalarString)[1]',
            has_warning        integer PATH 'count(./sp:Warnings)',
            warning_detail     text    PATH 'local-name((./sp:Warnings/*)[1])',
            -- statement-level (ancestor StmtSimple)
            statement_id       integer PATH '(ancestor::sp:StmtSimple/@StatementId)[1]',
            statement_text     text    PATH '(ancestor::sp:StmtSimple/@StatementText)[1]',
            statement_type     text    PATH '(ancestor::sp:StmtSimple/@StatementType)[1]',
            est_rows           numeric PATH '(ancestor::sp:StmtSimple/@StatementEstRows)[1]',
            optm_level         text    PATH '(ancestor::sp:StmtSimple/@StatementOptmLevel)[1]',
            early_abort_reason text    PATH '(ancestor::sp:StmtSimple/@StatementOptmEarlyAbortReason)[1]',
            cardinality_model  text    PATH '(ancestor::sp:StmtSimple/@CardinalityEstimationModelVersion)[1]',
            query_hash         text    PATH '(ancestor::sp:StmtSimple/@QueryHash)[1]',
            query_plan_hash    text    PATH '(ancestor::sp:StmtSimple/@QueryPlanHash)[1]',
            -- query-plan-level (ancestor QueryPlan)
            cached_plan_size_kb   integer PATH '(ancestor::sp:QueryPlan/@CachedPlanSize)[1]',
            compile_time_ms       integer PATH '(ancestor::sp:QueryPlan/@CompileTime)[1]',
            compile_cpu_ms        integer PATH '(ancestor::sp:QueryPlan/@CompileCPU)[1]',
            compile_memory_kb     integer PATH '(ancestor::sp:QueryPlan/@CompileMemory)[1]',
            degree_of_parallelism integer PATH '(ancestor::sp:QueryPlan/@DegreeOfParallelism)[1]',
            nonparallel_reason    text    PATH '(ancestor::sp:QueryPlan/@NonParallelPlanReason)[1]',
            serial_required_kb    numeric PATH '(ancestor::sp:QueryPlan/sp:MemoryGrantInfo/@SerialRequiredMemory)[1]',
            serial_desired_kb     numeric PATH '(ancestor::sp:QueryPlan/sp:MemoryGrantInfo/@SerialDesiredMemory)[1]',
            granted_kb            numeric PATH '(ancestor::sp:QueryPlan/sp:MemoryGrantInfo/@GrantedMemory)[1]',
            max_used_kb           numeric PATH '(ancestor::sp:QueryPlan/sp:MemoryGrantInfo/@MaxUsedMemory)[1]',
            missing_index_count   integer PATH 'count(ancestor::sp:QueryPlan/sp:MissingIndexes//sp:MissingIndex)',
            missing_index_impact  numeric PATH '(ancestor::sp:QueryPlan/sp:MissingIndexes/sp:MissingIndexGroup/@Impact)[1]',
            missing_index_table   text    PATH '(ancestor::sp:QueryPlan/sp:MissingIndexes//sp:MissingIndex/@Table)[1]',
            convert_warning_count integer PATH 'count(ancestor::sp:QueryPlan/sp:Warnings/sp:PlanAffectingConvert)',
            convert_issue         text    PATH '(ancestor::sp:QueryPlan/sp:Warnings/sp:PlanAffectingConvert/@ConvertIssue)[1]'
    ) AS x
$fn$;

ALTER FUNCTION monitoring.parse_execution_plan(text) OWNER TO dbdome_adm;


-- ============================================================
-- Overload: monitoring.parse_execution_plan(bigint)
--   Convenience wrapper — parse the execution plan(s) stored on ONE capture row,
--   identified by its bigint key. Looks the row up in
--   monitoring.general_metric_metadata_results, expands every execution_plan_xml in
--   that row's metric_metadata, and runs the (text) overload above on each —
--   returning the same per-operator table (49 columns).
--
--   NOTE ON THE KEY: the parameter is the table's bigint PRIMARY KEY `id`. The table
--   also has an `integer` column literally named `row_id`, but it is unused / NULL in
--   this data, so lookup is by `id` (the populated bigint identifier). Rename the
--   WHERE column to r.row_id if that column ever becomes the real key.
--
--   A capture row may hold multiple plans (one per active request); operators from
--   different plans are distinguishable by query_hash / query_plan_hash / statement_*.
--
-- Usage
--   SELECT * FROM monitoring.parse_execution_plan(7454773::bigint) ORDER BY subtree_cost DESC;
--
-- Keep the RETURNS TABLE below in sync with the (text) overload above.
-- Idempotent (DROP+CREATE).
-- ============================================================

DROP FUNCTION IF EXISTS monitoring.parse_execution_plan(bigint);

CREATE OR REPLACE FUNCTION monitoring.parse_execution_plan(p_row_id bigint)
RETURNS TABLE (
    -- ---- operator (RelOp) level ----
    node_id             integer,
    physical_op         text,
    logical_op          text,
    estimate_rows       numeric,
    est_rows_norowgoal  numeric,
    est_rows_read       numeric,
    estimate_cpu        numeric,
    estimate_io         numeric,
    subtree_cost        numeric,
    avg_row_size        integer,
    table_cardinality   numeric,
    est_rebinds         numeric,
    est_rewinds         numeric,
    parallel            boolean,
    exec_mode           text,
    output_cols         integer,
    object_database     text,
    object_schema       text,
    object_table        text,
    object_index        text,
    index_kind          text,
    predicate           text,
    seek_predicate      text,
    has_warning         boolean,
    warning_detail      text,
    -- ---- statement (StmtSimple ancestor) level ----
    statement_id        integer,
    statement_text      text,
    statement_type      text,
    est_rows            numeric,
    optm_level          text,
    early_abort_reason  text,
    cardinality_model   text,
    query_hash          text,
    query_plan_hash     text,
    -- ---- query-plan (QueryPlan ancestor) level ----
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
AS $fn$
    SELECT op.*
    FROM monitoring.general_metric_metadata_results r
    CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) elem
    CROSS JOIN LATERAL monitoring.parse_execution_plan(elem->>'execution_plan_xml') op
    WHERE r.id = p_row_id
      AND elem->>'execution_plan_xml' IS NOT NULL
$fn$;

ALTER FUNCTION monitoring.parse_execution_plan(bigint) OWNER TO dbdome_adm;
