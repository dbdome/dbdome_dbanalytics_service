"""
db_sync_generator.py
====================
Compares dbanalytics_repo (source/baseline) with dbanalytics (target/live)
and generates an executable SQL script with:

  Schema section  — CREATE SCHEMA, CREATE TABLE, ALTER TABLE (columns /
                    nullable / default / type), ADD CONSTRAINT, CREATE INDEX,
                    CREATE OR REPLACE VIEW, CREATE OR REPLACE FUNCTION
  Data section    — INSERT … ON CONFLICT DO UPDATE  (upsert for missing/changed rows)
                    UPDATE … WHERE  (for changed rows in target)
                    DELETE … WHERE  (commented by default; --emit-deletes to activate)

Output is wrapped in BEGIN / COMMIT (left uncommitted for review).

Usage:
    python db_sync_generator.py
    python db_sync_generator.py --source dbanalytics_repo --target dbanalytics
    python db_sync_generator.py --output sync_$(date +%Y%m%d).sql
    python db_sync_generator.py --schema-only
    python db_sync_generator.py --data-only
    python db_sync_generator.py --emit-deletes
"""

import argparse
import os
import sys
from datetime import datetime

import psycopg2
import psycopg2.extras

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

PG_HOST = "localhost"
PG_PORT = 5432
PG_USER = "dbdome_adm"
PG_PASS = "Yd2243796Anz!!"

SKIP_SCHEMAS = tuple({
    'information_schema', 'pg_catalog', 'pg_toast', 'sys', 'public',
    'pg_temp_0', 'pg_temp_71', 'pg_toast_temp_0', 'pg_toast_temp_71',
})

# Tables whose content is compared (non-runtime reference/config data).
# Runtime tables (servers, metrics, logs, alerts, job_schedules, executions)
# are intentionally excluded.
NON_RUNTIME_TABLES = [
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
    ('processes', 'organization'),
]

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def connect(dbname, host, port, user, password):
    return psycopg2.connect(
        host=host, port=port, dbname=dbname,
        user=user, password=password, connect_timeout=10,
    )


def query(conn, sql, params=None):
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute(sql, params)
        return [dict(r) for r in cur.fetchall()]


def to_literal(cur, val):
    """Escape a Python value to a SQL literal using psycopg2."""
    if val is None:
        return 'NULL'
    return cur.mogrify('%s', (val,)).decode('utf-8')


def col_type_str(col):
    t = col['data_type']
    if t in ('character varying', 'varchar') and col.get('character_maximum_length'):
        return f"varchar({col['character_maximum_length']})"
    if t == 'character' and col.get('character_maximum_length'):
        return f"char({col['character_maximum_length']})"
    if t == 'numeric' and col.get('numeric_precision'):
        return f"numeric({col['numeric_precision']},{col.get('numeric_scale', 0)})"
    return t

# ---------------------------------------------------------------------------
# Catalog fetchers
# ---------------------------------------------------------------------------

def get_schemas(conn):
    rows = query(conn,
        "SELECT schema_name FROM information_schema.schemata "
        "WHERE schema_name NOT IN %s", (SKIP_SCHEMAS,))
    return {r['schema_name'] for r in rows}


def get_tables(conn):
    rows = query(conn, """
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_schema NOT IN %s AND table_type = 'BASE TABLE'
        ORDER BY table_schema, table_name
    """, (SKIP_SCHEMAS,))
    return {(r['table_schema'], r['table_name']) for r in rows}


def get_columns(conn):
    rows = query(conn, """
        SELECT table_schema, table_name, column_name,
               data_type, character_maximum_length,
               numeric_precision, numeric_scale,
               is_nullable, column_default, ordinal_position
        FROM information_schema.columns
        WHERE table_schema NOT IN %s
        ORDER BY table_schema, table_name, ordinal_position
    """, (SKIP_SCHEMAS,))
    return {(r['table_schema'], r['table_name'], r['column_name']): r for r in rows}


def get_constraints(conn):
    rows = query(conn, """
        SELECT n.nspname  AS table_schema,
               cl.relname AS table_name,
               c.conname  AS constraint_name,
               c.contype  AS constraint_type,
               pg_get_constraintdef(c.oid) AS definition
        FROM pg_constraint c
        JOIN pg_class     cl ON cl.oid = c.conrelid
        JOIN pg_namespace n  ON n.oid  = cl.relnamespace
        WHERE n.nspname NOT IN %s AND c.conrelid > 0
        ORDER BY n.nspname, cl.relname,
                 CASE c.contype WHEN 'p' THEN 1 WHEN 'u' THEN 2
                                WHEN 'c' THEN 3 ELSE 4 END,
                 c.conname
    """, (SKIP_SCHEMAS,))
    return {(r['table_schema'], r['table_name'], r['constraint_name']): r for r in rows}


def get_indexes(conn):
    rows = query(conn, """
        SELECT schemaname, tablename, indexname, indexdef
        FROM pg_indexes
        WHERE schemaname NOT IN %s
        ORDER BY schemaname, tablename, indexname
    """, (SKIP_SCHEMAS,))
    return {(r['schemaname'], r['tablename'], r['indexname']): r['indexdef'] for r in rows}


def get_views(conn):
    rows = query(conn, """
        SELECT n.nspname AS schema_name, c.relname AS view_name,
               pg_get_viewdef(c.oid, true) AS view_definition
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relkind = 'v' AND n.nspname NOT IN %s
        ORDER BY n.nspname, c.relname
    """, (SKIP_SCHEMAS,))
    return {(r['schema_name'], r['view_name']): r['view_definition'] for r in rows}


def get_functions(conn):
    rows = query(conn, """
        SELECT n.nspname AS schema, p.proname AS name,
               pg_get_function_identity_arguments(p.oid) AS args,
               pg_get_functiondef(p.oid) AS definition
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname NOT IN %s AND p.prokind IN ('f', 'p')
        ORDER BY n.nspname, p.proname
    """, (SKIP_SCHEMAS,))
    return {(r['schema'], r['name'], r['args']): r['definition'] for r in rows}


def get_primary_key(conn, schema, table):
    rows = query(conn, """
        SELECT a.attname
        FROM pg_index i
        JOIN pg_attribute a ON a.attrelid = i.indrelid
                            AND a.attnum = ANY(i.indkey)
        WHERE i.indrelid = (
            SELECT c.oid FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = %s AND c.relname = %s
        ) AND i.indisprimary
        ORDER BY array_position(i.indkey, a.attnum)
    """, (schema, table))
    return [r['attname'] for r in rows]


def table_exists(conn, schema, table):
    return bool(query(conn, """
        SELECT 1 FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = %s AND c.relname = %s AND c.relkind = 'r'
    """, (schema, table)))

# ---------------------------------------------------------------------------
# Schema section
# ---------------------------------------------------------------------------

def schema_section(src, tgt, out):
    out.append("-- =========================================================")
    out.append("-- SECTION 1: Schema (DDL)")
    out.append("-- =========================================================\n")

    src_schemas = get_schemas(src)
    tgt_schemas = get_schemas(tgt)
    src_tables  = get_tables(src)
    tgt_tables  = get_tables(tgt)
    src_cols    = get_columns(src)
    tgt_cols    = get_columns(tgt)
    src_cons    = get_constraints(src)
    tgt_cons    = get_constraints(tgt)
    src_idx     = get_indexes(src)
    tgt_idx     = get_indexes(tgt)
    src_views   = get_views(src)
    tgt_views   = get_views(tgt)
    src_funcs   = get_functions(src)
    tgt_funcs   = get_functions(tgt)

    # --- New schemas ---
    for s in sorted(src_schemas - tgt_schemas):
        out.append(f"CREATE SCHEMA IF NOT EXISTS {s};")

    # --- New tables ---
    for schema, table in sorted(src_tables - tgt_tables):
        cols = sorted(
            [c for (s, t, _), c in src_cols.items() if s == schema and t == table],
            key=lambda c: c['ordinal_position'],
        )
        col_defs = []
        for c in cols:
            line = f"    {c['column_name']} {col_type_str(c)}"
            if c['is_nullable'] == 'NO':
                line += " NOT NULL"
            if c['column_default']:
                line += f" DEFAULT {c['column_default']}"
            col_defs.append(line)
        out.append(f"\n-- NEW TABLE: {schema}.{table}")
        out.append("CREATE TABLE IF NOT EXISTS {}.{} (\n{}\n);".format(
            schema, table, ",\n".join(col_defs)))

    # --- Missing constraints (PKs first so FKs can reference them) ---
    for (schema, table, cname), info in sorted(
            src_cons.items(),
            key=lambda kv: (kv[0][0], kv[0][1],
                            0 if kv[1]['constraint_type'] == 'p' else
                            1 if kv[1]['constraint_type'] == 'u' else 2)):
        if (schema, table, cname) not in tgt_cons:
            if (schema, table) in tgt_tables or (schema, table) in src_tables - tgt_tables:
                out.append(
                    f"ALTER TABLE {schema}.{table} "
                    f"ADD CONSTRAINT {cname} {info['definition']};")

    # --- New columns in existing tables ---
    for (schema, table, col), info in sorted(src_cols.items()):
        if (schema, table) not in tgt_tables:
            continue
        if (schema, table, col) not in tgt_cols:
            nullable = "" if info['is_nullable'] == 'YES' else " NOT NULL"
            default  = f" DEFAULT {info['column_default']}" if info['column_default'] else ""
            out.append(f"\n-- NEW COLUMN: {schema}.{table}.{col}")
            out.append(
                f"ALTER TABLE {schema}.{table} "
                f"ADD COLUMN IF NOT EXISTS {col} {col_type_str(info)}{nullable}{default};")

    # --- Changed columns ---
    for (schema, table, col) in sorted(set(src_cols) & set(tgt_cols)):
        sc = src_cols[(schema, table, col)]
        tc = tgt_cols[(schema, table, col)]

        if col_type_str(sc) != col_type_str(tc):
            out.append(f"\n-- TYPE CHANGE: {schema}.{table}.{col}  "
                       f"({col_type_str(tc)} -> {col_type_str(sc)})")
            out.append(
                f"ALTER TABLE {schema}.{table} ALTER COLUMN {col} "
                f"TYPE {col_type_str(sc)} USING {col}::{col_type_str(sc)};")

        if sc['is_nullable'] != tc['is_nullable']:
            verb = "SET NOT NULL" if sc['is_nullable'] == 'NO' else "DROP NOT NULL"
            out.append(f"ALTER TABLE {schema}.{table} ALTER COLUMN {col} {verb};")

        src_def = (sc.get('column_default') or '').strip()
        tgt_def = (tc.get('column_default') or '').strip()
        if src_def != tgt_def:
            if src_def:
                out.append(
                    f"ALTER TABLE {schema}.{table} ALTER COLUMN {col} "
                    f"SET DEFAULT {src_def};")
            else:
                out.append(
                    f"ALTER TABLE {schema}.{table} ALTER COLUMN {col} DROP DEFAULT;")

    # --- Extra columns in target (commented — destructive) ---
    for (schema, table, col) in sorted(set(tgt_cols) - set(src_cols)):
        if (schema, table) in src_tables:
            out.append(
                f"-- REVIEW: ALTER TABLE {schema}.{table} DROP COLUMN {col};"
                f"  -- exists in target only")

    # --- Missing indexes ---
    for (schema, table, idx_name) in sorted(set(src_idx) - set(tgt_idx)):
        if (schema, table) in tgt_tables or (schema, table) in src_tables - tgt_tables:
            out.append(f"\n{src_idx[(schema, table, idx_name)]};")

    # --- Views ---
    for key in sorted(set(src_views) - set(tgt_views)):
        schema, view = key
        out.append(f"\n-- NEW VIEW: {schema}.{view}")
        out.append(f"CREATE OR REPLACE VIEW {schema}.{view} AS\n{src_views[key]};")

    for key in sorted(set(src_views) & set(tgt_views)):
        if src_views[key] != tgt_views[key]:
            schema, view = key
            out.append(f"\n-- CHANGED VIEW: {schema}.{view}")
            out.append(f"CREATE OR REPLACE VIEW {schema}.{view} AS\n{src_views[key]};")

    # --- Functions / procedures ---
    for key in sorted(set(src_funcs) - set(tgt_funcs)):
        schema, name, args = key
        out.append(f"\n-- NEW FUNCTION: {schema}.{name}({args})")
        out.append(f"{src_funcs[key]};")

    for key in sorted(set(src_funcs) & set(tgt_funcs)):
        if src_funcs[key] != tgt_funcs[key]:
            schema, name, args = key
            out.append(f"\n-- CHANGED FUNCTION: {schema}.{name}({args})")
            out.append(f"{src_funcs[key]};")

# ---------------------------------------------------------------------------
# Data section
# ---------------------------------------------------------------------------

def data_section(src, tgt, out, tables, emit_deletes=False):
    out.append("\n\n-- =========================================================")
    out.append("-- SECTION 2: Data (INSERT / UPDATE / DELETE)")
    out.append("-- =========================================================\n")

    with src.cursor() as cur:
        for schema, table in tables:
            if not table_exists(src, schema, table):
                out.append(f"-- SKIP: {schema}.{table} — not in source")
                continue
            if not table_exists(tgt, schema, table):
                out.append(f"-- SKIP: {schema}.{table} — not in target (see schema section)")
                continue

            pk = get_primary_key(src, schema, table)
            if not pk:
                out.append(f"-- SKIP: {schema}.{table} — no primary key")
                continue

            with src.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as rc:
                rc.execute(f'SELECT * FROM "{schema}"."{table}"')
                src_rows = [dict(r) for r in rc.fetchall()]

            with tgt.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as rc:
                rc.execute(f'SELECT * FROM "{schema}"."{table}"')
                tgt_rows = [dict(r) for r in rc.fetchall()]

            src_idx = {tuple(r[k] for k in pk): r for r in src_rows}
            tgt_idx = {tuple(r[k] for k in pk): r for r in tgt_rows}

            only_src = sorted(set(src_idx) - set(tgt_idx), key=lambda x: tuple(map(str, x)))
            only_tgt = sorted(set(tgt_idx) - set(src_idx), key=lambda x: tuple(map(str, x)))
            changed  = [
                k for k in sorted(set(src_idx) & set(tgt_idx), key=lambda x: tuple(map(str, x)))
                if any(str(src_idx[k].get(c)) != str(tgt_idx[k].get(c)) for c in src_idx[k])
            ]

            if not (only_src or only_tgt or changed):
                continue

            out.append(f"\n-- Table: {schema}.{table}  (PK: {pk})"
                       f"  +{len(only_src)} missing  ~{len(changed)} changed"
                       f"  -{len(only_tgt)} extra in target")

            # INSERT (upsert) for rows missing in target
            for key in only_src:
                row = src_idx[key]
                cols     = list(row.keys())
                col_list = ", ".join(cols)
                val_list = ", ".join(to_literal(cur, row[c]) for c in cols)
                pk_cols  = ", ".join(pk)
                updates  = ", ".join(
                    f"{c} = EXCLUDED.{c}" for c in cols if c not in pk)
                do_clause = f"DO UPDATE SET {updates}" if updates else "DO NOTHING"
                out.append(
                    f"INSERT INTO {schema}.{table} ({col_list})\n"
                    f"    VALUES ({val_list})\n"
                    f"    ON CONFLICT ({pk_cols}) {do_clause};")

            # UPDATE for changed rows
            for key in changed:
                src_row = src_idx[key]
                tgt_row = tgt_idx[key]
                set_parts = ", ".join(
                    f"{c} = {to_literal(cur, src_row[c])}"
                    for c in src_row
                    if c not in pk and str(src_row.get(c)) != str(tgt_row.get(c))
                )
                where = " AND ".join(
                    f"{k} = {to_literal(cur, key[i])}" for i, k in enumerate(pk))
                out.append(f"UPDATE {schema}.{table} SET {set_parts} WHERE {where};")

            # DELETE for rows in target not in source
            for key in only_tgt:
                where = " AND ".join(
                    f"{k} = {to_literal(cur, key[i])}" for i, k in enumerate(pk))
                stmt = f"DELETE FROM {schema}.{table} WHERE {where};"
                if emit_deletes:
                    out.append(stmt)
                else:
                    out.append(f"-- REVIEW (DELETE): {stmt}")

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    p = argparse.ArgumentParser(
        description="Generate ALTER/INSERT/UPDATE/DELETE script to sync two PG databases")
    p.add_argument('--source',       default='dbanalytics_repo',
                   help='Source (baseline) database  [default: dbanalytics_repo]')
    p.add_argument('--target',       default='dbanalytics',
                   help='Target (live) database       [default: dbanalytics]')
    p.add_argument('--host',         default=PG_HOST)
    p.add_argument('--port',         default=PG_PORT, type=int)
    p.add_argument('--user',         default=PG_USER)
    p.add_argument('--password',     default=os.environ.get('PGPASSWORD', PG_PASS))
    p.add_argument('--output',       default=None,
                   help='Output SQL file (default: auto-named)')
    p.add_argument('--schema-only',  action='store_true',
                   help='Emit only DDL (schema) statements')
    p.add_argument('--data-only',    action='store_true',
                   help='Emit only data (INSERT/UPDATE/DELETE) statements')
    p.add_argument('--emit-deletes', action='store_true',
                   help='Emit DELETE statements (default: commented out for safety)')
    args = p.parse_args()

    try:
        src = connect(args.source, args.host, args.port, args.user, args.password)
        tgt = connect(args.target, args.host, args.port, args.user, args.password)
    except Exception as e:
        print(f"ERROR: cannot connect: {e}", file=sys.stderr)
        sys.exit(2)

    ts = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    out = [
        f"-- =============================================================================",
        f"-- Sync script  source={args.source}  target={args.target}",
        f"-- Generated: {ts}",
        f"-- REVIEW THIS SCRIPT BEFORE RUNNING.",
        f"-- Lines marked '-- REVIEW' require a manual decision.",
        f"-- DELETE statements are commented out by default (use --emit-deletes to activate).",
        f"-- =============================================================================\n",
        f"BEGIN;\n",
    ]

    try:
        if not args.data_only:
            schema_section(src, tgt, out)
        if not args.schema_only:
            data_section(src, tgt, out, NON_RUNTIME_TABLES, emit_deletes=args.emit_deletes)
    finally:
        src.close()
        tgt.close()

    out += [
        "",
        "-- COMMIT;   -- uncomment to apply",
        "-- ROLLBACK; -- uncomment to discard",
        "",
    ]

    sql_text = "\n".join(out)

    output_file = (args.output or
                   f"sync_{args.source}_to_{args.target}_"
                   f"{datetime.now().strftime('%Y%m%d_%H%M%S')}.sql")

    with open(output_file, "w", encoding="utf-8") as f:
        f.write(sql_text)

    print(f"Generated: {output_file}")


if __name__ == "__main__":
    main()
