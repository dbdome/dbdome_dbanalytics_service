"""
Writes events to log.firewall_audit_log.
Uses the same psycopg2 pool as log4dbexpert — no extra connections.
"""

from utils.log4dbexpert import _get_pool


def write_audit_event(
    server_name: str,
    vendor: str,
    db_user: str,
    client_ip: str,
    db_name: str,
    sql_statement: str,
    action_taken: str,
    policy_id=None,
    regulation: str = None,
    session_id: str = None,
    risk_score: int = 0,
):
    """INSERT one row into log.firewall_audit_log. Never raises."""
    try:
        pool = _get_pool()
        conn = pool.getconn()
        try:
            cur = conn.cursor()
            cur.execute(
                """
                INSERT INTO log.firewall_audit_log
                    (server_name, vendor, db_user, client_ip, db_name,
                     sql_statement, matched_policy, action_taken,
                     regulation, session_id, risk_score)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                """,
                (
                    server_name, vendor, db_user, client_ip, db_name,
                    sql_statement[:4000] if sql_statement else None,
                    policy_id, action_taken,
                    regulation, session_id, risk_score,
                ),
            )
            conn.commit()
            cur.close()
        except Exception as e:
            try:
                conn.rollback()
            except Exception:
                pass
            print(f"firewall_audit_writer: INSERT failed: {e}")
        finally:
            pool.putconn(conn)
    except Exception as e:
        print(f"firewall_audit_writer: pool error: {e}")
