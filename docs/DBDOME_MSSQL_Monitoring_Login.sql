/*=============================================================================
  DBDOME — read-only monitoring login for a Microsoft SQL Server target
  -----------------------------------------------------------------------------
  Creates a least-privilege, READ-ONLY login + per-database users that satisfy
  every shipped DBDOME SQL Server collector / root-cause query, and NOTHING
  more. Run as sysadmin (or securityadmin + a login that can grant the server
  permissions) on the TARGET instance you want DBDOME to monitor.

  >>> RUN IN SQLCMD MODE <<<  This script uses :setvar for the login name and
  password. In SSMS: Query menu -> "SQLCMD Mode". From the command line:
      sqlcmd -S <server> -E -i DBDOME_MSSQL_Monitoring_Login.sql
  If you prefer plain T-SQL, delete the two :setvar lines and replace every
  $(DBDOME_LOGIN) / $(DBDOME_PASSWORD) with your literal values.

  What the collectors actually read (and therefore what is granted):
    - Dynamic management views: sys.dm_exec_sessions / _requests / _connections
      / _sql_text / _query_plan / _query_stats, sys.dm_os_volume_stats,
      sys.dm_io_virtual_file_stats, sys.dm_db_missing_index_*, sys.dm_server_services,
      Extended-Events DMVs            ....... need  VIEW SERVER STATE
    - Security metadata: sys.server_principals, sys.sql_logins (metadata columns
      only — NOT password_hash), sys.server_role_members, sys.database_principals,
      object definitions                       ....... need  VIEW ANY DEFINITION
    - Instance inventory: sys.databases         ....... need  VIEW ANY DATABASE
    - Per-database metadata: INFORMATION_SCHEMA.COLUMNS, sys.columns, sys.types
      (column/schema discovery — metadata only, NO row sampling)
                                                ....... need  a DB user with
                                                              VIEW DEFINITION +
                                                              VIEW DATABASE STATE

  Intentionally NOT granted (keeps it truly read-only / least privilege):
    - db_datareader / SELECT on user data   — collectors read metadata, not rows
    - CONTROL SERVER / sysadmin / securityadmin
    - Any INSERT/UPDATE/DELETE/EXECUTE
  See the notes at the end for the two root causes that would need MORE than this.
=============================================================================*/

SET NOCOUNT ON;
GO

/*-------------------------------------------------------------------
  1. Parameters — EDIT THESE
-------------------------------------------------------------------*/
:setvar DBDOME_LOGIN  "dbdome_monitor"
-- Use a strong password and store it only in DBDOME's encrypted target vault.
:setvar DBDOME_PASSWORD "ChangeMe_Str0ng!Passphrase"

DECLARE @login   sysname = N'$(DBDOME_LOGIN)';
DECLARE @pwd     nvarchar(256) = N'$(DBDOME_PASSWORD)';
DECLARE @sql     nvarchar(max);

/*-------------------------------------------------------------------
  2. Create the LOGIN (SQL authentication)
     For Windows / AD auth instead, comment this block and use:
        CREATE LOGIN [DOMAIN\dbdome_monitor] FROM WINDOWS;
     (no password; the per-DB user loop below works unchanged).
-------------------------------------------------------------------*/
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = @login)
BEGIN
    SET @sql = N'CREATE LOGIN ' + QUOTENAME(@login) +
               N' WITH PASSWORD = ' + QUOTENAME(@pwd, '''') +
               N', CHECK_POLICY = ON, DEFAULT_DATABASE = [master];';
    EXEC sys.sp_executesql @sql;
    PRINT 'Created login ' + @login;
END
ELSE
    PRINT 'Login ' + @login + ' already exists — left as-is.';
GO

/*-------------------------------------------------------------------
  3. SERVER-LEVEL permissions (least privilege for monitoring)
-------------------------------------------------------------------*/
DECLARE @login sysname = N'$(DBDOME_LOGIN)';
DECLARE @g nvarchar(max);
SET @g =
      N'GRANT CONNECT SQL TO '        + QUOTENAME(@login) + N';' + CHAR(10)
    + N'GRANT VIEW SERVER STATE TO '  + QUOTENAME(@login) + N';' + CHAR(10)  -- all DMVs (server + database scope)
    + N'GRANT VIEW ANY DEFINITION TO '+ QUOTENAME(@login) + N';' + CHAR(10)  -- logins/roles/object metadata
    + N'GRANT VIEW ANY DATABASE TO '  + QUOTENAME(@login) + N';';            -- sys.databases visibility
EXEC sys.sp_executesql @g;
PRINT 'Granted server-level: CONNECT SQL, VIEW SERVER STATE, VIEW ANY DEFINITION, VIEW ANY DATABASE';
GO

/*-------------------------------------------------------------------
  4. DATABASE-LEVEL users + grants, in every ONLINE database
     (schema / sensitive-column discovery queries [db].INFORMATION_SCHEMA
      and [db].sys.columns, which require a user in that database).
     tempdb is skipped (transient). Re-run after adding databases, or add
     the same block to a server-level DDL trigger / model if you prefer new
     databases to inherit it automatically.
-------------------------------------------------------------------*/
DECLARE @login2 sysname = N'$(DBDOME_LOGIN)';
DECLARE @db sysname, @cmd nvarchar(max);

DECLARE db_cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT name FROM sys.databases
    WHERE state_desc = 'ONLINE'
      AND database_id <> 2                 -- skip tempdb
      AND source_database_id IS NULL       -- skip snapshots
      AND name NOT IN ('tempdb')
    ORDER BY name;

OPEN db_cur;
FETCH NEXT FROM db_cur INTO @db;
WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        SET @cmd = N'USE ' + QUOTENAME(@db) + N';' + CHAR(10) +
            N'IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = ' + QUOTENAME(@login2, '''') + N')' + CHAR(10) +
            N'    CREATE USER ' + QUOTENAME(@login2) + N' FOR LOGIN ' + QUOTENAME(@login2) + N';' + CHAR(10) +
            N'GRANT CONNECT TO '          + QUOTENAME(@login2) + N';' + CHAR(10) +
            N'GRANT VIEW DATABASE STATE TO ' + QUOTENAME(@login2) + N';' + CHAR(10) +  -- DB-scoped DMVs (missing indexes, etc.)
            N'GRANT VIEW DEFINITION TO '  + QUOTENAME(@login2) + N';';                 -- INFORMATION_SCHEMA / sys.columns metadata
        EXEC sys.sp_executesql @cmd;
        PRINT '  [' + @db + '] user + CONNECT, VIEW DATABASE STATE, VIEW DEFINITION';
    END TRY
    BEGIN CATCH
        PRINT '  [' + @db + '] SKIPPED: ' + ERROR_MESSAGE();   -- e.g. read-only replica / restricted DB
    END CATCH
    FETCH NEXT FROM db_cur INTO @db;
END
CLOSE db_cur;
DEALLOCATE db_cur;
GO

/*-------------------------------------------------------------------
  5. Verify — these must all return 1
-------------------------------------------------------------------*/
EXECUTE AS LOGIN = N'$(DBDOME_LOGIN)';
    SELECT
        HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW SERVER STATE')   AS can_view_server_state,
        HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW ANY DEFINITION') AS can_view_any_definition,
        HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW ANY DATABASE')   AS can_view_any_database,
        HAS_PERMS_BY_NAME(NULL, NULL, 'CONNECT SQL')         AS can_connect;
    -- quick smoke test of the DMVs DBDOME relies on:
    SELECT TOP 1 1 AS dmv_ok FROM sys.dm_exec_sessions;
    SELECT TOP 1 1 AS meta_ok FROM sys.server_principals;
REVERT;
GO

/*=============================================================================
  NOTES — root causes that need MORE than this read-only set
  -----------------------------------------------------------------------------
  The grants above cover every SHIPPED collector. A few specific SQL Server
  root causes, if/when you enable them, need elevated rights the default set
  deliberately excludes:

    * Weak / blank SA-style password checks via PWDCOMPARE(), and reading
      sys.sql_logins.password_hash .................... require CONTROL SERVER
    * Reading native SQL Server Audit *file* contents via sys.fn_get_audit_file
      ................................................. requires CONTROL SERVER
      (reading audit *configuration* — sys.server_audits / specifications —
       is covered by VIEW ANY DEFINITION and needs nothing extra)

  Do NOT grant CONTROL SERVER globally for these. If you need them, grant the
  single elevated permission explicitly and document it, or run those specific
  checks under a separate, tightly-controlled credential.

  To REMOVE this account later:
    -- in each database:  DROP USER [dbdome_monitor];
    -- then at server:    DROP LOGIN [dbdome_monitor];
=============================================================================*/
