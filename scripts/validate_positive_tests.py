"""
Companion runner — validate SQL Server detection positive tests end-to-end
against EVERY active SQL Server in metrics.servers.

For each server, for each reproducer block in positive_tests_sqlserver.sql it:
  1. runs SETUP  (held open in a SECOND session if the setup opens a transaction),
  2. runs the detection query (pulled live from rootcause.v_rootcauses),
  3. PASS if the detection returns >= 1 row, else FAIL,
  4. runs REVERT (and closes the held session) — always, even on failure.

!!!  DESTRUCTIVE reproducers WEAKEN the server (enable xp_cmdshell, create
     logins, disable audits, ...). metrics.servers may include PRODUCTION.
     SAFE tests run by default; DESTRUCTIVE requires BOTH --include-destructive
     AND --confirm, after you've verified every listed server is disposable.  !!!

Examples:
  python scripts/validate_positive_tests.py --dry-run                       # list servers + tests
  python scripts/validate_positive_tests.py                                 # SAFE tests, all MSSQL servers
  python scripts/validate_positive_tests.py --server TESTSQL --include-destructive --confirm
  python scripts/validate_positive_tests.py --rc SEC-SQL-ACC-010-RC07 --csv v.csv
"""
import argparse
import csv
import os
import re
import sys

import psycopg2

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from utils.config_dotenv import get_connection_string  # noqa: E402

LOGIN_TIMEOUT = 15
QUERY_TIMEOUT = int(os.environ.get("DBEXPERT_QUERY_TIMEOUT", "60"))
FETCH_CAP = 5000
_BASE = os.path.dirname(sys.executable) if getattr(sys, "frozen", False) \
    else os.path.dirname(os.path.abspath(__file__))
DEFAULT_FILE = os.path.join(_BASE, "positive_tests_sqlserver.sql")


# ----------------------------------------------------------------------------- parsing
def parse_blocks(path):
    txt = open(path, encoding="utf-8").read()
    blocks = []
    for m in re.finditer(r"/\* ===== (\S+) \[(\w+)\] ===== \*/(.*?)(?=/\* ===== |\Z)", txt, re.S):
        rc, safety, body = m.group(1), m.group(2), m.group(3)
        setup = revert = ""
        sm = re.search(r"--\s*SETUP:(.*?)(?=--\s*REVERT:|\Z)", body, re.S)
        rm = re.search(r"--\s*REVERT:(.*)", body, re.S)
        if sm:
            setup = sm.group(1).strip()
        if rm:
            revert = rm.group(1).strip()
        blocks.append({"rc": rc, "safety": safety.upper(), "setup": setup, "revert": revert})
    return blocks


def split_batches(sql):
    """Split T-SQL on lines that are just GO; drop empty / comment-only batches."""
    out = []
    for part in re.split(r"(?im)^[ \t]*GO[ \t]*$", sql or ""):
        p = part.strip()
        if not p:
            continue
        if all((not ln.strip()) or ln.strip().startswith("--") for ln in p.splitlines()):
            continue
        out.append(p)
    return out


def run_batches(conn, sql):
    for batch in split_batches(sql):
        cur = conn.cursor()
        try:
            cur.execute(batch)
            while cur.nextset():
                pass
        finally:
            cur.close()


# ----------------------------------------------------------------------------- pg / mssql
def load_detections(pg):
    cur = pg.cursor()
    cur.execute("""
        SELECT root_cause_id, max(content->>'sql')
        FROM rootcause.v_rootcauses
        WHERE vendor_name = 'sqlserver' AND content->>'sql' IS NOT NULL
        GROUP BY root_cause_id
    """)
    d = {r[0]: r[1] for r in cur.fetchall()}
    cur.close()
    return d


def load_servers(pg, only_server=None):
    cur = pg.cursor()
    cur.execute("""
        SELECT server, servername, database, username, password, driver, port, auth_type
        FROM metrics.servers
        WHERE lower(db_vendor) IN ('mssql', 'sqlserver') AND is_active = true
        ORDER BY server
    """)
    cols = ['server', 'servername', 'database', 'username', 'password', 'driver', 'port', 'auth_type']
    servers = [dict(zip(cols, r)) for r in cur.fetchall()]
    cur.close()
    if only_server:
        k = only_server.lower()
        servers = [s for s in servers
                   if k in (s['server'] or '').lower() or k in (s['servername'] or '').lower()]
    return servers


def _register_output_converters(conn):
    def _utf16(raw):
        return raw.decode("utf-16le", errors="replace") if isinstance(raw, (bytes, bytearray)) else raw

    def _dto(raw):
        if not isinstance(raw, (bytes, bytearray)):
            return raw
        try:
            import struct
            from datetime import datetime, timezone, timedelta
            t = struct.unpack("<6hI2h", raw)
            return datetime(t[0], t[1], t[2], t[3], t[4], t[5], t[6] // 1000,
                            timezone(timedelta(hours=t[7], minutes=t[8])))
        except Exception:
            return raw
    for st, fn in ((-16, _utf16), (-150, _utf16), (-155, _dto)):
        try:
            conn.add_output_converter(st, fn)
        except Exception:
            pass


def pick_driver(pyodbc, want):
    av = list(pyodbc.drivers())
    if want and want in av:
        return want
    for d in ("ODBC Driver 18 for SQL Server", "ODBC Driver 17 for SQL Server",
              "SQL Server Native Client 11.0", "SQL Server"):
        if d in av:
            return d
    return av[0] if av else "ODBC Driver 17 for SQL Server"


def connect_server(pyodbc, s, autocommit=True, database=None):
    driver = pick_driver(pyodbc, s.get('driver'))
    host = s['server'] or s['servername']
    if s.get('port'):
        host = f"{host},{s['port']}"
    db = database or s['database'] or 'master'
    common = f"Encrypt=yes;TrustServerCertificate=yes;Connection Timeout={LOGIN_TIMEOUT};"
    if (s.get('auth_type') or '').lower() == 'win':
        cs = f"DRIVER={{{driver}}};SERVER={host};DATABASE={db};Trusted_Connection=yes;{common}"
    else:
        cs = f"DRIVER={{{driver}}};SERVER={host};DATABASE={db};UID={s['username']};PWD={s['password']};{common}"
    conn = pyodbc.connect(cs, timeout=LOGIN_TIMEOUT, autocommit=autocommit)
    conn.timeout = QUERY_TIMEOUT
    _register_output_converters(conn)
    return conn


# ----------------------------------------------------------------------------- one server
def run_block(pyodbc, s, main_conn, b, detection, database):
    """Returns (status, rows_n, error). SETUP -> detection -> assert -> REVERT."""
    held = bool(re.search(r"(?i)\bBEGIN\s+TRAN", b["setup"]))
    held_conn = None
    status, rows_n, err = "ERROR", "", ""
    try:
        if held:
            held_conn = connect_server(pyodbc, s, autocommit=False, database=database)
            run_batches(held_conn, b["setup"])
        else:
            run_batches(main_conn, b["setup"])
        cur = main_conn.cursor()
        cur.execute(detection)
        rows = cur.fetchmany(FETCH_CAP) if cur.description else []
        cur.close()
        rows_n = len(rows)
        status = "PASS" if rows_n >= 1 else "FAIL"
    except Exception as e:
        err = str(e).splitlines()[-1][:240]
    finally:
        if held_conn is not None:
            try:
                held_conn.rollback()
            except Exception:
                pass
            try:
                held_conn.close()
            except Exception:
                pass
        if b["revert"]:
            try:
                run_batches(main_conn, b["revert"])
            except Exception as e:
                err = (err + f" | REVERT FAILED: {str(e).splitlines()[-1][:120]}").strip(" |")
    return status, rows_n, err


# ----------------------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser(description="Validate SQL Server positive tests against every metrics.servers MSSQL server.")
    ap.add_argument("--server", help="only metrics.servers entries whose name contains this string")
    ap.add_argument("--database", help="override DB (default: each server's configured database)")
    ap.add_argument("--file", default=DEFAULT_FILE)
    ap.add_argument("--rc", help="run a single root_cause_id")
    ap.add_argument("--limit", type=int)
    ap.add_argument("--include-destructive", action="store_true",
                    help="also run DESTRUCTIVE (server-weakening) tests. Requires --confirm.")
    ap.add_argument("--confirm", action="store_true",
                    help="acknowledge that EVERY listed server is disposable (required for --include-destructive)")
    ap.add_argument("--log", default="validate_positive_tests.log")
    ap.add_argument("--csv")
    ap.add_argument("--dry-run", action="store_true", help="list servers + tests, do NOT connect to any server")
    a = ap.parse_args()

    blocks = parse_blocks(a.file)
    if a.rc:
        blocks = [b for b in blocks if b["rc"] == a.rc]
    if not a.include_destructive:
        blocks = [b for b in blocks if b["safety"] == "SAFE"]
    if a.limit:
        blocks = blocks[:a.limit]

    pg = psycopg2.connect(get_connection_string())
    det = load_detections(pg)
    servers = load_servers(pg, a.server)
    pg.close()

    n_dest = sum(1 for b in blocks if b["safety"] == "DESTRUCTIVE")
    mode = "SAFE only" if not a.include_destructive else f"incl. {n_dest} DESTRUCTIVE"
    print(f"metrics.servers (MSSQL active): {len(servers)} | reproducers: {len(blocks)} ({mode}) | detections: {len(det)}\n")
    for s in servers:
        print(f"  - {s['server'] or s['servername']} (db={s['database']}, auth={s['auth_type']})")
    print()

    if a.dry_run:
        for b in blocks[:30]:
            held = bool(re.search(r"(?i)\bBEGIN\s+TRAN", b["setup"]))
            print(f"  {b['rc']:<30} [{b['safety']:<11}] {'held-session' if held else 'single-conn'}"
                  f"{'  (no detection)' if b['rc'] not in det else ''}")
        if len(blocks) > 30:
            print(f"  ... +{len(blocks) - 30} more")
        return

    if not servers:
        print("No active MSSQL servers in metrics.servers (or none matched --server)."); return

    # ---- destructive safety gate ----
    if a.include_destructive and not a.confirm:
        print("REFUSING: --include-destructive runs SERVER-WEAKENING scripts (enable xp_cmdshell, create logins,")
        print("disable audits, grant rights) against EVERY server listed above — metrics.servers may include PRODUCTION.")
        print("If, and only if, every listed server is a disposable/throwaway instance, re-run with --confirm.")
        sys.exit(3)
    if a.include_destructive:
        print("*** DESTRUCTIVE mode CONFIRMED — weakening every server above, then reverting. ***\n")

    import pyodbc
    logf = open(a.log, "w", encoding="utf-8")
    logf.write(f"# positive-test validation | servers={len(servers)} reproducers={len(blocks)} mode={mode}\n\n")
    results = []
    overall = {"PASS": 0, "FAIL": 0, "ERROR": 0, "SKIP": 0}

    for s in servers:
        label = s['server'] or s['servername']
        print(f"=== {label} ===")
        logf.write(f"\n===== {label} =====\n")
        try:
            main_conn = connect_server(pyodbc, s, autocommit=True, database=a.database)
        except Exception as e:
            msg = str(e).splitlines()[0]
            print(f"  CONNECT FAILED: {msg}\n")
            logf.write(f"  CONNECT FAILED: {msg}\n")
            for b in blocks:
                results.append({"server": label, "rc": b["rc"], "safety": b["safety"],
                                "status": "ERROR", "rows": "", "error": "connect failed"})
                overall["ERROR"] += 1
            continue

        tally = {"PASS": 0, "FAIL": 0, "ERROR": 0, "SKIP": 0}
        for b in blocks:
            detection = det.get(b["rc"])
            if not detection:
                status, rows_n, err = "SKIP", "", "no detection SQL"
            else:
                status, rows_n, err = run_block(pyodbc, s, main_conn, b, detection, a.database)
            tally[status] += 1
            overall[status] += 1
            mark = {"PASS": "[PASS]", "FAIL": "[FAIL]", "ERROR": "[ERR ]", "SKIP": "[skip]"}[status]
            line = f"  {mark} {b['rc']:<30} [{b['safety']:<11}] rows={rows_n}{('  ' + err) if err else ''}"
            print(line)
            logf.write(line + "\n")
            results.append({"server": label, "rc": b["rc"], "safety": b["safety"],
                            "status": status, "rows": rows_n, "error": err})
        main_conn.close()
        print(f"  --- {label}: {tally['PASS']} PASS, {tally['FAIL']} FAIL, {tally['ERROR']} ERROR, {tally['SKIP']} SKIP ---\n")

    logf.write(f"\n# overall: {overall}\n")
    logf.close()
    print(f"OVERALL: {overall['PASS']} PASS, {overall['FAIL']} FAIL, {overall['ERROR']} ERROR, {overall['SKIP']} SKIP")
    print(f"Log -> {a.log}")
    if a.csv:
        with open(a.csv, "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=["server", "rc", "safety", "status", "rows", "error"])
            w.writeheader()
            w.writerows(results)
        print(f"CSV -> {a.csv}")


if __name__ == "__main__":
    main()
