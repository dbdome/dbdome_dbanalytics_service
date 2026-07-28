-- =============================================================================
-- 6090_rbac_log.sql
-- Audit log for the RBAC provisioning process (processes/rbac_provisioning.py,
-- triggered by the /rbac_provision endpoint). One row per step: backup, each
-- database role, and the server role. Lives in dbanalytics (PostgreSQL).
-- Idempotent.
-- =============================================================================
CREATE TABLE IF NOT EXISTS metrics.rbac_log (
    row_id        bigserial PRIMARY KEY,
    server        text,
    database_name text,
    action        text,          -- backup | db_role:<name> | server_role:srv_dba | ...
    status        text,          -- ok | error | skipped
    detail        text,
    entry_date    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_rbac_log_entry ON metrics.rbac_log (entry_date DESC);
CREATE INDEX IF NOT EXISTS ix_rbac_log_server ON metrics.rbac_log (server, entry_date DESC);
