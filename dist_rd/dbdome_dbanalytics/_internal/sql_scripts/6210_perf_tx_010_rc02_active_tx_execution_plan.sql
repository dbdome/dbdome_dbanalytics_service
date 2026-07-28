-- 6210_perf_tx_010_rc02_active_tx_execution_plan.sql
-- NEW root cause  PERF-SQL-TX-010-RC02 (sqlserver): "Active transactions snapshot with execution plans".
-- Sibling of PERF-SQL-TX-010-RC01 (6200) but additionally returns EACH active request's execution
-- plan as XML TEXT via sys.dm_exec_text_query_plan(plan_handle, stmt_start, stmt_end). Excludes the
-- monitoring session itself ( s.session_id <> @@SPID ) and the dbdome account ( NOT LIKE '%dbdome%' ).
--
-- Idempotent: creates the root_cause / detection_path / detection_step / link only when missing,
-- and refreshes the step SQL on re-run. IDs come from the table sequences (never hard-coded).
DO $do$
DECLARE
  v_path_id integer;
  v_step_id integer;
  v_sql     text := $q$SELECT
    s.session_id,
    r.status,
    s.login_name,
    s.host_name,
    s.program_name,
    DB_NAME(r.database_id)                          AS database_name,
    r.command,
    r.wait_type,
    r.wait_time,
    NULLIF(r.blocking_session_id, 0)               AS blocking_session_id,
    r.cpu_time                                     AS cpu_ms,
    r.total_elapsed_time                           AS elapsed_ms,
    r.reads,
    r.writes,
    r.logical_reads,
    r.start_time                                   AS request_start_time,
    SUBSTRING(qt.text, (r.statement_start_offset / 2) + 1,
        ((CASE r.statement_end_offset WHEN -1 THEN DATALENGTH(qt.text)
          ELSE r.statement_end_offset END - r.statement_start_offset) / 2) + 1) AS query_text,
    qp.query_plan                                  AS execution_plan_xml
FROM sys.dm_exec_requests AS r WITH (NOLOCK)
JOIN sys.dm_exec_sessions AS s WITH (NOLOCK)
     ON s.session_id = r.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS qt
OUTER APPLY sys.dm_exec_text_query_plan(r.plan_handle, r.statement_start_offset, r.statement_end_offset) AS qp
WHERE s.is_user_process = 1
  AND s.session_id <> @@SPID
  AND ISNULL(s.login_name, '') NOT LIKE '%dbdome%'
ORDER BY r.total_elapsed_time DESC;$q$;
BEGIN
  -- 1) root cause
  INSERT INTO rootcause.root_causes
      (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable, created_at, updated_at)
  VALUES
      ('PERF-SQL-TX-010-RC02', 'PERF-SQL-TX-010',
       'Active transactions snapshot with execution plans',
       'active-transactions-snapshot-with-execution-plans',
       'Point-in-time snapshot of active user requests that also returns each request''s execution plan as XML text (sys.dm_exec_text_query_plan), for plan-level diagnosis of expensive or blocking statements. Excludes the monitoring session (@@SPID) and the dbdome service account.',
       ARRAY['performance','monitoring','transactions','execution-plan','query-plan'],
       ARRAY['sqlserver'], now(), now())
  ON CONFLICT (root_cause_id) DO NOTHING;

  -- 2) detection path (sqlserver)
  SELECT id INTO v_path_id FROM rootcause.detection_paths
   WHERE root_cause_id = 'PERF-SQL-TX-010-RC02' AND vendor_slug = 'sqlserver'
     AND name = 'Active transactions with execution plans (sqlserver)';
  IF v_path_id IS NULL THEN
     INSERT INTO rootcause.detection_paths
         (root_cause_id, vendor_slug, name, description, path_type, is_active, created_at, updated_at)
     VALUES
         ('PERF-SQL-TX-010-RC02', 'sqlserver',
          'Active transactions with execution plans (sqlserver)',
          'Retrieves all running user requests on SQL Server, each with its execution plan as XML text',
          'primary', true, now(), now())
     RETURNING id INTO v_path_id;
  END IF;

  -- 3) detection step (sqlserver) holding the SQL
  SELECT id INTO v_step_id FROM rootcause.detection_steps
   WHERE vendor_slug = 'sqlserver' AND name = 'Retrieve active transactions with execution plan';
  IF v_step_id IS NULL THEN
     INSERT INTO rootcause.detection_steps
         (vendor_slug, step_type, name, content, expected, parameters, created_at)
     VALUES
         ('sqlserver', 'sql_query', 'Retrieve active transactions with execution plan',
          jsonb_build_object('sql', v_sql),
          jsonb_build_object('severity','low','condition','row_count >= 0',
                             'description','Active user requests with their execution plan as XML text'),
          NULL, now())
     RETURNING id INTO v_step_id;
  ELSE
     UPDATE rootcause.detection_steps
        SET content = jsonb_set(content, '{sql}', to_jsonb(v_sql))
      WHERE id = v_step_id;
  END IF;

  -- 4) link path -> step
  IF NOT EXISTS (SELECT 1 FROM rootcause.detection_path_steps
                  WHERE detection_path_id = v_path_id AND detection_step_id = v_step_id) THEN
     INSERT INTO rootcause.detection_path_steps
         (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action, created_at)
     VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out', now());
  END IF;
END
$do$;

-- verify:
-- SELECT dp.root_cause_id, dp.vendor_slug,
--        (ds.content->>'sql') LIKE '%dm_exec_text_query_plan%' AS has_plan,
--        (ds.content->>'sql') LIKE '%@@SPID%'                  AS excludes_self
-- FROM rootcause.detection_paths dp
-- JOIN rootcause.detection_path_steps dps ON dps.detection_path_id = dp.id
-- JOIN rootcause.detection_steps ds ON ds.id = dps.detection_step_id
-- WHERE dp.root_cause_id = 'PERF-SQL-TX-010-RC02' AND dp.vendor_slug = 'sqlserver';
