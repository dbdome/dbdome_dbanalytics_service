/* =============================================================================
   provision_dbdome_mon_usr_sqlserver.sql

   Creates the DBDOME monitoring login  dbdome_mon_usr  on a Microsoft SQL Server
   and grants it EVERY permission the DBDOME SEC (and health) monitoring root
   causes need to read, across ALL databases, dynamically — including databases
   created in the future.

   RUN THIS ON: the monitored SQL Server (the target), as a sysadmin, once per
   server. It is idempotent — safe to re-run; it only adds what is missing.

   WHAT IT GRANTS (least privilege for read-only monitoring):

     Server level
       CONNECT SQL              login can connect
       VIEW SERVER STATE        all dm_exec_* / dm_os_* / dm_tran_* DMVs
                                (sessions, requests, connections, query_stats,
                                 transactions) — this is the permission whose
                                absence broke SEC-SQL-ACC-011-RC02
       VIEW ANY DEFINITION      server security catalog: server_principals,
                                server_permissions, sql_logins metadata, roles
       VIEW ANY DATABASE        see every database in sys.databases
       ALTER TRACE              read the default trace + errorlog scans that the
                                DDL-audit / AUD-020 root causes depend on
       (2022+) VIEW SERVER PERFORMANCE STATE, VIEW SERVER SECURITY STATE
                                granular replacements SQL 2022 split out of
                                VIEW SERVER STATE — granted only where they exist

     Every database (and model, so new databases inherit it)
       db_datareader            read all user tables/views for inventory checks
       VIEW DATABASE STATE      per-db DMVs and state
       VIEW DEFINITION          database_principals, database_permissions,
                                role members, masked_columns, object metadata

   WHAT IT DOES NOT GRANT (on purpose):
       sysadmin / db_owner / CONTROL SERVER.  A monitoring credential with admin
       rights is itself a security finding (see DBDOME SEC-SQL-AZ / privileged-
       login root causes).  A very small number of checks that read the raw
       password_hash or call certain xp_* need sysadmin; DBDOME does NOT export
       password hashes, so they are intentionally out of scope.  If you must have
       the elevated variant, uncomment SECTION 6.

   PASSWORD: set below. Rotate it and store it encrypted (DBDOME keeps it as
   enc:v1: in metrics.servers).  A plaintext password in a checked-in script is
   itself a finding — treat this file as a template.
   ============================================================================= */

SET NOCOUNT ON;
DECLARE @login   sysname       = N'dbdome_mon_usr';
DECLARE @pwd     nvarchar(128) = N'Yd2243796Anz!!';   -- rotate / parameterize
DECLARE @ver     int           = TRY_CONVERT(int, SERVERPROPERTY('ProductMajorVersion'));
DECLARE @sql     nvarchar(max);
DECLARE @msg     nvarchar(400);

/* ---------- SECTION 1: create or repair the server login ------------------- */
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = @login)
BEGIN
    SET @sql = N'CREATE LOGIN ' + QUOTENAME(@login) +
               N' WITH PASSWORD = ' + QUOTENAME(@pwd, '''') +
               N', CHECK_POLICY = OFF, DEFAULT_DATABASE = [master];';
    EXEC sys.sp_executesql @sql;
    PRINT 'login created: ' + @login;
END
ELSE
    PRINT 'login already exists: ' + @login;

/* ---------- SECTION 2: server-level grants (idempotent) -------------------- */
DECLARE @perm nvarchar(100);
DECLARE @perms TABLE (p nvarchar(100), min_ver int);
INSERT INTO @perms (p, min_ver) VALUES
    (N'CONNECT SQL',                      0),
    (N'VIEW SERVER STATE',                0),
    (N'VIEW ANY DEFINITION',              0),
    (N'VIEW ANY DATABASE',                0),
    (N'ALTER TRACE',                      0),
    (N'VIEW SERVER PERFORMANCE STATE',   16),   -- SQL 2022 granular perms
    (N'VIEW SERVER SECURITY STATE',      16);

DECLARE pc CURSOR LOCAL FAST_FORWARD FOR
    SELECT p FROM @perms WHERE @ver IS NULL OR @ver >= min_ver;
OPEN pc; FETCH NEXT FROM pc INTO @perm;
WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        SET @sql = N'GRANT ' + @perm + N' TO ' + QUOTENAME(@login) + N';';
        EXEC sys.sp_executesql @sql;
    END TRY
    BEGIN CATCH
        SET @msg = '  (skip server grant ' + @perm + ': ' + ERROR_MESSAGE() + ')';
        PRINT @msg;
    END CATCH
    FETCH NEXT FROM pc INTO @perm;
END
CLOSE pc; DEALLOCATE pc;
PRINT 'server-level grants applied';

/* ---------- SECTION 3: per-database provisioning, dynamically -------------- */
/* Covers model too, so every FUTURE database inherits the monitoring user with
   no re-run. Skips databases that are offline / restoring / not accessible. */
DECLARE @db sysname, @qdb nvarchar(258), @done int = 0, @skipped int = 0;

DECLARE dbc CURSOR LOCAL FAST_FORWARD FOR
    SELECT name
    FROM sys.databases
    WHERE state_desc = 'ONLINE'
      AND DATABASEPROPERTYEX(name, 'Updateability') IS NOT NULL
      AND HAS_DBACCESS(name) = 1
      AND name NOT IN (N'tempdb');            -- tempdb is rebuilt on restart

OPEN dbc; FETCH NEXT FROM dbc INTO @db;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @qdb = QUOTENAME(@db);
    BEGIN TRY
        SET @sql = N'
            USE ' + @qdb + N';
            IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @login)
                CREATE USER ' + QUOTENAME(@login) + N' FOR LOGIN ' + QUOTENAME(@login) + N';
            ALTER ROLE [db_datareader] ADD MEMBER ' + QUOTENAME(@login) + N';
            GRANT VIEW DATABASE STATE TO ' + QUOTENAME(@login) + N';
            GRANT VIEW DEFINITION     TO ' + QUOTENAME(@login) + N';';
        EXEC sys.sp_executesql @sql, N'@login sysname', @login = @login;
        SET @done += 1;
    END TRY
    BEGIN CATCH
        SET @skipped += 1;
        SET @msg = '  (skip db ' + @db + ': ' + ERROR_MESSAGE() + ')';
        PRINT @msg;
    END CATCH
    FETCH NEXT FROM dbc INTO @db;
END
CLOSE dbc; DEALLOCATE dbc;

SET @msg = 'per-database provisioning: ' + CAST(@done AS varchar(10)) +
           ' done, ' + CAST(@skipped AS varchar(10)) + ' skipped';
PRINT @msg;

/* ---------- SECTION 4: verification ---------------------------------------- */
PRINT '--- server permissions held by ' + @login + ' ---';
SELECT sp.permission_name, sp.state_desc
FROM sys.server_permissions sp
JOIN sys.server_principals pr ON pr.principal_id = sp.grantee_principal_id
WHERE pr.name = @login
ORDER BY sp.permission_name;

PRINT '--- databases where ' + @login + ' is provisioned ---';
DECLARE @vsql nvarchar(max) = N'';
SELECT @vsql = @vsql + N'
    SELECT ' + QUOTENAME(name, '''') + N' AS database_name,
           CASE WHEN EXISTS (SELECT 1 FROM ' + QUOTENAME(name) +
           N'.sys.database_principals WHERE name = ' + QUOTENAME(@login,'''') +
           N') THEN ''provisioned'' ELSE ''MISSING'' END AS status
    UNION ALL'
FROM sys.databases
WHERE state_desc = 'ONLINE' AND HAS_DBACCESS(name) = 1 AND name <> N'tempdb';
IF LEN(@vsql) > 0
BEGIN
    SET @vsql = LEFT(@vsql, LEN(@vsql) - LEN('UNION ALL')) + N' ORDER BY 1;';
    EXEC sys.sp_executesql @vsql;
END

/* ---------- SECTION 5: future databases (already handled) ------------------ */
/* Because SECTION 3 provisions [model], any database created after this runs
   inherits dbdome_mon_usr automatically. No DDL trigger required. To catch
   databases RESTORED (which do not inherit from model), simply re-run this
   script — it is idempotent — or schedule it. */

/* ---------- SECTION 6 (OPTIONAL, ELEVATED) -- uncomment only if required ----
   A few checks that read raw login password hashes or call certain xp_* need
   sysadmin. DBDOME does not export password hashes, so this is normally
   unnecessary AND makes the monitoring account a privileged-login finding.

   ALTER SERVER ROLE [sysadmin] ADD MEMBER [dbdome_mon_usr];
   --------------------------------------------------------------------------- */
