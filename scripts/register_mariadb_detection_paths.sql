-- =============================================================================
-- DBDOME: Register MariaDB detection paths
-- =============================================================================
-- Run on: dbanalytics PostgreSQL (port 5444)
--
-- Strategy: MariaDB is wire-compatible with MySQL, so every MySQL detection
-- step SQL runs unchanged on MariaDB.  This script:
--   1. Registers the mariadb vendor
--   2. Copies every MySQL detection_step     → new mariadb detection_step
--   3. Copies every MySQL detection_path     → new mariadb detection_path
--   4. Copies every MySQL detection_path_step→ new mariadb detection_path_step
--      (wired to the newly-created mariadb step)
--   5. Copies every MySQL resolution_step    → new mariadb resolution_step
--   6. Copies every MySQL resolution_path    → new mariadb resolution_path
--   7. Copies every MySQL resolution_path_step
--   8. Appends 'mariadb' to vendors_applicable on root_causes that list 'mysql'
--
-- Idempotent: existing mariadb rows are skipped, not duplicated.
-- =============================================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════
-- 1. REGISTER VENDOR
-- ═══════════════════════════════════════════════════════════════
INSERT INTO rootcause.vendors (slug, name, database_type_code)
SELECT 'mariadb', 'MariaDB', 'SQL'
WHERE NOT EXISTS (SELECT 1 FROM rootcause.vendors WHERE slug = 'mariadb');

-- ═══════════════════════════════════════════════════════════════
-- 2. COPY DETECTION STEPS  mysql → mariadb
-- ═══════════════════════════════════════════════════════════════
-- Temp mapping: mysql detection_step id → new mariadb detection_step id
CREATE TEMP TABLE _mdb_step_map (
    mysql_step_id  INT NOT NULL,
    mariadb_step_id INT NOT NULL
) ON COMMIT DROP;

DO $$
DECLARE
    r           RECORD;
    v_new_id    INT;
BEGIN
    FOR r IN
        SELECT id, step_type, name, content, expected, parameters
        FROM rootcause.detection_steps
        WHERE vendor_slug = 'mysql'
        ORDER BY id
    LOOP
        -- skip if a mariadb step with identical name already exists
        IF EXISTS (
            SELECT 1 FROM rootcause.detection_steps
            WHERE vendor_slug = 'mariadb' AND name = r.name
        ) THEN
            -- still record the mapping so paths can reference it
            SELECT id INTO v_new_id
            FROM rootcause.detection_steps
            WHERE vendor_slug = 'mariadb' AND name = r.name
            LIMIT 1;
            INSERT INTO _mdb_step_map VALUES (r.id, v_new_id);
            RAISE NOTICE 'Detection step already exists (skipped): %', r.name;
            CONTINUE;
        END IF;

        INSERT INTO rootcause.detection_steps
            (vendor_slug, step_type, name, content, expected, parameters)
        VALUES
            ('mariadb', r.step_type, r.name, r.content, r.expected, r.parameters)
        RETURNING id INTO v_new_id;

        INSERT INTO _mdb_step_map VALUES (r.id, v_new_id);
        RAISE NOTICE 'Created detection_step id=% from mysql id=%  [%]',
            v_new_id, r.id, r.name;
    END LOOP;
END;
$$;

-- ═══════════════════════════════════════════════════════════════
-- 3. COPY DETECTION PATHS  mysql → mariadb
-- ═══════════════════════════════════════════════════════════════
CREATE TEMP TABLE _mdb_path_map (
    mysql_path_id  INT NOT NULL,
    mariadb_path_id INT NOT NULL
) ON COMMIT DROP;

DO $$
DECLARE
    r           RECORD;
    v_new_id    INT;
BEGIN
    FOR r IN
        SELECT id, root_cause_id, name, description, path_type, is_active
        FROM rootcause.detection_paths
        WHERE vendor_slug = 'mysql'
        ORDER BY id
    LOOP
        IF EXISTS (
            SELECT 1 FROM rootcause.detection_paths
            WHERE vendor_slug = 'mariadb'
              AND root_cause_id = r.root_cause_id
              AND name = r.name
        ) THEN
            SELECT id INTO v_new_id
            FROM rootcause.detection_paths
            WHERE vendor_slug = 'mariadb'
              AND root_cause_id = r.root_cause_id
              AND name = r.name
            LIMIT 1;
            INSERT INTO _mdb_path_map VALUES (r.id, v_new_id);
            RAISE NOTICE 'Detection path already exists (skipped): % / %',
                r.root_cause_id, r.name;
            CONTINUE;
        END IF;

        INSERT INTO rootcause.detection_paths
            (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES
            (r.root_cause_id, 'mariadb', r.name, r.description, r.path_type, r.is_active)
        RETURNING id INTO v_new_id;

        INSERT INTO _mdb_path_map VALUES (r.id, v_new_id);
        RAISE NOTICE 'Created detection_path id=% from mysql id=%  [% / %]',
            v_new_id, r.id, r.root_cause_id, r.name;
    END LOOP;
END;
$$;

-- ═══════════════════════════════════════════════════════════════
-- 4. COPY DETECTION PATH STEPS  (rewired to mariadb ids)
-- ═══════════════════════════════════════════════════════════════
DO $$
DECLARE
    r               RECORD;
    v_mariadb_path  INT;
    v_mariadb_step  INT;
BEGIN
    FOR r IN
        SELECT dps.detection_path_id, dps.detection_step_id,
               dps.sequence, dps.on_match_action, dps.on_no_match_action
        FROM rootcause.detection_path_steps dps
        JOIN rootcause.detection_paths dp ON dp.id = dps.detection_path_id
        WHERE dp.vendor_slug = 'mysql'
        ORDER BY dps.detection_path_id, dps.sequence
    LOOP
        -- resolve mapped ids
        SELECT mariadb_path_id INTO v_mariadb_path
        FROM _mdb_path_map WHERE mysql_path_id = r.detection_path_id;

        SELECT mariadb_step_id INTO v_mariadb_step
        FROM _mdb_step_map WHERE mysql_step_id = r.detection_step_id;

        IF v_mariadb_path IS NULL OR v_mariadb_step IS NULL THEN
            RAISE WARNING 'Could not resolve mapping for mysql path=% step=% — skipped',
                r.detection_path_id, r.detection_step_id;
            CONTINUE;
        END IF;

        IF EXISTS (
            SELECT 1 FROM rootcause.detection_path_steps
            WHERE detection_path_id = v_mariadb_path
              AND detection_step_id = v_mariadb_step
              AND sequence = r.sequence
        ) THEN
            CONTINUE;
        END IF;

        INSERT INTO rootcause.detection_path_steps
            (detection_path_id, detection_step_id, sequence,
             on_match_action, on_no_match_action)
        VALUES
            (v_mariadb_path, v_mariadb_step, r.sequence,
             r.on_match_action, r.on_no_match_action);
    END LOOP;
    RAISE NOTICE 'Detection path steps wired for mariadb.';
END;
$$;

-- ═══════════════════════════════════════════════════════════════
-- 5. COPY RESOLUTION STEPS  mysql → mariadb
-- ═══════════════════════════════════════════════════════════════
CREATE TEMP TABLE _mdb_res_step_map (
    mysql_res_step_id  INT NOT NULL,
    mariadb_res_step_id INT NOT NULL
) ON COMMIT DROP;

DO $$
DECLARE
    r           RECORD;
    v_new_id    INT;
BEGIN
    FOR r IN
        SELECT id, step_type, name, content, risk_level,
               requires_confirmation, is_reversible, estimated_duration
        FROM rootcause.resolution_steps
        WHERE vendor_slug = 'mysql'
        ORDER BY id
    LOOP
        IF EXISTS (
            SELECT 1 FROM rootcause.resolution_steps
            WHERE vendor_slug = 'mariadb' AND name = r.name
        ) THEN
            SELECT id INTO v_new_id
            FROM rootcause.resolution_steps
            WHERE vendor_slug = 'mariadb' AND name = r.name
            LIMIT 1;
            INSERT INTO _mdb_res_step_map VALUES (r.id, v_new_id);
            RAISE NOTICE 'Resolution step already exists (skipped): %', r.name;
            CONTINUE;
        END IF;

        INSERT INTO rootcause.resolution_steps
            (vendor_slug, step_type, name, content, risk_level,
             requires_confirmation, is_reversible, estimated_duration)
        VALUES
            ('mariadb', r.step_type, r.name, r.content, r.risk_level,
             r.requires_confirmation, r.is_reversible, r.estimated_duration)
        RETURNING id INTO v_new_id;

        INSERT INTO _mdb_res_step_map VALUES (r.id, v_new_id);
        RAISE NOTICE 'Created resolution_step id=% from mysql id=%  [%]',
            v_new_id, r.id, r.name;
    END LOOP;
END;
$$;

-- ═══════════════════════════════════════════════════════════════
-- 6. COPY RESOLUTION PATHS  mysql → mariadb
-- ═══════════════════════════════════════════════════════════════
CREATE TEMP TABLE _mdb_res_path_map (
    mysql_res_path_id  INT NOT NULL,
    mariadb_res_path_id INT NOT NULL
) ON COMMIT DROP;

DO $$
DECLARE
    r           RECORD;
    v_new_id    INT;
    v_new_slug  TEXT;
BEGIN
    FOR r IN
        SELECT id, root_cause_id, name, slug, description,
               execution_mode, risk_level, is_active
        FROM rootcause.resolution_paths
        WHERE vendor_slug = 'mysql'
        ORDER BY id
    LOOP
        -- replace 'mysql' in the slug with 'mariadb' to keep slugs unique
        v_new_slug := replace(r.slug, 'mysql', 'mariadb');

        IF EXISTS (
            SELECT 1 FROM rootcause.resolution_paths
            WHERE vendor_slug = 'mariadb'
              AND root_cause_id = r.root_cause_id
              AND slug = v_new_slug
        ) THEN
            SELECT id INTO v_new_id
            FROM rootcause.resolution_paths
            WHERE vendor_slug = 'mariadb'
              AND root_cause_id = r.root_cause_id
              AND slug = v_new_slug
            LIMIT 1;
            INSERT INTO _mdb_res_path_map VALUES (r.id, v_new_id);
            RAISE NOTICE 'Resolution path already exists (skipped): % / %',
                r.root_cause_id, v_new_slug;
            CONTINUE;
        END IF;

        INSERT INTO rootcause.resolution_paths
            (root_cause_id, vendor_slug, name, slug, description,
             execution_mode, risk_level, is_active)
        VALUES
            (r.root_cause_id, 'mariadb', r.name, v_new_slug, r.description,
             r.execution_mode, r.risk_level, r.is_active)
        RETURNING id INTO v_new_id;

        INSERT INTO _mdb_res_path_map VALUES (r.id, v_new_id);
        RAISE NOTICE 'Created resolution_path id=% from mysql id=%  [% / %]',
            v_new_id, r.id, r.root_cause_id, v_new_slug;
    END LOOP;
END;
$$;

-- ═══════════════════════════════════════════════════════════════
-- 7. COPY RESOLUTION PATH STEPS  (rewired to mariadb ids)
-- ═══════════════════════════════════════════════════════════════
DO $$
DECLARE
    r                   RECORD;
    v_mariadb_res_path  INT;
    v_mariadb_res_step  INT;
BEGIN
    FOR r IN
        SELECT rps.resolution_path_id, rps.resolution_step_id,
               rps.step_order, rps.on_success, rps.on_failure
        FROM rootcause.resolution_path_steps rps
        JOIN rootcause.resolution_paths rp ON rp.id = rps.resolution_path_id
        WHERE rp.vendor_slug = 'mysql'
        ORDER BY rps.resolution_path_id, rps.step_order
    LOOP
        SELECT mariadb_res_path_id INTO v_mariadb_res_path
        FROM _mdb_res_path_map WHERE mysql_res_path_id = r.resolution_path_id;

        SELECT mariadb_res_step_id INTO v_mariadb_res_step
        FROM _mdb_res_step_map WHERE mysql_res_step_id = r.resolution_step_id;

        IF v_mariadb_res_path IS NULL OR v_mariadb_res_step IS NULL THEN
            RAISE WARNING 'Could not resolve mapping for mysql res_path=% res_step=% — skipped',
                r.resolution_path_id, r.resolution_step_id;
            CONTINUE;
        END IF;

        IF EXISTS (
            SELECT 1 FROM rootcause.resolution_path_steps
            WHERE resolution_path_id = v_mariadb_res_path
              AND resolution_step_id = v_mariadb_res_step
              AND step_order = r.step_order
        ) THEN
            CONTINUE;
        END IF;

        INSERT INTO rootcause.resolution_path_steps
            (resolution_path_id, resolution_step_id, step_order,
             on_success, on_failure)
        VALUES
            (v_mariadb_res_path, v_mariadb_res_step, r.step_order,
             r.on_success, r.on_failure);
    END LOOP;
    RAISE NOTICE 'Resolution path steps wired for mariadb.';
END;
$$;

-- ═══════════════════════════════════════════════════════════════
-- 8. EXTEND vendors_applicable ON ROOT CAUSES
-- ═══════════════════════════════════════════════════════════════
UPDATE rootcause.root_causes
SET vendors_applicable = array_append(vendors_applicable, 'mariadb')
WHERE 'mysql' = ANY(vendors_applicable)
  AND NOT ('mariadb' = ANY(vendors_applicable));

-- ═══════════════════════════════════════════════════════════════
-- 9. VERIFY
-- ═══════════════════════════════════════════════════════════════
SELECT '=== Vendor ===' AS section;
SELECT slug, name, database_type_code FROM rootcause.vendors WHERE slug = 'mariadb';

SELECT '=== Detection Paths ===' AS section;
SELECT dp.root_cause_id, dp.name, dp.is_active
FROM rootcause.detection_paths dp
WHERE dp.vendor_slug = 'mariadb'
ORDER BY dp.root_cause_id, dp.name;

SELECT '=== Detection Steps ===' AS section;
SELECT ds.id, ds.name, LEFT(ds.content->>'sql', 80) AS sql_preview
FROM rootcause.detection_steps ds
WHERE ds.vendor_slug = 'mariadb'
ORDER BY ds.id;

SELECT '=== Resolution Paths ===' AS section;
SELECT rp.root_cause_id, rp.name, rp.slug, rp.risk_level
FROM rootcause.resolution_paths rp
WHERE rp.vendor_slug = 'mariadb'
ORDER BY rp.root_cause_id;

SELECT '=== Summary ===' AS section;
SELECT
    (SELECT COUNT(*) FROM rootcause.detection_paths  WHERE vendor_slug = 'mariadb') AS detection_paths,
    (SELECT COUNT(*) FROM rootcause.detection_steps  WHERE vendor_slug = 'mariadb') AS detection_steps,
    (SELECT COUNT(*) FROM rootcause.resolution_paths WHERE vendor_slug = 'mariadb') AS resolution_paths,
    (SELECT COUNT(*) FROM rootcause.resolution_steps WHERE vendor_slug = 'mariadb') AS resolution_steps,
    (SELECT COUNT(DISTINCT root_cause_id)
     FROM rootcause.detection_paths WHERE vendor_slug = 'mariadb')                  AS root_causes_covered,
    (SELECT COUNT(*) FROM rootcause.root_causes
     WHERE 'mariadb' = ANY(vendors_applicable))                                     AS root_causes_with_mariadb;

COMMIT;
