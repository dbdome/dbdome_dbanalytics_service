-- =============================================================================
-- DBDOME runtime-data cleanup
--
-- Empties every operational table — schema/DDL is preserved. Use this to
-- reset a customer install, drop accumulated metric history before a re-pilot,
-- or wipe state after a test run.
--
-- Tables truncated (TRUNCATE ... RESTART IDENTITY CASCADE on each):
--
--   monitoring.*            -- every table in the schema (dynamic discovery)
--   alerts.*                -- every table in the schema (dynamic discovery)
--   metrics.servers
--   metrics.server_routines
--   log.operation_log
--
-- All other schemas (rootcause, config, jobs, processes, etc.) are LEFT
-- ALONE — taxonomy and configuration survive. Sequences are reset so a
-- fresh run starts from row_id 1.
--
-- Safety guard: refuses to run unless invoked with -v CONFIRM=yes.
--   psql -h localhost -p 5444 -U dbdome_adm -d dbanalytics \
--        -v CONFIRM=yes -f cleanup_runtime_data.sql
--
-- Single transaction: every TRUNCATE happens or nothing does. Re-running is
-- safe — TRUNCATE on already-empty tables is a no-op.
-- =============================================================================

\set ON_ERROR_STOP on

-- ----- 0. Safety guard --------------------------------------------------------
-- Refuse to run unless invoked with -v CONFIRM=yes
\if :{?CONFIRM}
  -- ok, CONFIRM was set on the command line; proceed.
\else
  \echo
  \echo '====================================================================='
  \echo 'REFUSED: this script truncates monitoring.*, alerts.*, metrics.servers,'
  \echo '         metrics.server_routines, and log.operation_log.'
  \echo
  \echo '         Re-run with the safety flag:'
  \echo '           psql ... -v CONFIRM=yes -f cleanup_runtime_data.sql'
  \echo '====================================================================='
  \echo
  \quit
\endif

\echo '====================================================================='
\echo 'DBDOME cleanup_runtime_data.sql -- truncating operational tables.'
\echo '====================================================================='

BEGIN;

-- ----- 1. Pre-cleanup audit (row counts) -------------------------------------
\echo
\echo '--- BEFORE ---'
SELECT n.nspname AS schema_name,
       c.relname  AS table_name,
       pg_catalog.pg_total_relation_size(c.oid) / 1024 AS size_kb,
       (SELECT reltuples::bigint
          FROM pg_class
         WHERE oid = c.oid)                            AS approx_rows
  FROM pg_class       c
  JOIN pg_namespace   n ON n.oid = c.relnamespace
 WHERE c.relkind = 'r'
   AND (
         n.nspname IN ('monitoring', 'alerts')
      OR (n.nspname = 'metrics' AND c.relname IN ('servers', 'server_routines'))
      OR (n.nspname = 'log'     AND c.relname = 'operation_log')
       )
 ORDER BY n.nspname, c.relname;

-- ----- 2. Truncate every table in monitoring.* ------------------------------
DO $cleanup_mon$
DECLARE
    v_list text;
BEGIN
    SELECT string_agg(format('%I.%I', n.nspname, c.relname), ', ')
      INTO v_list
      FROM pg_class     c
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE c.relkind = 'r'
       AND n.nspname = 'monitoring';

    IF v_list IS NULL THEN
        RAISE NOTICE 'monitoring schema: no tables found.';
    ELSE
        RAISE NOTICE 'monitoring: truncating %', v_list;
        EXECUTE format('TRUNCATE TABLE %s RESTART IDENTITY CASCADE', v_list);
    END IF;
END
$cleanup_mon$;

-- ----- 3. Truncate every table in alerts.* ----------------------------------
DO $cleanup_alerts$
DECLARE
    v_list text;
BEGIN
    SELECT string_agg(format('%I.%I', n.nspname, c.relname), ', ')
      INTO v_list
      FROM pg_class     c
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE c.relkind = 'r'
       AND n.nspname = 'alerts';

    IF v_list IS NULL THEN
        RAISE NOTICE 'alerts schema: no tables found.';
    ELSE
        RAISE NOTICE 'alerts: truncating %', v_list;
        EXECUTE format('TRUNCATE TABLE %s RESTART IDENTITY CASCADE', v_list);
    END IF;
END
$cleanup_alerts$;

-- ----- 4. Truncate the named tables in metrics + log ------------------------
TRUNCATE TABLE metrics.servers,
               metrics.server_routines,
               log.operation_log
          RESTART IDENTITY CASCADE;

-- ----- 5. Post-cleanup audit -------------------------------------------------
\echo
\echo '--- AFTER ---'
SELECT n.nspname AS schema_name,
       c.relname  AS table_name,
       (SELECT count(*)
          FROM (SELECT 1 FROM pg_class WHERE oid = c.oid) s)            AS exists,
       pg_catalog.pg_total_relation_size(c.oid) / 1024                  AS size_kb
  FROM pg_class       c
  JOIN pg_namespace   n ON n.oid = c.relnamespace
 WHERE c.relkind = 'r'
   AND (
         n.nspname IN ('monitoring', 'alerts')
      OR (n.nspname = 'metrics' AND c.relname IN ('servers', 'server_routines'))
      OR (n.nspname = 'log'     AND c.relname = 'operation_log')
       )
 ORDER BY n.nspname, c.relname;

\echo
\echo 'COMMIT-ing transaction...'
COMMIT;

\echo
\echo 'DONE. To verify zero rows:'
\echo "  SELECT relname, n_live_tup FROM pg_stat_user_tables"
\echo "   WHERE schemaname IN ('monitoring','alerts','metrics','log')"
\echo "  ORDER BY schemaname, relname;"




 --psql -h localhost -p 5444 -U dbdome_adm -d dbanalytics -v REPO_DB=dbanalytics_repo -f compare_dbanalytics_repo.sql > c:\install\compare.out