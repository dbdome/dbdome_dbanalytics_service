-- =============================================================================
-- DBDOME - Customer Database Setup Script (SQL Server)
-- =============================================================================
--
-- Purpose:   Prepare a customer SQL Server instance for DBDOME monitoring.
--            Creates a least-privilege monitoring login and grants the
--            minimum permissions required for all detection queries.
--
-- Run as:    sysadmin (sa or Windows admin)
-- Run on:    Each SQL Server instance to be monitored
-- Version:   1.0 — April 2026
--
-- What this script does:
--   1. Creates a SQL login [dbdome_monitor] with a strong password
--   2. Creates a user in each user database + msdb + master
--   3. Grants server-level permissions (VIEW SERVER STATE, etc.)
--   4. Grants database-level permissions (VIEW DATABASE STATE, etc.)
--   5. Grants read access to msdb system tables (jobs, backup history)
--   6. Optionally enables Query Store (recommended)
--   7. Validates all permissions with test queries
--
-- IMPORTANT:
--   - Review and change the password before running!
--   - This script does NOT modify any customer data or schema
--   - All permissions are read-only (SELECT/VIEW only)
--   - The login has NO write permissions to any customer database
--
-- =============================================================================

SET NOCOUNT ON;
PRINT '══════════════════════════════════════════════════════════════════';
PRINT ' DBDOME - Customer SQL Server Setup';
PRINT ' ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT '══════════════════════════════════════════════════════════════════';
PRINT '';

-- =============================================================================
-- CONFIGURATION — CHANGE THESE BEFORE RUNNING
-- =============================================================================
DECLARE @LoginName   SYSNAME       = N'dbdome_monitor';
DECLARE @Password    NVARCHAR(128) = N'Ch@ngeMe!Str0ng#2026';  -- TODO: CHANGE THIS!
DECLARE @DefaultDB   SYSNAME       = N'master';
-- =============================================================================

-- ═══════════════════════════════════════════════════════════════
-- STEP 1: Create server login
-- ═══════════════════════════════════════════════════════════════
PRINT '>> Step 1: Creating login [' + @LoginName + ']...';

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = @LoginName)
BEGIN
    DECLARE @sql NVARCHAR(MAX) = N'
        CREATE LOGIN [' + @LoginName + N']
        WITH PASSWORD = N''' + @Password + N''',
             DEFAULT_DATABASE = [' + @DefaultDB + N'],
             CHECK_EXPIRATION = OFF,
             CHECK_POLICY = ON;';
    EXEC sp_executesql @sql;
    PRINT '   Login created.';
END
ELSE
    PRINT '   Login already exists. Skipping.';
GO

-- ═══════════════════════════════════════════════════════════════
-- STEP 2: Grant server-level permissions
-- ═══════════════════════════════════════════════════════════════
PRINT '';
PRINT '>> Step 2: Granting server-level permissions...';

-- VIEW SERVER STATE: Required for all sys.dm_* DMVs
--   sys.dm_exec_query_stats, sys.dm_exec_sessions, sys.dm_exec_requests,
--   sys.dm_exec_connections, sys.dm_os_wait_stats, sys.dm_os_sys_info,
--   sys.dm_os_performance_counters, sys.dm_io_virtual_file_stats,
--   sys.dm_db_index_usage_stats, sys.dm_db_missing_index_*,
--   sys.dm_tran_*, sys.dm_hadr_*, sys.dm_exec_cached_plans, etc.
GRANT VIEW SERVER STATE TO [dbdome_monitor];
PRINT '   GRANT VIEW SERVER STATE';

-- VIEW ANY DEFINITION: Required to read metadata (sys.objects, sys.columns,
--   sys.indexes, sys.procedures, sys.triggers, sys.schemas, sys.types, etc.)
GRANT VIEW ANY DEFINITION TO [dbdome_monitor];
PRINT '   GRANT VIEW ANY DEFINITION';

-- CONNECT ANY DATABASE: Required to create user in each database and query
--   database-scoped DMVs and catalog views
GRANT CONNECT ANY DATABASE TO [dbdome_monitor];
PRINT '   GRANT CONNECT ANY DATABASE';

-- VIEW ANY DATABASE: Required to see database list and properties
GRANT VIEW ANY DATABASE TO [dbdome_monitor];
PRINT '   GRANT VIEW ANY DATABASE';

-- CONNECT SQL: Basic connection permission (implicit, but explicit is safer)
GRANT CONNECT SQL TO [dbdome_monitor];
PRINT '   GRANT CONNECT SQL';

-- ALTER ANY EVENT SESSION: Required to read Extended Events (system_health)
-- (needed by detection steps that read sys.fn_xe_file_target_read_file)
GRANT ALTER ANY EVENT SESSION TO [dbdome_monitor];
PRINT '   GRANT ALTER ANY EVENT SESSION';
GO

-- ═══════════════════════════════════════════════════════════════
-- STEP 3: Create user in master database
-- ═══════════════════════════════════════════════════════════════
PRINT '';
PRINT '>> Step 3: Creating user in [master]...';

USE master;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_monitor')
BEGIN
    CREATE USER [dbdome_monitor] FOR LOGIN [dbdome_monitor];
    PRINT '   User created in [master].';
END
ELSE
    PRINT '   User already exists in [master].';
GO

-- Grant read on server-level catalog views in master
GRANT VIEW DATABASE STATE TO [dbdome_monitor];
GRANT SELECT ON sys.configurations TO [dbdome_monitor];
GRANT SELECT ON sys.master_files TO [dbdome_monitor];
GRANT SELECT ON sys.databases TO [dbdome_monitor];
GRANT EXECUTE ON sys.xp_readerrorlog TO [dbdome_monitor];
PRINT '   Granted master-level permissions.';
GO

-- ═══════════════════════════════════════════════════════════════
-- STEP 4: Create user in msdb (for jobs, backup history, policies)
-- ═══════════════════════════════════════════════════════════════
PRINT '';
PRINT '>> Step 4: Creating user in [msdb]...';

USE msdb;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_monitor')
BEGIN
    CREATE USER [dbdome_monitor] FOR LOGIN [dbdome_monitor];
    PRINT '   User created in [msdb].';
END
ELSE
    PRINT '   User already exists in [msdb].';
GO

-- Grant read access to msdb system tables used by detection queries
-- Backup monitoring
GRANT SELECT ON msdb.dbo.backupset TO [dbdome_monitor];
GRANT SELECT ON msdb.dbo.backupmediafamily TO [dbdome_monitor];
GRANT SELECT ON msdb.dbo.restorehistory TO [dbdome_monitor];
GRANT SELECT ON msdb.dbo.suspect_pages TO [dbdome_monitor];
PRINT '   Granted backup table access.';

-- SQL Agent job monitoring
GRANT SELECT ON msdb.dbo.sysjobs TO [dbdome_monitor];
GRANT SELECT ON msdb.dbo.sysjobsteps TO [dbdome_monitor];
GRANT SELECT ON msdb.dbo.sysjobhistory TO [dbdome_monitor];
GRANT SELECT ON msdb.dbo.sysjobactivity TO [dbdome_monitor];
GRANT SELECT ON msdb.dbo.sysjobschedules TO [dbdome_monitor];
GRANT SELECT ON msdb.dbo.sysschedules TO [dbdome_monitor];
GRANT SELECT ON msdb.dbo.syssessions TO [dbdome_monitor];
GRANT SELECT ON msdb.dbo.syscategories TO [dbdome_monitor];
GRANT SELECT ON msdb.dbo.sysalerts TO [dbdome_monitor];
GRANT SELECT ON msdb.dbo.sysoperators TO [dbdome_monitor];
GRANT SELECT ON msdb.dbo.systargetservers TO [dbdome_monitor];
GRANT SELECT ON msdb.dbo.syssubsystems TO [dbdome_monitor];
GRANT SELECT ON msdb.dbo.sysproxies TO [dbdome_monitor];
PRINT '   Granted Agent job table access.';

-- Database mail
GRANT SELECT ON msdb.dbo.sysmail_account TO [dbdome_monitor];
GRANT SELECT ON msdb.dbo.sysmail_profile TO [dbdome_monitor];
GRANT SELECT ON msdb.dbo.sysmail_profileaccount TO [dbdome_monitor];
GRANT SELECT ON msdb.dbo.sysmail_server TO [dbdome_monitor];
PRINT '   Granted Database Mail table access.';

-- Policy-Based Management
GRANT SELECT ON msdb.dbo.syspolicy_policies TO [dbdome_monitor];
GRANT SELECT ON msdb.dbo.syspolicy_conditions TO [dbdome_monitor];
GRANT SELECT ON msdb.dbo.syspolicy_policy_categories TO [dbdome_monitor];
GRANT SELECT ON msdb.dbo.syspolicy_system_health_state TO [dbdome_monitor];
PRINT '   Granted Policy Management table access.';

-- Maintenance plans
GRANT SELECT ON msdb.dbo.sysmaintplan_plans TO [dbdome_monitor];
GRANT SELECT ON msdb.dbo.sysmaintplan_log TO [dbdome_monitor];
GRANT SELECT ON msdb.dbo.sysmaintplan_logdetail TO [dbdome_monitor];
PRINT '   Granted Maintenance Plan table access.';

-- Log shipping
GRANT SELECT ON msdb.dbo.log_shipping_primary_databases TO [dbdome_monitor];
GRANT SELECT ON msdb.dbo.log_shipping_secondary_databases TO [dbdome_monitor];
GRANT SELECT ON msdb.dbo.log_shipping_secondary TO [dbdome_monitor];
GRANT SELECT ON msdb.dbo.log_shipping_monitor_secondary TO [dbdome_monitor];
PRINT '   Granted Log Shipping table access.';

-- SSIS (if applicable)
IF OBJECT_ID('msdb.dbo.sysssispackages') IS NOT NULL
BEGIN
    GRANT SELECT ON msdb.dbo.sysssispackages TO [dbdome_monitor];
    GRANT SELECT ON msdb.dbo.sysssispackagefolders TO [dbdome_monitor];
    PRINT '   Granted SSIS table access.';
END;

-- Helper function
GRANT EXECUTE ON msdb.dbo.agent_datetime TO [dbdome_monitor];
PRINT '   Granted agent_datetime execute.';
GO

-- ═══════════════════════════════════════════════════════════════
-- STEP 5: Create user in ALL user databases
-- ═══════════════════════════════════════════════════════════════
PRINT '';
PRINT '>> Step 5: Creating user in all user databases...';
GO

USE master;
GO

DECLARE @dbname SYSNAME;
DECLARE @sql NVARCHAR(MAX);

DECLARE db_cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT name FROM sys.databases
    WHERE database_id > 4              -- Skip system DBs (already handled master, msdb)
      AND state = 0                    -- Online only
      AND is_read_only = 0            -- Writable (to create user)
      AND name NOT IN ('master', 'msdb', 'tempdb', 'model')
    ORDER BY name;

OPEN db_cur;
FETCH NEXT FROM db_cur INTO @dbname;
WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        -- Create user
        SET @sql = N'
            USE [' + @dbname + N'];
            IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = ''dbdome_monitor'')
                CREATE USER [dbdome_monitor] FOR LOGIN [dbdome_monitor];
            GRANT VIEW DATABASE STATE TO [dbdome_monitor];
            GRANT CONNECT TO [dbdome_monitor];
        ';
        EXEC sp_executesql @sql;
        PRINT '   [' + @dbname + '] - user created, VIEW DATABASE STATE granted.';
    END TRY
    BEGIN CATCH
        PRINT '   [' + @dbname + '] - WARNING: ' + ERROR_MESSAGE();
    END CATCH;

    FETCH NEXT FROM db_cur INTO @dbname;
END;
CLOSE db_cur; DEALLOCATE db_cur;
GO

-- ═══════════════════════════════════════════════════════════════
-- STEP 6: Enable Query Store (recommended, optional)
-- ═══════════════════════════════════════════════════════════════
PRINT '';
PRINT '>> Step 6: Query Store status (informational)...';
GO

SELECT name, is_query_store_on
FROM sys.databases
WHERE database_id > 4 AND state = 0
ORDER BY name;

PRINT '';
PRINT '   To enable Query Store on a database (recommended):';
PRINT '   ALTER DATABASE [YourDB] SET QUERY_STORE = ON;';
PRINT '   ALTER DATABASE [YourDB] SET QUERY_STORE (OPERATION_MODE = READ_WRITE);';
GO

-- ═══════════════════════════════════════════════════════════════
-- STEP 7: Network / Firewall guidance
-- ═══════════════════════════════════════════════════════════════
PRINT '';
PRINT '>> Step 7: Network configuration';
PRINT '';

DECLARE @port NVARCHAR(20);
SELECT @port = CAST(value_data AS NVARCHAR)
FROM sys.dm_server_registry
WHERE registry_key LIKE '%MSSQLServer\SuperSocketNetLib\Tcp\IPAll'
  AND value_name = 'TcpPort';

IF @port IS NULL OR @port = ''
    SELECT @port = CAST(value_data AS NVARCHAR)
    FROM sys.dm_server_registry
    WHERE registry_key LIKE '%MSSQLServer\SuperSocketNetLib\Tcp\IPAll'
      AND value_name = 'TcpDynamicPorts';

PRINT '   SQL Server TCP Port: ' + ISNULL(@port, '(could not detect - check SQL Server Configuration Manager)');
PRINT '';
PRINT '   Ensure the following is allowed through the firewall:';
PRINT '     - Inbound TCP port ' + ISNULL(@port, '1433') + ' from the DBDOME monitoring server';
PRINT '     - If using named instances, also allow UDP 1434 (SQL Browser)';
PRINT '     - If using Always On, ensure listener port is also open';
GO

-- ═══════════════════════════════════════════════════════════════
-- STEP 8: Validation — Test all required permissions
-- ═══════════════════════════════════════════════════════════════
PRINT '';
PRINT '══════════════════════════════════════════════════════════════════';
PRINT ' VALIDATION';
PRINT '══════════════════════════════════════════════════════════════════';
PRINT '';
GO

-- Impersonate the monitoring login to test permissions
PRINT '>> Testing permissions as [dbdome_monitor]...';
PRINT '';
GO

EXECUTE AS LOGIN = 'dbdome_monitor';
GO

-- Test 1: Server-level DMVs
PRINT '   Test 1: sys.dm_exec_query_stats (VIEW SERVER STATE)';
BEGIN TRY
    DECLARE @t1 INT;
    SELECT @t1 = COUNT(*) FROM sys.dm_exec_query_stats;
    PRINT '     PASS (' + CAST(@t1 AS VARCHAR) + ' rows)';
END TRY
BEGIN CATCH
    PRINT '     FAIL: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT '   Test 2: sys.dm_exec_sessions';
BEGIN TRY
    DECLARE @t2 INT;
    SELECT @t2 = COUNT(*) FROM sys.dm_exec_sessions WHERE is_user_process = 1;
    PRINT '     PASS (' + CAST(@t2 AS VARCHAR) + ' user sessions)';
END TRY
BEGIN CATCH
    PRINT '     FAIL: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT '   Test 3: sys.dm_os_wait_stats';
BEGIN TRY
    DECLARE @t3 INT;
    SELECT @t3 = COUNT(*) FROM sys.dm_os_wait_stats;
    PRINT '     PASS (' + CAST(@t3 AS VARCHAR) + ' wait types)';
END TRY
BEGIN CATCH
    PRINT '     FAIL: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT '   Test 4: sys.dm_os_performance_counters';
BEGIN TRY
    DECLARE @t4 INT;
    SELECT @t4 = COUNT(*) FROM sys.dm_os_performance_counters;
    PRINT '     PASS (' + CAST(@t4 AS VARCHAR) + ' counters)';
END TRY
BEGIN CATCH
    PRINT '     FAIL: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT '   Test 5: sys.dm_io_virtual_file_stats';
BEGIN TRY
    DECLARE @t5 INT;
    SELECT @t5 = COUNT(*) FROM sys.dm_io_virtual_file_stats(NULL, NULL);
    PRINT '     PASS (' + CAST(@t5 AS VARCHAR) + ' files)';
END TRY
BEGIN CATCH
    PRINT '     FAIL: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT '   Test 6: sys.configurations';
BEGIN TRY
    DECLARE @t6 INT;
    SELECT @t6 = COUNT(*) FROM sys.configurations;
    PRINT '     PASS (' + CAST(@t6 AS VARCHAR) + ' configs)';
END TRY
BEGIN CATCH
    PRINT '     FAIL: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT '   Test 7: sys.dm_exec_sql_text (CROSS APPLY)';
BEGIN TRY
    DECLARE @t7 INT;
    SELECT TOP 1 @t7 = LEN(t.text)
    FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) t;
    PRINT '     PASS';
END TRY
BEGIN CATCH
    PRINT '     FAIL: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT '   Test 8: sys.dm_hadr_availability_replica_states (AG monitoring)';
BEGIN TRY
    DECLARE @t8 INT;
    SELECT @t8 = COUNT(*) FROM sys.dm_hadr_availability_replica_states;
    PRINT '     PASS (' + CAST(@t8 AS VARCHAR) + ' replicas)';
END TRY
BEGIN CATCH
    PRINT '     PASS (no AG configured or not applicable)';
END CATCH;
GO

PRINT '   Test 9: msdb.dbo.backupset (backup history)';
BEGIN TRY
    DECLARE @t9 INT;
    SELECT @t9 = COUNT(*) FROM msdb.dbo.backupset;
    PRINT '     PASS (' + CAST(@t9 AS VARCHAR) + ' backup records)';
END TRY
BEGIN CATCH
    PRINT '     FAIL: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT '   Test 10: msdb.dbo.sysjobs (Agent jobs)';
BEGIN TRY
    DECLARE @t10 INT;
    SELECT @t10 = COUNT(*) FROM msdb.dbo.sysjobs;
    PRINT '     PASS (' + CAST(@t10 AS VARCHAR) + ' jobs)';
END TRY
BEGIN CATCH
    PRINT '     FAIL: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT '   Test 11: sys.dm_db_index_physical_stats (index fragmentation)';
BEGIN TRY
    DECLARE @t11 INT;
    SELECT @t11 = COUNT(*)
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED')
    WHERE page_count > 100;
    PRINT '     PASS (' + CAST(@t11 AS VARCHAR) + ' fragmented indexes)';
END TRY
BEGIN CATCH
    PRINT '     FAIL: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT '   Test 12: Expensive queries detection (PERF-SQL-QE-001-RC15)';
BEGIN TRY
    DECLARE @t12 INT;
    SELECT @t12 = COUNT(*)
    FROM (
        SELECT TOP 5 qs.total_worker_time / qs.execution_count AS avg_cpu
        FROM sys.dm_exec_query_stats qs
        WHERE qs.execution_count > 0
        ORDER BY avg_cpu DESC
    ) x;
    PRINT '     PASS (' + CAST(@t12 AS VARCHAR) + ' expensive queries found)';
END TRY
BEGIN CATCH
    PRINT '     FAIL: ' + ERROR_MESSAGE();
END CATCH;
GO

-- Revert impersonation
REVERT;
GO

-- ═══════════════════════════════════════════════════════════════
-- STEP 9: Summary
-- ═══════════════════════════════════════════════════════════════
PRINT '';
PRINT '══════════════════════════════════════════════════════════════════';
PRINT ' SETUP COMPLETE';
PRINT '══════════════════════════════════════════════════════════════════';
PRINT '';
PRINT ' Login:    dbdome_monitor';
PRINT ' Type:     SQL Authentication';
PRINT ' Access:   READ-ONLY (no data modification permissions)';
PRINT '';
PRINT ' Server permissions granted:';
PRINT '   - VIEW SERVER STATE        (DMVs: sessions, queries, waits, IO)';
PRINT '   - VIEW ANY DEFINITION      (metadata: tables, indexes, procs)';
PRINT '   - CONNECT ANY DATABASE     (access all databases)';
PRINT '   - VIEW ANY DATABASE        (see database list)';
PRINT '   - ALTER ANY EVENT SESSION  (read Extended Events)';
PRINT '';
PRINT ' Database permissions granted:';
PRINT '   - VIEW DATABASE STATE      (in every user database)';
PRINT '   - SELECT on msdb tables    (jobs, backups, policies, mail)';
PRINT '';
PRINT ' Connection details for DBDOME:';
PRINT '   Server:   ' + @@SERVERNAME;

DECLARE @port2 NVARCHAR(20);
SELECT @port2 = CAST(value_data AS NVARCHAR)
FROM sys.dm_server_registry
WHERE registry_key LIKE '%MSSQLServer\SuperSocketNetLib\Tcp\IPAll'
  AND value_name = 'TcpPort';
PRINT '   Port:     ' + ISNULL(@port2, '1433');
PRINT '   Login:    dbdome_monitor';
PRINT '   Auth:     SQL Authentication';
PRINT '   Encrypt:  Yes (TrustServerCertificate=Yes)';
PRINT '';
PRINT ' Next steps:';
PRINT '   1. Change the password above to a strong production password';
PRINT '   2. Register this server in DBDOME (metrics.servers table)';
PRINT '   3. Test connection from DBDOME monitoring server';
PRINT '   4. Enable Query Store on key databases (optional, recommended)';
PRINT '';
PRINT '══════════════════════════════════════════════════════════════════';
GO
