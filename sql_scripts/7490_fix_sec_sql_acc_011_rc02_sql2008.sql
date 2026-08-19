-- =============================================================================
-- 7490_fix_sec_sql_acc_011_rc02_sql2008.sql
-- Make the SEC-SQL-ACC-011-RC02 (sqlserver) detection step run on SQL Server
-- 2008 / 2008 R2.
--
-- SYMPTOM
--   Invalid column name 'database_id' on 2008-era targets; the root cause never
--   produces a verdict there.
--
-- CAUSE
--   The step selects
--       DB_NAME(COALESCE(r.database_id, s.database_id)) AS database_name
--   r = sys.dm_exec_requests, whose database_id exists since 2005 - fine.
--   s = sys.dm_exec_sessions, whose database_id was only ADDED IN 2012. SQL Server
--   binds column names for the whole batch at parse time, so the entire query
--   fails on 2008/2008 R2 even for rows that never needed it. Everything else in
--   the step is 2005+.
--
-- FIX
--   Source the session's database from sys.sysprocesses.dbid instead:
--       DB_NAME(COALESCE(r.database_id, p.dbid))
--   plus an OUTER APPLY feeding p. For a SLEEPING session with an open
--   transaction there is no request row, so dm_exec_requests cannot supply the
--   database, and no other 2008 DMV exposes a session's current database.
--   sysprocesses does, and exists in every version 2008 -> 2022, so ONE query
--   still serves every target. TOP (1) because sysprocesses returns a row per
--   worker thread on a parallel request.
--
-- WHY THIS IS A SURGICAL EDIT, NOT A REWRITE  (learned the hard way)
--   An earlier cut of this script replaced content wholesale with a known-good
--   query copied from the install dump. On 192.168.1.213 that SILENTLY REVERTED
--   7350_rc02_strip_execution_plan_xml, whose outer wrapper
--       SELECT ..., REPLACE(q.sql_text, N'execution_plan_xml', N'') ... FROM (...) AS q
--   was live but absent from the dump baseline. Any install that has had a later
--   migration, a re-seed, or local tuning applied would lose it the same way.
--   So: read the CURRENT sql, change ONLY the two things this fix is about, and
--   write it back - preserving wrappers and any other drift. Same adaptive
--   approach 7350 itself uses.
--
-- ENCRYPTION
--   Where 7300 is applied, detection_steps.content is a jsonb STRING holding an
--   armored PGP blob (rootcause.enc/dec, key in the GUC rootcause.k =
--   DBDOME_SECRET_KEY). Reads go through dec(), writes through enc(); on installs
--   without 7300 both are plain jsonb. The enc/dec references are reached via
--   EXECUTE so this still PARSES where those functions do not exist. On an
--   encrypted install with no session key the script RAISES rather than writing
--   plaintext over ciphertext.
--
-- Idempotent: a step already carrying the fix is left untouched.
-- =============================================================================

DO $mig$
DECLARE
    v_name  constant text := 'Detect SEC-SQL-ACC-011-RC02 (sqlserver)';
    v_old_expr constant text := 'DB_NAME(COALESCE(r.database_id, s.database_id))';
    v_new_expr constant text := 'DB_NAME(COALESCE(r.database_id, p.dbid))';
    v_anchor   constant text := 'OUTER APPLY sys.dm_exec_sql_text(';
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
    v_pos     integer;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM rootcause.detection_steps
                    WHERE vendor_slug='sqlserver' AND name=v_name) THEN
        RAISE NOTICE '7490: step "%" not present - nothing to do', v_name;
        RETURN;
    END IF;

    IF v_enc AND NOT v_haskey THEN
        RAISE EXCEPTION
            '7490: this install encrypts detection_steps (7300 applied) but the session has no key. '
            'Refusing to touch ciphertext. Connect as a role holding the role-default '
            '(dbdome_adm / dbdome_mon_usr / dbexpert_adm / dbdome_engine), or run first: '
            'SELECT set_config(''rootcause.k'', ''<DBDOME_SECRET_KEY>'', false);';
    END IF;

    -- read the CURRENT sql, through decryption where applicable
    IF v_enc THEN
        EXECUTE 'SELECT rootcause.dec(content)->>''sql'' FROM rootcause.detection_steps '
                'WHERE vendor_slug=''sqlserver'' AND name=$1' INTO v_sql USING v_name;
    ELSE
        SELECT content->>'sql' INTO v_sql FROM rootcause.detection_steps
         WHERE vendor_slug='sqlserver' AND name=v_name;
    END IF;

    IF v_sql IS NULL OR btrim(v_sql) = '' THEN
        RAISE EXCEPTION '7490: could not read the current SQL (wrong key, or content has no sql). Aborting.';
    END IF;

    IF position('sys.sysprocesses' in v_sql) > 0 AND position(v_old_expr in v_sql) = 0 THEN
        RAISE NOTICE '7490: already 2008-safe - no change';
        RETURN;
    END IF;

    IF position(v_old_expr in v_sql) = 0 THEN
        RAISE EXCEPTION '7490: expected expression % not found in the live SQL - '
                        'it has diverged; review by hand rather than letting this script guess.', v_old_expr;
    END IF;

    -- 1) swap the 2012-only column for the 2008-safe source
    v_new := replace(v_sql, v_old_expr, v_new_expr);

    -- 2) introduce p, immediately before the first dm_exec_sql_text apply (which
    --    exists in every known variant and sits after the s/r/c applies)
    v_pos := position(v_anchor in v_new);
    IF v_pos = 0 THEN
        RAISE EXCEPTION '7490: anchor "%" not found - cannot place the sysprocesses APPLY safely.', v_anchor;
    END IF;
    v_new := left(v_new, v_pos - 1) || v_apply || substr(v_new, v_pos);

    IF v_enc THEN
        EXECUTE 'UPDATE rootcause.detection_steps SET content = rootcause.enc(jsonb_build_object(''sql'', $1)) '
                'WHERE vendor_slug=''sqlserver'' AND name=$2' USING v_new, v_name;
    ELSE
        UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', v_new)
         WHERE vendor_slug='sqlserver' AND name=v_name;
    END IF;

    -- read back through the same path and assert both properties
    IF v_enc THEN
        EXECUTE 'SELECT rootcause.dec(content)->>''sql'' FROM rootcause.detection_steps '
                'WHERE vendor_slug=''sqlserver'' AND name=$1' INTO v_sql USING v_name;
    ELSE
        SELECT content->>'sql' INTO v_sql FROM rootcause.detection_steps
         WHERE vendor_slug='sqlserver' AND name=v_name;
    END IF;

    IF position('sys.sysprocesses' in v_sql) = 0 OR position(v_old_expr in v_sql) > 0 THEN
        RAISE EXCEPTION '7490: verification FAILED - stored SQL is not the 2008-safe version';
    END IF;

    RAISE NOTICE '7490: patched in place (storage=%); wrapper//customisation preserved: %',
                 CASE WHEN v_enc THEN 'encrypted' ELSE 'plaintext' END,
                 CASE WHEN position('execution_plan_xml' in v_sql) > 0
                      THEN '7350 wrapper still present' ELSE 'no 7350 wrapper on this install' END;
END $mig$;

-- -----------------------------------------------------------------------------
-- VERIFY (encrypted install; needs a key-bearing session)
--   SELECT rootcause.is_encrypted(content)                             AS ciphertext,     -- t
--          rootcause.dec(content)->>'sql' LIKE '%sysprocesses%'         AS fixed,          -- t
--          rootcause.dec(content)->>'sql' LIKE '%s.database\_id%' ESCAPE '\' AS old_column, -- f
--          rootcause.dec(content)->>'sql' LIKE '%execution_plan_xml%'   AS wrapper_intact  -- t where 7350 applied
--     FROM rootcause.detection_steps
--    WHERE vendor_slug='sqlserver' AND name='Detect SEC-SQL-ACC-011-RC02 (sqlserver)';
-- -----------------------------------------------------------------------------
