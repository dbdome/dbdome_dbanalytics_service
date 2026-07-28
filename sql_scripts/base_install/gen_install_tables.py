#!/usr/bin/env python3
"""
Generate idempotent per-table install scripts from a plain pg_dump.

For every table in C:\\install\\dbanalytics_install.backup this emits one
sql_scripts/install_tables/<schema>.<table>.sql that is safe to run repeatedly
via `psql -f`:

  * CREATE SCHEMA   IF NOT EXISTS
  * CREATE SEQUENCE IF NOT EXISTS   (each sequence the table owns)
  * CREATE TABLE    IF NOT EXISTS
  * the serial DEFAULT + sequence OWNED BY wiring
  * data is loaded ONLY into a freshly-created (empty) table:
        COPY into a TEMP staging table, then
        INSERT ... SELECT ... WHERE NOT EXISTS (SELECT 1 FROM target)
    so a re-run against an already-populated table inserts nothing (no dupes),
    which is exactly "if the table does not exist, add it and insert the data".
  * setval() recomputed from the actual table (never regresses the sequence)

Constraints / indexes / FKs / views are intentionally out of scope here.
"""
import os
import re

SRC = r"C:\install\dbanalytics_install.backup"
OUT_DIR = r"C:\dev\dbdome_dbanalytics_service\sql_scripts\base_install\install_tables"

# Schemas whose tables are runtime/audit data, NOT install seed data: emit their
# table structure but NEVER embed their rows, so a fresh install starts with these
# tables empty (they fill at runtime).
NO_DATA_SCHEMAS = {"log", "monitoring"}

HDR = re.compile(r'^-- (?:Data for )?Name: (.+?); Type: (.+?); Schema: (.+?); Owner:')

os.makedirs(OUT_DIR, exist_ok=True)

with open(SRC, "r", encoding="utf-8", newline="") as fh:
    lines = fh.readlines()

# ---- split the dump into typed object blocks -------------------------------
blocks = []
cur = None
in_copy = False
for line in lines:
    if not in_copy:
        m = HDR.match(line)
        if m:
            cur = {"name": m.group(1), "type": m.group(2),
                   "schema": m.group(3), "body": []}
            blocks.append(cur)
            continue
    if cur is not None:
        cur["body"].append(line)
        s = line.rstrip("\n")
        if not in_copy and s.startswith("COPY ") and s.endswith("FROM stdin;"):
            in_copy = True
        elif in_copy and s == r"\.":
            in_copy = False

# ---- collect per object ----------------------------------------------------
tbl_create   = {}                 # (schema, table) -> CREATE TABLE stmt (lines)
tbl_data     = {}                 # (schema, table) -> {"copy": line, "rows": [..]}
tbl_defaults = {}                 # (schema, table) -> [ALTER .. SET DEFAULT ..]
seq_create   = {}                 # (schema, seq)   -> CREATE SEQUENCE stmt
seq_owned    = {}                 # (schema, seq)   -> (tschema, ttable, col)
tbl_identity = {}                 # (schema, table) -> [ {alter, col, seqname} ]
tbl_cons     = {}                 # (schema, table) -> [ {conname, stmt} ]  (PK/unique/check)
tbl_attach   = {}                 # (child schema, child table) -> ATTACH PARTITION stmt
tbl_idx      = {}                 # (schema, table) -> [ create-index-stmt ]
fk_cons      = []                 # [ {schema, table, conname, stmt} ]
routines_views = []               # [str] functions/procedures/views/matviews, in dump order
# also map table -> set of (schema, seq)
tbl_seqs     = {}

def stmt_until_semicolon(body, start_kw):
    """Return the statement starting at the first line beginning with start_kw,
    up to and including the first line that ends with ';'."""
    out, started = [], False
    for ln in body:
        if not started and ln.lstrip().startswith(start_kw):
            started = True
        if started:
            out.append(ln)
            if ln.rstrip().endswith(";"):
                break
    return out

def cut_before_owner(body, create_kw):
    """Return the CREATE statement text (string) from the first line starting with
    create_kw up to, but not including, the trailing 'ALTER ... OWNER TO ...' line
    that pg_dump emits after every routine/view."""
    start = None
    for i, ln in enumerate(body):
        if start is None and ln.lstrip().startswith(create_kw):
            start = i
            continue
        if start is not None and re.match(r"^ALTER\s+\w+.*\bOWNER TO ", ln):
            return "".join(body[start:i]).rstrip()
    return "".join(body[start:]).rstrip() if start is not None else ""

def make_idempotent_routine(text):
    for frm, to in (("CREATE FUNCTION ", "CREATE OR REPLACE FUNCTION "),
                    ("CREATE PROCEDURE ", "CREATE OR REPLACE PROCEDURE "),
                    ("CREATE VIEW ", "CREATE OR REPLACE VIEW "),
                    ("CREATE MATERIALIZED VIEW ",
                     "CREATE MATERIALIZED VIEW IF NOT EXISTS ")):
        if text.startswith(frm):
            return to + text[len(frm):]
    return text

for b in blocks:
    t, schema, name = b["type"], b["schema"], b["name"]
    if t == "TABLE":
        tbl_create[(schema, name)] = stmt_until_semicolon(b["body"], "CREATE TABLE")
    elif t == "SEQUENCE":
        txt = "".join(b["body"])
        if "CREATE SEQUENCE" in txt:
            seq_create[(schema, name)] = stmt_until_semicolon(b["body"], "CREATE SEQUENCE")
        elif "AS IDENTITY" in txt:
            # identity column: ALTER TABLE t ALTER COLUMN c ADD GENERATED .. AS IDENTITY (...)
            m = re.search(r"ALTER TABLE\s+(\S+)\.(\w+)\s+ALTER COLUMN\s+(\w+)\s+ADD GENERATED",
                          txt)
            sm = re.search(r"SEQUENCE NAME\s+(\S+)", txt)
            if m:
                ts, tt, col = m.group(1), m.group(2), m.group(3)
                alter_lines, started = [], False
                for ln in b["body"]:
                    if not started and "ALTER TABLE" in ln:
                        started = True
                    if started:
                        alter_lines.append(ln.rstrip("\n"))
                        if ln.strip() == ");":
                            break
                tbl_identity.setdefault((ts, tt), []).append(
                    {"alter": "\n".join(alter_lines), "col": col,
                     "seqname": sm.group(1) if sm else None})
    elif t == "TABLE ATTACH":
        # pg_dump emits partition membership as a separate block:
        #   ALTER TABLE ONLY <parent> ATTACH PARTITION <child> FOR VALUES ...;
        # Dropping these leaves partitions detached and every INSERT into the
        # parent failing ("no partition ... found for row") — keep them.
        stmt = "".join(stmt_until_semicolon(b["body"], "ALTER TABLE")).rstrip()
        m = re.search(r"ATTACH PARTITION\s+(\S+?)\.(\S+?)[\s;]", stmt + " ")
        if m:
            tbl_attach[(m.group(1), m.group(2).strip('"'))] = stmt
    elif t == "SEQUENCE OWNED BY":
        txt = "".join(b["body"])
        m = re.search(r"ALTER SEQUENCE\s+(\S+)\s+OWNED BY\s+(\S+)\.(\w+);", txt)
        if m:
            seq_fqn = m.group(1)
            owner_tbl = m.group(2)        # schema.table
            col = m.group(3)
            ts, tt = owner_tbl.split(".", 1)
            seq_owned[(schema, name)] = (ts, tt, col)
            tbl_seqs.setdefault((ts, tt), set()).add((schema, name))
    elif t == "DEFAULT":
        txt = "".join(b["body"])
        m = re.search(r"ALTER TABLE ONLY\s+(\S+)\.(\w+)\s+ALTER COLUMN\s+(\w+)\s+"
                      r"SET DEFAULT nextval\('([^']+)'", txt)
        if m:
            ts, tt, col, seq_fqn = m.group(1), m.group(2), m.group(3), m.group(4)
            tbl_defaults.setdefault((ts, tt), []).append(
                f"ALTER TABLE {ts}.{tt} ALTER COLUMN {col} "
                f"SET DEFAULT nextval('{seq_fqn}'::regclass);")
            ss, sn = seq_fqn.split(".", 1)
            seq_owned.setdefault((ss, sn), (ts, tt, col))
            tbl_seqs.setdefault((ts, tt), set()).add((ss, sn))
    elif t == "TABLE DATA":
        copy_line, rows = None, []
        collecting = False
        for ln in b["body"]:
            s = ln.rstrip("\n")
            if not collecting and s.startswith("COPY ") and s.endswith("FROM stdin;"):
                copy_line = s
                collecting = True
                continue
            if collecting:
                if s == r"\.":
                    break
                rows.append(ln)
        if copy_line is not None and rows:        # only keep non-empty data
            tbl_data[(schema, name)] = {"copy": copy_line, "rows": rows}
    elif t == "CONSTRAINT":
        stmt = "".join(stmt_until_semicolon(b["body"], "ALTER TABLE")).rstrip()
        mt = re.search(r"ALTER TABLE ONLY\s+(\S+)", stmt)
        mc = re.search(r"ADD CONSTRAINT\s+(\S+)", stmt)
        if mt and mc:
            ts, tt = mt.group(1).split(".", 1)
            tbl_cons.setdefault((ts, tt.strip('"')), []).append(
                {"conname": mc.group(1).strip('"'), "stmt": stmt})
    elif t == "FK CONSTRAINT":
        stmt = "".join(stmt_until_semicolon(b["body"], "ALTER TABLE")).rstrip()
        mt = re.search(r"ALTER TABLE ONLY\s+(\S+)", stmt)
        mc = re.search(r"ADD CONSTRAINT\s+(\S+)", stmt)
        if mt and mc:
            ts, tt = mt.group(1).split(".", 1)
            fk_cons.append({"schema": ts, "table": tt.strip('"'),
                            "conname": mc.group(1).strip('"'), "stmt": stmt})
    elif t == "INDEX":
        stmt = "".join(stmt_until_semicolon(b["body"], "CREATE")).rstrip()
        mt = re.search(r"\bON\s+(?:ONLY\s+)?(\S+)", stmt)
        if mt and stmt.upper().startswith("CREATE"):
            ts, tt = mt.group(1).split(".", 1)
            stmt = re.sub(r"^CREATE UNIQUE INDEX ",
                          "CREATE UNIQUE INDEX IF NOT EXISTS ", stmt)
            stmt = re.sub(r"^CREATE INDEX ",
                          "CREATE INDEX IF NOT EXISTS ", stmt)
            tbl_idx.setdefault((ts, tt.strip('"')), []).append(stmt)
    elif t in ("FUNCTION", "PROCEDURE"):
        kw = "CREATE FUNCTION" if t == "FUNCTION" else "CREATE PROCEDURE"
        stmt = cut_before_owner(b["body"], kw)
        if stmt:
            routines_views.append(make_idempotent_routine(stmt))
    elif t == "VIEW":
        stmt = cut_before_owner(b["body"], "CREATE VIEW")
        if stmt:
            routines_views.append(make_idempotent_routine(stmt))
    elif t == "MATERIALIZED VIEW":
        stmt = cut_before_owner(b["body"], "CREATE MATERIALIZED VIEW")
        if stmt:
            routines_views.append(make_idempotent_routine(stmt))
    elif t == "MATERIALIZED VIEW DATA":
        for ln in b["body"]:
            if ln.lstrip().startswith("REFRESH MATERIALIZED VIEW"):
                routines_views.append(ln.strip())
                break

def as_if_not_exists(stmt_lines, kw_from, kw_to):
    out = list(stmt_lines)
    if out:
        out[0] = out[0].replace(kw_from, kw_to, 1)
    return out

def guarded_constraint(schema, table, conname, stmt):
    """Wrap an ALTER TABLE ... ADD CONSTRAINT in a guard that runs it only if a
    constraint of that name doesn't already exist on the table."""
    return (
        "DO $do$\nBEGIN\n"
        "    IF NOT EXISTS (SELECT 1 FROM pg_constraint con\n"
        "        JOIN pg_class c ON c.oid = con.conrelid\n"
        "        JOIN pg_namespace n ON n.oid = c.relnamespace\n"
        f"        WHERE n.nspname = '{schema}' AND c.relname = '{table}'\n"
        f"          AND con.conname = '{conname}') THEN\n"
        f"        {stmt.strip()}\n"
        "    END IF;\nEND $do$;")

# ---- emit one script per table --------------------------------------------
written = 0
index_lines = []
for (schema, table) in sorted(tbl_create.keys()):
    parts = []
    parts.append(f"-- Idempotent install for {schema}.{table}")
    parts.append(f"-- Auto-generated from {os.path.basename(SRC)}. Safe to re-run (psql -f).")
    parts.append("")
    parts.append(f"CREATE SCHEMA IF NOT EXISTS {schema};")
    parts.append("")

    seqs = sorted(tbl_seqs.get((schema, table), set()))
    for (ss, sn) in seqs:
        if (ss, sn) in seq_create:
            parts.append("".join(as_if_not_exists(
                seq_create[(ss, sn)], "CREATE SEQUENCE", "CREATE SEQUENCE IF NOT EXISTS")).rstrip())
            parts.append("")

    parts.append("".join(as_if_not_exists(
        tbl_create[(schema, table)], "CREATE TABLE", "CREATE TABLE IF NOT EXISTS")).rstrip())
    parts.append("")

    # partition membership: re-attach to the parent when created detached
    att = tbl_attach.get((schema, table))
    if att:
        parts.append(
            "DO $do$\nBEGIN\n"
            f"    IF NOT EXISTS (SELECT 1 FROM pg_inherits\n"
            f"        WHERE inhrelid = '{schema}.{table}'::regclass) THEN\n"
            f"        {att.replace('ALTER TABLE ONLY', 'ALTER TABLE').strip()}\n"
            "    END IF;\nEND $do$;")
        parts.append("")

    # identity column(s): add only if the column isn't already an identity
    for idy in tbl_identity.get((schema, table), []):
        parts.append(
            "DO $do$\nBEGIN\n"
            "    IF NOT EXISTS (SELECT 1 FROM pg_attribute a\n"
            "        JOIN pg_class c ON c.oid = a.attrelid\n"
            "        JOIN pg_namespace n ON n.oid = c.relnamespace\n"
            f"        WHERE n.nspname = '{schema}' AND c.relname = '{table}'\n"
            f"          AND a.attname = '{idy['col']}' AND a.attidentity <> '') THEN\n"
            f"        EXECUTE $cmd$ {idy['alter']} $cmd$;\n"
            "    END IF;\nEND $do$;")
    if tbl_identity.get((schema, table)):
        parts.append("")

    for d in tbl_defaults.get((schema, table), []):
        parts.append(d)
    for (ss, sn) in seqs:
        ow = seq_owned.get((ss, sn))
        if ow:
            ts, tt, col = ow
            parts.append(f"ALTER SEQUENCE {ss}.{sn} OWNED BY {ts}.{tt}.{col};")
    if tbl_defaults.get((schema, table)) or seqs:
        parts.append("")

    data = None if schema in NO_DATA_SCHEMAS else tbl_data.get((schema, table))
    if data:
        m = re.match(r"^COPY\s+\S+\s+(\(.*\))\s+FROM stdin;$", data["copy"])
        cols = m.group(1) if m else ""
        identity = (schema, table) in tbl_identity
        overriding = " OVERRIDING SYSTEM VALUE" if identity else ""
        collist = cols[1:-1].strip()        # drop the surrounding parens
        parts.append("-- data: load only into a freshly-created (empty) table")
        parts.append("DROP TABLE IF EXISTS _stg_load;")
        parts.append(f"CREATE TEMP TABLE _stg_load (LIKE {schema}.{table});")
        block = f"COPY _stg_load {cols} FROM stdin;\n" + "".join(data["rows"]) + "\\.\n"
        parts.append(block.rstrip("\n"))
        parts.append(
            f"INSERT INTO {schema}.{table} ({collist}){overriding}\n"
            f"SELECT {collist} FROM _stg_load\n"
            f"WHERE NOT EXISTS (SELECT 1 FROM {schema}.{table});")
        parts.append("DROP TABLE _stg_load;")
        parts.append("")

    # recompute each owned sequence from the actual table (never regresses)
    for (ss, sn) in seqs:
        ow = seq_owned.get((ss, sn))
        if ow:
            ts, tt, col = ow
            parts.append(
                f"SELECT setval('{ss}.{sn}', "
                f"GREATEST((SELECT COALESCE(max({col}),0) FROM {ts}.{tt}),1), "
                f"(SELECT count(*) FROM {ts}.{tt}) > 0);")
    for idy in tbl_identity.get((schema, table), []):
        if idy.get("seqname"):
            parts.append(
                f"SELECT setval('{idy['seqname']}', "
                f"GREATEST((SELECT COALESCE(max({idy['col']}),0) FROM {schema}.{table}),1), "
                f"(SELECT count(*) FROM {schema}.{table}) > 0);")
    parts.append("")

    # constraints (PK / unique / check) — guarded so re-runs don't error
    cons = tbl_cons.get((schema, table), [])
    for c in cons:
        parts.append(guarded_constraint(schema, table, c["conname"], c["stmt"]))
    if cons:
        parts.append("")

    # indexes (CREATE INDEX IF NOT EXISTS)
    idxs = tbl_idx.get((schema, table), [])
    for ix in idxs:
        parts.append(ix.strip())
    if idxs:
        parts.append("")

    fname = f"{schema}.{table}.sql"
    with open(os.path.join(OUT_DIR, fname), "w", encoding="utf-8", newline="\n") as out:
        out.write("\n".join(parts).rstrip() + "\n")
    index_lines.append(f"\\ir install_tables/{fname}")
    written += 1

# foreign keys: separate, run AFTER every table exists (cross-table refs)
fk_path = os.path.join(os.path.dirname(OUT_DIR), "90_foreign_keys.sql")
with open(fk_path, "w", encoding="utf-8", newline="\n") as fkf:
    fkf.write("-- Foreign-key constraints, applied after all tables exist.\n")
    fkf.write("-- Idempotent: each FK is added only if its name isn't already present.\n\n")
    for fk in sorted(fk_cons, key=lambda x: (x["schema"], x["table"], x["conname"])):
        fkf.write(guarded_constraint(fk["schema"], fk["table"],
                                     fk["conname"], fk["stmt"]) + "\n\n")

# functions / procedures / views / matviews, in dump (dependency) order.
# Run last: views depend on tables + functions, all created by now.
rv_path = os.path.join(os.path.dirname(OUT_DIR), "95_views_and_functions.sql")
with open(rv_path, "w", encoding="utf-8", newline="\n") as rvf:
    rvf.write("-- Functions, procedures, views and materialized views.\n")
    rvf.write("-- Emitted in pg_dump dependency order; functions/procedures/views use\n")
    rvf.write("-- CREATE OR REPLACE and matviews use IF NOT EXISTS, so re-runs are safe.\n\n")
    rvf.write("\n\n".join(routines_views) + "\n")

# convenience runner that includes every table script
with open(os.path.join(os.path.dirname(OUT_DIR), "00_install_all_tables.sql"),
          "w", encoding="utf-8", newline="\n") as idx:
    idx.write("-- Run the entire idempotent install (tables, data, constraints,\n")
    idx.write("-- indexes, foreign keys, functions and views).\n")
    idx.write("-- Usage:  psql -d dbanalytics -f sql_scripts/00_install_all_tables.sql\n\n")
    idx.write("\\ir 00_prereqs.sql\n\n")
    idx.write("\n".join(sorted(index_lines)) + "\n")
    idx.write("\n\\ir 90_foreign_keys.sql\n")
    idx.write("\\ir 95_views_and_functions.sql\n")

print(f"tables: {len(tbl_create)}  with-data: {len(tbl_data)}  "
      f"sequences: {len(seq_create)}  scripts written: {written}")
print(f"constraints: {sum(len(v) for v in tbl_cons.values())}  "
      f"indexes: {sum(len(v) for v in tbl_idx.values())}  fks: {len(fk_cons)}")
print(f"routines+views entries: {len(routines_views)}")
