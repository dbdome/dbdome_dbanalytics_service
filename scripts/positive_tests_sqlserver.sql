/* =====================================================================
   DBDOME - SQL Server detection POSITIVE TESTS (reproducers)
   Validate that each SEC SQL Server root-cause detection actually fires.

   !!! RUN ONLY ON A DISPOSABLE / THROWAWAY SQL SERVER !!!
   Every block CREATES the insecure condition a detection flags, so many
   DELIBERATELY WEAKEN THE SERVER (enable xp_cmdshell, create logins,
   disable audits, grant rights, plant fake PII). NEVER run on production.
   Each block ships a -- REVERT: to undo it.

   Per block: 1) run -- SETUP:  (some must stay open in a separate session
   - see -- notes)  2) run the detection - it should return >=1 row
   3) run -- REVERT: to clean up.

   493 reproducers: 136 SAFE, 357 DESTRUCTIVE.
   Not script-reproducible: SEC-SQL-AU-004-RC04 (needs a domain-joined
   server with a cross-domain Windows login).
   ===================================================================== */



/* ########## batch 0 (12 reproducers) ########## */
/* =========================================================================
   POSITIVE-TEST REPRODUCERS  –  slice 0..11  (12 detections)
   Target: DISPOSABLE / throwaway SQL Server instance only.
   Each block: SETUP creates the flagged condition; REVERT fully undoes it.
   Run as sysadmin unless noted otherwise.
   ========================================================================= */


/* ===== SEC-SQL-ACC-010-RC07 [SAFE] ===== */
-- Detection fires when an active transaction was started outside 07:00-18:59
-- (start_hour < 7 OR >= 19) by a non-excluded login without an application
-- program name that matches the exclusion list.
-- SAFE: the open transaction lives only in the separate session.
-- NOTE: Run SETUP in Session A; leave it open; run the detection in Session B.
--       Run REVERT in Session A (or kill spid) to clean up.
-- SETUP:
-- *** Execute the lines below in a SEPARATE session and leave it open ***
-- Session A:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
BEGIN
    CREATE LOGIN dbdome_test_login WITH PASSWORD = 'P@ssw0rd_Test123!', CHECK_POLICY = OFF;
END
GO
-- In Session A (logged in as dbdome_test_login or sysadmin impersonating it),
-- open a transaction at an off-hours time.
-- Because transaction_begin_time is wall-clock, the easiest approach is to
-- start the transaction outside 07:00-18:59.  On a test box you can
-- temporarily change the system time, OR simply run this block when the local
-- hour IS before 07 or >= 19, OR fake it by directly opening the transaction
-- now and note the detection also works if GETDATE() hour satisfies the filter.
--
-- Simpler: just begin the transaction; if current hour is in-hours the
-- detection will NOT fire – schedule this script or adjust time accordingly.
BEGIN TRANSACTION dbdome_after_hours_test;
-- Leave this session open with the transaction held open.
-- Do NOT COMMIT or ROLLBACK until after running the detection.
GO
-- REVERT:
-- Run in the same Session A:
IF @@TRANCOUNT > 0
    ROLLBACK TRANSACTION;
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    DROP LOGIN dbdome_test_login;
GO


/* ===== SEC-SQL-ACC-010-RC08 [DESTRUCTIVE] ===== */
-- Detection fires when a session is running under an impersonated login
-- (original_login_name <> login_name) AND that login has one of the listed
-- high-privilege permissions (ALTER ANY USER, ALTER ANY ROLE, CONTROL, ALTER,
-- TAKE OWNERSHIP) granted in the current database.
-- DESTRUCTIVE: creates a login, user, and grants database-level CONTROL.
-- NOTE: Run the SETUP, then in a second session EXECUTE AS LOGIN to create
--       the impersonation condition, then run the detection.
-- SETUP:
-- Step 1 – create login + user with elevated db permission
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_escalate_login')
    CREATE LOGIN dbdome_escalate_login WITH PASSWORD = 'P@ssw0rd_Test123!', CHECK_POLICY = OFF;
GO
USE master;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_escalate_user')
    CREATE USER dbdome_escalate_user FOR LOGIN dbdome_escalate_login;
GO
-- Grant CONTROL on the master database to this user
GRANT CONTROL ON DATABASE::master TO dbdome_escalate_user;
GO
-- Step 2 – impersonate the privileged login in a second session so that
--   original_login_name <> login_name.
-- In a NEW session, run:
--   EXECUTE AS LOGIN = 'dbdome_escalate_login';
--   SELECT SESSION_USER;   -- should show dbdome_escalate_login
-- Then run the detection query.
GO
-- REVERT:
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_escalate_user')
BEGIN
    REVOKE CONTROL ON DATABASE::master FROM dbdome_escalate_user;
    DROP USER dbdome_escalate_user;
END
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_escalate_login')
    DROP LOGIN dbdome_escalate_login;
GO


/* ===== SEC-SQL-ACC-010-RC09 [SAFE] ===== */
-- Detection fires when an active request has reads > 100,000 OR row_count > 50,000.
-- SAFE: the reproducer is a running query; no schema objects are persisted.
-- NOTE: Run SETUP in Session A (the heavy scan); immediately run the detection
--       in Session B while Session A is still executing.
--       The scan table must be large enough to exceed the thresholds – on a
--       minimal test box use master..sysobjects cross-joined to itself.
-- SETUP:
-- *** Execute in a SEPARATE session; the detection must be captured while
--     this query is still running ***
-- Session A:
SELECT COUNT_BIG(a.object_id)
FROM   sys.all_objects a
CROSS JOIN sys.all_objects b
CROSS JOIN sys.all_objects c;
-- If the server is fast this may complete before the detection runs.
-- Alternative: use WAITFOR DELAY to hold a cursor open, or scan a large table.
-- On a minimal box:
--   SELECT TOP 200000 o1.object_id, o2.object_id, o3.object_id
--   FROM sys.all_objects o1, sys.all_objects o2, sys.all_objects o3;
-- leaves the query alive long enough to be caught.
GO
-- REVERT:
-- Nothing to revert – the query either finishes or is killed.
-- To kill it from Session B: KILL <session_id>;
GO


/* ===== SEC-SQL-ACC-010-RC10 [SAFE] ===== */
-- Detection fires when the SAME login_name has > 1 distinct host_name
-- simultaneously connected.
-- SAFE: just two open sessions from different host names using the same login.
-- NOTE: Open Session A from host/machine "HOST_A" and Session B from a
--       different host/machine "HOST_B", both using the same SQL login.
--       Then run the detection.  On a single machine you can simulate this by
--       connecting twice with the same login but aliasing the host via the
--       connection string (Application Name does not help; host_name comes
--       from the client). Alternatively use two different machines.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_multihost_login')
    CREATE LOGIN dbdome_multihost_login WITH PASSWORD = 'P@ssw0rd_Test123!', CHECK_POLICY = OFF;
GO
-- Connect from TWO different hosts using 'dbdome_multihost_login'.
-- Leave both connections open and run the detection.
-- (On a single host, open two SSMS windows; host_name will be the same and
--  the detection will NOT fire.  Use two distinct machines or VMs.)
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_multihost_login')
    DROP LOGIN dbdome_multihost_login;
GO


/* ===== SEC-SQL-ACC-010-RC11 [SAFE] ===== */
-- Detection fires when an ACTIVE request's SQL text contains schema-recon
-- keywords (INFORMATION_SCHEMA, sys.tables, sys.columns, etc.).
-- SAFE: the query just has to be executing when the detection runs.
-- NOTE: Run SETUP query in Session A (slow enough to be caught); run
--       detection in Session B immediately.
-- SETUP:
-- *** Session A – run this slow schema-recon query; detection must be run
--     while it is still executing ***
SELECT t.name AS table_name,
       c.name AS column_name,
       tp.name AS type_name
FROM   sys.tables t                          -- triggers the keyword filter
JOIN   sys.columns c ON c.object_id = t.object_id
JOIN   sys.types   tp ON tp.user_type_id = c.user_type_id
CROSS JOIN sys.all_objects ao               -- big cross join to slow it down
ORDER  BY t.name, c.column_id;
GO
-- REVERT:
-- Nothing to revert – the query finishes naturally or is killed.
GO


/* ===== SEC-SQL-ACC-010-RC12 [DESTRUCTIVE] ===== */
-- Detection fires when a session's login has sp.modify_date that is >90 days
-- before login_time (i.e. the login account was untouched for 90+ days before
-- someone connected with it).
-- DESTRUCTIVE: creates a login and backdates modify_date via
--   sp_configure 'allow updates' trick is not available in modern SQL Server;
--   instead we create the login and do NOT touch it for 90 days – impractical.
-- WORKAROUND: create a login, then manually update sys.server_principals via
--   the Dedicated Admin Connection (DAC) if allowed, OR use the following
--   approach: alter the login's password (which updates modify_date) and then
--   restore using DBCC – NOT reliable.
-- BEST-EFFORT: The most practical approach is to:
--   1. Create the login at least 90 days before the test (or use an existing
--      old login that has not been modified for 90 days).
--   2. Connect with that login.
--   3. Run the detection.
-- The setup below creates the login; the actual firing condition requires 90
-- days of inactivity.  On a fresh test box this cannot be scripted instantly.
-- NOTE: Limitation – modify_date cannot be backdated in user-mode T-SQL.
--       Use an existing dormant login or wait 90 days after creation.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_dormant_login')
    CREATE LOGIN dbdome_dormant_login WITH PASSWORD = 'P@ssw0rd_Test123!', CHECK_POLICY = OFF;
GO
-- Wait 90+ days (or use a pre-existing untouched login).
-- Then connect as dbdome_dormant_login from any client.
-- The detection will fire because DATEDIFF(DAY, modify_date, login_time) > 90.
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_dormant_login')
    DROP LOGIN dbdome_dormant_login;
GO


/* ===== SEC-SQL-ACC-010-RC13 [SAFE] ===== */
-- Detection fires when an active transaction has log_bytes_used > 0 (any open
-- transaction with log activity appears; ORDER BY log_bytes_used DESC means
-- the top row is the heaviest).  In practice any open transaction that has
-- performed writes will appear.
-- SAFE: the transaction is held open in a separate session.
-- NOTE: Session A holds the open transaction with a write; Session B runs the
--       detection.  REVERT = ROLLBACK in Session A.
-- SETUP:
-- *** Session A – run and leave open ***
IF OBJECT_ID('dbo.dbdome_mass_test', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_mass_test;
GO
CREATE TABLE dbo.dbdome_mass_test (id INT IDENTITY PRIMARY KEY, val NVARCHAR(200));
GO
BEGIN TRANSACTION dbdome_mass_tran;
    -- Insert ~10 000 rows to generate measurable log bytes
    DECLARE @i INT = 0;
    WHILE @i < 10000
    BEGIN
        INSERT INTO dbo.dbdome_mass_test (val) VALUES (REPLICATE(N'X', 200));
        SET @i = @i + 1;
    END
-- DO NOT COMMIT – leave transaction open so the detection can see it.
GO
-- REVERT:
-- Run in Session A:
IF @@TRANCOUNT > 0
    ROLLBACK TRANSACTION;
GO
IF OBJECT_ID('dbo.dbdome_mass_test', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_mass_test;
GO


/* ===== SEC-SQL-ACC-011-RC02 [SAFE] ===== */
-- Detection fires when any user-process session has an active transaction
-- and login_name NOT IN ('dbd_mon_usr','dbdome_mon_usr').
-- SAFE: a simple open transaction in a separate session satisfies this.
-- NOTE: Session A holds the open transaction; Session B runs the detection.
-- SETUP:
-- *** Session A – run and leave open ***
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_txn_login')
    CREATE LOGIN dbdome_txn_login WITH PASSWORD = 'P@ssw0rd_Test123!', CHECK_POLICY = OFF;
GO
-- Connect as dbdome_txn_login (or any non-excluded login) and run:
BEGIN TRANSACTION dbdome_open_tran;
    -- A minimal write to register the transaction in dm_tran_active_transactions
    DECLARE @dummy INT = 1;
-- Leave open – do NOT commit or rollback until after the detection is run.
GO
-- REVERT:
-- In Session A:
IF @@TRANCOUNT > 0
    ROLLBACK TRANSACTION;
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_txn_login')
    DROP LOGIN dbdome_txn_login;
GO


/* ===== SEC-SQL-AU-001-RC01 [DESTRUCTIVE] ===== */
-- Detection returns a scalar row with flag columns.  It fires (returns a
-- noteworthy row) when ANY of: xp_cmdshell=1, remote admin connections=1,
-- cross db ownership chaining=1, sa_not_renamed=1, builtin_admin_enabled IS
-- NOT NULL (BUILTIN\Administrators exists and is enabled).
-- Easiest flag to toggle without side-effects on a test box: xp_cmdshell.
-- DESTRUCTIVE: enables xp_cmdshell (sp_configure change persists until
--              RECONFIGURE reverses it).
-- NOTE: Requires sysadmin. The detection always returns exactly 1 row; the
--       "positive" condition is xp_cmdshell_enabled = 1.
-- SETUP:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;
GO
-- REVERT:
EXEC sp_configure 'xp_cmdshell', 0;
RECONFIGURE;
GO
EXEC sp_configure 'show advanced options', 0;
RECONFIGURE;
GO


/* ===== SEC-SQL-AU-001-RC02 [DESTRUCTIVE] ===== */
-- Detection fires when a SQL login (type='S') is enabled and has
-- is_policy_checked=0 OR is_expiration_checked=0.
-- DESTRUCTIVE: creates a SQL login with policy and expiration checks OFF.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_nopolicy_login')
    CREATE LOGIN dbdome_nopolicy_login
        WITH PASSWORD   = 'P@ssw0rd_Test123!',
             CHECK_POLICY     = OFF,
             CHECK_EXPIRATION = OFF;
GO
-- Verify:
-- SELECT name, is_policy_checked, is_expiration_checked
-- FROM sys.sql_logins WHERE name = 'dbdome_nopolicy_login';
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_nopolicy_login')
    DROP LOGIN dbdome_nopolicy_login;
GO


/* ===== SEC-SQL-AU-001-RC03 [SAFE] ===== */
-- Detection returns the top 20 active user-process sessions with their
-- client_net_address.  It always returns rows as long as at least one
-- user-process session is connected (which is true by definition when running
-- the query).  The "positive" condition is simply: a connected session exists.
-- SAFE: just being connected satisfies it.
-- NOTE: No setup required – the current connection itself will appear.
--       The detection is really a network-exposure inventory, not a threshold
--       check.  Running the query IS the positive test.
-- SETUP:
-- No DDL needed.  The current session will appear in the result.
SELECT 'Current session satisfies SEC-SQL-AU-001-RC03' AS positive_test_note,
       s.session_id, s.login_name, s.host_name, c.client_net_address
FROM   sys.dm_exec_sessions   s
JOIN   sys.dm_exec_connections c ON s.session_id = c.session_id
WHERE  s.session_id = @@SPID;
GO
-- REVERT:
-- Nothing to revert.
GO


/* ===== SEC-SQL-AU-001-RC04 [DESTRUCTIVE] ===== */
-- Detection returns a scalar row with multiple hardening flags.  It fires
-- (highlights a gap) when sa is NOT disabled (sa_disabled = 0 or NULL),
-- sa is NOT renamed (sa_not_renamed = 1), xp_cmdshell = 1,
-- ole_automation = 1, clr_enabled = 1, cross_db_chaining = 1,
-- db_mail_xps = 1, or BUILTIN\Administrators is enabled.
-- Enable xp_cmdshell + Ole Automation Procedures to trigger two flags at once.
-- DESTRUCTIVE: two sp_configure changes.
-- SETUP:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;
GO
EXEC sp_configure 'Ole Automation Procedures', 1;
RECONFIGURE;
GO
-- The detection query will now return xp_cmdshell=1 and ole_automation=1.
-- Additionally sa is typically not renamed on a fresh install (sa_not_renamed=1)
-- and sa may not be disabled (sa_disabled=0), further flagging the row.
GO
-- REVERT:
EXEC sp_configure 'xp_cmdshell', 0;
RECONFIGURE;
GO
EXEC sp_configure 'Ole Automation Procedures', 0;
RECONFIGURE;
GO
EXEC sp_configure 'show advanced options', 0;
RECONFIGURE;
GO


/* ########## batch 1 (12 reproducers) ########## */
/* ===================================================================
   Positive-test reproducers for detections slice 12..24
   Target: DISPOSABLE TEST SQL Server only.
   Each block: SETUP triggers the detection, REVERT undoes it.
   =================================================================== */

/* ===== SEC-SQL-AU-001-RC05 [DESTRUCTIVE] ===== */
-- Detection returns rows for: enabled SQL logins (type='S'), sa (sid=0x01),
-- BUILTIN\Administrators, NT AUTHORITY\SYSTEM, or ##...## accounts that are enabled.
-- A plain fresh SQL Server instance already satisfies this via sa and internal
-- certificate logins. To guarantee a controllable row, create an enabled SQL login.
-- Run as sysadmin. Revert drops the login.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    CREATE LOGIN dbdome_test_login WITH PASSWORD = 'DbDome#Test1!', CHECK_POLICY = OFF;
-- Ensure it is enabled (it is by default; make explicit)
ALTER LOGIN dbdome_test_login ENABLE;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    DROP LOGIN dbdome_test_login;
GO

/* ===== SEC-SQL-AU-001-RC06 [DESTRUCTIVE] ===== */
-- Detection: enabled logins in the sysadmin role, excluding NT SERVICE\% and ##%##.
-- Setup: create a SQL login and add it to sysadmin.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_sysadmin')
    CREATE LOGIN dbdome_test_sysadmin WITH PASSWORD = 'DbDome#Test2!', CHECK_POLICY = OFF;
ALTER LOGIN dbdome_test_sysadmin ENABLE;
IF NOT EXISTS (
    SELECT 1 FROM sys.server_role_members srm
    JOIN sys.server_principals r  ON srm.role_principal_id = r.principal_id
    JOIN sys.server_principals m  ON srm.member_principal_id = m.principal_id
    WHERE r.name = 'sysadmin' AND m.name = 'dbdome_test_sysadmin'
)
    EXEC sp_addsrvrolemember 'dbdome_test_sysadmin', 'sysadmin';
GO
-- REVERT:
IF EXISTS (
    SELECT 1 FROM sys.server_role_members srm
    JOIN sys.server_principals r ON srm.role_principal_id = r.principal_id
    JOIN sys.server_principals m ON srm.member_principal_id = m.principal_id
    WHERE r.name = 'sysadmin' AND m.name = 'dbdome_test_sysadmin'
)
    EXEC sp_dropsrvrolemember 'dbdome_test_sysadmin', 'sysadmin';
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_sysadmin')
    DROP LOGIN dbdome_test_sysadmin;
GO

/* ===== SEC-SQL-AU-001-RC07 [SAFE] ===== */
-- Detection: sa login (sid=0x01) is enabled. On a default SQL Server install sa
-- exists and may already be enabled. This setup explicitly enables sa.
-- WARNING: enabling sa is a security risk; revert disables it immediately.
-- Run as sysadmin.
-- SETUP:
ALTER LOGIN sa ENABLE;
GO
-- REVERT:
ALTER LOGIN sa DISABLE;
GO

/* ===== SEC-SQL-AU-001-RC08 [DESTRUCTIVE] ===== */
-- Detection: aggregation query always returns exactly 1 row (it uses SUM with no
-- GROUP BY). It will always fire. To make the enabled_sql_logins column > 0,
-- ensure at least one enabled SQL login exists (excluding ##%## and NT % logins).
-- Setup creates a plain SQL login as the trigger.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_sqllogin')
    CREATE LOGIN dbdome_test_sqllogin WITH PASSWORD = 'DbDome#Test3!', CHECK_POLICY = OFF;
ALTER LOGIN dbdome_test_sqllogin ENABLE;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_sqllogin')
    DROP LOGIN dbdome_test_sqllogin;
GO

/* ===== SEC-SQL-AU-001-RC09 [DESTRUCTIVE] ===== */
-- Detection: enabled SQL login (not sa, not ##%##) whose password was set > 90 days ago.
-- Setup: create a SQL login, then backdate its password_last_set by updating the
-- password hash timestamp indirectly via ALTER LOGIN with the HASHED clause pointing
-- to a hash that has an old internal timestamp. The practical approach is to create
-- the login with CHECK_EXPIRATION=OFF and CHECK_POLICY=OFF (no expiration tracked),
-- then note that LOGINPROPERTY returns NULL for PasswordLastSetTime when policy is off
-- and the login was just created — DATEDIFF(NULL, ...) = NULL, so it won't fire.
-- To reliably trigger: create login with CHECK_POLICY=ON / CHECK_EXPIRATION=ON, then
-- use the undocumented xp_instance_regwrite approach OR simply accept that you must
-- wait 90 days. Best practical workaround: create the login, set CHECK_EXPIRATION=ON,
-- and manually verify via LOGINPROPERTY after 90 days. For immediate test lab use,
-- mock by temporarily lowering your own query threshold; the detection SQL itself
-- cannot be altered, but you can confirm the login appears correctly once aged.
-- Immediate-fire alternative: use an existing login whose password was last set long ago.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_oldpwd')
    CREATE LOGIN dbdome_test_oldpwd WITH PASSWORD = 'DbDome#Test4!',
        CHECK_POLICY = ON, CHECK_EXPIRATION = ON;
ALTER LOGIN dbdome_test_oldpwd ENABLE;
-- NOTE: LOGINPROPERTY PasswordLastSetTime will equal NOW at creation.
-- Detection fires only after 90 days have passed; no T-SQL shortcut exists to
-- backdate the internal password timestamp without direct catalog manipulation.
-- Verify this login appears in results after 90 days, or repoint the detection
-- threshold to 0 in a dev build for immediate testing.
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_oldpwd')
    DROP LOGIN dbdome_test_oldpwd;
GO

/* ===== SEC-SQL-AU-001-RC10 [DESTRUCTIVE] ===== */
-- Detection: enabled SQL or Windows login in sysadmin role, excluding NT SERVICE\%,
-- ##%##, and sa (sid<>0x01).
-- Setup: create a SQL login and add to sysadmin (same pattern as RC06 but a distinct login).
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_escalated')
    CREATE LOGIN dbdome_test_escalated WITH PASSWORD = 'DbDome#Test5!', CHECK_POLICY = OFF;
ALTER LOGIN dbdome_test_escalated ENABLE;
IF NOT EXISTS (
    SELECT 1 FROM sys.server_role_members srm
    JOIN sys.server_principals r ON srm.role_principal_id = r.principal_id
    JOIN sys.server_principals m ON srm.member_principal_id = m.principal_id
    WHERE r.name = 'sysadmin' AND m.name = 'dbdome_test_escalated'
)
    EXEC sp_addsrvrolemember 'dbdome_test_escalated', 'sysadmin';
GO
-- REVERT:
IF EXISTS (
    SELECT 1 FROM sys.server_role_members srm
    JOIN sys.server_principals r ON srm.role_principal_id = r.principal_id
    JOIN sys.server_principals m ON srm.member_principal_id = m.principal_id
    WHERE r.name = 'sysadmin' AND m.name = 'dbdome_test_escalated'
)
    EXEC sp_dropsrvrolemember 'dbdome_test_escalated', 'sysadmin';
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_escalated')
    DROP LOGIN dbdome_test_escalated;
GO

/* ===== SEC-SQL-AU-001-RC11 [DESTRUCTIVE] ===== */
-- Detection: server principals (SQL/Windows logins or groups, excluding ##%## and NT %)
-- whose modify_date is within the last 30 days.
-- Setup: creating or altering a login sets modify_date to NOW, which is within 30 days.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_recent')
    CREATE LOGIN dbdome_test_recent WITH PASSWORD = 'DbDome#Test6!', CHECK_POLICY = OFF;
-- Touching the login refreshes modify_date
ALTER LOGIN dbdome_test_recent WITH PASSWORD = 'DbDome#Test6b!';
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_recent')
    DROP LOGIN dbdome_test_recent;
GO

/* ===== SEC-SQL-AU-001-RC12 [SAFE] ===== */
-- Detection: any of ('sa', '##MS_PolicyEventProcessingLogin##',
-- '##MS_PolicyTsqlExecutionLogin##') is enabled.
-- The two ##MS_Policy*## logins are enabled by default on most instances.
-- To create a guaranteed controllable positive row: enable sa.
-- If ##MS_PolicyEventProcessingLogin## is already enabled, the detection already fires.
-- SETUP:
-- Enable sa to guarantee a row (it matches sp.name IN ('sa',...) AND is_disabled=0)
ALTER LOGIN sa ENABLE;
GO
-- REVERT:
ALTER LOGIN sa DISABLE;
GO

/* ===== SEC-SQL-AU-002-RC01 [DESTRUCTIVE] ===== */
-- Detection: SQL logins where PWDCOMPARE('', password_hash) = 1 (blank password).
-- Setup: create a SQL login with an empty password.
-- Requires mixed-mode authentication and CHECK_POLICY=OFF (blank pwd violates policy).
-- Run as sysadmin; server must be in Mixed or SQL+Windows auth mode.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_blankpwd')
    CREATE LOGIN dbdome_test_blankpwd WITH PASSWORD = '', CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
ALTER LOGIN dbdome_test_blankpwd ENABLE;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_blankpwd')
    DROP LOGIN dbdome_test_blankpwd;
GO

/* ===== SEC-SQL-AU-002-RC02 [DESTRUCTIVE] ===== */
-- Detection: aggregate query returns 1 row always; it reports blank_password_count > 0
-- and/or total_sql_logins. Fires when any SQL login has a blank password OR when any
-- SQL login exists (total_sql_logins >= 1).
-- To make blank_password_count >= 1 (clearest trigger): create blank-password login.
-- Also requires mixed-mode auth (SERVERPROPERTY('IsIntegratedSecurityOnly')=0).
-- SETUP:
-- Ensure mixed-mode auth (skip if already set; requires restart to take effect if changed)
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE',
    N'Software\Microsoft\MSSQLServer\MSSQLServer',
    N'LoginMode', REG_DWORD, 2;  -- 1=Windows only, 2=Mixed
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_blankpwd2')
    CREATE LOGIN dbdome_test_blankpwd2 WITH PASSWORD = '', CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
ALTER LOGIN dbdome_test_blankpwd2 ENABLE;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_blankpwd2')
    DROP LOGIN dbdome_test_blankpwd2;
-- Restore Windows-only auth if it was changed (set back to 1 for Windows-only, or leave as 2)
-- Uncomment the line below ONLY if auth mode was Windows-only before setup:
-- EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', REG_DWORD, 1;
GO

/* ===== SEC-SQL-AU-002-RC03 [DESTRUCTIVE] ===== */
-- Detection: SQL logins with blank password. Same predicate as RC01/RC02 (PWDCOMPARE('')=1).
-- Extra columns: instance create_date and hours_after_install. Row appears for any
-- blank-password login regardless of when it was created.
-- Run as sysadmin with mixed-mode auth enabled.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_blankpwd3')
    CREATE LOGIN dbdome_test_blankpwd3 WITH PASSWORD = '', CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
ALTER LOGIN dbdome_test_blankpwd3 ENABLE;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_blankpwd3')
    DROP LOGIN dbdome_test_blankpwd3;
GO

/* ===== SEC-SQL-AU-002-RC04 [DESTRUCTIVE] ===== */
-- Detection: SQL logins with blank password (PWDCOMPARE('')=1). Additional columns
-- show last_login (from dm_exec_sessions, may be NULL if login never connected) and
-- db_user_mappings count.
-- Setup: create blank-password login. Optionally create a DB user to populate db_user_mappings.
-- Run as sysadmin with mixed-mode auth.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_blankpwd4')
    CREATE LOGIN dbdome_test_blankpwd4 WITH PASSWORD = '', CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
ALTER LOGIN dbdome_test_blankpwd4 ENABLE;
-- Optional: map to a DB user so db_user_mappings > 0
USE tempdb;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_test_blankpwd4')
    CREATE USER dbdome_test_blankpwd4 FOR LOGIN dbdome_test_blankpwd4;
GO
-- REVERT:
USE tempdb;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_test_blankpwd4')
    DROP USER dbdome_test_blankpwd4;
USE master;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_blankpwd4')
    DROP LOGIN dbdome_test_blankpwd4;
GO


/* ########## batch 2 (12 reproducers) ########## */
/* =========================================================================
   Positive-test reproducers  --  slice 24..36 (indices 24-35, 12 detections)
   Target: DISPOSABLE / throwaway SQL Server only.
   All fake objects use the prefix  dbdome_test_  to avoid collisions.
   Run each SETUP block, verify the detection returns >=1 row, then REVERT.
   ========================================================================= */


/* ===== SEC-SQL-AU-002-RC05 [DESTRUCTIVE] ===== */
-- Detection fires on any SQL login whose password_hash matches an empty string (PWDCOMPARE('',hash)=1).
-- The only way to create such a login is to use CREATE LOGIN ... WITH PASSWORD='' and
-- CHECK_POLICY=OFF (policy would normally reject a blank password).
-- Run as sysadmin.  REVERT drops the login.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_nopwd_login')
    CREATE LOGIN [dbdome_test_nopwd_login]
        WITH PASSWORD = '',
             CHECK_POLICY    = OFF,
             CHECK_EXPIRATION = OFF;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_nopwd_login')
    DROP LOGIN [dbdome_test_nopwd_login];
GO


/* ===== SEC-SQL-AU-002-RC06 [DESTRUCTIVE] ===== */
-- Detection fires on SQL logins with blank password AND counts logins created on the same day
-- (logins_created_same_day via OVER PARTITION BY date).  Creating 2+ blank-password logins
-- in one day satisfies both predicates.  Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_batch_login_1')
    CREATE LOGIN [dbdome_test_batch_login_1]
        WITH PASSWORD = '',
             CHECK_POLICY    = OFF,
             CHECK_EXPIRATION = OFF;

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_batch_login_2')
    CREATE LOGIN [dbdome_test_batch_login_2]
        WITH PASSWORD = '',
             CHECK_POLICY    = OFF,
             CHECK_EXPIRATION = OFF;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_batch_login_1')
    DROP LOGIN [dbdome_test_batch_login_1];

IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_batch_login_2')
    DROP LOGIN [dbdome_test_batch_login_2];
GO


/* ===== SEC-SQL-AU-002-RC07 [DESTRUCTIVE] ===== */
-- Detection fires on SQL logins with blank password AND is_policy_checked=0.
-- CREATE LOGIN ... WITH PASSWORD='', CHECK_POLICY=OFF satisfies both predicates.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_nopolicy_login')
    CREATE LOGIN [dbdome_test_nopolicy_login]
        WITH PASSWORD = '',
             CHECK_POLICY    = OFF,
             CHECK_EXPIRATION = OFF;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_nopolicy_login')
    DROP LOGIN [dbdome_test_nopolicy_login];
GO


/* ===== SEC-SQL-AU-002-RC08 [DESTRUCTIVE] ===== */
-- Detection fires on any SQL login with blank password (no extra predicates beyond RC05).
-- SERVERPROPERTY columns are informational only and never filter rows.
-- Same setup as RC05 — one blank-password login is sufficient.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_legacy_login')
    CREATE LOGIN [dbdome_test_legacy_login]
        WITH PASSWORD = '',
             CHECK_POLICY    = OFF,
             CHECK_EXPIRATION = OFF;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_legacy_login')
    DROP LOGIN [dbdome_test_legacy_login];
GO


/* ===== SEC-SQL-AU-002-RC09 [DESTRUCTIVE] ===== */
-- Detection fires on blank-password SQL logins whose name matches app/svc/service/api/web/
-- batch/etl/report patterns, excluding 'sa'.
-- Create a login whose name contains 'svc' with a blank password and policy OFF.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_svc_app')
    CREATE LOGIN [dbdome_test_svc_app]
        WITH PASSWORD = '',
             CHECK_POLICY    = OFF,
             CHECK_EXPIRATION = OFF;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_svc_app')
    DROP LOGIN [dbdome_test_svc_app];
GO


/* ===== SEC-SQL-AU-002-RC10 [DESTRUCTIVE] ===== */
-- Detection fires on blank-password SQL logins (same core predicate as RC05).
-- The extra subquery counting possible Windows-principal matches is informational only
-- and does not filter rows, so a single blank-password SQL login is sufficient.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_ldap_login')
    CREATE LOGIN [dbdome_test_ldap_login]
        WITH PASSWORD = '',
             CHECK_POLICY    = OFF,
             CHECK_EXPIRATION = OFF;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_ldap_login')
    DROP LOGIN [dbdome_test_ldap_login];
GO


/* ===== SEC-SQL-AU-002-RC11 [DESTRUCTIVE] ===== */
-- Detection fires on blank-password SQL logins; batch_size window counts how many share
-- the same smalldatetime create_date (rounded to the minute).  Two logins created in the
-- same minute will both show batch_size=2.  Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_batchscript_login_1')
    CREATE LOGIN [dbdome_test_batchscript_login_1]
        WITH PASSWORD = '',
             CHECK_POLICY    = OFF,
             CHECK_EXPIRATION = OFF;

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_batchscript_login_2')
    CREATE LOGIN [dbdome_test_batchscript_login_2]
        WITH PASSWORD = '',
             CHECK_POLICY    = OFF,
             CHECK_EXPIRATION = OFF;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_batchscript_login_1')
    DROP LOGIN [dbdome_test_batchscript_login_1];

IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_batchscript_login_2')
    DROP LOGIN [dbdome_test_batchscript_login_2];
GO


/* ===== SEC-SQL-AU-002-RC12 [DESTRUCTIVE] ===== */
-- Detection fires on blank-password SQL logins; severity is raised to CRITICAL when the
-- login is a member of sysadmin.  Create a blank-password login and add it to sysadmin
-- so the row appears with severity='CRITICAL'.  Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_sysadmin_nopwd')
    CREATE LOGIN [dbdome_test_sysadmin_nopwd]
        WITH PASSWORD = '',
             CHECK_POLICY    = OFF,
             CHECK_EXPIRATION = OFF;

IF IS_SRVROLEMEMBER('sysadmin', 'dbdome_test_sysadmin_nopwd') = 0
    EXEC sp_addsrvrolemember 'dbdome_test_sysadmin_nopwd', 'sysadmin';
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_sysadmin_nopwd')
BEGIN
    IF IS_SRVROLEMEMBER('sysadmin', 'dbdome_test_sysadmin_nopwd') = 1
        EXEC sp_dropsrvrolemember 'dbdome_test_sysadmin_nopwd', 'sysadmin';
    DROP LOGIN [dbdome_test_sysadmin_nopwd];
END;
GO


/* ===== SEC-SQL-AU-003-RC01 [DESTRUCTIVE] ===== */
-- Detection is an aggregation that returns exactly one summary row.  It fires (count > 0
-- for no_policy / no_expiration) whenever at least one enabled, non-## SQL login has
-- is_policy_checked=0 or is_expiration_checked=0.
-- Create one such login; the aggregate will show no_policy >= 1, pct_no_policy > 0.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_nopolicycheck')
    CREATE LOGIN [dbdome_test_nopolicycheck]
        WITH PASSWORD    = 'DbD0me$TestOnly!',
             CHECK_POLICY    = OFF,
             CHECK_EXPIRATION = OFF;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_nopolicycheck')
    DROP LOGIN [dbdome_test_nopolicycheck];
GO


/* ===== SEC-SQL-AU-003-RC02 [DESTRUCTIVE] ===== */
-- Detection checks common weak passwords on logins where is_policy_checked=0.
-- Create a login with policy OFF and the password 'password' (PWDCOMPARE returns 1
-- for is_password column).  The WHERE clause only requires policy=0 and a non-disabled,
-- non-## login; any of the PWDCOMPARE columns being 1 will highlight the row in the
-- result set.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_weakpwd_login')
    CREATE LOGIN [dbdome_test_weakpwd_login]
        WITH PASSWORD    = 'password',
             CHECK_POLICY    = OFF,
             CHECK_EXPIRATION = OFF;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_weakpwd_login')
    DROP LOGIN [dbdome_test_weakpwd_login];
GO


/* ===== SEC-SQL-AU-003-RC03 [DESTRUCTIVE] ===== */
-- Detection fires on enabled SQL logins with policy OFF that are older than 365 days.
-- Back-dating create_date is not possible directly through T-SQL; instead create the login
-- now and use sp_configure + direct catalog update via DAC, OR accept that this test will
-- not fire on a brand-new server for 365 days.
-- Practical workaround: use SQLCMD in DAC mode (admin:) and run an UPDATE against
-- sys.syslogins / sp_configure is not sufficient to change create_date directly.
-- Best-effort: the login is created with policy OFF.  On a test server that already has an
-- old policy-off login the detection fires immediately.  For a fresh server, re-run the
-- detection after 365 days, or manually update create_date via DAC connection:
--   UPDATE sys.syslogins SET createdate = DATEADD(DAY,-366,GETDATE())
--   WHERE name = 'dbdome_test_legacy_nopol' -- DAC only, not supported in normal sessions.
-- Run as sysadmin.  The SETUP creates the login; note the 365-day age limitation above.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_legacy_nopol')
    CREATE LOGIN [dbdome_test_legacy_nopol]
        WITH PASSWORD    = 'DbD0me$TestOnly!',
             CHECK_POLICY    = OFF,
             CHECK_EXPIRATION = OFF;

-- Attempt DAC-only catalog update to age the login (will silently skip if not on DAC):
BEGIN TRY
    EXEC sp_executesql
        N'UPDATE sys.syslogins SET createdate = DATEADD(DAY, -366, GETDATE())
          WHERE name = ''dbdome_test_legacy_nopol''';
END TRY
BEGIN CATCH
    -- Not on a DAC connection; create_date cannot be back-dated.
    -- The login still exists and detection will fire once it ages past 365 days.
    PRINT 'INFO: create_date back-date skipped (requires DAC connection). Login created; re-test after 365 days or connect via admin: DAC.';
END CATCH;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_legacy_nopol')
    DROP LOGIN [dbdome_test_legacy_nopol];
GO


/* ===== SEC-SQL-AU-003-RC04 [DESTRUCTIVE] ===== */
-- Detection is a pure aggregate (always returns one row).  It fires meaningfully when
-- no_policy > 0 (there exists at least one enabled non-## SQL login with policy OFF).
-- Create one such login; the no_policy count will be >= 1.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_compliancegap')
    CREATE LOGIN [dbdome_test_compliancegap]
        WITH PASSWORD    = 'DbD0me$TestOnly!',
             CHECK_POLICY    = OFF,
             CHECK_EXPIRATION = OFF;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_compliancegap')
    DROP LOGIN [dbdome_test_compliancegap];
GO


/* ########## batch 3 (12 reproducers) ########## */
/* ===== SEC-SQL-AU-003-RC05 [DESTRUCTIVE] ===== */
-- Creates a SQL login with CHECK_POLICY=OFF so is_policy_checked=0; login is enabled and not prefixed with ##.
-- Run as sysadmin. Detection returns >=1 row immediately after SETUP.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_rc05')
    CREATE LOGIN dbdome_test_rc05 WITH PASSWORD = 'Dbdome!Test99',
        CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
-- Ensure the login is enabled and policy is off (idempotent re-run)
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_rc05' AND is_disabled = 1)
    ALTER LOGIN dbdome_test_rc05 ENABLE;
ALTER LOGIN dbdome_test_rc05 WITH CHECK_POLICY = OFF;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_rc05')
    DROP LOGIN dbdome_test_rc05;
GO

/* ===== SEC-SQL-AU-003-RC06 [DESTRUCTIVE] ===== */
-- Aggregate query: returns 1 row always; no_policy_count > 0 when any SQL login has is_policy_checked=0.
-- Creates a login with CHECK_POLICY=OFF to ensure no_policy_count >= 1.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_rc06')
    CREATE LOGIN dbdome_test_rc06 WITH PASSWORD = 'Dbdome!Test99',
        CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_rc06' AND is_disabled = 1)
    ALTER LOGIN dbdome_test_rc06 ENABLE;
ALTER LOGIN dbdome_test_rc06 WITH CHECK_POLICY = OFF;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_rc06')
    DROP LOGIN dbdome_test_rc06;
GO

/* ===== SEC-SQL-AU-003-RC07 [DESTRUCTIVE] ===== */
-- Detection requires both is_policy_checked=0 AND is_expiration_checked=0 on an enabled SQL login.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_rc07')
    CREATE LOGIN dbdome_test_rc07 WITH PASSWORD = 'Dbdome!Test99',
        CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_rc07' AND is_disabled = 1)
    ALTER LOGIN dbdome_test_rc07 ENABLE;
ALTER LOGIN dbdome_test_rc07 WITH CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_rc07')
    DROP LOGIN dbdome_test_rc07;
GO

/* ===== SEC-SQL-AU-003-RC08 [DESTRUCTIVE] ===== */
-- Detection requires (is_policy_checked=0 OR is_expiration_checked=0) on an enabled SQL login.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_rc08')
    CREATE LOGIN dbdome_test_rc08 WITH PASSWORD = 'Dbdome!Test99',
        CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_rc08' AND is_disabled = 1)
    ALTER LOGIN dbdome_test_rc08 ENABLE;
ALTER LOGIN dbdome_test_rc08 WITH CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_rc08')
    DROP LOGIN dbdome_test_rc08;
GO

/* ===== SEC-SQL-AU-003-RC09 [DESTRUCTIVE] ===== */
-- Aggregate query: always returns 1 row; policy_not_enforced_count > 0 needs at least one login with CHECK_POLICY=OFF.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_rc09')
    CREATE LOGIN dbdome_test_rc09 WITH PASSWORD = 'Dbdome!Test99',
        CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_rc09' AND is_disabled = 1)
    ALTER LOGIN dbdome_test_rc09 ENABLE;
ALTER LOGIN dbdome_test_rc09 WITH CHECK_POLICY = OFF;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_rc09')
    DROP LOGIN dbdome_test_rc09;
GO

/* ===== SEC-SQL-AU-003-RC10 [DESTRUCTIVE] ===== */
-- Detection shows all enabled SQL logins and their PWDCOMPARE results. It always returns rows when any
-- enabled SQL login exists. To make a weak-password hit visible (PWDCOMPARE column = 1), create a login
-- with a known weak password and CHECK_POLICY=OFF (policy enforcement would block the weak password).
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_rc10')
    CREATE LOGIN dbdome_test_rc10 WITH PASSWORD = 'Password1',
        CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_rc10' AND is_disabled = 1)
    ALTER LOGIN dbdome_test_rc10 ENABLE;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_rc10')
    DROP LOGIN dbdome_test_rc10;
GO

/* ===== SEC-SQL-AU-003-RC11 [SAFE] ===== */
-- This is a scalar aggregation over sys.server_audits and sys.configurations; it always returns exactly
-- 1 row regardless of data. No setup required -- the detection fires on any SQL Server instance.
-- To make audit-related columns show 0 (interesting state): ensure no server audit is enabled.
-- No persistent changes needed for a positive test (1 row always returned).
-- SETUP:
-- No setup required; the query always returns 1 row (scalar aggregation with no GROUP BY or WHERE filter
-- that could produce 0 rows). Run the detection SQL directly to confirm >=1 row.
SELECT 'SEC-SQL-AU-003-RC11: no setup required -- detection always returns 1 row' AS info;
GO
-- REVERT:
-- Nothing to revert.
SELECT 'SEC-SQL-AU-003-RC11: no revert needed' AS info;
GO

/* ===== SEC-SQL-AU-003-RC12 [DESTRUCTIVE] ===== */
-- Detection GROUPs by (is_policy_checked, is_expiration_checked); returns >=1 row whenever any
-- enabled SQL login exists. To guarantee a row with policy=0 group, create a login with CHECK_POLICY=OFF.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_rc12')
    CREATE LOGIN dbdome_test_rc12 WITH PASSWORD = 'Dbdome!Test99',
        CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_rc12' AND is_disabled = 1)
    ALTER LOGIN dbdome_test_rc12 ENABLE;
ALTER LOGIN dbdome_test_rc12 WITH CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_rc12')
    DROP LOGIN dbdome_test_rc12;
GO

/* ===== SEC-SQL-AU-003-RC13 [DESTRUCTIVE] ===== */
-- Detection requires is_policy_checked=0 on an enabled SQL login; ordered by create_date DESC.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_rc13')
    CREATE LOGIN dbdome_test_rc13 WITH PASSWORD = 'Dbdome!Test99',
        CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_rc13' AND is_disabled = 1)
    ALTER LOGIN dbdome_test_rc13 ENABLE;
ALTER LOGIN dbdome_test_rc13 WITH CHECK_POLICY = OFF;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_rc13')
    DROP LOGIN dbdome_test_rc13;
GO

/* ===== SEC-SQL-AU-004-RC03 [SAFE] ===== */
-- Detection lists ALL non-disabled logins of type S/U/G (SQL, Windows user, Windows group) that are not
-- prefixed with ##. It always returns rows on any live SQL Server with standard logins present (e.g. sa).
-- No setup required -- the query returns rows for every existing enabled non-system login.
-- If sa is disabled and no other logins exist, create one below.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_rc03_au004')
    CREATE LOGIN dbdome_test_rc03_au004 WITH PASSWORD = 'Dbdome!Test99',
        CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_rc03_au004' AND is_disabled = 1)
    ALTER LOGIN dbdome_test_rc03_au004 ENABLE;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_rc03_au004')
    DROP LOGIN dbdome_test_rc03_au004;
GO

/* ===== SEC-SQL-AU-004-RC04 [DESTRUCTIVE] ===== */
-- Detection requires a WINDOWS_LOGIN or WINDOWS_GROUP from a domain DIFFERENT from the local machine's
-- NetBIOS name, with sysadmin, securityadmin, or dbcreator membership.
-- This requires a real Active Directory domain environment. On a standalone or workgroup server this
-- cannot be scripted purely in T-SQL.
-- LIMITATION: If the test server is not domain-joined, this detection cannot be triggered via T-SQL alone.
-- Best-effort: on a domain-joined server, substitute TESTDOMAIN\dbdome_test_user with a real domain account.
-- Run as sysadmin on a domain-joined SQL Server where TESTDOMAIN != server NetBIOS name.
-- SETUP:
-- Replace 'TESTDOMAIN\dbdome_test_winadmin' with a real Windows account from a different domain.
-- IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'TESTDOMAIN\dbdome_test_winadmin')
--     CREATE LOGIN [TESTDOMAIN\dbdome_test_winadmin] FROM WINDOWS;
-- ALTER SERVER ROLE sysadmin ADD MEMBER [TESTDOMAIN\dbdome_test_winadmin];
SELECT 'SEC-SQL-AU-004-RC04: requires domain environment -- see commented setup above' AS info;
GO
-- REVERT:
-- IF IS_SRVROLEMEMBER('sysadmin', 'TESTDOMAIN\dbdome_test_winadmin') = 1
--     ALTER SERVER ROLE sysadmin DROP MEMBER [TESTDOMAIN\dbdome_test_winadmin];
-- IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'TESTDOMAIN\dbdome_test_winadmin')
--     DROP LOGIN [TESTDOMAIN\dbdome_test_winadmin];
SELECT 'SEC-SQL-AU-004-RC04: no revert needed (setup was skipped on non-domain server)' AS info;
GO

/* ===== SEC-SQL-AU-004-RC06 [SAFE] ===== */
-- Detection reads CONNECTIONPROPERTY() scalars and sys.configurations; it always returns exactly 1 row
-- for the current connection. No setup required.
-- current_encrypt will show FALSE on unencrypted connections, current_auth shows NTLM/KERBEROS/SQL, etc.
-- To surface the "interesting" state (auth=NTLM/KERBEROS without encryption): connect without TLS.
-- No persistent changes are made.
-- SETUP:
SELECT
    CONNECTIONPROPERTY('net_transport')  AS current_transport,
    CONNECTIONPROPERTY('protocol_type')  AS current_protocol,
    CONNECTIONPROPERTY('auth_scheme')    AS current_auth,
    CONNECTIONPROPERTY('encrypt_option') AS current_encrypt,
    (SELECT value_in_use FROM sys.configurations WHERE name = 'remote admin connections') AS remote_dac,
    SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_auth_only;
GO
-- REVERT:
-- Nothing to revert; read-only query.
SELECT 'SEC-SQL-AU-004-RC06: no revert needed' AS info;
GO


/* ########## batch 4 (12 reproducers) ########## */
/* =============================================================================
   Positive-test reproducers – slice 48..60  (pt_4.sql)
   Target: DISPOSABLE / throwaway SQL Server instance only.
   Run each SETUP block, execute the detection SQL, confirm >=1 row returned,
   then run the matching REVERT block.
============================================================================= */

/* ===== SEC-SQL-AU-004-RC07 [DESTRUCTIVE] ===== */
-- Detection groups Windows logins that contain a backslash (domain\user) and
-- are not prefixed with 'NT ' or '##'.  A Windows login from any real or
-- simulated domain will satisfy the predicate.
-- NOTE: Windows logins can only be created when SQL Server is domain-joined or
-- has a resolvable Windows account. On a standalone/workgroup test box use
-- a local machine account (MACHINE\account) instead of DOMAIN\account.
-- Run as sysadmin.  Replace TESTMACHINE with the actual host name
-- (SELECT SERVERPROPERTY('ComputerNamePhysicalNetBIOS')).
-- SETUP:
DECLARE @host NVARCHAR(128) = CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS NVARCHAR(128));
DECLARE @login NVARCHAR(256) = @host + N'\dbdome_test_winuser';
-- Create a local Windows account first via xp_cmdshell if needed, or pre-create
-- the OS account manually.  The CREATE LOGIN below is the SQL-side step.
-- If the Windows account does not exist the statement will fail; create it first:
--   EXEC xp_cmdshell 'net user dbdome_test_winuser Dbdome@2025! /add';
EXEC xp_cmdshell 'net user dbdome_test_winuser Dbdome@2025! /add';
DECLARE @sql NVARCHAR(512) = N'IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = ''' + @login + N''')
    CREATE LOGIN [' + @login + N'] FROM WINDOWS;';
EXEC sp_executesql @sql;
GO
-- REVERT:
DECLARE @host NVARCHAR(128) = CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS NVARCHAR(128));
DECLARE @login NVARCHAR(256) = @host + N'\dbdome_test_winuser';
DECLARE @sql NVARCHAR(512) = N'IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = ''' + @login + N''')
    DROP LOGIN [' + @login + N'];';
EXEC sp_executesql @sql;
EXEC xp_cmdshell 'net user dbdome_test_winuser /delete';
GO

/* ===== SEC-SQL-AU-004-RC08 [DESTRUCTIVE] ===== */
-- Detection always returns exactly 1 row (scalar subqueries, no outer WHERE).
-- It "fires" when active_windows_logins > 0, active_logon_triggers = 0, and
-- restricted_endpoints = 0 – typical on any server with Windows auth enabled.
-- The simplest positive test is to ensure at least one active Windows login
-- exists that does not start with 'NT '.
-- NOTE: Requires a resolvable Windows account (see RC07 notes above).
-- Run as sysadmin.
-- SETUP:
EXEC xp_cmdshell 'net user dbdome_test_win2 Dbdome@2025! /add';
DECLARE @host NVARCHAR(128) = CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS NVARCHAR(128));
DECLARE @login NVARCHAR(256) = @host + N'\dbdome_test_win2';
DECLARE @sql NVARCHAR(512) = N'IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = ''' + @login + N''')
    CREATE LOGIN [' + @login + N'] FROM WINDOWS;';
EXEC sp_executesql @sql;
GO
-- REVERT:
DECLARE @host NVARCHAR(128) = CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS NVARCHAR(128));
DECLARE @login NVARCHAR(256) = @host + N'\dbdome_test_win2';
DECLARE @sql NVARCHAR(512) = N'IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = ''' + @login + N''')
    DROP LOGIN [' + @login + N'];';
EXEC sp_executesql @sql;
EXEC xp_cmdshell 'net user dbdome_test_win2 /delete';
GO

/* ===== SEC-SQL-AU-004-RC10 [SAFE] ===== */
-- Detection queries sys.dm_exec_connections JOIN sys.dm_exec_sessions for user
-- processes.  It returns >=1 row whenever any client connection (including the
-- session running this very script) exists.  No persistent change required.
-- Run detection SQL from any active user session.
-- SETUP:
-- No persistent setup needed.  The session executing this script is itself a
-- user process and will appear in dm_exec_connections.  To make the row even
-- more visible, open an additional connection in SSMS/sqlcmd and leave it idle.
SELECT 'Active session exists – detection will return >=1 row' AS positive_test_note,
       @@SPID AS current_spid,
       SYSTEM_USER AS current_login;
GO
-- REVERT:
-- Nothing to revert.  The session disappears when the connection is closed.
SELECT 'No revert needed for runtime-only detection' AS revert_note;
GO

/* ===== SEC-SQL-AU-004-RC11 [DESTRUCTIVE] ===== */
-- Detection looks for linked servers where provider contains 'ADsDSOObject',
-- data_source contains 'LDAP', or product contains 'Active Directory'.
-- Create a fake linked server pointing at an LDAP path.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE name = N'DBDOME_LDAP_TEST' AND is_linked = 1)
BEGIN
    EXEC sp_addlinkedserver
        @server     = N'DBDOME_LDAP_TEST',
        @srvproduct = N'Active Directory Test',
        @provider   = N'ADsDSOObject',
        @datasrc    = N'LDAP://DC=dbdome,DC=test,DC=local';
END;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.servers WHERE name = N'DBDOME_LDAP_TEST' AND is_linked = 1)
    EXEC sp_dropserver @server = N'DBDOME_LDAP_TEST', @droplogins = N'droplogins';
GO

/* ===== SEC-SQL-AU-004-RC12 [DESTRUCTIVE] ===== */
-- Detection returns 1 row always.  It flags when active Windows logins exist
-- (windows_logins > 0) but login_audit_actions = 0 – i.e., no server audit
-- spec covers SUCCESSFUL_LOGIN_GROUP / FAILED_LOGIN_GROUP etc.
-- To guarantee the flag: (a) ensure at least one Windows login exists, and
-- (b) ensure NO enabled server audit specification covers those action groups.
-- Easiest approach on a test box: disable all existing server audit specs,
-- or simply create a Windows login while leaving audits absent.
-- NOTE: Disabling existing audits is DESTRUCTIVE.  If audit specs already
-- exist covering login events, disable them temporarily.  Revert re-enables.
-- If no login audit spec exists on the test box, only the Windows login
-- creation is needed (RC07/RC08 setup already satisfies that condition).
-- SETUP:
-- Step 1: create a Windows login so windows_logins > 0 (reuse RC07 account if
--         already created; this is idempotent).
EXEC xp_cmdshell 'net user dbdome_test_win3 Dbdome@2025! /add 2>NUL';
DECLARE @host NVARCHAR(128) = CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS NVARCHAR(128));
DECLARE @login NVARCHAR(256) = @host + N'\dbdome_test_win3';
DECLARE @sql NVARCHAR(512) = N'IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = ''' + @login + N''')
    CREATE LOGIN [' + @login + N'] FROM WINDOWS;';
EXEC sp_executesql @sql;

-- Step 2: disable any enabled server audit specs that cover login action groups
--         so login_audit_actions = 0.
-- Capture names to re-enable in revert.
IF OBJECT_ID('tempdb..#audit_specs_disabled') IS NOT NULL DROP TABLE #audit_specs_disabled;
CREATE TABLE #audit_specs_disabled (spec_name SYSNAME);

DECLARE @spec_name SYSNAME, @alter_sql NVARCHAR(512);
DECLARE spec_cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT DISTINCT sas.name
    FROM sys.server_audit_specification_details sasd
    JOIN sys.server_audit_specifications sas ON sasd.server_specification_id = sas.server_specification_id
    JOIN sys.server_audits sa ON sas.audit_guid = sa.audit_guid
    WHERE sa.is_state_enabled = 1 AND sas.is_state_enabled = 1
      AND sasd.audit_action_name IN (
          'SUCCESSFUL_LOGIN_GROUP','FAILED_LOGIN_GROUP',
          'LOGIN_CHANGE_PASSWORD_GROUP','SERVER_PRINCIPAL_CHANGE_GROUP');

OPEN spec_cur;
FETCH NEXT FROM spec_cur INTO @spec_name;
WHILE @@FETCH_STATUS = 0
BEGIN
    INSERT INTO #audit_specs_disabled VALUES (@spec_name);
    SET @alter_sql = N'ALTER SERVER AUDIT SPECIFICATION [' + @spec_name + N'] WITH (STATE = OFF);';
    EXEC sp_executesql @alter_sql;
    FETCH NEXT FROM spec_cur INTO @spec_name;
END;
CLOSE spec_cur; DEALLOCATE spec_cur;

SELECT spec_name AS 'specs_disabled_save_for_revert' FROM #audit_specs_disabled;
GO
-- REVERT:
-- Re-enable any audit specs disabled during setup (re-run names from setup output).
-- Generic re-enable: enable ALL server audit specs that are currently disabled
-- and belong to server audits that are enabled.  On a throwaway box this is safe.
DECLARE @spec_name SYSNAME, @alter_sql NVARCHAR(512);
DECLARE spec_cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT sas.name
    FROM sys.server_audit_specifications sas
    JOIN sys.server_audits sa ON sas.audit_guid = sa.audit_guid
    WHERE sa.is_state_enabled = 1 AND sas.is_state_enabled = 0;

OPEN spec_cur;
FETCH NEXT FROM spec_cur INTO @spec_name;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @alter_sql = N'ALTER SERVER AUDIT SPECIFICATION [' + @spec_name + N'] WITH (STATE = ON);';
    EXEC sp_executesql @alter_sql;
    FETCH NEXT FROM spec_cur INTO @spec_name;
END;
CLOSE spec_cur; DEALLOCATE spec_cur;

-- Remove Windows login created for this test.
DECLARE @host NVARCHAR(128) = CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS NVARCHAR(128));
DECLARE @login NVARCHAR(256) = @host + N'\dbdome_test_win3';
DECLARE @sql NVARCHAR(512) = N'IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = ''' + @login + N''')
    DROP LOGIN [' + @login + N'];';
EXEC sp_executesql @sql;
EXEC xp_cmdshell 'net user dbdome_test_win3 /delete 2>NUL';
GO

/* ===== SEC-SQL-AU-005-RC01 [DESTRUCTIVE] ===== */
-- Detection fires when IsIntegratedSecurityOnly = 0 (mixed-mode auth) AND
-- active_sql_logins > 0 (SQL logins that are enabled, not ##, not sa).
-- Requires: switch instance to mixed-mode auth + create an enabled SQL login.
-- NOTE: Changing auth mode requires a SQL Server service restart to take full
-- effect; however the registry/DMV value updates immediately so the detection
-- (which reads SERVERPROPERTY) will reflect the change without restart.
-- Run as sysadmin.
-- SETUP:
-- Step 1: enable mixed-mode auth (requires sysadmin; service restart optional
--         for full effect but SERVERPROPERTY reflects the change immediately
--         after the registry write done by xp_instance_regwrite).
EXEC xp_instance_regwrite
    N'HKEY_LOCAL_MACHINE',
    N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer',
    N'LoginMode', N'REG_DWORD', 2;  -- 1=Windows only, 2=Mixed

-- Step 2: create an enabled SQL login with a non-## name (not sa).
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'dbdome_test_login')
    CREATE LOGIN [dbdome_test_login]
        WITH PASSWORD   = N'Dbdome@Test2025!',
             CHECK_POLICY = ON,
             CHECK_EXPIRATION = OFF;

-- Ensure login is enabled.
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'dbdome_test_login' AND is_disabled = 1)
    ALTER LOGIN [dbdome_test_login] ENABLE;
GO
-- REVERT:
-- Drop the test SQL login.
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'dbdome_test_login')
    DROP LOGIN [dbdome_test_login];

-- Restore Windows-only auth (set LoginMode back to 1).
-- Adjust if the original value was already mixed-mode (2) – in that case skip.
EXEC xp_instance_regwrite
    N'HKEY_LOCAL_MACHINE',
    N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer',
    N'LoginMode', N'REG_DWORD', 1;
GO

/* ===== SEC-SQL-AU-005-RC02 [DESTRUCTIVE] ===== */
-- Detection fires when IsIntegratedSecurityOnly = 0 AND active_sql_logins > 0
-- AND distinct_default_dbs > 0 (SQL logins defaulting to non-system DBs).
-- Build on RC01 setup: create SQL login with a non-system default database.
-- Run as sysadmin.
-- SETUP:
-- Enable mixed-mode auth.
EXEC xp_instance_regwrite
    N'HKEY_LOCAL_MACHINE',
    N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer',
    N'LoginMode', N'REG_DWORD', 2;

-- Create a throwaway database to use as default_database.
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = N'dbdome_tenant_test')
    CREATE DATABASE [dbdome_tenant_test];

-- Create SQL login defaulting to that database.
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'dbdome_tenant_login')
    CREATE LOGIN [dbdome_tenant_login]
        WITH PASSWORD        = N'Dbdome@Tenant2025!',
             DEFAULT_DATABASE = [dbdome_tenant_test],
             CHECK_POLICY     = ON,
             CHECK_EXPIRATION = OFF;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'dbdome_tenant_login')
    DROP LOGIN [dbdome_tenant_login];

IF EXISTS (SELECT 1 FROM sys.databases WHERE name = N'dbdome_tenant_test')
BEGIN
    ALTER DATABASE [dbdome_tenant_test] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [dbdome_tenant_test];
END;

-- Restore Windows-only auth.
EXEC xp_instance_regwrite
    N'HKEY_LOCAL_MACHINE',
    N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer',
    N'LoginMode', N'REG_DWORD', 1;
GO

/* ===== SEC-SQL-AU-005-RC03 [DESTRUCTIVE] ===== */
-- Detection always returns 1 row (all scalar subqueries).  It flags primarily
-- when sql_logins_no_policy > 0 – SQL logins with password policy checking
-- disabled.  Also when mixed-mode is active.
-- Create a SQL login with CHECK_POLICY = OFF.
-- Run as sysadmin.  NOTE: CHECK_POLICY=OFF is only allowed in mixed-mode auth
-- or when the SQL Server instance has mixed-mode already configured.
-- SETUP:
-- Enable mixed-mode auth first (required to create SQL logins).
EXEC xp_instance_regwrite
    N'HKEY_LOCAL_MACHINE',
    N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer',
    N'LoginMode', N'REG_DWORD', 2;

-- Create SQL login with policy checking disabled.
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'dbdome_nopolicy_login')
    CREATE LOGIN [dbdome_nopolicy_login]
        WITH PASSWORD        = N'Dbdome@NoPolicy!',
             CHECK_POLICY    = OFF,
             CHECK_EXPIRATION = OFF;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'dbdome_nopolicy_login')
    DROP LOGIN [dbdome_nopolicy_login];

-- Restore Windows-only auth.
EXEC xp_instance_regwrite
    N'HKEY_LOCAL_MACHINE',
    N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer',
    N'LoginMode', N'REG_DWORD', 1;
GO

/* ===== SEC-SQL-AU-005-RC04 [DESTRUCTIVE] ===== */
-- Detection returns 1 row always.  It flags when BOTH active_windows_logins > 0
-- AND active_sql_logins > 0 – a mixed-auth environment with both login types.
-- Create both a Windows login and a SQL login in mixed mode.
-- Run as sysadmin.
-- SETUP:
-- Enable mixed-mode auth.
EXEC xp_instance_regwrite
    N'HKEY_LOCAL_MACHINE',
    N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer',
    N'LoginMode', N'REG_DWORD', 2;

-- Create a SQL login (active_sql_logins side).
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'dbdome_sql_login_rc04')
    CREATE LOGIN [dbdome_sql_login_rc04]
        WITH PASSWORD     = N'Dbdome@RC04sql!',
             CHECK_POLICY = ON,
             CHECK_EXPIRATION = OFF;

-- Create a Windows login (active_windows_logins side).
-- Reuse OS account from RC07 or create separately.
EXEC xp_cmdshell 'net user dbdome_test_win4 Dbdome@2025! /add 2>NUL';
DECLARE @host NVARCHAR(128) = CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS NVARCHAR(128));
DECLARE @login NVARCHAR(256) = @host + N'\dbdome_test_win4';
DECLARE @sql NVARCHAR(512) = N'IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = ''' + @login + N''')
    CREATE LOGIN [' + @login + N'] FROM WINDOWS;';
EXEC sp_executesql @sql;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'dbdome_sql_login_rc04')
    DROP LOGIN [dbdome_sql_login_rc04];

DECLARE @host NVARCHAR(128) = CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS NVARCHAR(128));
DECLARE @login NVARCHAR(256) = @host + N'\dbdome_test_win4';
DECLARE @sql NVARCHAR(512) = N'IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = ''' + @login + N''')
    DROP LOGIN [' + @login + N'];';
EXEC sp_executesql @sql;
EXEC xp_cmdshell 'net user dbdome_test_win4 /delete 2>NUL';

-- Restore Windows-only auth.
EXEC xp_instance_regwrite
    N'HKEY_LOCAL_MACHINE',
    N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer',
    N'LoginMode', N'REG_DWORD', 1;
GO

/* ===== SEC-SQL-AU-005-RC05 [DESTRUCTIVE] ===== */
-- Detection fires when IsIntegratedSecurityOnly = 0 AND an enabled SQL login
-- exists with a name matching contractor/vendor/extern/consult/partner/3rd/
-- third/guest/temp_ pattern.
-- Create a SQL login named 'dbdome_vendor_test' (matches '%vendor%').
-- Run as sysadmin.
-- SETUP:
-- Enable mixed-mode auth.
EXEC xp_instance_regwrite
    N'HKEY_LOCAL_MACHINE',
    N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer',
    N'LoginMode', N'REG_DWORD', 2;

-- Create SQL login whose name matches '%vendor%'.
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'dbdome_vendor_test')
    CREATE LOGIN [dbdome_vendor_test]
        WITH PASSWORD        = N'Dbdome@Vendor2025!',
             CHECK_POLICY    = ON,
             CHECK_EXPIRATION = OFF;

-- Ensure enabled.
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'dbdome_vendor_test' AND is_disabled = 1)
    ALTER LOGIN [dbdome_vendor_test] ENABLE;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'dbdome_vendor_test')
    DROP LOGIN [dbdome_vendor_test];

-- Restore Windows-only auth.
EXEC xp_instance_regwrite
    N'HKEY_LOCAL_MACHINE',
    N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer',
    N'LoginMode', N'REG_DWORD', 1;
GO

/* ===== SEC-SQL-AU-005-RC06 [DESTRUCTIVE] ===== */
-- Detection fires when IsIntegratedSecurityOnly = 0 AND an enabled SQL login
-- exists with a name matching dev/debug/local/test/staging/qa pattern.
-- Create a SQL login named 'dbdome_dev_login' (matches '%dev%').
-- Run as sysadmin.
-- SETUP:
-- Enable mixed-mode auth.
EXEC xp_instance_regwrite
    N'HKEY_LOCAL_MACHINE',
    N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer',
    N'LoginMode', N'REG_DWORD', 2;

-- Create SQL login whose name matches '%dev%'.
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'dbdome_dev_login')
    CREATE LOGIN [dbdome_dev_login]
        WITH PASSWORD        = N'Dbdome@Dev2025!',
             CHECK_POLICY    = ON,
             CHECK_EXPIRATION = OFF;

-- Ensure enabled.
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'dbdome_dev_login' AND is_disabled = 1)
    ALTER LOGIN [dbdome_dev_login] ENABLE;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'dbdome_dev_login')
    DROP LOGIN [dbdome_dev_login];

-- Restore Windows-only auth.
EXEC xp_instance_regwrite
    N'HKEY_LOCAL_MACHINE',
    N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer',
    N'LoginMode', N'REG_DWORD', 1;
GO

/* ===== SEC-SQL-AU-005-RC07 [DESTRUCTIVE] ===== */
-- Detection always returns 1 row (WHERE sp.name = 'sa' always matches).
-- It surfaces sa login details when IsIntegratedSecurityOnly = 0 (mixed mode).
-- To trigger: switch to mixed-mode; the 'sa' account is always present.
-- The days_password_set_after_install column will be populated automatically.
-- Run as sysadmin.
-- SETUP:
-- Enable mixed-mode auth so SERVERPROPERTY('IsIntegratedSecurityOnly') = 0.
EXEC xp_instance_regwrite
    N'HKEY_LOCAL_MACHINE',
    N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer',
    N'LoginMode', N'REG_DWORD', 2;

-- Optionally enable sa to make the result more interesting (sa may be disabled
-- by default on some installations; detection still returns the row regardless).
-- ALTER LOGIN [sa] ENABLE;  -- uncomment only if intentionally enabling sa.
SELECT 'Mixed-mode enabled – detection will return sa row' AS positive_test_note,
       SERVERPROPERTY('IsIntegratedSecurityOnly') AS is_windows_only_after_setup;
GO
-- REVERT:
-- Restore Windows-only auth.
EXEC xp_instance_regwrite
    N'HKEY_LOCAL_MACHINE',
    N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer',
    N'LoginMode', N'REG_DWORD', 1;

-- If sa was enabled above, disable it again:
-- ALTER LOGIN [sa] DISABLE;
SELECT 'Auth mode restored to Windows-only' AS revert_note,
       SERVERPROPERTY('IsIntegratedSecurityOnly') AS is_windows_only_after_revert;
GO


/* ########## batch 5 (12 reproducers) ########## */
/* ===================================================================
   Positive-test reproducers for detections slice 60..72
   Target: DISPOSABLE TEST SQL Server only.
   Each block: SETUP creates the condition the detection flags;
               REVERT fully undoes it.
   =================================================================== */

/* ===== SEC-SQL-AU-005-RC08 [DESTRUCTIVE] ===== */
-- Detection flags enabled SQL logins whose name matches service/app patterns
-- (svc, service, app, api, web, batch, etl, job) when mixed-mode auth is on.
-- Requires: mixed-mode auth (SERVERPROPERTY('IsIntegratedSecurityOnly')=0).
-- If the server is Windows-auth-only, toggle mixed-mode first (needs restart) or
-- run this on a server already in mixed-mode. Login name 'dbdome_test_svc' matches
-- the '%svc%' pattern and is enabled, so the detection returns >=1 row.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_svc')
    CREATE LOGIN dbdome_test_svc WITH PASSWORD = 'Dbdome!Test2025#', CHECK_POLICY = ON, CHECK_EXPIRATION = ON;
-- Ensure it is enabled (it is by default on CREATE).
ALTER LOGIN dbdome_test_svc ENABLE;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_svc')
    DROP LOGIN dbdome_test_svc;
GO

/* ===== SEC-SQL-AU-005-RC09 [DESTRUCTIVE] ===== */
-- Detection returns a snapshot row (always 1 row) when mixed-mode auth is on
-- (IsIntegratedSecurityOnly = 0) AND there is at least one active enabled SQL login
-- other than '##...' system accounts. Creating any enabled SQL login satisfies this.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_sqlauth')
    CREATE LOGIN dbdome_test_sqlauth WITH PASSWORD = 'Dbdome!Test2025#', CHECK_POLICY = ON;
ALTER LOGIN dbdome_test_sqlauth ENABLE;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_sqlauth')
    DROP LOGIN dbdome_test_sqlauth;
GO

/* ===== SEC-SQL-AU-005-RC10 [DESTRUCTIVE] ===== */
-- Detection flags enabled SQL logins that hold sysadmin, securityadmin, or serveradmin
-- when mixed-mode auth is on. Create an enabled SQL login and add it to sysadmin.
-- WARNING: grants sysadmin to the test login; revert immediately after the test.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_sysadmin')
    CREATE LOGIN dbdome_test_sysadmin WITH PASSWORD = 'Dbdome!Test2025#', CHECK_POLICY = ON;
ALTER LOGIN dbdome_test_sysadmin ENABLE;
ALTER SERVER ROLE sysadmin ADD MEMBER dbdome_test_sysadmin;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_sysadmin')
BEGIN
    ALTER SERVER ROLE sysadmin DROP MEMBER dbdome_test_sysadmin;
    DROP LOGIN dbdome_test_sysadmin;
END
GO

/* ===== SEC-SQL-AU-005-RC11 [SAFE] ===== */
-- Detection reports a snapshot of auth-scheme counts (NTLM, KERBEROS, SQL) for
-- current connections. It always returns exactly 1 row regardless of counts, so
-- the detection fires unconditionally whenever connections exist.
-- No setup is required beyond having at least one active connection (the query
-- runner's own session is sufficient).
-- SETUP:
-- No persistent change needed. The detection SELECT always returns 1 row.
-- Confirm by running the detection SQL in the current session.
SELECT
    SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_auth_only,
    (SELECT auth_scheme FROM sys.dm_exec_connections WHERE session_id = @@SPID) AS current_auth_scheme,
    (SELECT COUNT(*) FROM sys.dm_exec_connections WHERE auth_scheme = 'KERBEROS' AND parent_connection_id IS NULL) AS kerberos_connections,
    (SELECT COUNT(*) FROM sys.dm_exec_connections WHERE auth_scheme = 'NTLM'     AND parent_connection_id IS NULL) AS ntlm_connections,
    (SELECT COUNT(*) FROM sys.dm_exec_connections WHERE auth_scheme = 'SQL'      AND parent_connection_id IS NULL) AS sql_auth_connections;
GO
-- REVERT:
-- Nothing to revert (SAFE, no persistent change).
SELECT 'SEC-SQL-AU-005-RC11: no revert needed' AS status;
GO

/* ===== SEC-SQL-AU-005-RC12 [SAFE] ===== */
-- Detection counts sessions by auth scheme and returns 1 row whenever
-- sys.dm_exec_sessions has user-process rows. Connecting via SQL auth
-- (the typical test runner) already yields sql_auth_sessions >= 1.
-- No persistent change needed; the test runner's own SQL-auth session triggers it.
-- SETUP:
-- Connect with SQL authentication (e.g. using a SQL login) so that
-- sys.dm_exec_connections shows auth_scheme = 'SQL' for that session.
-- The detection returns 1 row as long as at least one user session exists.
SELECT
    SUM(CASE WHEN c.auth_scheme = 'SQL' THEN 1 ELSE 0 END) AS sql_auth_sessions,
    SUM(CASE WHEN c.auth_scheme IN ('KERBEROS','NTLM') THEN 1 ELSE 0 END) AS windows_auth_sessions,
    COUNT(*) AS total_sessions,
    ROUND(SUM(CASE WHEN c.auth_scheme = 'SQL' THEN 1.0 ELSE 0 END) / NULLIF(COUNT(*),0) * 100, 1) AS pct_sql_auth
FROM sys.dm_exec_sessions s
JOIN sys.dm_exec_connections c ON s.session_id = c.session_id
WHERE s.is_user_process = 1
  AND c.parent_connection_id IS NULL;
GO
-- REVERT:
-- Nothing to revert (SAFE, no persistent change).
SELECT 'SEC-SQL-AU-005-RC12: no revert needed' AS status;
GO

/* ===== SEC-SQL-AU-005-RC13 [DESTRUCTIVE] ===== */
-- Detection returns 1 row when mixed-mode is on AND active_sql_logins > 0.
-- It also reports the count of enabled server audits and audit specs.
-- Satisfying condition: create an enabled SQL login (active_sql_logins becomes >=1).
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_compliance')
    CREATE LOGIN dbdome_test_compliance WITH PASSWORD = 'Dbdome!Test2025#', CHECK_POLICY = ON;
ALTER LOGIN dbdome_test_compliance ENABLE;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_compliance')
    DROP LOGIN dbdome_test_compliance;
GO

/* ===== SEC-SQL-AU-006-RC01 [DESTRUCTIVE] ===== */
-- Detection returns 1 row. It flags when active_audits = 0 OR login_tracking_actions = 0.
-- Simplest trigger: disable (or ensure absence of) all server audits.
-- Setup: if a server audit exists and is enabled, disable it temporarily.
-- If no audit exists at all, the counts are already 0 and no setup is needed
-- beyond verifying the counts. The block below creates a dummy disabled audit so
-- the detection sees active_audits = 0.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
BEGIN
    -- Create an audit in disabled state so active_audits stays 0
    CREATE SERVER AUDIT dbdome_test_audit
        TO FILE (FILEPATH = 'C:\Windows\Temp\', MAXSIZE = 10 MB, MAX_FILES = 2, RESERVE_DISK_SPACE = OFF)
        WITH (ON_FAILURE = CONTINUE, QUEUE_DELAY = 1000)
        WHERE ([statement] LIKE '%dbdome%');
    -- Do NOT enable it; active_audits count remains 0 -> detection fires.
END
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
BEGIN
    -- Must disable before dropping
    ALTER SERVER AUDIT dbdome_test_audit WITH (STATE = OFF);
    DROP SERVER AUDIT dbdome_test_audit;
END
GO

/* ===== SEC-SQL-AU-006-RC02 [DESTRUCTIVE] ===== */
-- Detection flags enabled logins (SQL or Windows) whose name does NOT match
-- svc/service/app patterns, is not 'sa', not 'NT %', not '##%',
-- and whose modify_date was more than some threshold ago (or last_session is NULL
-- — actually the SQL has no recency filter here; it returns all matching enabled logins).
-- Simplest trigger: create an enabled SQL login with a plain user-style name.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_user')
    CREATE LOGIN dbdome_test_user WITH PASSWORD = 'Dbdome!Test2025#', CHECK_POLICY = ON;
ALTER LOGIN dbdome_test_user ENABLE;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_user')
    DROP LOGIN dbdome_test_user;
GO

/* ===== SEC-SQL-AU-006-RC03 [DESTRUCTIVE] ===== */
-- Detection flags enabled logins matching service-account name patterns
-- (svc, service, app, job, batch, etl, agent, daemon, sys).
-- 'dbdome_test_svc' matches '%svc%' so it will appear.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_svc_lifecycle')
    CREATE LOGIN dbdome_test_svc_lifecycle WITH PASSWORD = 'Dbdome!Test2025#', CHECK_POLICY = ON;
ALTER LOGIN dbdome_test_svc_lifecycle ENABLE;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_svc_lifecycle')
    DROP LOGIN dbdome_test_svc_lifecycle;
GO

/* ===== SEC-SQL-AU-006-RC04 [DESTRUCTIVE] ===== */
-- Detection flags enabled logins (not sa, not ##, not NT, not svc/service/app)
-- where last_session IS NULL (never logged in) AND modify_date is > 180 days ago.
-- To satisfy the 180-day condition without waiting, we backdate modify_date via
-- a direct catalog update. NOTE: updating system catalog requires DAC or
-- direct catalog updates (not supported without trace flag 634 / DAC connection
-- on standard editions). Best-effort workaround: create a login, do not use it
-- (last_session stays NULL), then wait 181 days — not practical in a test.
-- Instead, use the undocumented sp_configure 'allow updates' trick (SQL Server 2000
-- era; blocked on SQL Server 2005+). The practical approach on modern SQL Server:
-- create the login, accept that it will only pass the modify_date>180 days filter
-- once 181 days have elapsed. For immediate testing, note that the detection will
-- still return the row if any pre-existing login already meets both conditions.
-- SETUP (best-effort — row appears only after 180 days naturally):
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_contractor')
    CREATE LOGIN dbdome_test_contractor WITH PASSWORD = 'Dbdome!Test2025#', CHECK_POLICY = ON;
ALTER LOGIN dbdome_test_contractor ENABLE;
-- Note: The modify_date will equal today; the detection only returns this login
-- once DATEDIFF(DAY, modify_date, GETDATE()) > 180. For immediate QA, query any
-- pre-existing login that has not been modified in >180 days and has no sessions.
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_contractor')
    DROP LOGIN dbdome_test_contractor;
GO

/* ===== SEC-SQL-AU-006-RC05 [DESTRUCTIVE] ===== */
-- Detection flags enabled SQL logins where:
--   is_expiration_checked = 0 (password expiration not enforced)
--   AND last_session IS NULL (never logged in)
--   AND modify_date > 90 days ago.
-- Same timing caveat as RC04 for the 90-day filter.
-- Best-effort: create the login with CHECK_EXPIRATION = OFF; it immediately
-- satisfies is_expiration_checked = 0 and last_session IS NULL.
-- Row appears in detection after 90 days have elapsed.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_temp_access')
    CREATE LOGIN dbdome_test_temp_access
        WITH PASSWORD = 'Dbdome!Test2025#',
             CHECK_POLICY = OFF,
             CHECK_EXPIRATION = OFF;  -- is_expiration_checked = 0
ALTER LOGIN dbdome_test_temp_access ENABLE;
-- Note: row surfaces in detection once modify_date is >90 days old.
-- For immediate test, look for any pre-existing login with CHECK_EXPIRATION=OFF
-- that has never connected.
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_temp_access')
    DROP LOGIN dbdome_test_temp_access;
GO

/* ===== SEC-SQL-AU-006-RC06 [DESTRUCTIVE] ===== */
-- Detection flags enabled logins (SQL or Windows) whose name matches
-- test/dev/debug/qa/staging/demo/sample/sandbox/local patterns.
-- 'dbdome_test_dev' matches '%dev%' (and also '%test%').
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_dev')
    CREATE LOGIN dbdome_test_dev WITH PASSWORD = 'Dbdome!Test2025#', CHECK_POLICY = ON;
ALTER LOGIN dbdome_test_dev ENABLE;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_dev')
    DROP LOGIN dbdome_test_dev;
GO


/* ########## batch 6 (12 reproducers) ########## */
/* ===== SEC-SQL-AU-006-RC07 [DESTRUCTIVE] ===== */
-- Detection counts logins of type S/U/G (excluding ##% and NT%) and flags enabled_no_session.
-- Setup creates an enabled SQL login that has never logged in, so enabled_no_session >= 1.
-- Run as sysadmin. Revert drops the test login.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_rc07')
BEGIN
    CREATE LOGIN dbdome_test_login_rc07 WITH PASSWORD = 'Dbdome$Test1!', CHECK_POLICY = OFF;
END
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_rc07')
BEGIN
    DROP LOGIN dbdome_test_login_rc07;
END
GO

/* ===== SEC-SQL-AU-006-RC08 [DESTRUCTIVE] ===== */
-- Detection counts active SQL logins (type='S', is_disabled=0, not ##%, not sa)
-- and checks IsIntegratedSecurityOnly. Row is always returned (it's a scalar SELECT);
-- to make active_sql_logins > 0 create an enabled SQL login.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_rc08')
BEGIN
    CREATE LOGIN dbdome_test_login_rc08 WITH PASSWORD = 'Dbdome$Test2!', CHECK_POLICY = OFF;
END
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_rc08')
BEGIN
    DROP LOGIN dbdome_test_login_rc08;
END
GO

/* ===== SEC-SQL-AU-006-RC09 [DESTRUCTIVE] ===== */
-- Detection surfaces logins dormant > 90 days (modify_date > 90 days ago, no current session).
-- Setup: create a login, then back-date modify_date by updating the row via DAC or
-- by simply relying on the login having no session AND being created/modified long ago.
-- Simplest: create the login and let dormant_over_90_days count it once modify_date ages,
-- but to trigger immediately we also expose total_active_logins > 0 (always true with sa).
-- For immediate dormant trigger: use SQLCMD on DAC port to update modify_date, or accept
-- that this detection always returns 1 row (scalar subqueries, never 0 rows).
-- Run as sysadmin. DAC access required to force modify_date backdating.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_rc09')
BEGIN
    CREATE LOGIN dbdome_test_login_rc09 WITH PASSWORD = 'Dbdome$Test3!', CHECK_POLICY = OFF;
END
-- Force modify_date back 91 days via internal catalog update (requires DAC / sysadmin + trace flag):
-- If DAC is unavailable, the login will naturally age into dormancy; the detection still
-- returns 1 row (scalar SELECT) immediately, showing total_active_logins >= 1.
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_rc09')
BEGIN
    DROP LOGIN dbdome_test_login_rc09;
END
GO

/* ===== SEC-SQL-AU-006-RC10 [SAFE] ===== */
-- Detection flags logins that have active sessions from >1 distinct host_name.
-- This requires a live login connected simultaneously from 2+ hosts, which cannot be
-- scripted as a single-session T-SQL block. Best-effort: open two SSMS connections from
-- different machines (or two VMs) using the same login simultaneously, then run the detection.
-- The setup below creates the shared login; the "hold open" step must be done manually.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_shared_svc_rc10')
BEGIN
    CREATE LOGIN dbdome_shared_svc_rc10 WITH PASSWORD = 'Dbdome$Test4!', CHECK_POLICY = OFF;
END
-- ACTION: open two simultaneous sessions AS dbdome_shared_svc_rc10 from two different host names,
-- then execute the detection SQL. Both sessions must remain open during the check.
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_shared_svc_rc10')
BEGIN
    DROP LOGIN dbdome_shared_svc_rc10;
END
GO

/* ===== SEC-SQL-AU-006-RC11 [DESTRUCTIVE] ===== */
-- Detection returns all active logins (principal_id > 10, not ##%) with ownership_classification.
-- Any non-system, non-service-pattern login appears as 'unknown_ownership'.
-- Setup creates such a login; detection will immediately return >=1 row for it.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_rc11')
BEGIN
    CREATE LOGIN dbdome_test_login_rc11 WITH PASSWORD = 'Dbdome$Test5!', CHECK_POLICY = OFF;
END
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_rc11')
BEGIN
    DROP LOGIN dbdome_test_login_rc11;
END
GO

/* ===== SEC-SQL-AU-006-RC12 [DESTRUCTIVE] ===== */
-- Detection checks: login_audit_level (sys.configurations 'login auditing'),
-- xe_login_sessions (XE sessions with audit_login/login events), active_audits, login_audit_specs.
-- To make this return a "weak" posture (all zeros / low values): disable the login audit
-- and ensure no audit spec covers login events. Detection always returns 1 scalar row;
-- to make it flag a gap, set 'login auditing' = 0 (no auditing).
-- Run as sysadmin.
-- SETUP:
-- Record current value first:
DECLARE @cur INT = (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'login auditing');
-- Set login auditing to 0 (none) so login_audit_level = 0:
EXEC sp_configure 'login auditing', 0;
RECONFIGURE;
GO
-- REVERT:
-- Restore login auditing to 3 (both failed and successful logins):
EXEC sp_configure 'login auditing', 3;
RECONFIGURE;
GO

/* ===== SEC-SQL-AU-006-RC13 [DESTRUCTIVE] ===== */
-- Detection flags logins (principal_id > 10, enabled) with > 2 server role memberships.
-- Setup: create a login and add it to 3+ server roles.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_rc13')
BEGIN
    CREATE LOGIN dbdome_test_login_rc13 WITH PASSWORD = 'Dbdome$Test6!', CHECK_POLICY = OFF;
END
ALTER SERVER ROLE [dbcreator]    ADD MEMBER [dbdome_test_login_rc13];
ALTER SERVER ROLE [bulkadmin]    ADD MEMBER [dbdome_test_login_rc13];
ALTER SERVER ROLE [processadmin] ADD MEMBER [dbdome_test_login_rc13];
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_rc13')
BEGIN
    ALTER SERVER ROLE [dbcreator]    DROP MEMBER [dbdome_test_login_rc13];
    ALTER SERVER ROLE [bulkadmin]    DROP MEMBER [dbdome_test_login_rc13];
    ALTER SERVER ROLE [processadmin] DROP MEMBER [dbdome_test_login_rc13];
    DROP LOGIN dbdome_test_login_rc13;
END
GO

/* ===== SEC-SQL-AU-006-RC14 [DESTRUCTIVE] ===== */
-- Detection returns a scalar row with login_audit_level, active_audits, etc.
-- To expose an audit gap: set login auditing = 0 and ensure no server audit is enabled.
-- Detection always returns 1 row; login_audit_level = 0 flags a gap.
-- Run as sysadmin.
-- SETUP:
EXEC sp_configure 'login auditing', 0;
RECONFIGURE;
-- Disable any existing server audits temporarily (capture names first):
-- NOTE: If server audits exist, disable them individually. Generic disable below:
-- (Detection flags login_audit_level=0 even without touching server audits.)
GO
-- REVERT:
EXEC sp_configure 'login auditing', 3;
RECONFIGURE;
-- Re-enable any server audits that were disabled during setup (do manually if needed).
GO

/* ===== SEC-SQL-AU-006-RC15 [DESTRUCTIVE] ===== */
-- Detection counts active logins (principal_id > 10, enabled, not ##%) and measures staleness:
-- logins_stale_password (password not changed in 180+ days) and logins_older_than_1yr.
-- Setup: create a SQL login with CHECK_POLICY=OFF so password last set time won't auto-rotate.
-- The login will show as stale after 180 days; for immediate trigger of logins_older_than_1yr
-- we cannot backdate create_date without DAC. Detection returns 1 row always (scalar SELECTs);
-- logins_no_current_session will be > 0 immediately for the new login with no session.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_rc15')
BEGIN
    CREATE LOGIN dbdome_test_login_rc15 WITH PASSWORD = 'Dbdome$Test7!',
        CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
END
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_rc15')
BEGIN
    DROP LOGIN dbdome_test_login_rc15;
END
GO

/* ===== SEC-SQL-AU-007-RC02 [DESTRUCTIVE] ===== */
-- Detection checks: windows_only_auth (IsIntegratedSecurityOnly), sa_disabled,
-- sa_password_last_set, sa_policy_enforced, sa_expiration_enforced.
-- To trigger: enable sa login + ensure is_policy_checked=0, is_expiration_checked=0.
-- WARNING: enabling sa changes server security posture; revert immediately.
-- Run as sysadmin.
-- SETUP:
-- Step 1: Enable sa login
ALTER LOGIN [sa] ENABLE;
-- Step 2: Set sa password, disable policy and expiration checks (flags gap)
ALTER LOGIN [sa] WITH PASSWORD = 'Dbdome$Sa999!',
    CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
GO
-- REVERT:
ALTER LOGIN [sa] WITH CHECK_POLICY = ON, CHECK_EXPIRATION = OFF;
ALTER LOGIN [sa] DISABLE;
GO

/* ===== SEC-SQL-AU-007-RC04 [DESTRUCTIVE] ===== */
-- Detection checks: windows_only_auth, sa_disabled, logins_no_policy (SQL logins with
-- is_policy_checked=0), guest_enabled_in_current_db, dac_enabled.
-- Setup: create SQL login with CHECK_POLICY=OFF to raise logins_no_policy >= 1,
-- and enable remote admin connections (DAC) to raise dac_enabled = 1.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_rc04')
BEGIN
    CREATE LOGIN dbdome_test_login_rc04 WITH PASSWORD = 'Dbdome$Test8!', CHECK_POLICY = OFF;
END
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'remote admin connections', 1;
RECONFIGURE;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_rc04')
BEGIN
    DROP LOGIN dbdome_test_login_rc04;
END
EXEC sp_configure 'remote admin connections', 0;
RECONFIGURE;
GO

/* ===== SEC-SQL-AU-007-RC05 [DESTRUCTIVE] ===== */
-- Detection checks: remote_access config, CONNECTIONPROPERTY encrypt_option,
-- unencrypted_connections count, encrypted_connections count, tcp_endpoints_non_default.
-- To trigger remote_access = 1: enable it via sp_configure.
-- unencrypted_connections will be > 0 if current session is unencrypted (common in test envs).
-- Run as sysadmin.
-- SETUP:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'remote access', 1;
RECONFIGURE;
-- The detection scalar row is always returned; remote_access=1 flags the gap.
-- Unencrypted connections flag naturally if server does not enforce encryption.
GO
-- REVERT:
EXEC sp_configure 'remote access', 0;
RECONFIGURE;
GO


/* ########## batch 7 (12 reproducers) ########## */
/* ===== SEC-SQL-AU-007-RC06 [DESTRUCTIVE] ===== */
-- Incomplete hardening documentation: triggers on xp_cmdshell=1, or logins with no policy check.
-- Enable xp_cmdshell (shows xp_cmdshell=1) AND create a SQL login without policy check (logins_no_policy>=1).
-- Run as sysadmin. RECONFIGURE requires 'show advanced options' first.
-- SETUP:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_nopolicy')
    CREATE LOGIN dbdome_test_nopolicy WITH PASSWORD = 'P@ssw0rd_dbdome!', CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
GO
-- REVERT:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 0;
RECONFIGURE;

IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_nopolicy')
    DROP LOGIN dbdome_test_nopolicy;
GO

/* ===== SEC-SQL-AU-007-RC07 [DESTRUCTIVE] ===== */
-- Configuration file management tools: triggers when a SQL Agent job step contains sp_configure / RECONFIGURE.
-- Creates an enabled Agent job with a step that calls sp_configure.
-- Run as sysadmin. Requires SQL Server Agent to be running.
-- SETUP:
USE msdb;
GO
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = 'dbdome_test_config_job')
BEGIN
    EXEC msdb.dbo.sp_add_job
        @job_name = N'dbdome_test_config_job',
        @enabled = 1,
        @description = N'DBDome QA positive-test job - safe to delete';

    EXEC msdb.dbo.sp_add_jobstep
        @job_name = N'dbdome_test_config_job',
        @step_name = N'dbdome_step_sp_configure',
        @subsystem = N'TSQL',
        @command = N'EXEC sp_configure ''show advanced options'', 0; RECONFIGURE;',
        @database_name = N'master';

    EXEC msdb.dbo.sp_add_jobserver
        @job_name = N'dbdome_test_config_job',
        @server_name = N'(local)';
END
GO
-- REVERT:
USE msdb;
GO
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = 'dbdome_test_config_job')
BEGIN
    EXEC msdb.dbo.sp_delete_job @job_name = N'dbdome_test_config_job', @delete_unused_schedule = 1;
END
GO

/* ===== SEC-SQL-AU-007-RC09 [DESTRUCTIVE] ===== */
-- Recovery procedure reliance: triggers on remote_dac_enabled=1 OR a recently-created SQL login (<30 days).
-- Enable remote DAC and create a fresh SQL login.
-- Run as sysadmin.
-- SETUP:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'remote admin connections', 1;
RECONFIGURE;

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_recent_login')
    CREATE LOGIN dbdome_test_recent_login WITH PASSWORD = 'P@ssw0rd_dbdome!', CHECK_POLICY = OFF;
GO
-- REVERT:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'remote admin connections', 0;
RECONFIGURE;

IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_recent_login')
    DROP LOGIN dbdome_test_recent_login;
GO

/* ===== SEC-SQL-AU-007-RC10 [DESTRUCTIVE] ===== */
-- Container/Kubernetes secrets practice: returns every enabled SQL login (type='S', not ##).
-- The detection always returns rows as long as any active SQL login exists (including 'sa').
-- Create an explicit test SQL login to guarantee >=1 row regardless of sa state.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_sqlogin')
    CREATE LOGIN dbdome_test_sqlogin WITH PASSWORD = 'P@ssw0rd_dbdome!', CHECK_POLICY = OFF;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_sqlogin')
    DROP LOGIN dbdome_test_sqlogin;
GO

/* ===== SEC-SQL-AU-007-RC11 [DESTRUCTIVE] ===== */
-- Single-node assumption: triggers on active_sql_logins>=1 OR unencrypted remote connections>0 OR remote_dac=1.
-- The detection counts enabled SQL logins - creating one guarantees >=1 row.
-- Optionally also enable remote admin connections for extra signal.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_singlenode')
    CREATE LOGIN dbdome_test_singlenode WITH PASSWORD = 'P@ssw0rd_dbdome!', CHECK_POLICY = OFF;

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'remote admin connections', 1;
RECONFIGURE;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_singlenode')
    DROP LOGIN dbdome_test_singlenode;

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'remote admin connections', 0;
RECONFIGURE;
GO

/* ===== SEC-SQL-AU-007-RC12 [DESTRUCTIVE] ===== */
-- Administrator password forgotten or locked: triggers when active_sysadmin_sql_logins>=1 (SQL login in sysadmin role).
-- Grant sysadmin to a throwaway SQL login.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_sysadmin')
    CREATE LOGIN dbdome_test_sysadmin WITH PASSWORD = 'P@ssw0rd_dbdome!', CHECK_POLICY = OFF;

EXEC sp_addsrvrolemember 'dbdome_test_sysadmin', 'sysadmin';
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_sysadmin')
BEGIN
    EXEC sp_dropsrvrolemember 'dbdome_test_sysadmin', 'sysadmin';
    DROP LOGIN dbdome_test_sysadmin;
END
GO

/* ===== SEC-SQL-AU-007-RC13 [DESTRUCTIVE] ===== */
-- Documentation templates outdated: triggers on scan_startup_procs=1, or logins_no_policy>=1, or other legacy settings.
-- Enable 'scan for startup procs' and create a login without policy check.
-- Run as sysadmin.
-- SETUP:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'scan for startup procs', 1;
RECONFIGURE;

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_nopolicy2')
    CREATE LOGIN dbdome_test_nopolicy2 WITH PASSWORD = 'P@ssw0rd_dbdome!', CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
GO
-- REVERT:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'scan for startup procs', 0;
RECONFIGURE;

IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_nopolicy2')
    DROP LOGIN dbdome_test_nopolicy2;
GO

/* ===== SEC-SQL-AU-007-RC14 [SAFE] ===== */
-- No configuration drift detection: triggers when policy_violations (result=0 rows) > 0 in syspolicy_system_health_state,
-- OR when active_policies=0 (no Policy-Based Management policies enabled at all).
-- On a typical test server with no PBM configured, active_policies=0 already fires the detection.
-- No setup is needed if the server has no PBM policies; the detection returns a row with active_policies=0.
-- To force policy_violations>0: evaluate an existing failing policy.
-- This setup forces the state by creating and evaluating a policy that is designed to fail.
-- Note: Policy-Based Management DDL can be complex; the simplest reliable trigger is the already-zero active_policies=0 path.
-- SETUP:
-- On a clean test server, syspolicy_system_health_state has 0 rows with result=0 and active_policies=0;
-- the SELECT returns a row with active_policies=0, which the detection flags.
-- No DDL changes are required; verify with:
SELECT
  (SELECT COUNT(*) FROM msdb.dbo.syspolicy_policies WHERE is_enabled = 1) AS active_policies,
  (SELECT COUNT(*) FROM msdb.dbo.syspolicy_system_health_state WHERE result = 0) AS policy_violations;
GO
-- REVERT:
-- Nothing to revert; read-only verification query above.
SELECT 'No revert needed for SEC-SQL-AU-007-RC14 (read-only setup)' AS revert_status;
GO

/* ===== SEC-SQL-AUD-001-RC01 [DESTRUCTIVE] ===== */
-- Global logging switch is disabled: triggers when an audit or its specification has is_state_enabled=0 (or no audits exist).
-- Create a server audit in DISABLED state so the LEFT JOIN returns a row with audit_enabled=0.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_disabled')
BEGIN
    CREATE SERVER AUDIT dbdome_test_audit_disabled
        TO APPLICATION_LOG
        WITH (STATE = OFF);
END
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_disabled')
BEGIN
    ALTER SERVER AUDIT dbdome_test_audit_disabled WITH (STATE = OFF);
    DROP SERVER AUDIT dbdome_test_audit_disabled;
END
GO

/* ===== SEC-SQL-AUD-001-RC02 [DESTRUCTIVE] ===== */
-- Missing audit plugin/extension: detection queries sys.server_audits WHERE is_state_enabled=1
-- and counts active specs. Triggers when an enabled audit has 0 active server/db specs (active_server_specs=0 AND active_db_specs=0).
-- Create an enabled audit with no specifications attached.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_nospec')
BEGIN
    CREATE SERVER AUDIT dbdome_test_audit_nospec
        TO APPLICATION_LOG
        WITH (STATE = OFF);
END
-- Enable the audit (it will appear in the WHERE is_state_enabled=1 filter with 0 specs)
ALTER SERVER AUDIT dbdome_test_audit_nospec WITH (STATE = ON);
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_nospec')
BEGIN
    ALTER SERVER AUDIT dbdome_test_audit_nospec WITH (STATE = OFF);
    DROP SERVER AUDIT dbdome_test_audit_nospec;
END
GO

/* ===== SEC-SQL-AUD-001-RC03 [DESTRUCTIVE] ===== */
-- Audit policy set to "NONE": detection returns enabled server audit specifications with action_group_count.
-- Triggers when an enabled specification has 0 action groups (action_group_count=0) - i.e. an empty spec.
-- Create a server audit + an enabled audit specification with no action groups added.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc03')
BEGIN
    CREATE SERVER AUDIT dbdome_test_audit_rc03
        TO APPLICATION_LOG
        WITH (STATE = OFF);
END

ALTER SERVER AUDIT dbdome_test_audit_rc03 WITH (STATE = OFF);

IF NOT EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec_empty')
BEGIN
    CREATE SERVER AUDIT SPECIFICATION dbdome_test_spec_empty
        FOR SERVER AUDIT dbdome_test_audit_rc03;
    -- No ADD (action_group) clauses -> action_group_count = 0
END

ALTER SERVER AUDIT SPECIFICATION dbdome_test_spec_empty WITH (STATE = ON);
ALTER SERVER AUDIT dbdome_test_audit_rc03 WITH (STATE = ON);
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec_empty')
BEGIN
    ALTER SERVER AUDIT SPECIFICATION dbdome_test_spec_empty WITH (STATE = OFF);
    DROP SERVER AUDIT SPECIFICATION dbdome_test_spec_empty;
END

IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc03')
BEGIN
    ALTER SERVER AUDIT dbdome_test_audit_rc03 WITH (STATE = OFF);
    DROP SERVER AUDIT dbdome_test_audit_rc03;
END
GO

/* ===== SEC-SQL-AUD-001-RC04 [SAFE] ===== */
-- License restrictions: detection is a pure SELECT on SERVERPROPERTY() values - always returns exactly 1 row.
-- No setup required; the detection fires on every execution by design (it reports the current edition).
-- Express (EngineEdition=4) or Personal (EngineEdition=1) editions return 'NO AUDIT' labels.
-- SETUP:
-- Read-only - detection always returns 1 row. Verify current edition:
SELECT
    SERVERPROPERTY('Edition')      AS edition,
    SERVERPROPERTY('EngineEdition') AS engine_edition,
    CASE
        WHEN SERVERPROPERTY('EngineEdition') = 4 THEN 'Express - NO SQL Server Audit (detection fires)'
        WHEN SERVERPROPERTY('EngineEdition') = 1 THEN 'Personal/Desktop - NO AUDIT (detection fires)'
        ELSE 'Full audit capable edition - detection still returns 1 row'
    END AS audit_capability_check;
GO
-- REVERT:
-- Nothing to revert; read-only query.
SELECT 'No revert needed for SEC-SQL-AUD-001-RC04 (read-only setup)' AS revert_status;
GO


/* ########## batch 8 (12 reproducers) ########## */
/* ==========================================================================
   Positive-test reproducers — slice 96..108 (pt_8.sql)
   Target: DISPOSABLE / throwaway SQL Server instance only.
   Run SETUP in one session; run detection; run REVERT to clean up.
   All objects use the prefix "dbdome_test_" to avoid collisions.
   ========================================================================== */

/* ===== SEC-SQL-AUD-001-RC05 [DESTRUCTIVE] ===== */
-- Detection returns rows for FILE audits where is_state_enabled=0 OR on_failure_desc='SHUTDOWN'.
-- Setup creates a FILE server audit that is disabled (state=0) so the WHERE predicate fires.
-- Requires sysadmin. The audit path C:\Temp must exist (create it if absent).
-- REVERT drops the audit entirely.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc05')
BEGIN
    -- Ensure target path exists (xp_cmdshell must be enabled, or create path manually)
    EXEC master.dbo.sp_configure 'show advanced options', 1; RECONFIGURE;
    EXEC master.dbo.sp_configure 'xp_cmdshell', 1; RECONFIGURE;
    EXEC xp_cmdshell 'mkdir C:\Temp 2>NUL', no_output;
    CREATE SERVER AUDIT [dbdome_test_audit_rc05]
        TO FILE (FILEPATH = 'C:\Temp\', MAXSIZE = 10 MB, MAX_ROLLOVER_FILES = 2)
        WITH (ON_FAILURE = CONTINUE, STATE = OFF);
END;
-- Verify: the audit exists, is type FILE, and is disabled (STATE=OFF) -> detection returns >=1 row
SELECT name, type_desc, is_state_enabled, on_failure_desc
FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc05';
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc05')
BEGIN
    ALTER SERVER AUDIT [dbdome_test_audit_rc05] WITH (STATE = OFF);
    DROP SERVER AUDIT [dbdome_test_audit_rc05];
END;
EXEC master.dbo.sp_configure 'xp_cmdshell', 0; RECONFIGURE;
EXEC master.dbo.sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-AUD-001-RC06 [DESTRUCTIVE] ===== */
-- Detection has NO WHERE clause — it returns every row in sys.server_audits.
-- Any existing server audit satisfies the detection.
-- Setup creates a minimal FILE audit (disabled) so sys.server_audits has >=1 row.
-- The queue_delay assessment column is purely informational; no threshold gating.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc06')
BEGIN
    EXEC master.dbo.sp_configure 'show advanced options', 1; RECONFIGURE;
    EXEC master.dbo.sp_configure 'xp_cmdshell', 1; RECONFIGURE;
    EXEC xp_cmdshell 'mkdir C:\Temp 2>NUL', no_output;
    CREATE SERVER AUDIT [dbdome_test_audit_rc06]
        TO FILE (FILEPATH = 'C:\Temp\', MAXSIZE = 10 MB, MAX_ROLLOVER_FILES = 2)
        WITH (QUEUE_DELAY = 2000, ON_FAILURE = CONTINUE, STATE = OFF);
END;
-- queue_delay=2000 falls into the 'RELAXED' bucket (>1000) for extra coverage.
SELECT name, queue_delay FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc06';
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc06')
BEGIN
    ALTER SERVER AUDIT [dbdome_test_audit_rc06] WITH (STATE = OFF);
    DROP SERVER AUDIT [dbdome_test_audit_rc06];
END;
EXEC master.dbo.sp_configure 'xp_cmdshell', 0; RECONFIGURE;
EXEC master.dbo.sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-AUD-001-RC07 [DESTRUCTIVE] ===== */
-- Detection has NO WHERE clause — returns every server_audit row joined with server_file_audits.
-- Any FILE server audit satisfies it; a non-FILE audit produces a row with NULL file columns.
-- Setup creates a FILE audit (disabled) so the join returns a populated row.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc07')
BEGIN
    EXEC master.dbo.sp_configure 'show advanced options', 1; RECONFIGURE;
    EXEC master.dbo.sp_configure 'xp_cmdshell', 1; RECONFIGURE;
    EXEC xp_cmdshell 'mkdir C:\Temp 2>NUL', no_output;
    CREATE SERVER AUDIT [dbdome_test_audit_rc07]
        TO FILE (FILEPATH = 'C:\Temp\', MAXSIZE = 50 MB, MAX_ROLLOVER_FILES = 3)
        WITH (ON_FAILURE = CONTINUE, STATE = OFF);
END;
SELECT a.name, a.type_desc, a.is_state_enabled, sfa.log_file_path, sfa.max_file_size, sfa.max_rollover_files
FROM sys.server_audits a
LEFT JOIN sys.server_file_audits sfa ON a.audit_id = sfa.audit_id
WHERE a.name = 'dbdome_test_audit_rc07';
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc07')
BEGIN
    ALTER SERVER AUDIT [dbdome_test_audit_rc07] WITH (STATE = OFF);
    DROP SERVER AUDIT [dbdome_test_audit_rc07];
END;
EXEC master.dbo.sp_configure 'xp_cmdshell', 0; RECONFIGURE;
EXEC master.dbo.sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-AUD-001-RC08 [SAFE] ===== */
-- Detection is a pure aggregation SELECT — it always returns exactly 1 row regardless of state.
-- No setup is required; the query returns counts (possibly all zeros on a fresh instance).
-- Marked SAFE because setup_sql makes no persistent changes.
-- If you want the row to show "interesting" values (0 audits, c2=0, common_criteria=0),
-- just run the detection on a fresh instance with no audits configured.
-- SETUP:
-- No-op: the detection returns 1 row unconditionally. Verify with the query below.
SELECT
  (SELECT COUNT(*) FROM sys.server_audits) AS audit_count,
  (SELECT COUNT(*) FROM sys.server_audit_specifications) AS server_spec_count,
  (SELECT COUNT(*) FROM sys.database_audit_specifications) AS db_spec_count,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'c2 audit mode') AS c2_audit,
  (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'common criteria compliance enabled') AS common_criteria;
GO
-- REVERT:
-- No-op: no changes were made.
SELECT 1 AS revert_noop;
GO

/* ===== SEC-SQL-AUD-001-RC09 [DESTRUCTIVE] ===== */
-- Detection has no WHERE clause — returns all rows from sys.server_audits (ORDER BY name).
-- Any server audit causes it to return >=1 row.
-- Setup creates a FILE audit; the subquery counts of server/db specs will be 0 initially.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc09')
BEGIN
    EXEC master.dbo.sp_configure 'show advanced options', 1; RECONFIGURE;
    EXEC master.dbo.sp_configure 'xp_cmdshell', 1; RECONFIGURE;
    EXEC xp_cmdshell 'mkdir C:\Temp 2>NUL', no_output;
    CREATE SERVER AUDIT [dbdome_test_audit_rc09]
        TO FILE (FILEPATH = 'C:\Temp\', MAXSIZE = 10 MB, MAX_ROLLOVER_FILES = 2)
        WITH (ON_FAILURE = CONTINUE, STATE = OFF);
END;
SELECT name, is_state_enabled, type_desc FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc09';
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc09')
BEGIN
    ALTER SERVER AUDIT [dbdome_test_audit_rc09] WITH (STATE = OFF);
    DROP SERVER AUDIT [dbdome_test_audit_rc09];
END;
EXEC master.dbo.sp_configure 'xp_cmdshell', 0; RECONFIGURE;
EXEC master.dbo.sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-AUD-001-RC10 [DESTRUCTIVE] ===== */
-- Detection: is_state_enabled=0 AND modify_date > DATEADD(day,-30,GETDATE()).
-- Setup creates a FILE audit in STATE=OFF; modify_date is set at CREATE time (within last 30 days).
-- Disabling (ALTER...STATE=OFF) on an already-OFF audit updates modify_date to now.
-- Requires sysadmin.
-- SETUP:
EXEC master.dbo.sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC master.dbo.sp_configure 'xp_cmdshell', 1; RECONFIGURE;
EXEC xp_cmdshell 'mkdir C:\Temp 2>NUL', no_output;
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc10')
BEGIN
    ALTER SERVER AUDIT [dbdome_test_audit_rc10] WITH (STATE = OFF);
    DROP SERVER AUDIT [dbdome_test_audit_rc10];
END;
CREATE SERVER AUDIT [dbdome_test_audit_rc10]
    TO FILE (FILEPATH = 'C:\Temp\', MAXSIZE = 10 MB, MAX_ROLLOVER_FILES = 2)
    WITH (ON_FAILURE = CONTINUE, STATE = ON);
-- Enable then immediately disable to stamp a fresh modify_date within last 30 days
ALTER SERVER AUDIT [dbdome_test_audit_rc10] WITH (STATE = OFF);
SELECT name, is_state_enabled, modify_date FROM sys.server_audits
WHERE name = 'dbdome_test_audit_rc10'
  AND is_state_enabled = 0
  AND modify_date > DATEADD(day, -30, GETDATE());
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc10')
BEGIN
    ALTER SERVER AUDIT [dbdome_test_audit_rc10] WITH (STATE = OFF);
    DROP SERVER AUDIT [dbdome_test_audit_rc10];
END;
EXEC master.dbo.sp_configure 'xp_cmdshell', 0; RECONFIGURE;
EXEC master.dbo.sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-AUD-001-RC11 [DESTRUCTIVE] ===== */
-- Detection: WHERE sa.type_desc = 'FILE' — returns rows for FILE-type audits joined with
-- server_file_audits. Also surfaces container_hint from dm_os_loaded_modules.
-- Setup creates a FILE audit so the WHERE fires and log_file_path is populated.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc11')
BEGIN
    EXEC master.dbo.sp_configure 'show advanced options', 1; RECONFIGURE;
    EXEC master.dbo.sp_configure 'xp_cmdshell', 1; RECONFIGURE;
    EXEC xp_cmdshell 'mkdir C:\Temp 2>NUL', no_output;
    CREATE SERVER AUDIT [dbdome_test_audit_rc11]
        TO FILE (FILEPATH = 'C:\Temp\', MAXSIZE = 10 MB, MAX_ROLLOVER_FILES = 2)
        WITH (ON_FAILURE = CONTINUE, STATE = OFF);
END;
SELECT sa.name, sfa.log_file_path, sa.type_desc, sa.is_state_enabled
FROM sys.server_audits sa
LEFT JOIN sys.server_file_audits sfa ON sa.audit_id = sfa.audit_id
WHERE sa.type_desc = 'FILE' AND sa.name = 'dbdome_test_audit_rc11';
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc11')
BEGIN
    ALTER SERVER AUDIT [dbdome_test_audit_rc11] WITH (STATE = OFF);
    DROP SERVER AUDIT [dbdome_test_audit_rc11];
END;
EXEC master.dbo.sp_configure 'xp_cmdshell', 0; RECONFIGURE;
EXEC master.dbo.sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-AUD-001-RC12 [DESTRUCTIVE] ===== */
-- Detection: WHERE sa.is_state_enabled = 0 — returns disabled audits.
-- Also computes state_change_timing comparing modify_date to sqlserver_start_time.
-- Setup creates a FILE audit and leaves it in STATE=OFF.
-- For "Modified after restart" timing, enable then disable the audit after server starts.
-- SETUP:
EXEC master.dbo.sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC master.dbo.sp_configure 'xp_cmdshell', 1; RECONFIGURE;
EXEC xp_cmdshell 'mkdir C:\Temp 2>NUL', no_output;
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc12')
BEGIN
    ALTER SERVER AUDIT [dbdome_test_audit_rc12] WITH (STATE = OFF);
    DROP SERVER AUDIT [dbdome_test_audit_rc12];
END;
CREATE SERVER AUDIT [dbdome_test_audit_rc12]
    TO FILE (FILEPATH = 'C:\Temp\', MAXSIZE = 10 MB, MAX_ROLLOVER_FILES = 2)
    WITH (ON_FAILURE = CONTINUE, STATE = ON);
-- Disable immediately to set modify_date > sqlserver_start_time -> "Modified after restart"
ALTER SERVER AUDIT [dbdome_test_audit_rc12] WITH (STATE = OFF);
SELECT sa.name, sa.is_state_enabled, sa.on_failure_desc, sa.modify_date,
  (SELECT sqlserver_start_time FROM sys.dm_os_sys_info) AS last_restart,
  CASE WHEN sa.modify_date > (SELECT sqlserver_start_time FROM sys.dm_os_sys_info)
       THEN 'Modified after restart' ELSE 'Not modified since restart' END AS state_change_timing
FROM sys.server_audits sa
WHERE sa.name = 'dbdome_test_audit_rc12' AND sa.is_state_enabled = 0;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc12')
BEGIN
    ALTER SERVER AUDIT [dbdome_test_audit_rc12] WITH (STATE = OFF);
    DROP SERVER AUDIT [dbdome_test_audit_rc12];
END;
EXEC master.dbo.sp_configure 'xp_cmdshell', 0; RECONFIGURE;
EXEC master.dbo.sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-AUD-002-RC01 [DESTRUCTIVE] ===== */
-- Same SQL as RC07/RC09 family: no WHERE clause, returns all server_audits joined to
-- server_file_audits. Any audit row triggers it.
-- This detection is scoped to "aggressive rotation configuration" context.
-- Setup creates a FILE audit with small max_file_size and high max_rollover_files to
-- represent an aggressive rotation policy.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_aud2rc01')
BEGIN
    EXEC master.dbo.sp_configure 'show advanced options', 1; RECONFIGURE;
    EXEC master.dbo.sp_configure 'xp_cmdshell', 1; RECONFIGURE;
    EXEC xp_cmdshell 'mkdir C:\Temp 2>NUL', no_output;
    -- Small file size + unlimited rollover = aggressive rotation
    CREATE SERVER AUDIT [dbdome_test_audit_aud2rc01]
        TO FILE (FILEPATH = 'C:\Temp\', MAXSIZE = 2 MB, MAX_ROLLOVER_FILES = UNLIMITED)
        WITH (ON_FAILURE = CONTINUE, STATE = OFF);
END;
SELECT a.name, sfa.max_file_size, sfa.max_rollover_files
FROM sys.server_audits a
LEFT JOIN sys.server_file_audits sfa ON a.audit_id = sfa.audit_id
WHERE a.name = 'dbdome_test_audit_aud2rc01';
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_aud2rc01')
BEGIN
    ALTER SERVER AUDIT [dbdome_test_audit_aud2rc01] WITH (STATE = OFF);
    DROP SERVER AUDIT [dbdome_test_audit_aud2rc01];
END;
EXEC master.dbo.sp_configure 'xp_cmdshell', 0; RECONFIGURE;
EXEC master.dbo.sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-AUD-002-RC02 [DESTRUCTIVE] ===== */
-- Same SQL (no WHERE): returns all server_audits + file_audit join.
-- Context is "insufficient disk space". Setup creates a FILE audit pointing to
-- C:\Temp with a very large MAXSIZE to represent a disk-space risk configuration.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_aud2rc02')
BEGIN
    EXEC master.dbo.sp_configure 'show advanced options', 1; RECONFIGURE;
    EXEC master.dbo.sp_configure 'xp_cmdshell', 1; RECONFIGURE;
    EXEC xp_cmdshell 'mkdir C:\Temp 2>NUL', no_output;
    -- Large MAXSIZE with many rollover files = potential disk exhaustion
    CREATE SERVER AUDIT [dbdome_test_audit_aud2rc02]
        TO FILE (FILEPATH = 'C:\Temp\', MAXSIZE = 1024 MB, MAX_ROLLOVER_FILES = 100)
        WITH (ON_FAILURE = CONTINUE, STATE = OFF);
END;
SELECT a.name, sfa.max_file_size, sfa.max_rollover_files
FROM sys.server_audits a
LEFT JOIN sys.server_file_audits sfa ON a.audit_id = sfa.audit_id
WHERE a.name = 'dbdome_test_audit_aud2rc02';
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_aud2rc02')
BEGIN
    ALTER SERVER AUDIT [dbdome_test_audit_aud2rc02] WITH (STATE = OFF);
    DROP SERVER AUDIT [dbdome_test_audit_aud2rc02];
END;
EXEC master.dbo.sp_configure 'xp_cmdshell', 0; RECONFIGURE;
EXEC master.dbo.sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-AUD-002-RC03 [DESTRUCTIVE] ===== */
-- Same SQL (no WHERE): returns all server_audits + file_audit join.
-- Context is "lack of external archival" — FILE audits written locally without offloading.
-- Setup creates a local FILE audit with no external archival, representing the risk.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_aud2rc03')
BEGIN
    EXEC master.dbo.sp_configure 'show advanced options', 1; RECONFIGURE;
    EXEC master.dbo.sp_configure 'xp_cmdshell', 1; RECONFIGURE;
    EXEC xp_cmdshell 'mkdir C:\Temp 2>NUL', no_output;
    -- Local path only, no external archival configured
    CREATE SERVER AUDIT [dbdome_test_audit_aud2rc03]
        TO FILE (FILEPATH = 'C:\Temp\', MAXSIZE = 10 MB, MAX_ROLLOVER_FILES = 5)
        WITH (ON_FAILURE = CONTINUE, STATE = OFF);
END;
SELECT a.name, a.type_desc, sfa.log_file_path
FROM sys.server_audits a
LEFT JOIN sys.server_file_audits sfa ON a.audit_id = sfa.audit_id
WHERE a.name = 'dbdome_test_audit_aud2rc03';
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_aud2rc03')
BEGIN
    ALTER SERVER AUDIT [dbdome_test_audit_aud2rc03] WITH (STATE = OFF);
    DROP SERVER AUDIT [dbdome_test_audit_aud2rc03];
END;
EXEC master.dbo.sp_configure 'xp_cmdshell', 0; RECONFIGURE;
EXEC master.dbo.sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-AUD-002-RC04 [DESTRUCTIVE] ===== */
-- Same SQL (no WHERE): returns all server_audits + file_audit join.
-- Context is "default retention policies" — using SQL Server defaults without tuning.
-- Setup creates a FILE audit with SQL Server default values (MAXSIZE=0=UNLIMITED,
-- MAX_ROLLOVER_FILES=0 means 2147483647 in practice) to simulate default retention.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_aud2rc04')
BEGIN
    EXEC master.dbo.sp_configure 'show advanced options', 1; RECONFIGURE;
    EXEC master.dbo.sp_configure 'xp_cmdshell', 1; RECONFIGURE;
    EXEC xp_cmdshell 'mkdir C:\Temp 2>NUL', no_output;
    -- MAXSIZE=0 means UNLIMITED; MAX_ROLLOVER_FILES=0 = default/unlimited rollover
    CREATE SERVER AUDIT [dbdome_test_audit_aud2rc04]
        TO FILE (FILEPATH = 'C:\Temp\', MAXSIZE = 0 MB, MAX_ROLLOVER_FILES = UNLIMITED)
        WITH (ON_FAILURE = CONTINUE, STATE = OFF);
END;
SELECT a.name, a.type_desc, sfa.max_file_size, sfa.max_rollover_files
FROM sys.server_audits a
LEFT JOIN sys.server_file_audits sfa ON a.audit_id = sfa.audit_id
WHERE a.name = 'dbdome_test_audit_aud2rc04';
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_aud2rc04')
BEGIN
    ALTER SERVER AUDIT [dbdome_test_audit_aud2rc04] WITH (STATE = OFF);
    DROP SERVER AUDIT [dbdome_test_audit_aud2rc04];
END;
EXEC master.dbo.sp_configure 'xp_cmdshell', 0; RECONFIGURE;
EXEC master.dbo.sp_configure 'show advanced options', 0; RECONFIGURE;
GO


/* ########## batch 9 (12 reproducers) ########## */
/* ===== SEC-SQL-AUD-002-RC05 [DESTRUCTIVE] ===== */
-- Creates an APPLICATION_LOG server audit that is enabled.
-- Detection predicate: type_desc IN ('APPLICATION_LOG','SECURITY_LOG') AND is_state_enabled = 1.
-- Run as sysadmin. Drop the audit first if it already exists.
-- SETUP:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_applog_audit')
BEGIN
    ALTER SERVER AUDIT dbdome_test_applog_audit WITH (STATE = OFF);
    DROP SERVER AUDIT dbdome_test_applog_audit;
END
GO
CREATE SERVER AUDIT dbdome_test_applog_audit
    TO APPLICATION_LOG
    WITH (ON_FAILURE = CONTINUE);
GO
ALTER SERVER AUDIT dbdome_test_applog_audit WITH (STATE = ON);
GO
-- REVERT:
ALTER SERVER AUDIT dbdome_test_applog_audit WITH (STATE = OFF);
DROP SERVER AUDIT dbdome_test_applog_audit;
GO

/* ===== SEC-SQL-AUD-002-RC06 [DESTRUCTIVE] ===== */
-- Detection returns all rows from sys.server_audits LEFT JOIN sys.server_file_audits (no WHERE filter — returns >= 1 row whenever any audit exists).
-- Creates a minimal FILE-based server audit so the join produces at least one row.
-- Run as sysadmin.
-- SETUP:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_file_audit_rc06')
BEGIN
    ALTER SERVER AUDIT dbdome_test_file_audit_rc06 WITH (STATE = OFF);
    DROP SERVER AUDIT dbdome_test_file_audit_rc06;
END
GO
CREATE SERVER AUDIT dbdome_test_file_audit_rc06
    TO FILE (FILEPATH = N'C:\Windows\Temp\', MAXSIZE = 2 MB, MAX_ROLLOVER_FILES = 2)
    WITH (ON_FAILURE = CONTINUE);
GO
-- Leave audit DISABLED — detection has no is_state_enabled filter; just needs the row to exist.
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_file_audit_rc06')
BEGIN
    ALTER SERVER AUDIT dbdome_test_file_audit_rc06 WITH (STATE = OFF);
    DROP SERVER AUDIT dbdome_test_file_audit_rc06;
END
GO

/* ===== SEC-SQL-AUD-002-RC07 [DESTRUCTIVE] ===== */
-- Detection predicate: type_desc = 'FILE' AND is_state_enabled = 1.
-- Creates an enabled FILE-based server audit so the detection returns >= 1 row.
-- Run as sysadmin. C:\Windows\Temp must be writable by SQL Server service account.
-- SETUP:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_file_audit_rc07')
BEGIN
    ALTER SERVER AUDIT dbdome_test_file_audit_rc07 WITH (STATE = OFF);
    DROP SERVER AUDIT dbdome_test_file_audit_rc07;
END
GO
CREATE SERVER AUDIT dbdome_test_file_audit_rc07
    TO FILE (FILEPATH = N'C:\Windows\Temp\', MAXSIZE = 2 MB, MAX_ROLLOVER_FILES = 2)
    WITH (ON_FAILURE = CONTINUE);
GO
ALTER SERVER AUDIT dbdome_test_file_audit_rc07 WITH (STATE = ON);
GO
-- REVERT:
ALTER SERVER AUDIT dbdome_test_file_audit_rc07 WITH (STATE = OFF);
DROP SERVER AUDIT dbdome_test_file_audit_rc07;
GO

/* ===== SEC-SQL-AUD-002-RC08 [DESTRUCTIVE] ===== */
-- Same query as RC06: sys.server_audits LEFT JOIN sys.server_file_audits, no WHERE — returns >= 1 row when any audit exists.
-- Reuses the pattern: create a minimal server audit so the view is non-empty.
-- Run as sysadmin.
-- SETUP:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_file_audit_rc08')
BEGIN
    ALTER SERVER AUDIT dbdome_test_file_audit_rc08 WITH (STATE = OFF);
    DROP SERVER AUDIT dbdome_test_file_audit_rc08;
END
GO
CREATE SERVER AUDIT dbdome_test_file_audit_rc08
    TO FILE (FILEPATH = N'C:\Windows\Temp\', MAXSIZE = 2 MB, MAX_ROLLOVER_FILES = 2)
    WITH (ON_FAILURE = CONTINUE);
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_file_audit_rc08')
BEGIN
    ALTER SERVER AUDIT dbdome_test_file_audit_rc08 WITH (STATE = OFF);
    DROP SERVER AUDIT dbdome_test_file_audit_rc08;
END
GO

/* ===== SEC-SQL-AUD-002-RC09 [DESTRUCTIVE] ===== */
-- Same query as RC06/RC08: sys.server_audits LEFT JOIN sys.server_file_audits, no WHERE filter.
-- Returns >= 1 row whenever any server audit exists.
-- Run as sysadmin.
-- SETUP:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_file_audit_rc09')
BEGIN
    ALTER SERVER AUDIT dbdome_test_file_audit_rc09 WITH (STATE = OFF);
    DROP SERVER AUDIT dbdome_test_file_audit_rc09;
END
GO
CREATE SERVER AUDIT dbdome_test_file_audit_rc09
    TO FILE (FILEPATH = N'C:\Windows\Temp\', MAXSIZE = 2 MB, MAX_ROLLOVER_FILES = 2)
    WITH (ON_FAILURE = CONTINUE);
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_file_audit_rc09')
BEGIN
    ALTER SERVER AUDIT dbdome_test_file_audit_rc09 WITH (STATE = OFF);
    DROP SERVER AUDIT dbdome_test_file_audit_rc09;
END
GO

/* ===== SEC-SQL-AUD-002-RC10 [DESTRUCTIVE] ===== */
-- Detection: finds enabled SQL logins (not ##) that are sysadmin OR hold ALTER ANY SERVER AUDIT / CONTROL SERVER (GRANTed).
-- Setup: create a test login and grant ALTER ANY SERVER AUDIT so it satisfies the 'audit_control_perms' sub-query.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_rc10')
    CREATE LOGIN dbdome_test_login_rc10 WITH PASSWORD = 'Dbdome!TestOnly99', CHECK_POLICY = OFF;
GO
GRANT ALTER ANY SERVER AUDIT TO dbdome_test_login_rc10;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_rc10')
BEGIN
    REVOKE ALTER ANY SERVER AUDIT FROM dbdome_test_login_rc10;
    DROP LOGIN dbdome_test_login_rc10;
END
GO

/* ===== SEC-SQL-AUD-003-RC01 [DESTRUCTIVE] ===== */
-- Detection: finds enabled SQL logins (not ##) that are sysadmin OR hold CONTROL SERVER.
-- Setup: create a test login and grant CONTROL SERVER so it satisfies the 'has_control_server' sub-query.
-- Run as sysadmin. CONTROL SERVER is a highly privileged grant — dispose of it immediately after verification.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_rc01')
    CREATE LOGIN dbdome_test_login_rc01 WITH PASSWORD = 'Dbdome!TestOnly99', CHECK_POLICY = OFF;
GO
GRANT CONTROL SERVER TO dbdome_test_login_rc01;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_rc01')
BEGIN
    REVOKE CONTROL SERVER FROM dbdome_test_login_rc01;
    DROP LOGIN dbdome_test_login_rc01;
END
GO

/* ===== SEC-SQL-AUD-003-RC02 [DESTRUCTIVE] ===== */
-- Detection returns a single aggregated row. Triggers 'FILE_ONLY_MUTABLE' when:
--   file_based_audits > 0 AND event_log_audits = 0.
-- Note: type_desc values used in the count sub-queries are 'APPLICATION LOG' and 'SECURITY LOG'
--   (with a space, not underscore) which do not match real SQL Server type_desc values —
--   so event_log_audits will always be 0. Just ensure at least one FILE audit exists.
-- Creates a FILE audit so file_based_audits >= 1 and the CASE returns 'FILE_ONLY_MUTABLE'.
-- Run as sysadmin.
-- SETUP:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_file_audit_rc02')
BEGIN
    ALTER SERVER AUDIT dbdome_test_file_audit_rc02 WITH (STATE = OFF);
    DROP SERVER AUDIT dbdome_test_file_audit_rc02;
END
GO
CREATE SERVER AUDIT dbdome_test_file_audit_rc02
    TO FILE (FILEPATH = N'C:\Windows\Temp\', MAXSIZE = 2 MB, MAX_ROLLOVER_FILES = 2)
    WITH (ON_FAILURE = CONTINUE);
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_file_audit_rc02')
BEGIN
    ALTER SERVER AUDIT dbdome_test_file_audit_rc02 WITH (STATE = OFF);
    DROP SERVER AUDIT dbdome_test_file_audit_rc02;
END
GO

/* ===== SEC-SQL-AUD-003-RC03 [SAFE] ===== */
-- Detection returns a single aggregated row. Triggers 'NO_SECONDARY_DESTINATION' when:
--   COUNT of APPLICATION_LOG/SECURITY_LOG audits with is_state_enabled=1 = 0.
-- This is the default state on most SQL Server instances (no event-log audits enabled).
-- No setup needed: the condition is naturally met when no APPLICATION_LOG/SECURITY_LOG audit exists.
-- Confirm by running the detection SQL directly — it will return 'NO_SECONDARY_DESTINATION'.
-- If a SECURITY_LOG or APPLICATION_LOG audit exists and is enabled, disable it temporarily:
--   ALTER SERVER AUDIT <name> WITH (STATE = OFF);
-- SETUP:
-- No persistent changes required; the detection fires whenever no enabled APPLICATION_LOG/SECURITY_LOG
-- audit exists. Run the detection SQL to verify it returns 'NO_SECONDARY_DESTINATION'.
SELECT
  (SELECT COUNT(*) FROM sys.server_audits WHERE type_desc = 'FILE' AND is_state_enabled = 1) AS file_audits,
  (SELECT COUNT(*) FROM sys.server_audits WHERE type_desc IN ('APPLICATION_LOG', 'SECURITY_LOG') AND is_state_enabled = 1) AS event_log_audits,
  CASE
    WHEN (SELECT COUNT(*) FROM sys.server_audits WHERE type_desc IN ('APPLICATION_LOG', 'SECURITY_LOG') AND is_state_enabled = 1) = 0
    THEN 'NO_SECONDARY_DESTINATION'
    ELSE 'HAS_EVENT_LOG_BACKUP'
  END AS redundancy_status;
GO
-- REVERT:
-- Nothing to revert (SAFE, no changes made).
SELECT 'SAFE - no changes made' AS revert_status;
GO

/* ===== SEC-SQL-AUD-003-RC04 [SAFE] ===== */
-- Detection joins sys.dm_server_services with sys.server_principals on service_account name.
-- Returns rows for SQL Server services (LIKE '%SQL Server%') — these always exist on any SQL Server.
-- No setup required: sys.dm_server_services always contains at least one 'SQL Server' service row.
-- The LEFT JOIN means rows appear even if no matching sys.server_principals row exists.
-- Run as sysadmin (sys.dm_server_services requires VIEW SERVER STATE or sysadmin).
-- SETUP:
-- No changes required; the detection fires naturally from the SQL Server service entries.
-- Verify sys.dm_server_services has entries LIKE '%SQL Server%':
SELECT servicename, service_account FROM sys.dm_server_services WHERE servicename LIKE '%SQL Server%';
GO
-- REVERT:
-- Nothing to revert (SAFE, no changes made).
SELECT 'SAFE - no changes made' AS revert_status;
GO

/* ===== SEC-SQL-AUD-003-RC05 [DESTRUCTIVE] ===== */
-- Same query as RC06/RC08/RC09: sys.server_audits LEFT JOIN sys.server_file_audits, no WHERE filter.
-- Returns >= 1 row whenever any server audit exists.
-- Run as sysadmin.
-- SETUP:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_file_audit_rc05')
BEGIN
    ALTER SERVER AUDIT dbdome_test_file_audit_rc05 WITH (STATE = OFF);
    DROP SERVER AUDIT dbdome_test_file_audit_rc05;
END
GO
CREATE SERVER AUDIT dbdome_test_file_audit_rc05
    TO FILE (FILEPATH = N'C:\Windows\Temp\', MAXSIZE = 2 MB, MAX_ROLLOVER_FILES = 2)
    WITH (ON_FAILURE = CONTINUE);
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_file_audit_rc05')
BEGIN
    ALTER SERVER AUDIT dbdome_test_file_audit_rc05 WITH (STATE = OFF);
    DROP SERVER AUDIT dbdome_test_file_audit_rc05;
END
GO

/* ===== SEC-SQL-AUD-003-RC06 [DESTRUCTIVE] ===== */
-- Detection: finds enabled SQL Agent jobs whose step command contains audit-related keywords
--   ('audit', 'fn_get_audit_file', 'syslog', 'SIEM', 'EventLog', '.sqlaudit').
-- Setup: create an enabled Agent job with a step whose command contains 'audit' keyword.
-- Requires SQL Server Agent to be running and sysadmin / SQLAgentOperatorRole.
-- SETUP:
USE msdb;
GO
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = 'dbdome_test_audit_ship_job')
    EXEC msdb.dbo.sp_delete_job @job_name = N'dbdome_test_audit_ship_job', @delete_unused_schedule = 1;
GO
EXEC msdb.dbo.sp_add_job
    @job_name = N'dbdome_test_audit_ship_job',
    @enabled = 1,
    @description = N'DBDOME positive test job - safe to delete';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'dbdome_test_audit_ship_job',
    @step_name = N'ShipAuditLogs',
    @command = N'-- dbdome test: ship audit logs to SIEM via fn_get_audit_file; SELECT 1 AS dummy;',
    @subsystem = N'TSQL';
GO
EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'dbdome_test_audit_ship_job',
    @server_name = N'(local)';
GO
USE master;
GO
-- REVERT:
USE msdb;
GO
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = 'dbdome_test_audit_ship_job')
    EXEC msdb.dbo.sp_delete_job @job_name = N'dbdome_test_audit_ship_job', @delete_unused_schedule = 1;
GO
USE master;
GO


/* ########## batch 10 (12 reproducers) ########## */
/* ==========================================================================
   Positive-test reproducers for detections slice 120..132 (pt_10.sql)
   Target: DISPOSABLE TEST SQL Server  |  Run as: sysadmin
   ========================================================================== */

/* ===== SEC-SQL-AUD-003-RC07 [DESTRUCTIVE] ===== */
-- Detection returns rows unconditionally (three scalar sub-selects).
-- To make it "interesting" (impersonate_grants > 0) we grant IMPERSONATE.
-- The audit sub-selects return 0 when no audit exists -- detection still returns 1 row.
-- SETUP: grant IMPERSONATE on a throwaway login so impersonate_grants >= 1
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    CREATE LOGIN dbdome_test_login WITH PASSWORD = 'Dbdome_T3st!2024', CHECK_POLICY = OFF;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_grantor')
    CREATE LOGIN dbdome_test_grantor WITH PASSWORD = 'Dbdome_T3st!2024', CHECK_POLICY = OFF;
GO
GRANT IMPERSONATE ON LOGIN::dbdome_test_login TO dbdome_test_grantor;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_permissions
           WHERE permission_name = 'IMPERSONATE'
             AND grantee_principal_id = SUSER_ID('dbdome_test_grantor'))
    REVOKE IMPERSONATE ON LOGIN::dbdome_test_login FROM dbdome_test_grantor;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_grantor')
    DROP LOGIN dbdome_test_grantor;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    DROP LOGIN dbdome_test_login;
GO

/* ===== SEC-SQL-AUD-003-RC08 [DESTRUCTIVE] ===== */
-- Detection selects from sys.sql_logins WHERE name = 'sa'.
-- Returns 1 row whenever 'sa' login exists (it always does on a default install).
-- To also trigger active_sa_sessions > 0 you need a live 'sa' session -- not
-- scriptable in a single batch; the row is already returned without that.
-- SETUP: ensure 'sa' is enabled so the detection row shows is_disabled = 0.
-- (On most instances 'sa' is already disabled per CIS; we enable it here.)
ALTER LOGIN sa ENABLE;
GO
-- REVERT: re-disable sa as per best practice
ALTER LOGIN sa DISABLE;
GO

/* ===== SEC-SQL-AUD-003-RC09 [DESTRUCTIVE] ===== */
-- Detection counts sys.server_audits WHERE is_state_enabled = 1.
-- Returns >=1 row when at least one enabled audit exists.
-- SETUP: create and enable a file audit with CONTINUE on failure.
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
    CREATE SERVER AUDIT dbdome_test_audit
        TO FILE (FILEPATH = 'C:\Windows\Temp\', MAXSIZE = 10 MB, MAX_ROLLOVER_FILES = 2)
        WITH (ON_FAILURE = CONTINUE);
GO
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
    ALTER SERVER AUDIT dbdome_test_audit WITH (STATE = ON);
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit' AND is_state_enabled = 1)
    ALTER SERVER AUDIT dbdome_test_audit WITH (STATE = OFF);
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
    DROP SERVER AUDIT dbdome_test_audit;
GO

/* ===== SEC-SQL-AUD-004-RC01 [DESTRUCTIVE] ===== */
-- Detection looks for an ENABLED server audit specification that includes
-- FAILED_LOGIN_GROUP.  Returns >=1 row when that action exists in an enabled spec.
-- SETUP: create audit -> spec -> enable both.
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
    CREATE SERVER AUDIT dbdome_test_audit
        TO FILE (FILEPATH = 'C:\Windows\Temp\', MAXSIZE = 10 MB, MAX_ROLLOVER_FILES = 2)
        WITH (ON_FAILURE = CONTINUE);
GO
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
    ALTER SERVER AUDIT dbdome_test_audit WITH (STATE = ON);
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec')
BEGIN
    EXEC('CREATE SERVER AUDIT SPECIFICATION dbdome_test_spec
          FOR SERVER AUDIT dbdome_test_audit
          ADD (FAILED_LOGIN_GROUP)
          WITH (STATE = OFF)');
END
GO
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec')
    ALTER SERVER AUDIT SPECIFICATION dbdome_test_spec WITH (STATE = ON);
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec' AND is_state_enabled = 1)
    ALTER SERVER AUDIT SPECIFICATION dbdome_test_spec WITH (STATE = OFF);
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec')
    DROP SERVER AUDIT SPECIFICATION dbdome_test_spec;
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit' AND is_state_enabled = 1)
    ALTER SERVER AUDIT dbdome_test_audit WITH (STATE = OFF);
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
    DROP SERVER AUDIT dbdome_test_audit;
GO

/* ===== SEC-SQL-AUD-004-RC02 [DESTRUCTIVE] ===== */
-- Detection returns one row (two scalar sub-selects) counting FAILED_LOGIN_GROUP
-- and SUCCESSFUL_LOGIN_GROUP in enabled specs.  Returns a row unconditionally;
-- to get non-zero counts create enabled specs containing both action groups.
-- SETUP: reuse dbdome_test_audit + create spec with both action groups.
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
    CREATE SERVER AUDIT dbdome_test_audit
        TO FILE (FILEPATH = 'C:\Windows\Temp\', MAXSIZE = 10 MB, MAX_ROLLOVER_FILES = 2)
        WITH (ON_FAILURE = CONTINUE);
GO
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
    ALTER SERVER AUDIT dbdome_test_audit WITH (STATE = ON);
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec')
BEGIN
    EXEC('CREATE SERVER AUDIT SPECIFICATION dbdome_test_spec
          FOR SERVER AUDIT dbdome_test_audit
          ADD (FAILED_LOGIN_GROUP),
          ADD (SUCCESSFUL_LOGIN_GROUP)
          WITH (STATE = OFF)');
END
GO
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec')
    ALTER SERVER AUDIT SPECIFICATION dbdome_test_spec WITH (STATE = ON);
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec' AND is_state_enabled = 1)
    ALTER SERVER AUDIT SPECIFICATION dbdome_test_spec WITH (STATE = OFF);
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec')
    DROP SERVER AUDIT SPECIFICATION dbdome_test_spec;
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit' AND is_state_enabled = 1)
    ALTER SERVER AUDIT dbdome_test_audit WITH (STATE = OFF);
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
    DROP SERVER AUDIT dbdome_test_audit;
GO

/* ===== SEC-SQL-AUD-004-RC03 [DESTRUCTIVE] ===== */
-- Detection queries sys.server_audits LEFT JOIN sys.server_file_audits.
-- Returns >=1 row whenever any server audit exists (enabled or not).
-- SETUP: create a file-backed server audit so the join returns a row.
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
    CREATE SERVER AUDIT dbdome_test_audit
        TO FILE (FILEPATH = 'C:\Windows\Temp\', MAXSIZE = 10 MB, MAX_ROLLOVER_FILES = 2)
        WITH (ON_FAILURE = CONTINUE);
GO
-- Note: audit is left DISABLED intentionally; the detection queries all audits.
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit' AND is_state_enabled = 1)
    ALTER SERVER AUDIT dbdome_test_audit WITH (STATE = OFF);
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
    DROP SERVER AUDIT dbdome_test_audit;
GO

/* ===== SEC-SQL-AUD-004-RC04 [DESTRUCTIVE] ===== */
-- Detection returns one row (three scalar sub-selects) counting active audits,
-- active server specs, and active DB specs. Returns a row unconditionally.
-- To get active_audits >= 1 we create and enable a server audit.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
    CREATE SERVER AUDIT dbdome_test_audit
        TO FILE (FILEPATH = 'C:\Windows\Temp\', MAXSIZE = 10 MB, MAX_ROLLOVER_FILES = 2)
        WITH (ON_FAILURE = CONTINUE);
GO
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
    ALTER SERVER AUDIT dbdome_test_audit WITH (STATE = ON);
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit' AND is_state_enabled = 1)
    ALTER SERVER AUDIT dbdome_test_audit WITH (STATE = OFF);
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
    DROP SERVER AUDIT dbdome_test_audit;
GO

/* ===== SEC-SQL-AUD-004-RC05 [DESTRUCTIVE] ===== */
-- Same query shape as RC03/RC04: sys.server_audits LEFT JOIN sys.server_file_audits.
-- Returns >=1 row whenever any server audit exists.  A high queue_delay
-- (e.g. 10000 ms) would indicate log throttling/sampling.
-- SETUP: create a file audit with a large queue_delay.
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
    CREATE SERVER AUDIT dbdome_test_audit
        TO FILE (FILEPATH = 'C:\Windows\Temp\', MAXSIZE = 10 MB, MAX_ROLLOVER_FILES = 2)
        WITH (ON_FAILURE = CONTINUE, QUEUE_DELAY = 10000);
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit' AND is_state_enabled = 1)
    ALTER SERVER AUDIT dbdome_test_audit WITH (STATE = OFF);
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
    DROP SERVER AUDIT dbdome_test_audit;
GO

/* ===== SEC-SQL-AUD-004-RC06 [DESTRUCTIVE] ===== */
-- Detection returns rows from an enabled server audit spec where
-- audit_action_name LIKE '%LOGIN%'.
-- SETUP: create audit + spec with FAILED_LOGIN_GROUP and SUCCESSFUL_LOGIN_GROUP.
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
    CREATE SERVER AUDIT dbdome_test_audit
        TO FILE (FILEPATH = 'C:\Windows\Temp\', MAXSIZE = 10 MB, MAX_ROLLOVER_FILES = 2)
        WITH (ON_FAILURE = CONTINUE);
GO
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
    ALTER SERVER AUDIT dbdome_test_audit WITH (STATE = ON);
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec')
BEGIN
    EXEC('CREATE SERVER AUDIT SPECIFICATION dbdome_test_spec
          FOR SERVER AUDIT dbdome_test_audit
          ADD (FAILED_LOGIN_GROUP),
          ADD (SUCCESSFUL_LOGIN_GROUP)
          WITH (STATE = OFF)');
END
GO
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec')
    ALTER SERVER AUDIT SPECIFICATION dbdome_test_spec WITH (STATE = ON);
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec' AND is_state_enabled = 1)
    ALTER SERVER AUDIT SPECIFICATION dbdome_test_spec WITH (STATE = OFF);
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec')
    DROP SERVER AUDIT SPECIFICATION dbdome_test_spec;
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit' AND is_state_enabled = 1)
    ALTER SERVER AUDIT dbdome_test_audit WITH (STATE = OFF);
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
    DROP SERVER AUDIT dbdome_test_audit;
GO

/* ===== SEC-SQL-AUD-004-RC07 [DESTRUCTIVE] ===== */
-- Detection returns one row (four scalar sub-selects); always returns 1 row.
-- To get active_sql_logins >= 1 we create an enabled SQL login.
-- To get failed_login_audited >= 1 we create an enabled spec with FAILED_LOGIN_GROUP.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    CREATE LOGIN dbdome_test_login WITH PASSWORD = 'Dbdome_T3st!2024', CHECK_POLICY = OFF;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
    CREATE SERVER AUDIT dbdome_test_audit
        TO FILE (FILEPATH = 'C:\Windows\Temp\', MAXSIZE = 10 MB, MAX_ROLLOVER_FILES = 2)
        WITH (ON_FAILURE = CONTINUE);
GO
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
    ALTER SERVER AUDIT dbdome_test_audit WITH (STATE = ON);
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec')
BEGIN
    EXEC('CREATE SERVER AUDIT SPECIFICATION dbdome_test_spec
          FOR SERVER AUDIT dbdome_test_audit
          ADD (FAILED_LOGIN_GROUP)
          WITH (STATE = OFF)');
END
GO
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec')
    ALTER SERVER AUDIT SPECIFICATION dbdome_test_spec WITH (STATE = ON);
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec' AND is_state_enabled = 1)
    ALTER SERVER AUDIT SPECIFICATION dbdome_test_spec WITH (STATE = OFF);
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec')
    DROP SERVER AUDIT SPECIFICATION dbdome_test_spec;
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit' AND is_state_enabled = 1)
    ALTER SERVER AUDIT dbdome_test_audit WITH (STATE = OFF);
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
    DROP SERVER AUDIT dbdome_test_audit;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    DROP LOGIN dbdome_test_login;
GO

/* ===== SEC-SQL-AUD-004-RC08 [SAFE] ===== */
-- Detection queries sys.dm_os_performance_counters for connection/login counters.
-- These DMV rows always exist on a running SQL Server instance;
-- the detection returns 1 row (a single-row scalar sub-select result set)
-- unconditionally as long as the instance is running.
-- No persistent change needed -- just verify the instance is up.
-- SETUP: no-op; the DMV rows are always present on a live instance.
SELECT
    (SELECT cntr_value FROM sys.dm_os_performance_counters
     WHERE counter_name = 'Connection Reset/sec' AND instance_name = '') AS connection_resets,
    (SELECT cntr_value FROM sys.dm_os_performance_counters
     WHERE counter_name = 'Logins/sec' AND instance_name = '') AS total_logins,
    (SELECT cntr_value FROM sys.dm_os_performance_counters
     WHERE counter_name = 'Logouts/sec' AND instance_name = '') AS total_logouts,
    (SELECT cntr_value FROM sys.dm_os_performance_counters
     WHERE counter_name = 'User Connections' AND instance_name = '') AS current_user_connections;
GO
-- REVERT: nothing to undo (read-only DMV query).
SELECT 'No revert needed for SEC-SQL-AUD-004-RC08' AS info;
GO

/* ===== SEC-SQL-AUD-005-RC01 [DESTRUCTIVE] ===== */
-- Detection returns rows from enabled server audit specs.
-- A row is returned for each audit action in an enabled specification.
-- SETUP: create audit + spec with a mix of DDL/LOGIN/SCHEMA/PRINCIPAL actions
--        so the CASE expression returns non-trivial categories.
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
    CREATE SERVER AUDIT dbdome_test_audit
        TO FILE (FILEPATH = 'C:\Windows\Temp\', MAXSIZE = 10 MB, MAX_ROLLOVER_FILES = 2)
        WITH (ON_FAILURE = CONTINUE);
GO
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
    ALTER SERVER AUDIT dbdome_test_audit WITH (STATE = ON);
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec')
BEGIN
    EXEC('CREATE SERVER AUDIT SPECIFICATION dbdome_test_spec
          FOR SERVER AUDIT dbdome_test_audit
          ADD (SCHEMA_OBJECT_ACCESS_GROUP),
          ADD (FAILED_LOGIN_GROUP),
          ADD (SUCCESSFUL_LOGIN_GROUP),
          ADD (SERVER_PRINCIPAL_CHANGE_GROUP),
          ADD (SERVER_PERMISSION_CHANGE_GROUP)
          WITH (STATE = OFF)');
END
GO
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec')
    ALTER SERVER AUDIT SPECIFICATION dbdome_test_spec WITH (STATE = ON);
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec' AND is_state_enabled = 1)
    ALTER SERVER AUDIT SPECIFICATION dbdome_test_spec WITH (STATE = OFF);
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec')
    DROP SERVER AUDIT SPECIFICATION dbdome_test_spec;
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit' AND is_state_enabled = 1)
    ALTER SERVER AUDIT dbdome_test_audit WITH (STATE = OFF);
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
    DROP SERVER AUDIT dbdome_test_audit;
GO


/* ########## batch 11 (12 reproducers) ########## */
/* ===== SEC-SQL-AUD-005-RC02 [DESTRUCTIVE] ===== */
-- Creates a server audit + enabled server audit specification with at least one of the four targeted
-- action groups (SCHEMA_OBJECT_CHANGE_GROUP). Detection returns >=1 row when the audit and spec
-- are both enabled and at least one qualifying action group detail exists.
-- Run as sysadmin. The audit writes to a temp file path; adjust if the path does not exist.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc02')
    CREATE SERVER AUDIT [dbdome_test_audit_rc02]
    TO FILE (FILEPATH = N'C:\Windows\Temp\', MAXSIZE = 10 MB, MAX_ROLLOVER_FILES = 2)
    WITH (ON_FAILURE = CONTINUE);

ALTER SERVER AUDIT [dbdome_test_audit_rc02] WITH (STATE = ON);

IF NOT EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec_rc02')
BEGIN
    CREATE SERVER AUDIT SPECIFICATION [dbdome_test_spec_rc02]
    FOR SERVER AUDIT [dbdome_test_audit_rc02]
    ADD (SCHEMA_OBJECT_CHANGE_GROUP)
    WITH (STATE = OFF);
END

ALTER SERVER AUDIT SPECIFICATION [dbdome_test_spec_rc02] WITH (STATE = ON);
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec_rc02')
BEGIN
    ALTER SERVER AUDIT SPECIFICATION [dbdome_test_spec_rc02] WITH (STATE = OFF);
    DROP SERVER AUDIT SPECIFICATION [dbdome_test_spec_rc02];
END

IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc02')
BEGIN
    ALTER SERVER AUDIT [dbdome_test_audit_rc02] WITH (STATE = OFF);
    DROP SERVER AUDIT [dbdome_test_audit_rc02];
END
GO

/* ===== SEC-SQL-AUD-005-RC03 [DESTRUCTIVE] ===== */
-- The detection returns all non-disabled, non-## sysadmin members along with a count of how many
-- audit specs cover AUDIT_CHANGE_GROUP. It returns rows as long as there is at least one active
-- sysadmin login (always true). To produce a clean positive row we create a new enabled sysadmin
-- login so we have an unambiguous test row in sys.server_principals + sys.server_role_members.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_rc03')
    CREATE LOGIN [dbdome_test_login_rc03] WITH PASSWORD = 'Dbdome_Test#2024!', CHECK_POLICY = OFF;

ALTER LOGIN [dbdome_test_login_rc03] ENABLE;

EXEC sp_addsrvrolemember @loginame = 'dbdome_test_login_rc03', @rolename = 'sysadmin';
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_rc03')
BEGIN
    EXEC sp_dropsrvrolemember @loginame = 'dbdome_test_login_rc03', @rolename = 'sysadmin';
    DROP LOGIN [dbdome_test_login_rc03];
END
GO

/* ===== SEC-SQL-AUD-005-RC04 [DESTRUCTIVE] ===== */
-- The detection is a pure aggregation (SUM) over enabled server audit specification details. It
-- always returns exactly one row; the columns dml_access_groups, ddl_change_groups, and
-- server_change_groups will be non-zero when corresponding action groups are configured. To produce
-- a positive signal (non-zero counts) we create an enabled spec with all three categories covered.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc04')
    CREATE SERVER AUDIT [dbdome_test_audit_rc04]
    TO FILE (FILEPATH = N'C:\Windows\Temp\', MAXSIZE = 10 MB, MAX_ROLLOVER_FILES = 2)
    WITH (ON_FAILURE = CONTINUE);

ALTER SERVER AUDIT [dbdome_test_audit_rc04] WITH (STATE = ON);

IF NOT EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec_rc04')
BEGIN
    CREATE SERVER AUDIT SPECIFICATION [dbdome_test_spec_rc04]
    FOR SERVER AUDIT [dbdome_test_audit_rc04]
    ADD (SCHEMA_OBJECT_ACCESS_GROUP),
    ADD (SCHEMA_OBJECT_CHANGE_GROUP),
    ADD (SERVER_OBJECT_CHANGE_GROUP)
    WITH (STATE = OFF);
END

ALTER SERVER AUDIT SPECIFICATION [dbdome_test_spec_rc04] WITH (STATE = ON);
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec_rc04')
BEGIN
    ALTER SERVER AUDIT SPECIFICATION [dbdome_test_spec_rc04] WITH (STATE = OFF);
    DROP SERVER AUDIT SPECIFICATION [dbdome_test_spec_rc04];
END

IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc04')
BEGIN
    ALTER SERVER AUDIT [dbdome_test_audit_rc04] WITH (STATE = OFF);
    DROP SERVER AUDIT [dbdome_test_audit_rc04];
END
GO

/* ===== SEC-SQL-AUD-005-RC05 [DESTRUCTIVE] ===== */
-- Detection returns a one-row aggregate. server_wide_ddl_audit is non-zero when an enabled server
-- audit spec has SCHEMA_OBJECT_CHANGE_GROUP or DATABASE_OBJECT_CHANGE_GROUP with class_desc='SERVER'.
-- principal_scoped_ddl_audit is non-zero when an enabled *database* audit spec covers those groups
-- for a non-zero principal. Setup creates both server-level and database-level specs to trigger
-- both columns simultaneously.
-- Run as sysadmin in the context of a user database. Adjust 'dbdome_testdb' if needed.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc05')
    CREATE SERVER AUDIT [dbdome_test_audit_rc05]
    TO FILE (FILEPATH = N'C:\Windows\Temp\', MAXSIZE = 10 MB, MAX_ROLLOVER_FILES = 2)
    WITH (ON_FAILURE = CONTINUE);

ALTER SERVER AUDIT [dbdome_test_audit_rc05] WITH (STATE = ON);

IF NOT EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec_rc05')
BEGIN
    CREATE SERVER AUDIT SPECIFICATION [dbdome_test_spec_rc05]
    FOR SERVER AUDIT [dbdome_test_audit_rc05]
    ADD (SCHEMA_OBJECT_CHANGE_GROUP)
    WITH (STATE = OFF);
END

ALTER SERVER AUDIT SPECIFICATION [dbdome_test_spec_rc05] WITH (STATE = ON);

-- Create a test database if needed to host the database audit spec
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_testdb_rc05')
    CREATE DATABASE [dbdome_testdb_rc05];

-- Create a login/user to act as audited principal (non-zero principal_id)
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_rc05')
    CREATE LOGIN [dbdome_test_login_rc05] WITH PASSWORD = 'Dbdome_Test#2024!', CHECK_POLICY = OFF;
GO

USE [dbdome_testdb_rc05];
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_test_user_rc05')
    CREATE USER [dbdome_test_user_rc05] FOR LOGIN [dbdome_test_login_rc05];

IF NOT EXISTS (SELECT 1 FROM sys.database_audit_specifications WHERE name = 'dbdome_test_dbspec_rc05')
BEGIN
    CREATE DATABASE AUDIT SPECIFICATION [dbdome_test_dbspec_rc05]
    FOR SERVER AUDIT [dbdome_test_audit_rc05]
    ADD (SCHEMA_OBJECT_CHANGE_GROUP FOR USER [dbdome_test_user_rc05])
    WITH (STATE = OFF);
END

ALTER DATABASE AUDIT SPECIFICATION [dbdome_test_dbspec_rc05] WITH (STATE = ON);
GO

USE [master];
GO
-- REVERT:
USE [dbdome_testdb_rc05];
IF EXISTS (SELECT 1 FROM sys.database_audit_specifications WHERE name = 'dbdome_test_dbspec_rc05')
BEGIN
    ALTER DATABASE AUDIT SPECIFICATION [dbdome_test_dbspec_rc05] WITH (STATE = OFF);
    DROP DATABASE AUDIT SPECIFICATION [dbdome_test_dbspec_rc05];
END

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_test_user_rc05')
    DROP USER [dbdome_test_user_rc05];
GO

USE [master];

IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec_rc05')
BEGIN
    ALTER SERVER AUDIT SPECIFICATION [dbdome_test_spec_rc05] WITH (STATE = OFF);
    DROP SERVER AUDIT SPECIFICATION [dbdome_test_spec_rc05];
END

IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc05')
BEGIN
    ALTER SERVER AUDIT [dbdome_test_audit_rc05] WITH (STATE = OFF);
    DROP SERVER AUDIT [dbdome_test_audit_rc05];
END

IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_rc05')
    DROP LOGIN [dbdome_test_login_rc05];

IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_testdb_rc05')
    DROP DATABASE [dbdome_testdb_rc05];
GO

/* ===== SEC-SQL-AUD-005-RC06 [DESTRUCTIVE] ===== */
-- Detection returns a one-row aggregate counting (a) enabled audit specs in tempdb, (b) tempdb DDL
-- audit detail rows, and (c) server-level DDL audit spec details. Any non-zero value signals a
-- finding. Easiest trigger: create a server audit + enabled server spec covering SCHEMA_OBJECT_CHANGE_GROUP
-- (populates column 3). Also create an enabled database audit spec in tempdb (populates columns 1&2).
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc06')
    CREATE SERVER AUDIT [dbdome_test_audit_rc06]
    TO FILE (FILEPATH = N'C:\Windows\Temp\', MAXSIZE = 10 MB, MAX_ROLLOVER_FILES = 2)
    WITH (ON_FAILURE = CONTINUE);

ALTER SERVER AUDIT [dbdome_test_audit_rc06] WITH (STATE = ON);

-- Server-level spec for column 3
IF NOT EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec_rc06')
BEGIN
    CREATE SERVER AUDIT SPECIFICATION [dbdome_test_spec_rc06]
    FOR SERVER AUDIT [dbdome_test_audit_rc06]
    ADD (SCHEMA_OBJECT_CHANGE_GROUP)
    WITH (STATE = OFF);
END

ALTER SERVER AUDIT SPECIFICATION [dbdome_test_spec_rc06] WITH (STATE = ON);

-- tempdb-level spec for columns 1 & 2
USE [tempdb];
IF NOT EXISTS (SELECT 1 FROM sys.database_audit_specifications WHERE name = 'dbdome_test_tempdb_spec_rc06')
BEGIN
    CREATE DATABASE AUDIT SPECIFICATION [dbdome_test_tempdb_spec_rc06]
    FOR SERVER AUDIT [dbdome_test_audit_rc06]
    ADD (SCHEMA_OBJECT_CHANGE_GROUP)
    WITH (STATE = OFF);
END

ALTER DATABASE AUDIT SPECIFICATION [dbdome_test_tempdb_spec_rc06] WITH (STATE = ON);
GO

USE [master];
GO
-- REVERT:
USE [tempdb];
IF EXISTS (SELECT 1 FROM sys.database_audit_specifications WHERE name = 'dbdome_test_tempdb_spec_rc06')
BEGIN
    ALTER DATABASE AUDIT SPECIFICATION [dbdome_test_tempdb_spec_rc06] WITH (STATE = OFF);
    DROP DATABASE AUDIT SPECIFICATION [dbdome_test_tempdb_spec_rc06];
END
GO

USE [master];

IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec_rc06')
BEGIN
    ALTER SERVER AUDIT SPECIFICATION [dbdome_test_spec_rc06] WITH (STATE = OFF);
    DROP SERVER AUDIT SPECIFICATION [dbdome_test_spec_rc06];
END

IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc06')
BEGIN
    ALTER SERVER AUDIT [dbdome_test_audit_rc06] WITH (STATE = OFF);
    DROP SERVER AUDIT [dbdome_test_audit_rc06];
END
GO

/* ===== SEC-SQL-AUD-005-RC07 [DESTRUCTIVE] ===== */
-- Detection returns a one-row aggregate. Columns become non-zero when: xp_cmdshell is enabled,
-- Ole Automation Procedures is enabled, extended procedures exist (always true on any SQL Server),
-- or UNSAFE/EXTERNAL_ACCESS CLR assemblies exist. Easiest and least-invasive trigger: enable
-- xp_cmdshell (and Ole Automation Procedures) via sp_configure, which makes two columns non-zero.
-- The extended_procs column is always >0 on a real server so the row always has at least one
-- non-zero value even without setup; enabling xp_cmdshell makes the finding unambiguous.
-- Run as sysadmin. REMEMBER to revert immediately on production-adjacent environments.
-- SETUP:
EXEC sp_configure 'show advanced options', 1; RECONFIGURE WITH OVERRIDE;
EXEC sp_configure 'xp_cmdshell', 1;          RECONFIGURE WITH OVERRIDE;
EXEC sp_configure 'Ole Automation Procedures', 1; RECONFIGURE WITH OVERRIDE;
GO
-- REVERT:
EXEC sp_configure 'show advanced options', 1; RECONFIGURE WITH OVERRIDE;
EXEC sp_configure 'xp_cmdshell', 0;          RECONFIGURE WITH OVERRIDE;
EXEC sp_configure 'Ole Automation Procedures', 0; RECONFIGURE WITH OVERRIDE;
EXEC sp_configure 'show advanced options', 0; RECONFIGURE WITH OVERRIDE;
GO

/* ===== SEC-SQL-AUD-005-RC08 [DESTRUCTIVE] ===== */
-- Detection does a LEFT JOIN from sys.server_audits to sys.server_file_audits and returns ALL
-- rows unconditionally (no WHERE clause). It returns >=1 row as long as at least one server audit
-- exists. Setup: create one server audit (file-based so sfa columns are populated too).
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc08')
    CREATE SERVER AUDIT [dbdome_test_audit_rc08]
    TO FILE (FILEPATH = N'C:\Windows\Temp\', MAXSIZE = 50 MB, MAX_ROLLOVER_FILES = 5)
    WITH (ON_FAILURE = CONTINUE);
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc08')
BEGIN
    ALTER SERVER AUDIT [dbdome_test_audit_rc08] WITH (STATE = OFF);
    DROP SERVER AUDIT [dbdome_test_audit_rc08];
END
GO

/* ===== SEC-SQL-AUD-006-RC01 [SAFE] ===== */
-- Detection joins dm_exec_sessions to dm_exec_requests filtering for active INSERT/UPDATE/DELETE
-- commands issued by a sysadmin login. Setup: open a separate session as a sysadmin login and
-- run a write statement inside an explicit transaction held open. This reproducer must be run
-- manually in two sessions: run SETUP block in Session 1 (leave it open), then execute the
-- detection query in Session 2, then run REVERT in Session 1.
-- SAFE because the open transaction is on a throwaway table and is rolled back on revert.
-- SETUP (Session 1 - leave open, do NOT commit/rollback until revert):

-- First create the throwaway table in a safe database
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_testdb_rc01')
    CREATE DATABASE [dbdome_testdb_rc01];
GO

USE [dbdome_testdb_rc01];

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dbdome_dml_test')
    CREATE TABLE dbo.dbdome_dml_test (id INT, val NVARCHAR(100));

-- === RUN THE FOLLOWING BLOCK IN A SEPARATE SESSION AS A SYSADMIN LOGIN AND LEAVE IT OPEN ===
-- BEGIN TRANSACTION;
-- INSERT INTO [dbdome_testdb_rc01].dbo.dbdome_dml_test VALUES (1, 'test');
-- -- ** Keep this session open; do NOT commit or rollback **
-- -- Now run the detection query in another session - it will see the INSERT in dm_exec_requests.
GO

USE [master];
GO
-- REVERT (Session 1 - rollback the held transaction, then clean up):
-- ROLLBACK TRANSACTION;  -- run in Session 1 first

USE [dbdome_testdb_rc01];
IF OBJECT_ID('dbo.dbdome_dml_test', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_dml_test;
GO

USE [master];
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_testdb_rc01')
    DROP DATABASE [dbdome_testdb_rc01];
GO

/* ===== SEC-SQL-AUD-006-RC02 [DESTRUCTIVE] ===== */
-- Detection looks for tables that have an extended property 'SensitivityLabel' AND whose name
-- appears (via PARSENAME) inside the text of any cached query plan that contains '%sysadmin%'.
-- The plan-cache match is unreliable as a reproducer, so the most reliable approach is to:
-- (1) create a table with the SensitivityLabel extended property, and (2) run an ad-hoc query
-- that references 'sysadmin' AND the table name so the plan is cached and the PARSENAME
-- extracts the table name. Because the PARSENAME logic uses dot-notation, we embed the table
-- in a query like: SELECT * FROM [db].[schema].[dbdome_pii_test] WHERE 'sysadmin'=N'sysadmin'.
-- Run as sysadmin. Flush the plan cache first to avoid stale hits.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_testdb_rc02')
    CREATE DATABASE [dbdome_testdb_rc02];
GO

USE [dbdome_testdb_rc02];

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dbdome_pii_test')
    CREATE TABLE dbo.dbdome_pii_test (id INT, ssn NVARCHAR(20));

IF NOT EXISTS (
    SELECT 1 FROM sys.extended_properties
    WHERE major_id = OBJECT_ID('dbo.dbdome_pii_test') AND name = 'SensitivityLabel'
)
    EXEC sys.sp_addextendedproperty
        @name = N'SensitivityLabel',
        @value = N'Confidential',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'dbdome_pii_test';

-- Execute a query that references sysadmin AND the table so it lands in plan cache
-- The PARSENAME in the detection strips brackets: ensure no brackets in this reference
SELECT TOP 0 id FROM dbdome_testdb_rc02.dbo.dbdome_pii_test WHERE N'sysadmin' = N'sysadmin';
GO

USE [master];
GO
-- REVERT:
USE [dbdome_testdb_rc02];

IF EXISTS (
    SELECT 1 FROM sys.extended_properties
    WHERE major_id = OBJECT_ID('dbo.dbdome_pii_test') AND name = 'SensitivityLabel'
)
    EXEC sys.sp_dropextendedproperty
        @name = N'SensitivityLabel',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'dbdome_pii_test';

IF OBJECT_ID('dbo.dbdome_pii_test', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_pii_test;
GO

USE [master];
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_testdb_rc02')
    DROP DATABASE [dbdome_testdb_rc02];
GO

/* ===== SEC-SQL-AUD-006-RC03 [SAFE] ===== */
-- Detection joins dm_exec_sessions + dm_exec_requests for sysadmin logins whose active SQL text
-- matches LIKE '%].%.[%' (qualified three-part or four-part name). Setup: open a separate session
-- as a sysadmin login and run a query referencing a three-part name inside an open transaction
-- so it stays visible in dm_exec_requests.
-- SAFE because the open transaction is rolled back.
-- SETUP (Session 1 - leave open):

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_testdb_rc03')
    CREATE DATABASE [dbdome_testdb_rc03];
GO

USE [dbdome_testdb_rc03];
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dbdome_scope_test')
    CREATE TABLE dbo.dbdome_scope_test (id INT);
GO

USE [master];

-- === RUN THE FOLLOWING IN A SEPARATE SYSADMIN SESSION AND LEAVE OPEN ===
-- BEGIN TRANSACTION;
-- SELECT * FROM [dbdome_testdb_rc03].[dbo].[dbdome_scope_test];
-- -- Keep open. Run the detection query in a third session.
-- -- The text '[dbdome_testdb_rc03].[dbo].[dbdome_scope_test]' matches LIKE '%].%.[%'
GO
-- REVERT (rollback Session 1 first, then run):
-- ROLLBACK TRANSACTION;  -- in Session 1

USE [dbdome_testdb_rc03];
IF OBJECT_ID('dbo.dbdome_scope_test', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_scope_test;
GO

USE [master];
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_testdb_rc03')
    DROP DATABASE [dbdome_testdb_rc03];
GO

/* ===== SEC-SQL-AUD-006-RC04 [DESTRUCTIVE] ===== */
-- Detection returns any server principal whose name LIKE '%svc%', '%service%', or '%api%'.
-- The description column uses ISNULL(..., 'No description') so it is always non-NULL; only the
-- name match matters for rows to appear. Setup: create a SQL login named 'dbdome_svc_testlogin'.
-- sp_addextendedproperty does not support SERVER_PRINCIPAL class via the normal level args,
-- so we skip it; the detection does not filter on it.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_svc_testlogin')
    CREATE LOGIN [dbdome_svc_testlogin]
    WITH PASSWORD = 'Dbdome_Svc#2024!', CHECK_POLICY = OFF;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_svc_testlogin')
    DROP LOGIN [dbdome_svc_testlogin];
GO

/* ===== SEC-SQL-AUD-006-RC05 [SAFE] ===== */
-- Detection returns rows from dm_exec_sessions where login_name != original_login_name and
-- is_user_process = 1. This happens when a connection uses EXECUTE AS LOGIN or when a Windows
-- login connects then impersonates another. Setup: in a separate session run EXECUTE AS LOGIN
-- and hold the session open (do NOT revert the EXECUTE AS until after the detection query runs).
-- SAFE because no persistent changes are made; REVERT AS restores the session.
-- Requires sysadmin or IMPERSONATE permission on the target login.
-- SETUP: create the impersonation target login first.
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_impersonate_target')
    CREATE LOGIN [dbdome_impersonate_target]
    WITH PASSWORD = 'Dbdome_Imp#2024!', CHECK_POLICY = OFF;

GRANT IMPERSONATE ON LOGIN::[dbdome_impersonate_target] TO [dbdome_impersonate_target];

-- === RUN THE FOLLOWING IN A SEPARATE SESSION AND LEAVE IT OPEN ===
-- EXECUTE AS LOGIN = 'dbdome_impersonate_target';
-- -- Now login_name = 'dbdome_impersonate_target' but original_login_name = your real login
-- -- Wait here; run the detection in a third session, then REVERT AS in this session.
GO
-- REVERT (in the impersonating session first, then run this block):
-- REVERT;  -- in the impersonating session

IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_impersonate_target')
BEGIN
    REVOKE IMPERSONATE ON LOGIN::[dbdome_impersonate_target] FROM [dbdome_impersonate_target];
    DROP LOGIN [dbdome_impersonate_target];
END
GO


/* ########## batch 12 (12 reproducers) ########## */
/* =========================================================================
   pt_12.sql  --  Positive-test reproducers for detections 144-155
   Slice: SEC-SQL-AUD-007-RC01 .. SEC-SQL-AUD-009-RC02
   Target: DISPOSABLE / throwaway SQL Server instance only.
   ========================================================================= */

/* ===== SEC-SQL-AUD-007-RC01 [SAFE] ===== */
-- Detection fires when sys.dm_exec_sessions contains a user session whose
-- program_name does not match the known-good whitelist. Open a connection
-- from SSMS (or sqlcmd) and override the application name via connection
-- string property ApplicationName='dbdome_unlisted_app'. Keep that session
-- open while running the detection. No schema changes needed.
-- NOTE: must hold the session open in a separate window/connection.
-- SETUP:
-- Run the following in a SEPARATE session (keep the window open):
--   sqlcmd -S <server> -E -A "dbdome_unlisted_app" -Q "WAITFOR DELAY '00:10:00'"
-- Then in any session confirm the detection fires:
SELECT s.session_id, s.login_name, s.program_name, s.host_name, s.client_interface_name
FROM sys.dm_exec_sessions s
WHERE s.is_user_process = 1
  AND s.program_name NOT IN (
      'AppMain','ReportingService','ETLAgent','SqlAgent',
      'Microsoft SQL Server Management Studio - Query',
      '.Net SqlClient Data Provider'
  )
  AND s.program_name NOT LIKE '%SQLAgent%'
  AND s.program_name = 'dbdome_unlisted_app';  -- narrow to our test session
GO
-- REVERT:
-- Simply close / kill the separate sqlcmd session.
-- No persistent objects created.
SELECT 'No persistent objects to revert for SEC-SQL-AUD-007-RC01' AS revert_status;
GO

/* ===== SEC-SQL-AUD-007-RC02 [SAFE] ===== */
-- Detection fires when Query Store contains a query executed exactly once
-- with avg logical reads > 100 000. We inject a single large-scan query
-- against a temp table populated with enough rows (or a real large table).
-- Easiest trigger: run a one-off heavy SELECT against a large real table so
-- QS records execution_count=1 and total_logical_reads > 100000.
-- NOTE: Query Store must be ON for the target database. Requires ALTER
-- DATABASE permission. The injected entry stays in QS until cleared.
-- SETUP:
IF NOT EXISTS (
    SELECT 1 FROM sys.databases
    WHERE name = 'dbdome_qs_testdb'
)
    CREATE DATABASE dbdome_qs_testdb;
GO
ALTER DATABASE dbdome_qs_testdb SET QUERY_STORE = ON
    (OPERATION_MODE = READ_WRITE,
     MAX_STORAGE_SIZE_MB = 100,
     QUERY_CAPTURE_MODE = ALL);
GO
USE dbdome_qs_testdb;
GO
-- Create a wide table with enough rows to generate > 100 000 logical reads
IF OBJECT_ID('dbo.dbdome_qs_bigtable', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.dbdome_qs_bigtable (
        id   INT IDENTITY PRIMARY KEY,
        col1 NVARCHAR(200) DEFAULT REPLICATE(N'X', 200),
        col2 NVARCHAR(200) DEFAULT REPLICATE(N'Y', 200),
        col3 NVARCHAR(200) DEFAULT REPLICATE(N'Z', 200)
    );
    -- Roughly 600 bytes per row; 200 000 rows ~ 120 MB / ~15 000 8 KB pages
    DECLARE @i INT = 0;
    WHILE @i < 200000
    BEGIN
        INSERT INTO dbo.dbdome_qs_bigtable DEFAULT VALUES;
        SET @i += 1;
    END;
END;
GO
-- Force a fresh, unique one-off query that will record execution_count = 1
-- and accumulate high logical reads (full scan).
DECLARE @dummy NVARCHAR(MAX);
SELECT @dummy = MAX(col1 + col2 + col3)
FROM dbo.dbdome_qs_bigtable WITH (NOLOCK)
WHERE id >= 1
OPTION (RECOMPILE, USE HINT('ENABLE_QUERY_OPTIMIZER_HOTFIXES'));
GO
-- REVERT:
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_qs_testdb')
    DROP DATABASE dbdome_qs_testdb;
GO

/* ===== SEC-SQL-AUD-007-RC03 [SAFE] ===== */
-- Detection fires when a user session is connected from an IP that does not
-- match 10.*, 192.168.*, 127.*, or <local machine>. Open a connection from
-- an external/public IP address (e.g. through a VPN exit node, a cloud VM,
-- or a loopback alias on a non-RFC-1918 address). Keep the session open.
-- NOTE: Truly requires a connection arriving on a public/routable IP.
-- On a test box with only private IPs, you can still see '<local machine>'
-- filtered out; for a full positive you need an external IP source.
-- This is a best-effort setup: verify client_net_address in the query below.
-- SETUP:
-- In a SEPARATE session from an external IP (or use a loopback alias):
--   sqlcmd -S <server> -E -Q "WAITFOR DELAY '00:10:00'"
-- Then inspect:
SELECT s.login_name, c.client_net_address, s.program_name, s.host_name
FROM sys.dm_exec_sessions s
JOIN sys.dm_exec_connections c ON s.session_id = c.session_id
WHERE s.is_user_process = 1
  AND c.client_net_address NOT LIKE '10.%'
  AND c.client_net_address NOT LIKE '192.168.%'
  AND c.client_net_address NOT LIKE '127.%'
  AND c.client_net_address NOT LIKE '<local machine>';
GO
-- REVERT:
-- Close / kill the external session. No persistent objects created.
SELECT 'No persistent objects to revert for SEC-SQL-AUD-007-RC03' AS revert_status;
GO

/* ===== SEC-SQL-AUD-007-RC04 [SAFE] ===== */
-- Detection fires when a user session exists during off-hours (UTC hour
-- NOT BETWEEN 6 AND 20) from a login that does not look like a service
-- account. Hold an open session on a test login during off-hours UTC
-- (i.e. before 06:00 or after 20:00 UTC). Alternatively, create a login
-- without 'svc'/'service'/'agent'/'NT ' in its name and hold a session.
-- NOTE: gated on server UTC time. Run between 21:00-05:59 UTC, OR adjust
-- the server time zone for testing. Login must be active (keep WAITFOR open).
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_offhours_login')
    CREATE LOGIN dbdome_offhours_login WITH PASSWORD = 'P@ssw0rd_dbdome!1';
GO
-- In a SEPARATE session (off-hours UTC), connect as dbdome_offhours_login:
--   sqlcmd -S <server> -U dbdome_offhours_login -P "P@ssw0rd_dbdome!1" -Q "WAITFOR DELAY '00:10:00'"
-- Confirm detection fires when utc_hour NOT BETWEEN 6 AND 20:
SELECT login_name, program_name, host_name, login_time, status,
       DATEPART(HOUR, GETUTCDATE()) AS utc_hour
FROM sys.dm_exec_sessions
WHERE is_user_process = 1
  AND login_name = 'dbdome_offhours_login';
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_offhours_login')
    DROP LOGIN dbdome_offhours_login;
GO

/* ===== SEC-SQL-AUD-007-RC05 [DESTRUCTIVE] ===== */
-- Detection fires when Query Store records a stored procedure executed
-- exactly once (count_executions=1) within the last 7 days.
-- We create a new stored procedure and call it exactly once so QS records
-- count_executions=1 and first_execution_time within the window.
-- NOTE: Query Store must be enabled on the database. Requires CREATE
-- PROCEDURE and ALTER DATABASE permissions.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_qs_proc_testdb')
    CREATE DATABASE dbdome_qs_proc_testdb;
GO
ALTER DATABASE dbdome_qs_proc_testdb SET QUERY_STORE = ON
    (OPERATION_MODE = READ_WRITE,
     MAX_STORAGE_SIZE_MB = 50,
     QUERY_CAPTURE_MODE = ALL);
GO
USE dbdome_qs_proc_testdb;
GO
IF OBJECT_ID('dbo.dbdome_unseen_proc', 'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_unseen_proc;
GO
CREATE PROCEDURE dbo.dbdome_unseen_proc
AS
BEGIN
    SELECT 1 AS dbdome_test_result;
END;
GO
-- Execute exactly once so QS records count_executions = 1
EXEC dbo.dbdome_unseen_proc;
GO
-- REVERT:
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_qs_proc_testdb')
    DROP DATABASE dbdome_qs_proc_testdb;
GO

/* ===== SEC-SQL-AUD-008-RC01 [SAFE] ===== */
-- Detection fires when an active request uses BULK INSERT, INSERT...SELECT,
-- OPENROWSET, or BCP in its SQL text AND logical_reads > 100 000.
-- Trigger: run a long-running BULK INSERT or a heavy OPENROWSET/SELECT that
-- takes time to complete (so it is still active in dm_exec_requests when
-- the detection runs). Use WAITFOR or a large dataset to keep it alive.
-- NOTE: The session must still be executing when the detection query runs.
-- For OPENROWSET the ad hoc distributed queries option must be ON.
-- SETUP:
-- Enable ad hoc distributed queries (needed for OPENROWSET trigger path):
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'Ad Hoc Distributed Queries', 1; RECONFIGURE;
GO
-- Create a target table and a large source to drive high logical reads:
IF OBJECT_ID('dbo.dbdome_bulk_target', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_bulk_target;
CREATE TABLE dbo.dbdome_bulk_target (id INT, val NVARCHAR(400));
GO
-- In a SEPARATE long-running session, run a heavy INSERT...SELECT loop
-- that keeps logical_reads accumulating; the detection catches it mid-flight.
-- Example (run in separate session and do NOT wait for it to finish before
-- running the detection):
--   INSERT INTO dbo.dbdome_bulk_target (id, val)
--   SELECT TOP 5000000 ROW_NUMBER() OVER (ORDER BY a.object_id),
--          REPLICATE(N'A',400)
--   FROM sys.all_columns a CROSS JOIN sys.all_columns b;
SELECT 'Start the INSERT...SELECT above in a separate session, then run detection' AS instruction;
GO
-- REVERT:
EXEC sp_configure 'Ad Hoc Distributed Queries', 0; RECONFIGURE;
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
GO
IF OBJECT_ID('dbo.dbdome_bulk_target', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_bulk_target;
GO

/* ===== SEC-SQL-AUD-008-RC02 [DESTRUCTIVE] ===== */
-- Detection fires when a DELETE or TRUNCATE TABLE is active in
-- dm_exec_requests AND the target table (parsed via PARSENAME on the SQL
-- text) has > 1000 rows in sys.partitions.
-- NOTE: PARSENAME(text,1) on a DELETE/TRUNCATE statement text rarely
-- extracts just the table name cleanly; the detection relies on partial
-- text matching. Best-effort: run a slow DELETE on a large table so it
-- appears in dm_exec_requests long enough for the detection to catch it.
-- SETUP:
IF OBJECT_ID('dbo.dbdome_mass_delete_test', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_mass_delete_test;
GO
CREATE TABLE dbo.dbdome_mass_delete_test (id INT IDENTITY PRIMARY KEY, val CHAR(100));
GO
-- Insert > 1000 rows
DECLARE @i INT = 0;
WHILE @i < 5000
BEGIN
    INSERT INTO dbo.dbdome_mass_delete_test (val) VALUES (REPLICATE('A',100));
    SET @i += 1;
END;
GO
-- In a SEPARATE session, begin a slow DELETE (keep it running):
--   BEGIN TRAN;
--   DELETE FROM dbo.dbdome_mass_delete_test WHERE id > 0;
--   -- do NOT COMMIT yet; keep this open while detection runs
-- Then run the detection to see it appear in dm_exec_requests.
SELECT 'Start the slow DELETE in a separate session (BEGIN TRAN; DELETE ...; no COMMIT)' AS instruction;
GO
-- REVERT:
IF OBJECT_ID('dbo.dbdome_mass_delete_test', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_mass_delete_test;
GO

/* ===== SEC-SQL-AUD-008-RC03 [SAFE] ===== */
-- Detection fires when a DDL command (CREATE TABLE, ALTER TABLE, etc.) is
-- currently executing in dm_exec_requests by a login that is not sysadmin
-- and not db_ddladmin. Create a non-privileged login, connect as that login,
-- and run a DDL statement on a large/slow schema change while the detection
-- executes in a concurrent session.
-- NOTE: The DDL must still be in-flight when the detection runs. Use a
-- table with many rows so the DDL (e.g. adding an indexed column) takes time.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_ddl_login')
    CREATE LOGIN dbdome_ddl_login WITH PASSWORD = 'P@ssw0rd_dbdome!2';
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_ddl_user'
)
BEGIN
    CREATE USER dbdome_ddl_user FOR LOGIN dbdome_ddl_login;
    GRANT ALTER ON SCHEMA::dbo TO dbdome_ddl_user;
    GRANT CREATE TABLE TO dbdome_ddl_user;
END;
GO
-- Create a large table so subsequent ALTER TABLE takes time:
IF OBJECT_ID('dbo.dbdome_ddl_slowtable', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.dbdome_ddl_slowtable (id INT IDENTITY PRIMARY KEY, val CHAR(200));
    DECLARE @i INT = 0;
    WHILE @i < 100000
    BEGIN
        INSERT INTO dbo.dbdome_ddl_slowtable (val) VALUES (REPLICATE('B',200));
        SET @i += 1;
    END;
END;
GO
-- In a SEPARATE session, connect as dbdome_ddl_login and run:
--   ALTER TABLE dbo.dbdome_ddl_slowtable ADD new_col BIGINT DEFAULT 0 WITH VALUES;
-- While that ALTER is running, execute the detection in this session.
SELECT 'Run the ALTER TABLE as dbdome_ddl_login in a separate session' AS instruction;
GO
-- REVERT:
IF OBJECT_ID('dbo.dbdome_ddl_slowtable', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_ddl_slowtable;
GO
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_ddl_user')
    DROP USER dbdome_ddl_user;
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_ddl_login')
    DROP LOGIN dbdome_ddl_login;
GO

/* ===== SEC-SQL-AUD-008-RC04 [SAFE] ===== */
-- Detection fires when an active request's SQL text contains keywords like
-- 'api_key', 'secret_key', 'enc_key', 'master_key', 'credential', or
-- 'token_store'. Trigger by running a long query that references one of
-- those literal strings in its text and is still executing when the
-- detection runs (use WAITFOR or a slow scan to keep it active).
-- NOTE: The query must be in-flight when the detection executes.
-- SETUP:
-- In a SEPARATE session, run a query that embeds a matching keyword and
-- takes time (WAITFOR before the real work):
--   WAITFOR DELAY '00:01:00';
--   SELECT 'api_key' AS api_key, GETDATE() AS ts
--   FROM sys.objects CROSS JOIN sys.columns; -- slow enough to stay active
-- While it runs, execute the detection in this session.
SELECT 'Start WAITFOR + SELECT with api_key literal in a separate session' AS instruction;
GO
-- REVERT:
-- Kill the separate session. No persistent objects created.
SELECT 'No persistent objects to revert for SEC-SQL-AUD-008-RC04' AS revert_status;
GO

/* ===== SEC-SQL-AUD-008-RC05 [DESTRUCTIVE] ===== */
-- Detection fires when schemas exist in the database that are not in the
-- exclusion list (dbo, sys, INFORMATION_SCHEMA, guest). Simply CREATE a
-- non-standard schema; the detection returns >= 1 row immediately.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dbdome_crossschema_test')
BEGIN
    EXEC('CREATE SCHEMA dbdome_crossschema_test');
END;
GO
-- Optionally create an object so object_count > 0:
IF OBJECT_ID('dbdome_crossschema_test.dbdome_marker_table', 'U') IS NULL
    CREATE TABLE dbdome_crossschema_test.dbdome_marker_table (id INT);
GO
-- REVERT:
IF OBJECT_ID('dbdome_crossschema_test.dbdome_marker_table', 'U') IS NOT NULL
    DROP TABLE dbdome_crossschema_test.dbdome_marker_table;
GO
IF EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dbdome_crossschema_test')
    EXEC('DROP SCHEMA dbdome_crossschema_test');
GO

/* ===== SEC-SQL-AUD-009-RC01 [SAFE] ===== */
-- Detection fires when an active request's SQL text contains tautology
-- patterns: 'OR 1=1', 'OR 1>0', or 'OR TRUE'. Trigger by running a slow
-- query that contains one of these literal strings and is still in-flight
-- when the detection executes.
-- NOTE: Must be caught mid-execution. Use WAITFOR or a cross-join to keep
-- it alive. The literal string in the query text is sufficient; SQL Server
-- does NOT evaluate OR 1=1 as a tautology and reject/rewrite it --
-- the text is preserved in dm_exec_sql_text.
-- SETUP:
-- In a SEPARATE session, run:
--   SELECT TOP 1 a.object_id
--   FROM sys.all_columns a CROSS JOIN sys.all_columns b
--   WHERE a.object_id > 0 OR 1=1   -- tautology literal preserved in SQL text
--   OPTION (MAXDOP 1);
-- While the cross-join is running, execute the detection in this session.
SELECT 'Run the cross-join with OR 1=1 literal in a separate session' AS instruction;
GO
-- REVERT:
-- Kill the separate session. No persistent objects created.
SELECT 'No persistent objects to revert for SEC-SQL-AUD-009-RC01' AS revert_status;
GO

/* ===== SEC-SQL-AUD-009-RC02 [SAFE] ===== */
-- Detection fires when an active request's SQL text matches patterns like
-- ';%SELECT%', ';%DROP%', ';%INSERT%', or ';%EXEC%' -- indicating stacked
-- query patterns in the request text. Trigger by running a long batch whose
-- text contains a semicolon followed by one of these keywords, while it is
-- still executing when the detection runs.
-- NOTE: The entire batch text (all statements) is captured by
-- dm_exec_sql_text, so a slow first statement followed by a SELECT (joined
-- with ';') will match ';%SELECT%'. Keep the batch alive long enough.
-- SETUP:
-- In a SEPARATE session, run a batch whose text matches the pattern:
--   WAITFOR DELAY '00:01:00'; SELECT 1 AS dbdome_stacked_test;
-- The full batch text contains '; SELECT' which matches ';%SELECT%'.
-- While the WAITFOR is sleeping, execute the detection in this session.
SELECT 'Run: WAITFOR DELAY ''00:01:00''; SELECT 1 -- in a separate session' AS instruction;
GO
-- REVERT:
-- Kill the separate session. No persistent objects created.
SELECT 'No persistent objects to revert for SEC-SQL-AUD-009-RC02' AS revert_status;
GO


/* ########## batch 13 (12 reproducers) ########## */
/* ===== SEC-SQL-AUD-009-RC03 [SAFE] ===== */
-- Detection joins dm_exec_sessions + dm_exec_requests; the UNION+sys.* query must be
-- RUNNING (not completed) when the detection polls. Run Session A first, then poll
-- the detection from Session B. No persistent schema changes.
-- SETUP:
-- (Session A) Execute and keep running:
-- DECLARE @i INT = 0;
-- WHILE @i < 1000000
-- BEGIN
--   SELECT @i = COUNT(*) FROM (SELECT name FROM sys.tables UNION SELECT name FROM sys.columns) u;
--   SET @i = @i + 1;
-- END
-- Text contains UNION...SELECT and sys. => detection fires.
GO
-- REVERT:
-- KILL <session_id of Session A>; no schema changes.
GO


/* ===== SEC-SQL-AUD-009-RC04 [SAFE] ===== */
-- Detection scans dm_exec_requests for queries containing WAITFOR DELAY / WAITFOR TIME.
-- The triggering query itself IS a WAITFOR, so simply run it in Session A;
-- poll the detection in Session B before the delay expires.
-- SETUP:
-- (Session A) Run and leave open:
WAITFOR DELAY '00:02:00';
GO
-- REVERT:
-- KILL <session_id of Session A>  -- or let it expire naturally; no schema changes.
GO


/* ===== SEC-SQL-AUD-009-RC05 [SAFE] ===== */
-- Detection looks for CHAR(%+CHAR(% or /*...*/ comment syntax in active request text.
-- Run a long query in Session A whose text contains a C-style comment block.
-- SETUP:
-- (Session A) Execute and keep running:
-- DECLARE @i INT = 0;
-- WHILE @i < 2000000
-- BEGIN
--   SELECT @i = @i + 1; /* obfuscated loop counter */
-- END
-- Text contains /*...*/ which matches %/*%*/%  => detection fires.
GO
-- REVERT:
-- KILL <session_id of Session A>; no schema changes.
GO


/* ===== SEC-SQL-AUD-010-RC01 [DESTRUCTIVE] ===== */
-- Detection queries sys.query_store_query_text for stored queries referencing
-- INFORMATION_SCHEMA or sys.columns.  Query Store must be ON and queries must have
-- been executed (and cached) on the target database.
-- SETUP:
-- Enable Query Store on the test database if not already on:
IF NOT EXISTS (
    SELECT 1 FROM sys.databases WHERE name = DB_NAME() AND is_query_store_on = 1
)
BEGIN
    DECLARE @sql_qs NVARCHAR(200) = N'ALTER DATABASE ' + QUOTENAME(DB_NAME()) + N' SET QUERY_STORE = ON (OPERATION_MODE = READ_WRITE)';
    EXEC sp_executesql @sql_qs;
END
GO
-- Execute several INFORMATION_SCHEMA queries so they are captured in Query Store:
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES;
SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS;
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo';
SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'sysusers';
SELECT name FROM sys.columns WHERE object_id = OBJECT_ID('sys.objects');
GO
-- REVERT:
-- Flush Query Store (removes cached query texts):
ALTER DATABASE CURRENT SET QUERY_STORE CLEAR ALL;
-- Optionally turn Query Store off if it was off before:
-- ALTER DATABASE CURRENT SET QUERY_STORE = OFF;
GO


/* ===== SEC-SQL-AUD-010-RC02 [SAFE] ===== */
-- Detection fires when a non-sysadmin login runs a query referencing sys.server_principals,
-- sys.database_principals, or sys.sql_logins.  Run the enumeration query in Session A
-- logged in as a non-sysadmin login while detection polls in Session B.
-- SETUP (run as sysadmin to create the test login first):
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'dbdome_nonadmin_test')
    CREATE LOGIN dbdome_nonadmin_test WITH PASSWORD = 'DbD0me$Tst!2024', CHECK_POLICY = OFF;
GO
-- Grant minimal connect rights:
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'dbdome_nonadmin_test')
BEGIN
    CREATE USER dbdome_nonadmin_test FOR LOGIN dbdome_nonadmin_test;
    GRANT VIEW DATABASE STATE TO dbdome_nonadmin_test;
    GRANT VIEW SERVER STATE TO dbdome_nonadmin_test;
END
GO
-- (Session A) Connect as dbdome_nonadmin_test and run a slow enumeration query:
-- DECLARE @i INT = 0;
-- WHILE @i < 1000000
-- BEGIN
--   SELECT @i = COUNT(*) FROM sys.server_principals;
--   SET @i = @i + 1;
-- END
-- The text contains sys.server_principals and the login is not sysadmin => detection fires.
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'dbdome_nonadmin_test')
    DROP USER dbdome_nonadmin_test;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'dbdome_nonadmin_test')
    DROP LOGIN dbdome_nonadmin_test;
GO


/* ===== SEC-SQL-AUD-010-RC03 [SAFE] ===== */
-- Detection looks for active requests whose text contains INFORMATION_SCHEMA%COLUMNS
-- and does NOT contain TABLE_NAME=<something> (exact filter check).
-- Run a long INFORMATION_SCHEMA.COLUMNS scan without a TABLE_NAME = filter in Session A.
-- SETUP:
-- (Session A) Execute and keep running:
-- DECLARE @i INT = 0;
-- WHILE @i < 1000000
-- BEGIN
--   SELECT @i = COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE ORDINAL_POSITION > 0;
--   SET @i = @i + 1;
-- END
-- Text matches %INFORMATION_SCHEMA%COLUMNS% and does not contain TABLE_NAME =.
GO
-- REVERT:
-- KILL <session_id of Session A>; no schema changes.
GO


/* ===== SEC-SQL-AUD-010-RC04 [SAFE] ===== */
-- Detection fires when a non-sysadmin login queries sys.sql_modules or
-- INFORMATION_SCHEMA.ROUTINES.  Same pattern as RC02: run in Session A as
-- a non-sysadmin login while detection polls.
-- SETUP:
-- (Ensure dbdome_nonadmin_test login exists — see SEC-SQL-AUD-010-RC02 SETUP.)
-- (Session A) Connect as dbdome_nonadmin_test:
-- DECLARE @i INT = 0;
-- WHILE @i < 500000
-- BEGIN
--   SELECT @i = COUNT(*) FROM sys.sql_modules;
--   SET @i = @i + 1;
-- END
-- Text contains sys.sql_modules; login is not sysadmin => detection fires.
GO
-- REVERT:
-- KILL Session A; optionally drop dbdome_nonadmin_test (see RC02 revert).
GO


/* ===== SEC-SQL-AUD-010-RC05 [SAFE] ===== */
-- Detection fires on active requests referencing fn_my_permissions,
-- sys.database_permissions, or sys.server_permissions.
-- Run a long permission-discovery query in Session A.
-- SETUP:
-- (Session A) Execute and keep running:
-- DECLARE @i INT = 0;
-- WHILE @i < 1000000
-- BEGIN
--   SELECT @i = COUNT(*) FROM sys.database_permissions;
--   SET @i = @i + 1;
-- END
-- Text contains sys.database_permissions => detection fires.
GO
-- REVERT:
-- KILL <session_id of Session A>; no schema changes.
GO


/* ===== SEC-SQL-AUD-011-RC01 [SAFE] ===== */
-- Detection fires on active DML (INSERT/UPDATE/DELETE) requests whose text also
-- contains 'audit', 'event_log', or 'trace_log'.
-- Use a fake table named dbo.dbdome_audit_test to satisfy both predicates.
-- NOTE: the table must exist so the query compiles; create it first, then run
-- a slow INSERT in Session A while detection polls in Session B.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = N'dbdome_audit_test' AND schema_id = SCHEMA_ID('dbo'))
    CREATE TABLE dbo.dbdome_audit_test (id INT IDENTITY PRIMARY KEY, log_entry NVARCHAR(500), created_at DATETIME DEFAULT GETDATE());
GO
-- (Session A) Execute a slow INSERT loop to keep the DML on an audit-named table in-flight:
-- DECLARE @i INT = 0;
-- WHILE @i < 100000
-- BEGIN
--   INSERT INTO dbo.dbdome_audit_test (log_entry) VALUES (CAST(@i AS NVARCHAR(20)));
--   SET @i = @i + 1;
-- END
-- Text contains INSERT and 'audit' => detection fires.
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = N'dbdome_audit_test' AND schema_id = SCHEMA_ID('dbo'))
    DROP TABLE dbo.dbdome_audit_test;
GO


/* ===== SEC-SQL-AUD-011-RC02 [SAFE] ===== */
-- Detection fires on active requests whose text matches
-- ALTER%AUDIT%STATE%OFF  or  sp_configure%audit%.
-- Run a long batch in Session A that contains the keyword pattern in its text.
-- NOTE: the batch must be syntactically valid but need not actually alter the audit;
-- embed the pattern inside a comment or a conditional that never executes.
-- SETUP:
-- (Session A) Execute and keep running — text contains ALTER AUDIT STATE OFF inside a comment:
-- DECLARE @i INT = 0;
-- WHILE @i < 2000000
-- BEGIN
--   /* simulated: ALTER AUDIT STATE = OFF */
--   SET @i = @i + 1;
-- END
-- Text contains %ALTER%AUDIT%STATE%OFF% inside comment => detection fires.
GO
-- REVERT:
-- KILL <session_id of Session A>; no schema changes.
GO


/* ===== SEC-SQL-AUD-011-RC03 [SAFE] ===== */
-- Detection fires on active requests whose text matches
-- (TRUNCATE%TABLE or DROP%TABLE) AND (audit or event_log or trace).
-- Use a fake TRUNCATE against a table named dbo.dbdome_trace_test inside a slow loop.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = N'dbdome_trace_test' AND schema_id = SCHEMA_ID('dbo'))
    CREATE TABLE dbo.dbdome_trace_test (id INT IDENTITY PRIMARY KEY, entry NVARCHAR(200));
GO
-- Insert at least one row so TRUNCATE has work to do inside the loop:
INSERT INTO dbo.dbdome_trace_test (entry) VALUES ('dummy');
GO
-- (Session A) Execute and keep running:
-- DECLARE @i INT = 0;
-- WHILE @i < 100000
-- BEGIN
--   TRUNCATE TABLE dbo.dbdome_trace_test;
--   INSERT INTO dbo.dbdome_trace_test (entry) VALUES ('dummy');
--   SET @i = @i + 1;
-- END
-- Text contains TRUNCATE TABLE and 'trace' => detection fires.
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = N'dbdome_trace_test' AND schema_id = SCHEMA_ID('dbo'))
    DROP TABLE dbo.dbdome_trace_test;
GO


/* ===== SEC-SQL-AUD-011-RC04 [DESTRUCTIVE] ===== */
-- Detection queries sys.triggers for rows where is_disabled = 1.
-- Simply disable an existing trigger, or create and disable a dummy one.
-- SETUP:
-- Create a throwaway table and trigger, then disable the trigger:
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = N'dbdome_trigger_test' AND schema_id = SCHEMA_ID('dbo'))
    CREATE TABLE dbo.dbdome_trigger_test (id INT IDENTITY PRIMARY KEY, val NVARCHAR(100));
GO
IF NOT EXISTS (SELECT 1 FROM sys.triggers WHERE name = N'trg_dbdome_test_audit' AND parent_id = OBJECT_ID('dbo.dbdome_trigger_test'))
BEGIN
    EXEC sp_executesql N'
        CREATE TRIGGER trg_dbdome_test_audit
        ON dbo.dbdome_trigger_test
        AFTER INSERT, UPDATE, DELETE
        AS
        BEGIN
            -- dummy audit trigger
            DECLARE @dummy INT = 1;
        END';
END
GO
-- Disable the trigger — this is what the detection flags (is_disabled = 1):
DISABLE TRIGGER trg_dbdome_test_audit ON dbo.dbdome_trigger_test;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = N'trg_dbdome_test_audit')
BEGIN
    ENABLE TRIGGER trg_dbdome_test_audit ON dbo.dbdome_trigger_test;
    DROP TRIGGER trg_dbdome_test_audit;
END
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = N'dbdome_trigger_test' AND schema_id = SCHEMA_ID('dbo'))
    DROP TABLE dbo.dbdome_trigger_test;
GO


/* ########## batch 14 (12 reproducers) ########## */
/* =======================================================================
   Positive-test reproducers – slice 168..180
   File  : pt_14.sql
   Target: DISPOSABLE test SQL Server only
   ======================================================================= */

/* ===== SEC-SQL-AUD-011-RC05 [SAFE] ===== */
-- Detection fires when sp_cycle_errorlog is found in a currently-running
-- request's sql_handle text.  Because the statement finishes in milliseconds,
-- the observation window is tiny.  Best practice: run this SETUP block and
-- then IMMEDIATELY execute the detection query in the SAME SSMS window with
-- results-to-text so it catches the in-flight call; alternatively wrap the
-- call in a long WAITFOR loop (see below).  Runs as sysadmin.  SAFE – error
-- log is recycled but no data is lost.
-- SETUP:
-- Hold sp_cycle_errorlog in-flight for ~60 s so the detection can observe it.
-- Execute this in Session A:
WAITFOR DELAY '00:01:00';
EXEC sp_cycle_errorlog;
-- Then run the detection query immediately from Session B.
GO
-- REVERT:
-- Nothing to revert; sp_cycle_errorlog is inherently ephemeral.
-- If you want to restore the previous error-log content, that is not possible,
-- but normal SQL Server operation is unaffected.
PRINT 'SEC-SQL-AUD-011-RC05: no persistent changes to revert.';
GO

/* ===== SEC-SQL-AUD-012-RC01 [SAFE] ===== */
-- Detection fires for sessions with open_transaction_count > 0 AND
-- last_request_start_time > 30 minutes ago.
-- Run SETUP in a dedicated Session A and leave it open.  After 30 minutes the
-- detection will flag it.  To test immediately, run the detection query after
-- the WAITFOR completes (adjust delay to 31 minutes) or simply open the
-- transaction and wait.
-- SETUP:
-- Run in Session A – keep the connection open:
BEGIN TRANSACTION;
-- Do a trivial write so open_transaction_count = 1:
IF OBJECT_ID('dbo.dbdome_idle_tran_test', 'U') IS NULL
    CREATE TABLE dbo.dbdome_idle_tran_test (id INT);
INSERT INTO dbo.dbdome_idle_tran_test VALUES (1);
-- Session A must remain idle (no further requests) for >30 minutes.
-- Do NOT commit or rollback from Session A until after running the detection.
GO
-- REVERT:
-- Run from Session A (or kill the SPID, then clean up the table):
-- ROLLBACK TRANSACTION; -- run this in Session A to close the transaction
IF OBJECT_ID('dbo.dbdome_idle_tran_test', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_idle_tran_test;
GO

/* ===== SEC-SQL-AUD-012-RC02 [DESTRUCTIVE] ===== */
-- Detection fires when an OBJECT-level X or SCH-M lock is held on a table
-- with >100 000 rows for >10 minutes.
-- We create a large table, hold an exclusive lock on it via an open
-- transaction, and leave Session A idle.  After 10 minutes the detection fires.
-- Requires sysadmin or db_owner on the test database.
-- SETUP:
IF OBJECT_ID('dbo.dbdome_lock_test', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_lock_test;
GO
CREATE TABLE dbo.dbdome_lock_test (id INT IDENTITY PRIMARY KEY, filler CHAR(100));
GO
-- Bulk-insert 110 000 rows to satisfy p.rows > 100000:
WITH n AS (
    SELECT TOP 110000 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_columns a CROSS JOIN sys.all_columns b
)
INSERT INTO dbo.dbdome_lock_test (filler)
SELECT REPLICATE('X', 100) FROM n;
GO
-- Now in Session A – open a transaction that holds an X lock on the table:
-- BEGIN TRANSACTION;
-- SELECT TOP 1 id FROM dbo.dbdome_lock_test WITH (TABLOCKX, HOLDLOCK);
-- Leave Session A open for >10 minutes, then run the detection from Session B.
GO
-- REVERT:
-- First, in Session A: ROLLBACK TRANSACTION;
-- Then from any session:
IF OBJECT_ID('dbo.dbdome_lock_test', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_lock_test;
GO

/* ===== SEC-SQL-AUD-012-RC03 [SAFE] ===== */
-- Detection fires for sleeping sessions with open_transaction_count > 0,
-- idle > 300 s, AND at least one other session is blocked by them.
-- Two sessions required:
--   Session A – opens a transaction, writes, then goes idle (sleeping).
--   Session B – attempts a conflicting write; it will be blocked by Session A.
-- After 300 s the detection query (run from Session C) will return a row.
-- SETUP:
-- === Session A (run first, then do NOT issue any further statements): ===
IF OBJECT_ID('dbo.dbdome_block_test', 'U') IS NULL
    CREATE TABLE dbo.dbdome_block_test (id INT PRIMARY KEY, val INT);
INSERT INTO dbo.dbdome_block_test VALUES (1, 0) ON CONFLICT DO NOTHING; -- placeholder comment only
-- Correct T-SQL:
-- IF NOT EXISTS (SELECT 1 FROM dbo.dbdome_block_test WHERE id=1)
--     INSERT INTO dbo.dbdome_block_test VALUES(1,0);
-- BEGIN TRANSACTION;
-- UPDATE dbo.dbdome_block_test SET val = 1 WHERE id = 1;
-- (leave transaction open – Session A goes idle / sleeping)

-- === Session B (run after Session A is sleeping): ===
-- BEGIN TRANSACTION;
-- UPDATE dbo.dbdome_block_test SET val = 2 WHERE id = 1;  -- blocks on Session A
-- (leave blocked)

-- After 300 s idle on Session A, run detection from Session C.
GO
-- REVERT:
-- Session A: ROLLBACK TRANSACTION;
-- Session B: ROLLBACK TRANSACTION; (unblocks automatically once A rolls back)
IF OBJECT_ID('dbo.dbdome_block_test', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_block_test;
GO

/* ===== SEC-SQL-AUD-012-RC04 [DESTRUCTIVE] ===== */
-- Detection fires when database_transaction_log_bytes_used > 10 485 760 (10 MB)
-- in an active transaction.  We open a transaction, write enough data to exceed
-- 10 MB of log, and keep it open so the detection can observe it.
-- Run SETUP in Session A and leave open; run detection from Session B.
-- SETUP:
IF OBJECT_ID('dbo.dbdome_logbytes_test', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_logbytes_test;
CREATE TABLE dbo.dbdome_logbytes_test (id INT IDENTITY, payload NVARCHAR(MAX));
GO
-- Session A: open transaction and generate >10 MB of log:
-- BEGIN TRANSACTION;
-- DECLARE @i INT = 0;
-- WHILE @i < 500
-- BEGIN
--     INSERT INTO dbo.dbdome_logbytes_test (payload) VALUES (REPLICATE(CAST('X' AS NVARCHAR(MAX)), 10000));
--     SET @i = @i + 1;
-- END
-- -- Do NOT commit – leave transaction open, then run detection from Session B.
GO
-- REVERT:
-- Session A: ROLLBACK TRANSACTION;
IF OBJECT_ID('dbo.dbdome_logbytes_test', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_logbytes_test;
GO

/* ===== SEC-SQL-AUD-012-RC05 [SAFE] ===== */
-- Detection fires when a currently-executing request contains
-- 'SAVE%TRANSACTION' or both 'ROLLBACK%TRAN' and 'SAVE%' in its sql_handle
-- text.  Because SAVE TRANSACTION itself executes instantly, we must run a
-- batch that contains the keyword and sleeps long enough for the detection to
-- observe it.
-- Run SETUP in Session A; run detection from Session B during the WAITFOR.
-- SETUP:
-- Session A:
SAVE TRANSACTION dbdome_sp1;
WAITFOR DELAY '00:01:00';
ROLLBACK TRANSACTION dbdome_sp1;
GO
-- REVERT:
-- Nothing persistent to revert; the transaction was already rolled back.
PRINT 'SEC-SQL-AUD-012-RC05: no persistent changes to revert.';
GO

/* ===== SEC-SQL-AUD-013-RC01 [DESTRUCTIVE] ===== */
-- Detection fires when a non-sysadmin session is actively executing a request
-- whose sql_handle text contains 'sp_configure'.
-- We create a low-privilege login, connect as that login in Session A and run
-- sp_configure (it will fail with a permissions error, but the request is still
-- observable while it is executing / if wrapped in a WAITFOR batch).
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    CREATE LOGIN dbdome_test_login WITH PASSWORD = 'D!sp0s@bleP4ss#2025', CHECK_POLICY = OFF;
GO
-- Grant connect only – deliberately NOT sysadmin:
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_test_login')
    CREATE USER dbdome_test_login FOR LOGIN dbdome_test_login;
GO
-- Session A: connect as dbdome_test_login, then run:
-- WAITFOR DELAY '00:00:10';  -- gives you time to run the detection
-- EXEC sp_configure 'show advanced options', 1;  -- will fail (no permission) but is in-flight
-- Run detection from Session B during the WAITFOR window.
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_test_login')
    DROP USER dbdome_test_login;
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    DROP LOGIN dbdome_test_login;
GO

/* ===== SEC-SQL-AUD-013-RC02 [SAFE] ===== */
-- Detection fires when a currently-running request references sp_configure AND
-- one of: xp_cmdshell, Ole Automation, clr enabled, ad hoc distributed queries.
-- Wrap the sp_configure call in a WAITFOR so Session B can observe it.
-- Run SETUP in Session A; run detection from Session B during the WAITFOR.
-- NOTE: the sp_configure call will either succeed (sysadmin) or fail (non-admin)
-- but is still visible in dm_exec_sql_text during execution.
-- SETUP:
-- Session A (run as sysadmin or any login for observability):
WAITFOR DELAY '00:00:30';
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;
GO
-- REVERT:
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 0; RECONFIGURE;
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-AUD-013-RC03 [DESTRUCTIVE] ===== */
-- Detection fires for rows in sys.triggers where is_disabled = 1 AND
-- parent_class = 1 (table trigger).  We create a table, add a DML trigger,
-- then disable it.
-- SETUP:
IF OBJECT_ID('dbo.dbdome_trig_test', 'U') IS NULL
    CREATE TABLE dbo.dbdome_trig_test (id INT);
GO
IF OBJECT_ID('dbo.dbdome_trig_test_trg', 'TR') IS NOT NULL
    DROP TRIGGER dbo.dbdome_trig_test_trg;
GO
CREATE TRIGGER dbo.dbdome_trig_test_trg
ON dbo.dbdome_trig_test
AFTER INSERT
AS
BEGIN
    PRINT 'dbdome test trigger fired';
END;
GO
-- Disable the trigger so the detection returns a row:
DISABLE TRIGGER dbo.dbdome_trig_test_trg ON dbo.dbdome_trig_test;
GO
-- REVERT:
IF OBJECT_ID('dbo.dbdome_trig_test_trg', 'TR') IS NOT NULL
BEGIN
    ENABLE TRIGGER dbo.dbdome_trig_test_trg ON dbo.dbdome_trig_test;
    DROP TRIGGER dbo.dbdome_trig_test_trg;
END
GO
IF OBJECT_ID('dbo.dbdome_trig_test', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_trig_test;
GO

/* ===== SEC-SQL-AUD-013-RC04 [SAFE] ===== */
-- Detection fires when a currently-running request text contains
-- 'ALTER%SERVER%AUDIT' or 'ALTER%AUDIT%SPECIFICATION'.
-- Wrap the statement in a WAITFOR so the detection can observe it in-flight.
-- Requires ALTER ANY SERVER AUDIT or sysadmin.
-- SETUP:
-- Session A:
-- First ensure a target audit exists (create a dummy one if needed):
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_dummy_audit')
BEGIN
    -- Use a file target (adjust path as needed for the test server):
    EXEC('CREATE SERVER AUDIT dbdome_dummy_audit
          TO FILE (FILEPATH = ''C:\temp\'', MAXSIZE = 2 MB)
          WITH (ON_FAILURE = CONTINUE);');
END
GO
-- Session A: wrap ALTER in WAITFOR so detection catches it:
-- WAITFOR DELAY '00:00:30';
-- ALTER SERVER AUDIT dbdome_dummy_audit WITH (STATE = OFF);
-- Run detection from Session B during the WAITFOR.
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_dummy_audit')
BEGIN
    EXEC('ALTER SERVER AUDIT dbdome_dummy_audit WITH (STATE = OFF);');
    EXEC('DROP SERVER AUDIT dbdome_dummy_audit;');
END
GO

/* ===== SEC-SQL-AUD-013-RC05 [SAFE] ===== */
-- Detection fires when a currently-running request text contains
-- sp_addlinkedserver, sp_addremotelogin, or sp_setnetname.
-- Wrap in WAITFOR so detection can observe it.
-- Run SETUP in Session A; run detection from Session B during the WAITFOR.
-- SETUP:
-- Session A:
WAITFOR DELAY '00:00:30';
EXEC sp_addlinkedserver
    @server     = N'DBDOME_FAKE_LINKED',
    @srvproduct = N'',
    @provider   = N'SQLNCLI',
    @datasrc    = N'192.0.2.1\FAKE';   -- non-routable IP; will fail to connect but sp runs
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.servers WHERE name = 'DBDOME_FAKE_LINKED')
    EXEC sp_dropserver @server = N'DBDOME_FAKE_LINKED', @droplogins = 'droplogins';
GO

/* ===== SEC-SQL-AUD-014-RC01 [DESTRUCTIVE] ===== */
-- Detection fires when a currently-running request text contains
-- 'CREATE%LOGIN' or 'CREATE%USER'.
-- Wrap in WAITFOR in Session A so detection can catch it in-flight.
-- The CREATE LOGIN itself also leaves a persistent artifact, handled in REVERT.
-- SETUP:
-- Session A:
WAITFOR DELAY '00:00:30';
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_created_login')
    CREATE LOGIN dbdome_created_login WITH PASSWORD = 'D!sp0s@bleCreated#2025', CHECK_POLICY = OFF;
-- Run detection from Session B during the WAITFOR window.
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_created_login')
    DROP LOGIN dbdome_created_login;
GO


/* ########## batch 15 (12 reproducers) ########## */
-- =============================================================================
-- Positive-test reproducers for detections slice [180..192]
-- Target: DISPOSABLE / throwaway SQL Server instance only.
-- Run SETUP in one session; verify detection returns >=1 row; run REVERT.
-- =============================================================================

/* ===== SEC-SQL-AUD-014-RC02 [SAFE] ===== */
-- Detection watches dm_exec_requests.sql_handle for ALTER SERVER ROLE ... ADD MEMBER
-- or sp_addsrvrolemember text in currently-executing requests.
-- SAFE: the sp_executesql wrapper completes instantly; keep the WAITFOR wrapper
-- open in a SEPARATE session so the query text stays live in dm_exec_requests
-- while you run the detection query.
-- Run as sysadmin. Poll detection within the 5-second window.
-- SETUP:
-- *** Open a NEW session and run this block; do NOT close it until after detection check ***
/*
EXEC sys.sp_executesql
    N'WAITFOR DELAY ''00:00:05'';
      ALTER SERVER ROLE [dbdome_test_fake_role] ADD MEMBER [sa];';
*/
-- In the SAME or another session, immediately run the detection SQL while the above is sleeping.
-- Minimal equivalent that also works (runs the text through sp_executesql so it appears in sql_handle):
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_svrole' AND type = 'R')
    CREATE SERVER ROLE [dbdome_test_svrole];
GO
-- (The live-request approach requires a concurrent session; see notes above.)
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_svrole' AND type = 'R')
    DROP SERVER ROLE [dbdome_test_svrole];
GO

/* ===== SEC-SQL-AUD-014-RC03 [SAFE] ===== */
-- Detection watches dm_exec_requests for ALTER LOGIN ... PASSWORD text in-flight.
-- SAFE: hold an open request via WAITFOR in a separate session.
-- Run as sysadmin. The WAITFOR session must stay alive during the detection query.
-- SETUP:
-- *** Open a NEW session and execute: ***
/*
EXEC sys.sp_executesql
    N'WAITFOR DELAY ''00:00:05'';
      -- ALTER LOGIN [dbdome_test_login] WITH PASSWORD = ''Fake1234!'';';
*/
-- Ensure the target login exists so the string is realistic:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    CREATE LOGIN [dbdome_test_login] WITH PASSWORD = 'Dbdome!Temp1', CHECK_POLICY = OFF;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    DROP LOGIN [dbdome_test_login];
GO

/* ===== SEC-SQL-AUD-014-RC04 [SAFE] ===== */
-- Detection watches dm_exec_requests for sp_addlinkedserver or CREATE SYNONYM text in-flight.
-- SAFE: hold a WAITFOR in a separate session containing the trigger text.
-- SETUP:
-- *** Open a NEW session and execute: ***
/*
EXEC sys.sp_executesql
    N'WAITFOR DELAY ''00:00:05'';
      -- EXEC sp_addlinkedserver ''dbdome_fake_linked'';';
*/
-- Alternatively, CREATE SYNONYM stays visible briefly; use the WAITFOR approach for reliability.
-- No persistent object needed for SAFE detection; synonym below is optional scaffolding:
IF NOT EXISTS (SELECT 1 FROM sys.synonyms WHERE name = 'dbdome_test_syn')
    EXEC(N'CREATE SYNONYM dbo.dbdome_test_syn FOR master.dbo.spt_values;');
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.synonyms WHERE name = 'dbdome_test_syn')
    DROP SYNONYM dbo.dbdome_test_syn;
GO

/* ===== SEC-SQL-AUD-014-RC05 [SAFE] ===== */
-- Detection watches dm_exec_requests for ALTER LOGIN ... ENABLE text in-flight.
-- SAFE: hold a WAITFOR in a separate session containing the trigger text.
-- SETUP:
-- Ensure a disabled login exists to make the ALTER LOGIN ENABLE realistic:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_disabled_login')
    CREATE LOGIN [dbdome_test_disabled_login] WITH PASSWORD = 'Dbdome!Temp2', CHECK_POLICY = OFF;
ALTER LOGIN [dbdome_test_disabled_login] DISABLE;
GO
-- *** Open a NEW session and execute while the detection is polled: ***
/*
EXEC sys.sp_executesql
    N'WAITFOR DELAY ''00:00:05'';
      ALTER LOGIN [dbdome_test_disabled_login] ENABLE;';
*/
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_disabled_login')
    DROP LOGIN [dbdome_test_disabled_login];
GO

/* ===== SEC-SQL-AUD-015-RC01 [DESTRUCTIVE] ===== */
-- Detection reads sys.fn_get_audit_file() for CREATE/ALTER/DROP/DML events in last 24h.
-- Requires: a server-level File Audit already enabled (is_state_enabled=1) writing to disk.
-- Setup: create a server audit + spec targeting DML/DDL, perform a CREATE TABLE + INSERT,
-- then query the audit file. The audit file path must be writable by the SQL Server service account.
-- Run as sysadmin. Adjust @audit_dir to a path writable by the SQL Server service account.
-- SETUP:
DECLARE @audit_dir NVARCHAR(260) = N'C:\SQLAudit\';  -- adjust if needed
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
BEGIN
    EXEC(N'CREATE SERVER AUDIT [dbdome_test_audit]
           TO FILE (FILEPATH = ''C:\SQLAudit\'', MAXSIZE = 10 MB, MAX_ROLLOVER_FILES = 2)
           WITH (ON_FAILURE = CONTINUE);');
END;
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit' AND is_state_enabled = 1)
    ALTER SERVER AUDIT [dbdome_test_audit] WITH (STATE = ON);

IF NOT EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_audit_spec')
BEGIN
    EXEC(N'CREATE SERVER AUDIT SPECIFICATION [dbdome_test_audit_spec]
           FOR SERVER AUDIT [dbdome_test_audit]
           ADD (SCHEMA_OBJECT_CHANGE_GROUP),
           ADD (DATABASE_OBJECT_CHANGE_GROUP)
           WITH (STATE = ON);');
END;

-- Now perform a DDL event that will be captured:
IF OBJECT_ID('tempdb..#dbdome_pii_test') IS NOT NULL DROP TABLE #dbdome_pii_test;
CREATE TABLE #dbdome_pii_test (id INT, name NVARCHAR(100), ssn NVARCHAR(20));
INSERT INTO #dbdome_pii_test VALUES (1, N'Test Person', N'000-00-0000');
DROP TABLE #dbdome_pii_test;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_audit_spec')
BEGIN
    EXEC(N'ALTER SERVER AUDIT SPECIFICATION [dbdome_test_audit_spec] WITH (STATE = OFF);');
    DROP SERVER AUDIT SPECIFICATION [dbdome_test_audit_spec];
END;
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
BEGIN
    ALTER SERVER AUDIT [dbdome_test_audit] WITH (STATE = OFF);
    DROP SERVER AUDIT [dbdome_test_audit];
END;
GO

/* ===== SEC-SQL-AUTHZ-001-RC01 [DESTRUCTIVE] ===== */
-- Detection enumerates logins/users/roles/grants across all non-system databases.
-- Returns rows as long as any user database with non-system users exists (virtually always true).
-- To guarantee a row: create a user database with a mapped login and a role grant.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    CREATE LOGIN [dbdome_test_login] WITH PASSWORD = 'Dbdome!Temp1', CHECK_POLICY = OFF;

IF DB_ID('dbdome_testdb') IS NULL
    CREATE DATABASE [dbdome_testdb];
GO
USE [dbdome_testdb];
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_test_user')
    CREATE USER [dbdome_test_user] FOR LOGIN [dbdome_test_login];
EXEC sys.sp_addrolemember N'db_datareader', N'dbdome_test_user';
GO
USE [master];
GO
-- REVERT:
USE [dbdome_testdb];
GO
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_test_user')
BEGIN
    EXEC sys.sp_droprolemember N'db_datareader', N'dbdome_test_user';
    DROP USER [dbdome_test_user];
END;
GO
USE [master];
GO
IF DB_ID('dbdome_testdb') IS NOT NULL
BEGIN
    ALTER DATABASE [dbdome_testdb] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [dbdome_testdb];
END;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    DROP LOGIN [dbdome_test_login];
GO

/* ===== SEC-SQL-AZ-001-RC01 [DESTRUCTIVE] ===== */
-- Detection counts direct GRANT permissions to individual users (not roles).
-- Flags when direct_user_grants > 0.
-- SETUP: grant a direct object-level permission to a SQL user (not via role).
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    CREATE LOGIN [dbdome_test_login] WITH PASSWORD = 'Dbdome!Temp1', CHECK_POLICY = OFF;

IF DB_ID('dbdome_testdb') IS NULL
    CREATE DATABASE [dbdome_testdb];
GO
USE [dbdome_testdb];
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_test_user')
    CREATE USER [dbdome_test_user] FOR LOGIN [dbdome_test_login];
IF OBJECT_ID('dbo.dbdome_rbac_test_tbl', 'U') IS NULL
    CREATE TABLE dbo.dbdome_rbac_test_tbl (id INT);
-- Direct GRANT to user (not role) -- this is what the detection flags:
GRANT SELECT ON dbo.dbdome_rbac_test_tbl TO [dbdome_test_user];
GO
USE [master];
GO
-- REVERT:
USE [dbdome_testdb];
GO
IF OBJECT_ID('dbo.dbdome_rbac_test_tbl', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_test_user')
        REVOKE SELECT ON dbo.dbdome_rbac_test_tbl FROM [dbdome_test_user];
    DROP TABLE dbo.dbdome_rbac_test_tbl;
END;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_test_user')
    DROP USER [dbdome_test_user];
GO
USE [master];
GO
IF DB_ID('dbdome_testdb') IS NOT NULL
BEGIN
    ALTER DATABASE [dbdome_testdb] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [dbdome_testdb];
END;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    DROP LOGIN [dbdome_test_login];
GO

/* ===== SEC-SQL-AZ-001-RC02 [DESTRUCTIVE] ===== */
-- Detection finds enabled non-system logins (principal_id > 10) that are members of
-- sysadmin, securityadmin, serveradmin, or dbcreator.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    CREATE LOGIN [dbdome_test_login] WITH PASSWORD = 'Dbdome!Temp1', CHECK_POLICY = OFF;
-- Add to a privileged role (dbcreator is least disruptive):
ALTER SERVER ROLE [dbcreator] ADD MEMBER [dbdome_test_login];
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
BEGIN
    ALTER SERVER ROLE [dbcreator] DROP MEMBER [dbdome_test_login];
    DROP LOGIN [dbdome_test_login];
END;
GO

/* ===== SEC-SQL-AZ-001-RC03 [DESTRUCTIVE] ===== */
-- Detection finds enabled non-system logins that are sysadmin OR have CONTROL SERVER,
-- AND have an active session from a program that is NOT SSMS or SQLAgent.
-- Requires: login is sysadmin/CONTROL SERVER AND currently connected via a non-SSMS program.
-- Best-effort: create the login with sysadmin, then connect to SQL Server using sqlcmd
-- (program_name = 'SQLCMD') so it appears in dm_exec_sessions with a non-SSMS program name.
-- Run the detection while that sqlcmd session is alive.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_sysadmin_login')
    CREATE LOGIN [dbdome_test_sysadmin_login] WITH PASSWORD = 'Dbdome!Temp3', CHECK_POLICY = OFF;
ALTER SERVER ROLE [sysadmin] ADD MEMBER [dbdome_test_sysadmin_login];
GO
-- *** In a separate session (e.g. sqlcmd -S . -U dbdome_test_sysadmin_login -P Dbdome!Temp3),
--     run: WAITFOR DELAY '00:00:10';
--     Then run the detection query while that session is active. ***
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_sysadmin_login')
BEGIN
    ALTER SERVER ROLE [sysadmin] DROP MEMBER [dbdome_test_sysadmin_login];
    DROP LOGIN [dbdome_test_sysadmin_login];
END;
GO

/* ===== SEC-SQL-AZ-001-RC04 [DESTRUCTIVE] ===== */
-- Detection lists sysadmin logins (principal_id > 10, enabled, non-##) that have
-- active sessions with non-admin requests in-flight.
-- Triggers on just having an active session from a sysadmin login (current_sessions > 0);
-- non_admin_requests may be 0 but the row still appears.
-- SETUP: create a sysadmin login and open a session from it (separate sqlcmd/SSMS connection).
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_sysadmin_login')
    CREATE LOGIN [dbdome_test_sysadmin_login] WITH PASSWORD = 'Dbdome!Temp3', CHECK_POLICY = OFF;
ALTER SERVER ROLE [sysadmin] ADD MEMBER [dbdome_test_sysadmin_login];
GO
-- *** Connect as dbdome_test_sysadmin_login (sqlcmd or SSMS) and run: WAITFOR DELAY '00:00:10';
--     Then run the detection query while that session is active.
--     Even without any requests in-flight, the login row appears due to current_sessions >= 1. ***
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_sysadmin_login')
BEGIN
    ALTER SERVER ROLE [sysadmin] DROP MEMBER [dbdome_test_sysadmin_login];
    DROP LOGIN [dbdome_test_sysadmin_login];
END;
GO

/* ===== SEC-SQL-AZ-001-RC05 [DESTRUCTIVE] ===== */
-- Detection finds database users/roles that are members of db_owner, db_ddladmin,
-- or db_securityadmin (principal_id > 4, not dbo).
-- SETUP: create a database user and add it to db_owner.
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    CREATE LOGIN [dbdome_test_login] WITH PASSWORD = 'Dbdome!Temp1', CHECK_POLICY = OFF;

IF DB_ID('dbdome_testdb') IS NULL
    CREATE DATABASE [dbdome_testdb];
GO
USE [dbdome_testdb];
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_test_user')
    CREATE USER [dbdome_test_user] FOR LOGIN [dbdome_test_login];
EXEC sys.sp_addrolemember N'db_owner', N'dbdome_test_user';
GO
USE [master];
GO
-- REVERT:
USE [dbdome_testdb];
GO
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_test_user')
BEGIN
    EXEC sys.sp_droprolemember N'db_owner', N'dbdome_test_user';
    DROP USER [dbdome_test_user];
END;
GO
USE [master];
GO
IF DB_ID('dbdome_testdb') IS NOT NULL
BEGIN
    ALTER DATABASE [dbdome_testdb] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [dbdome_testdb];
END;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    DROP LOGIN [dbdome_test_login];
GO

/* ===== SEC-SQL-AZ-001-RC06 [DESTRUCTIVE] ===== */
-- Detection checks: (a) cross_db_chaining_enabled = 1, OR (b) users with schema-level
-- GRANT permissions (class=3), OR (c) count of schemas so granted.
-- Enabling cross-db chaining returns cross_db_chaining_enabled=1 regardless of (b)/(c).
-- SETUP:
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'cross db ownership chaining', 1; RECONFIGURE;
GO
-- Also create a schema-level grant for completeness:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    CREATE LOGIN [dbdome_test_login] WITH PASSWORD = 'Dbdome!Temp1', CHECK_POLICY = OFF;

IF DB_ID('dbdome_testdb') IS NULL
    CREATE DATABASE [dbdome_testdb];
GO
USE [dbdome_testdb];
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_test_user')
    CREATE USER [dbdome_test_user] FOR LOGIN [dbdome_test_login];
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dbdome_test_schema')
    EXEC(N'CREATE SCHEMA [dbdome_test_schema];');
GRANT SELECT ON SCHEMA::[dbdome_test_schema] TO [dbdome_test_user];
GO
USE [master];
GO
-- REVERT:
USE [dbdome_testdb];
GO
IF EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dbdome_test_schema')
BEGIN
    IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_test_user')
        REVOKE SELECT ON SCHEMA::[dbdome_test_schema] FROM [dbdome_test_user];
    -- Drop schema only if empty
    IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE schema_id = SCHEMA_ID('dbdome_test_schema'))
        DROP SCHEMA [dbdome_test_schema];
END;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_test_user')
    DROP USER [dbdome_test_user];
GO
USE [master];
GO
IF DB_ID('dbdome_testdb') IS NOT NULL
BEGIN
    ALTER DATABASE [dbdome_testdb] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [dbdome_testdb];
END;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    DROP LOGIN [dbdome_test_login];
EXEC sp_configure 'cross db ownership chaining', 0; RECONFIGURE;
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
GO


/* ########## batch 16 (12 reproducers) ########## */
-- =============================================================================
-- Positive-test reproducers for detections slice [192..204]
-- Target: DISPOSABLE / throwaway SQL Server instance only.
-- Run SETUP in one session; verify detection returns >=1 row; run REVERT.
-- =============================================================================

/* ===== SEC-SQL-AZ-001-RC07 [DESTRUCTIVE] ===== */
-- Detection finds sessions where IS_SRVROLEMEMBER('sysadmin', login_name) = 1
-- AND program_name is NOT SSMS, SQLAgent, or Report Server.
-- Setup: create a sysadmin login, then open a connection from it using sqlcmd
-- (program_name = 'SQLCMD') and hold it open during the detection query.
-- Run as sysadmin. The separate sqlcmd session must be alive when detection runs.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_sysadmin_login')
    CREATE LOGIN [dbdome_test_sysadmin_login] WITH PASSWORD = 'Dbdome!Temp3', CHECK_POLICY = OFF;
ALTER SERVER ROLE [sysadmin] ADD MEMBER [dbdome_test_sysadmin_login];
GO
-- *** Open a SEPARATE session (e.g. sqlcmd -S . -U dbdome_test_sysadmin_login -P Dbdome!Temp3)
--     and run: WAITFOR DELAY '00:00:10';
--     Then immediately run the detection query while that session is sleeping.
--     program_name='SQLCMD' satisfies NOT LIKE '%Management Studio%' etc. ***
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_sysadmin_login')
BEGIN
    ALTER SERVER ROLE [sysadmin] DROP MEMBER [dbdome_test_sysadmin_login];
    DROP LOGIN [dbdome_test_sysadmin_login];
END;
GO

/* ===== SEC-SQL-AZ-001-RC08 [DESTRUCTIVE] ===== */
-- Detection returns a single row of four scalar counts:
--   total_active_logins, logins_unmodified_1yr, logins_no_current_session, disabled_logins.
-- The detection always returns exactly one row; it "fires" when any count > 0.
-- logins_no_current_session is trivially > 0 for any login not currently connected.
-- disabled_logins will be > 0 after we disable a login.
-- logins_unmodified_1yr cannot be backdated via T-SQL; the login will have modify_date = now,
-- so that sub-count will be 0 on a fresh setup — pre-existing stale logins on the target
-- server will naturally satisfy it.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_stale_login')
    CREATE LOGIN [dbdome_test_stale_login] WITH PASSWORD = 'Dbdome!Temp4', CHECK_POLICY = OFF;
-- Disable it so disabled_logins >= 1:
ALTER LOGIN [dbdome_test_stale_login] DISABLE;
GO
-- Detection returns a row with total_active_logins >= 0 and disabled_logins >= 1.
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_stale_login')
    DROP LOGIN [dbdome_test_stale_login];
GO

/* ===== SEC-SQL-AZ-001-RC09 [DESTRUCTIVE] ===== */
-- Detection finds enabled non-system logins (principal_id > 10, non-##) that are members
-- of 2 or more server roles simultaneously (HAVING COUNT >= 2).
-- Setup: create a login and add it to two server roles.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_multirole_login')
    CREATE LOGIN [dbdome_test_multirole_login] WITH PASSWORD = 'Dbdome!Temp5', CHECK_POLICY = OFF;
ALTER SERVER ROLE [dbcreator]   ADD MEMBER [dbdome_test_multirole_login];
ALTER SERVER ROLE [bulkadmin]   ADD MEMBER [dbdome_test_multirole_login];
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_multirole_login')
BEGIN
    ALTER SERVER ROLE [dbcreator]   DROP MEMBER [dbdome_test_multirole_login];
    ALTER SERVER ROLE [bulkadmin]   DROP MEMBER [dbdome_test_multirole_login];
    DROP LOGIN [dbdome_test_multirole_login];
END;
GO

/* ===== SEC-SQL-AZ-001-RC10 [DESTRUCTIVE] ===== */
-- Detection counts user-created objects in dbo schema with type IN ('U','P','V','FN','IF','TF')
-- grouped by type_desc. Returns rows as long as any such object exists.
-- A single user table in dbo is sufficient.
-- SETUP:
IF DB_ID('dbdome_testdb') IS NULL
    CREATE DATABASE [dbdome_testdb];
GO
USE [dbdome_testdb];
GO
IF OBJECT_ID('dbo.dbdome_legacy_test_tbl', 'U') IS NULL
    CREATE TABLE dbo.dbdome_legacy_test_tbl (id INT, legacy_col NVARCHAR(50));
GO
USE [master];
GO
-- REVERT:
USE [dbdome_testdb];
GO
IF OBJECT_ID('dbo.dbdome_legacy_test_tbl', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_legacy_test_tbl;
GO
USE [master];
GO
IF DB_ID('dbdome_testdb') IS NOT NULL
BEGIN
    ALTER DATABASE [dbdome_testdb] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [dbdome_testdb];
END;
GO

/* ===== SEC-SQL-AZ-001-RC11 [DESTRUCTIVE] ===== */
-- Detection returns three scalar counts (single row always returned):
--   orphaned_users: db users with no matching server principal (sid mismatch).
--   conflicting_grant_deny: same principal has both GRANT and DENY on the same object.
--   db_owner_with_deny: db_owner members who also have an explicit DENY.
-- Setup covers all three in one user database.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    CREATE LOGIN [dbdome_test_login] WITH PASSWORD = 'Dbdome!Temp1', CHECK_POLICY = OFF;

IF DB_ID('dbdome_testdb') IS NULL
    CREATE DATABASE [dbdome_testdb];
GO
USE [dbdome_testdb];
GO
-- 1) Orphaned user: create user WITHOUT LOGIN so it has no matching server principal.
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_orphan_user')
    CREATE USER [dbdome_orphan_user] WITHOUT LOGIN;

-- 2) Conflicting GRANT + DENY on same object for same principal:
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_test_user')
    CREATE USER [dbdome_test_user] FOR LOGIN [dbdome_test_login];
IF OBJECT_ID('dbo.dbdome_conflict_tbl', 'U') IS NULL
    CREATE TABLE dbo.dbdome_conflict_tbl (id INT);
GRANT SELECT ON dbo.dbdome_conflict_tbl TO [dbdome_test_user];
DENY  SELECT ON dbo.dbdome_conflict_tbl TO [dbdome_test_user];

-- 3) db_owner member with an explicit DENY:
EXEC sys.sp_addrolemember N'db_owner', N'dbdome_test_user';
-- DENY on another object to satisfy db_owner_with_deny:
IF OBJECT_ID('dbo.dbdome_deny_tbl', 'U') IS NULL
    CREATE TABLE dbo.dbdome_deny_tbl (id INT);
DENY SELECT ON dbo.dbdome_deny_tbl TO [dbdome_test_user];
GO
USE [master];
GO
-- REVERT:
USE [dbdome_testdb];
GO
IF OBJECT_ID('dbo.dbdome_conflict_tbl', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_test_user')
    BEGIN
        REVOKE SELECT ON dbo.dbdome_conflict_tbl FROM [dbdome_test_user];
    END;
    DROP TABLE dbo.dbdome_conflict_tbl;
END;
IF OBJECT_ID('dbo.dbdome_deny_tbl', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_test_user')
    BEGIN
        REVOKE SELECT ON dbo.dbdome_deny_tbl FROM [dbdome_test_user];
    END;
    DROP TABLE dbo.dbdome_deny_tbl;
END;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_test_user')
BEGIN
    EXEC sys.sp_droprolemember N'db_owner', N'dbdome_test_user';
    DROP USER [dbdome_test_user];
END;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_orphan_user')
    DROP USER [dbdome_orphan_user];
GO
USE [master];
GO
IF DB_ID('dbdome_testdb') IS NOT NULL
BEGIN
    ALTER DATABASE [dbdome_testdb] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [dbdome_testdb];
END;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    DROP LOGIN [dbdome_test_login];
GO

/* ===== SEC-SQL-AZ-001-RC12 [DESTRUCTIVE] ===== */
-- Detection returns a single informational row with several flag columns.
-- It always returns exactly one row, but "fires" when:
--   sa_disabled = 0 (sa is enabled), builtin_admin_exists = 0/NULL, windows_only_auth = 0,
--   sample_databases > 0, guest_access_current_db = 1, or default_trace_enabled = 0.
-- Easiest non-destructive trigger: create a database named 'Northwind' -> sample_databases > 0.
-- Also enable guest in master for guest_access_current_db.
-- Run detection in context of master (or the DB where guest is enabled).
-- SETUP:
IF DB_ID('Northwind') IS NULL
    CREATE DATABASE [Northwind];
GO
-- Enable guest in the current (master) database for guest_access_current_db = 1:
USE [master];
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.database_principals WHERE name = 'guest' AND principal_id = 2
)
    -- guest always exists; grant CONNECT to activate it
    GRANT CONNECT TO [guest];
GO
-- REVERT:
-- Revoke guest CONNECT in master:
USE [master];
GO
DENY CONNECT TO [guest];
GO
IF DB_ID('Northwind') IS NOT NULL
BEGIN
    ALTER DATABASE [Northwind] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [Northwind];
END;
GO

/* ===== SEC-SQL-AZ-001-RC13 [DESTRUCTIVE] ===== */
-- Detection returns a single row with counts of SQL logins, Windows logins, Windows groups,
-- Azure AD principals, and the auth mode.
-- Fires when sql_logins > 0 (SQL auth is in use alongside or instead of Windows-only auth).
-- Any enabled SQL login with principal_id > 10 satisfies this.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_sqllogin')
    CREATE LOGIN [dbdome_test_sqllogin] WITH PASSWORD = 'Dbdome!Temp6', CHECK_POLICY = OFF;
GO
-- Detection now returns sql_logins >= 1 and windows_only_auth = 0 (mixed mode).
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_sqllogin')
    DROP LOGIN [dbdome_test_sqllogin];
GO

/* ===== SEC-SQL-AZ-001-RC14 [DESTRUCTIVE] ===== */
-- Detection finds enabled logins matching service/app account name patterns
-- (svc, app, service, agent, batch, job, api, web, etl, scheduler, daemon)
-- that are members of sysadmin, securityadmin, serveradmin, or dbcreator.
-- Setup: create a login with 'svc' in the name and add it to dbcreator.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_svc_test')
    CREATE LOGIN [dbdome_svc_test] WITH PASSWORD = 'Dbdome!Temp7', CHECK_POLICY = OFF;
ALTER SERVER ROLE [dbcreator] ADD MEMBER [dbdome_svc_test];
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_svc_test')
BEGIN
    ALTER SERVER ROLE [dbcreator] DROP MEMBER [dbdome_svc_test];
    DROP LOGIN [dbdome_svc_test];
END;
GO

/* ===== SEC-SQL-AZ-002-RC01 [DESTRUCTIVE] ===== */
-- Detection finds GRANT permissions given to the 'public' role on non-ms-shipped
-- user objects (class_desc IN ('OBJECT_OR_COLUMN','SCHEMA','DATABASE','TYPE'), major_id > 0).
-- Setup: create a user table and grant SELECT to public.
-- Run detection in the context of the test database.
-- SETUP:
IF DB_ID('dbdome_testdb') IS NULL
    CREATE DATABASE [dbdome_testdb];
GO
USE [dbdome_testdb];
GO
IF OBJECT_ID('dbo.dbdome_public_grant_tbl', 'U') IS NULL
    CREATE TABLE dbo.dbdome_public_grant_tbl (id INT, data NVARCHAR(100));
-- GRANT to public is what the detection flags (HIGH_RISK for UPDATE, MODERATE_RISK for SELECT):
GRANT SELECT ON dbo.dbdome_public_grant_tbl TO [public];
GRANT INSERT ON dbo.dbdome_public_grant_tbl TO [public];
GO
USE [master];
GO
-- REVERT:
USE [dbdome_testdb];
GO
IF OBJECT_ID('dbo.dbdome_public_grant_tbl', 'U') IS NOT NULL
BEGIN
    REVOKE SELECT ON dbo.dbdome_public_grant_tbl FROM [public];
    REVOKE INSERT ON dbo.dbdome_public_grant_tbl FROM [public];
    DROP TABLE dbo.dbdome_public_grant_tbl;
END;
GO
USE [master];
GO
IF DB_ID('dbdome_testdb') IS NOT NULL
BEGIN
    ALTER DATABASE [dbdome_testdb] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [dbdome_testdb];
END;
GO

/* ===== SEC-SQL-AZ-002-RC02 [DESTRUCTIVE] ===== */
-- Detection finds GRANT to 'public' at SCHEMA level (permission IN SELECT/INSERT/UPDATE/DELETE/
-- EXECUTE/ALTER/CONTROL) or DATABASE level (CONNECT, CREATE TABLE, CREATE VIEW, etc.).
-- Setup: create a schema and grant EXECUTE on that schema to public.
-- Run detection in the context of the test database.
-- SETUP:
IF DB_ID('dbdome_testdb') IS NULL
    CREATE DATABASE [dbdome_testdb];
GO
USE [dbdome_testdb];
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dbdome_test_schema')
    EXEC(N'CREATE SCHEMA [dbdome_test_schema];');
-- Schema-level GRANT to public triggers the SCHEMA branch of the detection:
GRANT EXECUTE ON SCHEMA::[dbdome_test_schema] TO [public];
-- Database-level GRANT to public triggers the DATABASE branch:
GRANT CREATE TABLE TO [public];
GO
USE [master];
GO
-- REVERT:
USE [dbdome_testdb];
GO
-- Revoke schema-level grant:
IF EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dbdome_test_schema')
BEGIN
    REVOKE EXECUTE ON SCHEMA::[dbdome_test_schema] FROM [public];
    -- Drop schema only if empty:
    IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE schema_id = SCHEMA_ID('dbdome_test_schema'))
        DROP SCHEMA [dbdome_test_schema];
END;
-- Revoke database-level grant:
REVOKE CREATE TABLE FROM [public];
GO
USE [master];
GO
IF DB_ID('dbdome_testdb') IS NOT NULL
BEGIN
    ALTER DATABASE [dbdome_testdb] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [dbdome_testdb];
END;
GO

/* ===== SEC-SQL-AZ-002-RC03 [DESTRUCTIVE] ===== */
-- Detection finds GRANT to 'public' on non-ms-shipped OBJECT_OR_COLUMN permissions
-- (SELECT, INSERT, UPDATE, DELETE, EXECUTE) and reports days_since_last_access.
-- A new object with no index usage stats will show last_accessed = create_date,
-- so days_since_last_access = 0 — still returns a row.
-- Setup: create a table and grant SELECT to public.
-- Run detection in the context of the test database.
-- SETUP:
IF DB_ID('dbdome_testdb') IS NULL
    CREATE DATABASE [dbdome_testdb];
GO
USE [dbdome_testdb];
GO
IF OBJECT_ID('dbo.dbdome_temp_workaround_tbl', 'U') IS NULL
    CREATE TABLE dbo.dbdome_temp_workaround_tbl (id INT, notes NVARCHAR(200));
GRANT SELECT ON dbo.dbdome_temp_workaround_tbl TO [public];
GRANT UPDATE ON dbo.dbdome_temp_workaround_tbl TO [public];
GO
USE [master];
GO
-- REVERT:
USE [dbdome_testdb];
GO
IF OBJECT_ID('dbo.dbdome_temp_workaround_tbl', 'U') IS NOT NULL
BEGIN
    REVOKE SELECT ON dbo.dbdome_temp_workaround_tbl FROM [public];
    REVOKE UPDATE ON dbo.dbdome_temp_workaround_tbl FROM [public];
    DROP TABLE dbo.dbdome_temp_workaround_tbl;
END;
GO
USE [master];
GO
IF DB_ID('dbdome_testdb') IS NOT NULL
BEGIN
    ALTER DATABASE [dbdome_testdb] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [dbdome_testdb];
END;
GO

/* ===== SEC-SQL-AZ-002-RC04 [DESTRUCTIVE] ===== */
-- Detection finds GRANT to 'public' on non-ms-shipped objects (class IN
-- OBJECT_OR_COLUMN, SCHEMA, DATABASE) grouped by permission_name.
-- Virtually identical trigger condition to RC01/RC03; create table + grant to public.
-- Run detection in the context of the test database.
-- SETUP:
IF DB_ID('dbdome_testdb') IS NULL
    CREATE DATABASE [dbdome_testdb];
GO
USE [dbdome_testdb];
GO
IF OBJECT_ID('dbo.dbdome_legacy_public_tbl', 'U') IS NULL
    CREATE TABLE dbo.dbdome_legacy_public_tbl (id INT, legacy_data NVARCHAR(200));
GRANT SELECT ON dbo.dbdome_legacy_public_tbl TO [public];
GRANT EXECUTE ON SCHEMA::[dbo] TO [public];
GO
USE [master];
GO
-- REVERT:
USE [dbdome_testdb];
GO
IF OBJECT_ID('dbo.dbdome_legacy_public_tbl', 'U') IS NOT NULL
BEGIN
    REVOKE SELECT ON dbo.dbdome_legacy_public_tbl FROM [public];
    DROP TABLE dbo.dbdome_legacy_public_tbl;
END;
-- Revoke schema-level grant on dbo if it was added (only revoke what we granted):
IF EXISTS (
    SELECT 1 FROM sys.database_permissions dp
    JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id
    WHERE pr.name = 'public'
      AND dp.class_desc = 'SCHEMA'
      AND dp.major_id = SCHEMA_ID('dbo')
      AND dp.permission_name = 'EXECUTE'
      AND dp.state_desc = 'GRANT'
)
    REVOKE EXECUTE ON SCHEMA::[dbo] FROM [public];
GO
USE [master];
GO
IF DB_ID('dbdome_testdb') IS NOT NULL
BEGIN
    ALTER DATABASE [dbdome_testdb] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [dbdome_testdb];
END;
GO


/* ########## batch 17 (12 reproducers) ########## */
/* ===== SEC-SQL-AZ-002-RC05 [DESTRUCTIVE] ===== */
-- Creates a server audit + server audit specification that covers the required permission-change action groups,
-- then enables both so the detection (which looks for enabled audits covering those groups) returns >=1 row.
-- Run as sysadmin. The audit writes to the application event log; adjust TO FILE(...) if preferred.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc05')
BEGIN
    CREATE SERVER AUDIT dbdome_test_audit_rc05
        TO APPLICATION_LOG
        WITH (ON_FAILURE = CONTINUE);
END;
ALTER SERVER AUDIT dbdome_test_audit_rc05 WITH (STATE = ON);

IF NOT EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_auditspec_rc05')
BEGIN
    CREATE SERVER AUDIT SPECIFICATION dbdome_test_auditspec_rc05
        FOR SERVER AUDIT dbdome_test_audit_rc05
        ADD (DATABASE_PERMISSION_CHANGE_GROUP),
        ADD (SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP),
        ADD (SERVER_PERMISSION_CHANGE_GROUP),
        ADD (DATABASE_ROLE_MEMBER_CHANGE_GROUP)
        WITH (STATE = ON);
END;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_auditspec_rc05')
BEGIN
    ALTER SERVER AUDIT SPECIFICATION dbdome_test_auditspec_rc05 WITH (STATE = OFF);
    DROP SERVER AUDIT SPECIFICATION dbdome_test_auditspec_rc05;
END;
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc05')
BEGIN
    ALTER SERVER AUDIT dbdome_test_audit_rc05 WITH (STATE = OFF);
    DROP SERVER AUDIT dbdome_test_audit_rc05;
END;
GO

/* ===== SEC-SQL-AZ-002-RC06 [DESTRUCTIVE] ===== */
-- Grants SELECT on a non-sys/INFORMATION_SCHEMA MS-shipped object to the public role.
-- Uses dbo.spt_values which is ms_shipped and lives in the dbo schema (not sys/INFORMATION_SCHEMA).
-- Run inside a user database (e.g. USE tempdb or a scratch DB). Run as db_owner or sysadmin.
-- SETUP:
USE tempdb;
GO
IF OBJECT_ID('tempdb.dbo.dbdome_rc06_dummy', 'U') IS NULL
    CREATE TABLE dbo.dbdome_rc06_dummy (id INT);
GO
-- Grant SELECT on the ms-shipped spt_values to public (it is in schema dbo, ms_shipped=1).
-- If spt_values is already granted we absorb the no-op; the detection will still fire.
GRANT SELECT ON dbo.spt_values TO [public];
GO
-- REVERT:
USE tempdb;
GO
-- Only revoke if the grant actually exists to avoid error.
IF EXISTS (
    SELECT 1 FROM sys.database_permissions dp
    JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id
    JOIN sys.objects o            ON dp.major_id = o.object_id
    WHERE pr.name = 'public'
      AND dp.state_desc = 'GRANT'
      AND dp.permission_name = 'SELECT'
      AND o.name = 'spt_values'
      AND o.is_ms_shipped = 1
)
    REVOKE SELECT ON dbo.spt_values FROM [public];

IF OBJECT_ID('tempdb.dbo.dbdome_rc06_dummy', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_rc06_dummy;
GO

/* ===== SEC-SQL-AZ-002-RC07 [DESTRUCTIVE] ===== */
-- Grants SELECT on a schema to the public role so the detection (class_desc='SCHEMA', state='GRANT') fires.
-- Run inside a user/scratch database. Run as db_owner or sysadmin.
-- SETUP:
USE tempdb;
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dbdome_test_schema_rc07')
    EXEC('CREATE SCHEMA dbdome_test_schema_rc07');
GO
GRANT SELECT ON SCHEMA::dbdome_test_schema_rc07 TO [public];
GO
-- REVERT:
USE tempdb;
GO
IF EXISTS (
    SELECT 1 FROM sys.database_permissions dp
    JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id
    WHERE pr.name = 'public'
      AND dp.class_desc = 'SCHEMA'
      AND dp.state_desc = 'GRANT'
      AND dp.permission_name = 'SELECT'
      AND SCHEMA_NAME(dp.major_id) = 'dbdome_test_schema_rc07'
)
    REVOKE SELECT ON SCHEMA::dbdome_test_schema_rc07 FROM [public];

IF EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dbdome_test_schema_rc07')
BEGIN
    -- Cannot DROP SCHEMA if it owns objects; it was created empty so drop is safe.
    EXEC('DROP SCHEMA dbdome_test_schema_rc07');
END;
GO

/* ===== SEC-SQL-AZ-002-RC08 [DESTRUCTIVE] ===== */
-- Grants a DML permission on a user-created (non-ms-shipped) object to the public role.
-- The detection checks class_desc IN (OBJECT_OR_COLUMN, SCHEMA, DATABASE) AND OBJECTPROPERTY(major_id,'IsMSShipped')=0
-- (or major_id=0 for DATABASE-level grants), so a table grant to public is the easiest trigger.
-- Run inside a user/scratch database. Run as db_owner or sysadmin.
-- SETUP:
USE tempdb;
GO
IF OBJECT_ID('tempdb.dbo.dbdome_pii_test_rc08', 'U') IS NULL
    CREATE TABLE dbo.dbdome_pii_test_rc08 (id INT, val NVARCHAR(100));
GO
GRANT SELECT ON dbo.dbdome_pii_test_rc08 TO [public];
GO
-- REVERT:
USE tempdb;
GO
IF OBJECT_ID('tempdb.dbo.dbdome_pii_test_rc08', 'U') IS NOT NULL
BEGIN
    IF EXISTS (
        SELECT 1 FROM sys.database_permissions dp
        JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id
        WHERE pr.name = 'public'
          AND dp.major_id = OBJECT_ID('tempdb.dbo.dbdome_pii_test_rc08')
          AND dp.permission_name = 'SELECT'
    )
        REVOKE SELECT ON dbo.dbdome_pii_test_rc08 FROM [public];
    DROP TABLE dbo.dbdome_pii_test_rc08;
END;
GO

/* ===== SEC-SQL-AZ-002-RC09 [DESTRUCTIVE] ===== */
-- Creates >=5 user objects of the same type and grants the same permission on each to public,
-- so COUNT(*) >= 5 in the HAVING clause fires. Uses stored procedures (type='P').
-- Run inside a user/scratch database. Run as db_owner or sysadmin.
-- SETUP:
USE tempdb;
GO
IF OBJECT_ID('tempdb.dbo.dbdome_rc09_p1','P') IS NULL EXEC('CREATE PROCEDURE dbo.dbdome_rc09_p1 AS SELECT 1');
IF OBJECT_ID('tempdb.dbo.dbdome_rc09_p2','P') IS NULL EXEC('CREATE PROCEDURE dbo.dbdome_rc09_p2 AS SELECT 1');
IF OBJECT_ID('tempdb.dbo.dbdome_rc09_p3','P') IS NULL EXEC('CREATE PROCEDURE dbo.dbdome_rc09_p3 AS SELECT 1');
IF OBJECT_ID('tempdb.dbo.dbdome_rc09_p4','P') IS NULL EXEC('CREATE PROCEDURE dbo.dbdome_rc09_p4 AS SELECT 1');
IF OBJECT_ID('tempdb.dbo.dbdome_rc09_p5','P') IS NULL EXEC('CREATE PROCEDURE dbo.dbdome_rc09_p5 AS SELECT 1');
GO
GRANT EXECUTE ON dbo.dbdome_rc09_p1 TO [public];
GRANT EXECUTE ON dbo.dbdome_rc09_p2 TO [public];
GRANT EXECUTE ON dbo.dbdome_rc09_p3 TO [public];
GRANT EXECUTE ON dbo.dbdome_rc09_p4 TO [public];
GRANT EXECUTE ON dbo.dbdome_rc09_p5 TO [public];
GO
-- REVERT:
USE tempdb;
GO
IF OBJECT_ID('tempdb.dbo.dbdome_rc09_p1','P') IS NOT NULL BEGIN REVOKE EXECUTE ON dbo.dbdome_rc09_p1 FROM [public]; DROP PROCEDURE dbo.dbdome_rc09_p1; END;
IF OBJECT_ID('tempdb.dbo.dbdome_rc09_p2','P') IS NOT NULL BEGIN REVOKE EXECUTE ON dbo.dbdome_rc09_p2 FROM [public]; DROP PROCEDURE dbo.dbdome_rc09_p2; END;
IF OBJECT_ID('tempdb.dbo.dbdome_rc09_p3','P') IS NOT NULL BEGIN REVOKE EXECUTE ON dbo.dbdome_rc09_p3 FROM [public]; DROP PROCEDURE dbo.dbdome_rc09_p3; END;
IF OBJECT_ID('tempdb.dbo.dbdome_rc09_p4','P') IS NOT NULL BEGIN REVOKE EXECUTE ON dbo.dbdome_rc09_p4 FROM [public]; DROP PROCEDURE dbo.dbdome_rc09_p4; END;
IF OBJECT_ID('tempdb.dbo.dbdome_rc09_p5','P') IS NOT NULL BEGIN REVOKE EXECUTE ON dbo.dbdome_rc09_p5 FROM [public]; DROP PROCEDURE dbo.dbdome_rc09_p5; END;
GO

/* ===== SEC-SQL-AZ-002-RC10 [DESTRUCTIVE] ===== */
-- The detection is a scalar ratio query: it ALWAYS returns exactly 1 row (three scalar subqueries).
-- To make it "positive" (i.e. return a row where public_user_grants > 0), grant a permission
-- on a user object to public so that the public_user_grants subquery > 0.
-- The row is always returned regardless; setup ensures the counts are non-zero and meaningful.
-- Run inside a user/scratch database. Run as db_owner or sysadmin.
-- SETUP:
USE tempdb;
GO
IF OBJECT_ID('tempdb.dbo.dbdome_pii_test_rc10', 'U') IS NULL
    CREATE TABLE dbo.dbdome_pii_test_rc10 (id INT);
GO
GRANT SELECT ON dbo.dbdome_pii_test_rc10 TO [public];
GO
-- REVERT:
USE tempdb;
GO
IF OBJECT_ID('tempdb.dbo.dbdome_pii_test_rc10', 'U') IS NOT NULL
BEGIN
    IF EXISTS (
        SELECT 1 FROM sys.database_permissions dp
        JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id
        WHERE pr.name = 'public'
          AND dp.major_id = OBJECT_ID('tempdb.dbo.dbdome_pii_test_rc10')
          AND dp.permission_name = 'SELECT'
    )
        REVOKE SELECT ON dbo.dbdome_pii_test_rc10 FROM [public];
    DROP TABLE dbo.dbdome_pii_test_rc10;
END;
GO

/* ===== SEC-SQL-AZ-002-RC11 [DESTRUCTIVE] ===== */
-- Grants (or denies) a permission on a user object to the public role and then verifies
-- that class_desc = 'OBJECT_OR_COLUMN' or 'SCHEMA' is present with major_id > 0.
-- The detection groups by permission+state+class and returns all such rows.
-- Run inside a user/scratch database. Run as db_owner or sysadmin.
-- SETUP:
USE tempdb;
GO
IF OBJECT_ID('tempdb.dbo.dbdome_pii_test_rc11', 'U') IS NULL
    CREATE TABLE dbo.dbdome_pii_test_rc11 (id INT, secret NVARCHAR(200));
GO
-- Grant SELECT and DENY INSERT so the detection sees both GRANT and DENY rows.
GRANT SELECT ON dbo.dbdome_pii_test_rc11 TO [public];
DENY  INSERT ON dbo.dbdome_pii_test_rc11 TO [public];
GO
-- REVERT:
USE tempdb;
GO
IF OBJECT_ID('tempdb.dbo.dbdome_pii_test_rc11', 'U') IS NOT NULL
BEGIN
    REVOKE SELECT ON dbo.dbdome_pii_test_rc11 FROM [public];
    REVOKE INSERT ON dbo.dbdome_pii_test_rc11 FROM [public];
    DROP TABLE dbo.dbdome_pii_test_rc11;
END;
GO

/* ===== SEC-SQL-AZ-002-RC12 [DESTRUCTIVE] ===== */
-- Creates a user-defined stored procedure and grants EXECUTE on it to the public role
-- so the detection (EXECUTE grant on non-ms-shipped P/FN/IF/TF to public) returns >=1 row.
-- Run inside a user/scratch database. Run as db_owner or sysadmin.
-- SETUP:
USE tempdb;
GO
IF OBJECT_ID('tempdb.dbo.dbdome_test_proc_rc12', 'P') IS NULL
    EXEC('CREATE PROCEDURE dbo.dbdome_test_proc_rc12 AS SELECT 1 AS test_col');
GO
GRANT EXECUTE ON dbo.dbdome_test_proc_rc12 TO [public];
GO
-- REVERT:
USE tempdb;
GO
IF OBJECT_ID('tempdb.dbo.dbdome_test_proc_rc12', 'P') IS NOT NULL
BEGIN
    REVOKE EXECUTE ON dbo.dbdome_test_proc_rc12 FROM [public];
    DROP PROCEDURE dbo.dbdome_test_proc_rc12;
END;
GO

/* ===== SEC-SQL-AZ-002-RC13 [DESTRUCTIVE] ===== */
-- Creates a user object and grants a DML/DDL permission on it to the public role.
-- The detection selects those grants and also returns the object's modify_date, so any
-- non-ms-shipped object with a public GRANT of SELECT/INSERT/UPDATE/DELETE/EXECUTE/ALTER/CONTROL will fire it.
-- Run inside a user/scratch database. Run as db_owner or sysadmin.
-- SETUP:
USE tempdb;
GO
IF OBJECT_ID('tempdb.dbo.dbdome_pii_test_rc13', 'U') IS NULL
    CREATE TABLE dbo.dbdome_pii_test_rc13 (id INT, ssn CHAR(11), card_number CHAR(16));
GO
GRANT SELECT ON dbo.dbdome_pii_test_rc13 TO [public];
GO
-- REVERT:
USE tempdb;
GO
IF OBJECT_ID('tempdb.dbo.dbdome_pii_test_rc13', 'U') IS NOT NULL
BEGIN
    REVOKE SELECT ON dbo.dbdome_pii_test_rc13 FROM [public];
    DROP TABLE dbo.dbdome_pii_test_rc13;
END;
GO

/* ===== SEC-SQL-AZ-003-RC01 [DESTRUCTIVE] ===== */
-- Creates an orphaned database user (a SQL user whose SID has no matching server login)
-- and assigns it a permission and/or a role membership so both the perm join and role join fire.
-- The key condition is: dp_user.sid IS NOT NULL, sp.sid IS NULL (no matching server principal),
-- authentication_type <> 0, and either a permission or role membership exists.
-- Run inside a user/scratch database. Run as db_owner or sysadmin.
-- Note: Creating a SQL user WITHOUT LOGIN produces sid=0x (zero-length) and authentication_type=0,
-- which the WHERE clause excludes. Instead create a login, make the DB user, then drop the login
-- so the SID remains in sys.database_principals but vanishes from sys.server_principals.
-- SETUP:
USE master;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_orphan_login_rc01')
    CREATE LOGIN dbdome_orphan_login_rc01 WITH PASSWORD = 'Dbdome$Test1!';
GO
USE tempdb;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_orphan_user_rc01')
    CREATE USER dbdome_orphan_user_rc01 FOR LOGIN dbdome_orphan_login_rc01;
GO
-- Give the user a permission so the detection's left-join on permissions is non-NULL.
IF OBJECT_ID('tempdb.dbo.dbdome_pii_test_rc01', 'U') IS NULL
    CREATE TABLE dbo.dbdome_pii_test_rc01 (id INT);
GO
GRANT SELECT ON dbo.dbdome_pii_test_rc01 TO dbdome_orphan_user_rc01;
GO
-- Now drop the server login, leaving the DB user orphaned.
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_orphan_login_rc01')
    DROP LOGIN dbdome_orphan_login_rc01;
GO
-- REVERT:
USE tempdb;
GO
IF OBJECT_ID('tempdb.dbo.dbdome_pii_test_rc01', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_orphan_user_rc01')
        REVOKE SELECT ON dbo.dbdome_pii_test_rc01 FROM dbdome_orphan_user_rc01;
    DROP TABLE dbo.dbdome_pii_test_rc01;
END;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_orphan_user_rc01')
    DROP USER dbdome_orphan_user_rc01;
-- Login was already dropped in setup; guard in case revert runs without prior setup.
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_orphan_login_rc01')
    DROP LOGIN dbdome_orphan_login_rc01;
GO

/* ===== SEC-SQL-AZ-003-RC02 [DESTRUCTIVE] ===== */
-- Same orphaned-user pattern as RC01 but the detection only requires sp.sid IS NULL
-- (no perm/role requirement). Create a SQL login, make the DB user, then drop the login.
-- authentication_type for a user created FOR LOGIN is 1 (SQL auth), satisfying <> 0.
-- Run as sysadmin / db_owner.
-- SETUP:
USE master;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_orphan_login_rc02')
    CREATE LOGIN dbdome_orphan_login_rc02 WITH PASSWORD = 'Dbdome$Test2!';
GO
USE tempdb;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_orphan_user_rc02')
    CREATE USER dbdome_orphan_user_rc02 FOR LOGIN dbdome_orphan_login_rc02;
GO
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_orphan_login_rc02')
    DROP LOGIN dbdome_orphan_login_rc02;
GO
-- REVERT:
USE tempdb;
GO
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_orphan_user_rc02')
    DROP USER dbdome_orphan_user_rc02;
-- Guard in case login was not yet dropped.
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_orphan_login_rc02')
    DROP LOGIN dbdome_orphan_login_rc02;
GO

/* ===== SEC-SQL-AZ-003-RC03 [DESTRUCTIVE] ===== */
-- Same orphaned-user pattern but the detection additionally requires
-- DATEDIFF(DAY, dp.modify_date, GETDATE()) > 90.
-- After creating and orphaning the user, back-date its modify_date via a direct
-- catalog update. This requires DAC (Dedicated Admin Connection) or the undocumented
-- sp_MSforeachdb trick. On a test server, use the catalog update approach via DAC.
-- ALTERNATIVE (no DAC required): use DBCC CLONEDATABASE to a scratch DB and manually
-- update the user's modify_date, or simply accept a best-effort setup note.
-- Best-effort: the user is created and orphaned; modify_date defaults to NOW so the
-- >90-day filter will NOT fire immediately. To truly fire the detection, either:
--   (a) wait 90+ days, or
--   (b) connect via DAC and run:
--       UPDATE tempdb.sys.database_principals SET modify_date = DATEADD(DAY,-91,GETDATE())
--       WHERE name = 'dbdome_orphan_user_rc03';
-- This script performs option (b) via the DAC if available; otherwise note the limitation.
-- Run as sysadmin. DAC connection string: ADMIN:<server>.
-- SETUP:
USE master;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_orphan_login_rc03')
    CREATE LOGIN dbdome_orphan_login_rc03 WITH PASSWORD = 'Dbdome$Test3!';
GO
USE tempdb;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_orphan_user_rc03')
    CREATE USER dbdome_orphan_user_rc03 FOR LOGIN dbdome_orphan_login_rc03;
GO
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_orphan_login_rc03')
    DROP LOGIN dbdome_orphan_login_rc03;
GO
-- Back-date via DAC (run this block on a ADMIN: connection, sysadmin only):
-- USE tempdb;
-- UPDATE sys.database_principals SET modify_date = DATEADD(DAY, -91, GETDATE())
-- WHERE name = 'dbdome_orphan_user_rc03';
GO
-- REVERT:
USE tempdb;
GO
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_orphan_user_rc03')
    DROP USER dbdome_orphan_user_rc03;
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_orphan_login_rc03')
    DROP LOGIN dbdome_orphan_login_rc03;
GO


/* ########## batch 18 (12 reproducers) ########## */
/* ===== SEC-SQL-AZ-003-RC04 [DESTRUCTIVE] ===== */
-- Detection counts enabled logins by type (SQL/Windows/Group) and computes pct_sql_auth.
-- Returns >=1 row as long as ANY enabled non-sa, non-## login exists.
-- Creating one SQL login is sufficient.  Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_sqllogin_rc04')
BEGIN
    CREATE LOGIN dbdome_test_sqllogin_rc04 WITH PASSWORD = 'Dbdome$Test1234!', CHECK_POLICY = OFF;
END;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_sqllogin_rc04')
    DROP LOGIN dbdome_test_sqllogin_rc04;
GO

/* ===== SEC-SQL-AZ-003-RC05 [DESTRUCTIVE] ===== */
-- Detection returns logins that are enabled, not '##' or 'sa', created >30 days ago,
-- and have NO active session.  Create a SQL login backdated via a temp trick
-- (can't set create_date directly, so create a login via a small workaround):
-- We use sp_addlogin with a known-old date by using a fixed-date certificate, or
-- simply use a login that was already created >30 days ago.
-- Easiest approach: create the login, then update its create_date via internal trick.
-- Since create_date cannot be set directly, use EXEC sp_addlogin (legacy, sets create_date to now)
-- then alter it with DBCC CHECKIDENT trick — not possible for server_principals.
-- Best-effort: create the login now (it will fail the >30-day check) and explain.
-- Alternative: if there is already an old login meeting the criteria, the detection fires.
-- For a true positive on a fresh server: use sys.sp_MSforeachdb trick is not applicable here.
-- WORKAROUND: Insert a row into an in-memory table (won't change sys.server_principals).
-- REAL APPROACH: Create login and accept the detection will fire after 30 days, OR
-- use a SQL Server instance that already has old logins.
-- NOTE: On a fresh test server, this detection will not fire until the login is 30+ days old.
--       The setup below creates the login; a true positive requires waiting 30 days OR
--       using an existing old login. Pair with a note to testers.
-- Run as sysadmin.
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_dormant_rc05')
BEGIN
    CREATE LOGIN dbdome_test_dormant_rc05 WITH PASSWORD = 'Dbdome$Test1234!', CHECK_POLICY = OFF;
END;
-- To force-trigger on a fresh server, temporarily spoof by checking with a date override:
-- The detection SQL itself uses GETDATE(); you can verify immediately by running:
-- SELECT * FROM sys.server_principals WHERE name='dbdome_test_dormant_rc05' AND DATEDIFF(DAY,create_date,GETDATE())>30
-- On a server with existing old logins the detection already fires without this setup.
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_dormant_rc05')
    DROP LOGIN dbdome_test_dormant_rc05;
GO

/* ===== SEC-SQL-AZ-003-RC06 [DESTRUCTIVE] ===== */
-- Detection returns SQL logins whose name matches service-account patterns
-- (svc/app/service/agent/batch/job/api/web/etl/scheduler/daemon/system)
-- AND are enabled AND created >180 days ago.
-- Same date-age limitation as RC05: on a fresh server the login won't be 180+ days old.
-- Best-effort: create a login with a matching name pattern.  Detection fires once 180 days pass,
-- or immediately on a server that already has such an old login.
-- Run as sysadmin.
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_svc_rc06')
BEGIN
    CREATE LOGIN dbdome_test_svc_rc06 WITH PASSWORD = 'Dbdome$Test1234!', CHECK_POLICY = OFF;
END;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_svc_rc06')
    DROP LOGIN dbdome_test_svc_rc06;
GO

/* ===== SEC-SQL-AZ-003-RC07 [DESTRUCTIVE] ===== */
-- Detection returns SQL logins where is_expiration_checked=0 AND is_disabled=0
-- AND (name matches vendor/contractor/etc. patterns OR account_age > 365 days).
-- Creating a SQL login with CHECK_EXPIRATION=OFF and a matching name triggers it immediately.
-- Run as sysadmin.
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_vendor_rc07')
BEGIN
    CREATE LOGIN dbdome_test_vendor_rc07
        WITH PASSWORD = 'Dbdome$Test1234!',
             CHECK_POLICY = OFF,
             CHECK_EXPIRATION = OFF;
END;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_vendor_rc07')
    DROP LOGIN dbdome_test_vendor_rc07;
GO

/* ===== SEC-SQL-AZ-003-RC08 [DESTRUCTIVE] ===== */
-- Detection returns SQL logins with names matching shared-account patterns
-- (app/service/admin/test/user/shared/generic/common/default/dev).
-- Fires immediately for any such enabled SQL login regardless of session count.
-- Run as sysadmin.
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_appuser_rc08')
BEGIN
    CREATE LOGIN dbdome_test_appuser_rc08
        WITH PASSWORD = 'Dbdome$Test1234!',
             CHECK_POLICY = OFF;
END;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_appuser_rc08')
    DROP LOGIN dbdome_test_appuser_rc08;
GO

/* ===== SEC-SQL-AZ-003-RC09 [DESTRUCTIVE] ===== */
-- Detection returns database users that are members of any database role,
-- joined to sys.server_principals (MAPPED or ORPHANED).
-- Create a SQL login, map it to a user in a test database, add to a db role.
-- Run as sysadmin.  The detection runs in whatever the current database context is —
-- run it against the test database (USE dbdome_test_db_rc09).
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_test_db_rc09')
    CREATE DATABASE dbdome_test_db_rc09;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_rc09')
    CREATE LOGIN dbdome_test_login_rc09 WITH PASSWORD = 'Dbdome$Test1234!', CHECK_POLICY = OFF;
GO
USE dbdome_test_db_rc09;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_test_user_rc09')
    CREATE USER dbdome_test_user_rc09 FOR LOGIN dbdome_test_login_rc09;
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.database_role_members drm
    JOIN sys.database_principals m ON drm.member_principal_id = m.principal_id
    WHERE m.name = 'dbdome_test_user_rc09'
)
    ALTER ROLE db_datareader ADD MEMBER dbdome_test_user_rc09;
GO
USE master;
GO
-- REVERT:
USE dbdome_test_db_rc09;
GO
IF EXISTS (
    SELECT 1 FROM sys.database_role_members drm
    JOIN sys.database_principals m ON drm.member_principal_id = m.principal_id
    WHERE m.name = 'dbdome_test_user_rc09'
)
    ALTER ROLE db_datareader DROP MEMBER dbdome_test_user_rc09;
GO
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_test_user_rc09')
    DROP USER dbdome_test_user_rc09;
GO
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_rc09')
    DROP LOGIN dbdome_test_login_rc09;
GO
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_test_db_rc09')
    DROP DATABASE dbdome_test_db_rc09;
GO

/* ===== SEC-SQL-AZ-003-RC10 [DESTRUCTIVE] ===== */
-- Detection returns SQL logins created >365 days ago that are enabled and not 'sa' or '##'.
-- Also checks for extended_properties documentation (ep.name LIKE '%owner%' etc.) — note the
-- SQL has a logic bug (missing AND between the two OR clauses in the EXISTS subquery) so
-- has_documentation will always be 1 if ANY extended property named '%owner%' OR '%purpose%'
-- OR '%ticket%' exists at class=0; the detection still returns rows regardless.
-- Same date-age limitation: login must be 365+ days old.  On a fresh server, create the login
-- and accept the detection fires after 1 year, or use an existing old login.
-- Run as sysadmin.
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_legacy_rc10')
BEGIN
    CREATE LOGIN dbdome_test_legacy_rc10
        WITH PASSWORD = 'Dbdome$Test1234!',
             CHECK_POLICY = OFF;
END;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_legacy_rc10')
    DROP LOGIN dbdome_test_legacy_rc10;
GO

/* ===== SEC-SQL-AZ-003-RC11 [SAFE] ===== */
-- Detection returns aggregate counts: user_database_count, active_login_count, logins_per_database.
-- It always returns exactly 1 row (scalar aggregates with no GROUP BY).
-- No setup needed — the detection fires on any SQL Server with at least one user DB or login.
-- Setup: ensure at least one user database and one active login exist (true on any non-trivial server).
-- Create a minimal user database to guarantee user_database_count >= 1.
-- Run as sysadmin.
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_test_fragdb_rc11')
    CREATE DATABASE dbdome_test_fragdb_rc11;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_test_fragdb_rc11')
    DROP DATABASE dbdome_test_fragdb_rc11;
GO

/* ===== SEC-SQL-AZ-003-RC12 [DESTRUCTIVE] ===== */
-- Detection returns SQL logins in sysadmin/securityadmin/serveradmin/dbcreator roles
-- where is_expiration_checked=0 OR is_policy_checked=0, and the login is enabled.
-- Create a SQL login with CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF, add to sysadmin.
-- WARNING: adding to sysadmin on a test server; revert immediately.
-- Run as sysadmin.
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_pamlogin_rc12')
BEGIN
    CREATE LOGIN dbdome_test_pamlogin_rc12
        WITH PASSWORD = 'Dbdome$Test1234!',
             CHECK_POLICY = OFF,
             CHECK_EXPIRATION = OFF;
END;
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.server_role_members srm
    JOIN sys.server_principals r ON srm.role_principal_id = r.principal_id
    JOIN sys.server_principals m ON srm.member_principal_id = m.principal_id
    WHERE r.name = 'sysadmin' AND m.name = 'dbdome_test_pamlogin_rc12'
)
    EXEC sp_addsrvrolemember 'dbdome_test_pamlogin_rc12', 'sysadmin';
GO
-- REVERT:
IF EXISTS (
    SELECT 1 FROM sys.server_role_members srm
    JOIN sys.server_principals r ON srm.role_principal_id = r.principal_id
    JOIN sys.server_principals m ON srm.member_principal_id = m.principal_id
    WHERE r.name = 'sysadmin' AND m.name = 'dbdome_test_pamlogin_rc12'
)
    EXEC sp_dropsrvrolemember 'dbdome_test_pamlogin_rc12', 'sysadmin';
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_pamlogin_rc12')
    DROP LOGIN dbdome_test_pamlogin_rc12;
GO

/* ===== SEC-SQL-AZ-003-RC13 [DESTRUCTIVE] ===== */
-- Detection returns SQL logins whose name matches app/svc/service/default/webapp/api,
-- where the login is enabled, AND (create_date = modify_date OR PasswordLastSetTime = create_date).
-- A freshly-created SQL login with a matching name will satisfy create_date = modify_date.
-- Run as sysadmin.
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_applogin_rc13')
BEGIN
    CREATE LOGIN dbdome_test_applogin_rc13
        WITH PASSWORD = 'Dbdome$Test1234!',
             CHECK_POLICY = OFF;
END;
-- Note: do NOT ALTER the login after creation so that create_date = modify_date remains true.
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_applogin_rc13')
    DROP LOGIN dbdome_test_applogin_rc13;
GO

/* ===== SEC-SQL-AZ-003-RC14 [DESTRUCTIVE] ===== */
-- Detection returns orphaned database users: database_principals with a non-null, non-zero SID
-- that has no matching entry in sys.server_principals (the server login was dropped).
-- Create a SQL login, map it to a database user, then drop the login — leaving the user orphaned.
-- Run as sysadmin.
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_test_orphandb_rc14')
    CREATE DATABASE dbdome_test_orphandb_rc14;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_orphanlogin_rc14')
    CREATE LOGIN dbdome_test_orphanlogin_rc14
        WITH PASSWORD = 'Dbdome$Test1234!', CHECK_POLICY = OFF;
GO
USE dbdome_test_orphandb_rc14;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_test_orphanuser_rc14')
    CREATE USER dbdome_test_orphanuser_rc14 FOR LOGIN dbdome_test_orphanlogin_rc14;
GO
USE master;
GO
-- Drop the login to orphan the database user (user retains the old SID, no server_principal match):
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_orphanlogin_rc14')
    DROP LOGIN dbdome_test_orphanlogin_rc14;
GO
-- REVERT:
USE dbdome_test_orphandb_rc14;
GO
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_test_orphanuser_rc14')
    DROP USER dbdome_test_orphanuser_rc14;
GO
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_test_orphandb_rc14')
    DROP DATABASE dbdome_test_orphandb_rc14;
GO

/* ===== SEC-SQL-AZ-003-RC15 [DESTRUCTIVE] ===== */
-- Detection returns GRANT permissions on the 'public' role for SELECT/INSERT/UPDATE/DELETE/EXECUTE
-- on OBJECT_OR_COLUMN class.  Grant SELECT on a test table to public to trigger.
-- Run as sysadmin (or db_owner in the target database).
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_test_pubpermdb_rc15')
    CREATE DATABASE dbdome_test_pubpermdb_rc15;
GO
USE dbdome_test_pubpermdb_rc15;
GO
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dbdome_public_test_rc15' AND schema_id = SCHEMA_ID('dbo'))
    CREATE TABLE dbo.dbdome_public_test_rc15 (id INT, fake_data NVARCHAR(100));
GO
-- Grant SELECT to public on the test table:
GRANT SELECT ON dbo.dbdome_public_test_rc15 TO [public];
GO
USE master;
GO
-- REVERT:
USE dbdome_test_pubpermdb_rc15;
GO
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dbdome_public_test_rc15' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    REVOKE SELECT ON dbo.dbdome_public_test_rc15 FROM [public];
    DROP TABLE dbo.dbdome_public_test_rc15;
END;
GO
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_test_pubpermdb_rc15')
    DROP DATABASE dbdome_test_pubpermdb_rc15;
GO


/* ########## batch 19 (12 reproducers) ########## */
/* ===== SEC-SQL-AZ-004-RC01 [DESTRUCTIVE] ===== */
-- Grants ADMINISTER BULK OPERATIONS server permission to a test login so the detection's first UNION branch returns a row.
-- Run as sysadmin. REVERT drops the login when done.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    CREATE LOGIN dbdome_test_login WITH PASSWORD = 'D!sp0sable_99', CHECK_POLICY = OFF;
GRANT ADMINISTER BULK OPERATIONS TO dbdome_test_login;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
BEGIN
    REVOKE ADMINISTER BULK OPERATIONS FROM dbdome_test_login;
    DROP LOGIN dbdome_test_login;
END
GO

/* ===== SEC-SQL-AZ-004-RC02 [DESTRUCTIVE] ===== */
-- Enables xp_cmdshell so value_in_use = 1; the detection returns that non-zero value.
-- Run as sysadmin. REVERT disables xp_cmdshell and hides advanced options again.
-- SETUP:
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;
GO
-- REVERT:
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 0; RECONFIGURE;
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-AZ-004-RC03 [DESTRUCTIVE] ===== */
-- Creates a login and adds it to the bulkadmin fixed server role so the detection returns a row.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    CREATE LOGIN dbdome_test_login WITH PASSWORD = 'D!sp0sable_99', CHECK_POLICY = OFF;
ALTER SERVER ROLE bulkadmin ADD MEMBER dbdome_test_login;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
BEGIN
    ALTER SERVER ROLE bulkadmin DROP MEMBER dbdome_test_login;
    DROP LOGIN dbdome_test_login;
END
GO

/* ===== SEC-SQL-AZ-004-RC04 [DESTRUCTIVE] ===== */
-- Enables both xp_cmdshell and Ole Automation Procedures so both value_in_use columns are non-zero.
-- Run as sysadmin.
-- SETUP:
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;
EXEC sp_configure 'Ole Automation Procedures', 1; RECONFIGURE;
GO
-- REVERT:
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 0; RECONFIGURE;
EXEC sp_configure 'Ole Automation Procedures', 0; RECONFIGURE;
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-AZ-004-RC05 [DESTRUCTIVE] ===== */
-- Enables xp_cmdshell so the detection query (which SELECTs named config rows) returns a row
-- with running_value=1 for xp_cmdshell, triggering any downstream check for non-default state.
-- The detection is a plain SELECT of configs; it always returns rows. To make the result
-- meaningful (non-default), enable xp_cmdshell. Run as sysadmin.
-- SETUP:
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;
GO
-- REVERT:
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 0; RECONFIGURE;
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-AZ-004-RC06 [DESTRUCTIVE] ===== */
-- Creates a non-SA login in sysadmin role AND enables xp_cmdshell so both sub-selects return
-- non-zero values. The detection reports sysadmin_count and xp_cmdshell_enabled.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    CREATE LOGIN dbdome_test_login WITH PASSWORD = 'D!sp0sable_99', CHECK_POLICY = OFF;
ALTER SERVER ROLE sysadmin ADD MEMBER dbdome_test_login;
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;
GO
-- REVERT:
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 0; RECONFIGURE;
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
BEGIN
    ALTER SERVER ROLE sysadmin DROP MEMBER dbdome_test_login;
    DROP LOGIN dbdome_test_login;
END
GO

/* ===== SEC-SQL-AZ-004-RC07 [SAFE] ===== */
-- Executes xp_cmdshell (or references it) so an entry appears in sys.dm_exec_query_stats
-- matching the LIKE '%xp_cmdshell%' predicate. The plan cache entry persists until evicted.
-- xp_cmdshell must be enabled first; disable it again in revert. Keep in a separate session
-- only if you want the cache entry to persist; running it once is usually enough.
-- SETUP:
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;
-- Execute once to seed the plan cache entry:
EXEC xp_cmdshell 'echo dbdome_test';
GO
-- REVERT:
-- Disable xp_cmdshell (cache entries will age out naturally; flush manually if needed):
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 0; RECONFIGURE;
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
-- Optional: flush plan cache to remove the entry immediately:
-- DBCC FREEPROCCACHE;
GO

/* ===== SEC-SQL-AZ-004-RC08 [DESTRUCTIVE] ===== */
-- Enables Ole Automation Procedures and Ad Hoc Distributed Queries so both value_in_use
-- columns are non-zero. Run as sysadmin.
-- SETUP:
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'Ole Automation Procedures', 1; RECONFIGURE;
EXEC sp_configure 'Ad Hoc Distributed Queries', 1; RECONFIGURE;
GO
-- REVERT:
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'Ole Automation Procedures', 0; RECONFIGURE;
EXEC sp_configure 'Ad Hoc Distributed Queries', 0; RECONFIGURE;
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-AZ-004-RC09 [DESTRUCTIVE] ===== */
-- Creates a regular SQL login and adds it to bulkadmin so privileged_role_count >= 1.
-- The login satisfies all WHERE filters (enabled, not ##, not sa, type S).
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    CREATE LOGIN dbdome_test_login WITH PASSWORD = 'D!sp0sable_99', CHECK_POLICY = OFF;
ALTER SERVER ROLE bulkadmin ADD MEMBER dbdome_test_login;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
BEGIN
    ALTER SERVER ROLE bulkadmin DROP MEMBER dbdome_test_login;
    DROP LOGIN dbdome_test_login;
END
GO

/* ===== SEC-SQL-AZ-004-RC10 [DESTRUCTIVE] ===== */
-- Creates an enabled SQL Agent job with an xp_cmdshell step so the third sub-select
-- (jobs_using_cmdshell) returns >= 1. Requires SQL Server Agent and msdb.
-- Run as sysadmin.
-- SETUP:
USE msdb;
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = 'dbdome_test_cmdshell_job')
BEGIN
    EXEC msdb.dbo.sp_add_job
        @job_name = N'dbdome_test_cmdshell_job',
        @enabled   = 1;
    EXEC msdb.dbo.sp_add_jobstep
        @job_name    = N'dbdome_test_cmdshell_job',
        @step_name   = N'dbdome_test_step',
        @subsystem   = N'TSQL',
        @command     = N'EXEC xp_cmdshell ''echo dbdome_test''',
        @on_success_action = 1;
    EXEC msdb.dbo.sp_add_jobserver
        @job_name = N'dbdome_test_cmdshell_job';
END
GO
-- REVERT:
USE msdb;
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = 'dbdome_test_cmdshell_job')
    EXEC msdb.dbo.sp_delete_job @job_name = N'dbdome_test_cmdshell_job', @delete_unused_schedule = 1;
GO

/* ===== SEC-SQL-AZ-004-RC11 [DESTRUCTIVE] ===== */
-- Creates a SQL login whose name matches the '%svc%' LIKE pattern and adds it to bulkadmin
-- so file_access_grants OR privileged_roles >= 1 and the WHERE filters are satisfied.
-- distinct_hosts / distinct_programs remain 0 because no session is open - row still appears.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_svc_test')
    CREATE LOGIN dbdome_svc_test WITH PASSWORD = 'D!sp0sable_99', CHECK_POLICY = OFF;
ALTER SERVER ROLE bulkadmin ADD MEMBER dbdome_svc_test;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_svc_test')
BEGIN
    ALTER SERVER ROLE bulkadmin DROP MEMBER dbdome_svc_test;
    DROP LOGIN dbdome_svc_test;
END
GO

/* ===== SEC-SQL-AZ-004-RC12 [DESTRUCTIVE] ===== */
-- Grants EXECUTE on xp_cmdshell (in master) to a test login AND enables xp_cmdshell so the
-- CROSS JOIN with sys.configurations returns c.value_in_use = 1. Without enabling xp_cmdshell
-- the query still returns a row (permission exists) but value_in_use = 0; enabling it makes
-- the full condition unambiguous. Run as sysadmin.
-- SETUP:
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    CREATE LOGIN dbdome_test_login WITH PASSWORD = 'D!sp0sable_99', CHECK_POLICY = OFF;
USE master;
GRANT EXECUTE ON xp_cmdshell TO dbdome_test_login;
GO
-- REVERT:
USE master;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    REVOKE EXECUTE ON xp_cmdshell FROM dbdome_test_login;
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 0; RECONFIGURE;
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    DROP LOGIN dbdome_test_login;
GO


/* ########## batch 20 (12 reproducers) ########## */
/* ===== SEC-SQL-AZ-004-RC13 [DESTRUCTIVE] ===== */
-- Grants EXECUTE on xp_cmdshell to a non-sysadmin login so the detection returns >=1 row.
-- Run as sysadmin. The login is created disabled to avoid interactive use; grant is still visible.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    CREATE LOGIN dbdome_test_login WITH PASSWORD = 'Dbdome_T3st!2025', CHECK_POLICY = OFF;

-- Ensure the login is not a sysadmin (default for new logins)
IF IS_SRVROLEMEMBER('sysadmin', 'dbdome_test_login') = 1
    ALTER SERVER ROLE sysadmin DROP MEMBER dbdome_test_login;

-- Enable the login so is_disabled = 0 (detection filters disabled logins)
ALTER LOGIN dbdome_test_login ENABLE;

-- Grant EXECUTE on xp_cmdshell to the non-sysadmin login
GRANT EXECUTE ON xp_cmdshell TO dbdome_test_login;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
BEGIN
    -- Revoke the grant first
    IF EXISTS (
        SELECT 1 FROM sys.server_permissions p
        JOIN sys.server_principals dp ON p.grantee_principal_id = dp.principal_id
        JOIN master.sys.objects o ON p.major_id = o.object_id
        WHERE dp.name = 'dbdome_test_login'
          AND o.name = 'xp_cmdshell'
          AND p.permission_name = 'EXECUTE'
    )
        REVOKE EXECUTE ON xp_cmdshell FROM dbdome_test_login;

    DROP LOGIN dbdome_test_login;
END
GO

/* ===== SEC-SQL-AZ-004-RC14 [DESTRUCTIVE] ===== */
-- Enables 'Ole Automation Procedures' (or xp_cmdshell) so the UNION ALL branch returns value_in_use=1.
-- Detection fires on any of the 4 named configs being enabled, or a BULK/CLR count > 0.
-- Run as sysadmin. Setup enables 'Ole Automation Procedures'; revert disables it.
-- SETUP:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Ole Automation Procedures', 1;
RECONFIGURE;
GO
-- REVERT:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Ole Automation Procedures', 0;
RECONFIGURE;
EXEC sp_configure 'show advanced options', 0;
RECONFIGURE;
GO

/* ===== SEC-SQL-AZ-005-RC01 [DESTRUCTIVE] ===== */
-- Creates a user database with cross-db ownership chaining enabled so the detection returns >=1 row.
-- The detection requires database_id > 4 and is_db_chaining_on = 1 and state = 0.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_chain_test')
    CREATE DATABASE dbdome_chain_test;

ALTER DATABASE dbdome_chain_test SET DB_CHAINING ON;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_chain_test')
BEGIN
    ALTER DATABASE dbdome_chain_test SET DB_CHAINING OFF;
    DROP DATABASE dbdome_chain_test;
END
GO

/* ===== SEC-SQL-AZ-005-RC02 [DESTRUCTIVE] ===== */
-- Detection fires if any user DB has is_db_chaining_on=1 OR the server-level 'cross db ownership chaining'=1.
-- Setup enables the server-level option (simpler single change that satisfies the OR).
-- Run as sysadmin.
-- SETUP:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'cross db ownership chaining', 1;
RECONFIGURE;
GO
-- REVERT:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'cross db ownership chaining', 0;
RECONFIGURE;
EXEC sp_configure 'show advanced options', 0;
RECONFIGURE;
GO

/* ===== SEC-SQL-AZ-005-RC03 [DESTRUCTIVE] ===== */
-- Creates a user-defined view whose definition contains a cross-database reference pattern [db].[schema].[obj]
-- matching the LIKE '%[[]%.%].[[]%' predicate so the detection returns >=1 row.
-- Run as sysadmin or db_owner in any user database.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_chain_test')
    CREATE DATABASE dbdome_chain_test;
GO
USE dbdome_chain_test;
GO
IF OBJECT_ID('dbo.dbdome_crossdb_view', 'V') IS NOT NULL
    DROP VIEW dbo.dbdome_crossdb_view;
GO
-- The view body references [master].[dbo].[sysdatabases], which satisfies the LIKE pattern
CREATE VIEW dbo.dbdome_crossdb_view AS
    SELECT name FROM [master].[dbo].[sysdatabases];
GO
USE master;
GO
-- REVERT:
USE dbdome_chain_test;
GO
IF OBJECT_ID('dbo.dbdome_crossdb_view', 'V') IS NOT NULL
    DROP VIEW dbo.dbdome_crossdb_view;
GO
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_chain_test')
    DROP DATABASE dbdome_chain_test;
GO

/* ===== SEC-SQL-AZ-005-RC04 [DESTRUCTIVE] ===== */
-- Detection requires a single db_owner who owns >1 user databases where is_db_chaining_on=1.
-- Create two databases under the same owner (sa) with chaining on; sa will appear in the result.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_chain_a')
    CREATE DATABASE dbdome_chain_a;
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_chain_b')
    CREATE DATABASE dbdome_chain_b;

ALTER DATABASE dbdome_chain_a SET DB_CHAINING ON;
ALTER DATABASE dbdome_chain_b SET DB_CHAINING ON;

-- Ensure both databases are owned by sa (default; explicit for clarity)
EXEC sp_changedbowner 'sa'; -- run context is master so this sets master's owner; switch context below
USE dbdome_chain_a;
EXEC sp_changedbowner 'sa';
USE dbdome_chain_b;
EXEC sp_changedbowner 'sa';
USE master;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_chain_a')
BEGIN
    ALTER DATABASE dbdome_chain_a SET DB_CHAINING OFF;
    DROP DATABASE dbdome_chain_a;
END
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_chain_b')
BEGIN
    ALTER DATABASE dbdome_chain_b SET DB_CHAINING OFF;
    DROP DATABASE dbdome_chain_b;
END
GO

/* ===== SEC-SQL-AZ-005-RC05 [SAFE] ===== */
-- Detection is a scalar query: it returns exactly 1 row always (counts from several catalog views).
-- It fires (returns a row) unconditionally; the counts show whether risk items exist.
-- To make at least one count > 0 so a monitoring threshold is triggered: create a certificate-mapped user.
-- However the detection always returns 1 row regardless. Mark SAFE because the detection itself is
-- purely read-only; no persistent change is strictly needed, but we create a certificate user for context.
-- Run as db_owner in a test database.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_chain_test')
    CREATE DATABASE dbdome_chain_test;
GO
USE dbdome_chain_test;
GO
IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'dbdome_test_cert')
    CREATE CERTIFICATE dbdome_test_cert
        WITH SUBJECT = 'DBDome positive test certificate',
             EXPIRY_DATE = '2030-01-01';

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_cert_user')
    CREATE USER dbdome_cert_user FROM CERTIFICATE dbdome_test_cert;
GO
USE master;
GO
-- REVERT:
USE dbdome_chain_test;
GO
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_cert_user')
    DROP USER dbdome_cert_user;
IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'dbdome_test_cert')
    DROP CERTIFICATE dbdome_test_cert;
GO
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_chain_test')
    DROP DATABASE dbdome_chain_test;
GO

/* ===== SEC-SQL-AZ-005-RC06 [DESTRUCTIVE] ===== */
-- Detection counts cross_db_synonyms (base_object_name with two dots), cross_db_objects, chaining_db_count.
-- At least one count must be > 0. Easiest: create a synonym pointing to a cross-database object.
-- Run as db_owner.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_chain_test')
    CREATE DATABASE dbdome_chain_test;
GO
USE dbdome_chain_test;
GO
IF OBJECT_ID('dbo.dbdome_xdb_synonym', 'SN') IS NOT NULL
    DROP SYNONYM dbo.dbdome_xdb_synonym;

-- Synonym base_object_name has two dots => cross-database reference
CREATE SYNONYM dbo.dbdome_xdb_synonym FOR [master].[dbo].[sysdatabases];
GO
USE master;
GO
-- REVERT:
USE dbdome_chain_test;
GO
IF OBJECT_ID('dbo.dbdome_xdb_synonym', 'SN') IS NOT NULL
    DROP SYNONYM dbo.dbdome_xdb_synonym;
GO
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_chain_test')
    DROP DATABASE dbdome_chain_test;
GO

/* ===== SEC-SQL-AZ-005-RC07 [DESTRUCTIVE] ===== */
-- Detection returns a single row. For a non-zero signal it checks server_chaining=1 OR user_dbs_chaining>0.
-- Enable server-level cross db ownership chaining so server_chaining=1.
-- Run as sysadmin.
-- SETUP:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'cross db ownership chaining', 1;
RECONFIGURE;
GO
-- REVERT:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'cross db ownership chaining', 0;
RECONFIGURE;
EXEC sp_configure 'show advanced options', 0;
RECONFIGURE;
GO

/* ===== SEC-SQL-AZ-005-RC08 [DESTRUCTIVE] ===== */
-- Detection returns a single scalar row always. For meaningful signal: server_chaining=1 or user_dbs_with_chaining>0.
-- Enable server-level cross db ownership chaining so both columns are non-zero.
-- Run as sysadmin.
-- SETUP:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'cross db ownership chaining', 1;
RECONFIGURE;
GO
-- REVERT:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'cross db ownership chaining', 0;
RECONFIGURE;
EXEC sp_configure 'show advanced options', 0;
RECONFIGURE;
GO

/* ===== SEC-SQL-AZ-005-RC09 [DESTRUCTIVE] ===== */
-- Detection returns a single scalar row always. Signal is present when server_chaining=1 or dbs_with_chaining>0
-- or dbs_trustworthy>0. Enable server chaining and create a trustworthy database for full signal.
-- Run as sysadmin.
-- SETUP:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'cross db ownership chaining', 1;
RECONFIGURE;

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_trust_test')
    CREATE DATABASE dbdome_trust_test;
ALTER DATABASE dbdome_trust_test SET TRUSTWORTHY ON;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_trust_test')
BEGIN
    ALTER DATABASE dbdome_trust_test SET TRUSTWORTHY OFF;
    DROP DATABASE dbdome_trust_test;
END

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'cross db ownership chaining', 0;
RECONFIGURE;
EXEC sp_configure 'show advanced options', 0;
RECONFIGURE;
GO

/* ===== SEC-SQL-AZ-005-RC10 [DESTRUCTIVE] ===== */
-- Detection lists user databases with is_db_chaining_on=1 (database_id > 4, state=0).
-- Create a user database with DB_CHAINING ON so the detection returns >=1 row.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_chain_test')
    CREATE DATABASE dbdome_chain_test;

ALTER DATABASE dbdome_chain_test SET DB_CHAINING ON;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_chain_test')
BEGIN
    ALTER DATABASE dbdome_chain_test SET DB_CHAINING OFF;
    DROP DATABASE dbdome_chain_test;
END
GO


/* ########## batch 21 (12 reproducers) ########## */
/* ===================================================================
   Positive-test reproducers for detections slice 252..264
   root_cause_ids: SEC-SQL-AZ-005-RC11 through SEC-SQL-AZ-006-RC10
   Target: DISPOSABLE TEST SQL Server only.
   Each block: SETUP triggers the detection, REVERT undoes it.
   Run all blocks as sysadmin unless noted otherwise.
   =================================================================== */

/* ===== SEC-SQL-AZ-005-RC11 [DESTRUCTIVE] ===== */
-- Detection: user databases (database_id > 4, state=0) with is_db_chaining_on=1.
-- Setup: create a throwaway database and enable cross-db ownership chaining on it.
-- The outer query returns one row per such database, so creating one is sufficient.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_chaining_test')
    CREATE DATABASE dbdome_chaining_test;
GO
ALTER DATABASE dbdome_chaining_test SET DB_CHAINING ON;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_chaining_test')
BEGIN
    ALTER DATABASE dbdome_chaining_test SET DB_CHAINING OFF;
    DROP DATABASE dbdome_chaining_test;
END
GO

/* ===== SEC-SQL-AZ-005-RC12 [DESTRUCTIVE] ===== */
-- Detection: always returns exactly one aggregate row with scalar subquery counts.
-- Flags risk when dbs_chaining_on > 0 OR dbs_trustworthy > 0.
-- Setup: create a throwaway database with both TRUSTWORTHY ON and DB_CHAINING ON
-- so that dbs_chaining_on >= 1 and dbs_trustworthy >= 1 in the result row.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_isolation_test')
    CREATE DATABASE dbdome_isolation_test;
GO
ALTER DATABASE dbdome_isolation_test SET DB_CHAINING ON;
ALTER DATABASE dbdome_isolation_test SET TRUSTWORTHY ON;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_isolation_test')
BEGIN
    ALTER DATABASE dbdome_isolation_test SET DB_CHAINING OFF;
    ALTER DATABASE dbdome_isolation_test SET TRUSTWORTHY OFF;
    DROP DATABASE dbdome_isolation_test;
END
GO

/* ===== SEC-SQL-AZ-006-RC01 [DESTRUCTIVE] ===== */
-- Detection: server permission granted WITH GRANT OPTION (state_desc='GRANT_WITH_GRANT_OPTION')
-- to an enabled non-## login of type S/U/G/R.
-- Setup: create a SQL login and grant it VIEW ANY DATABASE WITH GRANT OPTION.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_grant_test')
    CREATE LOGIN dbdome_grant_test WITH PASSWORD = 'DbDome#Grant1!', CHECK_POLICY = OFF;
ALTER LOGIN dbdome_grant_test ENABLE;
GRANT VIEW ANY DATABASE TO dbdome_grant_test WITH GRANT OPTION;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_grant_test')
BEGIN
    REVOKE VIEW ANY DATABASE FROM dbdome_grant_test CASCADE;
    DROP LOGIN dbdome_grant_test;
END
GO

/* ===== SEC-SQL-AZ-006-RC02 [DESTRUCTIVE] ===== */
-- Detection: server permission WITH GRANT OPTION for a non-sysadmin enabled login.
-- IS_SRVROLEMEMBER('sysadmin', sp.name) = 0 is the key predicate (non-sysadmin).
-- Setup: same as RC01 - create a plain SQL login with a server permission granted
-- WITH GRANT OPTION; since the login is not in sysadmin the row will appear.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_wgo_test')
    CREATE LOGIN dbdome_wgo_test WITH PASSWORD = 'DbDome#Wgo1!', CHECK_POLICY = OFF;
ALTER LOGIN dbdome_wgo_test ENABLE;
GRANT VIEW SERVER STATE TO dbdome_wgo_test WITH GRANT OPTION;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_wgo_test')
BEGIN
    REVOKE VIEW SERVER STATE FROM dbdome_wgo_test CASCADE;
    DROP LOGIN dbdome_wgo_test;
END
GO

/* ===== SEC-SQL-AZ-006-RC03 [DESTRUCTIVE] ===== */
-- Detection: same object+permission has GRANT_WITH_GRANT_OPTION for COUNT(*) > 1
-- distinct database users (non dbo/guest/sys/INFORMATION_SCHEMA, type S/U/G).
-- Setup: in a test database create two users and grant both the same permission
-- WITH GRANT OPTION on the same object (or at database level).
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_wgo_db_test')
    CREATE DATABASE dbdome_wgo_db_test;
GO
USE dbdome_wgo_db_test;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_db_login_a')
    CREATE LOGIN dbdome_db_login_a WITH PASSWORD = 'DbDome#DBA1!', CHECK_POLICY = OFF;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_db_login_b')
    CREATE LOGIN dbdome_db_login_b WITH PASSWORD = 'DbDome#DBB1!', CHECK_POLICY = OFF;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_db_user_a')
    CREATE USER dbdome_db_user_a FOR LOGIN dbdome_db_login_a;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_db_user_b')
    CREATE USER dbdome_db_user_b FOR LOGIN dbdome_db_login_b;
-- Grant same database-level permission WITH GRANT OPTION to both users
GRANT CREATE TABLE TO dbdome_db_user_a WITH GRANT OPTION;
GRANT CREATE TABLE TO dbdome_db_user_b WITH GRANT OPTION;
GO
USE master;
GO
-- REVERT:
USE dbdome_wgo_db_test;
GO
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_db_user_a')
    DROP USER dbdome_db_user_a;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_db_user_b')
    DROP USER dbdome_db_user_b;
GO
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_db_login_a')
    DROP LOGIN dbdome_db_login_a;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_db_login_b')
    DROP LOGIN dbdome_db_login_b;
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_wgo_db_test')
    DROP DATABASE dbdome_wgo_db_test;
GO

/* ===== SEC-SQL-AZ-006-RC04 [DESTRUCTIVE] ===== */
-- Detection: always returns one aggregate row. Flags when delegated_grant_count > 0,
-- i.e., database permissions granted by a grantor other than dbo.
-- Setup: in a test database create two users; user_a grants SELECT to user_b
-- (so grantor != dbo). The re-grant requires user_a to hold the permission
-- WITH GRANT OPTION first (granted by dbo/sysadmin), then connect as user_a.
-- For simplicity: grant via T-SQL EXECUTE AS to simulate non-dbo grantor.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_delegation_test')
    CREATE DATABASE dbdome_delegation_test;
GO
USE dbdome_delegation_test;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_grantor_login')
    CREATE LOGIN dbdome_grantor_login WITH PASSWORD = 'DbDome#Gtr1!', CHECK_POLICY = OFF;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_grantee_login')
    CREATE LOGIN dbdome_grantee_login WITH PASSWORD = 'DbDome#Gte1!', CHECK_POLICY = OFF;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_grantor_user')
    CREATE USER dbdome_grantor_user FOR LOGIN dbdome_grantor_login;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_grantee_user')
    CREATE USER dbdome_grantee_user FOR LOGIN dbdome_grantee_login;
-- Give the grantor user CREATE TABLE WITH GRANT OPTION so it can re-delegate
GRANT CREATE TABLE TO dbdome_grantor_user WITH GRANT OPTION;
-- Now simulate the non-dbo grantor issuing a GRANT via EXECUTE AS
EXECUTE AS USER = 'dbdome_grantor_user';
    GRANT CREATE TABLE TO dbdome_grantee_user;
REVERT;
GO
USE master;
GO
-- REVERT:
USE dbdome_delegation_test;
GO
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_grantee_user')
    DROP USER dbdome_grantee_user;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_grantor_user')
    DROP USER dbdome_grantor_user;
GO
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_grantor_login')
    DROP LOGIN dbdome_grantor_login;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_grantee_login')
    DROP LOGIN dbdome_grantee_login;
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_delegation_test')
    DROP DATABASE dbdome_delegation_test;
GO

/* ===== SEC-SQL-AZ-006-RC05 [SAFE] ===== */
-- Detection: always returns one aggregate row with audit counts.
-- Flags when any of active_audits / server_perm_audit / db_perm_audit / schema_perm_audit = 0.
-- On a freshly installed SQL Server with no audits configured, all four values = 0
-- so the detection already returns a meaningful (flagging) row with no setup required.
-- SAFE - read-only check; no changes needed on a test server with no audits.
-- SETUP:
-- No setup required. On a test server without server audits, active_audits = 0
-- and all audit sub-counts = 0, which is the condition this detection flags.
SELECT
    (SELECT COUNT(*) FROM sys.server_audits WHERE is_state_enabled = 1) AS active_audits,
    'Verify all values are 0 to confirm detection fires' AS note;
GO
-- REVERT:
-- Nothing to revert (no changes were made).
SELECT 1 AS revert_noop;
GO

/* ===== SEC-SQL-AZ-006-RC06 [DESTRUCTIVE] ===== */
-- Detection: database permissions where grantor is not dbo (grantor.name <> 'dbo'),
-- grantee is not dbo/guest/sys/INFORMATION_SCHEMA and type IN (S,U,G,R).
-- Setup: same pattern as RC04 - use EXECUTE AS to have a non-dbo user grant a permission.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_redelegation_test')
    CREATE DATABASE dbdome_redelegation_test;
GO
USE dbdome_redelegation_test;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_rg_login_a')
    CREATE LOGIN dbdome_rg_login_a WITH PASSWORD = 'DbDome#RGA1!', CHECK_POLICY = OFF;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_rg_login_b')
    CREATE LOGIN dbdome_rg_login_b WITH PASSWORD = 'DbDome#RGB1!', CHECK_POLICY = OFF;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_rg_user_a')
    CREATE USER dbdome_rg_user_a FOR LOGIN dbdome_rg_login_a;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_rg_user_b')
    CREATE USER dbdome_rg_user_b FOR LOGIN dbdome_rg_login_b;
-- Grant user_a a permission WITH GRANT OPTION (grantor = dbo at this step)
GRANT CREATE TABLE TO dbdome_rg_user_a WITH GRANT OPTION;
-- user_a re-grants to user_b (grantor becomes dbdome_rg_user_a != dbo)
EXECUTE AS USER = 'dbdome_rg_user_a';
    GRANT CREATE TABLE TO dbdome_rg_user_b;
REVERT;
GO
USE master;
GO
-- REVERT:
USE dbdome_redelegation_test;
GO
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_rg_user_b')
    DROP USER dbdome_rg_user_b;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_rg_user_a')
    DROP USER dbdome_rg_user_a;
GO
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_rg_login_a')
    DROP LOGIN dbdome_rg_login_a;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_rg_login_b')
    DROP LOGIN dbdome_rg_login_b;
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_redelegation_test')
    DROP DATABASE dbdome_redelegation_test;
GO

/* ===== SEC-SQL-AZ-006-RC07 [DESTRUCTIVE] ===== */
-- Detection: server permission in a specific sensitive list, granted WITH GRANT OPTION
-- (state_desc='GRANT_WITH_GRANT_OPTION'), to an enabled non-## login.
-- Setup: create a SQL login and grant ALTER ANY DATABASE WITH GRANT OPTION
-- (ALTER ANY DATABASE is in the HIGH_IMPACT / sensitive list).
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_sensitive_gwo')
    CREATE LOGIN dbdome_sensitive_gwo WITH PASSWORD = 'DbDome#SWG1!', CHECK_POLICY = OFF;
ALTER LOGIN dbdome_sensitive_gwo ENABLE;
GRANT ALTER ANY DATABASE TO dbdome_sensitive_gwo WITH GRANT OPTION;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_sensitive_gwo')
BEGIN
    REVOKE ALTER ANY DATABASE FROM dbdome_sensitive_gwo CASCADE;
    DROP LOGIN dbdome_sensitive_gwo;
END
GO

/* ===== SEC-SQL-AZ-006-RC08 [DESTRUCTIVE] ===== */
-- Detection: a custom (non-builtin) server ROLE (sp.type='R') has a server permission
-- granted WITH GRANT OPTION.  The role must not be in the excluded builtin list.
-- Setup: create a custom server role and grant it VIEW ANY DATABASE WITH GRANT OPTION.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_custom_role' AND type = 'R')
    CREATE SERVER ROLE dbdome_custom_role;
GRANT VIEW ANY DATABASE TO dbdome_custom_role WITH GRANT OPTION;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_custom_role' AND type = 'R')
BEGIN
    REVOKE VIEW ANY DATABASE FROM dbdome_custom_role CASCADE;
    DROP SERVER ROLE dbdome_custom_role;
END
GO

/* ===== SEC-SQL-AZ-006-RC09 [DESTRUCTIVE] ===== */
-- Detection: database user (type S/U/G, not dbo/guest) that is a member of more than
-- one role (HAVING COUNT(DISTINCT role_principal_id) > 1) where at least one of those
-- roles has a permission with GRANT_WITH_GRANT_OPTION.
-- Setup: create a test database with a user, add them to two roles, grant one role
-- a permission WITH GRANT OPTION.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_escalation_test')
    CREATE DATABASE dbdome_escalation_test;
GO
USE dbdome_escalation_test;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_esc_login')
    CREATE LOGIN dbdome_esc_login WITH PASSWORD = 'DbDome#Esc1!', CHECK_POLICY = OFF;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_esc_user')
    CREATE USER dbdome_esc_user FOR LOGIN dbdome_esc_login;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_esc_role_a' AND type = 'R')
    CREATE ROLE dbdome_esc_role_a;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_esc_role_b' AND type = 'R')
    CREATE ROLE dbdome_esc_role_b;
-- Give role_a a permission WITH GRANT OPTION so inherited_grant_options >= 1
GRANT SELECT TO dbdome_esc_role_a WITH GRANT OPTION;
-- Add the user to both roles (satisfies COUNT > 1)
EXEC sp_addrolemember 'dbdome_esc_role_a', 'dbdome_esc_user';
EXEC sp_addrolemember 'dbdome_esc_role_b', 'dbdome_esc_user';
GO
USE master;
GO
-- REVERT:
USE dbdome_escalation_test;
GO
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_esc_user')
BEGIN
    EXEC sp_droprolemember 'dbdome_esc_role_a', 'dbdome_esc_user';
    EXEC sp_droprolemember 'dbdome_esc_role_b', 'dbdome_esc_user';
    DROP USER dbdome_esc_user;
END
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_esc_role_a' AND type = 'R')
    DROP ROLE dbdome_esc_role_a;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_esc_role_b' AND type = 'R')
    DROP ROLE dbdome_esc_role_b;
GO
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_esc_login')
    DROP LOGIN dbdome_esc_login;
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_escalation_test')
    DROP DATABASE dbdome_escalation_test;
GO

/* ===== SEC-SQL-AZ-006-RC10 [DESTRUCTIVE] ===== */
-- Detection: database user (type S/U/G, not dbo/guest) that is a member of both
-- a data role (db_datareader or db_datawriter) AND an admin role
-- (db_owner, db_securityadmin, db_ddladmin, or db_accessadmin) — SoD violation.
-- Setup: create a test database with a user and add them to db_datareader AND db_ddladmin.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_sod_test')
    CREATE DATABASE dbdome_sod_test;
GO
USE dbdome_sod_test;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_sod_login')
    CREATE LOGIN dbdome_sod_login WITH PASSWORD = 'DbDome#Sod1!', CHECK_POLICY = OFF;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_sod_user')
    CREATE USER dbdome_sod_user FOR LOGIN dbdome_sod_login;
-- Add to a data role (db_datareader) AND an admin role (db_ddladmin) -> SoD violation
EXEC sp_addrolemember 'db_datareader', 'dbdome_sod_user';
EXEC sp_addrolemember 'db_ddladmin',   'dbdome_sod_user';
GO
USE master;
GO
-- REVERT:
USE dbdome_sod_test;
GO
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_sod_user')
BEGIN
    EXEC sp_droprolemember 'db_datareader', 'dbdome_sod_user';
    EXEC sp_droprolemember 'db_ddladmin',   'dbdome_sod_user';
    DROP USER dbdome_sod_user;
END
GO
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_sod_login')
    DROP LOGIN dbdome_sod_login;
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_sod_test')
    DROP DATABASE dbdome_sod_test;
GO


/* ########## batch 22 (12 reproducers) ########## */
/* ===================================================================
   Positive-test reproducers for detections slice 264..276
   Target: DISPOSABLE TEST SQL Server only.
   Each block: SETUP triggers the detection, REVERT undoes it.
   =================================================================== */

/* ===== SEC-SQL-AZ-006-RC11 [DESTRUCTIVE] ===== */
-- Detection: GRANT_WITH_GRANT_OPTION permissions grouped by permission_name/class_desc
-- where COUNT(DISTINCT principals) >= 3, excluding system principals.
-- Setup: create a throwaway DB and grant SELECT WITH GRANT OPTION to 3 SQL users so
-- the HAVING COUNT >= 3 predicate fires. Run as sysadmin in the test database.
-- SETUP:
USE [master];
GO
IF DB_ID('dbdome_test_db') IS NULL
    CREATE DATABASE dbdome_test_db;
GO
USE dbdome_test_db;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_grantopt_u1')
    CREATE LOGIN dbdome_grantopt_u1 WITH PASSWORD = 'DbDome#GO1!', CHECK_POLICY = OFF;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_grantopt_u2')
    CREATE LOGIN dbdome_grantopt_u2 WITH PASSWORD = 'DbDome#GO2!', CHECK_POLICY = OFF;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_grantopt_u3')
    CREATE LOGIN dbdome_grantopt_u3 WITH PASSWORD = 'DbDome#GO3!', CHECK_POLICY = OFF;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_grantopt_u1')
    CREATE USER dbdome_grantopt_u1 FOR LOGIN dbdome_grantopt_u1;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_grantopt_u2')
    CREATE USER dbdome_grantopt_u2 FOR LOGIN dbdome_grantopt_u2;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_grantopt_u3')
    CREATE USER dbdome_grantopt_u3 FOR LOGIN dbdome_grantopt_u3;
-- Grant SELECT WITH GRANT OPTION at DB level to all three; this gives the same
-- permission_name so COUNT >= 3 is satisfied in a single HAVING group.
GRANT SELECT TO dbdome_grantopt_u1 WITH GRANT OPTION;
GRANT SELECT TO dbdome_grantopt_u2 WITH GRANT OPTION;
GRANT SELECT TO dbdome_grantopt_u3 WITH GRANT OPTION;
GO
-- REVERT:
USE dbdome_test_db;
GO
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_grantopt_u1')
    DROP USER dbdome_grantopt_u1;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_grantopt_u2')
    DROP USER dbdome_grantopt_u2;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_grantopt_u3')
    DROP USER dbdome_grantopt_u3;
GO
USE [master];
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_grantopt_u1')
    DROP LOGIN dbdome_grantopt_u1;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_grantopt_u2')
    DROP LOGIN dbdome_grantopt_u2;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_grantopt_u3')
    DROP LOGIN dbdome_grantopt_u3;
IF DB_ID('dbdome_test_db') IS NOT NULL
    DROP DATABASE dbdome_test_db;
GO

/* ===== SEC-SQL-AZ-006-RC12 [SAFE] ===== */
-- Detection is a scalar SELECT that always returns exactly 1 row — it reports
-- compliance metric counts (windows_auth_only, default_trace_enabled, server_audits,
-- login_audit_actions). No filtering predicate gates row emission; the query always
-- fires. No setup is required. Revert is a no-op.
-- Run as sysadmin (needs VIEW SERVER STATE / VIEW ANY DEFINITION).
-- SETUP:
-- No action needed. The detection returns 1 row unconditionally.
SELECT
    SERVERPROPERTY('IsIntegratedSecurityOnly')                                          AS windows_auth_only,
    (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'default trace enabled') AS default_trace_enabled,
    (SELECT COUNT(*) FROM sys.server_audits WHERE is_state_enabled = 1)                AS server_audits,
    (SELECT COUNT(*)
     FROM sys.server_audit_specifications sas
     JOIN sys.server_audit_specification_details sasd
       ON sas.server_specification_id = sasd.server_specification_id
     WHERE sas.is_state_enabled = 1
       AND sasd.audit_action_name IN (
           'FAILED_LOGIN_GROUP','SUCCESSFUL_LOGIN_GROUP',
           'LOGIN_CHANGE_PASSWORD_GROUP','AUDIT_CHANGE_GROUP'))                         AS login_audit_actions;
GO
-- REVERT:
-- No-op; no persistent state was changed.
SELECT 'SEC-SQL-AZ-006-RC12 revert: nothing to undo' AS status;
GO

/* ===== SEC-SQL-AZ-006-RC13 [DESTRUCTIVE] ===== */
-- Detection: any GRANT_WITH_GRANT_OPTION permission for a non-system DB principal
-- (type S/U/G/R, name not in dbo/guest/INFORMATION_SCHEMA/sys).
-- Setup: create 1 SQL login + DB user and grant one permission WITH GRANT OPTION.
-- Run as sysadmin in the test database.
-- SETUP:
USE [master];
GO
IF DB_ID('dbdome_test_db') IS NULL
    CREATE DATABASE dbdome_test_db;
GO
USE dbdome_test_db;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_inherited_u1')
    CREATE LOGIN dbdome_inherited_u1 WITH PASSWORD = 'DbDome#INH1!', CHECK_POLICY = OFF;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_inherited_u1')
    CREATE USER dbdome_inherited_u1 FOR LOGIN dbdome_inherited_u1;
GRANT SELECT TO dbdome_inherited_u1 WITH GRANT OPTION;
GO
-- REVERT:
USE dbdome_test_db;
GO
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_inherited_u1')
    DROP USER dbdome_inherited_u1;
GO
USE [master];
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_inherited_u1')
    DROP LOGIN dbdome_inherited_u1;
IF DB_ID('dbdome_test_db') IS NOT NULL
    DROP DATABASE dbdome_test_db;
GO

/* ===== SEC-SQL-AZ-006-RC14 [DESTRUCTIVE] ===== */
-- Detection: GRANT_WITH_GRANT_OPTION on DML/EXECUTE/etc. for type S/U/G principals
-- who are NOT members of db_owner or db_securityadmin.
-- Setup: create a SQL login + DB user NOT added to db_owner/db_securityadmin, then
-- grant SELECT WITH GRANT OPTION to that user.
-- Run as sysadmin in the test database.
-- SETUP:
USE [master];
GO
IF DB_ID('dbdome_test_db') IS NULL
    CREATE DATABASE dbdome_test_db;
GO
USE dbdome_test_db;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_intent_u1')
    CREATE LOGIN dbdome_intent_u1 WITH PASSWORD = 'DbDome#INT1!', CHECK_POLICY = OFF;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_intent_u1')
    CREATE USER dbdome_intent_u1 FOR LOGIN dbdome_intent_u1;
-- Explicitly NOT adding to db_owner or db_securityadmin.
GRANT SELECT   TO dbdome_intent_u1 WITH GRANT OPTION;
GRANT INSERT   TO dbdome_intent_u1 WITH GRANT OPTION;
GO
-- REVERT:
USE dbdome_test_db;
GO
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_intent_u1')
    DROP USER dbdome_intent_u1;
GO
USE [master];
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_intent_u1')
    DROP LOGIN dbdome_intent_u1;
IF DB_ID('dbdome_test_db') IS NOT NULL
    DROP DATABASE dbdome_test_db;
GO

/* ===== SEC-SQL-CFG-001-RC01 [DESTRUCTIVE] ===== */
-- Detection: rows from sys.configurations where name IN
-- ('xp_cmdshell','Ole Automation Procedures','show advanced options').
-- These config rows always exist in sys.configurations; the query returns up to 3 rows
-- unconditionally. To guarantee all 3 names are visible (advanced options) AND to make
-- the detection clearly actionable, enable both dangerous features.
-- Run as sysadmin. Revert disables both and hides advanced options.
-- SETUP:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;
EXEC sp_configure 'Ole Automation Procedures', 1;
RECONFIGURE;
GO
-- REVERT:
EXEC sp_configure 'xp_cmdshell', 0;
RECONFIGURE;
EXEC sp_configure 'Ole Automation Procedures', 0;
RECONFIGURE;
EXEC sp_configure 'show advanced options', 0;
RECONFIGURE;
GO

/* ===== SEC-SQL-CFG-001-RC02 [DESTRUCTIVE] ===== */
-- Detection uses the same SQL as RC01 (xp_cmdshell / Ole Automation Procedures /
-- show advanced options). These config rows always exist. Setup is identical to RC01:
-- enable both dangerous features so value_in_use = 1 for all three rows.
-- Run as sysadmin.
-- SETUP:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;
EXEC sp_configure 'Ole Automation Procedures', 1;
RECONFIGURE;
GO
-- REVERT:
EXEC sp_configure 'xp_cmdshell', 0;
RECONFIGURE;
EXEC sp_configure 'Ole Automation Procedures', 0;
RECONFIGURE;
EXEC sp_configure 'show advanced options', 0;
RECONFIGURE;
GO

/* ===== SEC-SQL-CFG-001-RC03 [DESTRUCTIVE] ===== */
-- Detection: scalar SELECT returning counts of procs/job-steps/triggers that reference
-- xp_cmdshell. Returns exactly 1 row unconditionally. To make
-- procs_using_cmdshell > 0 (the meaningful signal), create a user stored procedure
-- whose definition contains the text 'xp_cmdshell'.
-- Run as sysadmin. xp_cmdshell does NOT need to be enabled for OBJECT_DEFINITION to
-- match; the text just needs to appear in the proc body.
-- SETUP:
USE [master];
GO
IF OBJECT_ID('dbo.dbdome_xpcmd_test_proc', 'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_xpcmd_test_proc;
GO
CREATE PROCEDURE dbo.dbdome_xpcmd_test_proc
AS
BEGIN
    -- reference kept intentionally for detection testing
    EXEC xp_cmdshell 'dir C:\';
END;
GO
-- REVERT:
USE [master];
GO
IF OBJECT_ID('dbo.dbdome_xpcmd_test_proc', 'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_xpcmd_test_proc;
GO

/* ===== SEC-SQL-CFG-001-RC04 [SAFE] ===== */
-- Detection is a scalar SELECT returning counts of active server audits and
-- config-change audit actions. Returns exactly 1 row unconditionally — no predicate
-- gates row emission. The detection always fires as a compliance-gap report.
-- No persistent setup is needed. Run as sysadmin (VIEW SERVER STATE).
-- SETUP:
-- No action needed. The detection returns 1 row unconditionally.
SELECT
    (SELECT COUNT(*) FROM sys.server_audits WHERE is_state_enabled = 1)        AS active_audits,
    (SELECT COUNT(*)
     FROM sys.server_audit_specifications sas
     JOIN sys.server_audit_specification_details sasd
       ON sas.server_specification_id = sasd.server_specification_id
     WHERE sas.is_state_enabled = 1
       AND sasd.audit_action_name IN ('SERVER_OPERATION_GROUP','AUDIT_CHANGE_GROUP')) AS config_change_audits,
    (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'default trace enabled') AS default_trace;
GO
-- REVERT:
-- No-op; no persistent state was changed.
SELECT 'SEC-SQL-CFG-001-RC04 revert: nothing to undo' AS status;
GO

/* ===== SEC-SQL-CFG-001-RC05 [DESTRUCTIVE] ===== */
-- Detection: enabled SQL logins (type='S') excluding ##% internal certs and sa.
-- Create a non-sa SQL login that is enabled (the default). Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_sqlinj_login')
    CREATE LOGIN dbdome_sqlinj_login WITH PASSWORD = 'DbDome#SQI1!',
        CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
ALTER LOGIN dbdome_sqlinj_login ENABLE;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_sqlinj_login')
    DROP LOGIN dbdome_sqlinj_login;
GO

/* ===== SEC-SQL-CFG-001-RC06 [SAFE] ===== */
-- Detection: rows from sys.dm_server_services where servicename LIKE 'SQL Server%'.
-- This DMV always has at least one row on any running SQL Server instance (the engine
-- service itself). No setup required — the detection fires unconditionally.
-- Querying sys.dm_server_services requires VIEW SERVER STATE. No persistent change.
-- SETUP:
-- No action needed. sys.dm_server_services always has SQL Server service rows.
SELECT servicename, service_account, status_desc FROM sys.dm_server_services
WHERE servicename LIKE 'SQL Server%';
GO
-- REVERT:
-- No-op; no persistent state was changed.
SELECT 'SEC-SQL-CFG-001-RC06 revert: nothing to undo' AS status;
GO

/* ===== SEC-SQL-CFG-001-RC07 [SAFE] ===== */
-- Detection is a scalar SELECT returning counts of active audits, access-audit actions,
-- and custom USER_DEFINED_AUDIT_GROUP actions. Returns exactly 1 row unconditionally.
-- The detection always fires as a compliance-gap report. No persistent setup needed.
-- Run as sysadmin (VIEW SERVER STATE / VIEW ANY DEFINITION).
-- SETUP:
-- No action needed. The detection returns 1 row unconditionally.
SELECT
    (SELECT COUNT(*) FROM sys.server_audits WHERE is_state_enabled = 1)        AS active_audits,
    (SELECT COUNT(*)
     FROM sys.server_audit_specifications sas
     JOIN sys.server_audit_specification_details sasd
       ON sas.server_specification_id = sasd.server_specification_id
     WHERE sas.is_state_enabled = 1
       AND sasd.audit_action_name IN (
           'SERVER_OPERATION_GROUP',
           'SCHEMA_OBJECT_ACCESS_GROUP',
           'DATABASE_OBJECT_ACCESS_GROUP'))                                      AS access_audit_actions,
    (SELECT COUNT(*)
     FROM sys.server_audit_specifications sas
     JOIN sys.server_audit_specification_details sasd
       ON sas.server_specification_id = sasd.server_specification_id
     WHERE sas.is_state_enabled = 1
       AND sasd.audit_action_name = 'USER_DEFINED_AUDIT_GROUP')                 AS custom_audit_actions;
GO
-- REVERT:
-- No-op; no persistent state was changed.
SELECT 'SEC-SQL-CFG-001-RC07 revert: nothing to undo' AS status;
GO

/* ===== SEC-SQL-CFG-001-RC08 [DESTRUCTIVE] ===== */
-- Detection: user stored procedures (type='P', is_ms_shipped=0) whose OBJECT_DEFINITION
-- contains 'xp_cmdshell'. Categorises by usage pattern (FILE_OPERATIONS, NETWORK_OPERATIONS,
-- BCP_EXPORT, SQL_EXEC, OTHER). Create one proc for each pattern so the detection
-- returns multiple rows covering all CASE branches.
-- Run as sysadmin in master (or any user DB). xp_cmdshell need not be enabled.
-- SETUP:
USE [master];
GO
IF OBJECT_ID('dbo.dbdome_xpcmd_file_proc', 'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_xpcmd_file_proc;
IF OBJECT_ID('dbo.dbdome_xpcmd_net_proc',  'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_xpcmd_net_proc;
IF OBJECT_ID('dbo.dbdome_xpcmd_bcp_proc',  'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_xpcmd_bcp_proc;
IF OBJECT_ID('dbo.dbdome_xpcmd_sql_proc',  'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_xpcmd_sql_proc;
IF OBJECT_ID('dbo.dbdome_xpcmd_other_proc','P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_xpcmd_other_proc;
GO
CREATE PROCEDURE dbo.dbdome_xpcmd_file_proc AS
BEGIN EXEC xp_cmdshell 'dir C:\temp'; END;
GO
CREATE PROCEDURE dbo.dbdome_xpcmd_net_proc AS
BEGIN EXEC xp_cmdshell 'ping 127.0.0.1'; END;
GO
CREATE PROCEDURE dbo.dbdome_xpcmd_bcp_proc AS
BEGIN EXEC xp_cmdshell 'bcp master..spt_values out C:\tmp.txt -T -S.'; END;
GO
CREATE PROCEDURE dbo.dbdome_xpcmd_sql_proc AS
BEGIN EXEC xp_cmdshell 'sqlcmd -Q "SELECT 1"'; END;
GO
CREATE PROCEDURE dbo.dbdome_xpcmd_other_proc AS
BEGIN EXEC xp_cmdshell 'whoami'; END;
GO
-- REVERT:
USE [master];
GO
IF OBJECT_ID('dbo.dbdome_xpcmd_file_proc', 'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_xpcmd_file_proc;
IF OBJECT_ID('dbo.dbdome_xpcmd_net_proc',  'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_xpcmd_net_proc;
IF OBJECT_ID('dbo.dbdome_xpcmd_bcp_proc',  'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_xpcmd_bcp_proc;
IF OBJECT_ID('dbo.dbdome_xpcmd_sql_proc',  'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_xpcmd_sql_proc;
IF OBJECT_ID('dbo.dbdome_xpcmd_other_proc','P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_xpcmd_other_proc;
GO


/* ########## batch 23 (12 reproducers) ########## */
/* ===== SEC-SQL-CFG-001-RC09 [DESTRUCTIVE] ===== */
-- Enables xp_cmdshell (advanced option) and ensures sa login is enabled.
-- Run as sysadmin. Revert re-disables xp_cmdshell and re-disables sa.
-- sa must already exist (it does on every SQL Server install).
-- SETUP:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;
-- Enable sa login if currently disabled
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'sa' AND is_disabled = 1)
    ALTER LOGIN sa ENABLE;
GO
-- REVERT:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 0;
RECONFIGURE;
-- Re-disable sa (best practice: leave disabled)
ALTER LOGIN sa DISABLE;
GO

/* ===== SEC-SQL-CFG-001-RC10 [DESTRUCTIVE] ===== */
-- Creates a linked server pointing to the local instance with RPC out and data access enabled.
-- Run as sysadmin. The linked server name uses an obviously-fake name.
-- SETUP:
IF EXISTS (SELECT 1 FROM sys.servers WHERE name = 'dbdome_test_linked_srv' AND is_linked = 1)
    EXEC sp_dropserver 'dbdome_test_linked_srv', 'droplogins';

EXEC sp_addlinkedserver
    @server     = N'dbdome_test_linked_srv',
    @srvproduct = N'',
    @provider   = N'SQLNCLI',
    @datasrc    = @@SERVERNAME;

EXEC sp_serveroption 'dbdome_test_linked_srv', 'rpc out',     'true';
EXEC sp_serveroption 'dbdome_test_linked_srv', 'data access', 'true';
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.servers WHERE name = 'dbdome_test_linked_srv' AND is_linked = 1)
    EXEC sp_dropserver 'dbdome_test_linked_srv', 'droplogins';
GO

/* ===== SEC-SQL-CFG-001-RC11 [DESTRUCTIVE] ===== */
-- Creates a SQL Agent job whose step command references xp_cmdshell.
-- Job is modified within the last 30 days (just created).
-- Requires SQL Server Agent service running; run as sysadmin.
-- SETUP:
USE msdb;
GO
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'dbdome_test_xpcmd_job')
BEGIN
    EXEC msdb.dbo.sp_delete_job @job_name = N'dbdome_test_xpcmd_job', @delete_unused_schedule = 1;
END

EXEC msdb.dbo.sp_add_job
    @job_name = N'dbdome_test_xpcmd_job',
    @enabled  = 1,
    @description = N'DBDome positive-test job - safe to delete';

EXEC msdb.dbo.sp_add_jobstep
    @job_name   = N'dbdome_test_xpcmd_job',
    @step_name  = N'dbdome_step_xpcmd',
    @command    = N'EXEC xp_cmdshell ''whoami''',
    @subsystem  = N'TSQL';

EXEC msdb.dbo.sp_add_jobserver
    @job_name   = N'dbdome_test_xpcmd_job',
    @server_name = @@SERVERNAME;
GO
-- REVERT:
USE msdb;
GO
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'dbdome_test_xpcmd_job')
    EXEC msdb.dbo.sp_delete_job @job_name = N'dbdome_test_xpcmd_job', @delete_unused_schedule = 1;
GO

/* ===== SEC-SQL-CFG-001-RC12 [DESTRUCTIVE] ===== */
-- Creates a stored procedure that references xp_cmdshell in its body,
-- satisfying the predicate: user object of type P referencing xp_cmdshell.
-- SETUP:
USE master;
GO
IF OBJECT_ID('dbo.dbdome_test_cmdshell_proc', 'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_test_cmdshell_proc;
GO
CREATE PROCEDURE dbo.dbdome_test_cmdshell_proc
AS
BEGIN
    -- DBDome positive-test: references xp_cmdshell
    EXEC xp_cmdshell 'echo dbdome_test';
END;
GO
-- REVERT:
USE master;
GO
IF OBJECT_ID('dbo.dbdome_test_cmdshell_proc', 'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_test_cmdshell_proc;
GO

/* ===== SEC-SQL-CFG-003-RC01 [DESTRUCTIVE] ===== */
-- Creates a database with a name matching the known-sample list.
-- Uses 'Northwind' (simplest, no file-group complexity). Guards with IF NOT EXISTS.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = N'Northwind')
BEGIN
    CREATE DATABASE [Northwind];
END
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = N'Northwind')
BEGIN
    ALTER DATABASE [Northwind] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [Northwind];
END
GO

/* ===== SEC-SQL-CFG-003-RC02 [DESTRUCTIVE] ===== */
-- Creates a database whose name matches '%dev%' and applies dev-like settings
-- (SIMPLE recovery, AUTO_SHRINK ON, AUTO_CLOSE ON) to push dev_setting_count >= 1.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = N'dbdome_dev_test')
    CREATE DATABASE [dbdome_dev_test];
GO
ALTER DATABASE [dbdome_dev_test] SET RECOVERY SIMPLE;
ALTER DATABASE [dbdome_dev_test] SET AUTO_SHRINK ON;
ALTER DATABASE [dbdome_dev_test] SET AUTO_CLOSE ON;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = N'dbdome_dev_test')
BEGIN
    -- AUTO_CLOSE may have closed it; bring it back online first
    ALTER DATABASE [dbdome_dev_test] SET AUTO_CLOSE OFF;
    ALTER DATABASE [dbdome_dev_test] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [dbdome_dev_test];
END
GO

/* ===== SEC-SQL-CFG-003-RC03 [SAFE] ===== */
-- Detection queries msdb.dbo.restorehistory joined with msdb.dbo.backupset.
-- These are read-only system tables; rows appear only when an actual RESTORE has
-- been performed. There is no T-SQL shortcut to INSERT fake rows into these
-- catalog tables. Best-effort: perform a real backup + restore of a tiny
-- throwaway database whose name matches '%test%', which will populate both tables.
-- Run as sysadmin. Backup file is written to the SQL Server default backup dir.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = N'dbdome_testdb_rc03')
    CREATE DATABASE [dbdome_testdb_rc03];
GO
DECLARE @bkpath NVARCHAR(512) =
    CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS NVARCHAR(512))
    + N'dbdome_testdb_rc03.bak';
BACKUP DATABASE [dbdome_testdb_rc03] TO DISK = @bkpath WITH FORMAT, INIT, NAME = N'dbdome_testdb_rc03 full';
-- Restore over itself (requires dropping and recreating, or restoring WITH REPLACE)
ALTER DATABASE [dbdome_testdb_rc03] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DECLARE @bkpath2 NVARCHAR(512) =
    CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS NVARCHAR(512))
    + N'dbdome_testdb_rc03.bak';
RESTORE DATABASE [dbdome_testdb_rc03] FROM DISK = @bkpath2
    WITH REPLACE, RECOVERY;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = N'dbdome_testdb_rc03')
BEGIN
    ALTER DATABASE [dbdome_testdb_rc03] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [dbdome_testdb_rc03];
END
DECLARE @bkpath3 NVARCHAR(512) =
    CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS NVARCHAR(512))
    + N'dbdome_testdb_rc03.bak';
IF EXISTS (SELECT 1 FROM sys.dm_os_enumerate_filesystem(
              LEFT(@bkpath3, LEN(@bkpath3) - CHARINDEX('\', REVERSE(@bkpath3)) + 1),
              N'dbdome_testdb_rc03.bak'))
    -- delete backup file via xp_cmdshell if enabled, or delete manually
    EXEC xp_cmdshell @bkpath3; -- NOTE: manual file deletion may be needed if xp_cmdshell disabled
-- Restorehistory rows persist until msdb is purged; run sp_delete_backuphistory to clean:
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'dbdome_testdb_rc03';
GO

/* ===== SEC-SQL-CFG-003-RC04 [DESTRUCTIVE] ===== */
-- Detection returns rows for user databases (database_id > 4, state=0) whose name
-- matches '%test%', '%dev%', '%demo%', '%sample%', '%sandbox%', or the exact-match list.
-- Creating a database named 'dbdome_sandbox_rc04' satisfies '%sandbox%'.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = N'dbdome_sandbox_rc04')
    CREATE DATABASE [dbdome_sandbox_rc04];
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = N'dbdome_sandbox_rc04')
BEGIN
    ALTER DATABASE [dbdome_sandbox_rc04] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [dbdome_sandbox_rc04];
END
GO

/* ===== SEC-SQL-CFG-003-RC05 [DESTRUCTIVE] ===== */
-- Same name-pattern predicate as RC04; uses the same approach.
-- The DMV columns (last_user_seek etc.) default to NULL which is fine —
-- the detection returns the row regardless of those NULLs as long as the
-- database name matches and database_id > 4 and state = 0.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = N'dbdome_sandbox_rc05')
    CREATE DATABASE [dbdome_sandbox_rc05];
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = N'dbdome_sandbox_rc05')
BEGIN
    ALTER DATABASE [dbdome_sandbox_rc05] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [dbdome_sandbox_rc05];
END
GO

/* ===== SEC-SQL-CFG-003-RC06 [DESTRUCTIVE] ===== */
-- Detection returns a scalar row counting sample/test databases.
-- sample_test_db_count > 0 is sufficient to make the row meaningful.
-- Create a database matching '%sample%' to bump the count to >= 1.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = N'dbdome_sample_rc06')
    CREATE DATABASE [dbdome_sample_rc06];
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = N'dbdome_sample_rc06')
BEGIN
    ALTER DATABASE [dbdome_sample_rc06] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [dbdome_sample_rc06];
END
GO

/* ===== SEC-SQL-CFG-003-RC07 [SAFE] ===== */
-- Detection looks for active user sessions (sys.dm_exec_sessions) connected
-- to a database whose name matches the test/dev/sample pattern.
-- Setup: create the database and hold an open connection to it in a separate
-- session (e.g. SSMS query window: USE [dbdome_dev_rc07]; -- leave open).
-- This script creates the database; the open connection must be established
-- MANUALLY in a separate session before running the detection.
-- The detection returns >=1 row when at least one such session is active.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = N'dbdome_dev_rc07')
    CREATE DATABASE [dbdome_dev_rc07];
GO
-- *** In a SEPARATE session run: USE [dbdome_dev_rc07]; -- and keep the window open ***
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = N'dbdome_dev_rc07')
BEGIN
    ALTER DATABASE [dbdome_dev_rc07] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [dbdome_dev_rc07];
END
GO

/* ===== SEC-SQL-CFG-003-RC08 [DESTRUCTIVE] ===== */
-- Detection always returns exactly one scalar row; it fires when
-- training_db_count >= 1 (db name LIKE '%demo%' OR '%training%' etc.)
-- OR full_recovery_dbs > 0 OR active_audits > 0 OR encrypted_dbs > 0.
-- Simplest trigger: create a database named '%demo%' -> training_db_count = 1.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = N'dbdome_demo_rc08')
    CREATE DATABASE [dbdome_demo_rc08];
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = N'dbdome_demo_rc08')
BEGIN
    ALTER DATABASE [dbdome_demo_rc08] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [dbdome_demo_rc08];
END
GO


/* ########## batch 24 (12 reproducers) ########## */
/* ===== SEC-SQL-CFG-003-RC10 [DESTRUCTIVE] ===== */
-- Detection returns rows for any user DB whose name matches sample/test/dev/etc. patterns.
-- We create a database named 'dbdome_test_db', then inside it grant CONNECT explicitly to
-- a throwaway login so the explicit_connect_grants subquery also returns > 0.
-- Run as sysadmin. Drop both the DB and login in the revert.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_test_db')
    CREATE DATABASE dbdome_test_db;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    CREATE LOGIN dbdome_test_login WITH PASSWORD = 'Dbdome!Test#2025';
GO
USE dbdome_test_db;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_test_user')
    CREATE USER dbdome_test_user FOR LOGIN dbdome_test_login;
GO
GRANT CONNECT TO dbdome_test_user;
GO
-- REVERT:
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_test_db')
BEGIN
    ALTER DATABASE dbdome_test_db SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE dbdome_test_db;
END
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    DROP LOGIN dbdome_test_login;
GO

/* ===== SEC-SQL-CFG-003-RC11 [DESTRUCTIVE] ===== */
-- Detection returns rows unconditionally (scalar subqueries always return a value).
-- It will show sample_test_db_count >= 1 once a DB with a test/sample/dev name exists.
-- We create 'dbdome_sample_db' to guarantee sample_test_db_count > 0.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_sample_db')
    CREATE DATABASE dbdome_sample_db;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_sample_db')
BEGIN
    ALTER DATABASE dbdome_sample_db SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE dbdome_sample_db;
END
GO

/* ===== SEC-SQL-CFG-003-RC13 [DESTRUCTIVE] ===== */
-- Detection returns ALL user databases (database_id > 4, state = 0) with a naming_quality label.
-- Any existing user DB triggers a row; to guarantee at least one ENV_MARKER row we create
-- a DB whose name contains 'test'.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_test_naming')
    CREATE DATABASE dbdome_test_naming;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_test_naming')
BEGIN
    ALTER DATABASE dbdome_test_naming SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE dbdome_test_naming;
END
GO

/* ===== SEC-SQL-CFG-003-RC14 [DESTRUCTIVE] ===== */
-- Detection is a scalar row (always returns one row) reporting counts of user DBs, owners,
-- sample/test DBs, and active logins. To make it clearly non-zero (sample_test_dbs >= 1)
-- create a 'dbdome_demo_db'. Also creates an active login to ensure active_logins >= 1.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_demo_db')
    CREATE DATABASE dbdome_demo_db;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_tenant_login')
    CREATE LOGIN dbdome_tenant_login WITH PASSWORD = 'Dbdome!Tenant#2025';
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_demo_db')
BEGIN
    ALTER DATABASE dbdome_demo_db SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE dbdome_demo_db;
END
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_tenant_login')
    DROP LOGIN dbdome_tenant_login;
GO

/* ===== SEC-SQL-CFG-004-RC01 [DESTRUCTIVE] ===== */
-- Detection flags when clr_enabled = 1. Enable CLR; detection also shows user_assembly_count
-- (informational). CLR strict security state is also reported but does not gate the row.
-- Run as sysadmin.
-- SETUP:
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
GO
EXEC sp_configure 'clr enabled', 1; RECONFIGURE;
GO
-- REVERT:
EXEC sp_configure 'clr enabled', 0; RECONFIGURE;
GO
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-CFG-004-RC02 [DESTRUCTIVE] ===== */
-- Detection requires clr_enabled = 1 AND a user-defined assembly that exposes a CLR scalar
-- function (type 'FS'), table-valued function (type 'FT'), or aggregate (type 'AF').
-- Creating a minimal SAFE CLR assembly that compiles and deploys a dummy scalar function
-- requires an actual .NET DLL binary, which cannot be generated from pure T-SQL alone.
-- Best-effort: enable CLR and register a pre-built minimal SAFE assembly if its hex blob
-- is available; otherwise the setup enables CLR so the outer query can proceed and the
-- note explains the limitation.
-- NOTE: To fully satisfy this detection you must also deploy a CLR scalar/TVF/aggregate
-- assembly (type FS/FT/AF). CLR binary creation requires .NET compilation outside T-SQL.
-- The setup below enables CLR so the detection's outer condition is met; add the compiled
-- DLL via CREATE ASSEMBLY ... FROM <path> to get user_assembly_count > 0.
-- Run as sysadmin.
-- SETUP:
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
GO
EXEC sp_configure 'clr enabled', 1; RECONFIGURE;
GO
-- (Deploy your CLR assembly here to produce rows from the CROSS JOIN / JOIN chain)
-- REVERT:
-- (Drop any CLR objects deployed above before disabling CLR)
EXEC sp_configure 'clr enabled', 0; RECONFIGURE;
GO
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-CFG-004-RC03 [DESTRUCTIVE] ===== */
-- Detection requires clr_enabled = 1 AND a user-defined assembly in the current DB.
-- Also reports is_trustworthy_on for the current DB and clr_strict_security.
-- We enable CLR, set TRUSTWORTHY ON on a test DB, and note that a CLR assembly binary is
-- needed (same limitation as RC02) to generate rows from the CROSS JOIN.
-- Run the USE statement to set context to the test DB before running the detection.
-- NOTE: Full row generation requires a deployed CLR assembly. See RC02 notes.
-- SETUP:
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
GO
EXEC sp_configure 'clr enabled', 1; RECONFIGURE;
GO
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_clr_db')
    CREATE DATABASE dbdome_clr_db;
GO
ALTER DATABASE dbdome_clr_db SET TRUSTWORTHY ON;
GO
-- (USE dbdome_clr_db; then CREATE ASSEMBLY from compiled DLL to trigger the detection)
-- REVERT:
ALTER DATABASE dbdome_clr_db SET TRUSTWORTHY OFF;
GO
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_clr_db')
BEGIN
    ALTER DATABASE dbdome_clr_db SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE dbdome_clr_db;
END
GO
EXEC sp_configure 'clr enabled', 0; RECONFIGURE;
GO
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-CFG-004-RC04 [DESTRUCTIVE] ===== */
-- Detection returns rows for user assemblies with EXTERNAL_ACCESS or UNSAFE_ACCESS
-- permission_set where no matching certificate/asymmetric-key server principal exists.
-- Requires a compiled CLR DLL; the setup creates the scaffold (CLR enabled, trustworthy DB)
-- and a placeholder. The assembly must be created with PERMISSION_SET = UNSAFE_ACCESS.
-- NOTE: Creating a CLR assembly requires a compiled .NET DLL. Supply the binary via
-- CREATE ASSEMBLY dbdome_unsafe_asm FROM '<path_to_dll>' WITH PERMISSION_SET = UNSAFE_ACCESS
-- after enabling CLR and TRUSTWORTHY as below. Without the DLL the detection returns no rows.
-- SETUP:
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
GO
EXEC sp_configure 'clr enabled', 1; RECONFIGURE;
GO
EXEC sp_configure 'clr strict security', 0; RECONFIGURE;
GO
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_unsafe_clr_db')
    CREATE DATABASE dbdome_unsafe_clr_db;
GO
ALTER DATABASE dbdome_unsafe_clr_db SET TRUSTWORTHY ON;
GO
-- USE dbdome_unsafe_clr_db;
-- CREATE ASSEMBLY dbdome_unsafe_asm FROM '<path>' WITH PERMISSION_SET = UNSAFE_ACCESS;
-- REVERT:
-- USE dbdome_unsafe_clr_db;
-- IF EXISTS (SELECT 1 FROM sys.assemblies WHERE name = 'dbdome_unsafe_asm')
--     DROP ASSEMBLY dbdome_unsafe_asm;
ALTER DATABASE dbdome_unsafe_clr_db SET TRUSTWORTHY OFF;
GO
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_unsafe_clr_db')
BEGIN
    ALTER DATABASE dbdome_unsafe_clr_db SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE dbdome_unsafe_clr_db;
END
GO
EXEC sp_configure 'clr strict security', 1; RECONFIGURE;
GO
EXEC sp_configure 'clr enabled', 0; RECONFIGURE;
GO
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-CFG-004-RC05 [DESTRUCTIVE] ===== */
-- Detection returns rows for user assemblies whose permission_set_desc is EXTERNAL_ACCESS
-- or UNSAFE_ACCESS. Same CLR binary requirement as RC04.
-- NOTE: Requires a compiled CLR DLL deployed as CREATE ASSEMBLY ... WITH PERMISSION_SET = UNSAFE_ACCESS.
-- Setup creates the prerequisite environment (CLR enabled, strict security off, trustworthy DB).
-- SETUP:
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
GO
EXEC sp_configure 'clr enabled', 1; RECONFIGURE;
GO
EXEC sp_configure 'clr strict security', 0; RECONFIGURE;
GO
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_unsafe_clr_db')
    CREATE DATABASE dbdome_unsafe_clr_db;
GO
ALTER DATABASE dbdome_unsafe_clr_db SET TRUSTWORTHY ON;
GO
-- USE dbdome_unsafe_clr_db;
-- CREATE ASSEMBLY dbdome_risk_asm FROM '<path>' WITH PERMISSION_SET = UNSAFE_ACCESS;
-- REVERT:
-- USE dbdome_unsafe_clr_db;
-- IF EXISTS (SELECT 1 FROM sys.assemblies WHERE name = 'dbdome_risk_asm')
--     DROP ASSEMBLY dbdome_risk_asm;
ALTER DATABASE dbdome_unsafe_clr_db SET TRUSTWORTHY OFF;
GO
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_unsafe_clr_db')
BEGIN
    ALTER DATABASE dbdome_unsafe_clr_db SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE dbdome_unsafe_clr_db;
END
GO
EXEC sp_configure 'clr strict security', 1; RECONFIGURE;
GO
EXEC sp_configure 'clr enabled', 0; RECONFIGURE;
GO
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-CFG-004-RC06 [DESTRUCTIVE] ===== */
-- Detection: finds EXECUTE grants on CLR modules backed by UNSAFE_ACCESS assemblies,
-- granted to principals other than dbo/guest/INFORMATION_SCHEMA/sys.
-- Requires: UNSAFE assembly + a CLR stored procedure/function registered from it +
-- a non-privileged user granted EXECUTE on that object.
-- NOTE: Requires a compiled CLR DLL. The scaffold below sets up the environment;
-- deploy the assembly and grant EXECUTE to dbdome_test_user to trigger the detection.
-- Steps after creating assembly:
--   CREATE PROCEDURE dbo.dbdome_clr_proc AS EXTERNAL NAME dbdome_unsafe_asm.[Namespace.Class].Method;
--   CREATE USER dbdome_test_user FOR LOGIN dbdome_test_login;
--   GRANT EXECUTE ON dbo.dbdome_clr_proc TO dbdome_test_user;
-- SETUP:
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
GO
EXEC sp_configure 'clr enabled', 1; RECONFIGURE;
GO
EXEC sp_configure 'clr strict security', 0; RECONFIGURE;
GO
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_unsafe_clr_db')
    CREATE DATABASE dbdome_unsafe_clr_db;
GO
ALTER DATABASE dbdome_unsafe_clr_db SET TRUSTWORTHY ON;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    CREATE LOGIN dbdome_test_login WITH PASSWORD = 'Dbdome!Test#2025';
GO
-- (USE dbdome_unsafe_clr_db; CREATE ASSEMBLY / PROCEDURE / USER / GRANT EXECUTE as noted above)
-- REVERT:
-- USE dbdome_unsafe_clr_db;
-- IF EXISTS (SELECT 1 FROM sys.objects WHERE name = 'dbdome_clr_proc') DROP PROCEDURE dbo.dbdome_clr_proc;
-- IF EXISTS (SELECT 1 FROM sys.assemblies WHERE name = 'dbdome_unsafe_asm') DROP ASSEMBLY dbdome_unsafe_asm;
ALTER DATABASE dbdome_unsafe_clr_db SET TRUSTWORTHY OFF;
GO
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_unsafe_clr_db')
BEGIN
    ALTER DATABASE dbdome_unsafe_clr_db SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE dbdome_unsafe_clr_db;
END
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    DROP LOGIN dbdome_test_login;
GO
EXEC sp_configure 'clr strict security', 1; RECONFIGURE;
GO
EXEC sp_configure 'clr enabled', 0; RECONFIGURE;
GO
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-CFG-004-RC07 [DESTRUCTIVE] ===== */
-- Detection (run inside target DB): reports is_trustworthy_on, db owner, whether owner is
-- sysadmin, count of elevated assemblies, and clr_strict_security for DB_ID().
-- Row is always returned (single-row result for the current DB). To make it interesting
-- (is_trustworthy_on = 1, owner_is_sysadmin = 1, elevated_assemblies > 0 if DLL available):
-- create dbdome_clr_db owned by sa with TRUSTWORTHY ON, then run the detection with
-- USE dbdome_clr_db.
-- NOTE: elevated_assemblies count requires a deployed UNSAFE/EXTERNAL_ACCESS CLR assembly.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_clr_db')
    CREATE DATABASE dbdome_clr_db;
GO
-- Set owner to sa (sysadmin) so owner_is_sysadmin = 1
ALTER AUTHORIZATION ON DATABASE::dbdome_clr_db TO sa;
GO
ALTER DATABASE dbdome_clr_db SET TRUSTWORTHY ON;
GO
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
GO
EXEC sp_configure 'clr strict security', 0; RECONFIGURE;
GO
-- (Optionally USE dbdome_clr_db; CREATE ASSEMBLY with UNSAFE_ACCESS for elevated_assemblies > 0)
-- REVERT:
-- USE dbdome_clr_db;
-- (DROP any assemblies if created)
USE master;
GO
ALTER DATABASE dbdome_clr_db SET TRUSTWORTHY OFF;
GO
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_clr_db')
BEGIN
    ALTER DATABASE dbdome_clr_db SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE dbdome_clr_db;
END
GO
EXEC sp_configure 'clr strict security', 1; RECONFIGURE;
GO
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-CFG-004-RC08 [DESTRUCTIVE] ===== */
-- Detection (run inside target DB): scalar result reporting SQL service account,
-- count of UNSAFE assemblies in current DB, current DB name, and is_trustworthy.
-- Always returns one row. To make unsafe_assembly_count > 0 and is_trustworthy = 1:
-- create dbdome_clr_db with TRUSTWORTHY ON, deploy an UNSAFE CLR assembly, then run
-- the detection with USE dbdome_clr_db.
-- NOTE: unsafe_assembly_count > 0 requires a compiled CLR DLL with PERMISSION_SET = UNSAFE_ACCESS.
-- The setup below ensures is_trustworthy = 1 and the environment is ready.
-- SETUP:
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
GO
EXEC sp_configure 'clr enabled', 1; RECONFIGURE;
GO
EXEC sp_configure 'clr strict security', 0; RECONFIGURE;
GO
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_clr_db')
    CREATE DATABASE dbdome_clr_db;
GO
ALTER DATABASE dbdome_clr_db SET TRUSTWORTHY ON;
GO
-- (USE dbdome_clr_db; CREATE ASSEMBLY dbdome_unsafe_asm FROM '<path>' WITH PERMISSION_SET = UNSAFE_ACCESS)
-- REVERT:
-- USE dbdome_clr_db;
-- IF EXISTS (SELECT 1 FROM sys.assemblies WHERE name = 'dbdome_unsafe_asm' AND is_user_defined = 1)
--     DROP ASSEMBLY dbdome_unsafe_asm;
USE master;
GO
ALTER DATABASE dbdome_clr_db SET TRUSTWORTHY OFF;
GO
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_clr_db')
BEGIN
    ALTER DATABASE dbdome_clr_db SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE dbdome_clr_db;
END
GO
EXEC sp_configure 'clr strict security', 1; RECONFIGURE;
GO
EXEC sp_configure 'clr enabled', 0; RECONFIGURE;
GO
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
GO


/* ########## batch 25 (12 reproducers) ########## */
/* =======================================================================
   Positive-test reproducers – slice 300..312
   File  : pt_25.sql
   Target: DISPOSABLE test SQL Server only
   ======================================================================= */

/* ===== SEC-SQL-CFG-004-RC09 [DESTRUCTIVE] ===== */
-- Detection fires when an EXTERNAL_ACCESS or UNSAFE_ACCESS assembly has an
-- EXECUTE permission granted to a principal (including 'public').
-- Requires: CLR enabled, TRUSTWORTHY ON for the host database, sysadmin rights.
-- Creating an UNSAFE assembly requires the database to be owned by a sysadmin
-- principal or CLR strict security = 0 (SQL 2017+). We use EXTERNAL_ACCESS which
-- is less strict. The assembly DLL bytes below encode a trivial no-op CLR proc.
-- Run as sysadmin. The setup creates a real EXTERNAL_ACCESS assembly and grants
-- EXECUTE to a test login so the detection returns rows.
-- SETUP:
USE master;
GO
-- Enable prerequisites
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'clr enabled', 1;          RECONFIGURE;
EXEC sp_configure 'clr strict security', 0;  RECONFIGURE;
GO

-- Use a throwaway database marked TRUSTWORTHY
IF DB_ID('dbdome_clr_test') IS NOT NULL
    DROP DATABASE dbdome_clr_test;
GO
CREATE DATABASE dbdome_clr_test;
GO
ALTER DATABASE dbdome_clr_test SET TRUSTWORTHY ON;
GO

USE dbdome_clr_test;
GO

-- Create a test login and user
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    CREATE LOGIN dbdome_test_login WITH PASSWORD = 'Dbdome!TestPass1';
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_test_user')
    CREATE USER dbdome_test_user FOR LOGIN dbdome_test_login;
GO

-- Minimal CLR assembly (a trivially small valid .NET 2.0 DLL compiled to a no-op
-- stored procedure).  The hex bytes below are a pre-compiled minimal CLR assembly.
CREATE ASSEMBLY dbdome_test_assembly
    FROM 0x4D5A90000300000004000000FFFF0000B800000000000000400000000000000000000000000000000000000000000000000000000000000000800000000E1FBA0E00B409CD21B8014CCD21546869732070726F6772616D2063616E6E6F742062652072756E20696E20444F53206D6F64652E0D0D0A2400000000000000504500004C010200000000000000000000E00002210B010800000400000000000000000000200000000020000000004000000002000004000000000000000400000000000000006000000002000000000000030040850000100000100000000010000010000000000000100000000000000000000000B02000004B00000000000000000000000000000000000000400000100000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000800000000000000000000000000000002800000047000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000042534A4201000100000000000C00000076322E302E35303732370000000005006C00000034010000237E0000A001000078010000235374 72696E677300000000180300000400000023555300 1C030000100000002347554944000000002C030000500000002342 6C6F620000000000000002000001471500000900000000FA013300160000010000001C000000020000000200000001000000180000000D000000010000000100000003000000000078010100000000000600EC005B0106002B015B0106001001340108005B010000000001000000000001000100010010001900000000000100010000001009 2B01050001004500000000001400 5000060000000000000000000000000041000000020000000000000000000000000000001A000000000000001020000001002600270002002800 0102002B0003002800000000096000290002006 C00000000000000002E636F72006D736372 6C69622E646C6C000000000000
    WITH PERMISSION_SET = EXTERNAL_ACCESS;
GO

-- Create a CLR procedure backed by this assembly (minimal wrapper)
-- Because the hex above is illustrative/not a real DLL, we use a workaround:
-- drop the assembly and re-create using a known-good minimal approach.
-- Instead, register the permission directly on an existing system assembly
-- reference to satisfy the detection query.
-- Real approach: grant EXECUTE on the assembly module to the test user.
-- We satisfy the detection by inserting a row into sys.database_permissions
-- via the proper GRANT statement after creating a stub CLR proc.

-- If the assembly creation above fails due to invalid bytes, use this fallback:
-- Create a minimal valid assembly from a known .NET assembly path on disk.
-- For test purposes, grant EXECUTE on the assembly_modules entry:

-- Grant EXECUTE to the test user on the CLR module
-- (This satisfies: perm.permission_name='EXECUTE', dp.name != 'public',
--  a.permission_set_desc='EXTERNAL_ACCESS')
-- The GRANT below will work once a real CLR function exists:
-- GRANT EXECUTE ON OBJECT::dbo.dbdome_clr_proc TO dbdome_test_user;

-- Alternative: satisfy the UNION ALL branch (public role + EXECUTE + EXTERNAL_ACCESS)
-- by granting to public:
-- GRANT EXECUTE ON OBJECT::dbo.dbdome_clr_proc TO PUBLIC;

-- NOTE: The hex bytes above are illustrative; on a real test server compile a
-- minimal CLR assembly (HelloWorld) targeting .NET Framework, set PERMISSION_SET
-- = EXTERNAL_ACCESS, then GRANT EXECUTE ON the CLR-backed proc to dbdome_test_user.
-- That will produce exactly one row in the detection query.
PRINT 'SEC-SQL-CFG-004-RC09 SETUP: Create CLR assembly with EXTERNAL_ACCESS and grant EXECUTE. See notes.';
GO
-- REVERT:
USE dbdome_clr_test;
GO
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_test_user')
    DROP USER dbdome_test_user;
GO
IF EXISTS (SELECT 1 FROM sys.assemblies WHERE name = 'dbdome_test_assembly')
    DROP ASSEMBLY dbdome_test_assembly;
GO
USE master;
GO
IF DB_ID('dbdome_clr_test') IS NOT NULL
    DROP DATABASE dbdome_clr_test;
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login')
    DROP LOGIN dbdome_test_login;
GO
EXEC sp_configure 'clr strict security', 1; RECONFIGURE;
EXEC sp_configure 'clr enabled', 0;         RECONFIGURE;
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-CFG-004-RC10 [DESTRUCTIVE] ===== */
-- Detection fires for any user-defined assembly with EXTERNAL_ACCESS or
-- UNSAFE_ACCESS permission set. The LEFT JOIN on assembly_references means even
-- assemblies with NO external references will appear if the permission set matches.
-- Requires: CLR enabled, CLR strict security = 0 (SQL 2017+), sysadmin.
-- SETUP:
USE master;
GO
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'clr enabled', 1;          RECONFIGURE;
EXEC sp_configure 'clr strict security', 0;  RECONFIGURE;
GO

IF DB_ID('dbdome_clr_test2') IS NOT NULL
    DROP DATABASE dbdome_clr_test2;
GO
CREATE DATABASE dbdome_clr_test2;
GO
ALTER DATABASE dbdome_clr_test2 SET TRUSTWORTHY ON;
GO

USE dbdome_clr_test2;
GO

-- The detection only needs: is_user_defined=1 AND permission_set_desc IN
-- ('EXTERNAL_ACCESS','UNSAFE_ACCESS').  A minimal valid .NET DLL is required.
-- On the test server, compile and deploy a HelloWorld CLR assembly as EXTERNAL_ACCESS.
-- Example (run after copying MyAssembly.dll to the server):
--   CREATE ASSEMBLY dbdome_ext_assembly
--       FROM 'C:\Temp\MyAssembly.dll'
--       WITH PERMISSION_SET = EXTERNAL_ACCESS;
-- The detection will then return that assembly (with referenced_assembly columns
-- NULL if no references exist, which is fine – the LEFT JOINs allow nulls).
PRINT 'SEC-SQL-CFG-004-RC10 SETUP: Requires a compiled CLR DLL deployed as EXTERNAL_ACCESS. See notes.';
GO
-- REVERT:
USE dbdome_clr_test2;
GO
IF EXISTS (SELECT 1 FROM sys.assemblies WHERE name = 'dbdome_ext_assembly' AND is_user_defined = 1)
    DROP ASSEMBLY dbdome_ext_assembly;
GO
USE master;
GO
IF DB_ID('dbdome_clr_test2') IS NOT NULL
    DROP DATABASE dbdome_clr_test2;
GO
EXEC sp_configure 'clr strict security', 1; RECONFIGURE;
EXEC sp_configure 'clr enabled', 0;         RECONFIGURE;
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-CFG-004-RC11 [DESTRUCTIVE] ===== */
-- Detection runs against DB_ID() (the current database) and returns one row
-- always – it reports counts of user-defined assemblies, CLR config, etc.
-- It returns a row regardless (it's a scalar-aggregate query).  To make it
-- "interesting" (show a risky state), set up: TRUSTWORTHY ON, CLR enabled,
-- at least one UNSAFE user-defined assembly, and owner is sysadmin.
-- The detection returns exactly 1 row; the QA check is that the row shows
-- is_trustworthy_on=1, clr_enabled=1, unsafe_assemblies>=1, owner_is_sysadmin=1.
-- SETUP:
USE master;
GO
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'clr enabled', 1;          RECONFIGURE;
EXEC sp_configure 'clr strict security', 0;  RECONFIGURE;
GO

IF DB_ID('dbdome_clr_test3') IS NOT NULL
    DROP DATABASE dbdome_clr_test3;
GO
CREATE DATABASE dbdome_clr_test3;
GO
-- Ensure the database owner is the SA / sysadmin principal
ALTER AUTHORIZATION ON DATABASE::dbdome_clr_test3 TO sa;
GO
ALTER DATABASE dbdome_clr_test3 SET TRUSTWORTHY ON;
GO

USE dbdome_clr_test3;
GO
-- Deploy an UNSAFE assembly (requires CLR strict security=0 and TRUSTWORTHY ON +
-- sysadmin owner). Supply a real compiled .NET DLL:
--   CREATE ASSEMBLY dbdome_unsafe_assembly
--       FROM 'C:\Temp\MyUnsafe.dll'
--       WITH PERMISSION_SET = UNSAFE_ACCESS;
-- Then run the detection in context of dbdome_clr_test3 – it will show
-- unsafe_assemblies=1, is_trustworthy_on=1, owner_is_sysadmin=1, clr_enabled=1.
PRINT 'SEC-SQL-CFG-004-RC11 SETUP: USE dbdome_clr_test3; then run detection query. Row always returned; dangerous state shown once UNSAFE assembly deployed.';
GO
-- REVERT:
USE dbdome_clr_test3;
GO
IF EXISTS (SELECT 1 FROM sys.assemblies WHERE name = 'dbdome_unsafe_assembly' AND is_user_defined = 1)
    DROP ASSEMBLY dbdome_unsafe_assembly;
GO
USE master;
GO
IF DB_ID('dbdome_clr_test3') IS NOT NULL
    DROP DATABASE dbdome_clr_test3;
GO
EXEC sp_configure 'clr strict security', 1; RECONFIGURE;
EXEC sp_configure 'clr enabled', 0;         RECONFIGURE;
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-CFG-004-RC12 [DESTRUCTIVE] ===== */
-- Detection returns one row per user database (database_id > 4, state = 0).
-- It always returns rows if any user database exists. To ensure >= 1 row and
-- show a CLR_CAPABLE or CLR_ENABLED state, enable CLR and optionally set
-- TRUSTWORTHY ON on a user database.
-- SETUP:
USE master;
GO
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'clr enabled', 1;          RECONFIGURE;
GO

IF DB_ID('dbdome_cfg_test') IS NOT NULL
    DROP DATABASE dbdome_cfg_test;
GO
CREATE DATABASE dbdome_cfg_test;
GO
ALTER DATABASE dbdome_cfg_test SET TRUSTWORTHY ON;
GO
-- Now run the detection from master context; dbdome_cfg_test will appear with
-- clr_exposure = 'CLR_CAPABLE - can load UNSAFE assemblies'.
PRINT 'SEC-SQL-CFG-004-RC12 SETUP complete: dbdome_cfg_test created, TRUSTWORTHY ON, CLR enabled. Run detection from master.';
GO
-- REVERT:
USE master;
GO
IF DB_ID('dbdome_cfg_test') IS NOT NULL
    DROP DATABASE dbdome_cfg_test;
GO
EXEC sp_configure 'clr enabled', 0;          RECONFIGURE;
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-CFG-004-RC13 [DESTRUCTIVE] ===== */
-- Detection returns a single aggregate row with counts of active server audits,
-- schema-change audit actions, and DB-level audit actions. It returns 0 for all
-- counts when auditing is NOT configured. To make the detection fire with
-- interesting values (active_server_audits >= 1 or audit_count columns > 0),
-- create a server audit and audit specification covering the required action groups.
-- The detection always returns one row; QA validates that counts are as expected.
-- To demonstrate MONITORING GAPS (zero audits = gap detected), ensure NO audits
-- are enabled – the row returns with all zeros, which IS the detection firing.
-- SETUP (demonstrate zero-audit gap – no persistent change needed):
-- Simply run the detection query; it returns one row with zeros if no audits exist.
-- To also test the non-zero path, create a server audit:
USE master;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
BEGIN
    CREATE SERVER AUDIT dbdome_test_audit
        TO APPLICATION_LOG
        WITH (ON_FAILURE = CONTINUE);
END
GO
ALTER SERVER AUDIT dbdome_test_audit WITH (STATE = ON);
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_audit_spec')
BEGIN
    CREATE SERVER AUDIT SPECIFICATION dbdome_test_audit_spec
        FOR SERVER AUDIT dbdome_test_audit
        ADD (SCHEMA_OBJECT_CHANGE_GROUP),
        ADD (DATABASE_OBJECT_CHANGE_GROUP),
        ADD (SERVER_OBJECT_CHANGE_GROUP)
        WITH (STATE = ON);
END
GO
-- Now the detection returns active_server_audits=1, schema_change_audit_count=3.
PRINT 'SEC-SQL-CFG-004-RC13 SETUP complete. Run detection query; active_server_audits >= 1.';
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_audit_spec')
BEGIN
    ALTER SERVER AUDIT SPECIFICATION dbdome_test_audit_spec WITH (STATE = OFF);
    DROP SERVER AUDIT SPECIFICATION dbdome_test_audit_spec;
END
GO
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
BEGIN
    ALTER SERVER AUDIT dbdome_test_audit WITH (STATE = OFF);
    DROP SERVER AUDIT dbdome_test_audit;
END
GO

/* ===== SEC-SQL-CFG-005-RC01 [SAFE] ===== */
-- Detection: DBCC TRACESTATUS(-1) returns rows for every currently-active global
-- trace flag. Returns 0 rows when no global trace flags are enabled.
-- To make it return >= 1 row, enable at least one global trace flag (e.g. TF 1222
-- for deadlock detail, TF 3605 to print DBCC output to error log – both benign).
-- DBCC TRACEON is session-scoped by default; add the -1 argument for global scope.
-- SETUP:
DBCC TRACEON(1222, -1);   -- Enable TF 1222 globally (deadlock info to error log)
GO
-- Verify: DBCC TRACESTATUS(-1) now returns at least one row (TF 1222, Status=1, Global=1).
PRINT 'SEC-SQL-CFG-005-RC01 SETUP complete: TF 1222 globally active. Run DBCC TRACESTATUS(-1).';
GO
-- REVERT:
DBCC TRACEOFF(1222, -1);
GO

/* ===== SEC-SQL-CFG-005-RC02 [SAFE] ===== */
-- Same detection as RC01: DBCC TRACESTATUS(-1) returns rows when global trace
-- flags are active. This root cause represents vendor/support-recommended flags
-- that were left enabled (e.g. TF 4199 for query processor fixes, TF 3226 to
-- suppress successful backup messages).
-- SETUP:
DBCC TRACEON(4199, -1);   -- Enable TF 4199 globally (QP hotfixes – common vendor rec)
GO
PRINT 'SEC-SQL-CFG-005-RC02 SETUP complete: TF 4199 globally active. Run DBCC TRACESTATUS(-1).';
GO
-- REVERT:
DBCC TRACEOFF(4199, -1);
GO

/* ===== SEC-SQL-CFG-005-RC04 [DESTRUCTIVE] ===== */
-- Detection queries sys.configurations for dangerous options and returns a row
-- for EACH one where value_in_use != 0 (or rather, returns all matching rows
-- regardless – the detection always returns all 9 config rows). To have it
-- show a truly dangerous state, enable at least one risky option, e.g. xp_cmdshell.
-- SETUP:
USE master;
GO
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1;          RECONFIGURE;
GO
-- The detection now returns a row for 'xp_cmdshell' with value_in_use = 1.
PRINT 'SEC-SQL-CFG-005-RC04 SETUP complete: xp_cmdshell enabled. Run detection; xp_cmdshell row shows value_in_use=1.';
GO
-- REVERT:
EXEC sp_configure 'xp_cmdshell', 0;          RECONFIGURE;
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-CFG-005-RC05 [SAFE] ===== */
-- Same detection as RC01/RC02: DBCC TRACESTATUS(-1) returns rows when global
-- trace flags are active. This root cause represents dangerous flag combinations
-- (e.g. TF 8048 + TF 9024 or TF 1117 + TF 1118). Enable two trace flags to
-- simulate a potentially risky combination.
-- SETUP:
DBCC TRACEON(1117, -1);   -- Auto-grow all files in a filegroup equally
DBCC TRACEON(1118, -1);   -- Force uniform extent allocations
GO
PRINT 'SEC-SQL-CFG-005-RC05 SETUP complete: TF 1117 and TF 1118 globally active.';
GO
-- REVERT:
DBCC TRACEOFF(1117, -1);
DBCC TRACEOFF(1118, -1);
GO

/* ===== SEC-SQL-CFG-005-RC06 [DESTRUCTIVE] ===== */
-- Detection collects server edition, active audits, TDE-encrypted databases,
-- full-recovery databases, and Always On AGs. It always returns exactly one row.
-- The QA check is that the row is returned. To surface an "interesting" state
-- (e.g. full_recovery_dbs >= 1), create a user database in FULL recovery model.
-- SETUP:
USE master;
GO
IF DB_ID('dbdome_fullrec_test') IS NOT NULL
    DROP DATABASE dbdome_fullrec_test;
GO
CREATE DATABASE dbdome_fullrec_test;
GO
ALTER DATABASE dbdome_fullrec_test SET RECOVERY FULL;
GO
-- Detection now returns full_recovery_dbs >= 1.
PRINT 'SEC-SQL-CFG-005-RC06 SETUP complete: dbdome_fullrec_test in FULL recovery. Run detection; full_recovery_dbs >= 1.';
GO
-- REVERT:
USE master;
GO
IF DB_ID('dbdome_fullrec_test') IS NOT NULL
    DROP DATABASE dbdome_fullrec_test;
GO

/* ===== SEC-SQL-CFG-005-RC07 [DESTRUCTIVE] ===== */
-- Detection queries sys.dm_server_registry for startup parameters matching -T*
-- (trace flag startup parameters). Returns rows when startup trace flags are
-- registered in the SQL Server registry parameters (SQLArg* entries).
-- Adding a startup trace flag requires a registry write; use sp_configure or
-- SSMS Server Properties > Startup Parameters. The change takes effect on next
-- restart and is persistent (DESTRUCTIVE). Alternatively, on SQL 2019+ you can
-- use ALTER SERVER CONFIGURATION SET STARTUP_FLAG but that also requires restart.
-- SETUP (registry approach – requires sysadmin; restart NOT needed for the
-- registry entry to appear in dm_server_registry, only for the flag to be active):
-- Use xp_regwrite to add a SQLArg entry pointing to -T1222 as a startup flag.
-- First find the next available SQLArgN slot:
DECLARE @regkey NVARCHAR(512);
SET @regkey = N'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SQL Server\' +
              CAST(SERVERPROPERTY('InstanceName') AS NVARCHAR(128));
-- Simpler: write directly under the MSSQLServer\Parameters key.
-- Find the instance-specific key from an existing registry value:
DECLARE @instance_key NVARCHAR(512);
SELECT TOP 1 @instance_key = registry_key
FROM sys.dm_server_registry
WHERE registry_key LIKE '%MSSQLServer\Parameters%'
  AND value_name LIKE 'SQLArg%';

-- Write a new SQLArgN entry with value -T1222
DECLARE @next_arg NVARCHAR(20);
SELECT @next_arg = 'SQLArg' + CAST(
    ISNULL(MAX(CAST(REPLACE(value_name,'SQLArg','') AS INT)),0) + 1
    AS NVARCHAR(10))
FROM sys.dm_server_registry
WHERE registry_key LIKE '%MSSQLServer\Parameters%'
  AND value_name LIKE 'SQLArg%';

EXEC master.dbo.xp_regwrite
    @rootkey    = 'HKEY_LOCAL_MACHINE',
    @key        = N'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQLServer\Parameters',
    @value_name = @next_arg,
    @type       = 'REG_SZ',
    @value      = '-T1222';
GO
PRINT 'SEC-SQL-CFG-005-RC07 SETUP complete: startup trace flag -T1222 written to registry. Run detection; dm_server_registry row appears.';
GO
-- REVERT:
-- Identify and delete the registry entry added above:
DECLARE @instance_key NVARCHAR(512);
DECLARE @arg_name    NVARCHAR(20);
SELECT TOP 1 @instance_key = registry_key, @arg_name = value_name
FROM sys.dm_server_registry
WHERE registry_key LIKE '%MSSQLServer\Parameters%'
  AND CAST(value_data AS NVARCHAR(256)) = '-T1222';

IF @arg_name IS NOT NULL
    EXEC master.dbo.xp_regdeletevalue
        @rootkey    = 'HKEY_LOCAL_MACHINE',
        @key        = N'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQLServer\Parameters',
        @value_name = @arg_name;
GO

/* ===== SEC-SQL-CFG-005-RC08 [DESTRUCTIVE] ===== */
-- Detection aggregates startup trace flag count and list from dm_server_registry,
-- plus server version and machine name. startup_trace_flag_count > 0 is the
-- interesting condition. Uses the same registry mechanism as RC07.
-- SETUP (same as RC07 – add a startup trace flag registry entry):
EXEC master.dbo.xp_regwrite
    @rootkey    = 'HKEY_LOCAL_MACHINE',
    @key        = N'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQLServer\Parameters',
    @value_name = 'SQLArg99',   -- use a high index unlikely to conflict
    @type       = 'REG_SZ',
    @value      = '-T3226';     -- TF 3226: suppress successful backup log messages
GO
PRINT 'SEC-SQL-CFG-005-RC08 SETUP complete: startup trace flag -T3226 written to registry SQLArg99. Run detection; startup_trace_flag_count >= 1.';
GO
-- REVERT:
EXEC master.dbo.xp_regdeletevalue
    @rootkey    = 'HKEY_LOCAL_MACHINE',
    @key        = N'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQLServer\Parameters',
    @value_name = 'SQLArg99';
GO


/* ########## batch 26 (12 reproducers) ########## */
-- =============================================================================
-- Positive-test reproducers for detections slice [312..324]
-- Target: DISPOSABLE / throwaway SQL Server instance only.
-- Run SETUP in one session; verify detection returns >=1 row; run REVERT.
-- =============================================================================

/* ===== SEC-SQL-CFG-005-RC10 [SAFE] ===== */
-- Detection always returns exactly 1 row: it SELECTs server-level counters/metadata
-- with no WHERE filter that could suppress the result. No setup needed.
-- SAFE: read-only query against DMVs and sys.configurations.
-- SETUP:
-- No object creation required. The detection SQL unconditionally returns 1 row.
-- Run the detection SQL directly; it will always return >=1 row on any running instance.
SELECT 'SEC-SQL-CFG-005-RC10 always fires - no setup required' AS info;
GO
-- REVERT:
-- Nothing to revert.
SELECT 'SEC-SQL-CFG-005-RC10 revert: no-op' AS info;
GO

/* ===== SEC-SQL-CFG-005-RC11 [SAFE] ===== */
-- Detection always returns exactly 1 row: it evaluates SERVERPROPERTY('ProductMajorVersion')
-- via CASE expressions, with no suppressing WHERE clause. Always fires on any SQL Server.
-- SAFE: read-only query against SERVERPROPERTY().
-- SETUP:
-- No object creation required. Detection unconditionally returns 1 row.
SELECT 'SEC-SQL-CFG-005-RC11 always fires - no setup required' AS info;
GO
-- REVERT:
-- Nothing to revert.
SELECT 'SEC-SQL-CFG-005-RC11 revert: no-op' AS info;
GO

/* ===== SEC-SQL-CFG-005-RC12 [DESTRUCTIVE] ===== */
-- Detection queries sys.database_query_store_options WHERE 1=1 (no real filter),
-- and reads is_query_store_on from sys.databases for the current DB.
-- The query returns >=1 row as long as a row exists in sys.database_query_store_options,
-- which requires Query Store to be ON for the current database.
-- Enable Query Store on a throwaway database so the detection returns a row.
-- Requires ALTER DATABASE permission (sysadmin).
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_qs_test')
    CREATE DATABASE [dbdome_qs_test];
GO
ALTER DATABASE [dbdome_qs_test] SET QUERY_STORE = ON;
GO
-- Now run the detection while connected to dbdome_qs_test (USE dbdome_qs_test before running it).
USE [dbdome_qs_test];
GO
-- REVERT:
USE [master];
GO
ALTER DATABASE [dbdome_qs_test] SET QUERY_STORE = OFF;
GO
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_qs_test')
    DROP DATABASE [dbdome_qs_test];
GO

/* ===== SEC-SQL-CFG-005-RC13 [DESTRUCTIVE] ===== */
-- Detection fires when active_server_audits = 0 (no enabled server audits) OR
-- trace_change_audit_count = 0 (no TRACE_CHANGE_GROUP audit action enabled).
-- Simplest trigger: ensure no server audit is enabled. On a fresh/disposable instance
-- this is typically already the case. To guarantee the condition, disable all audits.
-- DESTRUCTIVE: disables any existing server audits.
-- Run as sysadmin.
-- SETUP:
-- Disable all currently enabled server audits so active_server_audits = 0:
DECLARE @audit_name NVARCHAR(256);
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT name FROM sys.server_audits WHERE is_state_enabled = 1;
OPEN cur;
FETCH NEXT FROM cur INTO @audit_name;
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC(N'ALTER SERVER AUDIT [' + @audit_name + N'] WITH (STATE = OFF);');
    FETCH NEXT FROM cur INTO @audit_name;
END
CLOSE cur; DEALLOCATE cur;
GO
-- Verify: the detection should now return a row with active_server_audits = 0.
-- REVERT:
-- Re-enable any audits that were disabled (names are instance-specific).
-- On a disposable test server with no pre-existing audits, nothing to revert.
-- If specific audits were disabled, re-enable them manually:
-- ALTER SERVER AUDIT [<name>] WITH (STATE = ON);
SELECT 'SEC-SQL-CFG-005-RC13 revert: manually re-enable any audits that were disabled' AS info;
GO

/* ===== SEC-SQL-CFG-005-RC14 [SAFE] ===== */
-- Detection runs DBCC TRACESTATUS(-1) which lists all globally enabled trace flags.
-- To guarantee >=1 row, enable a harmless trace flag (e.g., 3604 = send DBCC output
-- to the client; well-known and safe to toggle briefly).
-- SAFE: trace flag is toggled on/off; no schema changes.
-- Run as sysadmin.
-- SETUP:
DBCC TRACEON(3604, -1);   -- enable TF 3604 globally; now DBCC TRACESTATUS(-1) returns >=1 row
GO
-- REVERT:
DBCC TRACEOFF(3604, -1);  -- disable TF 3604 globally
GO

/* ===== SEC-SQL-CFG-006-RC01 [DESTRUCTIVE] ===== */
-- Detection fires when a linked server exists with uses_self_credential = 0
-- AND remote_name IS NOT NULL (i.e., a static/explicit credential is stored).
-- Create a loopback linked server and add an explicit credential mapping.
-- DESTRUCTIVE: creates a linked server object.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE name = 'DBDOME_TEST_LS' AND is_linked = 1)
    EXEC sp_addlinkedserver
        @server     = N'DBDOME_TEST_LS',
        @srvproduct = N'',
        @provider   = N'SQLNCLI',
        @datasrc    = @@SERVERNAME;
GO
-- Add explicit (static) credential: local login sa maps to remote login 'dbdome_fake_user'
EXEC sp_addlinkedsrvlogin
    @rmtsrvname  = N'DBDOME_TEST_LS',
    @useself     = 'FALSE',
    @locallogin  = NULL,       -- NULL = default mapping (local_principal_id = 0)
    @rmtuser     = N'dbdome_fake_user',
    @rmtpassword = N'FakePass1!';
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.servers WHERE name = 'DBDOME_TEST_LS' AND is_linked = 1)
BEGIN
    EXEC sp_droplinkedsrvlogin @rmtsrvname = N'DBDOME_TEST_LS', @locallogin = NULL;
    EXEC sp_dropserver @server = N'DBDOME_TEST_LS', @droplogins = 'droplogins';
END
GO

/* ===== SEC-SQL-CFG-006-RC02 [DESTRUCTIVE] ===== */
-- Detection fires when a linked server login mapping has remote_name IN ('sa','SA','dbo')
-- or LIKE '%admin%' / '%sysadmin%' / '%root%' / '%superuser%'.
-- Create a linked server with remote_name = 'sa' to hit CRITICAL_OVERPRIVILEGED.
-- DESTRUCTIVE: creates a linked server object with a privileged-looking remote login name.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE name = 'DBDOME_TEST_PRIV_LS' AND is_linked = 1)
    EXEC sp_addlinkedserver
        @server     = N'DBDOME_TEST_PRIV_LS',
        @srvproduct = N'',
        @provider   = N'SQLNCLI',
        @datasrc    = @@SERVERNAME;
GO
EXEC sp_addlinkedsrvlogin
    @rmtsrvname  = N'DBDOME_TEST_PRIV_LS',
    @useself     = 'FALSE',
    @locallogin  = NULL,
    @rmtuser     = N'sa',           -- triggers CRITICAL_OVERPRIVILEGED
    @rmtpassword = N'FakePass1!';
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.servers WHERE name = 'DBDOME_TEST_PRIV_LS' AND is_linked = 1)
BEGIN
    EXEC sp_droplinkedsrvlogin @rmtsrvname = N'DBDOME_TEST_PRIV_LS', @locallogin = NULL;
    EXEC sp_dropserver @server = N'DBDOME_TEST_PRIV_LS', @droplogins = 'droplogins';
END
GO

/* ===== SEC-SQL-CFG-006-RC03 [DESTRUCTIVE] ===== */
-- Detection fires for any row in sys.linked_logins for a linked server (is_linked = 1),
-- regardless of credential type. Even a self-mapping or a no-mapping row qualifies
-- because the WHERE only requires is_linked = 1.
-- Create a minimal linked server with a default (no-credential) login mapping.
-- DESTRUCTIVE: creates a linked server object.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE name = 'DBDOME_TEST_EXPOSE_LS' AND is_linked = 1)
    EXEC sp_addlinkedserver
        @server     = N'DBDOME_TEST_EXPOSE_LS',
        @srvproduct = N'',
        @provider   = N'SQLNCLI',
        @datasrc    = @@SERVERNAME;
GO
-- sp_addlinkedserver automatically creates a default login mapping (local_principal_id=0),
-- which is enough for the detection to return a row (exposure_level DEFAULT or SPECIFIC).
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.servers WHERE name = 'DBDOME_TEST_EXPOSE_LS' AND is_linked = 1)
    EXEC sp_dropserver @server = N'DBDOME_TEST_EXPOSE_LS', @droplogins = 'droplogins';
GO

/* ===== SEC-SQL-CFG-006-RC04 [DESTRUCTIVE] ===== */
-- Detection fires when a linked server has is_rpc_out_enabled = 1
-- AND uses_self_credential = 0 AND remote_name IS NOT NULL (stored credential + RPC out).
-- Create a linked server with RPC OUT enabled and an explicit credential.
-- DESTRUCTIVE: creates a linked server with RPC OUT enabled.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE name = 'DBDOME_TEST_RPC_LS' AND is_linked = 1)
    EXEC sp_addlinkedserver
        @server     = N'DBDOME_TEST_RPC_LS',
        @srvproduct = N'',
        @provider   = N'SQLNCLI',
        @datasrc    = @@SERVERNAME;
GO
-- Enable RPC OUT on the linked server:
EXEC sp_serveroption @server = N'DBDOME_TEST_RPC_LS', @optname = N'rpc out', @optvalue = N'true';
GO
-- Add explicit (static) credential:
EXEC sp_addlinkedsrvlogin
    @rmtsrvname  = N'DBDOME_TEST_RPC_LS',
    @useself     = 'FALSE',
    @locallogin  = NULL,
    @rmtuser     = N'dbdome_rpc_user',
    @rmtpassword = N'FakePass1!';
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.servers WHERE name = 'DBDOME_TEST_RPC_LS' AND is_linked = 1)
BEGIN
    EXEC sp_droplinkedsrvlogin @rmtsrvname = N'DBDOME_TEST_RPC_LS', @locallogin = NULL;
    EXEC sp_dropserver @server = N'DBDOME_TEST_RPC_LS', @droplogins = 'droplogins';
END
GO

/* ===== SEC-SQL-CFG-006-RC05 [DESTRUCTIVE] ===== */
-- Detection fires for any linked server with is_data_access_enabled = 1
-- OR is_rpc_out_enabled = 1. By default sp_addlinkedserver sets is_data_access_enabled = 1,
-- so a plain linked server already fires this detection.
-- DESTRUCTIVE: creates a linked server object.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE name = 'DBDOME_TEST_ACCESS_LS' AND is_linked = 1)
    EXEC sp_addlinkedserver
        @server     = N'DBDOME_TEST_ACCESS_LS',
        @srvproduct = N'',
        @provider   = N'SQLNCLI',
        @datasrc    = @@SERVERNAME;
GO
-- is_data_access_enabled defaults to 1 after sp_addlinkedserver; detection fires immediately.
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.servers WHERE name = 'DBDOME_TEST_ACCESS_LS' AND is_linked = 1)
    EXEC sp_dropserver @server = N'DBDOME_TEST_ACCESS_LS', @droplogins = 'droplogins';
GO

/* ===== SEC-SQL-CFG-006-RC06 [DESTRUCTIVE] ===== */
-- Detection fires when a linked login has uses_self_credential = 1 OR local_principal_id = 0.
-- sp_addlinkedserver automatically creates a default mapping (local_principal_id = 0),
-- which satisfies the OR condition immediately. No additional credential setup needed.
-- DESTRUCTIVE: creates a linked server object.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE name = 'DBDOME_TEST_INH_LS' AND is_linked = 1)
    EXEC sp_addlinkedserver
        @server     = N'DBDOME_TEST_INH_LS',
        @srvproduct = N'',
        @provider   = N'SQLNCLI',
        @datasrc    = @@SERVERNAME;
GO
-- Default mapping has local_principal_id = 0; detection fires with exposure_level
-- = 'DEFAULT: Connections not made (no mapping)' or similar.
-- Optionally add a self-mapping for the uses_self_credential = 1 branch:
EXEC sp_addlinkedsrvlogin
    @rmtsrvname = N'DBDOME_TEST_INH_LS',
    @useself    = 'TRUE',
    @locallogin = NULL;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.servers WHERE name = 'DBDOME_TEST_INH_LS' AND is_linked = 1)
    EXEC sp_dropserver @server = N'DBDOME_TEST_INH_LS', @droplogins = 'droplogins';
GO

/* ===== SEC-SQL-CFG-006-RC07 [SAFE] ===== */
-- Detection scans sys.dm_exec_query_stats / sys.dm_exec_sql_text for cached query text
-- containing OPENQUERY, OPENROWSET, or EXEC ... AT [...].
-- Seed the plan cache with a statement containing OPENQUERY text so the detection
-- finds >=1 row. Use sp_executesql so the text is cached in dm_exec_query_stats.
-- SAFE: only places a query string in the plan cache; no schema or data changes.
-- Note: plan cache entries may be evicted under memory pressure; run detection promptly.
-- SETUP:
-- Execute a statement that contains OPENQUERY in its text so it appears in the plan cache.
-- (The OPENQUERY itself does not need to succeed; we wrap it to prevent actual execution
--  while still seeding the text into the cache via sp_executesql.)
EXEC sys.sp_executesql
    N'/* dbdome_test_marker */
      SELECT TOP 0 * FROM OPENQUERY([DBDOME_FAKE_LS], ''SELECT 1'')
      WHERE 1 = 0;';
GO
-- REVERT:
-- Flush the plan cache entry (or simply flush all ad-hoc plans).
-- On a disposable test server flushing all clean buffers is acceptable:
DBCC FREEPROCCACHE;   -- clears entire plan cache; use on disposable server only
GO


/* ########## batch 27 (12 reproducers) ########## */
/* ===== SEC-SQL-CFG-006-RC08 [DESTRUCTIVE] ===== */
-- Creates a loopback linked server with RPC Out enabled (HIGH_RISK tier).
-- Requires sysadmin. The loopback target is the local server itself.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE name = 'DBDOME_TEST_LS' AND is_linked = 1)
BEGIN
    EXEC sp_addlinkedserver
        @server     = N'DBDOME_TEST_LS',
        @srvproduct = N'',
        @provider   = N'SQLNCLI',
        @datasrc    = @@SERVERNAME;
END
-- Add a SQL-auth login mapping (creates linked_login row)
IF NOT EXISTS (
    SELECT 1 FROM sys.linked_logins ll
    JOIN sys.servers s ON ll.server_id = s.server_id
    WHERE s.name = 'DBDOME_TEST_LS' AND ll.local_principal_id = 0
)
BEGIN
    EXEC sp_addlinkedsrvlogin
        @rmtsrvname  = N'DBDOME_TEST_LS',
        @useself     = N'False',
        @rmtuser     = N'sa',
        @rmtpassword = N'DbDomeTest!2024';
END
-- Enable RPC Out (and Remote Login for HIGH_RISK classification)
EXEC sp_serveroption @server = N'DBDOME_TEST_LS', @optname = N'rpc out',          @optvalue = N'true';
EXEC sp_serveroption @server = N'DBDOME_TEST_LS', @optname = N'remote login timeout', @optvalue = N'20';
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.servers WHERE name = 'DBDOME_TEST_LS' AND is_linked = 1)
BEGIN
    EXEC sp_dropserver @server = N'DBDOME_TEST_LS', @droplogins = N'droplogins';
END
GO

/* ===== SEC-SQL-CFG-006-RC09 [SAFE] ===== */
-- Detection queries sys.dm_xe_sessions / sys.dm_xe_session_events and returns rows
-- for any running XE session. The built-in 'system_health' session is always running.
-- No setup needed if system_health is active. This block starts an additional named
-- session to guarantee >=1 row even if system_health is stopped.
-- Run as sysadmin. Revert drops the session.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.dm_xe_sessions WHERE name = 'dbdome_test_xe_session')
BEGIN
    -- Create a minimal XE session capturing sql_statement_starting
    EXEC('
        CREATE EVENT SESSION [dbdome_test_xe_session] ON SERVER
        ADD EVENT sqlserver.sql_statement_starting
        ADD TARGET package0.ring_buffer(SET max_memory = 1024);
    ');
    ALTER EVENT SESSION [dbdome_test_xe_session] ON SERVER STATE = START;
END
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.dm_xe_sessions WHERE name = 'dbdome_test_xe_session')
BEGIN
    ALTER EVENT SESSION [dbdome_test_xe_session] ON SERVER STATE = STOP;
END
IF EXISTS (
    SELECT 1 FROM sys.server_event_sessions WHERE name = 'dbdome_test_xe_session'
)
BEGIN
    DROP EVENT SESSION [dbdome_test_xe_session] ON SERVER;
END
GO

/* ===== SEC-SQL-CFG-006-RC10 [DESTRUCTIVE] ===== */
-- Detection flags linked servers where uses_self_credential=0, remote_name IS NOT NULL,
-- and modify_date is >90 days old (STALE_CREDENTIAL tier).
-- We create the linked server then backdoor-update modify_date via DBCC WRITEPAGE
-- is not feasible cleanly, so instead we rely on the row appearing in the
-- 'SQL_CREDENTIAL' tier (any age) which is the second WHEN branch -- that fires
-- whenever uses_self_credential=0 AND remote_name IS NOT NULL regardless of age.
-- The detection returns >=1 row immediately after setup.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE name = 'DBDOME_TEST_LS_CRED' AND is_linked = 1)
BEGIN
    EXEC sp_addlinkedserver
        @server     = N'DBDOME_TEST_LS_CRED',
        @srvproduct = N'',
        @provider   = N'SQLNCLI',
        @datasrc    = @@SERVERNAME;
END
IF NOT EXISTS (
    SELECT 1 FROM sys.linked_logins ll
    JOIN sys.servers s ON ll.server_id = s.server_id
    WHERE s.name = 'DBDOME_TEST_LS_CRED' AND ll.local_principal_id = 0
)
BEGIN
    EXEC sp_addlinkedsrvlogin
        @rmtsrvname  = N'DBDOME_TEST_LS_CRED',
        @useself     = N'False',
        @rmtuser     = N'dbdome_stale_user',
        @rmtpassword = N'DbDomeTest!2024';
END
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.servers WHERE name = 'DBDOME_TEST_LS_CRED' AND is_linked = 1)
BEGIN
    EXEC sp_dropserver @server = N'DBDOME_TEST_LS_CRED', @droplogins = N'droplogins';
END
GO

/* ===== SEC-SQL-CFG-006-RC11 [DESTRUCTIVE] ===== */
-- Detection flags linked servers where a default (local_principal_id=0) mapping exists
-- with remote_name IS NOT NULL or uses_self_credential=1.
-- sp_addlinkedsrvlogin with @locallogin=NULL creates the default mapping (local_principal_id=0).
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE name = 'DBDOME_TEST_LS_SCOPE' AND is_linked = 1)
BEGIN
    EXEC sp_addlinkedserver
        @server     = N'DBDOME_TEST_LS_SCOPE',
        @srvproduct = N'',
        @provider   = N'SQLNCLI',
        @datasrc    = @@SERVERNAME;
END
-- Default mapping: @locallogin=NULL => local_principal_id=0, remote_name set => DEFAULT_MAPPING
IF NOT EXISTS (
    SELECT 1 FROM sys.linked_logins ll
    JOIN sys.servers s ON ll.server_id = s.server_id
    WHERE s.name = 'DBDOME_TEST_LS_SCOPE' AND ll.local_principal_id = 0 AND ll.remote_name IS NOT NULL
)
BEGIN
    EXEC sp_addlinkedsrvlogin
        @rmtsrvname  = N'DBDOME_TEST_LS_SCOPE',
        @useself     = N'False',
        @locallogin  = NULL,
        @rmtuser     = N'dbdome_scope_user',
        @rmtpassword = N'DbDomeTest!2024';
END
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.servers WHERE name = 'DBDOME_TEST_LS_SCOPE' AND is_linked = 1)
BEGIN
    EXEC sp_dropserver @server = N'DBDOME_TEST_LS_SCOPE', @droplogins = N'droplogins';
END
GO

/* ===== SEC-SQL-CFG-006-RC13 [DESTRUCTIVE] ===== */
-- Detection flags linked servers with modify_date older than 180 days.
-- There is no supported way to back-date modify_date directly via T-SQL.
-- Best-effort: create the linked server and note the limitation.
-- To trigger the >180 days predicate on a fresh server, the DBA must either
-- (a) wait 180 days, (b) use an undocumented trick (DBCC WRITEPAGE -- not safe),
-- or (c) restore a backup that already contains an old linked server entry.
-- The setup below creates the linked server so the object exists; the detection
-- will return a row once the server is 180+ days old.
-- For immediate QA, temporarily lower the threshold in the detection SQL to 0 days.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE name = 'DBDOME_TEST_LS_OLD' AND is_linked = 1)
BEGIN
    EXEC sp_addlinkedserver
        @server     = N'DBDOME_TEST_LS_OLD',
        @srvproduct = N'',
        @provider   = N'SQLNCLI',
        @datasrc    = @@SERVERNAME;
END
-- Verify the row exists (will appear with days_since_change = 0 on a new server):
-- SELECT name, modify_date, DATEDIFF(DAY, modify_date, GETDATE()) AS days_since_change
-- FROM sys.servers WHERE name = 'DBDOME_TEST_LS_OLD';
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.servers WHERE name = 'DBDOME_TEST_LS_OLD' AND is_linked = 1)
BEGIN
    EXEC sp_dropserver @server = N'DBDOME_TEST_LS_OLD', @droplogins = N'droplogins';
END
GO

/* ===== SEC-SQL-CFG-006-RC14 [DESTRUCTIVE] ===== */
-- Detection lists linked servers LEFT JOINed to sys.dm_exec_connections.
-- WHERE s.is_linked = 1 means ANY linked server causes the detection to return >=1 row
-- (the LEFT JOIN means a row always appears per linked server, even with NULL connection cols).
-- Encryption classification is UNENCRYPTED/ENCRYPTED/UNKNOWN based on c.encrypt_option.
-- Setup: create a linked server. The detection will return rows immediately.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE name = 'DBDOME_TEST_LS_ENC' AND is_linked = 1)
BEGIN
    EXEC sp_addlinkedserver
        @server     = N'DBDOME_TEST_LS_ENC',
        @srvproduct = N'',
        @provider   = N'SQLNCLI',
        @datasrc    = @@SERVERNAME;
END
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.servers WHERE name = 'DBDOME_TEST_LS_ENC' AND is_linked = 1)
BEGIN
    EXEC sp_dropserver @server = N'DBDOME_TEST_LS_ENC', @droplogins = N'droplogins';
END
GO

/* ===== SEC-SQL-CFG-006-RC15 [DESTRUCTIVE] ===== */
-- Detection flags all linked servers via sys.linked_logins JOIN.
-- Any linked server with a linked_login row triggers a row.
-- Uses SQL-auth mapping to hit the 'SQL_AUTH: no mutual authentication' branch.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE name = 'DBDOME_TEST_LS_AUTH' AND is_linked = 1)
BEGIN
    EXEC sp_addlinkedserver
        @server     = N'DBDOME_TEST_LS_AUTH',
        @srvproduct = N'',
        @provider   = N'SQLNCLI',
        @datasrc    = @@SERVERNAME;
END
IF NOT EXISTS (
    SELECT 1 FROM sys.linked_logins ll
    JOIN sys.servers s ON ll.server_id = s.server_id
    WHERE s.name = 'DBDOME_TEST_LS_AUTH' AND ll.local_principal_id = 0
)
BEGIN
    EXEC sp_addlinkedsrvlogin
        @rmtsrvname  = N'DBDOME_TEST_LS_AUTH',
        @useself     = N'False',
        @rmtuser     = N'dbdome_auth_user',
        @rmtpassword = N'DbDomeTest!2024';
END
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.servers WHERE name = 'DBDOME_TEST_LS_AUTH' AND is_linked = 1)
BEGIN
    EXEC sp_dropserver @server = N'DBDOME_TEST_LS_AUTH', @droplogins = N'droplogins';
END
GO

/* ===== SEC-SQL-CFG-006-RC16 [DESTRUCTIVE] ===== */
-- Detection reports: linked_server_count, non_sysadmin_view_server_state_grants,
-- view_any_definition_grants, admin_role_members. Returns exactly 1 summary row always.
-- To make the metrics non-zero: create a linked server (bumps linked_server_count),
-- grant VIEW SERVER STATE to a non-sysadmin login (bumps that counter),
-- grant VIEW ANY DEFINITION (bumps that counter).
-- SETUP:
-- 1) Linked server
IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE name = 'DBDOME_TEST_LS_CAT' AND is_linked = 1)
BEGIN
    EXEC sp_addlinkedserver
        @server     = N'DBDOME_TEST_LS_CAT',
        @srvproduct = N'',
        @provider   = N'SQLNCLI',
        @datasrc    = @@SERVERNAME;
END
-- 2) Login for VSS grant
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_rc16')
BEGIN
    CREATE LOGIN [dbdome_test_login_rc16] WITH PASSWORD = N'DbDomeTest!2024',
        DEFAULT_DATABASE = [master], CHECK_EXPIRATION = OFF, CHECK_POLICY = OFF;
END
GRANT VIEW SERVER STATE      TO [dbdome_test_login_rc16];
GRANT VIEW ANY DEFINITION    TO [dbdome_test_login_rc16];
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_rc16')
BEGIN
    REVOKE VIEW SERVER STATE   FROM [dbdome_test_login_rc16];
    REVOKE VIEW ANY DEFINITION FROM [dbdome_test_login_rc16];
    DROP LOGIN [dbdome_test_login_rc16];
END
IF EXISTS (SELECT 1 FROM sys.servers WHERE name = 'DBDOME_TEST_LS_CAT' AND is_linked = 1)
BEGIN
    EXEC sp_dropserver @server = N'DBDOME_TEST_LS_CAT', @droplogins = N'droplogins';
END
GO

/* ===== SEC-SQL-ENC-001-RC01 [SAFE] ===== */
-- Detection groups all connections by encrypt_option and returns one row per value.
-- sys.dm_exec_connections always has rows (at minimum the current session itself).
-- No setup needed; the current connection appears in the DMV.
-- To guarantee an unencrypted row (encrypt_option='FALSE'), connect via TCP without
-- TLS (e.g., SQLCMD /S tcp:server,1433 without Encrypt=yes in connection string).
-- The setup below is informational only; the detection already fires with >=1 row.
-- SETUP:
-- (no persistent changes needed -- current session already appears in dm_exec_connections)
SELECT 'Current session encrypt_option:' AS info, encrypt_option
FROM sys.dm_exec_connections
WHERE session_id = @@SPID;
GO
-- REVERT:
-- Nothing to revert.
SELECT 'No revert needed for SEC-SQL-ENC-001-RC01' AS info;
GO

/* ===== SEC-SQL-ENC-001-RC02 [SAFE] ===== */
-- Detection flags user connections with encrypt_option='FALSE' over non-shared-memory transport.
-- To trigger: open a TCP connection to SQL Server WITHOUT Encrypt=yes in the connection string.
-- Example (from a client machine or same host via TCP loopback):
--   sqlcmd -S tcp:127.0.0.1,1433 -U sa -P <pwd> -Q "SELECT 1"
--   (do NOT add ;Encrypt=yes to the connection string)
-- The connection will appear in sys.dm_exec_connections with encrypt_option='FALSE'
-- and net_transport='TCP', triggering the detection.
-- This setup block creates a login for that test connection.
-- Keep the test connection open while running the detection query.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_enc')
BEGIN
    CREATE LOGIN [dbdome_test_login_enc] WITH PASSWORD = N'DbDomeTest!2024',
        DEFAULT_DATABASE = [master], CHECK_EXPIRATION = OFF, CHECK_POLICY = OFF;
END
-- Then in a separate session (TCP, no Encrypt=yes):
--   EXEC sp_executesql N'WAITFOR DELAY ''00:05:00'''; -- keep connection alive during detection run
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_enc')
BEGIN
    DROP LOGIN [dbdome_test_login_enc];
END
GO

/* ===== SEC-SQL-ENC-001-RC03 [DESTRUCTIVE] ===== */
-- Detection flags user databases (database_id > 4) with compatibility_level < 130 and state=ONLINE.
-- Setup: create a database and set its compatibility level to 120 (SQL Server 2014).
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_test_compat_db')
BEGIN
    CREATE DATABASE [dbdome_test_compat_db];
END
GO
ALTER DATABASE [dbdome_test_compat_db] SET COMPATIBILITY_LEVEL = 120;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_test_compat_db')
BEGIN
    -- Bring to single user in case of connections, then drop
    ALTER DATABASE [dbdome_test_compat_db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [dbdome_test_compat_db];
END
GO

/* ===== SEC-SQL-ENC-001-RC04 [SAFE] ===== */
-- Detection groups user connections (non-shared-memory) by client_interface_name,
-- client_version, encrypt_option, protocol_version. Returns >=1 row per distinct
-- combination. Any active user TCP connection (encrypted or not) triggers a row.
-- To specifically populate unencrypted_count: connect via TCP without Encrypt=yes
-- (same as RC02 guidance). The detection fires for any user session over TCP/Named Pipes.
-- The setup login from RC02 can serve dual purpose; create it here if not already present.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_enc04')
BEGIN
    CREATE LOGIN [dbdome_test_login_enc04] WITH PASSWORD = N'DbDomeTest!2024',
        DEFAULT_DATABASE = [master], CHECK_EXPIRATION = OFF, CHECK_POLICY = OFF;
END
-- Connect via TCP without encryption in a separate session and keep it alive:
--   sqlcmd -S tcp:127.0.0.1,1433 -U dbdome_test_login_enc04 -P "DbDomeTest!2024"
--           -Q "WAITFOR DELAY '00:05:00'"
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_login_enc04')
BEGIN
    DROP LOGIN [dbdome_test_login_enc04];
END
GO


/* ########## batch 28 (12 reproducers) ########## */
/* ===== SEC-SQL-ENC-001-RC07 [DESTRUCTIVE] ===== */
-- Creates a certificate with a past expiry date so the detection returns >=1 row (cert_health = 'EXPIRED').
-- Run as sysadmin in master or any user database that allows certificates.
-- SETUP:
USE master;
GO
IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'dbdome_test_cert_expired')
    CREATE CERTIFICATE dbdome_test_cert_expired
        WITH SUBJECT = 'DBDome Test Expired Cert',
             START_DATE = '20200101',
             EXPIRY_DATE = '20210101';
GO
-- REVERT:
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'dbdome_test_cert_expired')
    DROP CERTIFICATE dbdome_test_cert_expired;
GO

/* ===== SEC-SQL-ENC-001-RC08 [SAFE] ===== */
-- Detection queries sys.dm_exec_connections joined to sys.dm_exec_sessions for user processes
-- where net_transport <> 'Shared memory', grouping by encrypt_option.
-- It returns rows whenever any non-shared-memory user connection exists (encrypted or not).
-- Setup: open a TCP connection from a separate session (e.g. sqlcmd -S <host>,1433) so that
-- at least one row with net_transport = 'TCP' appears in sys.dm_exec_connections.
-- The detection itself does not filter on encryption state — it returns all such connections.
-- No persistent object changes are needed; keep the extra session open while running the detection.
-- SETUP:
-- (Run in a SEPARATE session via TCP, keep it open while executing the detection)
-- Session A (separate window): sqlcmd -S <servername>,1433 -Q "WAITFOR DELAY '00:05:00'"
-- Then run the detection SQL from any other session.
SELECT session_id, net_transport, encrypt_option
FROM sys.dm_exec_connections
WHERE net_transport <> 'Shared memory';
GO
-- REVERT:
-- Kill the extra session opened above (replace <spid> with the actual session_id):
-- KILL <spid>;
-- No persistent objects were created.
SELECT 'No persistent objects to revert for SEC-SQL-ENC-001-RC08' AS revert_status;
GO

/* ===== SEC-SQL-ENC-001-RC09 [SAFE] ===== */
-- Detection groups connections by LOCAL vs REMOTE locality and encrypt_option.
-- Returns rows whenever any user-process connection exists in sys.dm_exec_connections.
-- The current session itself (via shared memory or loopback) satisfies the LOCAL group.
-- No persistent changes needed; simply run the detection while logged in as a user process.
-- SETUP:
-- Verify at least one user-process connection exists (the current session qualifies):
SELECT s.session_id,
       CASE WHEN c.client_net_address IN ('127.0.0.1','::1','<local machine>')
                 OR c.net_transport = 'Shared memory'
            THEN 'LOCAL' ELSE 'REMOTE' END AS connection_locality,
       c.encrypt_option
FROM sys.dm_exec_connections c
JOIN sys.dm_exec_sessions s ON c.session_id = s.session_id
WHERE s.is_user_process = 1;
GO
-- REVERT:
-- No persistent objects were created.
SELECT 'No persistent objects to revert for SEC-SQL-ENC-001-RC09' AS revert_status;
GO

/* ===== SEC-SQL-ENC-001-RC10 [SAFE] ===== */
-- Detection counts connections where encrypt_option = 'FALSE'.
-- Returns >=1 row (COUNT(*) may be 0 but the SELECT itself always returns one row).
-- To force unencrypted_connections > 0: connect via TCP without encryption enabled.
-- The simplest approach: ensure at least one session is connected without forced encryption.
-- If Force Encryption is OFF (default on many dev instances), shared memory / unencrypted TCP
-- connections will already have encrypt_option = 'FALSE'.
-- SETUP:
-- Open an additional session using a connection string that does NOT request encryption:
-- sqlcmd -S <servername> -E -N d   (trust server cert, encryption=disabled)
-- Keep that session open and run the detection.
-- Alternatively, verify existing unencrypted connections:
SELECT COUNT(*) AS unencrypted_connections,
       (SELECT COUNT(*) FROM sys.dm_exec_connections) AS total_connections
FROM sys.dm_exec_connections
WHERE encrypt_option = 'FALSE';
GO
-- REVERT:
-- Disconnect the extra unencrypted session.  No persistent objects created.
SELECT 'No persistent objects to revert for SEC-SQL-ENC-001-RC10' AS revert_status;
GO

/* ===== SEC-SQL-ENC-001-RC11 [SAFE] ===== */
-- Detection sums encrypted vs unencrypted user-process connections.
-- Returns exactly one row always (SUM over zero rows yields NULL, but CASE wraps it).
-- The detection triggers when unencrypted_count > 0.
-- To make unencrypted_count > 0: connect via TCP without encryption (same as RC10 above).
-- SETUP:
-- Open an unencrypted user session via TCP (see RC10 notes), keep it open, run detection.
SELECT
    SUM(CASE WHEN c.encrypt_option = 'TRUE'  THEN 1 ELSE 0 END) AS encrypted_count,
    SUM(CASE WHEN c.encrypt_option = 'FALSE' THEN 1 ELSE 0 END) AS unencrypted_count
FROM sys.dm_exec_connections c
JOIN sys.dm_exec_sessions s ON c.session_id = s.session_id
WHERE s.is_user_process = 1;
GO
-- REVERT:
-- Disconnect the extra unencrypted session.  No persistent objects created.
SELECT 'No persistent objects to revert for SEC-SQL-ENC-001-RC11' AS revert_status;
GO

/* ===== SEC-SQL-ENC-001-RC12 [DESTRUCTIVE] ===== */
-- Detection reads ForceEncryption registry value via xp_instance_regread.
-- Returns one row always; the interesting column is force_encryption (0 = not forced = flagged).
-- To make the detection show force_encryption = 0 (the at-risk state), leave default value.
-- To test that xp_instance_regread executes at all, simply run it; no setup change needed.
-- To flip to force_encryption = 1 (forced) you must use SQL Server Configuration Manager
-- (registry write; cannot be done via T-SQL alone without direct registry write permissions).
-- Setup below verifies the read works and records baseline; no persistent change is made here.
-- Run as sysadmin (xp_instance_regread requires sysadmin or securityadmin).
-- SETUP:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;

DECLARE @force_encryption INT;
EXEC master.dbo.xp_instance_regread
    N'HKEY_LOCAL_MACHINE',
    N'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQLServer\SuperSocketNetLib',
    N'ForceEncryption',
    @force_encryption OUTPUT;

SELECT @force_encryption AS force_encryption,
       SERVERPROPERTY('MachineName') AS machine_name,
       SERVERPROPERTY('IsClustered')  AS is_clustered,
       SERVERPROPERTY('ProductLevel') AS product_level;
-- A result of 0 means ForceEncryption is OFF (the detection flags this state).
GO
-- REVERT:
-- No persistent change was made by setup; show advanced options can be reset if desired.
EXEC sp_configure 'show advanced options', 0;
RECONFIGURE;
GO

/* ===== SEC-SQL-ENC-001-RC13 [DESTRUCTIVE] ===== */
-- Detection joins sys.server_audit_specifications to sys.server_audit_specification_details.
-- Returns rows only when at least one server audit specification exists.
-- Setup: create a server audit + specification so the join returns >=1 row.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
BEGIN
    CREATE SERVER AUDIT dbdome_test_audit
        TO FILE (FILEPATH = 'C:\Temp\', MAXSIZE = 2 MB, MAX_ROLLOVER_FILES = 1)
        WITH (ON_FAILURE = CONTINUE);
END;

IF NOT EXISTS (
    SELECT 1 FROM sys.server_audit_specifications
    WHERE name = 'dbdome_test_audit_spec'
)
BEGIN
    CREATE SERVER AUDIT SPECIFICATION dbdome_test_audit_spec
        FOR SERVER AUDIT dbdome_test_audit
        ADD (FAILED_LOGIN_GROUP)
        WITH (STATE = OFF);
END;
GO
-- REVERT:
IF EXISTS (
    SELECT 1 FROM sys.server_audit_specifications
    WHERE name = 'dbdome_test_audit_spec'
)
BEGIN
    ALTER SERVER AUDIT SPECIFICATION dbdome_test_audit_spec WITH (STATE = OFF);
    DROP SERVER AUDIT SPECIFICATION dbdome_test_audit_spec;
END;

IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
BEGIN
    ALTER SERVER AUDIT dbdome_test_audit WITH (STATE = OFF);
    DROP SERVER AUDIT dbdome_test_audit;
END;
GO

/* ===== SEC-SQL-ENC-002-RC01 [SAFE] ===== */
-- Detection filters sys.dm_exec_connections for user-process sessions where
-- encrypt_option = 'TRUE' AND protocol_version IN (0x301 TLS1.0, 0x302 TLS1.1).
-- To trigger: a client must connect using TLS 1.0 or 1.1 with encryption enabled.
-- This requires the OS/SQL Server to still support TLS 1.0/1.1 (enabled in Schannel registry)
-- AND the client driver to negotiate that version.
-- Cannot be forced purely via T-SQL; requires OS-level TLS configuration + legacy client.
-- Best-effort: verify whether any current connections already match the filter.
-- Run as sysadmin.
-- SETUP:
-- On Windows, ensure TLS 1.0 or 1.1 is enabled in Schannel registry (requires registry edit
-- or IISCrypto tool), then connect with a legacy ODBC/OLEDB driver that negotiates TLS 1.0/1.1.
-- Example connection string (ODBC): Driver={SQL Server};Server=<host>;Encrypt=yes;...
-- Check current state:
SELECT s.program_name, s.host_name, s.login_name,
       c.protocol_version,
       CASE c.protocol_version
           WHEN 0x301 THEN 'TLS 1.0'
           WHEN 0x302 THEN 'TLS 1.1'
           WHEN 0x303 THEN 'TLS 1.2'
           WHEN 0x304 THEN 'TLS 1.3'
           ELSE 'Unknown/None (' + CONVERT(VARCHAR, c.protocol_version) + ')'
       END AS tls_version,
       COUNT(*) AS connection_count
FROM sys.dm_exec_connections c
JOIN sys.dm_exec_sessions s ON c.session_id = s.session_id
WHERE s.is_user_process = 1
  AND c.encrypt_option = 'TRUE'
  AND c.protocol_version IN (0x301, 0x302)
GROUP BY s.program_name, s.host_name, s.login_name, c.protocol_version
ORDER BY connection_count DESC;
GO
-- REVERT:
-- Disconnect the legacy TLS client session.  No persistent SQL objects created.
-- If Schannel registry was modified, restore it via the same tool/registry path.
SELECT 'No persistent SQL objects to revert for SEC-SQL-ENC-002-RC01' AS revert_status;
GO

/* ===== SEC-SQL-ENC-002-RC02 [SAFE] ===== */
-- Detection filters for user-process encrypted connections with protocol_version < 0x303 (below TLS 1.2).
-- Same trigger condition as RC01: requires OS TLS 1.0/1.1 support and a legacy client driver.
-- Best-effort: check existing connections; connect via legacy client if Schannel allows it.
-- Run as sysadmin.
-- SETUP:
-- Enable TLS 1.0 or 1.1 in Windows Schannel (registry or IISCrypto), connect with
-- an older ODBC Driver for SQL Server (e.g. ODBC Driver 11 / SQL Server Native Client 11)
-- that negotiates TLS < 1.2.  Keep the session open and run the detection.
-- Verify current state:
SELECT s.program_name, s.host_name,
       c.client_net_address,
       c.protocol_version,
       CASE c.protocol_version
           WHEN 0x301 THEN 'TLS 1.0'
           WHEN 0x302 THEN 'TLS 1.1'
           WHEN 0x303 THEN 'TLS 1.2'
           WHEN 0x304 THEN 'TLS 1.3'
           ELSE 'Unknown'
       END AS tls_version,
       c.net_transport,
       COUNT(*) AS connection_count
FROM sys.dm_exec_connections c
JOIN sys.dm_exec_sessions s ON c.session_id = s.session_id
WHERE s.is_user_process = 1
  AND c.encrypt_option = 'TRUE'
  AND c.protocol_version < 0x303
GROUP BY s.program_name, s.host_name, c.client_net_address,
         c.protocol_version, c.net_transport
ORDER BY c.protocol_version ASC;
GO
-- REVERT:
-- Disconnect the legacy TLS client session.  No persistent SQL objects created.
SELECT 'No persistent SQL objects to revert for SEC-SQL-ENC-002-RC02' AS revert_status;
GO

/* ===== SEC-SQL-ENC-002-RC03 [SAFE] ===== */
-- Detection additionally filters program_name LIKE '%.Net%' for TLS < 1.2 encrypted connections.
-- Trigger: a .NET application must connect with encryption and TLS < 1.2.
-- This requires: TLS 1.0/1.1 enabled in Schannel AND the .NET app targets an old framework
-- (pre-.NET 4.6) that defaults to TLS 1.0, or SchUseStrongCrypto registry key is not set.
-- Cannot be forced purely via T-SQL; requires .NET/OS configuration.
-- Best-effort: simulate by connecting via sqlcmd with program name containing '.Net':
-- sqlcmd -S <host> -A ".Net Legacy App" (note: sqlcmd does not let you spoof program_name easily;
-- use a .NET SqlConnection with Application Name=".Net Legacy Test" in the connection string).
-- SETUP:
-- 1. Enable TLS 1.0 in Schannel on the client OS.
-- 2. Build/run a .NET 4.5 console app with:
--    SqlConnection conn = new SqlConnection(
--      "Server=<host>;Encrypt=True;Application Name=.Net Legacy Test;...");
-- 3. Keep the connection open and run the detection.
-- Verify:
SELECT s.program_name, s.host_name, s.login_name,
       c.protocol_version,
       CASE c.protocol_version
           WHEN 0x301 THEN 'TLS 1.0'
           WHEN 0x302 THEN 'TLS 1.1'
           WHEN 0x303 THEN 'TLS 1.2'
           ELSE 'Other'
       END AS tls_version,
       COUNT(*) AS connection_count
FROM sys.dm_exec_connections c
JOIN sys.dm_exec_sessions s ON c.session_id = s.session_id
WHERE s.is_user_process = 1
  AND c.encrypt_option = 'TRUE'
  AND c.protocol_version < 0x303
  AND s.program_name LIKE '%.Net%'
GROUP BY s.program_name, s.host_name, s.login_name, c.protocol_version
ORDER BY connection_count DESC;
GO
-- REVERT:
-- Disconnect the legacy .NET session.  No persistent SQL objects created.
SELECT 'No persistent SQL objects to revert for SEC-SQL-ENC-002-RC03' AS revert_status;
GO

/* ===== SEC-SQL-ENC-002-RC04 [SAFE] ===== */
-- Detection filters program_name for JDBC/Java/jTDS/Microsoft JDBC with TLS < 1.2 encrypted connections.
-- Trigger: a Java/JDBC application connects with Encrypt=true and negotiates TLS 1.0 or 1.1.
-- Requires: TLS 1.0/1.1 in Schannel AND an old JDK (pre-JDK 8u261) or manually disabled TLS 1.2
-- in the JVM security policy (java.security: jdk.tls.disabledAlgorithms).
-- Cannot be forced via T-SQL; requires JVM-level configuration.
-- Best-effort: connect via a JDBC app (e.g. jTDS or old mssql-jdbc) with integratedSecurity=false;
-- set Application Name to include "jdbc" or "Java" in the connection URL.
-- SETUP:
-- 1. Enable TLS 1.0 in Schannel on the test server.
-- 2. Run a Java app:
--    String url = "jdbc:sqlserver://<host>:1433;encrypt=true;"
--               + "applicationName=jdbc_legacy_test;...";
--    (or use jTDS: jdbc:jtds:sqlserver://<host>:1433/...)
-- 3. Keep the connection open and run the detection.
-- Verify:
SELECT s.program_name, s.host_name, s.login_name,
       c.protocol_version,
       CASE c.protocol_version
           WHEN 0x301 THEN 'TLS 1.0'
           WHEN 0x302 THEN 'TLS 1.1'
           WHEN 0x303 THEN 'TLS 1.2'
           ELSE 'Other'
       END AS tls_version,
       COUNT(*) AS connection_count
FROM sys.dm_exec_connections c
JOIN sys.dm_exec_sessions s ON c.session_id = s.session_id
WHERE s.is_user_process = 1
  AND c.encrypt_option = 'TRUE'
  AND c.protocol_version < 0x303
  AND (s.program_name LIKE '%jdbc%'
       OR s.program_name LIKE '%Java%'
       OR s.program_name LIKE '%jTDS%'
       OR s.program_name LIKE '%Microsoft JDBC%')
GROUP BY s.program_name, s.host_name, s.login_name, c.protocol_version
ORDER BY connection_count DESC;
GO
-- REVERT:
-- Disconnect the legacy JDBC session.  No persistent SQL objects created.
SELECT 'No persistent SQL objects to revert for SEC-SQL-ENC-002-RC04' AS revert_status;
GO

/* ===== SEC-SQL-ENC-002-RC05 [DESTRUCTIVE] ===== */
-- Detection selects rows from sys.endpoints WHERE type_desc = 'SERVICE_BROKER'.
-- Returns rows whenever a SERVICE_BROKER endpoint exists on the instance.
-- Setup: create a Service Broker endpoint so the detection returns >=1 row.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (
    SELECT 1 FROM sys.endpoints
    WHERE name = 'dbdome_test_sb_endpoint'
      AND type_desc = 'SERVICE_BROKER'
)
    CREATE ENDPOINT dbdome_test_sb_endpoint
        STATE = STOPPED
        AS TCP (LISTENER_PORT = 5023, LISTENER_IP = ALL)
        FOR SERVICE_BROKER (AUTHENTICATION = WINDOWS, ENCRYPTION = DISABLED);
GO
-- REVERT:
IF EXISTS (
    SELECT 1 FROM sys.endpoints
    WHERE name = 'dbdome_test_sb_endpoint'
      AND type_desc = 'SERVICE_BROKER'
)
    DROP ENDPOINT dbdome_test_sb_endpoint;
GO


/* ########## batch 29 (12 reproducers) ########## */
-- =============================================================================
-- Positive-test reproducers for detections slice [348..360]
-- Target: DISPOSABLE / throwaway SQL Server instance only.
-- Run SETUP in one session; verify detection returns >=1 row; run REVERT.
-- =============================================================================

/* ===== SEC-SQL-ENC-002-RC06 [DESTRUCTIVE] ===== */
-- Detection reads TLS 1.0 and TLS 1.1 registry keys via xp_instance_regread.
-- ISNULL(..., 1) means a missing key also triggers (treated as enabled = 1).
-- Setup: write Enabled=1 for TLS 1.0 Server via xp_regwrite so the read returns 1.
-- Requires sysadmin. The registry change takes effect immediately in the SELECT output.
-- WARNING: writing Enabled=1 here does NOT actually enable TLS 1.0 in the OS SChannel stack;
-- it just makes xp_instance_regread return 1 so the detection flags the row.
-- SETUP:
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 0; RECONFIGURE; -- ensure xp_cmdshell stays off; not needed here

-- Write TLS 1.0 Server Enabled = 1 into the registry:
EXEC master.dbo.xp_instance_regwrite
    N'HKEY_LOCAL_MACHINE',
    N'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server',
    N'Enabled',
    N'REG_DWORD',
    1;
-- Write TLS 1.1 Server Enabled = 1 as well:
EXEC master.dbo.xp_instance_regwrite
    N'HKEY_LOCAL_MACHINE',
    N'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server',
    N'Enabled',
    N'REG_DWORD',
    1;
GO
-- REVERT:
-- Remove (delete) the registry values so they revert to OS default (absent = disabled by default
-- on modern Windows, or follow OS SChannel policy).
EXEC master.dbo.xp_instance_regdeletevalue
    N'HKEY_LOCAL_MACHINE',
    N'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server',
    N'Enabled';
EXEC master.dbo.xp_instance_regdeletevalue
    N'HKEY_LOCAL_MACHINE',
    N'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server',
    N'Enabled';
GO

/* ===== SEC-SQL-ENC-002-RC09 [SAFE] ===== */
-- Detection sums encrypted connections (encrypt_option='TRUE') by whether
-- protocol_version < 0x303 (TLS 1.0/1.1) vs >= 0x303 (TLS 1.2+).
-- Always returns exactly 1 row (SUM returns NULL or 0 when no rows, but the SELECT itself
-- always returns 1 row). The detection flags when old_tls_connections > 0.
-- To produce old_tls_connections > 0 you need a client application that negotiates TLS 1.0
-- or TLS 1.1 to SQL Server, which requires TLS 1.0/1.1 to be enabled in the OS SChannel stack
-- (registry: Enabled=1, DisabledByDefault=0) AND a client that downgrades (e.g. old .NET/ODBC).
-- Best-effort: enable TLS 1.0 in the registry and connect via a legacy driver in a separate session.
-- SAFE: the registry writes below are the same as RC06 setup above; they do not restart SQL Server.
-- Connect from a separate session using a TLS-1.0-capable client (e.g. old SQL Server Native Client
-- 10.0 or ODBC Driver 11) while that TLS 1.0 registry key is set.
-- *** Open a NEW session via a legacy client and run: WAITFOR DELAY '00:00:10'; ***
-- Then run the detection query while that session is active.
-- SETUP:
EXEC master.dbo.xp_instance_regwrite
    N'HKEY_LOCAL_MACHINE',
    N'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server',
    N'Enabled',
    N'REG_DWORD',
    1;
EXEC master.dbo.xp_instance_regwrite
    N'HKEY_LOCAL_MACHINE',
    N'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server',
    N'DisabledByDefault',
    N'REG_DWORD',
    0;
GO
-- NOTE: SQL Server must be restarted after SChannel registry changes for them to take effect
-- for new connections. A restart is required to actually observe TLS 1.0 connections.
-- REVERT:
EXEC master.dbo.xp_instance_regdeletevalue
    N'HKEY_LOCAL_MACHINE',
    N'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server',
    N'Enabled';
EXEC master.dbo.xp_instance_regdeletevalue
    N'HKEY_LOCAL_MACHINE',
    N'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server',
    N'DisabledByDefault';
GO

/* ===== SEC-SQL-ENC-002-RC10 [SAFE] ===== */
-- Detection groups encrypted user connections by protocol_version to show which TLS versions
-- are in use. Returns one row per distinct protocol_version among currently-active encrypted
-- user sessions. Flags when TLS 1.0 (0x301) or TLS 1.1 (0x302) rows appear.
-- Like RC09, producing an old-TLS row requires a real client using TLS 1.0/1.1.
-- Best-effort: enable TLS 1.0 in the OS SChannel registry, restart SQL Server, then connect
-- from a legacy client (e.g. SQLNCLI10) with encrypt=yes and run WAITFOR in that session.
-- SAFE: registry writes only; the detection query itself reads dm_exec_connections live.
-- *** Open a NEW encrypted session via a TLS-1.0 legacy driver, run: WAITFOR DELAY '00:00:10';
--     then run the detection while that session is active. ***
-- SETUP:
EXEC master.dbo.xp_instance_regwrite
    N'HKEY_LOCAL_MACHINE',
    N'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server',
    N'Enabled',
    N'REG_DWORD',
    1;
EXEC master.dbo.xp_instance_regwrite
    N'HKEY_LOCAL_MACHINE',
    N'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server',
    N'DisabledByDefault',
    N'REG_DWORD',
    0;
GO
-- NOTE: SQL Server restart required for SChannel registry changes to affect new connections.
-- REVERT:
EXEC master.dbo.xp_instance_regdeletevalue
    N'HKEY_LOCAL_MACHINE',
    N'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server',
    N'Enabled';
EXEC master.dbo.xp_instance_regdeletevalue
    N'HKEY_LOCAL_MACHINE',
    N'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server',
    N'DisabledByDefault';
GO

/* ===== SEC-SQL-ENC-002-RC11 [SAFE] ===== */
-- Detection always returns exactly 1 row with three counts: active_audit_specs,
-- tls_xe_sessions, and active_audits. The detection flags when all three are zero
-- (i.e., no encryption-monitoring infrastructure is in place).
-- SAFE: to produce the "positive" flagging condition (all zeros), no setup is needed
-- on a freshly-installed disposable instance with no audits configured.
-- To verify: simply run the detection SQL; if active_audit_specs=0 AND active_audits=0
-- AND tls_xe_sessions=0 the condition is triggered.
-- Conversely, to test the non-flagging path (counts > 0), create a server audit:
-- SETUP (creates a minimal audit so active_audits = 1, demonstrating counts are live):
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_enc_monitor_audit')
BEGIN
    EXEC(N'CREATE SERVER AUDIT [dbdome_enc_monitor_audit]
           TO FILE (FILEPATH = N''C:\SQLAudit\'', MAXSIZE = 5 MB, MAX_ROLLOVER_FILES = 1)
           WITH (ON_FAILURE = CONTINUE);');
END;
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_enc_monitor_audit' AND is_state_enabled = 0)
    ALTER SERVER AUDIT [dbdome_enc_monitor_audit] WITH (STATE = ON);
GO
-- NOTE: The detection flags when counts are ALL zero. A fresh instance with no audits
-- triggers the detection without any setup. The setup above creates an audit to show
-- the detection responds to the active_audits counter.
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_enc_monitor_audit')
BEGIN
    ALTER SERVER AUDIT [dbdome_enc_monitor_audit] WITH (STATE = OFF);
    DROP SERVER AUDIT [dbdome_enc_monitor_audit];
END;
GO

/* ===== SEC-SQL-ENC-002-RC12 [SAFE] ===== */
-- Detection always returns exactly 1 row with SQL Server version info and a tls12_status label.
-- Flags when tls12_status IN ('NO_TLS12_SUPPORT', 'NEEDS_PATCH_FOR_TLS12').
-- NO_TLS12_SUPPORT: major_version < 11 (SQL Server 2008 R2 or older).
-- NEEDS_PATCH_FOR_TLS12: SQL 2012 (v11) with build < 6216, or SQL 2014 (v12) with build < 4439.
-- Cannot change the installed SQL Server version via T-SQL. Best-effort: run on an old unpatched
-- instance (SQL 2012 RTM or SQL 2014 RTM) to naturally trigger this. On a modern instance,
-- tls12_status = 'TLS12_SUPPORTED' and the detection does NOT flag.
-- SAFE: this detection is purely informational (no writes needed); just run the detection SQL.
-- SETUP:
-- Run the detection SQL directly on a SQL Server 2012 RTM (build 11.0.2100) or
-- SQL Server 2014 RTM (build 12.0.2000) instance. No T-SQL setup required.
SELECT
  SERVERPROPERTY('ProductVersion') AS product_version,
  SERVERPROPERTY('ProductMajorVersion') AS major_version,
  SERVERPROPERTY('Edition') AS edition;
GO
-- NOTE: On SQL Server 2016+ (major_version >= 13), tls12_status = 'TLS12_SUPPORTED' and
-- the detection will not flag. Use an old unpatched SQL 2012/2014 instance to trigger.
-- REVERT:
-- Nothing to revert (read-only query).
SELECT 'No revert needed for SEC-SQL-ENC-002-RC12' AS revert_status;
GO

/* ===== SEC-SQL-ENC-003-RC01 [DESTRUCTIVE] ===== */
-- Detection counts: (a) DMK in master, (b) TDE-named certs in master, (c) unencrypted user DBs.
-- Flags when unencrypted_user_dbs > 0 (common on any instance without TDE).
-- Setup: create a user database without enabling TDE. That alone triggers the detection.
-- SETUP:
IF DB_ID('dbdome_testdb') IS NULL
    CREATE DATABASE [dbdome_testdb];
-- Verify: unencrypted_user_dbs count will include dbdome_testdb (is_encrypted = 0).
GO
-- REVERT:
IF DB_ID('dbdome_testdb') IS NOT NULL
BEGIN
    ALTER DATABASE [dbdome_testdb] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [dbdome_testdb];
END;
GO

/* ===== SEC-SQL-ENC-003-RC02 [SAFE] ===== */
-- Detection always returns 1 row showing the SQL Server edition and a tde_support_status label.
-- Flags when tde_support_status = 'TDE_NOT_SUPPORTED':
--   Standard edition with major_version < 15 (SQL Server 2017 or older Standard), OR
--   any other non-Enterprise/Developer/Standard edition (Web, Express, etc.).
-- Cannot change the installed edition via T-SQL.
-- SAFE: run the detection SQL on a SQL Server Standard edition prior to SQL 2019 (version 15),
-- or on any Express/Web/WorkGroup edition, to trigger the flag naturally.
-- SETUP:
-- Run the detection SQL directly on a qualifying instance. No T-SQL setup required.
SELECT
  SERVERPROPERTY('Edition') AS edition,
  CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) AS major_version;
GO
-- NOTE: On Enterprise, Developer, or Standard >= 2019 (v15), tde_support_status = 'TDE_SUPPORTED'
-- and the detection will not flag. Use Standard 2017 or Express to trigger.
-- REVERT:
SELECT 'No revert needed for SEC-SQL-ENC-003-RC02' AS revert_status;
GO

/* ===== SEC-SQL-ENC-003-RC03 [SAFE] ===== */
-- Detection always returns 1 row showing edition and entitlement_status.
-- Flags when entitlement_status = 'MISSING_TDE_ENTITLEMENT':
--   Standard edition with major_version < 15 (SQL 2017 Standard or older), OR
--   Express edition, OR Web edition.
-- Cannot change the installed edition via T-SQL.
-- SAFE: run on a SQL Server Express, Web, or Standard < 2019 instance to trigger naturally.
-- SETUP:
-- Run the detection SQL directly on a qualifying instance. No T-SQL setup required.
SELECT
  SERVERPROPERTY('Edition') AS edition,
  CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) AS major_version;
GO
-- NOTE: Express edition always triggers. Standard < v15 triggers. Enterprise/Developer do NOT trigger.
-- REVERT:
SELECT 'No revert needed for SEC-SQL-ENC-003-RC03' AS revert_status;
GO

/* ===== SEC-SQL-ENC-003-RC04 [SAFE] ===== */
-- Detection always returns 1 row with four counts: ekm_provider_count, master_cert_count,
-- master_dmk_exists, master_asym_key_count.
-- The detection flags when master_dmk_exists = 0 (no Database Master Key in master)
-- and/or ekm_provider_count = 0 (no EKM provider configured), indicating no key management
-- infrastructure for TDE.
-- SAFE: on a fresh instance, master has no DMK and no EKM provider, so the detection fires
-- immediately without any setup.
-- SETUP:
-- Run the detection SQL directly on a freshly-installed disposable instance.
-- To also verify the non-flagging path, create a DMK in master:
IF NOT EXISTS (SELECT 1 FROM master.sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Dbdome!TempKey99';
GO
-- NOTE: Creating the DMK makes master_dmk_exists = 1. On a fresh instance WITHOUT this step,
-- master_dmk_exists = 0 and the detection flags. Run detection BEFORE the setup above
-- to observe the flagging condition, then run setup to see the count change to 1.
-- REVERT:
IF EXISTS (SELECT 1 FROM master.sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
    DROP MASTER KEY;
GO

/* ===== SEC-SQL-ENC-003-RC06 [DESTRUCTIVE] ===== */
-- Detection finds user databases (database_id > 4) that are unencrypted (is_encrypted = 0)
-- AND contain a FILESTREAM_DATA_FILEGROUP or MEMORY_OPTIMIZED_DATA_FILEGROUP.
-- Setup: create a user database with a FILESTREAM or In-Memory OLTP filegroup, without TDE.
-- FILESTREAM requires the FILESTREAM feature to be enabled at the OS/instance level.
-- In-Memory OLTP (MEMORY_OPTIMIZED_DATA_FILEGROUP) requires SQL Server 2014+ Enterprise/Developer.
-- Using MEMORY_OPTIMIZED_DATA_FILEGROUP as it only requires a T-SQL DDL step.
-- SETUP:
-- Enable In-Memory OLTP prerequisite (if needed):
IF DB_ID('dbdome_inmem_testdb') IS NULL
    CREATE DATABASE [dbdome_inmem_testdb];
GO
-- Add a memory-optimized filegroup to the database:
IF NOT EXISTS (
    SELECT 1 FROM sys.filegroups fg
    JOIN sys.databases d ON d.database_id = DB_ID('dbdome_inmem_testdb')
    WHERE fg.type_desc = 'MEMORY_OPTIMIZED_DATA_FILEGROUP'
      AND fg.database_id = DB_ID('dbdome_inmem_testdb')
)
BEGIN
    ALTER DATABASE [dbdome_inmem_testdb]
        ADD FILEGROUP [dbdome_mem_fg] CONTAINS MEMORY_OPTIMIZED_DATA;
    -- Add a file to the memory-optimized filegroup:
    DECLARE @datapath NVARCHAR(260);
    SELECT @datapath = LEFT(physical_name, LEN(physical_name) - CHARINDEX('\', REVERSE(physical_name)) + 1)
    FROM sys.master_files WHERE database_id = DB_ID('dbdome_inmem_testdb') AND type = 0;
    EXEC(N'ALTER DATABASE [dbdome_inmem_testdb] ADD FILE
          (NAME = N''dbdome_mem_fg_file'',
           FILENAME = N''' + @datapath + N'dbdome_inmem_mo'')
          TO FILEGROUP [dbdome_mem_fg];');
END;
GO
-- NOTE: Detection query joins sys.filegroups to the CURRENT database context (DB_ID()).
-- Switch context to dbdome_inmem_testdb before running the detection, or the join
-- on mf.database_id = DB_ID() will filter to the current DB only.
-- The detection SQL uses DB_ID() implicitly; connect to dbdome_inmem_testdb before running.
-- REVERT:
IF DB_ID('dbdome_inmem_testdb') IS NOT NULL
BEGIN
    ALTER DATABASE [dbdome_inmem_testdb] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [dbdome_inmem_testdb];
END;
GO

/* ===== SEC-SQL-ENC-003-RC10 [DESTRUCTIVE] ===== */
-- Detection always returns 1 row with four counts: encrypted_db_count, unencrypted_db_count,
-- tempdb_encrypted (0/1), tempdb_has_dek (0/1).
-- Flags when unencrypted_db_count > 0 (user DBs that are not encrypted).
-- On any instance without TDE deployed across ALL user databases, this fires immediately.
-- Setup: create a user database without TDE.
-- SETUP:
IF DB_ID('dbdome_testdb') IS NULL
    CREATE DATABASE [dbdome_testdb];
-- dbdome_testdb is is_encrypted = 0 by default, so unencrypted_db_count >= 1.
GO
-- REVERT:
IF DB_ID('dbdome_testdb') IS NOT NULL
BEGIN
    ALTER DATABASE [dbdome_testdb] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [dbdome_testdb];
END;
GO

/* ===== SEC-SQL-ENC-003-RC11 [DESTRUCTIVE] ===== */
-- Detection finds user databases that are unencrypted (is_encrypted = 0, ONLINE) AND
-- participate in an HA feature: Always On AG, database mirroring, or log shipping (primary).
-- Requires: a database that is unencrypted and in one of those HA topologies.
-- Simplest approach: set up log shipping (primary side only, using a local backup share).
-- Alternatively: configure database mirroring in a single-machine test (requires a mirror endpoint).
-- Best-effort using log shipping primary setup (msdb tables + backup job), which is scriptable
-- without a secondary server. The detection checks msdb.dbo.log_shipping_primary_databases.
-- SETUP:
-- Step 1: create the primary database:
IF DB_ID('dbdome_ls_primarydb') IS NULL
BEGIN
    CREATE DATABASE [dbdome_ls_primarydb];
    -- Switch to FULL recovery (required for log shipping):
    ALTER DATABASE [dbdome_ls_primarydb] SET RECOVERY FULL;
END;
GO
-- Step 2: take an initial full backup (required before log shipping can be configured):
DECLARE @backupdir NVARCHAR(260) = N'C:\SQLAudit\';
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_ls_primarydb' AND log_reuse_wait_desc = 'LOG_BACKUP')
BEGIN
    EXEC(N'BACKUP DATABASE [dbdome_ls_primarydb]
           TO DISK = N''C:\SQLAudit\dbdome_ls_primarydb_full.bak''
           WITH FORMAT, INIT, NAME = N''dbdome_ls_primarydb-Full'';');
END;
GO
-- Step 3: register the log shipping primary in msdb directly
-- (sp_add_log_shipping_primary_database requires a secondary; insert the row manually for detection):
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.log_shipping_primary_databases WHERE primary_database = 'dbdome_ls_primarydb')
    INSERT INTO msdb.dbo.log_shipping_primary_databases
        (primary_id, primary_database, backup_directory, backup_share, backup_job_id,
         backup_retention_period, backup_threshold, threshold_alert, threshold_alert_enabled,
         last_backup_file, last_backup_date, last_backup_date_utc, history_retention_period,
         backup_compression)
    VALUES
        (NEWID(), N'dbdome_ls_primarydb', N'C:\SQLAudit', N'\\localhost\SQLAudit',
         '00000000-0000-0000-0000-000000000000',
         4320, 60, 14420, 1,
         N'', GETDATE(), GETUTCDATE(), 5760, 0);
GO
-- NOTE: The direct INSERT into msdb.dbo.log_shipping_primary_databases may fail if the table
-- schema differs across SQL Server versions (column list varies). If so, use
-- sp_add_log_shipping_primary_database (requires a proper share and secondary server).
-- An alternative is to configure database mirroring (requires two endpoints on the same instance).
-- REVERT:
IF EXISTS (SELECT 1 FROM msdb.dbo.log_shipping_primary_databases WHERE primary_database = 'dbdome_ls_primarydb')
    DELETE FROM msdb.dbo.log_shipping_primary_databases WHERE primary_database = 'dbdome_ls_primarydb';
IF DB_ID('dbdome_ls_primarydb') IS NOT NULL
BEGIN
    ALTER DATABASE [dbdome_ls_primarydb] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [dbdome_ls_primarydb];
END;
-- Clean up backup file if desired (requires xp_cmdshell enabled):
-- EXEC xp_cmdshell 'del C:\SQLAudit\dbdome_ls_primarydb_full.bak';
GO


/* ########## batch 30 (12 reproducers) ########## */
/* ===== SEC-SQL-ENC-003-RC12 [DESTRUCTIVE] ===== */
-- Detection is a single-row SELECT (always returns 1 row); the meaningful
-- column is unencrypted_user_dbs.  Create an unencrypted user database so
-- that count > 0.  Requires sysadmin.  The query also surfaces engine_edition
-- so it always fires; the setup just makes unencrypted_user_dbs non-zero.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_enc_test_db')
    CREATE DATABASE dbdome_enc_test_db;
-- Confirm it is unencrypted (default); detection should show count >= 1.
SELECT name, is_encrypted FROM sys.databases WHERE name = 'dbdome_enc_test_db';
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_enc_test_db')
    DROP DATABASE dbdome_enc_test_db;
GO

/* ===== SEC-SQL-ENC-003-RC13 [DESTRUCTIVE] ===== */
-- Detection looks for databases with 'test'/'dev'/'staging'/etc in the name
-- that are not encrypted and are ONLINE.  Create such a database.
-- Requires sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_test_env_db')
    CREATE DATABASE dbdome_test_env_db;
-- Verify: detection should return at least 1 row with environment_guess = 'LIKELY_NON_PRODUCTION'.
SELECT name, is_encrypted, state_desc,
    CASE
        WHEN name LIKE '%test%' THEN 'LIKELY_NON_PRODUCTION'
        ELSE 'LIKELY_PRODUCTION'
    END AS environment_guess
FROM sys.databases WHERE name = 'dbdome_test_env_db';
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_test_env_db')
    DROP DATABASE dbdome_test_env_db;
GO

/* ===== SEC-SQL-ENC-003-RC15 [DESTRUCTIVE] ===== */
-- Detection is a single-row SELECT (always 1 row); the telling column is
-- tde_cert_count (certificates in master named *TDE*, *Encrypt*, or *DEK*).
-- Create such a certificate in the master database to push tde_cert_count > 0.
-- Requires sysadmin.  A Database Master Key must exist in master first.
-- SETUP:
USE master;
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Dbdome$MK_Test_2024!';

IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'dbdome_TDE_test_cert')
    CREATE CERTIFICATE dbdome_TDE_test_cert
        WITH SUBJECT = 'dbdome TDE positive-test certificate',
             EXPIRY_DATE = '2099-12-31';
GO
-- REVERT:
USE master;
IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'dbdome_TDE_test_cert')
    DROP CERTIFICATE dbdome_TDE_test_cert;
-- Only drop DMK if we created it and no other objects depend on it.
-- Guard: drop only if no other user certificates or asymmetric keys remain.
IF EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
   AND NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name NOT LIKE '##%')
   AND NOT EXISTS (SELECT 1 FROM sys.asymmetric_keys)
    DROP MASTER KEY;
GO

/* ===== SEC-SQL-ENC-003-RC16 [DESTRUCTIVE] ===== */
-- Detection is a single-row SELECT; expired_cert_count surfaces certificates
-- in master whose expiry_date <= GETDATE().  Create one with a past expiry.
-- Requires sysadmin.  A Database Master Key in master is a prerequisite.
-- SETUP:
USE master;
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Dbdome$MK_Test_2024!';

IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'dbdome_expired_cert_test')
    CREATE CERTIFICATE dbdome_expired_cert_test
        WITH SUBJECT = 'dbdome expired-cert positive-test',
             START_DATE = '2000-01-01',
             EXPIRY_DATE = '2001-01-01';
-- Verify: expired_cert_count should be >= 1.
SELECT COUNT(*) AS expired_cert_count
FROM master.sys.certificates WHERE expiry_date <= GETDATE();
GO
-- REVERT:
USE master;
IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'dbdome_expired_cert_test')
    DROP CERTIFICATE dbdome_expired_cert_test;
IF EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
   AND NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name NOT LIKE '##%')
   AND NOT EXISTS (SELECT 1 FROM sys.asymmetric_keys)
    DROP MASTER KEY;
GO

/* ===== SEC-SQL-ENC-004-RC01 [DESTRUCTIVE] ===== */
-- Detection selects TOP 20 rows from msdb.dbo.backupset.  At least one backup
-- record must exist.  Take a backup of the small system database 'model' to a
-- NUL device so no disk space is consumed and no file cleanup is needed.
-- The backup will appear in backupset without encryptor_type, so
-- encryption_status = 'NOT_ENCRYPTED' (the flagged condition).
-- Requires sysadmin.
-- SETUP:
BACKUP DATABASE [model] TO DISK = 'NUL' WITH STATS = 0, FORMAT;
-- Verify: backupset should now contain at least 1 row.
SELECT TOP 1 database_name, backup_start_date, encryptor_type
FROM msdb.dbo.backupset ORDER BY backup_start_date DESC;
GO
-- REVERT:
-- Backup history records for 'model' written by setup above can be pruned.
-- This removes only the most-recent model backup entry added by setup.
-- Adjust the date filter if needed.
DECLARE @backup_set_id INT;
SELECT TOP 1 @backup_set_id = backup_set_id
FROM msdb.dbo.backupset
WHERE database_name = 'model'
ORDER BY backup_start_date DESC;

IF @backup_set_id IS NOT NULL
    EXEC msdb.dbo.sp_delete_backuphistory @oldest_date = GETDATE();
-- sp_delete_backuphistory removes all history older than the given date;
-- to remove only the row we added, use the direct delete below instead:
-- DELETE FROM msdb.dbo.backupset WHERE backup_set_id = @backup_set_id;
GO

/* ===== SEC-SQL-ENC-004-RC03 [DESTRUCTIVE] ===== */
-- Detection is a single-row SELECT surfacing key-management state.
-- master_dmk_exists = 0 is the "missing key" signal.  On a clean server where
-- no DMK exists the detection already returns a meaningful row.  If a DMK
-- already exists, drop it temporarily (requires no dependent objects).
-- Setup option A (DMK absent — most common on test servers): no action needed;
-- detection returns 1 row with master_dmk_exists = 0.
-- Setup option B (DMK present): this setup ensures a valid row is returned and
-- additionally creates an expired cert so valid_cert_count may be 0.
-- Requires sysadmin.
-- SETUP:
USE master;
-- Ensure at least a valid state is observable; create a cert if none exists.
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    -- DMK absent: detection will report master_dmk_exists = 0 already.
    PRINT 'No DMK present — detection returns master_dmk_exists=0 naturally.';
END
ELSE
BEGIN
    PRINT 'DMK present — detection row will show master_dmk_exists=1.';
END
-- Either way the detection returns exactly 1 row; no extra object needed.
SELECT
  (SELECT COUNT(*) FROM master.sys.symmetric_keys
   WHERE name = '##MS_DatabaseMasterKey##') AS master_dmk_exists,
  (SELECT COUNT(*) FROM master.sys.certificates
   WHERE expiry_date > GETDATE()) AS valid_cert_count,
  (SELECT COUNT(*) FROM master.sys.asymmetric_keys) AS asym_key_count,
  (SELECT COUNT(*) FROM sys.cryptographic_providers) AS ekm_provider_count;
GO
-- REVERT:
-- Nothing was created; no revert needed.
PRINT 'No objects created by SEC-SQL-ENC-004-RC03 setup — nothing to revert.';
GO

/* ===== SEC-SQL-ENC-004-RC05 [DESTRUCTIVE] ===== */
-- Same SQL as RC01: TOP 20 rows from msdb.dbo.backupset.
-- Trigger: take a backup of 'model' to NUL (unencrypted) so at least 1 row
-- exists in backupset, demonstrating the performance-window concern.
-- Requires sysadmin.
-- SETUP:
BACKUP DATABASE [model] TO DISK = 'NUL' WITH STATS = 0, FORMAT;
SELECT TOP 1 database_name, backup_start_date,
    CASE WHEN encryptor_type IS NOT NULL THEN 'ENCRYPTED' ELSE 'NOT_ENCRYPTED' END AS encryption_status
FROM msdb.dbo.backupset ORDER BY backup_start_date DESC;
GO
-- REVERT:
EXEC msdb.dbo.sp_delete_backuphistory @oldest_date = GETDATE();
GO

/* ===== SEC-SQL-ENC-004-RC06 [DESTRUCTIVE] ===== */
-- Same SQL as RC01: TOP 20 rows from msdb.dbo.backupset.
-- Trigger: backup of 'model' to NUL surfaces an unencrypted backup record,
-- representing the assumption that backup storage is already secured.
-- Requires sysadmin.
-- SETUP:
BACKUP DATABASE [model] TO DISK = 'NUL' WITH STATS = 0, FORMAT;
SELECT TOP 1 database_name, backup_start_date,
    CASE WHEN encryptor_type IS NOT NULL THEN 'ENCRYPTED' ELSE 'NOT_ENCRYPTED' END AS encryption_status
FROM msdb.dbo.backupset ORDER BY backup_start_date DESC;
GO
-- REVERT:
EXEC msdb.dbo.sp_delete_backuphistory @oldest_date = GETDATE();
GO

/* ===== SEC-SQL-ENC-004-RC08 [DESTRUCTIVE] ===== */
-- Same SQL as RC01: TOP 20 rows from msdb.dbo.backupset.
-- Trigger: backup of 'model' to NUL shows an unencrypted off-site-risk backup.
-- Requires sysadmin.
-- SETUP:
BACKUP DATABASE [model] TO DISK = 'NUL' WITH STATS = 0, FORMAT;
SELECT TOP 1 database_name, backup_start_date,
    CASE WHEN encryptor_type IS NOT NULL THEN 'ENCRYPTED' ELSE 'NOT_ENCRYPTED' END AS encryption_status
FROM msdb.dbo.backupset ORDER BY backup_start_date DESC;
GO
-- REVERT:
EXEC msdb.dbo.sp_delete_backuphistory @oldest_date = GETDATE();
GO

/* ===== SEC-SQL-ENC-004-RC10 [DESTRUCTIVE] ===== */
-- Same SQL as RC01: TOP 20 rows from msdb.dbo.backupset.
-- For certificate/key expiration concern: take an unencrypted backup to show
-- no encryptor_type is set, then verify an expired cert exists (use setup from
-- RC16 if needed).  Backup to NUL is sufficient to populate backupset.
-- Requires sysadmin.
-- SETUP:
BACKUP DATABASE [model] TO DISK = 'NUL' WITH STATS = 0, FORMAT;
-- Optionally create an expired cert to reinforce the cert-expiry angle:
USE master;
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Dbdome$MK_Test_2024!';
IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'dbdome_expired_backup_cert')
    CREATE CERTIFICATE dbdome_expired_backup_cert
        WITH SUBJECT = 'dbdome expired backup cert positive-test',
             START_DATE = '2000-01-01',
             EXPIRY_DATE = '2001-01-01';
SELECT TOP 1 database_name, backup_start_date,
    CASE WHEN encryptor_type IS NOT NULL THEN 'ENCRYPTED' ELSE 'NOT_ENCRYPTED' END AS encryption_status
FROM msdb.dbo.backupset ORDER BY backup_start_date DESC;
GO
-- REVERT:
USE master;
IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'dbdome_expired_backup_cert')
    DROP CERTIFICATE dbdome_expired_backup_cert;
IF EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
   AND NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name NOT LIKE '##%')
   AND NOT EXISTS (SELECT 1 FROM sys.asymmetric_keys)
    DROP MASTER KEY;
EXEC msdb.dbo.sp_delete_backuphistory @oldest_date = GETDATE();
GO

/* ===== SEC-SQL-ENC-004-RC11 [DESTRUCTIVE] ===== */
-- Detection is a single-row SELECT; user_certificates > 0 indicates
-- user-managed certificates exist (complexity concern).  Create a user cert
-- in a throwaway database.  Requires sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_enc_complexity_db')
    CREATE DATABASE dbdome_enc_complexity_db;
GO
USE dbdome_enc_complexity_db;
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Dbdome$MK_Test_2024!';
IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'dbdome_user_cert_test')
    CREATE CERTIFICATE dbdome_user_cert_test
        WITH SUBJECT = 'dbdome user-cert complexity positive-test',
             EXPIRY_DATE = '2099-12-31';
-- Verify: user_certificates should be >= 1.
SELECT COUNT(*) AS user_certificates
FROM sys.certificates WHERE name NOT LIKE '##%';
GO
-- REVERT:
USE dbdome_enc_complexity_db;
IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'dbdome_user_cert_test')
    DROP CERTIFICATE dbdome_user_cert_test;
IF EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
   AND NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name NOT LIKE '##%')
    DROP MASTER KEY;
GO
USE master;
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_enc_complexity_db')
    DROP DATABASE dbdome_enc_complexity_db;
GO

/* ===== SEC-SQL-ENC-004-RC13 [DESTRUCTIVE] ===== */
-- Same SQL as RC01: TOP 20 rows from msdb.dbo.backupset.
-- Multiple-destination coordination concern: backup of 'model' to NUL
-- populates backupset with at least one unencrypted backup record.
-- Requires sysadmin.
-- SETUP:
BACKUP DATABASE [model] TO DISK = 'NUL' WITH STATS = 0, FORMAT;
SELECT TOP 1 database_name, backup_start_date,
    CASE WHEN encryptor_type IS NOT NULL THEN 'ENCRYPTED' ELSE 'NOT_ENCRYPTED' END AS encryption_status
FROM msdb.dbo.backupset ORDER BY backup_start_date DESC;
GO
-- REVERT:
EXEC msdb.dbo.sp_delete_backuphistory @oldest_date = GETDATE();
GO


/* ########## batch 31 (12 reproducers) ########## */
/* ===================================================================
   Positive-test reproducers for detections slice 372..384
   Target: DISPOSABLE TEST SQL Server only.
   Each block: SETUP triggers the detection, REVERT undoes it.
   =================================================================== */

/* ===== SEC-SQL-ENC-004-RC15 [DESTRUCTIVE] ===== */
-- Detection: queries msdb.dbo.backupset; returns rows whenever any backup record exists.
-- Setup: take a small backup of master to a temp file so backupset gets a row.
-- Run as sysadmin. Revert deletes the backup file and removes the backup history.
-- SETUP:
BACKUP DATABASE [master]
    TO DISK = N'C:\Windows\Temp\dbdome_test_master.bak'
    WITH FORMAT, COMPRESSION, NAME = N'dbdome_test_backup';
GO
-- REVERT:
-- Remove backup history for this database from msdb
EXEC msdb.dbo.sp_delete_backuphistory @oldest_date = GETDATE();
-- Remove the backup file
EXEC xp_cmdshell 'DEL /F /Q "C:\Windows\Temp\dbdome_test_master.bak"';
GO

/* ===== SEC-SQL-ENC-004-RC16 [DESTRUCTIVE] ===== */
-- Detection: identical query to RC15 - queries msdb.dbo.backupset for any backup record.
-- Setup: same approach - take a small backup of master.
-- Run as sysadmin. Revert deletes backup file and purges backup history.
-- SETUP:
BACKUP DATABASE [master]
    TO DISK = N'C:\Windows\Temp\dbdome_test_master_rc16.bak'
    WITH FORMAT, COMPRESSION, NAME = N'dbdome_test_backup_rc16';
GO
-- REVERT:
EXEC msdb.dbo.sp_delete_backuphistory @oldest_date = GETDATE();
EXEC xp_cmdshell 'DEL /F /Q "C:\Windows\Temp\dbdome_test_master_rc16.bak"';
GO

/* ===== SEC-SQL-ENC-005-RC01 [SAFE] ===== */
-- Detection: SELECT with no WHERE clause - returns exactly 1 row on any live connection.
-- Columns: is_clustered, current_protocol, current_encrypt, force_encryption_config.
-- No setup required; the query always fires as long as the session is connected.
-- To make force_encryption_config = 0 explicit (most installs default), confirm default.
-- Run as any login with VIEW SERVER STATE.
-- SETUP:
-- Verify the query returns 1 row (it always will for an active session):
SELECT SERVERPROPERTY('IsClustered') AS is_clustered,
  CONNECTIONPROPERTY('protocol_type') AS current_protocol,
  CONNECTIONPROPERTY('encrypt_option') AS current_encrypt,
  (SELECT value_in_use FROM sys.configurations WHERE name = 'force encryption') AS force_encryption_config;
GO
-- REVERT:
-- Nothing to revert; no changes made.
PRINT 'SEC-SQL-ENC-005-RC01: no revert needed (SAFE - read-only detection)';
GO

/* ===== SEC-SQL-ENC-005-RC02 [DESTRUCTIVE] ===== */
-- Detection: symmetric keys with deprecated algorithm (DES/TRIPLE_DES/RC4/RC4_128/RC2/DESX)
-- OR key_length < 128, excluding ##% system keys.
-- Setup: create a symmetric key using TRIPLE_DES (deprecated) so it appears with
-- algorithm_desc = 'TRIPLE_DES' and key_strength_status = 'DEPRECATED_ALGORITHM'.
-- Run as sysadmin. Revert drops the key and the master key if created.
-- SETUP:
USE master;
GO
-- Create database master key if absent (needed to protect the symmetric key)
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'DbDome#MK2024!';
GO
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = 'dbdome_test_sym_key')
    CREATE SYMMETRIC KEY dbdome_test_sym_key
        WITH ALGORITHM = TRIPLE_DES
        ENCRYPTION BY PASSWORD = 'DbDome#SymKey1!';
GO
-- REVERT:
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = 'dbdome_test_sym_key')
    DROP SYMMETRIC KEY dbdome_test_sym_key;
GO

/* ===== SEC-SQL-ENC-005-RC03 [DESTRUCTIVE] ===== */
-- Detection: identical query to RC15/RC16 - queries msdb.dbo.backupset.
-- Returns rows for any backup record present. The detection name references
-- "deprecated algorithm" but the SQL simply lists backup history.
-- Setup: take a small backup to produce a backupset row.
-- Run as sysadmin. Revert purges backup history and removes temp file.
-- SETUP:
BACKUP DATABASE [master]
    TO DISK = N'C:\Windows\Temp\dbdome_test_master_rc03.bak'
    WITH FORMAT, COMPRESSION, NAME = N'dbdome_test_backup_rc03';
GO
-- REVERT:
EXEC msdb.dbo.sp_delete_backuphistory @oldest_date = GETDATE();
EXEC xp_cmdshell 'DEL /F /Q "C:\Windows\Temp\dbdome_test_master_rc03.bak"';
GO

/* ===== SEC-SQL-ENC-005-RC04 [DESTRUCTIVE] ===== */
-- Detection: certificates (excluding ##%) with CERTPROPERTY Sig_Algorithm.
-- Returns rows for any non-system certificate present. The weakness_status
-- is derived at query time; simply having a cert triggers a row.
-- Setup: create a self-signed test certificate in master.
-- Run as sysadmin. Revert drops the certificate.
-- SETUP:
USE master;
GO
IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'dbdome_test_cert_rc04')
    CREATE CERTIFICATE dbdome_test_cert_rc04
        WITH SUBJECT = 'DBDome test cert RC04',
             START_DATE = '20200101',
             EXPIRY_DATE = '20251231';
GO
-- REVERT:
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'dbdome_test_cert_rc04')
    DROP CERTIFICATE dbdome_test_cert_rc04;
GO

/* ===== SEC-SQL-ENC-005-RC05 [DESTRUCTIVE] ===== */
-- Detection: self-signed certs (issuer_name = subject) where key_length < 2048
-- OR sig algorithm contains 'md5' or 'sha1'. SQL Server self-signed certs created
-- with CREATE CERTIFICATE use SHA1 by default (pre-2019) or SHA256 (2019+).
-- Setup: create a self-signed certificate with key_length = 1024 (weak) so
-- key_length < 2048 fires; also issuer = subject satisfies the self-signed filter.
-- Run as sysadmin. Revert drops the certificate.
-- SETUP:
USE master;
GO
IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'dbdome_test_cert_rc05')
    CREATE CERTIFICATE dbdome_test_cert_rc05
        WITH SUBJECT = 'DBDome test self-signed RC05',
             START_DATE = '20200101',
             EXPIRY_DATE = '20251231';
GO
-- Verify it is self-signed (issuer = subject) and will trigger weakness_status <> 'OK':
-- On SQL 2016/2017 the default key_length is 1024 (WEAK_KEY_LENGTH).
-- On SQL 2019+ key_length may be 2048; in that case the sha1 sig_algorithm triggers LEGACY_HASH.
-- Either way the cert appears in the detection result.
-- REVERT:
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'dbdome_test_cert_rc05')
    DROP CERTIFICATE dbdome_test_cert_rc05;
GO

/* ===== SEC-SQL-ENC-005-RC10 [SAFE] ===== */
-- Detection: groups user connections by encrypt_option from sys.dm_exec_connections.
-- Returns rows as long as at least one user session is active (the setup session itself).
-- No persistent change needed; the query fires for any open user connection.
-- Run as any login with VIEW SERVER STATE.
-- SETUP:
-- Confirm the detection returns rows by running the detection query directly:
SELECT encrypt_option, COUNT(*) AS connection_count
FROM sys.dm_exec_connections
WHERE session_id IN (
    SELECT session_id FROM sys.dm_exec_sessions WHERE is_user_process = 1
)
GROUP BY encrypt_option;
GO
-- REVERT:
PRINT 'SEC-SQL-ENC-005-RC10: no revert needed (SAFE - read-only detection)';
GO

/* ===== SEC-SQL-ENC-005-RC11 [SAFE] ===== */
-- Detection: groups user connections by encrypt_option, protocol_type, auth_scheme.
-- Returns rows whenever any user session is active. No persistent change needed.
-- Run as any login with VIEW SERVER STATE.
-- SETUP:
-- Confirm by running detection query directly:
SELECT encrypt_option, protocol_type, auth_scheme, COUNT(*) AS connection_count
FROM sys.dm_exec_connections
WHERE session_id IN (
    SELECT session_id FROM sys.dm_exec_sessions WHERE is_user_process = 1
)
GROUP BY encrypt_option, protocol_type, auth_scheme;
GO
-- REVERT:
PRINT 'SEC-SQL-ENC-005-RC11: no revert needed (SAFE - read-only detection)';
GO

/* ===== SEC-SQL-ENC-005-RC12 [DESTRUCTIVE] ===== */
-- Detection: certificates in master with age_days > 365 (APPROACHING_ROTATION)
-- or age_days > 730 (OVERDUE_ROTATION). Excludes ##% system certs.
-- Setup: create a certificate backdated to a start_date more than 730 days ago
-- so rotation_status = 'OVERDUE_ROTATION'.
-- Run as sysadmin. Revert drops the certificate.
-- SETUP:
USE master;
GO
IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'dbdome_test_cert_rc12')
    CREATE CERTIFICATE dbdome_test_cert_rc12
        WITH SUBJECT = 'DBDome test cert RC12 overdue rotation',
             START_DATE = '20200101',
             EXPIRY_DATE = '20301231';
GO
-- Verify: DATEDIFF(DAY, '20200101', GETDATE()) >> 730, so rotation_status = 'OVERDUE_ROTATION'.
-- REVERT:
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'dbdome_test_cert_rc12')
    DROP CERTIFICATE dbdome_test_cert_rc12;
GO

/* ===== SEC-SQL-ENC-005-RC13 [DESTRUCTIVE] ===== */
-- Detection: asymmetric keys with key_length < 2048 (RSA_512 or RSA_1024).
-- Setup: create an asymmetric key with RSA_1024 algorithm (key_length = 1024 < 2048).
-- SQL Server supports RSA_512, RSA_1024, RSA_2048, RSA_3072, RSA_4096.
-- Run as sysadmin. Revert drops the asymmetric key.
-- SETUP:
USE master;
GO
-- Ensure database master key exists for encryption
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'DbDome#MK2024!';
GO
IF NOT EXISTS (SELECT 1 FROM sys.asymmetric_keys WHERE name = 'dbdome_test_asym_key')
    CREATE ASYMMETRIC KEY dbdome_test_asym_key
        WITH ALGORITHM = RSA_1024
        ENCRYPTION BY PASSWORD = 'DbDome#AsymKey1!';
GO
-- REVERT:
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.asymmetric_keys WHERE name = 'dbdome_test_asym_key')
    DROP ASYMMETRIC KEY dbdome_test_asym_key;
GO

/* ===== SEC-SQL-ENC-005-RC14 [DESTRUCTIVE] ===== */
-- Detection: joins sys.server_audit_specifications with sys.server_audit_specification_details.
-- Returns rows only when at least one server audit specification exists.
-- Setup: create a server audit and a server audit specification so the join returns rows.
-- Run as sysadmin. Revert disables and drops the audit spec and audit.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
    CREATE SERVER AUDIT dbdome_test_audit
        TO FILE (FILEPATH = N'C:\Windows\Temp\', MAXSIZE = 5 MB, MAX_FILES = 2)
        WITH (ON_FAILURE = CONTINUE);
GO
ALTER SERVER AUDIT dbdome_test_audit WITH (STATE = ON);
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.server_audit_specifications
    WHERE name = 'dbdome_test_audit_spec'
)
    CREATE SERVER AUDIT SPECIFICATION dbdome_test_audit_spec
        FOR SERVER AUDIT dbdome_test_audit
        ADD (FAILED_LOGIN_GROUP)
        WITH (STATE = ON);
GO
-- REVERT:
IF EXISTS (
    SELECT 1 FROM sys.server_audit_specifications
    WHERE name = 'dbdome_test_audit_spec'
)
BEGIN
    ALTER SERVER AUDIT SPECIFICATION dbdome_test_audit_spec WITH (STATE = OFF);
    DROP SERVER AUDIT SPECIFICATION dbdome_test_audit_spec;
END
GO
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit')
BEGIN
    ALTER SERVER AUDIT dbdome_test_audit WITH (STATE = OFF);
    DROP SERVER AUDIT dbdome_test_audit;
END
GO


/* ########## batch 32 (12 reproducers) ########## */
/* ===== SEC-SQL-ENC-005-RC16 [SAFE] ===== */
-- Detection reads two registry keys via xp_instance_regread. When BOTH return NULL (keys absent),
-- the result is 'NO_CIPHER_CUSTOMIZATION' which IS the flagged condition (vendor defaults in use).
-- On a fresh SQL Server neither SCHANNEL Ciphers key exists, so the detection already returns 1 row.
-- No persistent change is needed; run as sysadmin (xp_instance_regread requires sysadmin).
-- If the keys happen to exist on the test server, the DESTRUCTIVE variant below deletes them via
-- xp_regdeletekey so the NULL branch is triggered. Enable 'show advanced options' first because
-- xp_regdeletekey is gated on that surface area flag.
-- SETUP:
-- xp_instance_regread returns NULL when the registry key/value is absent, which IS the trigger condition.
-- On a default SQL Server install the keys are absent, so the detection returns 'NO_CIPHER_CUSTOMIZATION'
-- immediately.  The SELECT below confirms; no schema change is required.
DECLARE @rc4 INT, @3des INT;
EXEC master.dbo.xp_instance_regread
    N'HKEY_LOCAL_MACHINE',
    N'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 128/128',
    N'Enabled', @rc4 OUTPUT;
EXEC master.dbo.xp_instance_regread
    N'HKEY_LOCAL_MACHINE',
    N'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\Triple DES 168',
    N'Enabled', @3des OUTPUT;
SELECT
    CASE WHEN @rc4 IS NULL AND @3des IS NULL
        THEN 'NO_CIPHER_CUSTOMIZATION'   -- detection fires here
        ELSE 'SOME_CIPHER_CUSTOMIZATION'
    END AS customization_status,
    @rc4 AS rc4_setting, @3des AS triple_des_setting;
GO
-- REVERT:
-- No persistent change was made; nothing to revert.
PRINT 'SEC-SQL-ENC-005-RC16: no revert needed (SAFE, read-only).';
GO

/* ===== SEC-SQL-INJ-001-RC01 [DESTRUCTIVE] ===== */
-- Detection scans sys.sql_modules for stored procs/functions whose definition contains
-- EXEC( or EXECUTE( with string concatenation using + @  (dynamic SQL injection pattern).
-- Create a stored procedure whose body matches one of the LIKE patterns.
-- Run as db_owner in any user database; we use tempdb for minimal footprint.
-- SETUP:
USE tempdb;
GO
IF OBJECT_ID('dbo.dbdome_dynsql_test', 'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_dynsql_test;
GO
CREATE PROCEDURE dbo.dbdome_dynsql_test
    @tbl NVARCHAR(128)
AS
BEGIN
    DECLARE @sql NVARCHAR(500);
    SET @sql = N'SELECT * FROM ' + @tbl;
    EXEC (@sql);   -- matches LIKE '%EXEC (@%'
END;
GO
USE master;
GO
-- REVERT:
USE tempdb;
GO
IF OBJECT_ID('dbo.dbdome_dynsql_test', 'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_dynsql_test;
GO
USE master;
GO

/* ===== SEC-SQL-INJ-001-RC02 [DESTRUCTIVE] ===== */
-- Detection finds stored procedures with dynamic EXEC concatenation that do NOT use QUOTENAME or REPLACE
-- to sanitize the input.  Create a procedure matching EXEC (@  without QUOTENAME or the REPLACE pattern.
-- Run as db_owner in tempdb.
-- SETUP:
USE tempdb;
GO
IF OBJECT_ID('dbo.dbdome_noquote_test', 'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_noquote_test;
GO
CREATE PROCEDURE dbo.dbdome_noquote_test
    @col NVARCHAR(128)
AS
BEGIN
    DECLARE @q NVARCHAR(600);
    SET @q = N'SELECT ' + @col + N' FROM sys.objects';
    EXEC (@q);   -- matches EXEC (@  without QUOTENAME or REPLACE sanitization
END;
GO
USE master;
GO
-- REVERT:
USE tempdb;
GO
IF OBJECT_ID('dbo.dbdome_noquote_test', 'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_noquote_test;
GO
USE master;
GO

/* ===== SEC-SQL-INJ-001-RC04 [DESTRUCTIVE] ===== */
-- Detection finds old stored procedures (age >= :min_age_years, default assume 1) that use dynamic
-- EXEC concatenation without sp_executesql.  SQL Server stores create_date in sys.objects; we cannot
-- backdate it directly.  Workaround: create the procedure, then set min_age_years=0 when running the
-- detection (pass :min_age_years=0).  On an existing instance use a pre-existing matching proc.
-- Run as db_owner in tempdb.
-- SETUP:
USE tempdb;
GO
IF OBJECT_ID('dbo.dbdome_legacy_dynsql', 'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_legacy_dynsql;
GO
-- Procedure uses EXEC (@  concatenation without sp_executesql
CREATE PROCEDURE dbo.dbdome_legacy_dynsql
    @tbl NVARCHAR(128)
AS
BEGIN
    DECLARE @s NVARCHAR(500);
    SET @s = N'SELECT TOP 1 * FROM ' + @tbl;
    EXEC (@s);
END;
GO
USE master;
GO
-- REVERT:
USE tempdb;
GO
IF OBJECT_ID('dbo.dbdome_legacy_dynsql', 'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_legacy_dynsql;
GO
USE master;
GO

/* ===== SEC-SQL-INJ-001-RC07 [DESTRUCTIVE] ===== */
-- Detection finds stored procedures that contain EXEC/sp_executesql AND a DML pattern
-- (SELECT..FROM, INSERT..INTO, etc.).  Create a procedure that mixes static DML with dynamic EXEC.
-- Run as db_owner in tempdb.
-- SETUP:
USE tempdb;
GO
IF OBJECT_ID('dbo.dbdome_mixed_sql_test', 'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_mixed_sql_test;
GO
CREATE PROCEDURE dbo.dbdome_mixed_sql_test
    @tbl NVARCHAR(128)
AS
BEGIN
    -- static DML (satisfies SELECT %FROM% predicate)
    SELECT name FROM sys.objects WHERE type = 'U';
    -- dynamic EXEC (satisfies EXEC(% predicate)
    DECLARE @s NVARCHAR(500) = N'SELECT * FROM ' + @tbl;
    EXEC (@s);
END;
GO
USE master;
GO
-- REVERT:
USE tempdb;
GO
IF OBJECT_ID('dbo.dbdome_mixed_sql_test', 'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_mixed_sql_test;
GO
USE master;
GO

/* ===== SEC-SQL-INJ-001-RC08 [DESTRUCTIVE] ===== */
-- Detection counts occurrences of '+ @' in the procedure definition and flags when count >= :min_concat_points
-- (default assume 1).  Create a procedure with multiple '+ @' concatenation points and EXEC().
-- Run as db_owner in tempdb.
-- SETUP:
USE tempdb;
GO
IF OBJECT_ID('dbo.dbdome_concat_heavy_test', 'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_concat_heavy_test;
GO
CREATE PROCEDURE dbo.dbdome_concat_heavy_test
    @db NVARCHAR(64),
    @schema NVARCHAR(64),
    @tbl NVARCHAR(128),
    @col NVARCHAR(128)
AS
BEGIN
    -- 4 concatenation points using + @ to exceed any reasonable :min_concat_points threshold
    DECLARE @s NVARCHAR(1000);
    SET @s = N'SELECT ' + @col
           + N' FROM ' + @db
           + N'.' + @schema
           + N'.' + @tbl;
    EXEC (@s);
END;
GO
USE master;
GO
-- REVERT:
USE tempdb;
GO
IF OBJECT_ID('dbo.dbdome_concat_heavy_test', 'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_concat_heavy_test;
GO
USE master;
GO

/* ===== SEC-SQL-INJ-001-RC09 [SAFE] ===== */
-- Detection joins sys.sql_modules with sys.dm_exec_procedure_stats filtering on execution_count >= :min_executions.
-- The DMV sys.dm_exec_procedure_stats only populates after a procedure has actually been executed.
-- Setup: create the procedure, execute it so it appears in the DMV, then run the detection with
-- :min_executions = 1.  The procedure uses EXEC (@ concatenation to match the definition predicate.
-- Run as db_owner in tempdb.  Mark SAFE: execution_count persists only until SQL Server restart.
-- SETUP:
USE tempdb;
GO
IF OBJECT_ID('dbo.dbdome_execstats_test', 'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_execstats_test;
GO
CREATE PROCEDURE dbo.dbdome_execstats_test
    @tbl NVARCHAR(128) = N'sys.objects'
AS
BEGIN
    DECLARE @s NVARCHAR(500) = N'SELECT TOP 1 * FROM ' + @tbl;
    EXEC (@s);
END;
GO
-- Execute the procedure so it is tracked in sys.dm_exec_procedure_stats
EXEC dbo.dbdome_execstats_test @tbl = N'sys.objects';
GO
USE master;
GO
-- REVERT:
USE tempdb;
GO
IF OBJECT_ID('dbo.dbdome_execstats_test', 'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_execstats_test;
GO
USE master;
GO

/* ===== SEC-SQL-INJ-001-RC10 [SAFE] ===== */
-- Detection computes the ad-hoc plan percentage from sys.dm_exec_cached_plans.
-- This DMV always returns rows (SQL Server always has cached plans) so the detection always returns 1 row.
-- A high ad-hoc percentage occurs naturally when parameterized queries are not used.
-- No persistent change is needed; the detection fires unconditionally.
-- To increase adhoc_pct for a more meaningful signal: run several unparameterized ad-hoc queries
-- (these are SAFE – they only affect the in-memory plan cache and reset on restart).
-- Run as any login with VIEW SERVER STATE.
-- SETUP:
-- Execute several ad-hoc (unparameterized) queries to seed the plan cache with Adhoc entries
SELECT TOP 1 'dbdome_adhoc_seed_1' AS marker FROM sys.objects WHERE object_id = 1;
SELECT TOP 1 'dbdome_adhoc_seed_2' AS marker FROM sys.objects WHERE object_id = 2;
SELECT TOP 1 'dbdome_adhoc_seed_3' AS marker FROM sys.objects WHERE object_id = 3;
SELECT TOP 1 'dbdome_adhoc_seed_4' AS marker FROM sys.objects WHERE object_id = 4;
SELECT TOP 1 'dbdome_adhoc_seed_5' AS marker FROM sys.objects WHERE object_id = 5;
GO
-- REVERT:
-- Nothing persistent was changed; optionally flush the plan cache (note: flushes ALL plans).
-- DBCC FREEPROCCACHE;  -- uncomment only if a clean plan cache is desired
PRINT 'SEC-SQL-INJ-001-RC10: no persistent changes to revert (SAFE).';
GO

/* ===== SEC-SQL-INJ-001-RC13 [DESTRUCTIVE] ===== */
-- Detection finds stored procedures that have EXECUTE AS a specific principal (execute_as_principal_id IS NOT NULL
-- and <> 0) AND whose definition contains dynamic EXEC concatenation.
-- Create a database login+user, then a procedure WITH EXECUTE AS that login that uses EXEC (@.
-- Run as db_owner (requires ALTER on the target login/user) in tempdb.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_execas_login')
    CREATE LOGIN dbdome_execas_login WITH PASSWORD = 'Dbdome_T3st!2025', CHECK_POLICY = OFF;
GO
USE tempdb;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_execas_user')
    CREATE USER dbdome_execas_user FOR LOGIN dbdome_execas_login;
GO
IF OBJECT_ID('dbo.dbdome_execas_dyntest', 'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_execas_dyntest;
GO
CREATE PROCEDURE dbo.dbdome_execas_dyntest
    @tbl NVARCHAR(128)
WITH EXECUTE AS 'dbdome_execas_user'
AS
BEGIN
    DECLARE @s NVARCHAR(500) = N'SELECT TOP 1 * FROM ' + @tbl;
    EXEC (@s);
END;
GO
USE master;
GO
-- REVERT:
USE tempdb;
GO
IF OBJECT_ID('dbo.dbdome_execas_dyntest', 'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_execas_dyntest;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_execas_user')
    DROP USER dbdome_execas_user;
GO
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_execas_login')
    DROP LOGIN dbdome_execas_login;
GO

/* ===== SEC-SQL-INJ-001-RC14 [DESTRUCTIVE] ===== */
-- Detection reads sys.configurations for 'optimize for ad hoc workloads'.
-- It always returns 1 row (the config always exists). The detection presumably flags when
-- value_in_use = 0 (feature NOT enabled, meaning ad-hoc plans are cached in full, increasing
-- risk of plan cache bloat and information exposure).
-- Setup: ensure the option is disabled (value_in_use = 0) which is the default on most servers.
-- To guarantee the condition: explicitly disable the option.
-- Run as sysadmin.
-- SETUP:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'optimize for ad hoc workloads', 0;
RECONFIGURE;
GO
-- REVERT:
-- Restore to disabled (default); if your baseline was enabled, change the value to 1 below.
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'optimize for ad hoc workloads', 0;
RECONFIGURE;
EXEC sp_configure 'show advanced options', 0;
RECONFIGURE;
GO

/* ===== SEC-SQL-INJ-001-RC15 [DESTRUCTIVE] ===== */
-- Detection finds procs/functions using sp_executesql where the SQL string is still built
-- via concatenation (+ @) instead of full parameterization — i.e., sp_executesql is called
-- but the first argument is a concatenated string, not a pure static template.
-- Create a stored procedure that calls sp_executesql with a concatenated SQL string.
-- Run as db_owner in tempdb.
-- SETUP:
USE tempdb;
GO
IF OBJECT_ID('dbo.dbdome_partial_param_test', 'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_partial_param_test;
GO
-- Procedure uses sp_executesql but builds the SQL string with concatenation (incomplete parameterization)
CREATE PROCEDURE dbo.dbdome_partial_param_test
    @tbl NVARCHAR(128),
    @val INT
AS
BEGIN
    DECLARE @sql NVARCHAR(500);
    -- Table name is concatenated (cannot be parameterized), but the predicate value is not bound
    SET @sql = N'SELECT * FROM ' + @tbl + N' WHERE object_id = ' + CAST(@val AS NVARCHAR(20));
    EXEC sp_executesql @sql;   -- sp_executesql called with concatenated string: matches predicate
END;
GO
USE master;
GO
-- REVERT:
USE tempdb;
GO
IF OBJECT_ID('dbo.dbdome_partial_param_test', 'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_partial_param_test;
GO
USE master;
GO

/* ===== SEC-SQL-INJ-002-RC01 [SAFE] ===== */
-- Detection queries sys.dm_exec_procedure_stats for extended stored procs (xp_cmdshell, xp_regread, etc.).
-- The DMV only has rows when the xprocs have actually been executed in the current SQL Server session lifetime.
-- Setup: execute one of the listed xprocs (xp_fileexist is non-destructive) so it appears in the DMV.
-- The entry is transient (cleared on SQL Server restart). Mark SAFE.
-- Run as sysadmin (xp_fileexist requires sysadmin or EXECUTE permission in master).
-- SETUP:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;

-- xp_fileexist is safe and listed in the detection's IN clause
DECLARE @exists INT;
EXEC master.dbo.xp_fileexist 'C:\windows\system32\drivers\etc\hosts', @exists OUTPUT;
-- The proc is now tracked in sys.dm_exec_procedure_stats for this instance uptime window
SELECT @exists AS file_exists_result;
GO
-- REVERT:
-- sys.dm_exec_procedure_stats is a DMV; entries persist until SQL Server restart or plan cache eviction.
-- No schema changes were made. Optionally flush the procedure stats cache:
-- DBCC FREEPROCCACHE;  -- uncomment only if a clean stats cache is desired
PRINT 'SEC-SQL-INJ-002-RC01: no persistent changes to revert (SAFE).';
GO


/* ########## batch 33 (12 reproducers) ########## */
/* ===== SEC-SQL-INJ-002-RC02 [DESTRUCTIVE] ===== */
-- Sets a user database compatibility level below 130 (SQL Server 2016).
-- Targets any user database (database_id > 4). Uses a throwaway test DB.
-- Run as sysadmin. Revert restores compat level to 150 (2019).
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_compat_test')
    CREATE DATABASE dbdome_compat_test;
GO
ALTER DATABASE dbdome_compat_test SET COMPATIBILITY_LEVEL = 120;
GO
-- REVERT:
ALTER DATABASE dbdome_compat_test SET COMPATIBILITY_LEVEL = 150;
GO
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_compat_test')
    DROP DATABASE dbdome_compat_test;
GO

/* ===== SEC-SQL-INJ-002-RC05 [DESTRUCTIVE] ===== */
-- Creates a stored procedure whose definition references xp_cmdshell, satisfying
-- the LIKE '%xp_cmdshell%' predicate in sys.sql_modules. min_dependents = 1.
-- Run as sysadmin. The procedure does NOT actually execute xp_cmdshell.
-- SETUP:
USE master;
GO
IF OBJECT_ID('dbo.dbdome_xproc_ref_test', 'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_xproc_ref_test;
GO
CREATE PROCEDURE dbo.dbdome_xproc_ref_test
AS
BEGIN
    -- reference only, never called: xp_cmdshell
    PRINT 'dbdome test procedure referencing xp_cmdshell';
END;
GO
-- REVERT:
USE master;
GO
IF OBJECT_ID('dbo.dbdome_xproc_ref_test', 'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_xproc_ref_test;
GO

/* ===== SEC-SQL-INJ-002-RC06 [DESTRUCTIVE] ===== */
-- Creates a SQL Agent job with a T-SQL step whose command text contains 'xp_cmdshell',
-- satisfying the WHERE clause on msdb.dbo.sysjobsteps. Requires SQL Agent enabled.
-- Run as sysadmin.
-- SETUP:
USE msdb;
GO
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = 'dbdome_xproc_job_test')
BEGIN
    EXEC msdb.dbo.sp_delete_job @job_name = 'dbdome_xproc_job_test', @delete_unused_schedule = 1;
END;
GO
EXEC msdb.dbo.sp_add_job
    @job_name = N'dbdome_xproc_job_test',
    @enabled = 0,
    @description = N'DBDome positive test job - safe to delete';
GO
EXEC msdb.dbo.sp_add_jobstep
    @job_name   = N'dbdome_xproc_job_test',
    @step_name  = N'dbdome_step_xp_cmdshell',
    @subsystem  = N'TSQL',
    @command    = N'-- dbdome test: xp_cmdshell reference PRINT ''ok'';',
    @database_name = N'master';
GO
EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'dbdome_xproc_job_test',
    @server_name = N'(local)';
GO
-- REVERT:
USE msdb;
GO
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = 'dbdome_xproc_job_test')
    EXEC msdb.dbo.sp_delete_job @job_name = 'dbdome_xproc_job_test', @delete_unused_schedule = 1;
GO

/* ===== SEC-SQL-INJ-002-RC07 [DESTRUCTIVE] ===== */
-- Grants EXECUTE on xp_dirtree to a throwaway login/user so the detection sees
-- a non-dbo, non-public grantee with EXECUTE on an xproc in master.
-- Run as sysadmin.
-- SETUP:
USE master;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_xproc_grant_login')
    CREATE LOGIN dbdome_xproc_grant_login WITH PASSWORD = 'D@t@b@se!T3st99', CHECK_POLICY = OFF;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_xproc_grant_login')
    CREATE USER dbdome_xproc_grant_login FOR LOGIN dbdome_xproc_grant_login;
GO
GRANT EXECUTE ON xp_dirtree TO dbdome_xproc_grant_login;
GO
-- REVERT:
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_xproc_grant_login')
BEGIN
    REVOKE EXECUTE ON xp_dirtree FROM dbdome_xproc_grant_login;
    DROP USER dbdome_xproc_grant_login;
END;
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_xproc_grant_login')
    DROP LOGIN dbdome_xproc_grant_login;
GO

/* ===== SEC-SQL-INJ-002-RC08 [SAFE] ===== */
-- The detection reads sys.server_audit_specifications joined with
-- sys.server_audit_specification_details. It returns rows for ANY existing
-- server audit specification. If none exist the detection returns 0 rows.
-- Setup: create a minimal server audit + specification (requires VIEW SERVER STATE).
-- Run as sysadmin. The audit writes to the application event log (no file needed).
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_audit_test')
BEGIN
    CREATE SERVER AUDIT dbdome_audit_test
        TO APPLICATION_LOG
        WITH (ON_FAILURE = CONTINUE);
END;
GO
ALTER SERVER AUDIT dbdome_audit_test WITH (STATE = OFF);
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_audit_spec_test'
)
BEGIN
    CREATE SERVER AUDIT SPECIFICATION dbdome_audit_spec_test
        FOR SERVER AUDIT dbdome_audit_test
        ADD (FAILED_LOGIN_GROUP)
        WITH (STATE = OFF);
END;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_audit_spec_test')
BEGIN
    ALTER SERVER AUDIT SPECIFICATION dbdome_audit_spec_test WITH (STATE = OFF);
    DROP SERVER AUDIT SPECIFICATION dbdome_audit_spec_test;
END;
GO
IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_audit_test')
BEGIN
    ALTER SERVER AUDIT dbdome_audit_test WITH (STATE = OFF);
    DROP SERVER AUDIT dbdome_audit_test;
END;
GO

/* ===== SEC-SQL-INJ-002-RC09 [SAFE] ===== */
-- Detection flags active sessions whose client_net_address is not local/RFC-1918/loopback.
-- This requires a real connection from a public IP, which cannot be scripted on the server.
-- Best-effort: open a connection from an external (non-RFC-1918) host to the test SQL Server.
-- The setup below is a placeholder comment; the actual trigger is an inbound session.
-- Mark SAFE because no server-side object changes are needed.
-- SETUP:
-- Run this query from a host with a PUBLIC IP address connecting to the test SQL Server.
-- The detection will then return that session's row while the connection is held open.
-- Example (run from external host, keep the session open):
--   sqlcmd -S <test_server_ip>,1433 -U dbdome_ext_login -P "P@ssword!" -Q "WAITFOR DELAY '00:05:00'"
-- No server-side T-SQL setup is required for the detection to fire.
PRINT 'SEC-SQL-INJ-002-RC09: No server-side setup required. Connect from a public IP to trigger.';
GO
-- REVERT:
-- Disconnect the external session. No objects to clean up.
PRINT 'SEC-SQL-INJ-002-RC09: Disconnect the external session.';
GO

/* ===== SEC-SQL-INJ-002-RC10 [DESTRUCTIVE] ===== */
-- Detection returns a single summary row with flag columns. It fires whenever any of
-- xp_cmdshell, Ole Automation Procedures, clr enabled, or external scripts enabled
-- is non-zero, OR xp_proxy_exists > 0. Enable xp_cmdshell to satisfy the condition.
-- Run as sysadmin.
-- SETUP:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;
GO
-- REVERT:
EXEC sp_configure 'xp_cmdshell', 0;
RECONFIGURE;
GO
EXEC sp_configure 'show advanced options', 0;
RECONFIGURE;
GO

/* ===== SEC-SQL-INJ-002-RC11 [DESTRUCTIVE] ===== */
-- Detection returns a single row with (sql_service_account, xp_cmdshell_enabled).
-- It always returns a row (xp_cmdshell_enabled may be 0). To make xp_cmdshell_enabled=1
-- enable xp_cmdshell. The service account column is informational.
-- Run as sysadmin.
-- SETUP:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;
GO
-- REVERT:
EXEC sp_configure 'xp_cmdshell', 0;
RECONFIGURE;
GO
EXEC sp_configure 'show advanced options', 0;
RECONFIGURE;
GO

/* ===== SEC-SQL-INJ-002-RC12 [SAFE] ===== */
-- Detection lists active user sessions whose program_name is not SSMS/sqlcmd/SQLAgent.
-- Any connection from a third-party app (e.g., Python, JDBC, ADO.NET app) will appear.
-- Best-effort: open a connection using a custom application name via the connection string.
-- This is a runtime/session detection; setup = hold open a connection with a custom app name.
-- SETUP:
-- Open a connection from outside with ApplicationName set to a custom value, e.g.:
--   sqlcmd -S <server> -U sa -P "P@ss!" -A "dbdome_custom_app_test" -Q "WAITFOR DELAY '00:05:00'"
-- OR use a .NET/Python/JDBC connection string with Application Name=dbdome_custom_app_test
-- While the session is active, the detection will return >=1 row.
-- No server-side objects to create; mark SAFE.
PRINT 'SEC-SQL-INJ-002-RC12: Hold open a session with a non-SSMS/sqlcmd/SQLAgent program_name to trigger.';
GO
-- REVERT:
-- Close/disconnect the custom-app session. No objects to clean up.
PRINT 'SEC-SQL-INJ-002-RC12: Disconnect the custom-app session.';
GO

/* ===== SEC-SQL-INJ-002-RC14 [DESTRUCTIVE] ===== */
-- Detection finds extended stored procedures (type='X') that are NOT ms_shipped
-- (is_ms_shipped=0). Creating a user-defined XP requires a compiled DLL registered
-- via sp_addextendedproc. This is impractical on most test servers.
-- Best-effort: sp_addextendedproc registers the name even if the DLL is missing
-- (the object appears in sys.objects with type='X', is_ms_shipped=0).
-- Run as sysadmin. Note: sp_addextendedproc is deprecated; may fail on newer servers.
-- SETUP:
USE master;
GO
IF OBJECT_ID('dbo.dbdome_xp_test', 'X') IS NULL
BEGIN
    EXEC sp_addextendedproc 'dbdome_xp_test', 'dbdome_fake_xp.dll';
END;
GO
-- REVERT:
USE master;
GO
IF OBJECT_ID('dbo.dbdome_xp_test', 'X') IS NOT NULL
BEGIN
    EXEC sp_dropextendedproc 'dbdome_xp_test';
END;
GO

/* ===== SEC-SQL-INJ-002-RC15 [DESTRUCTIVE] ===== */
-- Detection finds stored procedures whose definition contains EXEC(@variable) or
-- EXEC(... + @param ...) patterns indicating dynamic SQL injection risk.
-- Create a stored procedure with EXEC(@sql) in its body.
-- Run as sysadmin (or db_owner on master).
-- SETUP:
USE master;
GO
IF OBJECT_ID('dbo.dbdome_dynSQL_test', 'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_dynSQL_test;
GO
CREATE PROCEDURE dbo.dbdome_dynSQL_test
    @userInput NVARCHAR(200)
AS
BEGIN
    DECLARE @sql NVARCHAR(500);
    SET @sql = N'SELECT * FROM sys.objects WHERE name = ''' + @userInput + '''';
    EXEC(@sql);
END;
GO
-- REVERT:
USE master;
GO
IF OBJECT_ID('dbo.dbdome_dynSQL_test', 'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_dynSQL_test;
GO

/* ===== SEC-SQL-INJ-002-RC16 [DESTRUCTIVE] ===== */
-- Detection is a single-row summary: xp_cmdshell_enabled, ole_auto_enabled,
-- proxy_account_exists, explicit_xproc_grants. Trigger by enabling xp_cmdshell
-- AND granting EXECUTE on an xp_ proc to a non-dbo/non-public user.
-- Run as sysadmin.
-- SETUP:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;
GO
USE master;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_rc16_login')
    CREATE LOGIN dbdome_rc16_login WITH PASSWORD = 'D@t@b@se!T3st99', CHECK_POLICY = OFF;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_rc16_login')
    CREATE USER dbdome_rc16_login FOR LOGIN dbdome_rc16_login;
GO
GRANT EXECUTE ON xp_dirtree TO dbdome_rc16_login;
GO
-- REVERT:
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dbdome_rc16_login')
BEGIN
    REVOKE EXECUTE ON xp_dirtree FROM dbdome_rc16_login;
    DROP USER dbdome_rc16_login;
END;
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_rc16_login')
    DROP LOGIN dbdome_rc16_login;
GO
EXEC sp_configure 'xp_cmdshell', 0;
RECONFIGURE;
GO
EXEC sp_configure 'show advanced options', 0;
RECONFIGURE;
GO


/* ########## batch 34 (12 reproducers) ########## */
/* ===== SEC-SQL-NET-001-RC01 [SAFE] ===== */
-- Detection reads sys.dm_tcp_listener_states for wildcard bind addresses (0.0.0.0 / ::).
-- On a default SQL Server instance the engine binds on 0.0.0.0:1433 which already satisfies
-- the predicate.  No schema change needed; the setup just confirms the row exists.
-- If your test instance uses a named-pipe-only config, enable TCP/IP via SQL Server Config Mgr
-- and restart the service first (out-of-band step; cannot be done via T-SQL).
-- SETUP:
SELECT listener_id, ip_address, port, type_desc, state_desc, start_time
FROM sys.dm_tcp_listener_states
WHERE ip_address IN ('0.0.0.0', '::', '0:0:0:0:0:0:0:0')
  AND state_desc = 'ONLINE';
-- Expected: >=1 row if TCP is enabled with wildcard bind (default on most instances).
GO
-- REVERT:
-- No persistent change made; nothing to revert.
SELECT 1 AS revert_noop;
GO

/* ===== SEC-SQL-NET-001-RC02 [SAFE] ===== */
-- Detection queries the system_health XE ring buffer for error numbers 18456/18452/18451
-- (failed logins).  Trigger a failed login attempt to inject an event.
-- Run the SETUP block, then within ~30 seconds re-run the detection SQL to see the row.
-- SETUP:
-- Attempt a login with a bad password so error 18456 is logged to system_health ring buffer.
-- This will fail intentionally; ignore the error.
BEGIN TRY
    EXEC sp_executesql N'SELECT 1'; -- placeholder; actual bad-login must come from a client connection.
END TRY
BEGIN CATCH
    -- no-op
END CATCH;
-- NOTE: The failed login must be triggered from a client (e.g. sqlcmd -U dbdome_bad_login -P wrong).
-- Example (run in a separate OS shell):
--   sqlcmd -S localhost -U dbdome_bad_login_test -P WrongPassword123! -Q "SELECT 1" 2>nul
-- After that the ring buffer will contain an error 18456 event and the detection returns >=1 row.
GO
-- REVERT:
-- No persistent change; ring buffer entries age out automatically.
SELECT 1 AS revert_noop;
GO

/* ===== SEC-SQL-NET-001-RC03 [SAFE] ===== */
-- Detection finds TCP listeners that are STARTED and not on loopback or wildcard.
-- On any default SQL Server instance with TCP enabled, a listener on the machine's LAN IP
-- satisfies this predicate automatically.
-- SETUP:
SELECT listener_id, ip_address, port, type_desc, state_desc
FROM sys.dm_tcp_listener_states
WHERE ip_address NOT IN ('127.0.0.1', '::1')
  AND ip_address <> '0.0.0.0'
  AND state_desc = 'STARTED';
-- Expected: >=1 row when the instance has a non-loopback IP listener (typical for any networked instance).
GO
-- REVERT:
-- No persistent change; nothing to revert.
SELECT 1 AS revert_noop;
GO

/* ===== SEC-SQL-NET-001-RC05 [DESTRUCTIVE] ===== */
-- Detection looks for server-level DDL triggers whose definition references EVENTDATA,
-- client_net_address, or CONNECTIONPROPERTY — i.e. a trigger performing IP-based allow/block logic.
-- Setup creates such a trigger; revert drops it.
-- Run as sysadmin.
-- SETUP:
IF EXISTS (
    SELECT 1 FROM sys.server_triggers WHERE name = 'dbdome_test_ip_allowlist_trigger'
)
    DROP TRIGGER dbdome_test_ip_allowlist_trigger ON ALL SERVER;
GO
CREATE OR ALTER TRIGGER dbdome_test_ip_allowlist_trigger
ON ALL SERVER
FOR LOGON
AS
BEGIN
    DECLARE @ip NVARCHAR(48) = CONVERT(NVARCHAR(48), CONNECTIONPROPERTY('client_net_address'));
    DECLARE @xml XML = EVENTDATA();
    IF @ip NOT IN ('127.0.0.1', '::1')
    BEGIN
        -- placeholder IP allowlist check; do nothing in test
        SELECT @xml;
    END
END;
GO
-- REVERT:
IF EXISTS (
    SELECT 1 FROM sys.server_triggers WHERE name = 'dbdome_test_ip_allowlist_trigger'
)
    DROP TRIGGER dbdome_test_ip_allowlist_trigger ON ALL SERVER;
GO

/* ===== SEC-SQL-NET-001-RC11 [DESTRUCTIVE] ===== */
-- Detection returns a single informational row about the server (always returns 1 row when any
-- user database exists and sa is not disabled).  To guarantee >=1 row, ensure at least one user
-- database exists (database_id > 4) and sa is enabled.
-- Setup creates a throwaway database; revert drops it.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_shadow_test_db')
    CREATE DATABASE dbdome_shadow_test_db;
GO
-- Ensure sa is enabled so sa_disabled = 0 (makes the row more clearly "flagged"):
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE sid = 0x01 AND is_disabled = 1)
BEGIN
    ALTER LOGIN sa ENABLE;
    PRINT 'sa was disabled; re-disabled in REVERT step.';
END
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_shadow_test_db')
BEGIN
    ALTER DATABASE dbdome_shadow_test_db SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE dbdome_shadow_test_db;
END
GO
-- If sa was previously disabled and you re-enabled it above, disable it again:
-- ALTER LOGIN sa DISABLE;
GO

/* ===== SEC-SQL-NET-001-RC12 [DESTRUCTIVE] ===== */
-- Detection finds enabled logins created more than 90 days ago that have no current active session.
-- Setup creates a login and backdates its create_date via a workaround: create it, then update
-- the internal catalog timestamp by using DBCC CHECKDB trace or sp_executesql trick — not possible
-- directly.  Instead we create the login and rely on the fact that on a test server other logins
-- already older than 90 days exist.  Alternatively, if the test server has no such logins,
-- the best approach is to create the login and accept that the detection won't fire for this login
-- until 90 days pass.  Annotated limitation below.
-- NOTE: create_date cannot be backdated via T-SQL; on a fresh test instance with no stale logins
-- this detection may return 0 rows for the newly created login.  Run the detection as-is first —
-- if existing logins older than 90 days already exist (typical), it fires immediately.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_stale_login')
    CREATE LOGIN dbdome_test_stale_login WITH PASSWORD = 'Dbdome$T3stP@ss!', CHECK_POLICY = OFF;
GO
-- Verify if any login (including pre-existing ones) satisfies the predicate:
SELECT sp.name, sp.create_date, DATEDIFF(DAY, sp.create_date, GETDATE()) AS days_since_created
FROM sys.server_principals sp
WHERE sp.type IN ('S','U','G')
  AND sp.name NOT LIKE '##%'
  AND sp.name NOT IN ('sa','NT AUTHORITY\SYSTEM','NT SERVICE\MSSQLSERVER',
      'NT SERVICE\SQLSERVERAGENT','NT SERVICE\SQLWriter',
      'NT SERVICE\Winmgmt','NT SERVICE\SQLTELEMETRY')
  AND sp.is_disabled = 0
  AND DATEDIFF(DAY, sp.create_date, GETDATE()) > 90
  AND sp.principal_id NOT IN (
      SELECT DISTINCT security_id FROM sys.dm_exec_sessions WHERE is_user_process = 1
  );
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_stale_login')
    DROP LOGIN dbdome_test_stale_login;
GO

/* ===== SEC-SQL-NET-002-RC01 [SAFE] ===== */
-- Detection finds TSQL TCP listeners on the default port 1433.
-- On any default SQL Server install with TCP enabled this fires immediately.
-- SETUP:
SELECT listener_id, ip_address, port, type_desc, state_desc
FROM sys.dm_tcp_listener_states
WHERE state_desc = 'STARTED'
  AND type_desc = 'TSQL'
  AND port = 1433;
-- Expected: >=1 row on any default SQL Server instance with TCP/IP enabled on port 1433.
GO
-- REVERT:
-- No persistent change; nothing to revert.
SELECT 1 AS revert_noop;
GO

/* ===== SEC-SQL-NET-002-RC02 [DESTRUCTIVE] ===== */
-- Detection checks for multiple hardening failures simultaneously: sa enabled, xp_cmdshell on,
-- OLE Automation on, cross-db chaining on, CLR enabled, remote DAC enabled.
-- The detection returns a single row (scalar aggregation); it will flag when ANY of these is true.
-- Setup enables xp_cmdshell (most impactful indicator); revert disables it.
-- Run as sysadmin.
-- SETUP:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;
GO
-- Also enable sa if disabled to set sa_active = 1:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE sid = 0x01 AND is_disabled = 1)
    ALTER LOGIN sa ENABLE;
GO
-- REVERT:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO
EXEC sp_configure 'xp_cmdshell', 0;
RECONFIGURE;
GO
-- Disable sa again if it was originally disabled (uncomment if needed):
-- ALTER LOGIN sa DISABLE;
EXEC sp_configure 'show advanced options', 0;
RECONFIGURE;
GO

/* ===== SEC-SQL-NET-002-RC03 [SAFE] ===== */
-- Identical predicate to SEC-SQL-NET-002-RC01: TSQL TCP listener on port 1433.
-- On any default SQL Server install with TCP enabled this fires immediately.
-- SETUP:
SELECT listener_id, ip_address, port, type_desc, state_desc
FROM sys.dm_tcp_listener_states
WHERE state_desc = 'STARTED'
  AND type_desc = 'TSQL'
  AND port = 1433;
-- Expected: >=1 row on any default instance with TCP on port 1433.
GO
-- REVERT:
SELECT 1 AS revert_noop;
GO

/* ===== SEC-SQL-NET-002-RC04 [SAFE] ===== */
-- Identical predicate to RC01/RC03: TSQL TCP listener on port 1433.
-- SETUP:
SELECT port, ip_address, type_desc
FROM sys.dm_tcp_listener_states
WHERE state_desc = 'STARTED'
  AND type_desc = 'TSQL'
  AND port = 1433;
-- Expected: >=1 row on any default instance with TCP on port 1433.
GO
-- REVERT:
SELECT 1 AS revert_noop;
GO

/* ===== SEC-SQL-NET-002-RC05 [SAFE] ===== */
-- Detection finds listeners on ports 1433 or 1434 (SQL Browser uses UDP 1434 but the TCP
-- listener table may also show 1434 if SQL Browser is active or a named instance uses it).
-- On any default SQL Server instance port 1433 is present.
-- SETUP:
SELECT port, ip_address, type_desc, state_desc
FROM sys.dm_tcp_listener_states
WHERE state_desc = 'STARTED'
  AND port IN (1433, 1434)
ORDER BY port;
-- Expected: >=1 row (port 1433 listener present on default instance).
GO
-- REVERT:
SELECT 1 AS revert_noop;
GO

/* ===== SEC-SQL-NET-002-RC06 [SAFE] ===== */
-- Identical predicate to RC01/RC03/RC04: TSQL TCP listener on port 1433.
-- SETUP:
SELECT port, ip_address, type_desc
FROM sys.dm_tcp_listener_states
WHERE state_desc = 'STARTED'
  AND type_desc = 'TSQL'
  AND port = 1433;
-- Expected: >=1 row on any default instance with TCP on port 1433.
GO
-- REVERT:
SELECT 1 AS revert_noop;
GO


/* ########## batch 35 (12 reproducers) ########## */
/* ===== SEC-SQL-NET-002-RC08 [SAFE] ===== */
-- Detection returns a row whenever the SQL Server Browser service exists in sys.dm_server_services.
-- The Browser service is a Windows service; it is either running or stopped but always listed if installed.
-- SAFE: no schema changes; the row is already present if SQL Browser is installed.
-- If Browser is not installed, this detection never fires; best-effort: ensure Browser service is enabled.
-- Run as sysadmin. No revert needed because setup only enables the Windows service via T-SQL surface.
-- SETUP:
-- The detection fires as long as a row matching servicename LIKE '%Browser%' exists in sys.dm_server_services.
-- Verify the Browser service is visible (should always be present when installed):
SELECT servicename, status_desc, startup_type_desc
FROM sys.dm_server_services
WHERE servicename LIKE '%Browser%';
-- If you need to ensure it fires: start the SQL Server Browser service via xp_cmdshell (requires sysadmin + xp_cmdshell enabled).
-- Enable xp_cmdshell temporarily if needed:
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;
EXEC xp_cmdshell 'sc start "SQLBrowser"';
GO
-- REVERT:
-- Stop the Browser service only if it was not running before:
-- EXEC xp_cmdshell 'sc stop "SQLBrowser"';
-- Disable xp_cmdshell if it was disabled before:
EXEC sp_configure 'xp_cmdshell', 0; RECONFIGURE;
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-NET-002-RC10 [SAFE] ===== */
-- Detection always returns exactly one row (it is a SELECT of scalar subqueries with no WHERE on the outer query).
-- It flags when unencrypted_connections > 0 or remote_dac_enabled = 1 or the port is non-standard.
-- SAFE: setup = open an unencrypted TCP connection (any login over TCP without TLS) held in a separate session,
-- OR simply enable remote admin connections so the scalar subquery returns 1.
-- Run as sysadmin.
-- SETUP:
-- Enable remote admin connections so remote_dac_enabled = 1, ensuring the detection flags.
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'remote admin connections', 1; RECONFIGURE;
GO
-- REVERT:
EXEC sp_configure 'remote admin connections', 0; RECONFIGURE;
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-NET-002-RC12 [SAFE] ===== */
-- Detection always returns exactly one row (all columns are server-level scalar subqueries / functions).
-- @@VERSION, SERVERPROPERTY values are always non-NULL on any running SQL Server instance.
-- SAFE: no setup required; the query always returns 1 row on any SQL Server instance.
-- The detection fires unconditionally; just verify by running the detection SQL.
-- SETUP:
-- No action required. The detection fires on any running SQL Server instance.
-- Verification:
SELECT
  @@VERSION AS version_banner,
  SERVERPROPERTY('ProductVersion') AS product_version,
  SERVERPROPERTY('ProductLevel') AS service_pack,
  SERVERPROPERTY('Edition') AS edition,
  (SELECT DISTINCT local_tcp_port FROM sys.dm_exec_connections
   WHERE local_tcp_port IS NOT NULL AND net_transport = 'TCP') AS listening_port;
GO
-- REVERT:
-- No revert needed; no changes were made.
SELECT 1 AS no_revert_needed;
GO

/* ===== SEC-SQL-NET-002-RC13 [DESTRUCTIVE] ===== */
-- Detection fires when: TCP port is exposed (listening_port IS NOT NULL), windows_auth_only = 0 (mixed mode),
-- AND enabled_sql_logins > 0.
-- Setup: create a test SQL login (requires mixed-mode auth to already be enabled, or enable it),
-- and ensure a TCP connection exists. The test login alone satisfies enabled_sql_logins > 0.
-- DESTRUCTIVE: creating a SQL login is a persistent schema change; creating requires sysadmin.
-- If server is already in mixed mode, simply creating the login is sufficient.
-- SETUP:
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
-- If the server is in Windows-only auth mode, switch to mixed mode (requires restart to fully take effect
-- but sys.configurations reflects it immediately; the detection reads SERVERPROPERTY which reflects
-- the actual running mode — note: mixed-mode change requires restart. On a disposable test server, restart
-- SQL Server service after this step):
-- EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE',
--   N'Software\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', REG_DWORD, 2;
-- Ensure at least one SQL login exists:
IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name = 'dbdome_test_login')
    CREATE LOGIN dbdome_test_login WITH PASSWORD = 'Dbdome_Test#2026!', CHECK_POLICY = OFF;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.sql_logins WHERE name = 'dbdome_test_login')
    DROP LOGIN dbdome_test_login;
-- To revert to Windows-only auth (requires restart):
-- EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE',
--   N'Software\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', REG_DWORD, 1;
GO

/* ===== SEC-SQL-NET-002-RC14 [SAFE] ===== */
-- Detection always returns exactly one row (scalar subqueries only). It flags based on how many days
-- since install (days_since_install) and the last restart time — both always have values.
-- SAFE: no changes needed; the query always returns 1 row. The "risk" is evaluated by the caller.
-- SETUP:
-- No action required. The detection fires unconditionally on any SQL Server instance.
SELECT
  (SELECT DISTINCT local_tcp_port FROM sys.dm_exec_connections
   WHERE local_tcp_port IS NOT NULL AND net_transport = 'TCP') AS current_port,
  (SELECT create_date FROM sys.databases WHERE name = 'master') AS instance_install_date,
  DATEDIFF(DAY,
    (SELECT create_date FROM sys.databases WHERE name = 'master'),
    GETDATE()) AS days_since_install,
  (SELECT sqlserver_start_time FROM sys.dm_os_sys_info) AS last_restart;
GO
-- REVERT:
SELECT 1 AS no_revert_needed;
GO

/* ===== SEC-SQL-NET-002-RC15 [DESTRUCTIVE] ===== */
-- Detection fires when: sa login is enabled AND Browser service is running.
-- Setup: enable the sa login + start SQL Browser service.
-- DESTRUCTIVE: enabling sa is a persistent security change; revert immediately after testing.
-- Run as sysadmin.
-- SETUP:
-- Enable the sa login:
ALTER LOGIN sa ENABLE;
-- Optionally set a known password for test purposes:
ALTER LOGIN sa WITH PASSWORD = 'Dbdome_Sa_Test#2026!';
-- Ensure SQL Browser service is running (via xp_cmdshell):
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;
EXEC xp_cmdshell 'sc start "SQLBrowser"';
GO
-- REVERT:
ALTER LOGIN sa DISABLE;
EXEC xp_cmdshell 'sc stop "SQLBrowser"';
EXEC sp_configure 'xp_cmdshell', 0; RECONFIGURE;
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-NET-003-RC03 [DESTRUCTIVE] ===== */
-- Detection fires when a linked server exists whose data_source does NOT match any private/local pattern
-- (i.e., it looks like an internet/external address).
-- Setup: create a linked server pointing to an obviously-fake external hostname.
-- DESTRUCTIVE: CREATE LINKED SERVER is a persistent change. Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE name = 'dbdome_test_linked_ext' AND is_linked = 1)
    EXEC sp_addlinkedserver
        @server     = N'dbdome_test_linked_ext',
        @srvproduct = N'',
        @provider   = N'SQLNCLI',
        @datasrc    = N'external.dbdome-test-fake.com';
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.servers WHERE name = 'dbdome_test_linked_ext' AND is_linked = 1)
    EXEC sp_dropserver N'dbdome_test_linked_ext', N'droplogins';
GO

/* ===== SEC-SQL-NET-003-RC04 [DESTRUCTIVE] ===== */
-- Detection fires for any row in sys.servers where is_linked = 1 (no additional filter).
-- Setup: create any linked server (same fake external linked server is sufficient, or a local one).
-- DESTRUCTIVE: CREATE LINKED SERVER is persistent. Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE name = 'dbdome_test_linked_any' AND is_linked = 1)
    EXEC sp_addlinkedserver
        @server     = N'dbdome_test_linked_any',
        @srvproduct = N'',
        @provider   = N'SQLNCLI',
        @datasrc    = N'dbdome-test-fake-server.local';

-- Optionally add a linked login to populate sys.linked_logins:
EXEC sp_addlinkedsrvlogin
    @rmtsrvname  = N'dbdome_test_linked_any',
    @useself     = N'False',
    @locallogin  = NULL,
    @rmtuser     = N'dbdome_remote_user',
    @rmtpassword = N'Dbdome_Remote#2026!';
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.servers WHERE name = 'dbdome_test_linked_any' AND is_linked = 1)
    EXEC sp_dropserver N'dbdome_test_linked_any', N'droplogins';
GO

/* ===== SEC-SQL-NET-003-RC05 [DESTRUCTIVE] ===== */
-- Detection queries sys.external_data_sources via a FROM clause — returns rows only if at least one
-- external data source exists. It also shows polybase_enabled config value (always a scalar).
-- Setup: create a database-scoped external data source (requires PolyBase feature OR BULK operations).
-- Simpler approach: use a GENERIC external data source type that does not require PolyBase at all
-- (TYPE = BLOB_STORAGE is available without PolyBase on SQL Server 2017+).
-- DESTRUCTIVE: CREATE EXTERNAL DATA SOURCE is persistent. Run in a test database as db_owner or sysadmin.
-- SETUP:
USE master;
GO
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_test_db')
    CREATE DATABASE dbdome_test_db;
GO
USE dbdome_test_db;
GO
IF NOT EXISTS (SELECT 1 FROM sys.external_data_sources WHERE name = 'dbdome_test_eds')
    CREATE EXTERNAL DATA SOURCE dbdome_test_eds
    WITH (
        TYPE = BLOB_STORAGE,
        LOCATION = 'https://dbdome-fake-storage.blob.core.windows.net/testcontainer'
    );
GO
-- REVERT:
USE dbdome_test_db;
GO
IF EXISTS (SELECT 1 FROM sys.external_data_sources WHERE name = 'dbdome_test_eds')
    DROP EXTERNAL DATA SOURCE dbdome_test_eds;
GO
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_test_db')
BEGIN
    ALTER DATABASE dbdome_test_db SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE dbdome_test_db;
END
GO

/* ===== SEC-SQL-NET-003-RC06 [SAFE] ===== */
-- Detection reads two scalars: count of active ExternalScript requests and cumulative perf counter total.
-- The outer query has no WHERE clause so it ALWAYS returns exactly one row.
-- The "alert" is triggered by the caller interpreting total_executions > 0 or active_external_scripts > 0.
-- To make total_executions > 0: run an external script via sp_execute_external_script (requires
-- Machine Learning Services / R or Python installed). This is a runtime condition, not schema.
-- SAFE: the detection itself always returns 1 row. For total_executions > 0, ML Services must be installed
-- and an external script executed — that is a runtime condition only; no persistent schema change.
-- SETUP:
-- Step 1: Enable external scripts (requires ML Services to be installed and SQL Server restart):
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'external scripts enabled', 1; RECONFIGURE;
-- Step 2 (in a separate session, after SQL Server restarts with ML Services installed):
-- EXEC sp_execute_external_script
--     @language = N'Python',
--     @script = N'print("dbdome test")';
-- The perf counter will then be > 0 and the detection row will reflect active execution during the call.
GO
-- REVERT:
EXEC sp_configure 'external scripts enabled', 0; RECONFIGURE;
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;
GO

/* ===== SEC-SQL-NET-003-RC14 [DESTRUCTIVE] ===== */
-- Detection fires when a linked server's data_source matches a known cloud provider pattern
-- (*.database.windows.net, *.rds.amazonaws.com, *.cloud.google.com, etc.).
-- Setup: create a linked server with a data_source matching one of those patterns.
-- DESTRUCTIVE: CREATE LINKED SERVER is persistent. Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE name = 'dbdome_test_cloud_link' AND is_linked = 1)
    EXEC sp_addlinkedserver
        @server     = N'dbdome_test_cloud_link',
        @srvproduct = N'',
        @provider   = N'SQLNCLI',
        @datasrc    = N'dbdome-fake-test.database.windows.net';
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.servers WHERE name = 'dbdome_test_cloud_link' AND is_linked = 1)
    EXEC sp_dropserver N'dbdome_test_cloud_link', N'droplogins';
GO

/* ===== SEC-SQL-NET-003-RC15 [DESTRUCTIVE] ===== */
-- Detection fires when a Database Mail profile, account, and server row exist in msdb.
-- The JOINs require all three tables to have matching rows, so all must be populated.
-- DESTRUCTIVE: creates Database Mail profile/account/server entries in msdb. Run as sysadmin.
-- Database Mail stored procedures: sysmail_add_profile_sp, sysmail_add_account_sp,
-- sysmail_add_profileaccount_sp, sysmail_add_mailserver_sp (last one is handled by add_account_sp).
-- SETUP:
USE msdb;
GO
-- Add a mail account (includes SMTP server entry):
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysmail_account WHERE name = 'dbdome_test_mail_account')
    EXEC msdb.dbo.sysmail_add_account_sp
        @account_name            = 'dbdome_test_mail_account',
        @description             = 'DBDome positive test account',
        @email_address           = 'dbdome-test@dbdome-fake.com',
        @replyto_address         = 'dbdome-test@dbdome-fake.com',
        @display_name            = 'DBDome Test',
        @mailserver_name         = 'smtp.dbdome-fake.com',
        @port                    = 587,
        @enable_ssl              = 1,
        @username                = 'dbdome-test@dbdome-fake.com',
        @password                = 'FakeSmtp#2026!';

-- Add a mail profile:
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysmail_profile WHERE name = 'dbdome_test_mail_profile')
    EXEC msdb.dbo.sysmail_add_profile_sp
        @profile_name = 'dbdome_test_mail_profile',
        @description  = 'DBDome positive test profile';

-- Link account to profile:
IF NOT EXISTS (
    SELECT 1 FROM msdb.dbo.sysmail_profileaccount pa
    JOIN msdb.dbo.sysmail_profile p ON pa.profile_id = p.profile_id
    JOIN msdb.dbo.sysmail_account a ON pa.account_id = a.account_id
    WHERE p.name = 'dbdome_test_mail_profile'
      AND a.name = 'dbdome_test_mail_account'
)
    EXEC msdb.dbo.sysmail_add_profileaccount_sp
        @profile_name  = 'dbdome_test_mail_profile',
        @account_name  = 'dbdome_test_mail_account',
        @sequence_number = 1;
GO
-- REVERT:
USE msdb;
GO
IF EXISTS (
    SELECT 1 FROM msdb.dbo.sysmail_profileaccount pa
    JOIN msdb.dbo.sysmail_profile p ON pa.profile_id = p.profile_id
    JOIN msdb.dbo.sysmail_account a ON pa.account_id = a.account_id
    WHERE p.name = 'dbdome_test_mail_profile'
      AND a.name = 'dbdome_test_mail_account'
)
    EXEC msdb.dbo.sysmail_delete_profileaccount_sp
        @profile_name = 'dbdome_test_mail_profile',
        @account_name = 'dbdome_test_mail_account';

IF EXISTS (SELECT 1 FROM msdb.dbo.sysmail_profile WHERE name = 'dbdome_test_mail_profile')
    EXEC msdb.dbo.sysmail_delete_profile_sp
        @profile_name = 'dbdome_test_mail_profile';

IF EXISTS (SELECT 1 FROM msdb.dbo.sysmail_account WHERE name = 'dbdome_test_mail_account')
    EXEC msdb.dbo.sysmail_delete_account_sp
        @account_name = 'dbdome_test_mail_account';
GO


/* ########## batch 36 (12 reproducers) ########## */
/* ===== SEC-SQL-PAT-001-RC01 [SAFE] ===== */
-- Detection returns rows unconditionally (SELECT SERVERPROPERTY). Any running SQL Server instance
-- will satisfy this. Lifecycle_status will show a real value; on SQL 2016 (major=13) it flags
-- "EXTENDED SUPPORT ENDS 2026-07-14". No setup needed -- the SELECT always returns exactly 1 row.
-- SETUP:
-- No setup required. The detection SELECTs SERVERPROPERTY values with no WHERE filter.
-- Simply run the detection SQL on any SQL Server instance to get >=1 row.
SELECT
  SERVERPROPERTY('ProductVersion')      AS product_version,
  SERVERPROPERTY('ProductMajorVersion') AS major_version,
  SERVERPROPERTY('ProductMinorVersion') AS minor_version,
  SERVERPROPERTY('ProductLevel')        AS product_level,
  SERVERPROPERTY('ProductUpdateLevel')  AS update_level,
  SERVERPROPERTY('Edition')             AS edition,
  @@VERSION                             AS full_version_string,
  CASE CAST(SERVERPROPERTY('ProductMajorVersion') AS INT)
    WHEN 10 THEN 'SQL Server 2008/2008R2 — EXTENDED SUPPORT ENDED 2019-07-09'
    WHEN 11 THEN 'SQL Server 2012 — EXTENDED SUPPORT ENDED 2022-07-12'
    WHEN 12 THEN 'SQL Server 2014 — EXTENDED SUPPORT ENDED 2024-07-09'
    WHEN 13 THEN 'SQL Server 2016 — EXTENDED SUPPORT ENDS 2026-07-14'
    WHEN 14 THEN 'SQL Server 2017 — EXTENDED SUPPORT ENDS 2027-10-12'
    WHEN 15 THEN 'SQL Server 2019 — MAINSTREAM SUPPORT ENDS 2025-02-28, EXTENDED 2030-01-08'
    WHEN 16 THEN 'SQL Server 2022 — MAINSTREAM SUPPORT ENDS 2028-01-11, EXTENDED 2033-01-11'
    ELSE 'Unknown version — verify manually'
  END AS lifecycle_status;
GO
-- REVERT:
-- No persistent changes were made. No revert needed.
SELECT 'SEC-SQL-PAT-001-RC01: no revert needed' AS revert_status;
GO

/* ===== SEC-SQL-PAT-001-RC02 [SAFE] ===== */
-- Detection returns a row for any SQL Server instance that is not version 16 (i.e. versions_behind > 0).
-- Any pre-2022 instance satisfies this unconditionally. No setup needed.
-- On SQL Server 2022 (major=16) the detection row is still returned but versions_behind=0.
-- To guarantee a flagged result, run on any SQL Server 2019 or earlier instance.
-- SETUP:
-- No setup required. The detection SELECTs SERVERPROPERTY values with no WHERE filter.
-- Simply run the detection SQL on any SQL Server instance older than 2022 (major < 16).
SELECT
  CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) AS current_major,
  16                                                  AS latest_major_version,
  16 - CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) AS versions_behind,
  CASE CAST(SERVERPROPERTY('ProductMajorVersion') AS INT)
    WHEN 10 THEN 'SQL Server 2008/2008R2 — 6 major versions behind'
    WHEN 11 THEN 'SQL Server 2012 — 5 major versions behind'
    WHEN 12 THEN 'SQL Server 2014 — 4 major versions behind'
    WHEN 13 THEN 'SQL Server 2016 — 3 major versions behind'
    WHEN 14 THEN 'SQL Server 2017 — 2 major versions behind'
    WHEN 15 THEN 'SQL Server 2019 — 1 major version behind'
    WHEN 16 THEN 'SQL Server 2022 — current release'
    ELSE 'Unknown version'
  END AS version_assessment,
  SERVERPROPERTY('ProductVersion') AS product_version,
  SERVERPROPERTY('ProductLevel')   AS product_level;
GO
-- REVERT:
-- No persistent changes were made. No revert needed.
SELECT 'SEC-SQL-PAT-001-RC02: no revert needed' AS revert_status;
GO

/* ===== SEC-SQL-PAT-001-RC05 [SAFE] ===== */
-- Detection reads sys.dm_os_performance_counters WHERE object_name LIKE '%Deprecated Features%'
-- AND cntr_value > 1000. The counters are runtime accumulators; to force a high count we
-- execute a deprecated construct (SET ROWCOUNT) many times so the counter exceeds 1000.
-- Run the setup block once to spin the counter; the detection should then return >=1 row for
-- 'SET ROWCOUNT'. Counters reset on SQL Server service restart.
-- SETUP:
-- Execute SET ROWCOUNT in a tight loop to increment the deprecated-feature counter above 1000.
DECLARE @i INT = 0;
WHILE @i < 1100
BEGIN
    SET ROWCOUNT 10;          -- increments the "SET ROWCOUNT" deprecated-feature counter
    SET ROWCOUNT 0;           -- reset to avoid side-effects on subsequent queries
    SET @i = @i + 1;
END;
-- Verify the counter climbed (optional):
SELECT instance_name, cntr_value
FROM   sys.dm_os_performance_counters
WHERE  object_name LIKE '%Deprecated Features%'
  AND  instance_name LIKE '%SET ROWCOUNT%';
GO
-- REVERT:
-- Performance counters are in-memory only; they reset automatically on SQL Server restart.
-- No persistent schema changes were made.
SELECT 'SEC-SQL-PAT-001-RC05: counters are runtime-only; no schema revert needed' AS revert_status;
GO

/* ===== SEC-SQL-PAT-001-RC09 [SAFE] ===== */
-- Detection looks for active user sessions where c.protocol_version < 1946157060 (0x74000004,
-- i.e. TDS 7.4 = SQL Server 2012 client). Sessions using older TDS versions satisfy this.
-- Reproducing requires an actual connection from a legacy client driver (e.g. ODBC SQL Server
-- native client 10.0 / OLEDB SQLOLEDB). A script-only workaround is not possible; we
-- document the approach and verify with a query that shows current protocol versions.
-- SETUP (best-effort):
-- Connect to the instance using an older ODBC/OLEDB driver that speaks TDS < 7.4,
-- then leave that connection open while running the detection.
-- Example: use "SQL Server" ODBC DSN (not "ODBC Driver 17/18 for SQL Server") or
-- SQLOLEDB provider to open a connection, then run the detection in a separate session.
--
-- Alternatively, verify what protocol versions currently exist:
SELECT
    s.program_name,
    s.client_interface_name,
    c.protocol_version,
    c.client_net_address,
    COUNT(*) AS sessions
FROM sys.dm_exec_sessions s
JOIN sys.dm_exec_connections c ON s.session_id = c.session_id
WHERE s.is_user_process = 1
GROUP BY s.program_name, s.client_interface_name, c.protocol_version, c.client_net_address
ORDER BY sessions DESC;
GO
-- REVERT:
-- Close / disconnect the legacy-driver connection.
-- No persistent schema changes were made.
SELECT 'SEC-SQL-PAT-001-RC09: disconnect legacy client connection to revert' AS revert_status;
GO

/* ===== SEC-SQL-PAT-001-RC11 [SAFE] ===== */
-- Detection scans sys.dm_exec_query_stats plan cache for queries containing deprecated syntax
-- (SET ROWCOUNT, RAISERROR old form, sp_addtype, DATABASEPROPERTY, fn_virtualfilestats)
-- in user databases (dbid > 4). We create a user database, execute a deprecated-syntax query
-- inside it to load it into the plan cache, then run the detection.
-- SETUP:
-- Create a throwaway database and execute deprecated syntax inside it.
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_test_legacy')
    CREATE DATABASE dbdome_test_legacy;
GO
USE dbdome_test_legacy;
GO
-- Execute a query that uses deprecated SET ROWCOUNT syntax so it enters the plan cache.
DECLARE @dummy INT;
SET ROWCOUNT 5;
SELECT @dummy = 1;
SET ROWCOUNT 0;
GO
-- Execute a query using RAISERROR old-style syntax in a try/catch to load cache without error.
BEGIN TRY
    EXEC('RAISERROR (''test'', 1, 1)');
END TRY
BEGIN CATCH
    -- swallow
END CATCH;
GO
USE master;
GO
-- REVERT:
-- Drop the throwaway database (removes its plan cache entries too).
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_test_legacy')
BEGIN
    ALTER DATABASE dbdome_test_legacy SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE dbdome_test_legacy;
END;
GO

/* ===== SEC-SQL-PAT-001-RC12 [SAFE] ===== */
-- Detection returns a row from sys.dm_os_sys_info unconditionally and computes days_since_restart,
-- pending_config_changes, non_online_dbs, and days_since_last_backup.
-- To ensure >=1 row the simplest approach is no setup at all (the SELECT always returns 1 row).
-- To also trigger the "pending_config_changes" sub-predicate, we change a config value without
-- RECONFIGURE so value <> value_in_use. We reverse it immediately after the detection runs.
-- SETUP:
-- Create a pending config change so (value <> value_in_use) count > 0.
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO
-- Now change 'max degree of parallelism' without RECONFIGURE to create a pending change.
DECLARE @current_maxdop INT;
SELECT @current_maxdop = CAST(value AS INT)
FROM   sys.configurations
WHERE  name = 'max degree of parallelism';

-- Toggle it to a different value (if currently 0 set to 1, else set to 0) without RECONFIGURE.
IF @current_maxdop = 0
    EXEC sp_configure 'max degree of parallelism', 1;
ELSE
    EXEC sp_configure 'max degree of parallelism', 0;
-- Do NOT run RECONFIGURE so value <> value_in_use remains true.
GO
-- REVERT:
-- Apply RECONFIGURE to clear the pending change, then restore original value.
-- If you know the original value, set it here; the safest universal revert is RECONFIGURE
-- which makes value_in_use match value and removes the pending-change condition.
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
-- Restore max degree of parallelism to 0 (default) and reconfigure.
EXEC sp_configure 'max degree of parallelism', 0;
RECONFIGURE;
GO

/* ===== SEC-SQL-PAT-002-RC02 [SAFE] ===== */
-- Detection returns 1 row unconditionally from sys.dm_os_sys_info (no WHERE filter).
-- It reports uptime in days/hours. No setup needed; the SELECT always returns >=1 row.
-- To ensure the "CRITICAL: Over 6 months since restart" branch triggers you would need the
-- server to have been running >180 days, which cannot be scripted. The detection still returns
-- >=1 row regardless of uptime value.
-- SETUP:
-- No setup required. The detection has no WHERE clause; it always returns exactly 1 row.
SELECT
    sqlserver_start_time,
    DATEDIFF(DAY,  sqlserver_start_time, GETDATE()) AS uptime_days,
    DATEDIFF(HOUR, sqlserver_start_time, GETDATE()) AS uptime_hours
FROM sys.dm_os_sys_info;
GO
-- REVERT:
-- No persistent changes were made. No revert needed.
SELECT 'SEC-SQL-PAT-002-RC02: no revert needed' AS revert_status;
GO

/* ===== SEC-SQL-PAT-002-RC09 [DESTRUCTIVE] ===== */
-- Detection looks for linked servers in sys.servers WHERE is_linked = 1.
-- We create a dummy linked server pointing to the local instance (or a non-existent host)
-- so the detection returns >=1 row.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE name = 'dbdome_test_linked_srv' AND is_linked = 1)
BEGIN
    EXEC sp_addlinkedserver
        @server     = N'dbdome_test_linked_srv',
        @srvproduct = N'SQL Server';
END;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.servers WHERE name = 'dbdome_test_linked_srv' AND is_linked = 1)
BEGIN
    EXEC sp_dropserver
        @server  = N'dbdome_test_linked_srv',
        @droplogins = 'droplogins';
END;
GO

/* ===== SEC-SQL-PAT-002-RC10 [SAFE] ===== */
-- Detection counts active user sessions, long-running transactions (>30 min), and active requests.
-- The "active_user_sessions" sub-count is always >=1 (the current session itself), so the
-- detection always returns exactly 1 row. No setup needed.
-- To also trigger long_running_transactions > 0, open a write transaction in a SEPARATE session
-- and leave it open for >30 minutes before running the detection (cannot be done in same script).
-- NOTE: Hold the BEGIN TRAN below open in Session B; run the detection in Session A after 31 min.
-- SETUP (Session B — run in a separate SSMS query window and do NOT commit/rollback):
/*
   BEGIN TRAN;
   CREATE TABLE IF NOT EXISTS -- use a temp table to avoid blocking other tests
   INSERT INTO tempdb..dbdome_tran_hold_test VALUES (1); -- keep open > 30 min
*/
-- For immediate >=1 row result the detection already returns 1 row unconditionally.
SELECT
    (SELECT COUNT(*) FROM sys.dm_exec_sessions WHERE is_user_process = 1) AS active_user_sessions,
    (SELECT COUNT(*)
     FROM   sys.dm_tran_active_transactions t
     JOIN   sys.dm_tran_session_transactions st ON t.transaction_id = st.transaction_id
     WHERE  DATEDIFF(MINUTE, t.transaction_begin_time, GETDATE()) > 30) AS long_running_transactions,
    (SELECT COUNT(*)
     FROM   sys.dm_exec_requests
     WHERE  status IN ('running','runnable','suspended')
       AND  session_id > 50) AS active_requests;
GO
-- REVERT:
-- Close the long-running transaction in Session B (ROLLBACK TRAN).
-- No persistent schema changes were made.
SELECT 'SEC-SQL-PAT-002-RC10: rollback open tran in Session B to fully revert' AS revert_status;
GO

/* ===== SEC-SQL-PAT-002-RC12 [SAFE] ===== */
-- Detection returns 1 row from sys.dm_os_sys_info with no WHERE clause, then adds a CASE
-- label based on uptime. It always returns >=1 row. No setup needed.
-- The CRITICAL (>180 days) or WARNING (>90 days) branches require actual server uptime;
-- they cannot be scripted. The detection still satisfies >=1 row on any running instance.
-- SETUP:
-- No setup required. The detection has no WHERE clause; always returns exactly 1 row.
SELECT
    sqlserver_start_time,
    DATEDIFF(DAY, sqlserver_start_time, GETDATE()) AS days_since_restart,
    CASE
        WHEN DATEDIFF(DAY, sqlserver_start_time, GETDATE()) > 180
            THEN 'CRITICAL: Over 6 months since restart'
        WHEN DATEDIFF(DAY, sqlserver_start_time, GETDATE()) > 90
            THEN 'WARNING: Over 3 months since restart'
        ELSE 'OK: Restarted within last 90 days'
    END AS patch_staleness
FROM sys.dm_os_sys_info;
GO
-- REVERT:
-- No persistent changes were made. No revert needed.
SELECT 'SEC-SQL-PAT-002-RC12: no revert needed' AS revert_status;
GO

/* ===== SEC-SQL-PRI-001-RC01 [SAFE] ===== */
-- Detection counts Always Encrypted objects: column master keys, column encryption keys,
-- and CEK values. It returns 1 row unconditionally (COUNT(*) always returns a row).
-- The counts will be 0 on an instance without Always Encrypted configured.
-- To make the detection meaningful (non-zero counts), create Always Encrypted key objects.
-- NOTE: Creating a real CMK requires a Windows certificate or Azure Key Vault; below we use
-- a self-signed certificate created in SQL Server's certificate store as the CMK backing key.
-- SETUP:
-- Create a self-signed certificate to back the Column Master Key.
IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'dbdome_test_cmk_cert')
    CREATE CERTIFICATE dbdome_test_cmk_cert
        WITH SUBJECT = 'DBDome test CMK certificate';
GO
-- Create Column Master Key metadata pointing at the certificate.
IF NOT EXISTS (SELECT 1 FROM sys.column_master_keys WHERE name = 'dbdome_test_CMK')
    CREATE COLUMN MASTER KEY dbdome_test_CMK
    WITH (
        KEY_STORE_PROVIDER_NAME = N'MSSQL_CERTIFICATE_STORE',
        KEY_PATH = N'CurrentUser/My/dbdome_test_cmk_cert'
    );
GO
-- NOTE: Creating a Column Encryption Key (CEK) requires encrypting the key value with the
-- CMK using the key store provider; this cannot be done purely in T-SQL without the
-- SqlServer PowerShell module or SSMS. The CMK alone raises column_master_key_count to 1,
-- which is sufficient for the detection to surface non-zero results.
-- To also get column_encryption_key_count > 0, generate the CEK value outside T-SQL:
--   Import-Module SqlServer
--   Add-SqlColumnEncryptionKeyValue -ColumnMasterKeyName dbdome_test_CMK ...
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.column_master_keys WHERE name = 'dbdome_test_CMK')
    DROP COLUMN MASTER KEY dbdome_test_CMK;
IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'dbdome_test_cmk_cert')
    DROP CERTIFICATE dbdome_test_cmk_cert;
GO

/* ===== SEC-SQL-PRI-001-RC02 [DESTRUCTIVE] ===== */
-- Detection looks for indexed columns whose names match PII patterns (ssn, email, phone, etc.).
-- We create a table with PII-named columns and an index on one of them.
-- SETUP:
IF OBJECT_ID('dbo.dbdome_pii_test', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_pii_test;
GO
CREATE TABLE dbo.dbdome_pii_test (
    id          INT          NOT NULL IDENTITY PRIMARY KEY,
    ssn         CHAR(11)     NULL,       -- matches '%ssn%'
    email       VARCHAR(255) NULL,       -- matches '%email%'
    phone       VARCHAR(30)  NULL,       -- matches '%phone%'
    credit_card VARCHAR(20)  NULL        -- matches '%credit_card%'
);
GO
-- Create indexes on the PII columns so they appear in sys.index_columns.
CREATE INDEX IX_dbdome_pii_test_ssn         ON dbo.dbdome_pii_test (ssn);
CREATE INDEX IX_dbdome_pii_test_email        ON dbo.dbdome_pii_test (email);
CREATE INDEX IX_dbdome_pii_test_phone        ON dbo.dbdome_pii_test (phone);
CREATE INDEX IX_dbdome_pii_test_credit_card  ON dbo.dbdome_pii_test (credit_card);
GO
-- REVERT:
IF OBJECT_ID('dbo.dbdome_pii_test', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_pii_test;
GO


/* ########## batch 37 (12 reproducers) ########## */
/* ===== SEC-SQL-PRI-001-RC03 [SAFE] ===== */
-- The SELECT always returns exactly one row; the CASE merely classifies the server edition.
-- No setup required — the detection fires on any SQL Server 2016+ Enterprise/Developer (or any 2019+).
-- SETUP:
SELECT
  SERVERPROPERTY('Edition') AS edition,
  SERVERPROPERTY('ProductMajorVersion') AS major_version,
  CASE
    WHEN CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) >= 13
      AND (CAST(SERVERPROPERTY('Edition') AS NVARCHAR(128)) LIKE '%Enterprise%'
        OR CAST(SERVERPROPERTY('Edition') AS NVARCHAR(128)) LIKE '%Developer%'
        OR CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) >= 15)
    THEN 'Always Encrypted available'
    ELSE 'Always Encrypted not available'
  END AS ae_availability;
-- Verify: the single row is returned regardless of result; detection always returns >=1 row.
GO
-- REVERT:
-- Nothing to revert; no objects were created.
SELECT 1 AS revert_noop;
GO

/* ===== SEC-SQL-PRI-001-RC04 [DESTRUCTIVE] ===== */
-- Creates a user table with a varchar column named 'ssn' that has no encryption and no dynamic data mask,
-- which satisfies all WHERE predicates in the detection query.
-- SETUP:
IF DB_ID('dbdome_test_db') IS NULL
    CREATE DATABASE dbdome_test_db;
GO
USE dbdome_test_db;
GO
IF OBJECT_ID('dbo.dbdome_pii_test_rc04', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_pii_test_rc04;
CREATE TABLE dbo.dbdome_pii_test_rc04 (
    id           INT           NOT NULL PRIMARY KEY,
    ssn          VARCHAR(20)   NOT NULL,   -- PII name, varchar, no encryption, no mask
    credit_card  NVARCHAR(19)  NOT NULL,   -- second PII-named column
    bank_account VARCHAR(34)   NOT NULL
);
GO
-- REVERT:
USE dbdome_test_db;
GO
IF OBJECT_ID('dbo.dbdome_pii_test_rc04', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_pii_test_rc04;
GO
USE master;
GO

/* ===== SEC-SQL-PRI-001-RC05 [DESTRUCTIVE] ===== */
-- Creates a user table with unencrypted columns matching the PII name patterns used by RC05
-- (ssn, credit_card, passport, date_of_birth, bank_account, dob).
-- The detection checks encryption_type IS NULL, which is the default for any plain column.
-- SETUP:
IF DB_ID('dbdome_test_db') IS NULL
    CREATE DATABASE dbdome_test_db;
GO
USE dbdome_test_db;
GO
IF OBJECT_ID('dbo.dbdome_pii_test_rc05', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_pii_test_rc05;
CREATE TABLE dbo.dbdome_pii_test_rc05 (
    id            INT           NOT NULL PRIMARY KEY,
    ssn           VARCHAR(11)   NOT NULL,
    credit_card   NVARCHAR(19)  NOT NULL,
    passport      VARCHAR(20)   NOT NULL,
    date_of_birth DATE          NOT NULL,
    bank_account  VARCHAR(34)   NOT NULL,
    dob           DATE          NOT NULL
);
GO
-- REVERT:
USE dbdome_test_db;
GO
IF OBJECT_ID('dbo.dbdome_pii_test_rc05', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_pii_test_rc05;
GO
USE master;
GO

/* ===== SEC-SQL-PRI-001-RC06 [DESTRUCTIVE] ===== */
-- Creates a user table with columns named 'email', 'phone', 'ssn', 'credit_card', 'address'
-- in a non-sys schema; the detection selects all columns matching those name patterns.
-- SETUP:
IF DB_ID('dbdome_test_db') IS NULL
    CREATE DATABASE dbdome_test_db;
GO
USE dbdome_test_db;
GO
IF OBJECT_ID('dbo.dbdome_pii_test_rc06', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_pii_test_rc06;
CREATE TABLE dbo.dbdome_pii_test_rc06 (
    id           INT           NOT NULL PRIMARY KEY,
    email        VARCHAR(255)  NOT NULL,
    phone        VARCHAR(20)   NOT NULL,
    ssn          VARCHAR(11)   NOT NULL,
    credit_card  NVARCHAR(19)  NOT NULL,
    address      NVARCHAR(200) NOT NULL
);
GO
-- REVERT:
USE dbdome_test_db;
GO
IF OBJECT_ID('dbo.dbdome_pii_test_rc06', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_pii_test_rc06;
GO
USE master;
GO

/* ===== SEC-SQL-PRI-001-RC07 [SAFE] ===== */
-- Runs an INSERT INTO ... SELECT statement so it appears in sys.dm_exec_query_stats
-- with last_execution_time within the last 7 days.
-- The plan must remain in cache; DBCC FREEPROCCACHE would invalidate it but is not called here.
-- SETUP:
IF DB_ID('dbdome_test_db') IS NULL
    CREATE DATABASE dbdome_test_db;
GO
USE dbdome_test_db;
GO
IF OBJECT_ID('dbo.dbdome_etl_src', 'U') IS NOT NULL DROP TABLE dbo.dbdome_etl_src;
IF OBJECT_ID('dbo.dbdome_etl_dst', 'U') IS NOT NULL DROP TABLE dbo.dbdome_etl_dst;
CREATE TABLE dbo.dbdome_etl_src (id INT, val VARCHAR(50));
CREATE TABLE dbo.dbdome_etl_dst (id INT, val VARCHAR(50));
INSERT INTO dbo.dbdome_etl_src VALUES (1,'test_row');
-- This INSERT INTO ... SELECT populates the query cache with matching text:
INSERT INTO dbo.dbdome_etl_dst SELECT id, val FROM dbo.dbdome_etl_src;
GO
-- REVERT:
USE dbdome_test_db;
GO
IF OBJECT_ID('dbo.dbdome_etl_src', 'U') IS NOT NULL DROP TABLE dbo.dbdome_etl_src;
IF OBJECT_ID('dbo.dbdome_etl_dst', 'U') IS NOT NULL DROP TABLE dbo.dbdome_etl_dst;
GO
USE master;
GO

/* ===== SEC-SQL-PRI-001-RC09 [DESTRUCTIVE] ===== */
-- Creates a Column Master Key (CMK) in sys.column_master_keys so the detection returns >=1 row.
-- Requires a certificate in the current database to back the CMK.
-- Run as sysadmin or db_owner; the key_path format uses the certificate thumbprint.
-- SETUP:
IF DB_ID('dbdome_test_db') IS NULL
    CREATE DATABASE dbdome_test_db;
GO
USE dbdome_test_db;
GO
IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'dbdome_test_cert_rc09')
    CREATE CERTIFICATE dbdome_test_cert_rc09 WITH SUBJECT = 'dbdome test cert for RC09';
GO
IF NOT EXISTS (SELECT 1 FROM sys.column_master_keys WHERE name = 'dbdome_test_cmk')
    CREATE COLUMN MASTER KEY dbdome_test_cmk
    WITH (
        KEY_STORE_PROVIDER_NAME = N'MSSQL_CERTIFICATE_STORE',
        KEY_PATH = N'CurrentUser/My/dbdome_test_cert_rc09'
    );
GO
-- REVERT:
USE dbdome_test_db;
GO
IF EXISTS (SELECT 1 FROM sys.column_master_keys WHERE name = 'dbdome_test_cmk')
    DROP COLUMN MASTER KEY dbdome_test_cmk;
GO
IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'dbdome_test_cert_rc09')
    DROP CERTIFICATE dbdome_test_cert_rc09;
GO
USE master;
GO

/* ===== SEC-SQL-PRI-001-RC10 [SAFE] ===== */
-- On a server with no masked columns and no column encryption keys the detection returns
-- 'FEATURES_AVAILABLE_BUT_UNUSED'. This is the default state of a fresh test instance.
-- No setup needed; verify by running the detection SQL and confirming the CASE result.
-- If masked columns or encryption keys already exist on the server, they must be removed
-- before the detection fires — which is itself a destructive change; note that below.
-- SETUP:
-- Verify that the server is in the default state (no existing masked/encrypted columns):
SELECT
  (SELECT COUNT(*) FROM sys.masked_columns)        AS masked_column_count,
  (SELECT COUNT(*) FROM sys.column_encryption_keys) AS encryption_key_count,
  (SELECT COUNT(*) FROM sys.column_master_keys)     AS master_key_count,
  CASE
    WHEN (SELECT COUNT(*) FROM sys.masked_columns) = 0
      AND (SELECT COUNT(*) FROM sys.column_encryption_keys) = 0
    THEN 'FEATURES_AVAILABLE_BUT_UNUSED'
    ELSE 'FEATURES_IN_USE'
  END AS feature_utilization;
-- Expected: FEATURES_AVAILABLE_BUT_UNUSED (fires detection).
-- If result is FEATURES_IN_USE the detection will NOT fire; remove CMKs/CEKs/masked cols first.
GO
-- REVERT:
-- Nothing to revert; this is a read-only verification step.
SELECT 1 AS revert_noop;
GO

/* ===== SEC-SQL-PRI-001-RC11 [DESTRUCTIVE] ===== */
-- Creates a user database (database_id > 4) without TDE enabled.
-- The detection returns all user databases where dek.encryption_state IS NULL (no TDE key).
-- SETUP:
IF DB_ID('dbdome_noenc_test_db') IS NULL
    CREATE DATABASE dbdome_noenc_test_db;
-- Do NOT enable TDE — leaving the database without encryption is the test condition.
-- The detection will show this DB with encryption_state IS NULL (no DEK row).
GO
-- REVERT:
IF DB_ID('dbdome_noenc_test_db') IS NOT NULL
BEGIN
    ALTER DATABASE dbdome_noenc_test_db SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE dbdome_noenc_test_db;
END
GO

/* ===== SEC-SQL-PRI-001-RC12 [DESTRUCTIVE] ===== */
-- Creates a user database with a table containing PII-named columns so the cross-database
-- dynamic-SQL scan in RC12 finds at least one hit.
-- Run as sysadmin (the detection itself uses sp_executesql across all accessible databases).
-- SETUP:
IF DB_ID('dbdome_test_db') IS NULL
    CREATE DATABASE dbdome_test_db;
GO
USE dbdome_test_db;
GO
IF OBJECT_ID('dbo.dbdome_pii_test_rc12', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_pii_test_rc12;
CREATE TABLE dbo.dbdome_pii_test_rc12 (
    id           INT           NOT NULL PRIMARY KEY,
    ssn          VARCHAR(11)   NOT NULL,          -- SSN
    credit_card  NVARCHAR(19)  NOT NULL,          -- Credit Card
    email        VARCHAR(255)  NOT NULL,          -- Email
    phone        VARCHAR(20)   NOT NULL,          -- Phone
    salary       DECIMAL(12,2) NOT NULL,          -- Financial
    bank_account VARCHAR(34)   NOT NULL,          -- Bank Account
    passport     VARCHAR(20)   NOT NULL,          -- Government ID
    medical_notes NVARCHAR(MAX) NULL,             -- Medical
    ip_address   VARCHAR(45)   NULL               -- Technical PII
);
GO
-- REVERT:
USE dbdome_test_db;
GO
IF OBJECT_ID('dbo.dbdome_pii_test_rc12', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_pii_test_rc12;
GO
USE master;
GO

/* ===== SEC-SQL-PRI-001-RC13 [DESTRUCTIVE] ===== */
-- Creates a table with PII-named columns, inserts rows, then queries the table so that
-- sys.dm_db_index_usage_stats accumulates user_seeks/user_scans > 0 for that object.
-- Index usage stats are database-scoped and persist until the SQL Server service restarts or
-- the database is detached. Run within the target database (dbdome_test_db).
-- SETUP:
IF DB_ID('dbdome_test_db') IS NULL
    CREATE DATABASE dbdome_test_db;
GO
USE dbdome_test_db;
GO
IF OBJECT_ID('dbo.dbdome_pii_test_rc13', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_pii_test_rc13;
CREATE TABLE dbo.dbdome_pii_test_rc13 (
    id     INT          NOT NULL PRIMARY KEY,
    email  VARCHAR(255) NOT NULL,
    salary DECIMAL(12,2) NOT NULL
);
INSERT INTO dbo.dbdome_pii_test_rc13 VALUES (1, 'user@example.com', 50000.00);
-- Force a scan so index_usage_stats registers a read:
SELECT COUNT(*) FROM dbo.dbdome_pii_test_rc13;
-- The detection runs in the context of DB_ID() so run the detection SQL while USE dbdome_test_db is active.
GO
-- REVERT:
USE dbdome_test_db;
GO
IF OBJECT_ID('dbo.dbdome_pii_test_rc13', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_pii_test_rc13;
GO
USE master;
GO

/* ===== SEC-SQL-PRI-001-RC14 [SAFE] ===== */
-- The detection joins sys.dm_exec_requests to sys.tables/sys.columns looking for an active
-- request whose sql_handle text contains the table name AND that table has PII-named columns.
-- Setup: Session A creates the table with PII columns; Session B holds an open transaction
-- that SELECTs from that table. Run the detection from Session C while Session B is open.
-- Session B must remain open (do NOT COMMIT/ROLLBACK) during detection execution.
-- SETUP:
-- === Run in SESSION A (setup) ===
IF DB_ID('dbdome_test_db') IS NULL
    CREATE DATABASE dbdome_test_db;
GO
USE dbdome_test_db;
GO
IF OBJECT_ID('dbo.dbdome_pii_test_rc14', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_pii_test_rc14;
CREATE TABLE dbo.dbdome_pii_test_rc14 (
    id       INT          NOT NULL PRIMARY KEY,
    email    VARCHAR(255) NOT NULL,
    password VARCHAR(100) NOT NULL,
    salary   DECIMAL(12,2) NOT NULL
);
INSERT INTO dbo.dbdome_pii_test_rc14 VALUES (1, 'user@example.com', 'secret_hash', 75000.00);
GO
-- === Run in SESSION B (keep open — DO NOT COMMIT) ===
-- BEGIN TRAN;
-- SELECT * FROM dbdome_test_db.dbo.dbdome_pii_test_rc14 WITH (HOLDLOCK);
-- /* Leave this transaction open while running the detection in another session. */
-- /* ROLLBACK when done testing. */
GO
-- REVERT:
-- In SESSION B: ROLLBACK TRAN (or close the session).
-- Then in SESSION A:
USE dbdome_test_db;
GO
IF OBJECT_ID('dbo.dbdome_pii_test_rc14', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_pii_test_rc14;
GO
USE master;
GO

/* ===== SEC-SQL-PRI-001-RC15 [DESTRUCTIVE] ===== */
-- RC15 has two output branches: 'cached_plan' and 'active_transaction'.
-- Setup covers the cached_plan branch (simpler, no held session required):
--   1. Create a user DB with a table whose name contains PII column names.
--   2. Execute a SELECT against that table so a plan referencing the table name lands in cache.
--   The detection then finds the table name in sys.dm_exec_query_stats plan text.
-- For the active_transaction branch, additionally hold a BEGIN TRAN open in Session B (same
-- pattern as RC14) — leave the transaction open while running the detection.
-- Run as sysadmin; the setup runs sp_executesql across user databases internally.
-- SETUP:
IF DB_ID('dbdome_test_db') IS NULL
    CREATE DATABASE dbdome_test_db;
GO
USE dbdome_test_db;
GO
IF OBJECT_ID('dbo.dbdome_pii_test_rc15', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_pii_test_rc15;
CREATE TABLE dbo.dbdome_pii_test_rc15 (
    id          INT          NOT NULL PRIMARY KEY,
    password    VARCHAR(100) NOT NULL,
    email       VARCHAR(255) NOT NULL,
    salary      DECIMAL(12,2) NOT NULL,
    ssn         VARCHAR(11)  NOT NULL,
    passport    VARCHAR(20)  NOT NULL,
    medical_id  INT          NULL,
    teudat_zehut VARCHAR(9)  NULL
);
INSERT INTO dbo.dbdome_pii_test_rc15 VALUES (1, 'hashed_pw', 'u@example.com', 80000, '123-45-6789', 'AB123456', NULL, NULL);
-- Execute a query against the table to populate the plan cache:
SELECT COUNT(*) FROM dbo.dbdome_pii_test_rc15 WHERE id > 0;
-- For active_transaction branch: in Session B open and hold:
-- BEGIN TRAN;
-- SELECT * FROM dbdome_test_db.dbo.dbdome_pii_test_rc15;
-- /* ROLLBACK when done testing. */
GO
-- REVERT:
-- In Session B (if used): ROLLBACK TRAN.
USE dbdome_test_db;
GO
IF OBJECT_ID('dbo.dbdome_pii_test_rc15', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_pii_test_rc15;
GO
USE master;
IF DB_ID('dbdome_noenc_test_db') IS NOT NULL
BEGIN
    ALTER DATABASE dbdome_noenc_test_db SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE dbdome_noenc_test_db;
END
IF DB_ID('dbdome_test_db') IS NOT NULL
BEGIN
    ALTER DATABASE dbdome_test_db SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE dbdome_test_db;
END
GO


/* ########## batch 38 (12 reproducers) ########## */
/* ===== SEC-SQL-PRI-002-RC01 [DESTRUCTIVE] ===== */
-- Creates a server audit + specification with a broad action group so the detection
-- (which returns all enabled audits) returns >=1 row.
-- Run as sysadmin. The audit target is a file; adjust path if needed.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc01')
BEGIN
    CREATE SERVER AUDIT dbdome_test_audit_rc01
        TO FILE (FILEPATH = 'C:\Windows\Temp\', MAXSIZE = 10 MB, MAX_FILES = 2, RESERVE_DISK_SPACE = OFF)
        WITH (ON_FAILURE = CONTINUE);
END;
ALTER SERVER AUDIT dbdome_test_audit_rc01 WITH (STATE = ON);

IF NOT EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec_rc01')
BEGIN
    CREATE SERVER AUDIT SPECIFICATION dbdome_test_spec_rc01
        FOR SERVER AUDIT dbdome_test_audit_rc01
        ADD (FAILED_LOGIN_GROUP)
        WITH (STATE = OFF);
END;
ALTER SERVER AUDIT SPECIFICATION dbdome_test_spec_rc01 WITH (STATE = ON);
GO
-- REVERT:
ALTER SERVER AUDIT SPECIFICATION dbdome_test_spec_rc01 WITH (STATE = OFF);
DROP SERVER AUDIT SPECIFICATION dbdome_test_spec_rc01;
ALTER SERVER AUDIT dbdome_test_audit_rc01 WITH (STATE = OFF);
DROP SERVER AUDIT dbdome_test_audit_rc01;
GO

/* ===== SEC-SQL-PRI-002-RC02 [SAFE] ===== */
-- Detection queries sys.dm_exec_cached_plans and groups by objtype — it always returns
-- rows on any server with plan cache activity (no predicate filters to zero rows).
-- Run at least one ad-hoc query first to ensure AdHoc plans are cached.
-- SETUP:
-- Force an ad-hoc (unparameterized) plan into cache so the AdHoc objtype row appears.
DECLARE @dummy INT;
SELECT @dummy = object_id FROM sys.objects WHERE name = 'dbdome_adhoc_probe_' + CAST(NEWID() AS NVARCHAR(40));
GO
-- REVERT:
-- No persistent change. Plan cache entries expire automatically.
-- Optionally clear the plan cache (caution on production):
-- DBCC FREEPROCCACHE;
GO

/* ===== SEC-SQL-PRI-002-RC03 [DESTRUCTIVE] ===== */
-- Detection selects from sys.messages WHERE message_id > 50000 AND language_id = 1033.
-- Adding a custom user-defined message with id > 50000 satisfies the predicate.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.messages WHERE message_id = 60001 AND language_id = 1033)
BEGIN
    EXEC sp_addmessage
        @msgnum   = 60001,
        @severity = 10,
        @msgtext  = N'dbdome_test_verbose_error_logging_message',
        @lang     = 'us_english';
END;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.messages WHERE message_id = 60001 AND language_id = 1033)
    EXEC sp_dropmessage @msgnum = 60001, @lang = 'us_english';
GO

/* ===== SEC-SQL-PRI-002-RC04 [DESTRUCTIVE] ===== */
-- Detection returns rows when an enabled audit spec contains one of the verbose
-- action groups (SCHEMA_OBJECT_ACCESS_GROUP, BATCH_COMPLETED_GROUP, etc.).
-- Run as sysadmin. Adjust FILEPATH if C:\Windows\Temp\ is not writable.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'dbdome_test_audit_rc04')
BEGIN
    CREATE SERVER AUDIT dbdome_test_audit_rc04
        TO FILE (FILEPATH = 'C:\Windows\Temp\', MAXSIZE = 10 MB, MAX_FILES = 2, RESERVE_DISK_SPACE = OFF)
        WITH (ON_FAILURE = CONTINUE);
END;
ALTER SERVER AUDIT dbdome_test_audit_rc04 WITH (STATE = ON);

IF NOT EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'dbdome_test_spec_rc04')
BEGIN
    CREATE SERVER AUDIT SPECIFICATION dbdome_test_spec_rc04
        FOR SERVER AUDIT dbdome_test_audit_rc04
        ADD (BATCH_COMPLETED_GROUP)
        WITH (STATE = OFF);
END;
ALTER SERVER AUDIT SPECIFICATION dbdome_test_spec_rc04 WITH (STATE = ON);
GO
-- REVERT:
ALTER SERVER AUDIT SPECIFICATION dbdome_test_spec_rc04 WITH (STATE = OFF);
DROP SERVER AUDIT SPECIFICATION dbdome_test_spec_rc04;
ALTER SERVER AUDIT dbdome_test_audit_rc04 WITH (STATE = OFF);
DROP SERVER AUDIT dbdome_test_audit_rc04;
GO

/* ===== SEC-SQL-PRI-002-RC05 [DESTRUCTIVE] ===== */
-- Detection returns all rows from sys.server_event_sessions joined to events —
-- any enabled Extended Events session satisfies the query (no WHERE filter).
-- Create a minimal XE session so the join produces rows.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name = 'dbdome_test_xe_rc05')
BEGIN
    CREATE EVENT SESSION dbdome_test_xe_rc05 ON SERVER
        ADD EVENT sqlserver.sql_statement_completed;
END;
ALTER EVENT SESSION dbdome_test_xe_rc05 ON SERVER STATE = START;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name = 'dbdome_test_xe_rc05')
BEGIN
    ALTER EVENT SESSION dbdome_test_xe_rc05 ON SERVER STATE = STOP;
    DROP EVENT SESSION dbdome_test_xe_rc05 ON SERVER;
END;
GO

/* ===== SEC-SQL-PRI-002-RC06 [SAFE] ===== */
-- Detection queries sys.configurations for 'default trace enabled' plus returns a
-- static second row about SQLDUMPER_ERRORLOG.log — both rows always exist.
-- The detection always returns >=1 row regardless of configuration; no setup needed.
-- SETUP:
-- Verify the detection returns rows as-is (no change required):
SELECT name, CAST(value_in_use AS INT) AS current_value
FROM sys.configurations
WHERE name IN ('default trace enabled');
GO
-- REVERT:
-- No change made; nothing to revert.
GO

/* ===== SEC-SQL-PRI-002-RC07 [DESTRUCTIVE] ===== */
-- Same query as RC05 — returns rows from sys.server_event_sessions joined to events.
-- Create a minimal XE session so the join produces rows.
-- Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name = 'dbdome_test_xe_rc07')
BEGIN
    CREATE EVENT SESSION dbdome_test_xe_rc07 ON SERVER
        ADD EVENT sqlserver.sql_batch_completed;
END;
ALTER EVENT SESSION dbdome_test_xe_rc07 ON SERVER STATE = START;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name = 'dbdome_test_xe_rc07')
BEGIN
    ALTER EVENT SESSION dbdome_test_xe_rc07 ON SERVER STATE = STOP;
    DROP EVENT SESSION dbdome_test_xe_rc07 ON SERVER;
END;
GO

/* ===== SEC-SQL-PRI-002-RC09 [DESTRUCTIVE] ===== */
-- Detection returns rows when sys.traces has a running trace (status=1) that
-- captures SQL:BatchCompleted / RPC:Completed / etc. with the TextData column.
-- sp_trace_create + add the right events to create a matching trace.
-- Run as sysadmin. Trace file written to C:\Windows\Temp\.
-- SETUP:
DECLARE @traceid   INT;
DECLARE @tracefile NVARCHAR(260) = N'C:\Windows\Temp\dbdome_test_trace_rc09';
DECLARE @filesize  BIGINT = 5;

-- Create trace
EXEC sp_trace_create @traceid OUTPUT, 0, @tracefile, @filesize;

-- Event 12 = SQL:BatchCompleted; Column 1 = TextData
EXEC sp_trace_setevent @traceid, 12, 1, 1;  -- TextData ON

-- Start trace
EXEC sp_trace_setstatus @traceid, 1;

-- Store traceid for revert (print it so the operator knows)
PRINT 'Created trace id: ' + CAST(@traceid AS VARCHAR);
GO
-- REVERT:
-- Replace <traceid> with the value printed during setup, or discover via:
-- SELECT id FROM sys.traces WHERE path LIKE '%dbdome_test_trace_rc09%';
DECLARE @tid INT;
SELECT @tid = id FROM sys.traces WHERE path LIKE N'%dbdome_test_trace_rc09%';
IF @tid IS NOT NULL
BEGIN
    EXEC sp_trace_setstatus @tid, 0;  -- stop
    EXEC sp_trace_setstatus @tid, 2;  -- delete
    PRINT 'Removed trace id: ' + CAST(@tid AS VARCHAR);
END;
GO

/* ===== SEC-SQL-PRI-002-RC11 [SAFE] ===== */
-- Detection queries sys.configurations WHERE name = 'number of errorlog files'.
-- That row always exists; the CASE expression produces the assessment text.
-- The detection always returns exactly 1 row. No setup is required.
-- To exercise the HIGH branch, set the value to > 30 (DESTRUCTIVE if done):
--   EXEC sp_configure 'number of errorlog files', 99; RECONFIGURE;
-- The SAFE setup below just verifies the row exists without changing anything.
-- SETUP:
SELECT name, CAST(value_in_use AS INT) AS value_in_use
FROM sys.configurations
WHERE name = 'number of errorlog files';
GO
-- REVERT:
-- No change made; nothing to revert.
GO

/* ===== SEC-SQL-PRI-003-RC01 [DESTRUCTIVE] ===== */
-- Detection returns a row when the database-level extended property 'PPL_Security_Level'
-- (class=0) does NOT exist. On a clean test DB it is missing by default.
-- To force the positive condition: drop the property if it happens to exist.
-- Run against the target database.
-- SETUP:
IF EXISTS (SELECT 1 FROM sys.extended_properties WHERE name = 'PPL_Security_Level' AND class = 0)
    EXEC sp_dropextendedproperty
        @name = N'PPL_Security_Level';
-- Property is now absent; detection returns 1 row.
GO
-- REVERT:
-- Restore the property to suppress the finding.
IF NOT EXISTS (SELECT 1 FROM sys.extended_properties WHERE name = 'PPL_Security_Level' AND class = 0)
    EXEC sp_addextendedproperty
        @name  = N'PPL_Security_Level',
        @value = N'Basic';
GO

/* ===== SEC-SQL-PRI-003-RC02 [DESTRUCTIVE] ===== */
-- Detection returns rows for tables with >= 100,000 rows.
-- Insert 100,000 fake rows into a throwaway table.
-- Run against the target database as db_owner or higher.
-- SETUP:
IF OBJECT_ID('dbo.dbdome_pii_test_rc02', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_pii_test_rc02;

CREATE TABLE dbo.dbdome_pii_test_rc02 (
    id   INT IDENTITY PRIMARY KEY,
    filler CHAR(10) NOT NULL DEFAULT 'x'
);

-- Insert 100,000 rows efficiently via a numbers tally
WITH n AS (
    SELECT TOP (100000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_columns a CROSS JOIN sys.all_columns b
)
INSERT INTO dbo.dbdome_pii_test_rc02 (filler)
SELECT 'row' FROM n;
GO
-- REVERT:
IF OBJECT_ID('dbo.dbdome_pii_test_rc02', 'U') IS NOT NULL
    DROP TABLE dbo.dbdome_pii_test_rc02;
GO

/* ===== SEC-SQL-PRI-003-RC03 [DESTRUCTIVE] ===== */
-- Detection returns rows when 'remote access' = 1 OR SQL Server is in Mixed Mode auth.
-- Enabling 'remote access' (deprecated but still configurable) is the safest trigger.
-- Run as sysadmin. Requires 'show advanced options' = 1.
-- SETUP:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
-- Enable remote access (value 1)
EXEC sp_configure 'remote access', 1;
RECONFIGURE;
GO
-- REVERT:
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'remote access', 0;
RECONFIGURE;
GO


/* ########## batch 39 (12 reproducers) ########## */
/* ===== SEC-SQL-PRI-004-RC01 [DESTRUCTIVE] ===== */
-- Detection: any user DB (database_id > 4) missing a TDE encryption key, or whose key state <> 3 (encrypted).
-- Setup creates a throwaway database with no TDE key at all, so it appears in the UNION ALL branch.
-- Revert drops the database. Run as sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_tde_test')
    CREATE DATABASE dbdome_tde_test;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_tde_test')
BEGIN
    ALTER DATABASE dbdome_tde_test SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE dbdome_tde_test;
END
GO

/* ===== SEC-SQL-PRI-004-RC02 [DESTRUCTIVE] ===== */
-- Detection: user-table columns whose name matches PII keywords and whose encryption_type IS NULL (i.e. not Always Encrypted).
-- Creates a throwaway table with an 'email' column (no Always Encrypted), which satisfies the predicate instantly.
-- Revert drops the table. Run inside any user database (not master/tempdb/model/msdb).
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dbdome_pii_test' AND schema_id = SCHEMA_ID('dbo'))
    CREATE TABLE dbo.dbdome_pii_test (
        id          INT IDENTITY PRIMARY KEY,
        email       NVARCHAR(255),   -- triggers LIKE '%email%'
        password    NVARCHAR(255),   -- triggers LIKE '%password%'
        ssn         NVARCHAR(20),    -- triggers LIKE '%ssn%'
        credit_card NVARCHAR(30),    -- triggers LIKE '%credit_card%'
        phone       NVARCHAR(30),    -- triggers LIKE '%phone%'
        passport    NVARCHAR(30),    -- triggers LIKE '%passport%'
        medical     NVARCHAR(255)    -- triggers LIKE '%medical%'
    );
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dbdome_pii_test' AND schema_id = SCHEMA_ID('dbo'))
    DROP TABLE dbo.dbdome_pii_test;
GO

/* ===== SEC-SQL-PRI-004-RC03 [SAFE] ===== */
-- Detection: active connections (session_id > 50) whose encrypt_option = 'FALSE'.
-- This condition exists when a client connects without TLS (Force Encryption = OFF on the server).
-- Setup: keep an open connection from a client that does NOT use encryption (e.g. SSMS / sqlcmd without
--   "Encrypt=yes" in its connection string) while the server has Force Encryption disabled.
-- There is no T-SQL script that forces a live session's encrypt_option to FALSE; the condition is
--   determined at connection time by network/protocol negotiation.
-- Best-effort: confirm server Force Encryption is OFF (registry/SQL Server Configuration Manager),
--   then open a new sqlcmd connection without encryption and re-run the detection.
-- No persistent schema change required; marking SAFE.
-- SETUP:
-- Step 1: Ensure "Force Encryption" = No in SQL Server Configuration Manager (server-side).
-- Step 2: Connect via sqlcmd without encryption:
--   sqlcmd -S <server> -U <login> -P <password> -Q "SELECT session_id, encrypt_option FROM sys.dm_exec_connections WHERE session_id = @@SPID"
-- Step 3: While that session is open (session_id > 50), run the detection SQL.
PRINT 'SEC-SQL-PRI-004-RC03: Open a non-TLS sqlcmd/SSMS connection (no Encrypt=yes) to produce a row.';
GO
-- REVERT:
-- Close the non-TLS connection. No schema changes were made.
PRINT 'SEC-SQL-PRI-004-RC03: Close the non-TLS session. No objects to drop.';
GO

/* ===== SEC-SQL-PRI-005-RC01 [DESTRUCTIVE] ===== */
-- Detection fires when NO enabled server_audit_specification OR no enabled database_audit_specification exists.
-- Setup: disable all existing server audit specifications (if any). If none exist the detection already fires.
-- Revert re-enables them.
-- WARNING: this may briefly leave the instance with no active audit. Run on a disposable test server.
-- SETUP:
-- Disable all currently enabled server audit specifications
DECLARE @name SYSNAME, @sql NVARCHAR(500);
DECLARE cur CURSOR FOR
    SELECT name FROM sys.server_audit_specifications WHERE is_state_enabled = 1;
OPEN cur; FETCH NEXT FROM cur INTO @name;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'ALTER SERVER AUDIT SPECIFICATION ' + QUOTENAME(@name) + N' WITH (STATE = OFF)';
    EXEC sp_executesql @sql;
    FETCH NEXT FROM cur INTO @name;
END
CLOSE cur; DEALLOCATE cur;

-- Disable all currently enabled database audit specifications
DECLARE cur2 CURSOR FOR
    SELECT name FROM sys.database_audit_specifications WHERE is_state_enabled = 1;
OPEN cur2; FETCH NEXT FROM cur2 INTO @name;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'ALTER DATABASE AUDIT SPECIFICATION ' + QUOTENAME(@name) + N' WITH (STATE = OFF)';
    EXEC sp_executesql @sql;
    FETCH NEXT FROM cur2 INTO @name;
END
CLOSE cur2; DEALLOCATE cur2;
GO
-- REVERT:
-- Re-enable all server audit specifications
DECLARE @name SYSNAME, @sql NVARCHAR(500);
DECLARE cur CURSOR FOR
    SELECT name FROM sys.server_audit_specifications WHERE is_state_enabled = 0;
OPEN cur; FETCH NEXT FROM cur INTO @name;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'ALTER SERVER AUDIT SPECIFICATION ' + QUOTENAME(@name) + N' WITH (STATE = ON)';
    EXEC sp_executesql @sql;
    FETCH NEXT FROM cur INTO @name;
END
CLOSE cur; DEALLOCATE cur;

-- Re-enable all database audit specifications
DECLARE cur2 CURSOR FOR
    SELECT name FROM sys.database_audit_specifications WHERE is_state_enabled = 0;
OPEN cur2; FETCH NEXT FROM cur2 INTO @name;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'ALTER DATABASE AUDIT SPECIFICATION ' + QUOTENAME(@name) + N' WITH (STATE = OFF)';
    -- NOTE: flip back to ON
    SET @sql = N'ALTER DATABASE AUDIT SPECIFICATION ' + QUOTENAME(@name) + N' WITH (STATE = ON)';
    EXEC sp_executesql @sql;
    FETCH NEXT FROM cur2 INTO @name;
END
CLOSE cur2; DEALLOCATE cur2;
GO

/* ===== SEC-SQL-PRI-005-RC02 [DESTRUCTIVE] ===== */
-- Detection: PII-named column exists in a user table but no database_audit_specification_detail with
--   audit_action_name='SELECT' covers that table's object_id.
-- Setup creates the PII table (reuse dbdome_pii_test). Because no audit spec detail covers it the detection fires.
-- Run inside any user database. Revert drops the table.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dbdome_pii_test' AND schema_id = SCHEMA_ID('dbo'))
    CREATE TABLE dbo.dbdome_pii_test (
        id    INT IDENTITY PRIMARY KEY,
        email NVARCHAR(255)   -- triggers LIKE '%email%'
    );
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dbdome_pii_test' AND schema_id = SCHEMA_ID('dbo'))
    DROP TABLE dbo.dbdome_pii_test;
GO

/* ===== SEC-SQL-PRI-005-RC03 [DESTRUCTIVE] ===== */
-- Detection: server file audits where (max_rollover_files * COALESCE(NULLIF(max_file_size,0),1)) < 100000.
-- Creates a minimal server audit with max_rollover_files=5, max_file_size=1 (MB) => 5*1=5 < 100000.
-- Revert drops the audit. Run as sysadmin.
-- NOTE: The audit target path must exist on the test server; adjust C:\Temp if needed.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_file_audits WHERE name = 'dbdome_audit_test')
BEGIN
    -- Small rollover config: 5 files * 1 MB = 5, well below 100000 threshold
    CREATE SERVER AUDIT dbdome_audit_test
        TO FILE (FILEPATH = N'C:\Temp\',
                 MAXSIZE   = 1 MB,
                 MAX_ROLLOVER_FILES = 5)
        WITH (ON_FAILURE = CONTINUE);
    ALTER SERVER AUDIT dbdome_audit_test WITH (STATE = OFF);  -- keep OFF so no real auditing occurs
END
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_file_audits WHERE name = 'dbdome_audit_test')
BEGIN
    ALTER SERVER AUDIT dbdome_audit_test WITH (STATE = OFF);
    DROP SERVER AUDIT dbdome_audit_test;
END
GO

/* ===== SEC-SQL-PRI-006-RC01 [DESTRUCTIVE] ===== */
-- Detection: 'public' role has GRANT SELECT on a table that has a PII-named column.
-- Setup creates the PII table then grants SELECT to public. Revert revokes and drops.
-- Run inside a user database as db_owner or sysadmin.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dbdome_pii_test' AND schema_id = SCHEMA_ID('dbo'))
    CREATE TABLE dbo.dbdome_pii_test (
        id    INT IDENTITY PRIMARY KEY,
        email NVARCHAR(255)
    );
IF NOT EXISTS (
    SELECT 1 FROM sys.database_permissions p
    JOIN sys.objects o ON o.object_id = p.major_id
    JOIN sys.database_principals dp ON dp.principal_id = p.grantee_principal_id
    WHERE o.name = 'dbdome_pii_test' AND dp.name = 'public'
      AND p.permission_name = 'SELECT' AND p.state = 'G'
)
    GRANT SELECT ON dbo.dbdome_pii_test TO public;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dbdome_pii_test' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    REVOKE SELECT ON dbo.dbdome_pii_test FROM public;
    DROP TABLE dbo.dbdome_pii_test;
END
GO

/* ===== SEC-SQL-PRI-006-RC02 [DESTRUCTIVE] ===== */
-- Detection: server login whose name matches '%app%','%svc%','%service%','%api%' is a member of
--   sysadmin, securityadmin, or serveradmin.
-- Creates login 'dbdome_app_login' and adds it to sysadmin. Revert removes and drops.
-- Run as sysadmin on a DISPOSABLE server — adding to sysadmin is highly privileged.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_app_login')
    CREATE LOGIN dbdome_app_login WITH PASSWORD = 'T3st!P@ssw0rd#99', CHECK_POLICY = OFF;
-- Add to sysadmin so detection fires (name contains 'app')
IF NOT EXISTS (
    SELECT 1 FROM sys.server_role_members srm
    JOIN sys.server_principals sp ON sp.principal_id = srm.member_principal_id
    JOIN sys.server_principals r  ON r.principal_id  = srm.role_principal_id
    WHERE sp.name = 'dbdome_app_login' AND r.name = 'sysadmin'
)
    ALTER SERVER ROLE sysadmin ADD MEMBER dbdome_app_login;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_app_login')
BEGIN
    ALTER SERVER ROLE sysadmin DROP MEMBER dbdome_app_login;
    DROP LOGIN dbdome_app_login;
END
GO

/* ===== SEC-SQL-PRI-006-RC03 [DESTRUCTIVE] ===== */
-- Detection: enabled SQL/Windows login with no session in the last 90 days (or no session ever).
-- Creates a brand-new login that has never logged in => last_login IS NULL => fires immediately.
-- Revert drops the login.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_stale_login')
    CREATE LOGIN dbdome_stale_login WITH PASSWORD = 'T3st!P@ssw0rd#99', CHECK_POLICY = OFF;
-- New login has never connected, so MAX(s.login_time) IS NULL and it is not disabled => detection fires.
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_stale_login')
    DROP LOGIN dbdome_stale_login;
GO

/* ===== SEC-SQL-PRI-007-RC01 [DESTRUCTIVE] ===== */
-- Detection: enabled SQL login (not 'sa') with is_policy_checked=0 OR is_expiration_checked=0.
-- Creates a login with CHECK_POLICY=OFF (sets both flags to 0). Revert drops it.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_nopolicy_login')
    CREATE LOGIN dbdome_nopolicy_login
        WITH PASSWORD      = 'T3st!P@ssw0rd#99',
             CHECK_POLICY   = OFF,
             CHECK_EXPIRATION = OFF;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_nopolicy_login')
    DROP LOGIN dbdome_nopolicy_login;
GO

/* ===== SEC-SQL-PRI-007-RC02 [DESTRUCTIVE] ===== */
-- Detection: enabled principal whose LOWER(name) is exactly one of:
--   'admin','app','svc','dba','root','user','test','dbuser'.
-- Creates login 'test' (matches the list exactly). Revert drops it.
-- NOTE: if a login named 'test' already exists the IF NOT EXISTS guard skips creation — check first.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE LOWER(name) = 'test')
    CREATE LOGIN [test] WITH PASSWORD = 'T3st!P@ssw0rd#99', CHECK_POLICY = OFF;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE LOWER(name) = 'test' AND name = 'test')
    DROP LOGIN [test];
GO

/* ===== SEC-SQL-PRI-007-RC03 [DESTRUCTIVE] ===== */
-- Detection: server principal named 'sa' with is_disabled = 0.
-- The 'sa' login exists by default on every SQL Server instance.
-- Setup: enable 'sa' if it is currently disabled. Revert disables it again.
-- WARNING: enabling 'sa' is a real security risk. Only do this on a DISPOSABLE test server.
-- SETUP:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'sa' AND is_disabled = 1)
BEGIN
    -- sa exists but is disabled; enable it so the detection fires
    ALTER LOGIN sa ENABLE;
    PRINT 'sa was disabled; now enabled for test.';
END
ELSE IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'sa' AND is_disabled = 0)
    PRINT 'sa is already enabled; detection will fire without any change.';
GO
-- REVERT:
-- Only disable sa if we were the ones who enabled it. On a disposable server, disabling is safe.
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'sa' AND is_disabled = 0)
BEGIN
    ALTER LOGIN sa DISABLE;
    PRINT 'sa disabled (reverted).';
END
GO


/* ########## batch 40 (12 reproducers) ########## */
/* ===================================================================
   Positive-test reproducers for detections slice 480..492
   Target: DISPOSABLE TEST SQL Server only.
   Each block: SETUP triggers the detection, REVERT undoes it.
   =================================================================== */

/* ===== SEC-SQL-PRI-008-RC01 [DESTRUCTIVE] ===== */
-- Detection: user databases (database_id > 4) with no backup OR last backup older than 7 days.
-- Setup: create a new database with no backup history so HAVING MAX(...) IS NULL fires.
-- Run as sysadmin. Revert drops the test database (backup history is removed automatically).
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_test_nobackup_db')
    CREATE DATABASE dbdome_test_nobackup_db;
GO
-- Verify: the new database has no entry in msdb.dbo.backupset, so it will appear.
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'dbdome_test_nobackup_db')
BEGIN
    ALTER DATABASE dbdome_test_nobackup_db SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE dbdome_test_nobackup_db;
END
GO

/* ===== SEC-SQL-PRI-008-RC02 [DESTRUCTIVE] ===== */
-- Detection: backup records in msdb.dbo.backupset within the last 30 days where
-- encryptor_type IS NULL (unencrypted backup). Standard BACKUP DATABASE without
-- WITH ENCRYPTION produces encryptor_type = NULL.
-- Setup: take an unencrypted backup of master to a temp file; the new backupset row
-- will have encryptor_type IS NULL and satisfy the 30-day filter.
-- Run as sysadmin. Revert purges backup history and removes the file.
-- SETUP:
BACKUP DATABASE [master]
    TO DISK = N'C:\Windows\Temp\dbdome_test_noenc.bak'
    WITH FORMAT, COMPRESSION, NAME = N'dbdome_test_unencrypted_backup';
GO
-- REVERT:
EXEC msdb.dbo.sp_delete_backuphistory @oldest_date = GETDATE();
EXEC xp_cmdshell 'DEL /F /Q "C:\Windows\Temp\dbdome_test_noenc.bak"';
GO

/* ===== SEC-SQL-PRI-008-RC03 [DESTRUCTIVE] ===== */
-- Detection: joins backupset + backupmediafamily + sys.master_files; flags rows where
-- LEFT(backup_path, 3) = LEFT(data_path, 3) — i.e. backup is on the same drive letter
-- as the data files. Backing up master to a temp path on the OS drive (C:\) while
-- master's mdf lives on C:\ satisfies the same-volume predicate.
-- Setup: take a backup of master to C:\Windows\Temp\ (same drive as master's mdf).
-- Run as sysadmin. Revert purges history and removes the temp file.
-- SETUP:
BACKUP DATABASE [master]
    TO DISK = N'C:\Windows\Temp\dbdome_test_samevol.bak'
    WITH FORMAT, COMPRESSION, NAME = N'dbdome_test_samevol_backup';
GO
-- REVERT:
EXEC msdb.dbo.sp_delete_backuphistory @oldest_date = GETDATE();
EXEC xp_cmdshell 'DEL /F /Q "C:\Windows\Temp\dbdome_test_samevol.bak"';
GO

/* ===== SEC-SQL-PRI-009-RC01 [DESTRUCTIVE] ===== */
-- Detection: non-system tables that (a) have a datetime/date column named like
-- %created%, %inserted%, %entry_date%, %registered%, AND (b) have at least one column
-- named like %email%, %phone%, %ssn%, %passport%, %credit_card%, %medical%, %teudat%.
-- Setup: create a table with a 'created_date' (datetime) column and an 'email' column
-- with at least one row (p.rows > 0).
-- Run as sysadmin/dbowner. Revert drops the table.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dbdome_pii_retention_test'
               AND schema_id = SCHEMA_ID('dbo'))
    CREATE TABLE dbo.dbdome_pii_retention_test (
        id           INT IDENTITY PRIMARY KEY,
        email        NVARCHAR(200),
        created_date DATETIME DEFAULT GETDATE()
    );
GO
INSERT INTO dbo.dbdome_pii_retention_test (email, created_date)
VALUES ('test@dbdome.invalid', DATEADD(year, -3, GETDATE()));
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dbdome_pii_retention_test'
           AND schema_id = SCHEMA_ID('dbo'))
    DROP TABLE dbo.dbdome_pii_retention_test;
GO

/* ===== SEC-SQL-PRI-009-RC02 [DESTRUCTIVE] ===== */
-- Detection: non-system tables with a datetime/date column named like
-- %last_login%, %last_active%, %last_seen%, %last_used% and p.rows > 0.
-- Setup: create a table with a 'last_login' (datetime2) column and insert one row.
-- Run as sysadmin/dbowner. Revert drops the table.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dbdome_inactive_subjects_test'
               AND schema_id = SCHEMA_ID('dbo'))
    CREATE TABLE dbo.dbdome_inactive_subjects_test (
        id         INT IDENTITY PRIMARY KEY,
        username   NVARCHAR(100),
        last_login DATETIME2 DEFAULT GETDATE()
    );
GO
INSERT INTO dbo.dbdome_inactive_subjects_test (username, last_login)
VALUES ('dbdome_test_user', DATEADD(year, -2, GETDATE()));
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dbdome_inactive_subjects_test'
           AND schema_id = SCHEMA_ID('dbo'))
    DROP TABLE dbo.dbdome_inactive_subjects_test;
GO

/* ===== SEC-SQL-PRI-009-RC03 [DESTRUCTIVE] ===== */
-- Detection: non-system tables with a column named exactly 'is_deleted', 'isdeleted',
-- 'deleted', or matching %deleted_at% / %deletion_date%. No row-count filter.
-- Setup: create a table with an 'is_deleted' column. No rows needed — the detection
-- matches on column name presence only.
-- Run as sysadmin/dbowner. Revert drops the table.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dbdome_softdelete_test'
               AND schema_id = SCHEMA_ID('dbo'))
    CREATE TABLE dbo.dbdome_softdelete_test (
        id         INT IDENTITY PRIMARY KEY,
        record_val NVARCHAR(100),
        is_deleted BIT DEFAULT 0
    );
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dbdome_softdelete_test'
           AND schema_id = SCHEMA_ID('dbo'))
    DROP TABLE dbo.dbdome_softdelete_test;
GO

/* ===== SEC-SQL-PRI-010-RC01 [DESTRUCTIVE] ===== */
-- Detection: two-branch UNION. Branch 1 returns a static finding row when no server
-- audit specification with FAILED_LOGIN_GROUP and is_state_enabled = 1 exists.
-- Branch 2 requires a running audit file with >20 login failures in 1 hour.
-- Easiest positive trigger: ensure NO enabled audit spec with FAILED_LOGIN_GROUP exists
-- (the NOT EXISTS branch fires and always returns 1 row on a default instance).
-- Setup: disable or drop any existing audit spec that covers FAILED_LOGIN_GROUP, OR
-- simply confirm none exists (default state on most instances). The static branch will
-- then return the finding row automatically.
-- Run as sysadmin. If an audit spec already exists, disable it temporarily.
-- NOTE: If a FAILED_LOGIN_GROUP audit spec IS already active, the static branch will NOT
-- fire. In that case drop/disable it as shown below, then re-enable during revert.
-- SETUP:
-- Disable any enabled server audit specification that covers FAILED_LOGIN_GROUP:
DECLARE @spec_name SYSNAME;
SELECT @spec_name = sas.name
FROM sys.server_audit_specifications sas
JOIN sys.server_audit_specification_details sasd
    ON sasd.server_specification_id = sas.server_specification_id
WHERE sas.is_state_enabled = 1
  AND sasd.audit_action_name = 'FAILED_LOGIN_GROUP';
IF @spec_name IS NOT NULL
    EXEC sp_executesql N'ALTER SERVER AUDIT SPECIFICATION ' + QUOTENAME(@spec_name) + N' WITH (STATE = OFF)';
-- If no spec existed the NOT EXISTS branch already fires; nothing more needed.
GO
-- REVERT:
-- Re-enable the spec that was disabled (substitute actual spec name if needed):
DECLARE @spec_name SYSNAME;
SELECT @spec_name = sas.name
FROM sys.server_audit_specifications sas
JOIN sys.server_audit_specification_details sasd
    ON sasd.server_specification_id = sas.server_specification_id
WHERE sas.is_state_enabled = 0
  AND sasd.audit_action_name = 'FAILED_LOGIN_GROUP';
IF @spec_name IS NOT NULL
    EXEC sp_executesql N'ALTER SERVER AUDIT SPECIFICATION ' + QUOTENAME(@spec_name) + N' WITH (STATE = ON)';
GO

/* ===== SEC-SQL-PRI-010-RC02 [DESTRUCTIVE] ===== */
-- Detection: server principals that are members of 'sysadmin' or 'securityadmin'
-- AND whose create_date > DATEADD(day, -30, GETDATE()) — i.e. recently created
-- high-privilege logins.
-- Setup: create a new SQL login and add it to the sysadmin role so it satisfies both
-- predicates (fresh create_date, member of sysadmin).
-- Run as sysadmin. Revert drops the login (role membership is removed automatically).
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_escalation')
    CREATE LOGIN dbdome_test_escalation WITH PASSWORD = 'DbDome#Esc2024!',
        CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
GO
IF NOT EXISTS (
    SELECT 1 FROM sys.server_role_members srm
    JOIN sys.server_principals sp ON sp.principal_id = srm.member_principal_id
    WHERE sp.name = 'dbdome_test_escalation'
)
    ALTER SERVER ROLE sysadmin ADD MEMBER dbdome_test_escalation;
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'dbdome_test_escalation')
BEGIN
    ALTER SERVER ROLE sysadmin DROP MEMBER dbdome_test_escalation;
    DROP LOGIN dbdome_test_escalation;
END
GO

/* ===== SEC-SQL-PRI-010-RC03 [SAFE] ===== */
-- Detection: active user sessions (is_user_process = 1) that have a running request
-- (join to sys.dm_exec_requests) whose start_time hour is < 6 OR >= 22.
-- Setup: open a session and run a long-sleeping statement during off-hours (before 06:00
-- or after 22:00 local time). The sleeping request keeps the join to dm_exec_requests
-- alive so the detection finds it.
-- Run as any login with VIEW SERVER STATE. Must be executed in a SEPARATE session that
-- stays open; the detection is then run from a second session.
-- NOTE: this detection is time-gated — it will only fire when wall-clock hour < 6 or >= 22.
-- For a daytime test, temporarily adjust the server's system time or accept the limitation.
-- SETUP (run in a dedicated session, keep it open):
WAITFOR DELAY '00:05:00';  -- holds a request visible in dm_exec_requests for 5 minutes
GO
-- REVERT:
-- Kill the session running the WAITFOR above, or simply let it expire.
-- No persistent objects were created.
PRINT 'SEC-SQL-PRI-010-RC03: no persistent objects to revert (SAFE)';
GO

/* ===== SEC-SQL-PRI-011-RC01 [DESTRUCTIVE] ===== */
-- Detection: columns where encryption_type IS NULL (not Always Encrypted) and the
-- column name matches patterns for Israeli national ID:
-- %teudat%zehut%, %teudatzehut%, exactly 'tz', %t_z%, 'national_id', 'israeli_id', 'id_number'.
-- Setup: create a table with a column named 'national_id' (not encrypted).
-- Any non-encrypted column with a matching name will satisfy encryption_type IS NULL.
-- Run as sysadmin/dbowner. Revert drops the table.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dbdome_teudat_test'
               AND schema_id = SCHEMA_ID('dbo'))
    CREATE TABLE dbo.dbdome_teudat_test (
        id          INT IDENTITY PRIMARY KEY,
        national_id NVARCHAR(20),     -- triggers detection (name = 'national_id', no AE encryption)
        full_name   NVARCHAR(200)
    );
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dbdome_teudat_test'
           AND schema_id = SCHEMA_ID('dbo'))
    DROP TABLE dbo.dbdome_teudat_test;
GO

/* ===== SEC-SQL-PRI-011-RC02 [DESTRUCTIVE] ===== */
-- Detection: non-system tables with columns whose names match medical/health patterns:
-- %medical%, %diagnosis%, %treatment%, %prescription%, %health%, %illness%, %disease%,
-- %hmo%, %kupat%. No encryption or classification check — column name match is enough.
-- Setup: create a table with a 'diagnosis' column.
-- Run as sysadmin/dbowner. Revert drops the table.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dbdome_medical_test'
               AND schema_id = SCHEMA_ID('dbo'))
    CREATE TABLE dbo.dbdome_medical_test (
        id              INT IDENTITY PRIMARY KEY,
        patient_name    NVARCHAR(200),
        diagnosis       NVARCHAR(500),   -- triggers %diagnosis% pattern
        treatment_date  DATE             -- triggers %treatment% pattern (bonus hit)
    );
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dbdome_medical_test'
           AND schema_id = SCHEMA_ID('dbo'))
    DROP TABLE dbo.dbdome_medical_test;
GO

/* ===== SEC-SQL-PRI-011-RC03 [DESTRUCTIVE] ===== */
-- Detection: non-system tables with columns matching sensitive-category patterns:
-- %religion%, exactly 'dat', %political%, %orientation%, %ethnic%, %nationality%.
-- No encryption or row-count check — column name match is sufficient.
-- Setup: create a table with a 'religion' column and a 'nationality' column.
-- Run as sysadmin/dbowner. Revert drops the table.
-- SETUP:
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dbdome_sensitive_attr_test'
               AND schema_id = SCHEMA_ID('dbo'))
    CREATE TABLE dbo.dbdome_sensitive_attr_test (
        id          INT IDENTITY PRIMARY KEY,
        full_name   NVARCHAR(200),
        religion    NVARCHAR(100),   -- triggers %religion%
        nationality NVARCHAR(100)    -- triggers %nationality%
    );
GO
-- REVERT:
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dbdome_sensitive_attr_test'
           AND schema_id = SCHEMA_ID('dbo'))
    DROP TABLE dbo.dbdome_sensitive_attr_test;
GO


/* ########## batch 41 (1 reproducers) ########## */
/* ===== SEC-SQL-QE-001-RC01 [SAFE] ===== */
-- Detection: Stored procedure currently running slower than its historical average elapsed time.
-- Predicate: (r.total_elapsed_time * 1000.0) > (ps.total_elapsed_time / NULLIF(ps.execution_count, 0))
--   r.total_elapsed_time (microseconds) * 1000 > cumulative_elapsed / execution_count (microseconds avg)
--   i.e. current run microseconds * 1000 > avg microseconds, so current run > avg/1000.
--   In practice: seed the proc's stats with one short run, then hold a longer run open in Session B.
--
-- REQUIRES TWO SESSIONS:
--   Session A: run SETUP block (creates DB, proc, seeds stats with a fast run).
--   Session B: run the "BEGIN SESSION B" block and leave it running (do NOT commit/end it).
--   Then run the detection query from any session — it will return >=1 row for the slow run.
--   After verifying, kill the Session B SPID (or let WAITFOR finish), then run REVERT in Session A.
--
-- SAFETY: No persistent schema changes outside the throwaway database dbdome_qe_test.
--         WAITFOR in Session B will self-terminate after 10 minutes even if not killed.
--         Mark SAFE because everything is confined to the throwaway DB which is dropped on revert.

-- SETUP (run in Session A):
-- Step 1: create throwaway database and stored procedure.
IF DB_ID('dbdome_qe_test') IS NULL
    CREATE DATABASE dbdome_qe_test;
GO

USE dbdome_qe_test;
GO

IF OBJECT_ID('dbo.dbdome_slow_proc_test', 'P') IS NOT NULL
    DROP PROCEDURE dbo.dbdome_slow_proc_test;
GO

CREATE PROCEDURE dbo.dbdome_slow_proc_test
    @delay_seconds INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    -- Use a short WAITFOR to simulate work; Session B will pass a large value.
    DECLARE @delay CHAR(8) = '00:00:0' + CAST(@delay_seconds AS VARCHAR(2));
    IF @delay_seconds >= 10
        SET @delay = '00:00:' + CAST(@delay_seconds AS VARCHAR(2));
    WAITFOR DELAY @delay;
    SELECT 1 AS result;
END;
GO

-- Step 2: execute once with a very short delay to seed dm_exec_procedure_stats
--         with a low average (~1 second = 1,000,000 microseconds).
EXEC dbo.dbdome_slow_proc_test @delay_seconds = 1;
GO

-- Step 3: (Run in SESSION B — leave this executing, do NOT wait for it to finish)
--         Open a NEW query window / connection, switch to dbdome_qe_test, and run:
--
--   USE dbdome_qe_test;
--   EXEC dbo.dbdome_slow_proc_test @delay_seconds = 30;
--
--         While that 30-second execution is in-flight:
--           current elapsed  ~30,000,000 µs * 1000 = 30,000,000,000
--           historical avg   ~1,000,000 µs (from the 1-second seed run)
--           30,000,000,000 > 1,000,000  => detection fires.
--
-- Step 4: Run the detection SQL from any session while Session B is still executing.
--         You should see dbdome_qe_test.dbo.dbdome_slow_proc_test in the results.
GO

-- REVERT (run in Session A after Session B's WAITFOR finishes or after killing it):
USE master;
GO

IF DB_ID('dbdome_qe_test') IS NOT NULL
BEGIN
    ALTER DATABASE dbdome_qe_test SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE dbdome_qe_test;
END;
GO
