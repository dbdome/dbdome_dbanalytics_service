-- ============================================================
-- Rootcauses admin: enable/disable a root cause and change its risk level from
-- the "Rootcauses" dashboard.
--
-- IMPORTANT: monitoring/alerting reads rootcause.v_rootcauses, whose columns come
-- from:
--   * risk_level  <- rootcause.resolution_steps.risk_level  (per resolution step)
--   * is_active    <- rootcause.detection_paths.is_active
-- So edits MUST target those tables (an earlier version wrote resolution_paths,
-- which v_rootcauses ignores). We also keep resolution_paths in sync because its
-- risk_level participates in the v_rootcauses join to rootcause.risk_level (a row
-- only appears when that level is active).
--
-- A root cause maps to several resolution steps (one per vendor); some steps are
-- shared with OTHER root causes, so set_root_cause_risk only touches steps used
-- exclusively by this root cause (shared steps are left untouched to avoid
-- cross-contamination). SECURITY DEFINER so the Grafana role can call them.
-- No-op on null/blank. Idempotent.
-- ============================================================
CREATE OR REPLACE FUNCTION rootcause.set_root_cause_active(p_root_cause_id text, p_active boolean)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
DECLARE n_dp integer; n_rp integer;
BEGIN
    IF p_root_cause_id IS NULL OR p_root_cause_id = '' OR p_active IS NULL THEN
        RETURN 'noop';
    END IF;
    UPDATE rootcause.detection_paths SET is_active = p_active
     WHERE root_cause_id = p_root_cause_id;
    GET DIAGNOSTICS n_dp = ROW_COUNT;
    UPDATE rootcause.resolution_paths SET is_active = p_active, updated_at = now()
     WHERE root_cause_id = p_root_cause_id;
    GET DIAGNOSTICS n_rp = ROW_COUNT;
    RETURN format('is_active=%s : %s detection_path(s), %s resolution_path(s) for %s',
                  p_active, n_dp, n_rp, p_root_cause_id);
END $$;

CREATE OR REPLACE FUNCTION rootcause.set_root_cause_risk(p_root_cause_id text, p_risk text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
DECLARE n_steps integer; n_paths integer; v text;
BEGIN
    IF p_root_cause_id IS NULL OR p_root_cause_id = '' OR p_risk IS NULL OR p_risk = '' THEN
        RETURN 'noop';
    END IF;
    v := lower(trim(p_risk));
    IF v NOT IN ('low', 'medium', 'high', 'critical') THEN
        RAISE EXCEPTION 'invalid risk_level: %', p_risk;
    END IF;

    -- effective risk (what v_rootcauses outputs): resolution_steps used ONLY by
    -- this root cause.
    UPDATE rootcause.resolution_steps SET risk_level = v
     WHERE id IN (
        SELECT rpstp.resolution_step_id
        FROM rootcause.resolution_paths rp
        JOIN rootcause.resolution_path_steps rpstp ON rpstp.resolution_path_id = rp.id
        WHERE rp.root_cause_id = p_root_cause_id
     )
     AND id NOT IN (
        SELECT rpstp2.resolution_step_id
        FROM rootcause.resolution_paths rp2
        JOIN rootcause.resolution_path_steps rpstp2 ON rpstp2.resolution_path_id = rp2.id
        WHERE rp2.root_cause_id <> p_root_cause_id
     );
    GET DIAGNOSTICS n_steps = ROW_COUNT;

    -- keep the resolution_paths filter level aligned so the row stays visible.
    UPDATE rootcause.resolution_paths SET risk_level = v, updated_at = now()
     WHERE root_cause_id = p_root_cause_id;
    GET DIAGNOSTICS n_paths = ROW_COUNT;

    RETURN format('risk_level=%s : %s step(s), %s path(s) for %s', v, n_steps, n_paths, p_root_cause_id);
END $$;
