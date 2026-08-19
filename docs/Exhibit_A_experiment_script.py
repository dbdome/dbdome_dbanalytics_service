"""
Neutralization-effect experiment — three arms against a live SQL Server.

Purpose: produce real, reproducible measurements distinguishing (B) a prior-art
"sanitize so it errors" neutralization from (C) the claimed method — replacing an
attacker's in-flight statement with a CRAFTED, EXECUTABLE statement that delays
the client and holds the client's memory.

Target: 192.168.1.229:1433 (dbdome-targets test SQL Server 2022). NOT a customer
system. Read-only monitoring login; no server state is modified.

Client-side measurement: the "client" is THIS python process + its ODBC driver.
We measure wall-clock elapsed for the whole request, and the process RSS held at
the moment the result set has been received but not yet released — that is the
memory the attacker's client is forced to hold.

Each arm is run REPEATS times; we report per-run and median. Raw rows are printed
so the declaration can quote exact figures.
"""
import os, sys, time, statistics, gc
import psutil, pyodbc, psycopg2
from cryptography.fernet import Fernet

REPEATS = 5
DELAY_SECONDS = 5          # crafted WAITFOR in arm C
ROWCOUNT_HOLD = 2_000_000  # rows the crafted statement forces the client to buffer

# ---- resolve target credential from the local catalog, decrypt with local key ----
env = {}
with open(r"C:\ProgramData\DBDOME\bin\.env", encoding="utf-8") as fh:
    for line in fh:
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, _, v = line.partition("=")
            env[k.strip()] = v.strip().strip('"').strip("'")

def dec_pg(v):
    return Fernet(env["DBDOME_SECRET_KEY"].encode()).decrypt(v[len("enc:v1:"):].encode()).decode() \
        if isinstance(v, str) and v.startswith("enc:v1:") else v

pgpw = dec_pg(env["PG_PASSWORD"])
conn = psycopg2.connect(host="localhost", port="5432", dbname="dbanalytics",
                        user=env["PG_USER"], password=pgpw)
cur = conn.cursor()
cur.execute("SELECT username, password, port FROM metrics.servers "
            "WHERE server='192.168.1.229' AND db_vendor IN ('mssql','sqlserver') LIMIT 1")
user, enc_pw, port = cur.fetchone()
tpw = dec_pg(enc_pw)
conn.close()

CS = (f"Driver={{ODBC Driver 18 for SQL Server}};Server=192.168.1.229,{port};"
      f"Uid={user};Pwd={tpw};TrustServerCertificate=yes;Encrypt=no;Connection Timeout=30")

proc = psutil.Process()

def rss_mb():
    return proc.memory_info().rss / (1024 * 1024)

def run_arm(label, sql, fetch_all):
    """Returns (elapsed_s, mem_held_delta_mb, outcome). One fresh connection each
    run so nothing carries over. mem_held = RSS after the result is materialized
    minus RSS just before the request — the memory the client is made to hold."""
    gc.collect()
    base = rss_mb()
    cn = pyodbc.connect(CS, timeout=30)
    cur = cn.cursor()
    t0 = time.perf_counter()
    outcome = "completed"
    peak = base
    rows = 0
    try:
        cur.execute(sql)
        if fetch_all:
            data = cur.fetchall()          # force the client to hold the result set
            rows = len(data)
            peak = rss_mb()                # measured WHILE data is still referenced
            del data
        else:
            peak = rss_mb()
    except pyodbc.Error as e:
        outcome = "error: " + e.args[0] if e.args else "error"
        peak = rss_mb()
    elapsed = time.perf_counter() - t0
    cur.close(); cn.close()
    return elapsed, max(0.0, peak - base), outcome, rows

# ---- the three statements -------------------------------------------------------
# A. Baseline: the attacker's own quick statement, unmodified.
SQL_A = "SELECT TOP 1 name FROM sys.databases;"

# B. Prior-art neutralization (Alberstein-style): the statement is altered so that
#    it ERRORS on execution rather than performing its function. We reproduce that
#    outcome faithfully — a delimited / non-executable identifier where a table
#    name belongs, which SQL Server rejects immediately.
SQL_B = "SELECT TOP 1 name FROM [__NEUTRALIZED_UNKNOWN_ELEMENT__];"

# C. Claimed method: replace the statement with a crafted, EXECUTABLE statement
#    that (i) delays the client (WAITFOR DELAY) and (ii) holds significant client
#    memory (a large materialized result set the client must buffer). Both effects
#    are produced by a single executable statement, exactly as claimed.
SQL_C = (
    f"WAITFOR DELAY '00:00:{DELAY_SECONDS:02d}'; "
    f"WITH n(x) AS (SELECT 1 UNION ALL SELECT x+1 FROM n WHERE x < 2048) "
    f"SELECT TOP ({ROWCOUNT_HOLD}) "
    f"  REPLICATE('X', 64) AS payload "
    f"FROM n a CROSS JOIN n b OPTION (MAXRECURSION 0);"
)

ARMS = [
    ("A  baseline (unmodified)",        SQL_A, True),
    ("B  prior-art (errors on exec)",   SQL_B, True),
    ("C  claimed (delay + hold memory)",SQL_C, True),
]

print("=" * 74)
print("NEUTRALIZATION-EFFECT EXPERIMENT")
print(f"Target 192.168.1.229:{port}  login {user}  driver 'ODBC Driver 18 for SQL Server'")
print(f"Repeats per arm: {REPEATS}   crafted delay: {DELAY_SECONDS}s   hold rows: {ROWCOUNT_HOLD:,}")
print("=" * 74)

summary = {}
for label, sql, fetch in ARMS:
    print(f"\n--- ARM {label} ---")
    times, mems, outcome, rowsn = [], [], None, 0
    for i in range(REPEATS):
        el, mem, oc, rows = run_arm(label, sql, fetch)
        times.append(el); mems.append(mem); outcome = oc; rowsn = rows
        print(f"  run {i+1}: elapsed={el:8.3f}s  client_mem_held={mem:8.1f} MB  "
              f"rows={rows:>9,}  {oc[:40]}")
    summary[label] = (statistics.median(times), statistics.median(mems), outcome, rowsn)

print("\n" + "=" * 74)
print("MEDIAN RESULTS")
print("=" * 74)
print(f"{'Arm':<34}{'elapsed (s)':>14}{'client mem held (MB)':>24}")
for label, sql, fetch in ARMS:
    mt, mm, oc, rn = summary[label]
    print(f"{label:<34}{mt:>14.3f}{mm:>24.1f}")

mA = summary[ARMS[0][0]]; mB = summary[ARMS[1][0]]; mC = summary[ARMS[2][0]]
print("\nKEY CONTRASTS")
print(f"  B (prior art) elapsed {mB[0]:.3f}s, mem {mB[1]:.1f} MB  -> {mB[2][:50]}")
print(f"  C (claimed)   elapsed {mC[0]:.3f}s, mem {mC[1]:.1f} MB")
if mB[0] > 0:
    print(f"  C holds the client {mC[0]/max(mB[0],0.001):.0f}x longer than B")
print(f"  C holds {mC[1]-mB[1]:.0f} MB more client memory than B")
