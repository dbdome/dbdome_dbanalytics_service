"""Backfill missing hours in a monthly GMMR table.

Finds hour-buckets that have NO records (within the table's observed
first..last-hour range) and fills each from the NEAREST other day that has
records at the same hour-of-day. Copied rows keep all columns except the
auto-generated `id`; their `entry_date` is set to the MISSING day + the donor
row's time-of-day (so a donor 2026-06-14 03:17:22 becomes 2026-06-15 03:17:22
when filling 2026-06-15 03:00).

Dry-run by default (prints the plan). Pass --apply to insert.

Usage:
  python fill_gmmr_missing_hours.py                       # dry-run, monitoring.gmmr_2026_06
  python fill_gmmr_missing_hours.py --apply
  python fill_gmmr_missing_hours.py --table monitoring.gmmr_2026_07 --apply
"""
import sys
import argparse
import psycopg2

BASE = "C:/dev/dbdome_dbanalytics_service"

# Columns copied from the donor rows (everything EXCEPT the identity `id`).
# entry_date is rewritten to the missing day; the rest are copied verbatim.
COPY_COLS = ["row_id", "server", "category_id", "metric_name", "metric_config",
             "metric_metadata", "entry_date", "metric_metadata_vs_expected",
             "server_id"]

# Shared CTE: missing hours in the observed range + their nearest donor day.
# %(tbl)s is interpolated as a trusted identifier (validated against the catalog).
PLAN_CTE = """
WITH present_hours AS (
    SELECT DISTINCT date_trunc('hour', entry_date) AS h FROM {tbl}
),
bounds AS (
    SELECT date_trunc('hour', min(entry_date)) AS lo,
           date_trunc('hour', max(entry_date)) AS hi FROM {tbl}
),
grid AS (
    SELECT generate_series(lo, hi, interval '1 hour') AS h FROM bounds
),
missing AS (
    SELECT g.h AS missing_hour, g.h::date AS missing_day,
           extract(hour FROM g.h)::int AS hod
    FROM grid g
    LEFT JOIN present_hours p ON p.h = g.h
    WHERE p.h IS NULL
),
donor AS (
    SELECT m.missing_hour, m.missing_day, m.hod, d.donor_day
    FROM missing m
    CROSS JOIN LATERAL (
        SELECT s.entry_date::date AS donor_day
        FROM {tbl} s
        WHERE extract(hour FROM s.entry_date)::int = m.hod
          AND s.entry_date::date <> m.missing_day
        GROUP BY s.entry_date::date
        ORDER BY abs(s.entry_date::date - m.missing_day), s.entry_date::date
        LIMIT 1
    ) d
)
"""


def qualify(cur, table):
    """Validate schema.table exists; return a safely-quoted identifier."""
    if "." not in table:
        sys.exit("--table must be schema-qualified, e.g. monitoring.gmmr_2026_06")
    schema, name = table.split(".", 1)
    cur.execute("SELECT to_regclass(%s)", (f"{schema}.{name}",))
    if cur.fetchone()[0] is None:
        sys.exit(f"table not found: {table}")
    return f'"{schema}"."{name}"'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--table", default="monitoring.gmmr_2026_06")
    ap.add_argument("--apply", action="store_true",
                    help="actually insert (default: dry-run)")
    args = ap.parse_args()

    env = {}
    for line in open(f"{BASE}/.env"):
        line = line.strip()
        if "=" in line and not line.startswith("#"):
            k, v = line.split("=", 1)
            env[k] = v

    conn = psycopg2.connect(host=env["PG_HOST"], port=env["PG_PORT"],
                            user=env["PG_USER"], password=env["PG_PASSWORD"],
                            dbname=env["PG_DB"])
    conn.autocommit = False
    cur = conn.cursor()
    tbl = qualify(cur, args.table)

    # ---- plan: missing hours, donor day, and how many rows each will add ----
    cur.execute(PLAN_CTE.format(tbl=tbl) + """
        SELECT d.missing_hour, d.donor_day,
               (SELECT count(*) FROM {tbl} s
                 WHERE s.entry_date::date = d.donor_day
                   AND extract(hour FROM s.entry_date)::int = d.hod) AS rows_to_add
        FROM donor d ORDER BY d.missing_hour
    """.format(tbl=tbl))
    plan = cur.fetchall()

    print(f"table: {args.table}")
    print(f"missing hours with an available donor: {len(plan)}")
    total = 0
    for missing_hour, donor_day, n in plan:
        total += n
        print(f"   {missing_hour}  <- donor {donor_day}  (+{n} rows)")
    print(f"total rows to insert: {total}")

    if not args.apply:
        print("\nDRY-RUN — nothing inserted. Re-run with --apply to execute.")
        conn.rollback(); cur.close(); conn.close()
        return

    # ---- apply: one atomic INSERT..SELECT copying donor rows into the gap ----
    cols = ", ".join(COPY_COLS)
    insert_sql = PLAN_CTE.format(tbl=tbl) + f"""
        INSERT INTO {tbl} ({cols})
        SELECT s.row_id, s.server, s.category_id, s.metric_name, s.metric_config,
               s.metric_metadata,
               d.missing_day + (s.entry_date - date_trunc('day', s.entry_date))
                   AS entry_date,
               s.metric_metadata_vs_expected, s.server_id
        FROM donor d
        JOIN {tbl} s
          ON s.entry_date::date = d.donor_day
         AND extract(hour FROM s.entry_date)::int = d.hod
    """
    cur.execute(insert_sql)
    inserted = cur.rowcount
    conn.commit()
    print(f"\nAPPLIED — inserted {inserted} rows across {len(plan)} hours.")
    cur.close(); conn.close()


if __name__ == "__main__":
    main()
