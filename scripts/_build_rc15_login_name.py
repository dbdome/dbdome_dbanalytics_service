"""Build + validate the SEC-SQL-PRI-001-RC15 'add login_name' change.
Read-only against the DB: fetches current content, applies per-vendor transforms,
validates, backs up originals, and writes an idempotent fix .sql script.
Does NOT modify the DB."""
import psycopg2, json, os

HERE = os.path.dirname(os.path.abspath(__file__))
env = {}
for line in open(os.path.join(HERE, "..", ".env"), encoding="utf-8", errors="ignore"):
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip().strip('"').strip("'")

con = psycopg2.connect(host=env["PG_HOST"], port=env["PG_PORT"], user=env["PG_USER"],
                       password=env["PG_PASSWORD"], dbname=env["PG_DB"])
con.set_session(readonly=True)
cur = con.cursor()

IDS = {15591: "mariadb", 13068: "mysql", 13066: "oracle",
       13067: "postgresql", 13065: "sqlserver"}

# Per-vendor (anchor -> replacement). Appends login_name as the last select-list
# column in BOTH union branches: real user on the active-transaction branch,
# NULL on the aggregate cached-plan branch (no session there).
mysql_tx = [
    ("LEFT(d.digest_text, 4000) AS query_text FROM",
     "LEFT(d.digest_text, 4000) AS query_text, NULL AS login_name FROM"),
    ("LEFT(trx.trx_query, 4000) AS query_text FROM",
     "LEFT(trx.trx_query, 4000) AS query_text, p.user AS login_name FROM"),
    ("JOIN sensitive_cols sc ON trx.trx_query LIKE CONCAT('%', sc.table_name, '%') WHERE trx.trx_state",
     "JOIN sensitive_cols sc ON trx.trx_query LIKE CONCAT('%', sc.table_name, '%') "
     "LEFT JOIN information_schema.processlist p ON p.id = trx.trx_mysql_thread_id WHERE trx.trx_state"),
]
TX = {
    "mariadb": mysql_tx,
    "mysql": mysql_tx,
    "oracle": [
        ("AS query_text FROM v$sql sql",
         "AS query_text, CAST(NULL AS VARCHAR2(128)) AS login_name FROM v$sql sql"),
        ("AS query_text FROM v$transaction t",
         "AS query_text, s.username AS login_name FROM v$transaction t"),
    ],
    "postgresql": [
        ("LEFT(pss.query, 4000) AS query_text FROM pg_stat_statements pss",
         "LEFT(pss.query, 4000) AS query_text, pg_get_userbyid(pss.userid) AS login_name FROM pg_stat_statements pss"),
        ("LEFT(psa.query, 4000) AS query_text FROM pg_stat_activity psa",
         "LEFT(psa.query, 4000) AS query_text, psa.usename AS login_name FROM pg_stat_activity psa"),
    ],
    "sqlserver": [
        ("AS query_text\nFROM sys.dm_exec_query_stats",
         "AS query_text,\n       CAST(NULL AS sysname) AS login_name\nFROM sys.dm_exec_query_stats"),
        ("AS query_text\nFROM sys.dm_tran_active_transactions",
         "AS query_text,\n       ses.login_name AS login_name\nFROM sys.dm_tran_active_transactions"),
    ],
}

backup, new_sql = {}, {}
for sid, vendor in IDS.items():
    cur.execute("SELECT content FROM rootcause.detection_steps WHERE id=%s", (sid,))
    content = cur.fetchone()[0]           # jsonb -> dict
    sql = content["sql"]
    backup[sid] = {"vendor": vendor, "content": content}
    if "login_name" in sql:
        print(f"[skip] id={sid} {vendor}: already has login_name")
        new_sql[sid] = None
        continue
    out = sql
    for anchor, repl in TX[vendor]:
        if anchor not in out:
            raise SystemExit(f"ANCHOR MISS id={sid} {vendor}: {anchor[:60]!r}")
        out = out.replace(anchor, repl, 1)
    # validate: exactly 2 login_name select aliases (one per union branch)
    n = out.count("AS login_name")
    if n != 2:
        raise SystemExit(f"VALIDATION FAIL id={sid} {vendor}: AS login_name count={n} (want 2)")
    new_content = dict(content); new_content["sql"] = out
    new_sql[sid] = new_content
    # preview the head of each branch
    print(f"\n=== id={sid} {vendor} : login_name added (2 branches) ===")
con.close()

# backup originals
bdir = os.path.join(HERE, "backups"); os.makedirs(bdir, exist_ok=True)
bpath = os.path.join(bdir, "rc15_content_backup.json")
with open(bpath, "w", encoding="utf-8") as f:
    json.dump(backup, f, ensure_ascii=False, indent=1)
print("\nBackup of original content ->", bpath)

# write idempotent fix script
def pg_lit(d):
    return "'" + json.dumps(d, ensure_ascii=False).replace("'", "''") + "'::jsonb"

lines = [
    "-- =============================================================================",
    "-- SEC-SQL-PRI-001-RC15 - return login_name for all DB vendors",
    "-- Appends a login_name column to BOTH union branches of each vendor detection:",
    "--   active-transaction branch -> real connected user; cached-plan/aggregate",
    "--   branch -> NULL (no session bound to a cached plan).",
    "-- RC14 already returns login_name for every vendor (no change needed).",
    "-- Idempotent: re-running is a no-op for rows that already contain login_name.",
    "-- Run on dbanalytics PG (5432).",
    "-- =============================================================================",
    "BEGIN;",
]
for sid, vendor in IDS.items():
    nc = new_sql[sid]
    if nc is None:
        lines.append(f"-- id={sid} ({vendor}) already had login_name - skipped")
        continue
    lines.append(f"-- {vendor} (id {sid})")
    lines.append(f"UPDATE rootcause.detection_steps SET content = {pg_lit(nc)} WHERE id = {sid};")
lines += [
    "-- verify: every RC15 row should now contain login_name",
    "SELECT id, vendor_slug, (content->>'sql' LIKE '%login_name%') AS has_login_name",
    "FROM rootcause.detection_steps WHERE name LIKE '%PRI-001-RC15%' ORDER BY vendor_slug;",
    "COMMIT;",
]
spath = os.path.join(HERE, "fix_SEC-SQL-PRI-001-RC15_add_login_name.sql")
open(spath, "w", encoding="utf-8").write("\n".join(lines) + "\n")
print("Fix script ->", spath)
print("\nTransforms validated for:", [f"{v}({s})" for s, v in IDS.items() if new_sql[s] is not None])
