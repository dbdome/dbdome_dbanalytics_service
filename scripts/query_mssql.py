#!/usr/bin/env python3
r"""
query_mssql.py - tiny portable SQL Server query tool (uses the pyodbc the
collector already ships, so nothing new to install).

Examples:
    python query_mssql.py -S 10.47.57.45 -d master -U sa -Q "SELECT @@VERSION"
    python query_mssql.py -S host,1433 -d mydb -U app -i query.sql
    python query_mssql.py -S host -d mydb -U app --csv -Q "SELECT name FROM sys.databases"
    set MSSQL_PWD=secret  &  python query_mssql.py -S host -d mydb -U app -Q "SELECT 1"

Password resolution order:  -P value  ->  $MSSQL_PWD  ->  interactive prompt
(so it never has to appear in your shell history).

Customer servers usually have a self-signed cert; with a modern
"ODBC Driver NN for SQL Server" this tool sets TrustServerCertificate=yes by
default (the sqlcmd -C equivalent). Pass --no-trust to require a valid cert.
The legacy "SQL Server" driver ignores those options.
"""
import argparse
import csv
import getpass
import os
import sys

import pyodbc


def pick_driver(explicit=None):
    drivers = pyodbc.drivers()
    if explicit:
        if explicit not in drivers:
            sys.exit(f"driver {explicit!r} not installed; available: {drivers}")
        return explicit
    # Prefer the highest-numbered modern driver, else the legacy one.
    modern = sorted((d for d in drivers if d.startswith("ODBC Driver") and "SQL Server" in d),
                    reverse=True)
    if modern:
        return modern[0]
    if "SQL Server" in drivers:
        return "SQL Server"
    sys.exit(f"no SQL Server ODBC driver found; available: {drivers}")


def build_conn_str(args, driver):
    parts = [f"DRIVER={{{driver}}}", f"SERVER={args.server}", f"DATABASE={args.database}"]
    if args.user:
        parts += [f"UID={args.user}", f"PWD={args.password}"]
    else:
        parts.append("Trusted_Connection=yes")        # Windows auth
    # Encryption keywords are only understood by the modern msodbcsql drivers.
    if driver.startswith("ODBC Driver"):
        parts.append("Encrypt=" + ("yes" if args.encrypt else "no"))
        parts.append("TrustServerCertificate=" + ("no" if args.no_trust else "yes"))
    return ";".join(parts) + ";"


def print_table(cols, rows):
    widths = [len(c) for c in cols]
    srows = []
    for r in rows:
        cells = ["" if v is None else str(v) for v in r]
        srows.append(cells)
        for i, c in enumerate(cells):
            widths[i] = max(widths[i], len(c))
    line = "  ".join(c.ljust(widths[i]) for i, c in enumerate(cols))
    print(line)
    print("  ".join("-" * widths[i] for i in range(len(cols))))
    for cells in srows:
        print("  ".join(c.ljust(widths[i]) for i, c in enumerate(cells)))
    print(f"({len(rows)} row{'s' if len(rows) != 1 else ''})")


def main():
    ap = argparse.ArgumentParser(description="Run a query/script against SQL Server via pyodbc.")
    ap.add_argument("-S", "--server", required=True, help="host or host,port")
    ap.add_argument("-d", "--database", default="master")
    ap.add_argument("-U", "--user", help="SQL login (omit for Windows auth)")
    ap.add_argument("-P", "--password", help="password (else $MSSQL_PWD or prompt)")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("-Q", "--query", help="SQL to run")
    g.add_argument("-i", "--input", help="path to a .sql file to run")
    ap.add_argument("--driver", help="force a specific ODBC driver name")
    ap.add_argument("--encrypt", action="store_true", default=True, help="encrypt connection (default)")
    ap.add_argument("--no-encrypt", dest="encrypt", action="store_false")
    ap.add_argument("--no-trust", action="store_true",
                    help="require a valid server cert (default: trust self-signed)")
    ap.add_argument("--timeout", type=int, default=15, help="login timeout seconds (default 15)")
    ap.add_argument("--csv", action="store_true", help="output CSV instead of an aligned table")
    args = ap.parse_args()

    if args.user and not args.password:
        args.password = os.getenv("MSSQL_PWD") or getpass.getpass(f"Password for {args.user}@{args.server}: ")

    sql = open(args.input, encoding="utf-8-sig").read() if args.input else args.query
    driver = pick_driver(args.driver)

    try:
        cn = pyodbc.connect(build_conn_str(args, driver), timeout=args.timeout)
    except pyodbc.Error as e:
        sys.exit(f"connection failed [{driver}]: {e}")

    cur = cn.cursor()
    try:
        cur.execute(sql)
    except pyodbc.Error as e:
        sys.exit(f"query error: {e}")

    first = True
    while True:
        if cur.description:                              # a result set
            cols = [c[0] for c in cur.description]
            rows = cur.fetchall()
            if not first:
                print()
            if args.csv:
                w = csv.writer(sys.stdout, lineterminator="\n")
                w.writerow(cols)
                w.writerows(rows)
            else:
                print_table(cols, rows)
        else:                                            # DML / DDL
            print(f"({cur.rowcount} row(s) affected)")
        first = False
        if not cur.nextset():
            break
    cn.close()


if __name__ == "__main__":
    main()
