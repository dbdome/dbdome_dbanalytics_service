-- =============================================================================
-- 7430_untrack_sensitive_columns.sql
--
-- Let an operator mark a column as INSENSITIVE (a blacklist / "untrack"), so a
-- column that auto-discovery keeps classifying as sensitive - ip_address is the
-- canonical example - stops producing alerts.
--
-- Two effects, deliberately layered:
--
--   1. PREVENTION. metrics.v_sensitive_columns_all drops untracked columns, so
--      the RC15 sensitive-list injection never ships them to the target and the
--      detection cannot match them in the first place. This is the cheap path
--      and it needs no query parsing at all.
--
--   2. SUPPRESSION. A BEFORE INSERT trigger on alerts.alert_log checks the
--      alert's own captured query text for blacklisted column names and skips
--      the INSERT. This is the belt-and-braces layer, and it exists for the same
--      reason 7290 does: alert_log is written from >10 paths (every vendor
--      collector + app_login_guard + ransomware_guard + sensitive-access and
--      anomaly analysis), and the dedicated collectors have historically
--      bypassed collector-side filters. The single table every alert must pass
--      through is the only place an exclusion can actually be guaranteed.
--
-- The check is done ON THE QUERY TEXT already stored in the alert - no query is
-- issued against the target, and no sensitive column data is read.
--
-- Idempotent.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. untrack flag
-- -----------------------------------------------------------------------------
ALTER TABLE metrics.sensitive_columns
    ADD COLUMN IF NOT EXISTS untrack boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN metrics.sensitive_columns.untrack IS
  'true = blacklisted / insensitive. Excluded from v_sensitive_columns_all and suppresses alerts whose query text references it.';

CREATE INDEX IF NOT EXISTS ix_sensitive_columns_untrack
    ON metrics.sensitive_columns (lower(column_name)) WHERE untrack;

-- -----------------------------------------------------------------------------
-- 2. add_sensitive_column gains p_untrack.
--    The old 6-arg procedure is dropped first: keeping it alongside a 7-arg
--    version with a DEFAULT would make every existing 6-arg CALL ambiguous
--    (42725 procedure is not unique). Dropping it means existing callers -
--    http_server's /sensitive_column_add - keep working unchanged and simply
--    get untrack = false.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS metrics.add_sensitive_column(text, text, text, text, text, text);

CREATE OR REPLACE PROCEDURE metrics.add_sensitive_column(
    p_server text,
    p_db     text,
    p_schema text,
    p_table  text,
    p_column text,
    p_pii    text,
    p_untrack boolean DEFAULT false)
LANGUAGE plpgsql AS $$
BEGIN
    IF p_column IS NULL OR p_column = '' THEN
        RAISE EXCEPTION 'add_sensitive_column: column_name is required';
    END IF;
    -- table_name is required to TRACK (it identifies the object being watched)
    -- but optional to BLACKLIST, where NULL scope means "this column name
    -- anywhere".
    IF NOT COALESCE(p_untrack, false) AND (p_table IS NULL OR p_table = '') THEN
        RAISE EXCEPTION 'add_sensitive_column: table_name is required when tracking';
    END IF;

    -- Deliberately NOT using ON CONFLICT: the unique index treats NULLs as
    -- distinct, so a wildcard blacklist row (NULL server/db/schema/table) would
    -- never conflict and every call would append a duplicate. IS NOT DISTINCT
    -- FROM gives NULL-safe upsert semantics.
    UPDATE metrics.sensitive_columns
       SET pii_category = p_pii,
           untrack      = COALESCE(p_untrack, false),
           entry_date   = now()
     WHERE server       IS NOT DISTINCT FROM p_server
       AND db_name      IS NOT DISTINCT FROM p_db
       AND schema_name  IS NOT DISTINCT FROM p_schema
       AND table_name   IS NOT DISTINCT FROM p_table
       AND lower(column_name) = lower(p_column);

    IF NOT FOUND THEN
        INSERT INTO metrics.sensitive_columns
               (server, db_name, schema_name, table_name, column_name, pii_category, untrack)
        VALUES (p_server, p_db, p_schema, p_table, p_column, p_pii, COALESCE(p_untrack, false));
    END IF;
END $$;

COMMENT ON PROCEDURE metrics.add_sensitive_column(text,text,text,text,text,text,boolean) IS
  'Track (p_untrack=false) or blacklist (p_untrack=true) a column. Blacklisted = insensitive: never injected into detections, and alerts quoting it are suppressed.';

-- convenience wrapper for the "untrack" UI action
CREATE OR REPLACE PROCEDURE metrics.untrack_sensitive_column(
    p_server text, p_db text, p_schema text, p_table text, p_column text)
LANGUAGE plpgsql AS $$
BEGIN
    CALL metrics.add_sensitive_column(p_server, p_db, p_schema, p_table, p_column,
                                      'Blacklisted (insensitive)', true);
END $$;

-- -----------------------------------------------------------------------------
-- 3. The blacklist itself.
--    NULL scope columns act as wildcards: a row with server/db/schema/table NULL
--    and column_name 'ip_address' blacklists that column name everywhere.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW metrics.v_untracked_columns AS
SELECT server, db_name, schema_name, table_name, column_name, pii_category, entry_date
FROM metrics.sensitive_columns
WHERE untrack;

COMMENT ON VIEW metrics.v_untracked_columns IS
  'Blacklisted (insensitive) columns. NULL server/db/schema/table = wildcard.';

-- -----------------------------------------------------------------------------
-- 4. v_sensitive_columns_all now excludes blacklisted columns - including the
--    auto-discovered half, so re-discovery cannot resurrect them.
--    (Rebuilt in full from 6150; the WHERE NOT EXISTS is the only change.)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW metrics.v_sensitive_columns_all AS
SELECT u.server, u.db_name, u.schema_name, u.table_name, u.column_name, u.pii_category
FROM (
    SELECT server, db_name, schema_name, table_name, column_name, pii_category
    FROM metrics.sensitive_columns
    WHERE NOT untrack
    UNION
    SELECT server,
           database_name AS db_name,
           table_schema  AS schema_name,
           table_name,
           column_name,
           CASE
             WHEN lower(column_name) ~ '(password|pass)'   THEN 'Password'
             WHEN lower(column_name) ~ '(secret|token|key)' THEN 'Credential'
             WHEN lower(column_name) ~ '(credit|card)'     THEN 'Credit Card'
             WHEN lower(column_name) ~ 'ssn'               THEN 'SSN'
             WHEN lower(column_name) ~ 'email'             THEN 'Email'
             WHEN lower(column_name) ~ 'phone'             THEN 'Phone'
             WHEN lower(column_name) ~ 'address'           THEN 'Address'
             WHEN lower(column_name) ~ '(dob|birth)'       THEN 'Date of Birth'
             WHEN lower(column_name) ~ 'salary'            THEN 'Salary'
             WHEN lower(column_name) ~ 'passport'          THEN 'Passport'
             WHEN lower(column_name) ~ '(medical|diagnosis)' THEN 'Medical'
             WHEN lower(column_name) ~ 'teudat'            THEN 'Teudat Zehut'
             ELSE 'Other Sensitive'
           END AS pii_category
    FROM monitoring.sensitive_schema
) u
WHERE u.table_name IS NOT NULL
  AND u.column_name IS NOT NULL
  -- drop anything blacklisted, matching on column name with NULL-as-wildcard scope
  AND NOT EXISTS (
        SELECT 1
        FROM metrics.sensitive_columns b
        WHERE b.untrack
          AND lower(b.column_name) = lower(u.column_name)
          AND (b.server      IS NULL OR b.server      = u.server)
          AND (b.db_name     IS NULL OR b.db_name     = u.db_name)
          AND (b.schema_name IS NULL OR b.schema_name = u.schema_name)
          AND (b.table_name  IS NULL OR b.table_name  = u.table_name)
  );

-- -----------------------------------------------------------------------------
-- 5. Does a piece of query text reference a blacklisted column?
--    Word-boundary match so 'ip_address' does not fire on 'chip_addressing',
--    and [] / "" / `` quoting is tolerated.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION metrics.fn_query_hits_blacklist(p_server text, p_query text)
RETURNS boolean
LANGUAGE sql STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM metrics.sensitive_columns b
        WHERE b.untrack
          AND (b.server IS NULL OR b.server = p_server)
          AND p_query IS NOT NULL
          AND p_query ~* ('(^|[^a-z0-9_])' || regexp_replace(b.column_name, '([^a-z0-9_])', '\\\1', 'gi') || '([^a-z0-9_]|$)')
    );
$$;

-- Does the text reference a sensitive column that is NOT blacklisted?
CREATE OR REPLACE FUNCTION metrics.fn_query_hits_tracked_sensitive(p_server text, p_query text)
RETURNS boolean
LANGUAGE sql STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM metrics.v_sensitive_columns_all s
        WHERE (s.server IS NULL OR s.server = p_server)
          AND p_query IS NOT NULL
          AND p_query ~* ('(^|[^a-z0-9_])' || regexp_replace(s.column_name, '([^a-z0-9_])', '\\\1', 'gi') || '([^a-z0-9_]|$)')
    );
$$;

-- -----------------------------------------------------------------------------
-- 6. Central suppression, same shape as 7290.
--
--    SAFETY DECISION: an alert is skipped only when its query text references a
--    blacklisted column AND references NO still-tracked sensitive column.
--    Suppressing on "contains a blacklisted column" alone would mean
--    blacklisting ip_address silences a
--        SELECT ip_address, ssn FROM customers
--    exfiltration alert - one benign column would become a way to hide every
--    sensitive one. Set config.global_params 'blacklist_suppress_strict' = 'true'
--    to get that literal behaviour instead; it defaults to the safe reading.
-- -----------------------------------------------------------------------------
INSERT INTO config.global_params (key, value)
SELECT 'blacklist_suppress_strict', 'false'
WHERE NOT EXISTS (SELECT 1 FROM config.global_params WHERE key = 'blacklist_suppress_strict');

CREATE OR REPLACE FUNCTION alerts.fn_skip_blacklisted_column_alerts()
RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_text   text;
    v_strict boolean;
BEGIN
    -- nothing blacklisted -> nothing to do (cheap short-circuit for the common case)
    IF NOT EXISTS (SELECT 1 FROM metrics.sensitive_columns WHERE untrack) THEN
        RETURN NEW;
    END IF;

    -- the alert's own captured query text: metadata rows (query_text, statement,
    -- current_statement, ...) plus the diagnostic metric_query. No target access.
    v_text := coalesce(NEW.metadata::text, '') || ' ' || coalesce(NEW.metric_query::text, '');

    IF NOT metrics.fn_query_hits_blacklist(NEW.server, v_text) THEN
        RETURN NEW;                       -- no blacklisted column mentioned
    END IF;

    v_strict := coalesce((SELECT value FROM config.global_params
                          WHERE key = 'blacklist_suppress_strict'), 'false')::boolean;

    IF v_strict THEN
        RETURN NULL;                      -- literal: any blacklisted column -> skip
    END IF;

    -- safe default: skip only if nothing still-sensitive is also referenced
    IF metrics.fn_query_hits_tracked_sensitive(NEW.server, v_text) THEN
        RETURN NEW;                       -- real sensitive column present -> keep alerting
    END IF;

    RETURN NULL;                          -- blacklisted only -> skip (no alert, no incident)
END;
$$;

DROP TRIGGER IF EXISTS trg_01_skip_blacklisted_column_alerts ON alerts.alert_log;

-- Sorts after trg_00_skip_excluded_login_alerts (7290) and before the fill
-- triggers, so a login exclusion still wins and skipped rows do no further work.
CREATE TRIGGER trg_01_skip_blacklisted_column_alerts
    BEFORE INSERT ON alerts.alert_log
    FOR EACH ROW
    EXECUTE FUNCTION alerts.fn_skip_blacklisted_column_alerts();

-- -----------------------------------------------------------------------------
-- USAGE
--   -- blacklist ip_address everywhere (NULL scope = wildcard):
--   CALL metrics.add_sensitive_column(NULL,NULL,NULL,NULL,'ip_address','Blacklisted (insensitive)',true);
--   -- or scoped to one table:
--   CALL metrics.untrack_sensitive_column('192.168.1.229','CRM','dbo','customers','ip_address');
--   -- back to tracked:
--   CALL metrics.add_sensitive_column('192.168.1.229','CRM','dbo','customers','ip_address','Address',false);
--   -- see the blacklist:
--   SELECT * FROM metrics.v_untracked_columns;
-- -----------------------------------------------------------------------------
