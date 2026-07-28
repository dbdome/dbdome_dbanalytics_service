#!/usr/bin/env python3
"""
compare_dbanalytics_repo.py

Compare two PostgreSQL databases on the same cluster:
    src = dbanalytics         (live, customer)
    dst = dbanalytics_repo    (canonical template / repo state)

Two-phase diff. Both phases are read-only.

  PHASE 1 - schema (DDL)
      Same catalog queries as compare_dbanalytics_schemas.py: schemas,
      tables, columns, constraints, indexes, sequences, views, functions,
      enum/composite/domain types.

  PHASE 2 - non-runtime data
      Row-level diff of an allow-list of (schema, table) pairs that hold
      configuration, taxonomy, and definitions (NOT operational/runtime
      data like monitored servers, collected metrics, logs, alerts).
      Each row keyed by the table's primary key (auto-discovered).
      A table without a PK is keyed by the full row tuple and only
      presence/absence is reported (no "changed" detection).

Output legend (same as the schema-only script):
    -  only in src (dst is missing it)
    +  only in dst (dst has extra; src is behind)
    ~  present in both, content differs

Exit codes:
    0  no differences
    1  differences found
    2  connection / SQL error

Usage:
    set PGPASSWORD or use ~/.pgpass, then:

    python compare_dbanalytics_repo.py
    python compare_dbanalytics_repo.py --src-db dbanalytics --dst-db dbanalytics_repo
    python compare_dbanalytics_repo.py --schema-only
    python compare_dbanalytics_repo.py --data-only
    python compare_dbanalytics_repo.py --include-table siem_config.destinations
    python compare_dbanalytics_repo.py --exclude-table jobs.jobs
"""

from __future__ import annotations

import argparse
import difflib
import os
import sys

try:
    import psycopg2
    import psycopg2.extras
except ImportError:
    sys.stderr.write("psycopg2 not installed. Run: pip install psycopg2-binary\n")
    sys.exit(2)


SYSTEM_SCHEMAS = (
    'pg_catalog', 'information_schema', 'pg_toast',
    'sys', 'dbms_sql',
)

# ---------------------------------------------------------------------------
# Allow-list: tables that hold non-runtime data and SHOULD be diffed.
# Runtime tables (metrics.servers, monitoring.*, alerts.*, log.*, agg.*,
# jobs.job_schedules, processes.executions) are deliberately omitted.
# Override at runtime with --include-table / --exclude-table.
# ---------------------------------------------------------------------------
NON_RUNTIME_TABLES = [
    # rootcause taxonomy (the entire detection tree definition)
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

    # config (mail / alerts / reports / SIEM / retention / global)
    ('config', 'global_params'),
    ('config', 'action_types'),
    ('config', 'mail_config'),
    ('config', 'mail_groups'),
    ('config', 'mail_jobs'),
    ('config', 'reports'),
    ('config', 'reports_jobs'),
    ('config', 'alerts'),
    ('config', 'alerts_reports'),
    ('config', 'alerts_thresholds'),
    ('config', 'thresholds'),
    ('config', 'webook_alerts'),
    ('config', 'retention_policy'),
    ('config', 'siem'),
    ('config', 'schema_versions'),

    # metrics non-runtime (definitions, not customer servers)
    ('metrics', 'custom_metrics'),
    ('metrics', 'registered_processes'),
    ('metrics', 'routines'),
    ('metrics', 'sql_injection_patterns'),

    # processes / jobs (templates only -- not executions / job_schedules)
    ('jobs',      'jobs'),
    ('processes', 'process'),
    ('processes', 'steps'),
    ('processes', 'organization'),
]

# Runtime tables — never diffed even if asked. Hardcoded skip list to avoid
# pulling huge result sets and to keep the report focused.
RUNTIME_TABLES_BLOCKLIST = {
    ('metrics', 'servers'),
    ('metrics', 'server_routines'),
    ('metrics', 'servers_routines'),
    ('jobs', 'job_schedules'),
    ('processes', 'executions'),
}


# ---------- catalog queries (unchanged from compare_dbanalytics_schemas) ----

Q_SCHEMAS = """
SELECT nspname FROM pg_namespace
 WHERE nspname NOT IN %(sys)s
   AND nspname NOT LIKE 'pg\\_temp\\_%%'
   AND nspname NOT LIKE 'pg\\_toast\\_temp\\_%%'
 ORDER BY nspname
"""

Q_TABLES = """
SELECT table_schema, table_name, table_type
  FROM information_schema.tables
 WHERE table_schema NOT IN %(sys)s
 ORDER BY table_schema, table_name
"""

Q_COLUMNS = """
SELECT table_schema, table_name, column_name,
       ordinal_position, udt_name AS data_type,
       character_maximum_length, numeric_precision, numeric_scale,
       is_nullable, column_default
  FROM information_schema.columns
 WHERE table_schema NOT IN %(sys)s
 ORDER BY table_schema, table_name, ordinal_position
"""

Q_CONSTRAINTS = """
SELECT n.nspname  AS schema_name, cl.relname AS table_name,
       c.conname  AS constraint_name, c.contype AS constraint_type,
       pg_get_constraintdef(c.oid) AS definition
  FROM pg_constraint c
  JOIN pg_class cl ON cl.oid = c.conrelid
  JOIN pg_namespace n ON n.oid = cl.relnamespace
 WHERE n.nspname NOT IN %(sys)s
 ORDER BY n.nspname, cl.relname, c.conname
"""

Q_INDEXES = """
SELECT schemaname, tablename, indexname, indexdef
  FROM pg_indexes
 WHERE schemaname NOT IN %(sys)s
 ORDER BY schemaname, tablename, indexname
"""

Q_SEQUENCES = """
SELECT sequence_schema, sequence_name, data_type,
       start_value, minimum_value, maximum_value, increment, cycle_option
  FROM information_schema.sequences
 WHERE sequence_schema NOT IN %(sys)s
 ORDER BY sequence_schema, sequence_name
"""

Q_VIEWS = """
SELECT n.nspname AS schema_name, c.relname AS view_name,
       pg_get_viewdef(c.oid, true) AS view_definition,
       CASE c.relkind WHEN 'm' THEN 'MATERIALIZED' ELSE 'VIEW' END AS view_kind
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE c.relkind IN ('v','m') AND n.nspname NOT IN %(sys)s
 ORDER BY n.nspname, c.relname
"""

Q_FUNCTIONS = """
SELECT n.nspname AS schema_name, p.proname AS function_name,
       pg_get_function_identity_arguments(p.oid) AS args,
       pg_get_function_result(p.oid)             AS result_type,
       p.prokind                                 AS kind,
       pg_get_functiondef(p.oid)                 AS definition
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname NOT IN %(sys)s
   AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')
 ORDER BY n.nspname, p.proname, args
"""

Q_TYPES = """
SELECT n.nspname AS schema_name, t.typname AS type_name, t.typtype AS type_kind,
       CASE t.typtype
         WHEN 'e' THEN (SELECT string_agg(enumlabel, ',' ORDER BY enumsortorder)
                          FROM pg_enum WHERE enumtypid = t.oid)
         WHEN 'd' THEN format_type(t.typbasetype, t.typtypmod)
         WHEN 'c' THEN (SELECT string_agg(attname || ' ' || format_type(atttypid, atttypmod),
                                          ', ' ORDER BY attnum)
                          FROM pg_attribute
                         WHERE attrelid = t.typrelid AND attnum > 0 AND NOT attisdropped)
       END AS body
  FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
 WHERE t.typtype IN ('e','c','d')
   AND n.nspname NOT IN %(sys)s
   AND NOT EXISTS (SELECT 1 FROM pg_class c
                    WHERE c.reltype = t.oid AND c.relkind IN ('r','v','m','f','p'))
 ORDER BY n.nspname, t.typname
"""

Q_PK = """
SELECT a.attname
  FROM pg_index i
  JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
 WHERE i.indrelid = (SELECT c.oid FROM pg_class c
                       JOIN pg_namespace n ON n.oid = c.relnamespace
                      WHERE n.nspname = %s AND c.relname = %s)
   AND i.indisprimary
 ORDER BY array_position(i.indkey, a.attnum)
"""

Q_TABLE_EXISTS = """
SELECT 1 FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = %s AND c.relname = %s AND c.relkind = 'r'
"""


# ---------- helpers ----------

def connect(host, port, user, dbname, password):
    return psycopg2.connect(host=host, port=port, user=user, dbname=dbname,
                            password=password, connect_timeout=10)


def fetch(conn, sql, params=None):
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute(sql, params or {})
        return [dict(r) for r in cur.fetchall()]


def table_exists(conn, schema, table):
    with conn.cursor() as cur:
        cur.execute(Q_TABLE_EXISTS, (schema, table))
        return cur.fetchone() is not None


def get_primary_key(conn, schema, table):
    with conn.cursor() as cur:
        cur.execute(Q_PK, (schema, table))
        return [r[0] for r in cur.fetchall()]


def fetch_rows(conn, schema, table):
    """Fetch every row as a dict. Caller picks the key columns."""
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute(f'SELECT * FROM "{schema}"."{table}"')
        return [dict(r) for r in cur.fetchall()]


def key_index(rows, key_fields):
    return {tuple(r[k] for k in key_fields): r for r in rows}


def fmt_key(k):
    if isinstance(k, tuple):
        return "(" + ", ".join(repr(p) for p in k) + ")"
    return repr(k)


# ---------- schema phase ----------

def diff_section(title, src_rows, dst_rows, key_fields, value_fields,
                 multiline_field=None):
    src = key_index(src_rows, key_fields)
    dst = key_index(dst_rows, key_fields)
    only_src = sorted(set(src) - set(dst), key=lambda x: tuple(map(str, x)))
    only_dst = sorted(set(dst) - set(src), key=lambda x: tuple(map(str, x)))
    common   = sorted(set(src) & set(dst), key=lambda x: tuple(map(str, x)))

    changed = []
    for k in common:
        a, b = src[k], dst[k]
        diffs = [(f, a.get(f), b.get(f)) for f in value_fields
                 if str(a.get(f)) != str(b.get(f))]
        if diffs:
            changed.append((k, diffs))

    if not (only_src or only_dst or changed):
        return 0
    print()
    print(f"=== {title} ===")
    for k in only_src: print(f"  -  {fmt_key(k)}")
    for k in only_dst: print(f"  +  {fmt_key(k)}")
    for k, diffs in changed:
        print(f"  ~  {fmt_key(k)}")
        for f, va, vb in diffs:
            if multiline_field and f == multiline_field:
                print(f"       {f}: (unified diff)")
                a_lines = (va or '').splitlines()
                b_lines = (vb or '').splitlines()
                for line in difflib.unified_diff(a_lines, b_lines, lineterm='', n=2,
                                                 fromfile='src', tofile='dst'):
                    print(f"         {line}")
            else:
                print(f"       {f}:  src={va!r}  dst={vb!r}")
    return len(only_src) + len(only_dst) + len(changed)


def schema_phase(src, dst, sys_schemas):
    print("# === PHASE 1: schema (DDL) ===")
    total = 0
    sections = [
        ("Schemas",
         Q_SCHEMAS,            ('nspname',),                              ()),
        ("Tables / views",
         Q_TABLES,             ('table_schema', 'table_name'),            ('table_type',)),
        ("Columns",
         Q_COLUMNS,            ('table_schema', 'table_name', 'column_name'),
         ('data_type','character_maximum_length','numeric_precision','numeric_scale',
          'is_nullable','column_default','ordinal_position')),
        ("Constraints",
         Q_CONSTRAINTS,        ('schema_name','table_name','constraint_name'),
         ('constraint_type','definition')),
        ("Indexes",
         Q_INDEXES,            ('schemaname','tablename','indexname'),    ('indexdef',)),
        ("Sequences",
         Q_SEQUENCES,          ('sequence_schema','sequence_name'),
         ('data_type','increment','minimum_value','maximum_value','cycle_option')),
        ("Views",
         Q_VIEWS,              ('schema_name','view_name'),
         ('view_kind','view_definition')),
        ("Functions / procedures",
         Q_FUNCTIONS,          ('schema_name','function_name','args'),
         ('result_type','kind','definition')),
        ("Types (enum/composite/domain)",
         Q_TYPES,              ('schema_name','type_name'),
         ('type_kind','body')),
    ]
    for title, q, keys, vals in sections:
        a = fetch(src, q, {"sys": sys_schemas})
        b = fetch(dst, q, {"sys": sys_schemas})
        ml = 'view_definition' if title == 'Views' else (
              'definition'      if title.startswith('Functions') else None)
        total += diff_section(title, a, b, keys, vals, multiline_field=ml)
    return total


# ---------- data phase ----------

def data_phase(src, dst, table_list):
    print()
    print("# === PHASE 2: non-runtime data ===")
    total = 0
    for schema, table in table_list:
        in_src = table_exists(src, schema, table)
        in_dst = table_exists(dst, schema, table)
        if not in_src and not in_dst:
            continue   # truly missing on both sides; schema phase reports it

        if not in_src or not in_dst:
            label = "src" if in_dst else "dst"
            print(f"\n[skip] {schema}.{table} -- not present in {label}; see schema phase")
            total += 1
            continue

        pk_src = get_primary_key(src, schema, table)
        pk_dst = get_primary_key(dst, schema, table)
        if pk_src != pk_dst:
            print(f"\n[skip] {schema}.{table} -- PK mismatch  src={pk_src} dst={pk_dst}; "
                  "see schema phase for the cause")
            total += 1
            continue

        rows_src = fetch_rows(src, schema, table)
        rows_dst = fetch_rows(dst, schema, table)

        if not pk_src:
            # No PK: report only counts + presence by full-row hash.
            set_src = {tuple(sorted(r.items())) for r in rows_src}
            set_dst = {tuple(sorted(r.items())) for r in rows_dst}
            only_src = set_src - set_dst
            only_dst = set_dst - set_src
            if not (only_src or only_dst):
                continue
            print(f"\n=== data: {schema}.{table} (no PK; row-set diff) ===")
            for r in list(only_src)[:25]:
                print(f"  -  {dict(r)}")
            if len(only_src) > 25: print(f"     ... and {len(only_src)-25} more in src only")
            for r in list(only_dst)[:25]:
                print(f"  +  {dict(r)}")
            if len(only_dst) > 25: print(f"     ... and {len(only_dst)-25} more in dst only")
            total += len(only_src) + len(only_dst)
            continue

        # PK present: index, then 3-way diff.
        idx_src = key_index(rows_src, pk_src)
        idx_dst = key_index(rows_dst, pk_src)
        keys_only_src = sorted(set(idx_src) - set(idx_dst),
                               key=lambda x: tuple(map(str, x)))
        keys_only_dst = sorted(set(idx_dst) - set(idx_src),
                               key=lambda x: tuple(map(str, x)))
        common         = sorted(set(idx_src) & set(idx_dst),
                                key=lambda x: tuple(map(str, x)))
        changed = []
        for k in common:
            a, b = idx_src[k], idx_dst[k]
            cols = sorted(set(a) | set(b))
            diffs = [(c, a.get(c), b.get(c)) for c in cols
                     if str(a.get(c)) != str(b.get(c))]
            if diffs:
                changed.append((k, diffs))

        if not (keys_only_src or keys_only_dst or changed):
            continue

        print(f"\n=== data: {schema}.{table} (PK={pk_src}) ===")
        for k in keys_only_src:
            print(f"  -  {fmt_key(k)}")
        for k in keys_only_dst:
            print(f"  +  {fmt_key(k)}")
        for k, diffs in changed:
            print(f"  ~  {fmt_key(k)}")
            for col, va, vb in diffs:
                # Truncate long column dumps so a wide jsonb doesn't blow the screen.
                sa = str(va); sb = str(vb)
                if len(sa) > 240: sa = sa[:240] + "..."
                if len(sb) > 240: sb = sb[:240] + "..."
                print(f"       {col}:  src={sa}  dst={sb}")
        total += len(keys_only_src) + len(keys_only_dst) + len(changed)

    return total


# ---------- main ----------

def parse_table(s):
    if '.' not in s:
        raise argparse.ArgumentTypeError(f"expected schema.table, got {s!r}")
    a, b = s.split('.', 1)
    return (a, b)


def main():
    p = argparse.ArgumentParser(
        description="Compare two PG dbs (live vs canonical-repo) for schema and "
                    "non-runtime data drift.")
    p.add_argument('--host',     default='localhost')
    p.add_argument('--port',     default=5432, type=int)
    p.add_argument('--user',     default='dbdome_adm')
    p.add_argument('--src-db',   default='dbanalytics')
    p.add_argument('--dst-db',   default='dbanalytics_repo')
    p.add_argument('--password', default=os.environ.get('PGPASSWORD'))
    p.add_argument('--exclude-schema', action='append', default=[])
    p.add_argument('--include-table',  action='append', default=[],
                   type=parse_table,
                   help='Add table (schema.table) to the data-diff allow-list.')
    p.add_argument('--exclude-table',  action='append', default=[],
                   type=parse_table,
                   help='Drop table (schema.table) from the data-diff allow-list.')
    p.add_argument('--schema-only', action='store_true',
                   help='Run only phase 1 (DDL diff).')
    p.add_argument('--data-only',   action='store_true',
                   help='Run only phase 2 (non-runtime data diff).')
    args = p.parse_args()

    sys_schemas = SYSTEM_SCHEMAS + tuple(args.exclude_schema)

    # Resolve the data table list.
    tables = list(NON_RUNTIME_TABLES)
    for t in args.include_table:
        if t not in tables and t not in RUNTIME_TABLES_BLOCKLIST:
            tables.append(t)
    excludes = set(args.exclude_table) | RUNTIME_TABLES_BLOCKLIST
    tables = [t for t in tables if t not in excludes]

    print(f"# src: {args.user}@{args.host}:{args.port}/{args.src_db}")
    print(f"# dst: {args.user}@{args.host}:{args.port}/{args.dst_db}")
    print(f"# data tables: {len(tables)}  (use --include-table / --exclude-table to change)")

    try:
        src = connect(args.host, args.port, args.user, args.src_db, args.password)
    except Exception as e:
        sys.stderr.write(f"src connect failed: {e}\n")
        sys.exit(2)
    try:
        dst = connect(args.host, args.port, args.user, args.dst_db, args.password)
    except Exception as e:
        src.close()
        sys.stderr.write(f"dst connect failed: {e}\n")
        sys.exit(2)

    total = 0
    try:
        if not args.data_only:
            total += schema_phase(src, dst, sys_schemas)
        if not args.schema_only:
            total += data_phase(src, dst, tables)
    finally:
        src.close()
        dst.close()

    print()
    if total == 0:
        print("# no differences found.")
        sys.exit(0)
    print(f"# {total} differing object(s) / row(s).")
    sys.exit(1)


if __name__ == '__main__':
    main()
