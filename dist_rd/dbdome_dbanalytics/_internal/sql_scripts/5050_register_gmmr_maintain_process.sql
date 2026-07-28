-- ============================================================
-- Register the 'gmmr_maintain' scheduled process.
-- Runs monitoring.gmmr_maintain() hourly: create upcoming monthly partitions,
-- drop partitions past retention, and dedup identical metric_metadata snapshots.
-- Resolved to processes.gmmr_maintenance.run_gmmr_maintain via
-- job_operation_scheduler.get_function_by_name (requires the matching code build).
-- Idempotent: only inserts if the process isn't already registered.
-- ============================================================

INSERT INTO metrics.registered_processes (process_name, interval, is_active, description)
SELECT 'gmmr_maintain', 3600, true,
       'Partition maintenance + duplicate cleanup for general_metric_metadata_results'
WHERE NOT EXISTS (
    SELECT 1 FROM metrics.registered_processes WHERE process_name = 'gmmr_maintain'
);
