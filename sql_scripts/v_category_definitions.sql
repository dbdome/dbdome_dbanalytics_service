CREATE OR REPLACE VIEW rootcause.v_category_definitions AS
WITH domain_data AS (
    SELECT
        d.category_id AS id,
        d.name,
        CASE d.code
            WHEN 'SEC' THEN 'ShieldLock'
            WHEN 'PERF' THEN 'Speedometer2'
            WHEN 'HLTH' THEN 'HeartPulse'
            ELSE 'Diagram3'
        END AS icon,
        2 AS severity,
        'red' AS status,
        'red' AS "trafficLight",
        (SELECT COUNT(DISTINCT i2.issue_id)
         FROM rootcause.issues i2
         WHERE i2.domain_code = d.code) AS "advisoryCount"
    FROM rootcause.domains d
    WHERE d.is_enabled = true
),
area_data AS (
    SELECT DISTINCT
        i.category_id || a.category_id AS id,
        a.name,
        CASE a.code
            WHEN 'ACC' THEN 'ShieldCheck'
            WHEN 'AU' THEN 'PersonLock'
            WHEN 'AUTH' THEN 'PersonLock'
            WHEN 'AZ' THEN 'Key'
            WHEN 'AUTHZ' THEN 'Key'
            WHEN 'NET' THEN 'Globe'
            WHEN 'INJ' THEN 'BugFill'
            WHEN 'ENC' THEN 'LockFill'
            WHEN 'LOG' THEN 'FileEarmarkText'
            WHEN 'AUD' THEN 'ClipboardData'
            WHEN 'AUDIT' THEN 'ClipboardData'
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
        2 AS severity,
        'red' AS status,
        'red' AS "trafficLight"
    FROM rootcause.areas a
    JOIN rootcause.issues i ON i.area_code = a.code
    JOIN rootcause.domains d ON d.code = i.domain_code
    WHERE d.is_enabled = true
),
category_data AS (
    SELECT DISTINCT
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
        2 AS severity,
        'red' AS status,
        'red' AS "trafficLight",
        ARRAY[i.domain_code || i.area_code || i.issue_id || '.json'] AS "detailFiles"
    FROM rootcause.issues i
    JOIN rootcause.domains d ON d.code = i.domain_code
	join rootcause.areas a on a.code = i.area_code
    WHERE d.is_enabled = true
)
SELECT json_build_object(
    'adminConsoleURL', 'http://localhost:8000/admin',
    'domains', (SELECT json_agg(row_to_json(d) ORDER BY d.id) FROM domain_data d),
    'areas', (SELECT json_agg(row_to_json(a) ORDER BY a.id) FROM area_data a),
    'categories', (SELECT json_agg(row_to_json(c) ORDER BY c.id) FROM category_data c),
    'servers', (SELECT json_agg(DISTINCT s.server ORDER BY s.server) FROM metrics.servers s WHERE s.is_active = true)
) AS result;
