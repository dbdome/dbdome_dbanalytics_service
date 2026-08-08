-- =============================================================================
-- 7440_app_version.sql
-- DBDOME product version: storage, history and the accessors the UI reads.
--
-- Version format is MAJOR.MINOR.BUILD rendered as "2.01.043": MAJOR/MINOR are
-- product decisions and change rarely; BUILD is entered by the operator at
-- every rebuild (build.ps1 prompts, pre-filling last+1). One row per build, so
-- the table doubles as the build history - "which binary is this customer on"
-- is answerable from the DB alone.
--
-- The running service registers its own baked-in version at startup
-- (utils/version.py -> config.set_version), so the table always describes the
-- binary that is actually running, not the last one someone built.
--
-- Dashboards read config.get_version_label() through a hidden query variable
-- ($dbdome_version, refresh-on-load) exactly like $global_ip / config.get_local_ip().
-- That is why a new build never needs the 102 dashboards re-edited: the rail
-- footer interpolates the variable and the variable re-queries this table.
--
-- Idempotent (IF NOT EXISTS + ON CONFLICT + CREATE OR REPLACE); guarded owner
-- re-assert, same as the rest of the numbered series.
-- =============================================================================

CREATE TABLE IF NOT EXISTS config.app_version
(
    row_id      serial      PRIMARY KEY,
    -- NOT unique on its own: one build produces the same version string for the
    -- service, setup and update components. Uniqueness is the triple below.
    version     text        NOT NULL,               -- '2.01.043' (display form)
    major       smallint    NOT NULL,
    minor       smallint    NOT NULL,
    build_no    integer     NOT NULL,
    built_at    timestamptz NOT NULL DEFAULT now(),
    built_by    text        NULL,                   -- OS user that ran build.ps1
    component   text        NOT NULL DEFAULT 'service'
                            CHECK (component IN ('service', 'setup', 'update')),
    notes       text        NULL,                   -- what shipped in this build
    is_current  boolean     NOT NULL DEFAULT false,
    CONSTRAINT app_version_build_no_positive CHECK (build_no >= 0),
    CONSTRAINT app_version_triple_uniq UNIQUE (major, minor, build_no, component)
);

-- An earlier revision of this script declared `version text NOT NULL UNIQUE`,
-- which blocks registering the same build for a second component ("duplicate
-- key ... app_version_version_key"). Drop it where it exists; the triple above
-- is the real key.
ALTER TABLE config.app_version DROP CONSTRAINT IF EXISTS app_version_version_key;

-- Exactly one current row per component.
CREATE UNIQUE INDEX IF NOT EXISTS app_version_one_current
    ON config.app_version (component) WHERE is_current;

CREATE INDEX IF NOT EXISTS app_version_built_at_idx
    ON config.app_version (built_at DESC);

COMMENT ON TABLE config.app_version IS
  'DBDOME version history, one row per build. is_current marks the running build per component. Written by utils/version.py at service startup and by build.ps1; read by the dashboards via config.get_version_label().';
COMMENT ON COLUMN config.app_version.build_no IS
  'Operator-entered build number, the BUILD in 2.01.BUILD. build.ps1 pre-fills last+1.';

-- ---------------------------------------------------------------------------
-- Accessors
-- ---------------------------------------------------------------------------

-- '2.01.043' - zero-padded minor and build so versions sort and read uniformly.
CREATE OR REPLACE FUNCTION config.format_version(p_major int, p_minor int, p_build int)
    RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT p_major::text || '.' || lpad(p_minor::text, 2, '0')
                         || '.' || lpad(p_build::text, 3, '0');
$$;

-- Bare version of the running service, e.g. '2.01.043'. Empty string rather
-- than NULL when unset: a NULL would render as "null" in a Grafana text panel.
CREATE OR REPLACE FUNCTION config.get_version(p_component text DEFAULT 'service')
    RETURNS text
    LANGUAGE sql STABLE
    AS $$
    SELECT coalesce(max(version), '')
    FROM config.app_version
    WHERE component = p_component AND is_current;
$$;

-- What the dashboard rail shows, e.g. 'DBDOME v2.01.043 - built 2026-08-08'.
CREATE OR REPLACE FUNCTION config.get_version_label(p_component text DEFAULT 'service')
    RETURNS text
    LANGUAGE sql STABLE
    AS $$
    SELECT coalesce(
        (SELECT 'DBDOME v' || version || ' - built ' || to_char(built_at, 'YYYY-MM-DD')
         FROM config.app_version
         WHERE component = p_component AND is_current
         LIMIT 1),
        'DBDOME - version not registered');
$$;

-- Register a build and make it current. Re-running the same triple is a no-op
-- apart from refreshing built_at/notes, so a rebuild of the same number is safe.
CREATE OR REPLACE FUNCTION config.set_version(
        p_major     int,
        p_minor     int,
        p_build     int,
        p_built_by  text DEFAULT NULL,
        p_notes     text DEFAULT NULL,
        p_component text DEFAULT 'service')
    RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_version text := config.format_version(p_major, p_minor, p_build);
BEGIN
    UPDATE config.app_version
       SET is_current = false
     WHERE component = p_component AND is_current;

    INSERT INTO config.app_version
            (version, major, minor, build_no, built_by, notes, component, is_current)
     VALUES (v_version, p_major, p_minor, p_build, p_built_by, p_notes, p_component, true)
    ON CONFLICT (major, minor, build_no, component) DO UPDATE
       SET built_at   = now(),
           built_by   = coalesce(EXCLUDED.built_by, config.app_version.built_by),
           notes      = coalesce(EXCLUDED.notes,    config.app_version.notes),
           version    = EXCLUDED.version,
           is_current = true;

    RETURN v_version;
END;
$$;

-- Next build number to offer at the prompt.
CREATE OR REPLACE FUNCTION config.next_build_no(p_component text DEFAULT 'service')
    RETURNS integer
    LANGUAGE sql STABLE
    AS $$
    SELECT coalesce(max(build_no), 0) + 1
    FROM config.app_version
    WHERE component = p_component;
$$;

-- History for the About panel / support: newest first.
CREATE OR REPLACE VIEW config.v_app_version AS
SELECT version,
       component,
       built_at,
       built_by,
       notes,
       is_current
FROM config.app_version
ORDER BY component, build_no DESC;

COMMENT ON VIEW config.v_app_version IS
  'DBDOME build history, newest first - the resultset behind the About / Version dashboard panel.';

-- ---------------------------------------------------------------------------
-- Seed: 2.01.000 so the accessors never return the "not registered" text on a
-- fresh install. The service overwrites this at startup with its real build.
-- ---------------------------------------------------------------------------
INSERT INTO config.app_version (version, major, minor, build_no, built_by, notes,
                                component, is_current)
VALUES ('2.01.000', 2, 1, 0, 'install', 'baseline seeded by 7440', 'service', true)
ON CONFLICT (major, minor, build_no, component) DO NOTHING;

-- Guarded owner re-assert (script may run as postgres on a fresh install or as
-- dbdome_adm on upgrade).
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_adm') THEN
        EXECUTE 'ALTER TABLE config.app_version OWNER TO dbdome_adm';
        EXECUTE 'ALTER SEQUENCE config.app_version_row_id_seq OWNER TO dbdome_adm';
        EXECUTE 'ALTER VIEW  config.v_app_version OWNER TO dbdome_adm';
        EXECUTE 'ALTER FUNCTION config.format_version(int, int, int) OWNER TO dbdome_adm';
        EXECUTE 'ALTER FUNCTION config.get_version(text) OWNER TO dbdome_adm';
        EXECUTE 'ALTER FUNCTION config.get_version_label(text) OWNER TO dbdome_adm';
        EXECUTE 'ALTER FUNCTION config.set_version(int, int, int, text, text, text) OWNER TO dbdome_adm';
        EXECUTE 'ALTER FUNCTION config.next_build_no(text) OWNER TO dbdome_adm';
    END IF;
END $$;

-- The Grafana datasource role reads the label through the hidden dashboard
-- variable, so it needs EXECUTE even under the 6690 hardening.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_grafana_ro') THEN
        EXECUTE 'GRANT SELECT ON config.app_version, config.v_app_version TO dbdome_grafana_ro';
        EXECUTE 'GRANT EXECUTE ON FUNCTION config.get_version(text) TO dbdome_grafana_ro';
        EXECUTE 'GRANT EXECUTE ON FUNCTION config.get_version_label(text) TO dbdome_grafana_ro';
    END IF;
END $$;
