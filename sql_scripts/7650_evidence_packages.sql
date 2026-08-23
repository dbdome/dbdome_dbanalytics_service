-- =============================================================================
-- 7650_evidence_packages.sql
--
-- Create log.evidence_packages and register the generator.
--
-- WHY THIS EXISTS
--   GRC Phase 10 (audit evidence packages) shipped as CODE ONLY. The table it
--   reads and writes was never created by anything:
--
--       processes/evidence_package_generator.py   INSERTs / UPDATEs it
--       http_server.py  /grc/evidence-packages    renders the page
--       http_server.py  /api/evidence-packages    SELECTs the 100 newest
--       http_server.py  /api/evidence-package/... streams the artefacts
--       job_operation_scheduler.py                maps evidence_package_generation
--
--   ...but a search of all 388 sql_scripts, the 394-file postgres/install set
--   and the 26 MB dbanalytics_install.backup base dump found no CREATE for it,
--   and to_regclass('log.evidence_packages') returned NULL on every install
--   checked (customer and development alike). The Evidence Packages screen was
--   therefore permanently empty - not "no packages yet", but no storage at all,
--   and every generator run failed on the first INSERT.
--
--   The other fifteen GRC tables (access_review_instances, attestations,
--   cross_border_transfers, hash_chain_checkpoints, incidents, sod_violations,
--   threat_response_log, ...) are all present. Phase 10 is the single phase
--   whose DDL never landed.
--
-- COLUMNS
--   Derived from the code that uses the table, not invented. The generator
--   INSERTs (package_name, regulation, period_start, period_end, generated_by,
--   package_type, status, included_sections) RETURNING package_id, then UPDATEs
--   (status, pdf_path, csv_zip_path, sha256_pdf, sha256_csv, included_sections,
--   file_size_bytes) or (status, error_message) on failure. The list API orders
--   by created_at DESC, so that column is required rather than cosmetic.
--
-- REGISTRATION
--   Registered INACTIVE, matching every sibling GRC job
--   (compliance_reports_daily, compliance_reports_weekly, attestation_scheduler,
--   hash_chain_verify - all is_active=false). Creating the table is what makes
--   the screen and on-demand generation work; starting a recurring job that
--   writes files to disk is a separate decision for the operator.
--
-- FRESH INSTALLS NEED THIS APPLIED BY HAND
--   dbdome_update runs the numbered scripts, so an existing install picks this
--   up on the next update. dbdome_setup does NOT: it creates the database,
--   restores dbanalytics_install.backup and runs some inline SQL - it never
--   executes sql_scripts. Because the table is absent from that dump, a freshly
--   installed system has the same empty Evidence Packages screen and no script
--   run will fix it.
--
--   Until the base dump is rebaked to include log.evidence_packages, a fresh
--   install must either run dbdome_update afterwards, or apply this file:
--       psql -U postgres -d dbanalytics -f 7650_evidence_packages.sql
--
--   This applies to every DB object added by a numbered script after the dump
--   was baked, not only to this one.
--
-- SAFE TO RE-RUN. Creates nothing that already exists and never overrides an
-- operator's is_active choice.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS log;

CREATE TABLE IF NOT EXISTS log.evidence_packages (
    package_id        bigserial PRIMARY KEY,

    package_name      text          NOT NULL,
    regulation        text,                      -- NULL = all regulations
    period_start      date          NOT NULL,
    period_end        date          NOT NULL,
    generated_by      text,                      -- 'scheduler' | a user name

    -- 'ON_DEMAND' from the UI, 'SCHEDULED' from run_evidence_package_generation.
    package_type      text          NOT NULL DEFAULT 'ON_DEMAND',

    -- The download endpoint returns 409 unless this is COMPLETE, so the three
    -- values below are a contract with http_server, not free text.
    status            text          NOT NULL DEFAULT 'GENERATING',

    -- Section names actually included. The generator passes a Python list here
    -- and seeds it with the '{}' literal, so this must be an array, not jsonb.
    included_sections text[]        NOT NULL DEFAULT '{}',

    pdf_path          text,
    csv_zip_path      text,
    sha256_pdf        varchar(64),
    sha256_csv        varchar(64),
    file_size_bytes   bigint,

    error_message     text,

    created_at        timestamptz   NOT NULL DEFAULT now()
);

-- Constrain status to what the code writes and what the download endpoint
-- tests for. Added separately so re-running against an existing table is safe.
DO $ck$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                    WHERE conname = 'evidence_packages_status_chk') THEN
        ALTER TABLE log.evidence_packages
            ADD CONSTRAINT evidence_packages_status_chk
            CHECK (status IN ('GENERATING', 'COMPLETE', 'FAILED'));
    END IF;
END $ck$;

-- The list API is ORDER BY created_at DESC LIMIT 100 - the common read.
CREATE INDEX IF NOT EXISTS ix_evidence_packages_created
    ON log.evidence_packages (created_at DESC);

-- "show me the GDPR packages for this period" - the auditor's question.
CREATE INDEX IF NOT EXISTS ix_evidence_packages_reg_period
    ON log.evidence_packages (regulation, period_end DESC);

COMMENT ON TABLE log.evidence_packages IS
    'GRC Phase 10: index of generated audit evidence packages. One row per '
    'package; sha256_pdf/sha256_csv are the integrity hashes of the artefacts '
    'at pdf_path/csv_zip_path. Written by processes/evidence_package_generator.py, '
    'read by /api/evidence-packages.';


-- ---------------------------------------------------------------------------
-- Register the generator (inactive, like its GRC siblings)
-- ---------------------------------------------------------------------------
-- 2592000s = 30 days, matching the "Monthly scheduled entry" docstring on
-- run_evidence_package_generation(), which fans out one package per regulation
-- across PCI-DSS, HIPAA, GDPR and SOC2.
INSERT INTO metrics.registered_processes (process_name, is_active, interval, description)
SELECT 'evidence_package_generation', false, 2592000,
       'GRC Phase 10: generates audit evidence packages (text report + CSV zip, '
       'each SHA-256 hashed) into REPORT_DIR/evidence and indexes them in '
       'log.evidence_packages. One package per regulation per run. INACTIVE by '
       'default - packages can be generated on demand from /grc/evidence-packages. '
       'NOTE: as an interval job the 30-day timer restarts with the service, so '
       'on a frequently updated host it may not fire; on-demand generation is '
       'the reliable path.'
WHERE NOT EXISTS (SELECT 1 FROM metrics.registered_processes
                   WHERE process_name = 'evidence_package_generation');

-- Already registered? Refresh the description only; never touch is_active,
-- which is the operator's decision.
UPDATE metrics.registered_processes
   SET description = 'GRC Phase 10: generates audit evidence packages (text '
                     'report + CSV zip, each SHA-256 hashed) into '
                     'REPORT_DIR/evidence and indexes them in '
                     'log.evidence_packages. One package per regulation per run.'
 WHERE process_name = 'evidence_package_generation';


-- ---------------------------------------------------------------------------
-- Verify, and report the source tables the generator will find empty
-- ---------------------------------------------------------------------------
DO $mig$
DECLARE
    v_missing_cols text;
    v_registered   int;
    v_absent       text[] := '{}';
    v_tbl          text;
BEGIN
    IF to_regclass('log.evidence_packages') IS NULL THEN
        RAISE EXCEPTION '7650: log.evidence_packages was not created';
    END IF;

    -- Every column the shipped code touches must be present, including on an
    -- install where an older/partial version of this table already existed.
    SELECT string_agg(c, ', ') INTO v_missing_cols
      FROM unnest(ARRAY['package_id','package_name','regulation','period_start',
                        'period_end','generated_by','package_type','status',
                        'included_sections','pdf_path','csv_zip_path',
                        'sha256_pdf','sha256_csv','file_size_bytes',
                        'error_message','created_at']) AS c
     WHERE NOT EXISTS (SELECT 1 FROM information_schema.columns
                        WHERE table_schema = 'log'
                          AND table_name   = 'evidence_packages'
                          AND column_name  = c);

    IF v_missing_cols IS NOT NULL THEN
        RAISE EXCEPTION '7650: log.evidence_packages is missing column(s): %',
                        v_missing_cols;
    END IF;

    SELECT count(*) INTO v_registered
      FROM metrics.registered_processes
     WHERE process_name = 'evidence_package_generation';

    IF v_registered = 0 THEN
        RAISE EXCEPTION '7650: evidence_package_generation was not registered';
    END IF;

    -- The generator reads eight source tables and swallows errors per section
    -- (_collect_section returns an empty result on any exception), so a missing
    -- table silently produces an empty section rather than a failure. Name them
    -- here so an empty section is explainable instead of mysterious.
    FOREACH v_tbl IN ARRAY ARRAY['log.firewall_audit_log','log.ddl_audit_log',
                                 'log.privilege_change_log','log.sod_violations',
                                 'log.tls_violations','log.vulnerability_findings',
                                 'log.retention_executions','log.threat_response_log']
    LOOP
        IF to_regclass(v_tbl) IS NULL THEN
            v_absent := v_absent || v_tbl;
        END IF;
    END LOOP;

    RAISE NOTICE '7650: log.evidence_packages created; evidence_package_generation '
                 'registered (inactive). Generate on demand from '
                 '/grc/evidence-packages.';

    IF array_length(v_absent, 1) IS NOT NULL THEN
        RAISE WARNING '7650: % of 8 evidence source tables do not exist on this '
                      'install and will produce EMPTY sections: %',
                      array_length(v_absent, 1), array_to_string(v_absent, ', ');
    END IF;
END $mig$;
