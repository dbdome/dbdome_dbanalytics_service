#log4dbexpert.py
import psycopg2
import psycopg2.pool
from datetime import datetime
from utils.config_dotenv import get_connection_string

_server_port_cache = {}
_pool = None


def _get_pool():
    """Get or create a connection pool (lazy init, thread-safe)."""
    global _pool
    if _pool is None or _pool.closed:
        _pool = psycopg2.pool.ThreadedConnectionPool(
            minconn=1, maxconn=5,
            dsn=get_connection_string()
        )
    return _pool


def get_port_for_server(servername):
    """Look up the port for a server name from metrics.servers. Returns port or None."""
    if not servername:
        return None
    if servername in _server_port_cache:
        return _server_port_cache[servername]
    try:
        pool = _get_pool()
        conn = pool.getconn()
        try:
            cur = conn.cursor()
            cur.execute("SELECT port FROM metrics.servers WHERE server = %s LIMIT 1", (servername,))
            row = cur.fetchone()
            port = row[0] if row else None
            _server_port_cache[servername] = port
            cur.close()
            return port
        finally:
            pool.putconn(conn)
    except Exception:
        return None


def db_write_log(message, result, routine, servername, port=None):
    if port:
        servername = f"{servername}:{port}"
    try:
        pool = _get_pool()
        conn = pool.getconn()
        try:
            cur = conn.cursor()
            cur.execute(
                "INSERT INTO log.operation_log (message, level, routine_name, server_name) VALUES (%s, %s, %s, %s)",
                (message, result, routine, servername)
            )
            conn.commit()
            cur.close()
        except Exception as e:
            try:
                conn.rollback()
            except Exception:
                pass
            print(f"insert into log.operation_log failed with error:{e}")
        finally:
            pool.putconn(conn)
    except Exception as e:
        print(f"db_write_log pool error:{e}")