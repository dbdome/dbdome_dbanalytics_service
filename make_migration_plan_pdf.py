"""Generate the DBDOME 'Cross-Vendor Data Migration Engine' plan as a branded PDF.

Same visual language as the other DBDOME documents (cover with logo, navy
section bands, tag pills), plus two renderers those guides did not need: a
two-column table for the data model / reuse map, and a monospaced code block
for the rule JSON and DDL fragments.

Content is the design agreed in session: source server + database set -> JSON
transformation ruleset stored in Postgres -> destination server + database set,
run by the existing scheduler. Every claim about drivers, row counts and
existing objects in here was verified against this machine, not assumed.
"""
import datetime

NAVY = (23, 42, 77)
BLUE = (37, 99, 175)
LIGHT = (238, 242, 249)
CODEBG = (245, 246, 248)
GREY = (90, 90, 90)
LINE = (210, 216, 226)
BASE = "C:/dev/dbdome_dbanalytics_service"
LOGO = f"{BASE}/static/images/dbdome_logo.png"
OUT = f"{BASE}/docs/DBDOME_Migration_Engine_Plan.pdf"

TITLE = "Cross-Vendor Data Migration Engine"
SUBTITLE = "Source server + database set  ->  JSON ruleset in Postgres  ->  destination server + database set"
META = "Status: design, for approval   |   Target first source vendor: IBM DB2"

INTRO = (
    "This plan describes an end-to-end migration solution that extracts from a source "
    "server's set of databases, transforms each row against rules stored as JSON in "
    "Postgres tables, and loads the result into a destination server's set of databases - "
    "on a schedule. It is deliberately built from parts DBDOME already runs: the server "
    "registry and its encrypted credentials, the JSON-rule execution pattern used by the "
    "detection tree, the column-rule cache used by data masking, the interval scheduler, "
    "and the run-accounting shape introduced with the mail diagnostics. The new work is "
    "the rule schema, the extract-transform-load engine, type mapping and reconciliation.")

STATS = [("~70%", "of the plumbing already exists in this codebase"),
         ("DB2", "driver verified on the exact build interpreter"),
         ("8 + 3", "new Postgres tables and operator views (written, validated)"),
         ("3-4 wk", "to a production-quality first vendor pair")]

# ---------------------------------------------------------------- content
# section = (code, title, intro, [blocks])
# block   = ("item", tag, heading, body) | ("table", title, [(k, v), ...])
#         | ("code", caption, "text") | ("note", "", body)
SECTIONS = [

 ("VERDICT", "Feasibility and the DB2 question",
  "What was actually tested on this machine, and what it costs.",
  [
   ("item", "YES", "The solution is feasible, and most of it is assembly rather than invention",
    "DBDOME already connects to seven vendors with encrypted credentials, already stores "
    "executable rules as JSON in Postgres and runs them against a target connection, "
    "already schedules recurring work with a live enable/disable toggle, and already has a "
    "run-accounting pattern that records the stage a failure happened at. The migration "
    "engine reuses all five."),

   ("item", "VERIFIED", "DB2 as a source works on the exact interpreter the build uses",
    "ibm_db 3.3.0 publishes a cp314 wheel; it was downloaded and imported successfully on "
    "Python 3.14.5 on this machine. The first import failed with 'DLL load failed' and "
    "succeeded once clidriver/bin was registered with os.add_dll_directory() - the same "
    "pattern utils/oracle_client.py already uses for the Oracle Instant Client. So the "
    "integration shape is one this codebase has solved before."),

   ("item", "COST", "About 86 MB added to the bundle, plus a spec entry and a runtime hook",
    "Almost all of it is IBM's bundled CLI driver. The alternative is pyodbc, which is "
    "already in the build, against the IBM Data Server ODBC driver - no new Python "
    "dependency, but the driver must then be installed on every host."),

   ("item", "CAVEAT", "The risk is which DB2, not whether DB2",
    "LUW, DB2 for i (AS/400) and z/OS differ in catalog views (SYSCAT.* vs QSYS2.* vs "
    "SYSIBM.*), paging syntax, and - on i and z - CCSID/EBCDIC encoding plus GRAPHIC and "
    "VARGRAPHIC types. The engine is unaffected; the introspection SQL and type map are "
    "per-flavour. Decide the flavour before Phase 1."),

   ("note", "", "There is no DB2 instance on this network to develop against. DB2 Community "
    "Edition in Docker on the Ubuntu VM is the cheapest way to unblock Phase 1, and should "
    "be stood up before any engine work starts."),
  ]),

 ("SHAPE", "The solution in one picture",
  "Four moving parts; the middle two are rows in Postgres, not code.",
  [
   ("code", "Flow",
    "source server (metrics.servers.server_id)\n"
    "   +-- database set          <- migration.database_map (source_database)\n"
    "          |\n"
    "          v\n"
    "   transformation ruleset    <- migration.rules (JSONB)\n"
    "     project -> database -> object -> column, merged, most specific wins\n"
    "          |\n"
    "          v\n"
    "   destination server (metrics.servers.server_id)\n"
    "   +-- database set          <- migration.database_map (target_database)\n"
    "\n"
    "driven by: metrics.registered_processes 'migration_runner' (60s tick)\n"
    "           + migration.schedules (per-project cadence and guardrails)"),

   ("item", "WHY", "Connection identity is never duplicated",
    "An endpoint is a reference to metrics.servers.server_id, so host, port, vendor, "
    "driver and the enc:v1: credentials keep living where the existing server form "
    "manages them. Because metrics.servers.database is a single column, the database SET "
    "cannot live there - it is migration.database_map."),

   ("item", "SETS", "One table makes renames, subsets and consolidation the same thing",
    "A 1:1 rename is one row. A subset is fewer rows. Many-to-one consolidation is several "
    "rows sharing a target_database. No code path distinguishes them."),
  ]),

 ("MODEL", "The Postgres data model",
  "Written as sql_scripts/7680_migration_engine.sql and validated against the live "
  "database inside a transaction that was rolled back.",
  [
   ("table", "Tables", [
     ("migration.projects", "Source and target server_id, mode (full/incremental), object_scope, batch size, parallelism, on_error policy, and allow_write - the dry-run gate, false by default."),
     ("migration.database_map", "The database set on both sides: source_database -> target_database, schema_map JSONB, load_order, is_active."),
     ("migration.rules", "The JSON ruleset. scope in (project, database, object, column) with a CHECK that each scope carries exactly the keys it needs. GIN-indexed."),
     ("migration.schedules", "Per-project cadence plus the guardrails a long destructive job needs. One row per project."),
     ("migration.runs", "One row per execution: trigger, dry_run, status, counts, heartbeat, host."),
     ("migration.run_items", "One row per (database, object): status, STAGE, rows read/written/rejected, duration, error class and code."),
     ("migration.watermarks", "Per (project, database, object) resume point - restartability and incremental loads."),
     ("migration.rejects", "Quarantined rows with the rule that rejected them, so bad data never silently disappears."),
   ]),
   ("table", "Operator views", [
     ("migration.v_schedule_due", "Why each project will or will not start on this tick."),
     ("migration.v_run_errors", "Every failed or skipped object, newest first."),
     ("migration.v_run_summary", "Per-run totals: objects ok/failed, rows, duration."),
   ]),
   ("note", "", "Two defaults are deliberately conservative: allow_write starts false, so a new "
    "project can only dry-run until someone explicitly enables writing; and object_scope starts "
    "'listed' (opt-in per object) rather than 'all'. Both are one-column changes if the opposite "
    "posture is preferred."),
  ]),

 ("RULES", "The transformation ruleset",
  "Rules are rows. Changing a mapping is an UPDATE, never a rebuild - the same property "
  "that lets the Oracle tester's query file be swapped in bin.",
  [
   ("item", "MERGE", "Resolution is project -> database -> object -> column",
    "Rules are merged rather than replaced, so a project-level default such as 'trim all text' "
    "or 'DECIMAL maps to numeric' applies everywhere while an object or column rule overrides "
    "only what it names. This mirrors config.masking_rules keyed by (server, table, column) and "
    "cached by processes/data_masking_engine.py, one level deeper."),

   ("code", "Project scope - the defaults everything inherits",
    '{ "type_map": { "DECIMAL": "numeric", "DECFLOAT": "numeric",\n'
    '                "VARGRAPHIC": "text", "TIMESTAMP": "timestamp(6)",\n'
    '                "CLOB": "text", "BLOB": "bytea" },\n'
    '  "defaults": { "trim_text": true, "empty_string_as_null": true,\n'
    '                "batch_size": 5000 },\n'
    '  "exclude":  { "objects": ["*_TMP", "SYS*"] } }'),

   ("code", "Object scope - one table",
    '{ "source": { "select": "SELECT * FROM DB2INST1.CUSTOMERS\n'
    '                         WHERE UPD_TS > :watermark",\n'
    '              "params": { "watermark": { "from": "watermark",\n'
    '                                         "type": "timestamp" } },\n'
    '              "order_by": ["CUST_ID"] },\n'
    '  "target": { "table": "public.customers", "load": "upsert",\n'
    '              "keys": ["cust_id"],\n'
    '              "post_sql": ["ANALYZE public.customers"] },\n'
    '  "validate": { "row_count": "equal", "checksum_keys": ["cust_id"] } }'),

   ("code", "Column scope - overrides only what it names",
    '{ "src": "SSN", "dst": "ssn", "type": "text",\n'
    '  "transform": [ { "op": "trim" },\n'
    '                 { "op": "mask", "rule": "ssn_last4" } ] }'),

   ("item", "SAFETY", "Transforms are a whitelisted operator registry, never eval",
    "trim, cast, nullif, concat, lookup, date_parse, mask and a restricted expr subset. A rule "
    "stored in the database must never be able to execute arbitrary Python: the rules table is "
    "operator-editable, so it is an injection surface by definition."),

   ("item", "SEED", "Rules are drafted, not hand-written from nothing",
    "monitoring.schema already holds 2,896 discovered table/column/data_type rows. The generator "
    "drafts column rules from it against the project type map, and the operator edits only the "
    "exceptions. For a DB2 source not yet inventoried, the connector reads SYSCAT.COLUMNS."),
  ]),

 ("SCHED", "Scheduling",
  "Two layers, both already running in this product. No third scheduler is introduced.",
  [
   ("item", "TICK", "One new registered process: migration_runner, 60s, seeded INACTIVE",
    "metrics.registered_processes already drives interval jobs, resolves a process name to a "
    "callable via get_function_by_name, and is re-read by the config watcher every 30 seconds - "
    "so a migration dispatcher can be enabled or disabled live, with no restart. It is seeded "
    "inactive on purpose: creating tables is what makes the feature possible, starting a loop "
    "that can write to customer databases is a separate, deliberate act."),

   ("item", "CADENCE", "Per-project schedule rows, modelled on jobs.job_schedules",
    "schedule_kind is interval, daily, weekly, monthly, cron or manual, with a CHECK constraint "
    "that the chosen kind brings its own parameters - a daily schedule without a time is "
    "rejected by the database, not by hope."),

   ("table", "Guardrails a report schedule never needed", [
     ("Single-flight", "state + heartbeat_at + lock_key (generated, for pg_try_advisory_lock). A tick must never start a project that is already running, including from a second service instance."),
     ("Crash recovery", "stale_after_seconds. A service killed mid-run would otherwise leave state='running' forever; a stale run becomes dispatchable again."),
     ("Maintenance window", "allow_from / allow_to / allow_days, plus kill_outside_window. Big loads run at night."),
     ("Retry with backoff", "attempt, max_attempts, retry_backoff_seconds. A dead source is backed off, not hammered every tick."),
     ("Catch-up policy", "run_once or skip. After downtime a report may replay; a migration must never replay every missed slot."),
     ("Runtime cap", "max_runtime_seconds, priority, consecutive_failures."),
   ]),

   ("code", "Verified dispatcher decisions (v_schedule_due, exercised in a rolled-back transaction)",
    "due now                -> due                    stale=False\n"
    "not due yet            -> not due yet\n"
    "already running        -> already running\n"
    "stale -> recoverable   -> due                    stale=True\n"
    "schedule inactive      -> schedule inactive\n"
    "paused                 -> paused"),

   ("item", "WHY", "A skipped migration must never be a mystery",
    "v_schedule_due returns a dispatch_decision for every project, so 'it did not run last night' "
    "is answered by one query instead of by reading scheduler code. This is the same principle as "
    "the mail send log added earlier: record the reason, not just the outcome."),
  ]),

 ("ENGINE", "The engine",
  "Vendor-agnostic by construction: the only vendor-specific parts are the connector and "
  "the introspection SQL.",
  [
   ("code", "Loop",
    "project\n"
    " +- for each active database_map row        (up to parallel_databases)\n"
    "     +- resolve ruleset for that database\n"
    "     +- enumerate objects (rules union source catalog)\n"
    "         +- per object:\n"
    "             extract batch (server-side cursor, batch_size)\n"
    "             transform     (rule pipeline, rejects quarantined)\n"
    "             load          (execute_values / COPY for PG targets)\n"
    "             checkpoint    (migration.watermarks)\n"
    "             validate      (row count, key checksums)\n"
    "         +- write migration.run_items: status, stage, counts, ms, error"),

   ("item", "RESTART", "Checkpoint per batch, not per table",
    "A killed run resumes at the watermark rather than restarting the object. The cost is that a "
    "failure can leave a partially loaded table; that is recoverable by design but must be a "
    "stated choice, not a surprise."),

   ("item", "DRYRUN", "Preview before any write exists as a first-class mode",
    "allow_write=false extracts and transforms and writes nothing, reporting what would have been "
    "loaded. The operator page reuses the /tester pattern built for the Oracle root-cause tester: "
    "background run, live progress, stop button, PDF report at the end."),
  ]),

 ("PHASES", "Delivery plan",
  "Roughly three to four weeks to a production-quality first vendor pair; materially less "
  "for each additional source, because only the connector changes.",
  [
   ("item", "PHASE 1  (2-3 d)", "DB2 connector and catalog introspection",
    "utils/db2_client.py mirroring oracle_client.py's DLL-directory initialisation, the type-map "
    "table, and introspection proven against a real DB2 instance (Docker DB2 Community Edition "
    "on the Ubuntu VM). Gate: connect, list schemas, read a table, map every column type."),

   ("item", "PHASE 2  (2-3 d)", "Schema and rule model",
    "Apply 7680_migration_engine.sql, add the JSON schema validator, and build the rule generator "
    "that drafts rules from monitoring.schema and from source introspection."),

   ("item", "PHASE 3  (5-8 d)", "The engine",
    "Extract, transform, load, batching, checkpoints, rejects and run accounting. Gate: a full "
    "load of a non-trivial database with reconciliation clean."),

   ("item", "PHASE 4  (2-3 d)", "Operator page and dispatcher",
    "/migration cloned from /tester, plus the migration_runner dispatcher consuming "
    "v_schedule_due and taking the advisory lock."),

   ("item", "PHASE 5  (2-3 d)", "Validation and reconciliation",
    "Row counts, per-key checksums, sampled column comparison, and a PDF/CSV reconciliation report "
    "per run."),

   ("item", "PHASE 6  (3-5 d, optional)", "Incremental and CDC",
    "Watermark-based incremental is included in the engine. True log-based CDC on DB2 LUW has no "
    "cheap equivalent of logical decoding and means IBM InfoSphere CDC or a third-party tool - "
    "set that expectation before it is promised to anyone."),
  ]),

 ("RISK", "Risks and decisions outstanding",
  "The ones that change the design if answered late.",
  [
   ("table", "Risks", [
     ("Type fidelity", "DECFLOAT, GRAPHIC/VARGRAPHIC, LOBs, and timestamp precision - DB2 offers 12 fractional digits where Postgres stops at 6. Needs an explicit, testable type map rather than per-rule guesswork."),
     ("Encoding", "CCSID and EBCDIC on DB2 for i and z/OS."),
     ("Identity and keys", "Sequence and identity resync after load, and FK-safe load ordering (load_order in database_map)."),
     ("Throughput", "execute_values is comfortable to about a million rows per object; beyond that use COPY with a binary writer."),
     ("Transactional boundary", "Per-batch commit means a visible partial table during a run."),
     ("No test instance", "There is no DB2 on this network today. Phase 1 is blocked until one exists."),
   ]),
   ("table", "Decisions needed", [
     ("Which DB2 flavour", "LUW, for i, or z/OS - drives introspection SQL, paging and encoding."),
     ("Object scope default", "Opt-in per object ('listed', the safer default as written) or all-with-exclusions ('all', faster to set up, can pull staging tables into production)."),
     ("Driver strategy", "Bundle ibm_db (+86 MB, self-contained) or require the IBM ODBC driver on each host via the pyodbc already in the build."),
     ("Target write mode", "Insert-only, upsert on keys, or truncate-and-load per object - it is per-rule, but a project default should be agreed."),
   ]),
   ("note", "", "Housekeeping to fold into Phase 3: utils/transformer_mssql_pg.py is the 49-line ancestor "
    "of this engine and carries a live production password in the repository. It should be deleted or "
    "gutted when the engine lands, and that credential rotated."),
  ]),

 ("REUSE", "What already exists",
  "Every row here is an existing, working part of this product - the reason the estimate is "
  "weeks rather than months.",
  [
   ("table", "Reuse map", [
     ("Vendor connections, encrypted credentials", "metrics.servers (17 servers, 7 vendors) + utils/secrets_crypto + per-vendor collectors, including Informix - the IBM-family precedent."),
     ("JSON rules in PG executed as steps", "rootcause.detection_steps and processes/detection_tree_executor.py (execute_step / execute_path, :name parameter substitution)."),
     ("Column rules with a resolution cache", "config.masking_rules + processes/data_masking_engine.py."),
     ("Interval scheduling with a live toggle", "metrics.registered_processes + the 30-second config watcher."),
     ("Calendar scheduling precedent", "jobs.jobs / jobs.job_schedules (2,463 rows) and v_job_scheduler."),
     ("Run accounting with stage and error code", "alerts.mail_send_log and its views, added this week."),
     ("Operator page: background run, progress, PDF", "/tester and /api/tester/* , added this week."),
     ("Bulk load into Postgres", "psycopg2 execute_values, already used in utils/transformer_mssql_pg.py."),
     ("Packaging a native client driver", "utils/oracle_client.py thick-mode initialisation and the spec entries that ship it."),
   ]),
  ]),
]



# ---------------------------------------------------------------- rendering
# reportlab, not fpdf: reportlab 4.5.1 is already in the build venv (the product
# renders its compliance and tester PDFs with it), so this generator carries no
# dependency the build does not already have.
import os
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm, mm
from reportlab.platypus import (Image, KeepTogether, PageBreak, Paragraph,
                                Preformatted, SimpleDocTemplate, Spacer, Table,
                                TableStyle)

C_NAVY = colors.Color(*[c / 255 for c in NAVY])
C_BLUE = colors.Color(*[c / 255 for c in BLUE])
C_LIGHT = colors.Color(*[c / 255 for c in LIGHT])
C_CODE = colors.Color(*[c / 255 for c in CODEBG])
C_GREY = colors.Color(*[c / 255 for c in GREY])
C_LINE = colors.Color(*[c / 255 for c in LINE])

_ss = getSampleStyleSheet()
S_BODY = ParagraphStyle("body", parent=_ss["Normal"], fontName="Helvetica",
                        fontSize=9, leading=12.5, textColor=colors.Color(.27, .27, .27))
S_HEAD = ParagraphStyle("head", parent=S_BODY, fontName="Helvetica-Bold",
                        fontSize=9.5, leading=12.5, textColor=colors.Color(.12, .12, .12))
S_INTRO = ParagraphStyle("intro", parent=S_BODY, fontName="Helvetica-Oblique",
                         fontSize=9, leading=12, textColor=C_GREY)
S_SECT = ParagraphStyle("sect", parent=S_BODY, fontName="Helvetica-Bold",
                        fontSize=13, leading=16, textColor=colors.white)
S_PILL = ParagraphStyle("pill", parent=S_BODY, fontName="Courier-Bold",
                        fontSize=8, leading=10, textColor=C_NAVY, alignment=TA_CENTER)
S_KEY = ParagraphStyle("key", parent=S_BODY, fontName="Helvetica-Bold",
                       fontSize=8.5, leading=11, textColor=C_NAVY)
S_VAL = ParagraphStyle("val", parent=S_BODY, fontSize=8.5, leading=11)
S_NOTE = ParagraphStyle("note", parent=S_BODY, fontName="Helvetica-Oblique",
                        fontSize=8.6, leading=11.5, textColor=colors.Color(.35, .27, .08))
S_CODE = ParagraphStyle("codeblk", parent=S_BODY, fontName="Courier", fontSize=7.4,
                        leading=9.6, textColor=colors.Color(.14, .18, .25))
S_CAP = ParagraphStyle("cap", parent=S_INTRO, fontSize=8.4, leading=10.5)

PAGE_W, PAGE_H = A4
LM = RM = 1.8 * cm
CONTENT_W = PAGE_W - LM - RM


def clean(s):
    """Flatten a content string to one line; renderers wrap it themselves."""
    return " ".join((s or "").split())


def esc(s):
    return clean(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def section_band(title, code):
    t = Table([[Paragraph("&nbsp;" + esc(title) + " &nbsp;(" + code + ")", S_SECT)]],
              colWidths=[CONTENT_W], rowHeights=[10 * mm])
    t.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), C_NAVY),
                           ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                           ("LEFTPADDING", (0, 0), (-1, -1), 4)]))
    return t


def item_flow(tag, heading, body):
    """Tag pill on the left, heading + body on the right, kept on one page."""
    pill = Table([[Paragraph(esc(tag), S_PILL)]], colWidths=[2.4 * cm])
    pill.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), C_LIGHT),
                              ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                              ("TOPPADDING", (0, 0), (-1, -1), 2),
                              ("BOTTOMPADDING", (0, 0), (-1, -1), 2)]))
    right = [Paragraph(esc(heading), S_HEAD)]
    if body:
        right.append(Spacer(1, 1.5))
        right.append(Paragraph(esc(body), S_BODY))
    t = Table([[pill, right]], colWidths=[2.6 * cm, CONTENT_W - 2.6 * cm])
    t.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"),
                           ("LEFTPADDING", (0, 0), (0, 0), 0),
                           ("LEFTPADDING", (1, 0), (1, 0), 4),
                           ("TOPPADDING", (0, 0), (-1, -1), 1),
                           ("BOTTOMPADDING", (0, 0), (-1, -1), 4)]))
    return KeepTogether([t, Spacer(1, 2)])


def table_flow(title, rows):
    out = []
    if title:
        out.append(Paragraph(esc(title), S_KEY))
        out.append(Spacer(1, 3))
    data = [[Paragraph(esc(k), S_KEY), Paragraph(esc(v), S_VAL)] for k, v in rows]
    t = Table(data, colWidths=[4.6 * cm, CONTENT_W - 4.6 * cm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (0, -1), C_LIGHT),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LINEBELOW", (0, 0), (-1, -1), 0.4, C_LINE),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]))
    out.append(t)
    out.append(Spacer(1, 6))
    return out


def code_flow(caption, text):
    inner = Preformatted(text, S_CODE)
    box = Table([[inner]], colWidths=[CONTENT_W])
    box.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), C_CODE),
                             ("BOX", (0, 0), (-1, -1), 0.5, C_LINE),
                             ("LEFTPADDING", (0, 0), (-1, -1), 6),
                             ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                             ("TOPPADDING", (0, 0), (-1, -1), 5),
                             ("BOTTOMPADDING", (0, 0), (-1, -1), 5)]))
    flows = []
    if caption:
        flows.append(Paragraph(esc(caption), S_CAP))
        flows.append(Spacer(1, 2))
    flows.append(box)
    flows.append(Spacer(1, 6))
    return KeepTogether(flows)


def note_flow(body):
    t = Table([["", Paragraph(esc(body), S_NOTE)]],
              colWidths=[0.16 * cm, CONTENT_W - 0.16 * cm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (0, -1), colors.Color(.84, .62, .18)),
        ("BACKGROUND", (1, 0), (1, -1), colors.Color(.988, .973, .922)),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (1, 0), (1, 0), 7), ("RIGHTPADDING", (1, 0), (1, 0), 7),
        ("TOPPADDING", (0, 0), (-1, -1), 5), ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ]))
    return KeepTogether([t, Spacer(1, 6)])


def _chrome(canvas, doc):
    """Running header (from page 2) and a footer on every page."""
    canvas.saveState()
    if doc.page > 1:
        if os.path.isfile(LOGO):
            try:
                canvas.drawImage(LOGO, LM, PAGE_H - 1.45 * cm, width=0.75 * cm,
                                 height=0.75 * cm, mask="auto", preserveAspectRatio=True)
            except Exception:
                pass
        canvas.setFont("Helvetica-Bold", 8.5)
        canvas.setFillColor(C_GREY)
        canvas.drawString(LM + 1.0 * cm, PAGE_H - 1.2 * cm,
                          "DBDOME  -  Cross-Vendor Data Migration Engine  -  Plan")
        canvas.setStrokeColor(C_LINE)
        canvas.line(LM, PAGE_H - 1.6 * cm, PAGE_W - RM, PAGE_H - 1.6 * cm)
    canvas.setFont("Helvetica", 7.6)
    canvas.setFillColor(C_GREY)
    canvas.drawCentredString(PAGE_W / 2, 1.05 * cm,
                             "Page " + str(doc.page) + "   |   DBDOME Migration Engine - "
                             "design for approval   |   Confidential")
    canvas.restoreState()


story = []

# ---- cover ----
if os.path.isfile(LOGO):
    img = Image(LOGO, width=3.4 * cm, height=3.4 * cm, kind="proportional")
    img.hAlign = "CENTER"
    story.append(img)
story.append(Spacer(1, 6))
story.append(Paragraph("DBDOME", ParagraphStyle("t1", parent=S_BODY, fontName="Helvetica-Bold",
                                                fontSize=24, leading=27, alignment=TA_CENTER,
                                                textColor=C_NAVY)))
story.append(Paragraph(esc(TITLE), ParagraphStyle("t2", parent=S_BODY, fontName="Helvetica-Bold",
                                                  fontSize=15, leading=19, alignment=TA_CENTER,
                                                  textColor=C_BLUE)))
story.append(Spacer(1, 2))
story.append(Paragraph(esc(SUBTITLE), ParagraphStyle("t3", parent=S_BODY, fontSize=9,
                                                     leading=12, alignment=TA_CENTER,
                                                     textColor=C_GREY)))
story.append(Paragraph(esc(META), ParagraphStyle("t4", parent=S_BODY, fontSize=9.5,
                                                 leading=13, alignment=TA_CENTER,
                                                 textColor=C_GREY)))
story.append(Spacer(1, 8))
rule = Table([[""]], colWidths=[CONTENT_W], rowHeights=[1.6])
rule.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), C_NAVY)]))
story.append(rule)
story.append(Spacer(1, 10))
story.append(Paragraph(esc(INTRO), ParagraphStyle("lead", parent=S_BODY, fontSize=9.6,
                                                  leading=13.6)))
story.append(Spacer(1, 10))
stat_rows = [[Paragraph("&nbsp;" + esc(v), ParagraphStyle("sv", parent=S_KEY, fontSize=10.5)),
              Paragraph("&nbsp;" + esc(l), S_VAL)] for v, l in STATS]
st = Table(stat_rows, colWidths=[3.1 * cm, CONTENT_W - 3.1 * cm])
st.setStyle(TableStyle([("BACKGROUND", (0, 0), (0, -1), C_LIGHT),
                        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                        ("TOPPADDING", (0, 0), (-1, -1), 4),
                        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
                        ("LINEBELOW", (0, 0), (-1, -1), 0.4, colors.white)]))
story.append(st)
story.append(Spacer(1, 12))
story.append(Paragraph("Contents", S_KEY))
story.append(Spacer(1, 3))
toc = [[Paragraph("<font face='Courier'>" + esc(c) + "</font>", S_VAL), Paragraph(esc(t), S_VAL)]
       for c, t, _i, _b in SECTIONS]
tt = Table(toc, colWidths=[2.6 * cm, CONTENT_W - 2.6 * cm])
tt.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"),
                        ("TOPPADDING", (0, 0), (-1, -1), 1.5),
                        ("BOTTOMPADDING", (0, 0), (-1, -1), 1.5)]))
story.append(tt)
story.append(Spacer(1, 10))
story.append(Paragraph("Generated " + datetime.date.today().strftime("%d %b %Y") +
                       "   |   DDL: sql_scripts/7680_migration_engine.sql", S_CAP))

# ---- body ----
for code, title, intro, blocks in SECTIONS:
    story.append(PageBreak())
    story.append(section_band(title, code))
    story.append(Spacer(1, 5))
    if intro:
        story.append(Paragraph(esc(intro), S_INTRO))
        story.append(Spacer(1, 3))
        hr = Table([[""]], colWidths=[CONTENT_W], rowHeights=[0.4])
        hr.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), C_LINE)]))
        story.append(hr)
        story.append(Spacer(1, 7))
    for block in blocks:
        kind = block[0]
        if kind == "item":
            story.append(item_flow(block[1], block[2], block[3]))
        elif kind == "table":
            story.extend(table_flow(block[1], block[2]))
        elif kind == "code":
            story.append(code_flow(block[1], block[2]))
        elif kind == "note":
            story.append(note_flow(block[2]))

os.makedirs(os.path.dirname(OUT), exist_ok=True)
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=LM, rightMargin=RM,
                        topMargin=2.1 * cm, bottomMargin=1.7 * cm,
                        title="DBDOME - Cross-Vendor Data Migration Engine - Plan",
                        author="DBDOME", subject=SUBTITLE)
doc.build(story, onFirstPage=_chrome, onLaterPages=_chrome)

_n_items = sum(1 for _c, _t, _i, bl in SECTIONS for b in bl if b[0] == "item")
_n_rows = sum(len(b[2]) for _c, _t, _i, bl in SECTIONS for b in bl if b[0] == "table")
_n_code = sum(1 for _c, _t, _i, bl in SECTIONS for b in bl if b[0] == "code")
print("WROTE " + OUT)
print("  sections=%d items=%d table_rows=%d code_blocks=%d bytes=%d"
      % (len(SECTIONS), _n_items, _n_rows, _n_code, os.path.getsize(OUT)))
