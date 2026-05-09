-- GRC Phase 3: User risk scoring & behaviour baseline
-- Run after grc_phase1_schema.sql

-- ──────────────────────────────────────────────────────────────
-- 1. Per-user behaviour baseline + current risk score
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS monitoring.user_risk_profiles (
    profile_id              SERIAL          PRIMARY KEY,
    server_name             VARCHAR(200)    NOT NULL,
    db_user                 VARCHAR(200)    NOT NULL,

    -- Learned baselines (updated by EMA on every scorer run)
    avg_queries_per_hour    NUMERIC(10,2)   NOT NULL DEFAULT 0,
    typical_hour_start      SMALLINT        NOT NULL DEFAULT 7,    -- 0-23
    typical_hour_end        SMALLINT        NOT NULL DEFAULT 19,   -- 0-23
    typical_tables          TEXT[]          NOT NULL DEFAULT '{}', -- normalised table names seen in queries
    avg_duration_secs       NUMERIC(10,2)   NOT NULL DEFAULT 0,
    avg_logical_reads       NUMERIC(14,2)   NOT NULL DEFAULT 0,

    -- Scoring state
    risk_score              SMALLINT        NOT NULL DEFAULT 0,    -- 0-100
    observation_count       INTEGER         NOT NULL DEFAULT 0,    -- total scorer runs that saw this user
    consecutive_high_risk   SMALLINT        NOT NULL DEFAULT 0,    -- runs in a row with score >= 70

    -- Timestamps
    first_seen_at           TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    last_seen_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    last_updated            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    UNIQUE (server_name, db_user)
);

CREATE INDEX IF NOT EXISTS idx_urp_risk_score
    ON monitoring.user_risk_profiles (risk_score DESC);

CREATE INDEX IF NOT EXISTS idx_urp_server_user
    ON monitoring.user_risk_profiles (server_name, db_user);

-- ──────────────────────────────────────────────────────────────
-- 2. Risk event history (append-only, thin record)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS monitoring.user_risk_events (
    event_id        BIGSERIAL       PRIMARY KEY,
    event_time      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    server_name     VARCHAR(200)    NOT NULL,
    db_user         VARCHAR(200)    NOT NULL,
    risk_score      SMALLINT        NOT NULL,
    risk_factors    JSONB           NOT NULL DEFAULT '{}',  -- {"off_hours":20,"volume_spike":30,...}
    active_sessions INTEGER         NOT NULL DEFAULT 0,
    active_queries  INTEGER         NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_ure_server_user_time
    ON monitoring.user_risk_events (server_name, db_user, event_time DESC);

CREATE INDEX IF NOT EXISTS idx_ure_risk_score
    ON monitoring.user_risk_events (risk_score DESC, event_time DESC);

-- ──────────────────────────────────────────────────────────────
-- 3. Reporting views
-- ──────────────────────────────────────────────────────────────

-- Current top-risk users (live dashboard)
CREATE OR REPLACE VIEW monitoring.v_top_risk_users AS
SELECT  p.server_name,
        p.db_user,
        p.risk_score,
        p.consecutive_high_risk,
        p.observation_count,
        p.avg_queries_per_hour,
        p.typical_hour_start,
        p.typical_hour_end,
        p.last_seen_at
FROM    monitoring.user_risk_profiles p
ORDER   BY p.risk_score DESC, p.consecutive_high_risk DESC;

-- Risk score trend (last 24 h per user)
CREATE OR REPLACE VIEW monitoring.v_risk_score_trend AS
SELECT  server_name,
        db_user,
        DATE_TRUNC('hour', event_time) AS hour_bucket,
        AVG(risk_score)::SMALLINT       AS avg_risk,
        MAX(risk_score)                 AS peak_risk,
        SUM(active_queries)             AS total_queries
FROM    monitoring.user_risk_events
WHERE   event_time >= NOW() - INTERVAL '24 hours'
GROUP BY server_name, db_user, DATE_TRUNC('hour', event_time)
ORDER BY hour_bucket DESC, peak_risk DESC;

-- SOC2 CC6.3 report feed — high-risk user events
CREATE OR REPLACE VIEW log.v_rpt_soc2_high_risk_users AS
SELECT  e.event_time,
        e.server_name,
        e.db_user,
        e.risk_score,
        e.risk_factors,
        e.active_sessions,
        e.active_queries
FROM    monitoring.user_risk_events e
WHERE   e.risk_score >= 70
ORDER   BY e.risk_score DESC, e.event_time DESC;

-- ──────────────────────────────────────────────────────────────
-- 4. Register the scorer as a scheduled process (every 5 min)
-- ──────────────────────────────────────────────────────────────
INSERT INTO metrics.registered_processes (process_name, interval, is_active, description)
VALUES ('user_risk_scoring', 300, TRUE,
        'GRC Phase 3: user behaviour baseline learning and risk scoring (5-min interval)')
ON CONFLICT (process_name) DO UPDATE
    SET interval    = EXCLUDED.interval,
        is_active   = EXCLUDED.is_active,
        description = EXCLUDED.description;
