-- =============================================================================
-- 7360_create_perf_sql_tx_010_rc02.sql
--
-- Idempotent CREATE of PERF-SQL-TX-010-RC02 -- "Active transactions snapshot with
-- execution plans" (SQL Server). Point-in-time capture of active user requests
-- with each request's execution plan (sys.dm_exec_text_query_plan) as XML text;
-- feeds the execution-plan agent (monitoring.parse_execution_plan) for plan-level
-- diagnosis of expensive / blocking statements. Excludes @@SPID and dbdome logins.
--
-- Creates: issue PERF-SQL-TX-010 + root_cause RC02 + the sqlserver detection
-- (path -> step) + the resolution (path -> 2 steps). Safe to re-run: issue/root
-- cause upsert ON CONFLICT DO NOTHING; detection/resolution insert only when the
-- (root_cause_id, vendor_slug) path is absent.
--
-- PLAINTEXT authoring artifact -- content is encrypted at rest by the encrypt
-- trigger / install-time taxonomy pass when a session key is present.
-- =============================================================================

-- 1) issue
INSERT INTO rootcause.issues (issue_id,domain_code,database_type_code,area_code,name,slug,description,category_id) VALUES
('PERF-SQL-TX-010','PERF','SQL','TX','Active Transactions Monitoring','active-transactions-monitoring','Retrieves all currently running transactions with login, program, database, query text, and duration. Provides baseline visibility into what is executing on the server at any point in time.',NULL)
ON CONFLICT (issue_id) DO NOTHING;

-- 2) root_cause
INSERT INTO rootcause.root_causes (root_cause_id,issue_id,name,slug,description,topics,vendors_applicable,vendor_considerations,search_text) VALUES
('PERF-SQL-TX-010-RC02','PERF-SQL-TX-010','Active transactions snapshot with execution plans','active-transactions-snapshot-with-execution-plans','Point-in-time snapshot of active user requests that also returns each request''s execution plan as XML text (sys.dm_exec_text_query_plan), for plan-level diagnosis of expensive or blocking statements. Excludes the monitoring session (@@SPID) and the dbdome service account.',ARRAY['performance','monitoring','transactions','execution-plan','query-plan'],ARRAY['sqlserver'],NULL,NULL)
ON CONFLICT (root_cause_id) DO NOTHING;

-- 3) sqlserver detection (step -> path -> link); vendors_applicable extended
DO $do$
DECLARE lstep int; lpath int;
BEGIN
  IF EXISTS (SELECT 1 FROM rootcause.detection_paths
             WHERE root_cause_id='PERF-SQL-TX-010-RC02' AND vendor_slug='sqlserver') THEN
    RAISE NOTICE 'PERF-SQL-TX-010-RC02 sqlserver detection already present - skip';
  ELSE
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
      VALUES ('sqlserver', 'sql_query', 'Retrieve active transactions with execution plan',
              jsonb_build_object('sql', $sql$SELECT
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
ORDER BY r.total_elapsed_time DESC;$sql$),
              $j${"severity": "low", "condition": "row_count >= 0", "description": "Active user requests with their execution plan as XML text"}$j$::jsonb)
      RETURNING id INTO lstep;
    INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
      VALUES ('PERF-SQL-TX-010-RC02', 'sqlserver', 'Active transactions with execution plans (sqlserver)', 'Retrieves all running user requests on SQL Server, each with its execution plan as XML text', 'primary', true)
      RETURNING id INTO lpath;
    INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
      VALUES (lpath, lstep, 1, 'confirmed', 'ruled_out');
    UPDATE rootcause.root_causes
       SET vendors_applicable = (SELECT array(SELECT DISTINCT unnest(vendors_applicable || ARRAY['sqlserver']) ORDER BY 1))
     WHERE root_cause_id='PERF-SQL-TX-010-RC02' AND NOT ('sqlserver' = ANY(vendors_applicable));
    RAISE NOTICE 'created PERF-SQL-TX-010-RC02 sqlserver detection';
  END IF;
END $do$;

-- 4) resolution (2 steps -> path -> links)
DO $do$
DECLARE rpath int; s1 int; s2 int;
BEGIN
  IF EXISTS (SELECT 1 FROM rootcause.resolution_paths WHERE root_cause_id='PERF-SQL-TX-010-RC02' AND vendor_slug='sqlserver') THEN
    RAISE NOTICE 'PERF-SQL-TX-010-RC02 resolution already present - skip';
  ELSE
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, rollback, risk_level, requires_confirmation, is_reversible, estimated_duration)
      VALUES ('sqlserver', 'investigate', 'Review active transactions with execution plans', $j${"sql": "SELECT\n    s.session_id, s.login_name, s.host_name, s.program_name,\n    DB_NAME(r.database_id) AS database_name, r.status, r.command, r.wait_type,\n    NULLIF(r.blocking_session_id, 0) AS blocking_session_id,\n    r.total_elapsed_time / 1000 AS elapsed_sec,\n    SUBSTRING(t.text, 1, 500) AS query_text,\n    qp.query_plan AS execution_plan_xml\nFROM sys.dm_exec_requests r\nJOIN sys.dm_exec_sessions s ON r.session_id = s.session_id\nOUTER APPLY sys.dm_exec_sql_text(r.sql_handle) t\nOUTER APPLY sys.dm_exec_text_query_plan(r.plan_handle, r.statement_start_offset, r.statement_end_offset) qp\nWHERE s.is_user_process = 1 AND r.total_elapsed_time > 30000\nORDER BY r.total_elapsed_time DESC", "description": "Identify transactions running longer than 30 seconds and inspect each one's execution plan (execution_plan_xml) to find expensive operators, missing indexes, or bad estimates. Check for blocking chains via blocking_session_id."}$j$::jsonb, NULL, 'low', false, true, '2-5 min')
      RETURNING id INTO s1;
    INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, rollback, risk_level, requires_confirmation, is_reversible, estimated_duration)
      VALUES ('sqlserver', 'instruct', 'Kill problematic long-running transactions', $j${"sql": "KILL {session_id};", "parameters": ["session_id"], "description": "Kill specific long-running or blocking transactions. Use KILL {session_id} WITH STATUSONLY to check rollback progress first."}$j$::jsonb, NULL, 'medium', true, false, '2 minutes')
      RETURNING id INTO s2;
    INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, risk_description, status, prerequisites, is_active)
      VALUES ('PERF-SQL-TX-010-RC02', 'sqlserver', 'Review and manage active transactions (with execution plans)', 'manage-active-tx-with-plan-sqlserver', 'Identify long-running transactions, analyse their execution plans, and kill if necessary', 'semi_automatic', 'medium', 'Killing a transaction rolls back its work; review the plan and blocking chain before acting.', 'active', NULL, true)
      RETURNING id INTO rpath;
    INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order, condition, on_success, on_failure, notes)
      VALUES (rpath, s1, 1, NULL, 'next', 'stop', NULL),
             (rpath, s2, 2, NULL, 'done', 'stop', NULL);
    RAISE NOTICE 'created PERF-SQL-TX-010-RC02 resolution';
  END IF;
END $do$;
