-- ============================================================
-- Blocker: kill the running session behind a root cause when its matching
-- webook_alert has blocker = true.
--
--   * config.webook_alerts.blocker (bool)  : enable killing for a
--     (metric_type, risk_level) rule. Default false (off).
--   * alerts.blocker_log                    : audit of every kill/skip/error.
--   * config.global_params 'blocker_dry_run': global safety. Default 'true' =
--     LOG intended kills but do NOT execute them. Set to 'false' to arm.
--   * registers the 'blocker' scheduler process.
--
-- Two gates must be open before anything is killed: a webook_alert row with
-- blocker=true AND blocker_dry_run='false'. Idempotent.
-- ============================================================

ALTER TABLE config.webook_alerts
    ADD COLUMN IF NOT EXISTS blocker boolean NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS alerts.blocker_log (
    log_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entry_date    timestamptz NOT NULL DEFAULT now(),
    server        text,
    db_vendor     text,
    root_cause_id text,
    session_id    text,
    action        text,   -- killed | dry-run | skipped | not-running | error
    detail        text
);
CREATE INDEX IF NOT EXISTS ix_blocker_log_date ON alerts.blocker_log (entry_date DESC);
CREATE INDEX IF NOT EXISTS ix_blocker_log_server_sid ON alerts.blocker_log (server, session_id, entry_date DESC);

-- alerts.blocks : same structure as alerts.mail_alert_log; one row per executed
-- block (kill), mirroring how mail sends are recorded in mail_alert_log.
CREATE TABLE IF NOT EXISTS alerts.blocks (LIKE alerts.mail_alert_log INCLUDING DEFAULTS);
CREATE SEQUENCE IF NOT EXISTS alerts.blocks_row_id_seq;
ALTER TABLE alerts.blocks ALTER COLUMN row_id SET DEFAULT nextval('alerts.blocks_row_id_seq');
ALTER SEQUENCE alerts.blocks_row_id_seq OWNED BY alerts.blocks.row_id;

-- global dry-run safety switch (default ON so nothing is killed until armed)
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM config.global_params WHERE key = 'blocker_dry_run') THEN
        INSERT INTO config.global_params (key, value) VALUES ('blocker_dry_run', 'true');
    END IF;
END $do$;

-- register the scheduler process (frequent enough to catch running transactions)
INSERT INTO metrics.registered_processes (process_name, is_active, interval, description)
SELECT 'blocker', true, 120,
       'Kill running sessions for root causes whose webook_alert has blocker=true (gated by blocker_dry_run)'
WHERE NOT EXISTS (
    SELECT 1 FROM metrics.registered_processes WHERE process_name = 'blocker');
