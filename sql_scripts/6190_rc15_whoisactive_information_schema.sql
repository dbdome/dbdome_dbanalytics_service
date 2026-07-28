-- =============================================================================
-- 6190_rc15_whoisactive_information_schema.sql
-- SEC-SQL-PRI-001-RC15 (sqlserver): the detection is the single-SELECT
-- "Who Is Active" snapshot, restricted to sessions/plans whose SQL text contains
-- a SENSITIVE COLUMN. Sensitive columns are discovered INLINE from
-- information_schema.columns (current database) and classified into pii_category,
-- replacing the injected /*__SENSITIVE_COLS_VALUES__*/ list.
--
-- Two WhoIsActive branches (live sessions incl. recently-completed + open-tran,
-- and the plan cache for the last 60s) INNER JOIN the discovered sensitive_cols
-- on  <sql text> LIKE '%' + column_name + '%'  -- one row per session x matched
-- sensitive column, surfacing schema_name / table_name / column_name / pii_category.
--
-- Output keys match view monitoring.v_sec_sql_pri_001_rc15 (2500) exactly, so the
-- view is unchanged (in_transaction keys off source = active_transaction).
-- No '--' comments inside the stored SQL, single statement, no GO. Replaces 6180.
-- Idempotent; matched by (vendor_slug + name LIKE '%PRI-001-RC15%').
-- =============================================================================
UPDATE rootcause.detection_steps
SET content = content || jsonb_build_object('sql', $rc15sql$WITH sensitive_cols AS (
    SELECT
        c.table_schema AS schema_name,
        c.table_name   AS table_name,
        c.column_name  AS column_name,
        CASE
            WHEN LOWER(c.column_name) LIKE '%password%' OR LOWER(c.column_name) LIKE '%pass%' THEN 'Password'
            WHEN LOWER(c.column_name) LIKE '%secret%' OR LOWER(c.column_name) LIKE '%token%' OR LOWER(c.column_name) LIKE '%key%' THEN 'Credential'
            WHEN LOWER(c.column_name) LIKE '%credit%' OR LOWER(c.column_name) LIKE '%card%' THEN 'Credit Card'
            WHEN LOWER(c.column_name) LIKE '%ssn%' THEN 'SSN'
            WHEN LOWER(c.column_name) LIKE '%email%' THEN 'Email'
            WHEN LOWER(c.column_name) LIKE '%phone%' THEN 'Phone'
            WHEN LOWER(c.column_name) LIKE '%address%' THEN 'Address'
            WHEN LOWER(c.column_name) LIKE '%dob%' OR LOWER(c.column_name) LIKE '%birth%' THEN 'Date of Birth'
            WHEN LOWER(c.column_name) LIKE '%salary%' THEN 'Salary'
            WHEN LOWER(c.column_name) LIKE '%passport%' THEN 'Passport'
            WHEN LOWER(c.column_name) LIKE '%medical%' OR LOWER(c.column_name) LIKE '%diagnosis%' THEN 'Medical'
            WHEN LOWER(c.column_name) LIKE '%teudat%' THEN 'Teudat Zehut'
            ELSE 'Other Sensitive'
        END AS pii_category
    FROM information_schema.columns c
    WHERE c.table_schema NOT IN ('information_schema','mysql','performance_schema','sys')
      AND (LOWER(c.column_name) LIKE '%password%' OR LOWER(c.column_name) LIKE '%pass%'
        OR LOWER(c.column_name) LIKE '%secret%' OR LOWER(c.column_name) LIKE '%token%' OR LOWER(c.column_name) LIKE '%key%'
        OR LOWER(c.column_name) LIKE '%credit%' OR LOWER(c.column_name) LIKE '%card%'
        OR LOWER(c.column_name) LIKE '%ssn%'
        OR LOWER(c.column_name) LIKE '%email%'
        OR LOWER(c.column_name) LIKE '%phone%'
        OR LOWER(c.column_name) LIKE '%address%'
        OR LOWER(c.column_name) LIKE '%dob%' OR LOWER(c.column_name) LIKE '%birth%'
        OR LOWER(c.column_name) LIKE '%salary%'
        OR LOWER(c.column_name) LIKE '%passport%'
        OR LOWER(c.column_name) LIKE '%medical%' OR LOWER(c.column_name) LIKE '%diagnosis%'
        OR LOWER(c.column_name) LIKE '%teudat%')
)
SELECT
    CASE
        WHEN ISNULL(tx.open_tran_count, 0) > 0 THEN 'active_transaction'
        WHEN r.session_id IS NOT NULL          THEN 'session'
        ELSE 'recently_completed'
    END AS source,
    s.session_id,
    CAST(NULL AS BIGINT) AS transaction_id,
    s.login_name,
    sc.schema_name,
    sc.table_name,
    sc.column_name,
    sc.pii_category,
    CAST(NULL AS BIGINT) AS execution_count,
    s.last_request_end_time AS last_execution_time,
    r.reads AS avg_reads,
    CAST(r.cpu_time AS BIGINT) AS avg_cpu_ms,
    tx.tran_begin_time AS transaction_begin_time,
    CAST(
        CASE
            WHEN r.statement_start_offset IS NOT NULL AND qt.text IS NOT NULL THEN
                SUBSTRING(qt.text, (r.statement_start_offset / 2) + 1,
                    ((CASE r.statement_end_offset WHEN -1 THEN DATALENGTH(qt.text) ELSE r.statement_end_offset END - r.statement_start_offset) / 2) + 1)
            ELSE qt.text
        END AS NVARCHAR(MAX)) AS query_text
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
JOIN sensitive_cols sc ON qt.text LIKE N'%' + sc.column_name + N'%'
WHERE s.is_user_process = 1
  AND s.session_id <> @@SPID
  AND ISNULL(s.login_name, '') NOT LIKE '%dbdome%'
  AND qt.text IS NOT NULL
  AND (
        r.session_id IS NOT NULL
        OR ISNULL(tx.open_tran_count, 0) > 0
        OR s.last_request_end_time >= DATEADD(SECOND, -60, GETDATE())
      )
UNION ALL
SELECT
    'cached_plan' AS source,
    CAST(NULL AS SMALLINT) AS session_id,
    CAST(NULL AS BIGINT) AS transaction_id,
    CAST(NULL AS NVARCHAR(128)) AS login_name,
    sc.schema_name,
    sc.table_name,
    sc.column_name,
    sc.pii_category,
    qs.execution_count,
    qs.last_execution_time AS last_execution_time,
    CAST(qs.total_logical_reads / NULLIF(qs.execution_count, 0) AS BIGINT) AS avg_reads,
    CAST(qs.total_worker_time   / NULLIF(qs.execution_count, 0) / 1000 AS BIGINT) AS avg_cpu_ms,
    CAST(NULL AS DATETIME) AS transaction_begin_time,
    CAST(
        SUBSTRING(st.text, (qs.statement_start_offset / 2) + 1,
            ((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(st.text) ELSE qs.statement_end_offset END - qs.statement_start_offset) / 2) + 1)
        AS NVARCHAR(MAX)) AS query_text
FROM sys.dm_exec_query_stats AS qs WITH (NOLOCK)
OUTER APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
JOIN sensitive_cols sc ON st.text LIKE N'%' + sc.column_name + N'%'
WHERE qs.last_execution_time >= DATEADD(SECOND, -60, GETDATE())
  AND st.text IS NOT NULL
  AND st.text NOT LIKE '%dm_exec_query_stats%'$rc15sql$)
WHERE vendor_slug = 'sqlserver'
  AND name LIKE '%PRI-001-RC15%';

-- VERIFY
SELECT id, vendor_slug, name,
       length(content->>'sql') AS sql_len,
       CASE WHEN content->>'sql' LIKE '%information_schema.columns%'
             AND content->>'sql' LIKE '%dm_exec_sessions%' THEN 'whoisactive+infoschema' ELSE 'other' END AS state
FROM rootcause.detection_steps
WHERE vendor_slug = 'sqlserver'
  AND name LIKE '%PRI-001-RC15%';
