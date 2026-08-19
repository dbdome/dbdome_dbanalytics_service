-- =============================================================================
-- 7500_ransomware_guard_login_authorization_gate.sql
--
-- Let metrics.login_authorizations suppress ransomware-guard findings for a login
-- that is explicitly authorised to run the statement in question:
--   SEC-SQL-AUD-031-RC03  ransom-note artifacts
--   SEC-SQL-AUD-031-RC04  bulk export -> mass delete (double extortion)
--   SEC-SQL-AUD-031-RC05  system command / OLE automation
-- RC01 (mass encryption) and RC02 (modification velocity) are deliberately NOT
-- gated, and SEC-SQL-ACC-011-RC02 is exempt entirely - it is the collector feed
-- every one of these reads, so gating it would starve the detections of input.
--
-- WHY A NEW FUNCTION AND NOT metrics.is_login_authorized()
--   That function answers "is this login RESTRICTED from doing this?" and returns
--   TRUE when no rule matches - "unrestricted, nothing to judge" (7470, lines
--   115-117). That is right for SEC-SQL-AUD-011-RC06, whose view SHOWS the
--   unauthorised statements. It is exactly wrong as a suppression gate: using it
--   here would mean every login WITHOUT a rule is "authorised", so the ransomware
--   guard would fall silent for the entire estate the moment this shipped - the
--   opposite of the intent, and silently.
--
--   This function answers the other question: "is this login EXPLICITLY authorised
--   for this statement?" It returns TRUE only when an active white rule matches the
--   login AND the server AND ticks that operation. No rule => FALSE => still alerts.
--
-- STRICT ON ANYTHING IT CANNOT CLASSIFY (product decision)
--   monitoring.sql_command_verb() only recognises select/insert/update/delete/
--   drop/truncate. Anything else - EXEC xp_cmdshell, sp_OACreate, bcp, BULK INSERT,
--   OPENROWSET(BULK ...) - yields NULL and this returns FALSE, so it keeps alerting
--   even for a login with all six operations ticked. An allow-list must not be able
--   to wave through a ransomware delivery path.
--
--   Known edge, called out rather than hidden: `SELECT ... INTO` and `SELECT *`
--   bulk exports DO parse as verb 'select', so a login with op_select ticked can
--   suppress an RC04 row whose statement is a SELECT-based export. Only the
--   EXEC/bcp/OPENROWSET forms are unconditionally kept. If SELECT-based export
--   should also be non-waivable, that needs an op_bulk_export column rather than a
--   verb test - deliberately not done here.
--
-- Black rules still win: an explicit deny is never waived.
-- Idempotent.
-- =============================================================================

CREATE OR REPLACE FUNCTION metrics.is_statement_explicitly_authorized(
        p_login   text,
        p_server  text,
        p_sql     text)
    RETURNS boolean
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_cmd text;
BEGIN
    IF p_login IS NULL OR btrim(coalesce(p_login, '')) = '' THEN
        RETURN false;                      -- no login to authorise -> keep the alert
    END IF;

    v_cmd := monitoring.sql_command_verb(p_sql);
    IF v_cmd IS NULL THEN
        RETURN false;                      -- unclassifiable (EXEC/bcp/OPENROWSET) -> keep the alert
    END IF;

    -- Explicit deny wins outright.
    IF EXISTS (
        SELECT 1 FROM metrics.login_authorizations a
        WHERE a.is_active AND a.mode = 'black'
          AND p_login ILIKE a.login_name
          AND (a.server IN ('%', '') OR coalesce(p_server, '') ILIKE a.server)
          AND CASE v_cmd
                WHEN 'select' THEN a.op_select WHEN 'insert' THEN a.op_insert
                WHEN 'update' THEN a.op_update WHEN 'delete' THEN a.op_delete
                WHEN 'drop'   THEN a.op_drop   WHEN 'truncate' THEN a.op_truncate
                ELSE false END
    ) THEN
        RETURN false;
    END IF;

    -- Suppress ONLY on a positive, active white rule for this exact operation.
    RETURN EXISTS (
        SELECT 1 FROM metrics.login_authorizations a
        WHERE a.is_active AND a.mode = 'white'
          AND p_login ILIKE a.login_name
          AND (a.server IN ('%', '') OR coalesce(p_server, '') ILIKE a.server)
          AND CASE v_cmd
                WHEN 'select' THEN a.op_select WHEN 'insert' THEN a.op_insert
                WHEN 'update' THEN a.op_update WHEN 'delete' THEN a.op_delete
                WHEN 'drop'   THEN a.op_drop   WHEN 'truncate' THEN a.op_truncate
                ELSE false END
    );
END;
$$;

COMMENT ON FUNCTION metrics.is_statement_explicitly_authorized(text, text, text) IS
  'TRUE only when an ACTIVE white rule in metrics.login_authorizations matches the login and server and ticks the statement''s verb. Unlike metrics.is_login_authorized(), a login with no rule returns FALSE - so it is safe to use as a suppression gate (ransomware_guard RC03/RC04/RC05). Statements whose verb is not one of the six modelled operations (EXEC/bcp/OPENROWSET/...) always return FALSE. Black rules always return FALSE.';

-- Ownership / grants, mirroring 7470 (only when the hardened roles exist).
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_adm') THEN
        EXECUTE 'ALTER FUNCTION metrics.is_statement_explicitly_authorized(text, text, text) OWNER TO dbdome_adm';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_grafana_ro') THEN
        EXECUTE 'GRANT EXECUTE ON FUNCTION metrics.is_statement_explicitly_authorized(text, text, text) TO dbdome_grafana_ro';
    END IF;
END $$;

-- -----------------------------------------------------------------------------
-- VERIFY (expect, for a login with a white rule ticking only op_select):
--   'select 1'                      -> true   (ticked)
--   'delete from t'                 -> false  (not ticked)
--   'exec xp_cmdshell ''dir'''      -> false  (unclassifiable verb)
--   same statements, login with NO rule at all -> false for every one
--
--   SELECT metrics.is_statement_explicitly_authorized('sapsa','<server>', s)
--   FROM unnest(ARRAY['select 1','delete from t','exec xp_cmdshell ''dir''']) s;
-- -----------------------------------------------------------------------------
