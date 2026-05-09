-- =============================================================================
-- Register IBM Informix as a vendor in DBDOME
-- =============================================================================
-- Run on: dbanalytics PostgreSQL (port 5444)
-- =============================================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════
-- 1. Register vendor
-- ═══════════════════════════════════════════════════════════════
INSERT INTO rootcause.vendors (slug, name, database_type_code)
SELECT 'informix', 'IBM Informix', 'SQL'
WHERE NOT EXISTS (SELECT 1 FROM rootcause.vendors WHERE slug = 'informix');

-- ═══════════════════════════════════════════════════════════════
-- 2. Verify
-- ═══════════════════════════════════════════════════════════════
SELECT slug, name, database_type_code, created_at
FROM rootcause.vendors
WHERE slug = 'informix';

COMMIT;
