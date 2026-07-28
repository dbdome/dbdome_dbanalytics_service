-- =============================================================================
-- 6700_gmmr_maintain_security_definer.sql
--
-- Follow-up to 6690_harden_rootcause_schema.sql: keep gmmr partition
-- maintenance working once dbdome_mon_usr is no longer superuser.
--
-- monitoring.gmmr_maintain() runs partition DDL:
--   CREATE TABLE ... PARTITION OF monitoring.general_metric_metadata_results
--   DROP TABLE monitoring.gmmr_YYYY_MM
-- Attaching a partition requires OWNERSHIP of the parent partitioned table
-- (schema CREATE is not enough) and dropping one requires owning the child.
--
-- Fix:
--   1) dbdome_engine owns the gmmr parent + every existing partition
--      (children do NOT follow the parent's owner automatically).
--   2) gmmr_maintain becomes SECURITY DEFINER owned by dbdome_engine, so the
--      DDL runs with the engine's privileges regardless of caller. New
--      partitions are then created owned by dbdome_engine too, so future
--      retention drops keep working.
--   3) EXECUTE is revoked from PUBLIC (functions grant it by default) and from
--      dbdome_grafana_ro (6690 gave it EXECUTE on all monitoring functions;
--      a definer maintenance function must not be callable from Grafana),
--      then granted only to dbdome_mon_usr. The scheduler keeps calling
--      SELECT monitoring.gmmr_maintain(12) unchanged.
--
-- The trigger monitoring.gmmr_upsert_latest needs nothing: trigger functions
-- run as the inserting user, and INSERT routing into existing partitions only
-- needs table INSERT, which dbdome_mon_usr keeps via 6690.
--
-- NOTE: CREATE OR REPLACE FUNCTION keeps the owner but takes SECURITY/SET
-- clauses from the new definition — if a later script ever recreates
-- gmmr_maintain, re-apply this script after it.
--
-- Idempotent. Run as a superuser (postgres) AFTER 6690.
-- =============================================================================

DO $$
DECLARE r record;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        RAISE NOTICE '6700: role dbdome_engine missing - apply 6690_harden_rootcause_schema.sql first; skipping';
        RETURN;
    END IF;

    IF to_regclass('monitoring.general_metric_metadata_results') IS NULL THEN
        RAISE NOTICE '6700: monitoring.general_metric_metadata_results missing - skipping';
        RETURN;
    END IF;

    -- ------------------------------------------------------------------
    -- 1) ownership: parent + all partitions (incl. gmmr_default)
    -- ------------------------------------------------------------------
    EXECUTE 'ALTER TABLE monitoring.general_metric_metadata_results OWNER TO dbdome_engine';

    FOR r IN
        SELECT c.relname
        FROM pg_inherits i
        JOIN pg_class c     ON c.oid = i.inhrelid
        JOIN pg_class p     ON p.oid = i.inhparent
        JOIN pg_namespace n ON n.oid = p.relnamespace
        WHERE n.nspname = 'monitoring'
          AND p.relname = 'general_metric_metadata_results'
    LOOP
        EXECUTE format('ALTER TABLE monitoring.%I OWNER TO dbdome_engine', r.relname);
    END LOOP;

    -- ------------------------------------------------------------------
    -- 2) definer function owned by the engine
    -- ------------------------------------------------------------------
    IF to_regprocedure('monitoring.gmmr_maintain(int,int)') IS NULL THEN
        RAISE NOTICE '6700: monitoring.gmmr_maintain(int,int) missing - skipping function changes';
        RETURN;
    END IF;

    EXECUTE 'ALTER FUNCTION monitoring.gmmr_maintain(int,int) OWNER TO dbdome_engine';
    -- body references other schemas fully qualified, so a minimal locked-down
    -- search_path is safe and blocks path hijacking of the definer
    EXECUTE 'ALTER FUNCTION monitoring.gmmr_maintain(int,int) SECURITY DEFINER '
            'SET search_path = monitoring, pg_temp';

    -- ------------------------------------------------------------------
    -- 3) narrow EXECUTE
    -- ------------------------------------------------------------------
    EXECUTE 'REVOKE EXECUTE ON FUNCTION monitoring.gmmr_maintain(int,int) FROM PUBLIC';
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_grafana_ro') THEN
        EXECUTE 'REVOKE EXECUTE ON FUNCTION monitoring.gmmr_maintain(int,int) FROM dbdome_grafana_ro';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_mon_usr') THEN
        EXECUTE 'GRANT EXECUTE ON FUNCTION monitoring.gmmr_maintain(int,int) TO dbdome_mon_usr';
    END IF;

    RAISE NOTICE '6700: gmmr parent/partitions owned by dbdome_engine; gmmr_maintain is SECURITY DEFINER';
END $$;

-- -----------------------------------------------------------------------------
-- Verification (after the 6690 SECTION 8 demotion):
--   SET ROLE dbdome_mon_usr;
--   SELECT monitoring.gmmr_maintain(12);                  -- must succeed (creates months ahead)
--   RESET ROLE;
--   SET ROLE dbdome_grafana_ro;
--   SELECT monitoring.gmmr_maintain(12);                  -- must FAIL (permission denied)
--   RESET ROLE;
--   SELECT relname, pg_get_userbyid(relowner)
--   FROM pg_class WHERE relname LIKE 'gmmr%';             -- all dbdome_engine
-- -----------------------------------------------------------------------------
