-- =============================================================================
-- sync_dbanalytics_to_repo.sql
--
-- Generates an executable SQL script that, when applied to `dbanalytics`,
-- brings it into sync with `dbanalytics_repo`. The output is pure SQL:
-- CREATE / ALTER / DROP statements for schema drift, plus INSERT /
-- UPDATE / DELETE statements for non-runtime data drift.
--
-- Direction:   src = dbanalytics  (live)   ----->   dst = dbanalytics_repo
-- The output, applied to src, makes src look like dst.
--
-- Usage (capture output as a script, review, then apply):
--
--   psql -h <host> -p 5444 -U dbdome_adm -d dbanalytics \
--        -v REPO_DB=dbanalytics_repo \
--        -v REPO_PASSWORD=<password> \
--        -f sync_dbanalytics_to_repo.sql > sync.sql
--
--   # review sync.sql, then:
--   psql -h <host> -p 5444 -U dbdome_adm -d dbanalytics -f sync.sql
--
-- All destructive statements (DROP SCHEMA, DROP TABLE, DELETE FROM ...)
-- are commented out by default -- review and uncomment what you actually
-- want to apply.
--
-- Optional psql vars (same as compare_dbanalytics_repo.sql):
--   -v REPO_HOST=...   -v REPO_PORT=5444   -v REPO_USER=...   -v REPO_PASSWORD=...
-- Defaults inherit from the current psql session via inet_server_addr() /
-- inet_server_port() / current_user.
-- =============================================================================

\set ON_ERROR_STOP on

\if :{?REPO_DB}
\else
  \set REPO_DB dbanalytics_repo
\endif

CREATE EXTENSION IF NOT EXISTS dblink;

-- Inherit host/port/user from the current session by default.
SELECT
  coalesce(host(inet_server_addr()), 'localhost') AS host,
  coalesce(inet_server_port()::text, '5444')      AS port,
  current_user                                    AS usr
\gset auto_

\if :{?REPO_HOST} \else \set REPO_HOST :auto_host \endif
\if :{?REPO_PORT} \else \set REPO_PORT :auto_port \endif
\if :{?REPO_USER} \else \set REPO_USER :auto_usr  \endif
\if :{?REPO_PASSWORD} \else \set REPO_PASSWORD '' \endif

SELECT CASE WHEN 'repo' = ANY(coalesce(dblink_get_connections(), '{}'::text[]))
            THEN dblink_disconnect('repo') ELSE 'noop' END AS dblink_setup \gset trash_

SELECT dblink_connect('repo',
  format('host=%s port=%s user=%s dbname=%s%s',
         :'REPO_HOST', :'REPO_PORT', :'REPO_USER', :'REPO_DB',
         CASE WHEN :'REPO_PASSWORD' = '' THEN ''
              ELSE ' password=' || :'REPO_PASSWORD' END)) AS dblink_setup \gset trash_

-- Clean SQL output: no headers, no row counts, no padding.
\pset format unaligned
\pset tuples_only on
\pset footer off
\pset border 0
\pset null ''

-- ----------------------------------------------------------------------------
-- Banner
-- ----------------------------------------------------------------------------
SELECT '-- =============================================================';
SELECT '-- Sync script: dbanalytics  -->  ' || :'REPO_DB';
SELECT '-- Generated at ' || now()::text;
SELECT '-- Review carefully, especially commented-out DROP / DELETE blocks.';
SELECT '-- =============================================================';
SELECT '';
SELECT 'BEGIN;';
SELECT '';

-- ============================================================================
-- 1. SCHEMAS
-- ============================================================================
SELECT '-- ----- schemas -----';
WITH src AS (
  SELECT nspname::text FROM pg_namespace
   WHERE nspname NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
     AND nspname NOT LIKE 'pg\_temp\_%' AND nspname NOT LIKE 'pg\_toast\_temp\_%'
), dst AS (
  SELECT * FROM dblink('repo', $$
    SELECT nspname::text FROM pg_namespace
     WHERE nspname NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
       AND nspname NOT LIKE 'pg\_temp\_%' AND nspname NOT LIKE 'pg\_toast\_temp\_%'
  $$) AS t(nspname text)
)
SELECT format('CREATE SCHEMA IF NOT EXISTS %I;', d.nspname)
  FROM dst d WHERE NOT EXISTS (SELECT 1 FROM src s WHERE s.nspname = d.nspname)
ORDER BY 1;

-- ============================================================================
-- 2. TABLES (only-in-dst create empty shells; columns added in section 3)
-- ============================================================================
SELECT '';
SELECT '-- ----- tables (create empty shells; columns / constraints follow) -----';
WITH src AS (
  SELECT table_schema::text, table_name::text
    FROM information_schema.tables
   WHERE table_type = 'BASE TABLE'
     AND table_schema NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
), dst AS (
  SELECT * FROM dblink('repo', $$
    SELECT table_schema::text, table_name::text
      FROM information_schema.tables
     WHERE table_type = 'BASE TABLE'
       AND table_schema NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
  $$) AS t(table_schema text, table_name text)
)
SELECT format('CREATE TABLE IF NOT EXISTS %I.%I ();',
              d.table_schema, d.table_name)
  FROM dst d
 WHERE NOT EXISTS (SELECT 1 FROM src s
                    WHERE s.table_schema=d.table_schema AND s.table_name=d.table_name)
 ORDER BY 1;

-- ============================================================================
-- 3. COLUMNS
-- ============================================================================
SELECT '';
SELECT '-- ----- columns: ADD (only-in-dst) -----';
WITH src AS (
  SELECT table_schema::text, table_name::text, column_name::text,
         udt_name::text AS data_type,
         character_maximum_length AS char_max,
         numeric_precision        AS num_prec,
         numeric_scale            AS num_scale,
         is_nullable::text,
         column_default::text,
         ordinal_position::int
    FROM information_schema.columns
   WHERE table_schema NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
), dst AS (
  SELECT * FROM dblink('repo', $$
    SELECT table_schema::text, table_name::text, column_name::text,
           udt_name::text, character_maximum_length, numeric_precision,
           numeric_scale, is_nullable::text, column_default::text,
           ordinal_position::int
      FROM information_schema.columns
     WHERE table_schema NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
  $$) AS t(table_schema text, table_name text, column_name text,
           data_type text, char_max int, num_prec int, num_scale int,
           is_nullable text, column_default text, ordinal_position int)
)
SELECT format('ALTER TABLE %I.%I ADD COLUMN IF NOT EXISTS %I %s%s%s;',
              d.table_schema, d.table_name, d.column_name,
              CASE
                WHEN d.data_type IN ('varchar','bpchar') AND d.char_max IS NOT NULL
                  THEN d.data_type || '(' || d.char_max || ')'
                WHEN d.data_type = 'numeric' AND d.num_prec IS NOT NULL
                  THEN 'numeric(' || d.num_prec
                       || coalesce(',' || d.num_scale, '') || ')'
                ELSE d.data_type
              END,
              CASE WHEN d.is_nullable = 'NO' THEN ' NOT NULL' ELSE '' END,
              CASE WHEN d.column_default IS NOT NULL
                   THEN ' DEFAULT ' || d.column_default ELSE '' END)
  FROM dst d
 WHERE NOT EXISTS (SELECT 1 FROM src s
                    WHERE s.table_schema=d.table_schema
                      AND s.table_name  =d.table_name
                      AND s.column_name =d.column_name)
 ORDER BY d.table_schema, d.table_name, d.ordinal_position;

SELECT '';
SELECT '-- ----- columns: ALTER (definition differs) -----';
WITH src AS (
  SELECT table_schema::text, table_name::text, column_name::text,
         udt_name::text AS data_type,
         character_maximum_length AS char_max,
         numeric_precision        AS num_prec,
         numeric_scale            AS num_scale,
         is_nullable::text,
         column_default::text
    FROM information_schema.columns
   WHERE table_schema NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
), dst AS (
  SELECT * FROM dblink('repo', $$
    SELECT table_schema::text, table_name::text, column_name::text,
           udt_name::text, character_maximum_length, numeric_precision,
           numeric_scale, is_nullable::text, column_default::text
      FROM information_schema.columns
     WHERE table_schema NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
  $$) AS t(table_schema text, table_name text, column_name text,
           data_type text, char_max int, num_prec int, num_scale int,
           is_nullable text, column_default text)
), j AS (
  SELECT s.table_schema, s.table_name, s.column_name,
         s.data_type   AS s_type,    d.data_type   AS d_type,
         s.char_max    AS s_char,    d.char_max    AS d_char,
         s.num_prec    AS s_prec,    d.num_prec    AS d_prec,
         s.num_scale   AS s_scale,   d.num_scale   AS d_scale,
         s.is_nullable AS s_null,    d.is_nullable AS d_null,
         s.column_default AS s_def,  d.column_default AS d_def
    FROM src s JOIN dst d USING (table_schema, table_name, column_name)
)
SELECT stmt FROM (
  -- type / size changes
  SELECT 1 AS ord, j.table_schema, j.table_name, j.column_name,
         format('ALTER TABLE %I.%I ALTER COLUMN %I TYPE %s;',
                j.table_schema, j.table_name, j.column_name,
                CASE
                  WHEN j.d_type IN ('varchar','bpchar') AND j.d_char IS NOT NULL
                    THEN j.d_type || '(' || j.d_char || ')'
                  WHEN j.d_type = 'numeric' AND j.d_prec IS NOT NULL
                    THEN 'numeric(' || j.d_prec || coalesce(',' || j.d_scale, '') || ')'
                  ELSE j.d_type
                END) AS stmt
    FROM j
   WHERE row(j.s_type, j.s_char, j.s_prec, j.s_scale)
      IS DISTINCT FROM
         row(j.d_type, j.d_char, j.d_prec, j.d_scale)
  UNION ALL
  -- nullability changes
  SELECT 2, j.table_schema, j.table_name, j.column_name,
         format('ALTER TABLE %I.%I ALTER COLUMN %I %s NOT NULL;',
                j.table_schema, j.table_name, j.column_name,
                CASE WHEN j.d_null = 'NO' THEN 'SET' ELSE 'DROP' END)
    FROM j WHERE j.s_null IS DISTINCT FROM j.d_null
  UNION ALL
  -- default changes
  SELECT 3, j.table_schema, j.table_name, j.column_name,
         format('ALTER TABLE %I.%I ALTER COLUMN %I %s;',
                j.table_schema, j.table_name, j.column_name,
                CASE WHEN j.d_def IS NULL THEN 'DROP DEFAULT'
                     ELSE 'SET DEFAULT ' || j.d_def END)
    FROM j WHERE coalesce(j.s_def, '') IS DISTINCT FROM coalesce(j.d_def, '')
) z
ORDER BY z.table_schema, z.table_name, z.column_name, z.ord;

-- ============================================================================
-- 4. CONSTRAINTS (add only-in-dst; replace differing)
-- ============================================================================
SELECT '';
SELECT '-- ----- constraints: ADD / REPLACE -----';
WITH src AS (
  SELECT n.nspname::text AS schema_name, cl.relname::text AS table_name,
         c.conname::text AS constraint_name,
         pg_get_constraintdef(c.oid)::text AS definition
    FROM pg_constraint c
    JOIN pg_class cl ON cl.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = cl.relnamespace
   WHERE n.nspname NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
), dst AS (
  SELECT * FROM dblink('repo', $$
    SELECT n.nspname::text, cl.relname::text, c.conname::text,
           pg_get_constraintdef(c.oid)::text
      FROM pg_constraint c
      JOIN pg_class cl ON cl.oid = c.conrelid
      JOIN pg_namespace n ON n.oid = cl.relnamespace
     WHERE n.nspname NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
  $$) AS t(schema_name text, table_name text, constraint_name text, definition text)
)
SELECT stmt FROM (
  -- only-in-dst: just ADD
  SELECT 1 AS ord, d.schema_name, d.table_name, d.constraint_name,
         format('ALTER TABLE %I.%I ADD CONSTRAINT %I %s;',
                d.schema_name, d.table_name, d.constraint_name, d.definition) AS stmt
    FROM dst d
   WHERE NOT EXISTS (SELECT 1 FROM src s
                      WHERE s.schema_name=d.schema_name
                        AND s.table_name=d.table_name
                        AND s.constraint_name=d.constraint_name)
  UNION ALL
  -- differing: DROP then ADD
  SELECT 2, d.schema_name, d.table_name, d.constraint_name,
         format('ALTER TABLE %I.%I DROP CONSTRAINT IF EXISTS %I; ALTER TABLE %I.%I ADD CONSTRAINT %I %s;',
                d.schema_name, d.table_name, d.constraint_name,
                d.schema_name, d.table_name, d.constraint_name, d.definition)
    FROM src s JOIN dst d USING (schema_name, table_name, constraint_name)
   WHERE s.definition IS DISTINCT FROM d.definition
) z
ORDER BY z.schema_name, z.table_name, z.ord, z.constraint_name;

-- ============================================================================
-- 5. INDEXES (add only-in-dst; replace differing)
-- ============================================================================
SELECT '';
SELECT '-- ----- indexes: CREATE / REPLACE -----';
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
SELECT stmt FROM (
  SELECT 1 AS ord, d.schemaname, d.indexname, d.indexdef || ';' AS stmt
    FROM dst d
   WHERE NOT EXISTS (SELECT 1 FROM src s
                      WHERE s.schemaname=d.schemaname AND s.indexname=d.indexname)
  UNION ALL
  SELECT 2, d.schemaname, d.indexname,
         format('DROP INDEX IF EXISTS %I.%I; %s;',
                d.schemaname, d.indexname, d.indexdef)
    FROM src s JOIN dst d USING (schemaname, tablename, indexname)
   WHERE s.indexdef IS DISTINCT FROM d.indexdef
) z
ORDER BY z.schemaname, z.ord, z.indexname;

-- ============================================================================
-- 6. SEQUENCES (create only-in-dst; alter differing)
-- ============================================================================
SELECT '';
SELECT '-- ----- sequences: CREATE / ALTER -----';
WITH src AS (
  SELECT sequence_schema::text, sequence_name::text,
         data_type::text, increment::text, minimum_value::text, maximum_value::text
    FROM information_schema.sequences
   WHERE sequence_schema NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
), dst AS (
  SELECT * FROM dblink('repo', $$
    SELECT sequence_schema::text, sequence_name::text,
           data_type::text, increment::text, minimum_value::text, maximum_value::text
      FROM information_schema.sequences
     WHERE sequence_schema NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
  $$) AS t(sequence_schema text, sequence_name text,
           data_type text, increment text, minimum_value text, maximum_value text)
)
SELECT stmt FROM (
  SELECT 1 AS ord, d.sequence_schema, d.sequence_name,
         format('CREATE SEQUENCE IF NOT EXISTS %I.%I AS %s INCREMENT %s MINVALUE %s MAXVALUE %s;',
                d.sequence_schema, d.sequence_name, d.data_type,
                d.increment, d.minimum_value, d.maximum_value) AS stmt
    FROM dst d
   WHERE NOT EXISTS (SELECT 1 FROM src s
                      WHERE s.sequence_schema=d.sequence_schema
                        AND s.sequence_name=d.sequence_name)
  UNION ALL
  SELECT 2, d.sequence_schema, d.sequence_name,
         format('ALTER SEQUENCE %I.%I INCREMENT BY %s MINVALUE %s MAXVALUE %s;',
                d.sequence_schema, d.sequence_name,
                d.increment, d.minimum_value, d.maximum_value)
    FROM src s JOIN dst d USING (sequence_schema, sequence_name)
   WHERE row(s.data_type, s.increment, s.minimum_value, s.maximum_value)
      IS DISTINCT FROM
         row(d.data_type, d.increment, d.minimum_value, d.maximum_value)
) z
ORDER BY z.sequence_schema, z.ord, z.sequence_name;

-- ============================================================================
-- 7. VIEWS  (CREATE OR REPLACE for both new and changed)
-- ============================================================================
SELECT '';
SELECT '-- ----- views: CREATE OR REPLACE -----';
WITH src AS (
  SELECT n.nspname::text AS schema_name, c.relname::text AS view_name,
         CASE c.relkind WHEN 'm' THEN 'MATERIALIZED' ELSE '' END::text AS kw,
         pg_get_viewdef(c.oid, true)::text AS view_def
    FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE c.relkind IN ('v','m')
     AND n.nspname NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
), dst AS (
  SELECT * FROM dblink('repo', $$
    SELECT n.nspname::text, c.relname::text,
           CASE c.relkind WHEN 'm' THEN 'MATERIALIZED' ELSE '' END::text,
           pg_get_viewdef(c.oid, true)::text
      FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
     WHERE c.relkind IN ('v','m')
       AND n.nspname NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
  $$) AS t(schema_name text, view_name text, kw text, view_def text)
)
SELECT format('CREATE OR REPLACE %s VIEW %I.%I AS %s%s',
              d.kw, d.schema_name, d.view_name,
              d.view_def,
              CASE WHEN right(rtrim(d.view_def), 1) = ';' THEN '' ELSE ';' END)
  FROM dst d
  LEFT JOIN src s USING (schema_name, view_name)
 WHERE s.view_name IS NULL OR s.view_def IS DISTINCT FROM d.view_def
 ORDER BY d.schema_name, d.view_name;

-- ============================================================================
-- 8. FUNCTIONS / PROCEDURES  (CREATE OR REPLACE; full def from dst)
-- ============================================================================
SELECT '';
SELECT '-- ----- functions / procedures: CREATE OR REPLACE -----';
WITH src AS (
  SELECT n.nspname::text                                  AS schema_name,
         p.proname::text                                  AS function_name,
         pg_get_function_identity_arguments(p.oid)::text  AS args,
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
           md5(pg_get_functiondef(p.oid)),
           pg_get_functiondef(p.oid)::text
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
       AND NOT EXISTS (SELECT 1 FROM pg_depend d
                        WHERE d.objid = p.oid AND d.deptype = 'e')
  $$) AS t(schema_name text, function_name text, args text,
           def_hash text, def_text text)
)
SELECT d.def_text ||
       CASE WHEN right(rtrim(d.def_text), 1) = ';' THEN '' ELSE ';' END
  FROM dst d
  LEFT JOIN src s USING (schema_name, function_name, args)
 WHERE s.function_name IS NULL OR s.def_hash IS DISTINCT FROM d.def_hash
 ORDER BY d.schema_name, d.function_name, d.args;

-- ============================================================================
-- PHASE 2: non-runtime data sync (UPSERT only-in-dst + differing rows)
-- ============================================================================
SELECT '';
SELECT '-- ============================================================';
SELECT '-- PHASE 2: non-runtime data sync (UPSERT)';
SELECT '-- ============================================================';

-- Helper: emit INSERT ... ON CONFLICT ... DO UPDATE for every row that's
-- only-in-dst or differs from src. Skip rows that are identical or only-in-src
-- (the latter need DELETE -- emitted in section 9, commented out).
CREATE OR REPLACE FUNCTION pg_temp.sync_table_upsert(p_schema text, p_table text)
RETURNS TABLE(stmt text)
LANGUAGE plpgsql AS $f$
DECLARE
    v_pk          text[];
    v_pk_quoted   text;
    v_pk_concat   text;
    v_set_clause  text;
    v_src_query   text;
    v_dst_query   text;
    v_src_ok      boolean;
    v_dst_ok      boolean;
BEGIN
    SELECT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                    WHERE n.nspname=p_schema AND c.relname=p_table AND c.relkind='r')
      INTO v_src_ok;
    SELECT cnt > 0 INTO v_dst_ok FROM dblink('repo', format(
        $q$SELECT count(*)::int FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
            WHERE n.nspname=%L AND c.relname=%L AND c.relkind='r'$q$,
        p_schema, p_table)) AS t(cnt int);

    IF NOT v_src_ok OR NOT v_dst_ok THEN
        RETURN;       -- skip; schema phase already emitted CREATE/DROP
    END IF;

    SELECT array_agg(a.attname::text ORDER BY array_position(i.indkey, a.attnum))
      INTO v_pk
      FROM pg_index i
      JOIN pg_attribute a ON a.attrelid=i.indrelid AND a.attnum=ANY(i.indkey)
      JOIN pg_class c     ON c.oid=i.indrelid
      JOIN pg_namespace n ON n.oid=c.relnamespace
     WHERE n.nspname=p_schema AND c.relname=p_table AND i.indisprimary;

    IF v_pk IS NULL THEN
        stmt := format('-- %I.%I has no primary key; data sync skipped',
                       p_schema, p_table);
        RETURN NEXT;
        RETURN;
    END IF;

    -- "col1, col2"
    SELECT string_agg(quote_ident(x), ', ') INTO v_pk_quoted FROM unnest(v_pk) x;
    -- "concat_ws('|', col1::text, ...)"  -- builds a portable text key
    SELECT 'concat_ws(''|'', ' ||
           string_agg(format('coalesce(%I::text, ''<null>'')', x), ', ') ||
           ')'
      INTO v_pk_concat
      FROM unnest(v_pk) x;

    -- "col_a = excluded.col_a, col_b = excluded.col_b, ..."  (non-PK columns)
    SELECT string_agg(format('%I = excluded.%I', column_name, column_name),
                      E',\n    ' ORDER BY ordinal_position)
      INTO v_set_clause
      FROM information_schema.columns
     WHERE table_schema = p_schema
       AND table_name   = p_table
       AND column_name  <> ALL(v_pk);

    v_src_query := format($q$SELECT %s AS k, row_to_json(t.*)::text AS rj FROM %I.%I t$q$,
                          v_pk_concat, p_schema, p_table);
    v_dst_query := format($q$SELECT %s, row_to_json(t.*)::text FROM %I.%I t$q$,
                          v_pk_concat, p_schema, p_table);

    -- Emit INSERT ... ON CONFLICT for: only-in-dst rows AND rows where src/dst differ.
    RETURN QUERY EXECUTE format($q$
      WITH src AS (%s),
           dst AS (SELECT * FROM dblink('repo', %L) AS d(k text, rj text)),
           targets AS (
             SELECT d.k, d.rj
               FROM dst d LEFT JOIN src s USING (k)
              WHERE s.k IS NULL OR s.rj IS DISTINCT FROM d.rj
           )
      SELECT format(
        E'INSERT INTO %%I.%%I\n  SELECT * FROM jsonb_populate_record(NULL::%%I.%%I, %%L::jsonb)\n  ON CONFLICT (%s) DO %s;',
        %L, %L, %L, %L, t.rj
      ) AS stmt
        FROM targets t
       ORDER BY t.k
    $q$,
      v_src_query,
      v_dst_query,
      v_pk_quoted,
      CASE WHEN v_set_clause IS NULL OR length(trim(v_set_clause)) = 0
           THEN 'NOTHING'
           ELSE E'UPDATE SET\n    ' || v_set_clause
      END,
      p_schema, p_table, p_schema, p_table
    );
END
$f$;

-- Helper: emit DELETE statements for rows that exist in src but not in dst.
-- Always emitted commented-out -- review before uncommenting.
CREATE OR REPLACE FUNCTION pg_temp.sync_table_delete(p_schema text, p_table text)
RETURNS TABLE(stmt text)
LANGUAGE plpgsql AS $f$
DECLARE
    v_pk         text[];
    v_pk_concat  text;
    v_t_tuple    text;       -- (t.col1, t.col2)
    v_r_tuple    text;       -- (r.col1, r.col2)
    v_src_query  text;
    v_dst_query  text;
    v_src_ok     boolean;
    v_dst_ok     boolean;
BEGIN
    SELECT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                    WHERE n.nspname=p_schema AND c.relname=p_table AND c.relkind='r')
      INTO v_src_ok;
    SELECT cnt > 0 INTO v_dst_ok FROM dblink('repo', format(
        $q$SELECT count(*)::int FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
            WHERE n.nspname=%L AND c.relname=%L AND c.relkind='r'$q$,
        p_schema, p_table)) AS t(cnt int);

    IF NOT v_src_ok OR NOT v_dst_ok THEN
        RETURN;
    END IF;

    SELECT array_agg(a.attname::text ORDER BY array_position(i.indkey, a.attnum))
      INTO v_pk
      FROM pg_index i
      JOIN pg_attribute a ON a.attrelid=i.indrelid AND a.attnum=ANY(i.indkey)
      JOIN pg_class c     ON c.oid=i.indrelid
      JOIN pg_namespace n ON n.oid=c.relnamespace
     WHERE n.nspname=p_schema AND c.relname=p_table AND i.indisprimary;

    IF v_pk IS NULL THEN
        RETURN;
    END IF;

    -- "(t.col1, t.col2)"  and  "(r.col1, r.col2)" -- column-tuple comparison
    SELECT '(' || string_agg('t.' || quote_ident(x), ', ') || ')',
           '(' || string_agg('r.' || quote_ident(x), ', ') || ')'
      INTO v_t_tuple, v_r_tuple
      FROM unnest(v_pk) x;

    SELECT 'concat_ws(''|'', ' ||
           string_agg(format('coalesce(%I::text, ''<null>'')', x), ', ') ||
           ')'
      INTO v_pk_concat
      FROM unnest(v_pk) x;

    v_src_query := format($q$SELECT %s AS k, row_to_json(t.*)::text AS rj FROM %I.%I t$q$,
                          v_pk_concat, p_schema, p_table);
    v_dst_query := format($q$SELECT %s, row_to_json(t.*)::text FROM %I.%I t$q$,
                          v_pk_concat, p_schema, p_table);

    -- Emit one commented DELETE per only-in-src key.
    RETURN QUERY EXECUTE format($q$
      WITH src AS (%s),
           dst AS (SELECT * FROM dblink('repo', %L) AS d(k text, rj text)),
           orphans AS (SELECT s.k, s.rj FROM src s LEFT JOIN dst d USING (k)
                        WHERE d.k IS NULL)
      SELECT format(
        E'-- only-in-src key: %%s\n-- DELETE FROM %%I.%%I AS t USING jsonb_populate_record(NULL::%%I.%%I, %%L::jsonb) AS r WHERE %s = %s;',
        o.k, %L, %L, %L, %L, o.rj
      ) AS stmt
        FROM orphans o
       ORDER BY o.k
    $q$,
      v_src_query,
      v_dst_query,
      v_t_tuple,
      v_r_tuple,
      p_schema, p_table, p_schema, p_table
    );
END
$f$;

-- Run the upsert generators across the allow-list.
SELECT '';
SELECT '-- ----- INSERT ... ON CONFLICT (UPSERT for new + differing rows) -----';
WITH targets(schema_name, table_name) AS (
  VALUES
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
    ('metrics',   'custom_metrics'),
    ('metrics',   'registered_processes'),
    ('metrics',   'routines'),
    ('metrics',   'sql_injection_patterns'),
    ('jobs',      'jobs'),
    ('processes', 'process'),
    ('processes', 'steps'),
    ('processes', 'organization')
)
SELECT u.stmt
  FROM targets t
  CROSS JOIN LATERAL pg_temp.sync_table_upsert(t.schema_name, t.table_name) u;

-- ============================================================================
-- 9. DROPS AND DELETES (commented out — review before uncommenting)
-- ============================================================================
SELECT '';
SELECT '-- ============================================================';
SELECT '-- DESTRUCTIVE SECTION  (commented out)';
SELECT '-- Uncomment statements you want to apply.';
SELECT '-- ============================================================';

-- columns dropped only-in-src
SELECT '';
SELECT '-- ----- columns: DROP only-in-src -----';
WITH src AS (
  SELECT table_schema::text, table_name::text, column_name::text
    FROM information_schema.columns
   WHERE table_schema NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
), dst AS (
  SELECT * FROM dblink('repo', $$
    SELECT table_schema::text, table_name::text, column_name::text
      FROM information_schema.columns
     WHERE table_schema NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
  $$) AS t(table_schema text, table_name text, column_name text)
)
SELECT format('-- ALTER TABLE %I.%I DROP COLUMN IF EXISTS %I;',
              s.table_schema, s.table_name, s.column_name)
  FROM src s
 WHERE NOT EXISTS (SELECT 1 FROM dst d
                    WHERE d.table_schema=s.table_schema
                      AND d.table_name  =s.table_name
                      AND d.column_name =s.column_name)
 ORDER BY 1;

-- constraints dropped only-in-src
SELECT '';
SELECT '-- ----- constraints: DROP only-in-src -----';
WITH src AS (
  SELECT n.nspname::text AS schema_name, cl.relname::text AS table_name,
         c.conname::text AS constraint_name
    FROM pg_constraint c
    JOIN pg_class cl ON cl.oid=c.conrelid
    JOIN pg_namespace n ON n.oid=cl.relnamespace
   WHERE n.nspname NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
), dst AS (
  SELECT * FROM dblink('repo', $$
    SELECT n.nspname::text, cl.relname::text, c.conname::text
      FROM pg_constraint c
      JOIN pg_class cl ON cl.oid=c.conrelid
      JOIN pg_namespace n ON n.oid=cl.relnamespace
     WHERE n.nspname NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
  $$) AS t(schema_name text, table_name text, constraint_name text)
)
SELECT format('-- ALTER TABLE %I.%I DROP CONSTRAINT IF EXISTS %I;',
              s.schema_name, s.table_name, s.constraint_name)
  FROM src s
 WHERE NOT EXISTS (SELECT 1 FROM dst d
                    WHERE d.schema_name=s.schema_name
                      AND d.table_name=s.table_name
                      AND d.constraint_name=s.constraint_name)
 ORDER BY 1;

-- indexes dropped only-in-src
SELECT '';
SELECT '-- ----- indexes: DROP only-in-src -----';
WITH src AS (
  SELECT schemaname::text, indexname::text FROM pg_indexes
   WHERE schemaname NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
), dst AS (
  SELECT * FROM dblink('repo', $$
    SELECT schemaname::text, indexname::text FROM pg_indexes
     WHERE schemaname NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
  $$) AS t(schemaname text, indexname text)
)
SELECT format('-- DROP INDEX IF EXISTS %I.%I;', s.schemaname, s.indexname)
  FROM src s
 WHERE NOT EXISTS (SELECT 1 FROM dst d
                    WHERE d.schemaname=s.schemaname AND d.indexname=s.indexname)
 ORDER BY 1;

-- tables / schemas dropped only-in-src
SELECT '';
SELECT '-- ----- tables: DROP only-in-src -----';
WITH src AS (
  SELECT table_schema::text, table_name::text FROM information_schema.tables
   WHERE table_type='BASE TABLE'
     AND table_schema NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
), dst AS (
  SELECT * FROM dblink('repo', $$
    SELECT table_schema::text, table_name::text FROM information_schema.tables
     WHERE table_type='BASE TABLE'
       AND table_schema NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
  $$) AS t(table_schema text, table_name text)
)
SELECT format('-- DROP TABLE IF EXISTS %I.%I CASCADE;', s.table_schema, s.table_name)
  FROM src s
 WHERE NOT EXISTS (SELECT 1 FROM dst d
                    WHERE d.table_schema=s.table_schema AND d.table_name=s.table_name)
 ORDER BY 1;

-- schemas dropped only-in-src
SELECT '';
SELECT '-- ----- schemas: DROP only-in-src -----';
WITH src AS (
  SELECT nspname::text FROM pg_namespace
   WHERE nspname NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
     AND nspname NOT LIKE 'pg\_temp\_%' AND nspname NOT LIKE 'pg\_toast\_temp\_%'
), dst AS (
  SELECT * FROM dblink('repo', $$
    SELECT nspname::text FROM pg_namespace
     WHERE nspname NOT IN ('pg_catalog','information_schema','pg_toast','sys','dbms_sql')
       AND nspname NOT LIKE 'pg\_temp\_%' AND nspname NOT LIKE 'pg\_toast\_temp\_%'
  $$) AS t(nspname text)
)
SELECT format('-- DROP SCHEMA IF EXISTS %I CASCADE;', s.nspname)
  FROM src s WHERE NOT EXISTS (SELECT 1 FROM dst d WHERE d.nspname=s.nspname)
 ORDER BY 1;

-- data: rows that are only-in-src (commented DELETEs)
SELECT '';
SELECT '-- ----- data: DELETE only-in-src rows (commented) -----';
WITH targets(schema_name, table_name) AS (
  VALUES
    ('rootcause', 'vendors'), ('rootcause', 'database_types'),
    ('rootcause', 'risk_level'), ('rootcause', 'severity'),
    ('rootcause', 'domains'), ('rootcause', 'areas'),
    ('rootcause', 'issues'), ('rootcause', 'issue_domains'),
    ('rootcause', 'issue_root_causes'), ('rootcause', 'root_causes'),
    ('rootcause', 'detection_paths'), ('rootcause', 'detection_path_steps'),
    ('rootcause', 'detection_steps'), ('rootcause', 'resolution_paths'),
    ('rootcause', 'resolution_path_steps'), ('rootcause', 'resolution_steps'),
    ('config', 'global_params'), ('config', 'action_types'),
    ('config', 'mail_config'), ('config', 'mail_groups'),
    ('config', 'mail_jobs'), ('config', 'reports'),
    ('config', 'reports_jobs'), ('config', 'alerts'),
    ('config', 'alerts_reports'), ('config', 'alerts_thresholds'),
    ('config', 'thresholds'), ('config', 'webook_alerts'),
    ('config', 'retention_policy'), ('config', 'siem'),
    ('config', 'schema_versions'),
    ('metrics', 'custom_metrics'), ('metrics', 'registered_processes'),
    ('metrics', 'routines'), ('metrics', 'sql_injection_patterns'),
    ('jobs', 'jobs'),
    ('processes', 'process'), ('processes', 'steps'),
    ('processes', 'organization')
)
SELECT u.stmt
  FROM targets t
  CROSS JOIN LATERAL pg_temp.sync_table_delete(t.schema_name, t.table_name) u;

-- ----------------------------------------------------------------------------
-- footer
-- ----------------------------------------------------------------------------
SELECT '';
SELECT 'COMMIT;';
SELECT '';
SELECT '-- =============================================================';
SELECT '-- end of generated sync script';
SELECT '-- =============================================================';

-- close the dblink connection on the GENERATING session
SELECT dblink_disconnect('repo') \gset trash_
