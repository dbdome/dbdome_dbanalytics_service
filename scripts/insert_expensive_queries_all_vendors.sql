-- =============================================================================
-- PERF-SQL-QE-001-RC15 — Expensive queries (high CPU per execution)
-- All vendors: sqlserver, oracle, postgresql, mysql
-- =============================================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════
-- CLEANUP: Remove previous sqlserver-only RC15
-- ═══════════════════════════════════════════════════════════════
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id = 'PERF-SQL-QE-001-RC15');
DELETE FROM rootcause.detection_paths WHERE root_cause_id = 'PERF-SQL-QE-001-RC15';
DELETE FROM rootcause.detection_steps WHERE id IN (12180);  -- previous sqlserver-only step
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id = 'PERF-SQL-QE-001-RC15');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id = 'PERF-SQL-QE-001-RC15';
DELETE FROM rootcause.resolution_steps WHERE id IN (30070);  -- previous sqlserver-only step
DELETE FROM rootcause.root_causes WHERE root_cause_id = 'PERF-SQL-QE-001-RC15';
DELETE FROM metrics.custom_metrics WHERE metric_name = 'PERF-SQL-QE-001-RC15';

-- ═══════════════════════════════════════════════════════════════
-- 1. ROOT CAUSE
-- ═══════════════════════════════════════════════════════════════
INSERT INTO rootcause.root_causes (
    root_cause_id, issue_id, name, slug, description,
    topics, vendors_applicable
) VALUES (
    'PERF-SQL-QE-001-RC15',
    'PERF-SQL-QE-001',
    'Expensive queries (high CPU per execution)',
    'expensive-queries-high-cpu',
    'Queries consuming disproportionate CPU time per execution. Identifies resource-intensive statements ranked by average CPU cost, including the originating login, host, and program name where available.',
    ARRAY['expensive queries', 'high cpu', 'query stats', 'plan cache', 'top queries', 'resource intensive', 'slow queries'],
    ARRAY['sqlserver', 'oracle', 'postgresql', 'mysql']
);

-- ═══════════════════════════════════════════════════════════════
-- 2. DETECTION STEPS (one per vendor)
-- ═══════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────
-- SQL Server
-- ─────────────────────────────────────────────
INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected, parameters)
VALUES (
    'sqlserver', 'query',
    'Detect expensive queries by average CPU (sqlserver)',
    '{"sql": "SELECT qs.total_worker_time / qs.execution_count AS avg_cpu, qs.total_worker_time AS total_cpu, qs.execution_count, qs.total_elapsed_time / qs.execution_count AS avg_duration_ms, qs.last_execution_time, COALESCE(es1.login_name, es2.login_name, ''N/A'') AS login_name, COALESCE(es1.host_name, es2.host_name, ''N/A'') AS host_name, COALESCE(es1.program_name, es2.program_name, ''N/A'') AS program_name, SUBSTRING(qt.text, (qs.statement_start_offset/2)+1, ((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(qt.text) ELSE qs.statement_end_offset END - qs.statement_start_offset)/2)+1) AS query_text FROM sys.dm_exec_query_stats qs CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt LEFT JOIN sys.dm_exec_connections ec ON ec.most_recent_sql_handle = qs.sql_handle LEFT JOIN sys.dm_exec_sessions es1 ON es1.session_id = ec.session_id LEFT JOIN sys.dm_exec_requests r ON r.sql_handle = qs.sql_handle LEFT JOIN sys.dm_exec_sessions es2 ON es2.session_id = r.session_id WHERE qs.execution_count > 0 ORDER BY avg_cpu DESC"}'::jsonb,
    '{"condition": "row_count > 0", "description": "Returns the most expensive queries by average CPU time per execution with login/host/program attribution"}'::jsonb,
    NULL
);

-- ─────────────────────────────────────────────
-- Oracle
-- ─────────────────────────────────────────────
INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected, parameters)
VALUES (
    'oracle', 'query',
    'Detect expensive queries by average CPU (oracle)',
    '{"sql": "SELECT s.sql_id, s.cpu_time / GREATEST(s.executions, 1) AS avg_cpu_us, s.cpu_time AS total_cpu_us, s.executions AS execution_count, s.elapsed_time / GREATEST(s.executions, 1) AS avg_elapsed_us, s.last_active_time, NVL(sess.username, ''N/A'') AS login_name, NVL(sess.machine, ''N/A'') AS host_name, NVL(sess.program, ''N/A'') AS program_name, SUBSTR(s.sql_text, 1, 200) AS query_text FROM v$sqlarea s LEFT JOIN v$session sess ON sess.sql_id = s.sql_id AND sess.status = ''ACTIVE'' WHERE s.executions > 0 ORDER BY avg_cpu_us DESC"}'::jsonb,
    '{"condition": "row_count > 0", "description": "Returns the most expensive queries by average CPU time from v$sqlarea with active session attribution"}'::jsonb,
    NULL
);

-- ─────────────────────────────────────────────
-- PostgreSQL
-- ─────────────────────────────────────────────
INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected, parameters)
VALUES (
    'postgresql', 'query',
    'Detect expensive queries by average CPU (postgresql)',
    '{"sql": "SELECT pss.queryid, ROUND((pss.total_exec_time / GREATEST(pss.calls, 1))::numeric, 2) AS avg_time_ms, ROUND(pss.total_exec_time::numeric, 2) AS total_time_ms, pss.calls AS execution_count, ROUND((pss.mean_exec_time)::numeric, 2) AS mean_exec_time_ms, pss.rows AS total_rows, pg_get_userbyid(pss.userid) AS login_name, d.datname AS database_name, LEFT(pss.query, 200) AS query_text FROM pg_stat_statements pss JOIN pg_database d ON d.oid = pss.dbid WHERE pss.calls > 0 ORDER BY avg_time_ms DESC"}'::jsonb,
    '{"condition": "row_count > 0", "description": "Returns the most expensive queries by average execution time from pg_stat_statements. Requires pg_stat_statements extension to be enabled."}'::jsonb,
    NULL
);

-- ─────────────────────────────────────────────
-- MySQL
-- ─────────────────────────────────────────────
INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected, parameters)
VALUES (
    'mysql', 'query',
    'Detect expensive queries by average CPU (mysql)',
    '{"sql": "SELECT DIGEST AS query_digest, SCHEMA_NAME AS database_name, COUNT_STAR AS execution_count, ROUND(AVG_TIMER_WAIT / 1000000000, 2) AS avg_time_ms, ROUND(SUM_TIMER_WAIT / 1000000000, 2) AS total_time_ms, ROUND(SUM_CPU_TIMER_WAIT / 1000000000, 2) AS total_cpu_ms, SUM_ROWS_EXAMINED AS total_rows_examined, SUM_ROWS_SENT AS total_rows_sent, FIRST_SEEN, LAST_SEEN, LEFT(DIGEST_TEXT, 200) AS query_text FROM performance_schema.events_statements_summary_by_digest WHERE COUNT_STAR > 0 AND SCHEMA_NAME IS NOT NULL ORDER BY avg_time_ms DESC"}'::jsonb,
    '{"condition": "row_count > 0", "description": "Returns the most expensive queries by average execution time from performance_schema statement digest summaries"}'::jsonb,
    NULL
);

-- ═══════════════════════════════════════════════════════════════
-- 3. DETECTION PATHS + PATH STEPS (one per vendor, two risk levels)
-- ═══════════════════════════════════════════════════════════════

DO $$
DECLARE
    v_vendors TEXT[] := ARRAY['sqlserver', 'oracle', 'postgresql', 'mysql'];
    v_vendor TEXT;
    v_step_id INT;
    v_path_id INT;
BEGIN
    FOREACH v_vendor IN ARRAY v_vendors
    LOOP
        -- Get the detection step for this vendor
        SELECT id INTO v_step_id
        FROM rootcause.detection_steps
        WHERE vendor_slug = v_vendor
          AND name = 'Detect expensive queries by average CPU (' || v_vendor || ')'
        ORDER BY id DESC LIMIT 1;

        -- Create detection path (high risk)
        INSERT INTO rootcause.detection_paths (
            root_cause_id, vendor_slug, name, description, path_type, is_active
        ) VALUES (
            'PERF-SQL-QE-001-RC15', v_vendor,
            'Detect expensive queries (' || v_vendor || ') - high',
            'Identifies most CPU-expensive queries from the query stats/plan cache for ' || v_vendor,
            'diagnostic', true
        ) RETURNING id INTO v_path_id;

        INSERT INTO rootcause.detection_path_steps (
            detection_path_id, detection_step_id, sequence,
            on_match_action, on_no_match_action
        ) VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');

        -- Create detection path (medium risk)
        INSERT INTO rootcause.detection_paths (
            root_cause_id, vendor_slug, name, description, path_type, is_active
        ) VALUES (
            'PERF-SQL-QE-001-RC15', v_vendor,
            'Detect expensive queries (' || v_vendor || ') - medium',
            'Identifies most CPU-expensive queries from the query stats/plan cache for ' || v_vendor,
            'diagnostic', true
        ) RETURNING id INTO v_path_id;

        INSERT INTO rootcause.detection_path_steps (
            detection_path_id, detection_step_id, sequence,
            on_match_action, on_no_match_action
        ) VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');

        RAISE NOTICE 'Created detection for %: step=%, paths created', v_vendor, v_step_id;
    END LOOP;
END;
$$;

-- ═══════════════════════════════════════════════════════════════
-- 4. RESOLUTION STEPS + PATHS (one per vendor)
-- ═══════════════════════════════════════════════════════════════

DO $$
DECLARE
    v_vendors TEXT[] := ARRAY['sqlserver', 'oracle', 'postgresql', 'mysql'];
    v_vendor TEXT;
    v_res_step_id INT;
    v_res_path_id INT;
    v_action TEXT;
BEGIN
    FOREACH v_vendor IN ARRAY v_vendors
    LOOP
        -- Vendor-specific resolution advice
        CASE v_vendor
            WHEN 'sqlserver' THEN
                v_action := 'Review the top CPU-consuming queries. Consider adding missing indexes (check sys.dm_db_missing_index_details), rewriting inefficient joins, parameterizing ad-hoc queries, updating statistics, or adding query hints (OPTION RECOMPILE, OPTIMIZE FOR) to reduce CPU cost.';
            WHEN 'oracle' THEN
                v_action := 'Review the top CPU-consuming SQL from v$sqlarea. Use SQL Tuning Advisor (DBMS_SQLTUNE), check execution plans via DBMS_XPLAN.DISPLAY_CURSOR, add missing indexes, gather fresh statistics with DBMS_STATS, or pin good plans with SQL Plan Baselines.';
            WHEN 'postgresql' THEN
                v_action := 'Review the top queries from pg_stat_statements. Use EXPLAIN (ANALYZE, BUFFERS) to find bottlenecks, add missing indexes, run ANALYZE to refresh statistics, consider partial indexes or expression indexes, and check for sequential scans on large tables.';
            WHEN 'mysql' THEN
                v_action := 'Review the top queries from performance_schema digests. Use EXPLAIN to check execution plans, add missing indexes, run ANALYZE TABLE to update statistics, check for full table scans in slow_log, and consider query rewrites to avoid filesort/temporary tables.';
        END CASE;

        -- Create resolution step
        INSERT INTO rootcause.resolution_steps (
            vendor_slug, step_type, name, content,
            risk_level, requires_confirmation, is_reversible
        ) VALUES (
            v_vendor, 'recommendation',
            'Tune expensive queries (' || v_vendor || ')',
            ('{"action": "' || v_action || '"}')::jsonb,
            'medium', false, true
        ) RETURNING id INTO v_res_step_id;

        -- Create resolution path
        INSERT INTO rootcause.resolution_paths (
            root_cause_id, vendor_slug, name, slug, description,
            execution_mode, risk_level, is_active
        ) VALUES (
            'PERF-SQL-QE-001-RC15', v_vendor,
            'Tune expensive queries (' || v_vendor || ')',
            'tune-expensive-queries-' || v_vendor,
            'Review and optimize the most CPU-intensive queries identified by the detection step',
            'supervised', 'medium', true
        ) RETURNING id INTO v_res_path_id;

        -- Link resolution step to path
        INSERT INTO rootcause.resolution_path_steps (
            resolution_path_id, resolution_step_id, step_order
        ) VALUES (v_res_path_id, v_res_step_id, 1);

        RAISE NOTICE 'Created resolution for %: step=%, path=%', v_vendor, v_res_step_id, v_res_path_id;
    END LOOP;
END;
$$;

-- ═══════════════════════════════════════════════════════════════
-- 5. VERIFY
-- ═══════════════════════════════════════════════════════════════

SELECT '=== Root Cause ===' AS section;
SELECT root_cause_id, name, vendors_applicable
FROM rootcause.root_causes WHERE root_cause_id = 'PERF-SQL-QE-001-RC15';

SELECT '=== Detection Paths ===' AS section;
SELECT dp.id, dp.vendor_slug, dp.name, dp.is_active
FROM rootcause.detection_paths dp WHERE dp.root_cause_id = 'PERF-SQL-QE-001-RC15'
ORDER BY dp.vendor_slug, dp.name;

SELECT '=== Detection Steps ===' AS section;
SELECT ds.id, ds.vendor_slug, LEFT(ds.content->>'sql', 80) AS sql_preview
FROM rootcause.detection_steps ds
JOIN rootcause.detection_path_steps dps ON dps.detection_step_id = ds.id
JOIN rootcause.detection_paths dp ON dp.id = dps.detection_path_id
WHERE dp.root_cause_id = 'PERF-SQL-QE-001-RC15'
ORDER BY ds.vendor_slug;

SELECT '=== In v_rootcauses View ===' AS section;
SELECT root_cause_id, root_cause_name, vendor_name, risk_level
FROM rootcause.v_rootcauses WHERE root_cause_id = 'PERF-SQL-QE-001-RC15'
ORDER BY vendor_name;

COMMIT;
