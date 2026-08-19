-- =============================================================================
-- 7560_acc011_rc02_revert_2008_sysprocesses.sql
-- Revert the 7490 "2008-safe" edit to SEC-SQL-ACC-011-RC02 (sqlserver), at the
-- operator's request, while KEEPING the 7550 VIEW SERVER STATE guard.
--
-- WHAT IT UNDOES (exactly the two things 7490 did, nothing else)
--   1. DB_NAME(COALESCE(r.database_id, p.dbid))
--        -> DB_NAME(COALESCE(r.database_id, s.database_id))
--   2. removes the OUTER APPLY over sys.sysprocesses that fed p
--
-- WHAT IT KEEPS
--   * the 7550 HAS_PERMS_BY_NAME guard (batch stays degradable, no error storm)
--   * the 7350 execution_plan_xml wrapper
--   * any other local drift - this is a surgical reverse of 7490's two edits on
--     the CURRENT text, not a substitution of a stored copy. Same rule 7490 and
--     7550 follow, and for the same reason: substituting a "known-good" copy
--     silently reverted 7350 on 213 once already.
--
-- CONSEQUENCE - READ BEFORE APPLYING
--   sys.dm_exec_sessions.database_id was ADDED IN SQL SERVER 2012. T-SQL binds
--   column names for the whole batch at parse time, so on a 2008 / 2008 R2
--   target the ENTIRE step fails with "Invalid column name 'database_id'" even
--   for rows that never needed it. That is precisely the bug 7490 existed to
--   fix. Applying this re-opens it. On 2012+ targets there is no difference.
--
--   This does NOT affect the VIEW SERVER STATE failure on eladsap_prod:
--   sys.sysprocesses never threw error 300 (without the permission it silently
--   narrows to the caller's own session). The objects that hard-fail are
--   dm_exec_sql_text / dm_exec_connections / dm_exec_query_stats /
--   dm_tran_active_transactions, none of which 7490 or this script touch.
--
-- ENCRYPTION: same contract as 7490 / 7550 - read via rootcause.dec(), write via
-- rootcause.enc(), reached through EXECUTE so this parses where those functions
-- do not exist; refuses to write plaintext over ciphertext without a key.
--
-- Idempotent: a step already reverted is left untouched.
-- =============================================================================

DO $mig$
DECLARE
    v_name     constant text := 'Detect SEC-SQL-ACC-011-RC02 (sqlserver)';
    v_new_expr constant text := 'DB_NAME(COALESCE(r.database_id, s.database_id))';
    v_old_expr constant text := 'DB_NAME(COALESCE(r.database_id, p.dbid))';
    -- byte-for-byte the block 7490 inserted
    v_apply    constant text :=
        E'OUTER APPLY (\n'
        '    SELECT TOP (1) sp.dbid\n'
        '    FROM sys.sysprocesses AS sp WITH (NOLOCK)\n'
        '    WHERE sp.spid = s.session_id\n'
        ') AS p\n';
    v_enc     boolean := to_regprocedure('rootcause.enc(jsonb)') IS NOT NULL;
    v_haskey  boolean := nullif(current_setting('rootcause.k', true), '') IS NOT NULL;
    v_sql     text;
    v_new     text;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM rootcause.detection_steps
                    WHERE vendor_slug='sqlserver' AND name=v_name) THEN
        RAISE NOTICE '7560: step "%" not present - nothing to do', v_name;
        RETURN;
    END IF;

    IF v_enc AND NOT v_haskey THEN
        RAISE EXCEPTION
            '7560: this install encrypts detection_steps (7300 applied) but the session has no key. '
            'Refusing to touch ciphertext. Connect as a role holding the role-default '
            '(dbdome_adm / dbdome_mon_usr / dbexpert_adm / dbdome_engine), or run first: '
            'SELECT set_config(''rootcause.k'', ''<DBDOME_SECRET_KEY>'', false);';
    END IF;

    IF v_enc THEN
        EXECUTE 'SELECT rootcause.dec(content)->>''sql'' FROM rootcause.detection_steps '
                'WHERE vendor_slug=''sqlserver'' AND name=$1' INTO v_sql USING v_name;
    ELSE
        SELECT content->>'sql' INTO v_sql FROM rootcause.detection_steps
         WHERE vendor_slug='sqlserver' AND name=v_name;
    END IF;

    IF v_sql IS NULL OR btrim(v_sql) = '' THEN
        RAISE EXCEPTION '7560: could not read the current SQL (wrong key, or content has no sql). Aborting.';
    END IF;

    IF position('sys.sysprocesses' in v_sql) = 0 AND position(v_new_expr in v_sql) > 0 THEN
        RAISE NOTICE '7560: already reverted - no change';
        RETURN;
    END IF;

    IF position(v_old_expr in v_sql) = 0 THEN
        RAISE EXCEPTION '7560: expected expression % not found in the live SQL - '
                        'it has diverged; review by hand rather than letting this script guess.', v_old_expr;
    END IF;
    IF position(v_apply in v_sql) = 0 THEN
        RAISE EXCEPTION '7560: the sysprocesses APPLY block 7490 inserted is not present verbatim - '
                        'refusing to guess at its boundaries. Review by hand.';
    END IF;

    v_new := replace(v_sql, v_old_expr, v_new_expr);   -- 1) 2012-only column back
    v_new := replace(v_new, v_apply, '');              -- 2) drop the APPLY that fed p

    IF v_enc THEN
        EXECUTE 'UPDATE rootcause.detection_steps SET content = rootcause.enc(jsonb_build_object(''sql'', $1)) '
                'WHERE vendor_slug=''sqlserver'' AND name=$2' USING v_new, v_name;
    ELSE
        UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', v_new)
         WHERE vendor_slug='sqlserver' AND name=v_name;
    END IF;

    IF v_enc THEN
        EXECUTE 'SELECT rootcause.dec(content)->>''sql'' FROM rootcause.detection_steps '
                'WHERE vendor_slug=''sqlserver'' AND name=$1' INTO v_sql USING v_name;
    ELSE
        SELECT content->>'sql' INTO v_sql FROM rootcause.detection_steps
         WHERE vendor_slug='sqlserver' AND name=v_name;
    END IF;

    -- the revert must have happened AND the guard must have survived it
    IF position('sys.sysprocesses' in v_sql) > 0
       OR position(v_old_expr in v_sql) > 0
       OR position(v_new_expr in v_sql) = 0 THEN
        RAISE EXCEPTION '7560: verification FAILED - stored SQL is not the reverted version';
    END IF;
    IF position('HAS_PERMS_BY_NAME' in v_sql) = 0 THEN
        RAISE EXCEPTION '7560: verification FAILED - the 7550 guard was lost; restore it before using this step';
    END IF;

    RAISE NOTICE '7560: reverted 7490 in place (storage=%); guard kept: %; 7350 wrapper: %',
                 CASE WHEN v_enc THEN 'encrypted' ELSE 'plaintext' END,
                 position('HAS_PERMS_BY_NAME' in v_sql) > 0,
                 position('execution_plan_xml' in v_sql) > 0;
END $mig$;
