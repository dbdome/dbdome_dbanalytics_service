"""
GRC Phase 4: Attestation Period Scheduler

Runs daily. For each active control in config.attestation_controls,
checks whether a new attestation period needs to be opened based on
the control's frequency (MONTHLY / QUARTERLY / SEMI_ANNUAL / ANNUAL).

If the last period for that (control, regulation) ended more than
<frequency> ago, opens a new period and creates PENDING attestation rows
for all relevant controls in that regulation.
"""

from datetime import date, timedelta
from utils.log4dbexpert import db_write_log
from utils.config_dotenv import get_connection_string
import psycopg2


_FREQ_DAYS = {
    "MONTHLY":     30,
    "QUARTERLY":   90,
    "SEMI_ANNUAL": 180,
    "ANNUAL":      365,
}

_FREQ_LABEL = {
    "MONTHLY":     "Monthly",
    "QUARTERLY":   "Q",
    "SEMI_ANNUAL": "H",
    "ANNUAL":      "Annual",
}


def _period_name(freq: str, start: date) -> str:
    if freq == "QUARTERLY":
        q = (start.month - 1) // 3 + 1
        return f"Q{q} {start.year}"
    if freq == "SEMI_ANNUAL":
        h = 1 if start.month <= 6 else 2
        return f"H{h} {start.year}"
    if freq == "ANNUAL":
        return str(start.year)
    return start.strftime("%Y-%m")  # MONTHLY


def run_attestation_scheduler():
    try:
        conn = psycopg2.connect(get_connection_string())
        cur  = conn.cursor()

        today = date.today()

        # Load active controls grouped by (regulation, frequency)
        cur.execute(
            """
            SELECT regulation, attestation_frequency,
                   array_agg(control_id) AS control_ids,
                   array_agg(control_name) AS control_names
            FROM   config.attestation_controls
            WHERE  is_active = TRUE
            GROUP  BY regulation, attestation_frequency
            """
        )
        groups = cur.fetchall()

        periods_opened = 0

        for regulation, freq, control_ids, control_names in groups:
            freq_days = _FREQ_DAYS.get(freq, 90)

            # Find the most recent period for this regulation+freq
            cur.execute(
                """
                SELECT MAX(period_end) FROM config.attestation_periods
                WHERE regulation=%s
                """,
                (regulation,),
            )
            row = cur.fetchone()
            last_end = row[0] if row and row[0] else None

            # Open a new period if none exists or last ended >= freq_days ago
            if last_end is None or (today - last_end).days >= freq_days:
                period_start = (last_end + timedelta(days=1)) if last_end else today
                period_end   = period_start + timedelta(days=freq_days - 1)
                due_date     = period_end + timedelta(days=14)  # 2-week review window
                pname        = _period_name(freq, period_start)

                cur.execute(
                    """
                    INSERT INTO config.attestation_periods
                        (period_name, period_start, period_end, due_date, regulation, status)
                    VALUES (%s,%s,%s,%s,%s,'OPEN')
                    RETURNING period_id
                    """,
                    (pname, period_start, period_end, due_date, regulation),
                )
                period_id = cur.fetchone()[0]

                # Create PENDING attestation rows for each control
                for ctrl_id, ctrl_name in zip(control_ids, control_names):
                    cur.execute(
                        """
                        INSERT INTO log.attestations
                            (period_id, control_id, control_name, regulation,
                             attestation_status)
                        VALUES (%s,%s,%s,%s,'PENDING')
                        """,
                        (period_id, ctrl_id, ctrl_name, regulation),
                    )

                conn.commit()
                print(f"[attestation_scheduler] opened period '{pname}' "
                      f"for {regulation} ({len(control_ids)} controls)")
                periods_opened += 1

        if not periods_opened:
            print("[attestation_scheduler] no new periods needed")

        cur.close()
        conn.close()

    except Exception as e:
        db_write_log(f"attestation_scheduler error: {e}", "", "attestation_scheduler", "")
