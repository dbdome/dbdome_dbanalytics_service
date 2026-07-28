-- =============================================================================
-- 6690_harden_rootcause_schema.sql
--
-- Least-privilege hardening of the rootcause schema (the detection-catalog IP).
-- Implements steps 1 + 2 of the rootcause hardening plan (see sql_scripts/usage.sql):
--
--   1) Non-superuser application roles:
--        dbdome_engine     - detection engine; the ONLY principal allowed into
--                            rootcause. Becomes the app login (PG_USER) after
--                            cutover. Owns rootcause objects and all views.
--        dbdome_grafana_ro - read-only reporting role for the Grafana
--                            datasource, scoped to customer-facing schemas.
--   2) Least-privilege on rootcause:
--        REVOKE everything from PUBLIC, dbdome_mon_usr, dbexpert_mon_usr and
--        dbdome_grafana_ro; GRANT to dbdome_engine only; lock down default
--        privileges so future rootcause objects stay private.
--
-- All monitoring/public/alerts views are re-owned by dbdome_engine so that
-- views which still join rootcause keep working for Grafana/monitoring roles
-- (PostgreSQL checks underlying-table privileges against the VIEW OWNER).
--
-- Idempotent. Run as a superuser (postgres) against the dbanalytics DB.
--
-- !! CUTOVER CHECKLIST (manual, after applying this script) !!
--   a) Set real passwords (roles are created with CHANGE_ME placeholders):
--        ALTER ROLE dbdome_engine     PASSWORD '<strong password>';
--        ALTER ROLE dbdome_grafana_ro PASSWORD '<strong password>';
--   b) Switch the app to the engine role: .env PG_USER=dbdome_engine
--      (dbanalytics service, DBDOME_web, DBDOME_scheduler) and restart the
--      services (they do NOT auto-restart).
--   c) Repoint the Grafana PostgreSQL datasource(s) to dbdome_grafana_ro.
--   d) Only after a-c are verified, run SECTION 8 below (superuser demotion,
--      shipped commented out). Until then dbdome_mon_usr stays superuser and
--      the REVOKEs are not yet effective for it.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- SECTION 1: create the non-superuser roles
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        CREATE ROLE dbdome_engine LOGIN
            NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION
            PASSWORD 'CHANGE_ME_dbdome_engine';
        RAISE NOTICE 'created role dbdome_engine - SET A REAL PASSWORD (cutover step a)';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_grafana_ro') THEN
        CREATE ROLE dbdome_grafana_ro LOGIN
            NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION
            PASSWORD 'CHANGE_ME_dbdome_grafana_ro';
        RAISE NOTICE 'created role dbdome_grafana_ro - SET A REAL PASSWORD (cutover step a)';
    END IF;
END $$;

COMMENT ON ROLE dbdome_engine     IS 'DBDOME detection engine / application role; sole principal with rootcause access';
COMMENT ON ROLE dbdome_grafana_ro IS 'Read-only Grafana datasource role; customer-facing schemas only, NO rootcause';

-- -----------------------------------------------------------------------------
-- SECTION 2: system-role capabilities the app needs once it is not superuser
--   pg_monitor            - pg_stat_* views used by self-monitoring
--   pg_read/write_server_files - file_fdw errorlog reads (AUD-022) and the
--                                dump/retention COPY-to-disk functions
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    GRANT pg_monitor, pg_read_server_files, pg_write_server_files TO dbdome_engine;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_mon_usr') THEN
        GRANT pg_monitor, pg_read_server_files, pg_write_server_files TO dbdome_mon_usr;
    END IF;
    -- file_fdw wrapper + any existing foreign servers (errorlog readers)
    IF EXISTS (SELECT 1 FROM pg_foreign_data_wrapper WHERE fdwname = 'file_fdw') THEN
        GRANT USAGE ON FOREIGN DATA WRAPPER file_fdw TO dbdome_engine;
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_mon_usr') THEN
            GRANT USAGE ON FOREIGN DATA WRAPPER file_fdw TO dbdome_mon_usr;
        END IF;
    END IF;
END $$;

DO $$
DECLARE r record;
BEGIN
    FOR r IN SELECT srvname FROM pg_foreign_server LOOP
        EXECUTE format('GRANT USAGE ON FOREIGN SERVER %I TO dbdome_engine', r.srvname);
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_mon_usr') THEN
            EXECUTE format('GRANT USAGE ON FOREIGN SERVER %I TO dbdome_mon_usr', r.srvname);
        END IF;
    END LOOP;
END $$;

-- Engine may create schemas during migrations (e.g. 6215 created monitoring)
DO $$
BEGIN
    EXECUTE format('GRANT CREATE, CONNECT, TEMP ON DATABASE %I TO dbdome_engine', current_database());
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO dbdome_grafana_ro',           current_database());
END $$;

-- -----------------------------------------------------------------------------
-- SECTION 3: dbdome_engine owns rootcause (schema + every object in it)
-- -----------------------------------------------------------------------------
DO $$
DECLARE r record;
BEGIN
    EXECUTE 'ALTER SCHEMA rootcause OWNER TO dbdome_engine';

    FOR r IN
        SELECT c.relkind, c.relname
        FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'rootcause' AND c.relkind IN ('r','p','v','m')
    LOOP
        EXECUTE format('ALTER %s rootcause.%I OWNER TO dbdome_engine',
                       CASE r.relkind WHEN 'v' THEN 'VIEW'
                                      WHEN 'm' THEN 'MATERIALIZED VIEW'
                                      ELSE 'TABLE' END,
                       r.relname);
    END LOOP;

    -- standalone sequences only: serial/identity sequences are internally
    -- linked to their table (pg_depend deptype a/i) and follow its owner;
    -- altering them directly errors out
    FOR r IN
        SELECT c.relname
        FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'rootcause' AND c.relkind = 'S'
          AND NOT EXISTS (
              SELECT 1 FROM pg_depend d
              WHERE d.classid = 'pg_class'::regclass
                AND d.objid   = c.oid
                AND d.deptype IN ('a','i'))
    LOOP
        EXECUTE format('ALTER SEQUENCE rootcause.%I OWNER TO dbdome_engine', r.relname);
    END LOOP;

    FOR r IN
        SELECT p.oid::regprocedure AS sig,
               CASE p.prokind WHEN 'p' THEN 'PROCEDURE' ELSE 'FUNCTION' END AS kind
        FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'rootcause'
    LOOP
        EXECUTE format('ALTER %s %s OWNER TO dbdome_engine', r.kind, r.sig);
    END LOOP;
END $$;

-- -----------------------------------------------------------------------------
-- SECTION 4: re-own all NON-rootcause views to dbdome_engine.
-- Views that still join rootcause (the description split is not finished for
-- all of them) must be owned by a role that can read rootcause, otherwise the
-- Grafana/monitoring roles lose those dashboards after the demotion.
-- -----------------------------------------------------------------------------
DO $$
DECLARE r record;
BEGIN
    FOR r IN
        SELECT n.nspname, c.relname, c.relkind
        FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relkind IN ('v','m')
          AND n.nspname NOT IN ('pg_catalog','information_schema','rootcause')
    LOOP
        EXECUTE format('ALTER %s %I.%I OWNER TO dbdome_engine',
                       CASE r.relkind WHEN 'm' THEN 'MATERIALIZED VIEW' ELSE 'VIEW' END,
                       r.nspname, r.relname);
    END LOOP;
END $$;

-- -----------------------------------------------------------------------------
-- SECTION 5: lock rootcause down.
-- REVOKE from PUBLIC and every role except dbdome_engine (and postgres) -
-- including GROUP roles such as dbdome_adm, whose grants would otherwise flow
-- to dbdome_mon_usr through membership. Then re-grant to the engine only and
-- close future-object leaks via default privileges.
-- -----------------------------------------------------------------------------
DO $$
DECLARE r record;
BEGIN
    REVOKE ALL ON SCHEMA rootcause                       FROM PUBLIC;
    REVOKE ALL ON ALL TABLES     IN SCHEMA rootcause     FROM PUBLIC;
    REVOKE ALL ON ALL SEQUENCES  IN SCHEMA rootcause     FROM PUBLIC;
    REVOKE ALL ON ALL FUNCTIONS  IN SCHEMA rootcause     FROM PUBLIC;

    FOR r IN
        SELECT rolname FROM pg_roles
        WHERE rolname NOT IN ('postgres', 'dbdome_engine')
          AND rolname NOT LIKE 'pg\_%'
    LOOP
        EXECUTE format('REVOKE ALL ON SCHEMA rootcause                   FROM %I', r.rolname);
        EXECUTE format('REVOKE ALL ON ALL TABLES    IN SCHEMA rootcause  FROM %I', r.rolname);
        EXECUTE format('REVOKE ALL ON ALL SEQUENCES IN SCHEMA rootcause  FROM %I', r.rolname);
        EXECUTE format('REVOKE ALL ON ALL FUNCTIONS IN SCHEMA rootcause  FROM %I', r.rolname);
    END LOOP;
END $$;

GRANT USAGE, CREATE ON SCHEMA rootcause TO dbdome_engine;
GRANT ALL ON ALL TABLES    IN SCHEMA rootcause TO dbdome_engine;
GRANT ALL ON ALL SEQUENCES IN SCHEMA rootcause TO dbdome_engine;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA rootcause TO dbdome_engine;

-- future rootcause objects: never visible to PUBLIC, always to the engine
ALTER DEFAULT PRIVILEGES                        IN SCHEMA rootcause REVOKE ALL ON TABLES    FROM PUBLIC;
ALTER DEFAULT PRIVILEGES                        IN SCHEMA rootcause REVOKE ALL ON SEQUENCES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES                        IN SCHEMA rootcause REVOKE ALL ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE dbdome_engine IN SCHEMA rootcause REVOKE ALL ON TABLES    FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE dbdome_engine IN SCHEMA rootcause REVOKE ALL ON SEQUENCES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE dbdome_engine IN SCHEMA rootcause REVOKE ALL ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES                        IN SCHEMA rootcause GRANT ALL ON TABLES    TO dbdome_engine;
ALTER DEFAULT PRIVILEGES                        IN SCHEMA rootcause GRANT ALL ON SEQUENCES TO dbdome_engine;
ALTER DEFAULT PRIVILEGES                        IN SCHEMA rootcause GRANT ALL ON FUNCTIONS TO dbdome_engine;

-- -----------------------------------------------------------------------------
-- SECTION 6: full application grants on every NON-rootcause schema.
--   dbdome_engine  - full read/write (it becomes the app login)
--   dbdome_mon_usr - full read/write, so collection keeps working after the
--                    superuser demotion in SECTION 8
-- Includes default privileges so objects created by future numbered scripts
-- (run as postgres or dbdome_engine) stay reachable by both roles.
-- -----------------------------------------------------------------------------
DO $$
DECLARE s record; tgt text;
BEGIN
    FOR s IN
        SELECT nspname FROM pg_namespace
        WHERE nspname NOT IN ('pg_catalog','information_schema','rootcause')
          AND nspname NOT LIKE 'pg\_%'
    LOOP
        FOREACH tgt IN ARRAY ARRAY['dbdome_engine','dbdome_mon_usr'] LOOP
            CONTINUE WHEN NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = tgt);
            EXECUTE format('GRANT USAGE, CREATE ON SCHEMA %I TO %I',            s.nspname, tgt);
            EXECUTE format('GRANT ALL ON ALL TABLES    IN SCHEMA %I TO %I',     s.nspname, tgt);
            EXECUTE format('GRANT ALL ON ALL SEQUENCES IN SCHEMA %I TO %I',     s.nspname, tgt);
            EXECUTE format('GRANT ALL ON ALL FUNCTIONS IN SCHEMA %I TO %I',     s.nspname, tgt);
            EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT ALL ON TABLES    TO %I', s.nspname, tgt);
            EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT ALL ON SEQUENCES TO %I', s.nspname, tgt);
            EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT ALL ON FUNCTIONS TO %I', s.nspname, tgt);
            EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE dbdome_engine IN SCHEMA %I GRANT ALL ON TABLES    TO %I', s.nspname, tgt);
            EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE dbdome_engine IN SCHEMA %I GRANT ALL ON SEQUENCES TO %I', s.nspname, tgt);
            EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE dbdome_engine IN SCHEMA %I GRANT ALL ON FUNCTIONS TO %I', s.nspname, tgt);
        END LOOP;
    END LOOP;
END $$;

-- -----------------------------------------------------------------------------
-- SECTION 7: read-only Grafana role, customer-facing schemas ONLY.
-- SELECT on tables/views + EXECUTE on functions (dashboards call
-- monitoring.get_root_cause_resultset / get_alert_log_resultset* and the
-- alerts.resolve_incident_ui form). rootcause is deliberately absent.
-- -----------------------------------------------------------------------------
DO $$
DECLARE s text;
BEGIN
    FOREACH s IN ARRAY ARRAY[
        'public','alerts','config','flowchart','log','metrics',
        'monitoring','monitoring_history','reports','threats','widget'
    ] LOOP
        CONTINUE WHEN NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = s);
        EXECUTE format('GRANT USAGE ON SCHEMA %I TO dbdome_grafana_ro',                s);
        EXECUTE format('GRANT SELECT  ON ALL TABLES    IN SCHEMA %I TO dbdome_grafana_ro', s);
        EXECUTE format('GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA %I TO dbdome_grafana_ro', s);
        EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT SELECT  ON TABLES    TO dbdome_grafana_ro', s);
        EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT EXECUTE ON FUNCTIONS TO dbdome_grafana_ro', s);
        EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE dbdome_engine IN SCHEMA %I GRANT SELECT  ON TABLES    TO dbdome_grafana_ro', s);
        EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE dbdome_engine IN SCHEMA %I GRANT EXECUTE ON FUNCTIONS TO dbdome_grafana_ro', s);
    END LOOP;
END $$;

-- -----------------------------------------------------------------------------
-- SECTION 8: superuser demotion -- THE step that makes all of the above real.
-- Shipped COMMENTED OUT: run manually only after cutover steps a-c
-- (passwords set, .env PG_USER=dbdome_engine, services restarted healthy,
-- Grafana datasource repointed). Recovery if anything breaks:
--   ALTER ROLE dbdome_mon_usr SUPERUSER;   (as postgres)
-- -----------------------------------------------------------------------------
-- DO $$
-- BEGIN
--     IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_mon_usr' AND rolsuper) THEN
--         ALTER ROLE dbdome_mon_usr NOSUPERUSER NOCREATEDB NOCREATEROLE;
--     END IF;
--     IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_mon_usr' AND rolsuper) THEN
--         ALTER ROLE dbexpert_mon_usr NOSUPERUSER NOCREATEDB NOCREATEROLE;
--     END IF;
-- END $$;

-- -----------------------------------------------------------------------------
-- Verification (run after SECTION 8):
--   SELECT rolname, rolsuper FROM pg_roles WHERE rolcanlogin;         -- no app superusers
--   SET ROLE dbdome_grafana_ro;
--   SELECT * FROM rootcause.root_causes LIMIT 1;                      -- must FAIL (permission denied)
--   SELECT * FROM monitoring.v_rootcauses LIMIT 1;                    -- must still work (view owner = engine)
--   RESET ROLE;
-- -----------------------------------------------------------------------------
