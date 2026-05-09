-- =============================================================================
-- recover_full_disk.sql
--
-- Customer recovery runbook for a DBDOME database that has filled the disk.
-- Truncates the high-volume runtime tables, reclaims the freed space, and
-- reviews replication slots that may be retaining WAL.
--
-- PRE-REQUISITES
--   * The PostgreSQL service is RUNNING. If it won't start, free a few
--     hundred MB on the data volume first (delete %TEMP%, old log files,
--     pgsql_tmp/ inside pg_data, etc.) and start the service before
--     running this script. Error 3534 on Windows almost always means
--     "could not write -- disk full".
--   * The dbdome collector service should ideally be STOPPED while this
--     runs, otherwise inflight INSERTs into monitoring.* / alerts.* may
--     conflict with the TRUNCATE / VACUUM FULL locks.
--
-- WHAT THIS SCRIPT DOES (5 phases)
--   1. Pre-state diagnostics: db size, top 30 largest tables, replication slots.
--   2. TRUNCATE monitoring.*, alerts.*, metrics.servers,
--      metrics.server_routines, log.operation_log  -- single transaction.
--   3. VACUUM FULL the same tables (now-empty -- harmless and quick).
--   4. Post-state diagnostics.
--   5. Replication-slot review with commented-out pg_drop_replication_slot
--      hints. Review carefully -- dropping a slot in active use breaks
--      replication.
--
-- SAFETY GUARD: refuses to run unless invoked with -v CONFIRM=yes.
--
-- USAGE
--   psql -h localhost -p 5444 -U dbdome_adm -d dbanalytics ^
--        -v CONFIRM=yes ^
--        -f recover_full_disk.sql
-- =============================================================================

\set ON_ERROR_STOP on

\if :{?CONFIRM}
  -- ok, proceed.
\else
  \echo
  \echo '====================================================================='
  \echo 'REFUSED: this script TRUNCATEs runtime tables (monitoring.*, alerts.*,'
  \echo '         metrics.servers, metrics.server_routines, log.operation_log)'
  \echo '         and then VACUUM FULLs them.'
  \echo
  \echo '         Re-run with the safety flag:'
  \echo '           psql ... -v CONFIRM=yes -f recover_full_disk.sql'
  \echo '====================================================================='
  \echo
  \quit
\endif

\timing on
\pset pager off

\echo
\echo '====================================================================='
\echo 'recover_full_disk.sql  --  DBDOME full-disk recovery'
\echo '====================================================================='

-- ----------------------------------------------------------------------------
-- 1. PRE-STATE DIAGNOSTICS
-- ----------------------------------------------------------------------------
\echo
\echo '--- 1a. database size (pre) ---'
SELECT current_database()                                    AS db,
       pg_size_pretty(pg_database_size(current_database()))  AS size;

\echo
\echo '--- 1b. top 30 tables by total size (incl indexes + toast) ---'
SELECT n.nspname || '.' || c.relname                          AS rel,
       pg_size_pretty(pg_total_relation_size(c.oid))          AS total,
       pg_size_pretty(pg_relation_size(c.oid))                AS heap,
       pg_size_pretty(pg_indexes_size(c.oid))                 AS indexes,
       (SELECT reltuples::bigint FROM pg_class WHERE oid=c.oid) AS approx_rows
  FROM pg_class       c
  JOIN pg_namespace   n ON n.oid = c.relnamespace
 WHERE c.relkind = 'r'
   AND n.nspname NOT IN ('pg_catalog','information_schema','pg_toast')
 ORDER BY pg_total_relation_size(c.oid) DESC
 LIMIT 30;

\echo
\echo '--- 1c. replication slots (potential WAL retention) ---'
SELECT slot_name,
       slot_type,
       active,
       database,
       restart_lsn,
       pg_size_pretty(
         pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)
       ) AS retained_wal
  FROM pg_replication_slots
 ORDER BY pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) DESC NULLS LAST;

\echo
\echo '--- 1d. pg_wal directory size (best-effort; needs file-fdw or superuser) ---'
SELECT count(*)                                       AS wal_segments,
       pg_size_pretty(sum((pg_stat_file(name)).size)) AS pg_wal_total
  FROM (SELECT 'pg_wal/' || file_name AS name
          FROM pg_ls_waldir()) f;

-- ----------------------------------------------------------------------------
-- 2. TRUNCATE RUNTIME TABLES (single transaction)
-- ----------------------------------------------------------------------------
\echo
\echo '--- 2. truncating runtime tables ---'

BEGIN;

DO $cleanup_mon$
DECLARE v_list text;
BEGIN
    SELECT string_agg(format('%I.%I', n.nspname, c.relname), ', ')
      INTO v_list
      FROM pg_class     c
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE c.relkind = 'r' AND n.nspname = 'monitoring';
    IF v_list IS NULL THEN
        RAISE NOTICE 'monitoring: no tables found.';
    ELSE
        RAISE NOTICE 'monitoring: truncating %', v_list;
        EXECUTE format('TRUNCATE TABLE %s RESTART IDENTITY CASCADE', v_list);
    END IF;
END
$cleanup_mon$;

DO $cleanup_alerts$
DECLARE v_list text;
BEGIN
    SELECT string_agg(format('%I.%I', n.nspname, c.relname), ', ')
      INTO v_list
      FROM pg_class     c
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE c.relkind = 'r' AND n.nspname = 'alerts';
    IF v_list IS NULL THEN
        RAISE NOTICE 'alerts: no tables found.';
    ELSE
        RAISE NOTICE 'alerts: truncating %', v_list;
        EXECUTE format('TRUNCATE TABLE %s RESTART IDENTITY CASCADE', v_list);
    END IF;
END
$cleanup_alerts$;

TRUNCATE TABLE metrics.servers,
               metrics.server_routines,
               log.operation_log
          RESTART IDENTITY CASCADE;

COMMIT;

-- ----------------------------------------------------------------------------
-- 3. VACUUM FULL on the truncated tables
--    \gexec runs each generated VACUUM FULL as its own top-level command --
--    necessary because VACUUM FULL cannot run inside a transaction or DO.
-- ----------------------------------------------------------------------------
\echo
\echo '--- 3. VACUUM FULL on truncated tables ---'

SELECT format('VACUUM FULL %I.%I;', n.nspname, c.relname) AS cmd
  FROM pg_class       c
  JOIN pg_namespace   n ON n.oid = c.relnamespace
 WHERE c.relkind = 'r'
   AND ( n.nspname IN ('monitoring','alerts')
      OR (n.nspname = 'metrics' AND c.relname IN ('servers','server_routines'))
      OR (n.nspname = 'log'     AND c.relname = 'operation_log') )
 ORDER BY n.nspname, c.relname
\gexec

-- ----------------------------------------------------------------------------
-- 4. POST-STATE DIAGNOSTICS
-- ----------------------------------------------------------------------------
\echo
\echo '--- 4a. database size (post) ---'
SELECT current_database()                                    AS db,
       pg_size_pretty(pg_database_size(current_database()))  AS size;

\echo
\echo '--- 4b. row counts on the cleaned tables (should all be 0) ---'
SELECT schemaname || '.' || relname AS rel,
       n_live_tup                   AS live_rows,
       pg_size_pretty(pg_total_relation_size((schemaname || '.' || relname)::regclass)) AS size
  FROM pg_stat_user_tables
 WHERE schemaname IN ('monitoring','alerts')
    OR (schemaname='metrics' AND relname IN ('servers','server_routines'))
    OR (schemaname='log'     AND relname = 'operation_log')
 ORDER BY 1;

-- ----------------------------------------------------------------------------
-- 5. REPLICATION SLOT REVIEW
-- ----------------------------------------------------------------------------
\echo
\echo '--- 5. replication slot review ---'
\echo 'Inactive slots that retain large WAL are a common cause of disk fill.'
\echo 'Each row below is a *commented* drop hint -- review carefully and only'
\echo 'uncomment a slot you are SURE is not in active use:'
\echo

SELECT format(
         '-- name=%I  active=%s  retained_wal=%s   ->   SELECT pg_drop_replication_slot(%L);',
         slot_name,
         active,
         pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)),
         slot_name)
  FROM pg_replication_slots
 ORDER BY pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) DESC NULLS LAST;

-- ----------------------------------------------------------------------------
\echo
\echo '====================================================================='
\echo 'recover_full_disk.sql  --  DONE.'
\echo '====================================================================='
\echo
\echo 'Recommended follow-ups:'
\echo '  * Confirm pg_database_size now fits within your headroom budget.'
\echo '  * Tighten config.retention_policy so monitoring rows age out.'
\echo '  * Schedule cleanup_runtime_data.sql via the DBDOME processes table'
\echo '    (or as a cron / Task Scheduler job) so this never reoccurs.'
\echo '  * If retained_wal in step 5 is still huge, investigate the slot'
\echo '    consumer and either restart it or drop the slot.'
\echo '====================================================================='
