-- 6240_perf_tx_010_rc02_resolution_path.sql
-- PERF-SQL-TX-010-RC02 was created (6210) with a detection path/step but NO
-- resolution path. rootcause.v_rootcauses inner-joins
--   root_causes -> detection_paths -> detection_steps -> vendors
--                -> resolution_paths -> resolution_path_steps -> resolution_steps
--                -> risk_level
-- so a root cause with no resolution_paths is filtered out entirely. That is why
--   SELECT * FROM rootcause.v_rootcauses WHERE root_cause_id='PERF-SQL-TX-010-RC02'
-- returned nothing. This adds a sqlserver resolution path for RC02 modeled on the
-- RC01 path ("Review and manage active transactions"): an investigate step that
-- additionally surfaces each request's execution plan, plus the existing KILL step.
--
-- Idempotent: every object is looked up first and only created when missing; IDs
-- come from the table sequences (never hard-coded). risk_level 'medium' is a valid
-- rootcause.risk_level value (join is on rp.risk_level::bpchar).
DO $do$
DECLARE
  v_path_id    integer;
  v_review_id  integer;
  v_kill_id    integer;
  v_review_sql text := $q$SELECT
    s.session_id, s.login_name, s.host_name, s.program_name,
    DB_NAME(r.database_id) AS database_name, r.status, r.command, r.wait_type,
    NULLIF(r.blocking_session_id, 0) AS blocking_session_id,
    r.total_elapsed_time / 1000 AS elapsed_sec,
    SUBSTRING(t.text, 1, 500) AS query_text,
    qp.query_plan AS execution_plan_xml
FROM sys.dm_exec_requests r
JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) t
OUTER APPLY sys.dm_exec_text_query_plan(r.plan_handle, r.statement_start_offset, r.statement_end_offset) qp
WHERE s.is_user_process = 1 AND r.total_elapsed_time > 30000
ORDER BY r.total_elapsed_time DESC$q$;
BEGIN
  -- 1) investigate step (RC02-specific: includes the execution plan)
  SELECT id INTO v_review_id FROM rootcause.resolution_steps
   WHERE vendor_slug = 'sqlserver'
     AND name = 'Review active transactions with execution plans';
  IF v_review_id IS NULL THEN
     INSERT INTO rootcause.resolution_steps
         (vendor_slug, step_type, name, content, risk_level,
          requires_confirmation, is_reversible, estimated_duration, created_at)
     VALUES
         ('sqlserver', 'investigate', 'Review active transactions with execution plans',
          jsonb_build_object(
             'sql', v_review_sql,
             'description', 'Identify transactions running longer than 30 seconds and inspect each one''s execution plan (execution_plan_xml) to find expensive operators, missing indexes, or bad estimates. Check for blocking chains via blocking_session_id.'),
          'low', false, true, '2-5 min', now())
     RETURNING id INTO v_review_id;
  END IF;

  -- 2) kill step: reuse the existing RC01 KILL step if present, else create it
  SELECT id INTO v_kill_id FROM rootcause.resolution_steps
   WHERE vendor_slug = 'sqlserver'
     AND name = 'Kill problematic long-running transactions'
   ORDER BY id LIMIT 1;
  IF v_kill_id IS NULL THEN
     INSERT INTO rootcause.resolution_steps
         (vendor_slug, step_type, name, content, risk_level,
          requires_confirmation, is_reversible, estimated_duration, created_at)
     VALUES
         ('sqlserver', 'instruct', 'Kill problematic long-running transactions',
          jsonb_build_object('sql', 'KILL {session_id};', 'parameters', jsonb_build_array('session_id'),
             'description', 'Kill specific long-running or blocking transactions. Use KILL {session_id} WITH STATUSONLY to check rollback progress first.'),
          'medium', true, false, '1 min', now())
     RETURNING id INTO v_kill_id;
  END IF;

  -- 3) resolution path for RC02 (sqlserver)
  SELECT id INTO v_path_id FROM rootcause.resolution_paths
   WHERE root_cause_id = 'PERF-SQL-TX-010-RC02' AND vendor_slug = 'sqlserver'
     AND slug = 'manage-active-tx-with-plan-sqlserver';
  IF v_path_id IS NULL THEN
     INSERT INTO rootcause.resolution_paths
         (root_cause_id, vendor_slug, name, slug, description, execution_mode,
          risk_level, risk_description, status, is_active, created_at, updated_at)
     VALUES
         ('PERF-SQL-TX-010-RC02', 'sqlserver',
          'Review and manage active transactions (with execution plans)',
          'manage-active-tx-with-plan-sqlserver',
          'Identify long-running transactions, analyse their execution plans, and kill if necessary',
          'semi_automatic', 'medium',
          'Killing a transaction rolls back its work; review the plan and blocking chain before acting.',
          'active', true, now(), now())
     RETURNING id INTO v_path_id;
  END IF;

  -- 4) link steps to the path (ordered: investigate -> kill)
  IF NOT EXISTS (SELECT 1 FROM rootcause.resolution_path_steps
                  WHERE resolution_path_id = v_path_id AND resolution_step_id = v_review_id) THEN
     INSERT INTO rootcause.resolution_path_steps
         (resolution_path_id, resolution_step_id, step_order, on_success, on_failure, created_at)
     VALUES (v_path_id, v_review_id, 1, 'next', 'stop', now());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM rootcause.resolution_path_steps
                  WHERE resolution_path_id = v_path_id AND resolution_step_id = v_kill_id) THEN
     INSERT INTO rootcause.resolution_path_steps
         (resolution_path_id, resolution_step_id, step_order, on_success, on_failure, created_at)
     VALUES (v_path_id, v_kill_id, 2, 'done', 'stop', now());
  END IF;
END
$do$;

-- verify:
-- SELECT DISTINCT root_cause_id, vendor_name, step_name, risk_level
-- FROM rootcause.v_rootcauses WHERE root_cause_id = 'PERF-SQL-TX-010-RC02';
