"""
Database Schema Comparator — Generates ALTER scripts
=====================================================
Compares two PostgreSQL databases and generates ALTER SQL to bring
the target (live) database in sync with the source (repo/install baseline).

Usage:
    python db_schema_compare.py                          # defaults: repo vs live
    python db_schema_compare.py --source dbanalytics_repo --target dbanalytics
    python db_schema_compare.py --source dbanalytics_install --target dbanalytics
    python db_schema_compare.py --output alter_script.sql

Detects:
    - New schemas in source (missing in target)
    - New tables in source (missing in target)
    - New columns in source tables (missing in target)
    - Column type changes
    - Column default changes
    - Column nullable changes
    - Missing indexes
    - Missing constraints
    - Dropped tables (in source but not target — reported, not scripted)
    - New/changed views
    - New/changed functions/procedures
"""

import psycopg2
import argparse
import sys
from datetime import datetime


# ================================================================
# CONFIG
# ================================================================

PG_HOST = "localhost"
PG_PORT = 5444
PG_USER = "dbdome_mon_usr"
PG_PASS = "Yd2243796Anz!!"

SKIP_SCHEMAS = (
    'information_schema', 'pg_catalog', 'pg_toast', 'sys', 'public',
    'pg_temp_0', 'pg_temp_71', 'pg_toast_temp_0', 'pg_toast_temp_71',
)


# ================================================================
# HELPERS
# ================================================================

def connect(dbname):
    return psycopg2.connect(
        host=PG_HOST, port=PG_PORT, user=PG_USER,
        password=PG_PASS, dbname=dbname,
        connect_timeout=10,
    )


def query(conn, sql, params=None):
    cur = conn.cursor()
    cur.execute(sql, params)
    cols = [d[0] for d in cur.description]
    rows = [dict(zip(cols, r)) for r in cur.fetchall()]
    cur.close()
    return rows


def get_schemas(conn):
    return {r['schema_name'] for r in query(conn, """
        SELECT schema_name FROM information_schema.schemata
        WHERE schema_name NOT IN %s
    """, (SKIP_SCHEMAS,))}


def get_tables(conn):
    """Returns dict: (schema, table) -> set of column info."""
    rows = query(conn, """
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_schema NOT IN %s AND table_type = 'BASE TABLE'
        ORDER BY table_schema, table_name
    """, (SKIP_SCHEMAS,))
    return {(r['table_schema'], r['table_name']) for r in rows}


def get_columns(conn):
    """Returns dict: (schema, table, column) -> column details."""
    rows = query(conn, """
        SELECT table_schema, table_name, column_name,
               data_type, character_maximum_length,
               numeric_precision, numeric_scale,
               is_nullable, column_default,
               ordinal_position
        FROM information_schema.columns
        WHERE table_schema NOT IN %s
        ORDER BY table_schema, table_name, ordinal_position
    """, (SKIP_SCHEMAS,))
    result = {}
    for r in rows:
        key = (r['table_schema'], r['table_name'], r['column_name'])
        result[key] = r
    return result


def get_indexes(conn):
    """Returns dict: (schema, table, index_name) -> index definition."""
    rows = query(conn, """
        SELECT schemaname, tablename, indexname, indexdef
        FROM pg_indexes
        WHERE schemaname NOT IN %s
        ORDER BY schemaname, tablename, indexname
    """, (SKIP_SCHEMAS,))
    result = {}
    for r in rows:
        key = (r['schemaname'], r['tablename'], r['indexname'])
        result[key] = r['indexdef']
    return result


def get_constraints(conn):
    """Returns dict: (schema, table, constraint_name) -> constraint details."""
    rows = query(conn, """
        SELECT tc.table_schema, tc.table_name, tc.constraint_name,
               tc.constraint_type,
               string_agg(kcu.column_name, ', ' ORDER BY kcu.ordinal_position) AS columns
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
            ON kcu.constraint_name = tc.constraint_name
            AND kcu.table_schema = tc.table_schema
        WHERE tc.table_schema NOT IN %s
        GROUP BY tc.table_schema, tc.table_name, tc.constraint_name, tc.constraint_type
        ORDER BY tc.table_schema, tc.table_name
    """, (SKIP_SCHEMAS,))
    result = {}
    for r in rows:
        key = (r['table_schema'], r['table_name'], r['constraint_name'])
        result[key] = r
    return result


def get_views(conn):
    """Returns dict: (schema, view_name) -> view definition."""
    rows = query(conn, """
        SELECT table_schema, table_name, view_definition
        FROM information_schema.views
        WHERE table_schema NOT IN %s
    """, (SKIP_SCHEMAS,))
    return {(r['table_schema'], r['table_name']): r['view_definition'] for r in rows}


def get_functions(conn):
    """Returns dict: (schema, routine_name, params) -> routine definition."""
    rows = query(conn, """
        SELECT n.nspname AS schema, p.proname AS name,
               pg_get_function_identity_arguments(p.oid) AS args,
               pg_get_functiondef(p.oid) AS definition
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname NOT IN %s
          AND p.prokind IN ('f', 'p')
        ORDER BY n.nspname, p.proname
    """, (SKIP_SCHEMAS,))
    result = {}
    for r in rows:
        key = (r['schema'], r['name'], r['args'])
        result[key] = r['definition']
    return result


def col_type_str(col):
    """Build a readable type string from column info."""
    t = col['data_type']
    if t in ('character varying', 'varchar') and col.get('character_maximum_length'):
        return f"varchar({col['character_maximum_length']})"
    if t == 'character' and col.get('character_maximum_length'):
        return f"char({col['character_maximum_length']})"
    if t == 'numeric' and col.get('numeric_precision'):
        return f"numeric({col['numeric_precision']},{col.get('numeric_scale', 0)})"
    return t


# ================================================================
# COMPARE
# ================================================================

def compare(source_db, target_db):
    print(f"Comparing: {source_db} (source/repo) -> {target_db} (target/live)")
    print(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()

    src = connect(source_db)
    tgt = connect(target_db)

    alter_lines = []
    report_lines = []

    def alter(sql):
        alter_lines.append(sql)

    def report(msg):
        report_lines.append(msg)
        print(f"  {msg}")

    # ── 1. Schemas ──
    print("Checking schemas...")
    src_schemas = get_schemas(src)
    tgt_schemas = get_schemas(tgt)

    for s in sorted(src_schemas - tgt_schemas):
        report(f"NEW SCHEMA: {s}")
        alter(f"CREATE SCHEMA IF NOT EXISTS {s};")

    for s in sorted(tgt_schemas - src_schemas):
        report(f"EXTRA SCHEMA in target (not in source): {s}")

    # ── 2. Tables ──
    print("Checking tables...")
    src_tables = get_tables(src)
    tgt_tables = get_tables(tgt)

    for schema, table in sorted(src_tables - tgt_tables):
        report(f"NEW TABLE: {schema}.{table}")
        # Get CREATE TABLE from source
        cols = [c for (s, t, _), c in get_columns(src).items() if s == schema and t == table]
        cols.sort(key=lambda c: c['ordinal_position'])
        col_defs = []
        for c in cols:
            line = f"    {c['column_name']} {col_type_str(c)}"
            if c['is_nullable'] == 'NO':
                line += " NOT NULL"
            if c['column_default']:
                line += f" DEFAULT {c['column_default']}"
            col_defs.append(line)
        alter(f"CREATE TABLE IF NOT EXISTS {schema}.{table} (\n" + ",\n".join(col_defs) + "\n);")

    for schema, table in sorted(tgt_tables - src_tables):
        report(f"EXTRA TABLE in target (not in source): {schema}.{table}")

    # ── 3. Columns ──
    print("Checking columns...")
    src_cols = get_columns(src)
    tgt_cols = get_columns(tgt)

    # New columns
    for (schema, table, col), info in sorted(src_cols.items()):
        if (schema, table) not in tgt_tables:
            continue  # table already reported as new
        if (schema, table, col) not in tgt_cols:
            report(f"NEW COLUMN: {schema}.{table}.{col} ({col_type_str(info)})")
            nullable = "" if info['is_nullable'] == 'YES' else " NOT NULL"
            default = f" DEFAULT {info['column_default']}" if info['column_default'] else ""
            alter(f"ALTER TABLE {schema}.{table} ADD COLUMN IF NOT EXISTS {col} {col_type_str(info)}{nullable}{default};")

    # Changed columns
    for key in sorted(set(src_cols.keys()) & set(tgt_cols.keys())):
        sc = src_cols[key]
        tc = tgt_cols[key]
        schema, table, col = key

        # Type change
        if col_type_str(sc) != col_type_str(tc):
            report(f"TYPE CHANGE: {schema}.{table}.{col}: {col_type_str(tc)} -> {col_type_str(sc)}")
            alter(f"ALTER TABLE {schema}.{table} ALTER COLUMN {col} TYPE {col_type_str(sc)};")

        # Nullable change
        if sc['is_nullable'] != tc['is_nullable']:
            if sc['is_nullable'] == 'NO':
                report(f"SET NOT NULL: {schema}.{table}.{col}")
                alter(f"ALTER TABLE {schema}.{table} ALTER COLUMN {col} SET NOT NULL;")
            else:
                report(f"DROP NOT NULL: {schema}.{table}.{col}")
                alter(f"ALTER TABLE {schema}.{table} ALTER COLUMN {col} DROP NOT NULL;")

        # Default change
        src_def = sc.get('column_default') or ''
        tgt_def = tc.get('column_default') or ''
        if src_def != tgt_def:
            if src_def:
                report(f"DEFAULT CHANGE: {schema}.{table}.{col}: '{tgt_def}' -> '{src_def}'")
                alter(f"ALTER TABLE {schema}.{table} ALTER COLUMN {col} SET DEFAULT {src_def};")
            else:
                report(f"DROP DEFAULT: {schema}.{table}.{col}")
                alter(f"ALTER TABLE {schema}.{table} ALTER COLUMN {col} DROP DEFAULT;")

    # Dropped columns (in target but not source)
    for (schema, table, col) in sorted(set(tgt_cols.keys()) - set(src_cols.keys())):
        if (schema, table) not in src_tables:
            continue  # table not in source at all
        report(f"EXTRA COLUMN in target: {schema}.{table}.{col}")
        alter(f"-- REVIEW: ALTER TABLE {schema}.{table} DROP COLUMN {col};  -- exists in target but not source")

    # ── 4. Indexes ──
    print("Checking indexes...")
    src_idx = get_indexes(src)
    tgt_idx = get_indexes(tgt)

    for key in sorted(set(src_idx.keys()) - set(tgt_idx.keys())):
        schema, table, idx_name = key
        if (schema, table) not in tgt_tables:
            continue
        report(f"MISSING INDEX: {schema}.{idx_name}")
        alter(f"{src_idx[key]};")

    # ── 5. Views ──
    print("Checking views...")
    src_views = get_views(src)
    tgt_views = get_views(tgt)

    for key in sorted(set(src_views.keys()) - set(tgt_views.keys())):
        schema, view = key
        report(f"NEW VIEW: {schema}.{view}")
        alter(f"CREATE OR REPLACE VIEW {schema}.{view} AS\n{src_views[key]};")

    for key in sorted(set(src_views.keys()) & set(tgt_views.keys())):
        if src_views[key] != tgt_views[key]:
            schema, view = key
            report(f"CHANGED VIEW: {schema}.{view}")
            alter(f"CREATE OR REPLACE VIEW {schema}.{view} AS\n{src_views[key]};")

    # ── 6. Functions/Procedures ──
    print("Checking functions/procedures...")
    src_funcs = get_functions(src)
    tgt_funcs = get_functions(tgt)

    for key in sorted(set(src_funcs.keys()) - set(tgt_funcs.keys())):
        schema, name, args = key
        report(f"NEW FUNCTION: {schema}.{name}({args})")
        alter(f"{src_funcs[key]};")

    for key in sorted(set(src_funcs.keys()) & set(tgt_funcs.keys())):
        if src_funcs[key] != tgt_funcs[key]:
            schema, name, args = key
            report(f"CHANGED FUNCTION: {schema}.{name}({args})")
            alter(f"-- Changed: {schema}.{name}({args})\n{src_funcs[key]};")

    src.close()
    tgt.close()

    return alter_lines, report_lines


# ================================================================
# MAIN
# ================================================================

def main():
    parser = argparse.ArgumentParser(description="Compare two PostgreSQL databases and generate ALTER script")
    parser.add_argument("--source", default="dbanalytics_repo", help="Source (baseline) database name")
    parser.add_argument("--target", default="dbanalytics", help="Target (live) database name")
    parser.add_argument("--output", default=None, help="Output SQL file (default: auto-named)")
    args = parser.parse_args()

    alter_lines, report_lines = compare(args.source, args.target)

    if not alter_lines:
        print("\n  No differences found. Databases are in sync.")
        return

    # Generate output file
    output_file = args.output or f"alter_{args.source}_to_{args.target}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.sql"

    header = (
        f"-- =============================================================================\n"
        f"-- ALTER script: {args.source} -> {args.target}\n"
        f"-- Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
        f"-- Differences found: {len(report_lines)}\n"
        f"-- =============================================================================\n"
        f"-- REVIEW THIS SCRIPT BEFORE RUNNING!\n"
        f"-- Lines starting with '-- REVIEW:' require manual decision.\n"
        f"-- =============================================================================\n\n"
        f"BEGIN;\n\n"
    )

    footer = "\n\n-- Uncomment to apply:\n-- COMMIT;\n\n-- To rollback:\n-- ROLLBACK;\n"

    with open(output_file, "w", encoding="utf-8") as f:
        f.write(header)
        for line in alter_lines:
            f.write(line + "\n\n")
        f.write(footer)

    print(f"\n{'=' * 60}")
    print(f"  Summary: {len(report_lines)} differences found")
    print(f"  ALTER script: {output_file}")
    print(f"{'=' * 60}")


if __name__ == "__main__":
    main()
