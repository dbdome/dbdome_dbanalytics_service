-- =============================================================================
-- 7640_security_agent_annotate_process.sql
--
-- Register the security agent's annotation sweep as a scheduled process, and
-- move triage OFF the alert path.
--
-- WHY
--   Triage used to run inside the collector, between a detection firing and the
--   alert being dispatched. Every alert therefore waited for a language model on
--   CPU. Measured in production on 2026-08-22:
--       decided_by=timeout           11 alerts, avg 135,012 ms
--       decided_by=model (ollama)     1 alert,     108,217 ms
--   against 20.8s warm for the same three cases on an idle box. Nothing was ever
--   lost - the agent fails open - but alert DISPATCH was being delayed by up to
--   two minutes, which is the wrong thing for a security product to trade away.
--
--   With SECURITY_AGENT_ANNOTATE_INLINE=false (the new default) the collector
--   writes the alert immediately and this sweep adds the verdict seconds later.
--   Latency stops being something to tune.
--
-- INTERVAL
--   60s. The sweep annotates up to SECURITY_AGENT_ANNOTATE_BATCH (25) alerts per
--   run at ~25s each, so a burst drains over a few minutes rather than one run
--   holding the model while everything else waits.
--
-- Idempotent.
-- =============================================================================

INSERT INTO metrics.registered_processes (process_name, is_active, interval, description)
SELECT 'security_agent_annotate', true, 60,
       'Annotates alerts raised without a security-agent verdict: adds `reason` '
       'to alerts.alert_log.metadata and records the decision in '
       'alerts.security_agent_verdict. Runs AFTER the alert is dispatched, so '
       'triage never delays alerting. Does nothing unless '
       'SECURITY_AGENT_ENABLED=true in bin\.env.'
WHERE NOT EXISTS (SELECT 1 FROM metrics.registered_processes
                   WHERE process_name = 'security_agent_annotate');

-- Already registered but switched off by a previous run? Leave the operator's
-- choice alone; only the description is refreshed.
UPDATE metrics.registered_processes
   SET description = 'Annotates alerts raised without a security-agent verdict: '
                     'adds `reason` to alerts.alert_log.metadata and records the '
                     'decision in alerts.security_agent_verdict. Runs AFTER the '
                     'alert is dispatched, so triage never delays alerting.'
 WHERE process_name = 'security_agent_annotate';


DO $mig$
DECLARE
    v_int int;
    v_act boolean;
    v_fn  int;
BEGIN
    SELECT interval, is_active INTO v_int, v_act
      FROM metrics.registered_processes WHERE process_name = 'security_agent_annotate';

    IF v_int IS NULL THEN
        RAISE EXCEPTION '7640: security_agent_annotate was not registered';
    END IF;

    -- The sweep queries monitoring.fn_metadata_object(); without 7630 it would
    -- fail on every run, so fail here instead where it is obvious why.
    SELECT count(*) INTO v_fn
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'monitoring' AND p.proname = 'fn_metadata_object';

    IF v_fn = 0 THEN
        RAISE EXCEPTION '7640: monitoring.fn_metadata_object() is missing - apply '
                        'sql_scripts/7630_security_agent_resultset.sql first';
    END IF;

    RAISE NOTICE '7640: security_agent_annotate registered (interval=%s, is_active=%). '
                 'Triage now runs after alert dispatch, not inside it.', v_int, v_act;
END $mig$;
