-- =============================================================================
-- 7460_downgrade_critical_rootcauses.sql
--
-- Reduce root-cause risk from 'critical' to 'high', EXCEPT for the destructive
-- ones.
--
-- Why: 451 of 9,087 resolution paths were marked critical. At that volume
-- "critical" stops meaning anything - an operator triaging the Open Alerts
-- board cannot tell a dropped schema from an audit-retention setting. Reserving
-- critical for destruction restores the signal.
--
-- "Destructive" here describes the EVENT THE ROOT CAUSE DETECTS, not the SQL of
-- its remediation: data or objects dropped, truncated, mass-deleted, purged, or
-- encrypted by ransomware. Those keep critical. Everything else - audit
-- configuration, permission drift, session termination, retention tuning - moves
-- to high.
--
-- Matching is on rootcause.root_causes.name only, deliberately NOT description:
-- matching descriptions pulled in "Insufficient disk space" and "File system
-- quotas" on the words "loss" and "delet", which are not destructive events.
--
-- Scope: BOTH rootcause.resolution_paths.risk_level and
-- rootcause.resolution_steps.risk_level.
--
-- Both are required, and the second one is the one that actually matters:
-- rootcause.v_rootcauses exposes `rpst.risk_level` - the resolution STEP's level
-- - and only joins the path's level against the lookup table. Downgrading paths
-- alone changes the catalogue but NOT the severity an alert carries. An earlier
-- revision of this script did exactly that and left 137 paths still reporting
-- critical.
--
-- A step is only downgraded when NO path referencing it belongs to a destructive
-- root cause. Steps are not shared across root causes in the shipped catalogue,
-- but the guard costs nothing and keeps the rule correct if that changes.
--
-- Idempotent: re-running only ever affects rows still sitting at 'critical'
-- that are not destructive, so the second run is a no-op. Reversible via the
-- audit table written below.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- The destructive-event vocabulary, in one place so the rule is auditable and
-- the same expression is used by the update, the audit and the verification.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION rootcause.is_destructive_name(p_name text)
    RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT coalesce(p_name, '') ~*
           '\m(drop|dropped|truncate|truncated|truncation|delete|deleted|deletion|'
           'purge|purged|destroy|destroyed|destructive|ransomware|wipe|wiped)\M';
$$;

COMMENT ON FUNCTION rootcause.is_destructive_name(text) IS
  'True when a root-cause NAME describes a destructive event (drop/truncate/delete/purge/ransomware). Used by 7460 to decide which root causes keep risk_level=critical.';

-- ---------------------------------------------------------------------------
-- Audit trail: what this migration changed, so it can be explained or undone.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rootcause.risk_level_downgrade_audit
(
    row_id            serial      PRIMARY KEY,
    resolution_path_id integer    NOT NULL,
    root_cause_id     varchar     NULL,
    root_cause_name   text        NULL,
    path_name         text        NULL,
    old_risk_level    text        NOT NULL,
    new_risk_level    text        NOT NULL,
    changed_at        timestamptz NOT NULL DEFAULT now(),
    changed_by        text        NOT NULL DEFAULT current_user,
    script            text        NOT NULL DEFAULT '7460'
);

-- Step downgrades reuse the same audit table; resolution_path_id stays NOT NULL
-- for path rows, so it is relaxed and an object_type discriminator added.
ALTER TABLE rootcause.risk_level_downgrade_audit
    ADD COLUMN IF NOT EXISTS resolution_step_id integer NULL;
ALTER TABLE rootcause.risk_level_downgrade_audit
    ADD COLUMN IF NOT EXISTS object_type text NOT NULL DEFAULT 'path';
ALTER TABLE rootcause.risk_level_downgrade_audit
    ALTER COLUMN resolution_path_id DROP NOT NULL;

COMMENT ON TABLE rootcause.risk_level_downgrade_audit IS
  'Row-level record of the 7460 critical->high downgrade, for paths (object_type=path) and resolution steps (object_type=step). Restore paths with: UPDATE rootcause.resolution_paths p SET risk_level=a.old_risk_level FROM rootcause.risk_level_downgrade_audit a WHERE a.resolution_path_id=p.id AND a.object_type=''path''; and steps with: UPDATE rootcause.resolution_steps s SET risk_level=a.old_risk_level FROM rootcause.risk_level_downgrade_audit a WHERE a.resolution_step_id=s.id AND a.object_type=''step'';';

-- ---------------------------------------------------------------------------
-- Record, then downgrade. Both use the identical predicate, and the audit is
-- written from the same statement's OLD rows so the two cannot drift.
-- ---------------------------------------------------------------------------
WITH downgraded AS (
    UPDATE rootcause.resolution_paths p
       SET risk_level = 'high',
           updated_at = now()
      FROM rootcause.root_causes rc
     WHERE rc.root_cause_id = p.root_cause_id
       AND p.risk_level = 'critical'
       AND NOT rootcause.is_destructive_name(rc.name)
    RETURNING p.id, p.root_cause_id, rc.name AS rc_name, p.name AS path_name
)
INSERT INTO rootcause.risk_level_downgrade_audit
        (resolution_path_id, root_cause_id, root_cause_name, path_name,
         old_risk_level, new_risk_level)
SELECT id, root_cause_id, rc_name, path_name, 'critical', 'high'
FROM downgraded;

-- ---------------------------------------------------------------------------
-- Same treatment for resolution STEPS - the level v_rootcauses actually exposes.
-- A step is spared if ANY path referencing it belongs to a destructive root
-- cause, and if it is reachable from no path at all (nothing to classify by).
-- ---------------------------------------------------------------------------
WITH downgraded_steps AS (
    UPDATE rootcause.resolution_steps s
       SET risk_level = 'high'
     WHERE s.risk_level = 'critical'
       AND EXISTS (
           SELECT 1 FROM rootcause.resolution_path_steps ps
           WHERE ps.resolution_step_id = s.id)
       AND NOT EXISTS (
           SELECT 1
           FROM rootcause.resolution_path_steps ps
           JOIN rootcause.resolution_paths p  ON p.id = ps.resolution_path_id
           JOIN rootcause.root_causes      rc ON rc.root_cause_id = p.root_cause_id
           WHERE ps.resolution_step_id = s.id
             AND rootcause.is_destructive_name(rc.name))
    RETURNING s.id, s.name
)
INSERT INTO rootcause.risk_level_downgrade_audit
        (resolution_step_id, path_name, old_risk_level, new_risk_level, object_type)
SELECT id, name, 'critical', 'high', 'step'
FROM downgraded_steps;

-- Paths with no matching root_causes row cannot be classified, so they are left
-- critical rather than silently downgraded. Report them for follow-up.
DO $$
DECLARE
    v_orphans int;
    v_left    int;
    v_moved   int;
BEGIN
    SELECT count(*) INTO v_orphans
    FROM rootcause.resolution_paths p
    LEFT JOIN rootcause.root_causes rc ON rc.root_cause_id = p.root_cause_id
    WHERE p.risk_level = 'critical' AND rc.root_cause_id IS NULL;

    SELECT count(*) INTO v_left
    FROM rootcause.resolution_paths WHERE risk_level = 'critical';

    SELECT count(*) INTO v_moved
    FROM rootcause.risk_level_downgrade_audit
    WHERE script = '7460' AND object_type = 'path';

    RAISE NOTICE '7460: % path(s) downgraded critical->high (all runs)', v_moved;
    RAISE NOTICE '7460: % path(s) remain critical', v_left;
    RAISE NOTICE '7460: % step(s) downgraded critical->high (all runs); % step(s) remain critical',
        (SELECT count(*) FROM rootcause.risk_level_downgrade_audit
          WHERE script = '7460' AND object_type = 'step'),
        (SELECT count(*) FROM rootcause.resolution_steps WHERE risk_level = 'critical');
    IF v_orphans > 0 THEN
        RAISE NOTICE '7460: % critical path(s) have no root_causes row and were left untouched', v_orphans;
    END IF;
END $$;

-- Guarded owner re-assert (same pattern as the rest of the numbered series).
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_adm') THEN
        EXECUTE 'ALTER TABLE rootcause.risk_level_downgrade_audit OWNER TO dbdome_adm';
        EXECUTE 'ALTER SEQUENCE rootcause.risk_level_downgrade_audit_row_id_seq OWNER TO dbdome_adm';
        EXECUTE 'ALTER FUNCTION rootcause.is_destructive_name(text) OWNER TO dbdome_adm';
    END IF;
END $$;
