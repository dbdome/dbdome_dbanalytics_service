-- View: rootcause.v_category_definitions
-- Returns CategoryDefinitions.json structure from rootcause taxonomy
-- Traffic light logic based on latest monitoring results:
--   red (severity 2): matched has a value (true or false) in metric_metadata_vs_expected
--   yellow (severity 1): matched is NULL but metric_metadata is not empty ('[]')
--   green (severity 0): no data or empty results

CREATE OR REPLACE VIEW rootcause.v_category_definitions AS
WITH
-- Latest result per root_cause_id: determine traffic light status
latest_results AS (
    SELECT DISTINCT ON (metric_name)
        metric_name AS root_cause_id,
        metric_metadata_vs_expected,
        metric_metadata,
        CASE
            WHEN metric_metadata_vs_expected IS NOT NULL
                 AND (metric_metadata_vs_expected::jsonb->>'matched') IS NOT NULL
                THEN 'red'
            WHEN metric_metadata IS NOT NULL
                 AND metric_metadata::text != '[]'
                 AND metric_metadata::text != ''
                THEN 'yellow'
            ELSE 'green'
        END AS traffic_light,
        CASE
            WHEN metric_metadata_vs_expected IS NOT NULL
                 AND (metric_metadata_vs_expected::jsonb->>'matched') IS NOT NULL
                THEN 2
            WHEN metric_metadata IS NOT NULL
                 AND metric_metadata::text != '[]'
                 AND metric_metadata::text != ''
                THEN 1
            ELSE 0
        END AS sev
    FROM monitoring.general_metric_metadata_results
    ORDER BY metric_name, entry_date DESC
),
-- Aggregate status per issue: worst (max severity) from any root_cause under that issue
issue_status AS (
    SELECT
        rc.issue_id,
        COALESCE(MAX(lr.sev), 0) AS sev,
        CASE COALESCE(MAX(lr.sev), 0)
            WHEN 2 THEN 'red'
            WHEN 1 THEN 'yellow'
            ELSE 'green'
        END AS traffic_light
    FROM rootcause.root_causes rc
    LEFT JOIN latest_results lr ON lr.root_cause_id = rc.root_cause_id
    GROUP BY rc.issue_id
),
-- Aggregate status per area: worst from any issue in that area+domain
area_status AS (
    SELECT
        i.domain_code,
        i.area_code,
        COALESCE(MAX(ist.sev), 0) AS sev,
        CASE COALESCE(MAX(ist.sev), 0)
            WHEN 2 THEN 'red'
            WHEN 1 THEN 'yellow'
            ELSE 'green'
        END AS traffic_light
    FROM rootcause.issues i
    LEFT JOIN issue_status ist ON ist.issue_id = i.issue_id
    GROUP BY i.domain_code, i.area_code
),
-- Aggregate status per domain: worst from any area
domain_status AS (
    SELECT
        domain_code,
        COALESCE(MAX(sev), 0) AS sev,
        CASE COALESCE(MAX(sev), 0)
            WHEN 2 THEN 'red'
            WHEN 1 THEN 'yellow'
            ELSE 'green'
        END AS traffic_light
    FROM area_status
    GROUP BY domain_code
),
domain_data AS (
    SELECT
        d.category_id AS id,
        d.name,
        CASE d.code
            WHEN 'SEC' THEN 'ShieldLock'
            WHEN 'PERF' THEN 'Speedometer2'
            WHEN 'HLTH' THEN 'HeartPulse'
            ELSE 'Diagram3'
        END AS icon,
        COALESCE(ds.sev, 0) AS severity,
        COALESCE(ds.traffic_light, 'green') AS status,
        COALESCE(ds.traffic_light, 'green') AS "trafficLight",
        (SELECT COUNT(DISTINCT i2.issue_id)
         FROM rootcause.issues i2
         WHERE i2.domain_code = d.code) AS "advisoryCount"
    FROM rootcause.domains d
    LEFT JOIN domain_status ds ON ds.domain_code = d.code
    WHERE d.is_enabled = true
),
area_data AS (
    SELECT DISTINCT
        d.category_id || a.category_id AS id,
        a.name,
        CASE a.code
            WHEN 'ACC' THEN 'ShieldCheck'
            WHEN 'AU' THEN 'ShieldCheck'
            WHEN 'AUTH' THEN 'ShieldCheck'
            WHEN 'AZ' THEN 'Key'
            WHEN 'AUTHZ' THEN 'Key'
            WHEN 'NET' THEN 'Globe'
            WHEN 'INJ' THEN 'Database'
            WHEN 'ENC' THEN 'LockFill'
            WHEN 'LOG' THEN 'FileEarmarkText'
            WHEN 'AUD' THEN 'ShieldCheck'
            WHEN 'AUDIT' THEN 'ShieldCheck'
            WHEN 'ATK' THEN 'ShieldExclamation'
            WHEN 'CMD' THEN 'Terminal'
            WHEN 'CFG' THEN 'GearWideConnected'
            WHEN 'DAT' THEN 'Database'
            WHEN 'DATA' THEN 'Database'
            WHEN 'PRI' THEN 'SortNumericDown'
            WHEN 'PAT' THEN 'Search'
            WHEN 'VS' THEN 'VectorPen'
            WHEN 'QE' THEN 'Lightning'
            WHEN 'QRY' THEN 'CodeSlash'
            WHEN 'IX' THEN 'ListCheck'
            WHEN 'CONN' THEN 'Link'
            WHEN 'MEM' THEN 'Memory'
            WHEN 'LM' THEN 'Lock'
            WHEN 'SYS' THEN 'Pc'
            WHEN 'MNT' THEN 'Wrench'
            WHEN 'IDX' THEN 'ListCheck'
            WHEN 'IO' THEN 'HddStack'
            WHEN 'LAT' THEN 'Stopwatch'
            WHEN 'OPT' THEN 'Sliders'
            WHEN 'WRT' THEN 'PencilSquare'
            WHEN 'THRU' THEN 'Speedometer'
            WHEN 'CD' THEN 'ArrowRepeat'
            WHEN 'AD' THEN 'App'
            WHEN 'DM' THEN 'DatabaseGear'
            ELSE 'Shield'
        END AS icon,
        COALESCE(ast.sev, 0) AS severity,
        COALESCE(ast.traffic_light, 'green') AS status,
        COALESCE(ast.traffic_light, 'green') AS "trafficLight"
    FROM rootcause.areas a
    JOIN rootcause.issues i ON i.area_code = a.code
    JOIN rootcause.domains d ON d.code = i.domain_code
    LEFT JOIN area_status ast ON ast.domain_code = i.domain_code AND ast.area_code = a.code
    WHERE d.is_enabled = true
),
-- Build detailFiles per issue: issue_id.json + all root_cause_id.json
issue_detail_files AS (
    SELECT
        i.issue_id,
        ARRAY[i.issue_id || '.json'] ||
            COALESCE(
                (SELECT array_agg(DISTINCT rc.root_cause_id || '.json' ORDER BY rc.root_cause_id || '.json')
                 FROM rootcause.root_causes rc
                 WHERE rc.issue_id = i.issue_id),
                ARRAY[]::text[]
            ) AS detail_files
    FROM rootcause.issues i
),
category_data AS (
    SELECT
        d.category_id || a.category_id || i.category_id AS id,
        i.name,
        CASE
            WHEN i.name ILIKE '%injection%' THEN 'BugFill'
            WHEN i.name ILIKE '%login%' OR i.name ILIKE '%auth%' OR i.name ILIKE '%account%' THEN 'PersonLock'
            WHEN i.name ILIKE '%encrypt%' OR i.name ILIKE '%tls%' OR i.name ILIKE '%ssl%' THEN 'LockFill'
            WHEN i.name ILIKE '%privilege%' OR i.name ILIKE '%permission%' OR i.name ILIKE '%access%' THEN 'Key'
            WHEN i.name ILIKE '%anomal%' OR i.name ILIKE '%suspicious%' THEN 'ExclamationTriangle'
            WHEN i.name ILIKE '%audit%' OR i.name ILIKE '%log%' THEN 'FileEarmarkText'
            WHEN i.name ILIKE '%network%' OR i.name ILIKE '%remote%' OR i.name ILIKE '%connection%' THEN 'Globe'
            WHEN i.name ILIKE '%query%' OR i.name ILIKE '%execution%' THEN 'Lightning'
            WHEN i.name ILIKE '%index%' THEN 'ListCheck'
            WHEN i.name ILIKE '%lock%' OR i.name ILIKE '%block%' OR i.name ILIKE '%deadlock%' THEN 'Lock'
            WHEN i.name ILIKE '%memory%' OR i.name ILIKE '%buffer%' THEN 'Memory'
            WHEN i.name ILIKE '%disk%' OR i.name ILIKE '%io%' OR i.name ILIKE '%storage%' THEN 'HddStack'
            WHEN i.name ILIKE '%cpu%' THEN 'Cpu'
            WHEN i.name ILIKE '%backup%' THEN 'CloudUpload'
            WHEN i.name ILIKE '%transact%' THEN 'ArrowLeftRight'
            WHEN i.name ILIKE '%config%' OR i.name ILIKE '%setting%' THEN 'GearWideConnected'
            WHEN i.name ILIKE '%data%' OR i.name ILIKE '%sensitive%' OR i.name ILIKE '%pii%' THEN 'ShieldCheck'
            ELSE 'ExclamationTriangle'
        END AS icon,
        COALESCE(ist.sev, 0) AS severity,
        COALESCE(ist.traffic_light, 'green') AS status,
        COALESCE(ist.traffic_light, 'green') AS "trafficLight",
        idf.detail_files AS "detailFiles"
    FROM rootcause.issues i
    JOIN rootcause.domains d ON d.code = i.domain_code
    JOIN rootcause.areas a ON a.code = i.area_code
    JOIN issue_detail_files idf ON idf.issue_id = i.issue_id
    LEFT JOIN issue_status ist ON ist.issue_id = i.issue_id
    WHERE d.is_enabled = true
      AND EXISTS (
          SELECT 1 FROM rootcause.v_rootcauses vrc
          JOIN metrics.servers s ON s.db_vendor = vrc.vendor_name
          WHERE vrc.issue_id = i.issue_id
      )
)
SELECT json_build_object(
    'adminConsoleURL', 'http://localhost:8000/admin',
    'domains', (SELECT json_agg(row_to_json(d) ORDER BY d.id) FROM domain_data d),
    'areas', (SELECT json_agg(row_to_json(a) ORDER BY a.id) FROM area_data a),
    'categories', (SELECT json_agg(row_to_json(c) ORDER BY c.id) FROM category_data c),
    'servers', (SELECT json_agg(DISTINCT s.server ORDER BY s.server) FROM metrics.servers s WHERE s.is_active = true)
) AS result;
