#log4dbexpert.py
import os
import psycopg2
import psycopg2.pool
from datetime import datetime
from utils.config_dotenv import get_connection_string

_server_port_cache = {}
_pool = None


def _pool_maxconn():
    """Max pooled logging connections. Tunable via env LOG_POOL_MAXCONN (default 50)
    so it can be raised without a rebuild. Postgres max_connections is far higher."""
    try:
        return max(5, int(os.getenv("LOG_POOL_MAXCONN", "50")))
    except (TypeError, ValueError):
        return 50


def _get_pool():
    """Get or create a connection pool (lazy init, thread-safe)."""
    global _pool
    if _pool is None or _pool.closed:
        _pool = psycopg2.pool.ThreadedConnectionPool(
            minconn=1, maxconn=_pool_maxconn(),
            dsn=get_connection_string()
        )
    return _pool


def _acquire(pool):
    """Borrow a connection from the pool. If the pool is momentarily exhausted
    (a burst of concurrent log writes), fall back to a direct short-lived
    connection so logging NEVER drops. Returns (conn, pooled)."""
    try:
        return pool.getconn(), True
    except psycopg2.pool.PoolError:
        return psycopg2.connect(get_connection_string()), False


def _release(pool, conn, pooled):
    try:
        if pooled:
            pool.putconn(conn)
        else:
            conn.close()
    except Exception:
        pass


def get_port_for_server(servername):
    """Look up the port for a server name from metrics.servers. Returns port or None."""
    if not servername:
        return None
    if servername in _server_port_cache:
        return _server_port_cache[servername]
    try:
        pool = _get_pool()
        conn, pooled = _acquire(pool)
        try:
            cur = conn.cursor()
            cur.execute("SELECT port FROM metrics.servers WHERE server = %s LIMIT 1", (servername,))
            row = cur.fetchone()
            port = row[0] if row else None
            _server_port_cache[servername] = port
            cur.close()
            return port
        finally:
            _release(pool, conn, pooled)
    except Exception:
        return None


def db_write_log(message, result, routine, servername, port=None):
    if port:
        servername = f"{servername}:{port}"
    try:
        level = int(result) if result not in (None, "") else 0
    except (TypeError, ValueError):
        level = 0
    try:
        pool = _get_pool()
        conn, pooled = _acquire(pool)
        try:
            cur = conn.cursor()
            cur.execute(
                "INSERT INTO log.operation_log (message, level, routine_name, server_name) VALUES (%s, %s, %s, %s)",
                (message, level, routine, servername)
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
            _release(pool, conn, pooled)
    except Exception as e:
        print(f"db_write_log pool error:{e}")
