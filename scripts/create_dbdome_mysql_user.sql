-- =============================================================================
-- create_dbdome_mysql_user.sql
--
-- Creates the MySQL monitoring account for DBDOME with the privileges needed
-- to run ALL security/perf root-cause detections (vendor_slug = 'mysql',
-- 2,483 detection steps as of 2026-07-17). Grants are grounded in a scan of
-- every object those steps reference:
--   information_schema.* (incl. PROCESSLIST, INNODB_*, FILES)  -> PROCESS
--   performance_schema.* (global_status/variables, digests,
--     replication_*, data_locks, keyring_keys, host_cache, ...) -> SELECT
--   mysql.* (user, db, role_edges, audit_log_*, general_log,
--     tables_priv, func, default_roles, ...)                    -> SELECT
--   sys.* (innodb_lock_waits, schema_redundant_indexes, ...)    -> SELECT
--   SHOW BINARY LOGS                                            -> REPLICATION CLIENT
--   SHOW ENGINE INNODB STATUS                                   -> PROCESS
--   information_schema.EVENTS / TRIGGERS / ROUTINES visibility  -> EVENT, TRIGGER, SHOW_ROUTINE
--
-- Run as root (or an admin with GRANT OPTION) on the monitored MySQL server.
-- Tested syntax: MySQL 8.0+. MariaDB variant at the bottom.
--
-- !! EDIT BEFORE RUNNING !!
--   - password: replace CHANGE_ME_STRONG_PASSWORD
--   - host: '%' accepts connection from anywhere; scope it to the DBDOME
--     machine's IP when you can (e.g. 'dbdome'@'10.10.53.20'). REMEMBER:
--     the host part is where DBDOME connects FROM (the client), NOT this
--     server's address. If MySQL sits behind a local proxy/tunnel, the
--     connection may arrive as 'localhost' - create that row instead/too.
-- =============================================================================

CREATE USER IF NOT EXISTS 'dbdome'@'%' IDENTIFIED BY 'CHANGE_ME_STRONG_PASSWORD';

-- -----------------------------------------------------------------------------
-- TIER 1 - REQUIRED (read-only monitoring core)
--   SELECT             : information_schema / performance_schema / mysql / sys reads
--   PROCESS            : PROCESSLIST, SHOW ENGINE INNODB STATUS, I_S.INNODB_*, I_S.FILES
--   REPLICATION CLIENT : SHOW BINARY LOGS, replication status detections
--   SHOW DATABASES     : full schema enumeration (not just granted ones)
--   SHOW VIEW          : view definitions for exposure/definer checks
-- -----------------------------------------------------------------------------
GRANT SELECT, PROCESS, REPLICATION CLIENT, SHOW DATABASES, SHOW VIEW
    ON *.* TO 'dbdome'@'%';

-- SHOW_ROUTINE (MySQL 8.0.20+): stored procedure/function bodies for the
-- definer / SQL-injection surface checks without making the account a DBA.
GRANT SHOW_ROUTINE ON *.* TO 'dbdome'@'%';

-- -----------------------------------------------------------------------------
-- TIER 2 - RECOMMENDED (metadata visibility, technically DDL-capable)
-- information_schema.EVENTS/TRIGGERS rows are only visible with the EVENT /
-- TRIGGER privilege on the schema. Without these, the scheduled-task-abuse
-- and trigger-based-persistence detections return empty (blind spot), they
-- do not error. The trade-off: these privileges also allow CREATING events/
-- triggers - if the customer's security team objects, drop this grant and
-- accept the blind spot.
-- -----------------------------------------------------------------------------
GRANT EVENT, TRIGGER ON *.* TO 'dbdome'@'%';

-- -----------------------------------------------------------------------------
-- TIER 3 - OPTIONAL (uncomment per deployment)
-- -----------------------------------------------------------------------------
-- (a) One detection-enablement step ('Ensure MySQL general_log is enabled with
--     TABLE output') runs SET GLOBAL log_output/general_log so the auth/audit
--     detections (AUD-021/022/024/025 family) have a log table to read.
--     WARNING: SYSTEM_VARIABLES_ADMIN can change ANY global variable
--     (including disabling audit) - security teams rightly dislike it.
--     Alternative: skip this grant and have the DBA enable it once manually:
--       SET GLOBAL log_output = 'TABLE';  SET GLOBAL general_log = 'ON';
-- GRANT SYSTEM_VARIABLES_ADMIN ON *.* TO 'dbdome'@'%';

-- (b) Session-kill blocker (KILL of offending sessions, e.g. app-login-guard
--     style responses). Not used by MySQL detections today.
-- GRANT CONNECTION_ADMIN ON *.* TO 'dbdome'@'%';

FLUSH PRIVILEGES;

-- -----------------------------------------------------------------------------
-- Verification (run as the new user from the DBDOME machine:
--   mysqlsh --sql --mysql -h <this-server-ip> -u dbdome -p )
-- -----------------------------------------------------------------------------
-- SELECT CURRENT_USER();                                        -- expect dbdome@%
-- SHOW GRANTS;
-- SELECT COUNT(*) FROM information_schema.PROCESSLIST;          -- PROCESS ok
-- SELECT COUNT(*) FROM performance_schema.global_variables;     -- perf schema ok
-- SELECT COUNT(*) FROM mysql.user;                              -- mysql schema ok
-- SHOW BINARY LOGS;                                             -- REPLICATION CLIENT ok
-- SELECT COUNT(*) FROM information_schema.INNODB_TRX;           -- PROCESS ok
-- SELECT COUNT(*) FROM sys.schema_redundant_indexes;            -- sys ok

-- =============================================================================
-- MariaDB variant (MariaDB has no dynamic privileges; SHOW_ROUTINE /
-- SYSTEM_VARIABLES_ADMIN / CONNECTION_ADMIN do not exist there).
-- The detection catalog has a separate 'mariadb' vendor with the same needs.
-- =============================================================================
-- CREATE USER IF NOT EXISTS 'dbdome'@'%' IDENTIFIED BY 'CHANGE_ME_STRONG_PASSWORD';
-- GRANT SELECT, PROCESS, REPLICATION CLIENT, SHOW DATABASES, SHOW VIEW, EVENT, TRIGGER
--     ON *.* TO 'dbdome'@'%';
-- -- routine bodies (MariaDB has no SHOW_ROUTINE; covered by SELECT ON mysql.proc,
-- -- already included in SELECT ON *.*)
-- -- optional, only if the general_log enablement step must run (grants full DBA
-- -- power on MariaDB - prefer manual one-time enablement instead):
-- -- GRANT SUPER ON *.* TO 'dbdome'@'%';
-- FLUSH PRIVILEGES;

-- Client-auth note: MySQL 8 accounts default to caching_sha2_password. The
-- DBDOME collector (pymysql) supports it. If a legacy client at the customer
-- fails with an RSA/auth-plugin error, either upgrade the client or fall back:
--   ALTER USER 'dbdome'@'%' IDENTIFIED WITH mysql_native_password BY '<password>';
