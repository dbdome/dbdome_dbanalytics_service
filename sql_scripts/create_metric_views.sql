-- Auto-generated views for monitoring.general_metric_metadata_results
-- Generated: 2026-04-09
-- Total views: 605
-- Skipped (no JSON keys): 412
-- Skipped (already exists): 1

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_001_rc03 AS
SELECT
    r.server,
    j.value ->> 'current_connections' AS current_connections,
    j.value ->> 'max_configured' AS max_configured,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'HLTH-SQL-AD-001-RC03';

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_001_rc04 AS
SELECT
    r.server,
    j.value ->> 'total_user_sessions' AS total_user_sessions,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'HLTH-SQL-AD-001-RC04';

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_001_rc06 AS
SELECT
    r.server,
    j.value ->> 'avg_elapsed_us' AS avg_elapsed_us,
    j.value ->> 'avg_reads' AS avg_reads,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'query_text' AS query_text,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'HLTH-SQL-AD-001-RC06';

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_001_rc09 AS
SELECT
    r.server,
    j.value ->> 'name' AS name,
    j.value ->> 'value' AS value,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'HLTH-SQL-AD-001-RC09';

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_001_rc10 AS
SELECT
    r.server,
    j.value ->> 'batch_requests_sec' AS batch_requests_sec,
    j.value ->> 'current_sessions' AS current_sessions,
    j.value ->> 'user_connections_counter' AS user_connections_counter,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'HLTH-SQL-AD-001-RC10';

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_001_rc11 AS
SELECT
    r.server,
    j.value ->> 'current_sessions' AS current_sessions,
    j.value ->> 'max_configured' AS max_configured,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'HLTH-SQL-AD-001-RC11';

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_001_rc12 AS
SELECT
    r.server,
    j.value ->> 'active' AS active,
    j.value ->> 'idle' AS idle,
    j.value ->> 'idle_ratio' AS idle_ratio,
    j.value ->> 'total' AS total,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'HLTH-SQL-AD-001-RC12';

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_ad_001_rc13 AS
SELECT
    r.server,
    j.value ->> 'total_user_sessions' AS total_user_sessions,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'HLTH-SQL-AD-001-RC13';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_001_rc01 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'signal_wait_time_ms' AS signal_wait_time_ms,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-001-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_001_rc02 AS
SELECT
    r.server,
    j.value ->> 'buffer_mb' AS buffer_mb,
    j.value ->> 'buffer_pool_data_mb' AS buffer_pool_data_mb,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'dirty_mb' AS dirty_mb,
    j.value ->> 'dirty_pages' AS dirty_pages,
    j.value ->> 'lazy_writes_per_sec' AS lazy_writes_per_sec,
    j.value ->> 'page_reads_per_sec' AS page_reads_per_sec,
    j.value ->> 'ple_seconds' AS ple_seconds,
    j.value ->> 'total_data_files_mb' AS total_data_files_mb,
    j.value ->> 'total_pages' AS total_pages,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-001-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_001_rc03 AS
SELECT
    r.server,
    j.value ->> 'avg_logical_reads' AS avg_logical_reads,
    j.value ->> 'avg_physical_reads' AS avg_physical_reads,
    j.value ->> 'avg_rows_returned' AS avg_rows_returned,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'query_text' AS query_text,
    j.value ->> 'reads_per_row' AS reads_per_row,
    j.value ->> 'total_logical_reads' AS total_logical_reads,
    j.value ->> 'total_physical_reads' AS total_physical_reads,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-001-RC03';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_001_rc04 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-001-RC04';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_001_rc05 AS
SELECT
    r.server,
    j.value ->> 'avg_elapsed_ms' AS avg_elapsed_ms,
    j.value ->> 'avg_grant_kb' AS avg_grant_kb,
    j.value ->> 'avg_ideal_grant_kb' AS avg_ideal_grant_kb,
    j.value ->> 'avg_logical_reads' AS avg_logical_reads,
    j.value ->> 'avg_spills' AS avg_spills,
    j.value ->> 'avg_used_grant_kb' AS avg_used_grant_kb,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'has_missing_index_hint' AS has_missing_index_hint,
    j.value ->> 'has_no_join_predicate' AS has_no_join_predicate,
    j.value ->> 'has_spill_warning' AS has_spill_warning,
    j.value ->> 'has_warnings' AS has_warnings,
    j.value ->> 'query_text' AS query_text,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-001-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_001_rc06 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'free_list_stalls_per_sec' AS free_list_stalls_per_sec,
    j.value ->> 'longest_request_ms' AS longest_request_ms,
    j.value ->> 'page_io_latch_waiters' AS page_io_latch_waiters,
    j.value ->> 'page_latch_waiters' AS page_latch_waiters,
    j.value ->> 'ple_seconds' AS ple_seconds,
    j.value ->> 'signal_wait_time_ms' AS signal_wait_time_ms,
    j.value ->> 'total_active_requests' AS total_active_requests,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-001-RC06';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_001_rc09 AS
SELECT
    r.server,
    j.value ->> 'avg_logical_reads' AS avg_logical_reads,
    j.value ->> 'avg_rows_returned' AS avg_rows_returned,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'last_actual_rows' AS last_actual_rows,
    j.value ->> 'max_rows' AS max_rows,
    j.value ->> 'min_rows' AS min_rows,
    j.value ->> 'query_text' AS query_text,
    j.value ->> 'total_spills' AS total_spills,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-001-RC09';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_001_rc11 AS
SELECT
    r.server,
    j.value ->> 'forwarded_records_per_sec' AS forwarded_records_per_sec,
    j.value ->> 'full_scans_per_sec' AS full_scans_per_sec,
    j.value ->> 'ghost_cleanup_rate' AS ghost_cleanup_rate,
    j.value ->> 'ple_seconds' AS ple_seconds,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-001-RC11';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_001_rc12 AS
SELECT
    r.server,
    j.value ->> 'bg_writer_pages_per_sec' AS bg_writer_pages_per_sec,
    j.value ->> 'checkpoint_pages_per_sec' AS checkpoint_pages_per_sec,
    j.value ->> 'lazy_writes_per_sec' AS lazy_writes_per_sec,
    j.value ->> 'page_writes_per_sec' AS page_writes_per_sec,
    j.value ->> 'ple_seconds' AS ple_seconds,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-001-RC12';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_001_rc13 AS
SELECT
    r.server,
    j.value ->> 'clerk_name' AS clerk_name,
    j.value ->> 'clerk_type' AS clerk_type,
    j.value ->> 'committed_mb' AS committed_mb,
    j.value ->> 'locked_pages_mb' AS locked_pages_mb,
    j.value ->> 'memory_low_notification' AS memory_low_notification,
    j.value ->> 'memory_mb' AS memory_mb,
    j.value ->> 'memory_utilization_percentage' AS memory_utilization_percentage,
    j.value ->> 'os_available_memory_mb' AS os_available_memory_mb,
    j.value ->> 'os_total_memory_mb' AS os_total_memory_mb,
    j.value ->> 'page_fault_count' AS page_fault_count,
    j.value ->> 'sql_physical_memory_mb' AS sql_physical_memory_mb,
    j.value ->> 'system_memory_state_desc' AS system_memory_state_desc,
    j.value ->> 'virtual_memory_low' AS virtual_memory_low,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-001-RC13';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_002_rc01 AS
SELECT
    r.server,
    j.value ->> 'objtype' AS objtype,
    j.value ->> 'plan_count' AS plan_count,
    j.value ->> 'single_use_count' AS single_use_count,
    j.value ->> 'single_use_pct' AS single_use_pct,
    j.value ->> 'single_use_size_mb' AS single_use_size_mb,
    j.value ->> 'total_size_mb' AS total_size_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-002-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_002_rc04 AS
SELECT
    r.server,
    j.value ->> 'exec_plans' AS exec_plans,
    j.value ->> 'objtype' AS objtype,
    j.value ->> 'parameterized_plans' AS parameterized_plans,
    j.value ->> 'plan_kb' AS plan_kb,
    j.value ->> 'query_text' AS query_text,
    j.value ->> 'single_use_adhoc' AS single_use_adhoc,
    j.value ->> 'single_use_mb' AS single_use_mb,
    j.value ->> 'sql_plan_count' AS sql_plan_count,
    j.value ->> 'total_cache_objects' AS total_cache_objects,
    j.value ->> 'usecounts' AS usecounts,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-002-RC04';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_002_rc05 AS
SELECT
    r.server,
    j.value ->> 'active_sessions' AS active_sessions,
    j.value ->> 'client_interface_name' AS client_interface_name,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'single_use_cache_mb' AS single_use_cache_mb,
    j.value ->> 'total_cache_mb' AS total_cache_mb,
    j.value ->> 'total_single_use_plans' AS total_single_use_plans,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-002-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_002_rc08 AS
SELECT
    r.server,
    j.value ->> 'name' AS name,
    j.value ->> 'single_use_mb' AS single_use_mb,
    j.value ->> 'single_use_pct' AS single_use_pct,
    j.value ->> 'single_use_plans' AS single_use_plans,
    j.value ->> 'total_cache_mb' AS total_cache_mb,
    j.value ->> 'total_plans' AS total_plans,
    j.value ->> 'value_in_use' AS value_in_use,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-002-RC08';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_002_rc09 AS
SELECT
    r.server,
    j.value ->> 'cache_mb' AS cache_mb,
    j.value ->> 'cache_type' AS cache_type,
    j.value ->> 'pages_kb' AS pages_kb,
    j.value ->> 'temp_proc_cache_mb' AS temp_proc_cache_mb,
    j.value ->> 'temp_proc_plans' AS temp_proc_plans,
    j.value ->> 'total_executions' AS total_executions,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-002-RC09';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_002_rc11 AS
SELECT
    r.server,
    j.value ->> 'active_cursors' AS active_cursors,
    j.value ->> 'cursor_requests' AS cursor_requests,
    j.value ->> 'open_cursors_all_sessions' AS open_cursors_all_sessions,
    j.value ->> 'prepared_plan_cache_mb' AS prepared_plan_cache_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-002-RC11';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_002_rc12 AS
SELECT
    r.server,
    j.value ->> 'buffer_pool_mb' AS buffer_pool_mb,
    j.value ->> 'cache_status' AS cache_status,
    j.value ->> 'compilations' AS compilations,
    j.value ->> 'entries_count' AS entries_count,
    j.value ->> 'entries_in_use_count' AS entries_in_use_count,
    j.value ->> 'name' AS name,
    j.value ->> 'pages_in_use_kb' AS pages_in_use_kb,
    j.value ->> 'pages_kb' AS pages_kb,
    j.value ->> 'plan_stores_mb' AS plan_stores_mb,
    j.value ->> 'recompilations' AS recompilations,
    j.value ->> 'total_plan_cache_mb' AS total_plan_cache_mb,
    j.value ->> 'type' AS type,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-002-RC12';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_003_rc02 AS
SELECT
    r.server,
    j.value ->> 'active_snapshot_txns' AS active_snapshot_txns,
    j.value ->> 'current_ghost_records' AS current_ghost_records,
    j.value ->> 'ghost_cleanup_waiting' AS ghost_cleanup_waiting,
    j.value ->> 'ghost_records_cleaned' AS ghost_records_cleaned,
    j.value ->> 'ghost_records_created' AS ghost_records_created,
    j.value ->> 'oldest_active_txn_sec' AS oldest_active_txn_sec,
    j.value ->> 'version_store_kb' AS version_store_kb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-003-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_003_rc03 AS
SELECT
    r.server,
    j.value ->> 'internal_objects_mb' AS internal_objects_mb,
    j.value ->> 'user_objects_mb' AS user_objects_mb,
    j.value ->> 'version_store_mb' AS version_store_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-003-RC03';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_003_rc04 AS
SELECT
    r.server,
    j.value ->> 'current_ghost_rows' AS current_ghost_rows,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'total_deletes' AS total_deletes,
    j.value ->> 'total_modifications' AS total_modifications,
    j.value ->> 'total_updates' AS total_updates,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-003-RC04';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_003_rc11 AS
SELECT
    r.server,
    j.value ->> 'highly_modified_stats' AS highly_modified_stats,
    j.value ->> 'most_recent_update' AS most_recent_update,
    j.value ->> 'stale_stats_30d' AS stale_stats_30d,
    j.value ->> 'stale_stats_7d' AS stale_stats_7d,
    j.value ->> 'total_stats' AS total_stats,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-003-RC11';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_003_rc14 AS
SELECT
    r.server,
    j.value ->> 'avg_fragmentation' AS avg_fragmentation,
    j.value ->> 'indexes_over_30pct' AS indexes_over_30pct,
    j.value ->> 'indexes_over_50pct' AS indexes_over_50pct,
    j.value ->> 'indexes_over_80pct' AS indexes_over_80pct,
    j.value ->> 'total_indexes_checked' AS total_indexes_checked,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-003-RC14';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_004_rc01 AS
SELECT
    r.server,
    j.value ->> 'entries_count' AS entries_count,
    j.value ->> 'entries_in_use_count' AS entries_in_use_count,
    j.value ->> 'max_wait_time_ms' AS max_wait_time_ms,
    j.value ->> 'name' AS name,
    j.value ->> 'pages_in_use_kb' AS pages_in_use_kb,
    j.value ->> 'pages_kb' AS pages_kb,
    j.value ->> 'signal_wait_time_ms' AS signal_wait_time_ms,
    j.value ->> 'type' AS type,
    j.value ->> 'usage_pct' AS usage_pct,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-004-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_004_rc02 AS
SELECT
    r.server,
    j.value ->> 'batch_requests_sec' AS batch_requests_sec,
    j.value ->> 'compilations_sec' AS compilations_sec,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'plan_generation_num' AS plan_generation_num,
    j.value ->> 'query_text' AS query_text,
    j.value ->> 'recompilations_sec' AS recompilations_sec,
    j.value ->> 'recompile_ratio' AS recompile_ratio,
    j.value ->> 'total_elapsed_ms' AS total_elapsed_ms,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-004-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_004_rc03 AS
SELECT
    r.server,
    j.value ->> 'cache_hit_ratio_base' AS cache_hit_ratio_base,
    j.value ->> 'cache_hit_ratio_divisor' AS cache_hit_ratio_divisor,
    j.value ->> 'cache_pages' AS cache_pages,
    j.value ->> 'cached_plans_count' AS cached_plans_count,
    j.value ->> 'clerk_type' AS clerk_type,
    j.value ->> 'name' AS name,
    j.value ->> 'pct_of_total_clerks' AS pct_of_total_clerks,
    j.value ->> 'physical_memory_low' AS physical_memory_low,
    j.value ->> 'size_mb' AS size_mb,
    j.value ->> 'total_kb' AS total_kb,
    j.value ->> 'type' AS type,
    j.value ->> 'virtual_memory_low' AS virtual_memory_low,
    j.value ->> 'vm_committed_kb' AS vm_committed_kb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-004-RC03';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_004_rc04 AS
SELECT
    r.server,
    j.value ->> 'plan_count' AS plan_count,
    j.value ->> 'plan_type' AS plan_type,
    j.value ->> 'single_use_mb' AS single_use_mb,
    j.value ->> 'single_use_pct' AS single_use_pct,
    j.value ->> 'single_use_plans' AS single_use_plans,
    j.value ->> 'total_size_mb' AS total_size_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-004-RC04';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_004_rc05 AS
SELECT
    r.server,
    j.value ->> 'auto_created' AS auto_created,
    j.value ->> 'auto_param_attempts_sec' AS auto_param_attempts_sec,
    j.value ->> 'compilations_sec' AS compilations_sec,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'is_auto_create_stats_on' AS is_auto_create_stats_on,
    j.value ->> 'is_auto_update_stats_async_on' AS is_auto_update_stats_async_on,
    j.value ->> 'is_auto_update_stats_on' AS is_auto_update_stats_on,
    j.value ->> 'last_updated' AS last_updated,
    j.value ->> 'modification_counter' AS modification_counter,
    j.value ->> 'modification_pct' AS modification_pct,
    j.value ->> 'recompilations_sec' AS recompilations_sec,
    j.value ->> 'rows' AS rows,
    j.value ->> 'rows_sampled' AS rows_sampled,
    j.value ->> 'stats_name' AS stats_name,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'user_created' AS user_created,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-004-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_004_rc09 AS
SELECT
    r.server,
    j.value ->> 'avg_elapsed_ms' AS avg_elapsed_ms,
    j.value ->> 'cmemthread_wait_ms' AS cmemthread_wait_ms,
    j.value ->> 'cmemthread_waits' AS cmemthread_waits,
    j.value ->> 'entries_count' AS entries_count,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'name' AS name,
    j.value ->> 'pages_kb' AS pages_kb,
    j.value ->> 'plan_generation_num' AS plan_generation_num,
    j.value ->> 'plan_size_kb' AS plan_size_kb,
    j.value ->> 'query_text' AS query_text,
    j.value ->> 'total_cpu_ms' AS total_cpu_ms,
    j.value ->> 'total_elapsed_ms' AS total_elapsed_ms,
    j.value ->> 'type' AS type,
    j.value ->> 'usecounts' AS usecounts,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-004-RC09';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_004_rc10 AS
SELECT
    r.server,
    j.value ->> 'plan_count' AS plan_count,
    j.value ->> 'plan_type' AS plan_type,
    j.value ->> 'single_use' AS single_use,
    j.value ->> 'total_mb' AS total_mb,
    j.value ->> 'wasted_mb' AS wasted_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-004-RC10';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_004_rc11 AS
SELECT
    r.server,
    j.value ->> 'avg_elapsed_ms' AS avg_elapsed_ms,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'objtype' AS objtype,
    j.value ->> 'plan_kb' AS plan_kb,
    j.value ->> 'query_text' AS query_text,
    j.value ->> 'sniffed_value_1' AS sniffed_value_1,
    j.value ->> 'usecounts' AS usecounts,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-004-RC11';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_004_rc12 AS
SELECT
    r.server,
    j.value ->> 'avg_reuse' AS avg_reuse,
    j.value ->> 'cache_mb' AS cache_mb,
    j.value ->> 'cached_plans' AS cached_plans,
    j.value ->> 'cpu_count' AS cpu_count,
    j.value ->> 'objtype' AS objtype,
    j.value ->> 'physical_memory_mb' AS physical_memory_mb,
    j.value ->> 'sqlserver_start_time' AS sqlserver_start_time,
    j.value ->> 'uptime_hours' AS uptime_hours,
    j.value ->> 'uptime_minutes' AS uptime_minutes,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-004-RC12';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_005_rc01 AS
SELECT
    r.server,
    j.value ->> 'column_name' AS column_name,
    j.value ->> 'data_type' AS data_type,
    j.value ->> 'default_value' AS default_value,
    j.value ->> 'index_name' AS index_name,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-005-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_005_rc04 AS
SELECT
    r.server,
    j.value ->> 'effective_fill_factor' AS effective_fill_factor,
    j.value ->> 'fill_factor' AS fill_factor,
    j.value ->> 'index_name' AS index_name,
    j.value ->> 'leaf_insert_count' AS leaf_insert_count,
    j.value ->> 'leaf_update_count' AS leaf_update_count,
    j.value ->> 'page_splits' AS page_splits,
    j.value ->> 'split_rate_pct' AS split_rate_pct,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-005-RC04';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_005_rc05 AS
SELECT
    r.server,
    j.value ->> 'assessment' AS assessment,
    j.value ->> 'effective_fill_factor' AS effective_fill_factor,
    j.value ->> 'index_name' AS index_name,
    j.value ->> 'leaf_delete_count' AS leaf_delete_count,
    j.value ->> 'leaf_insert_count' AS leaf_insert_count,
    j.value ->> 'leaf_update_count' AS leaf_update_count,
    j.value ->> 'page_splits' AS page_splits,
    j.value ->> 'split_rate_pct' AS split_rate_pct,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-005-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_005_rc06 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'signal_wait_time_ms' AS signal_wait_time_ms,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-005-RC06';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_005_rc09 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-005-RC09';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ce_005_rc10 AS
SELECT
    r.server,
    j.value ->> 'index_name' AS index_name,
    j.value ->> 'insert_pattern' AS insert_pattern,
    j.value ->> 'leaf_delete_count' AS leaf_delete_count,
    j.value ->> 'leaf_insert_count' AS leaf_insert_count,
    j.value ->> 'nonleaf_splits' AS nonleaf_splits,
    j.value ->> 'page_splits' AS page_splits,
    j.value ->> 'range_scan_count' AS range_scan_count,
    j.value ->> 'singleton_lookup_count' AS singleton_lookup_count,
    j.value ->> 'table_name' AS table_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CE-005-RC10';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_001_rc01 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'max_user_connections' AS max_user_connections,
    j.value ->> 'running_sessions' AS running_sessions,
    j.value ->> 'sleeping_sessions' AS sleeping_sessions,
    j.value ->> 'suspended_sessions' AS suspended_sessions,
    j.value ->> 'total_connections' AS total_connections,
    j.value ->> 'user_sessions' AS user_sessions,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-001-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_001_rc02 AS
SELECT
    r.server,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'idle_since_seconds' AS idle_since_seconds,
    j.value ->> 'last_request_end_time' AS last_request_end_time,
    j.value ->> 'last_request_start_time' AS last_request_start_time,
    j.value ->> 'last_sql' AS last_sql,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'login_time' AS login_time,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'state_desc' AS state_desc,
    j.value ->> 'status' AS status,
    j.value ->> 'transaction_age_seconds' AS transaction_age_seconds,
    j.value ->> 'transaction_begin_time' AS transaction_begin_time,
    j.value ->> 'transaction_state' AS transaction_state,
    j.value ->> 'transaction_type' AS transaction_type,
    j.value ->> 'txn_age_seconds' AS txn_age_seconds,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-001-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_001_rc03 AS
SELECT
    r.server,
    j.value ->> 'connect_time' AS connect_time,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'idle_minutes' AS idle_minutes,
    j.value ->> 'last_request_end_time' AS last_request_end_time,
    j.value ->> 'last_request_start_time' AS last_request_start_time,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'login_time' AS login_time,
    j.value ->> 'num_reads' AS num_reads,
    j.value ->> 'num_writes' AS num_writes,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_age_minutes' AS session_age_minutes,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'status' AS status,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-001-RC03';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_001_rc04 AS
SELECT
    r.server,
    j.value ->> 'avg_elapsed_ms' AS avg_elapsed_ms,
    j.value ->> 'avg_logical_reads' AS avg_logical_reads,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'max_elapsed_ms' AS max_elapsed_ms,
    j.value ->> 'query_text' AS query_text,
    j.value ->> 'total_elapsed_ms' AS total_elapsed_ms,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-001-RC04';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_001_rc07 AS
SELECT
    r.server,
    j.value ->> 'avg_sessions_per_host' AS avg_sessions_per_host,
    j.value ->> 'distinct_hosts' AS distinct_hosts,
    j.value ->> 'earliest_login' AS earliest_login,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'latest_request' AS latest_request,
    j.value ->> 'max_connections' AS max_connections,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'running' AS running,
    j.value ->> 'server_total_sessions' AS server_total_sessions,
    j.value ->> 'session_count' AS session_count,
    j.value ->> 'sleeping' AS sleeping,
    j.value ->> 'suspended' AS suspended,
    j.value ->> 'total_sessions' AS total_sessions,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-001-RC07';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_001_rc08 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_seconds' AS avg_wait_seconds,
    j.value ->> 'max_wait_seconds' AS max_wait_seconds,
    j.value ->> 'total_wait_seconds' AS total_wait_seconds,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-001-RC08';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_001_rc09 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'max_wait_time_ms' AS max_wait_time_ms,
    j.value ->> 'total_wait_seconds' AS total_wait_seconds,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-001-RC09';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_001_rc11 AS
SELECT
    r.server,
    j.value ->> 'connect_time' AS connect_time,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'idle_since_minutes' AS idle_since_minutes,
    j.value ->> 'last_request_end_time' AS last_request_end_time,
    j.value ->> 'last_request_start_time' AS last_request_start_time,
    j.value ->> 'login_time' AS login_time,
    j.value ->> 'num_reads' AS num_reads,
    j.value ->> 'num_writes' AS num_writes,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_age_minutes' AS session_age_minutes,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'status' AS status,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-001-RC11';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_001_rc13 AS
SELECT
    r.server,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'idle_hours' AS idle_hours,
    j.value ->> 'last_request_end_time' AS last_request_end_time,
    j.value ->> 'last_request_start_time' AS last_request_start_time,
    j.value ->> 'login_time' AS login_time,
    j.value ->> 'num_reads' AS num_reads,
    j.value ->> 'num_writes' AS num_writes,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_age_hours' AS session_age_hours,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'status' AS status,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-001-RC13';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_002_rc01 AS
SELECT
    r.server,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'idle_minutes' AS idle_minutes,
    j.value ->> 'last_request_end_time' AS last_request_end_time,
    j.value ->> 'last_request_start_time' AS last_request_start_time,
    j.value ->> 'login_time' AS login_time,
    j.value ->> 'num_reads' AS num_reads,
    j.value ->> 'num_writes' AS num_writes,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'txn_status' AS txn_status,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-002-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_002_rc02 AS
SELECT
    r.server,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'idle_minutes' AS idle_minutes,
    j.value ->> 'last_request_end_time' AS last_request_end_time,
    j.value ->> 'last_request_start_time' AS last_request_start_time,
    j.value ->> 'last_sql' AS last_sql,
    j.value ->> 'login_time' AS login_time,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'state_desc' AS state_desc,
    j.value ->> 'status' AS status,
    j.value ->> 'transaction_begin_time' AS transaction_begin_time,
    j.value ->> 'transaction_state' AS transaction_state,
    j.value ->> 'txn_age_minutes' AS txn_age_minutes,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-002-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_002_rc03 AS
SELECT
    r.server,
    j.value ->> 'connect_time' AS connect_time,
    j.value ->> 'current_user_connections' AS current_user_connections,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'idle_minutes' AS idle_minutes,
    j.value ->> 'last_request_end_time' AS last_request_end_time,
    j.value ->> 'login_time' AS login_time,
    j.value ->> 'num_reads' AS num_reads,
    j.value ->> 'num_writes' AS num_writes,
    j.value ->> 'open_transaction_count' AS open_transaction_count,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_age_hours' AS session_age_hours,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'stale_sessions_24h' AS stale_sessions_24h,
    j.value ->> 'stale_sessions_72h' AS stale_sessions_72h,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-002-RC03';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_002_rc04 AS
SELECT
    r.server,
    j.value ->> 'idle_minutes' AS idle_minutes,
    j.value ->> 'last_request_end_time' AS last_request_end_time,
    j.value ->> 'login_time' AS login_time,
    j.value ->> 'num_reads' AS num_reads,
    j.value ->> 'num_writes' AS num_writes,
    j.value ->> 'open_transaction_count' AS open_transaction_count,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_id' AS session_id,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-002-RC04';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_002_rc06 AS
SELECT
    r.server,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'idle_minutes' AS idle_minutes,
    j.value ->> 'last_query' AS last_query,
    j.value ->> 'last_request_end_time' AS last_request_end_time,
    j.value ->> 'login_time' AS login_time,
    j.value ->> 'open_transaction_count' AS open_transaction_count,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_id' AS session_id,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-002-RC06';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_002_rc09 AS
SELECT
    r.server,
    j.value ->> 'idle_bucket' AS idle_bucket,
    j.value ->> 'session_count' AS session_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-002-RC09';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_002_rc10 AS
SELECT
    r.server,
    j.value ->> 'client_net_address' AS client_net_address,
    j.value ->> 'current_connections' AS current_connections,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'idle_minutes' AS idle_minutes,
    j.value ->> 'last_request_end_time' AS last_request_end_time,
    j.value ->> 'login_time' AS login_time,
    j.value ->> 'logins_per_sec' AS logins_per_sec,
    j.value ->> 'logouts_per_sec' AS logouts_per_sec,
    j.value ->> 'net_transport' AS net_transport,
    j.value ->> 'num_reads' AS num_reads,
    j.value ->> 'num_writes' AS num_writes,
    j.value ->> 'open_transaction_count' AS open_transaction_count,
    j.value ->> 'orphaned_sessions' AS orphaned_sessions,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_id' AS session_id,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-002-RC10';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_002_rc12 AS
SELECT
    r.server,
    j.value ->> 'blocked_session_count' AS blocked_session_count,
    j.value ->> 'database_transaction_log_bytes_reserved' AS database_transaction_log_bytes_reserved,
    j.value ->> 'database_transaction_log_bytes_used' AS database_transaction_log_bytes_used,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'idle_minutes' AS idle_minutes,
    j.value ->> 'last_request_end_time' AS last_request_end_time,
    j.value ->> 'log_reuse_wait_desc' AS log_reuse_wait_desc,
    j.value ->> 'log_since_backup_mb' AS log_since_backup_mb,
    j.value ->> 'log_used_mb' AS log_used_mb,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'transaction_begin_time' AS transaction_begin_time,
    j.value ->> 'transaction_id' AS transaction_id,
    j.value ->> 'transaction_name' AS transaction_name,
    j.value ->> 'txn_age_minutes' AS txn_age_minutes,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-002-RC12';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_002_rc13 AS
SELECT
    r.server,
    j.value ->> 'active_duration_min' AS active_duration_min,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'idle_since_min' AS idle_since_min,
    j.value ->> 'last_request_duration_sec' AS last_request_duration_sec,
    j.value ->> 'last_request_end_time' AS last_request_end_time,
    j.value ->> 'last_request_start_time' AS last_request_start_time,
    j.value ->> 'login_time' AS login_time,
    j.value ->> 'num_reads' AS num_reads,
    j.value ->> 'num_writes' AS num_writes,
    j.value ->> 'open_transaction_count' AS open_transaction_count,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_id' AS session_id,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-002-RC13';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_003_rc01 AS
SELECT
    r.server,
    j.value ->> 'active_sessions' AS active_sessions,
    j.value ->> 'avg_session_age_sec' AS avg_session_age_sec,
    j.value ->> 'max_session_age_sec' AS max_session_age_sec,
    j.value ->> 'min_session_age_sec' AS min_session_age_sec,
    j.value ->> 'program_name' AS program_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-003-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_003_rc02 AS
SELECT
    r.server,
    j.value ->> 'session_age_bucket' AS session_age_bucket,
    j.value ->> 'session_count' AS session_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-003-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_003_rc05 AS
SELECT
    r.server,
    j.value ->> 'auth_scheme' AS auth_scheme,
    j.value ->> 'current_database' AS current_database,
    j.value ->> 'encrypt_option' AS encrypt_option,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_count' AS session_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-003-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_003_rc06 AS
SELECT
    r.server,
    j.value ->> 'active_sessions' AS active_sessions,
    j.value ->> 'client_net_address' AS client_net_address,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'sessions_from_host' AS sessions_from_host,
    j.value ->> 'sleeping_sessions' AS sleeping_sessions,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-003-RC06';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_003_rc08 AS
SELECT
    r.server,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'query_text' AS query_text,
    j.value ->> 'total_cpu_ms' AS total_cpu_ms,
    j.value ->> 'total_elapsed_ms' AS total_elapsed_ms,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-003-RC08';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_003_rc09 AS
SELECT
    r.server,
    j.value ->> 'connection_resets_sec' AS connection_resets_sec,
    j.value ->> 'current_connections' AS current_connections,
    j.value ->> 'logins_sec' AS logins_sec,
    j.value ->> 'logouts_sec' AS logouts_sec,
    j.value ->> 'max_wait_time_ms' AS max_wait_time_ms,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-003-RC09';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_003_rc10 AS
SELECT
    r.server,
    j.value ->> 'avg_connection_age_sec' AS avg_connection_age_sec,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'connection_resets_sec' AS connection_resets_sec,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'logins_sec' AS logins_sec,
    j.value ->> 'logouts_sec' AS logouts_sec,
    j.value ->> 'max_connection_age_sec' AS max_connection_age_sec,
    j.value ->> 'min_connection_age_sec' AS min_connection_age_sec,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_count' AS session_count,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-003-RC10';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_003_rc11 AS
SELECT
    r.server,
    j.value ->> 'connect_minute' AS connect_minute,
    j.value ->> 'connections_created' AS connections_created,
    j.value ->> 'earliest_connection' AS earliest_connection,
    j.value ->> 'latest_connection' AS latest_connection,
    j.value ->> 'restart_status' AS restart_status,
    j.value ->> 'sqlserver_start_time' AS sqlserver_start_time,
    j.value ->> 'uptime_minutes' AS uptime_minutes,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-003-RC11';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_003_rc12 AS
SELECT
    r.server,
    j.value ->> 'active_sessions' AS active_sessions,
    j.value ->> 'avg_age_sec' AS avg_age_sec,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'batch_requests_sec' AS batch_requests_sec,
    j.value ->> 'connection_resets_sec' AS connection_resets_sec,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'logins_sec' AS logins_sec,
    j.value ->> 'logouts_sec' AS logouts_sec,
    j.value ->> 'min_age_sec' AS min_age_sec,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-003-RC12';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_003_rc13 AS
SELECT
    r.server,
    j.value ->> 'avg_uses' AS avg_uses,
    j.value ->> 'batch_requests_sec' AS batch_requests_sec,
    j.value ->> 'compilation_pct_of_batches' AS compilation_pct_of_batches,
    j.value ->> 'compilations_sec' AS compilations_sec,
    j.value ->> 'plan_count' AS plan_count,
    j.value ->> 'plan_type' AS plan_type,
    j.value ->> 'recompilations_sec' AS recompilations_sec,
    j.value ->> 'total_size_mb' AS total_size_mb,
    j.value ->> 'total_uses' AS total_uses,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-003-RC13';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_003_rc14 AS
SELECT
    r.server,
    j.value ->> 'avg_elapsed_us' AS avg_elapsed_us,
    j.value ->> 'avg_rows' AS avg_rows,
    j.value ->> 'batch_requests_sec' AS batch_requests_sec,
    j.value ->> 'connection_resets_sec' AS connection_resets_sec,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'logins_sec' AS logins_sec,
    j.value ->> 'query_prefix' AS query_prefix,
    j.value ->> 'user_connections' AS user_connections,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-003-RC14';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_003_rc15 AS
SELECT
    r.server,
    j.value ->> 'connection_resets_sec' AS connection_resets_sec,
    j.value ->> 'errors_sec' AS errors_sec,
    j.value ->> 'logins_sec' AS logins_sec,
    j.value ->> 'logouts_sec' AS logouts_sec,
    j.value ->> 'max_wait_time_ms' AS max_wait_time_ms,
    j.value ->> 'signal_wait_time_ms' AS signal_wait_time_ms,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-003-RC15';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_004_rc01 AS
SELECT
    r.server,
    j.value ->> 'active_requests' AS active_requests,
    j.value ->> 'active_workers' AS active_workers,
    j.value ->> 'configured_max_connections' AS configured_max_connections,
    j.value ->> 'configured_max_workers' AS configured_max_workers,
    j.value ->> 'current_connections' AS current_connections,
    j.value ->> 'current_user_sessions' AS current_user_sessions,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'max_wait_time_ms' AS max_wait_time_ms,
    j.value ->> 'max_workers_any_scheduler' AS max_workers_any_scheduler,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_count' AS session_count,
    j.value ->> 'signal_wait_time_ms' AS signal_wait_time_ms,
    j.value ->> 'sleeping_sessions' AS sleeping_sessions,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-004-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_004_rc02 AS
SELECT
    r.server,
    j.value ->> 'active_workers' AS active_workers,
    j.value ->> 'connect_minute' AS connect_minute,
    j.value ->> 'connections_per_minute' AS connections_per_minute,
    j.value ->> 'current_login_rate' AS current_login_rate,
    j.value ->> 'current_sessions' AS current_sessions,
    j.value ->> 'current_total_connections' AS current_total_connections,
    j.value ->> 'logins_sec' AS logins_sec,
    j.value ->> 'logouts_sec' AS logouts_sec,
    j.value ->> 'max_wait_time_ms' AS max_wait_time_ms,
    j.value ->> 'severity' AS severity,
    j.value ->> 'signal_wait_time_ms' AS signal_wait_time_ms,
    j.value ->> 'user_errors_sec' AS user_errors_sec,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-004-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_004_rc03 AS
SELECT
    r.server,
    j.value ->> 'avg_connections_per_host' AS avg_connections_per_host,
    j.value ->> 'avg_connections_per_program' AS avg_connections_per_program,
    j.value ->> 'configured_max' AS configured_max,
    j.value ->> 'distinct_client_hosts' AS distinct_client_hosts,
    j.value ->> 'distinct_programs' AS distinct_programs,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'max_workers' AS max_workers,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'running_count' AS running_count,
    j.value ->> 'running_sessions' AS running_sessions,
    j.value ->> 'session_count' AS session_count,
    j.value ->> 'sleeping_count' AS sleeping_count,
    j.value ->> 'sleeping_pct' AS sleeping_pct,
    j.value ->> 'sleeping_sessions' AS sleeping_sessions,
    j.value ->> 'total_connections' AS total_connections,
    j.value ->> 'total_user_sessions' AS total_user_sessions,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-004-RC03';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_004_rc04 AS
SELECT
    r.server,
    j.value ->> 'configured_max_workers' AS configured_max_workers,
    j.value ->> 'configured_value' AS configured_value,
    j.value ->> 'max_wait_time_ms' AS max_wait_time_ms,
    j.value ->> 'max_workers_per_scheduler' AS max_workers_per_scheduler,
    j.value ->> 'name' AS name,
    j.value ->> 'running_max_workers' AS running_max_workers,
    j.value ->> 'running_value' AS running_value,
    j.value ->> 'scheduler_count' AS scheduler_count,
    j.value ->> 'status' AS status,
    j.value ->> 'total_active_workers' AS total_active_workers,
    j.value ->> 'total_queued_tasks' AS total_queued_tasks,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-004-RC04';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_004_rc05 AS
SELECT
    r.server,
    j.value ->> 'active_workers' AS active_workers,
    j.value ->> 'admin_tool_sessions' AS admin_tool_sessions,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'idle_minutes' AS idle_minutes,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'max_workers' AS max_workers,
    j.value ->> 'open_transaction_count' AS open_transaction_count,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_category' AS session_category,
    j.value ->> 'session_count' AS session_count,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'sleeping_count' AS sleeping_count,
    j.value ->> 'status' AS status,
    j.value ->> 'threadpool_waits' AS threadpool_waits,
    j.value ->> 'total_sessions' AS total_sessions,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-004-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_004_rc06 AS
SELECT
    r.server,
    j.value ->> 'active_workers' AS active_workers,
    j.value ->> 'max_connections' AS max_connections,
    j.value ->> 'max_workers' AS max_workers,
    j.value ->> 'repl_count' AS repl_count,
    j.value ->> 'replication_sessions' AS replication_sessions,
    j.value ->> 'threadpool_waits' AS threadpool_waits,
    j.value ->> 'total_user_sessions' AS total_user_sessions,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-004-RC06';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_004_rc07 AS
SELECT
    r.server,
    j.value ->> 'active_workers' AS active_workers,
    j.value ->> 'client_net_address' AS client_net_address,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'idle_hours' AS idle_hours,
    j.value ->> 'last_request_end_time' AS last_request_end_time,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'login_time' AS login_time,
    j.value ->> 'max_workers' AS max_workers,
    j.value ->> 'open_transaction_count' AS open_transaction_count,
    j.value ->> 'orphaned_estimate' AS orphaned_estimate,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'status' AS status,
    j.value ->> 'total_user_sessions' AS total_user_sessions,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-004-RC07';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_004_rc08 AS
SELECT
    r.server,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'env_classification' AS env_classification,
    j.value ->> 'non_prod_pct' AS non_prod_pct,
    j.value ->> 'non_prod_sessions' AS non_prod_sessions,
    j.value ->> 'running_count' AS running_count,
    j.value ->> 'session_count' AS session_count,
    j.value ->> 'sleeping_count' AS sleeping_count,
    j.value ->> 'total_sessions' AS total_sessions,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-004-RC08';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_004_rc09 AS
SELECT
    r.server,
    j.value ->> 'avg_connection_age_min' AS avg_connection_age_min,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'hung_with_open_txn' AS hung_with_open_txn,
    j.value ->> 'long_lived_sessions' AS long_lived_sessions,
    j.value ->> 'max_connection_age_min' AS max_connection_age_min,
    j.value ->> 'open_txn_sessions' AS open_txn_sessions,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_count' AS session_count,
    j.value ->> 'threadpool_waits' AS threadpool_waits,
    j.value ->> 'total_sessions' AS total_sessions,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-004-RC09';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_004_rc10 AS
SELECT
    r.server,
    j.value ->> 'active_workers' AS active_workers,
    j.value ->> 'max_sessions_single_source' AS max_sessions_single_source,
    j.value ->> 'max_workers' AS max_workers,
    j.value ->> 'total_sessions' AS total_sessions,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-004-RC10';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_004_rc11 AS
SELECT
    r.server,
    j.value ->> 'active_workers' AS active_workers,
    j.value ->> 'current_user_sessions' AS current_user_sessions,
    j.value ->> 'max_user_connections' AS max_user_connections,
    j.value ->> 'max_wait_time_ms' AS max_wait_time_ms,
    j.value ->> 'max_worker_threads' AS max_worker_threads,
    j.value ->> 'max_workers' AS max_workers,
    j.value ->> 'memory_used_mb' AS memory_used_mb,
    j.value ->> 'resource_governor_enabled' AS resource_governor_enabled,
    j.value ->> 'total_memory_mb' AS total_memory_mb,
    j.value ->> 'user_sessions' AS user_sessions,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    j.value ->> 'worker_utilization_pct' AS worker_utilization_pct,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-004-RC11';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_004_rc13 AS
SELECT
    r.server,
    j.value ->> 'available_memory_mb' AS available_memory_mb,
    j.value ->> 'locked_pages_mb' AS locked_pages_mb,
    j.value ->> 'max_wait_time_ms' AS max_wait_time_ms,
    j.value ->> 'memory_utilization_percentage' AS memory_utilization_percentage,
    j.value ->> 'page_life_expectancy_sec' AS page_life_expectancy_sec,
    j.value ->> 'process_physical_memory_low' AS process_physical_memory_low,
    j.value ->> 'process_virtual_memory_low' AS process_virtual_memory_low,
    j.value ->> 'sql_memory_used_mb' AS sql_memory_used_mb,
    j.value ->> 'stolen_pages' AS stolen_pages,
    j.value ->> 'system_high_memory_signal_state' AS system_high_memory_signal_state,
    j.value ->> 'system_low_memory_signal_state' AS system_low_memory_signal_state,
    j.value ->> 'target_pages' AS target_pages,
    j.value ->> 'total_memory_mb' AS total_memory_mb,
    j.value ->> 'user_errors_sec' AS user_errors_sec,
    j.value ->> 'user_sessions' AS user_sessions,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-004-RC13';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cn_010_rc01 AS
SELECT
    r.server,
    j.value ->> 'auth_scheme' AS auth_scheme,
    j.value ->> 'client_net_address' AS client_net_address,
    j.value ->> 'connected_sec' AS connected_sec,
    j.value ->> 'cpu_time' AS cpu_time,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'last_request_end_time' AS last_request_end_time,
    j.value ->> 'last_request_start_time' AS last_request_start_time,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'login_time' AS login_time,
    j.value ->> 'memory_usage' AS memory_usage,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'reads' AS reads,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'status' AS status,
    j.value ->> 'writes' AS writes,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CN-010-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc01 AS
SELECT
    r.server,
    j.value ->> 'avg_cpu_us' AS avg_cpu_us,
    j.value ->> 'avg_logical_reads' AS avg_logical_reads,
    j.value ->> 'ci_scan_count' AS ci_scan_count,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'key_lookup_count' AS key_lookup_count,
    j.value ->> 'query_plan' AS query_plan,
    j.value ->> 'query_text' AS query_text,
    j.value ->> 'table_scan_count' AS table_scan_count,
    j.value ->> 'total_cpu_us' AS total_cpu_us,
    j.value ->> 'warning_count' AS warning_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-001-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc02 AS
SELECT
    r.server,
    j.value ->> 'avg_cpu_ms' AS avg_cpu_ms,
    j.value ->> 'avg_elapsed_ms' AS avg_elapsed_ms,
    j.value ->> 'avg_logical_reads' AS avg_logical_reads,
    j.value ->> 'creation_time' AS creation_time,
    j.value ->> 'EventTime' AS EventTime,
    j.value ->> 'exec_per_min' AS exec_per_min,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'idle_pct' AS idle_pct,
    j.value ->> 'other_process_cpu_pct' AS other_process_cpu_pct,
    j.value ->> 'plan_age_min' AS plan_age_min,
    j.value ->> 'query_text' AS query_text,
    j.value ->> 'record_id' AS record_id,
    j.value ->> 'sql_cpu_pct' AS sql_cpu_pct,
    j.value ->> 'total_cpu_ms' AS total_cpu_ms,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-001-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc03 AS
SELECT
    r.server,
    j.value ->> 'avg_cpu_ms' AS avg_cpu_ms,
    j.value ->> 'avg_logical_reads' AS avg_logical_reads,
    j.value ->> 'avg_reads' AS avg_reads,
    j.value ->> 'ci_scans' AS ci_scans,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'nc_scans' AS nc_scans,
    j.value ->> 'object_name' AS object_name,
    j.value ->> 'query_plan' AS query_plan,
    j.value ->> 'query_text' AS query_text,
    j.value ->> 'table_scans' AS table_scans,
    j.value ->> 'total_logical_reads' AS total_logical_reads,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-001-RC03';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc05 AS
SELECT
    r.server,
    j.value ->> 'actual_rows' AS actual_rows,
    j.value ->> 'auto_created' AS auto_created,
    j.value ->> 'avg_cpu_ms' AS avg_cpu_ms,
    j.value ->> 'avg_reads' AS avg_reads,
    j.value ->> 'days_since_update' AS days_since_update,
    j.value ->> 'estimated_rows' AS estimated_rows,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'last_updated' AS last_updated,
    j.value ->> 'modification_counter' AS modification_counter,
    j.value ->> 'pct_modified' AS pct_modified,
    j.value ->> 'query_text' AS query_text,
    j.value ->> 'rows_sampled' AS rows_sampled,
    j.value ->> 'stat_name' AS stat_name,
    j.value ->> 'stat_rows' AS stat_rows,
    j.value ->> 'table_name' AS table_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-001-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc06 AS
SELECT
    r.server,
    j.value ->> 'avg_cpu_ms' AS avg_cpu_ms,
    j.value ->> 'avg_reads' AS avg_reads,
    j.value ->> 'cpu_variance_ratio' AS cpu_variance_ratio,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'max_cpu_ms' AS max_cpu_ms,
    j.value ->> 'max_reads' AS max_reads,
    j.value ->> 'min_cpu_ms' AS min_cpu_ms,
    j.value ->> 'min_reads' AS min_reads,
    j.value ->> 'procedure_name' AS procedure_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-001-RC06';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc08 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'pct_of_total_waits' AS pct_of_total_waits,
    j.value ->> 'signal_wait_time_ms' AS signal_wait_time_ms,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-001-RC08';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc10 AS
SELECT
    r.server,
    j.value ->> 'avg_cpu_ms' AS avg_cpu_ms,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'query_text' AS query_text,
    j.value ->> 'udf_operator_count' AS udf_operator_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-001-RC10';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc11 AS
SELECT
    r.server,
    j.value ->> 'cntr_value' AS cntr_value,
    j.value ->> 'counter_name' AS counter_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-001-RC11';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc12 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'pct_of_total' AS pct_of_total,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-001-RC12';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc13 AS
SELECT
    r.server,
    j.value ->> 'cntr_value' AS cntr_value,
    j.value ->> 'counter_name' AS counter_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-001-RC13';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc14 AS
SELECT
    r.server,
    j.value ->> 'avg_cpu_ms' AS avg_cpu_ms,
    j.value ->> 'avg_elapsed_ms' AS avg_elapsed_ms,
    j.value ->> 'avg_grant_kb' AS avg_grant_kb,
    j.value ->> 'avg_spills_per_exec' AS avg_spills_per_exec,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'query_text' AS query_text,
    j.value ->> 'total_spills' AS total_spills,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-001-RC14';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc15 AS
SELECT
    r.server,
    j.value ->> 'available_memory_mb' AS available_memory_mb,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'buffer_cache_hit_ratio' AS buffer_cache_hit_ratio,
    j.value ->> 'free_list_stalls_sec' AS free_list_stalls_sec,
    j.value ->> 'lazy_writes_sec' AS lazy_writes_sec,
    j.value ->> 'memory_grants_pending' AS memory_grants_pending,
    j.value ->> 'page_life_expectancy_sec' AS page_life_expectancy_sec,
    j.value ->> 'resource_semaphore_wait_ms' AS resource_semaphore_wait_ms,
    j.value ->> 'resource_semaphore_waits' AS resource_semaphore_waits,
    j.value ->> 'sql_memory_in_use_mb' AS sql_memory_in_use_mb,
    j.value ->> 'system_memory_state_desc' AS system_memory_state_desc,
    j.value ->> 'total_memory_mb' AS total_memory_mb,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-001-RC15';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc17 AS
SELECT
    r.server,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-001-RC17';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc18 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'bg_writer_pages_sec' AS bg_writer_pages_sec,
    j.value ->> 'checkpoint_pages_sec' AS checkpoint_pages_sec,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'is_auto_update_stats_async_on' AS is_auto_update_stats_async_on,
    j.value ->> 'is_auto_update_stats_on' AS is_auto_update_stats_on,
    j.value ->> 'lazy_writes_sec' AS lazy_writes_sec,
    j.value ->> 'log_flushes_sec' AS log_flushes_sec,
    j.value ->> 'log_reuse_wait_desc' AS log_reuse_wait_desc,
    j.value ->> 'page_writes_sec' AS page_writes_sec,
    j.value ->> 'target_recovery_time_in_seconds' AS target_recovery_time_in_seconds,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-001-RC18';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc19 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'blocking_session_id' AS blocking_session_id,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'duration_sec' AS duration_sec,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'last_sql' AS last_sql,
    j.value ->> 'log_bytes_flushed_sec' AS log_bytes_flushed_sec,
    j.value ->> 'log_flush_wait_ms' AS log_flush_wait_ms,
    j.value ->> 'log_flushes_sec' AS log_flushes_sec,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'tran_name' AS tran_name,
    j.value ->> 'transaction_begin_time' AS transaction_begin_time,
    j.value ->> 'transaction_id' AS transaction_id,
    j.value ->> 'transactions_sec' AS transactions_sec,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-001-RC19';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc21 AS
SELECT
    r.server,
    j.value ->> 'active_workers_count' AS active_workers_count,
    j.value ->> 'avg_cpu_ms' AS avg_cpu_ms,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'context_switches_count' AS context_switches_count,
    j.value ->> 'cpu_id' AS cpu_id,
    j.value ->> 'current_tasks_count' AS current_tasks_count,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'plan_generation_num' AS plan_generation_num,
    j.value ->> 'query_text' AS query_text,
    j.value ->> 'runnable_tasks_count' AS runnable_tasks_count,
    j.value ->> 'scheduler_id' AS scheduler_id,
    j.value ->> 'signal_pct' AS signal_pct,
    j.value ->> 'signal_wait_time_ms' AS signal_wait_time_ms,
    j.value ->> 'switches_per_yield' AS switches_per_yield,
    j.value ->> 'total_cpu_ms' AS total_cpu_ms,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    j.value ->> 'work_queue_count' AS work_queue_count,
    j.value ->> 'yield_count' AS yield_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-001-RC21';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_001_rc22 AS
SELECT
    r.server,
    j.value ->> 'EventTime' AS EventTime,
    j.value ->> 'hyperthread_ratio' AS hyperthread_ratio,
    j.value ->> 'logical_cpus' AS logical_cpus,
    j.value ->> 'OtherProcessCPU' AS OtherProcessCPU,
    j.value ->> 'record_id' AS record_id,
    j.value ->> 'scheduler_count' AS scheduler_count,
    j.value ->> 'signal_wait_pct' AS signal_wait_pct,
    j.value ->> 'SQLProcessUtilization' AS SQLProcessUtilization,
    j.value ->> 'SystemIdle' AS SystemIdle,
    j.value ->> 'total_runnable_tasks' AS total_runnable_tasks,
    j.value ->> 'total_signal_wait_ms' AS total_signal_wait_ms,
    j.value ->> 'total_wait_ms' AS total_wait_ms,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-001-RC22';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc01 AS
SELECT
    r.server,
    j.value ->> 'avg_use_count' AS avg_use_count,
    j.value ->> 'cacheobjtype' AS cacheobjtype,
    j.value ->> 'objtype' AS objtype,
    j.value ->> 'plan_count' AS plan_count,
    j.value ->> 'single_use_plans' AS single_use_plans,
    j.value ->> 'total_size_mb' AS total_size_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-002-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc02 AS
SELECT
    r.server,
    j.value ->> 'batch_requests_sec' AS batch_requests_sec,
    j.value ->> 'compilations_sec' AS compilations_sec,
    j.value ->> 'objtype' AS objtype,
    j.value ->> 'recompilations_sec' AS recompilations_sec,
    j.value ->> 'size_kb' AS size_kb,
    j.value ->> 'sql_text' AS sql_text,
    j.value ->> 'usecounts' AS usecounts,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-002-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc03 AS
SELECT
    r.server,
    j.value ->> 'auto_param_attempts' AS auto_param_attempts,
    j.value ->> 'auto_update_stats' AS auto_update_stats,
    j.value ->> 'auto_update_stats_async' AS auto_update_stats_async,
    j.value ->> 'recompilations_sec' AS recompilations_sec,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-002-RC03';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc04 AS
SELECT
    r.server,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'last_compile_time' AS last_compile_time,
    j.value ->> 'plan_generation_num' AS plan_generation_num,
    j.value ->> 'query_text' AS query_text,
    j.value ->> 'total_cpu_ms' AS total_cpu_ms,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-002-RC04';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc05 AS
SELECT
    r.server,
    j.value ->> 'batch_requests_sec' AS batch_requests_sec,
    j.value ->> 'compilations_sec' AS compilations_sec,
    j.value ->> 'recently_recompiled_plans' AS recently_recompiled_plans,
    j.value ->> 'recompilations_sec' AS recompilations_sec,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-002-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc06 AS
SELECT
    r.server,
    j.value ->> 'avg_cpu_ms' AS avg_cpu_ms,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'plan_generation_num' AS plan_generation_num,
    j.value ->> 'proc_text' AS proc_text,
    j.value ->> 'procedure_name' AS procedure_name,
    j.value ->> 'total_cpu_ms' AS total_cpu_ms,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-002-RC06';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc07 AS
SELECT
    r.server,
    j.value ->> 'dbid' AS dbid,
    j.value ->> 'max_avg_cpu_ms' AS max_avg_cpu_ms,
    j.value ->> 'max_plan_gen' AS max_plan_gen,
    j.value ->> 'min_avg_cpu_ms' AS min_avg_cpu_ms,
    j.value ->> 'plan_count' AS plan_count,
    j.value ->> 'procedure_name' AS procedure_name,
    j.value ->> 'total_executions' AS total_executions,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-002-RC07';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc08 AS
SELECT
    r.server,
    j.value ->> 'batch_requests_sec' AS batch_requests_sec,
    j.value ->> 'recompilations_sec' AS recompilations_sec,
    j.value ->> 'total_recompile_cpu_ms' AS total_recompile_cpu_ms,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-002-RC08';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc09 AS
SELECT
    r.server,
    j.value ->> 'avg_cpu_ms' AS avg_cpu_ms,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'last_compile_time' AS last_compile_time,
    j.value ->> 'minutes_since_compile' AS minutes_since_compile,
    j.value ->> 'object_name' AS object_name,
    j.value ->> 'plan_generation_num' AS plan_generation_num,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-002-RC09';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc11 AS
SELECT
    r.server,
    j.value ->> 'avg_cpu_ms' AS avg_cpu_ms,
    j.value ->> 'avg_reads' AS avg_reads,
    j.value ->> 'creation_time' AS creation_time,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'plan_generation_num' AS plan_generation_num,
    j.value ->> 'query_text' AS query_text,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-002-RC11';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc12 AS
SELECT
    r.server,
    j.value ->> 'cache_hit_ratio_base' AS cache_hit_ratio_base,
    j.value ->> 'cache_hit_ratio_raw' AS cache_hit_ratio_raw,
    j.value ->> 'cache_pages' AS cache_pages,
    j.value ->> 'compilations_sec' AS compilations_sec,
    j.value ->> 'entries_count' AS entries_count,
    j.value ->> 'entries_in_use_count' AS entries_in_use_count,
    j.value ->> 'eviction_status' AS eviction_status,
    j.value ->> 'lazy_writes_sec' AS lazy_writes_sec,
    j.value ->> 'name' AS name,
    j.value ->> 'pages_in_use_kb' AS pages_in_use_kb,
    j.value ->> 'pages_kb' AS pages_kb,
    j.value ->> 'recompilations_sec' AS recompilations_sec,
    j.value ->> 'stolen_memory_kb' AS stolen_memory_kb,
    j.value ->> 'total_cache_objects' AS total_cache_objects,
    j.value ->> 'type' AS type,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-002-RC12';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc13 AS
SELECT
    r.server,
    j.value ->> 'batch_requests_sec' AS batch_requests_sec,
    j.value ->> 'compilations_sec' AS compilations_sec,
    j.value ->> 'low_reuse_prepared_mb' AS low_reuse_prepared_mb,
    j.value ->> 'low_reuse_prepared_plans' AS low_reuse_prepared_plans,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-002-RC13';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc15 AS
SELECT
    r.server,
    j.value ->> 'approx_join_count' AS approx_join_count,
    j.value ->> 'avg_cpu_ms' AS avg_cpu_ms,
    j.value ->> 'avg_elapsed_ms' AS avg_elapsed_ms,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'plan_generation_num' AS plan_generation_num,
    j.value ->> 'query_length_chars' AS query_length_chars,
    j.value ->> 'query_prefix' AS query_prefix,
    j.value ->> 'total_cpu_ms' AS total_cpu_ms,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-002-RC15';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc17 AS
SELECT
    r.server,
    j.value ->> 'compatibility_level' AS compatibility_level,
    j.value ->> 'inlineable_udfs' AS inlineable_udfs,
    j.value ->> 'inlining_status' AS inlining_status,
    j.value ->> 'non_inlineable_udfs' AS non_inlineable_udfs,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-002-RC17';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc18 AS
SELECT
    r.server,
    j.value ->> 'batch_requests_sec' AS batch_requests_sec,
    j.value ->> 'cache_hit_ratio' AS cache_hit_ratio,
    j.value ->> 'cache_mb' AS cache_mb,
    j.value ->> 'cache_pages' AS cache_pages,
    j.value ->> 'compilations_sec' AS compilations_sec,
    j.value ->> 'entries_count' AS entries_count,
    j.value ->> 'entries_in_use_count' AS entries_in_use_count,
    j.value ->> 'in_use_mb' AS in_use_mb,
    j.value ->> 'pages_in_use_kb' AS pages_in_use_kb,
    j.value ->> 'pages_kb' AS pages_kb,
    j.value ->> 'recompilations_sec' AS recompilations_sec,
    j.value ->> 'total_cached_plans' AS total_cached_plans,
    j.value ->> 'type' AS type,
    j.value ->> 'unused_entries' AS unused_entries,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-002-RC18';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc19 AS
SELECT
    r.server,
    j.value ->> 'avg_elapsed_us' AS avg_elapsed_us,
    j.value ->> 'avg_exec_cpu_us' AS avg_exec_cpu_us,
    j.value ->> 'compilations_sec' AS compilations_sec,
    j.value ->> 'compile_cpu_ms' AS compile_cpu_ms,
    j.value ->> 'compile_time_ms' AS compile_time_ms,
    j.value ->> 'creation_time' AS creation_time,
    j.value ->> 'early_abort' AS early_abort,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'last_execution_time' AS last_execution_time,
    j.value ->> 'optim_level' AS optim_level,
    j.value ->> 'plan_generation_num' AS plan_generation_num,
    j.value ->> 'query_text' AS query_text,
    j.value ->> 'recompilations_sec' AS recompilations_sec,
    j.value ->> 'signal_wait_pct' AS signal_wait_pct,
    j.value ->> 'single_use_plans' AS single_use_plans,
    j.value ->> 'total_plans' AS total_plans,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-002-RC19';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_002_rc20 AS
SELECT
    r.server,
    j.value ->> 'avg_cpu_us' AS avg_cpu_us,
    j.value ->> 'avg_reads' AS avg_reads,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'procedure_name' AS procedure_name,
    j.value ->> 'procedure_text' AS procedure_text,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-002-RC20';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc01 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'configured_value' AS configured_value,
    j.value ->> 'name' AS name,
    j.value ->> 'value_in_use' AS value_in_use,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-003-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc02 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'signal_wait_time_ms' AS signal_wait_time_ms,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-003-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc03 AS
SELECT
    r.server,
    j.value ->> 'dop' AS dop,
    j.value ->> 'estimate_row_count' AS estimate_row_count,
    j.value ->> 'node_id' AS node_id,
    j.value ->> 'physical_operator_name' AS physical_operator_name,
    j.value ->> 'row_count' AS row_count,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'thread_id' AS thread_id,
    j.value ->> 'wait_time' AS wait_time,
    j.value ->> 'wait_type' AS wait_type,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-003-RC03';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc04 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'configured_value' AS configured_value,
    j.value ->> 'maximum' AS maximum,
    j.value ->> 'minimum' AS minimum,
    j.value ->> 'name' AS name,
    j.value ->> 'pct_of_total' AS pct_of_total,
    j.value ->> 'value_in_use' AS value_in_use,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-003-RC04';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc05 AS
SELECT
    r.server,
    j.value ->> 'avg_load_factor' AS avg_load_factor,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'logical_cpus' AS logical_cpus,
    j.value ->> 'max_load_factor' AS max_load_factor,
    j.value ->> 'maxdop' AS maxdop,
    j.value ->> 'numa_nodes' AS numa_nodes,
    j.value ->> 'online_schedulers' AS online_schedulers,
    j.value ->> 'pending_io' AS pending_io,
    j.value ->> 'runnable_tasks' AS runnable_tasks,
    j.value ->> 'sockets' AS sockets,
    j.value ->> 'total_tasks' AS total_tasks,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-003-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc06 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'cores_per_numa' AS cores_per_numa,
    j.value ->> 'hyperthread_ratio' AS hyperthread_ratio,
    j.value ->> 'logical_cpus' AS logical_cpus,
    j.value ->> 'maxdop' AS maxdop,
    j.value ->> 'numa_node_count' AS numa_node_count,
    j.value ->> 'physical_cores' AS physical_cores,
    j.value ->> 'socket_count' AS socket_count,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-003-RC06';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc07 AS
SELECT
    r.server,
    j.value ->> 'granted' AS granted,
    j.value ->> 'parallel_grants' AS parallel_grants,
    j.value ->> 'total_granted_mb' AS total_granted_mb,
    j.value ->> 'waiting_for_grant' AS waiting_for_grant,
    j.value ->> 'waiting_required_mb' AS waiting_required_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-003-RC07';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc08 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-003-RC08';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc09 AS
SELECT
    r.server,
    j.value ->> 'free_mb' AS free_mb,
    j.value ->> 'internal_objects_mb' AS internal_objects_mb,
    j.value ->> 'io_wait_ms' AS io_wait_ms,
    j.value ->> 'user_objects_mb' AS user_objects_mb,
    j.value ->> 'version_store_mb' AS version_store_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-003-RC09';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc12 AS
SELECT
    r.server,
    j.value ->> 'estimate_row_count' AS estimate_row_count,
    j.value ->> 'node_id' AS node_id,
    j.value ->> 'physical_operator_name' AS physical_operator_name,
    j.value ->> 'row_count' AS row_count,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'thread_id' AS thread_id,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-003-RC12';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc14 AS
SELECT
    r.server,
    j.value ->> 'active_workers_count' AS active_workers_count,
    j.value ->> 'context_switches_count' AS context_switches_count,
    j.value ->> 'cpu_count' AS cpu_count,
    j.value ->> 'cpu_id' AS cpu_id,
    j.value ->> 'current_tasks_count' AS current_tasks_count,
    j.value ->> 'load_factor' AS load_factor,
    j.value ->> 'parallel_queries_now' AS parallel_queries_now,
    j.value ->> 'runnable_tasks_count' AS runnable_tasks_count,
    j.value ->> 'scheduler_id' AS scheduler_id,
    j.value ->> 'scheduler_yield_count' AS scheduler_yield_count,
    j.value ->> 'scheduler_yield_ms' AS scheduler_yield_ms,
    j.value ->> 'total_parallel_threads' AS total_parallel_threads,
    j.value ->> 'work_queue_count' AS work_queue_count,
    j.value ->> 'yield_count' AS yield_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-003-RC14';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc16 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'cache_hit_ratio' AS cache_hit_ratio,
    j.value ->> 'page_lookups_sec' AS page_lookups_sec,
    j.value ->> 'page_reads_sec' AS page_reads_sec,
    j.value ->> 'parallel_scan_queries' AS parallel_scan_queries,
    j.value ->> 'readaheads_sec' AS readaheads_sec,
    j.value ->> 'total_scan_threads' AS total_scan_threads,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-003-RC16';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc18 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-003-RC18';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc19 AS
SELECT
    r.server,
    j.value ->> 'active_workers_count' AS active_workers_count,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'context_switches_count' AS context_switches_count,
    j.value ->> 'cost_threshold' AS cost_threshold,
    j.value ->> 'current_tasks_count' AS current_tasks_count,
    j.value ->> 'hyperthread_ratio' AS hyperthread_ratio,
    j.value ->> 'load_factor' AS load_factor,
    j.value ->> 'logical_cpus' AS logical_cpus,
    j.value ->> 'maxdop' AS maxdop,
    j.value ->> 'numa_node_count' AS numa_node_count,
    j.value ->> 'parent_node_id' AS parent_node_id,
    j.value ->> 'physical_cores' AS physical_cores,
    j.value ->> 'runnable_tasks_count' AS runnable_tasks_count,
    j.value ->> 'scheduler_id' AS scheduler_id,
    j.value ->> 'socket_count' AS socket_count,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    j.value ->> 'yield_count' AS yield_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-003-RC19';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc21 AS
SELECT
    r.server,
    j.value ->> 'active_workers' AS active_workers,
    j.value ->> 'cost_threshold' AS cost_threshold,
    j.value ->> 'frequent_parallel_plans' AS frequent_parallel_plans,
    j.value ->> 'max_worker_threads' AS max_worker_threads,
    j.value ->> 'maxdop' AS maxdop,
    j.value ->> 'queued_requests' AS queued_requests,
    j.value ->> 'threadpool_wait_ms' AS threadpool_wait_ms,
    j.value ->> 'threadpool_waits' AS threadpool_waits,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-003-RC21';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_003_rc22 AS
SELECT
    r.server,
    j.value ->> 'buffer_cache_hit_ratio' AS buffer_cache_hit_ratio,
    j.value ->> 'foreign_committed_kb' AS foreign_committed_kb,
    j.value ->> 'logical_cpus' AS logical_cpus,
    j.value ->> 'maxdop' AS maxdop,
    j.value ->> 'memory_node_id' AS memory_node_id,
    j.value ->> 'numa_node_count' AS numa_node_count,
    j.value ->> 'numa_status' AS numa_status,
    j.value ->> 'page_lookups_sec' AS page_lookups_sec,
    j.value ->> 'pages_kb' AS pages_kb,
    j.value ->> 'physical_cores' AS physical_cores,
    j.value ->> 'target_kb' AS target_kb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-003-RC22';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_004_rc01 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'index_name' AS index_name,
    j.value ->> 'is_auto_create_stats_incremental_on' AS is_auto_create_stats_incremental_on,
    j.value ->> 'is_auto_create_stats_on' AS is_auto_create_stats_on,
    j.value ->> 'is_auto_update_stats_async_on' AS is_auto_update_stats_async_on,
    j.value ->> 'is_auto_update_stats_on' AS is_auto_update_stats_on,
    j.value ->> 'last_updated' AS last_updated,
    j.value ->> 'modification_counter' AS modification_counter,
    j.value ->> 'object_name' AS object_name,
    j.value ->> 'rows_sampled' AS rows_sampled,
    j.value ->> 'sample_pct' AS sample_pct,
    j.value ->> 'stats_name' AS stats_name,
    j.value ->> 'total_rows' AS total_rows,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-004-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_004_rc02 AS
SELECT
    r.server,
    j.value ->> 'compatibility_level' AS compatibility_level,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'large_tables_with_mods' AS large_tables_with_mods,
    j.value ->> 'threshold_mode' AS threshold_mode,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-004-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_004_rc03 AS
SELECT
    r.server,
    j.value ->> 'hours_since_update' AS hours_since_update,
    j.value ->> 'last_updated' AS last_updated,
    j.value ->> 'modification_counter' AS modification_counter,
    j.value ->> 'pct_modified' AS pct_modified,
    j.value ->> 'rows_sampled' AS rows_sampled,
    j.value ->> 'stats_name' AS stats_name,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'total_rows' AS total_rows,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-004-RC03';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_004_rc05 AS
SELECT
    r.server,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'is_auto_create_stats_on' AS is_auto_create_stats_on,
    j.value ->> 'is_auto_update_stats_on' AS is_auto_update_stats_on,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-004-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_004_rc07 AS
SELECT
    r.server,
    j.value ->> 'avg_cpu_us' AS avg_cpu_us,
    j.value ->> 'avg_reads' AS avg_reads,
    j.value ->> 'avg_rows' AS avg_rows,
    j.value ->> 'column_refs' AS column_refs,
    j.value ->> 'cpu_variance' AS cpu_variance,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'query_text' AS query_text,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-004-RC07';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_004_rc08 AS
SELECT
    r.server,
    j.value ->> 'avg_cpu_us' AS avg_cpu_us,
    j.value ->> 'avg_grant_kb' AS avg_grant_kb,
    j.value ->> 'avg_reads' AS avg_reads,
    j.value ->> 'avg_rows' AS avg_rows,
    j.value ->> 'avg_used_grant_kb' AS avg_used_grant_kb,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'grant_utilization_pct' AS grant_utilization_pct,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-004-RC08';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_004_rc10 AS
SELECT
    r.server,
    j.value ->> 'in_row_mb' AS in_row_mb,
    j.value ->> 'partition_number' AS partition_number,
    j.value ->> 'row_count' AS row_count,
    j.value ->> 'rows' AS rows,
    j.value ->> 'table_name' AS table_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-004-RC10';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_004_rc11 AS
SELECT
    r.server,
    j.value ->> 'avg_cpu_us' AS avg_cpu_us,
    j.value ->> 'avg_reads' AS avg_reads,
    j.value ->> 'cpu_variance' AS cpu_variance,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'plan_generation_num' AS plan_generation_num,
    j.value ->> 'read_variance' AS read_variance,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-004-RC11';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_004_rc12 AS
SELECT
    r.server,
    j.value ->> 'compatibility_level' AS compatibility_level,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'is_auto_create_stats_incremental_on' AS is_auto_create_stats_incremental_on,
    j.value ->> 'is_auto_create_stats_on' AS is_auto_create_stats_on,
    j.value ->> 'is_auto_update_stats_on' AS is_auto_update_stats_on,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-004-RC12';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_004_rc13 AS
SELECT
    r.server,
    j.value ->> 'avg_actual_rows' AS avg_actual_rows,
    j.value ->> 'avg_cpu_us' AS avg_cpu_us,
    j.value ->> 'avg_grant_kb' AS avg_grant_kb,
    j.value ->> 'avg_reads' AS avg_reads,
    j.value ->> 'avg_spills' AS avg_spills,
    j.value ->> 'avg_used_grant_kb' AS avg_used_grant_kb,
    j.value ->> 'cardinality_estimator' AS cardinality_estimator,
    j.value ->> 'compatibility_level' AS compatibility_level,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'queries_with_spills' AS queries_with_spills,
    j.value ->> 'query_text' AS query_text,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-004-RC13';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_004_rc15 AS
SELECT
    r.server,
    j.value ->> 'avg_cpu_us' AS avg_cpu_us,
    j.value ->> 'avg_grant_kb' AS avg_grant_kb,
    j.value ->> 'avg_rows' AS avg_rows,
    j.value ->> 'avg_spills' AS avg_spills,
    j.value ->> 'avg_used_grant_kb' AS avg_used_grant_kb,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'grant_utilization_pct' AS grant_utilization_pct,
    j.value ->> 'query_text' AS query_text,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-004-RC15';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_004_rc18 AS
SELECT
    r.server,
    j.value ->> 'filter_definition' AS filter_definition,
    j.value ->> 'index_name' AS index_name,
    j.value ->> 'index_updates' AS index_updates,
    j.value ->> 'index_usage' AS index_usage,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'rows_sampled' AS rows_sampled,
    j.value ->> 'stat_last_updated' AS stat_last_updated,
    j.value ->> 'stat_rows' AS stat_rows,
    j.value ->> 'table_name' AS table_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-004-RC18';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_cpu_004_rc21 AS
SELECT
    r.server,
    j.value ->> 'compatibility_level' AS compatibility_level,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'deferred_compilation_disabled' AS deferred_compilation_disabled,
    j.value ->> 'tv_estimation_behavior' AS tv_estimation_behavior,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-CPU-004-RC21';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_001_rc01 AS
SELECT
    r.server,
    j.value ->> 'avg_read_kb' AS avg_read_kb,
    j.value ->> 'avg_read_stall_ms' AS avg_read_stall_ms,
    j.value ->> 'avg_resource_wait_ms' AS avg_resource_wait_ms,
    j.value ->> 'avg_total_stall_ms' AS avg_total_stall_ms,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'avg_write_kb' AS avg_write_kb,
    j.value ->> 'avg_write_stall_ms' AS avg_write_stall_ms,
    j.value ->> 'cntr_value' AS cntr_value,
    j.value ->> 'counter_name' AS counter_name,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'file_name' AS file_name,
    j.value ->> 'file_type' AS file_type,
    j.value ->> 'num_of_reads' AS num_of_reads,
    j.value ->> 'num_of_writes' AS num_of_writes,
    j.value ->> 'object_name' AS object_name,
    j.value ->> 'physical_name' AS physical_name,
    j.value ->> 'signal_wait_time_ms' AS signal_wait_time_ms,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-001-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_001_rc02 AS
SELECT
    r.server,
    j.value ->> 'avg_read_ms' AS avg_read_ms,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'avg_write_ms' AS avg_write_ms,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'file_name' AS file_name,
    j.value ->> 'log_avg_write_ms' AS log_avg_write_ms,
    j.value ->> 'log_file_path' AS log_file_path,
    j.value ->> 'physical_name' AS physical_name,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    j.value ->> 'write_read_ratio' AS write_read_ratio,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-001-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_001_rc03 AS
SELECT
    r.server,
    j.value ->> 'avg_read_ms' AS avg_read_ms,
    j.value ->> 'avg_write_kb' AS avg_write_kb,
    j.value ->> 'avg_write_ms' AS avg_write_ms,
    j.value ->> 'avg_writelog_ms' AS avg_writelog_ms,
    j.value ->> 'checkpoint_pages_sec' AS checkpoint_pages_sec,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'lazy_writes_sec' AS lazy_writes_sec,
    j.value ->> 'num_of_writes' AS num_of_writes,
    j.value ->> 'physical_name' AS physical_name,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'writelog_waits' AS writelog_waits,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-001-RC03';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_001_rc05 AS
SELECT
    r.server,
    j.value ->> 'cntr_value' AS cntr_value,
    j.value ->> 'counter_name' AS counter_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-001-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_001_rc06 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-001-RC06';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_001_rc07 AS
SELECT
    r.server,
    j.value ->> 'avg_bytes_per_read' AS avg_bytes_per_read,
    j.value ->> 'avg_read_ms' AS avg_read_ms,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'avg_write_ms' AS avg_write_ms,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'io_assessment' AS io_assessment,
    j.value ->> 'num_of_reads' AS num_of_reads,
    j.value ->> 'num_of_writes' AS num_of_writes,
    j.value ->> 'pct_of_total_waits' AS pct_of_total_waits,
    j.value ->> 'physical_name' AS physical_name,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-001-RC07';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_001_rc09 AS
SELECT
    r.server,
    j.value ->> 'avg_queued_read_ms' AS avg_queued_read_ms,
    j.value ->> 'avg_queued_write_ms' AS avg_queued_write_ms,
    j.value ->> 'avg_read_ms' AS avg_read_ms,
    j.value ->> 'avg_write_ms' AS avg_write_ms,
    j.value ->> 'contention_indicator' AS contention_indicator,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'max_iops_per_volume' AS max_iops_per_volume,
    j.value ->> 'physical_name' AS physical_name,
    j.value ->> 'pool_name' AS pool_name,
    j.value ->> 'read_io_completed_total' AS read_io_completed_total,
    j.value ->> 'read_io_issued_total' AS read_io_issued_total,
    j.value ->> 'read_io_queued_total' AS read_io_queued_total,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'write_io_completed_total' AS write_io_completed_total,
    j.value ->> 'write_io_issued_total' AS write_io_issued_total,
    j.value ->> 'write_io_queued_total' AS write_io_queued_total,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-001-RC09';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_001_rc10 AS
SELECT
    r.server,
    j.value ->> 'avg_read_ms' AS avg_read_ms,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'avg_write_ms' AS avg_write_ms,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'degradation_pattern' AS degradation_pattern,
    j.value ->> 'physical_name' AS physical_name,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-001-RC10';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_001_rc11 AS
SELECT
    r.server,
    j.value ->> 'cntr_value' AS cntr_value,
    j.value ->> 'counter_name' AS counter_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-001-RC11';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_001_rc12 AS
SELECT
    r.server,
    j.value ->> 'network_io_avg_ms' AS network_io_avg_ms,
    j.value ->> 'overall_avg_stall_ms' AS overall_avg_stall_ms,
    j.value ->> 'total_io_mb' AS total_io_mb,
    j.value ->> 'total_io_ops' AS total_io_ops,
    j.value ->> 'total_read_mb' AS total_read_mb,
    j.value ->> 'total_write_mb' AS total_write_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-001-RC12';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_001_rc13 AS
SELECT
    r.server,
    j.value ->> 'active_grants_mb' AS active_grants_mb,
    j.value ->> 'active_memory_grants' AS active_memory_grants,
    j.value ->> 'avg_resource_semaphore_ms' AS avg_resource_semaphore_ms,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'checkpoint_pages_sec' AS checkpoint_pages_sec,
    j.value ->> 'free_list_stalls_sec' AS free_list_stalls_sec,
    j.value ->> 'lazy_writes_sec' AS lazy_writes_sec,
    j.value ->> 'page_life_expectancy' AS page_life_expectancy,
    j.value ->> 'page_reads_sec' AS page_reads_sec,
    j.value ->> 'page_writes_sec' AS page_writes_sec,
    j.value ->> 'pending_memory_grants' AS pending_memory_grants,
    j.value ->> 'resource_semaphore_waits' AS resource_semaphore_waits,
    j.value ->> 'target_memory_kb' AS target_memory_kb,
    j.value ->> 'total_memory_kb' AS total_memory_kb,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-001-RC13';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_002_rc01 AS
SELECT
    r.server,
    j.value ->> 'avg_log_write_ms' AS avg_log_write_ms,
    j.value ->> 'avg_writelog_ms' AS avg_writelog_ms,
    j.value ->> 'batch_requests_sec' AS batch_requests_sec,
    j.value ->> 'log_flush_wait_time_ms' AS log_flush_wait_time_ms,
    j.value ->> 'log_flush_waits_ms' AS log_flush_waits_ms,
    j.value ->> 'log_flushes' AS log_flushes,
    j.value ->> 'log_flushes_sec' AS log_flushes_sec,
    j.value ->> 'log_writes' AS log_writes,
    j.value ->> 'name' AS name,
    j.value ->> 'writelog_wait_time_ms' AS writelog_wait_time_ms,
    j.value ->> 'writelog_waits' AS writelog_waits,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-002-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_002_rc02 AS
SELECT
    r.server,
    j.value ->> 'data_drive' AS data_drive,
    j.value ->> 'data_file_path' AS data_file_path,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'log_drive' AS log_drive,
    j.value ->> 'log_file_path' AS log_file_path,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-002-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_002_rc03 AS
SELECT
    r.server,
    j.value ->> 'avg_log_write_ms' AS avg_log_write_ms,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'io_stall_write_ms' AS io_stall_write_ms,
    j.value ->> 'log_mb_written' AS log_mb_written,
    j.value ->> 'log_writes' AS log_writes,
    j.value ->> 'max_wait_time_ms' AS max_wait_time_ms,
    j.value ->> 'name' AS name,
    j.value ->> 'physical_name' AS physical_name,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-002-RC03';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_002_rc04 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'avg_writelog_ms' AS avg_writelog_ms,
    j.value ->> 'logbuffer_wait_ms' AS logbuffer_wait_ms,
    j.value ->> 'logbuffer_waits' AS logbuffer_waits,
    j.value ->> 'max_wait_time_ms' AS max_wait_time_ms,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    j.value ->> 'writelog_wait_ms' AS writelog_wait_ms,
    j.value ->> 'writelog_waits' AS writelog_waits,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-002-RC04';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_002_rc05 AS
SELECT
    r.server,
    j.value ->> 'avg_log_write_ms' AS avg_log_write_ms,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'delayed_durability_desc' AS delayed_durability_desc,
    j.value ->> 'log_flushes' AS log_flushes,
    j.value ->> 'log_writes' AS log_writes,
    j.value ->> 'name' AS name,
    j.value ->> 'pct_of_total_waits' AS pct_of_total_waits,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-002-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_002_rc06 AS
SELECT
    r.server,
    j.value ->> 'backoffs' AS backoffs,
    j.value ->> 'collisions' AS collisions,
    j.value ->> 'name' AS name,
    j.value ->> 'sleep_time' AS sleep_time,
    j.value ->> 'spins' AS spins,
    j.value ->> 'spins_per_collision' AS spins_per_collision,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-002-RC06';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_002_rc07 AS
SELECT
    r.server,
    j.value ->> 'avg_log_write_ms' AS avg_log_write_ms,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'avg_write_size_bytes' AS avg_write_size_bytes,
    j.value ->> 'max_wait_time_ms' AS max_wait_time_ms,
    j.value ->> 'name' AS name,
    j.value ->> 'total_log_writes' AS total_log_writes,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-002-RC07';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_002_rc09 AS
SELECT
    r.server,
    j.value ->> 'growth_setting' AS growth_setting,
    j.value ->> 'is_percent_growth' AS is_percent_growth,
    j.value ->> 'log_size_mb' AS log_size_mb,
    j.value ->> 'max_size' AS max_size,
    j.value ->> 'name' AS name,
    j.value ->> 'physical_name' AS physical_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-002-RC09';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_002_rc11 AS
SELECT
    r.server,
    j.value ->> 'avg_log_write_ms' AS avg_log_write_ms,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'avg_write_bytes' AS avg_write_bytes,
    j.value ->> 'log_writes' AS log_writes,
    j.value ->> 'max_wait_time_ms' AS max_wait_time_ms,
    j.value ->> 'name' AS name,
    j.value ->> 'pct_of_waits' AS pct_of_waits,
    j.value ->> 'physical_name' AS physical_name,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-002-RC11';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_002_rc12 AS
SELECT
    r.server,
    j.value ->> 'foreign_committed_kb' AS foreign_committed_kb,
    j.value ->> 'local_pages_kb' AS local_pages_kb,
    j.value ->> 'memory_node_id' AS memory_node_id,
    j.value ->> 'numa_node' AS numa_node,
    j.value ->> 'numa_status' AS numa_status,
    j.value ->> 'runnable_tasks' AS runnable_tasks,
    j.value ->> 'scheduler_count' AS scheduler_count,
    j.value ->> 'target_kb' AS target_kb,
    j.value ->> 'total_tasks' AS total_tasks,
    j.value ->> 'workers' AS workers,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-002-RC12';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_002_rc14 AS
SELECT
    r.server,
    j.value ->> 'avg_write_bytes' AS avg_write_bytes,
    j.value ->> 'avg_write_ms' AS avg_write_ms,
    j.value ->> 'avg_writelog_ms' AS avg_writelog_ms,
    j.value ->> 'batch_requests_sec' AS batch_requests_sec,
    j.value ->> 'log_flushes' AS log_flushes,
    j.value ->> 'log_mb_written' AS log_mb_written,
    j.value ->> 'log_writes' AS log_writes,
    j.value ->> 'name' AS name,
    j.value ->> 'transactions_sec' AS transactions_sec,
    j.value ->> 'writelog_total_ms' AS writelog_total_ms,
    j.value ->> 'writelog_waits' AS writelog_waits,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-002-RC14';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_002_rc15 AS
SELECT
    r.server,
    j.value ->> 'avg_data_write_ms' AS avg_data_write_ms,
    j.value ->> 'avg_log_write_ms' AS avg_log_write_ms,
    j.value ->> 'avg_writelog_ms' AS avg_writelog_ms,
    j.value ->> 'checkpoint_pages_sec' AS checkpoint_pages_sec,
    j.value ->> 'command' AS command,
    j.value ->> 'database_id' AS database_id,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'elapsed_sec' AS elapsed_sec,
    j.value ->> 'name' AS name,
    j.value ->> 'percent_complete' AS percent_complete,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'status' AS status,
    j.value ->> 'wait_sec' AS wait_sec,
    j.value ->> 'wait_type' AS wait_type,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-002-RC15';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_003_rc01 AS
SELECT
    r.server,
    j.value ->> 'checkpoint_pages_sec' AS checkpoint_pages_sec,
    j.value ->> 'dirty_pages' AS dirty_pages,
    j.value ->> 'name' AS name,
    j.value ->> 'page_life_expectancy' AS page_life_expectancy,
    j.value ->> 'recovery_interval_min' AS recovery_interval_min,
    j.value ->> 'recovery_model_desc' AS recovery_model_desc,
    j.value ->> 'target_recovery_time_in_seconds' AS target_recovery_time_in_seconds,
    j.value ->> 'total_pages' AS total_pages,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-003-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_003_rc02 AS
SELECT
    r.server,
    j.value ->> 'avg_pageiolatch_ms' AS avg_pageiolatch_ms,
    j.value ->> 'bg_writer_pages_sec' AS bg_writer_pages_sec,
    j.value ->> 'checkpoint_pages_sec' AS checkpoint_pages_sec,
    j.value ->> 'dirty_mb' AS dirty_mb,
    j.value ->> 'dirty_pages' AS dirty_pages,
    j.value ->> 'dirty_ratio' AS dirty_ratio,
    j.value ->> 'lazy_writes_sec' AS lazy_writes_sec,
    j.value ->> 'pageiolatch_waits' AS pageiolatch_waits,
    j.value ->> 'total_buffer_pages' AS total_buffer_pages,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-003-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_003_rc03 AS
SELECT
    r.server,
    j.value ->> 'avg_pageiolatch_write_ms' AS avg_pageiolatch_write_ms,
    j.value ->> 'bg_writer_pages_sec' AS bg_writer_pages_sec,
    j.value ->> 'checkpoint_pages_sec' AS checkpoint_pages_sec,
    j.value ->> 'indirect_checkpoint_pages_sec' AS indirect_checkpoint_pages_sec,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-003-RC03';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_003_rc04 AS
SELECT
    r.server,
    j.value ->> 'checkpoint_pages_sec' AS checkpoint_pages_sec,
    j.value ->> 'dirty_mb' AS dirty_mb,
    j.value ->> 'dirty_pages' AS dirty_pages,
    j.value ->> 'dirty_ratio' AS dirty_ratio,
    j.value ->> 'free_list_stalls_sec' AS free_list_stalls_sec,
    j.value ->> 'lazy_writes_sec' AS lazy_writes_sec,
    j.value ->> 'ple_seconds' AS ple_seconds,
    j.value ->> 'total_pages' AS total_pages,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-003-RC04';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_003_rc05 AS
SELECT
    r.server,
    j.value ->> 'bg_writer_pages_sec' AS bg_writer_pages_sec,
    j.value ->> 'checkpoint_pages_sec' AS checkpoint_pages_sec,
    j.value ->> 'dirty_pages' AS dirty_pages,
    j.value ->> 'dirty_ratio' AS dirty_ratio,
    j.value ->> 'lazy_writes_sec' AS lazy_writes_sec,
    j.value ->> 'ple_seconds' AS ple_seconds,
    j.value ->> 'total_pages' AS total_pages,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-003-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_003_rc07 AS
SELECT
    r.server,
    j.value ->> 'avg_read_microsec' AS avg_read_microsec,
    j.value ->> 'buffer_mb' AS buffer_mb,
    j.value ->> 'buffered_pages' AS buffered_pages,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'db_name' AS db_name,
    j.value ->> 'dirty_pages' AS dirty_pages,
    j.value ->> 'file_id' AS file_id,
    j.value ->> 'filegroup_count' AS filegroup_count,
    j.value ->> 'physical_name' AS physical_name,
    j.value ->> 'size_mb' AS size_mb,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-003-RC07';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_003_rc08 AS
SELECT
    r.server,
    j.value ->> 'avg_read_stall_ms' AS avg_read_stall_ms,
    j.value ->> 'cache_hit_ratio' AS cache_hit_ratio,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'file_name' AS file_name,
    j.value ->> 'free_list_stalls_sec' AS free_list_stalls_sec,
    j.value ->> 'io_stall_read_ms' AS io_stall_read_ms,
    j.value ->> 'lazy_writes_sec' AS lazy_writes_sec,
    j.value ->> 'num_of_bytes_read' AS num_of_bytes_read,
    j.value ->> 'num_of_reads' AS num_of_reads,
    j.value ->> 'page_reads_sec' AS page_reads_sec,
    j.value ->> 'ple_seconds' AS ple_seconds,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-003-RC08';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_003_rc09 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-003-RC09';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_003_rc10 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'checkpoint_pages_sec' AS checkpoint_pages_sec,
    j.value ->> 'sessions_waiting_on_latches' AS sessions_waiting_on_latches,
    j.value ->> 'signal_wait_time_ms' AS signal_wait_time_ms,
    j.value ->> 'total_latch_waits' AS total_latch_waits,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-003-RC10';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_003_rc11 AS
SELECT
    r.server,
    j.value ->> 'avg_write_latch_ms' AS avg_write_latch_ms,
    j.value ->> 'bg_writer_pages_sec' AS bg_writer_pages_sec,
    j.value ->> 'checkpoint_pages_sec' AS checkpoint_pages_sec,
    j.value ->> 'indirect_cp_pages_sec' AS indirect_cp_pages_sec,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-003-RC11';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_003_rc12 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'data_size_mb' AS data_size_mb,
    j.value ->> 'log_reuse_wait_desc' AS log_reuse_wait_desc,
    j.value ->> 'name' AS name,
    j.value ->> 'recovery_model_desc' AS recovery_model_desc,
    j.value ->> 'target_recovery_time_in_seconds' AS target_recovery_time_in_seconds,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-003-RC12';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_003_rc13 AS
SELECT
    r.server,
    j.value ->> 'avg_io_stall_ms' AS avg_io_stall_ms,
    j.value ->> 'bgwriter_pages_sec' AS bgwriter_pages_sec,
    j.value ->> 'checkpoint_pages_sec' AS checkpoint_pages_sec,
    j.value ->> 'lazy_writes_sec' AS lazy_writes_sec,
    j.value ->> 'page_reads_sec' AS page_reads_sec,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-003-RC13';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_003_rc15 AS
SELECT
    r.server,
    j.value ->> 'avg_read_latency_ms' AS avg_read_latency_ms,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'avg_write_latency_ms' AS avg_write_latency_ms,
    j.value ->> 'checkpoint_pages_sec' AS checkpoint_pages_sec,
    j.value ->> 'db_name' AS db_name,
    j.value ->> 'num_of_reads' AS num_of_reads,
    j.value ->> 'num_of_writes' AS num_of_writes,
    j.value ->> 'page_reads_sec' AS page_reads_sec,
    j.value ->> 'page_writes_sec' AS page_writes_sec,
    j.value ->> 'pending_io_requests' AS pending_io_requests,
    j.value ->> 'physical_name' AS physical_name,
    j.value ->> 'total_io_stall_ms' AS total_io_stall_ms,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-003-RC15';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc01 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'files_per_cpu' AS files_per_cpu,
    j.value ->> 'logical_cpus' AS logical_cpus,
    j.value ->> 'tempdb_data_files' AS tempdb_data_files,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-004-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc02 AS
SELECT
    r.server,
    j.value ->> 'avg_pagelatch_up_ms' AS avg_pagelatch_up_ms,
    j.value ->> 'cpu_cores' AS cpu_cores,
    j.value ->> 'pagelatch_up_total_ms' AS pagelatch_up_total_ms,
    j.value ->> 'pagelatch_up_waits' AS pagelatch_up_waits,
    j.value ->> 'tempdb_files' AS tempdb_files,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-004-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc03 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'free_space_mb' AS free_space_mb,
    j.value ->> 'pagelatch_waits' AS pagelatch_waits,
    j.value ->> 'tempdb_files' AS tempdb_files,
    j.value ->> 'used_space_mb' AS used_space_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-004-RC03';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc04 AS
SELECT
    r.server,
    j.value ->> 'extent_allocation_mode' AS extent_allocation_mode,
    j.value ->> 'Global' AS Global,
    j.value ->> 'Session' AS Session,
    j.value ->> 'sql_version_major' AS sql_version_major,
    j.value ->> 'Status' AS Status,
    j.value ->> 'tempdb_files' AS tempdb_files,
    j.value ->> 'TraceFlag' AS TraceFlag,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-004-RC04';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc05 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'Global' AS Global,
    j.value ->> 'major_version' AS major_version,
    j.value ->> 'product_version' AS product_version,
    j.value ->> 'Session' AS Session,
    j.value ->> 'Status' AS Status,
    j.value ->> 'tf1118_recommendation' AS tf1118_recommendation,
    j.value ->> 'TraceFlag' AS TraceFlag,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-004-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc06 AS
SELECT
    r.server,
    j.value ->> 'file_id' AS file_id,
    j.value ->> 'file_size_mb' AS file_size_mb,
    j.value ->> 'free_mb' AS free_mb,
    j.value ->> 'growth' AS growth,
    j.value ->> 'is_percent_growth' AS is_percent_growth,
    j.value ->> 'max_size' AS max_size,
    j.value ->> 'name' AS name,
    j.value ->> 'physical_name' AS physical_name,
    j.value ->> 'size_mb' AS size_mb,
    j.value ->> 'used_mb' AS used_mb,
    j.value ->> 'utilization_ratio' AS utilization_ratio,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-004-RC06';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc07 AS
SELECT
    r.server,
    j.value ->> 'active_sessions' AS active_sessions,
    j.value ->> 'alloc_pages' AS alloc_pages,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'dealloc_pages' AS dealloc_pages,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'internal_obj_alloc_pages' AS internal_obj_alloc_pages,
    j.value ->> 'internal_obj_dealloc_pages' AS internal_obj_dealloc_pages,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'user_obj_alloc_pages' AS user_obj_alloc_pages,
    j.value ->> 'user_obj_dealloc_pages' AS user_obj_dealloc_pages,
    j.value ->> 'wait_resource' AS wait_resource,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-004-RC07';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc08 AS
SELECT
    r.server,
    j.value ->> 'free_space_mb' AS free_space_mb,
    j.value ->> 'internal_objects_mb' AS internal_objects_mb,
    j.value ->> 'user_objects_mb' AS user_objects_mb,
    j.value ->> 'version_store_mb' AS version_store_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-004-RC08';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc09 AS
SELECT
    r.server,
    j.value ->> 'compatibility_level' AS compatibility_level,
    j.value ->> 'internal_obj_kb' AS internal_obj_kb,
    j.value ->> 'major_version' AS major_version,
    j.value ->> 'temp_table_creation_rate' AS temp_table_creation_rate,
    j.value ->> 'tv_behavior' AS tv_behavior,
    j.value ->> 'user_obj_kb' AS user_obj_kb,
    j.value ->> 'version_store_kb' AS version_store_kb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-004-RC09';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc10 AS
SELECT
    r.server,
    j.value ->> 'avg_cpu_us' AS avg_cpu_us,
    j.value ->> 'avg_elapsed_us' AS avg_elapsed_us,
    j.value ->> 'avg_grant_kb' AS avg_grant_kb,
    j.value ->> 'avg_ideal_grant_kb' AS avg_ideal_grant_kb,
    j.value ->> 'avg_spills_per_exec' AS avg_spills_per_exec,
    j.value ->> 'avg_used_grant_kb' AS avg_used_grant_kb,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'query_text' AS query_text,
    j.value ->> 'total_spills' AS total_spills,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-004-RC10';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc11 AS
SELECT
    r.server,
    j.value ->> 'avg_cpu_us' AS avg_cpu_us,
    j.value ->> 'avg_elapsed_us' AS avg_elapsed_us,
    j.value ->> 'avg_logical_writes' AS avg_logical_writes,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'db_name' AS db_name,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'proc_name' AS proc_name,
    j.value ->> 'sql_compilations_sec' AS sql_compilations_sec,
    j.value ->> 'temp_creation_rate' AS temp_creation_rate,
    j.value ->> 'temp_for_destruction' AS temp_for_destruction,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-004-RC11';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc12 AS
SELECT
    r.server,
    j.value ->> 'available_memory_kb' AS available_memory_kb,
    j.value ->> 'granted_memory_kb' AS granted_memory_kb,
    j.value ->> 'grantee_count' AS grantee_count,
    j.value ->> 'internal_obj_kb' AS internal_obj_kb,
    j.value ->> 'internal_obj_pct' AS internal_obj_pct,
    j.value ->> 'memory_utilization_pct' AS memory_utilization_pct,
    j.value ->> 'tempdb_size_kb' AS tempdb_size_kb,
    j.value ->> 'total_memory_kb' AS total_memory_kb,
    j.value ->> 'used_memory_kb' AS used_memory_kb,
    j.value ->> 'user_obj_kb' AS user_obj_kb,
    j.value ->> 'waiter_count' AS waiter_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-004-RC12';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc13 AS
SELECT
    r.server,
    j.value ->> 'avg_read_stall_ms' AS avg_read_stall_ms,
    j.value ->> 'avg_write_stall_ms' AS avg_write_stall_ms,
    j.value ->> 'num_of_reads' AS num_of_reads,
    j.value ->> 'num_of_writes' AS num_of_writes,
    j.value ->> 'physical_name' AS physical_name,
    j.value ->> 'written_mb' AS written_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-004-RC13';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc14 AS
SELECT
    r.server,
    j.value ->> 'avg_read_stall_ms' AS avg_read_stall_ms,
    j.value ->> 'avg_write_stall_ms' AS avg_write_stall_ms,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'drive' AS drive,
    j.value ->> 'drive_letter' AS drive_letter,
    j.value ->> 'file_path' AS file_path,
    j.value ->> 'file_type' AS file_type,
    j.value ->> 'source' AS source,
    j.value ->> 'total_ios' AS total_ios,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-004-RC14';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc15 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'major_version' AS major_version,
    j.value ->> 'temp_creation_rate' AS temp_creation_rate,
    j.value ->> 'tempdb_memory_optimized' AS tempdb_memory_optimized,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-004-RC15';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc16 AS
SELECT
    r.server,
    j.value ->> 'duration_sec' AS duration_sec,
    j.value ->> 'is_read_committed_snapshot_on' AS is_read_committed_snapshot_on,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'name' AS name,
    j.value ->> 'perf_counter_version_kb' AS perf_counter_version_kb,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'snapshot_isolation_state' AS snapshot_isolation_state,
    j.value ->> 'snapshot_isolation_state_desc' AS snapshot_isolation_state_desc,
    j.value ->> 'tempdb_total_kb' AS tempdb_total_kb,
    j.value ->> 'tran_name' AS tran_name,
    j.value ->> 'transaction_begin_time' AS transaction_begin_time,
    j.value ->> 'transaction_id' AS transaction_id,
    j.value ->> 'version_cleanup_rate_kb_sec' AS version_cleanup_rate_kb_sec,
    j.value ->> 'version_gen_rate_kb_sec' AS version_gen_rate_kb_sec,
    j.value ->> 'version_store_kb' AS version_store_kb,
    j.value ->> 'version_store_mb' AS version_store_mb,
    j.value ->> 'version_store_pct' AS version_store_pct,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-004-RC16';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc17 AS
SELECT
    r.server,
    j.value ->> 'avg_read_stall_ms' AS avg_read_stall_ms,
    j.value ->> 'avg_write_stall_ms' AS avg_write_stall_ms,
    j.value ->> 'file_id' AS file_id,
    j.value ->> 'growth' AS growth,
    j.value ->> 'is_percent_growth' AS is_percent_growth,
    j.value ->> 'max_file_kb' AS max_file_kb,
    j.value ->> 'max_size' AS max_size,
    j.value ->> 'min_file_kb' AS min_file_kb,
    j.value ->> 'num_of_reads' AS num_of_reads,
    j.value ->> 'num_of_writes' AS num_of_writes,
    j.value ->> 'physical_name' AS physical_name,
    j.value ->> 'size_kb' AS size_kb,
    j.value ->> 'total_data_files' AS total_data_files,
    j.value ->> 'total_ios' AS total_ios,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-004-RC17';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_io_004_rc18 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'logical_cpus' AS logical_cpus,
    j.value ->> 'tempdb_data_files' AS tempdb_data_files,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IO-004-RC18';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_001_rc03 AS
SELECT
    r.server,
    j.value ->> 'auto_created' AS auto_created,
    j.value ->> 'avg_elapsed_us' AS avg_elapsed_us,
    j.value ->> 'avg_logical_reads' AS avg_logical_reads,
    j.value ->> 'avg_rows' AS avg_rows,
    j.value ->> 'db_name' AS db_name,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'hours_since_update' AS hours_since_update,
    j.value ->> 'is_auto_create_stats_on' AS is_auto_create_stats_on,
    j.value ->> 'is_auto_update_stats_async_on' AS is_auto_update_stats_async_on,
    j.value ->> 'is_auto_update_stats_on' AS is_auto_update_stats_on,
    j.value ->> 'last_updated' AS last_updated,
    j.value ->> 'modification_counter' AS modification_counter,
    j.value ->> 'modification_pct' AS modification_pct,
    j.value ->> 'query_text' AS query_text,
    j.value ->> 'rows_sampled' AS rows_sampled,
    j.value ->> 'stale_stat_count' AS stale_stat_count,
    j.value ->> 'stat_name' AS stat_name,
    j.value ->> 'stat_rows' AS stat_rows,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'user_created' AS user_created,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IX-001-RC03';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_001_rc04 AS
SELECT
    r.server,
    j.value ->> 'avg_elapsed_us' AS avg_elapsed_us,
    j.value ->> 'avg_logical_reads' AS avg_logical_reads,
    j.value ->> 'avg_rows' AS avg_rows,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'query_text' AS query_text,
    j.value ->> 'selectivity_pct' AS selectivity_pct,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IX-001-RC04';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_001_rc09 AS
SELECT
    r.server,
    j.value ->> 'index_name' AS index_name,
    j.value ->> 'last_updated' AS last_updated,
    j.value ->> 'modification_counter' AS modification_counter,
    j.value ->> 'stat_name' AS stat_name,
    j.value ->> 'stat_rows' AS stat_rows,
    j.value ->> 'table_name' AS table_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IX-001-RC09';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_002_rc02 AS
SELECT
    r.server,
    j.value ->> 'sqlserver_start_time' AS sqlserver_start_time,
    j.value ->> 'uptime_days' AS uptime_days,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IX-002-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_002_rc03 AS
SELECT
    r.server,
    j.value ->> 'reads' AS reads,
    j.value ->> 'redundant_index' AS redundant_index,
    j.value ->> 'size_mb' AS size_mb,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'write_overhead' AS write_overhead,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IX-002-RC03';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_002_rc05 AS
SELECT
    r.server,
    j.value ->> 'sqlserver_start_time' AS sqlserver_start_time,
    j.value ->> 'uptime_days' AS uptime_days,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IX-002-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_002_rc12 AS
SELECT
    r.server,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'is_auto_create_stats_on' AS is_auto_create_stats_on,
    j.value ->> 'is_auto_update_stats_async_on' AS is_auto_update_stats_async_on,
    j.value ->> 'is_auto_update_stats_on' AS is_auto_update_stats_on,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IX-002-RC12';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_003_rc05 AS
SELECT
    r.server,
    j.value ->> 'fill_factor_setting' AS fill_factor_setting,
    j.value ->> 'name' AS name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IX-003-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_003_rc11 AS
SELECT
    r.server,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'file_name' AS file_name,
    j.value ->> 'free_mb' AS free_mb,
    j.value ->> 'growth' AS growth,
    j.value ->> 'max_size' AS max_size,
    j.value ->> 'total_mb' AS total_mb,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'used_mb' AS used_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IX-003-RC11';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_003_rc12 AS
SELECT
    r.server,
    j.value ->> 'blocking_session_id' AS blocking_session_id,
    j.value ->> 'command' AS command,
    j.value ->> 'elapsed_minutes' AS elapsed_minutes,
    j.value ->> 'index_name' AS index_name,
    j.value ->> 'percent_complete' AS percent_complete,
    j.value ->> 'rebuild_mode' AS rebuild_mode,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'sql_text' AS sql_text,
    j.value ->> 'status' AS status,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'wait_time' AS wait_time,
    j.value ->> 'wait_type' AS wait_type,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IX-003-RC12';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_004_rc01 AS
SELECT
    r.server,
    j.value ->> 'index1' AS index1,
    j.value ->> 'index1_keys' AS index1_keys,
    j.value ->> 'index2' AS index2,
    j.value ->> 'index2_keys' AS index2_keys,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'type1' AS type1,
    j.value ->> 'type2' AS type2,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IX-004-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_004_rc03 AS
SELECT
    r.server,
    j.value ->> 'index1' AS index1,
    j.value ->> 'index2' AS index2,
    j.value ->> 'key_cols_1' AS key_cols_1,
    j.value ->> 'key_cols_2' AS key_cols_2,
    j.value ->> 'table_name' AS table_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IX-004-RC03';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_004_rc05 AS
SELECT
    r.server,
    j.value ->> 'index_name' AS index_name,
    j.value ->> 'is_primary_key' AS is_primary_key,
    j.value ->> 'is_unique' AS is_unique,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'user_scans' AS user_scans,
    j.value ->> 'user_seeks' AS user_seeks,
    j.value ->> 'user_updates' AS user_updates,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IX-004-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_005_rc09 AS
SELECT
    r.server,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'is_auto_create_stats_on' AS is_auto_create_stats_on,
    j.value ->> 'is_auto_update_stats_async_on' AS is_auto_update_stats_async_on,
    j.value ->> 'is_auto_update_stats_on' AS is_auto_update_stats_on,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IX-005-RC09';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_006_rc03 AS
SELECT
    r.server,
    j.value ->> 'sqlserver_start_time' AS sqlserver_start_time,
    j.value ->> 'total_wasted_mb' AS total_wasted_mb,
    j.value ->> 'total_wasted_updates' AS total_wasted_updates,
    j.value ->> 'unused_index_count' AS unused_index_count,
    j.value ->> 'uptime_days' AS uptime_days,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IX-006-RC03';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_006_rc05 AS
SELECT
    r.server,
    j.value ->> 'sqlserver_start_time' AS sqlserver_start_time,
    j.value ->> 'uptime_days' AS uptime_days,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IX-006-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_006_rc10 AS
SELECT
    r.server,
    j.value ->> 'sqlserver_start_time' AS sqlserver_start_time,
    j.value ->> 'uptime_days' AS uptime_days,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IX-006-RC10';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_006_rc11 AS
SELECT
    r.server,
    j.value ->> 'last_updated' AS last_updated,
    j.value ->> 'modification_counter' AS modification_counter,
    j.value ->> 'pct_modified' AS pct_modified,
    j.value ->> 'rows' AS rows,
    j.value ->> 'rows_sampled' AS rows_sampled,
    j.value ->> 'schema_name' AS schema_name,
    j.value ->> 'stats_name' AS stats_name,
    j.value ->> 'table_name' AS table_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IX-006-RC11';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_007_rc01 AS
SELECT
    r.server,
    j.value ->> 'index_name' AS index_name,
    j.value ->> 'index_size_mb' AS index_size_mb,
    j.value ->> 'key_column_count' AS key_column_count,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'total_key_bytes' AS total_key_bytes,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IX-007-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_ix_007_rc05 AS
SELECT
    r.server,
    j.value ->> 'last_updated' AS last_updated,
    j.value ->> 'leading_column' AS leading_column,
    j.value ->> 'modification_counter' AS modification_counter,
    j.value ->> 'stat_name' AS stat_name,
    j.value ->> 'stat_rows' AS stat_rows,
    j.value ->> 'table_name' AS table_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-IX-007-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_001_rc01 AS
SELECT
    r.server,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'deadlock_count_recent' AS deadlock_count_recent,
    j.value ->> 'lock_waits' AS lock_waits,
    j.value ->> 'total_lock_wait_ms' AS total_lock_wait_ms,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-001-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_001_rc02 AS
SELECT
    r.server,
    j.value ->> 'current_statement' AS current_statement,
    j.value ->> 'duration_seconds' AS duration_seconds,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'locks_held' AS locks_held,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'objects_locked' AS objects_locked,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'transaction_begin_time' AS transaction_begin_time,
    j.value ->> 'transaction_id' AS transaction_id,
    j.value ->> 'transaction_name' AS transaction_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-001-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_001_rc05 AS
SELECT
    r.server,
    j.value ->> 'avg_elapsed_us' AS avg_elapsed_us,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'query_fragment' AS query_fragment,
    j.value ->> 'total_deadlocks' AS total_deadlocks,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-001-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_001_rc07 AS
SELECT
    r.server,
    j.value ->> 'total_deadlocks' AS total_deadlocks,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-001-RC07';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_001_rc08 AS
SELECT
    r.server,
    j.value ->> 'name' AS name,
    j.value ->> 'value_in_use' AS value_in_use,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-001-RC08';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_001_rc11 AS
SELECT
    r.server,
    j.value ->> 'total_deadlocks' AS total_deadlocks,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-001-RC11';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_001_rc12 AS
SELECT
    r.server,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'query_fragment' AS query_fragment,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-001-RC12';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_001_rc13 AS
SELECT
    r.server,
    j.value ->> 'duration_sec' AS duration_sec,
    j.value ->> 'held_locks' AS held_locks,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'session_status' AS session_status,
    j.value ->> 'transaction_id' AS transaction_id,
    j.value ->> 'transaction_name' AS transaction_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-001-RC13';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_001_rc14 AS
SELECT
    r.server,
    j.value ->> 'total_deadlocks' AS total_deadlocks,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-001-RC14';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_002_rc02 AS
SELECT
    r.server,
    j.value ->> 'avg_reads' AS avg_reads,
    j.value ->> 'blocking_session_id' AS blocking_session_id,
    j.value ->> 'elapsed_sec' AS elapsed_sec,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'granted_query_memory' AS granted_query_memory,
    j.value ->> 'logical_reads' AS logical_reads,
    j.value ->> 'plan_xml' AS plan_xml,
    j.value ->> 'query_fragment' AS query_fragment,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'status' AS status,
    j.value ->> 'wait_type' AS wait_type,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-002-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_002_rc06 AS
SELECT
    r.server,
    j.value ->> 'held_lock_count' AS held_lock_count,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'idle_seconds' AS idle_seconds,
    j.value ->> 'last_request_end_time' AS last_request_end_time,
    j.value ->> 'login_time' AS login_time,
    j.value ->> 'open_transaction_count' AS open_transaction_count,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_id' AS session_id,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-002-RC06';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_002_rc07 AS
SELECT
    r.server,
    j.value ->> 'current_lock_count' AS current_lock_count,
    j.value ->> 'lock_memory_kb' AS lock_memory_kb,
    j.value ->> 'total_deadlocks' AS total_deadlocks,
    j.value ->> 'total_lock_wait_ms' AS total_lock_wait_ms,
    j.value ->> 'total_lock_waits' AS total_lock_waits,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-002-RC07';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_002_rc08 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'signal_wait_time_ms' AS signal_wait_time_ms,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-002-RC08';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_002_rc09 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-002-RC09';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_002_rc10 AS
SELECT
    r.server,
    j.value ->> 'cpu_time' AS cpu_time,
    j.value ->> 'held_locks' AS held_locks,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'logical_reads' AS logical_reads,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_elapsed_sec' AS session_elapsed_sec,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'transaction_id' AS transaction_id,
    j.value ->> 'txn_duration_sec' AS txn_duration_sec,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-002-RC10';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_002_rc11 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_seconds' AS avg_wait_seconds,
    j.value ->> 'blocked_pct' AS blocked_pct,
    j.value ->> 'blocked_session_count' AS blocked_session_count,
    j.value ->> 'blocked_sessions' AS blocked_sessions,
    j.value ->> 'max_wait_seconds' AS max_wait_seconds,
    j.value ->> 'sleeping_sessions' AS sleeping_sessions,
    j.value ->> 'total_user_sessions' AS total_user_sessions,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-002-RC11';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_002_rc14 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'is_auto_update_stats_async_on' AS is_auto_update_stats_async_on,
    j.value ->> 'is_auto_update_stats_on' AS is_auto_update_stats_on,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-002-RC14';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_003_rc01 AS
SELECT
    r.server,
    j.value ->> 'blocked_sessions' AS blocked_sessions,
    j.value ->> 'duration_seconds' AS duration_seconds,
    j.value ->> 'held_locks' AS held_locks,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'last_sql_text' AS last_sql_text,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'transaction_begin_time' AS transaction_begin_time,
    j.value ->> 'transaction_id' AS transaction_id,
    j.value ->> 'transaction_state' AS transaction_state,
    j.value ->> 'transaction_type' AS transaction_type,
    j.value ->> 'txn_duration_seconds' AS txn_duration_seconds,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-003-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_003_rc05 AS
SELECT
    r.server,
    j.value ->> 'blocking_session_id' AS blocking_session_id,
    j.value ->> 'command' AS command,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'sql_text' AS sql_text,
    j.value ->> 'wait_seconds' AS wait_seconds,
    j.value ->> 'wait_type' AS wait_type,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-003-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_003_rc08 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-003-RC08';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_003_rc10 AS
SELECT
    r.server,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'rcsi_enabled' AS rcsi_enabled,
    j.value ->> 'snapshot_isolation_state' AS snapshot_isolation_state,
    j.value ->> 'snapshot_isolation_state_desc' AS snapshot_isolation_state_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-003-RC10';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_003_rc11 AS
SELECT
    r.server,
    j.value ->> 'deadlock_count' AS deadlock_count,
    j.value ->> 'first_deadlock' AS first_deadlock,
    j.value ->> 'last_deadlock' AS last_deadlock,
    j.value ->> 'time_span_minutes' AS time_span_minutes,
    j.value ->> 'total_deadlocks' AS total_deadlocks,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-003-RC11';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_003_rc13 AS
SELECT
    r.server,
    j.value ->> 'command' AS command,
    j.value ->> 'percent_complete' AS percent_complete,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'sql_text' AS sql_text,
    j.value ->> 'status' AS status,
    j.value ->> 'wait_seconds' AS wait_seconds,
    j.value ->> 'wait_type' AS wait_type,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-003-RC13';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_003_rc14 AS
SELECT
    r.server,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'is_auto_update_stats_async_on' AS is_auto_update_stats_async_on,
    j.value ->> 'is_auto_update_stats_on' AS is_auto_update_stats_on,
    j.value ->> 'total_pending_modifications' AS total_pending_modifications,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-003-RC14';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_004_rc01 AS
SELECT
    r.server,
    j.value ->> 'avg_resource_wait_ms' AS avg_resource_wait_ms,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'signal_wait_time_ms' AS signal_wait_time_ms,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-004-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_004_rc02 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'pct_of_pagelatch_waits' AS pct_of_pagelatch_waits,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-004-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_004_rc03 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'page_reads_per_sec' AS page_reads_per_sec,
    j.value ->> 'ple_seconds' AS ple_seconds,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-004-RC03';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_004_rc04 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-004-RC04';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_004_rc05 AS
SELECT
    r.server,
    j.value ->> 'committed_mb' AS committed_mb,
    j.value ->> 'current_tasks' AS current_tasks,
    j.value ->> 'foreign_committed_mb' AS foreign_committed_mb,
    j.value ->> 'foreign_pct' AS foreign_pct,
    j.value ->> 'memory_node_id' AS memory_node_id,
    j.value ->> 'pages_mb' AS pages_mb,
    j.value ->> 'parent_node_id' AS parent_node_id,
    j.value ->> 'pending_io' AS pending_io,
    j.value ->> 'runnable_tasks' AS runnable_tasks,
    j.value ->> 'scheduler_count' AS scheduler_count,
    j.value ->> 'total_yields' AS total_yields,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-004-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_004_rc06 AS
SELECT
    r.server,
    j.value ->> 'file_count_status' AS file_count_status,
    j.value ->> 'internal_objects_mb' AS internal_objects_mb,
    j.value ->> 'logical_cpus' AS logical_cpus,
    j.value ->> 'signal_wait_time_ms' AS signal_wait_time_ms,
    j.value ->> 'tempdb_data_files' AS tempdb_data_files,
    j.value ->> 'tempdb_free_mb' AS tempdb_free_mb,
    j.value ->> 'user_objects_mb' AS user_objects_mb,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-004-RC06';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_004_rc07 AS
SELECT
    r.server,
    j.value ->> 'avg_read_stall_ms' AS avg_read_stall_ms,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'avg_write_stall_ms' AS avg_write_stall_ms,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'io_stall_read_ms' AS io_stall_read_ms,
    j.value ->> 'io_stall_write_ms' AS io_stall_write_ms,
    j.value ->> 'num_of_reads' AS num_of_reads,
    j.value ->> 'num_of_writes' AS num_of_writes,
    j.value ->> 'physical_name' AS physical_name,
    j.value ->> 'resource_wait_ms' AS resource_wait_ms,
    j.value ->> 'signal_wait_time_ms' AS signal_wait_time_ms,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-004-RC07';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_004_rc08 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-004-RC08';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_004_rc13 AS
SELECT
    r.server,
    j.value ->> 'backoffs' AS backoffs,
    j.value ->> 'collisions' AS collisions,
    j.value ->> 'signal_pct' AS signal_pct,
    j.value ->> 'signal_wait_time_ms' AS signal_wait_time_ms,
    j.value ->> 'sleep_time' AS sleep_time,
    j.value ->> 'spinlock_name' AS spinlock_name,
    j.value ->> 'spins' AS spins,
    j.value ->> 'spins_per_collision' AS spins_per_collision,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-004-RC13';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_004_rc14 AS
SELECT
    r.server,
    j.value ->> 'avg_load_factor' AS avg_load_factor,
    j.value ->> 'committed_mb' AS committed_mb,
    j.value ->> 'foreign_committed_mb' AS foreign_committed_mb,
    j.value ->> 'latch_class' AS latch_class,
    j.value ->> 'locked_pages_mb' AS locked_pages_mb,
    j.value ->> 'max_wait_time_ms' AS max_wait_time_ms,
    j.value ->> 'memory_node_id' AS memory_node_id,
    j.value ->> 'numa_node' AS numa_node,
    j.value ->> 'pages_mb' AS pages_mb,
    j.value ->> 'runnable_tasks' AS runnable_tasks,
    j.value ->> 'scheduler_count' AS scheduler_count,
    j.value ->> 'shared_mb' AS shared_mb,
    j.value ->> 'total_tasks' AS total_tasks,
    j.value ->> 'total_yields' AS total_yields,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'waiting_requests_count' AS waiting_requests_count,
    j.value ->> 'work_queue' AS work_queue,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-004-RC14';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_005_rc01 AS
SELECT
    r.server,
    j.value ->> 'command' AS command,
    j.value ->> 'duration_sec' AS duration_sec,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'sql_text' AS sql_text,
    j.value ->> 'tran_name' AS tran_name,
    j.value ->> 'transaction_begin_time' AS transaction_begin_time,
    j.value ->> 'transaction_id' AS transaction_id,
    j.value ->> 'wait_type' AS wait_type,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-005-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_005_rc02 AS
SELECT
    r.server,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'last_sql' AS last_sql,
    j.value ->> 'last_wait_type' AS last_wait_type,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'session_status' AS session_status,
    j.value ->> 'transaction_duration_sec' AS transaction_duration_sec,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-005-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_005_rc03 AS
SELECT
    r.server,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'idle_since_last_request_sec' AS idle_since_last_request_sec,
    j.value ->> 'last_sql' AS last_sql,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'open_transaction_count' AS open_transaction_count,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'status' AS status,
    j.value ->> 'transaction_duration_sec' AS transaction_duration_sec,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-005-RC03';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_005_rc04 AS
SELECT
    r.server,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'idle_seconds' AS idle_seconds,
    j.value ->> 'implicit_transactions_on' AS implicit_transactions_on,
    j.value ->> 'last_sql' AS last_sql,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'open_transaction_count' AS open_transaction_count,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'status' AS status,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-005-RC04';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_005_rc06 AS
SELECT
    r.server,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'idle_seconds' AS idle_seconds,
    j.value ->> 'last_request_end_time' AS last_request_end_time,
    j.value ->> 'last_request_start_time' AS last_request_start_time,
    j.value ->> 'lock_count' AS lock_count,
    j.value ->> 'log_bytes_used' AS log_bytes_used,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'open_transaction_count' AS open_transaction_count,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'resource_type' AS resource_type,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'status' AS status,
    j.value ->> 'transaction_age_minutes' AS transaction_age_minutes,
    j.value ->> 'transaction_begin_time' AS transaction_begin_time,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-005-RC06';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_005_rc07 AS
SELECT
    r.server,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'is_auto_close_on' AS is_auto_close_on,
    j.value ->> 'is_auto_shrink_on' AS is_auto_shrink_on,
    j.value ->> 'isolation_level' AS isolation_level,
    j.value ->> 'isolation_level_id' AS isolation_level_id,
    j.value ->> 'last_sql' AS last_sql,
    j.value ->> 'open_transaction_count' AS open_transaction_count,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'rcsi_enabled' AS rcsi_enabled,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'snapshot_isolation_state_desc' AS snapshot_isolation_state_desc,
    j.value ->> 'transaction_duration_sec' AS transaction_duration_sec,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-005-RC07';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_lc_005_rc13 AS
SELECT
    r.server,
    j.value ->> 'active_grants' AS active_grants,
    j.value ->> 'avg_resource_sem_wait_ms' AS avg_resource_sem_wait_ms,
    j.value ->> 'grant_time' AS grant_time,
    j.value ->> 'granted_memory_kb' AS granted_memory_kb,
    j.value ->> 'ideal_memory_kb' AS ideal_memory_kb,
    j.value ->> 'max_used_memory_kb' AS max_used_memory_kb,
    j.value ->> 'pending_grants' AS pending_grants,
    j.value ->> 'pending_memory_mb' AS pending_memory_mb,
    j.value ->> 'query_cost' AS query_cost,
    j.value ->> 'query_text' AS query_text,
    j.value ->> 'required_memory_kb' AS required_memory_kb,
    j.value ->> 'resource_pool' AS resource_pool,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'total_waits' AS total_waits,
    j.value ->> 'used_memory_kb' AS used_memory_kb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-LC-005-RC13';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_001_rc01 AS
SELECT
    r.server,
    j.value ->> 'available_physical_mb' AS available_physical_mb,
    j.value ->> 'grants_pending' AS grants_pending,
    j.value ->> 'low_physical_memory' AS low_physical_memory,
    j.value ->> 'max_server_memory_mb' AS max_server_memory_mb,
    j.value ->> 'ple_seconds' AS ple_seconds,
    j.value ->> 'sql_memory_util_pct' AS sql_memory_util_pct,
    j.value ->> 'sqlserver_using_mb' AS sqlserver_using_mb,
    j.value ->> 'system_memory_state' AS system_memory_state,
    j.value ->> 'total_memory_clerks_mb' AS total_memory_clerks_mb,
    j.value ->> 'total_physical_mb' AS total_physical_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-001-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_001_rc02 AS
SELECT
    r.server,
    j.value ->> 'buffer_pool_data_mb' AS buffer_pool_data_mb,
    j.value ->> 'cache_hit_ratio' AS cache_hit_ratio,
    j.value ->> 'cache_hit_ratio_base' AS cache_hit_ratio_base,
    j.value ->> 'lazy_writes_sec' AS lazy_writes_sec,
    j.value ->> 'max_memory_mb' AS max_memory_mb,
    j.value ->> 'page_life_expectancy' AS page_life_expectancy,
    j.value ->> 'page_reads_sec' AS page_reads_sec,
    j.value ->> 'total_data_file_mb' AS total_data_file_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-001-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_001_rc03 AS
SELECT
    r.server,
    j.value ->> 'avg_session_memory_kb' AS avg_session_memory_kb,
    j.value ->> 'clerk_memory_mb' AS clerk_memory_mb,
    j.value ->> 'clerk_type' AS clerk_type,
    j.value ->> 'connection_memory_kb' AS connection_memory_kb,
    j.value ->> 'total_session_memory_kb' AS total_session_memory_kb,
    j.value ->> 'total_sessions' AS total_sessions,
    j.value ->> 'user_connections' AS user_connections,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-001-RC03';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_001_rc04 AS
SELECT
    r.server,
    j.value ->> 'grants_pending' AS grants_pending,
    j.value ->> 'total_granted_mb' AS total_granted_mb,
    j.value ->> 'total_server_mb' AS total_server_mb,
    j.value ->> 'total_used_mb' AS total_used_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-001-RC04';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_001_rc05 AS
SELECT
    r.server,
    j.value ->> 'clerk_mb' AS clerk_mb,
    j.value ->> 'clerk_name' AS clerk_name,
    j.value ->> 'clerk_type' AS clerk_type,
    j.value ->> 'committed_vas_mb' AS committed_vas_mb,
    j.value ->> 'locked_pages_mb' AS locked_pages_mb,
    j.value ->> 'low_memory_signal' AS low_memory_signal,
    j.value ->> 'low_vas_signal' AS low_vas_signal,
    j.value ->> 'memory_utilization_percentage' AS memory_utilization_percentage,
    j.value ->> 'pct_of_total' AS pct_of_total,
    j.value ->> 'physical_in_use_mb' AS physical_in_use_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-001-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_001_rc06 AS
SELECT
    r.server,
    j.value ->> 'grants_outstanding' AS grants_outstanding,
    j.value ->> 'grants_pending' AS grants_pending,
    j.value ->> 'ple' AS ple,
    j.value ->> 'total_granted_mb' AS total_granted_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-001-RC06';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_001_rc07 AS
SELECT
    r.server,
    j.value ->> 'cached_proc_plans' AS cached_proc_plans,
    j.value ->> 'plan_cache_hit_ratio' AS plan_cache_hit_ratio,
    j.value ->> 'proc_cache_mb' AS proc_cache_mb,
    j.value ->> 'recompiles_sec' AS recompiles_sec,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-001-RC07';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_001_rc08 AS
SELECT
    r.server,
    j.value ->> 'checkpoint_pages_sec' AS checkpoint_pages_sec,
    j.value ->> 'clerk_mb' AS clerk_mb,
    j.value ->> 'free_list_stalls_sec' AS free_list_stalls_sec,
    j.value ->> 'ghost_cleanup_sec' AS ghost_cleanup_sec,
    j.value ->> 'lazy_writes_sec' AS lazy_writes_sec,
    j.value ->> 'type' AS type,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-001-RC08';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_001_rc09 AS
SELECT
    r.server,
    j.value ->> 'available_mb' AS available_mb,
    j.value ->> 'current_using_mb' AS current_using_mb,
    j.value ->> 'max_configured_mb' AS max_configured_mb,
    j.value ->> 'other_processes_mb' AS other_processes_mb,
    j.value ->> 'sql_low_memory' AS sql_low_memory,
    j.value ->> 'sql_using_mb' AS sql_using_mb,
    j.value ->> 'system_memory_state_desc' AS system_memory_state_desc,
    j.value ->> 'target_mb' AS target_mb,
    j.value ->> 'total_physical_mb' AS total_physical_mb,
    j.value ->> 'total_server_mb' AS total_server_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-001-RC09';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_001_rc10 AS
SELECT
    r.server,
    j.value ->> 'connection_memory_mb' AS connection_memory_mb,
    j.value ->> 'session_memory_mb' AS session_memory_mb,
    j.value ->> 'token_perm_mb' AS token_perm_mb,
    j.value ->> 'total_user_sessions' AS total_user_sessions,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-001-RC10';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_001_rc11 AS
SELECT
    r.server,
    j.value ->> 'duration_sec' AS duration_sec,
    j.value ->> 'longest_txn_sec' AS longest_txn_sec,
    j.value ->> 'open_transaction_count' AS open_transaction_count,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'session_status' AS session_status,
    j.value ->> 'tempdb_free_mb' AS tempdb_free_mb,
    j.value ->> 'transaction_id' AS transaction_id,
    j.value ->> 'transaction_type' AS transaction_type,
    j.value ->> 'version_gen_rate_kb_sec' AS version_gen_rate_kb_sec,
    j.value ->> 'version_store_mb' AS version_store_mb,
    j.value ->> 'version_store_reserved_mb' AS version_store_reserved_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-001-RC11';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_001_rc12 AS
SELECT
    r.server,
    j.value ->> 'ghost_cleanup_sec' AS ghost_cleanup_sec,
    j.value ->> 'ple' AS ple,
    j.value ->> 'total_forwarded_fetches' AS total_forwarded_fetches,
    j.value ->> 'total_ghost_records' AS total_ghost_records,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-001-RC12';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_001_rc14 AS
SELECT
    r.server,
    j.value ->> 'cost_threshold' AS cost_threshold,
    j.value ->> 'queries_waiting_for_grant' AS queries_waiting_for_grant,
    j.value ->> 'resource_semaphore_wait_ms' AS resource_semaphore_wait_ms,
    j.value ->> 'resource_semaphore_waiters' AS resource_semaphore_waiters,
    j.value ->> 'server_maxdop' AS server_maxdop,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-001-RC14';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_002_rc02 AS
SELECT
    r.server,
    j.value ->> 'auto_created' AS auto_created,
    j.value ->> 'last_updated' AS last_updated,
    j.value ->> 'modified_pct' AS modified_pct,
    j.value ->> 'rows_modified' AS rows_modified,
    j.value ->> 'stat_name' AS stat_name,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'table_rows' AS table_rows,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-002-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_002_rc06 AS
SELECT
    r.server,
    j.value ->> 'large_grant_count' AS large_grant_count,
    j.value ->> 'pending_grants' AS pending_grants,
    j.value ->> 'resource_semaphore_wait_ms' AS resource_semaphore_wait_ms,
    j.value ->> 'total_granted_kb' AS total_granted_kb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-002-RC06';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_002_rc08 AS
SELECT
    r.server,
    j.value ->> 'cost_threshold' AS cost_threshold,
    j.value ->> 'effective_maxdop' AS effective_maxdop,
    j.value ->> 'logical_cpus' AS logical_cpus,
    j.value ->> 'maxdop' AS maxdop,
    j.value ->> 'numa_nodes' AS numa_nodes,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-002-RC08';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_002_rc13 AS
SELECT
    r.server,
    j.value ->> 'included_columns' AS included_columns,
    j.value ->> 'index_name' AS index_name,
    j.value ->> 'key_columns' AS key_columns,
    j.value ->> 'key_lookups' AS key_lookups,
    j.value ->> 'leaf_insert_count' AS leaf_insert_count,
    j.value ->> 'range_scan_count' AS range_scan_count,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-002-RC13';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_002_rc15 AS
SELECT
    r.server,
    j.value ->> 'grant_status' AS grant_status,
    j.value ->> 'grant_wait_ms' AS grant_wait_ms,
    j.value ->> 'granted_memory_kb' AS granted_memory_kb,
    j.value ->> 'ideal_memory_kb' AS ideal_memory_kb,
    j.value ->> 'is_small' AS is_small,
    j.value ->> 'requested_memory_kb' AS requested_memory_kb,
    j.value ->> 'required_memory_kb' AS required_memory_kb,
    j.value ->> 'session_id' AS session_id,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-002-RC15';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc01 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'cache_hit_ratio' AS cache_hit_ratio,
    j.value ->> 'cache_hit_ratio_base' AS cache_hit_ratio_base,
    j.value ->> 'lazy_writes_per_sec' AS lazy_writes_per_sec,
    j.value ->> 'max_server_memory_mb' AS max_server_memory_mb,
    j.value ->> 'memory_utilization_percentage' AS memory_utilization_percentage,
    j.value ->> 'page_reads_per_sec' AS page_reads_per_sec,
    j.value ->> 'physical_in_use_mb' AS physical_in_use_mb,
    j.value ->> 'physical_memory_mb' AS physical_memory_mb,
    j.value ->> 'ple_seconds' AS ple_seconds,
    j.value ->> 'signal_wait_time_ms' AS signal_wait_time_ms,
    j.value ->> 'sql_committed_mb' AS sql_committed_mb,
    j.value ->> 'sql_target_mb' AS sql_target_mb,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-003-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc02 AS
SELECT
    r.server,
    j.value ->> 'buffer_pool_coverage_pct' AS buffer_pool_coverage_pct,
    j.value ->> 'buffer_pool_used_mb' AS buffer_pool_used_mb,
    j.value ->> 'checkpoint_pages' AS checkpoint_pages,
    j.value ->> 'free_list_stalls' AS free_list_stalls,
    j.value ->> 'lazy_writes' AS lazy_writes,
    j.value ->> 'max_memory_pct_of_physical' AS max_memory_pct_of_physical,
    j.value ->> 'max_server_memory_mb' AS max_server_memory_mb,
    j.value ->> 'min_server_memory_mb' AS min_server_memory_mb,
    j.value ->> 'physical_memory_mb' AS physical_memory_mb,
    j.value ->> 'ple_seconds' AS ple_seconds,
    j.value ->> 'sql_committed_mb' AS sql_committed_mb,
    j.value ->> 'sql_target_mb' AS sql_target_mb,
    j.value ->> 'total_data_size_mb' AS total_data_size_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-003-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc03 AS
SELECT
    r.server,
    j.value ->> 'cache_hit_ratio' AS cache_hit_ratio,
    j.value ->> 'cached_mb' AS cached_mb,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'dirty_mb' AS dirty_mb,
    j.value ->> 'page_reads_per_sec' AS page_reads_per_sec,
    j.value ->> 'ple_seconds' AS ple_seconds,
    j.value ->> 'readahead_per_sec' AS readahead_per_sec,
    j.value ->> 'total_table_scans' AS total_table_scans,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-003-RC03';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc04 AS
SELECT
    r.server,
    j.value ->> 'cache_hit_ratio' AS cache_hit_ratio,
    j.value ->> 'cache_hit_ratio_base' AS cache_hit_ratio_base,
    j.value ->> 'lazy_writes_per_sec' AS lazy_writes_per_sec,
    j.value ->> 'page_reads_per_sec' AS page_reads_per_sec,
    j.value ->> 'ple_seconds' AS ple_seconds,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-003-RC04';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc05 AS
SELECT
    r.server,
    j.value ->> 'full_scans_sec' AS full_scans_sec,
    j.value ->> 'page_reads_sec' AS page_reads_sec,
    j.value ->> 'ple_seconds' AS ple_seconds,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-003-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc06 AS
SELECT
    r.server,
    j.value ->> 'estimated_wasted_pages' AS estimated_wasted_pages,
    j.value ->> 'ple_seconds' AS ple_seconds,
    j.value ->> 'total_pages_in_buffer' AS total_pages_in_buffer,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-003-RC06';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc07 AS
SELECT
    r.server,
    j.value ->> 'bgwriter_pages_sec' AS bgwriter_pages_sec,
    j.value ->> 'checkpoint_pages_sec' AS checkpoint_pages_sec,
    j.value ->> 'page_writes_sec' AS page_writes_sec,
    j.value ->> 'ple_seconds' AS ple_seconds,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-003-RC07';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc09 AS
SELECT
    r.server,
    j.value ->> 'total_buffer_pages' AS total_buffer_pages,
    j.value ->> 'total_wasted_pages' AS total_wasted_pages,
    j.value ->> 'wasted_mb' AS wasted_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-003-RC09';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc10 AS
SELECT
    r.server,
    j.value ->> 'batch_requests_sec' AS batch_requests_sec,
    j.value ->> 'page_splits_sec' AS page_splits_sec,
    j.value ->> 'ple_seconds' AS ple_seconds,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-003-RC10';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc11 AS
SELECT
    r.server,
    j.value ->> 'avg_logical_reads' AS avg_logical_reads,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'full_scans_sec' AS full_scans_sec,
    j.value ->> 'index_seeks_sec' AS index_seeks_sec,
    j.value ->> 'page_reads_sec' AS page_reads_sec,
    j.value ->> 'ple_seconds' AS ple_seconds,
    j.value ->> 'query_fragment' AS query_fragment,
    j.value ->> 'total_logical_reads' AS total_logical_reads,
    j.value ->> 'total_physical_reads' AS total_physical_reads,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-003-RC11';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc12 AS
SELECT
    r.server,
    j.value ->> 'current_query' AS current_query,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'internal_alloc_pages' AS internal_alloc_pages,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'tempdb_buffer_mb' AS tempdb_buffer_mb,
    j.value ->> 'tempdb_buffer_pct' AS tempdb_buffer_pct,
    j.value ->> 'tempdb_pages_in_buffer' AS tempdb_pages_in_buffer,
    j.value ->> 'total_alloc_pages' AS total_alloc_pages,
    j.value ->> 'total_buffer_pages' AS total_buffer_pages,
    j.value ->> 'user_alloc_pages' AS user_alloc_pages,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-003-RC12';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc13 AS
SELECT
    r.server,
    j.value ->> 'avg_elapsed_ms' AS avg_elapsed_ms,
    j.value ->> 'avg_logical_reads' AS avg_logical_reads,
    j.value ->> 'avg_physical_reads' AS avg_physical_reads,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'free_list_stalls_sec' AS free_list_stalls_sec,
    j.value ->> 'lazy_writes_sec' AS lazy_writes_sec,
    j.value ->> 'ple_seconds' AS ple_seconds,
    j.value ->> 'query_fragment' AS query_fragment,
    j.value ->> 'top_operator' AS top_operator,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-003-RC13';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc14 AS
SELECT
    r.server,
    j.value ->> 'active_queries' AS active_queries,
    j.value ->> 'granted_memory_kb' AS granted_memory_kb,
    j.value ->> 'grants_outstanding' AS grants_outstanding,
    j.value ->> 'grants_pending' AS grants_pending,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'ideal_memory_kb' AS ideal_memory_kb,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'query_cost' AS query_cost,
    j.value ->> 'query_text' AS query_text,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'total_granted_memory_mb' AS total_granted_memory_mb,
    j.value ->> 'used_memory_kb' AS used_memory_kb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-003-RC14';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc15 AS
SELECT
    r.server,
    j.value ->> 'page_lookups_sec' AS page_lookups_sec,
    j.value ->> 'page_reads_sec' AS page_reads_sec,
    j.value ->> 'ple_seconds' AS ple_seconds,
    j.value ->> 'readahead_pages_sec' AS readahead_pages_sec,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-003-RC15';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_003_rc16 AS
SELECT
    r.server,
    j.value ->> 'avg_pageio_latch_ms' AS avg_pageio_latch_ms,
    j.value ->> 'ple_seconds' AS ple_seconds,
    j.value ->> 'sessions_waiting_on_io' AS sessions_waiting_on_io,
    j.value ->> 'stolen_pages' AS stolen_pages,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-003-RC16';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_004_rc01 AS
SELECT
    r.server,
    j.value ->> 'actual_rows' AS actual_rows,
    j.value ->> 'avg_spills' AS avg_spills,
    j.value ->> 'avg_unused_grant_kb' AS avg_unused_grant_kb,
    j.value ->> 'estimated_rows' AS estimated_rows,
    j.value ->> 'estimation_ratio' AS estimation_ratio,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'internal_alloc_mb' AS internal_alloc_mb,
    j.value ->> 'query_fragment' AS query_fragment,
    j.value ->> 'temp_table_creation_rate' AS temp_table_creation_rate,
    j.value ->> 'total_grant_kb' AS total_grant_kb,
    j.value ->> 'total_internal_alloc_pages' AS total_internal_alloc_pages,
    j.value ->> 'total_spills' AS total_spills,
    j.value ->> 'total_used_grant_kb' AS total_used_grant_kb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-004-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_004_rc02 AS
SELECT
    r.server,
    j.value ->> 'last_updated' AS last_updated,
    j.value ->> 'modification_counter' AS modification_counter,
    j.value ->> 'modification_pct' AS modification_pct,
    j.value ->> 'rows' AS rows,
    j.value ->> 'rows_sampled' AS rows_sampled,
    j.value ->> 'schema_name' AS schema_name,
    j.value ->> 'stat_name' AS stat_name,
    j.value ->> 'table_name' AS table_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-004-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_004_rc03 AS
SELECT
    r.server,
    j.value ->> 'actual_rows' AS actual_rows,
    j.value ->> 'avg_spills' AS avg_spills,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'max_rows' AS max_rows,
    j.value ->> 'min_rows' AS min_rows,
    j.value ->> 'query_fragment' AS query_fragment,
    j.value ->> 'row_count_variance' AS row_count_variance,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-004-RC03';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_004_rc04 AS
SELECT
    r.server,
    j.value ->> 'avg_spills' AS avg_spills,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'last_grant_kb' AS last_grant_kb,
    j.value ->> 'max_grant_kb' AS max_grant_kb,
    j.value ->> 'max_used_grant_kb' AS max_used_grant_kb,
    j.value ->> 'min_grant_kb' AS min_grant_kb,
    j.value ->> 'min_used_grant_kb' AS min_used_grant_kb,
    j.value ->> 'query_fragment' AS query_fragment,
    j.value ->> 'total_spills' AS total_spills,
    j.value ->> 'used_grant_variance' AS used_grant_variance,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-004-RC04';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_004_rc05 AS
SELECT
    r.server,
    j.value ->> 'avg_grant_kb' AS avg_grant_kb,
    j.value ->> 'avg_spills' AS avg_spills,
    j.value ->> 'avg_used_grant_kb' AS avg_used_grant_kb,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'grant_utilization_pct' AS grant_utilization_pct,
    j.value ->> 'hash_operators' AS hash_operators,
    j.value ->> 'query_fragment' AS query_fragment,
    j.value ->> 'sort_est_row_size' AS sort_est_row_size,
    j.value ->> 'sort_operators' AS sort_operators,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-004-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_004_rc06 AS
SELECT
    r.server,
    j.value ->> 'avg_logical_reads' AS avg_logical_reads,
    j.value ->> 'avg_spills' AS avg_spills,
    j.value ->> 'convert_expression' AS convert_expression,
    j.value ->> 'convert_implicit_count' AS convert_implicit_count,
    j.value ->> 'convert_issue' AS convert_issue,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'implicit_conversion_warnings' AS implicit_conversion_warnings,
    j.value ->> 'query_fragment' AS query_fragment,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-004-RC06';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_mem_004_rc07 AS
SELECT
    r.server,
    j.value ->> 'avg_grant_kb' AS avg_grant_kb,
    j.value ->> 'avg_logical_reads' AS avg_logical_reads,
    j.value ->> 'avg_spills' AS avg_spills,
    j.value ->> 'compute_scalar_count' AS compute_scalar_count,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'non_sargable_pattern' AS non_sargable_pattern,
    j.value ->> 'query_fragment' AS query_fragment,
    j.value ->> 'scan_count' AS scan_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-MEM-004-RC07';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_001_rc01 AS
SELECT
    r.server,
    j.value ->> 'current_maxdop' AS current_maxdop,
    j.value ->> 'hyperthread_ratio' AS hyperthread_ratio,
    j.value ->> 'logical_cpus' AS logical_cpus,
    j.value ->> 'maxdop_configured' AS maxdop_configured,
    j.value ->> 'maxdop_setting' AS maxdop_setting,
    j.value ->> 'name' AS name,
    j.value ->> 'numa_nodes' AS numa_nodes,
    j.value ->> 'physical_cores' AS physical_cores,
    j.value ->> 'recommended_maxdop' AS recommended_maxdop,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-PL-001-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_001_rc02 AS
SELECT
    r.server,
    j.value ->> 'configured_value' AS configured_value,
    j.value ->> 'name' AS name,
    j.value ->> 'value_in_use' AS value_in_use,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-PL-001-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_001_rc04 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'cpu_usage_pct' AS cpu_usage_pct,
    j.value ->> 'hyperthread_ratio' AS hyperthread_ratio,
    j.value ->> 'logical_cpus' AS logical_cpus,
    j.value ->> 'online_schedulers' AS online_schedulers,
    j.value ->> 'pct_of_total' AS pct_of_total,
    j.value ->> 'scheduler_count' AS scheduler_count,
    j.value ->> 'signal_wait_pct' AS signal_wait_pct,
    j.value ->> 'total_signal_wait_ms' AS total_signal_wait_ms,
    j.value ->> 'total_wait_ms' AS total_wait_ms,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-PL-001-RC04';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_001_rc05 AS
SELECT
    r.server,
    j.value ->> 'avg_read_stall_ms' AS avg_read_stall_ms,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'avg_write_stall_ms' AS avg_write_stall_ms,
    j.value ->> 'db_name' AS db_name,
    j.value ->> 'num_of_reads' AS num_of_reads,
    j.value ->> 'num_of_writes' AS num_of_writes,
    j.value ->> 'pct_of_total' AS pct_of_total,
    j.value ->> 'physical_name' AS physical_name,
    j.value ->> 'total_io_stall_ms' AS total_io_stall_ms,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-PL-001-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_001_rc06 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'pct_of_total' AS pct_of_total,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-PL-001-RC06';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_001_rc08 AS
SELECT
    r.server,
    j.value ->> 'active_requests' AS active_requests,
    j.value ->> 'max_workers' AS max_workers,
    j.value ->> 'thread_status' AS thread_status,
    j.value ->> 'total_threads' AS total_threads,
    j.value ->> 'total_workers' AS total_workers,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-PL-001-RC08';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_001_rc09 AS
SELECT
    r.server,
    j.value ->> 'objtype' AS objtype,
    j.value ->> 'plan_cache_mb' AS plan_cache_mb,
    j.value ->> 'plan_count' AS plan_count,
    j.value ->> 'single_use_mb' AS single_use_mb,
    j.value ->> 'single_use_parallel_plans' AS single_use_parallel_plans,
    j.value ->> 'single_use_pct' AS single_use_pct,
    j.value ->> 'single_use_plans' AS single_use_plans,
    j.value ->> 'total_size_mb' AS total_size_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-PL-001-RC09';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_001_rc10 AS
SELECT
    r.server,
    j.value ->> 'avg_dop' AS avg_dop,
    j.value ->> 'avg_threadpool_wait_ms' AS avg_threadpool_wait_ms,
    j.value ->> 'concurrent_parallel_queries' AS concurrent_parallel_queries,
    j.value ->> 'max_dop' AS max_dop,
    j.value ->> 'max_workers' AS max_workers,
    j.value ->> 'max_workers_count' AS max_workers_count,
    j.value ->> 'running_workers' AS running_workers,
    j.value ->> 'suspended_workers' AS suspended_workers,
    j.value ->> 'threadpool_wait_count' AS threadpool_wait_count,
    j.value ->> 'threadpool_wait_ms' AS threadpool_wait_ms,
    j.value ->> 'total_parallel_workers' AS total_parallel_workers,
    j.value ->> 'total_workers' AS total_workers,
    j.value ->> 'workers_used_pct' AS workers_used_pct,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-PL-001-RC10';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_002_rc01 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-PL-002-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_002_rc02 AS
SELECT
    r.server,
    j.value ->> 'partition_count' AS partition_count,
    j.value ->> 'partition_number' AS partition_number,
    j.value ->> 'partition_scheme' AS partition_scheme,
    j.value ->> 'pct_of_total' AS pct_of_total,
    j.value ->> 'rows' AS rows,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'total_rows' AS total_rows,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-PL-002-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_002_rc06 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-PL-002-RC06';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_002_rc09 AS
SELECT
    r.server,
    j.value ->> 'active_workers_count' AS active_workers_count,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'cpu_id' AS cpu_id,
    j.value ->> 'current_tasks_count' AS current_tasks_count,
    j.value ->> 'pending_disk_io_count' AS pending_disk_io_count,
    j.value ->> 'runnable_tasks_count' AS runnable_tasks_count,
    j.value ->> 'scheduler_id' AS scheduler_id,
    j.value ->> 'scheduler_state' AS scheduler_state,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    j.value ->> 'work_queue_count' AS work_queue_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-PL-002-RC09';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_003_rc01 AS
SELECT
    r.server,
    j.value ->> 'active_workers' AS active_workers,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'current_workers' AS current_workers,
    j.value ->> 'max_worker_threads' AS max_worker_threads,
    j.value ->> 'preemptive_workers' AS preemptive_workers,
    j.value ->> 'processes_blocked' AS processes_blocked,
    j.value ->> 'queued_requests' AS queued_requests,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-PL-003-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_003_rc03 AS
SELECT
    r.server,
    j.value ->> 'blocked_request_count' AS blocked_request_count,
    j.value ->> 'max_workers' AS max_workers,
    j.value ->> 'pct_workers_blocked' AS pct_workers_blocked,
    j.value ->> 'queued_requests' AS queued_requests,
    j.value ->> 'total_workers' AS total_workers,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-PL-003-RC03';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_003_rc04 AS
SELECT
    r.server,
    j.value ->> 'active_user_sessions' AS active_user_sessions,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'connection_resets_per_sec' AS connection_resets_per_sec,
    j.value ->> 'logins_per_sec' AS logins_per_sec,
    j.value ->> 'logouts_per_sec' AS logouts_per_sec,
    j.value ->> 'max_workers' AS max_workers,
    j.value ->> 'user_connections' AS user_connections,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-PL-003-RC04';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_003_rc05 AS
SELECT
    r.server,
    j.value ->> 'avg_io_wait_ms' AS avg_io_wait_ms,
    j.value ->> 'buffer_pool_mb' AS buffer_pool_mb,
    j.value ->> 'grants_pending' AS grants_pending,
    j.value ->> 'max_workers' AS max_workers,
    j.value ->> 'ple_seconds' AS ple_seconds,
    j.value ->> 'queued_requests' AS queued_requests,
    j.value ->> 'server_memory_mb' AS server_memory_mb,
    j.value ->> 'target_memory_mb' AS target_memory_mb,
    j.value ->> 'threads_waiting_on_io' AS threads_waiting_on_io,
    j.value ->> 'total_workers' AS total_workers,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-PL-003-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_003_rc06 AS
SELECT
    r.server,
    j.value ->> 'long_running_queries' AS long_running_queries,
    j.value ->> 'max_workers' AS max_workers,
    j.value ->> 'pct_workers_orphaned' AS pct_workers_orphaned,
    j.value ->> 'queued_requests' AS queued_requests,
    j.value ->> 'total_workers' AS total_workers,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-PL-003-RC06';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_003_rc07 AS
SELECT
    r.server,
    j.value ->> 'avg_exclusive_lock_wait_ms' AS avg_exclusive_lock_wait_ms,
    j.value ->> 'deadlock_count' AS deadlock_count,
    j.value ->> 'earliest_deadlock' AS earliest_deadlock,
    j.value ->> 'latest_deadlock' AS latest_deadlock,
    j.value ->> 'max_workers' AS max_workers,
    j.value ->> 'queued_requests' AS queued_requests,
    j.value ->> 'threads_waiting_on_locks' AS threads_waiting_on_locks,
    j.value ->> 'total_workers' AS total_workers,
    j.value ->> 'total_x_lock_wait_ms' AS total_x_lock_wait_ms,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-PL-003-RC07';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_003_rc08 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'overallocated_schedulers' AS overallocated_schedulers,
    j.value ->> 'preemptive_workers' AS preemptive_workers,
    j.value ->> 'suspended_workers' AS suspended_workers,
    j.value ->> 'total_context_switches' AS total_context_switches,
    j.value ->> 'total_yields' AS total_yields,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-PL-003-RC08';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_004_rc01 AS
SELECT
    r.server,
    j.value ->> 'grants_outstanding' AS grants_outstanding,
    j.value ->> 'grants_pending' AS grants_pending,
    j.value ->> 'internal_objects_mb' AS internal_objects_mb,
    j.value ->> 'server_memory_mb' AS server_memory_mb,
    j.value ->> 'total_granted_mb' AS total_granted_mb,
    j.value ->> 'total_ideal_mb' AS total_ideal_mb,
    j.value ->> 'total_requested_mb' AS total_requested_mb,
    j.value ->> 'user_objects_mb' AS user_objects_mb,
    j.value ->> 'version_store_mb' AS version_store_mb,
    j.value ->> 'waiting_for_grant' AS waiting_for_grant,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-PL-004-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_004_rc03 AS
SELECT
    r.server,
    j.value ->> 'avg_cxpacket_ms' AS avg_cxpacket_ms,
    j.value ->> 'cxpacket_count' AS cxpacket_count,
    j.value ->> 'cxpacket_wait_ms' AS cxpacket_wait_ms,
    j.value ->> 'tempdb_spill_mb' AS tempdb_spill_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-PL-004-RC03';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_004_rc05 AS
SELECT
    r.server,
    j.value ->> 'avg_read_latency_ms' AS avg_read_latency_ms,
    j.value ->> 'avg_write_latency_ms' AS avg_write_latency_ms,
    j.value ->> 'io_stall_read_ms' AS io_stall_read_ms,
    j.value ->> 'io_stall_write_ms' AS io_stall_write_ms,
    j.value ->> 'num_of_reads' AS num_of_reads,
    j.value ->> 'num_of_writes' AS num_of_writes,
    j.value ->> 'physical_name' AS physical_name,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-PL-004-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_004_rc07 AS
SELECT
    r.server,
    j.value ->> 'grants_outstanding' AS grants_outstanding,
    j.value ->> 'grants_pending' AS grants_pending,
    j.value ->> 'query_exec_reserved_kb' AS query_exec_reserved_kb,
    j.value ->> 'target_server_kb' AS target_server_kb,
    j.value ->> 'total_server_kb' AS total_server_kb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-PL-004-RC07';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_pl_004_rc08 AS
SELECT
    r.server,
    j.value ->> 'cpu_count' AS cpu_count,
    j.value ->> 'pageiolatch_wait_ms' AS pageiolatch_wait_ms,
    j.value ->> 'pageiolatch_waits' AS pageiolatch_waits,
    j.value ->> 'pagelatch_wait_ms' AS pagelatch_wait_ms,
    j.value ->> 'pagelatch_waits' AS pagelatch_waits,
    j.value ->> 'tempdb_data_files' AS tempdb_data_files,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-PL-004-RC08';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_001_rc02 AS
SELECT
    r.server,
    j.value ->> 'auto_created' AS auto_created,
    j.value ->> 'days_since_update' AS days_since_update,
    j.value ->> 'last_updated' AS last_updated,
    j.value ->> 'mod_pct' AS mod_pct,
    j.value ->> 'modification_counter' AS modification_counter,
    j.value ->> 'rows_sampled' AS rows_sampled,
    j.value ->> 'sample_pct' AS sample_pct,
    j.value ->> 'stat_name' AS stat_name,
    j.value ->> 'stat_rows' AS stat_rows,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'user_created' AS user_created,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-001-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_001_rc03 AS
SELECT
    r.server,
    j.value ->> 'avg_read_latency_ms' AS avg_read_latency_ms,
    j.value ->> 'avg_signal_wait_ms' AS avg_signal_wait_ms,
    j.value ->> 'avg_write_latency_ms' AS avg_write_latency_ms,
    j.value ->> 'batch_requests_sec' AS batch_requests_sec,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'grants_pending' AS grants_pending,
    j.value ->> 'num_of_reads' AS num_of_reads,
    j.value ->> 'num_of_writes' AS num_of_writes,
    j.value ->> 'physical_name' AS physical_name,
    j.value ->> 'ple_seconds' AS ple_seconds,
    j.value ->> 'signal_wait_pct' AS signal_wait_pct,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-001-RC03';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_001_rc04 AS
SELECT
    r.server,
    j.value ->> 'avg_cpu_us' AS avg_cpu_us,
    j.value ->> 'avg_elapsed_us' AS avg_elapsed_us,
    j.value ->> 'avg_logical_reads' AS avg_logical_reads,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'query_text' AS query_text,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-001-RC04';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_001_rc08 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'max_wait_time_ms' AS max_wait_time_ms,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-001-RC08';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_001_rc12 AS
SELECT
    r.server,
    j.value ->> 'compilations_sec' AS compilations_sec,
    j.value ->> 'plan_cache_mb' AS plan_cache_mb,
    j.value ->> 'recompilations_sec' AS recompilations_sec,
    j.value ->> 'single_use_plans' AS single_use_plans,
    j.value ->> 'total_cached_plans' AS total_cached_plans,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-001-RC12';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_001_rc13 AS
SELECT
    r.server,
    j.value ->> 'assessment' AS assessment,
    j.value ->> 'compatibility_level' AS compatibility_level,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'is_auto_create_stats_on' AS is_auto_create_stats_on,
    j.value ->> 'is_auto_update_stats_async_on' AS is_auto_update_stats_async_on,
    j.value ->> 'is_auto_update_stats_on' AS is_auto_update_stats_on,
    j.value ->> 'is_parameterization_forced' AS is_parameterization_forced,
    j.value ->> 'is_read_committed_snapshot_on' AS is_read_committed_snapshot_on,
    j.value ->> 'page_verify_option_desc' AS page_verify_option_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-001-RC13';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_001_rc14 AS
SELECT
    r.server,
    j.value ->> 'cache_hit_ratio' AS cache_hit_ratio,
    j.value ->> 'cache_hit_ratio_base' AS cache_hit_ratio_base,
    j.value ->> 'lazy_writes_per_sec' AS lazy_writes_per_sec,
    j.value ->> 'page_reads_per_sec' AS page_reads_per_sec,
    j.value ->> 'ple_seconds' AS ple_seconds,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-001-RC14';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_002_rc09 AS
SELECT
    r.server,
    j.value ->> 'auto_created_stats' AS auto_created_stats,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'index_stats_only' AS index_stats_only,
    j.value ->> 'is_auto_create_stats_on' AS is_auto_create_stats_on,
    j.value ->> 'is_auto_update_stats_async_on' AS is_auto_update_stats_async_on,
    j.value ->> 'is_auto_update_stats_on' AS is_auto_update_stats_on,
    j.value ->> 'user_created_stats' AS user_created_stats,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-002-RC09';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_002_rc12 AS
SELECT
    r.server,
    j.value ->> 'index_name' AS index_name,
    j.value ->> 'index_status' AS index_status,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'table_rows' AS table_rows,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'user_scans' AS user_scans,
    j.value ->> 'user_seeks' AS user_seeks,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-002-RC12';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_003_rc01 AS
SELECT
    r.server,
    j.value ->> 'auto_created' AS auto_created,
    j.value ->> 'days_since_update' AS days_since_update,
    j.value ->> 'last_updated' AS last_updated,
    j.value ->> 'mod_pct' AS mod_pct,
    j.value ->> 'modification_counter' AS modification_counter,
    j.value ->> 'rows_sampled' AS rows_sampled,
    j.value ->> 'sample_pct' AS sample_pct,
    j.value ->> 'stat_name' AS stat_name,
    j.value ->> 'stat_rows' AS stat_rows,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'user_created' AS user_created,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-003-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_003_rc04 AS
SELECT
    r.server,
    j.value ->> 'cost_threshold_parallelism' AS cost_threshold_parallelism,
    j.value ->> 'maxdop' AS maxdop,
    j.value ->> 'recent_query_count' AS recent_query_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-003-RC04';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_003_rc06 AS
SELECT
    r.server,
    j.value ->> 'avg_elapsed' AS avg_elapsed,
    j.value ->> 'database_id' AS database_id,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'max_elapsed_time' AS max_elapsed_time,
    j.value ->> 'max_logical_reads' AS max_logical_reads,
    j.value ->> 'min_elapsed_time' AS min_elapsed_time,
    j.value ->> 'min_logical_reads' AS min_logical_reads,
    j.value ->> 'procedure_name' AS procedure_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-003-RC06';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_003_rc08 AS
SELECT
    r.server,
    j.value ->> 'auto_created' AS auto_created,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'is_auto_create_stats_on' AS is_auto_create_stats_on,
    j.value ->> 'is_auto_update_stats_async_on' AS is_auto_update_stats_async_on,
    j.value ->> 'is_auto_update_stats_on' AS is_auto_update_stats_on,
    j.value ->> 'last_updated' AS last_updated,
    j.value ->> 'modification_counter' AS modification_counter,
    j.value ->> 'pct_modified' AS pct_modified,
    j.value ->> 'rows_sampled' AS rows_sampled,
    j.value ->> 'schema_name' AS schema_name,
    j.value ->> 'stat_name' AS stat_name,
    j.value ->> 'stat_rows' AS stat_rows,
    j.value ->> 'table_name' AS table_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-003-RC08';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_003_rc09 AS
SELECT
    r.server,
    j.value ->> 'ce_model' AS ce_model,
    j.value ->> 'compatibility_level' AS compatibility_level,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'engine_major_version' AS engine_major_version,
    j.value ->> 'is_query_store_on' AS is_query_store_on,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-003-RC09';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_003_rc10 AS
SELECT
    r.server,
    j.value ->> 'forced_plan_count' AS forced_plan_count,
    j.value ->> 'hints' AS hints,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'name' AS name,
    j.value ->> 'plan_guide_id' AS plan_guide_id,
    j.value ->> 'scope_type_desc' AS scope_type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-003-RC10';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_003_rc11 AS
SELECT
    r.server,
    j.value ->> 'cost_threshold' AS cost_threshold,
    j.value ->> 'maxdop' AS maxdop,
    j.value ->> 'online_schedulers' AS online_schedulers,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-003-RC11';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_003_rc13 AS
SELECT
    r.server,
    j.value ->> 'avg_elapsed_ms' AS avg_elapsed_ms,
    j.value ->> 'avg_grant_kb' AS avg_grant_kb,
    j.value ->> 'avg_ideal_grant_kb' AS avg_ideal_grant_kb,
    j.value ->> 'avg_spills_per_exec' AS avg_spills_per_exec,
    j.value ->> 'avg_used_grant_kb' AS avg_used_grant_kb,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'free_mb' AS free_mb,
    j.value ->> 'internal_objects_mb' AS internal_objects_mb,
    j.value ->> 'query_fragment' AS query_fragment,
    j.value ->> 'total_spills' AS total_spills,
    j.value ->> 'user_objects_mb' AS user_objects_mb,
    j.value ->> 'version_store_mb' AS version_store_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-003-RC13';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_003_rc14 AS
SELECT
    r.server,
    j.value ->> 'auto_created' AS auto_created,
    j.value ->> 'column_count' AS column_count,
    j.value ->> 'columns' AS columns,
    j.value ->> 'schema_name' AS schema_name,
    j.value ->> 'stat_name' AS stat_name,
    j.value ->> 'table_name' AS table_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-003-RC14';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_003_rc15 AS
SELECT
    r.server,
    j.value ->> 'current_rows' AS current_rows,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'is_auto_update_stats_on' AS is_auto_update_stats_on,
    j.value ->> 'last_updated' AS last_updated,
    j.value ->> 'modification_counter' AS modification_counter,
    j.value ->> 'most_recent_write' AS most_recent_write,
    j.value ->> 'oldest_stale_stat' AS oldest_stale_stat,
    j.value ->> 'pct_modified' AS pct_modified,
    j.value ->> 'schema_name' AS schema_name,
    j.value ->> 'stat_name' AS stat_name,
    j.value ->> 'stat_rows' AS stat_rows,
    j.value ->> 'table_name' AS table_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-003-RC15';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_004_rc01 AS
SELECT
    r.server,
    j.value ->> 'avg_elapsed' AS avg_elapsed,
    j.value ->> 'database_id' AS database_id,
    j.value ->> 'elapsed_variance' AS elapsed_variance,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'max_elapsed_time' AS max_elapsed_time,
    j.value ->> 'min_elapsed_time' AS min_elapsed_time,
    j.value ->> 'procedure_name' AS procedure_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-004-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_004_rc05 AS
SELECT
    r.server,
    j.value ->> 'avg_grant_kb' AS avg_grant_kb,
    j.value ->> 'avg_ideal_grant_kb' AS avg_ideal_grant_kb,
    j.value ->> 'avg_spills' AS avg_spills,
    j.value ->> 'avg_used_grant_kb' AS avg_used_grant_kb,
    j.value ->> 'batch_mgf' AS batch_mgf,
    j.value ->> 'compatibility_level' AS compatibility_level,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'max_grant_kb' AS max_grant_kb,
    j.value ->> 'max_spills' AS max_spills,
    j.value ->> 'mgf_status' AS mgf_status,
    j.value ->> 'min_grant_kb' AS min_grant_kb,
    j.value ->> 'min_spills' AS min_spills,
    j.value ->> 'query_fragment' AS query_fragment,
    j.value ->> 'row_mgf' AS row_mgf,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-004-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_004_rc07 AS
SELECT
    r.server,
    j.value ->> 'avg_cpu_ms' AS avg_cpu_ms,
    j.value ->> 'avg_elapsed_ms' AS avg_elapsed_ms,
    j.value ->> 'avg_logical_reads' AS avg_logical_reads,
    j.value ->> 'est_rows' AS est_rows,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'plan_dop' AS plan_dop,
    j.value ->> 'query_fragment' AS query_fragment,
    j.value ->> 'subtree_cost' AS subtree_cost,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-004-RC07';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_004_rc08 AS
SELECT
    r.server,
    j.value ->> 'compatibility_level' AS compatibility_level,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'iqp_features' AS iqp_features,
    j.value ->> 'is_query_store_on' AS is_query_store_on,
    j.value ->> 'name' AS name,
    j.value ->> 'value' AS value,
    j.value ->> 'value_for_secondary' AS value_for_secondary,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-004-RC08';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_004_rc09 AS
SELECT
    r.server,
    j.value ->> 'avg_elapsed_ms' AS avg_elapsed_ms,
    j.value ->> 'avg_logical_reads' AS avg_logical_reads,
    j.value ->> 'cacheobjtype' AS cacheobjtype,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'objtype' AS objtype,
    j.value ->> 'plan_age_hours' AS plan_age_hours,
    j.value ->> 'plan_created' AS plan_created,
    j.value ->> 'proc_name' AS proc_name,
    j.value ->> 'query_fragment' AS query_fragment,
    j.value ->> 'size_in_bytes' AS size_in_bytes,
    j.value ->> 'usecounts' AS usecounts,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-004-RC09';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_004_rc10 AS
SELECT
    r.server,
    j.value ->> 'single_use_mb' AS single_use_mb,
    j.value ->> 'single_use_pct' AS single_use_pct,
    j.value ->> 'single_use_plans' AS single_use_plans,
    j.value ->> 'total_adhoc_mb' AS total_adhoc_mb,
    j.value ->> 'total_adhoc_plans' AS total_adhoc_plans,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-004-RC10';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_004_rc14 AS
SELECT
    r.server,
    j.value ->> 'objtype' AS objtype,
    j.value ->> 'plan_count' AS plan_count,
    j.value ->> 'single_use_count' AS single_use_count,
    j.value ->> 'single_use_pct' AS single_use_pct,
    j.value ->> 'total_mb' AS total_mb,
    j.value ->> 'total_uses' AS total_uses,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-004-RC14';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_005_rc13 AS
SELECT
    r.server,
    j.value ->> 'column_name' AS column_name,
    j.value ->> 'column_type' AS column_type,
    j.value ->> 'fractional_precision' AS fractional_precision,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'type_notes' AS type_notes,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-005-RC13';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_007_rc07 AS
SELECT
    r.server,
    j.value ->> 'last_updated' AS last_updated,
    j.value ->> 'mod_pct' AS mod_pct,
    j.value ->> 'modification_counter' AS modification_counter,
    j.value ->> 'rows' AS rows,
    j.value ->> 'rows_sampled' AS rows_sampled,
    j.value ->> 'stats_name' AS stats_name,
    j.value ->> 'table_name' AS table_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-007-RC07';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_008_rc01 AS
SELECT
    r.server,
    j.value ->> 'available_mb' AS available_mb,
    j.value ->> 'granted_mb' AS granted_mb,
    j.value ->> 'grantee_count' AS grantee_count,
    j.value ->> 'max_target_mb' AS max_target_mb,
    j.value ->> 'pool_id' AS pool_id,
    j.value ->> 'resource_semaphore_id' AS resource_semaphore_id,
    j.value ->> 'target_memory_mb' AS target_memory_mb,
    j.value ->> 'timeout_error_count' AS timeout_error_count,
    j.value ->> 'total_memory_mb' AS total_memory_mb,
    j.value ->> 'used_mb' AS used_mb,
    j.value ->> 'waiter_count' AS waiter_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-008-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_008_rc05 AS
SELECT
    r.server,
    j.value ->> 'active_parallel_thread_count' AS active_parallel_thread_count,
    j.value ->> 'max_request_grant_memory_kb' AS max_request_grant_memory_kb,
    j.value ->> 'pool_id' AS pool_id,
    j.value ->> 'total_reduced_memgrant_count' AS total_reduced_memgrant_count,
    j.value ->> 'total_request_count' AS total_request_count,
    j.value ->> 'workload_group' AS workload_group,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-008-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_qe_008_rc17 AS
SELECT
    r.server,
    j.value ->> 'current_rows' AS current_rows,
    j.value ->> 'days_since_update' AS days_since_update,
    j.value ->> 'last_updated' AS last_updated,
    j.value ->> 'modification_counter' AS modification_counter,
    j.value ->> 'modification_pct' AS modification_pct,
    j.value ->> 'rows_sampled' AS rows_sampled,
    j.value ->> 'stat_name' AS stat_name,
    j.value ->> 'stat_rows' AS stat_rows,
    j.value ->> 'table_name' AS table_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-QE-008-RC17';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_001_rc06 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'cntr_value' AS cntr_value,
    j.value ->> 'counter_name' AS counter_name,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-TX-001-RC06';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_001_rc09 AS
SELECT
    r.server,
    j.value ->> 'avg_wait_ms' AS avg_wait_ms,
    j.value ->> 'wait_time_ms' AS wait_time_ms,
    j.value ->> 'wait_type' AS wait_type,
    j.value ->> 'waiting_tasks_count' AS waiting_tasks_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-TX-001-RC09';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_002_rc01 AS
SELECT
    r.server,
    j.value ->> 'age_minutes' AS age_minutes,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'last_sql' AS last_sql,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'session_status' AS session_status,
    j.value ->> 'transaction_begin_time' AS transaction_begin_time,
    j.value ->> 'transaction_id' AS transaction_id,
    j.value ->> 'transaction_name' AS transaction_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-TX-002-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_002_rc02 AS
SELECT
    r.server,
    j.value ->> 'avg_log_write_ms' AS avg_log_write_ms,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'log_flushes_sec' AS log_flushes_sec,
    j.value ->> 'total_log_written_mb' AS total_log_written_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-TX-002-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_002_rc03 AS
SELECT
    r.server,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'last_log_backup' AS last_log_backup,
    j.value ->> 'log_reuse_wait_desc' AS log_reuse_wait_desc,
    j.value ->> 'log_used_mb' AS log_used_mb,
    j.value ->> 'log_used_pct' AS log_used_pct,
    j.value ->> 'minutes_since_log_backup' AS minutes_since_log_backup,
    j.value ->> 'recovery_model_desc' AS recovery_model_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-TX-002-RC03';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_002_rc09 AS
SELECT
    r.server,
    j.value ->> 'current_size_mb' AS current_size_mb,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'growth' AS growth,
    j.value ->> 'growth_desc' AS growth_desc,
    j.value ->> 'is_percent_growth' AS is_percent_growth,
    j.value ->> 'max_size' AS max_size,
    j.value ->> 'max_size_desc' AS max_size_desc,
    j.value ->> 'physical_name' AS physical_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-TX-002-RC09';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_004_rc01 AS
SELECT
    r.server,
    j.value ->> 'deadlock_pct_of_txn' AS deadlock_pct_of_txn,
    j.value ->> 'total_deadlocks' AS total_deadlocks,
    j.value ->> 'txn_per_sec' AS txn_per_sec,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-TX-004-RC01';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_004_rc02 AS
SELECT
    r.server,
    j.value ->> 'lock_wait_time_ms' AS lock_wait_time_ms,
    j.value ->> 'lock_waits_per_sec' AS lock_waits_per_sec,
    j.value ->> 'total_lock_timeouts' AS total_lock_timeouts,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-TX-004-RC02';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_004_rc04 AS
SELECT
    r.server,
    j.value ->> 'active_txn' AS active_txn,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'total_txn_per_sec' AS total_txn_per_sec,
    j.value ->> 'user_errors_per_sec' AS user_errors_per_sec,
    j.value ->> 'write_txn' AS write_txn,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-TX-004-RC04';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_004_rc05 AS
SELECT
    r.server,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'log_bytes_flushed_sec' AS log_bytes_flushed_sec,
    j.value ->> 'log_reuse_wait_desc' AS log_reuse_wait_desc,
    j.value ->> 'transactions_sec' AS transactions_sec,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-TX-004-RC05';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_004_rc07 AS
SELECT
    r.server,
    j.value ->> 'max_workers' AS max_workers,
    j.value ->> 'memory_low' AS memory_low,
    j.value ->> 'memory_state' AS memory_state,
    j.value ->> 'resource_semaphore_ms' AS resource_semaphore_ms,
    j.value ->> 'threadpool_ms' AS threadpool_ms,
    j.value ->> 'total_workers' AS total_workers,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-TX-004-RC07';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_004_rc09 AS
SELECT
    r.server,
    j.value ->> 'configured_value' AS configured_value,
    j.value ->> 'description' AS description,
    j.value ->> 'name' AS name,
    j.value ->> 'value_in_use' AS value_in_use,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-TX-004-RC09';

CREATE OR REPLACE VIEW monitoring.v_perf_sql_tx_004_rc11 AS
SELECT
    r.server,
    j.value ->> 'connection_resets_per_sec' AS connection_resets_per_sec,
    j.value ->> 'current_user_connections' AS current_user_connections,
    j.value ->> 'logins_per_sec' AS logins_per_sec,
    j.value ->> 'logouts_per_sec' AS logouts_per_sec,
    j.value ->> 'reset_pct_of_logins' AS reset_pct_of_logins,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'PERF-SQL-TX-004-RC11';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc01 AS
SELECT
    r.server,
    j.value ->> 'builtin_admin_enabled' AS builtin_admin_enabled,
    j.value ->> 'cross_db_chaining' AS cross_db_chaining,
    j.value ->> 'dac_remote_enabled' AS dac_remote_enabled,
    j.value ->> 'days_until_expiration' AS days_until_expiration,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'name' AS name,
    j.value ->> 'password_last_set' AS password_last_set,
    j.value ->> 'sa_not_renamed' AS sa_not_renamed,
    j.value ->> 'xp_cmdshell_enabled' AS xp_cmdshell_enabled,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-001-RC01';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc03 AS
SELECT
    r.server,
    j.value ->> 'client_net_address' AS client_net_address,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'is_admin_endpoint' AS is_admin_endpoint,
    j.value ->> 'is_dynamic_port' AS is_dynamic_port,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'login_time' AS login_time,
    j.value ->> 'name' AS name,
    j.value ->> 'port' AS port,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'protocol_desc' AS protocol_desc,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'state_desc' AS state_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-001-RC03';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc04 AS
SELECT
    r.server,
    j.value ->> 'active_audits' AS active_audits,
    j.value ->> 'builtin_admin_disabled' AS builtin_admin_disabled,
    j.value ->> 'cc_compliance' AS cc_compliance,
    j.value ->> 'clr_enabled' AS clr_enabled,
    j.value ->> 'cross_db_chaining' AS cross_db_chaining,
    j.value ->> 'db_mail_xps' AS db_mail_xps,
    j.value ->> 'default_trace' AS default_trace,
    j.value ->> 'ole_automation' AS ole_automation,
    j.value ->> 'sa_disabled' AS sa_disabled,
    j.value ->> 'sa_not_renamed' AS sa_not_renamed,
    j.value ->> 'xp_cmdshell' AS xp_cmdshell,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-001-RC04';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc05 AS
SELECT
    r.server,
    j.value ->> 'account_purpose' AS account_purpose,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'modify_date' AS modify_date,
    j.value ->> 'name' AS name,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-001-RC05';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc06 AS
SELECT
    r.server,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'modify_date' AS modify_date,
    j.value ->> 'name' AS name,
    j.value ->> 'password_last_set' AS password_last_set,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-001-RC06';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc07 AS
SELECT
    r.server,
    j.value ->> 'active_sa_sessions' AS active_sa_sessions,
    j.value ->> 'most_recent_sa_login' AS most_recent_sa_login,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-001-RC07';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc08 AS
SELECT
    r.server,
    j.value ->> 'enabled_external_logins' AS enabled_external_logins,
    j.value ->> 'enabled_sql_logins' AS enabled_sql_logins,
    j.value ->> 'enabled_windows_groups' AS enabled_windows_groups,
    j.value ->> 'enabled_windows_logins' AS enabled_windows_logins,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'name' AS name,
    j.value ->> 'password_age_days' AS password_age_days,
    j.value ->> 'password_last_set' AS password_last_set,
    j.value ->> 'sa_disabled' AS sa_disabled,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-001-RC08';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc09 AS
SELECT
    r.server,
    j.value ->> 'login_audit_specs' AS login_audit_specs,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-001-RC09';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc10 AS
SELECT
    r.server,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'name' AS name,
    j.value ->> 'password_last_set' AS password_last_set,
    j.value ->> 'total_server_roles' AS total_server_roles,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-001-RC10';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc11 AS
SELECT
    r.server,
    j.value ->> 'change_audit_specs' AS change_audit_specs,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'days_since_modified' AS days_since_modified,
    j.value ->> 'modify_date' AS modify_date,
    j.value ->> 'name' AS name,
    j.value ->> 'server_role_count' AS server_role_count,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-001-RC11';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_001_rc12 AS
SELECT
    r.server,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'days_until_expiration' AS days_until_expiration,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_sysadmin' AS is_sysadmin,
    j.value ->> 'last_session_time' AS last_session_time,
    j.value ->> 'modify_date' AS modify_date,
    j.value ->> 'name' AS name,
    j.value ->> 'password_last_set' AS password_last_set,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-001-RC12';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc01 AS
SELECT
    r.server,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_sysadmin' AS is_sysadmin,
    j.value ->> 'modify_date' AS modify_date,
    j.value ->> 'name' AS name,
    j.value ->> 'no_both' AS no_both,
    j.value ->> 'no_expiration' AS no_expiration,
    j.value ->> 'no_policy' AS no_policy,
    j.value ->> 'password_last_set' AS password_last_set,
    j.value ->> 'pct_no_policy' AS pct_no_policy,
    j.value ->> 'total_sql_logins' AS total_sql_logins,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-003-RC01';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc02 AS
SELECT
    r.server,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'is_123456' AS is_123456,
    j.value ->> 'is_admin' AS is_admin,
    j.value ->> 'is_blank' AS is_blank,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_Passw0rd' AS is_Passw0rd,
    j.value ->> 'is_password' AS is_password,
    j.value ->> 'is_Password1' AS is_Password1,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_sa' AS is_sa,
    j.value ->> 'is_same_as_login' AS is_same_as_login,
    j.value ->> 'is_securityadmin' AS is_securityadmin,
    j.value ->> 'is_sysadmin' AS is_sysadmin,
    j.value ->> 'modify_date' AS modify_date,
    j.value ->> 'name' AS name,
    j.value ->> 'password_last_set' AS password_last_set,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-003-RC02';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc04 AS
SELECT
    r.server,
    j.value ->> 'fully_enforced' AS fully_enforced,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_sysadmin' AS is_sysadmin,
    j.value ->> 'name' AS name,
    j.value ->> 'no_policy' AS no_policy,
    j.value ->> 'password_age_days' AS password_age_days,
    j.value ->> 'password_last_set' AS password_last_set,
    j.value ->> 'policy_only' AS policy_only,
    j.value ->> 'total_sql_logins' AS total_sql_logins,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-003-RC04';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc05 AS
SELECT
    r.server,
    j.value ->> 'is_blank' AS is_blank,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'is_same_as_login' AS is_same_as_login,
    j.value ->> 'login_name_length' AS login_name_length,
    j.value ->> 'name' AS name,
    j.value ->> 'password_last_set' AS password_last_set,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-003-RC05';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc06 AS
SELECT
    r.server,
    j.value ->> 'active_sessions' AS active_sessions,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'logins_per_sec' AS logins_per_sec,
    j.value ->> 'name' AS name,
    j.value ->> 'no_policy_count' AS no_policy_count,
    j.value ->> 'pct_no_policy' AS pct_no_policy,
    j.value ->> 'total_sql_logins' AS total_sql_logins,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-003-RC06';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc07 AS
SELECT
    r.server,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'name' AS name,
    j.value ->> 'password_age_days' AS password_age_days,
    j.value ->> 'password_last_set' AS password_last_set,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-003-RC07';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc08 AS
SELECT
    r.server,
    j.value ->> 'is_blank' AS is_blank,
    j.value ->> 'is_common_complex_password' AS is_common_complex_password,
    j.value ->> 'is_common_dev_password' AS is_common_dev_password,
    j.value ->> 'is_common_password' AS is_common_password,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'matches_login_name' AS matches_login_name,
    j.value ->> 'name' AS name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-003-RC08';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc09 AS
SELECT
    r.server,
    j.value ->> 'expiration_enforced_count' AS expiration_enforced_count,
    j.value ->> 'expiration_not_enforced_count' AS expiration_not_enforced_count,
    j.value ->> 'pct_without_policy' AS pct_without_policy,
    j.value ->> 'policy_enforced_count' AS policy_enforced_count,
    j.value ->> 'policy_not_enforced_count' AS policy_not_enforced_count,
    j.value ->> 'total_sql_logins' AS total_sql_logins,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-003-RC09';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc10 AS
SELECT
    r.server,
    j.value ->> 'is_blank' AS is_blank,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'matches_login_name' AS matches_login_name,
    j.value ->> 'name' AS name,
    j.value ->> 'password_last_set' AS password_last_set,
    j.value ->> 'pwd_Admin123' AS pwd_Admin123,
    j.value ->> 'pwd_changeme' AS pwd_changeme,
    j.value ->> 'pwd_Pass1234' AS pwd_Pass1234,
    j.value ->> 'pwd_Passw0rd' AS pwd_Passw0rd,
    j.value ->> 'pwd_password' AS pwd_password,
    j.value ->> 'pwd_Password1' AS pwd_Password1,
    j.value ->> 'pwd_Sql2016' AS pwd_Sql2016,
    j.value ->> 'pwd_Welcome1' AS pwd_Welcome1,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-003-RC10';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc11 AS
SELECT
    r.server,
    j.value ->> 'active_audit_specs' AS active_audit_specs,
    j.value ->> 'active_audits' AS active_audits,
    j.value ->> 'login_audit_actions' AS login_audit_actions,
    j.value ->> 'windows_auth_only' AS windows_auth_only,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-003-RC11';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc12 AS
SELECT
    r.server,
    j.value ->> 'avg_password_age_days' AS avg_password_age_days,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'login_count' AS login_count,
    j.value ->> 'logins' AS logins,
    j.value ->> 'max_password_age_days' AS max_password_age_days,
    j.value ->> 'min_password_age_days' AS min_password_age_days,
    j.value ->> 'stdev_password_age_days' AS stdev_password_age_days,
    j.value ->> 'total_logins' AS total_logins,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-003-RC12';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_003_rc13 AS
SELECT
    r.server,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'modify_date' AS modify_date,
    j.value ->> 'name' AS name,
    j.value ->> 'password_last_set' AS password_last_set,
    j.value ->> 'secs_between_create_and_pwdset' AS secs_between_create_and_pwdset,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-003-RC13';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_004_rc03 AS
SELECT
    r.server,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'login_type' AS login_type,
    j.value ->> 'role_level' AS role_level,
    j.value ->> 'service_account' AS service_account,
    j.value ->> 'servicename' AS servicename,
    j.value ->> 'startup_type_desc' AS startup_type_desc,
    j.value ->> 'status_desc' AS status_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-004-RC03';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_004_rc04 AS
SELECT
    r.server,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'default_database_name' AS default_database_name,
    j.value ->> 'domain_name' AS domain_name,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'is_sysadmin' AS is_sysadmin,
    j.value ->> 'name' AS name,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-004-RC04';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_004_rc06 AS
SELECT
    r.server,
    j.value ->> 'auth_scheme' AS auth_scheme,
    j.value ->> 'distinct_logins' AS distinct_logins,
    j.value ->> 'encrypt_option' AS encrypt_option,
    j.value ->> 'session_count' AS session_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-004-RC06';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_004_rc07 AS
SELECT
    r.server,
    j.value ->> 'domain_name' AS domain_name,
    j.value ->> 'enabled_count' AS enabled_count,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'is_securityadmin' AS is_securityadmin,
    j.value ->> 'is_sysadmin' AS is_sysadmin,
    j.value ->> 'last_session' AS last_session,
    j.value ->> 'login_count' AS login_count,
    j.value ->> 'name' AS name,
    j.value ->> 'sysadmin_count' AS sysadmin_count,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-004-RC07';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_004_rc10 AS
SELECT
    r.server,
    j.value ->> 'auth_scheme' AS auth_scheme,
    j.value ->> 'client_net_address' AS client_net_address,
    j.value ->> 'distinct_logins' AS distinct_logins,
    j.value ->> 'encrypt_option' AS encrypt_option,
    j.value ->> 'session_count' AS session_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-004-RC10';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_004_rc12 AS
SELECT
    r.server,
    j.value ->> 'default_trace_on' AS default_trace_on,
    j.value ->> 'default_trace_status' AS default_trace_status,
    j.value ->> 'login_audit_actions' AS login_audit_actions,
    j.value ->> 'windows_logins' AS windows_logins,
    j.value ->> 'xe_login_sessions' AS xe_login_sessions,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-004-RC12';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc01 AS
SELECT
    r.server,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'last_login' AS last_login,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_count' AS session_count,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-005-RC01';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc03 AS
SELECT
    r.server,
    j.value ->> 'active_sessions' AS active_sessions,
    j.value ->> 'possible_windows_equivalent' AS possible_windows_equivalent,
    j.value ->> 'sql_created' AS sql_created,
    j.value ->> 'sql_disabled' AS sql_disabled,
    j.value ->> 'sql_login' AS sql_login,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-005-RC03';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc04 AS
SELECT
    r.server,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'days_since_modified' AS days_since_modified,
    j.value ->> 'last_session' AS last_session,
    j.value ->> 'modify_date' AS modify_date,
    j.value ->> 'password_last_set' AS password_last_set,
    j.value ->> 'sql_login' AS sql_login,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-005-RC04';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc05 AS
SELECT
    r.server,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'last_session' AS last_session,
    j.value ->> 'name' AS name,
    j.value ->> 'password_last_set' AS password_last_set,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'windows_login_count' AS windows_login_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-005-RC05';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc06 AS
SELECT
    r.server,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'dev_tool_sessions' AS dev_tool_sessions,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'name' AS name,
    j.value ->> 'total_sessions' AS total_sessions,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-005-RC06';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc09 AS
SELECT
    r.server,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'name' AS name,
    j.value ->> 'password_last_set' AS password_last_set,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-005-RC09';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc10 AS
SELECT
    r.server,
    j.value ->> 'distinct_hosts' AS distinct_hosts,
    j.value ->> 'host_names' AS host_names,
    j.value ->> 'name' AS name,
    j.value ->> 'total_sessions' AS total_sessions,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-005-RC10';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc11 AS
SELECT
    r.server,
    j.value ->> 'auth_scheme' AS auth_scheme,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'distinct_logins' AS distinct_logins,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-005-RC11';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc12 AS
SELECT
    r.server,
    j.value ->> 'pct_sql_auth' AS pct_sql_auth,
    j.value ->> 'sql_auth_sessions' AS sql_auth_sessions,
    j.value ->> 'total_sessions' AS total_sessions,
    j.value ->> 'windows_auth_sessions' AS windows_auth_sessions,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-005-RC12';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_005_rc13 AS
SELECT
    r.server,
    j.value ->> 'active_audits' AS active_audits,
    j.value ->> 'login_audit_actions' AS login_audit_actions,
    j.value ->> 'recent_sql_logins' AS recent_sql_logins,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-005-RC13';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_006_rc01 AS
SELECT
    r.server,
    j.value ->> 'active_audits' AS active_audits,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'days_since_modified' AS days_since_modified,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'last_session_time' AS last_session_time,
    j.value ->> 'login_tracking_actions' AS login_tracking_actions,
    j.value ->> 'modify_date' AS modify_date,
    j.value ->> 'name' AS name,
    j.value ->> 'password_last_set' AS password_last_set,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'windows_auth_only' AS windows_auth_only,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-006-RC01';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_006_rc02 AS
SELECT
    r.server,
    j.value ->> 'account_age_days' AS account_age_days,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'last_session_time' AS last_session_time,
    j.value ->> 'modify_date' AS modify_date,
    j.value ->> 'name' AS name,
    j.value ->> 'password_age_days' AS password_age_days,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-006-RC02';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_006_rc07 AS
SELECT
    r.server,
    j.value ->> 'account_category' AS account_category,
    j.value ->> 'active_sql_logins' AS active_sql_logins,
    j.value ->> 'active_windows_logins' AS active_windows_logins,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'disabled_logins' AS disabled_logins,
    j.value ->> 'enabled_logins' AS enabled_logins,
    j.value ->> 'enabled_no_session' AS enabled_no_session,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'last_session' AS last_session,
    j.value ->> 'name' AS name,
    j.value ->> 'newest_login_date' AS newest_login_date,
    j.value ->> 'oldest_login_date' AS oldest_login_date,
    j.value ->> 'total_logins' AS total_logins,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-006-RC07';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_006_rc09 AS
SELECT
    r.server,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'created_last_quarter' AS created_last_quarter,
    j.value ->> 'days_since_modified' AS days_since_modified,
    j.value ->> 'dormancy_tier' AS dormancy_tier,
    j.value ->> 'dormant_over_90_days' AS dormant_over_90_days,
    j.value ->> 'last_session' AS last_session,
    j.value ->> 'name' AS name,
    j.value ->> 'total_active_logins' AS total_active_logins,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-006-RC09';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_006_rc10 AS
SELECT
    r.server,
    j.value ->> 'distinct_hosts' AS distinct_hosts,
    j.value ->> 'earliest_session' AS earliest_session,
    j.value ->> 'latest_session' AS latest_session,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'original_login_name' AS original_login_name,
    j.value ->> 'privileged_roles' AS privileged_roles,
    j.value ->> 'programs' AS programs,
    j.value ->> 'server_role_ids' AS server_role_ids,
    j.value ->> 'total_sessions' AS total_sessions,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-006-RC10';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_006_rc11 AS
SELECT
    r.server,
    j.value ->> 'accessible_databases' AS accessible_databases,
    j.value ->> 'age_days' AS age_days,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'last_session' AS last_session,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'modify_date' AS modify_date,
    j.value ->> 'ownership_classification' AS ownership_classification,
    j.value ->> 'password_last_set' AS password_last_set,
    j.value ->> 'server_roles' AS server_roles,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-006-RC11';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_006_rc12 AS
SELECT
    r.server,
    j.value ->> 'active_audits' AS active_audits,
    j.value ->> 'login_audit_enabled' AS login_audit_enabled,
    j.value ->> 'login_audit_specs' AS login_audit_specs,
    j.value ->> 'xe_login_sessions' AS xe_login_sessions,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-006-RC12';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_006_rc14 AS
SELECT
    r.server,
    j.value ->> 'active_audits' AS active_audits,
    j.value ->> 'active_xe_sessions' AS active_xe_sessions,
    j.value ->> 'login_audit_level' AS login_audit_level,
    j.value ->> 'success_login_audit' AS success_login_audit,
    j.value ->> 'xe_login_tracking' AS xe_login_tracking,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-006-RC14';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_006_rc15 AS
SELECT
    r.server,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'logins_no_current_session' AS logins_no_current_session,
    j.value ->> 'logins_older_than_1yr' AS logins_older_than_1yr,
    j.value ->> 'logins_stale_password' AS logins_stale_password,
    j.value ->> 'role_membership' AS role_membership,
    j.value ->> 'total_active_logins' AS total_active_logins,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-006-RC15';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_007_rc05 AS
SELECT
    r.server,
    j.value ->> 'current_encrypt_option' AS current_encrypt_option,
    j.value ->> 'encrypted_connections' AS encrypted_connections,
    j.value ->> 'explicit_remote_logins' AS explicit_remote_logins,
    j.value ->> 'linked_server_count' AS linked_server_count,
    j.value ->> 'remote_access' AS remote_access,
    j.value ->> 'remote_dac' AS remote_dac,
    j.value ->> 'self_credential_links' AS self_credential_links,
    j.value ->> 'tcp_endpoints_non_default' AS tcp_endpoints_non_default,
    j.value ->> 'unencrypted_connections' AS unencrypted_connections,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-007-RC05';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_007_rc07 AS
SELECT
    r.server,
    j.value ->> 'config_modifying_jobs' AS config_modifying_jobs,
    j.value ->> 'current_value' AS current_value,
    j.value ->> 'hardened_value' AS hardened_value,
    j.value ->> 'name' AS name,
    j.value ->> 'pending_config_changes' AS pending_config_changes,
    j.value ->> 'recent_config_sql' AS recent_config_sql,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-007-RC07';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_007_rc09 AS
SELECT
    r.server,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'modify_date' AS modify_date,
    j.value ->> 'name' AS name,
    j.value ->> 'password_last_set' AS password_last_set,
    j.value ->> 'recent_sql_logins_created' AS recent_sql_logins_created,
    j.value ->> 'remote_dac_enabled' AS remote_dac_enabled,
    j.value ->> 'sa_disabled' AS sa_disabled,
    j.value ->> 'sa_last_modified' AS sa_last_modified,
    j.value ->> 'sa_password_last_set' AS sa_password_last_set,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-007-RC09';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_007_rc10 AS
SELECT
    r.server,
    j.value ->> 'auth_scheme' AS auth_scheme,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'privilege_level' AS privilege_level,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-007-RC10';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_007_rc12 AS
SELECT
    r.server,
    j.value ->> 'active_sysadmin_sql_logins' AS active_sysadmin_sql_logins,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'is_sysadmin' AS is_sysadmin,
    j.value ->> 'modify_date' AS modify_date,
    j.value ->> 'name' AS name,
    j.value ->> 'password_last_set' AS password_last_set,
    j.value ->> 'policy_enforced' AS policy_enforced,
    j.value ->> 'sa_disabled' AS sa_disabled,
    j.value ->> 'sa_exists' AS sa_exists,
    j.value ->> 'sa_modified' AS sa_modified,
    j.value ->> 'sa_password_last_set' AS sa_password_last_set,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-007-RC12';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_au_007_rc14 AS
SELECT
    r.server,
    j.value ->> 'active_policies' AS active_policies,
    j.value ->> 'policy_violations' AS policy_violations,
    j.value ->> 'security_policies' AS security_policies,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AU-007-RC14';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_001_rc02 AS
SELECT
    r.server,
    j.value ->> 'name' AS name,
    j.value ->> 'value' AS value,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AUD-001-RC02';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_001_rc03 AS
SELECT
    r.server,
    j.value ->> 'required_group' AS required_group,
    j.value ->> 'status' AS status,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AUD-001-RC03';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_001_rc04 AS
SELECT
    r.server,
    j.value ->> 'audit_count' AS audit_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AUD-001-RC04';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_001_rc08 AS
SELECT
    r.server,
    j.value ->> 'audit_count' AS audit_count,
    j.value ->> 'c2_audit' AS c2_audit,
    j.value ->> 'common_criteria' AS common_criteria,
    j.value ->> 'Data' AS Data,
    j.value ->> 'db_spec_count' AS db_spec_count,
    j.value ->> 'server_spec_count' AS server_spec_count,
    j.value ->> 'Value' AS Value,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AUD-001-RC08';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_002_rc05 AS
SELECT
    r.server,
    j.value ->> 'file_audit_count' AS file_audit_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AUD-002-RC05';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_002_rc10 AS
SELECT
    r.server,
    j.value ->> 'audit_control_perms' AS audit_control_perms,
    j.value ->> 'is_sysadmin' AS is_sysadmin,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'permission_name' AS permission_name,
    j.value ->> 'state_desc' AS state_desc,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AUD-002-RC10';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_003_rc01 AS
SELECT
    r.server,
    j.value ->> 'has_control_server' AS has_control_server,
    j.value ->> 'is_sysadmin' AS is_sysadmin,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AUD-003-RC01';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_003_rc02 AS
SELECT
    r.server,
    j.value ->> 'event_log_audits' AS event_log_audits,
    j.value ->> 'file_based_audits' AS file_based_audits,
    j.value ->> 'mutability_risk' AS mutability_risk,
    j.value ->> 'sysadmin_count' AS sysadmin_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AUD-003-RC02';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_003_rc03 AS
SELECT
    r.server,
    j.value ->> 'event_log_audits' AS event_log_audits,
    j.value ->> 'file_audits' AS file_audits,
    j.value ->> 'redundancy_status' AS redundancy_status,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AUD-003-RC03';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_003_rc04 AS
SELECT
    r.server,
    j.value ->> 'has_alter_audit' AS has_alter_audit,
    j.value ->> 'is_sysadmin' AS is_sysadmin,
    j.value ->> 'principal_id' AS principal_id,
    j.value ->> 'service_account' AS service_account,
    j.value ->> 'servicename' AS servicename,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AUD-003-RC04';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_003_rc07 AS
SELECT
    r.server,
    j.value ->> 'impersonate_grants' AS impersonate_grants,
    j.value ->> 'impersonation_audited' AS impersonation_audited,
    j.value ->> 'login_events_audited' AS login_events_audited,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AUD-003-RC07';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_003_rc08 AS
SELECT
    r.server,
    j.value ->> 'active_sa_sessions' AS active_sa_sessions,
    j.value ->> 'distinct_hosts' AS distinct_hosts,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'last_password_change' AS last_password_change,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'name' AS name,
    j.value ->> 'privileged_roles' AS privileged_roles,
    j.value ->> 'total_sessions' AS total_sessions,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AUD-003-RC08';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_003_rc09 AS
SELECT
    r.server,
    j.value ->> 'continue_on_failure' AS continue_on_failure,
    j.value ->> 'fail_op_on_failure' AS fail_op_on_failure,
    j.value ->> 'shutdown_on_failure' AS shutdown_on_failure,
    j.value ->> 'total_audits' AS total_audits,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AUD-003-RC09';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_004_rc01 AS
SELECT
    r.server,
    j.value ->> 'audit_level' AS audit_level,
    j.value ->> 'audit_level_desc' AS audit_level_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AUD-004-RC01';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_004_rc02 AS
SELECT
    r.server,
    j.value ->> 'audit_level' AS audit_level,
    j.value ->> 'failed_login_audited' AS failed_login_audited,
    j.value ->> 'status' AS status,
    j.value ->> 'success_login_audited' AS success_login_audited,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AUD-004-RC02';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_004_rc04 AS
SELECT
    r.server,
    j.value ->> 'active_audits' AS active_audits,
    j.value ->> 'active_db_specs' AS active_db_specs,
    j.value ->> 'active_server_specs' AS active_server_specs,
    j.value ->> 'audit_level' AS audit_level,
    j.value ->> 'registry_compensation' AS registry_compensation,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AUD-004-RC04';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_004_rc07 AS
SELECT
    r.server,
    j.value ->> 'audit_level' AS audit_level,
    j.value ->> 'registry_captures_failures' AS registry_captures_failures,
    j.value ->> 'sql_audit_captures_failures' AS sql_audit_captures_failures,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AUD-004-RC07';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_005_rc03 AS
SELECT
    r.server,
    j.value ->> 'audit_change_monitored' AS audit_change_monitored,
    j.value ->> 'is_sysadmin' AS is_sysadmin,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AUD-005-RC03';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_005_rc04 AS
SELECT
    r.server,
    j.value ->> 'ddl_change_groups' AS ddl_change_groups,
    j.value ->> 'dml_access_groups' AS dml_access_groups,
    j.value ->> 'server_change_groups' AS server_change_groups,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AUD-005-RC04';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_005_rc05 AS
SELECT
    r.server,
    j.value ->> 'principal_scoped_ddl_audit' AS principal_scoped_ddl_audit,
    j.value ->> 'server_wide_ddl_audit' AS server_wide_ddl_audit,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AUD-005-RC05';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_005_rc06 AS
SELECT
    r.server,
    j.value ->> 'current_temp_objects' AS current_temp_objects,
    j.value ->> 'server_ddl_audit' AS server_ddl_audit,
    j.value ->> 'temp_table_rate' AS temp_table_rate,
    j.value ->> 'tempdb_audit_specs' AS tempdb_audit_specs,
    j.value ->> 'tempdb_ddl_audit' AS tempdb_ddl_audit,
    j.value ->> 'user_objects_mb_in_tempdb' AS user_objects_mb_in_tempdb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AUD-005-RC06';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_005_rc07 AS
SELECT
    r.server,
    j.value ->> 'clr_enabled' AS clr_enabled,
    j.value ->> 'clr_strict_security' AS clr_strict_security,
    j.value ->> 'ddl_audit_enabled' AS ddl_audit_enabled,
    j.value ->> 'extended_procs' AS extended_procs,
    j.value ->> 'ole_automation_enabled' AS ole_automation_enabled,
    j.value ->> 'unsafe_assemblies' AS unsafe_assemblies,
    j.value ->> 'user_clr_assemblies' AS user_clr_assemblies,
    j.value ->> 'xp_cmdshell_enabled' AS xp_cmdshell_enabled,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AUD-005-RC07';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc01 AS
SELECT
    r.server,
    j.value ->> 'custom_roles' AS custom_roles,
    j.value ->> 'direct_user_grants' AS direct_user_grants,
    j.value ->> 'role_grants' AS role_grants,
    j.value ->> 'total_grants' AS total_grants,
    j.value ->> 'users_with_direct_grants' AS users_with_direct_grants,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-001-RC01';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc02 AS
SELECT
    r.server,
    j.value ->> 'active_sessions' AS active_sessions,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'server_roles' AS server_roles,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-001-RC02';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc03 AS
SELECT
    r.server,
    j.value ->> 'has_control_server' AS has_control_server,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'is_sysadmin' AS is_sysadmin,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-001-RC03';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc04 AS
SELECT
    r.server,
    j.value ->> 'command' AS command,
    j.value ->> 'current_sessions' AS current_sessions,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'non_admin_requests' AS non_admin_requests,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'request_count' AS request_count,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-001-RC04';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc06 AS
SELECT
    r.server,
    j.value ->> 'cross_db_chaining_enabled' AS cross_db_chaining_enabled,
    j.value ->> 'schemas_granted' AS schemas_granted,
    j.value ->> 'users_with_schema_grants' AS users_with_schema_grants,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-001-RC06';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc07 AS
SELECT
    r.server,
    j.value ->> 'commands_used' AS commands_used,
    j.value ->> 'distinct_commands' AS distinct_commands,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'is_sysadmin' AS is_sysadmin,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_count' AS session_count,
    j.value ->> 'total_requests' AS total_requests,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-001-RC07';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc08 AS
SELECT
    r.server,
    j.value ->> 'access_review_jobs' AS access_review_jobs,
    j.value ->> 'disabled_logins' AS disabled_logins,
    j.value ->> 'logins_no_current_session' AS logins_no_current_session,
    j.value ->> 'logins_unmodified_1yr' AS logins_unmodified_1yr,
    j.value ->> 'permission_audit_specs' AS permission_audit_specs,
    j.value ->> 'total_active_logins' AS total_active_logins,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-001-RC08';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc10 AS
SELECT
    r.server,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'default_schema_name' AS default_schema_name,
    j.value ->> 'is_db_owner' AS is_db_owner,
    j.value ->> 'owned_schemas' AS owned_schemas,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'user_name' AS user_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-001-RC10';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc11 AS
SELECT
    r.server,
    j.value ->> 'conflicting_grant_deny' AS conflicting_grant_deny,
    j.value ->> 'db_owner_with_deny' AS db_owner_with_deny,
    j.value ->> 'orphaned_users' AS orphaned_users,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-001-RC11';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc12 AS
SELECT
    r.server,
    j.value ->> 'current_value' AS current_value,
    j.value ->> 'hardened_value' AS hardened_value,
    j.value ->> 'name' AS name,
    j.value ->> 'status' AS status,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-001-RC12';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc13 AS
SELECT
    r.server,
    j.value ->> 'ad_groups' AS ad_groups,
    j.value ->> 'governance_status' AS governance_status,
    j.value ->> 'individual_windows_logins' AS individual_windows_logins,
    j.value ->> 'sql_logins' AS sql_logins,
    j.value ->> 'total_principals' AS total_principals,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-001-RC13';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_001_rc14 AS
SELECT
    r.server,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'last_session_time' AS last_session_time,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'modify_date' AS modify_date,
    j.value ->> 'role_name' AS role_name,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-001-RC14';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_002_rc04 AS
SELECT
    r.server,
    j.value ->> 'compat_version' AS compat_version,
    j.value ->> 'compatibility_level' AS compatibility_level,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'database_name' AS database_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-002-RC04';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_002_rc06 AS
SELECT
    r.server,
    j.value ->> 'class_desc' AS class_desc,
    j.value ->> 'object_name' AS object_name,
    j.value ->> 'permission_name' AS permission_name,
    j.value ->> 'schema_name' AS schema_name,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-002-RC06';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_002_rc08 AS
SELECT
    r.server,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'guest_enabled' AS guest_enabled,
    j.value ->> 'public_user_object_grants' AS public_user_object_grants,
    j.value ->> 'trustworthy_on' AS trustworthy_on,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-002-RC08';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_002_rc10 AS
SELECT
    r.server,
    j.value ->> 'custom_role_grants' AS custom_role_grants,
    j.value ->> 'custom_roles' AS custom_roles,
    j.value ->> 'public_user_grants' AS public_user_grants,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-002-RC10';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_002_rc11 AS
SELECT
    r.server,
    j.value ->> 'class_desc' AS class_desc,
    j.value ->> 'permission_count' AS permission_count,
    j.value ->> 'permission_name' AS permission_name,
    j.value ->> 'state_desc' AS state_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-002-RC11';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc04 AS
SELECT
    r.server,
    j.value ->> 'pct_sql_auth' AS pct_sql_auth,
    j.value ->> 'sql_logins' AS sql_logins,
    j.value ->> 'total_logins' AS total_logins,
    j.value ->> 'windows_groups' AS windows_groups,
    j.value ->> 'windows_logins' AS windows_logins,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-003-RC04';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc05 AS
SELECT
    r.server,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'days_since_created' AS days_since_created,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'last_session_time' AS last_session_time,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'modify_date' AS modify_date,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-003-RC05';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc07 AS
SELECT
    r.server,
    j.value ->> 'account_age_days' AS account_age_days,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'days_until_expiration' AS days_until_expiration,
    j.value ->> 'is_disabled' AS is_disabled,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'modify_date' AS modify_date,
    j.value ->> 'password_last_set' AS password_last_set,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-003-RC07';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc08 AS
SELECT
    r.server,
    j.value ->> 'distinct_hosts' AS distinct_hosts,
    j.value ->> 'distinct_programs' AS distinct_programs,
    j.value ->> 'host_list' AS host_list,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'total_sessions' AS total_sessions,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-003-RC08';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc11 AS
SELECT
    r.server,
    j.value ->> 'active_login_count' AS active_login_count,
    j.value ->> 'logins_per_database' AS logins_per_database,
    j.value ->> 'user_database_count' AS user_database_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-003-RC11';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc12 AS
SELECT
    r.server,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'modify_date' AS modify_date,
    j.value ->> 'password_last_set' AS password_last_set,
    j.value ->> 'role_membership' AS role_membership,
    j.value ->> 'server_role' AS server_role,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-003-RC12';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_003_rc15 AS
SELECT
    r.server,
    j.value ->> 'class_desc' AS class_desc,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'direct_grants' AS direct_grants,
    j.value ->> 'grantee_name' AS grantee_name,
    j.value ->> 'object_name' AS object_name,
    j.value ->> 'permission_name' AS permission_name,
    j.value ->> 'role_count' AS role_count,
    j.value ->> 'schema_name' AS schema_name,
    j.value ->> 'state_desc' AS state_desc,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'user_name' AS user_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-003-RC15';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc01 AS
SELECT
    r.server,
    j.value ->> 'description' AS description,
    j.value ->> 'is_enabled' AS is_enabled,
    j.value ->> 'name' AS name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-004-RC01';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc02 AS
SELECT
    r.server,
    j.value ->> 'clr_enabled' AS clr_enabled,
    j.value ->> 'ole_automation_enabled' AS ole_automation_enabled,
    j.value ->> 'safe_clr_assemblies' AS safe_clr_assemblies,
    j.value ->> 'ssis_packages' AS ssis_packages,
    j.value ->> 'xp_cmdshell_enabled' AS xp_cmdshell_enabled,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-004-RC02';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc04 AS
SELECT
    r.server,
    j.value ->> 'adhoc_distributed_queries' AS adhoc_distributed_queries,
    j.value ->> 'bulk_ops_grantees' AS bulk_ops_grantees,
    j.value ->> 'bulkadmin_members' AS bulkadmin_members,
    j.value ->> 'has_proxy_account' AS has_proxy_account,
    j.value ->> 'ole_automation_enabled' AS ole_automation_enabled,
    j.value ->> 'xp_cmdshell_enabled' AS xp_cmdshell_enabled,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-004-RC04';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc05 AS
SELECT
    r.server,
    j.value ->> 'assembly_name' AS assembly_name,
    j.value ->> 'configured_value' AS configured_value,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'description' AS description,
    j.value ->> 'is_user_defined' AS is_user_defined,
    j.value ->> 'modify_date' AS modify_date,
    j.value ->> 'name' AS name,
    j.value ->> 'owner_name' AS owner_name,
    j.value ->> 'permission_set_desc' AS permission_set_desc,
    j.value ->> 'running_value' AS running_value,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-004-RC05';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc06 AS
SELECT
    r.server,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'ole_enabled' AS ole_enabled,
    j.value ->> 'server_roles' AS server_roles,
    j.value ->> 'sysadmin_count' AS sysadmin_count,
    j.value ->> 'type_desc' AS type_desc,
    j.value ->> 'xp_cmdshell_enabled' AS xp_cmdshell_enabled,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-004-RC06';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc07 AS
SELECT
    r.server,
    j.value ->> 'avg_elapsed_us' AS avg_elapsed_us,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'last_execution_time' AS last_execution_time,
    j.value ->> 'query_text' AS query_text,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-004-RC07';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc08 AS
SELECT
    r.server,
    j.value ->> 'adhoc_queries_enabled' AS adhoc_queries_enabled,
    j.value ->> 'assembly_permission_grantees' AS assembly_permission_grantees,
    j.value ->> 'external_assemblies' AS external_assemblies,
    j.value ->> 'ole_automation_enabled' AS ole_automation_enabled,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-004-RC08';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc09 AS
SELECT
    r.server,
    j.value ->> 'account_age_days' AS account_age_days,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'file_access_permissions' AS file_access_permissions,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'privileged_role_count' AS privileged_role_count,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-004-RC09';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc10 AS
SELECT
    r.server,
    j.value ->> 'active_audits' AS active_audits,
    j.value ->> 'jobs_using_cmdshell' AS jobs_using_cmdshell,
    j.value ->> 'object_access_audit' AS object_access_audit,
    j.value ->> 'ole_enabled' AS ole_enabled,
    j.value ->> 'relevant_audit_actions' AS relevant_audit_actions,
    j.value ->> 'user_defined_audit' AS user_defined_audit,
    j.value ->> 'xp_cmdshell_enabled' AS xp_cmdshell_enabled,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-004-RC10';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc11 AS
SELECT
    r.server,
    j.value ->> 'distinct_hosts' AS distinct_hosts,
    j.value ->> 'distinct_programs' AS distinct_programs,
    j.value ->> 'hosts' AS hosts,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'programs' AS programs,
    j.value ->> 'total_sessions' AS total_sessions,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-004-RC11';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_004_rc14 AS
SELECT
    r.server,
    j.value ->> 'check_type' AS check_type,
    j.value ->> 'data_source' AS data_source,
    j.value ->> 'provider' AS provider,
    j.value ->> 'provider_type' AS provider_type,
    j.value ->> 'server_name' AS server_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-004-RC14';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_005_rc05 AS
SELECT
    r.server,
    j.value ->> 'cert_mapped_users' AS cert_mapped_users,
    j.value ->> 'contained_users' AS contained_users,
    j.value ->> 'explicit_auth_grants' AS explicit_auth_grants,
    j.value ->> 'user_asymmetric_keys' AS user_asymmetric_keys,
    j.value ->> 'user_certificates' AS user_certificates,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-005-RC05';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_005_rc06 AS
SELECT
    r.server,
    j.value ->> 'chaining_db_count' AS chaining_db_count,
    j.value ->> 'cross_db_objects' AS cross_db_objects,
    j.value ->> 'cross_db_synonyms' AS cross_db_synonyms,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-005-RC06';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_005_rc12 AS
SELECT
    r.server,
    j.value ->> 'containment_desc' AS containment_desc,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'db_owner' AS db_owner,
    j.value ->> 'is_db_chaining_on' AS is_db_chaining_on,
    j.value ->> 'is_encrypted' AS is_encrypted,
    j.value ->> 'is_trustworthy_on' AS is_trustworthy_on,
    j.value ->> 'isolation_status' AS isolation_status,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-005-RC12';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_006_rc04 AS
SELECT
    r.server,
    j.value ->> 'active_audits' AS active_audits,
    j.value ->> 'delegated_grant_count' AS delegated_grant_count,
    j.value ->> 'permission_change_audits' AS permission_change_audits,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-006-RC04';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_006_rc05 AS
SELECT
    r.server,
    j.value ->> 'active_audits' AS active_audits,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'db_perm_audit' AS db_perm_audit,
    j.value ->> 'grant_option_count' AS grant_option_count,
    j.value ->> 'permission_audit_status' AS permission_audit_status,
    j.value ->> 'schema_perm_audit' AS schema_perm_audit,
    j.value ->> 'scope' AS scope,
    j.value ->> 'server_perm_audit' AS server_perm_audit,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-006-RC05';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_az_006_rc12 AS
SELECT
    r.server,
    j.value ->> 'active_audits' AS active_audits,
    j.value ->> 'permission_audit_actions' AS permission_audit_actions,
    j.value ->> 'total_grant_options' AS total_grant_options,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-AZ-006-RC12';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc01 AS
SELECT
    r.server,
    j.value ->> 'age_years' AS age_years,
    j.value ->> 'compatibility_level' AS compatibility_level,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'description' AS description,
    j.value ->> 'is_enabled' AS is_enabled,
    j.value ->> 'name' AS name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-001-RC01';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc02 AS
SELECT
    r.server,
    j.value ->> 'compatibility_level' AS compatibility_level,
    j.value ->> 'custom_schemas' AS custom_schemas,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'db_owner' AS db_owner,
    j.value ->> 'description' AS description,
    j.value ->> 'is_enabled' AS is_enabled,
    j.value ->> 'name' AS name,
    j.value ->> 'procs_using_xp_cmdshell' AS procs_using_xp_cmdshell,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-001-RC02';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc03 AS
SELECT
    r.server,
    j.value ->> 'enabled' AS enabled,
    j.value ->> 'job_steps_using_cmdshell' AS job_steps_using_cmdshell,
    j.value ->> 'name' AS name,
    j.value ->> 'procs_using_cmdshell' AS procs_using_cmdshell,
    j.value ->> 'triggers_using_cmdshell' AS triggers_using_cmdshell,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-001-RC03';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc04 AS
SELECT
    r.server,
    j.value ->> 'active_audits' AS active_audits,
    j.value ->> 'config_change_audits' AS config_change_audits,
    j.value ->> 'configured_value' AS configured_value,
    j.value ->> 'default_trace' AS default_trace,
    j.value ->> 'drift_status' AS drift_status,
    j.value ->> 'name' AS name,
    j.value ->> 'runtime_value' AS runtime_value,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-001-RC04';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc05 AS
SELECT
    r.server,
    j.value ->> 'auth_type' AS auth_type,
    j.value ->> 'days_until_expiration' AS days_until_expiration,
    j.value ->> 'is_expiration_checked' AS is_expiration_checked,
    j.value ->> 'is_policy_checked' AS is_policy_checked,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-001-RC05';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc06 AS
SELECT
    r.server,
    j.value ->> 'agent_service_account' AS agent_service_account,
    j.value ->> 'privilege_assessment' AS privilege_assessment,
    j.value ->> 'server_name' AS server_name,
    j.value ->> 'service_account' AS service_account,
    j.value ->> 'servicename' AS servicename,
    j.value ->> 'sql_service_account' AS sql_service_account,
    j.value ->> 'status_desc' AS status_desc,
    j.value ->> 'xp_cmdshell_enabled' AS xp_cmdshell_enabled,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-001-RC06';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc07 AS
SELECT
    r.server,
    j.value ->> 'access_audit_actions' AS access_audit_actions,
    j.value ->> 'active_audits' AS active_audits,
    j.value ->> 'custom_audit_actions' AS custom_audit_actions,
    j.value ->> 'xp_cmdshell_enabled' AS xp_cmdshell_enabled,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-001-RC07';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_001_rc12 AS
SELECT
    r.server,
    j.value ->> 'backup_source_db' AS backup_source_db,
    j.value ->> 'backup_source_server' AS backup_source_server,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'days_since_restore' AS days_since_restore,
    j.value ->> 'restore_date' AS restore_date,
    j.value ->> 'restore_type' AS restore_type,
    j.value ->> 'restored_by' AS restored_by,
    j.value ->> 'source_type' AS source_type,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-001-RC12';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_003_rc06 AS
SELECT
    r.server,
    j.value ->> 'create_db_triggers' AS create_db_triggers,
    j.value ->> 'naming_policy_triggers' AS naming_policy_triggers,
    j.value ->> 'sample_test_db_count' AS sample_test_db_count,
    j.value ->> 'total_user_dbs' AS total_user_dbs,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-003-RC06';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_003_rc08 AS
SELECT
    r.server,
    j.value ->> 'active_audits' AS active_audits,
    j.value ->> 'encrypted_dbs' AS encrypted_dbs,
    j.value ->> 'full_recovery_dbs' AS full_recovery_dbs,
    j.value ->> 'server_edition' AS server_edition,
    j.value ->> 'training_db_count' AS training_db_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-003-RC08';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_003_rc11 AS
SELECT
    r.server,
    j.value ->> 'active_audits' AS active_audits,
    j.value ->> 'classification' AS classification,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'full_recovery_dbs' AS full_recovery_dbs,
    j.value ->> 'has_tde' AS has_tde,
    j.value ->> 'last_backup' AS last_backup,
    j.value ->> 'recovery_model_desc' AS recovery_model_desc,
    j.value ->> 'sample_test_db_count' AS sample_test_db_count,
    j.value ->> 'tde_encrypted_dbs' AS tde_encrypted_dbs,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-003-RC11';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_003_rc13 AS
SELECT
    r.server,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'naming_quality' AS naming_quality,
    j.value ->> 'recovery_model_desc' AS recovery_model_desc,
    j.value ->> 'state_desc' AS state_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-003-RC13';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_003_rc14 AS
SELECT
    r.server,
    j.value ->> 'active_logins' AS active_logins,
    j.value ->> 'distinct_owners' AS distinct_owners,
    j.value ->> 'sample_test_dbs' AS sample_test_dbs,
    j.value ->> 'total_user_dbs' AS total_user_dbs,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-003-RC14';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_004_rc08 AS
SELECT
    r.server,
    j.value ->> 'current_database' AS current_database,
    j.value ->> 'is_trustworthy' AS is_trustworthy,
    j.value ->> 'sql_service_account' AS sql_service_account,
    j.value ->> 'unsafe_assembly_count' AS unsafe_assembly_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-004-RC08';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_004_rc12 AS
SELECT
    r.server,
    j.value ->> 'clr_exposure' AS clr_exposure,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'db_owner' AS db_owner,
    j.value ->> 'is_trustworthy_on' AS is_trustworthy_on,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-004-RC12';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_004_rc13 AS
SELECT
    r.server,
    j.value ->> 'active_server_audits' AS active_server_audits,
    j.value ->> 'db_level_audit_count' AS db_level_audit_count,
    j.value ->> 'schema_change_audit_count' AS schema_change_audit_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-004-RC13';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_005_rc01 AS
SELECT
    r.server,
    j.value ->> 'Global' AS Global,
    j.value ->> 'Session' AS Session,
    j.value ->> 'Status' AS Status,
    j.value ->> 'TraceFlag' AS TraceFlag,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-005-RC01';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_005_rc02 AS
SELECT
    r.server,
    j.value ->> 'Global' AS Global,
    j.value ->> 'Session' AS Session,
    j.value ->> 'Status' AS Status,
    j.value ->> 'TraceFlag' AS TraceFlag,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-005-RC02';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_005_rc05 AS
SELECT
    r.server,
    j.value ->> 'Global' AS Global,
    j.value ->> 'Session' AS Session,
    j.value ->> 'Status' AS Status,
    j.value ->> 'TraceFlag' AS TraceFlag,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-005-RC05';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_005_rc06 AS
SELECT
    r.server,
    j.value ->> 'active_audits' AS active_audits,
    j.value ->> 'ag_count' AS ag_count,
    j.value ->> 'full_recovery_dbs' AS full_recovery_dbs,
    j.value ->> 'Global' AS Global,
    j.value ->> 'product_level' AS product_level,
    j.value ->> 'server_edition' AS server_edition,
    j.value ->> 'Session' AS Session,
    j.value ->> 'Status' AS Status,
    j.value ->> 'tde_encrypted_dbs' AS tde_encrypted_dbs,
    j.value ->> 'TraceFlag' AS TraceFlag,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-005-RC06';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_005_rc07 AS
SELECT
    r.server,
    j.value ->> 'Global' AS Global,
    j.value ->> 'Session' AS Session,
    j.value ->> 'Status' AS Status,
    j.value ->> 'TraceFlag' AS TraceFlag,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-005-RC07';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_005_rc08 AS
SELECT
    r.server,
    j.value ->> 'last_restart' AS last_restart,
    j.value ->> 'machine_name' AS machine_name,
    j.value ->> 'sql_version' AS sql_version,
    j.value ->> 'startup_trace_flag_count' AS startup_trace_flag_count,
    j.value ->> 'startup_trace_flags' AS startup_trace_flags,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-005-RC08';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_005_rc10 AS
SELECT
    r.server,
    j.value ->> 'drive_count' AS drive_count,
    j.value ->> 'errorlog_file_count' AS errorlog_file_count,
    j.value ->> 'errors_per_sec' AS errors_per_sec,
    j.value ->> 'Global' AS Global,
    j.value ->> 'last_restart' AS last_restart,
    j.value ->> 'Session' AS Session,
    j.value ->> 'Status' AS Status,
    j.value ->> 'TraceFlag' AS TraceFlag,
    j.value ->> 'uptime_days' AS uptime_days,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-005-RC10';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_005_rc11 AS
SELECT
    r.server,
    j.value ->> 'dbsc_availability' AS dbsc_availability,
    j.value ->> 'edition' AS edition,
    j.value ->> 'full_version' AS full_version,
    j.value ->> 'Global' AS Global,
    j.value ->> 'major_version' AS major_version,
    j.value ->> 'Session' AS Session,
    j.value ->> 'Status' AS Status,
    j.value ->> 'tf_1117_1118_2371_status' AS tf_1117_1118_2371_status,
    j.value ->> 'TraceFlag' AS TraceFlag,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-005-RC11';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_005_rc12 AS
SELECT
    r.server,
    j.value ->> 'Global' AS Global,
    j.value ->> 'major_version' AS major_version,
    j.value ->> 'plan_guides_count' AS plan_guides_count,
    j.value ->> 'qs_desired_state' AS qs_desired_state,
    j.value ->> 'query_store_check' AS query_store_check,
    j.value ->> 'query_store_enabled' AS query_store_enabled,
    j.value ->> 'Session' AS Session,
    j.value ->> 'Status' AS Status,
    j.value ->> 'TraceFlag' AS TraceFlag,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-005-RC12';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_005_rc14 AS
SELECT
    r.server,
    j.value ->> 'Global' AS Global,
    j.value ->> 'Session' AS Session,
    j.value ->> 'Status' AS Status,
    j.value ->> 'TraceFlag' AS TraceFlag,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-005-RC14';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_006_rc07 AS
SELECT
    r.server,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'last_execution_time' AS last_execution_time,
    j.value ->> 'linked_query_type' AS linked_query_type,
    j.value ->> 'query_text' AS query_text,
    j.value ->> 'source_database' AS source_database,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-006-RC07';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_006_rc09 AS
SELECT
    r.server,
    j.value ->> 'event_name' AS event_name,
    j.value ->> 'session_name' AS session_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-006-RC09';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_006_rc14 AS
SELECT
    r.server,
    j.value ->> 'auth_scheme' AS auth_scheme,
    j.value ->> 'client_net_address' AS client_net_address,
    j.value ->> 'encrypt_option' AS encrypt_option,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'net_transport' AS net_transport,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_id' AS session_id,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-006-RC14';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_006_rc15 AS
SELECT
    r.server,
    j.value ->> 'auth_scheme' AS auth_scheme,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'encrypt_option' AS encrypt_option,
    j.value ->> 'mutual_auth_status' AS mutual_auth_status,
    j.value ->> 'net_transport' AS net_transport,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-006-RC15';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_cfg_006_rc16 AS
SELECT
    r.server,
    j.value ->> 'admin_role_members' AS admin_role_members,
    j.value ->> 'linked_server_count' AS linked_server_count,
    j.value ->> 'non_sysadmin_view_server_state_grants' AS non_sysadmin_view_server_state_grants,
    j.value ->> 'view_any_definition_grants' AS view_any_definition_grants,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-CFG-006-RC16';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc01 AS
SELECT
    r.server,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'encrypt_option' AS encrypt_option,
    j.value ->> 'encryption_status' AS encryption_status,
    j.value ->> 'force_encryption' AS force_encryption,
    j.value ->> 'pct' AS pct,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-001-RC01';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc02 AS
SELECT
    r.server,
    j.value ->> 'auth_scheme' AS auth_scheme,
    j.value ->> 'client_net_address' AS client_net_address,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'encrypt_option' AS encrypt_option,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'net_transport' AS net_transport,
    j.value ->> 'program_name' AS program_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-001-RC02';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc03 AS
SELECT
    r.server,
    j.value ->> 'active_sessions' AS active_sessions,
    j.value ->> 'client_interface_name' AS client_interface_name,
    j.value ->> 'client_version' AS client_version,
    j.value ->> 'compat_version' AS compat_version,
    j.value ->> 'compatibility_level' AS compatibility_level,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'encrypt_option' AS encrypt_option,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'net_transport' AS net_transport,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'protocol_version' AS protocol_version,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-001-RC03';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc04 AS
SELECT
    r.server,
    j.value ->> 'client_interface_name' AS client_interface_name,
    j.value ->> 'client_version' AS client_version,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'encrypt_option' AS encrypt_option,
    j.value ->> 'encrypted_count' AS encrypted_count,
    j.value ->> 'protocol_version' AS protocol_version,
    j.value ->> 'unencrypted_count' AS unencrypted_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-001-RC04';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc07 AS
SELECT
    r.server,
    j.value ->> 'cert_health' AS cert_health,
    j.value ->> 'cert_status' AS cert_status,
    j.value ->> 'certificate_id' AS certificate_id,
    j.value ->> 'configured_cert_thumbprint' AS configured_cert_thumbprint,
    j.value ->> 'days_until_expiry' AS days_until_expiry,
    j.value ->> 'expiry_date' AS expiry_date,
    j.value ->> 'name' AS name,
    j.value ->> 'start_date' AS start_date,
    j.value ->> 'subject' AS subject,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-001-RC07';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc08 AS
SELECT
    r.server,
    j.value ->> 'auth_scheme' AS auth_scheme,
    j.value ->> 'cert_status' AS cert_status,
    j.value ->> 'configured_cert_thumbprint' AS configured_cert_thumbprint,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'encrypt_option' AS encrypt_option,
    j.value ->> 'encryption_state' AS encryption_state,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'instance_name' AS instance_name,
    j.value ->> 'machine_name' AS machine_name,
    j.value ->> 'program_name' AS program_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-001-RC08';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc09 AS
SELECT
    r.server,
    j.value ->> 'client_net_address' AS client_net_address,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'connection_locality' AS connection_locality,
    j.value ->> 'encrypt_option' AS encrypt_option,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'net_transport' AS net_transport,
    j.value ->> 'pct_within_locality' AS pct_within_locality,
    j.value ->> 'program_name' AS program_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-001-RC09';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc10 AS
SELECT
    r.server,
    j.value ->> 'force_encryption' AS force_encryption,
    j.value ->> 'total_connections' AS total_connections,
    j.value ->> 'unencrypted_connections' AS unencrypted_connections,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-001-RC10';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc11 AS
SELECT
    r.server,
    j.value ->> 'auth_scheme' AS auth_scheme,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'encrypt_option' AS encrypt_option,
    j.value ->> 'encrypted_count' AS encrypted_count,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'unencrypted_count' AS unencrypted_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-001-RC11';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc12 AS
SELECT
    r.server,
    j.value ->> 'cert_status' AS cert_status,
    j.value ->> 'certificate_hash' AS certificate_hash,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-001-RC12';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_001_rc13 AS
SELECT
    r.server,
    j.value ->> 'unencrypted_connections' AS unencrypted_connections,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-001-RC13';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_002_rc09 AS
SELECT
    r.server,
    j.value ->> 'modern_tls_connections' AS modern_tls_connections,
    j.value ->> 'old_tls_connections' AS old_tls_connections,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-002-RC09';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_002_rc10 AS
SELECT
    r.server,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'distinct_apps' AS distinct_apps,
    j.value ->> 'protocol_version' AS protocol_version,
    j.value ->> 'tls_version' AS tls_version,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-002-RC10';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_002_rc11 AS
SELECT
    r.server,
    j.value ->> 'active_audit_specs' AS active_audit_specs,
    j.value ->> 'active_audits' AS active_audits,
    j.value ->> 'old_tls_connections' AS old_tls_connections,
    j.value ->> 'tls_xe_sessions' AS tls_xe_sessions,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-002-RC11';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_002_rc12 AS
SELECT
    r.server,
    j.value ->> 'build_type' AS build_type,
    j.value ->> 'edition' AS edition,
    j.value ->> 'major_version' AS major_version,
    j.value ->> 'product_level' AS product_level,
    j.value ->> 'product_version' AS product_version,
    j.value ->> 'tls12_status' AS tls12_status,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-002-RC12';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc01 AS
SELECT
    r.server,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'database_id' AS database_id,
    j.value ->> 'encryption_state' AS encryption_state,
    j.value ->> 'encryption_state_desc' AS encryption_state_desc,
    j.value ->> 'is_encrypted' AS is_encrypted,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'key_length' AS key_length,
    j.value ->> 'master_db_has_dmk' AS master_db_has_dmk,
    j.value ->> 'name' AS name,
    j.value ->> 'state_desc' AS state_desc,
    j.value ->> 'tde_certs_count' AS tde_certs_count,
    j.value ->> 'unencrypted_user_dbs' AS unencrypted_user_dbs,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-003-RC01';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc02 AS
SELECT
    r.server,
    j.value ->> 'edition' AS edition,
    j.value ->> 'is_encrypted' AS is_encrypted,
    j.value ->> 'major_version' AS major_version,
    j.value ->> 'name' AS name,
    j.value ->> 'product_version' AS product_version,
    j.value ->> 'tde_support_status' AS tde_support_status,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-003-RC02';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc03 AS
SELECT
    r.server,
    j.value ->> 'edition' AS edition,
    j.value ->> 'entitlement_status' AS entitlement_status,
    j.value ->> 'major_version' AS major_version,
    j.value ->> 'product_version' AS product_version,
    j.value ->> 'unencrypted_db_count' AS unencrypted_db_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-003-RC03';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc04 AS
SELECT
    r.server,
    j.value ->> 'ekm_provider_count' AS ekm_provider_count,
    j.value ->> 'encryption_state' AS encryption_state,
    j.value ->> 'is_encrypted' AS is_encrypted,
    j.value ->> 'master_asym_key_count' AS master_asym_key_count,
    j.value ->> 'master_cert_count' AS master_cert_count,
    j.value ->> 'master_dmk_exists' AS master_dmk_exists,
    j.value ->> 'name' AS name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-003-RC04';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc10 AS
SELECT
    r.server,
    j.value ->> 'encrypted_db_count' AS encrypted_db_count,
    j.value ->> 'free_mb' AS free_mb,
    j.value ->> 'internal_objects_mb' AS internal_objects_mb,
    j.value ->> 'tempdb_data_files' AS tempdb_data_files,
    j.value ->> 'tempdb_encrypted' AS tempdb_encrypted,
    j.value ->> 'tempdb_has_dek' AS tempdb_has_dek,
    j.value ->> 'unencrypted_db_count' AS unencrypted_db_count,
    j.value ->> 'user_objects_mb' AS user_objects_mb,
    j.value ->> 'version_store_mb' AS version_store_mb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-003-RC10';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc13 AS
SELECT
    r.server,
    j.value ->> 'create_date' AS create_date,
    j.value ->> 'environment_guess' AS environment_guess,
    j.value ->> 'is_encrypted' AS is_encrypted,
    j.value ->> 'name' AS name,
    j.value ->> 'state_desc' AS state_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-003-RC13';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc15 AS
SELECT
    r.server,
    j.value ->> 'encrypted_db_count' AS encrypted_db_count,
    j.value ->> 'inactive_dek_count' AS inactive_dek_count,
    j.value ->> 'master_dmk_exists' AS master_dmk_exists,
    j.value ->> 'tde_cert_count' AS tde_cert_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-003-RC15';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_003_rc16 AS
SELECT
    r.server,
    j.value ->> 'asym_key_count' AS asym_key_count,
    j.value ->> 'cert_name' AS cert_name,
    j.value ->> 'days_expired' AS days_expired,
    j.value ->> 'ekm_provider_count' AS ekm_provider_count,
    j.value ->> 'expired_cert_count' AS expired_cert_count,
    j.value ->> 'expiry_date' AS expiry_date,
    j.value ->> 'master_dmk_exists' AS master_dmk_exists,
    j.value ->> 'pvt_key_encryption_type_desc' AS pvt_key_encryption_type_desc,
    j.value ->> 'start_date' AS start_date,
    j.value ->> 'subject' AS subject,
    j.value ->> 'valid_cert_count' AS valid_cert_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-003-RC16';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc01 AS
SELECT
    r.server,
    j.value ->> 'backup_start_date' AS backup_start_date,
    j.value ->> 'backup_type' AS backup_type,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'encryption_status' AS encryption_status,
    j.value ->> 'encryptor_type' AS encryptor_type,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'size_mb' AS size_mb,
    j.value ->> 'tde_enabled' AS tde_enabled,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-004-RC01';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc03 AS
SELECT
    r.server,
    j.value ->> 'asym_key_count' AS asym_key_count,
    j.value ->> 'backup_start_date' AS backup_start_date,
    j.value ->> 'backup_type' AS backup_type,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'ekm_provider_count' AS ekm_provider_count,
    j.value ->> 'encryption_status' AS encryption_status,
    j.value ->> 'encryptor_type' AS encryptor_type,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'master_dmk_exists' AS master_dmk_exists,
    j.value ->> 'size_mb' AS size_mb,
    j.value ->> 'tde_enabled' AS tde_enabled,
    j.value ->> 'valid_cert_count' AS valid_cert_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-004-RC03';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc05 AS
SELECT
    r.server,
    j.value ->> 'backup_start_date' AS backup_start_date,
    j.value ->> 'backup_type' AS backup_type,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'encryption_status' AS encryption_status,
    j.value ->> 'encryptor_type' AS encryptor_type,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'size_mb' AS size_mb,
    j.value ->> 'tde_enabled' AS tde_enabled,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-004-RC05';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc06 AS
SELECT
    r.server,
    j.value ->> 'backup_start_date' AS backup_start_date,
    j.value ->> 'backup_type' AS backup_type,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'encryption_status' AS encryption_status,
    j.value ->> 'encryptor_type' AS encryptor_type,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'size_mb' AS size_mb,
    j.value ->> 'tde_enabled' AS tde_enabled,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-004-RC06';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc08 AS
SELECT
    r.server,
    j.value ->> 'backup_start_date' AS backup_start_date,
    j.value ->> 'backup_type' AS backup_type,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'encryption_status' AS encryption_status,
    j.value ->> 'encryptor_type' AS encryptor_type,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'size_mb' AS size_mb,
    j.value ->> 'tde_enabled' AS tde_enabled,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-004-RC08';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc10 AS
SELECT
    r.server,
    j.value ->> 'backup_start_date' AS backup_start_date,
    j.value ->> 'backup_type' AS backup_type,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'encryption_status' AS encryption_status,
    j.value ->> 'encryptor_type' AS encryptor_type,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'size_mb' AS size_mb,
    j.value ->> 'tde_enabled' AS tde_enabled,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-004-RC10';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc11 AS
SELECT
    r.server,
    j.value ->> 'asymmetric_keys' AS asymmetric_keys,
    j.value ->> 'backup_start_date' AS backup_start_date,
    j.value ->> 'backup_type' AS backup_type,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'dmk_exists' AS dmk_exists,
    j.value ->> 'encryption_status' AS encryption_status,
    j.value ->> 'encryptor_type' AS encryptor_type,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'size_mb' AS size_mb,
    j.value ->> 'tde_enabled' AS tde_enabled,
    j.value ->> 'user_certificates' AS user_certificates,
    j.value ->> 'user_symmetric_keys' AS user_symmetric_keys,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-004-RC11';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc13 AS
SELECT
    r.server,
    j.value ->> 'backup_start_date' AS backup_start_date,
    j.value ->> 'backup_type' AS backup_type,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'encryption_status' AS encryption_status,
    j.value ->> 'encryptor_type' AS encryptor_type,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'size_mb' AS size_mb,
    j.value ->> 'tde_enabled' AS tde_enabled,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-004-RC13';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc15 AS
SELECT
    r.server,
    j.value ->> 'backup_start_date' AS backup_start_date,
    j.value ->> 'backup_type' AS backup_type,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'encryption_status' AS encryption_status,
    j.value ->> 'encryptor_type' AS encryptor_type,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'size_mb' AS size_mb,
    j.value ->> 'tde_enabled' AS tde_enabled,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-004-RC15';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_004_rc16 AS
SELECT
    r.server,
    j.value ->> 'backup_start_date' AS backup_start_date,
    j.value ->> 'backup_type' AS backup_type,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'encryption_status' AS encryption_status,
    j.value ->> 'encryptor_type' AS encryptor_type,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'size_mb' AS size_mb,
    j.value ->> 'tde_enabled' AS tde_enabled,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-004-RC16';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_005_rc01 AS
SELECT
    r.server,
    j.value ->> 'auth_scheme' AS auth_scheme,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'encrypt_option' AS encrypt_option,
    j.value ->> 'net_transport' AS net_transport,
    j.value ->> 'protocol_type' AS protocol_type,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-005-RC01';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_005_rc03 AS
SELECT
    r.server,
    j.value ->> 'backup_start_date' AS backup_start_date,
    j.value ->> 'backup_type' AS backup_type,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'encryption_status' AS encryption_status,
    j.value ->> 'encryptor_type' AS encryptor_type,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'size_mb' AS size_mb,
    j.value ->> 'tde_enabled' AS tde_enabled,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-005-RC03';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_005_rc10 AS
SELECT
    r.server,
    j.value ->> 'encrypted_connections' AS encrypted_connections,
    j.value ->> 'tls_connections' AS tls_connections,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-005-RC10';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_enc_005_rc14 AS
SELECT
    r.server,
    j.value ->> 'encrypted_connections' AS encrypted_connections,
    j.value ->> 'event_name' AS event_name,
    j.value ->> 'session_name' AS session_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-ENC-005-RC14';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_001_rc07 AS
SELECT
    r.server,
    j.value ->> 'mixed_pattern_count' AS mixed_pattern_count,
    j.value ->> 'unprotected_mixed_count' AS unprotected_mixed_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-INJ-001-RC07';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_001_rc10 AS
SELECT
    r.server,
    j.value ->> 'adhoc_pct' AS adhoc_pct,
    j.value ->> 'adhoc_plans' AS adhoc_plans,
    j.value ->> 'prepared_plans' AS prepared_plans,
    j.value ->> 'proc_plans' AS proc_plans,
    j.value ->> 'total_plans' AS total_plans,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-INJ-001-RC10';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_001_rc14 AS
SELECT
    r.server,
    j.value ->> 'name' AS name,
    j.value ->> 'value_in_use' AS value_in_use,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-INJ-001-RC14';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc02 AS
SELECT
    r.server,
    j.value ->> 'compat_version' AS compat_version,
    j.value ->> 'compatibility_level' AS compatibility_level,
    j.value ->> 'config_name' AS config_name,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'is_enabled' AS is_enabled,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC02';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc08 AS
SELECT
    r.server,
    j.value ->> 'event_name' AS event_name,
    j.value ->> 'session_name' AS session_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC08';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc09 AS
SELECT
    r.server,
    j.value ->> 'auth_scheme' AS auth_scheme,
    j.value ->> 'client_net_address' AS client_net_address,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'program_name' AS program_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC09';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc10 AS
SELECT
    r.server,
    j.value ->> 'clr_enabled' AS clr_enabled,
    j.value ->> 'external_scripts_enabled' AS external_scripts_enabled,
    j.value ->> 'ole_auto_enabled' AS ole_auto_enabled,
    j.value ->> 'xp_cmdshell_enabled' AS xp_cmdshell_enabled,
    j.value ->> 'xp_proxy_exists' AS xp_proxy_exists,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC10';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc11 AS
SELECT
    r.server,
    j.value ->> 'privilege_assessment' AS privilege_assessment,
    j.value ->> 'service_account' AS service_account,
    j.value ->> 'servicename' AS servicename,
    j.value ->> 'sql_service_account' AS sql_service_account,
    j.value ->> 'startup_type_desc' AS startup_type_desc,
    j.value ->> 'status_desc' AS status_desc,
    j.value ->> 'xp_cmdshell_enabled' AS xp_cmdshell_enabled,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC11';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_inj_002_rc16 AS
SELECT
    r.server,
    j.value ->> 'explicit_xproc_grants' AS explicit_xproc_grants,
    j.value ->> 'ole_auto_enabled' AS ole_auto_enabled,
    j.value ->> 'proxy_account_exists' AS proxy_account_exists,
    j.value ->> 'sa_enabled' AS sa_enabled,
    j.value ->> 'show_advanced_enabled' AS show_advanced_enabled,
    j.value ->> 'xp_cmdshell_current' AS xp_cmdshell_current,
    j.value ->> 'xp_cmdshell_enabled' AS xp_cmdshell_enabled,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-INJ-002-RC16';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_001_rc01 AS
SELECT
    r.server,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'ip_address' AS ip_address,
    j.value ->> 'listener_id' AS listener_id,
    j.value ->> 'local_net_address' AS local_net_address,
    j.value ->> 'local_tcp_port' AS local_tcp_port,
    j.value ->> 'port' AS port,
    j.value ->> 'start_time' AS start_time,
    j.value ->> 'state_desc' AS state_desc,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-NET-001-RC01';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_001_rc02 AS
SELECT
    r.server,
    j.value ->> 'auth_scheme' AS auth_scheme,
    j.value ->> 'client_net_address' AS client_net_address,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'encrypt_option' AS encrypt_option,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'ip_address' AS ip_address,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'login_time' AS login_time,
    j.value ->> 'port' AS port,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'state_desc' AS state_desc,
    j.value ->> 'type_desc' AS type_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-NET-001-RC02';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_001_rc03 AS
SELECT
    r.server,
    j.value ->> 'client_net_address' AS client_net_address,
    j.value ->> 'connect_time' AS connect_time,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'local_net_address' AS local_net_address,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'program_name' AS program_name,
    j.value ->> 'session_id' AS session_id,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-NET-001-RC03';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_001_rc05 AS
SELECT
    r.server,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'ip_prefix' AS ip_prefix,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-NET-001-RC05';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_001_rc11 AS
SELECT
    r.server,
    j.value ->> 'ag_count' AS ag_count,
    j.value ->> 'credential_count' AS credential_count,
    j.value ->> 'job_count' AS job_count,
    j.value ->> 'log_shipping_count' AS log_shipping_count,
    j.value ->> 'mail_profile_count' AS mail_profile_count,
    j.value ->> 'recent_backup_count' AS recent_backup_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-NET-001-RC11';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_002_rc02 AS
SELECT
    r.server,
    j.value ->> 'clr_enabled' AS clr_enabled,
    j.value ->> 'cross_db_chaining' AS cross_db_chaining,
    j.value ->> 'ole_auto_enabled' AS ole_auto_enabled,
    j.value ->> 'remote_dac_enabled' AS remote_dac_enabled,
    j.value ->> 'sa_active' AS sa_active,
    j.value ->> 'sa_disabled' AS sa_disabled,
    j.value ->> 'xp_cmdshell_enabled' AS xp_cmdshell_enabled,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-NET-002-RC02';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_002_rc06 AS
SELECT
    r.server,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'distinct_hosts' AS distinct_hosts,
    j.value ->> 'local_tcp_port' AS local_tcp_port,
    j.value ->> 'program_name' AS program_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-NET-002-RC06';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_002_rc08 AS
SELECT
    r.server,
    j.value ->> 'local_tcp_port' AS local_tcp_port,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-NET-002-RC08';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_002_rc10 AS
SELECT
    r.server,
    j.value ->> 'auth_scheme' AS auth_scheme,
    j.value ->> 'encrypt_option' AS encrypt_option,
    j.value ->> 'host_name' AS host_name,
    j.value ->> 'listening_port' AS listening_port,
    j.value ->> 'login_name' AS login_name,
    j.value ->> 'remote_dac_enabled' AS remote_dac_enabled,
    j.value ->> 'session_id' AS session_id,
    j.value ->> 'total_tcp_connections' AS total_tcp_connections,
    j.value ->> 'unencrypted_connections' AS unencrypted_connections,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-NET-002-RC10';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_002_rc12 AS
SELECT
    r.server,
    j.value ->> 'edition' AS edition,
    j.value ->> 'listening_port' AS listening_port,
    j.value ->> 'product_version' AS product_version,
    j.value ->> 'service_pack' AS service_pack,
    j.value ->> 'version_banner' AS version_banner,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-NET-002-RC12';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_002_rc14 AS
SELECT
    r.server,
    j.value ->> 'current_port' AS current_port,
    j.value ->> 'days_since_install' AS days_since_install,
    j.value ->> 'instance_install_date' AS instance_install_date,
    j.value ->> 'last_restart' AS last_restart,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-NET-002-RC14';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_003_rc06 AS
SELECT
    r.server,
    j.value ->> 'active_external_scripts' AS active_external_scripts,
    j.value ->> 'configured_value' AS configured_value,
    j.value ->> 'current_value' AS current_value,
    j.value ->> 'description' AS description,
    j.value ->> 'name' AS name,
    j.value ->> 'total_executions' AS total_executions,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-NET-003-RC06';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_net_003_rc15 AS
SELECT
    r.server,
    j.value ->> 'command' AS command,
    j.value ->> 'date_created' AS date_created,
    j.value ->> 'date_modified' AS date_modified,
    j.value ->> 'job_enabled' AS job_enabled,
    j.value ->> 'job_name' AS job_name,
    j.value ->> 'step_name' AS step_name,
    j.value ->> 'subsystem' AS subsystem,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-NET-003-RC15';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pat_001_rc01 AS
SELECT
    r.server,
    j.value ->> 'edition' AS edition,
    j.value ->> 'full_version_string' AS full_version_string,
    j.value ->> 'lifecycle_status' AS lifecycle_status,
    j.value ->> 'major_version' AS major_version,
    j.value ->> 'minor_version' AS minor_version,
    j.value ->> 'product_level' AS product_level,
    j.value ->> 'product_version' AS product_version,
    j.value ->> 'update_level' AS update_level,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-PAT-001-RC01';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pat_001_rc02 AS
SELECT
    r.server,
    j.value ->> 'current_major' AS current_major,
    j.value ->> 'latest_major_version' AS latest_major_version,
    j.value ->> 'product_level' AS product_level,
    j.value ->> 'product_version' AS product_version,
    j.value ->> 'version_assessment' AS version_assessment,
    j.value ->> 'versions_behind' AS versions_behind,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-PAT-001-RC02';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pat_001_rc05 AS
SELECT
    r.server,
    j.value ->> 'deprecated_feature' AS deprecated_feature,
    j.value ->> 'usage_count' AS usage_count,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-PAT-001-RC05';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pat_001_rc09 AS
SELECT
    r.server,
    j.value ->> 'connection_count' AS connection_count,
    j.value ->> 'distinct_clients' AS distinct_clients,
    j.value ->> 'protocol_version' AS protocol_version,
    j.value ->> 'tds_version_desc' AS tds_version_desc,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-PAT-001-RC09';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pat_001_rc11 AS
SELECT
    r.server,
    j.value ->> 'compat_gap' AS compat_gap,
    j.value ->> 'compatibility_level' AS compatibility_level,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'engine_compat_level' AS engine_compat_level,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-PAT-001-RC11';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pat_001_rc12 AS
SELECT
    r.server,
    j.value ->> 'cumulative_update' AS cumulative_update,
    j.value ->> 'current_major' AS current_major,
    j.value ->> 'days_since_last_backup' AS days_since_last_backup,
    j.value ->> 'days_since_restart' AS days_since_restart,
    j.value ->> 'last_full_backup' AS last_full_backup,
    j.value ->> 'latest_major_version' AS latest_major_version,
    j.value ->> 'non_online_dbs' AS non_online_dbs,
    j.value ->> 'pending_config_changes' AS pending_config_changes,
    j.value ->> 'product_level' AS product_level,
    j.value ->> 'product_version' AS product_version,
    j.value ->> 'sqlserver_start_time' AS sqlserver_start_time,
    j.value ->> 'versions_behind' AS versions_behind,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-PAT-001-RC12';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pat_002_rc02 AS
SELECT
    r.server,
    j.value ->> 'edition' AS edition,
    j.value ->> 'major_version' AS major_version,
    j.value ->> 'product_build_type' AS product_build_type,
    j.value ->> 'product_level' AS product_level,
    j.value ->> 'product_update_level' AS product_update_level,
    j.value ->> 'product_version' AS product_version,
    j.value ->> 'sqlserver_start_time' AS sqlserver_start_time,
    j.value ->> 'uptime_days' AS uptime_days,
    j.value ->> 'uptime_hours' AS uptime_hours,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-PAT-002-RC02';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pat_002_rc09 AS
SELECT
    r.server,
    j.value ->> 'compat_version' AS compat_version,
    j.value ->> 'compatibility_level' AS compatibility_level,
    j.value ->> 'current_major_version' AS current_major_version,
    j.value ->> 'database_name' AS database_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-PAT-002-RC09';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pat_002_rc10 AS
SELECT
    r.server,
    j.value ->> 'active_requests' AS active_requests,
    j.value ->> 'active_user_sessions' AS active_user_sessions,
    j.value ->> 'long_running_transactions' AS long_running_transactions,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-PAT-002-RC10';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pat_002_rc12 AS
SELECT
    r.server,
    j.value ->> 'branch_description' AS branch_description,
    j.value ->> 'days_since_restart' AS days_since_restart,
    j.value ->> 'major_version' AS major_version,
    j.value ->> 'patch_staleness' AS patch_staleness,
    j.value ->> 'product_build_type' AS product_build_type,
    j.value ->> 'product_level' AS product_level,
    j.value ->> 'product_update_level' AS product_update_level,
    j.value ->> 'product_version' AS product_version,
    j.value ->> 'sqlserver_start_time' AS sqlserver_start_time,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-PAT-002-RC12';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc01 AS
SELECT
    r.server,
    j.value ->> 'cek_value_count' AS cek_value_count,
    j.value ->> 'column_encryption_key_count' AS column_encryption_key_count,
    j.value ->> 'column_master_key_count' AS column_master_key_count,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'encryption_state' AS encryption_state,
    j.value ->> 'encryption_state_desc' AS encryption_state_desc,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'key_length' AS key_length,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-PRI-001-RC01';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc03 AS
SELECT
    r.server,
    j.value ->> 'ae_availability' AS ae_availability,
    j.value ->> 'cek_count' AS cek_count,
    j.value ->> 'cmk_count' AS cmk_count,
    j.value ->> 'edition' AS edition,
    j.value ->> 'encrypted_column_count' AS encrypted_column_count,
    j.value ->> 'major_version' AS major_version,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-PRI-001-RC03';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc05 AS
SELECT
    r.server,
    j.value ->> 'algorithm_desc' AS algorithm_desc,
    j.value ->> 'compatibility_level' AS compatibility_level,
    j.value ->> 'database_created' AS database_created,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'encryption_capability' AS encryption_capability,
    j.value ->> 'key_length' AS key_length,
    j.value ->> 'key_name' AS key_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-PRI-001-RC05';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc07 AS
SELECT
    r.server,
    j.value ->> 'createdate' AS createdate,
    j.value ->> 'description' AS description,
    j.value ->> 'execution_count' AS execution_count,
    j.value ->> 'folder_name' AS folder_name,
    j.value ->> 'has_bulk_insert' AS has_bulk_insert,
    j.value ->> 'has_insert' AS has_insert,
    j.value ->> 'last_execution_time' AS last_execution_time,
    j.value ->> 'package_name' AS package_name,
    j.value ->> 'packageformat' AS packageformat,
    j.value ->> 'query_text' AS query_text,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-PRI-001-RC07';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc09 AS
SELECT
    r.server,
    j.value ->> 'cert_name' AS cert_name,
    j.value ->> 'days_until_expiry' AS days_until_expiry,
    j.value ->> 'expiry_date' AS expiry_date,
    j.value ->> 'pvt_key_encryption_type_desc' AS pvt_key_encryption_type_desc,
    j.value ->> 'start_date' AS start_date,
    j.value ->> 'subject' AS subject,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-PRI-001-RC09';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc10 AS
SELECT
    r.server,
    j.value ->> 'edition' AS edition,
    j.value ->> 'encryption_key_count' AS encryption_key_count,
    j.value ->> 'feature_utilization' AS feature_utilization,
    j.value ->> 'major_version' AS major_version,
    j.value ->> 'masked_column_count' AS masked_column_count,
    j.value ->> 'masking_support_level' AS masking_support_level,
    j.value ->> 'master_key_count' AS master_key_count,
    j.value ->> 'product_level' AS product_level,
    j.value ->> 'product_version' AS product_version,
    j.value ->> 'update_level' AS update_level,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-PRI-001-RC10';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc11 AS
SELECT
    r.server,
    j.value ->> 'backup_finish_date' AS backup_finish_date,
    j.value ->> 'backup_type' AS backup_type,
    j.value ->> 'backup_type_desc' AS backup_type_desc,
    j.value ->> 'cert_expiry' AS cert_expiry,
    j.value ->> 'certificate_name' AS certificate_name,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'encryption_state' AS encryption_state,
    j.value ->> 'encryption_state_desc' AS encryption_state_desc,
    j.value ->> 'encryptor_thumbprint' AS encryptor_thumbprint,
    j.value ->> 'encryptor_type' AS encryptor_type,
    j.value ->> 'is_copy_only' AS is_copy_only,
    j.value ->> 'key_algorithm' AS key_algorithm,
    j.value ->> 'physical_device_name' AS physical_device_name,
    j.value ->> 'size_mb' AS size_mb,
    j.value ->> 'tde_algorithm' AS tde_algorithm,
    j.value ->> 'tde_key_length' AS tde_key_length,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-PRI-001-RC11';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_002_rc01 AS
SELECT
    r.server,
    j.value ->> 'event_name' AS event_name,
    j.value ->> 'package' AS package,
    j.value ->> 'session_name' AS session_name,
    j.value ->> 'startup_state' AS startup_state,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-PRI-002-RC01';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_002_rc02 AS
SELECT
    r.server,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'is_parameterization_forced' AS is_parameterization_forced,
    j.value ->> 'name' AS name,
    j.value ->> 'parameterization_mode' AS parameterization_mode,
    j.value ->> 'pct_of_plans' AS pct_of_plans,
    j.value ->> 'plan_count' AS plan_count,
    j.value ->> 'plan_type' AS plan_type,
    j.value ->> 'size_mb' AS size_mb,
    j.value ->> 'value_in_use' AS value_in_use,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-PRI-002-RC02';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_002_rc03 AS
SELECT
    r.server,
    j.value ->> 'Global' AS Global,
    j.value ->> 'Session' AS Session,
    j.value ->> 'Status' AS Status,
    j.value ->> 'TraceFlag' AS TraceFlag,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-PRI-002-RC03';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_002_rc05 AS
SELECT
    r.server,
    j.value ->> 'event_name' AS event_name,
    j.value ->> 'package' AS package,
    j.value ->> 'session_name' AS session_name,
    j.value ->> 'startup_state' AS startup_state,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-PRI-002-RC05';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_002_rc06 AS
SELECT
    r.server,
    j.value ->> 'assessment' AS assessment,
    j.value ->> 'current_value' AS current_value,
    j.value ->> 'name' AS name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-PRI-002-RC06';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_002_rc07 AS
SELECT
    r.server,
    j.value ->> 'event_name' AS event_name,
    j.value ->> 'package' AS package,
    j.value ->> 'session_name' AS session_name,
    j.value ->> 'startup_state' AS startup_state,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-PRI-002-RC07';

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_002_rc09 AS
SELECT
    r.server,
    j.value ->> 'buffer_count' AS buffer_count,
    j.value ->> 'buffer_size' AS buffer_size,
    j.value ->> 'event_count' AS event_count,
    j.value ->> 'is_default' AS is_default,
    j.value ->> 'max_file_size_mb' AS max_file_size_mb,
    j.value ->> 'start_time' AS start_time,
    j.value ->> 'status' AS status,
    j.value ->> 'status_desc' AS status_desc,
    j.value ->> 'stop_time' AS stop_time,
    j.value ->> 'trace_file_path' AS trace_file_path,
    j.value ->> 'trace_id' AS trace_id,
    j.value ->> 'trace_type' AS trace_type,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name = 'SEC-SQL-PRI-002-RC09';

