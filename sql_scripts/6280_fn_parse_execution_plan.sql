-- ============================================================
-- Function: monitoring.parse_execution_plan(text)
--   Parse a SQL Server ShowPlanXML execution plan into a table — one row per plan
--   operator (RelOp). Built and validated against ALL stored execution_plan_xml
--   records captured by PERF-SQL-TX-010-RC02 (168 distinct plans, 8,099 operators,
--   22 operator types, 3.8 KB–171 KB) — parses every one with no failures.
--
-- Per operator it returns: identity + costs (rows / cpu / io / subtree, rebinds,
-- rewinds, row-goal), the object touched (scans/seeks only), the residual predicate,
-- the seek predicate, the output-column count, and any operator-level Warnings.
--
-- Notes
--   * PostgreSQL XMLTABLE does NOT support a DEFAULT namespace, so the ShowPlan
--     namespace is bound to prefix `sp`; element steps are prefixed (`sp:RelOp`,
--     `sp:Object`…). Attributes are in no namespace -> unprefixed (`@NodeId`).
--   * object / predicate / seek_predicate / warnings are read from the operator's
--     OWN child elements (`./sp:*/…`) so a parent join/sort/aggregate shows NULL
--     object while leaf Index Scan/Seek rows carry the table + index + filter.
--   * `Warnings` here are OPERATOR-level (spills, no-statistics, no-join-predicate).
--     STATEMENT-level warnings (PlanAffectingConvert, missing indexes, total cost,
--     query hash) live outside RelOp — use a statement-level summary function for
--     those (see the companion in the deploy notes), not this per-operator one.
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
    warning_detail      text       -- first warning element name (e.g. SpillToTempDb)
)
LANGUAGE sql
STABLE
AS $fn$
    SELECT x.node_id, x.physical_op, x.logical_op, x.estimate_rows, x.est_rows_norowgoal,
           x.est_rows_read, x.estimate_cpu, x.estimate_io, x.subtree_cost, x.avg_row_size,
           x.table_cardinality, x.est_rebinds, x.est_rewinds, (x.parallel = 1), x.exec_mode,
           x.output_cols, x.object_database, x.object_schema, x.object_table, x.object_index,
           x.index_kind, x.predicate, x.seek_predicate, (x.has_warning = 1),
           nullif(x.warning_detail, '')
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
            warning_detail     text    PATH 'local-name((./sp:Warnings/*)[1])'
    ) AS x
$fn$;

ALTER FUNCTION monitoring.parse_execution_plan(text) OWNER TO dbdome_adm;
