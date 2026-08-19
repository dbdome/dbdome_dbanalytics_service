-- =============================================================================
-- 7550_acc011_rc02_view_server_state_guard.sql
-- Stop SEC-SQL-ACC-011-RC02 (sqlserver) from hard-failing on targets where the
-- monitoring login has no VIEW SERVER STATE.
--
-- SYMPTOM
--   Every sweep logs
--     Metric 'SEC-SQL-ACC-011-RC02' failed: (pyodbc.ProgrammingError) ('42000',
--     "...VIEW SERVER STATE permission was denied on object 'server',
--      database 'master'. (300) ... (297)")
--   and NOTHING is written to gmmr - so the root cause looks "never collected"
--   rather than "cannot collect". Measured on 192.168.1.222 / eladsap_prod
--   (192.168.200.50): 175 failures in 7 days, ~1 per sweep, zero gmmr rows in 90.
--
-- CAUSE
--   The step reads server-scoped DMVs. Without VIEW SERVER STATE SQL Server
--   splits them into two behaviours, and BOTH are wrong for us:
--     * dm_exec_sessions / dm_exec_requests / sys.sysprocesses -> silently
--       restricted to the CALLER'S OWN session (no error)
--     * dm_exec_sql_text / dm_exec_connections / dm_exec_query_stats /
--       dm_tran_active_transactions -> hard error 300/297
--   The hard error is what kills the batch.
--
-- WHAT THIS FIX DOES - AND DOES NOT DO
--   It CANNOT restore the data. Cross-session visibility IS the permission;
--   no query shape substitutes for it. The real fix is, on the TARGET instance:
--       USE master; GRANT VIEW SERVER STATE TO [<dbdome monitoring login>];
--   What it does do is make the step degrade instead of erupting: the query is
--   wrapped in a HAS_PERMS_BY_NAME guard, so a target without the grant returns
--   an EMPTY result set of the same shape instead of raising.
--
-- WHY THE FALLBACK RETURNS NO ROWS (deliberate - do not "improve" this)
--   The obvious nicety is to return one diagnostic row saying "permission
--   missing". Do not. This step's expected.condition is `row_count > 0` and its
--   on_match_action is `confirmed`, so ANY row returned raises a CONFIRMED
--   finding for "Active transactions (excluding monitoring user)" - i.e. the
--   product would assert active transactions exist on a server it cannot see.
--   A false confirmed finding is worse than an empty one. Zero rows -> the step
--   rules out cleanly.
--   Consequence to accept: with this applied the missing grant is no longer
--   loud. It stops appearing in log.operation_log. Track the grant separately.
--
-- WHY THE BATCH STARTS WITH `IF` AND NOT `SET NOCOUNT ON`
--   The collector runs pd.read_sql_query(text(sql)) (see
--   collection/mssql/monitoring_metrics_mssql_generic_query.py) and pandas reads
--   the FIRST result set only - it never calls nextset(). Leading with a
--   non-rowset statement risks "Previous SQL was not a query". Starting at the
--   IF keeps the SELECT's rowset first. Same "rowset must be first" constraint
--   the dynamic-UNION steps live under.
--
-- SURGICAL, per the lesson recorded in 7490: read the CURRENT sql, WRAP it, and
-- write it back. Never substitute a known-good copy - that silently reverted
-- 7350's execution_plan_xml wrapper on 213 once already.
--
-- ENCRYPTION: same contract as 7490. Where 7300 is applied, content is a jsonb
-- string holding an armored PGP blob; read via rootcause.dec(), write via
-- rootcause.enc(), key in GUC rootcause.k. Reached through EXECUTE so this still
-- PARSES where those functions do not exist. Refuses to write plaintext over
-- ciphertext when the session has no key.
--
-- Idempotent: a step already carrying the guard is left untouched.
-- =============================================================================

DO $mig$
DECLARE
    v_name   constant text := 'Detect SEC-SQL-ACC-011-RC02 (sqlserver)';
    v_marker constant text := 'HAS_PERMS_BY_NAME';
    v_prefix constant text :=
$q$IF HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW SERVER STATE') = 1
BEGIN
$q$;
    -- Empty result set, same 24 columns / same order / same types as the guarded
    -- query's outer SELECT, so every downstream consumer keeps its shape.
    v_suffix constant text :=
$q$
END
ELSE
BEGIN
    SELECT
        CAST(NULL AS SMALLINT)      AS session_id,
        CAST(NULL AS NVARCHAR(60))  AS status,
        CAST(NULL AS NVARCHAR(60))  AS activity,
        CAST(NULL AS NVARCHAR(128)) AS login_name,
        CAST(NULL AS NVARCHAR(128)) AS host_name,
        CAST(NULL AS NVARCHAR(128)) AS program_name,
        CAST(NULL AS NVARCHAR(128)) AS database_name,
        CAST(NULL AS NVARCHAR(32))  AS command,
        CAST(NULL AS NVARCHAR(60))  AS wait_type,
        CAST(NULL AS INT)           AS wait_time,
        CAST(NULL AS SMALLINT)      AS blocking_session_id,
        CAST(NULL AS BIGINT)        AS cpu_ms,
        CAST(NULL AS BIGINT)        AS elapsed_ms,
        CAST(NULL AS BIGINT)        AS reads,
        CAST(NULL AS BIGINT)        AS writes,
        CAST(NULL AS BIGINT)        AS logical_reads,
        CAST(NULL AS REAL)          AS percent_complete,
        CAST(NULL AS INT)           AS open_tran_count,
        CAST(NULL AS DATETIME)      AS tran_begin_time,
        CAST(NULL AS DATETIME)      AS request_start_time,
        CAST(NULL AS DATETIME)      AS last_request_start_time,
        CAST(NULL AS DATETIME)      AS last_request_end_time,
        CAST(NULL AS DATETIME)      AS login_time,
        CAST(NULL AS NVARCHAR(MAX)) AS sql_text
    WHERE 1 = 0;
END;
$q$;
    v_enc    boolean := to_regprocedure('rootcause.enc(jsonb)') IS NOT NULL;
    v_haskey boolean := nullif(current_setting('rootcause.k', true), '') IS NOT NULL;
    v_sql    text;
    v_new    text;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM rootcause.detection_steps
                    WHERE vendor_slug='sqlserver' AND name=v_name) THEN
        RAISE NOTICE '7550: step "%" not present - nothing to do', v_name;
        RETURN;
    END IF;

    IF v_enc AND NOT v_haskey THEN
        RAISE EXCEPTION
            '7550: this install encrypts detection_steps (7300 applied) but the session has no key. '
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
        RAISE EXCEPTION '7550: could not read the current SQL (wrong key, or content has no sql). Aborting.';
    END IF;

    IF position(v_marker in v_sql) > 0 THEN
        RAISE NOTICE '7550: guard already present - no change';
        RETURN;
    END IF;

    -- Sanity: this must still look like the step we think it is, or a previous
    -- migration has moved the ground under us and a blind wrap would be wrong.
    IF position('sys.dm_exec_sessions' in v_sql) = 0 THEN
        RAISE EXCEPTION '7550: live SQL does not reference sys.dm_exec_sessions - '
                        'it has diverged; review by hand rather than letting this script guess.';
    END IF;

    -- Wrap, preserving the existing body byte-for-byte (7350 wrapper, 7490
    -- sysprocesses APPLY, and any local drift all ride along untouched).
    -- Trailing ';' would close the batch before END, so drop it if present.
    v_new := v_prefix || rtrim(rtrim(btrim(v_sql), ';')) || v_suffix;

    IF v_enc THEN
        EXECUTE 'UPDATE rootcause.detection_steps SET content = rootcause.enc(jsonb_build_object(''sql'', $1)) '
                'WHERE vendor_slug=''sqlserver'' AND name=$2' USING v_new, v_name;
    ELSE
        UPDATE rootcause.detection_steps SET content = jsonb_build_object('sql', v_new)
         WHERE vendor_slug='sqlserver' AND name=v_name;
    END IF;

    -- read back through the same path and assert the guard AND the body survived
    IF v_enc THEN
        EXECUTE 'SELECT rootcause.dec(content)->>''sql'' FROM rootcause.detection_steps '
                'WHERE vendor_slug=''sqlserver'' AND name=$1' INTO v_sql USING v_name;
    ELSE
        SELECT content->>'sql' INTO v_sql FROM rootcause.detection_steps
         WHERE vendor_slug='sqlserver' AND name=v_name;
    END IF;

    IF position(v_marker in v_sql) = 0
       OR position('sys.dm_exec_sessions' in v_sql) = 0
       OR position('sys.dm_exec_query_stats' in v_sql) = 0 THEN
        RAISE EXCEPTION '7550: verification FAILED - stored SQL is not the guarded version';
    END IF;

    RAISE NOTICE '7550: guarded in place (storage=%); %',
                 CASE WHEN v_enc THEN 'encrypted' ELSE 'plaintext' END,
                 CASE WHEN position('execution_plan_xml' in v_sql) > 0
                      THEN '7350 wrapper still present' ELSE 'no 7350 wrapper on this install' END;
END $mig$;
