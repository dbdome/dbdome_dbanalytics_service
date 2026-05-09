import pyodbc
import psycopg2
import urllib.parse
from collection.mssql.mssql_driver_util import get_installed_driver_by_priority
from utils.log4dbexpert import db_write_log
import oracledb


def get_target_connection(vendor, server, database, username, password, port, auth_type, service_name=None):
    """Return a DB-API connection to a monitored target server."""
    match vendor.lower():
        case "sqlserver" | "mssql":
            return _connect_mssql(server, database, username, password, auth_type)
        case "postgresql" | "postgres":
            return _connect_postgresql(server, database, username, password, port)
        case "oracle":
            return _connect_oracle(server, username, password, port, service_name)
        case "oracle-19c":
            return _connect_oracle(server, username, password, port, service_name, oracle_version="oracle-19c")
        case "oracle-21c":
            return _connect_oracle(server, username, password, port, service_name, oracle_version="oracle-21c")
        case "oracle-23ai":
            return _connect_oracle(server, username, password, port, service_name, oracle_version="oracle-23ai")
        case "mysql" | "mariadb":
            return _connect_mysql(server, database, username, password, port)
        case "informix":
            return _connect_informix(server, database, username, password, port)
        case _:
            raise ValueError(f"Unsupported vendor: {vendor}")


def _connect_mssql(server, database, username, password, auth_type):
    driver = get_installed_driver_by_priority()
    if driver is None:
        raise RuntimeError("No suitable ODBC driver found for SQL Server")

    if auth_type == "win":
        odbc_str = (
            f"DRIVER={{{driver}}};"
            f"SERVER={server};"
            f"DATABASE={database};"
            f"Trusted_Connection=yes;"
            f"Encrypt=yes;"
            f"TrustServerCertificate=yes;"
        )
    else:
        odbc_str = (
            f"DRIVER={{{driver}}};"
            f"SERVER={server};"
            f"DATABASE={database};"
            f"UID={username};"
            f"PWD={password};"
            f"Encrypt=yes;"
            f"TrustServerCertificate=yes;"
        )
    conn = pyodbc.connect(odbc_str, timeout=30)

    # Register output converters for NVARCHAR(MAX)/XML (type -16) and SQL_VARIANT (-150)
    # to avoid 'ODBC SQL type -16 is not yet supported' errors
    def _decode_long_nvarchar(raw):
        if isinstance(raw, bytes):
            return raw.decode("utf-16le", errors="replace")
        return raw

    try:
        conn.add_output_converter(-16, _decode_long_nvarchar)
        conn.add_output_converter(-150, _decode_long_nvarchar)
    except Exception:
        pass

    return conn


def _connect_postgresql(server, database, username, password, port):
    return psycopg2.connect(
        host=server, port=port, dbname=database,
        user=username, password=password,
        connect_timeout=30
    )


def _connect_oracle(server, username, password, port, service_name, oracle_version=None):
    """
    Connect to Oracle. Supports:
      - oracle-19c: tries thin mode first, falls back to thick mode if Oracle Client is available
      - oracle-21c: thin mode (default, no client needed)
      - oracle-23ai: thin mode with enhanced AI/vector features
    """
    import oracledb

    version = (oracle_version or "").lower().strip()
    port = int(port) if port else 1521
    dsn = oracledb.makedsn(server, port, service_name=service_name)

    if version == "oracle-19c":
        # 19c: try thin mode first (works with python-oracledb >= 1.0 against 19c)
        try:
            return oracledb.connect(
                user=username, password=password,
                dsn=dsn,
                tcp_connect_timeout=30
            )
        except oracledb.DatabaseError:
            # Thin mode failed — try thick mode with Oracle Client libraries
            try:
                oracledb.init_oracle_client()
            except oracledb.ProgrammingError:
                pass  # already initialized
            return oracledb.connect(
                user=username, password=password,
                dsn=dsn
            )

    else:
        # Default for 21c, 23ai, and plain "oracle": thin mode
        return oracledb.connect(
            user=username, password=password,
            dsn=dsn,
            tcp_connect_timeout=30
        )


def _connect_mysql(server, database, username, password, port):
    import pymysql
    return pymysql.connect(
        host=server, port=int(port), user=username,
        password=password, database=database,
        connect_timeout=30
    )


def _connect_informix(server, database, username, password, port):
    """
    Connect to IBM Informix using pyodbc with the Informix ODBC driver.
    Requires: IBM Informix Client SDK (CSDK) with ODBC driver installed.
    Alternative: pip install IfxPy for native Informix Python driver.
    """
    port = int(port) if port else 9089

    # Try pyodbc with Informix ODBC driver first
    try:
        odbc_str = (
            f"DRIVER={{IBM INFORMIX ODBC DRIVER}};"
            f"SERVER={server};"
            f"DATABASE={database};"
            f"HOST={server};"
            f"SERVICE={port};"
            f"UID={username};"
            f"PWD={password};"
            f"PROTOCOL=onsoctcp;"
            f"CLIENT_LOCALE=en_US.utf8;"
            f"DB_LOCALE=en_US.utf8;"
        )
        return pyodbc.connect(odbc_str, timeout=30)
    except Exception:
        pass

    # Fallback: try IfxPy (IBM Informix native driver)
    try:
        import IfxPyDbi as dbapi2
        conn = dbapi2.connect(
            f"SERVER={server};DATABASE={database};HOST={server};"
            f"SERVICE={port};UID={username};PWD={password};PROTOCOL=onsoctcp",
            username, password
        )
        return conn
    except ImportError:
        raise RuntimeError(
            "No Informix driver found. Install either:\n"
            "  1. IBM Informix Client SDK (CSDK) with ODBC driver, or\n"
            "  2. pip install IfxPy"
        )
