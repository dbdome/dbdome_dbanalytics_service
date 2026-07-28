"""
SQL Server root-cause detection test harness (sqlcmd-style, pyodbc).

Reads .env (the Postgres config DB), loads the SQL Server targets from
metrics.servers, loads every detection query for vendor 'sqlserver' from
rootcause.v_rootcauses (content->>'sql'), connects to each server and runs each
detection, reporting pass / error / row-count per (server, root_cause).

Examples:
  python scripts/test_rootcauses_mssql.py
        # all SEC sqlserver detections against every active MSSQL server
  python scripts/test_rootcauses_mssql.py --rc SEC-SQL-PRI-001-RC14 --samples
        # one root cause, print a sample returned row (e.g. the sensitive column)
  python scripts/test_rootcauses_mssql.py --domain SEC --limit 25
  python scripts/test_rootcauses_mssql.py --server PRODSQL01 --csv results.csv
  python scripts/test_rootcauses_mssql.py --dry-run
        # list what would run (servers + detections) without connecting
"""
import argparse
import csv
import json
import os
import sys

import psycopg2

# Allow running from scripts/ — make the repo root importable for utils.*
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from utils.config_dotenv import get_connection_string  # noqa: E402

QUERY_TIMEOUT = int(os.environ.get("DBEXPERT_QUERY_TIMEOUT", "30"))   # seconds per detection
LOGIN_TIMEOUT = 15
FETCH_CAP = 5000   # don't pull unbounded rows for a test


def _substitute_parameters(sql, parameters):
    """Replace :param_name placeholders with literal values — mirrors the
    collector's _substitute_parameters so parameterized detections run.
    Accepts a dict or a JSON string (v_rootcauses.parameters)."""
    if isinstance(parameters, str):
        try:
            parameters = json.loads(parameters)
        except (json.JSONDecodeError, ValueError):
            parameters = None
    if not parameters or not isinstance(parameters, dict):
        return sql
    for key, value in parameters.items():
        if isinstance(value, str):
            sql = sql.replace(f":{key}", f"'{value}'")
        else:
            sql = sql.replace(f":{key}", str(value))
    return sql


def _write_log(logf, server, root_cause_id, root_cause_name, query, outcome):
    """Append one record: server, root_cause_id, root_cause_name, the query, result."""
    if logf is None:
        return
    logf.write("=" * 100 + "\n")
    logf.write(f"server         : {server}\n")
    logf.write(f"root_cause_id  : {root_cause_id}\n")
    if root_cause_name:
        logf.write(f"root_cause     : {root_cause_name}\n")
    logf.write(f"result         : {outcome}\n")
    logf.write(f"query          :\n{query}\n\n")
    logf.flush()


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


def load_rootcauses(pg, domain='SEC', rc=None, limit=None):
    cur = pg.cursor()
    cur.execute("""
        SELECT root_cause_id,
               max(detection_name)     AS detection_name,
               max(root_cause_name)    AS root_cause_name,
               max(content->>'sql')    AS sql,
               max(parameters::text)   AS parameters
        FROM rootcause.v_rootcauses
        WHERE vendor_name = 'sqlserver'
          AND content->>'sql' IS NOT NULL
          AND (%(dom)s IS NULL OR domain_code = %(dom)s)
          AND (%(rc)s  IS NULL OR root_cause_id = %(rc)s)
        GROUP BY root_cause_id
        ORDER BY root_cause_id
    """, {'dom': domain, 'rc': rc})
    rcs = [{'root_cause_id': r[0], 'detection_name': r[1], 'root_cause_name': r[2],
            'sql': r[3], 'parameters': r[4]} for r in cur.fetchall()]
    cur.close()
    return rcs[:limit] if limit else rcs


# Metadata keys (case-insensitive) that hold a captured SQL statement.
_QUERY_KEYS = ('query_text', 'query', 'sql_text', 'sql', 'statement')


def load_alert_queries(pg, only_server=None, rc=None, limit=None):
    """Pull captured SQL out of alerts.alert_log.metadata.

    Each alert's metadata is a (possibly double-encoded) JSON list of result
    rows; rows that carry a query_text/query/sql_text value are the SQL the
    flagged session was running. Returns distinct {root_cause_id, server, query}.
    """
    cur = pg.cursor()
    cur.execute("""
        SELECT root_cause_id, server, metadata
        FROM alerts.alert_log
        WHERE metadata IS NOT NULL
          AND root_cause_id IS NOT NULL
          AND root_cause_id NOT IN ('NaN', 'nan', '')
          AND (%(srv)s IS NULL OR server ILIKE '%%' || %(srv)s || '%%')
          AND (%(rc)s  IS NULL OR root_cause_id = %(rc)s)
        ORDER BY entry_date DESC
    """, {'srv': only_server, 'rc': rc})
    seen = set()
    out = []
    for rc_id, srv, md in cur.fetchall():
        if isinstance(md, str):
            try:
                md = json.loads(md)
            except (ValueError, TypeError):
                continue
        elements = md if isinstance(md, list) else [md]
        for el in elements:
            if not isinstance(el, dict):
                continue
            q = next((v.strip() for k, v in el.items()
                      if k.lower() in _QUERY_KEYS and isinstance(v, str) and v.strip()), None)
            if not q:
                continue
            key = (srv, q)
            if key in seen:
                continue
            seen.add(key)
            out.append({'root_cause_id': rc_id, 'server': srv, 'query': q})
    cur.close()
    return out[:limit] if limit else out


def run_alerts_mode(a, servers, items):
    """Run each query captured from alerts.alert_log against its server.

    Captured SQL can be DML, so every statement runs inside a transaction that
    is ALWAYS rolled back — nothing is persisted; this only tests executability.
    """
    print(f"Source: alerts.alert_log | captured queries: {len(items)} "
          f"(distinct server+query{', rc=' + a.rc if a.rc else ''})\n")
    if a.dry_run:
        for it in items:
            print(f"  {it['server']:<18} {it['root_cause_id']:<28} "
                  f"{it['query'][:90].replace(chr(10), ' ')}")
        return

    try:
        import pyodbc
    except ImportError:
        print("pyodbc not installed — pip install pyodbc"); sys.exit(2)

    creds = {(s['server'] or s['servername']): s for s in servers}
    logf = open(a.log, 'w', encoding='utf-8')
    logf.write("# DBDOME captured-query test — source=alerts.alert_log (each query rolled back)\n\n")

    from collections import defaultdict
    by_server = defaultdict(list)
    for it in items:
        by_server[it['server']].append(it)

    for srv, qs in by_server.items():
        print(f"=== {srv} ({len(qs)} queries) ===")
        s = creds.get(srv) or next((v for k, v in creds.items()
                                    if srv and (srv in k or k in srv)), None)
        if not s:
            print(f"  no matching credentials in metrics.servers for '{srv}' — skipping")
            for it in qs:
                _write_log(logf, srv, it['root_cause_id'], "", it['query'], "SKIPPED: no credentials")
            print()
            continue
        try:
            conn = connect_mssql(pyodbc, s)
            conn.autocommit = False
        except Exception as e:
            msg = str(e).splitlines()[0]
            print(f"  CONNECT FAILED: {msg}")
            for it in qs:
                _write_log(logf, srv, it['root_cause_id'], "", it['query'], f"CONNECT FAILED: {msg}")
            print()
            continue

        ok = err = 0
        for it in qs:
            print(f"  root_cause_id: {it['root_cause_id']}")
            print(f"  query        : {it['query'][:200].replace(chr(10), ' ')}")
            cur = conn.cursor()
            try:
                cur.execute(it['query'])
                n = len(cur.fetchmany(FETCH_CAP)) if cur.description else 0
                ok += 1
                outcome = f"OK rows={n}"
            except Exception as e:
                err += 1
                outcome = "ERR: " + str(e).splitlines()[-1][:240]
            finally:
                try:
                    conn.rollback()   # never persist captured DML
                except Exception:
                    pass
                cur.close()
            print(f"    -> {outcome}\n")
            _write_log(logf, srv, it['root_cause_id'], "", it['query'], outcome)
        conn.close()
        print(f"  --- {srv}: {ok} ok, {err} error ---\n")

    logf.close()
    print(f"Log -> {a.log}")


def pick_driver(pyodbc, want):
    available = list(pyodbc.drivers())
    if want and want in available:
        return want
    for d in ("ODBC Driver 18 for SQL Server", "ODBC Driver 17 for SQL Server",
              "SQL Server Native Client 11.0", "SQL Server"):
        if d in available:
            return d
    return available[0] if available else "ODBC Driver 17 for SQL Server"


def _register_output_converters(conn):
    """Mirror the collector's pyodbc output converters so columns pyodbc can't
    auto-decode don't raise 'ODBC SQL type ... is not yet supported':
      -16  NVARCHAR(MAX)/XML  -> UTF-16LE
      -150 sql_variant        -> UTF-16LE
      -155 datetimeoffset     -> aware datetime
    """
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

    for sqltype, fn in ((-16, _utf16), (-150, _utf16), (-155, _dto)):
        try:
            conn.add_output_converter(sqltype, fn)
        except Exception:
            pass


def connect_mssql(pyodbc, s):
    driver = pick_driver(pyodbc, s.get('driver'))
    host = s['server'] or s['servername']
    if s.get('port'):
        host = f"{host},{s['port']}"
    db = s['database'] or 'master'
    common = "Encrypt=yes;TrustServerCertificate=yes;Connection Timeout=%d;" % LOGIN_TIMEOUT
    if (s.get('auth_type') or '').lower() == 'win':
        cs = f"DRIVER={{{driver}}};SERVER={host};DATABASE={db};Trusted_Connection=yes;{common}"
    else:
        cs = f"DRIVER={{{driver}}};SERVER={host};DATABASE={db};UID={s['username']};PWD={s['password']};{common}"
    conn = pyodbc.connect(cs, timeout=LOGIN_TIMEOUT)
    conn.timeout = QUERY_TIMEOUT   # per-query timeout
    _register_output_converters(conn)
    return conn


def run():
    ap = argparse.ArgumentParser(description="Run SQL Server root-cause detections against monitored servers.")
    ap.add_argument("--source", choices=['rootcause', 'alerts'], default='rootcause',
                    help="rootcause = detection SQL from v_rootcauses (default); "
                         "alerts = captured SQL pulled from alerts.alert_log metadata")
    ap.add_argument("--rc", help="single root_cause_id, e.g. SEC-SQL-PRI-001-RC14")
    ap.add_argument("--domain", default="SEC", help="domain_code filter (default SEC; 'ALL' for every domain)")
    ap.add_argument("--server", help="only servers whose name contains this string")
    ap.add_argument("--limit", type=int, help="cap number of detections")
    ap.add_argument("--samples", action="store_true", help="print one sample returned row per detection")
    ap.add_argument("--csv", help="write per-(server,rc) results to this CSV")
    ap.add_argument("--log", default="test_rootcauses_mssql.log",
                    help="log file with server, root_cause_name, and the query run "
                         "(default: test_rootcauses_mssql.log)")
    ap.add_argument("--dry-run", action="store_true", help="list what would run, do not connect to any server")
    a = ap.parse_args()

    pg = psycopg2.connect(get_connection_string())
    servers = load_servers(pg, a.server)
    if a.source == 'alerts':
        items = load_alert_queries(pg, a.server, a.rc, a.limit)
        pg.close()
        run_alerts_mode(a, servers, items)
        return
    domain = None if a.domain.lower() == 'all' else a.domain
    rcs = load_rootcauses(pg, domain, a.rc, a.limit)
    pg.close()

    print(f"Servers: {len(servers)} | Detections: {len(rcs)} "
          f"(vendor=sqlserver, domain={a.domain}{', rc=' + a.rc if a.rc else ''})\n")
    if a.dry_run:
        print("Servers:")
        for s in servers:
            print(f"  - {s['server'] or s['servername']} (db={s['database']}, auth={s['auth_type']})")
        print("\nDetections:")
        for rc in rcs:
            print(f"  - {rc['root_cause_id']:<30} {rc['detection_name']}")
        return

    try:
        import pyodbc
    except ImportError:
        print("pyodbc not installed — pip install pyodbc"); sys.exit(2)

    logf = open(a.log, 'w', encoding='utf-8')
    logf.write("# DBDOME SQL Server root-cause detection log\n")
    logf.write(f"# vendor=sqlserver domain={a.domain} servers={len(servers)} detections={len(rcs)}\n\n")

    results = []
    for s in servers:
        label = s['server'] or s['servername']
        print(f"=== {label} ===")
        try:
            conn = connect_mssql(pyodbc, s)
        except Exception as e:
            msg = str(e).splitlines()[0]
            print(f"  CONNECT FAILED: {msg}")
            _write_log(logf, label, "", "(connection)", "", f"CONNECT FAILED: {msg}")
            for rc in rcs:
                results.append({'server': label, 'root_cause_id': rc['root_cause_id'],
                                'status': 'CONN_FAIL', 'rows': '', 'error': msg})
            print()
            continue

        ok = err = 0
        for rc in rcs:
            sql = _substitute_parameters(rc['sql'], rc.get('parameters'))
            rc_name = rc.get('root_cause_name') or rc['root_cause_id']
            cur = conn.cursor()
            try:
                cur.execute(sql)
                rows = cur.fetchmany(FETCH_CAP) if cur.description else []
                n = len(rows)
                ok += 1
                sample = ""
                if a.samples and n:
                    sample = "  e.g. " + str(tuple(rows[0]))[:160]
                capped = "+" if n == FETCH_CAP else ""
                print(f"  [OK]  {rc['root_cause_id']:<30} rows={n}{capped}{sample}")
                results.append({'server': label, 'root_cause_id': rc['root_cause_id'],
                                'status': 'OK', 'rows': n, 'error': ''})
                outcome = f"OK rows={n}{capped}"
            except Exception as e:
                err += 1
                msg = str(e).splitlines()[-1][:240]
                print(f"  [ERR] {rc['root_cause_id']:<30} {msg}")
                results.append({'server': label, 'root_cause_id': rc['root_cause_id'],
                                'status': 'ERR', 'rows': '', 'error': msg})
                outcome = f"ERR: {msg}"
            finally:
                cur.close()
            _write_log(logf, label, rc['root_cause_id'], rc_name, sql, outcome)
        conn.close()
        print(f"  --- {label}: {ok} ok, {err} error ---\n")

    logf.close()
    print(f"Log -> {a.log}")

    if a.csv:
        with open(a.csv, 'w', newline='', encoding='utf-8') as f:
            w = csv.DictWriter(f, fieldnames=['server', 'root_cause_id', 'status', 'rows', 'error'])
            w.writeheader()
            w.writerows(results)
        print(f"CSV -> {a.csv}")


if __name__ == "__main__":
    run()
