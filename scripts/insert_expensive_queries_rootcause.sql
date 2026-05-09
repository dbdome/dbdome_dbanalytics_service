-- =============================================================================
-- INSERT: PERF-SQL-QE-001-RC15 — Expensive queries (high CPU per execution)
-- =============================================================================
-- Vendor: sqlserver only
-- Issue:  Slow Query Execution (PERF-SQL-QE-001)
-- Detects queries with high average CPU cost from sys.dm_exec_query_stats
-- =============================================================================

BEGIN;

-- ─────────────────────────────────────────────
-- 1. Insert root cause
-- ─────────────────────────────────────────────
INSERT INTO rootcause.root_causes (
    root_cause_id, issue_id, name, slug, description,
    topics, vendors_applicable
)
VALUES (
    'PERF-SQL-QE-001-RC15',
    'PERF-SQL-QE-001',
    'Expensive queries (high CPU per execution)',
    'expensive-queries-high-cpu',
    'Queries consuming disproportionate CPU time per execution. Identifies the top resource-intensive statements from the plan cache ranked by average CPU cost, including the originating login, host, and program name.',
    ARRAY['expensive queries', 'high cpu', 'query stats', 'plan cache', 'top queries', 'resource intensive'],
    ARRAY['sqlserver']
);

-- ─────────────────────────────────────────────
-- 2. Insert detection step (the SQL query)
-- ─────────────────────────────────────────────
INSERT INTO rootcause.detection_steps (
    vendor_slug, step_type, name, content, expected, parameters
)
VALUES (
    'sqlserver',
    'query',
    'Detect expensive queries by average CPU',
    '{
        "sql": "SELECT TOP 20 qs.total_worker_time / qs.execution_count AS avg_cpu, qs.total_worker_time AS total_cpu, qs.execution_count, qs.total_elapsed_time / qs.execution_count AS avg_duration_ms, qs.last_execution_time, COALESCE(es1.login_name, es2.login_name, ''N/A'') AS login_name, COALESCE(es1.host_name, es2.host_name, ''N/A'') AS host_name, COALESCE(es1.program_name, es2.program_name, ''N/A'') AS program_name, SUBSTRING(qt.text, (qs.statement_start_offset/2)+1, ((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(qt.text) ELSE qs.statement_end_offset END - qs.statement_start_offset)/2)+1) AS query_text FROM sys.dm_exec_query_stats qs CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt LEFT JOIN sys.dm_exec_connections ec ON ec.most_recent_sql_handle = qs.sql_handle LEFT JOIN sys.dm_exec_sessions es1 ON es1.session_id = ec.session_id LEFT JOIN sys.dm_exec_requests r ON r.sql_handle = qs.sql_handle LEFT JOIN sys.dm_exec_sessions es2 ON es2.session_id = r.session_id WHERE qs.execution_count > 0 ORDER BY avg_cpu DESC"
    }'::jsonb,
    '{
        "condition": "row_count > 0",
        "description": "Returns the top 20 most expensive queries by average CPU time per execution, including login/host/program attribution"
    }'::jsonb,
    NULL
)
RETURNING id;

-- ─────────────────────────────────────────────
-- 3. Insert detection path (sqlserver, high risk)
-- ─────────────────────────────────────────────
INSERT INTO rootcause.detection_paths (
    root_cause_id, vendor_slug, name, description, path_type, is_active
)
VALUES (
    'PERF-SQL-QE-001-RC15',
    'sqlserver',
    'Detect expensive queries by CPU cost (sqlserver)',
    'Identifies top-20 most CPU-expensive queries from the plan cache with session attribution via dm_exec_connections and dm_exec_requests',
    'diagnostic',
    true
)
RETURNING id;

-- ─────────────────────────────────────────────
-- 4. Wire step to path (using returned IDs)
-- ─────────────────────────────────────────────
-- We need the IDs from the inserts above. Use a DO block:

DO $$
DECLARE
    v_step_id INT;
    v_path_id INT;
BEGIN
    -- Get the step we just inserted
    SELECT id INTO v_step_id
    FROM rootcause.detection_steps
    WHERE vendor_slug = 'sqlserver'
      AND name = 'Detect expensive queries by average CPU'
    ORDER BY id DESC LIMIT 1;

    -- Get the path we just inserted
    SELECT id INTO v_path_id
    FROM rootcause.detection_paths
    WHERE root_cause_id = 'PERF-SQL-QE-001-RC15'
      AND vendor_slug = 'sqlserver'
    ORDER BY id DESC LIMIT 1;

    -- Link step to path at sequence 1
    INSERT INTO rootcause.detection_path_steps (
        detection_path_id, detection_step_id, sequence,
        on_match_action, on_no_match_action
    )
    VALUES (
        v_path_id, v_step_id, 1,
        'confirmed', 'ruled_out'
    );

    RAISE NOTICE 'Created: path_id=%, step_id=%', v_path_id, v_step_id;
END;
$$;

-- ─────────────────────────────────────────────
-- 5. Also insert into metrics.custom_metrics
--    so the generic MSSQL collector picks it up
-- ─────────────────────────────────────────────
INSERT INTO metrics.custom_metrics (query, category_id, metric_name, is_active, db_vendor, description)
SELECT
    ds.content->>'sql',
    -1,
    'PERF-SQL-QE-001-RC15',
    true,
    'mssql',
    'Top 20 most expensive queries by average CPU time per execution with login/host attribution'
FROM rootcause.detection_steps ds
WHERE ds.vendor_slug = 'sqlserver'
  AND ds.name = 'Detect expensive queries by average CPU'
ORDER BY ds.id DESC
LIMIT 1
;

-- ─────────────────────────────────────────────
-- 6. Verify
-- ─────────────────────────────────────────────
SELECT '=== Root Cause ===' AS section;
SELECT root_cause_id, name, vendors_applicable
FROM rootcause.root_causes
WHERE root_cause_id = 'PERF-SQL-QE-001-RC15';

SELECT '=== Detection Path ===' AS section;
SELECT dp.id, dp.root_cause_id, dp.vendor_slug, dp.name, dp.is_active
FROM rootcause.detection_paths dp
WHERE dp.root_cause_id = 'PERF-SQL-QE-001-RC15';

SELECT '=== Detection Step ===' AS section;
SELECT ds.id, ds.vendor_slug, ds.name,
       LEFT(ds.content->>'sql', 100) AS sql_preview,
       ds.expected->>'condition' AS condition
FROM rootcause.detection_steps ds
JOIN rootcause.detection_path_steps dps ON dps.detection_step_id = ds.id
JOIN rootcause.detection_paths dp ON dp.id = dps.detection_path_id
WHERE dp.root_cause_id = 'PERF-SQL-QE-001-RC15';

SELECT '=== v_rootcauses View ===' AS section;
SELECT root_cause_id, root_cause_name, vendor_name, detection_name, risk_level
FROM rootcause.v_rootcauses
WHERE root_cause_id = 'PERF-SQL-QE-001-RC15';

COMMIT;
