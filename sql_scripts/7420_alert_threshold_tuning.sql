-- ============================================================================
-- 7420_alert_threshold_tuning.sql
--
-- Adaptive alert thresholds: when the same root cause keeps alerting on the
-- same server with the same magnitude, raise that server's threshold just past
-- what was actually observed, so the steady state stops paging while a genuine
-- step-change still fires.
--
-- Design notes
--   * rootcause.detection_steps.parameters is GLOBAL (shared by every server
--     and vendor). It is NEVER written here. Overrides live per
--     (server, root_cause_id, step_name, param_name) in
--     rootcause.parameter_tuning, so a noisy server goes quiet on its own and
--     rollback is one DELETE.
--   * The new value is learned from alerts.alert_log.metadata - the actual
--     collected rows - not from a blind multiplier.
--   * To learn a value we must know WHICH metadata column the parameter is
--     compared against. That is derived from expected.condition (e.g.
--     "avg_reads > :read_threshold" -> observed_key = 'avg_reads'). When the
--     condition is prose rather than an expression the mapping cannot be
--     derived; the row is recorded with needs_mapping = true and is NOT tuned.
--     Nothing is ever guessed.
--
-- Idempotent. Safe to re-run.
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS rootcause;

-- ---------------------------------------------------------------------------
-- 1. Override table
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rootcause.parameter_tuning (
    row_id           bigserial PRIMARY KEY,
    server           character varying(100) NOT NULL,
    root_cause_id    character varying(100) NOT NULL,
    step_name        character varying(300) NOT NULL,
    param_name       text                   NOT NULL,
    base_value       numeric,                       -- as shipped in detection_steps
    current_value    numeric,                       -- what the collector must use
    observed_key     text,                          -- metadata column the param is compared to
    observed_max     numeric,                       -- highest value seen in the window
    recurrence_count integer NOT NULL DEFAULT 0,
    raise_count      integer NOT NULL DEFAULT 0,
    needs_mapping    boolean NOT NULL DEFAULT false,-- true = condition not machine-readable
    is_active        boolean NOT NULL DEFAULT true, -- false = override ignored (manual off switch)
    last_raised_at   timestamp without time zone,
    created_at       timestamp without time zone NOT NULL DEFAULT now(),
    updated_at       timestamp without time zone NOT NULL DEFAULT now(),
    CONSTRAINT parameter_tuning_uq UNIQUE (server, root_cause_id, step_name, param_name)
);

CREATE INDEX IF NOT EXISTS ix_parameter_tuning_lookup
    ON rootcause.parameter_tuning (server, root_cause_id) WHERE is_active;

COMMENT ON TABLE rootcause.parameter_tuning IS
  'Per-server threshold overrides learned from recurring alerts. detection_steps.parameters is never modified.';

-- audit trail: every raise, so a human can see how a threshold drifted
CREATE TABLE IF NOT EXISTS rootcause.parameter_tuning_audit (
    row_id         bigserial PRIMARY KEY,
    tuning_row_id  bigint,
    server         character varying(100) NOT NULL,
    root_cause_id  character varying(100) NOT NULL,
    step_name      character varying(300) NOT NULL,
    param_name     text NOT NULL,
    old_value      numeric,
    new_value      numeric,
    observed_max   numeric,
    recurrences    integer,
    reason         text,
    changed_at     timestamp without time zone NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_parameter_tuning_audit_when
    ON rootcause.parameter_tuning_audit (changed_at);

-- ---------------------------------------------------------------------------
-- 2. Tuning knobs (config.global_params, same pattern as disk_size)
-- ---------------------------------------------------------------------------
INSERT INTO config.global_params (key, value)
SELECT v.key, v.value
FROM (VALUES
    ('tuning_enabled',           'false'),  -- master switch, OFF until you turn it on
    ('tuning_min_recurrences',   '5'),      -- alerts for the same (server, rc) before tuning
    ('tuning_window_hours',      '168'),    -- look-back window (7 days)
    ('tuning_margin_pct',        '10'),     -- headroom above observed max
    ('tuning_max_raise_multiple','4'),      -- hard cap: never exceed base * this
    ('tuning_max_raises',        '5'),      -- per (server, rc, param) lifetime raises
    ('tuning_cooldown_hours',    '24')      -- min gap between raises of the same param
) AS v(key, value)
WHERE NOT EXISTS (
    SELECT 1 FROM config.global_params g WHERE g.key = v.key
);

-- ---------------------------------------------------------------------------
-- 3. Derive the observed column from a condition expression
--    "avg_reads > :read_threshold"                    -> avg_reads
--    "total_connections > max_connections * :pct/100"  -> total_connections
--    "Queries scanning all partitions"                 -> NULL (prose)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION rootcause.f_param_observed_key(p_condition text, p_param text)
RETURNS text
LANGUAGE plpgsql IMMUTABLE
AS $$
DECLARE
    m text[];
BEGIN
    IF p_condition IS NULL OR p_param IS NULL THEN
        RETURN NULL;
    END IF;

    -- <identifier> <comparison> ... :param     (identifier is the observed column)
    m := regexp_match(
            p_condition,
            '([A-Za-z_][A-Za-z0-9_\.]*)\s*(?:>=|<=|>|<|=)\s*[^<>=]*?:' || p_param || '\M'
         );
    IF m IS NOT NULL THEN
        -- strip a table alias if present: a.avg_reads -> avg_reads
        RETURN split_part(m[1], '.', greatest(1, array_length(string_to_array(m[1], '.'), 1)));
    END IF;

    -- reversed form:  :param < avg_reads
    m := regexp_match(
            p_condition,
            ':' || p_param || '\M\s*(?:>=|<=|>|<|=)\s*([A-Za-z_][A-Za-z0-9_\.]*)'
         );
    IF m IS NOT NULL THEN
        RETURN split_part(m[1], '.', greatest(1, array_length(string_to_array(m[1], '.'), 1)));
    END IF;

    RETURN NULL;   -- prose condition; caller must flag needs_mapping
END;
$$;

-- ---------------------------------------------------------------------------
-- 4. Effective parameters for a server = base jsonb with overrides applied.
--    The collector calls this instead of using detection_steps.parameters raw.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION rootcause.effective_parameters(
    p_server        text,
    p_root_cause_id text,
    p_step_name     text,
    p_base          jsonb
)
RETURNS jsonb
LANGUAGE sql STABLE
AS $$
    -- p_base may be an ENCRYPTED jsonb string scalar (7300) when the session has
    -- no rootcause.k key, or NULL when dec() withheld it. jsonb_each would raise
    -- "cannot call jsonb_each on a non-object" - guard, and pass it through
    -- untouched rather than corrupting it.
    SELECT COALESCE(
        (SELECT jsonb_object_agg(k, v)
         FROM (
             SELECT b.key AS k,
                    COALESCE(to_jsonb(t.current_value), b.value) AS v
             FROM jsonb_each(CASE WHEN jsonb_typeof(p_base) = 'object'
                                  THEN p_base ELSE '{}'::jsonb END) b
             LEFT JOIN rootcause.parameter_tuning t
                    ON t.server        = p_server
                   AND t.root_cause_id = p_root_cause_id
                   AND t.step_name     = p_step_name
                   AND t.param_name    = b.key
                   AND t.is_active
                   AND t.current_value IS NOT NULL
         ) x),
        p_base
    );
$$;

COMMENT ON FUNCTION rootcause.effective_parameters(text, text, text, jsonb) IS
  'Overlay per-server learned thresholds onto a detection step''s base parameters.';

-- ---------------------------------------------------------------------------
-- 5. The tuner. Returns the number of parameters raised.
--    Runs read-only against alert_log; only writes parameter_tuning(+audit).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION rootcause.tune_alert_thresholds()
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    c_enabled     boolean;
    c_min_recur   integer;
    c_window_h    integer;
    c_margin      numeric;
    c_max_mult    numeric;
    c_max_raises  integer;
    c_cooldown_h  integer;
    r             record;
    v_obs_key     text;
    v_obs_max     numeric;
    v_base        numeric;
    v_current     numeric;
    v_new         numeric;
    v_cap         numeric;
    v_tuning_id   bigint;
    v_raise_count integer;
    v_raised      integer := 0;   -- return value; must NOT be reused as scratch
BEGIN
    SELECT COALESCE((SELECT value FROM config.global_params WHERE key='tuning_enabled'),'false')::boolean,
           COALESCE((SELECT value FROM config.global_params WHERE key='tuning_min_recurrences'),'5')::int,
           COALESCE((SELECT value FROM config.global_params WHERE key='tuning_window_hours'),'168')::int,
           COALESCE((SELECT value FROM config.global_params WHERE key='tuning_margin_pct'),'10')::numeric,
           COALESCE((SELECT value FROM config.global_params WHERE key='tuning_max_raise_multiple'),'4')::numeric,
           COALESCE((SELECT value FROM config.global_params WHERE key='tuning_max_raises'),'5')::int,
           COALESCE((SELECT value FROM config.global_params WHERE key='tuning_cooldown_hours'),'24')::int
      INTO c_enabled, c_min_recur, c_window_h, c_margin, c_max_mult, c_max_raises, c_cooldown_h;

    IF NOT c_enabled THEN
        RETURN 0;
    END IF;

    -- rootcause.detection_steps.parameters is ENCRYPTED on this install (7300):
    -- the column holds a jsonb string scalar carrying a PGP blob, and
    -- rootcause.dec() withholds plaintext from a session with no rootcause.k.
    -- v_rootcauses is measured to expose plaintext objects regardless, so this
    -- is a WARNING, not a block - the object-type guard in the loop below is
    -- what actually keeps ciphertext out. Callers should still connect with
    -- options=-c rootcause.k=<key>; get_connection_string() injects it.
    IF rootcause._key() IS NULL THEN
        RAISE WARNING 'tune_alert_thresholds: no rootcause.k in session; any still-encrypted detection parameters will be skipped';
    END IF;

    -- every (server, root_cause) that has recurred enough, x every numeric
    -- parameter of its detection steps
    FOR r IN
        WITH recur AS (
            SELECT al.server,
                   al.root_cause_id,
                   count(*) AS recurrences
            FROM alerts.alert_log al
            WHERE al.entry_date >= now() - make_interval(hours => c_window_h)
            GROUP BY al.server, al.root_cause_id
            HAVING count(*) >= c_min_recur
        )
        SELECT recur.server,
               recur.root_cause_id,
               recur.recurrences,
               rc.step_name,
               rc.expected ->> 'condition' AS condition,
               p.key   AS param_name,
               p.value AS param_value
        FROM recur
        JOIN rootcause.v_rootcauses rc ON rc.root_cause_id = recur.root_cause_id
        -- guard INSIDE the lateral: rc.parameters is a jsonb string scalar when
        -- still encrypted, and jsonb_each() errors on any non-object
        CROSS JOIN LATERAL jsonb_each(
            CASE WHEN jsonb_typeof(rc.parameters) = 'object'
                 THEN rc.parameters ELSE '{}'::jsonb END
        ) p
        WHERE jsonb_typeof(p.value) = 'number'
    LOOP
        v_obs_key := rootcause.f_param_observed_key(r.condition, r.param_name);

        -- Condition is prose -> we cannot learn a value. Record it so a human
        -- can supply observed_key, but never invent one.
        IF v_obs_key IS NULL THEN
            INSERT INTO rootcause.parameter_tuning
                   (server, root_cause_id, step_name, param_name,
                    base_value, recurrence_count, needs_mapping, is_active)
            VALUES (r.server, r.root_cause_id, r.step_name, r.param_name,
                    (r.param_value #>> '{}')::numeric, r.recurrences, true, false)
            ON CONFLICT (server, root_cause_id, step_name, param_name)
            DO UPDATE SET recurrence_count = EXCLUDED.recurrence_count,
                          needs_mapping    = true,
                          updated_at       = now();
            CONTINUE;
        END IF;

        -- highest value actually observed for that column across the window
        SELECT max(val) INTO v_obs_max
        FROM (
            SELECT NULLIF(elem ->> v_obs_key, '') AS raw
            FROM alerts.alert_log al
            CROSS JOIN LATERAL jsonb_array_elements(al.metadata) elem
            WHERE al.server        = r.server
              AND al.root_cause_id = r.root_cause_id
              AND al.entry_date   >= now() - make_interval(hours => c_window_h)
              AND jsonb_typeof(al.metadata) = 'array'
        ) s
        CROSS JOIN LATERAL (
            SELECT CASE WHEN s.raw ~ '^-?[0-9]+(\.[0-9]+)?$' THEN s.raw::numeric END AS val
        ) v;

        IF v_obs_max IS NULL THEN
            CONTINUE;    -- column absent or non-numeric in the payload
        END IF;

        v_base := (r.param_value #>> '{}')::numeric;

        SELECT current_value, raise_count, row_id
          INTO v_current, v_raise_count, v_tuning_id
        FROM rootcause.parameter_tuning
        WHERE server = r.server AND root_cause_id = r.root_cause_id
          AND step_name = r.step_name AND param_name = r.param_name;

        v_current := COALESCE(v_current, v_base);

        -- cooldown / lifetime-raise guards
        IF EXISTS (
            SELECT 1 FROM rootcause.parameter_tuning
            WHERE server = r.server AND root_cause_id = r.root_cause_id
              AND step_name = r.step_name AND param_name = r.param_name
              AND (raise_count >= c_max_raises
                   OR (last_raised_at IS NOT NULL
                       AND last_raised_at > now() - make_interval(hours => c_cooldown_h)))
        ) THEN
            CONTINUE;
        END IF;

        v_new := ceil(v_obs_max * (1 + c_margin / 100.0));
        v_cap := v_base * c_max_mult;
        IF v_new > v_cap THEN
            v_new := v_cap;
        END IF;

        -- only ever raise, never lower, and never no-op
        IF v_new <= v_current THEN
            CONTINUE;
        END IF;

        INSERT INTO rootcause.parameter_tuning
               (server, root_cause_id, step_name, param_name, base_value,
                current_value, observed_key, observed_max, recurrence_count,
                raise_count, needs_mapping, is_active, last_raised_at, updated_at)
        VALUES (r.server, r.root_cause_id, r.step_name, r.param_name, v_base,
                v_new, v_obs_key, v_obs_max, r.recurrences,
                1, false, true, now(), now())
        ON CONFLICT (server, root_cause_id, step_name, param_name)
        DO UPDATE SET current_value    = EXCLUDED.current_value,
                      observed_key     = EXCLUDED.observed_key,
                      observed_max     = EXCLUDED.observed_max,
                      recurrence_count = EXCLUDED.recurrence_count,
                      raise_count      = rootcause.parameter_tuning.raise_count + 1,
                      needs_mapping    = false,
                      is_active        = true,
                      last_raised_at   = now(),
                      updated_at       = now()
        RETURNING row_id INTO v_tuning_id;

        INSERT INTO rootcause.parameter_tuning_audit
               (tuning_row_id, server, root_cause_id, step_name, param_name,
                old_value, new_value, observed_max, recurrences, reason)
        VALUES (v_tuning_id, r.server, r.root_cause_id, r.step_name, r.param_name,
                v_current, v_new, v_obs_max, r.recurrences,
                format('recurred %s times in %sh; observed max %s on %s; raised with %s%% margin',
                       r.recurrences, c_window_h, v_obs_max, v_obs_key, c_margin));

        v_raised := v_raised + 1;
    END LOOP;

    RETURN v_raised;
END;
$$;

-- ---------------------------------------------------------------------------
-- 6. Inspection view (Grafana / UI)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW rootcause.v_parameter_tuning AS
SELECT t.server,
       t.root_cause_id,
       t.step_name,
       t.param_name,
       t.base_value,
       t.current_value,
       CASE WHEN t.base_value IS NULL OR t.base_value = 0 THEN NULL
            ELSE round(t.current_value / t.base_value, 2) END AS raise_factor,
       t.observed_key,
       t.observed_max,
       t.recurrence_count,
       t.raise_count,
       t.needs_mapping,
       t.is_active,
       t.last_raised_at,
       t.updated_at
FROM rootcause.parameter_tuning t;

-- ---------------------------------------------------------------------------
-- 7. Register the scheduled process (hourly). is_active = false to match the
--    tuning_enabled master switch - turn both on deliberately.
-- ---------------------------------------------------------------------------
INSERT INTO metrics.registered_processes (process_name, is_active)
SELECT 'alert_threshold_tuner', false
WHERE NOT EXISTS (
    SELECT 1 FROM metrics.registered_processes WHERE process_name = 'alert_threshold_tuner'
);

-- ---------------------------------------------------------------------------
-- ROLLBACK (manual)
--   -- undo one server's learned thresholds:
--   DELETE FROM rootcause.parameter_tuning WHERE server = '<server>';
--   -- undo everything, keep the audit trail:
--   UPDATE rootcause.parameter_tuning SET is_active = false;
--   -- stop tuning:
--   UPDATE config.global_params SET value='false' WHERE key='tuning_enabled';
-- ---------------------------------------------------------------------------
