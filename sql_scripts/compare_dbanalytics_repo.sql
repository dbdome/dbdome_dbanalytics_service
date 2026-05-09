-- =============================================================================
-- compare_dbanalytics_repo.sql
--
-- Compare the live `dbanalytics` database against a canonical
-- `dbanalytics_repo` template using dblink. Two phases:
--
--   PHASE 1 -- schema (DDL): schemas, tables, columns, constraints, indexes,
--              sequences, views, functions, types.
--   PHASE 2 -- non-runtime data: row-level diff of an allow-list of tables
--              (rootcause.*, config.*, definitions in metrics/jobs/processes).
--              Runtime tables (servers, server_routines, executions,
--              monitoring.*, alerts.*, log.*) are deliberately excluded.
--
-- Output legend (column "m"):
--    -   only in src  (live db has it, repo does not)
--    +   only in dst  (repo has it, live db is behind)
--    ~   present in both, content differs
--
-- Usage:
--   psql -h <host> -p 5444 -U dbdome_adm -d dbanalytics \
--        -v REPO_DB=dbanalytics_repo \
--        -f compare_dbanalytics_repo.sql > compare.out
--
--   By default the dblink connection inherits host/port/user from the
--   current psql session via inet_server_addr() / inet_server_port() /
--   current_user, so it always targets the same cluster you're already
--   connected to. If those are NULL (Unix-socket / local connection)
--   the script falls back to localhost:5444. Override with:
--      -v REPO_HOST=...
--      -v REPO_PORT=5444
--      -v REPO_USER=...
--      -v REPO_PASSWORD=...
--
--   dblink runs server-side, so it CANNOT see the client's PGPASSWORD or
--   ~/.pgpass. Either pass -v REPO_PASSWORD=... at the command line, or
--   place the password in the postgres OS user's pgpass file on the
--   server (Windows: %APPDATA%\postgresql\pgpass.conf, *nix: ~/.pgpass).
--
-- Both databases must be on the same cluster (dblink uses host/port/dbname).
-- The script is read-only: no CREATE / DROP outside of TEMP scope.
-- =============================================================================

\set ON_ERROR_STOP on

\if :{?REPO_DB}
\else
  \set REPO_DB dbanalytics_repo
\endif

CREATE EXTENSION IF NOT EXISTS dblink;

-- Capture the current psql session's host/port/user so dblink targets the
-- same cluster by default. inet_server_addr() / inet_server_port() are NULL
-- when connecting via Unix socket -- coalesce to sensible defaults.
SELECT
  coalesce(host(inet_server_addr()), 'localhost') AS host,
  coalesce(inet_server_port()::text, '5444')      AS port,
  current_user                                    AS usr
\gset auto_

\if :{?REPO_HOST}
\else
\set REPO_HOST :auto_host
\endif

\if :{?REPO_PORT}
\else
\set REPO_PORT :auto_port
\endif

\if :{?REPO_USER}
\else
\set REPO_USER :auto_usr
\endif

\if :{?REPO_PASSWORD}
\else
\set REPO_PASSWORD ''
\endif

\echo
\echo '====================================================================='
\echo 'compare_dbanalytics_repo.sql'
\echo '   src = current database (\\conninfo to confirm)'
\echo '   dst = ':REPO_USER'@':REPO_HOST':':REPO_PORT'/':REPO_DB
\echo '====================================================================='

-- (re)connect dblink to the repo database
SELECT CASE WHEN 'repo' = ANY(coalesce(dblink_get_connections(), '{}'::text[]))
            THEN dblink_disconnect('repo') ELSE 'noop' END AS dblink_setup;
SELECT dblink_connect('repo',
  format('host=%s port=%s user=%s dbname=%s%s',
         :'REPO_HOST', :'REPO_PORT', :'REPO_USER', :'REPO_DB',
         CASE WHEN :'REPO_PASSWORD' = '' THEN ''
              ELSE ' password=' || :'REPO_PASSWORD' END)) AS dblink_setup;

\pset pager off
\pset null '(null)'

-- ============================================================================
-- PHASE 1 -- schema (DDL)
-- ============================================================================
\echo
\echo '# ====================  PHASE 1: schema (DDL)  ===================='

-- ----------------------------------------------------------------------------
-- 1.1 schemas
-- ----------------------------------------------------------------------------
\echo
\echo '--- Schemas ---'

WITH src AS (
  SELECT nspname::text AS nspname
    FROM pg_namespace
   WHERE nspname NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
     AND nspname NOT LIKE 'pg\_temp\_%'
     AND nspname NOT LIKE 'pg\_toast\_temp\_%'
), dst AS (
  SELECT * FROM dblink('repo', $$
    SELECT nspname::text FROM pg_namespace
     WHERE nspname NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
       AND nspname NOT LIKE 'pg\_temp\_%'
       AND nspname NOT LIKE 'pg\_toast\_temp\_%'
  $$) AS t(nspname text)
)
SELECT '-' AS m, nspname FROM (SELECT nspname FROM src EXCEPT SELECT nspname FROM dst) x
UNION ALL
SELECT '+', nspname FROM (SELECT nspname FROM dst EXCEPT SELECT nspname FROM src) x
ORDER BY 1, 2;

-- ----------------------------------------------------------------------------
-- 1.2 tables / views (kind only)
-- ----------------------------------------------------------------------------
\echo
\echo '--- Tables / views ---'

WITH src AS (
  SELECT table_schema::text, table_name::text, table_type::text
    FROM information_schema.tables
   WHERE table_schema NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
), dst AS (
  SELECT * FROM dblink('repo', $$
    SELECT table_schema::text, table_name::text, table_type::text
      FROM information_schema.tables
     WHERE table_schema NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
  $$) AS t(table_schema text, table_name text, table_type text)
)
SELECT '-' AS m, s.table_schema, s.table_name,
       s.table_type AS src_kind, NULL::text AS dst_kind
  FROM src s
 WHERE NOT EXISTS (SELECT 1 FROM dst d
                    WHERE d.table_schema=s.table_schema AND d.table_name=s.table_name)
UNION ALL
SELECT '+', d.table_schema, d.table_name, NULL, d.table_type
  FROM dst d
 WHERE NOT EXISTS (SELECT 1 FROM src s
                    WHERE s.table_schema=d.table_schema AND s.table_name=d.table_name)
UNION ALL
SELECT '~', s.table_schema, s.table_name, s.table_type, d.table_type
  FROM src s JOIN dst d USING (table_schema, table_name)
 WHERE s.table_type IS DISTINCT FROM d.table_type
ORDER BY 2, 3, 1;

-- ----------------------------------------------------------------------------
-- 1.3 columns
-- ----------------------------------------------------------------------------
\echo
\echo '--- Columns ---'

WITH src AS (
  SELECT table_schema::text, table_name::text, column_name::text,
         ordinal_position::int,
         udt_name::text             AS data_type,
         character_maximum_length   AS char_max,
         numeric_precision          AS num_prec,
         numeric_scale              AS num_scale,
         is_nullable::text,
         column_default::text
    FROM information_schema.columns
   WHERE table_schema NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
), dst AS (
  SELECT * FROM dblink('repo', $$
    SELECT table_schema::text, table_name::text, column_name::text,
           ordinal_position::int,
           udt_name::text,
           character_maximum_length,
           numeric_precision,
           numeric_scale,
           is_nullable::text,
           column_default::text
      FROM information_schema.columns
     WHERE table_schema NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
  $$) AS t(table_schema text, table_name text, column_name text,
           ordinal_position int, data_type text, char_max int,
           num_prec int, num_scale int, is_nullable text, column_default text)
)
SELECT '-' AS m, s.table_schema, s.table_name, s.column_name,
       s.data_type::text AS src_def, NULL::text AS dst_def
  FROM src s
 WHERE NOT EXISTS (SELECT 1 FROM dst d
                    WHERE d.table_schema=s.table_schema
                      AND d.table_name=s.table_name
                      AND d.column_name=s.column_name)
UNION ALL
SELECT '+', d.table_schema, d.table_name, d.column_name,
       NULL, d.data_type
  FROM dst d
 WHERE NOT EXISTS (SELECT 1 FROM src s
                    WHERE s.table_schema=d.table_schema
                      AND s.table_name=d.table_name
                      AND s.column_name=d.column_name)
UNION ALL
SELECT '~', s.table_schema, s.table_name, s.column_name,
       format('%s null=%s default=%s pos=%s', s.data_type, s.is_nullable,
              coalesce(s.column_default,''), s.ordinal_position),
       format('%s null=%s default=%s pos=%s', d.data_type, d.is_nullable,
              coalesce(d.column_default,''), d.ordinal_position)
  FROM src s JOIN dst d USING (table_schema, table_name, column_name)
 WHERE row(s.data_type, s.char_max, s.num_prec, s.num_scale,
          s.is_nullable, coalesce(s.column_default,''), s.ordinal_position)
    IS DISTINCT FROM
       row(d.data_type, d.char_max, d.num_prec, d.num_scale,
           d.is_nullable, coalesce(d.column_default,''), d.ordinal_position)
ORDER BY 2, 3, 4, 1;

-- ----------------------------------------------------------------------------
-- 1.4 constraints
-- ----------------------------------------------------------------------------
\echo
\echo '--- Constraints ---'

WITH src AS (
  SELECT n.nspname::text  AS schema_name,
         cl.relname::text AS table_name,
         c.conname::text  AS constraint_name,
         c.contype::text  AS constraint_type,
         pg_get_constraintdef(c.oid)::text AS definition
    FROM pg_constraint c
    JOIN pg_class cl    ON cl.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = cl.relnamespace
   WHERE n.nspname NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
), dst AS (
  SELECT * FROM dblink('repo', $$
    SELECT n.nspname::text, cl.relname::text, c.conname::text,
           c.contype::text, pg_get_constraintdef(c.oid)::text
      FROM pg_constraint c
      JOIN pg_class cl    ON cl.oid = c.conrelid
      JOIN pg_namespace n ON n.oid = cl.relnamespace
     WHERE n.nspname NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
  $$) AS t(schema_name text, table_name text, constraint_name text,
           constraint_type text, definition text)
)
SELECT '-' AS m, s.schema_name, s.table_name, s.constraint_name,
       s.definition AS src_def, NULL::text AS dst_def
  FROM src s
 WHERE NOT EXISTS (SELECT 1 FROM dst d
                    WHERE d.schema_name=s.schema_name AND d.table_name=s.table_name
                      AND d.constraint_name=s.constraint_name)
UNION ALL
SELECT '+', d.schema_name, d.table_name, d.constraint_name, NULL, d.definition
  FROM dst d
 WHERE NOT EXISTS (SELECT 1 FROM src s
                    WHERE s.schema_name=d.schema_name AND s.table_name=d.table_name
                      AND s.constraint_name=d.constraint_name)
UNION ALL
SELECT '~', s.schema_name, s.table_name, s.constraint_name, s.definition, d.definition
  FROM src s JOIN dst d USING (schema_name, table_name, constraint_name)
 WHERE s.constraint_type IS DISTINCT FROM d.constraint_type
    OR s.definition      IS DISTINCT FROM d.definition
ORDER BY 2, 3, 4, 1;

-- ----------------------------------------------------------------------------
-- 1.5 indexes
-- ----------------------------------------------------------------------------
\echo
\echo '--- Indexes ---'

WITH src AS (
  SELECT schemaname::text, tablename::text, indexname::text, indexdef::text
    FROM pg_indexes
   WHERE schemaname NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
), dst AS (
  SELECT * FROM dblink('repo', $$
    SELECT schemaname::text, tablename::text, indexname::text, indexdef::text
      FROM pg_indexes
     WHERE schemaname NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
  $$) AS t(schemaname text, tablename text, indexname text, indexdef text)
)
SELECT '-' AS m, s.schemaname, s.tablename, s.indexname,
       s.indexdef AS src_def, NULL::text AS dst_def
  FROM src s
 WHERE NOT EXISTS (SELECT 1 FROM dst d
                    WHERE d.schemaname=s.schemaname AND d.tablename=s.tablename
                      AND d.indexname=s.indexname)
UNION ALL
SELECT '+', d.schemaname, d.tablename, d.indexname, NULL, d.indexdef
  FROM dst d
 WHERE NOT EXISTS (SELECT 1 FROM src s
                    WHERE s.schemaname=d.schemaname AND s.tablename=d.tablename
                      AND s.indexname=d.indexname)
UNION ALL
SELECT '~', s.schemaname, s.tablename, s.indexname, s.indexdef, d.indexdef
  FROM src s JOIN dst d USING (schemaname, tablename, indexname)
 WHERE s.indexdef IS DISTINCT FROM d.indexdef
ORDER BY 2, 3, 4, 1;

-- ----------------------------------------------------------------------------
-- 1.6 sequences
-- ----------------------------------------------------------------------------
\echo
\echo '--- Sequences ---'

WITH src AS (
  SELECT sequence_schema::text, sequence_name::text, data_type::text,
         start_value::text, minimum_value::text, maximum_value::text,
         increment::text, cycle_option::text
    FROM information_schema.sequences
   WHERE sequence_schema NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
), dst AS (
  SELECT * FROM dblink('repo', $$
    SELECT sequence_schema::text, sequence_name::text, data_type::text,
           start_value::text, minimum_value::text, maximum_value::text,
           increment::text, cycle_option::text
      FROM information_schema.sequences
     WHERE sequence_schema NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
  $$) AS t(sequence_schema text, sequence_name text, data_type text,
           start_value text, minimum_value text, maximum_value text,
           increment text, cycle_option text)
)
SELECT '-' AS m, s.sequence_schema, s.sequence_name,
       format('%s inc=%s min=%s max=%s', s.data_type, s.increment, s.minimum_value, s.maximum_value) AS src_def,
       NULL::text AS dst_def
  FROM src s
 WHERE NOT EXISTS (SELECT 1 FROM dst d
                    WHERE d.sequence_schema=s.sequence_schema AND d.sequence_name=s.sequence_name)
UNION ALL
SELECT '+', d.sequence_schema, d.sequence_name, NULL,
       format('%s inc=%s min=%s max=%s', d.data_type, d.increment, d.minimum_value, d.maximum_value)
  FROM dst d
 WHERE NOT EXISTS (SELECT 1 FROM src s
                    WHERE s.sequence_schema=d.sequence_schema AND s.sequence_name=d.sequence_name)
UNION ALL
SELECT '~', s.sequence_schema, s.sequence_name,
       format('%s inc=%s min=%s max=%s', s.data_type, s.increment, s.minimum_value, s.maximum_value),
       format('%s inc=%s min=%s max=%s', d.data_type, d.increment, d.minimum_value, d.maximum_value)
  FROM src s JOIN dst d USING (sequence_schema, sequence_name)
 WHERE row(s.data_type, s.increment, s.minimum_value, s.maximum_value, s.cycle_option)
    IS DISTINCT FROM
       row(d.data_type, d.increment, d.minimum_value, d.maximum_value, d.cycle_option)
ORDER BY 2, 3, 1;

-- ----------------------------------------------------------------------------
-- 1.7 views (definitions)
-- ----------------------------------------------------------------------------
\echo
\echo '--- Views ---'

WITH src AS (
  SELECT n.nspname::text  AS schema_name,
         c.relname::text  AS view_name,
         CASE c.relkind WHEN 'm' THEN 'MATERIALIZED' ELSE 'VIEW' END::text AS view_kind,
         pg_get_viewdef(c.oid, true)::text AS view_def
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE c.relkind IN ('v','m')
     AND n.nspname NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
), dst AS (
  SELECT * FROM dblink('repo', $$
    SELECT n.nspname::text, c.relname::text,
           CASE c.relkind WHEN 'm' THEN 'MATERIALIZED' ELSE 'VIEW' END::text,
           pg_get_viewdef(c.oid, true)::text
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE c.relkind IN ('v','m')
       AND n.nspname NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
  $$) AS t(schema_name text, view_name text, view_kind text, view_def text)
)
SELECT '-' AS m, s.schema_name, s.view_name, s.view_kind AS src_kind, NULL::text AS dst_kind
  FROM src s
 WHERE NOT EXISTS (SELECT 1 FROM dst d
                    WHERE d.schema_name=s.schema_name AND d.view_name=s.view_name)
UNION ALL
SELECT '+', d.schema_name, d.view_name, NULL, d.view_kind
  FROM dst d
 WHERE NOT EXISTS (SELECT 1 FROM src s
                    WHERE s.schema_name=d.schema_name AND s.view_name=d.view_name)
UNION ALL
SELECT '~', s.schema_name, s.view_name,
       'def differs (' || char_length(s.view_def) || ' chars)',
       'def differs (' || char_length(d.view_def) || ' chars)'
  FROM src s JOIN dst d USING (schema_name, view_name)
 WHERE s.view_kind IS DISTINCT FROM d.view_kind
    OR s.view_def  IS DISTINCT FROM d.view_def
ORDER BY 2, 3, 1;

-- ----------------------------------------------------------------------------
-- 1.8 functions / procedures
-- ----------------------------------------------------------------------------
\echo
\echo '--- Functions / procedures ---'

WITH src AS (
  SELECT n.nspname::text                                  AS schema_name,
         p.proname::text                                  AS function_name,
         pg_get_function_identity_arguments(p.oid)::text  AS args,
         pg_get_function_result(p.oid)::text              AS result_type,
         p.prokind::text                                  AS kind,
         md5(pg_get_functiondef(p.oid))                   AS def_hash
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
     AND NOT EXISTS (SELECT 1 FROM pg_depend d
                      WHERE d.objid = p.oid AND d.deptype = 'e')
), dst AS (
  SELECT * FROM dblink('repo', $$
    SELECT n.nspname::text, p.proname::text,
           pg_get_function_identity_arguments(p.oid)::text,
           pg_get_function_result(p.oid)::text,
           p.prokind::text,
           md5(pg_get_functiondef(p.oid))
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
       AND NOT EXISTS (SELECT 1 FROM pg_depend d
                        WHERE d.objid = p.oid AND d.deptype = 'e')
  $$) AS t(schema_name text, function_name text, args text,
           result_type text, kind text, def_hash text)
)
SELECT '-' AS m, s.schema_name, s.function_name, s.args,
       format('%s %s', s.kind, s.result_type) AS src_def, NULL::text AS dst_def
  FROM src s
 WHERE NOT EXISTS (SELECT 1 FROM dst d
                    WHERE d.schema_name=s.schema_name AND d.function_name=s.function_name
                      AND d.args=s.args)
UNION ALL
SELECT '+', d.schema_name, d.function_name, d.args, NULL,
       format('%s %s', d.kind, d.result_type)
  FROM dst d
 WHERE NOT EXISTS (SELECT 1 FROM src s
                    WHERE s.schema_name=d.schema_name AND s.function_name=d.function_name
                      AND s.args=d.args)
UNION ALL
SELECT '~', s.schema_name, s.function_name, s.args,
       format('%s %s body=%s', s.kind, s.result_type, left(s.def_hash, 8)),
       format('%s %s body=%s', d.kind, d.result_type, left(d.def_hash, 8))
  FROM src s JOIN dst d USING (schema_name, function_name, args)
 WHERE row(s.result_type, s.kind, s.def_hash)
    IS DISTINCT FROM
       row(d.result_type, d.kind, d.def_hash)
ORDER BY 2, 3, 4, 1;

-- ----------------------------------------------------------------------------
-- 1.9 types (enum / composite / domain)
-- ----------------------------------------------------------------------------
\echo
\echo '--- Types (enum / composite / domain) ---'

WITH src AS (
  SELECT n.nspname::text AS schema_name,
         t.typname::text AS type_name,
         t.typtype::text AS type_kind,
         CASE t.typtype
           WHEN 'e' THEN (SELECT string_agg(enumlabel, ',' ORDER BY enumsortorder)
                            FROM pg_enum WHERE enumtypid = t.oid)
           WHEN 'd' THEN format_type(t.typbasetype, t.typtypmod)
           WHEN 'c' THEN (SELECT string_agg(attname || ' ' || format_type(atttypid, atttypmod),
                                            ', ' ORDER BY attnum)
                            FROM pg_attribute
                           WHERE attrelid = t.typrelid AND attnum > 0 AND NOT attisdropped)
         END::text AS body
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
   WHERE t.typtype IN ('e','c','d')
     AND n.nspname NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
     AND NOT EXISTS (SELECT 1 FROM pg_class c
                      WHERE c.reltype = t.oid
                        AND c.relkind IN ('r','v','m','f','p'))
), dst AS (
  SELECT * FROM dblink('repo', $$
    SELECT n.nspname::text, t.typname::text, t.typtype::text,
           CASE t.typtype
             WHEN 'e' THEN (SELECT string_agg(enumlabel, ',' ORDER BY enumsortorder)
                              FROM pg_enum WHERE enumtypid = t.oid)
             WHEN 'd' THEN format_type(t.typbasetype, t.typtypmod)
             WHEN 'c' THEN (SELECT string_agg(attname || ' ' || format_type(atttypid, atttypmod),
                                              ', ' ORDER BY attnum)
                              FROM pg_attribute
                             WHERE attrelid = t.typrelid AND attnum > 0 AND NOT attisdropped)
           END::text
      FROM pg_type t
      JOIN pg_namespace n ON n.oid = t.typnamespace
     WHERE t.typtype IN ('e','c','d')
       AND n.nspname NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
       AND NOT EXISTS (SELECT 1 FROM pg_class c
                        WHERE c.reltype = t.oid
                          AND c.relkind IN ('r','v','m','f','p'))
  $$) AS t(schema_name text, type_name text, type_kind text, body text)
)
SELECT '-' AS m, s.schema_name, s.type_name, s.type_kind, s.body AS src_body, NULL::text AS dst_body
  FROM src s
 WHERE NOT EXISTS (SELECT 1 FROM dst d
                    WHERE d.schema_name=s.schema_name AND d.type_name=s.type_name)
UNION ALL
SELECT '+', d.schema_name, d.type_name, d.type_kind, NULL, d.body
  FROM dst d
 WHERE NOT EXISTS (SELECT 1 FROM src s
                    WHERE s.schema_name=d.schema_name AND s.type_name=d.type_name)
UNION ALL
SELECT '~', s.schema_name, s.type_name, s.type_kind, s.body, d.body
  FROM src s JOIN dst d USING (schema_name, type_name)
 WHERE row(s.type_kind, s.body) IS DISTINCT FROM row(d.type_kind, d.body)
ORDER BY 2, 3, 1;


-- ============================================================================
-- PHASE 2 -- non-runtime data
-- ============================================================================
\echo
\echo '# ====================  PHASE 2: non-runtime data  ===================='

-- ---- helper: generic row-level diff for a single (schema, table) pair -----
-- Returns one row per difference (marker, key_text, src_data, dst_data).
-- PK is auto-discovered from pg_index.indisprimary on the *local* side.
CREATE OR REPLACE FUNCTION pg_temp.diff_table(p_schema text, p_table text)
RETURNS TABLE(marker text, key_text text, src_data text, dst_data text)
LANGUAGE plpgsql AS $f$
DECLARE
    v_pk             text[];
    v_pk_select      text;
    v_src_query      text;
    v_dst_query      text;
    v_src_exists     boolean;
    v_dst_exists     boolean;
BEGIN
    SELECT EXISTS (
      SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = p_schema AND c.relname = p_table AND c.relkind = 'r')
      INTO v_src_exists;

    SELECT cnt > 0 INTO v_dst_exists
      FROM dblink('repo', format(
        $q$SELECT count(*)::int FROM pg_class c
             JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = %L AND c.relname = %L AND c.relkind = 'r'$q$,
        p_schema, p_table)) AS t(cnt int);

    IF NOT v_src_exists AND NOT v_dst_exists THEN
        RETURN;
    END IF;

    IF NOT v_src_exists THEN
        marker := '!';
        key_text := format('%I.%I', p_schema, p_table);
        src_data := 'src missing';
        dst_data := 'see schema phase';
        RETURN NEXT;
        RETURN;
    END IF;

    IF NOT v_dst_exists THEN
        marker := '!';
        key_text := format('%I.%I', p_schema, p_table);
        src_data := 'see schema phase';
        dst_data := 'dst missing';
        RETURN NEXT;
        RETURN;
    END IF;

    -- discover PK
    SELECT array_agg(a.attname::text ORDER BY array_position(i.indkey, a.attnum))
      INTO v_pk
      FROM pg_index i
      JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
      JOIN pg_class c     ON c.oid = i.indrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = p_schema AND c.relname = p_table AND i.indisprimary;

    IF v_pk IS NULL THEN
        -- no PK: full-row presence diff via row_to_json text
        v_src_query := format(
          $q$SELECT row_to_json(t.*)::text AS rj FROM %I.%I t$q$, p_schema, p_table);
        v_dst_query := format(
          $q$SELECT row_to_json(t.*)::text       FROM %I.%I t$q$, p_schema, p_table);

        RETURN QUERY EXECUTE format($q$
          WITH src AS (%s),
               dst AS (SELECT * FROM dblink('repo', %L) AS d(rj text))
          SELECT '-'::text, '(no-pk)'::text, rj, NULL::text
            FROM (SELECT rj FROM src EXCEPT ALL SELECT rj FROM dst) x
          UNION ALL
          SELECT '+'::text, '(no-pk)'::text, NULL::text, rj
            FROM (SELECT rj FROM dst EXCEPT ALL SELECT rj FROM src) x
        $q$, v_src_query, v_dst_query);

    ELSE
        -- build a portable text key: concat_ws('|', col1::text, col2::text, ...)
        SELECT 'concat_ws(''|'', ' ||
               string_agg(format('coalesce(%I::text, ''<null>'')', x), ', ') ||
               ')'
          INTO v_pk_select
          FROM unnest(v_pk) x;

        v_src_query := format(
          $q$SELECT %s AS k, row_to_json(t.*)::text AS rj FROM %I.%I t$q$,
          v_pk_select, p_schema, p_table);
        v_dst_query := format(
          $q$SELECT %s,        row_to_json(t.*)::text       FROM %I.%I t$q$,
          v_pk_select, p_schema, p_table);

        RETURN QUERY EXECUTE format($q$
          WITH src AS (%s),
               dst AS (SELECT * FROM dblink('repo', %L) AS d(k text, rj text))
          SELECT '-'::text, src.k, src.rj, NULL::text
            FROM src LEFT JOIN dst USING (k) WHERE dst.k IS NULL
          UNION ALL
          SELECT '+'::text, dst.k, NULL::text, dst.rj
            FROM dst LEFT JOIN src USING (k) WHERE src.k IS NULL
          UNION ALL
          SELECT '~'::text, src.k, src.rj, dst.rj
            FROM src JOIN dst USING (k) WHERE src.rj IS DISTINCT FROM dst.rj
        $q$, v_src_query, v_dst_query);
    END IF;
END
$f$;

-- ---- target list: tables that hold non-runtime (config / taxonomy) data ----
-- Edit this list to add/remove tables. Runtime tables (servers,
-- server_routines, executions, monitoring.*, alerts.*, log.*) MUST NOT
-- appear here -- a row diff over millions of rows is meaningless.
\echo
\echo '--- Phase 2 row-level diff (allow-list) ---'

WITH targets(schema_name, table_name) AS (
  VALUES
    -- rootcause taxonomy (entire detection tree)
    ('rootcause', 'vendors'),
    ('rootcause', 'database_types'),
    ('rootcause', 'risk_level'),
    ('rootcause', 'severity'),
    ('rootcause', 'domains'),
    ('rootcause', 'areas'),
    ('rootcause', 'issues'),
    ('rootcause', 'issue_domains'),
    ('rootcause', 'issue_root_causes'),
    ('rootcause', 'root_causes'),
    ('rootcause', 'detection_paths'),
    ('rootcause', 'detection_path_steps'),
    ('rootcause', 'detection_steps'),
    ('rootcause', 'resolution_paths'),
    ('rootcause', 'resolution_path_steps'),
    ('rootcause', 'resolution_steps'),

    -- config (mail / alerts / reports / SIEM / retention / global)
    ('config',    'global_params'),
    ('config',    'action_types'),
    ('config',    'mail_config'),
    ('config',    'mail_groups'),
    ('config',    'mail_jobs'),
    ('config',    'reports'),
    ('config',    'reports_jobs'),
    ('config',    'alerts'),
    ('config',    'alerts_reports'),
    ('config',    'alerts_thresholds'),
    ('config',    'thresholds'),
    ('config',    'webook_alerts'),
    ('config',    'retention_policy'),
    ('config',    'siem'),
    ('config',    'schema_versions'),

    -- metrics non-runtime (definitions, NOT customer servers)
    ('metrics',   'custom_metrics'),
    ('metrics',   'registered_processes'),
    ('metrics',   'routines'),
    ('metrics',   'sql_injection_patterns'),

    -- jobs / processes (templates only -- NOT executions / job_schedules)
    ('jobs',      'jobs'),
    ('processes', 'process'),
    ('processes', 'steps'),
    ('processes', 'organization')
)
SELECT format('%I.%I', t.schema_name, t.table_name) AS rel,
       d.marker  AS m,
       d.key_text AS key,
       CASE WHEN length(d.src_data) > 240
            THEN left(d.src_data, 240) || '...' ELSE d.src_data END AS src,
       CASE WHEN length(d.dst_data) > 240
            THEN left(d.dst_data, 240) || '...' ELSE d.dst_data END AS dst
  FROM targets t
  CROSS JOIN LATERAL pg_temp.diff_table(t.schema_name, t.table_name) d
 ORDER BY rel, m, key;

-- ============================================================================
-- cleanup
-- ============================================================================
SELECT dblink_disconnect('repo') AS dblink_teardown;

\echo
\echo '====================================================================='
\echo 'compare_dbanalytics_repo.sql -- DONE.'
\echo '====================================================================='
