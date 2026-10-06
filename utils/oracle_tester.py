"""Oracle root-cause query tester -- core used by the DBDOME web UI (/tester).

This is the same job scripts/oracle_rootcause_tester.py does from the command
line, packaged so http_server.py can run it from a web page and hand the user a
PDF:

  * the queries come from ``oracle_rootcause_queries.json`` which lives NEXT TO
    THE EXECUTABLE (the appliance ``bin`` directory) -- see resolve_queries_file;
  * the Oracle credentials are supplied by the user on the page, so a test can be
    run with a purpose-made account instead of the stored monitoring user;
  * every query result is persisted to monitoring.oracle_verification_results
    (same table the CLI tester writes) and rendered into a PDF report.

The condition evaluation (``expected.condition`` -> matched) mirrors the
collector's _build_comparison so "detected" here means the same thing it means
in production.
"""
import json
import os
import re
import sys
import time
import uuid
from datetime import datetime

import psycopg2

from utils.config_dotenv import get_connection_string
from utils.oracle_client import oracle_connect

try:
    from utils.log4dbexpert import db_write_log as _db_log
except Exception:                                    # pragma: no cover
    def _db_log(*_a, **_k):
        return None


# Next to the exe when frozen (ProgramData\DBDOME\bin), else the repo root.
APP_DIR = (os.path.dirname(sys.executable) if getattr(sys, "frozen", False)
           else os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LOGO_PATH = os.path.join(APP_DIR, "icons", "LOGO.png")
REPORT_DIR = os.path.join(APP_DIR, "reports", "tester")
RESULTS_TABLE = "monitoring.oracle_verification_results"

# oracle_rootcause_queries.json is the file the user drops in bin/; the older
# oracle_verification_queries.json (bundled in the build) is the fallback.
QUERY_FILENAMES = ("oracle_rootcause_queries.json", "oracle_verification_queries.json")


def resolve_queries_file(explicit=None):
    """Locate the queries JSON. Search order: an explicit path, then
    bin/ (next to the exe), the working directory, and the bundled scripts dir."""
    if explicit:
        return explicit if os.path.isfile(explicit) else None
    base = os.path.dirname(os.path.abspath(__file__))
    dirs = [APP_DIR, os.getcwd(),
            os.path.join(os.path.dirname(base), "scripts"),
            os.path.join(getattr(sys, "_MEIPASS", os.path.dirname(base)), "scripts")]
    for d in dirs:
        for name in QUERY_FILENAMES:
            p = os.path.join(d, name)
            if os.path.isfile(p):
                return p
    return None


def load_queries(path):
    """Return (meta, items). Accepts the --export-queries object or a bare list."""
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    raw = data.get("queries", []) if isinstance(data, dict) else data
    meta = {k: v for k, v in data.items() if k != "queries"} if isinstance(data, dict) else {}
    items = []
    for it in raw:
        rcid = it.get("root_cause_id") or it.get("rootcause")
        q = it.get("query") or it.get("sql")
        if rcid and q:
            items.append({
                "root_cause_id": rcid,
                "root_cause_name": it.get("root_cause_name") or "",
                "query": q,
                "parameters": it.get("parameters"),
                "expected": it.get("expected"),
            })
    return meta, items


# Match a real :name bind only: the colon must not follow a word char or another
# colon, so Oracle format masks ('HH24:MI:SS') and time literals are left alone.
_PARAM_RE = re.compile(r"(?<![\w:]):([A-Za-z_]\w*)")


def _coerce_param(v):
    if isinstance(v, dict):
        v = v.get("default", v.get("value"))
    if v is None:
        return None
    if isinstance(v, bool):
        return "1" if v else "0"
    if isinstance(v, (int, float)):
        return str(v)
    return "'" + str(v).replace("'", "''") + "'"


def substitute_params(sql, params, default="1"):
    """Inline-substitute :name placeholders exactly like the collector does."""
    if isinstance(params, str):
        try:
            params = json.loads(params)
        except Exception:
            params = None
    pmap = params if isinstance(params, dict) else {}

    def repl(m):
        name = m.group(1)
        if name in pmap:
            c = _coerce_param(pmap[name])
            if c is not None:
                return c
        return str(default)

    return _PARAM_RE.sub(repl, sql)


def evaluate(expected, row_count):
    """Apply expected.condition to the row count, mirroring the collector's
    _build_comparison. Returns (matched, condition, severity)."""
    exp = expected
    if isinstance(exp, str):
        try:
            exp = json.loads(exp)
        except Exception:
            exp = {}
    if not isinstance(exp, dict):
        exp = {}
    condition = exp.get("condition", "") or ""
    severity = exp.get("severity")
    matched = None
    if condition:
        m = re.match(r"^\s*row_count\s*([><=!]+)\s*(\d+)\s*$", condition, re.IGNORECASE)
        if m:
            op, val = m.group(1), int(m.group(2))
            if op == ">":              matched = row_count > val
            elif op == ">=":           matched = row_count >= val
            elif op == "<":            matched = row_count < val
            elif op == "<=":           matched = row_count <= val
            elif op in ("=", "=="):    matched = row_count == val
            elif op in ("!=", "<>"):   matched = row_count != val
    else:
        matched = row_count > 0
    return (bool(matched), condition, severity)


def run_query(conn, sql, sample, fetch_cap):
    """Execute one detection query. Returns (status, rows, elapsed_ms, sample, error)."""
    t0 = time.time()
    try:
        cur = conn.cursor()
        cur.execute(sql)
        if cur.description is None:
            cur.close()
            return ("ok", 0, (time.time() - t0) * 1000.0, [], None)
        colnames = [d[0] for d in cur.description]
        rows = cur.fetchmany(fetch_cap)
        sample_rows = [dict(zip(colnames, r)) for r in rows[:sample]]
        cur.close()
        return ("ok", len(rows), (time.time() - t0) * 1000.0, sample_rows, None)
    except Exception as e:
        return ("error", None, (time.time() - t0) * 1000.0, [],
                str(e).splitlines()[0][:300])


# --- results persistence (same table the CLI tester writes) -----------------
def ensure_results_table(pg):
    """Create the results table when missing; fall back to verifying it exists
    when the connected role has no CREATE right (it is shipped by migration 6380)."""
    ddl = """
        CREATE TABLE IF NOT EXISTS monitoring.oracle_verification_results (
            row_id        BIGSERIAL PRIMARY KEY,
            run_id        TEXT,
            entry_date    TIMESTAMPTZ NOT NULL DEFAULT now(),
            server        TEXT,
            root_cause_id TEXT,
            query         TEXT,
            status        TEXT,
            rows          TEXT,
            elapsed_ms    NUMERIC,
            result_sample JSONB,
            error         TEXT
        )
    """
    try:
        with pg.cursor() as cur:
            cur.execute("CREATE SCHEMA IF NOT EXISTS monitoring")
            cur.execute(ddl)
        pg.commit()
    except Exception:
        pg.rollback()
        with pg.cursor() as cur:
            cur.execute("SELECT to_regclass('monitoring.oracle_verification_results')")
            exists = cur.fetchone()[0] is not None
        pg.commit()
        if not exists:
            raise


def insert_result(pg, run_id, server, rcid, query, status, rows, elapsed_ms, sample, error):
    """Insert one result row. Never raises -- persistence must not kill a run."""
    try:
        with pg.cursor() as cur:
            cur.execute(
                """INSERT INTO monitoring.oracle_verification_results
                   (run_id, server, root_cause_id, query, status, rows, elapsed_ms,
                    result_sample, error)
                   VALUES (%s,%s,%s,%s,%s,%s,%s,CAST(%s AS jsonb),%s)""",
                (run_id, server, rcid, query, status,
                 None if rows is None else str(rows), elapsed_ms,
                 None if sample is None else json.dumps(sample, default=str), error))
        pg.commit()
    except Exception as e:
        try:
            pg.rollback()
        except Exception:
            pass
        _db_log(f"tester insert_result failed: {e}", 0, "oracle_tester", server or "")


def list_oracle_servers(include_inactive=False):
    """Registered Oracle targets, for the page's server picker. No passwords are
    returned -- only whether one is stored."""
    sql = """
        SELECT servername, server, port, username, service_name, db_version,
               is_active, (password IS NOT NULL AND password <> '') AS has_password
        FROM metrics.servers
        WHERE lower(db_vendor) = 'oracle'
        {active}
        ORDER BY servername
    """.format(active="" if include_inactive else "AND is_active = true")
    pg = psycopg2.connect(get_connection_string())
    try:
        with pg.cursor() as cur:
            cur.execute(sql)
            cols = [d[0] for d in cur.description]
            return [dict(zip(cols, r)) for r in cur.fetchall()]
    finally:
        pg.close()


def stored_password(servername):
    """Decrypted password of a registered Oracle server, or None."""
    from utils.secrets_crypto import decrypt_secret
    pg = psycopg2.connect(get_connection_string())
    try:
        with pg.cursor() as cur:
            cur.execute("""SELECT password FROM metrics.servers
                            WHERE servername = %s AND lower(db_vendor) = 'oracle'
                            LIMIT 1""", (servername,))
            row = cur.fetchone()
    finally:
        pg.close()
    if not row or not row[0]:
        return None
    pw = decrypt_secret(row[0])
    if isinstance(pw, str) and pw.startswith("enc:v1:"):
        raise RuntimeError("stored password could not be decrypted (DBDOME_SECRET_KEY mismatch)")
    return pw


def test_connection(user, password, host, port, service_name):
    """Connect with the supplied credentials and return the Oracle banner."""
    conn = oracle_connect(user, password, host, port, service_name)
    try:
        cur = conn.cursor()
        cur.execute("SELECT banner FROM v$version WHERE ROWNUM = 1")
        row = cur.fetchone()
        cur.close()
        return (row[0] if row else "connected")
    finally:
        try:
            conn.close()
        except Exception:
            pass


# --- the run ----------------------------------------------------------------
def run_tests(cfg, on_progress=None, should_stop=None):
    """Run the queries file against one Oracle instance and produce a PDF.

    cfg keys: host, port, service_name, username, password, server_label,
              queries_file, rc_filter, limit, sample, fetch_cap, default_param,
              persist (bool).
    on_progress(dict) is called after every query; should_stop() aborts the run
    (the PDF is still written, marked as stopped). Returns the summary dict.
    """
    host = (cfg.get("host") or "").split(":")[0].strip()
    port = cfg.get("port") or 1521
    service_name = (cfg.get("service_name") or "").strip()
    username = (cfg.get("username") or "").strip()
    password = cfg.get("password") or ""
    label = (cfg.get("server_label") or host or "oracle").strip()
    sample = int(cfg.get("sample") or 2)
    fetch_cap = int(cfg.get("fetch_cap") or 5000)
    default_param = str(cfg.get("default_param") or "1")
    persist = bool(cfg.get("persist", True))

    qfile = resolve_queries_file(cfg.get("queries_file"))
    if not qfile:
        raise RuntimeError("oracle_rootcause_queries.json not found in the bin directory")
    qmeta, items = load_queries(qfile)

    available = len(items)
    rc_filter = (cfg.get("rc_filter") or "").strip().lower()
    if rc_filter:
        items = [i for i in items if rc_filter in i["root_cause_id"].lower()
                 or rc_filter in (i["root_cause_name"] or "").lower()]
    matching = len(items)
    limit = cfg.get("limit")
    if limit:
        items = items[:int(limit)]
    if not items:
        raise RuntimeError("no queries selected (check the filter)")

    run_id = datetime.now().strftime("%Y%m%d%H%M%S") + "-" + uuid.uuid4().hex[:6]
    started = datetime.now()

    conn = oracle_connect(username, password, host, port, service_name)
    banner = ""
    try:
        cur = conn.cursor()
        cur.execute("SELECT banner FROM v$version WHERE ROWNUM = 1")
        r = cur.fetchone()
        banner = r[0] if r else ""
        cur.close()
    except Exception:
        pass

    pg = None
    if persist:
        try:
            pg = psycopg2.connect(get_connection_string())
            ensure_results_table(pg)
        except Exception as e:
            _db_log(f"tester: results persistence off ({e})", 0, "oracle_tester", label)
            pg = None

    results = []
    n_ok = n_err = n_detect = 0
    stopped = False
    try:
        for idx, it in enumerate(items, 1):
            if should_stop and should_stop():
                stopped = True
                break
            sql = substitute_params(it["query"], it.get("parameters"), default_param)
            status, rows, ms, srows, error = run_query(conn, sql, sample, fetch_cap)
            matched, condition, severity = (False, "", None)
            if status == "ok":
                n_ok += 1
                matched, condition, severity = evaluate(it.get("expected"), rows or 0)
                if matched:
                    n_detect += 1
            else:
                n_err += 1
                _, condition, severity = evaluate(it.get("expected"), 0)
            rec = {
                "root_cause_id": it["root_cause_id"],
                "root_cause_name": it["root_cause_name"],
                "status": "failed" if status == "error" else "success",
                "rows": rows,
                "elapsed_ms": round(ms, 1),
                "matched": matched,
                "condition": condition,
                "severity": severity,
                "error": error,
                "sample": srows,
                "query": sql,
            }
            results.append(rec)
            if pg:
                insert_result(pg, run_id, label, it["root_cause_id"], sql,
                              rec["status"], rows, rec["elapsed_ms"], srows, error)
            if on_progress:
                on_progress({"done": idx, "total": len(items), "success": n_ok,
                             "failed": n_err, "detections": n_detect, "last": rec})
    finally:
        try:
            conn.close()
        except Exception:
            pass
        if pg:
            try:
                pg.close()
            except Exception:
                pass

    finished = datetime.now()
    summary = {
        "run_id": run_id,
        "server": label,
        "host": host,
        "port": port,
        "service_name": service_name,
        "username": username,
        "banner": banner,
        "queries_file": qfile,
        "queries_file_meta": qmeta,
        "rc_filter": cfg.get("rc_filter") or "",
        "queries_available": available,
        "queries_matching": matching,
        "limit": int(limit) if limit else None,
        "total": len(results),
        "selected": len(items),
        "success": n_ok,
        "failed": n_err,
        "detections": n_detect,
        "persisted": bool(pg is not None),
        "started": started,
        "finished": finished,
        "duration_s": round((finished - started).total_seconds(), 1),
        "stopped": stopped,
    }
    summary["pdf_path"] = build_report_pdf(summary, results)
    summary["pdf_filename"] = os.path.basename(summary["pdf_path"])
    _db_log(f"tester run {run_id} on {label}: {n_ok} ok, {n_err} failed, "
            f"{n_detect} detections -> {summary['pdf_filename']}",
            0, "oracle_tester", label)
    return summary


# --- PDF --------------------------------------------------------------------
def _p(text, style, cap=None):
    from reportlab.platypus import Paragraph
    s = "" if text is None else str(text)
    if cap and len(s) > cap:
        s = s[:cap - 3] + "..."
    s = s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    return Paragraph(s, style)


def _scope_text(summary):
    """Spell out how many of the file's queries actually ran, so a filtered or
    capped run is never mistaken for a full sweep of the catalogue."""
    avail = summary.get("queries_available")
    ran = summary.get("total")
    if not avail:
        return f"{ran} queries"
    txt = f"{ran} of {avail} queries in the file"
    parts = []
    if summary.get("rc_filter"):
        parts.append(f"filter matched {summary.get('queries_matching')}")
    if summary.get("limit"):
        parts.append(f"capped at {summary['limit']}")
    if summary.get("stopped"):
        parts.append("stopped early")
    return txt + (" (" + ", ".join(parts) + ")" if parts else "")


def build_report_pdf(summary, results, pdf_path=None):
    """Render the run to a PDF report and return its path."""
    from reportlab.lib import colors
    from reportlab.lib.enums import TA_LEFT
    from reportlab.lib.pagesizes import A4, landscape
    from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
    from reportlab.lib.units import cm
    from reportlab.platypus import (Image, PageBreak, Paragraph, SimpleDocTemplate,
                                    Spacer, Table, TableStyle)

    os.makedirs(REPORT_DIR, exist_ok=True)
    if not pdf_path:
        safe = re.sub(r"[^A-Za-z0-9_.-]+", "_", str(summary.get("server") or "oracle"))
        pdf_path = os.path.join(
            REPORT_DIR,
            f"oracle_rootcause_test_{safe}_{summary['started']:%Y%m%d%H%M%S}.pdf")

    pagesize = landscape(A4)
    doc = SimpleDocTemplate(pdf_path, pagesize=pagesize, title="DBDOME Oracle Root-Cause Test",
                            author="DBDOME", rightMargin=1.5 * cm, leftMargin=1.5 * cm,
                            topMargin=1.5 * cm, bottomMargin=1.5 * cm)
    styles = getSampleStyleSheet()
    cell = ParagraphStyle("cell", parent=styles["Normal"], fontName="Helvetica",
                          fontSize=8, leading=9.5, alignment=TA_LEFT, wordWrap="CJK")
    mono = ParagraphStyle("mono", parent=cell, fontName="Courier", fontSize=7, leading=8.5)
    head = ParagraphStyle("hcell", parent=cell, fontName="Helvetica-Bold",
                          fontSize=8, textColor=colors.whitesmoke)
    h2 = ParagraphStyle("h2", parent=styles["Heading2"], fontSize=12, spaceBefore=14,
                        spaceAfter=6, textColor=colors.HexColor("#2F4F4F"))

    el = []
    title = Paragraph(
        "<b>DBDOME &mdash; Oracle Root-Cause Detection Test</b><br/>"
        f"<font size=9>Server: {summary.get('server')} &nbsp;|&nbsp; "
        f"Run: {summary['started']:%Y-%m-%d %H:%M:%S} &nbsp;|&nbsp; "
        f"run_id {summary.get('run_id')}</font>", styles["Normal"])
    if os.path.isfile(LOGO_PATH):
        hdr = Table([[Image(LOGO_PATH, width=4 * cm, height=1.5 * cm), title]],
                    colWidths=[4.5 * cm, None])
    else:
        hdr = Table([[title]])
    hdr.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                             ("BOTTOMPADDING", (0, 0), (-1, -1), 10)]))
    el.append(hdr)

    # -- run parameters --------------------------------------------------
    el.append(Paragraph("Run parameters", h2))
    qmeta = summary.get("queries_file_meta") or {}
    info = [
        ("Oracle instance", f"{summary.get('host')}:{summary.get('port')} / "
                            f"{summary.get('service_name')}"),
        ("Connected as", summary.get("username")),
        ("Oracle version", (summary.get("banner") or "")[:110]),
        ("Queries file", summary.get("queries_file")),
        ("Queries file generated", str(qmeta.get("amended_at") or qmeta.get("generated_at") or "")),
        ("Filter", summary.get("rc_filter") or "(none - all root causes)"),
        ("Scope", _scope_text(summary)),
        ("Started / finished", f"{summary['started']:%Y-%m-%d %H:%M:%S} - "
                               f"{summary['finished']:%H:%M:%S} "
                               f"({summary.get('duration_s')} s)"),
        ("Results persisted to", RESULTS_TABLE if summary.get("persisted") else "(not persisted)"),
    ]
    if summary.get("stopped"):
        info.append(("NOTE", "Run stopped by the user before all queries completed."))
    t = Table([[_p(k, cell), _p(v, cell, 400)] for k, v in info],
              colWidths=[5 * cm, None])
    t.setStyle(TableStyle([
        ("GRID", (0, 0), (-1, -1), 0.4, colors.grey),
        ("BACKGROUND", (0, 0), (0, -1), colors.HexColor("#EDF1F1")),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 5), ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 3), ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
    ]))
    el.append(t)

    # -- summary ---------------------------------------------------------
    el.append(Paragraph("Summary", h2))
    empty = sum(1 for r in results if r["status"] == "success" and not r["matched"])
    srow = [["Queries run", "Succeeded", "Failed", "Detections (condition met)", "No finding"],
            [str(summary.get("total")), str(summary.get("success")), str(summary.get("failed")),
             str(summary.get("detections")), str(empty)]]
    st = Table(srow, colWidths=[5 * cm] * 5)
    st.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#2F4F4F")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.whitesmoke),
        ("FONT", (0, 0), (-1, 0), "Helvetica-Bold", 9),
        ("FONT", (0, 1), (-1, 1), "Helvetica-Bold", 11),
        ("ALIGN", (0, 0), (-1, -1), "CENTER"),
        ("GRID", (0, 0), (-1, -1), 0.4, colors.grey),
        ("TOPPADDING", (0, 0), (-1, -1), 5), ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ]))
    el.append(st)

    # -- detections ------------------------------------------------------
    dets = [r for r in results if r["matched"]]
    el.append(Paragraph(f"Detections &mdash; condition met ({len(dets)})", h2))
    if dets:
        data = [[_p("Root cause", head), _p("Name", head), _p("Severity", head),
                 _p("Condition", head), _p("Rows", head), _p("Sample row", head)]]
        for r in dets:
            smp = json.dumps(r["sample"][0], default=str) if r.get("sample") else ""
            data.append([_p(r["root_cause_id"], cell), _p(r["root_cause_name"], cell, 120),
                         _p(r.get("severity") or "", cell), _p(r.get("condition"), cell, 60),
                         _p(r.get("rows"), cell), _p(smp, mono, 300)])
        dt = Table(data, repeatRows=1,
                   colWidths=[4.4 * cm, 5.6 * cm, 1.8 * cm, 2.6 * cm, 1.4 * cm, 10.9 * cm])
        dt.setStyle(_grid_style(colors, TableStyle, colors.HexColor("#8B1A1A")))
        el.append(dt)
    else:
        el.append(Paragraph("No root cause met its detection condition on this instance.", cell))

    # -- errors ----------------------------------------------------------
    errs = [r for r in results if r["status"] == "failed"]
    if errs:
        el.append(Paragraph(f"Failed queries ({len(errs)})", h2))
        data = [[_p("Root cause", head), _p("Name", head), _p("Error", head)]]
        for r in errs:
            data.append([_p(r["root_cause_id"], cell), _p(r["root_cause_name"], cell, 120),
                         _p(r.get("error"), mono, 300)])
        et = Table(data, repeatRows=1, colWidths=[4.4 * cm, 6 * cm, 16.3 * cm])
        et.setStyle(_grid_style(colors, TableStyle, colors.HexColor("#8A6D00")))
        el.append(et)

    # -- full result list -------------------------------------------------
    el.append(PageBreak())
    el.append(Paragraph(f"All results ({len(results)})", h2))
    data = [[_p("#", head), _p("Root cause", head), _p("Name", head), _p("Status", head),
             _p("Rows", head), _p("ms", head), _p("Detected", head), _p("Condition", head)]]
    for i, r in enumerate(results, 1):
        data.append([_p(i, cell), _p(r["root_cause_id"], cell),
                     _p(r["root_cause_name"], cell, 120),
                     _p("FAILED" if r["status"] == "failed" else "ok", cell),
                     _p("-" if r["rows"] is None else r["rows"], cell),
                     _p(int(r["elapsed_ms"]), cell),
                     _p("YES" if r["matched"] else "", cell),
                     _p(r.get("condition"), cell, 60)])
    at = Table(data, repeatRows=1,
               colWidths=[1 * cm, 4.4 * cm, 8.5 * cm, 1.8 * cm, 1.4 * cm,
                          1.6 * cm, 2 * cm, 6 * cm])
    at.setStyle(_grid_style(colors, TableStyle, colors.HexColor("#2F4F4F")))
    el.append(at)
    el.append(Spacer(1, 10))
    el.append(Paragraph(
        "Queries are the Oracle detection statements shipped with DBDOME, executed with the "
        "credentials supplied on the /tester page. &quot;Detected&quot; applies the same "
        "row-count condition the collector uses, so a YES here is what production would alert on.",
        cell))

    def _footer(canvas, doc_):
        canvas.saveState()
        canvas.setFont("Helvetica", 8)
        canvas.drawString(1.5 * cm, 1 * cm,
                          f"DBDOME Oracle root-cause test - {summary.get('server')} - "
                          f"run_id {summary.get('run_id')}")
        canvas.drawRightString(pagesize[0] - 1.5 * cm, 1 * cm, f"Page {doc_.page}")
        canvas.restoreState()

    doc.build(el, onFirstPage=_footer, onLaterPages=_footer)
    return pdf_path


def _grid_style(colors, TableStyle, header_bg):
    return TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), header_bg),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("GRID", (0, 0), (-1, -1), 0.4, colors.grey),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.whitesmoke, colors.HexColor("#EFEFEF")]),
        ("LEFTPADDING", (0, 0), (-1, -1), 4), ("RIGHTPADDING", (0, 0), (-1, -1), 4),
        ("TOPPADDING", (0, 0), (-1, -1), 2.5), ("BOTTOMPADDING", (0, 0), (-1, -1), 2.5),
    ])
