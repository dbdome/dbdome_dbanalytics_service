-- ============================================================
-- 6450  Un-share SEC-SQL-PRI-001-RC16 resolution steps + set risk = high
--
-- RC16 was created (script 6310) by cloning RC12's resolution PATHS but REUSING
-- RC12's resolution STEPS - so RC16 and RC12 point at the same
-- rootcause.resolution_steps rows. rootcause.set_root_cause_risk() deliberately
-- REFUSES to change a resolution_step that is shared with another root cause
-- (its "AND id NOT IN (... root_cause_id <> p_root_cause_id ...)" clause), so
-- calling set_root_cause_risk('SEC-SQL-PRI-001-RC16', ...) updated 0 steps and
-- the effective risk in rootcause.v_rootcauses (which reads resolution_steps)
-- never changed - it stayed 'critical'.
--
-- Fix: give RC16 its OWN copies of those resolution steps (name suffixed to
-- satisfy the UNIQUE(vendor_slug,name) constraint), re-point RC16's
-- resolution_path_steps at the copies, set the copies to 'high', and align the
-- resolution_paths filter level. RC12 is left untouched (keeps its steps at
-- their current risk). After this, set_root_cause_risk() works for RC16.
-- Idempotent.
-- ============================================================
BEGIN;

DO $$
DECLARE r record; v_new bigint;
BEGIN
    FOR r IN
        SELECT rps.id AS rps_id, rs.id AS old_step, rs.vendor_slug, rs.step_type,
               rs.name, rs.content, rs.rollback, rs.requires_confirmation,
               rs.is_reversible, rs.estimated_duration
        FROM rootcause.resolution_paths rp
        JOIN rootcause.resolution_path_steps rps ON rps.resolution_path_id = rp.id
        JOIN rootcause.resolution_steps rs ON rs.id = rps.resolution_step_id
        WHERE rp.root_cause_id = 'SEC-SQL-PRI-001-RC16'
          -- only un-share steps genuinely shared with another root cause
          AND EXISTS (
              SELECT 1 FROM rootcause.resolution_paths rp2
              JOIN rootcause.resolution_path_steps x ON x.resolution_path_id = rp2.id
              WHERE x.resolution_step_id = rs.id
                AND rp2.root_cause_id <> 'SEC-SQL-PRI-001-RC16')
    LOOP
        INSERT INTO rootcause.resolution_steps
            (vendor_slug, step_type, name, content, rollback, risk_level,
             requires_confirmation, is_reversible, estimated_duration)
        VALUES (r.vendor_slug, r.step_type, r.name || ' (SEC-SQL-PRI-001-RC16)',
                r.content, r.rollback, 'high',
                r.requires_confirmation, r.is_reversible, r.estimated_duration)
        ON CONFLICT (vendor_slug, name) DO UPDATE SET risk_level = 'high'
        RETURNING id INTO v_new;

        UPDATE rootcause.resolution_path_steps
           SET resolution_step_id = v_new
         WHERE id = r.rps_id;
    END LOOP;
END $$;

-- keep the paths' filter level aligned (as set_root_cause_risk does)
UPDATE rootcause.resolution_paths
   SET risk_level = 'high', updated_at = now()
 WHERE root_cause_id = 'SEC-SQL-PRI-001-RC16';

-- verify: RC16 should now read 'high' everywhere; RC12 unchanged
SELECT 'RC16' AS rc, vendor_name, risk_level, count(*)
  FROM rootcause.v_rootcauses WHERE root_cause_id = 'SEC-SQL-PRI-001-RC16'
 GROUP BY 1,2,3
UNION ALL
SELECT 'RC12', vendor_name, risk_level, count(*)
  FROM rootcause.v_rootcauses WHERE root_cause_id = 'SEC-SQL-PRI-001-RC12'
 GROUP BY 1,2,3
 ORDER BY 1,2;

COMMIT;
