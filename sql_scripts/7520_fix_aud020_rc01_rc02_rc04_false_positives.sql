-- =============================================================================
-- 7520_fix_aud020_rc01_rc02_rc04_false_positives.sql
--
-- Stop SEC-SQL-AUD-020-RC01/RC02/RC04 firing on stored-procedure DEFINITIONS that
-- merely contain the words they hunt for.
--
-- WHAT'S WRONG
--   Each of these root causes reads the plan cache:
--       FROM sys.dm_exec_query_stats qs OUTER APPLY sys.dm_exec_sql_text(qs.sql_handle) st
--       WHERE ... st.text LIKE '%DROP%DATABASE%' ...
--   `%...%` spans the WHOLE batch, and the plan cache is full of CREATE PROCEDURE
--   texts. Any procedure whose body mentions dropping something matches, so the
--   detector reports "Database or schema dropped" for a proc that was merely
--   compiled. Observed live on 192.168.1.213: 51 alerts on RC01, 46 on RC02, 51 on
--   RC04 in 14 days, including Microsoft's own sys.sp_table_statistics2_rowset -
--   which means they re-alert forever and can never be cleared.
--
--   Same class of bug 6460 fixed for RC03, but broader: 6460 excluded DBDOME's own
--   monitoring footprint, while these also match ordinary customer and system
--   procedure definitions.
--
-- THE FIX
--   Wrap the existing detection in an outer SELECT that drops rows whose statement
--   is an object DEFINITION (CREATE/ALTER PROC|FUNCTION|TRIGGER|VIEW) or DBDOME's
--   own monitoring text. Wrapping, rather than rewriting the inner SQL, is
--   deliberate: it preserves whatever is live on the box - later migrations, a
--   re-seed, local tuning - which a wholesale content replacement silently reverts
--   (learned the hard way on 7490/7350). Same technique 7350 uses.
--
--   Only the DMV step is wrapped. The audit-trail step (fn_get_audit_file) is left
--   alone: it is a TRY/CATCH batch that cannot be wrapped in a subquery, and it
--   reports statements that were genuinely EXECUTED and audited, so a CREATE PROC
--   appearing there is a real event rather than a cache artefact.
--
-- WHAT THIS DOES NOT FIX
--   Attribution. The plan-cache branch hardcodes `CAST(NULL AS NVARCHAR(128)) AS
--   login_name` because dm_exec_query_stats has no session attached - by the time a
--   statement is cached, who ran it is gone. On 213, 3,773 of 3,775 collected rows
--   came from that branch, which is why alerts.alert_log.login_name is empty for
--   this family. The cure is the audit trail (server_principal_name), i.e. getting
--   SQL Server Audit writing C:\Audit\dbdome_audit*.sqlaudit on the targets - not a
--   change to this SQL.
--
-- Idempotent: the wrapper is marked and re-running is a no-op.
-- =============================================================================

DO $mig$
DECLARE
    v_marker  constant text := 'dbdome-fp-guard';
    -- Built with chr(10) + explicit ||: no E'' strings, so the T-SQL inside needs no
    -- backslash gymnastics. Underscores are escaped the T-SQL way, [_], because
    -- LIKE '_' is a single-character wildcard and '%dm_exec_%' would also match
    -- e.g. "dmXexecY". Same reason 6460 used an ESCAPE clause; brackets avoid it.
    v_filter  constant text :=
        'WHERE /* dbdome-fp-guard */'                              || chr(10) ||
        '      q.statement NOT LIKE ''%CREATE%PROC%'''             || chr(10) ||
        '  AND q.statement NOT LIKE ''%ALTER%PROC%'''              || chr(10) ||
        '  AND q.statement NOT LIKE ''%CREATE%FUNCTION%'''         || chr(10) ||
        '  AND q.statement NOT LIKE ''%ALTER%FUNCTION%'''          || chr(10) ||
        '  AND q.statement NOT LIKE ''%CREATE%TRIGGER%'''          || chr(10) ||
        '  AND q.statement NOT LIKE ''%CREATE%VIEW%'''             || chr(10) ||
        -- DBDOME's own monitoring footprint (mirrors 6460)
        '  AND q.statement NOT LIKE ''%dm[_]exec[_]%'''            || chr(10) ||
        '  AND q.statement NOT LIKE ''%fn[_]get[_]audit[_]file%''' || chr(10) ||
        '  AND q.statement NOT LIKE ''%fn[_]trace[_]gettable%'''   || chr(10) ||
        '  AND q.statement NOT LIKE ''%sys.traces%''';
    v_enc     boolean := to_regprocedure('rootcause.enc(jsonb)') IS NOT NULL;
    v_haskey  boolean := nullif(current_setting('rootcause.k', true), '') IS NOT NULL;
    r         record;
    v_sql     text;
    v_new     text;
    v_done    int := 0;
    v_skip    int := 0;
BEGIN
    IF v_enc AND NOT v_haskey THEN
        RAISE EXCEPTION
            '7520: detection_steps are encrypted (7300) but this session has no key. '
            'Connect as dbdome_adm / dbdome_mon_usr, or run: '
            'SELECT set_config(''rootcause.k'', ''<DBDOME_SECRET_KEY>'', false);';
    END IF;

    FOR r IN
        SELECT ds.id, dp.root_cause_id, ds.name
        FROM rootcause.detection_paths dp
        JOIN rootcause.detection_path_steps dps ON dps.detection_path_id = dp.id
        JOIN rootcause.detection_steps ds       ON ds.id = dps.detection_step_id
        WHERE dp.vendor_slug = 'sqlserver'
          AND dp.root_cause_id IN ('SEC-SQL-AUD-020-RC01',
                                   'SEC-SQL-AUD-020-RC02',
                                   'SEC-SQL-AUD-020-RC04')
        ORDER BY dp.root_cause_id
    LOOP
        IF v_enc THEN
            EXECUTE 'SELECT rootcause.dec(content)->>''sql'' FROM rootcause.detection_steps WHERE id=$1'
              INTO v_sql USING r.id;
        ELSE
            SELECT content->>'sql' INTO v_sql FROM rootcause.detection_steps WHERE id = r.id;
        END IF;

        IF v_sql IS NULL OR btrim(v_sql) = '' THEN
            RAISE EXCEPTION '7520: cannot read SQL for step % (wrong key?)', r.id;
        END IF;
        IF position(v_marker in v_sql) > 0 THEN
            v_skip := v_skip + 1; CONTINUE;                    -- already guarded
        END IF;
        -- The audit-trail step is a TRY/CATCH batch: not wrappable, and not the
        -- source of these false positives.
        IF position('fn_get_audit_file' in v_sql) > 0 THEN
            v_skip := v_skip + 1; CONTINUE;
        END IF;
        IF position('dm_exec_query_stats' in v_sql) = 0 THEN
            RAISE NOTICE '7520: step % (%) has no plan-cache branch - left alone', r.id, r.root_cause_id;
            v_skip := v_skip + 1; CONTINUE;
        END IF;

        v_new := 'SELECT q.event_time, q.login_name, q.database_name, q.object_name, q.statement' || chr(10)
              || 'FROM (' || chr(10) || v_sql || chr(10) || ') AS q' || chr(10) || v_filter;

        IF v_enc THEN
            EXECUTE 'UPDATE rootcause.detection_steps SET content = rootcause.enc(jsonb_build_object(''sql'', $1)) WHERE id=$2'
              USING v_new, r.id;
        ELSE
            UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', v_new) WHERE id = r.id;
        END IF;
        v_done := v_done + 1;
        RAISE NOTICE '7520: guarded % (step %)', r.root_cause_id, r.id;
    END LOOP;

    RAISE NOTICE '7520: % step(s) wrapped, % skipped (already guarded / audit-trail / no cache branch)',
                 v_done, v_skip;
END $mig$;

-- -----------------------------------------------------------------------------
-- VERIFY (key-bearing session)
--   SELECT dp.root_cause_id, ds.id,
--          (rootcause.dec(ds.content)->>'sql') LIKE '%dbdome-fp-guard%' AS guarded
--     FROM rootcause.detection_paths dp
--     JOIN rootcause.detection_path_steps dps ON dps.detection_path_id=dp.id
--     JOIN rootcause.detection_steps ds ON ds.id=dps.detection_step_id
--    WHERE dp.vendor_slug='sqlserver'
--      AND dp.root_cause_id IN ('SEC-SQL-AUD-020-RC01','SEC-SQL-AUD-020-RC02','SEC-SQL-AUD-020-RC04')
--    ORDER BY 1, 2;
--   -- the DMV step guarded=t, the audit step guarded=f (by design)
--
-- Then watch a collection cycle: rows for these metrics should drop to the genuine
-- events only, and the existing open incidents can be resolved once they stop
-- re-arriving.
-- -----------------------------------------------------------------------------
