-- =============================================================================
-- 5049_acc_011_rc02_remove_sensitive_filter.sql
-- SEC-SQL-ACC-011-RC02 (sqlserver): REMOVE the column-level sensitive-access
-- filter that 5048 added. Restores the plain single-SELECT WhoIsActive snapshot
-- (running + open-tran sleepers + finished-in-last-60s + plan-cache branch) with
-- NO sensitive_cols CTE / EXISTS / injection token, so it again reports all
-- active and recently-active sessions (not just those touching sensitive cols).
--
-- The after_hours / in_transaction columns live in view 1055 and are unaffected.
-- 5048 has been deleted so the runner cannot re-add the filter. Single statement,
-- no GO, no '--' comments inside the stored SQL. Idempotent; matched by
-- (vendor_slug + name LIKE '%ACC-011-RC02%').
-- =============================================================================
UPDATE rootcause.detection_steps
SET content = content || jsonb_build_object('sql', $rc02wia$SELECT
    s.session_id,
    COALESCE(r.status, s.status) AS status,
    CASE
        WHEN r.session_id IS NOT NULL          THEN 'running'
        WHEN ISNULL(tx.open_tran_count, 0) > 0 THEN 'sleeping (open tran)'
        ELSE 'recently completed'
    END AS activity,
    s.login_name,
    s.host_name,
    s.program_name,
    DB_NAME(COALESCE(r.database_id, s.database_id)) AS database_name,
    r.command,
    r.wait_type,
    r.wait_time,
    NULLIF(r.blocking_session_id, 0) AS blocking_session_id,
    r.cpu_time AS cpu_ms,
    r.total_elapsed_time AS elapsed_ms,
    r.reads,
    r.writes,
    r.logical_reads,
    r.percent_complete,
    ISNULL(tx.open_tran_count, 0) AS open_tran_count,
    tx.tran_begin_time,
    r.start_time AS request_start_time,
    s.last_request_start_time,
    s.last_request_end_time,
    s.login_time,
    CAST(
        CASE
            WHEN r.statement_start_offset IS NOT NULL AND qt.text IS NOT NULL THEN
                SUBSTRING(qt.text, (r.statement_start_offset / 2) + 1,
                    ((CASE r.statement_end_offset WHEN -1 THEN DATALENGTH(qt.text) ELSE r.statement_end_offset END - r.statement_start_offset) / 2) + 1)
            ELSE qt.text
        END AS NVARCHAR(MAX)) AS sql_text
FROM sys.dm_exec_sessions AS s WITH (NOLOCK)
OUTER APPLY (
    SELECT TOP (1) rq.*
    FROM sys.dm_exec_requests AS rq WITH (NOLOCK)
    WHERE rq.session_id = s.session_id
    ORDER BY rq.cpu_time DESC
) AS r
OUTER APPLY (
    SELECT TOP (1) cn.most_recent_sql_handle
    FROM sys.dm_exec_connections AS cn WITH (NOLOCK)
    WHERE cn.session_id = s.session_id
    ORDER BY cn.connect_time DESC
) AS c
OUTER APPLY sys.dm_exec_sql_text(COALESCE(r.sql_handle, c.most_recent_sql_handle)) AS qt
OUTER APPLY (
    SELECT MIN(tat.transaction_begin_time) AS tran_begin_time,
           COUNT(*) AS open_tran_count
    FROM sys.dm_tran_session_transactions AS tst WITH (NOLOCK)
    JOIN sys.dm_tran_active_transactions  AS tat WITH (NOLOCK)
         ON tat.transaction_id = tst.transaction_id
    WHERE tst.session_id = s.session_id
) AS tx
WHERE s.is_user_process = 1
  AND s.session_id <> @@SPID
  AND ISNULL(s.login_name, '') NOT LIKE '%dbdome%'
  AND (
        r.session_id IS NOT NULL
        OR ISNULL(tx.open_tran_count, 0) > 0
        OR s.last_request_end_time >= DATEADD(SECOND, -60, GETDATE())
      )
UNION ALL
SELECT
    CAST(NULL AS SMALLINT) AS session_id,
    CAST(NULL AS NVARCHAR(60)) AS status,
    'completed (plan cache)' AS activity,
    CAST(NULL AS NVARCHAR(128)) AS login_name,
    CAST(NULL AS NVARCHAR(128)) AS host_name,
    CAST(NULL AS NVARCHAR(128)) AS program_name,
    DB_NAME(st.dbid) AS database_name,
    CAST(NULL AS NVARCHAR(32)) AS command,
    CAST(NULL AS NVARCHAR(60)) AS wait_type,
    CAST(NULL AS INT) AS wait_time,
    CAST(NULL AS SMALLINT) AS blocking_session_id,
    CAST(qs.total_worker_time   / NULLIF(qs.execution_count, 0) / 1000 AS BIGINT) AS cpu_ms,
    CAST(qs.total_elapsed_time  / NULLIF(qs.execution_count, 0) / 1000 AS BIGINT) AS elapsed_ms,
    CAST(qs.total_physical_reads / NULLIF(qs.execution_count, 0) AS BIGINT) AS reads,
    CAST(qs.total_logical_writes / NULLIF(qs.execution_count, 0) AS BIGINT) AS writes,
    CAST(qs.total_logical_reads  / NULLIF(qs.execution_count, 0) AS BIGINT) AS logical_reads,
    CAST(NULL AS REAL) AS percent_complete,
    CAST(NULL AS INT) AS open_tran_count,
    CAST(NULL AS DATETIME) AS tran_begin_time,
    CAST(NULL AS DATETIME) AS request_start_time,
    CAST(NULL AS DATETIME) AS last_request_start_time,
    qs.last_execution_time AS last_request_end_time,
    CAST(NULL AS DATETIME) AS login_time,
    CAST(
        SUBSTRING(st.text, (qs.statement_start_offset / 2) + 1,
            ((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(st.text) ELSE qs.statement_end_offset END - qs.statement_start_offset) / 2) + 1)
        AS NVARCHAR(MAX)) AS sql_text
FROM sys.dm_exec_query_stats AS qs WITH (NOLOCK)
OUTER APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
WHERE qs.last_execution_time >= DATEADD(SECOND, -60, GETDATE())
  AND st.text IS NOT NULL
  AND st.text NOT LIKE '%dm_exec_query_stats%'$rc02wia$)
WHERE vendor_slug = 'sqlserver'
  AND name LIKE '%ACC-011-RC02%';

-- VERIFY
SELECT id, vendor_slug, name,
       length(content->>'sql') AS sql_len,
       CASE WHEN content->>'sql' LIKE '%sensitive_cols%' THEN 'STILL-FILTERED' ELSE 'no-sensitive-filter' END AS state
FROM rootcause.detection_steps
WHERE vendor_slug = 'sqlserver'
  AND name LIKE '%ACC-011-RC02%';
