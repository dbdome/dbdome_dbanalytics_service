-- ============================================================
-- SEC-SQL-AUD-006/007/008  Suspicious Transaction Root Causes
-- ============================================================
SET client_encoding = 'UTF8';
BEGIN;

-- ── 1. ISSUES ────────────────────────────────────────────────
INSERT INTO rootcause.issues
  (issue_id, domain_code, database_type_code, area_code, name, slug, description)
VALUES
  ('SEC-SQL-AUD-006','SEC','SQL','AUD',
   'High Privilege User Suspicious Transactions',
   'high-privilege-user-suspicious-transactions',
   'Suspicious database transactions executed by superusers, DBAs, or administrative roles that may indicate insider threat, credential compromise, or policy violation.'),

  ('SEC-SQL-AUD-007','SEC','SQL','AUD',
   'Unknown Transaction Patterns',
   'unknown-transaction-patterns',
   'Transactions that do not match known application baselines: unrecognized query signatures, unexpected source connections, or off-hours activity suggesting unauthorized access.'),

  ('SEC-SQL-AUD-008','SEC','SQL','AUD',
   'Risky Transaction Execution',
   'risky-transaction-execution',
   'High-impact operations such as bulk data exports, mass deletions, production DDL changes, or access to credential and encryption tables that represent significant data-loss or integrity risk.');

-- ── 2. ROOT CAUSES — SEC-SQL-AUD-006 (High Privilege) ────────
INSERT INTO rootcause.root_causes
  (root_cause_id, issue_id, name, slug, description, vendors_applicable)
VALUES
  ('SEC-SQL-AUD-006-RC01','SEC-SQL-AUD-006',
   'Privileged account executing DML outside maintenance window',
   'privileged-account-dml-outside-maintenance-window',
   'A superuser or DBA account runs INSERT/UPDATE/DELETE during normal business hours or outside a scheduled window, signalling unplanned or unauthorized data modification.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-006-RC02','SEC-SQL-AUD-006',
   'Superuser running ad-hoc queries on sensitive tables',
   'superuser-adhoc-queries-sensitive-tables',
   'An admin account directly queries PII, credential, financial, or encryption-key tables outside an approved application context, indicating reconnaissance or exfiltration preparation.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-006-RC03','SEC-SQL-AUD-006',
   'High privilege account accessing schema outside designated scope',
   'high-privilege-account-out-of-scope-schema',
   'An administrative account that normally operates within a specific schema begins accessing schemas or databases outside its designated boundary, suggesting lateral movement.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-006-RC04','SEC-SQL-AUD-006',
   'Service account performing interactive or manual transactions',
   'service-account-interactive-transactions',
   'A service or application account (expected to run only parameterized queries) is observed in an interactive session running ad-hoc SQL, indicating possible credential theft.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-006-RC05','SEC-SQL-AUD-006',
   'Privilege escalation during active session',
   'privilege-escalation-active-session',
   'A session that started with standard privileges subsequently executes GRANT, SET ROLE, or other privilege-elevating commands within the same connection.',
   ARRAY['postgresql','sqlserver','mysql','oracle']);

-- ── 3. ROOT CAUSES — SEC-SQL-AUD-007 (Unknown Patterns) ──────
INSERT INTO rootcause.root_causes
  (root_cause_id, issue_id, name, slug, description, vendors_applicable)
VALUES
  ('SEC-SQL-AUD-007-RC01','SEC-SQL-AUD-007',
   'Transactions from unregistered application signatures',
   'transactions-unregistered-application-signatures',
   'SQL traffic originates from an application_name, client program, or connection tag not present in the approved application registry, suggesting a rogue or shadow tool.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-007-RC02','SEC-SQL-AUD-007',
   'Query patterns not matching known application baseline',
   'query-patterns-not-matching-baseline',
   'Queries exhibit structural signatures (table combinations, column access, JOIN depth) that do not appear in the established workload fingerprint, indicating manually crafted or injected SQL.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-007-RC03','SEC-SQL-AUD-007',
   'Connections from unexpected network addresses',
   'connections-unexpected-network-addresses',
   'Active database sessions originate from IP ranges or hostnames not listed in the approved connection whitelist, indicating an unauthorized client.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-007-RC04','SEC-SQL-AUD-007',
   'Off-hours transaction activity from non-automated accounts',
   'off-hours-activity-non-automated-accounts',
   'Human-owned accounts generate database activity during nights, weekends, or holidays when no scheduled batch jobs are expected, consistent with unauthorized access.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-007-RC05','SEC-SQL-AUD-007',
   'Execution of previously unseen stored procedures or functions',
   'execution-unseen-stored-procedures',
   'A stored procedure or function that has never appeared in historical workload logs is called, potentially indicating a backdoor or newly injected code object.',
   ARRAY['postgresql','sqlserver','mysql','oracle']);

-- ── 4. ROOT CAUSES — SEC-SQL-AUD-008 (Risky Transactions) ────
INSERT INTO rootcause.root_causes
  (root_cause_id, issue_id, name, slug, description, vendors_applicable)
VALUES
  ('SEC-SQL-AUD-008-RC01','SEC-SQL-AUD-008',
   'Bulk data export or mass SELECT on sensitive tables',
   'bulk-data-export-sensitive-tables',
   'A single session issues SELECT queries returning unusually large row counts from tables classified as sensitive, consistent with data exfiltration.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-008-RC02','SEC-SQL-AUD-008',
   'Mass DELETE or TRUNCATE without WHERE clause',
   'mass-delete-truncate-without-where',
   'A DELETE with no predicate or a TRUNCATE statement executes against a non-empty table, risking irreversible data loss.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-008-RC03','SEC-SQL-AUD-008',
   'DDL statements executed in production by non-DBA accounts',
   'ddl-production-non-dba-accounts',
   'CREATE, ALTER, or DROP statements are executed by accounts that do not hold an approved DBA role, violating change-management controls.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-008-RC04','SEC-SQL-AUD-008',
   'Transactions accessing credential or encryption key tables',
   'transactions-credential-encryption-key-tables',
   'Any account other than the designated key-management service queries tables that store hashed passwords, API keys, or encryption key material.',
   ARRAY['postgresql','sqlserver','mysql','oracle']),

  ('SEC-SQL-AUD-008-RC05','SEC-SQL-AUD-008',
   'Cross-schema transactions outside application scope',
   'cross-schema-transactions-outside-application-scope',
   'A session joins or accesses tables from two or more schemas that the associated application has no business reason to combine, suggesting unauthorized data correlation.',
   ARRAY['postgresql','sqlserver','mysql','oracle']);

COMMIT;
