r"""
Ordered SQL runner — applies *.sql migrations strictly in FILENAME order,
tracking what has run so each script executes only once per content.

Ordering
--------
Files run in ascending filename order (case-insensitive). Put a zero-padded
sequence number at the head of the filename to control order, e.g.

    0010_create_schema.sql
    0020_create_rc_views.sql
    0030_fix_rc15_login_name.sql

Zero-pad (0010, not 10) so the lexicographic sort matches the numeric order.

Run-once vs re-apply
--------------------
Each script's text is checksummed (line-ending-insensitive). A script runs when
its (filename, checksum) has not been successfully applied before:
  * a one-shot migration never changes  -> runs exactly once;
  * an edited CREATE OR REPLACE VIEW/FUNCTION changes checksum -> re-applies.
Unchanged scripts are skipped, so the daily re-run is a cheap no-op.

Safety
------
  * A Postgres advisory lock serialises concurrent runners (every service
    startup calls this), so only one instance applies at a time.
  * Each script runs in its own transaction together with its ledger row, so
    the record and the change commit atomically.
  * A failing script is logged and recorded, then the run CONTINUES (one broken
    view never blocks the rest). Inspect meta.schema_migrations for failures.

Ledger: meta.schema_migrations (auto-created).

Folders (additive, scanned in priority order; first wins on filename clash):
  1) $SQL_SCRIPTS_DIR
  2) <exe dir>\..\postgres\install     (operator/update migrations)
  3) <exe dir>\postgres\install
  4) <exe dir>\sql_scripts             (external next to exe)
  5) <_MEIPASS>\sql_scripts            (bundled in the frozen exe)
  6) <repo>\sql_scripts                (dev)
"""
import os
import sys
import glob
import time
import hashlib

import psycopg2

from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log

# Fixed key for pg_advisory_lock — any constant unique to this runner.
_ADVISORY_LOCK_KEY = 727274

_LEDGER_DDL = """
CREATE SCHEMA IF NOT EXISTS meta;
CREATE TABLE IF NOT EXISTS meta.schema_migrations (
    id           bigserial PRIMARY KEY,
    filename     text        NOT NULL,
    checksum     text        NOT NULL,
    applied_at   timestamptz NOT NULL DEFAULT now(),
    execution_ms integer,
    success      boolean     NOT NULL DEFAULT true,
    error        text
);
CREATE INDEX IF NOT EXISTS ix_schema_migrations_file
    ON meta.schema_migrations(filename, applied_at DESC);
"""


def _sql_scripts_dirs():
    """All folders to scan, in priority order (first wins on filename clash).

    Additive on purpose: the shipped view/migration set is bundled in the exe
    (sql_scripts), while operator/update migrations are dropped next to the
    install bootstrap (postgres\\install). Both feed the single ledger, so
    pointing SQL_SCRIPTS_DIR at postgres\\install does NOT hide the bundled
    scripts — it adds to them.
    """
    exe_dir = os.path.dirname(os.path.abspath(sys.executable))
    candidates = []
    env = os.getenv("SQL_SCRIPTS_DIR")
    if env:
        candidates.append(env)                                   # explicit override (highest)
    candidates.append(os.path.join(exe_dir, "..", "postgres", "install"))   # <DEST_DIR>\postgres\install
    candidates.append(os.path.join(exe_dir, "postgres", "install"))
    candidates.append(os.path.join(exe_dir, "sql_scripts"))      # external next to exe
    meipass = getattr(sys, "_MEIPASS", None)
    if meipass:
        candidates.append(os.path.join(meipass, "sql_scripts"))  # bundled (onedir _internal)
    candidates.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sql_scripts"))  # dev repo
    seen, dirs = set(), []
    for c in candidates:
        if not c:
            continue
        ap = os.path.abspath(c)
        if ap not in seen:
            seen.add(ap)
            if os.path.isdir(ap):
                dirs.append(ap)
    return dirs


def _checksum(text):
    # Normalise line endings so CRLF/LF checkouts don't look "changed".
    norm = text.replace("\r\n", "\n").replace("\r", "\n")
    return hashlib.sha256(norm.encode("utf-8")).hexdigest()


def _log(msg, level=0):
    print(f"[sql_script_runner] {msg}")
    if level == 0:
        return
    try:
        db_write_log(msg, 0, "sql_script_runner", "")
    except Exception:
        pass


def _record(conn, *, filename, checksum, execution_ms, success, error):
    cur = conn.cursor()
    cur.execute(
        """INSERT INTO meta.schema_migrations
               (filename, checksum, execution_ms, success, error)
           VALUES (%s,%s,%s,%s,%s)""",
        (filename, checksum, execution_ms, success, error),
    )
    cur.close()


def run_sql_scripts():
    folders = _sql_scripts_dirs()
    if not folders:
        _log("no sql_scripts folder found", level=1)
        return

    # Merge *.sql across all folders; higher-priority folder wins on basename.
    by_name = {}
    for folder in folders:
        for path in sorted(glob.glob(os.path.join(folder, "*.sql"))):
            by_name.setdefault(os.path.basename(path), path)
    # Strict filename order (case-insensitive) — sequence-number prefix drives it.
    names = sorted(by_name, key=str.lower)
    if not names:
        _log(f"no .sql files in {folders}")
        return

    try:
        conn = psycopg2.connect(get_connection_string())
    except Exception as e:
        _log(f"connect failed: {e}", level=1)
        return

    applied = changed = skipped = errors = 0
    locked = False
    try:
        # Serialise concurrent runners (each service startup calls this).
        with conn.cursor() as c:
            c.execute("SELECT pg_advisory_lock(%s)", (_ADVISORY_LOCK_KEY,))
        conn.commit()
        locked = True

        # Ensure the ledger exists.
        with conn.cursor() as c:
            c.execute(_LEDGER_DDL)
        conn.commit()

        # Latest successful checksum per filename.
        with conn.cursor() as c:
            c.execute("""SELECT DISTINCT ON (filename) filename, checksum
                         FROM meta.schema_migrations
                         WHERE success
                         ORDER BY filename, applied_at DESC""")
            last_ok = {fn: cs for fn, cs in c.fetchall()}

        # Single ordered pass.
        for name in names:
            path = by_name[name]
            with open(path, "r", encoding="utf-8") as f:
                sql = f.read()
            cs = _checksum(sql)
            if last_ok.get(name) == cs:          # already applied, unchanged
                skipped += 1
                continue
            if not sql.strip():
                continue
            first_time = name not in last_ok
            t0 = time.time()
            try:
                with conn.cursor() as c:
                    c.execute(sql)               # multi-statement / DO / functions ok
                _record(conn, filename=name, checksum=cs,
                        execution_ms=int((time.time() - t0) * 1000),
                        success=True, error=None)
                conn.commit()
                if first_time:
                    applied += 1
                else:
                    changed += 1
                _log(f"{'applied' if first_time else 'changed'}  {name}")
            except Exception as e:
                conn.rollback()
                _record(conn, filename=name, checksum=cs,
                        execution_ms=int((time.time() - t0) * 1000),
                        success=False, error=str(e)[:2000])
                conn.commit()
                errors += 1
                _log(f"ERR {name}: {e}", level=1)
    finally:
        if locked:
            try:
                with conn.cursor() as c:
                    c.execute("SELECT pg_advisory_unlock(%s)", (_ADVISORY_LOCK_KEY,))
                conn.commit()
            except Exception:
                pass
        conn.close()

    _log(f"done: {applied} applied, {changed} re-applied (changed), "
         f"{skipped} unchanged, {errors} error(s) from {folders}")
