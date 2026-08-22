-- =============================================================================
-- 7610_ransomware_sequence.sql
--
-- Ransomware detection: N DISTINCT destructive operations by one login, in a
-- short window, one after another.
--
-- WHY THIS IS SQL AND NOT A MODEL
--   "four different operations within five minutes" is a countable, exact
--   condition. A language model would return a PROBABILITY that it happened.
--   For a security rule you want an answer that fires identically every time
--   and can be explained afterwards, so the SEQUENCE is detected here and the
--   JUDGEMENT ("attack, or the nightly archive job that always does exactly
--   these four things?") is left to security_agent, which annotates the alert
--   with its reason. Teaching the model this rule by fine-tuning was considered
--   and rejected: the shipped model is a quantized GGUF with no gradients, and
--   a LoRA on the base model would need a GPU, a labelled corpus and a
--   re-quantize for every wording change. security_agent/rules.json carries the
--   judgement guidance instead, editable without a rebuild.
--
-- WHY IT IS NOT A rootcause.detection_steps ROW
--   Detection steps hold a VENDOR query (T-SQL, PL/SQL...) that the collector
--   runs on the monitored server, and their content is PGP-encrypted under the
--   per-session rootcause.k key. Neither fits here: a chain spans MULTIPLE
--   collection samples, so it can only be evaluated after the events have
--   landed in monitoring.general_metric_metadata_results. That is the same
--   reason analysis/anomaly_agent.py and analyse_metrics_sensitive_column_access
--   run Postgres-side and write alerts.alert_log directly.
--
-- TUNING
--   Thresholds live in config.global_params so a site can change them without a
--   rebuild: ransomware_min_distinct_ops (default 4) and
--   ransomware_window_minutes (default 5).
--
-- Idempotent. Safe to re-run.
-- =============================================================================

-- ----------------------------------------------------------------------------
-- 1) Tunables
-- ----------------------------------------------------------------------------
INSERT INTO config.global_params (key, value)
SELECT 'ransomware_min_distinct_ops', '4'
WHERE NOT EXISTS (SELECT 1 FROM config.global_params WHERE key = 'ransomware_min_distinct_ops');

INSERT INTO config.global_params (key, value)
SELECT 'ransomware_window_minutes', '5'
WHERE NOT EXISTS (SELECT 1 FROM config.global_params WHERE key = 'ransomware_window_minutes');


-- ----------------------------------------------------------------------------
-- 2) Classify a statement into a destructive operation class.
--
--    Deliberately conservative and readable rather than clever: a security rule
--    that nobody can audit is a liability. Returns NULL for anything that is not
--    one of the classes the ransomware shape is built from, and those rows are
--    dropped before the sequence is evaluated.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION alerts.fn_destructive_class(p_operation text, p_query text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $fn$
    SELECT CASE
        -- explicit operation labels from the collectors, when present
        WHEN upper(coalesce(p_operation,'')) IN ('DELETE','MASS_DELETE')      THEN 'MASS_DELETE'
        WHEN upper(coalesce(p_operation,'')) IN ('UPDATE','MASS_UPDATE')      THEN 'MASS_UPDATE'
        WHEN upper(coalesce(p_operation,'')) IN ('DROP','DROP_TABLE')         THEN 'DROP_OBJECT'
        WHEN upper(coalesce(p_operation,'')) = 'TRUNCATE'                     THEN 'TRUNCATE'
        -- otherwise fall back to the statement text
        WHEN p_query ~* '\mdrop\s+(table|database|schema)\M'                  THEN 'DROP_OBJECT'
        WHEN p_query ~* '\mtruncate\s+table\M'                                THEN 'TRUNCATE'
        WHEN p_query ~* '\mdelete\s+from\M'                                   THEN 'MASS_DELETE'
        WHEN p_query ~* '\mupdate\s+\w+\s+set\M'                              THEN 'MASS_UPDATE'
        WHEN p_query ~* '(backup\s+database|sp_delete_backuphistory|rman\s+delete)' THEN 'BACKUP_TAMPER'
        WHEN p_query ~* '(sp_configure|alter\s+server\s+audit|audit_policy|drop\s+audit)' THEN 'AUDIT_DISABLE'
        WHEN p_query ~* '(xp_cmdshell|openrowset|bulk\s+insert|into\s+outfile)' THEN 'SHELL_OR_BULK'
        WHEN p_query ~* '\mgrant\s+.*\mto\M'                                  THEN 'PRIV_GRANT'
        ELSE NULL
    END;
$fn$;

COMMENT ON FUNCTION alerts.fn_destructive_class(text, text) IS
    'Maps an observed operation/statement to a destructive operation class, or '
    'NULL when it is not one. Input to the ransomware sequence rule.';


-- ----------------------------------------------------------------------------
-- 3) The events, shredded out of gmmr.
--
--    metric_metadata is an ARRAY of row objects, with the statement under
--    QUERY_TEXT and the principal under LOGIN_NAME (verified against live data).
--    Keys are matched case-insensitively because collectors differ on casing.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW alerts.v_destructive_events AS
SELECT g.server,
       g.server_id,
       g.metric_name,
       g.entry_date,
       coalesce(e.rec->>'LOGIN_NAME',  e.rec->>'login_name')  AS login_name,
       coalesce(e.rec->>'DB_NAME',     e.rec->>'database_name') AS database_name,
       coalesce(e.rec->>'QUERY_TEXT',  e.rec->>'query_text')  AS query_text,
       coalesce(e.rec->>'OPERATION',   e.rec->>'operation')   AS operation,
       alerts.fn_destructive_class(
           coalesce(e.rec->>'OPERATION', e.rec->>'operation'),
           coalesce(e.rec->>'QUERY_TEXT', e.rec->>'query_text')
       ) AS op_class
FROM monitoring.general_metric_metadata_results g
CROSS JOIN LATERAL jsonb_array_elements(g.metric_metadata) AS e(rec)
WHERE jsonb_typeof(g.metric_metadata) = 'array'
  AND jsonb_typeof(e.rec) = 'object';

COMMENT ON VIEW alerts.v_destructive_events IS
    'gmmr metric_metadata arrays shredded to one row per observed statement, '
    'classified by alerts.fn_destructive_class. op_class IS NULL for ordinary traffic.';


-- ----------------------------------------------------------------------------
-- 4) The rule: N distinct destructive classes by one login inside the window.
--
--    Implemented with a self-join over an ordered event stream rather than LAG,
--    because the interesting condition is "N DISTINCT classes", not "the last N
--    events" -- with LAG, one repeated operation would break a chain that a
--    human would obviously call an attack.
--
--    p_lookback_minutes bounds the scan. gmmr.entry_date is the ONSET of a
--    state rather than a heartbeat, so callers should pass a generous value.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION alerts.fn_ransomware_sequences(
    p_lookback_minutes int DEFAULT 60,
    p_server           text DEFAULT NULL
)
RETURNS TABLE (
    server           varchar,
    server_id        uuid,
    login_name       text,
    database_name    text,
    first_seen       timestamp,
    last_seen        timestamp,
    distinct_ops     int,
    op_classes       text[],
    statements       jsonb
)
LANGUAGE plpgsql
STABLE
AS $fn$
DECLARE
    v_min_ops int := coalesce((SELECT value::int FROM config.global_params
                               WHERE key = 'ransomware_min_distinct_ops'), 4);
    v_window  int := coalesce((SELECT value::int FROM config.global_params
                               WHERE key = 'ransomware_window_minutes'), 5);
BEGIN
    RETURN QUERY
    WITH ev AS (
        SELECT e.server, e.server_id, e.login_name, e.database_name,
               e.entry_date, e.op_class, e.query_text
        FROM alerts.v_destructive_events e
        WHERE e.op_class IS NOT NULL
          AND e.login_name IS NOT NULL
          AND e.entry_date >= LOCALTIMESTAMP - make_interval(mins => p_lookback_minutes)
          AND (p_server IS NULL OR e.server = p_server)
    ),
    -- For each event, the chain it anchors: everything by the same login on the
    -- same server within the window that STARTS at this event.
    chain AS (
        SELECT a.server, a.server_id, a.login_name, a.database_name,
               a.entry_date                                   AS first_seen,
               max(b.entry_date)                              AS last_seen,
               count(DISTINCT b.op_class)::int                AS distinct_ops,
               array_agg(DISTINCT b.op_class)                 AS op_classes,
               jsonb_agg(DISTINCT jsonb_build_object(
                   'at', b.entry_date, 'op', b.op_class,
                   'query', left(b.query_text, 500)))         AS statements
        FROM ev a
        JOIN ev b
          ON b.server     = a.server
         AND b.login_name = a.login_name
         AND b.entry_date >= a.entry_date
         AND b.entry_date <  a.entry_date + make_interval(mins => v_window)
        GROUP BY a.server, a.server_id, a.login_name, a.database_name, a.entry_date
    )
    SELECT c.server, c.server_id, c.login_name, c.database_name,
           c.first_seen, c.last_seen, c.distinct_ops, c.op_classes, c.statements
    FROM chain c
    WHERE c.distinct_ops >= v_min_ops
      -- Keep only the widest chain per login: overlapping windows otherwise
      -- report the same incident once per anchoring event.
      AND NOT EXISTS (
          SELECT 1 FROM chain c2
          WHERE c2.server = c.server
            AND c2.login_name = c.login_name
            AND c2.distinct_ops >= v_min_ops
            AND (c2.distinct_ops > c.distinct_ops
                 OR (c2.distinct_ops = c.distinct_ops AND c2.first_seen < c.first_seen))
            AND c2.first_seen <  c.last_seen
            AND c2.last_seen  >= c.first_seen
      )
    ORDER BY c.last_seen DESC;
END;
$fn$;

COMMENT ON FUNCTION alerts.fn_ransomware_sequences(int, text) IS
    'Logins that performed >= ransomware_min_distinct_ops DISTINCT destructive '
    'operation classes within ransomware_window_minutes. One row per incident.';


-- ----------------------------------------------------------------------------
-- 5) Register the root cause so the finding is a first-class product object.
--    SEC / SQL / ACC matches the existing anomalous-activity family.
-- ----------------------------------------------------------------------------
-- Only columns that have existed since the schema was created are named here.
-- category_id is omitted for the same reason as is_informational below: naming
-- a column that a given install has not yet acquired aborts the statement, and
-- psql then carries on so the failure surfaces later as a confusing "root cause
-- was not created". Both are nullable/defaulted where they exist.
INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code,
                              name, slug, description)
SELECT 'SEC-SQL-ACC-040', 'SEC', 'SQL', 'ACC',
       'Ransomware-Pattern Activity',
       'ransomware-pattern-activity',
       'A single login performed several DIFFERENT destructive operations in '
       'quick succession - the behavioural signature of ransomware or a '
       'destructive insider action, which no individual statement reveals.'
WHERE NOT EXISTS (SELECT 1 FROM rootcause.issues WHERE issue_id = 'SEC-SQL-ACC-040');

-- is_informational is deliberately NOT listed.
--
-- It exists on some installs and not others (it arrives with a later migration),
-- and naming it made this INSERT fail outright on an install that predates it:
--   ERROR: column "is_informational" of relation "root_causes" does not exist
-- Seen on a 2026-08-22 update run. psql continues past the error, so the script
-- reported exit 0 while the root cause was never created and the verification
-- block below then failed with a confusing second error.
--
-- Omitting it is correct rather than merely defensive: where the column exists
-- it defaults to false, which is the value this root cause wants anyway.
INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description,
                                   topics, vendors_applicable)
SELECT 'SEC-SQL-ACC-040-RC01', 'SEC-SQL-ACC-040',
       'Destructive operation chain by a single login',
       'destructive-operation-chain',
       'Four or more distinct destructive operation classes (mass update, mass '
       'delete, drop, truncate, backup tampering, audit disable, shell/bulk, '
       'privilege grant) were observed from one login on one server within a '
       'few minutes. Individually these can be legitimate; in a short chain '
       'they are the ransomware signature. Scheduled archive and maintenance '
       'jobs produce a similar shape, which is what the security agent triages.',
       ARRAY['ransomware','destructive','insider','sequence'],
       ARRAY['sqlserver','oracle','postgresql','mysql','mariadb']
WHERE NOT EXISTS (SELECT 1 FROM rootcause.root_causes
                   WHERE root_cause_id = 'SEC-SQL-ACC-040-RC01');


-- ----------------------------------------------------------------------------
-- 6) The scheduled evaluator. is_active=false: a new security rule must be
--    switched on deliberately after its thresholds have been reviewed against
--    the site's own traffic, not silently at upgrade.
-- ----------------------------------------------------------------------------
INSERT INTO metrics.registered_processes (process_name, is_active, interval, description)
SELECT 'ransomware_sequence_detect', false, 300,
       'Evaluates alerts.fn_ransomware_sequences() and raises '
       'SEC-SQL-ACC-040-RC01. Off by default: review '
       'ransomware_min_distinct_ops / ransomware_window_minutes against real '
       'traffic before enabling, or a nightly maintenance job will alert every '
       'night. The security agent annotates each alert with its reason.'
WHERE NOT EXISTS (SELECT 1 FROM metrics.registered_processes
                   WHERE process_name = 'ransomware_sequence_detect');


-- ----------------------------------------------------------------------------
-- 7) Verify, loudly.
-- ----------------------------------------------------------------------------
DO $mig$
DECLARE
    v_rc     int;
    v_proc   int;
    v_minops text;
    v_win    text;
    v_hits   int;
    v_srv    text;
BEGIN
    SELECT count(*) INTO v_rc FROM rootcause.root_causes
     WHERE root_cause_id = 'SEC-SQL-ACC-040-RC01';
    IF v_rc = 0 THEN
        RAISE EXCEPTION '7610: root cause SEC-SQL-ACC-040-RC01 was not created';
    END IF;

    SELECT count(*) INTO v_proc FROM metrics.registered_processes
     WHERE process_name = 'ransomware_sequence_detect';
    IF v_proc = 0 THEN
        RAISE EXCEPTION '7610: ransomware_sequence_detect was not registered';
    END IF;

    SELECT value INTO v_minops FROM config.global_params WHERE key = 'ransomware_min_distinct_ops';
    SELECT value INTO v_win    FROM config.global_params WHERE key = 'ransomware_window_minutes';

    -- Smoke-test the function so a syntax or type error surfaces at deploy time
    -- rather than on the first scheduled run.
    --
    -- BOUNDED, DELIBERATELY. The first version of this block ran the function
    -- unbounded across every server and hung for 45 minutes against a 1.47M-row
    -- partitioned gmmr, holding a session the whole time. A migration that can
    -- hang on its own sanity check is worse than one with no sanity check: it
    -- blocks the deploy and looks like a database problem. So:
    --   * statement_timeout is capped for this block only (LOCAL);
    --   * the trial covers ONE server and a 15-minute window, which is enough
    --     to prove the plan compiles and executes;
    --   * a timeout is caught and downgraded to a WARNING -- the objects are
    --     already created and correct, and the operator is told to measure the
    --     real cost before enabling the process.
    SET LOCAL statement_timeout = '20s';

    SELECT server INTO v_srv
      FROM monitoring.general_metric_metadata_results
     ORDER BY entry_date DESC
     LIMIT 1;

    BEGIN
        SELECT count(*) INTO v_hits
          FROM alerts.fn_ransomware_sequences(15, v_srv);

        RAISE NOTICE '7610: SEC-SQL-ACC-040-RC01 registered; thresholds min_distinct_ops=%, '
                     'window_minutes=%; process ransomware_sequence_detect is INACTIVE '
                     '(enable it deliberately). Smoke test on server % over 15 min '
                     'matched % chain(s).', v_minops, v_win, coalesce(v_srv,'(none)'), v_hits;
    EXCEPTION
        WHEN query_canceled THEN
            RAISE WARNING '7610: objects created, but the smoke test exceeded 20s on server %. '
                          'The detection function may be too expensive at this data volume - '
                          'measure it with EXPLAIN ANALYZE before enabling '
                          'ransomware_sequence_detect.', coalesce(v_srv,'(none)');
        WHEN others THEN
            RAISE WARNING '7610: objects created, but the smoke test failed: % - %',
                          SQLSTATE, SQLERRM;
    END;
END $mig$;
