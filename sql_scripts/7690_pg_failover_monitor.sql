-- ============================================================
-- PostgreSQL primary-down detector for DBDOME's own store (HA/DR, Tier 1).
--
-- Companion to the PG_HOST=primary,alternate failover DSN. The scheduled
-- process 'pg_failover_monitor' (processes.pg_failover_monitor) watches the
-- primary and, after N consecutive failures, emails the alert recipients the
-- exact promote command to run. It NEVER promotes automatically (no split-brain
-- risk); promotion stays a human decision.
--
-- Creates:
--   * config.pg_failover_monitor  - singleton config + state row
--   * log.pg_failover_events      - event ledger
--   * registers the 'pg_failover_monitor' process (60s, active)
-- Idempotent.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS log;

-- --- config + state (single row, row_id = 1) --------------------------------
CREATE TABLE IF NOT EXISTS config.pg_failover_monitor (
    row_id               integer PRIMARY KEY DEFAULT 1 CHECK (row_id = 1),
    is_enabled           boolean     NOT NULL DEFAULT true,
    fail_threshold       integer     NOT NULL DEFAULT 3,   -- consecutive failed checks before alerting
    connect_timeout_secs integer     NOT NULL DEFAULT 5,   -- per-probe connect timeout
    max_replay_lag_mb    numeric     NOT NULL DEFAULT 50,  -- standby "caught up" ceiling for SAFE-TO-PROMOTE
    recurrency_hours     integer     NOT NULL DEFAULT 1,   -- reserved (outage uses single-shot trip flag)
    primary_host         text,                             -- override; NULL => derive from PG_HOST[0]
    primary_port         integer,
    standby_host         text,                             -- override; NULL => derive from PG_HOST[1]
    standby_port         integer,
    standby_datadir      text,                             -- informational, for the pg_ctl promote hint
    -- state, maintained by the process (DB copy; authoritative state lives in the
    -- local cache file so it survives the primary being down)
    consecutive_failures integer     NOT NULL DEFAULT 0,
    tripped              boolean     NOT NULL DEFAULT false,
    last_state           text,
    last_checked         timestamptz,
    notes                text,
    updated_at           timestamptz NOT NULL DEFAULT now()
);

INSERT INTO config.pg_failover_monitor (row_id, notes)
SELECT 1, 'Tier 1: detect + alert + preview only. Hosts derive from PG_HOST '
          '(first=primary, second=standby) unless overridden here. DBDOME never '
          'auto-promotes; the alert carries the promote command for a human to run.'
WHERE NOT EXISTS (SELECT 1 FROM config.pg_failover_monitor WHERE row_id = 1);

-- --- event ledger -----------------------------------------------------------
CREATE TABLE IF NOT EXISTS log.pg_failover_events (
    event_id             bigserial PRIMARY KEY,
    event_time           timestamptz NOT NULL DEFAULT now(),
    state                text        NOT NULL,   -- primary_up | primary_down | preview_emitted
                                                 -- | standby_not_ready | no_standby | recovered
    primary_host         text,
    standby_host         text,
    consecutive_failures integer,
    replay_lag_bytes     bigint,
    recommended_action   text,
    detail               jsonb
);
CREATE INDEX IF NOT EXISTS ix_pg_failover_events_time
    ON log.pg_failover_events (event_time DESC);

-- --- register the scheduled process -----------------------------------------
-- Resolved to processes.pg_failover_monitor.run_pg_failover_monitor via
-- job_operation_scheduler.get_function_by_name (requires the matching build).
INSERT INTO metrics.registered_processes (process_name, interval, is_active, description)
SELECT 'pg_failover_monitor', 60, true,
       'HA/DR: detect PostgreSQL primary down and email the promote command (no auto-promote)'
WHERE NOT EXISTS (
    SELECT 1 FROM metrics.registered_processes WHERE process_name = 'pg_failover_monitor'
);
