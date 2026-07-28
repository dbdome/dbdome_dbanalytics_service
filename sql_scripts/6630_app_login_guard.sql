-- =============================================================================
-- 6630_app_login_guard.sql
--
-- "Applicative login used from a watched program" scenario.
--
-- 1) Two watchlist config tables:
--      metrics.app_logins (applicative_login, server)  -- service/app logins to watch
--      metrics.programs   (program_name,      server)  -- programs to watch
--    Both match case-insensitively via SQL LIKE (entries may be exact or wildcards
--    like '%SSMS%'); an empty/NULL server (or '%') means "all servers".
--
-- 2) New root cause SEC-SQL-ACC-030-RC01 so the alert names/severity resolve.
--    Detection is performed by the app_login_guard analysis process (NOT a
--    collector SQL query), so its detection_path is is_active=false.
--
-- 3) Register the app_login_guard process (metrics.registered_processes). The
--    watchlists start empty, so the process is a no-op until they are populated.
-- Idempotent.
-- =============================================================================

CREATE TABLE IF NOT EXISTS metrics.app_logins (
    row_id            bigserial PRIMARY KEY,
    applicative_login text        NOT NULL,
    server            text,                                   -- NULL/''/'%' = all servers
    is_active         boolean     NOT NULL DEFAULT true,
    entry_date        timestamp   NOT NULL DEFAULT now()
);
COMMENT ON TABLE metrics.app_logins IS
    'Watchlist of applicative/service logins (LIKE patterns) for the app_login_guard scenario';

CREATE TABLE IF NOT EXISTS metrics.programs (
    row_id       bigserial PRIMARY KEY,
    program_name text        NOT NULL,
    server       text,                                        -- NULL/''/'%' = all servers
    is_active    boolean     NOT NULL DEFAULT true,
    entry_date   timestamp   NOT NULL DEFAULT now()
);
COMMENT ON TABLE metrics.programs IS
    'Watchlist of program names (LIKE patterns) for the app_login_guard scenario';

-- ---- new root cause (full chain so v_rootcauses resolves name + severity) ----
DO $$
DECLARE v_dp int; v_ds int; v_rp int; v_rs int;
BEGIN
    INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description)
    VALUES ('SEC-SQL-ACC-030','SEC','SQL','ACC',
            'Applicative Login From Watched Program',
            'applicative-login-from-watched-program',
            'A watched applicative/service login is being used through a watched program (e.g. an ad-hoc client tool), which may indicate misuse of a service account.')
    ON CONFLICT (issue_id) DO NOTHING;

    INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, vendors_applicable, topics)
    VALUES ('SEC-SQL-ACC-030-RC01','SEC-SQL-ACC-030',
            'Applicative login used from a watched program',
            'applicative-login-used-from-a-watched-program',
            'An active transaction was seen whose login_name matches metrics.app_logins AND whose program_name matches metrics.programs for that server. Detected by the app_login_guard analysis process, which raises an alert and (subject to the blocker_dry_run switch) kills the offending session.',
            ARRAY['sqlserver'], ARRAY['applicative login','watched program','session kill','service account misuse'])
    ON CONFLICT (root_cause_id) DO NOTHING;

    IF NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
                   WHERE root_cause_id='SEC-SQL-ACC-030-RC01' AND vendor_slug='sqlserver') THEN
        INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
        VALUES ('sqlserver','process','Detect SEC-SQL-ACC-030-RC01 (sqlserver)',
                jsonb_build_object('engine','process','process','app_login_guard',
                    'sql','-- Detected by the app_login_guard analysis process: a login in metrics.app_logins used with a program in metrics.programs within SEC-SQL-ACC-011-RC02 active transactions.'),
                jsonb_build_object('condition','row_count > 0',
                    'description','An applicative login from metrics.app_logins was used with a program from metrics.programs'))
        RETURNING id INTO v_ds;

        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('SEC-SQL-ACC-030-RC01','sqlserver','Detect SEC-SQL-ACC-030-RC01 (sqlserver)',
                'Process-based detection (app_login_guard); not a collector SQL query.','diagnostic', false)
        RETURNING id INTO v_dp;

        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_dp, v_ds, 1, 'confirmed','ruled_out');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM rootcause.resolution_paths
                   WHERE root_cause_id='SEC-SQL-ACC-030-RC01' AND vendor_slug='sqlserver') THEN
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver','remediate','Kill the offending session and review the applicative login',
                jsonb_build_object('action','kill_session',
                    'description','Kill the session on the target server (subject to blocker_dry_run) and review why the applicative login was used from a watched program.'),
                'high', true, false)
        RETURNING id INTO v_rs;

        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
        VALUES ('SEC-SQL-ACC-030-RC01','sqlserver','Resolve: Detect SEC-SQL-ACC-030-RC01 (sqlserver)',
                'resolve-sec_sql_acc_030_rc01-sqlserver',
                'Kill the offending session and investigate the applicative login / program combination.',
                'supervised','high','authored', true)
        RETURNING id INTO v_rp;

        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order)
        VALUES (v_rp, v_rs, 1);
    END IF;
END $$;

-- ---- register the analysis process (no-op until the watchlists are populated) ----
INSERT INTO metrics.registered_processes (process_name, is_active, interval, description)
SELECT 'app_login_guard', true, 60,
       'Alert + kill sessions where an applicative login (metrics.app_logins) is used from a watched program (metrics.programs) in SEC-SQL-ACC-011-RC02 active transactions'
WHERE NOT EXISTS (SELECT 1 FROM metrics.registered_processes WHERE process_name='app_login_guard');
