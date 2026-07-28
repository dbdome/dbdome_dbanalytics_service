-- =============================================================================
-- Register "Active transactions" query in metrics.custom_metrics for all vendors
-- =============================================================================
-- Run on: dbanalytics PostgreSQL (port 5432, db dbanalytics)
-- Vendors: oracle, sqlserver, postgresql, mysql
--
-- Column aliases for every vendor match monitoring.v_active_transactions
-- (the canonical MSSQL shape), so all vendors surface in that single view:
--   session_id, login_name, host_name, database_name, status, start_time,
--   command, cpu_time (ms), total_elapsed_time (ms), transaction_id,
--   transaction_name, query_text   (the collector adds server + entry_date).
--
-- Idempotent / self-healing:
--   * oracle/postgresql/mysql: any existing 'Active transactions' row (incl.
--     earlier non-canonical versions) is DELETEd then re-INSERTed canonically.
--   * sqlserver: inserted only if absent; the working MSSQL row is left as-is
--     since it is already canonical.
-- =============================================================================

BEGIN;

-- Fix the serial sequence if it has fallen behind (manual inserts elsewhere).
SELECT setval(
    pg_get_serial_sequence('metrics.custom_metrics', 'row_id'),
    (SELECT COALESCE(MAX(row_id), 1) FROM metrics.custom_metrics)
);

-- ======================= oracle =======================
DELETE FROM metrics.custom_metrics
 WHERE metric_name = 'Active transactions' AND lower(db_vendor) = 'oracle';

INSERT INTO metrics.custom_metrics (category_id, metric_name, query, description, is_active, db_vendor)
VALUES (-1, 'Active transactions',
'SELECT
    s.sid                                                 AS session_id,
    s.username                                            AS login_name,
    s.machine                                             AS host_name,
    sys_context(''USERENV'',''DB_NAME'')                  AS database_name,
    s.status                                              AS status,
    TO_DATE(t.start_time,''MM/DD/RR HH24:MI:SS'')         AS start_time,
    s.command                                             AS command,
    ROUND(NVL(q.cpu_time, 0) / 1000)                      AS cpu_time,
    ROUND((SYSDATE - TO_DATE(t.start_time,''MM/DD/RR HH24:MI:SS'')) * 86400 * 1000) AS total_elapsed_time,
    (t.xidusn || ''.'' || t.xidslot || ''.'' || t.xidsqn) AS transaction_id,
    t.name                                                AS transaction_name,
    REPLACE(REPLACE(REPLACE(
        DBMS_LOB.SUBSTR(q.sql_fulltext, 4000, 1),
        CHR(0), ''''), CHR(13), '' ''), CHR(10), '' '')   AS query_text
FROM v$transaction t
JOIN v$session s   ON s.taddr = t.addr
LEFT JOIN v$sql q  ON q.sql_id = s.sql_id AND q.child_number = s.sql_child_number
WHERE s.type = ''USER''',
'Active (open) transactions on Oracle - joins v$transaction to v$session. Aliased to the monitoring.v_active_transactions shape (session, login, host, status, start_time, command, cpu/elapsed ms, XID, name, SQL text).',
true, 'oracle');

-- ======================= sqlserver =======================
-- Canonical shape (matches monitoring.v_active_transactions). Replaces any
-- existing mssql/sqlserver row so database_name is included.
DELETE FROM metrics.custom_metrics
 WHERE metric_name = 'Active transactions' AND lower(db_vendor) IN ('mssql', 'sqlserver');

INSERT INTO metrics.custom_metrics (category_id, metric_name, query, description, is_active, db_vendor)
VALUES (-1, 'Active transactions',
'SELECT
    s.session_id        AS session_id,
    s.login_name        AS login_name,
    s.host_name         AS host_name,
    DB_NAME(s.database_id) AS database_name,
    r.status            AS status,
    r.start_time        AS start_time,
    r.command           AS command,
    r.cpu_time          AS cpu_time,
    r.total_elapsed_time AS total_elapsed_time,
    at.transaction_id   AS transaction_id,
    at.name             AS transaction_name,
    LEFT(REPLACE(REPLACE(REPLACE(t.text, NCHAR(0), N''''), CHAR(13), N'' ''), CHAR(10), N'' ''), 4000) AS query_text
FROM sys.dm_exec_sessions s
JOIN sys.dm_exec_requests r              ON r.session_id = s.session_id
JOIN sys.dm_tran_session_transactions st ON st.session_id = s.session_id
JOIN sys.dm_tran_active_transactions at  ON at.transaction_id = st.transaction_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE s.is_user_process = 1
  AND t.text IS NOT NULL',
'Active (open) transactions on SQL Server - joins dm_tran_active_transactions to dm_exec_sessions/requests. Matches the monitoring.v_active_transactions shape.',
true, 'sqlserver');

-- ======================= postgresql =======================
-- PostgreSQL has no per-session CPU counter (cpu_time = NULL); command carries
-- the wait state.
DELETE FROM metrics.custom_metrics
 WHERE metric_name = 'Active transactions' AND lower(db_vendor) IN ('postgres', 'postgresql');

INSERT INTO metrics.custom_metrics (category_id, metric_name, query, description, is_active, db_vendor)
VALUES (-1, 'Active transactions',
'SELECT
    pid                                                   AS session_id,
    usename                                               AS login_name,
    host(client_addr)                                     AS host_name,
    datname                                               AS database_name,
    state                                                 AS status,
    xact_start                                            AS start_time,
    coalesce(wait_event_type, ''CPU'')                    AS command,
    NULL::int                                             AS cpu_time,
    (EXTRACT(EPOCH FROM (now() - xact_start)) * 1000)::bigint AS total_elapsed_time,
    backend_xid::text                                     AS transaction_id,
    application_name                                      AS transaction_name,
    LEFT(query, 4000)                                     AS query_text
FROM pg_stat_activity
WHERE xact_start IS NOT NULL AND pid <> pg_backend_pid()
ORDER BY xact_start',
'Active (open) transactions on PostgreSQL - rows from pg_stat_activity with a non-null xact_start, aliased to the monitoring.v_active_transactions shape.',
true, 'postgresql');

-- ======================= mysql =======================
-- MySQL has no per-transaction CPU counter (cpu_time = NULL).
DELETE FROM metrics.custom_metrics
 WHERE metric_name = 'Active transactions' AND lower(db_vendor) IN ('mysql', 'mariadb');

INSERT INTO metrics.custom_metrics (category_id, metric_name, query, description, is_active, db_vendor)
VALUES (-1, 'Active transactions',
'SELECT
    trx.trx_mysql_thread_id                               AS session_id,
    p.user                                                AS login_name,
    p.host                                                AS host_name,
    p.db                                                  AS database_name,
    trx.trx_state                                         AS status,
    trx.trx_started                                       AS start_time,
    p.command                                             AS command,
    NULL                                                  AS cpu_time,
    (TIMESTAMPDIFF(SECOND, trx.trx_started, NOW()) * 1000) AS total_elapsed_time,
    trx.trx_id                                            AS transaction_id,
    NULL                                                  AS transaction_name,
    LEFT(trx.trx_query, 4000)                             AS query_text
FROM information_schema.innodb_trx trx
LEFT JOIN information_schema.processlist p ON trx.trx_mysql_thread_id = p.id
ORDER BY trx.trx_started',
'Active (open) transactions on MySQL/MariaDB - rows from information_schema.innodb_trx joined to processlist, aliased to the monitoring.v_active_transactions shape.',
true, 'mysql');

-- ======================= informix =======================
-- Realign the pre-existing Informix metric to the canonical shape so it also
-- surfaces in monitoring.v_active_transactions. Informix has no SQL text or CPU
-- in systrans; tx_begtime is epoch seconds (-> *1000 for the view's ms cast).
DELETE FROM metrics.custom_metrics
 WHERE metric_name = 'Active transactions' AND lower(db_vendor) = 'informix';

INSERT INTO metrics.custom_metrics (category_id, metric_name, query, description, is_active, db_vendor)
VALUES (-1, 'Active transactions',
'SELECT
    t.tx_owner                                            AS session_id,
    s.username                                            AS login_name,
    s.hostname                                            AS host_name,
    NULL                                                  AS database_name,
    CASE t.tx_flags
        WHEN 0 THEN ''inactive''
        WHEN 1 THEN ''active''
        WHEN 2 THEN ''committed''
        WHEN 4 THEN ''rolled back''
        ELSE ''other ('' || t.tx_flags || '')''
    END                                                   AS status,
    t.tx_begtime * 1000                                   AS start_time,
    s.progname                                            AS command,
    NULL                                                  AS cpu_time,
    (DBINFO(''utc_current'') - t.tx_begtime) * 1000       AS total_elapsed_time,
    t.tx_id                                               AS transaction_id,
    NULL                                                  AS transaction_name,
    NULL                                                  AS query_text
FROM sysmaster:systrans t
JOIN sysmaster:syssessions s ON s.sid = t.tx_owner
ORDER BY total_elapsed_time DESC',
'Active (open) transactions on Informix - sysmaster:systrans joined to syssessions, aliased to the monitoring.v_active_transactions shape (no SQL text / CPU available).',
true, 'informix');

-- Verify: every vendor should now carry the canonical shape incl. database_name.
SELECT row_id, db_vendor, metric_name, is_active,
       (query LIKE '%total_elapsed_time%' AND query LIKE '%query_text%') AS canonical_shape,
       (query LIKE '%database_name%') AS has_database_name
FROM metrics.custom_metrics
WHERE metric_name = 'Active transactions'
ORDER BY db_vendor;

COMMIT;
