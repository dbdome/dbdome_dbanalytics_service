"""
RBAC provisioning process (SQL Server).

Given a selected SQL Server + database, this:
  1. Backs up the database to '<default-backup-dir>\\<dbname>_<unix_time>.bak'
     (original name + unix timestamp), so there is a restore point before any
     permission change.
  2. Creates four DATABASE roles in the selected database, each granted only the
     least-privilege permissions its name implies:
        db_readonly       -> SELECT
        db_dataentry      -> SELECT, INSERT, UPDATE, DELETE
        db_manager        -> data CRUD + EXECUTE + create/alter objects (no security admin)
        db_report_viewer  -> SELECT + VIEW DEFINITION
  3. Creates the SERVER role srv_dba and grants it ALTER ANY CONNECTION.

Idempotent: roles are created only if missing; grants re-applied harmlessly.
Connection + credentials come from metrics.servers (decrypted), exactly like the
masking/encryption actions. The registered login must have enough privilege
(backup + CREATE ROLE + CREATE SERVER ROLE); otherwise each failing step is
recorded in metrics.rbac_log and the run continues.

Triggered on demand from the dashboard via the /rbac_provision HTTP endpoint.
"""
import time
import pyodbc
import psycopg2

from utils.config_dotenv import get_connection_string
from utils.secrets_crypto import decrypt_secret
from utils.log4dbexpert import db_write_log

# database role -> least-privilege grants (schema-scoped to dbo). The Transactions
# DENY is guarded so it is harmless on databases that have no such table.
DB_ROLE_GRANTS = {
    "db_readonly":      ["GRANT SELECT ON SCHEMA::dbo TO [db_readonly];"],
    "db_dataentry":     ["GRANT SELECT, INSERT, UPDATE ON SCHEMA::dbo TO [db_dataentry];",
                         "IF OBJECT_ID('dbo.Transactions') IS NOT NULL "
                         "DENY SELECT ON OBJECT::dbo.Transactions TO [db_dataentry];"],
    "db_manager":       ["GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO [db_manager];",
                         "GRANT EXECUTE ON SCHEMA::dbo TO [db_manager];"],
    "db_report_viewer": ["GRANT SELECT ON SCHEMA::dbo TO [db_report_viewer];"],
}

# Each role gets a demo login -> database user -> role membership, so the role's
# permissions are actually usable. Logins are server-wide; on subsequent runs the
# login is reused and only the per-database user + membership are (re)created.
ROLE_LOGIN = {
    "db_readonly":      "app_readonly",
    "db_dataentry":     "app_dataentry",
    "db_manager":       "app_manager",
    "db_report_viewer": "app_report",
}
SRV_LOGIN = "app_dba"                    # mapped to the srv_dba server role
# Default password for the created logins (CHECK_POLICY=ON). Caller can override
# per run via provision_rbac(..., login_password=...). Single quotes are escaped
# before inlining, so any supplied value is safe.
RBAC_LOGIN_PASSWORD = "BgbyO90K4z0q7ICOZplw"


# ---------------------------------------------------------------------------
def _rbac_log(server, database, action, status, detail):
    """Audit each step into metrics.rbac_log (dbanalytics / PostgreSQL)."""
    try:
        conn = psycopg2.connect(get_connection_string())
        conn.autocommit = True
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO metrics.rbac_log (server, database_name, action, status, detail) "
                "VALUES (%s,%s,%s,%s,%s)",
                (server, database, action, status, (detail or "")[:1000]))
        conn.close()
    except Exception as e:
        print("rbac_log failed:", e)


def _resolve_mssql(server):
    """Return (port, username, password_plain, default_db) for the active MSSQL
    instance registered for `server`, or None."""
    conn = psycopg2.connect(get_connection_string())
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT port, username, password, database FROM metrics.servers "
                "WHERE server=%s AND is_active=true AND lower(db_vendor) IN ('mssql','sqlserver') "
                "ORDER BY row_id LIMIT 1", (server,))
            row = cur.fetchone()
    finally:
        conn.close()
    if not row:
        return None
    port, user, pw_enc, ddb = row
    return port, user, decrypt_secret(pw_enc), ddb


def _connect(server, port, user, pw, db="master", timeout=120):
    drivers = pyodbc.drivers()
    drv = next((d for d in ("ODBC Driver 18 for SQL Server", "ODBC Driver 17 for SQL Server",
                            "SQL Server") if d in drivers), None)
    if not drv:
        raise RuntimeError("no suitable ODBC driver installed")
    srv = f"{server},{port}" if port else server
    last = None
    for enc in ("yes", "no"):   # try encrypted first, fall back (older/self-signed instances)
        cs = (f"DRIVER={{{drv}}};SERVER={srv};DATABASE={db or 'master'};UID={user};PWD={pw};"
              f"Encrypt={enc};TrustServerCertificate=yes;Connection Timeout=20;")
        try:
            c = pyodbc.connect(cs, timeout=timeout)
            c.autocommit = True
            return c
        except Exception as e:
            last = e
    raise last


# ---------------------------------------------------------------------------
def provision_rbac(server, database, login_password=None):
    """Back up `database` on `server`, create the least-privilege RBAC roles, then
    create a login per role (given password), CREATE USER for each in the database,
    and add the user to its role. Returns a result dict (also -> metrics.rbac_log)."""
    pw = (login_password or RBAC_LOGIN_PASSWORD).replace("'", "''")   # escape for inline literal
    result = {"server": server, "database": database, "backup": None,
              "db_roles": [], "logins": [], "server_role": None, "errors": []}

    if not server or not database:
        result["errors"].append("server and database are required")
        return result

    info = _resolve_mssql(server)
    if not info:
        msg = "no active MSSQL instance for this server in metrics.servers"
        result["errors"].append(msg)
        _rbac_log(server, database, "resolve", "error", msg)
        return result

    port, user, pw, _ddb = info
    try:
        conn = _connect(server, port, user, pw, "master")
    except Exception as e:
        result["errors"].append(f"connect failed: {e}")
        _rbac_log(server, database, "connect", "error", str(e))
        return result

    cur = conn.cursor()
    try:
        cur.execute("SELECT 1 FROM sys.databases WHERE name = ?", (database,))
        if not cur.fetchone():
            msg = f"database '{database}' not found on {server}"
            result["errors"].append(msg)
            _rbac_log(server, database, "validate", "error", msg)
            return result

        # 1) BACKUP DATABASE [db] TO DISK = '<dir>\<db>_<unix>.bak'
        try:
            unix = int(time.time())
            cur.execute("SELECT CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS nvarchar(4000))")
            bdir = (cur.fetchone()[0] or "").rstrip("\\/")
            sep = "/" if ("/" in bdir and "\\" not in bdir) else "\\"   # Linux vs Windows SQL Server
            bak = (f"{bdir}{sep}{database}_{unix}.bak") if bdir else f"{database}_{unix}.bak"
            cur.execute(
                "DECLARE @db sysname=?, @p nvarchar(4000)=?;"
                "DECLARE @q nvarchar(max);"
                "BEGIN TRY "
                "  SET @q=N'BACKUP DATABASE '+QUOTENAME(@db)+N' TO DISK=N'''+REPLACE(@p,'''','''''')+"
                "         N''' WITH INIT, COMPRESSION, NAME=N''RBAC pre-change backup'';';"
                "  EXEC sys.sp_executesql @q;"
                "END TRY BEGIN CATCH "          # COMPRESSION unsupported on some editions
                "  SET @q=N'BACKUP DATABASE '+QUOTENAME(@db)+N' TO DISK=N'''+REPLACE(@p,'''','''''')+"
                "         N''' WITH INIT, NAME=N''RBAC pre-change backup'';';"
                "  EXEC sys.sp_executesql @q;"
                "END CATCH;", (database, bak))
            while cur.nextset():
                pass
            result["backup"] = bak
            _rbac_log(server, database, "backup", "ok", bak)
        except Exception as e:
            result["errors"].append(f"backup failed: {e}")
            _rbac_log(server, database, "backup", "error", str(e))

        # 2) database roles (least-privilege, schema-scoped) in the selected database
        for role, grants in DB_ROLE_GRANTS.items():
            try:
                body = (f"IF DATABASE_PRINCIPAL_ID('{role}') IS NULL CREATE ROLE [{role}]; "
                        + " ".join(grants))
                cur.execute(
                    "DECLARE @db sysname=?, @body nvarchar(max)=?;"
                    "DECLARE @q nvarchar(max)=N'USE '+QUOTENAME(@db)+N'; '+@body;"
                    "EXEC sys.sp_executesql @q;", (database, body))
                while cur.nextset():
                    pass
                result["db_roles"].append(role)
                _rbac_log(server, database, f"db_role:{role}", "ok", "; ".join(grants))
            except Exception as e:
                result["errors"].append(f"role {role} failed: {e}")
                _rbac_log(server, database, f"db_role:{role}", "error", str(e))

            # login -> CREATE USER -> add to role (makes the role usable)
            login = ROLE_LOGIN.get(role)
            if not login:
                continue
            try:
                # server-scope: create the login with the given password (idempotent)
                cur.execute(f"IF SUSER_ID('{login}') IS NULL "
                            f"CREATE LOGIN [{login}] WITH PASSWORD = '{pw}', CHECK_POLICY = ON;")
                while cur.nextset():
                    pass
                # db-scope: CREATE USER for the login, then add to the role
                ubody = (f"IF DATABASE_PRINCIPAL_ID('{login}') IS NULL "
                         f"CREATE USER [{login}] FOR LOGIN [{login}]; "
                         f"ALTER ROLE [{role}] ADD MEMBER [{login}];")
                cur.execute(
                    "DECLARE @db sysname=?, @body nvarchar(max)=?;"
                    "DECLARE @q nvarchar(max)=N'USE '+QUOTENAME(@db)+N'; '+@body;"
                    "EXEC sys.sp_executesql @q;", (database, ubody))
                while cur.nextset():
                    pass
                result["logins"].append(f"{login}->{role}")
                _rbac_log(server, database, f"login:{login}", "ok", f"CREATE USER + member of {role}")
            except Exception as e:
                result["errors"].append(f"login {login} failed: {e}")
                _rbac_log(server, database, f"login:{login}", "error", str(e))

        # 3) server role srv_dba + GRANT ALTER ANY CONNECTION, with a mapped login
        try:
            cur.execute("IF NOT EXISTS (SELECT 1 FROM sys.server_principals "
                        "WHERE name='srv_dba' AND type='R') CREATE SERVER ROLE [srv_dba];")
            cur.execute("GRANT ALTER ANY CONNECTION TO [srv_dba];")
            cur.execute(f"IF SUSER_ID('{SRV_LOGIN}') IS NULL "
                        f"CREATE LOGIN [{SRV_LOGIN}] WITH PASSWORD = '{pw}', CHECK_POLICY = ON;")
            cur.execute(f"ALTER SERVER ROLE srv_dba ADD MEMBER [{SRV_LOGIN}];")
            while cur.nextset():
                pass
            result["server_role"] = "srv_dba"
            result["logins"].append(f"{SRV_LOGIN}->srv_dba")
            _rbac_log(server, database, "server_role:srv_dba", "ok",
                      f"GRANT ALTER ANY CONNECTION; login {SRV_LOGIN} added")
        except Exception as e:
            result["errors"].append(f"server role srv_dba failed: {e}")
            _rbac_log(server, database, "server_role:srv_dba", "error", str(e))

        db_write_log(
            f"rbac_provision {server}/{database}: backup={result['backup']} "
            f"db_roles={result['db_roles']} logins={result['logins']} "
            f"server_role={result['server_role']} errors={len(result['errors'])}",
            0, "rbac_provisioning", server)
    finally:
        conn.close()
    return result


def restore_database(server, database, backup_file=None):
    """Revert ALL changes by restoring <database> from a backup (the one taken by
    provision_rbac before the RBAC / data-protection changes). This is the revert
    path for irreversible controls - static masking and anonymization - and also
    rolls back masking/tokenization in one shot. If backup_file is omitted, the
    most recent full backup of the database is used. Audited to metrics.rbac_log."""
    result = {"server": server, "database": database, "backup_file": backup_file,
              "status": None, "detail": None}
    info = _resolve_mssql(server)
    if not info:
        result.update(status="error", detail="no active MSSQL instance for this server")
        _rbac_log(server, database, "restore", "error", result["detail"]); return result
    port, user, pw, _ddb = info
    try:
        conn = _connect(server, port, user, pw, "master"); cur = conn.cursor()
        if not backup_file:
            # 1) our own audit trail - the exact path provision_rbac backed up to
            try:
                pconn = psycopg2.connect(get_connection_string())
                with pconn.cursor() as pc:
                    pc.execute("SELECT detail FROM metrics.rbac_log WHERE server=%s AND database_name=%s "
                               "AND action='backup' AND status='ok' ORDER BY row_id DESC LIMIT 1",
                               (server, database))
                    rr = pc.fetchone()
                pconn.close()
                if rr and rr[0]:
                    backup_file = rr[0]
            except Exception as e:
                print("rbac_log backup lookup failed:", e)
        if not backup_file:
            # 2) fall back to msdb backup history
            cur.execute(
                "SELECT TOP 1 mf.physical_device_name FROM msdb.dbo.backupset bs "
                "JOIN msdb.dbo.backupmediafamily mf ON mf.media_set_id = bs.media_set_id "
                "WHERE bs.database_name = ? AND bs.type = 'D' "
                "ORDER BY bs.backup_finish_date DESC", (database,))
            r = cur.fetchone()
            if r:
                backup_file = r[0]
        if not backup_file:
            conn.close(); result.update(status="error", detail=f"no backup found for '{database}'")
            _rbac_log(server, database, "restore", "error", result["detail"]); return result
        result["backup_file"] = backup_file

        # exclusive access, then RESTORE ... WITH REPLACE (overwrites the live DB)
        cur.execute(
            "DECLARE @db sysname=?, @f nvarchar(4000)=?;"
            "DECLARE @q nvarchar(max);"
            "SET @q=N'ALTER DATABASE '+QUOTENAME(@db)+N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE;';"
            "EXEC sys.sp_executesql @q;"
            "SET @q=N'RESTORE DATABASE '+QUOTENAME(@db)+N' FROM DISK=N'''+REPLACE(@f,'''','''''')+"
            "        N''' WITH REPLACE;';"
            "EXEC sys.sp_executesql @q;", (database, backup_file))
        while cur.nextset():
            pass
        try:    # ensure it comes back multi-user (restore usually does this already)
            cur.execute("DECLARE @db sysname=?; DECLARE @q nvarchar(max)="
                        "N'ALTER DATABASE '+QUOTENAME(@db)+N' SET MULTI_USER;'; EXEC sys.sp_executesql @q;",
                        (database,))
            while cur.nextset():
                pass
        except Exception:
            pass
        conn.close()
        result.update(status="ok", detail=f"restored from {backup_file}")
        _rbac_log(server, database, "restore", "ok", f"RESTORE FROM {backup_file}")
        db_write_log(f"restore_database {server}/{database} from {backup_file}", 0, "rbac_provisioning", server)
    except Exception as e:
        result.update(status="error", detail=str(e)[:300])
        _rbac_log(server, database, "restore", "error", result["detail"])
    return result
