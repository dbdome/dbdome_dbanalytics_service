-- ============================================================
-- rootcause change: PERF-SQL-QE-001-RC04 (sqlserver) detection content
--
-- Sets the detection CONTENT (the SQL the collector runs) for the SQL Server
-- steps of PERF-SQL-QE-001-RC04 to the "active transactions with execution
-- plans" query that was copied from PERF-SQL-TX-010-RC02.
--
-- Self-contained: the query is embedded as a jsonb literal, so this reproduces
-- the change on any environment WITHOUT depending on PERF-SQL-TX-010-RC02.
-- Portable: targets by root_cause_id + vendor (not by numeric step id).
-- Idempotent: re-running sets the same value. Updates BOTH sqlserver steps of
-- this root cause (ids 2230, 2231 in the source DB).
--
-- Only the content column is changed; expected, name, etc. are left as-is.
-- Generated 06 Jul 2026 from the live value in rootcause.detection_steps.
-- ============================================================

BEGIN;

UPDATE rootcause.detection_steps AS d
SET content = $qe001rc04${"sql": "SELECT\n    s.session_id,\n    r.status,\n    s.login_name,\n    s.host_name,\n    s.program_name,\n    DB_NAME(r.database_id)                          AS database_name,\n    r.command,\n    r.wait_type,\n    r.wait_time,\n    NULLIF(r.blocking_session_id, 0)               AS blocking_session_id,\n    r.cpu_time                                     AS cpu_ms,\n    r.total_elapsed_time                           AS elapsed_ms,\n    r.reads,\n    r.writes,\n    r.logical_reads,\n    r.start_time                                   AS request_start_time,\n    SUBSTRING(qt.text, (r.statement_start_offset / 2) + 1,\n        ((CASE r.statement_end_offset WHEN -1 THEN DATALENGTH(qt.text)\n          ELSE r.statement_end_offset END - r.statement_start_offset) / 2) + 1) AS query_text,\n    qp.query_plan                                  AS execution_plan_xml\nFROM sys.dm_exec_requests AS r WITH (NOLOCK)\nJOIN sys.dm_exec_sessions AS s WITH (NOLOCK)\n     ON s.session_id = r.session_id\nOUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS qt\nOUTER APPLY sys.dm_exec_text_query_plan(r.plan_handle, r.statement_start_offset, r.statement_end_offset) AS qp\nWHERE s.is_user_process = 1\n  AND s.session_id <> @@SPID\n  AND ISNULL(s.login_name, '') NOT LIKE '%dbdome%'\nORDER BY r.total_elapsed_time DESC;"}$qe001rc04$::jsonb
FROM rootcause.detection_path_steps ps
JOIN rootcause.detection_paths dp ON dp.id = ps.detection_path_id
WHERE ps.detection_step_id = d.id
  AND dp.root_cause_id = 'PERF-SQL-QE-001-RC04'
  AND d.vendor_slug     = 'sqlserver';

COMMIT;   -- or ROLLBACK;
