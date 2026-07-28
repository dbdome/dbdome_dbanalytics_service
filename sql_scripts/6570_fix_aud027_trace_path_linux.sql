-- =============================================================================
-- 6570_fix_aud027_trace_path_linux.sql
--
-- SEC-SQL-AUD-027-RC01 (sqlserver) — destructive-operation detection — derived
-- the default-trace file path with CHARINDEX('\', ...) (BACKSLASH ONLY). On
-- Linux SQL Server the default-trace path uses forward slashes
-- (/var/opt/mssql/log/log_N.trc), so the expression built '...log_N.trc\log.trc'
-- and sys.fn_trace_gettable() ERRORED -> DROP OBJECT / BACKUP / login- & role-
-- management alerts NEVER fired on any Linux MSSQL host. (The events ARE recorded
-- in the default trace; only the detection query was broken.) Verified on two
-- Linux SQL Server hosts: the fixed derivation returns 55 events/24h vs an error.
--
-- Fix: choose the path separator dynamically (\ on Windows, / on Linux) before
-- stripping the filename and appending 'log.trc'. Windows behaviour is unchanged
-- (CHARINDEX('\') still matches, so @sep = '\'). Idempotent — re-running sets the
-- same corrected SQL. Matched by root cause + vendor (not by step id, which
-- differs per install).
-- =============================================================================

UPDATE rootcause.detection_steps ds
SET content = jsonb_set(
    ds.content,
    '{sql}',
    to_jsonb($aud027$SET NOCOUNT ON;
DECLARE @tracefile nvarchar(260), @tracepath nvarchar(260), @sep char(1);
SELECT @tracepath = path FROM sys.traces WHERE is_default = 1;
SET @sep = CASE WHEN CHARINDEX('\', @tracepath) > 0 THEN '\' ELSE '/' END;
SET @tracefile = SUBSTRING(@tracepath, 1, LEN(@tracepath) - CHARINDEX(@sep, REVERSE(@tracepath))) + @sep + 'log.trc';
IF @tracefile IS NULL
BEGIN
    SELECT CONVERT(varchar(19), GETDATE(), 120) AS event_time, CAST(NULL AS nvarchar(128)) AS login_name,
           CAST(@@SERVERNAME AS nvarchar(128)) AS host_name, CAST(NULL AS nvarchar(128)) AS os_user,
           'DEFAULT TRACE DISABLED' AS auth_info,
           'The default trace is disabled - destructive operations cannot be audited; re-enable it (sp_configure default trace enabled, 1)' AS statement;
    RETURN;
END
SELECT TOP 500
    CONVERT(varchar(19), t.StartTime, 120) AS event_time,
    t.LoginName AS login_name,
    ISNULL(t.HostName, CAST(@@SERVERNAME AS nvarchar(128))) AS host_name,
    t.NTUserName AS os_user,
    CASE t.EventClass
        WHEN 47  THEN 'DROP OBJECT'
        WHEN 115 THEN CASE t.EventSubClass WHEN 1 THEN 'BACKUP DATABASE' WHEN 2 THEN 'RESTORE DATABASE' ELSE 'BACKUP/RESTORE' END
        WHEN 104 THEN CASE t.EventSubClass WHEN 2 THEN 'DROP LOGIN' ELSE 'LOGIN MGMT' END
        WHEN 109 THEN CASE t.EventSubClass WHEN 2 THEN 'DROP DATABASE USER' ELSE 'DB USER MGMT' END
        WHEN 111 THEN CASE t.EventSubClass WHEN 2 THEN 'DROP ROLE' ELSE 'ROLE MGMT' END
        WHEN 108 THEN 'SERVER ROLE MEMBERSHIP CHANGE'
        WHEN 110 THEN 'DB ROLE MEMBERSHIP CHANGE'
        ELSE 'DESTRUCTIVE EVENT'
    END + CASE WHEN t.Success = 0 THEN ' (FAILED ATTEMPT)' ELSE '' END AS auth_info,
    ISNULL(t.DatabaseName, '') + CASE WHEN t.ObjectName IS NOT NULL THEN '.' + t.ObjectName ELSE '' END
        + ' via ' + ISNULL(t.ApplicationName, 'unknown app') AS statement
FROM sys.fn_trace_gettable(@tracefile, DEFAULT) t
WHERE t.EventClass IN (47, 104, 108, 109, 110, 111, 115)
  AND t.StartTime >= DATEADD(day, -1, GETDATE())
  AND ISNULL(t.DatabaseName, '') <> 'tempdb'
ORDER BY t.StartTime DESC;$aud027$::text),
    true
)
FROM rootcause.detection_path_steps dps
JOIN rootcause.detection_paths dp ON dp.id = dps.detection_path_id
WHERE dps.detection_step_id = ds.id
  AND dp.root_cause_id = 'SEC-SQL-AUD-027-RC01'
  AND ds.vendor_slug = 'sqlserver';
