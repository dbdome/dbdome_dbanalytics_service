-- =============================================================================
-- 7570_acc011_rc02_vendor_sql_respec.sql
-- Set the SEC-SQL-ACC-011-RC02 detection SQL for sqlserver / postgresql /
-- mysql / mariadb / oracle to the texts specified by the operator (2026-08-13).
--
-- THIS IS A WHOLESALE REPLACEMENT, NOT A SURGICAL EDIT.
-- 7490 / 7550 / 7560 deliberately read the live SQL and changed only their own
-- expressions, because substituting a stored copy silently reverted 7350 on 213
-- once before. Here the operator supplied the COMPLETE desired text per vendor,
-- so substitution IS the instruction - but the consequences for sqlserver are
-- real and are recorded here:
--
--   * the 7550 HAS_PERMS_BY_NAME guard is REMOVED. On a target whose monitoring
--     login lacks VIEW SERVER STATE the step returns to hard-failing every
--     sweep (measured: 175 failures in 7 days on 192.168.200.50) instead of
--     degrading to an empty result.
--   * the 7350 wrapper is REMOVED - the outer
--       SELECT q.*, REPLACE(q.sql_text, N'execution_plan_xml', N'') FROM (...) AS q
--     is gone, so sql_text is no longer scrubbed of that token.
--   * 7560's revert stands: DB_NAME(COALESCE(r.database_id, s.database_id)) is
--     the 2012+ form, so SQL Server 2008/2008 R2 targets fail to parse the whole
--     batch ("Invalid column name 'database_id'").
--
-- Upside of dropping the guard: the SQL is a single SELECT expression again, so
-- compute_calc_query can wrap it and the stored calc_query is runnable.
--
-- COLUMN SHAPES DIFFER BY VENDOR - this is the operator's spec, not a mistake:
-- sqlserver returns the wide 24-column session/request shape, while
-- postgresql / mysql / mariadb / oracle return the 10-column
-- (session_id, login_name, host_name, program_name, database_name,
--  transaction_id, transaction_begin_time, duration_seconds,
--  transaction_state, query_text) shape. Any view or decision-tree join that
-- assumes one shape across vendors needs checking.
--
-- ENCRYPTION: same contract as 7490/7550/7560 - read via rootcause.dec(), write
-- via rootcause.enc(), reached through EXECUTE so this parses where those
-- functions do not exist; refuses to write plaintext over ciphertext.
--
-- Idempotent: a vendor already carrying the exact text is skipped.
-- =============================================================================

DO $mig$
DECLARE
    v_enc    boolean := to_regprocedure('rootcause.enc(jsonb)') IS NOT NULL;
    v_haskey boolean := nullif(current_setting('rootcause.k', true), '') IS NOT NULL;
    r        record;
    v_name   text;
    v_cur    text;
    v_done   int := 0;
    v_skip   int := 0;
BEGIN
    IF v_enc AND NOT v_haskey THEN
        RAISE EXCEPTION
            '7570: this install encrypts detection_steps (7300 applied) but the session has no key. '
            'Refusing to touch ciphertext. Connect as a role holding the role-default '
            '(dbdome_adm / dbdome_mon_usr / dbexpert_adm / dbdome_engine), or run first: '
            'SELECT set_config(''rootcause.k'', ''<DBDOME_SECRET_KEY>'', false);';
    END IF;

    FOR r IN
        SELECT * FROM (VALUES
        ('sqlserver', $sqlsrv$SELECT
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
  AND st.text NOT LIKE '%dm_exec_query_stats%'$sqlsrv$),

        ('postgresql', $pgsql$SELECT
  pid AS session_id,
  usename AS login_name,
  client_addr::text AS host_name,
  application_name AS program_name,
  datname AS database_name,
  backend_xid::text AS transaction_id,
  xact_start AS transaction_begin_time,
  EXTRACT(EPOCH FROM (now() - COALESCE(xact_start, query_start, state_change)))::int AS duration_seconds,
  state AS transaction_state,
  left(query, 4000) AS query_text
FROM pg_stat_activity
WHERE backend_type = 'client backend'
  AND pid <> pg_backend_pid()
  AND COALESCE(usename,'') NOT LIKE 'dbdome%'
  AND (state IN ('active','idle in transaction','idle in transaction (aborted)')
       OR state_change >= now() - interval '120 seconds')$pgsql$),

        ('mysql', $mysql$SELECT
  p.id AS session_id,
  p.user AS login_name,
  p.host AS host_name,
  p.command AS program_name,
  p.db AS database_name,
  t.trx_id AS transaction_id,
  t.trx_started AS transaction_begin_time,
  COALESCE(TIMESTAMPDIFF(SECOND, t.trx_started, NOW()), p.time) AS duration_seconds,
  COALESCE(t.trx_state, p.state, p.command) AS transaction_state,
  LEFT(COALESCE(t.trx_query, p.info), 4000) AS query_text
FROM information_schema.processlist p
LEFT JOIN information_schema.innodb_trx t ON t.trx_mysql_thread_id = p.id
WHERE COALESCE(p.user,'') NOT IN ('dbdome','dbdome_mon_usr','event_scheduler','system user')
  AND (p.command <> 'Sleep' OR t.trx_id IS NOT NULL OR p.time <= 120)$mysql$),

        ('mariadb', $maria$SELECT
  p.id AS session_id,
  p.user AS login_name,
  p.host AS host_name,
  p.command AS program_name,
  p.db AS database_name,
  t.trx_id AS transaction_id,
  t.trx_started AS transaction_begin_time,
  COALESCE(TIMESTAMPDIFF(SECOND, t.trx_started, NOW()), p.time) AS duration_seconds,
  COALESCE(t.trx_state, p.state, p.command) AS transaction_state,
  LEFT(COALESCE(t.trx_query, p.info), 4000) AS query_text
FROM information_schema.processlist p
LEFT JOIN information_schema.innodb_trx t ON t.trx_mysql_thread_id = p.id
WHERE COALESCE(p.user,'') NOT IN ('dbdome','dbdome_mon_usr','event_scheduler','system user')
  AND (p.command <> 'Sleep' OR t.trx_id IS NOT NULL OR p.time <= 120)$maria$),

        ('oracle', $ora$SELECT
  s.sid AS session_id,
  s.username AS login_name,
  s.machine AS host_name,
  s.program AS program_name,
  SYS_CONTEXT('USERENV','DB_NAME') AS database_name,
  t.xidusn || '.' || t.xidslot || '.' || t.xidsqn AS transaction_id,
  TO_CHAR(TO_DATE(t.start_time,'MM/DD/YY HH24:MI:SS'),'YYYY-MM-DD HH24:MI:SS') AS transaction_begin_time,
  s.last_call_et AS duration_seconds,
  s.status AS transaction_state,
  SUBSTR(sq.sql_text, 1, 4000) AS query_text
FROM v$session s
LEFT JOIN v$transaction t ON t.ses_addr = s.saddr
LEFT JOIN v$sql sq ON sq.sql_id = s.sql_id
WHERE s.type = 'USER' AND s.username IS NOT NULL
  AND s.username NOT IN ('SYS','SYSTEM','DBSNMP','SYSMAN','XDB')
  AND (s.status = 'ACTIVE' OR t.ses_addr IS NOT NULL OR s.last_call_et <= 120)$ora$)
        ) AS t(vendor, sql)
    LOOP
        v_name := 'Detect SEC-SQL-ACC-011-RC02 (' || r.vendor || ')';

        IF NOT EXISTS (SELECT 1 FROM rootcause.detection_steps
                        WHERE vendor_slug = r.vendor AND name = v_name) THEN
            RAISE NOTICE '7570: % - step not present, skipped', r.vendor;
            CONTINUE;
        END IF;

        IF v_enc THEN
            EXECUTE 'SELECT rootcause.dec(content)->>''sql'' FROM rootcause.detection_steps '
                    'WHERE vendor_slug=$1 AND name=$2' INTO v_cur USING r.vendor, v_name;
        ELSE
            SELECT content->>'sql' INTO v_cur FROM rootcause.detection_steps
             WHERE vendor_slug = r.vendor AND name = v_name;
        END IF;

        IF v_cur IS NOT DISTINCT FROM r.sql THEN
            RAISE NOTICE '7570: % - already the specified text, no change', r.vendor;
            v_skip := v_skip + 1;
            CONTINUE;
        END IF;

        IF v_enc THEN
            EXECUTE 'UPDATE rootcause.detection_steps '
                    'SET content = rootcause.enc(jsonb_build_object(''sql'', $1)) '
                    'WHERE vendor_slug=$2 AND name=$3' USING r.sql, r.vendor, v_name;
        ELSE
            UPDATE rootcause.detection_steps
               SET content = jsonb_build_object('sql', r.sql)
             WHERE vendor_slug = r.vendor AND name = v_name;
        END IF;

        -- read back through the same path and assert byte equality
        IF v_enc THEN
            EXECUTE 'SELECT rootcause.dec(content)->>''sql'' FROM rootcause.detection_steps '
                    'WHERE vendor_slug=$1 AND name=$2' INTO v_cur USING r.vendor, v_name;
        ELSE
            SELECT content->>'sql' INTO v_cur FROM rootcause.detection_steps
             WHERE vendor_slug = r.vendor AND name = v_name;
        END IF;

        IF v_cur IS DISTINCT FROM r.sql THEN
            RAISE EXCEPTION '7570: verification FAILED for % - stored SQL differs from the specified text', r.vendor;
        END IF;

        RAISE NOTICE '7570: % - set (% chars)', r.vendor, length(r.sql);
        v_done := v_done + 1;
    END LOOP;

    RAISE NOTICE '7570: done - % updated, % already correct (storage=%)',
                 v_done, v_skip, CASE WHEN v_enc THEN 'encrypted' ELSE 'plaintext' END;
END $mig$;
