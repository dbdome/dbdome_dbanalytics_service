-- =============================================================================
-- 7350_rc02_strip_execution_plan_xml.sql
--
-- SEC-SQL-ACC-011-RC02 captures the sql_text of active/recent statements. When a
-- captured statement is itself a plan-fetching query (it aliases a column as
-- 'execution_plan_xml'), that literal string ends up inside RC02's sql_text.
-- Strip it: wrap the RC02 sqlserver detection in an outer SELECT that applies
-- REPLACE(sql_text, 'execution_plan_xml', '') while preserving every column.
--
-- Adaptive + idempotent: reads the CURRENT decrypted RC02 sqlserver SQL and wraps
-- it only if not already wrapped, so it also self-heals after 5047 re-seeds the
-- raw query. The BEFORE-UPDATE encrypt trigger re-encrypts content on write
-- (enc() is idempotent, so expected/parameters are untouched). Runs after 5047.
-- =============================================================================
DO $$
DECLARE
    v_step  int;
    v_sql   text;
    v_cols  text := 'q.session_id, q.status, q.activity, q.login_name, q.host_name, '
                 || 'q.program_name, q.database_name, q.command, q.wait_type, q.wait_time, '
                 || 'q.blocking_session_id, q.cpu_ms, q.elapsed_ms, q.reads, q.writes, '
                 || 'q.logical_reads, q.percent_complete, q.open_tran_count, q.tran_begin_time, '
                 || 'q.request_start_time, q.last_request_start_time, q.last_request_end_time, '
                 || 'q.login_time';
    v_wrapped text;
BEGIN
    SELECT ds.id, ds.content->>'sql'
      INTO v_step, v_sql
    FROM rootcause.detection_paths dp
    JOIN rootcause.detection_path_steps dps ON dps.detection_path_id = dp.id
    JOIN rootcause.detection_steps ds ON ds.id = dps.detection_step_id
    WHERE dp.root_cause_id = 'SEC-SQL-ACC-011-RC02' AND dp.vendor_slug = 'sqlserver'
    LIMIT 1;

    -- content may be encrypted at rest; get the plaintext SQL via dec()
    IF v_sql IS NULL OR v_sql = '' OR left(v_sql,1) <> 'S' THEN
        SELECT (rootcause.dec(ds.content))->>'sql' INTO v_sql
        FROM rootcause.detection_steps ds WHERE ds.id = v_step;
    END IF;

    IF v_step IS NULL OR v_sql IS NULL THEN
        RAISE NOTICE '7350: RC02 sqlserver detection not found - skip'; RETURN;
    END IF;
    IF position('REPLACE(q.sql_text' in v_sql) > 0 THEN
        RAISE NOTICE '7350: RC02 already strips execution_plan_xml - skip'; RETURN;
    END IF;

    v_wrapped := 'SELECT ' || v_cols || E',\n'
              || '       REPLACE(q.sql_text, N''execution_plan_xml'', N'''') AS sql_text' || E'\n'
              || 'FROM (' || E'\n' || v_sql || E'\n' || ') AS q';

    UPDATE rootcause.detection_steps
       SET content = jsonb_build_object('sql', v_wrapped)
     WHERE id = v_step;

    RAISE NOTICE '7350: wrapped RC02 sqlserver detection (step %) to strip execution_plan_xml', v_step;
END $$;
