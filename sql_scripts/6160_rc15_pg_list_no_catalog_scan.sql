-- =============================================================================
-- 6160_rc15_pg_list_no_catalog_scan.sql
-- SEC-SQL-PRI-001-RC15 (sqlserver): remove the cross-database catalog scan from
-- the per-cycle detection (the remaining timeout cause) and exclude the
-- monitoring login.
--
-- Background
-- ----------
-- 6130/6140 fixed the plan-cache join, but RC15 still built #sensitive_cols by
-- looping `USE <db>; ... sys.columns` over every database, every cycle. The SEC
-- sweep runs every 5s and overlaps itself ("maximum number of running instances
-- reached"), so three metrics (RC12/RC14/RC15) each run that full catalog scan
-- concurrently on the target -> intermittent HYT00 timeouts.
--
-- Right approach: the catalog scan is INVENTORY, not detection. It is now done
-- out-of-band (collect_metric_mssql_sensitive_data_activity -> sensitive_schema)
-- and surfaced via metrics.v_sensitive_columns_all (union with the curated
-- metrics.sensitive_columns). The collector injects that per-server list into
-- the placeholder below, so the target only does the cheap, bounded DMV match.
--
-- Fail-safe / deploy-order-independent
-- ------------------------------------
-- The seed uses a VALUES list with a sentinel first row and a
-- /*__SENSITIVE_COLS_VALUES__*/ injection point. The collector replaces that
-- comment with ",(...),(...)" for the server. If the collector hook is not yet
-- deployed (or the list is empty), the comment stays and the SQL is STILL valid
-- T-SQL -- it just yields the sentinel (which matches no real query text), so
-- RC15 returns nothing instead of erroring or timing out. No catalog scan runs
-- in either case.
--
-- Also: exclude the monitoring account (dbdome_mon_usr, and dynamically the
-- login the detection itself runs as via SUSER_SNAME()) from the attributed
-- branches, so RC15 never reports DBDOME's own monitoring queries.
--
-- No '--' comments inside the stored SQL (metrics.v_custom_metrics flattens
-- \n -> space). Output columns/order unchanged. Idempotent; matched by
-- (vendor_slug + name LIKE '%PRI-001-RC15%').
-- =============================================================================
UPDATE rootcause.detection_steps
SET content = content || jsonb_build_object('sql', $rc15sql$SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#sensitive_cols') IS NOT NULL DROP TABLE #sensitive_cols;
CREATE TABLE #sensitive_cols (
    db_name      nvarchar(128) NULL,
    schema_name  nvarchar(128) NULL,
    table_name   nvarchar(128) NULL,
    column_name  nvarchar(128) NULL,
    pii_category nvarchar(50)  NULL
);

INSERT INTO #sensitive_cols (db_name, schema_name, table_name, column_name, pii_category)
SELECT db_name, schema_name, table_name, column_name, pii_category
FROM (VALUES
    (CAST(NULL AS nvarchar(128)), CAST(NULL AS nvarchar(128)), CAST(N'~~no_sensitive_list~~' AS nvarchar(128)), CAST(N'~~' AS nvarchar(128)), CAST(NULL AS nvarchar(50)))
    /*__SENSITIVE_COLS_VALUES__*/
) v(db_name, schema_name, table_name, column_name, pii_category)
WHERE table_name IS NOT NULL;

IF OBJECT_ID('tempdb..#sens_tables') IS NOT NULL DROP TABLE #sens_tables;
SELECT DISTINCT table_name INTO #sens_tables FROM #sensitive_cols WHERE table_name IS NOT NULL;

CREATE CLUSTERED INDEX ix_sensitive_cols_tab ON #sensitive_cols(table_name);

IF OBJECT_ID('tempdb..#plans') IS NOT NULL DROP TABLE #plans;
SELECT TOP (500)
       qs.execution_count,
       qs.last_execution_time,
       qs.total_logical_reads / NULLIF(qs.execution_count, 0)         AS avg_reads,
       qs.total_worker_time   / NULLIF(qs.execution_count, 0) / 1000  AS avg_cpu_ms,
       LEFT(t.text, 4000) AS query_text
INTO #plans
FROM sys.dm_exec_query_stats AS qs WITH (NOLOCK)
CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) AS t
WHERE t.text IS NOT NULL
  AND qs.last_execution_time > DATEADD(HOUR, -24, GETDATE())
  AND LEFT(t.text, 4000) NOT LIKE '%tempdb..#sensitive_cols%'
ORDER BY qs.last_execution_time DESC;

IF OBJECT_ID('tempdb..#plan_hits') IS NOT NULL DROP TABLE #plan_hits;
SELECT p.execution_count, p.last_execution_time, p.avg_reads, p.avg_cpu_ms,
       p.query_text, st.table_name
INTO #plan_hits
FROM #plans p
JOIN #sens_tables st ON p.query_text LIKE '%' + st.table_name + '%';

CREATE CLUSTERED INDEX ix_plan_hits_tab ON #plan_hits(table_name);

SELECT TOP 100 'cached_plan'         AS source,
       CAST(NULL AS INT)     AS session_id,
       CAST(NULL AS BIGINT)  AS transaction_id,
       ph.execution_count,
       ph.last_execution_time,
       ph.avg_reads,
       ph.avg_cpu_ms,
       CAST(NULL AS DATETIME) AS transaction_begin_time,
       sc.db_name, sc.schema_name, sc.table_name, sc.column_name, sc.pii_category,
       ph.query_text         AS query_text,
       CAST(NULL AS sysname) AS login_name
FROM #plan_hits ph
JOIN #sensitive_cols sc ON sc.table_name = ph.table_name
UNION ALL
SELECT 'session'            AS source,
       ses.session_id,
       CAST(NULL AS BIGINT)  AS transaction_id,
       CAST(NULL AS BIGINT)  AS execution_count,
       ses.last_request_start_time AS last_execution_time,
       CAST(NULL AS BIGINT)  AS avg_reads,
       CAST(NULL AS BIGINT)  AS avg_cpu_ms,
       CAST(NULL AS DATETIME) AS transaction_begin_time,
       sc.db_name, sc.schema_name, sc.table_name, sc.column_name, sc.pii_category,
       LEFT(t.text, 4000)    AS query_text,
       ses.login_name        AS login_name
FROM sys.dm_exec_connections con
CROSS APPLY sys.dm_exec_sql_text(con.most_recent_sql_handle) AS t
JOIN sys.dm_exec_sessions ses ON ses.session_id = con.session_id
JOIN #sens_tables stc ON t.text LIKE '%' + stc.table_name + '%'
JOIN #sensitive_cols sc ON sc.table_name = stc.table_name
WHERE ses.is_user_process = 1
  AND t.text IS NOT NULL
  AND LEFT(t.text, 4000) NOT LIKE '%tempdb..#sensitive_cols%'
  AND ISNULL(ses.login_name, N'') NOT IN (N'dbdome_mon_usr', SUSER_SNAME())
UNION ALL
SELECT 'active_transaction'  AS source,
       ses.session_id,
       tat.transaction_id,
       CAST(NULL AS BIGINT)  AS execution_count,
       CAST(NULL AS DATETIME) AS last_execution_time,
       CAST(NULL AS BIGINT)  AS avg_reads,
       CAST(NULL AS BIGINT)  AS avg_cpu_ms,
       tat.transaction_begin_time,
       sc.db_name, sc.schema_name, sc.table_name, sc.column_name, sc.pii_category,
       LEFT(t.text, 4000)    AS query_text,
       ses.login_name        AS login_name
FROM sys.dm_tran_active_transactions    tat
JOIN sys.dm_tran_session_transactions   sts ON sts.transaction_id = tat.transaction_id
JOIN sys.dm_exec_sessions               ses ON ses.session_id     = sts.session_id
JOIN sys.dm_exec_connections            con ON con.session_id     = sts.session_id
CROSS APPLY sys.dm_exec_sql_text(con.most_recent_sql_handle) AS t
JOIN #sens_tables stt ON t.text LIKE '%' + stt.table_name + '%'
JOIN #sensitive_cols sc ON sc.table_name = stt.table_name
WHERE tat.transaction_state = 2
  AND ses.is_user_process   = 1
  AND t.text IS NOT NULL
  AND LEFT(t.text, 4000) NOT LIKE '%tempdb..#sensitive_cols%'
  AND ISNULL(ses.login_name, N'') NOT IN (N'dbdome_mon_usr', SUSER_SNAME())
ORDER BY source, last_execution_time;$rc15sql$)
WHERE vendor_slug = 'sqlserver'
  AND name LIKE '%PRI-001-RC15%';
