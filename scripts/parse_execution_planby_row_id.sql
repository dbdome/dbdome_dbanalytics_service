-- FUNCTION: monitoring.parse_execution_planby_row_id(bigint)

-- DROP FUNCTION IF EXISTS monitoring.parse_execution_planby_row_id(bigint);

CREATE OR REPLACE FUNCTION monitoring.parse_execution_planby_row_id(
	p_row_id bigint)
    RETURNS TABLE(node_id integer, physical_op text, logical_op text, estimate_rows numeric, est_rows_norowgoal numeric, est_rows_read numeric, estimate_cpu numeric, estimate_io numeric, subtree_cost numeric, avg_row_size integer, table_cardinality numeric, est_rebinds numeric, est_rewinds numeric, parallel boolean, exec_mode text, output_cols integer, object_database text, object_schema text, object_table text, object_index text, index_kind text, predicate text, seek_predicate text, has_warning boolean, warning_detail text, statement_id integer, statement_text text, statement_type text, est_rows numeric, optm_level text, early_abort_reason text, cardinality_model text, query_hash text, query_plan_hash text, cached_plan_size_kb integer, compile_time_ms integer, compile_cpu_ms integer, compile_memory_kb integer, degree_of_parallelism integer, nonparallel_reason text, serial_required_kb numeric, serial_desired_kb numeric, granted_kb numeric, max_used_kb numeric, missing_index_count integer, missing_index_impact numeric, missing_index_table text, convert_warning_count integer, convert_issue text) 
    LANGUAGE 'sql'
    COST 100
    STABLE PARALLEL UNSAFE
    ROWS 1000

AS $BODY$
    SELECT op.*
    FROM monitoring.general_metric_metadata_results r
    CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) elem
    CROSS JOIN LATERAL monitoring.parse_execution_plan(elem->>'execution_plan_xml') op
    WHERE r.id = p_row_id
      AND elem->>'execution_plan_xml' IS NOT NULL
$BODY$;

ALTER FUNCTION monitoring.parse_execution_planby_row_id(bigint)
    OWNER TO dbdome_adm;

