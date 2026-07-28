-- ============================================================
-- 6380  monitoring.oracle_verification_results
--   Results table written by scripts/oracle_rootcause_tester.py on a
--   --queries-file run: one row per (server, root_cause_id, query sent, results).
--   The on-site tester connects as the read-only dbdome_mon_usr, so INSERT +
--   sequence USAGE are granted to it here (the tester self-creates the table when
--   it runs as an admin, but relies on this grant when running as the mon user).
--   Idempotent.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE TABLE IF NOT EXISTS monitoring.oracle_verification_results (
    row_id        BIGSERIAL PRIMARY KEY,
    run_id        TEXT,
    entry_date    TIMESTAMPTZ NOT NULL DEFAULT now(),
    server        TEXT,
    root_cause_id TEXT,
    query         TEXT,
    status        TEXT,
    rows          TEXT,
    elapsed_ms    NUMERIC,
    result_sample JSONB,
    error         TEXT
);

CREATE INDEX IF NOT EXISTS ix_oracle_verif_results_run
    ON monitoring.oracle_verification_results (run_id, server, root_cause_id);

GRANT USAGE ON SCHEMA monitoring TO dbdome_mon_usr;
GRANT SELECT, INSERT ON monitoring.oracle_verification_results TO dbdome_mon_usr;
GRANT USAGE, SELECT ON SEQUENCE monitoring.oracle_verification_results_row_id_seq TO dbdome_mon_usr;
