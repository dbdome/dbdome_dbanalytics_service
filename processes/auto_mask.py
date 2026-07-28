"""
auto_mask: when a config.webook_alerts rule has auto_mask = true (AND is_active,
AND risk_level = critical), automatically apply SQL Server Dynamic Data Masking
to the sensitive columns surfaced by the PII detection query results
(monitoring.v_sec_sql_pri_001_rc12) on each matching server.

Two gates (per-rule auto_mask=true at critical risk, AND the global
config.global_params 'masking_dry_run' switch). While dry-run is on, every
candidate is logged to metrics.masking_log as 'auto-dry-run' and nothing is
changed. Already-masked columns are skipped (idempotent). SQL Server only.
"""
import os
import psycopg2

from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log
from utils.secrets_crypto import decrypt_secret


def _truthy(v):
    return str(v).strip().lower() in ("true", "t", "1", "yes", "on")


def _mlog(cur, server, db, schema, table, column, fn, action, detail):
    try:
        cur.execute(
            "INSERT INTO metrics.masking_log (server, db_name, schema_name, table_name, column_name, mask_function, action, detail) "
            "VALUES (%s,%s,%s,%s,%s,%s,%s,%s)",
            (server, db, schema, table, column, fn, action, (detail or "")[:500]))
    except Exception:
        pass


def _mssql_connect(server, port, database, username, password):
    import pyodbc
    drivers = pyodbc.drivers()
    drv = next((d for d in ("ODBC Driver 18 for SQL Server",
                            "ODBC Driver 17 for SQL Server", "SQL Server") if d in drivers), None)
    if not drv:
        raise RuntimeError("no suitable ODBC driver")
    server_str = f"{server},{port}" if port else server
    enc = os.environ.get("DBEXPERT_MSSQL_ENCRYPT", "yes")
    cs = (f"DRIVER={{{drv}}};SERVER={server_str};DATABASE={database or 'master'};"
          f"UID={username};PWD={password};Encrypt={enc};TrustServerCertificate=yes;Connection Timeout=15;")
    c = pyodbc.connect(cs, timeout=15)
    c.autocommit = True
    return c


def _apply_mask(tcur, schema, table, column, fn):
    """Mask one column if not already masked. Returns (action, detail)."""
    tcur.execute(
        "SELECT mc.is_masked FROM sys.masked_columns mc "
        "JOIN sys.columns c ON c.object_id=mc.object_id AND c.column_id=mc.column_id "
        "WHERE mc.object_id=OBJECT_ID(?) AND c.name=?", (f"{schema}.{table}", column))
    row = tcur.fetchone()
    if row and row[0]:
        return "already-masked", "column already masked"
    tcur.execute(
        "DECLARE @s sysname=?, @t sysname=?, @c sysname=?, @fn nvarchar(100)=?;"
        "DECLARE @sql nvarchar(max)=N'ALTER TABLE '+QUOTENAME(@s)+N'.'+QUOTENAME(@t)+"
        "N' ALTER COLUMN '+QUOTENAME(@c)+N' ADD MASKED WITH (FUNCTION = '+QUOTENAME(@fn,'''')+N')';"
        "EXEC sys.sp_executesql @sql;", (schema, table, column, fn))
    return "auto-masked", f"ADD MASKED WITH (FUNCTION = '{fn}')"


def run_auto_mask():
    conn = None
    try:
        conn = psycopg2.connect(get_connection_string())
        conn.autocommit = True
        cur = conn.cursor()

        # gate 1: any active critical rule with auto_mask=true?
        cur.execute("SELECT count(*) FROM config.webook_alerts "
                    "WHERE auto_mask = true AND is_active = true "
                    "AND lower(trim(risk_level)) = 'critical'")
        if (cur.fetchone() or [0])[0] == 0:
            return

        # gate 2: global dry-run switch
        cur.execute("SELECT value FROM config.global_params WHERE key='masking_dry_run' "
                    "ORDER BY row_id DESC LIMIT 1")
        r = cur.fetchone()
        dry = True if (not r or r[0] is None) else _truthy(r[0])

        # candidate columns = the PII detection query results
        cur.execute("SELECT DISTINCT server, db_name, schema_name, table_name, column_name, pii_category "
                    "FROM monitoring.v_sec_sql_pri_001_rc12 "
                    "WHERE db_name IS NOT NULL AND schema_name IS NOT NULL "
                    "AND table_name IS NOT NULL AND column_name IS NOT NULL "
                    "AND lower(schema_name) <> 'unencrypted'")
        cols = cur.fetchall()
        if not cols:
            return

        # dedupe: don't re-log a candidate already logged in the last 24h (keeps
        # masking_log from growing every cycle while dry-run is on).
        cur.execute("SELECT DISTINCT server, db_name, schema_name, table_name, column_name "
                    "FROM metrics.masking_log "
                    "WHERE action IN ('auto-dry-run','auto-masked') AND entry_date > now() - interval '24 hours'")
        seen = set(tuple(r) for r in cur.fetchall())

        # group by server so we connect once per host
        by_server = {}
        for srv, db, sch, tbl, col, pii in cols:
            by_server.setdefault(srv, []).append((db, sch, tbl, col, pii))

        for srv, items in by_server.items():
            cur.execute("SELECT db_vendor, port, username, password FROM metrics.servers "
                        "WHERE server=%s AND is_active=true AND lower(db_vendor) IN ('mssql','sqlserver') "
                        "ORDER BY row_id LIMIT 1", (srv,))
            srow = cur.fetchone()
            if not srow:
                _mlog(cur, srv, None, None, None, None, None, "skipped", "no active MSSQL instance for this server")
                continue
            vendor, port, username, password = srow
            password = decrypt_secret(password)   # stored encrypted; idempotent on plaintext

            if dry:
                for db, sch, tbl, col, pii in items:
                    if (srv, db, sch, tbl, col) in seen:
                        continue
                    fn = "email()" if "email" in (pii or "").lower() else "default()"
                    _mlog(cur, srv, db, sch, tbl, col, fn, "auto-dry-run",
                          f"would auto-mask [{sch}].[{tbl}].[{col}] with {fn}")
                continue

            # connect once per database on the server (DDM is per-db)
            conns = {}
            try:
                for db, sch, tbl, col, pii in items:
                    fn = "email()" if "email" in (pii or "").lower() else "default()"
                    try:
                        if db not in conns:
                            conns[db] = _mssql_connect(srv, port, db, username, password)
                        tcur = conns[db].cursor()
                        action, detail = _apply_mask(tcur, sch, tbl, col, fn)
                        if action == "already-masked":
                            continue  # silent: don't re-log every cycle
                        _mlog(cur, srv, db, sch, tbl, col, fn, action, detail)
                        if action == "auto-masked":
                            db_write_log(f"auto_mask: masked {srv}/{db}/{sch}.{tbl}.{col}", 0, "run_auto_mask", srv)
                    except Exception as e:
                        _mlog(cur, srv, db, sch, tbl, col, fn, "error", str(e)[:300])
            finally:
                for c in conns.values():
                    try: c.close()
                    except Exception: pass
    except Exception as e:
        db_write_log(f"auto_mask failed: {e}", 0, "run_auto_mask", "")
    finally:
        if conn is not None:
            try: conn.close()
            except Exception: pass
