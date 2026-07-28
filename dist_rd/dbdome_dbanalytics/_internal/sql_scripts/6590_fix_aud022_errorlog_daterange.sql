-- =============================================================================
-- 6590_fix_aud022_errorlog_daterange.sql
--
-- SEC-SQL-AUD-022-RC01 (sqlserver) — "Unsuccessful database authentication
-- attempts" — read the SQL Server error log via
--     xp_readerrorlog 0, 1, N'Login failed'
-- with NO date range, so INSERT..EXEC buffered EVERY 'Login failed' line in the
-- entire current error log into a table variable and only filtered by date
-- afterwards. On hosts whose error log is bloated with tens of thousands of
-- failed logins (a mis-set monitoring credential hammering the server, or an
-- external brute-force on 'sa'), the whole thing exceeded the collector's 30s
-- query timeout (DBEXPERT_QUERY_TIMEOUT) and the metric errored every cycle
-- (HYT00 Query timeout expired).
--
-- Fix: pass the start/end time to xp_readerrorlog (@p5/@p6) so the log is
-- filtered at the source to the last 24h. Measured on a live Linux host with
-- ~82k failed logins/24h: ~76s -> ~25s (under the 30s cap); on a lighter host
-- ~30s -> ~7s. Same result set; the trailing WHERE is kept as a belt-and-braces
-- bound. Idempotent; matched by root cause + vendor (not step id).
--
-- NOTE: a bloated error log is itself the real problem — fix the flood source
-- (mis-set dbdome_mon_usr password / brute-force) and cycle the log
-- (EXEC sp_cycle_errorlog) for durable headroom.
-- =============================================================================

UPDATE rootcause.detection_steps ds
SET content = jsonb_set(
    ds.content,
    '{sql}',
    to_jsonb($aud022$SET NOCOUNT ON;
BEGIN TRY
  DECLARE @el TABLE (LogDate datetime, ProcessInfo nvarchar(100), LogText nvarchar(4000));
  DECLARE @start datetime = DATEADD(DAY,-1, GETDATE()), @end datetime = GETDATE();
  INSERT INTO @el EXEC sys.xp_readerrorlog 0, 1, N'Login failed', NULL, @start, @end;
  SELECT TOP 500 CONVERT(varchar(19), LogDate, 120) AS event_time, CAST(NULL AS sysname) AS login_name,
         CAST(NULL AS sysname) AS host_name, CAST(NULL AS sysname) AS os_user,
         LogText AS error_info, ProcessInfo AS attempts
  FROM @el WHERE LogDate > DATEADD(DAY,-1, GETDATE()) ORDER BY LogDate DESC;
END TRY
BEGIN CATCH
  SELECT CAST(NULL AS varchar(19)) AS event_time, CAST(NULL AS sysname) AS login_name,
         CAST(NULL AS sysname) AS host_name, CAST(NULL AS sysname) AS os_user,
         CAST(NULL AS nvarchar(4000)) AS error_info, CAST(NULL AS nvarchar(100)) AS attempts WHERE 1=0;
END CATCH$aud022$::text),
    true
)
FROM rootcause.detection_path_steps dps
JOIN rootcause.detection_paths dp ON dp.id = dps.detection_path_id
WHERE dps.detection_step_id = ds.id
  AND dp.root_cause_id = 'SEC-SQL-AUD-022-RC01'
  AND ds.vendor_slug = 'sqlserver';
