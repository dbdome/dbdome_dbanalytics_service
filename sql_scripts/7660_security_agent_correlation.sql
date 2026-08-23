-- =============================================================================
-- 7660_security_agent_correlation.sql
--
-- Store the security agent's SECOND evidence arm: corroboration and novelty.
--
-- WHY
--   Until now the agent judged an alert on statement precedent alone -- "has
--   this server run something shaped like this before?". That answers whether
--   the QUERY is familiar, not whether the FINDING is real. Two questions were
--   missing, and both are answerable from alerts.alert_log:
--
--     CORROBORATION  What else fired on this server in the same window? A
--                    detection arriving inside an unusual cluster is far
--                    stronger evidence than one arriving alone.
--     NOVELTY        Has this root cause, on this server, for this login, at
--                    this hour, happened before? A rule that has fired hourly
--                    for six weeks is background; its first appearance is not.
--
--   security_agent/correlation.py computes both. These columns keep the result
--   so a verdict can be re-examined later: was the model wrong, or was it given
--   thin evidence?
--
-- TWO MEASUREMENTS THAT SHAPED THE DESIGN, recorded here because they are not
-- obvious from the code:
--
--   1. RAW CO-OCCURRENCE COUNTS ARE MEANINGLESS. On the development database a
--      single hour on SIM-ORACLE contained 1,489 distinct root causes, and
--      192.168.1.229 ran at 660/hour. Storing "37 other findings" would make
--      every alert look maximally corroborated. correlation_ratio is therefore
--      the cluster measured against THAT SERVER's own baseline density, and it
--      is the ratio -- not the count -- that carries meaning.
--
--   2. login_name IS ALMOST NEVER POPULATED: 1 row in 162,997 on the same
--      database. A history query that treats NULL as "this login has never done
--      this before" manufactures a novelty signal on essentially every alert.
--      The flag `login_not_attributed` records that the question could not be
--      asked, which is a different statement from "the login is new".
--
-- SAFE TO RE-RUN.
-- =============================================================================

ALTER TABLE alerts.security_agent_verdict
    ADD COLUMN IF NOT EXISTS correlation jsonb NOT NULL DEFAULT '{}'::jsonb;

-- The derived signals, denormalized out of the jsonb so they are queryable and
-- indexable without digging into the document on every row.
ALTER TABLE alerts.security_agent_verdict
    ADD COLUMN IF NOT EXISTS correlation_flags text[] NOT NULL DEFAULT '{}';

-- Cluster size in the window, and that size relative to the server's own
-- baseline. Both, because the count alone cannot be interpreted (see note 1).
ALTER TABLE alerts.security_agent_verdict
    ADD COLUMN IF NOT EXISTS concurrent_root_causes integer;

ALTER TABLE alerts.security_agent_verdict
    ADD COLUMN IF NOT EXISTS correlation_ratio numeric(8,2);

-- How established this rule is on this server: total firings in the history
-- window, and how many distinct days it was seen on. A rule seen 400 times
-- across 1 day is a burst; 400 across 40 days is furniture.
ALTER TABLE alerts.security_agent_verdict
    ADD COLUMN IF NOT EXISTS rule_history_count integer;

ALTER TABLE alerts.security_agent_verdict
    ADD COLUMN IF NOT EXISTS rule_history_days integer;

COMMENT ON COLUMN alerts.security_agent_verdict.correlation IS
    'Full output of security_agent.correlation.gather(): concurrent cluster, '
    'rule/login/hour history, and derived flags.';
COMMENT ON COLUMN alerts.security_agent_verdict.correlation_ratio IS
    'Distinct co-occurring root causes divided by this server''s own baseline '
    'density. NULL = no baseline available, which is NOT the same as isolated.';
COMMENT ON COLUMN alerts.security_agent_verdict.correlation_flags IS
    'Derived signals, e.g. first_occurrence_on_this_server, '
    'clustered_with_other_findings, burst_vs_own_history, '
    'unusual_hour_for_this_rule, login_not_attributed.';

-- GIN over the flag array: "show me every verdict that was corroborated by a
-- cluster" / "...that was a first occurrence" are the review queries.
CREATE INDEX IF NOT EXISTS ix_sav_correlation_flags
    ON alerts.security_agent_verdict USING gin (correlation_flags);


-- ---------------------------------------------------------------------------
-- Review view: where correlation and the model disagree
-- ---------------------------------------------------------------------------
-- The point of the second arm is to catch the case the model got wrong. The
-- interesting rows are those the model called KNOWN_QUERY while correlation
-- says the finding is novel or corroborated -- i.e. candidate false negatives.
CREATE OR REPLACE VIEW alerts.v_security_agent_correlation AS
SELECT v.verdict_id,
       v.entry_date,
       v.server,
       v.root_cause_id,
       v.verdict,
       v.confidence,
       v.decided_by,
       v.concurrent_root_causes,
       v.correlation_ratio,
       v.rule_history_count,
       v.rule_history_days,
       v.correlation_flags,
       (v.correlation_flags && ARRAY['first_occurrence_on_this_server',
                                     'rare_on_this_server',
                                     'burst_vs_own_history',
                                     'clustered_with_other_findings',
                                     'unusual_hour_for_this_rule',
                                     'first_time_this_login_tripped_this_rule']
       ) AS correlation_suggests_real,
       (v.verdict = 'KNOWN_QUERY'
        AND v.correlation_flags && ARRAY['first_occurrence_on_this_server',
                                         'burst_vs_own_history',
                                         'clustered_with_other_findings',
                                         'unusual_hour_for_this_rule']
       ) AS review_candidate,
       v.reason
FROM alerts.security_agent_verdict v;

COMMENT ON VIEW alerts.v_security_agent_correlation IS
    'Security-agent verdicts with their correlation evidence. review_candidate '
    'flags rows the model called KNOWN_QUERY while the corroboration/novelty '
    'arm suggested otherwise - the candidate false negatives worth reading.';


DO $mig$
DECLARE
    v_missing text;
BEGIN
    SELECT string_agg(c, ', ') INTO v_missing
      FROM unnest(ARRAY['correlation','correlation_flags','concurrent_root_causes',
                        'correlation_ratio','rule_history_count','rule_history_days']) AS c
     WHERE NOT EXISTS (SELECT 1 FROM information_schema.columns
                        WHERE table_schema='alerts'
                          AND table_name='security_agent_verdict'
                          AND column_name=c);
    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION '7660: column(s) not added: %', v_missing;
    END IF;

    RAISE NOTICE '7660: correlation columns added to alerts.security_agent_verdict; '
                 'review with SELECT * FROM alerts.v_security_agent_correlation '
                 'WHERE review_candidate;';
END $mig$;
