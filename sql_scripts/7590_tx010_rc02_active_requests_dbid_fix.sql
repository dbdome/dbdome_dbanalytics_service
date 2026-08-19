-- =============================================================================
-- 7590_tx010_rc02_active_requests_dbid_fix.sql
-- Replace the PERF-SQL-TX-010-RC02 (sqlserver) detection SQL with the operator's
-- active-requests-with-execution-plan query (2026-08-18), including the
-- database_name resolution fix.
--
-- WHAT CHANGED vs. the prior text
--   * database_name is now resolved robustly from the database id:
--       DB_NAME(COALESCE(NULLIF(r.database_id, 0), s.database_id))
--     r.database_id is 0 for requests with no active DB context, and DB_NAME(0)
--     is NULL ("host did not resolve"). NULLIF drops the meaningless 0 and falls
--     back to the session's database id (s.database_id, 2012+). Both are numeric
--     ids turned into a name by DB_NAME.
--   * richer request columns (last_wait_type, wait_resource, row_count, dop,
--     granted_query_memory, percent_complete, estimated_completion_time,
--     transaction_id/isolation, open_transaction_count, query_hash,
--     query_plan_hash) and a :threshold_ms elapsed filter.
--
-- PARAMETER
--   The query contains the DBDOME placeholder :threshold_ms, substituted by the
--   collector before execution. This script sets a step parameter default of 0
--   (return every active user request; elapsed >= 0). Raise it to collect only
--   long-running requests, e.g. {"threshold_ms": 5000} for >= 5 s. Without the
--   parameter the placeholder would remain literal and the query would fail.
--
-- PERMISSION
--   Every DMV here (dm_exec_requests/sessions/sql_text/text_query_plan) needs
--   VIEW SERVER STATE on the target. A login lacking it fails with 300/297
--   ("VIEW SERVER STATE permission was denied") in ~16 ms. See
--   provisioning/provision_dbdome_mon_usr_sqlserver.sql.
--
-- ENCRYPTION: same contract as 7490/7570 - read via rootcause.dec(), write via
-- rootcause.enc(), reached through EXECUTE so this parses where those functions
-- do not exist; refuses to write plaintext over ciphertext without a key.
-- Idempotent: a step already carrying this exact text + parameter is skipped.
-- =============================================================================

DO $mig$
DECLARE
    v_name constant text := 'Retrieve active transactions with execution plan';
    v_sql  constant text := $q$SELECT
    s.session_id,
    r.status,
    s.login_name,
    s.host_name,
    s.program_name,
    DB_NAME(COALESCE(NULLIF(r.database_id, 0), s.database_id)) AS database_name,
    r.command,
    r.wait_type,
    r.wait_time,
    r.last_wait_type,
    r.wait_resource,
    NULLIF(r.blocking_session_id, 0)                AS blocking_session_id,
    r.cpu_time                                      AS cpu_ms,
    r.total_elapsed_time                            AS elapsed_ms,
    r.reads,
    r.writes,
    r.logical_reads,
    r.row_count                                     AS request_row_count,
    r.dop,
    r.granted_query_memory                          AS granted_query_memory_pages,
    r.percent_complete,
    r.estimated_completion_time                     AS estimated_completion_ms,
    r.transaction_id,
    r.transaction_isolation_level,
    s.open_transaction_count,
    CONVERT(varchar(34), r.query_hash, 1)           AS query_hash,
    CONVERT(varchar(34), r.query_plan_hash, 1)      AS query_plan_hash,
    r.start_time                                    AS request_start_time,
    SUBSTRING(qt.text, (r.statement_start_offset / 2) + 1,
        ((CASE r.statement_end_offset WHEN -1 THEN DATALENGTH(qt.text)
          ELSE r.statement_end_offset END - r.statement_start_offset) / 2) + 1) AS query_text,
    qp.query_plan                                   AS execution_plan_xml
FROM sys.dm_exec_requests AS r WITH (NOLOCK)
JOIN sys.dm_exec_sessions AS s WITH (NOLOCK)
     ON s.session_id = r.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS qt
OUTER APPLY sys.dm_exec_text_query_plan(r.plan_handle, r.statement_start_offset, r.statement_end_offset) AS qp
WHERE s.is_user_process = 1
  AND s.session_id <> @@SPID
  AND ISNULL(s.login_name, '') NOT LIKE '%dbdome%'
  AND r.total_elapsed_time >= :threshold_ms
ORDER BY r.total_elapsed_time DESC$q$;
    v_params constant jsonb := '{"threshold_ms": 0}'::jsonb;

    v_enc    boolean := to_regprocedure('rootcause.enc(jsonb)') IS NOT NULL;
    v_haskey boolean := nullif(current_setting('rootcause.k', true), '') IS NOT NULL;
    v_cur_sql    text;
    v_cur_params text;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM rootcause.detection_steps
                    WHERE vendor_slug='sqlserver' AND name=v_name) THEN
        RAISE NOTICE '7590: step "%" not present - nothing to do', v_name;
        RETURN;
    END IF;

    IF v_enc AND NOT v_haskey THEN
        RAISE EXCEPTION
            '7590: this install encrypts detection_steps (7300 applied) but the session has no key. '
            'Connect as a role holding the role-default (dbdome_adm / dbdome_mon_usr / dbexpert_adm / '
            'dbdome_engine), or run: SELECT set_config(''rootcause.k'', ''<DBDOME_SECRET_KEY>'', false);';
    END IF;

    -- read current, through decryption where applicable
    IF v_enc THEN
        EXECUTE 'SELECT rootcause.dec(content)->>''sql'', rootcause.dec(coalesce(parameters,''null''::jsonb))::text '
                'FROM rootcause.detection_steps WHERE vendor_slug=''sqlserver'' AND name=$1'
            INTO v_cur_sql, v_cur_params USING v_name;
    ELSE
        SELECT content->>'sql', coalesce(parameters::text,'null')
          INTO v_cur_sql, v_cur_params
          FROM rootcause.detection_steps WHERE vendor_slug='sqlserver' AND name=v_name;
    END IF;

    IF v_cur_sql IS NOT DISTINCT FROM v_sql
       AND v_cur_params IS NOT DISTINCT FROM v_params::text THEN
        RAISE NOTICE '7590: already the specified text + parameter - no change';
        RETURN;
    END IF;

    -- write content AND step parameters
    IF v_enc THEN
        EXECUTE 'UPDATE rootcause.detection_steps '
                'SET content = rootcause.enc(jsonb_build_object(''sql'', $1)), '
                '    parameters = rootcause.enc($2) '
                'WHERE vendor_slug=''sqlserver'' AND name=$3'
            USING v_sql, v_params, v_name;
    ELSE
        UPDATE rootcause.detection_steps
           SET content = jsonb_build_object('sql', v_sql),
               parameters = v_params
         WHERE vendor_slug='sqlserver' AND name=v_name;
    END IF;

    -- read back and assert
    IF v_enc THEN
        EXECUTE 'SELECT rootcause.dec(content)->>''sql'' FROM rootcause.detection_steps '
                'WHERE vendor_slug=''sqlserver'' AND name=$1' INTO v_cur_sql USING v_name;
    ELSE
        SELECT content->>'sql' INTO v_cur_sql FROM rootcause.detection_steps
         WHERE vendor_slug='sqlserver' AND name=v_name;
    END IF;

    IF v_cur_sql IS DISTINCT FROM v_sql
       OR position('COALESCE(NULLIF(r.database_id, 0), s.database_id)' in v_cur_sql) = 0 THEN
        RAISE EXCEPTION '7590: verification FAILED - stored SQL is not the expected version';
    END IF;

    RAISE NOTICE '7590: stored (% chars, storage=%); threshold_ms default=0',
                 length(v_sql), CASE WHEN v_enc THEN 'encrypted' ELSE 'plaintext' END;
END $mig$;
