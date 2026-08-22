"""Offline security-triage agent.

Ported from dbdiagnostics/resolution_agent (same llama.cpp scaffolding, same
fail-soft posture) but with a different job: instead of writing a tuning report
for a slow query, it decides whether a query that tripped a detection rule is a
genuine SECURITY ALERT or just one of the application's KNOWN transaction
queries.

It answers that by retrieving what this server has actually been running --
monitoring.general_metric_metadata_results -- and grounding the model on that
precedent. A query whose shape the application has run a thousand times is not
an intrusion; one with no precedent on this server is a candidate.

Design rules, all deliberate:
  * FAIL OPEN. Model missing, slow, or broken => the alert fires exactly as it
    does today. A security gate that fails closed is a silent outage.
  * OFF BY DEFAULT. SECURITY_AGENT_ENABLED must be set explicitly; upgrading a
    customer must never silently start suppressing their security alerts.
  * ALWAYS EXPLAIN. Every verdict carries a reason, recorded on both sides of
    the decision. For alerts it is written into alerts.alert_log metadata as
    `reason`; suppressions are recorded too, because a false negative is the
    failure you most need to be able to read back.
"""
