"""
GRC Phase 4: Immutable Audit Hash Chain Verifier

Walks log.firewall_audit_log in audit_id order, recomputes each
SHA-256 hash and compares it to the stored row_hash.
Stores the result in log.hash_chain_checkpoints.

Called on demand (UI) or on a slow schedule (e.g. daily).
"""

import hashlib
from utils.log4dbexpert import db_write_log
from utils.config_dotenv import get_connection_string
from processes.hash_chain_writer import _canonical
import psycopg2


def run_hash_chain_verify(start_id: int = 0) -> dict:
    """
    Verify the hash chain from start_id onwards.
    Returns a summary dict:
      { rows_checked, is_valid, broken_at_id, error_detail }
    """
    result = {
        "rows_checked": 0,
        "is_valid": True,
        "broken_at_id": None,
        "error_detail": None,
        "last_hash": None,
        "last_id": None,
    }
    try:
        conn = psycopg2.connect(get_connection_string())
        cur = conn.cursor()

        cur.execute(
            """
            SELECT audit_id, event_time, server_name, db_user,
                   action_taken, risk_score, row_hash, prev_hash
            FROM   log.firewall_audit_log
            WHERE  row_hash IS NOT NULL AND audit_id > %s
            ORDER  BY audit_id ASC
            """,
            (start_id,),
        )
        rows = cur.fetchall()

        prev_hash = None
        for (audit_id, event_time, server_name, db_user,
             action_taken, risk_score, stored_hash, stored_prev) in rows:

            # Check prev_hash linkage
            expected_prev = prev_hash  # None for GENESIS row
            if stored_prev != expected_prev:
                result["is_valid"] = False
                result["broken_at_id"] = audit_id
                result["error_detail"] = (
                    f"prev_hash mismatch at audit_id={audit_id}: "
                    f"stored={stored_prev!r} expected={expected_prev!r}"
                )
                break

            canonical = _canonical(prev_hash, audit_id, event_time,
                                   server_name, db_user, action_taken, risk_score)
            expected_hash = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
            if stored_hash != expected_hash:
                result["is_valid"] = False
                result["broken_at_id"] = audit_id
                result["error_detail"] = (
                    f"hash mismatch at audit_id={audit_id}: "
                    f"stored={stored_hash[:16]}… expected={expected_hash[:16]}…"
                )
                break

            prev_hash = stored_hash
            result["rows_checked"] += 1
            result["last_hash"] = stored_hash
            result["last_id"] = audit_id

        # Persist checkpoint
        if result["last_id"] is not None:
            cur.execute(
                """
                INSERT INTO log.hash_chain_checkpoints
                    (table_name, last_hashed_id, last_hash, rows_hashed,
                     verified_at, is_valid, broken_at_id, error_detail)
                VALUES ('log.firewall_audit_log', %s, %s, %s,
                         NOW(), %s, %s, %s)
                """,
                (
                    result["last_id"],
                    result["last_hash"],
                    result["rows_checked"],
                    result["is_valid"],
                    result["broken_at_id"],
                    result["error_detail"],
                ),
            )
            conn.commit()

        cur.close()
        conn.close()

    except Exception as e:
        result["is_valid"] = False
        result["error_detail"] = str(e)
        db_write_log(f"hash_chain_verifier error: {e}", "", "hash_chain_verifier", "")

    return result
