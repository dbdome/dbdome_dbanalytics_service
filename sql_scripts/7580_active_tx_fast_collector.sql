-- =============================================================================
-- 7580_active_tx_fast_collector.sql
-- Register the dedicated 30s collector for SEC-SQL-ACC-011-RC02 and hand the
-- root cause off to it from the generic sweep.
--
-- WHY
--   Measured on 192.168.1.222 against 192.168.200.50 (2026-08-15):
--     * the metric's own query runs in 0.38s (branch A 0.19s, branch B 0.34s,
--       797 rows) - it is NOT slow
--     * but it sits in the SEC sweep behind ~1,695 active mssql metrics that run
--       SEQUENTIALLY, so consecutive runs were 328s / 331s / 335s / 341s / 368s /
--       372s apart, with outliers at 747s and 858s - about 90 executions/day
--     * BOTH branches look back only 60 SECONDS
--       (`DATEADD(SECOND, -60, GETDATE())`), so at that spacing the metric
--       observes its window ~7-18% of the time and MISSES over 80% of the
--       transactions and statements it exists to detect
--   This is a coverage hole, not a latency annoyance. Cadence must stay <= 60s.
--
-- HOW
--   collect_metrics_operation_active_tx() reuses the existing per-server thread
--   pool (_run_domain_collection) scoped to this one root cause, so the insert,
--   comparison and alert paths are untouched.
--
-- THE EXCLUSION IS NOT OPTIONAL
--   config.global_params('dedicated_collector_rcs') is what the generic mssql
--   collector reads to EXCLUDE these root causes. Without it BOTH the sweep and
--   this process write the same metric_name into gmmr every cycle - duplicate
--   rows and duplicate alerts, with nothing in the row to tell them apart.
--   Keep this list in step with collect_metrics.ACTIVE_TX_RC.
--
-- VOLUME
--   ~797 rows/execution. At 30s that is ~2,880 runs/day/server (~2.3M rows) vs
--   ~90 runs/day today. The collector is called with skip_unchanged=True, so a
--   sample identical to the previous one is NOT stored - gmmr.entry_date is the
--   onset of a state, not a heartbeat. The alert comparison still runs on every
--   sample, so suppressing a duplicate row cannot suppress a finding.
--
-- Idempotent.
-- =============================================================================

-- 1) the scheduled process. sync_jobs() reads is_active/interval every config
--    watcher tick, so both are live knobs - no service restart needed.
INSERT INTO metrics.registered_processes (process_name, is_active, interval, description)
SELECT 'active_tx_fast_collect', true, 30,
       'Dedicated collector for SEC-SQL-ACC-011-RC02 (active transactions). One '
       'worker thread per active server, reusing the generic collector path. The '
       'query looks back only 60s, so the interval MUST stay <= 60s or activity '
       'is missed between runs. Excluded from the generic sweep via '
       'config.global_params(dedicated_collector_rcs).'
WHERE NOT EXISTS (SELECT 1 FROM metrics.registered_processes
                   WHERE process_name = 'active_tx_fast_collect');

-- 2) hand the root cause off - the generic sweep now skips it
INSERT INTO config.global_params (key, value)
SELECT 'dedicated_collector_rcs', 'SEC-SQL-ACC-011-RC02'
WHERE NOT EXISTS (SELECT 1 FROM config.global_params
                   WHERE key = 'dedicated_collector_rcs');

-- 3) report the resulting state
DO $mig$
DECLARE
    v_int  int;
    v_act  boolean;
    v_ded  text;
BEGIN
    SELECT interval, is_active INTO v_int, v_act
      FROM metrics.registered_processes WHERE process_name = 'active_tx_fast_collect';
    SELECT value INTO v_ded FROM config.global_params WHERE key = 'dedicated_collector_rcs';

    IF v_int IS NULL THEN
        RAISE EXCEPTION '7580: active_tx_fast_collect was not registered';
    END IF;
    IF v_ded IS NULL OR position('SEC-SQL-ACC-011-RC02' in v_ded) = 0 THEN
        RAISE EXCEPTION '7580: dedicated_collector_rcs does not list SEC-SQL-ACC-011-RC02 - '
                        'the generic sweep would double-collect it';
    END IF;
    IF v_int > 60 THEN
        RAISE WARNING '7580: interval is % - the query only looks back 60s, so activity '
                      'will be missed between runs', v_int;
    END IF;

    RAISE NOTICE '7580: active_tx_fast_collect registered (interval=%, is_active=%); '
                 'dedicated_collector_rcs=%', v_int, v_act, v_ded;
END $mig$;
