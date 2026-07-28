-- =============================================================================
-- 6130_fix_sec_sql_pri_001_rc15_timeout.sql
-- SEC-SQL-PRI-001-RC15 (sqlserver) times out: HYT00 "Query timeout expired".
--
-- Root cause of the timeout
-- -------------------------
-- The cached-plan branch did:
--     FROM sys.dm_exec_query_stats qs
--     CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) t
--     JOIN #sensitive_cols sc ON t.text LIKE '%' + sc.table_name + '%'
-- which materialises the SQL text of the ENTIRE plan cache and runs a
-- leading-wildcard LIKE once per sensitive *column*. #sensitive_cols holds one
-- row per column, so every table name is re-tested many times -> O(plans x cols)
-- substring scans over (potentially huge) plan-cache texts. On a busy server
-- this exceeds DBEXPERT_QUERY_TIMEOUT (default 30s) and pyodbc raises HYT00.
--
-- Fix (semantics-preserving; identical output columns + order)
-- ------------------------------------------------------------
--   1) #sens_tables = DISTINCT table_name  -> run the expensive LIKE against a
--      small set of names, not once per column.
--   2) #plans = a bounded, recent snapshot of the plan cache (TOP 500 by
--      last_execution_time, last 24h). dm_exec_sql_text is now applied only to
--      that bounded set instead of the whole cache.
--   3) Match plans against #sens_tables once (#plan_hits), then attach the
--      per-column metadata by table_name. The active-transaction branch is
--      unchanged in meaning (few rows) and routed through #sens_tables too.
--
-- Notes
-- -----
--  * metrics.v_custom_metrics flattens \n -> ' ' before the query is executed,
--    so the stored SQL MUST NOT contain '--' line comments (they would comment
--    out the rest of the one-line statement). This SQL uses none.
--  * Output columns are unchanged: source, session_id, transaction_id,
--    execution_count, last_execution_time, avg_reads, avg_cpu_ms,
--    transaction_begin_time, db_name, schema_name, table_name, column_name,
--    pii_category, query_text, login_name -- so monitoring.v_sec_sql_pri_001_rc15
--    and the Grafana panels keep working.
--  * Matched by (vendor_slug + name LIKE '%PRI-001-RC15%'), like 6070, because
--    detection_steps.id is assigned per-install and must not be used as a key.
--  * Idempotent: re-running sets identical content (the ledger applies it once
--    per checksum). RC12/RC14 share the same cross-database catalog scan and may
--    benefit from the same treatment if they also time out.
-- =============================================================================
UPDATE rootcause.detection_steps
SET content = content || jsonb_build_object('sql', $rc15sql$SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#sensitive_cols') IS NOT NULL DROP TABLE #sensitive_cols;
CREATE TABLE #sensitive_cols (
    db_name      sysname,
    schema_name  sysname,
    table_name   sysname,
    column_name  sysname,
    pii_category nvarchar(50)
);

DECLARE @sql nvarchar(max) = N'';
SELECT @sql = @sql + N'
USE ' + QUOTENAME(name) + N';
INSERT INTO #sensitive_cols (db_name, schema_name, table_name, column_name, pii_category)
SELECT DB_NAME(), s.name, t.name, c.name,
  CASE
    WHEN LOWER(c.name) LIKE ''%password%'' OR LOWER(c.name) LIKE ''%pass%'' THEN ''Password''
    WHEN LOWER(c.name) LIKE ''%secret%''   OR LOWER(c.name) LIKE ''%token%'' OR LOWER(c.name) LIKE ''%key%'' THEN ''Credential''
    WHEN LOWER(c.name) LIKE ''%credit%''   OR LOWER(c.name) LIKE ''%card%''  THEN ''Credit Card''
    WHEN LOWER(c.name) LIKE ''%ssn%''      THEN ''SSN''
    WHEN LOWER(c.name) LIKE ''%email%''    THEN ''Email''
    WHEN LOWER(c.name) LIKE ''%phone%''    THEN ''Phone''
    WHEN LOWER(c.name) LIKE ''%address%''  THEN ''Address''
    WHEN LOWER(c.name) LIKE ''%dob%''      OR LOWER(c.name) LIKE ''%birth%'' THEN ''Date of Birth''
    WHEN LOWER(c.name) LIKE ''%salary%''   THEN ''Salary''
    WHEN LOWER(c.name) LIKE ''%passport%'' THEN ''Passport''
    WHEN LOWER(c.name) LIKE ''%medical%''  OR LOWER(c.name) LIKE ''%diagnosis%'' THEN ''Medical''
    WHEN LOWER(c.name) LIKE ''%teudat%''   THEN ''Teudat Zehut''
    ELSE ''Other Sensitive''
  END
FROM sys.tables  t
JOIN sys.columns c ON c.object_id = t.object_id
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE t.is_ms_shipped = 0
  AND (LOWER(c.name) LIKE ''%password%'' OR LOWER(c.name) LIKE ''%pass%''
    OR LOWER(c.name) LIKE ''%secret%''   OR LOWER(c.name) LIKE ''%token%'' OR LOWER(c.name) LIKE ''%key%''
    OR LOWER(c.name) LIKE ''%credit%''   OR LOWER(c.name) LIKE ''%card%''
    OR LOWER(c.name) LIKE ''%ssn%''
    OR LOWER(c.name) LIKE ''%email%''
    OR LOWER(c.name) LIKE ''%phone%''
    OR LOWER(c.name) LIKE ''%address%''
    OR LOWER(c.name) LIKE ''%dob%''      OR LOWER(c.name) LIKE ''%birth%''
    OR LOWER(c.name) LIKE ''%salary%''
    OR LOWER(c.name) LIKE ''%passport%''
    OR LOWER(c.name) LIKE ''%medical%''  OR LOWER(c.name) LIKE ''%diagnosis%''
    OR LOWER(c.name) LIKE ''%teudat%'');
'
FROM sys.databases
WHERE state = 0
  AND database_id > 4
  AND HAS_DBACCESS(name) = 1
  AND name NOT IN ('distribution', 'ReportServer', 'ReportServerTempDB', 'SSISDB');

EXEC sp_executesql @sql;

IF OBJECT_ID('tempdb..#sens_tables') IS NOT NULL DROP TABLE #sens_tables;
SELECT DISTINCT table_name INTO #sens_tables FROM #sensitive_cols;

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
ORDER BY source, last_execution_time;$rc15sql$)
WHERE vendor_slug = 'sqlserver'
  AND name LIKE '%PRI-001-RC15%';
