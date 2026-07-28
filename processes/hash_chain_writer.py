"""
GRC Phase 4: Immutable Audit Hash Chain Writer

Runs every 60 s. Picks up rows in log.firewall_audit_log that have
row_hash IS NULL and computes a SHA-256 hash chain:

  row_hash = SHA-256( prev_hash | audit_id | event_time | server_name |
                      db_user | action_taken | risk_score )

The first row (no predecessor) uses the literal string "GENESIS" as prev_hash.
"""

import hashlib
from utils.log4dbexpert import db_write_log
from utils.config_dotenv import get_connection_string
import psycopg2


_BATCH = 500   # rows to hash per run


def _canonical(prev_hash: str, audit_id: int, event_time, server_name: str,
                db_user: str, action_taken: str, risk_score: int) -> str:
    return (
        f"{prev_hash or 'GENESIS'}|{audit_id}|{event_time}|"
        f"{server_name or ''}|{db_user or ''}|{action_taken or ''}|{risk_score or 0}"
    )


def run_hash_chain_write():
    try:
        conn = psycopg2.connect(get_connection_string())
        conn.autocommit = False
        cur = conn.cursor()

        # Find the current chain tip (last hashed row)
        cur.execute(
            """
            SELECT audit_id, row_hash
            FROM   log.firewall_audit_log
            WHERE  row_hash IS NOT NULL
            ORDER  BY audit_id DESC
            LIMIT  1
            """
        )
        tip = cur.fetchone()
        prev_id   = tip[0] if tip else 0
        prev_hash = tip[1] if tip else None

        # Fetch next batch of un-hashed rows after the current tip
        cur.execute(
            """
            SELECT audit_id, event_time, server_name, db_user, action_taken, risk_score
            FROM   log.firewall_audit_log
            WHERE  row_hash IS NULL AND audit_id > %s
            ORDER  BY audit_id ASC
            LIMIT  %s
            """,
            (prev_id, _BATCH),
        )
        rows = cur.fetchall()

        if not rows:
            cur.close()
            conn.close()
            return

        for audit_id, event_time, server_name, db_user, action_taken, risk_score in rows:
            canonical = _canonical(prev_hash, audit_id, event_time,
                                   server_name, db_user, action_taken, risk_score)
            new_hash = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
            cur.execute(
                "UPDATE log.firewall_audit_log "
                "SET row_hash=%s, prev_hash=%s WHERE audit_id=%s",
                (new_hash, prev_hash, audit_id),
            )
            prev_hash = new_hash

        conn.commit()
        cur.close()
        conn.close()
        print(f"[hash_chain_writer] hashed {len(rows)} rows, tip={prev_hash[:12]}…")

    except Exception as e:
        db_write_log(f"hash_chain_writer error: {e}", "", "hash_chain_writer", "")
