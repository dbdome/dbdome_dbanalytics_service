-- =============================================================================
-- DBDOME: SQL Server audit-status view
-- =============================================================================
-- Run on: every monitored SQL Server instance (one-time setup by a DBA).
-- Requires: VIEW SERVER STATE (server audits are server-scope objects).
--
-- Purpose: exposes the current SQL Server Audit configuration as a read-only
-- view so that DBDOME detection step 1 for SEC-SQL-AUD-015 can report audit
-- state without needing CREATE SERVER AUDIT permissions or a pre-existing
-- audit directory (C:\Audit\ or similar).
--
-- Output columns match the SEC-SQL-AUD-015 step-1 contract:
--   setup_ok              INT            1 = audit running, 0 = not ready
--   audit_name            NVARCHAR(128)
--   audit_directory       NVARCHAR(512)  actual path or '(not configured)'
--   error_message         NVARCHAR(4000) NULL when setup_ok = 1
--   enabled_server_audits INT
--   enabled_server_specs  INT
-- =============================================================================

USE master;
GO

CREATE OR ALTER VIEW dbo.vw_dbdome_audit_status
AS
-- Row for the dbdome_audit if it already exists
SELECT
    CAST(
        CASE
            WHEN sa.is_state_enabled = 1 THEN 1
            ELSE 0
        END AS INT)                                                      AS setup_ok,
    sa.name                                                              AS audit_name,
    COALESCE(sfa.log_file_path, N'(not configured)')                     AS audit_directory,
    CAST(
        CASE
            WHEN sa.is_state_enabled = 0
                THEN N'Server audit [' + sa.name + N'] exists but is disabled. '
                   + N'Enable it: ALTER SERVER AUDIT [' + sa.name + N'] WITH (STATE = ON);'
            ELSE NULL
        END AS NVARCHAR(4000))                                           AS error_message,
    (SELECT COUNT(*)
     FROM sys.server_audits
     WHERE is_state_enabled = 1)                                         AS enabled_server_audits,
    (SELECT COUNT(*)
     FROM sys.server_audit_specifications
     WHERE is_state_enabled = 1)                                         AS enabled_server_specs
FROM sys.server_audits sa
LEFT JOIN sys.server_file_audits sfa ON sfa.audit_id = sa.audit_id
WHERE sa.name = N'dbdome_audit'

UNION ALL

-- Fallback row when no dbdome_audit exists at all
SELECT
    CAST(0 AS INT),
    N'dbdome_audit',
    N'(not configured)',
    CAST(
        N'Server audit [dbdome_audit] does not exist. '
      + N'Create it (sysadmin required): '
      + N'CREATE SERVER AUDIT [dbdome_audit] '
      + N'TO FILE (FILEPATH = N''<audit_dir>'', MAXSIZE = 256 MB, MAX_ROLLOVER_FILES = 10) '
      + N'WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE); '
      + N'ALTER SERVER AUDIT [dbdome_audit] WITH (STATE = ON);'
      AS NVARCHAR(4000)),
    CAST((SELECT COUNT(*) FROM sys.server_audits             WHERE is_state_enabled = 1) AS INT),
    CAST((SELECT COUNT(*) FROM sys.server_audit_specifications WHERE is_state_enabled = 1) AS INT)
WHERE NOT EXISTS (
    SELECT 1 FROM sys.server_audits WHERE name = N'dbdome_audit'
);
GO

-- Quick sanity check (run immediately after):
-- SELECT * FROM dbo.vw_dbdome_audit_status;
