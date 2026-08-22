-- =============================================================================
-- 7600_security_agent_verdict.sql
--
-- Audit trail for the offline security-triage agent (security_agent/).
--
-- WHY THIS TABLE EXISTS
--   The agent can SUPPRESS an alert it judges to be normal application traffic.
--   A suppressed alert never reaches alerts.alert_log -- that is the point --
--   which means without a separate record a false negative would be invisible
--   forever. Every decision is written here, raised and suppressed alike, so
--   the gate can be audited and tuned instead of trusted blindly.
--
--   Alerts that ARE raised additionally carry the rationale inline, as
--   `reason` inside alerts.alert_log.metadata, so a DBA reading the alert sees
--   why it survived triage without joining anything.
--
-- SAFE TO RE-RUN. Creates nothing that already exists.
-- =============================================================================

CREATE TABLE IF NOT EXISTS alerts.security_agent_verdict (
    verdict_id          bigserial PRIMARY KEY,
    entry_date          timestamp        NOT NULL DEFAULT LOCALTIMESTAMP,

    server              varchar(256)     NOT NULL,
    root_cause_id       varchar(128),
    metric_name         varchar(256),

    -- The statement that was judged, plus its literal-free fingerprint. The
    -- fingerprint is what makes "how often has this same shape been suppressed"
    -- answerable without re-normalizing 20 KB of text per row.
    query_text          text,
    query_fingerprint   varchar(32),

    verdict             varchar(24)      NOT NULL,   -- SECURITY_ALERT | KNOWN_QUERY
    confidence          numeric(4,3),
    reason              text,
    indicators          jsonb            NOT NULL DEFAULT '[]'::jsonb,
    matched_precedent   boolean,

    -- What the retrieval actually found, kept so a bad verdict can be explained
    -- after the fact: was the model wrong, or was it starved of precedent?
    exact_matches       integer          NOT NULL DEFAULT 0,
    distinct_shapes     integer          NOT NULL DEFAULT 0,
    candidates_searched integer          NOT NULL DEFAULT 0,
    retrieval_method    varchar(32),

    model               varchar(256),
    elapsed_ms          integer,
    -- model | privileged_shape | model_unavailable | timeout | generation_error |
    -- low_confidence_override | no_query
    decided_by          varchar(40),

    raised              boolean          NOT NULL,
    alert_row_id        integer,

    CONSTRAINT ck_security_agent_verdict CHECK (verdict IN ('SECURITY_ALERT', 'KNOWN_QUERY'))
);

COMMENT ON TABLE alerts.security_agent_verdict IS
    'Every security_agent triage decision. Suppressed alerts appear ONLY here, '
    'so this is the audit trail for what the gate silenced.';
COMMENT ON COLUMN alerts.security_agent_verdict.raised IS
    'TRUE = the alert was written to alerts.alert_log. FALSE = suppressed as known traffic.';
COMMENT ON COLUMN alerts.security_agent_verdict.decided_by IS
    'Which path produced the verdict. Anything other than ''model'' means the '
    'decision was deterministic, usually a fail-open.';

-- Reviewing what was silenced, newest first, is the query this table exists for.
CREATE INDEX IF NOT EXISTS ix_sav_suppressed
    ON alerts.security_agent_verdict (entry_date DESC)
    WHERE raised IS FALSE;

CREATE INDEX IF NOT EXISTS ix_sav_server_rc_date
    ON alerts.security_agent_verdict (server, root_cause_id, entry_date DESC);

-- "is this fingerprint always suppressed?" -- the tuning question.
CREATE INDEX IF NOT EXISTS ix_sav_fingerprint
    ON alerts.security_agent_verdict (query_fingerprint, entry_date DESC);


-- -----------------------------------------------------------------------------
-- Review view: what the gate silenced, and on what evidence.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW alerts.v_security_agent_suppressed AS
SELECT v.entry_date,
       v.server,
       v.root_cause_id,
       v.metric_name,
       v.confidence,
       v.reason,
       v.exact_matches,
       v.distinct_shapes,
       v.retrieval_method,
       v.decided_by,
       v.elapsed_ms,
       left(v.query_text, 400) AS query_preview,
       v.query_fingerprint
FROM alerts.security_agent_verdict v
WHERE v.raised IS FALSE
ORDER BY v.entry_date DESC;

COMMENT ON VIEW alerts.v_security_agent_suppressed IS
    'Alerts the security agent suppressed as known application traffic. Review '
    'this regularly: a wrong entry here is a missed security alert.';


-- -----------------------------------------------------------------------------
-- Effectiveness summary: is the gate earning its place, per root cause?
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW alerts.v_security_agent_summary AS
SELECT server,
       root_cause_id,
       count(*)                                             AS decisions,
       count(*) FILTER (WHERE raised IS FALSE)              AS suppressed,
       round(100.0 * count(*) FILTER (WHERE raised IS FALSE)
             / NULLIF(count(*), 0), 1)                      AS suppressed_pct,
       count(*) FILTER (WHERE decided_by <> 'model')        AS non_model_decisions,
       round(avg(elapsed_ms)::numeric, 0)                   AS avg_ms,
       max(entry_date)                                      AS last_seen
FROM alerts.security_agent_verdict
GROUP BY server, root_cause_id
ORDER BY suppressed DESC;

COMMENT ON VIEW alerts.v_security_agent_summary IS
    'Per root-cause suppression rate. A rate near 100% means the rule itself is '
    'miscalibrated; a high non_model_decisions count means the agent is failing '
    'open rather than actually triaging.';
