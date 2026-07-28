-- =============================================================================
-- 5046_fix_sec_sql_acc_011_rc02_single_select.sql
-- SEC-SQL-ACC-011-RC02 (sqlserver): restore a single-SELECT active-transactions
-- detection query.
--
-- Why
-- ---
-- An earlier change swapped this detection for the full "Who Is Active" batch.
-- The generic collector wraps every metric as
--     SELECT * FROM ( <query> ) a WHERE <condition>
-- and evaluates the result set, so the detection MUST be a single SELECT.
-- A multi-statement batch (DECLARE / CREATE TABLE #.. / INSERT..EXEC / RETURN)
-- cannot live inside a derived table and fails to execute. This restores a
-- single SELECT: one row per in-flight transaction, excluding the dbdome
-- monitoring login and the detection's own login.
--
-- No '--' comments inside the stored SQL (metrics.v_custom_metrics flattens
-- \n -> space before execution). Output columns/order match
-- monitoring.v_sec_sql_acc_011_rc02 (1055). Idempotent; matched by
-- (vendor_slug + name LIKE '%ACC-011-RC02%').
-- =============================================================================
UPDATE rootcause.detection_steps
SET content = content || jsonb_build_object('sql', $rc02sql$SET NOCOUNT ON;
SELECT
    @@SERVERNAME AS server,
    s.session_id,
    s.login_name,
    s.host_name,
    s.program_name,
    DB_NAME(s.database_id) AS database_name,
    t.transaction_id,
    tat.transaction_begin_time,
    DATEDIFF(SECOND, tat.transaction_begin_time, GETDATE()) AS duration_seconds,
    tat.transaction_state,
    SUBSTRING(st.text, 1, 4000) AS query_text
FROM sys.dm_tran_active_transactions tat
JOIN sys.dm_tran_session_transactions t ON t.transaction_id = tat.transaction_id
JOIN sys.dm_exec_sessions s ON s.session_id = t.session_id
LEFT JOIN sys.dm_exec_connections c ON c.session_id = s.session_id
OUTER APPLY sys.dm_exec_sql_text(c.most_recent_sql_handle) st
WHERE s.is_user_process = 1
  AND s.login_name NOT IN ('dbd_mon_usr','dbdome_mon_usr')
  AND ISNULL(s.login_name, '') <> SUSER_SNAME()
ORDER BY tat.transaction_begin_time$rc02sql$)
WHERE vendor_slug = 'sqlserver'
  AND name LIKE '%ACC-011-RC02%';

-- VERIFY
SELECT id, vendor_slug, name, length(content->>'sql') AS sql_len
FROM rootcause.detection_steps
WHERE vendor_slug = 'sqlserver'
  AND name LIKE '%ACC-011-RC02%';
