-- =============================================================================
-- 7330_fix_disk_size_param.sql
--
-- config.global_params.disk_size is the TOTAL disk capacity in MB. It feeds the
-- disk-space alert (config.alerts 'disk space'):
--     (disk_size - used_mb) / disk_size * 100  = free %
-- and any dashboard/report that reads free-disk %.
--
-- It shipped as a placeholder '10000' (10 GB), which on any real install is far
-- below actual usage, so the computed free% went wildly negative (e.g. -1304).
-- Alert-gated reports (their trigger threshold never matches an out-of-range
-- value) then silently never fire.
--
-- Authoritative value: processes/internal_health_monitor.py now writes the real
-- OS disk total (shutil.disk_usage of the data drive, in MB) into this key on
-- every run (every 300 s). SQL cannot read OS free space, so this migration only:
--   * guarantees the row exists, and
--   * repairs an obviously-broken value at install/upgrade time (missing,
--     non-numeric, or smaller than current tablespace usage) to a safe floor
--     with generous headroom, so free% stays well ABOVE the alert band (no false
--     low-disk alarm) until the health monitor sets the exact capacity.
--
-- A sane operator-set value (>= current usage) is left untouched.
-- Idempotent; safe to re-run.
-- =============================================================================
DO $$
DECLARE
    used_mb  bigint;
    cur_val  text;
    cur_num  bigint;
    seed     bigint;
BEGIN
    IF to_regclass('config.global_params') IS NULL THEN
        RAISE NOTICE '7330: config.global_params missing - skipping';
        RETURN;
    END IF;

    SELECT ceil(COALESCE(sum(pg_tablespace_size(spcname)), 0) / (1024.0 * 1024))::bigint
      INTO used_mb
      FROM pg_tablespace;

    -- Safe interim floor: 3x current usage (=> ~66% free, comfortably outside a
    -- "low disk" band), never below 100 GB. The health monitor refines it to the
    -- true OS capacity on its next run.
    seed := GREATEST(used_mb * 3, 100000);

    SELECT value INTO cur_val FROM config.global_params WHERE key = 'disk_size' LIMIT 1;

    IF cur_val IS NULL THEN
        INSERT INTO config.global_params (key, value) VALUES ('disk_size', seed::text);
        RAISE NOTICE '7330: disk_size missing -> seeded % MB (usage % MB)', seed, used_mb;
        RETURN;
    END IF;

    BEGIN
        cur_num := cur_val::bigint;
    EXCEPTION WHEN others THEN
        cur_num := NULL;
    END;

    IF cur_num IS NULL OR cur_num < used_mb THEN
        UPDATE config.global_params SET value = seed::text WHERE key = 'disk_size';
        RAISE NOTICE '7330: disk_size ''%'' was broken (usage % MB) -> repaired to % MB',
                     cur_val, used_mb, seed;
    ELSE
        RAISE NOTICE '7330: disk_size % MB is sane (usage % MB) - left unchanged',
                     cur_num, used_mb;
    END IF;
END $$;
