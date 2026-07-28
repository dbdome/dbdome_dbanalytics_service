#!/usr/bin/env python3
"""
mssql_audit_activity_tester.py -- generate SQL Server activity that trips the
DBDOME audit root-cause detections, for on-site detection testing / demos.

Unlike oracle_rootcause_tester.py (which RUNS read-only detection queries), this
tool GENERATES the audited activity a privileged user would perform, so the
DBDOME collectors detect it on their next cycle and raise the alerts.

Scenarios (SQL Server, vendor 'sqlserver'):
  SEC-SQL-AUD-022-RC01  Unsuccessful authentication  -> failed-password logins
                        (source: error log via xp_readerrorlog 'Login failed')
  SEC-SQL-AUD-024-RC01  SELECT on sensitive table    -> SELECT on a sensitive-named
                        table (source: plan cache dm_exec_query_stats)
  SEC-SQL-AUD-025-RC01  Data change on sensitive tbl -> UPDATE on a sensitive-named
                        table (source: plan cache)
  SEC-SQL-AUD-027-RC01  Destructive op (DROP/etc.)   -> clone+DROP a table and
                        CREATE+DROP a login (source: default trace fn_trace_gettable)

The AUD-024/025 detections match only specific sensitive table-name substrings
(STTM_CUSTOMER, STTM_CUST_ACCOUNT, FSDH_CUSTOMER_BVN, STTM_PERSONAL, STTM_CORPORATE),
so this tool clones the customer's real tables into sensitive-named copies and runs
the SELECT/UPDATE against those so the detections genuinely fire.

Credentials are NOT stored here: pass --password or set MSSQL_SA_PASSWORD.

Usage:
  python scripts/mssql_audit_activity_tester.py \
      --server 192.168.1.229,1433 --user sa --password '***' --database FinTrust
  # add --verify to also run the four detection queries and report their row counts
  # add --cleanup to drop the sensitive-named clone tables afterwards
"""
import argparse
import datetime
import os
import sys
import time

import pyodbc

SENSITIVE_ACCOUNT = "STTM_CUST_ACCOUNT"   # clone of the accounts table (AUD-024 SELECT)
SENSITIVE_CARD    = "STTM_CUSTOMER"       # clone of the cards table    (AUD-025 UPDATE)
LOGIN_NAME        = "destructive_user"

DETECTION_SQL = {
"SEC-SQL-AUD-022-RC01": """SET NOCOUNT ON;
DECLARE @el TABLE (LogDate datetime, ProcessInfo nvarchar(100), LogText nvarchar(4000));
INSERT INTO @el EXEC sys.xp_readerrorlog 0, 1, N'Login failed';
SELECT COUNT(*) FROM @el WHERE LogDate > DATEADD(DAY,-1,GETDATE()) AND LogText LIKE '%destructive_user%';""",
"SEC-SQL-AUD-024-RC01": """SELECT COUNT(*) FROM sys.dm_exec_query_stats qs WITH (NOLOCK)
OUTER APPLY sys.dm_exec_sql_text(qs.sql_handle) st
WHERE qs.last_execution_time >= DATEADD(DAY,-1,GETDATE()) AND st.text IS NOT NULL
  AND st.text NOT LIKE '%dm_exec_query_stats%'
  AND UPPER(st.text) LIKE '%STTM_CUST_ACCOUNT%';""",
"SEC-SQL-AUD-025-RC01": """SELECT COUNT(*) FROM sys.dm_exec_query_stats qs WITH (NOLOCK)
OUTER APPLY sys.dm_exec_sql_text(qs.sql_handle) st
WHERE qs.last_execution_time >= DATEADD(DAY,-1,GETDATE()) AND st.text IS NOT NULL
  AND st.text NOT LIKE '%dm_exec_query_stats%'
  AND UPPER(st.text) LIKE '%UPDATE %' AND UPPER(st.text) LIKE '%STTM_CUSTOMER%';""",
"SEC-SQL-AUD-027-RC01": """SET NOCOUNT ON;
DECLARE @tracefile nvarchar(260), @tracepath nvarchar(260), @sep char(1);
SELECT @tracepath = path FROM sys.traces WHERE is_default=1;
SET @sep = CASE WHEN CHARINDEX('\\', @tracepath) > 0 THEN '\\' ELSE '/' END;
SET @tracefile = SUBSTRING(@tracepath,1,LEN(@tracepath)-CHARINDEX(@sep,REVERSE(@tracepath))) + @sep + 'log.trc';
SELECT COUNT(*) FROM sys.fn_trace_gettable(@tracefile, DEFAULT) t
WHERE t.EventClass IN (47,104,108,109,110,111,115)
  AND t.StartTime >= DATEADD(day,-1,GETDATE())
  AND ISNULL(t.DatabaseName,'') <> 'tempdb';""",
}


def connect(driver, server, uid, pwd, database="master", timeout=20):
    cs = (f"DRIVER={{{driver}}};SERVER={server};UID={uid};PWD={pwd};DATABASE={database};"
          f"Encrypt=yes;TrustServerCertificate=yes;Connection Timeout={timeout};")
    return pyodbc.connect(cs, autocommit=True)


def step(msg):
    print(f"  -> {msg}", flush=True)


def scenario_027(cur, db):
    print("\n[SEC-SQL-AUD-027] destructive operations (clone+DROP table, CREATE+DROP login)")
    ts = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
    clone = f"Cards_clone_{ts}"
    cur.execute(f"SELECT * INTO [{db}].dbo.[{clone}] FROM [{db}].dbo.[Cards]")
    step(f"created clone [{db}].dbo.{clone} ({cur.rowcount} rows copied)")
    cur.execute(f"DROP TABLE [{db}].dbo.[{clone}]")
    step(f"DROP TABLE {clone}  (default-trace EventClass 47 DROP OBJECT)")
    cur.execute(f"IF SUSER_ID('{LOGIN_NAME}') IS NOT NULL DROP LOGIN [{LOGIN_NAME}]")
    cur.execute(f"CREATE LOGIN [{LOGIN_NAME}] WITH PASSWORD='D3str0y$Me_Real1', CHECK_POLICY=OFF")
    step(f"CREATE LOGIN {LOGIN_NAME}  (EventClass 104 LOGIN MGMT)")
    return LOGIN_NAME


def scenario_022(server, driver, db):
    print("\n[SEC-SQL-AUD-022] unsuccessful authentication (wrong-password logins x3)")
    attempts = 0
    for i in range(3):
        try:
            connect(driver, server, LOGIN_NAME, "WrongPassword!" + str(i), db, timeout=8)
            step(f"attempt {i+1}: unexpectedly SUCCEEDED")
        except pyodbc.Error as e:
            sqlstate = e.args[0] if e.args else "?"
            attempts += 1
            step(f"attempt {i+1}: login failed as expected (SQLSTATE {sqlstate})")
        time.sleep(0.3)
    return attempts


def drop_login(cur):
    cur.execute(f"IF SUSER_ID('{LOGIN_NAME}') IS NOT NULL DROP LOGIN [{LOGIN_NAME}]")
    step(f"DROP LOGIN {LOGIN_NAME}  (EventClass 104 DROP LOGIN)")


def scenario_024(cur, db):
    print("\n[SEC-SQL-AUD-024] SELECT on sensitive table")
    cur.execute(f"IF OBJECT_ID('{db}.dbo.{SENSITIVE_ACCOUNT}') IS NOT NULL DROP TABLE [{db}].dbo.[{SENSITIVE_ACCOUNT}]")
    cur.execute(f"SELECT * INTO [{db}].dbo.[{SENSITIVE_ACCOUNT}] FROM [{db}].dbo.[Accounts]")
    step(f"created sensitive-named clone {SENSITIVE_ACCOUNT} from Accounts ({cur.rowcount} rows)")
    for _ in range(2):
        cur.execute(f"SELECT * FROM [{db}].dbo.[{SENSITIVE_ACCOUNT}]")
        cur.fetchall()
    step(f"SELECT * FROM {SENSITIVE_ACCOUNT}  (matches sensitive-name detection)")
    cur.execute(f"SELECT * FROM [{db}].dbo.[Accounts]")   # literal, as requested
    cur.fetchall()
    step("SELECT * FROM Accounts  (literal request; not a detection trigger)")


def scenario_025(cur, db):
    print("\n[SEC-SQL-AUD-025] data change on sensitive table")
    cur.execute(f"IF OBJECT_ID('{db}.dbo.{SENSITIVE_CARD}') IS NOT NULL DROP TABLE [{db}].dbo.[{SENSITIVE_CARD}]")
    cur.execute(f"SELECT * INTO [{db}].dbo.[{SENSITIVE_CARD}] FROM [{db}].dbo.[Cards]")
    step(f"created sensitive-named clone {SENSITIVE_CARD} from Cards ({cur.rowcount} rows)")
    cur.execute(f"UPDATE [{db}].dbo.[{SENSITIVE_CARD}] SET card_type = 'AUDIT_TEST' "
                f"WHERE card_id = (SELECT MIN(card_id) FROM [{db}].dbo.[{SENSITIVE_CARD}])")
    step(f"UPDATE {SENSITIVE_CARD} ({cur.rowcount} row)  (matches sensitive-name detection)")
    cur.execute(f"UPDATE [{db}].dbo.[Cards] SET is_active = is_active "
                f"WHERE card_id = (SELECT MIN(card_id) FROM [{db}].dbo.[Cards])")
    step(f"UPDATE Cards (benign self-assignment, {cur.rowcount} row; literal request)")


def verify(cur):
    print("\n== VERIFY: running the four detection queries as-is ==")
    allhit = True
    for rcid, sql in DETECTION_SQL.items():
        try:
            cur.execute(sql)
            n = cur.fetchone()[0]
            hit = "FIRES" if (n and n > 0) else "no rows"
            if not (n and n > 0):
                allhit = False
            print(f"  {rcid}: row_count={n}  -> {hit}")
        except Exception as e:
            allhit = False
            print(f"  {rcid}: ERROR {str(e).splitlines()[0][:160]}")
    return allhit


def cleanup(cur, db):
    print("\n== CLEANUP: dropping sensitive-named clone tables ==")
    for t in (SENSITIVE_ACCOUNT, SENSITIVE_CARD):
        cur.execute(f"IF OBJECT_ID('{db}.dbo.{t}') IS NOT NULL DROP TABLE [{db}].dbo.[{t}]")
        step(f"dropped {t}")


def main():
    ap = argparse.ArgumentParser(description="DBDOME MSSQL audit-detection activity generator")
    ap.add_argument("--server", default="192.168.1.229,1433")
    ap.add_argument("--user", default="sa")
    ap.add_argument("--password", default=os.getenv("MSSQL_SA_PASSWORD"))
    ap.add_argument("--database", default="FinTrust")
    ap.add_argument("--driver", default="ODBC Driver 18 for SQL Server")
    ap.add_argument("--verify", action="store_true", help="run the detection queries afterwards")
    ap.add_argument("--cleanup", action="store_true", help="drop the sensitive-named clone tables at the end")
    args = ap.parse_args()

    if not args.password:
        print("FATAL: no password (pass --password or set MSSQL_SA_PASSWORD)")
        return 2

    print(f"== DBDOME MSSQL audit activity tester ==")
    print(f"target: {args.server}  db={args.database}  user={args.user}  driver={args.driver}")
    try:
        conn = connect(args.driver, args.server, args.user, args.password, args.database)
        cur = conn.cursor()
    except Exception as e:
        print(f"FATAL: connect failed: {e}")
        return 2

    # 027 first (creates the login), then 022 uses it, then drop the login (027 drop event)
    scenario_027(cur, args.database)
    n_fail = scenario_022(args.server, args.driver, args.database)
    drop_login(cur)
    scenario_024(cur, args.database)
    scenario_025(cur, args.database)

    print(f"\nactivity generated: failed-login attempts={n_fail}")
    rc = 0
    if args.verify:
        # brief pause so the default trace flushes the DROP/login events to log.trc
        time.sleep(3)
        rc = 0 if verify(cur) else 1
    if args.cleanup:
        cleanup(cur, args.database)
    conn.close()
    print("\n== DONE ==")
    print("NOTE: the DBDOME collector runs these detections as dbdome_mon_usr on its "
          "schedule; alerts will appear on the next collection cycle.")
    return rc


if __name__ == "__main__":
    sys.exit(main())
