-- =============================================================================
-- 7540_aud020_rc01_default_trace_attribution.sql
--
-- Give SEC-SQL-AUD-020-RC01 (sqlserver) a login_name, by reading the DEFAULT
-- TRACE instead of relying on the plan cache. 7530 could not fix this one: its
-- step is a multi-statement batch, outside 7530's provable rewrite rules.
--
-- WHAT'S WRONG
--   The collected step's 24h branch reads sys.dm_exec_query_stats +
--   sys.dm_exec_sql_text and hardcodes `CAST(NULL AS NVARCHAR(128)) AS
--   login_name`: the plan cache is an aggregate shared across sessions, so by the
--   time a statement is cached, WHO ran it is gone. The other branch reads
--   sys.dm_exec_requests, which sees a drop only while it is still executing --
--   and a DROP DATABASE finishes in milliseconds. 7520 measured the outcome on
--   192.168.1.213: 3,773 of 3,775 collected rows came from the unattributable
--   branch, which is why alerts.alert_log.login_name is empty for this family.
--
--   7520 concluded the cure was SQL Server Audit (server_principal_name) via the
--   step-2 fn_get_audit_file batch from 6270. That step is hardcoded to
--   N'C:\Audit\dbdome_audit*.sqlaudit' inside a TRY/CATCH whose CATCH returns an
--   EMPTY result set, so wherever that audit isn't configured -- or the host is
--   Linux -- it silently yields nothing, and every customer would have to stand up
--   SQL Server Audit before "who dropped the database?" could be answered.
--
-- THE FIX
--   The default trace is ON by default, needs no per-target setup, and records
--   the DDL event itself with LoginName. 6570 already relies on it for
--   SEC-SQL-AUD-027-RC01. This PREPENDS a trace branch; when the trace answers,
--   the batch returns those rows and never reaches the plan-cache branch.
--
--   Path derivation is 6570's (dynamic '\' vs '/' separator), which is the fix
--   that took AUD-027 from permanently-dark to working on Linux MSSQL.
--
-- VALIDATED ON A LIVE INSTANCE before this file was written
--   (Microsoft SQL Server 2022 RTM-CU25, Linux, via the dbdome_mon_usr login):
--     * path derivation: /var/opt/mssql/log/log_35.trc -> /var/opt/mssql/log/log.trc
--     * the monitoring login CAN read it (ALTER TRACE present): 570 Object:Deleted
--       events retained
--     * the full query below executes and returns the 5 expected columns
--
--   That validation also DISPROVED the obvious filter. sys.trace_subclass_values
--   on this build does NOT name object types 'DATABASE' / 'SCHEMA' -- it returns
--   two-letter codes: 16964 = 'DB', 17235 = 'SC', 21075 = 'SR', 17747 = 'SE', 94
--   codes in all. A `subclass_name IN ('DATABASE','SCHEMA')` filter would have
--   matched NOTHING and shipped as a silent no-op, exactly the AUD-027 failure
--   mode. So the branch matches ObjectType 16964 / 'DB', which is unambiguous.
--
-- SCOPE: DATABASE drops only.
--   Schema drops are NOT covered by this branch. The two-letter code a DROP SCHEMA
--   emits could not be confirmed without generating one on a live server ('SC' is
--   more likely Service Broker CONTRACT than schema, and guessing is what this
--   whole exercise is meant to stop). Schema drops continue to be caught by the
--   existing plan-cache branch, unattributed, exactly as today -- nothing is lost.
--   To finish the job: run a DROP SCHEMA on a test instance, read the ObjectType
--   off the trace, and widen the IN list to the observed code.
--
-- PREPEND, never replace: the existing SQL (7520's false-positive guard and any
--   local tuning) is carried through verbatim and still runs whenever the trace is
--   disabled or unreadable. Wholesale replacement silently reverts later
--   migrations -- learned on 7490/7350, and why 7520 wraps rather than rewrites.
--
-- The trace branch is inside TRY/CATCH: sys.fn_trace_gettable needs ALTER TRACE,
--   so a target whose monitoring login lacks it falls through to today's behaviour
--   rather than turning a noisy metric into a failing one.
--
-- Output columns and order are unchanged (event_time, login_name, database_name,
-- object_name, statement), so monitoring.v_sec_sql_aud_020_rc01, the alert
-- resultset and the Grafana panels are unaffected. The alert path needs nothing
-- else: fn_get_alert_log_resultset (0320) already falls back to
-- jsonb_lower_keys(elem)->>'login_name' when alerts.alert_log.login_name is empty.
--
-- No '--' comments inside the stored T-SQL: metrics.v_custom_metrics flattens
-- \n -> space before execution, so a line comment would swallow the rest of the
-- batch (the constraint 6140/5046 call out). The marker is a /* */ block comment.
--
-- Encryption-aware (7300): reads via rootcause.dec(), writes via rootcause.enc().
-- Idempotent: the marker makes a re-run a no-op.
-- =============================================================================

DO $mig$
DECLARE
    v_marker  constant text := 'dbdome-aud020-trace';
    v_enc     boolean := to_regprocedure('rootcause.enc(jsonb)') IS NOT NULL;
    v_haskey  boolean := nullif(current_setting('rootcause.k', true), '') IS NOT NULL;

    v_trace   constant text := $aud020$SET NOCOUNT ON; /* dbdome-aud020-trace */
DECLARE @tracepath nvarchar(260), @tracefile nvarchar(260), @sep char(1);
BEGIN TRY
    SELECT @tracepath = path FROM sys.traces WHERE is_default = 1;
    IF @tracepath IS NOT NULL
    BEGIN
        SET @sep = CASE WHEN CHARINDEX('\', @tracepath) > 0 THEN '\' ELSE '/' END;
        SET @tracefile = SUBSTRING(@tracepath, 1, LEN(@tracepath) - CHARINDEX(@sep, REVERSE(@tracepath))) + @sep + 'log.trc';
    END;
    IF @tracefile IS NOT NULL
    BEGIN
        SELECT TOP 500
            CONVERT(varchar(19), t.StartTime, 120) AS event_time,
            t.LoginName AS login_name,
            ISNULL(t.DatabaseName, '') AS database_name,
            t.ObjectName AS object_name,
            'DROP DATABASE ' + ISNULL(t.ObjectName, ISNULL(t.DatabaseName, ''))
                + ' by ' + ISNULL(t.LoginName, 'unknown login')
                + ' via ' + ISNULL(t.ApplicationName, 'unknown app')
                + ' from ' + ISNULL(t.HostName, 'unknown host')
                + CASE WHEN t.Success = 0 THEN ' (FAILED ATTEMPT)' ELSE '' END AS statement
        FROM sys.fn_trace_gettable(@tracefile, DEFAULT) t
        LEFT JOIN sys.trace_subclass_values sv
               ON sv.trace_event_id  = t.EventClass
              AND sv.trace_column_id = 28
              AND sv.subclass_value  = t.ObjectType
        WHERE t.EventClass = 47
          AND t.StartTime >= DATEADD(day, -1, GETDATE())
          AND (t.ObjectType = 16964 OR ISNULL(sv.subclass_name, '') = 'DB')
          AND ISNULL(t.LoginName, '') NOT LIKE '%dbdome%'
          AND ISNULL(t.ApplicationName, '') NOT LIKE '%dbdome%'
        ORDER BY t.StartTime DESC;
        RETURN;
    END;
END TRY
BEGIN CATCH
    SET @tracefile = NULL;
END CATCH;$aud020$;

    r         record;
    v_sql     text;
    v_new     text;
    v_done    int := 0;
    v_skip    int := 0;
BEGIN
    IF v_enc AND NOT v_haskey THEN
        RAISE EXCEPTION
            '7540: detection_steps are encrypted (7300) but this session has no key. '
            'Connect as dbdome_adm / dbdome_mon_usr, or run: '
            'SELECT set_config(''rootcause.k'', ''<DBDOME_SECRET_KEY>'', false);';
    END IF;

    FOR r IN
        SELECT ds.id, dp.root_cause_id, ds.name
        FROM rootcause.detection_paths dp
        JOIN rootcause.detection_path_steps dps ON dps.detection_path_id = dp.id
        JOIN rootcause.detection_steps ds       ON ds.id = dps.detection_step_id
        WHERE dp.vendor_slug = 'sqlserver'
          AND dp.root_cause_id = 'SEC-SQL-AUD-020-RC01'
        ORDER BY ds.id
    LOOP
        IF v_enc THEN
            EXECUTE 'SELECT rootcause.dec(content)->>''sql'' FROM rootcause.detection_steps WHERE id=$1'
              INTO v_sql USING r.id;
        ELSE
            SELECT content->>'sql' INTO v_sql FROM rootcause.detection_steps WHERE id = r.id;
        END IF;

        IF v_sql IS NULL OR btrim(v_sql) = '' THEN
            RAISE EXCEPTION '7540: cannot read SQL for step % (wrong key?)', r.id;
        END IF;
        IF position(v_marker in v_sql) > 0 THEN
            v_skip := v_skip + 1; CONTINUE;
        END IF;
        -- 6270's audit-trail batch already reports server_principal_name: leave it.
        IF position('fn_get_audit_file' in v_sql) > 0 THEN
            v_skip := v_skip + 1; CONTINUE;
        END IF;
        -- Only the plan-cache branch carries the attribution gap this fixes.
        IF position('dm_exec_query_stats' in v_sql) = 0 THEN
            RAISE NOTICE '7540: step % (%) has no plan-cache branch - left alone', r.id, r.root_cause_id;
            v_skip := v_skip + 1; CONTINUE;
        END IF;

        v_new := v_trace || chr(10) || v_sql;

        IF v_enc THEN
            EXECUTE 'UPDATE rootcause.detection_steps SET content = rootcause.enc(jsonb_build_object(''sql'', $1)) WHERE id=$2'
              USING v_new, r.id;
        ELSE
            UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', v_new) WHERE id = r.id;
        END IF;
        v_done := v_done + 1;
        RAISE NOTICE '7540: default-trace attribution added to % (step %)', r.root_cause_id, r.id;
    END LOOP;

    RAISE NOTICE '7540: % step(s) updated, % skipped (already applied / audit-trail / no cache branch)',
                 v_done, v_skip;
END $mig$;

-- -----------------------------------------------------------------------------
-- VERIFY
--
-- 1) Catalog (key-bearing session) -- the DMV step carries the marker, the
--    audit-trail step does not:
--
--   SELECT ds.id, ds.name,
--          (rootcause.dec(ds.content)->>'sql') LIKE '%dbdome-aud020-trace%' AS has_trace_branch
--     FROM rootcause.detection_paths dp
--     JOIN rootcause.detection_path_steps dps ON dps.detection_path_id = dp.id
--     JOIN rootcause.detection_steps ds ON ds.id = dps.detection_step_id
--    WHERE dp.vendor_slug = 'sqlserver' AND dp.root_cause_id = 'SEC-SQL-AUD-020-RC01'
--    ORDER BY ds.id;
--
-- 2) End-to-end, on a test instance you are allowed to mutate: drop a scratch
--    database, then confirm the trace attributes it (this is the one check that
--    cannot be done read-only, which is why it is not claimed above):
--
--   CREATE DATABASE dbdome_trace_probe; DROP DATABASE dbdome_trace_probe;
--   -- then, as the monitoring login:
--   DECLARE @p nvarchar(260), @f nvarchar(260), @s char(1);
--   SELECT @p = path FROM sys.traces WHERE is_default = 1;
--   SET @s = CASE WHEN CHARINDEX('\', @p) > 0 THEN '\' ELSE '/' END;
--   SET @f = SUBSTRING(@p, 1, LEN(@p) - CHARINDEX(@s, REVERSE(@p))) + @s + 'log.trc';
--   SELECT TOP 5 t.StartTime, t.LoginName, t.DatabaseName, t.ObjectName, t.ObjectType
--     FROM sys.fn_trace_gettable(@f, DEFAULT) t
--    WHERE t.EventClass = 47 AND t.ObjectType = 16964
--    ORDER BY t.StartTime DESC;
--   -- expect the drop, attributed to the login that ran it
--
-- 3) After a collection cycle:
--
--   SELECT server, event_time, login_name, database_name, object_name, statement
--     FROM monitoring.v_sec_sql_aud_020_rc01 ORDER BY entry_date DESC LIMIT 20;
--   -- login_name still NULL on every row means the trace branch is not answering:
--   -- check ALTER TRACE for the monitoring login and
--   -- sp_configure 'default trace enabled'.
-- -----------------------------------------------------------------------------
