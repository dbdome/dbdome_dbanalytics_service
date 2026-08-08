-- =============================================================================
-- 7470_login_authorization_guard.sql
--
-- Per-login statement authorisation: declare which of SELECT / INSERT / UPDATE /
-- DELETE / DROP / TRUNCATE each login may run, and raise a CRITICAL
-- SEC-SQL-AUD-011-RC06 finding when a login runs something it may not.
--
-- Ships:
--   1. metrics.login_authorizations        - config table (white or black rules)
--   2. metrics.is_login_authorized()       - the rule engine, defined once so the
--                                            view, the collector clone and the UI
--                                            preview cannot disagree
--   3. monitoring.v_sec_sql_aud_011_rc06   - the unauthorised statements
--   4. monitoring.derive_sec_sql_aud_011_rc06() - clones the SEC-SQL-ACC-011-RC02
--                                            gmmr record into a SEC-SQL-AUD-011-RC06
--                                            record carrying only the unauthorised
--                                            rows, so RC06 collects like any other
--                                            metric
--   5. root cause SEC-SQL-AUD-011-RC06 (detection + resolution chain)
--
-- SOURCE OF TRUTH
--   monitoring.general_metric_metadata_results rows where metric_name =
--   'SEC-SQL-ACC-011-RC02'. Each row's metric_metadata is a jsonb ARRAY of session
--   objects; login_name and query_text are read from those objects. Nothing is
--   re-queried on the monitored server - RC06 is derived entirely from data the
--   collector already brought back.
--
-- SEMANTICS
--   white rule  the ticked operations are the ONLY ones this login may run
--   black rule  the ticked operations are forbidden
--   Black wins over white - an explicit deny is never overridden by an allow.
--   A login with NO active matching rule is unrestricted. Deliberate: an empty
--   config table is a no-op, not an alert storm on every session. Same contract
--   as the app_login_guard watchlists.
--
-- login_name and server are case-insensitive LIKE patterns; server '%' or blank
-- means every server.
--
-- Idempotent.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Config table
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS metrics.login_authorizations
(
    row_id      serial       PRIMARY KEY,
    login_name  varchar(256) NOT NULL,                 -- ILIKE pattern
    server      varchar(256) NOT NULL DEFAULT '%',     -- '%' = all servers
    mode        text         NOT NULL DEFAULT 'white'
                             CHECK (mode IN ('white', 'black')),
    op_select   boolean      NOT NULL DEFAULT false,
    op_insert   boolean      NOT NULL DEFAULT false,
    op_update   boolean      NOT NULL DEFAULT false,
    op_delete   boolean      NOT NULL DEFAULT false,
    op_drop     boolean      NOT NULL DEFAULT false,
    op_truncate boolean      NOT NULL DEFAULT false,
    is_active   boolean      NOT NULL DEFAULT true,
    description text         NULL,
    entry_date  timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT login_authorizations_uniq UNIQUE (login_name, server, mode)
);

COMMENT ON TABLE metrics.login_authorizations IS
  'Per-login statement authorisation for SEC-SQL-AUD-011-RC06. mode=white: the ticked operations are the only ones the login may run. mode=black: the ticked operations are forbidden. Black wins over white; a login with no active rule is unrestricted (empty table = no alerts). login_name/server are case-insensitive LIKE patterns, server ''%'' = all servers.';
COMMENT ON COLUMN metrics.login_authorizations.mode IS
  'white = allow-list (anything not ticked is unauthorised); black = deny-list (anything ticked is unauthorised).';

CREATE INDEX IF NOT EXISTS login_authorizations_active_idx
    ON metrics.login_authorizations (is_active) WHERE is_active;

-- ---------------------------------------------------------------------------
-- 2. Rule engine
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION metrics.is_login_authorized(
        p_login   text,
        p_server  text,
        p_command text)
    RETURNS boolean
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_cmd       text := lower(coalesce(p_command, ''));
    v_black_hit boolean;
    v_white_any boolean;
    v_white_ok  boolean;
BEGIN
    IF p_login IS NULL OR v_cmd = '' THEN
        RETURN true;                       -- nothing to judge
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM metrics.login_authorizations a
        WHERE a.is_active AND a.mode = 'black'
          AND p_login ILIKE a.login_name
          AND (a.server IN ('%', '') OR coalesce(p_server, '') ILIKE a.server)
          AND CASE v_cmd
                WHEN 'select' THEN a.op_select WHEN 'insert' THEN a.op_insert
                WHEN 'update' THEN a.op_update WHEN 'delete' THEN a.op_delete
                WHEN 'drop'   THEN a.op_drop   WHEN 'truncate' THEN a.op_truncate
                ELSE false END
    ) INTO v_black_hit;

    IF v_black_hit THEN
        RETURN false;                      -- explicit deny is decisive
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM metrics.login_authorizations a
        WHERE a.is_active AND a.mode = 'white'
          AND p_login ILIKE a.login_name
          AND (a.server IN ('%', '') OR coalesce(p_server, '') ILIKE a.server)
    ) INTO v_white_any;

    IF NOT v_white_any THEN
        RETURN true;                       -- unrestricted: no rule covers it
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM metrics.login_authorizations a
        WHERE a.is_active AND a.mode = 'white'
          AND p_login ILIKE a.login_name
          AND (a.server IN ('%', '') OR coalesce(p_server, '') ILIKE a.server)
          AND CASE v_cmd
                WHEN 'select' THEN a.op_select WHEN 'insert' THEN a.op_insert
                WHEN 'update' THEN a.op_update WHEN 'delete' THEN a.op_delete
                WHEN 'drop'   THEN a.op_drop   WHEN 'truncate' THEN a.op_truncate
                ELSE false END
    ) INTO v_white_ok;

    RETURN v_white_ok;
END;
$$;

COMMENT ON FUNCTION metrics.is_login_authorized(text, text, text) IS
  'Evaluates metrics.login_authorizations for one (login, server, command). False = unauthorised. Black rules win; no matching rule = authorised.';

-- ---------------------------------------------------------------------------
-- 3. The leading SQL verb of a statement.
--    Skips leading block and line comments so a commented preamble cannot hide
--    the verb; WITH is treated as SELECT.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION monitoring.sql_command_verb(p_sql text)
    RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE lower((regexp_match(coalesce(p_sql, ''),
                       '^\s*(?:/\*.*?\*/\s*|--[^\n]*\n\s*)*([a-zA-Z]+)'))[1])
             WHEN 'select'   THEN 'select'
             WHEN 'with'     THEN 'select'
             WHEN 'insert'   THEN 'insert'
             WHEN 'update'   THEN 'update'
             WHEN 'delete'   THEN 'delete'
             WHEN 'drop'     THEN 'drop'
             WHEN 'truncate' THEN 'truncate'
           END;
$$;

-- ---------------------------------------------------------------------------
-- 4. Detection view - unauthorised statements from today's collected sessions
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW monitoring.v_sec_sql_aud_011_rc06 AS
SELECT
    s.servername,
    g.server,
    g.server_id,
    e->>'session_id'         AS session_id,
    e->>'login_name'         AS login_name,
    e->>'host_name'          AS host_name,
    e->>'program_name'       AS program_name,
    e->>'database_name'      AS database_name,
    e->>'transaction_state'  AS status,
    e->>'transaction_id'     AS transaction_id,
    e->>'duration_seconds'   AS duration,
    c.command,
    coalesce(e->>'query_text', e->>'sql_text') AS query,
    g.entry_date
FROM monitoring.general_metric_metadata_results g
LEFT JOIN metrics.servers s ON s.server = g.server
CROSS JOIN LATERAL jsonb_array_elements(g.metric_metadata) e
CROSS JOIN LATERAL (
    SELECT monitoring.sql_command_verb(coalesce(e->>'query_text', e->>'sql_text')) AS command
) c
WHERE g.metric_name = 'SEC-SQL-ACC-011-RC02'
  AND g.entry_date >= current_date
  AND jsonb_typeof(g.metric_metadata) = 'array'
  AND e->>'login_name' IS NOT NULL
  AND c.command IS NOT NULL
  AND NOT metrics.is_login_authorized(e->>'login_name', g.server, c.command);

COMMENT ON VIEW monitoring.v_sec_sql_aud_011_rc06 IS
  'SEC-SQL-AUD-011-RC06: today''s collected sessions (from the SEC-SQL-ACC-011-RC02 gmmr records) whose login is not authorised to run that statement per metrics.login_authorizations. Empty while the config table has no active rules.';

-- ---------------------------------------------------------------------------
-- 5. Collector clone
--    For every SEC-SQL-ACC-011-RC02 gmmr record that contains at least one
--    unauthorised statement, write the SAME record back under metric_name
--    'SEC-SQL-AUD-011-RC06', carrying only the unauthorised rows. RC06 then
--    behaves like any other collected metric downstream (alerting, dashboards,
--    root-cause resultsets) with no collector change.
--
--    Dedupe is on (server, entry_date): a source record is cloned once. Safe to
--    call on any schedule.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION monitoring.derive_sec_sql_aud_011_rc06(
        p_since timestamp DEFAULT NULL)
    RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_since timestamp := coalesce(p_since, current_date::timestamp);
    v_rows  integer;
BEGIN
    WITH src AS (
        -- metric_config is `json`, which has no equality operator and so cannot
        -- appear in GROUP BY. Every row of a group comes from the same source
        -- record, so min() over its text form returns that record's config exactly.
        SELECT g.id, g.server, g.server_id, g.category_id, g.entry_date,
               min(g.metric_config::text)::json AS metric_config,
               jsonb_agg(e) FILTER (
                   WHERE NOT metrics.is_login_authorized(
                             e->>'login_name', g.server,
                             monitoring.sql_command_verb(coalesce(e->>'query_text', e->>'sql_text')))
                     AND e->>'login_name' IS NOT NULL
                     AND monitoring.sql_command_verb(coalesce(e->>'query_text', e->>'sql_text')) IS NOT NULL
               ) AS bad
        FROM monitoring.general_metric_metadata_results g
        CROSS JOIN LATERAL jsonb_array_elements(g.metric_metadata) e
        WHERE g.metric_name = 'SEC-SQL-ACC-011-RC02'
          AND g.entry_date >= v_since
          AND jsonb_typeof(g.metric_metadata) = 'array'
        GROUP BY g.id, g.server, g.server_id, g.category_id, g.entry_date
    )
    INSERT INTO monitoring.general_metric_metadata_results
        (server, server_id, category_id, metric_name, metric_config,
         metric_metadata, metric_metadata_vs_expected, entry_date)
    SELECT src.server, src.server_id, src.category_id, 'SEC-SQL-AUD-011-RC06',
           src.metric_config,
           src.bad,
           jsonb_build_object(
               'matched', true,
               'expected', jsonb_build_object(
                   'condition', 'row_count > 0',
                   'description', 'A login executed a statement it is not authorised to run'),
               'derived_from', 'SEC-SQL-ACC-011-RC02',
               'unauthorized_count', jsonb_array_length(src.bad)),
           src.entry_date
    FROM src
    WHERE src.bad IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM monitoring.general_metric_metadata_results d
          WHERE d.metric_name = 'SEC-SQL-AUD-011-RC06'
            AND d.server = src.server
            AND d.entry_date = src.entry_date);

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    RETURN v_rows;
END;
$$;

COMMENT ON FUNCTION monitoring.derive_sec_sql_aud_011_rc06(timestamp) IS
  'Clones SEC-SQL-ACC-011-RC02 gmmr records into SEC-SQL-AUD-011-RC06 records containing only the statements the login was not authorised to run. Returns the number of records written. Deduped on (server, entry_date); safe to re-run.';

-- ---------------------------------------------------------------------------
-- 6. Root cause SEC-SQL-AUD-011-RC06
--    detection_steps.content is auto-encrypted by trg_00_encrypt_detection
--    (7300), so plaintext jsonb is inserted here on purpose.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
    v_dp int; v_ds int; v_rp int; v_rs int; v_vendor text;
BEGIN
    INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code,
                                  name, slug, description)
    VALUES ('SEC-SQL-AUD-011', 'SEC', 'SQL', 'AUD',
            'Audit and Log Tampering', 'audit-and-log-tampering',
            'Activity that tampers with, disables or destroys the audit and log trail.')
    ON CONFLICT (issue_id) DO NOTHING;

    INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description,
                                       vendors_applicable, topics)
    VALUES ('SEC-SQL-AUD-011-RC06', 'SEC-SQL-AUD-011',
            'Unauthorised INSERT, UPDATE, DELETE or DROP statement executed by a login',
            'unauthorised-insert-update-delete-drop-statement-executed-by-a-login',
            'A login executed a statement it is not authorised to run under metrics.login_authorizations. '
            'White rules make the ticked operations the only permitted ones; black rules forbid the ticked '
            'operations outright. Derived from the SEC-SQL-ACC-011-RC02 collected sessions by '
            'monitoring.derive_sec_sql_aud_011_rc06(), which clones the record under this metric name '
            'carrying only the unauthorised statements. Unauthorised write or DDL activity of this kind is '
            'how audit and log tables get altered or destroyed, so it is treated as critical.',
            ARRAY['sqlserver', 'postgresql', 'mysql', 'oracle'],
            ARRAY['authorisation', 'audit tampering', 'privilege misuse', 'DML', 'DDL', 'whitelist', 'blacklist'])
    ON CONFLICT (root_cause_id) DO NOTHING;

    FOREACH v_vendor IN ARRAY ARRAY['sqlserver', 'postgresql', 'mysql', 'oracle'] LOOP
        IF NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
                       WHERE root_cause_id = 'SEC-SQL-AUD-011-RC06' AND vendor_slug = v_vendor) THEN
            INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
            VALUES (v_vendor, 'query', 'Detect SEC-SQL-AUD-011-RC06 (' || v_vendor || ')',
                    jsonb_build_object('engine', 'sql',
                        'sql', 'SELECT * FROM monitoring.v_sec_sql_aud_011_rc06 ORDER BY entry_date DESC'),
                    jsonb_build_object('condition', 'row_count > 0',
                        'description', 'A login executed a statement it is not authorised to run'))
            RETURNING id INTO v_ds;

            INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description,
                                                   path_type, is_active)
            VALUES ('SEC-SQL-AUD-011-RC06', v_vendor,
                    'Detect SEC-SQL-AUD-011-RC06 (' || v_vendor || ')',
                    'Unauthorised statements per metrics.login_authorizations, derived from the SEC-SQL-ACC-011-RC02 collected sessions.',
                    'diagnostic', true)
            RETURNING id INTO v_dp;

            INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id,
                                                        sequence, on_match_action, on_no_match_action)
            VALUES (v_dp, v_ds, 1, 'confirmed', 'ruled_out');
        END IF;

        IF NOT EXISTS (SELECT 1 FROM rootcause.resolution_paths
                       WHERE root_cause_id = 'SEC-SQL-AUD-011-RC06' AND vendor_slug = v_vendor) THEN
            INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content,
                                                    risk_level, requires_confirmation, is_reversible)
            VALUES (v_vendor, 'remediate',
                    'Review the unauthorised statement and correct the login''s authorisation',
                    jsonb_build_object('action', 'review',
                        'description', 'Confirm whether the login should have been able to run this operation. '
                                       'If it should, tick that operation on its white rule in /login_authorizations. '
                                       'If it should not, revoke the underlying database privilege - this guard '
                                       'detects and alerts, it does not block.'),
                    -- critical, and it MUST be set here: rootcause.v_rootcauses
                    -- exposes the resolution STEP's risk_level (rpst.risk_level),
                    -- not the path's, so this column is the one that reaches the
                    -- alert. Setting only the path leaves the alert at the step's
                    -- level.
                    'critical', true, true)
            RETURNING id INTO v_rs;

            INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description,
                                                    execution_mode, risk_level, status, is_active)
            VALUES ('SEC-SQL-AUD-011-RC06', v_vendor,
                    'Resolve: Detect SEC-SQL-AUD-011-RC06 (' || v_vendor || ')',
                    'resolve-sec_sql_aud_011_rc06-' || v_vendor,
                    'Review the unauthorised statement, then either authorise the operation or revoke the privilege.',
                    'supervised', 'critical', 'authored', true)
            RETURNING id INTO v_rp;

            INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order)
            VALUES (v_rp, v_rs, 1);
        END IF;
    END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- 6b. Corrective: force RC06 to critical everywhere it is read.
--     An earlier revision of this script created the resolution step at 'high'.
--     Because v_rootcauses exposes the STEP's risk_level, that made the alert
--     high even though the path said critical. Re-assert both on every run so an
--     install that got the earlier revision is repaired.
-- ---------------------------------------------------------------------------
UPDATE rootcause.resolution_steps s
   SET risk_level = 'critical'
  FROM rootcause.resolution_path_steps ps, rootcause.resolution_paths p
 WHERE ps.resolution_step_id = s.id
   AND p.id = ps.resolution_path_id
   AND p.root_cause_id = 'SEC-SQL-AUD-011-RC06'
   AND s.risk_level IS DISTINCT FROM 'critical';

UPDATE rootcause.resolution_paths
   SET risk_level = 'critical'
 WHERE root_cause_id = 'SEC-SQL-AUD-011-RC06'
   AND risk_level IS DISTINCT FROM 'critical';

-- ---------------------------------------------------------------------------
-- 7. Ownership + grants
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_adm') THEN
        EXECUTE 'ALTER TABLE metrics.login_authorizations OWNER TO dbdome_adm';
        EXECUTE 'ALTER SEQUENCE metrics.login_authorizations_row_id_seq OWNER TO dbdome_adm';
        EXECUTE 'ALTER VIEW monitoring.v_sec_sql_aud_011_rc06 OWNER TO dbdome_adm';
        EXECUTE 'ALTER FUNCTION metrics.is_login_authorized(text, text, text) OWNER TO dbdome_adm';
        EXECUTE 'ALTER FUNCTION monitoring.sql_command_verb(text) OWNER TO dbdome_adm';
        EXECUTE 'ALTER FUNCTION monitoring.derive_sec_sql_aud_011_rc06(timestamp) OWNER TO dbdome_adm';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_grafana_ro') THEN
        EXECUTE 'GRANT SELECT ON metrics.login_authorizations, monitoring.v_sec_sql_aud_011_rc06 TO dbdome_grafana_ro';
        EXECUTE 'GRANT EXECUTE ON FUNCTION metrics.is_login_authorized(text, text, text) TO dbdome_grafana_ro';
        EXECUTE 'GRANT EXECUTE ON FUNCTION monitoring.sql_command_verb(text) TO dbdome_grafana_ro';
    END IF;
END $$;
