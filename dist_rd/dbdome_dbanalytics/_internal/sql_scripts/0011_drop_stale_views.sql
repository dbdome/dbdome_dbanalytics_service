-- =============================================================================
-- Make the view-(re)creation scripts that follow idempotent on an EXISTING DB.
--
-- On an upgrade the monitoring views already exist, often with a different
-- entry_date type (the gmmr partition migration changed entry_date from
-- timestamptz -> timestamp) or a different column shape, so the later
-- `CREATE OR REPLACE VIEW` statements fail with:
--   * "cannot change data type of view column ..."
--   * "cannot drop columns from view"
--   * "cannot drop view ... because other objects depend on it"
--
-- Dropping them here (CASCADE) lets every following CREATE [OR REPLACE] recreate
-- them FRESH. The only dependent in this chain is v_all_active_transactions
-- (a leaf - nothing depends on it); it is recreated later by
-- 2700_create_view_v_all_active_transactions.sql once its base views exist.
--
-- Idempotent: IF EXISTS makes this a no-op on a fresh install.
-- =============================================================================

DROP VIEW IF EXISTS monitoring.v_all_active_transactions CASCADE;
DROP VIEW IF EXISTS monitoring.v_active_transactions CASCADE;
DROP VIEW IF EXISTS monitoring.v_sec_sql_acc_010_rc07 CASCADE;
DROP VIEW IF EXISTS monitoring.v_sec_sql_acc_010_rc11 CASCADE;
DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_010_rc03 CASCADE;
DROP VIEW IF EXISTS monitoring.v_sec_sql_qe_001_rc01 CASCADE;
