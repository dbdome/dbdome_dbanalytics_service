-- =============================================================================
-- DBDOME self-monitoring vendor: "dbanalytics"
--
-- Treats the dbanalytics catalog (the PG database that DBDOME stores its own
-- collected metrics in) as a monitored target. Adds:
--
--   1. Vendor               rootcause.vendors          slug='dbanalytics'
--   2. Root cause           SEC-ANL-PII-001-RC01       under existing issue
--                                                       SEC-SQL-PRI-001
--   3. Detection step       Postgres SQL that scans
--                              monitoring.v_expensive_queries
--                              monitoring.v_active_transactions
--                           for sensitive-data patterns in query text.
--   4. Detection path + path-step linking the two.
--   5. Resolution path + step (recommendation only, no automation).
--
-- Live target = the dbanalytics catalog DB itself (PostgreSQL on port 5444).
-- The detection SQL must therefore be valid PostgreSQL, NOT T-SQL or PL/SQL.
--
-- Idempotent: every INSERT is guarded with NOT EXISTS / WHERE NOT IN, so
-- re-running this script is a no-op once everything is in place.
--
-- HOW TO RUN: against the dbanalytics catalog DB.
--     psql -h localhost -p 5444 -U dbdome_adm -d dbanalytics \
--          -f register_dbanalytics_self_monitoring.sql
-- =============================================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. REGISTER VENDOR
-- ═══════════════════════════════════════════════════════════════════════════

INSERT INTO rootcause.vendors (slug, name, database_type_code)
SELECT 'dbanalytics', 'DBDOME dbanalytics catalog (self)', 'SQL'
WHERE NOT EXISTS (
    SELECT 1 FROM rootcause.vendors WHERE slug = 'dbanalytics'
);

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. CREATE ROOT CAUSE
-- ═══════════════════════════════════════════════════════════════════════════
-- Reuses the existing SEC-SQL-PRI-001 issue (Sensitive data privacy). The
-- 'ANL' segment in the new RC id is unconventional but signals "analytics
-- catalog self-monitoring" so we don't collide with vendor-side schema
-- discovery RCs (RC12, RC13, RC15).

INSERT INTO rootcause.root_causes (
    root_cause_id, issue_id, name, slug, description,
    topics, vendors_applicable
)
SELECT
    'SEC-ANL-PII-001-RC01',
    'SEC-SQL-PRI-001',
    'Sensitive data observed in dbanalytics catalog views',
    'sensitive-data-in-dbanalytics-catalog',
    'The DBDOME dbanalytics catalog stores observed query text from monitored '
    'targets in monitoring.v_expensive_queries and monitoring.v_active_'
    'transactions. If queries on monitored servers reference PII columns '
    '(SSN, credit card, password, email, salary, etc.), the data leaks into '
    'these aggregation views and becomes visible to anyone with read access '
    'to the dbanalytics catalog. This RC scans both views for sensitive '
    'patterns so leaks can be triaged and the upstream queries hardened or '
    'masked.',
    ARRAY['pii', 'self-monitoring', 'data-leakage', 'observability', 'dbanalytics',
          'gdpr', 'hipaa', 'pci-dss', 'aggregation-leak'],
    ARRAY['dbanalytics']
WHERE NOT EXISTS (
    SELECT 1 FROM rootcause.root_causes
     WHERE root_cause_id = 'SEC-ANL-PII-001-RC01'
);

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. CREATE / UPDATE DETECTION STEP
-- ═══════════════════════════════════════════════════════════════════════════
-- Postgres regex-based scan of the two analytics views. Sensitive-pattern
-- map mirrors the column-name patterns used by SEC-SQL-PRI-001-RC12/RC13
-- so a PII hit here aligns with the existing taxonomy.

DO $do$
DECLARE
    v_step_id INT;
    v_path_id INT;
    v_res_step_id INT;
    v_res_path_id INT;
    v_pg_sql  TEXT := $sql$WITH patterns(pattern, pii_category) AS (
    VALUES
        ('ssn|social_security',                                  'SSN'),
        ('credit_card|card_number|cvv|cvc',                      'Credit Card'),
        ('password|passwd|secret|api_key|apikey|token',          'Credential'),
        ('\bemail\b|e_mail',                                     'Email'),
        ('phone|mobile|cell',                                    'Phone'),
        ('birth|dob|date_of_birth',                              'Date of Birth'),
        ('salary|income|wage',                                   'Financial'),
        ('bank_account|iban|routing',                            'Bank Account'),
        ('national_id|passport|driver_license|tax_id|id_number', 'Government ID'),
        ('medical|diagnosis|health',                             'Medical'),
        ('ip_address|mac_address|biometric',                     'Technical PII')
),
sources AS (
    SELECT 'expensive_query'::text AS source,
           eq.server::text         AS server,
           eq.query::text          AS query_text
      FROM monitoring.v_expensive_queries eq
     WHERE eq.query IS NOT NULL
       AND length(eq.query) > 0
    UNION ALL
    SELECT 'active_transaction'::text AS source,
           at.server::text            AS server,
           at.query::text             AS query_text
      FROM monitoring.v_active_transactions at
     WHERE at.query IS NOT NULL
       AND length(at.query) > 0
)
SELECT s.source,
       s.server,
       p.pii_category,
       LEFT(s.query_text, 4000) AS query_text
  FROM sources s
  JOIN patterns p ON LOWER(s.query_text) ~ p.pattern
 ORDER BY p.pii_category, s.source, s.server$sql$;
BEGIN

    -- 3a. Detection step (idempotent: insert only if not already there).
    SELECT id
      INTO v_step_id
      FROM rootcause.detection_steps
     WHERE vendor_slug = 'dbanalytics'
       AND name = 'Detect sensitive data in dbanalytics views (postgres)';

    IF v_step_id IS NULL THEN
        INSERT INTO rootcause.detection_steps (
            vendor_slug, step_type, name, content, expected
        ) VALUES (
            'dbanalytics',
            'query',
            'Detect sensitive data in dbanalytics views (postgres)',
            jsonb_build_object('sql', v_pg_sql),
            jsonb_build_object(
                'condition', 'row_count > 0',
                'description',
                'Sensitive-data patterns (PII / credential / financial) found '
                'in observed query text inside monitoring.v_expensive_queries '
                'or monitoring.v_active_transactions',
                'severity', 'high'
            )
        ) RETURNING id INTO v_step_id;
        RAISE NOTICE 'Detection step created: id=%', v_step_id;
    ELSE
        -- Already exists — refresh the SQL so re-running this script picks up
        -- pattern-list edits without manual UPDATE.
        UPDATE rootcause.detection_steps
           SET content  = jsonb_set(coalesce(content, '{}'::jsonb),
                                    '{sql}', to_jsonb(v_pg_sql)),
               expected = jsonb_build_object(
                   'condition', 'row_count > 0',
                   'description',
                   'Sensitive-data patterns (PII / credential / financial) found '
                   'in observed query text inside monitoring.v_expensive_queries '
                   'or monitoring.v_active_transactions',
                   'severity', 'high'
               )
         WHERE id = v_step_id;
        RAISE NOTICE 'Detection step refreshed: id=%', v_step_id;
    END IF;

    -- 3b. Detection path: link the new RC to the new step.
    SELECT id
      INTO v_path_id
      FROM rootcause.detection_paths
     WHERE root_cause_id = 'SEC-ANL-PII-001-RC01'
       AND vendor_slug   = 'dbanalytics';

    IF v_path_id IS NULL THEN
        INSERT INTO rootcause.detection_paths (
            root_cause_id, vendor_slug, name, description,
            path_type, is_active
        ) VALUES (
            'SEC-ANL-PII-001-RC01',
            'dbanalytics',
            'Scan dbanalytics expensive_queries + active_transactions for PII',
            'Pattern-match observed query text in the dbanalytics monitoring '
            'views against the standard PII pattern list.',
            'diagnostic',
            true
        ) RETURNING id INTO v_path_id;
        RAISE NOTICE 'Detection path created: id=%', v_path_id;

        INSERT INTO rootcause.detection_path_steps (
            detection_path_id, detection_step_id, sequence,
            on_match_action, on_no_match_action
        ) VALUES (
            v_path_id, v_step_id, 1, 'confirmed', 'ruled_out'
        );
    ELSE
        RAISE NOTICE 'Detection path already exists: id=%', v_path_id;
    END IF;

    -- 3c. Resolution step + path (recommendation only).
    SELECT id
      INTO v_res_step_id
      FROM rootcause.resolution_steps
     WHERE vendor_slug = 'dbanalytics'
       AND name = 'Resolve: redact PII from dbanalytics catalog';

    IF v_res_step_id IS NULL THEN
        INSERT INTO rootcause.resolution_steps (
            vendor_slug, step_type, name, content,
            risk_level, requires_confirmation, is_reversible
        ) VALUES (
            'dbanalytics',
            'recommendation',
            'Resolve: redact PII from dbanalytics catalog',
            jsonb_build_object(
                'action',
                'PII observed in monitoring.v_expensive_queries / v_active_'
                'transactions originated on a monitored target. Two layers of '
                'fix: (a) on the target, mask or parameterize the offending '
                'literals so they never reach the plan cache or active-tx '
                'snapshot; (b) on dbanalytics, tighten access to the monitoring '
                'schema views, or add a column-level redact rule in the '
                'collector that strips matched literals before persisting.'
            ),
            'high',
            false,
            true
        ) RETURNING id INTO v_res_step_id;
    END IF;

    SELECT id
      INTO v_res_path_id
      FROM rootcause.resolution_paths
     WHERE root_cause_id = 'SEC-ANL-PII-001-RC01'
       AND vendor_slug   = 'dbanalytics';

    IF v_res_path_id IS NULL THEN
        INSERT INTO rootcause.resolution_paths (
            root_cause_id, vendor_slug, name, slug, description,
            execution_mode, risk_level, is_active
        ) VALUES (
            'SEC-ANL-PII-001-RC01',
            'dbanalytics',
            'Redact PII from dbanalytics catalog',
            'resolve-anl-pii-001-rc01-' || v_res_step_id,
            'Reduce PII exposure in the analytics catalog by fixing the '
            'upstream queries and tightening access to the monitoring views.',
            'supervised',
            'high',
            true
        ) RETURNING id INTO v_res_path_id;

        INSERT INTO rootcause.resolution_path_steps (
            resolution_path_id, resolution_step_id, step_order
        ) VALUES (v_res_path_id, v_res_step_id, 1);
    END IF;
END
$do$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 4. VERIFY
-- ═══════════════════════════════════════════════════════════════════════════

SELECT '=== Vendor ===' AS section;
SELECT slug, name, database_type_code
  FROM rootcause.vendors
 WHERE slug = 'dbanalytics';

SELECT '=== Root cause ===' AS section;
SELECT root_cause_id, issue_id, name, vendors_applicable
  FROM rootcause.root_causes
 WHERE root_cause_id = 'SEC-ANL-PII-001-RC01';

SELECT '=== Detection step ===' AS section;
SELECT id, vendor_slug, name, LEFT(content->>'sql', 200) AS sql_head
  FROM rootcause.detection_steps
 WHERE vendor_slug = 'dbanalytics'
 ORDER BY id;

SELECT '=== Detection path ===' AS section;
SELECT dp.id, dp.root_cause_id, dp.name, dp.is_active,
       (SELECT count(*)
          FROM rootcause.detection_path_steps dps
         WHERE dps.detection_path_id = dp.id) AS step_count
  FROM rootcause.detection_paths dp
 WHERE dp.vendor_slug = 'dbanalytics'
 ORDER BY dp.id;

SELECT '=== In v_rootcauses (joined view) ===' AS section;
SELECT root_cause_id, root_cause_name, vendor_name, risk_level
  FROM rootcause.v_rootcauses
 WHERE root_cause_id = 'SEC-ANL-PII-001-RC01';

COMMIT;
