
-- View: rootcause.v_rootcauses

-- DROP VIEW rootcause.v_rootcauses cascade ;

CREATE OR REPLACE VIEW rootcause.v_rootcauses
 AS
 SELECT DISTINCT d.code AS domain_code,
    d.name AS domain_name,
    a.code AS area_code,
    a.name AS area_name,
    i.name AS issue_name,
	parameters  , 
    i.issue_id,
    rc.root_cause_id,
    rc.name AS root_cause_name,
    rc.description AS root_cause_desc,
    dp.name AS detection_name,
    dp.description AS detection_desc,
    stps.name AS step_name,
    stps.name,
    stps.content,
    stps.expected,
    dp.is_active,
    v.slug AS vendor_name,
    rpst.risk_level
   FROM (((((((((((rootcause.issues i
     JOIN rootcause.domains d ON (((d.code)::text = (i.domain_code)::text)))
     JOIN rootcause.areas a ON (((a.code)::text = (i.area_code)::text)))
     JOIN rootcause.root_causes rc ON (((rc.issue_id)::text = (i.issue_id)::text)))
     JOIN rootcause.detection_paths dp ON (((dp.root_cause_id)::text = (rc.root_cause_id)::text)))
     JOIN rootcause.detection_path_steps stpstp ON ((stpstp.detection_path_id = dp.id)))
     JOIN rootcause.detection_steps stps ON ((stps.id = stpstp.detection_step_id)))
     JOIN rootcause.vendors v ON (((v.slug)::text = (stps.vendor_slug)::text)))
     JOIN rootcause.resolution_paths rp ON (((rp.root_cause_id)::text = (rc.root_cause_id)::text)))
     JOIN rootcause.resolution_path_steps rpstp ON ((rpstp.resolution_path_id = rp.id)))
     JOIN rootcause.resolution_steps rpst ON ((rpst.id = rpstp.resolution_step_id)))
     JOIN rootcause.risk_level rl ON ((rl.risk_level = (rpst.risk_level)::bpchar)))
  WHERE ((d.is_enabled IS TRUE) AND (a.is_enabled IS TRUE) );

ALTER TABLE IF EXISTS rootcause.v_rootcauses
    OWNER TO enterprisedb;



-- View: rootcause.v_category_definitions

-- DROP VIEW rootcause.v_category_definitions;

CREATE OR REPLACE VIEW rootcause.v_category_definitions
 AS
 WITH latest_results AS (
         SELECT DISTINCT ON (general_metric_metadata_results.metric_name) general_metric_metadata_results.metric_name AS root_cause_id,
            general_metric_metadata_results.metric_metadata_vs_expected,
            general_metric_metadata_results.metric_metadata,
                CASE
                    WHEN ((general_metric_metadata_results.metric_metadata_vs_expected IS NOT NULL) AND ((general_metric_metadata_results.metric_metadata_vs_expected ->> 'matched'::text) IS NOT NULL)) THEN 'red'::text
                    WHEN ((general_metric_metadata_results.metric_metadata IS NOT NULL) AND ((general_metric_metadata_results.metric_metadata)::text <> '[]'::text) AND ((general_metric_metadata_results.metric_metadata)::text <> ''::text)) THEN 'yellow'::text
                    ELSE 'green'::text
                END AS traffic_light,
                CASE
                    WHEN ((general_metric_metadata_results.metric_metadata_vs_expected IS NOT NULL) AND ((general_metric_metadata_results.metric_metadata_vs_expected ->> 'matched'::text) IS NOT NULL)) THEN 2
                    WHEN ((general_metric_metadata_results.metric_metadata IS NOT NULL) AND ((general_metric_metadata_results.metric_metadata)::text <> '[]'::text) AND ((general_metric_metadata_results.metric_metadata)::text <> ''::text)) THEN 1
                    ELSE 0
                END AS sev
           FROM monitoring.general_metric_metadata_results
          ORDER BY general_metric_metadata_results.metric_name, general_metric_metadata_results.entry_date DESC
        ), issue_status AS (
         SELECT rc.issue_id,
            COALESCE(max(lr.sev), 0) AS sev,
                CASE COALESCE(max(lr.sev), 0)
                    WHEN 2 THEN 'red'::text
                    WHEN 1 THEN 'yellow'::text
                    ELSE 'green'::text
                END AS traffic_light
           FROM (rootcause.root_causes rc
             LEFT JOIN latest_results lr ON (((lr.root_cause_id)::text = (rc.root_cause_id)::text)))
          GROUP BY rc.issue_id
        ), area_status AS (
         SELECT i.domain_code,
            i.area_code,
            COALESCE(max(ist.sev), 0) AS sev,
                CASE COALESCE(max(ist.sev), 0)
                    WHEN 2 THEN 'red'::text
                    WHEN 1 THEN 'yellow'::text
                    ELSE 'green'::text
                END AS traffic_light
           FROM (rootcause.issues i
             LEFT JOIN issue_status ist ON (((ist.issue_id)::text = (i.issue_id)::text)))
          GROUP BY i.domain_code, i.area_code
        ), domain_status AS (
         SELECT area_status.domain_code,
            COALESCE(max(area_status.sev), 0) AS sev,
                CASE COALESCE(max(area_status.sev), 0)
                    WHEN 2 THEN 'red'::text
                    WHEN 1 THEN 'yellow'::text
                    ELSE 'green'::text
                END AS traffic_light
           FROM area_status
          GROUP BY area_status.domain_code
        ), domain_data AS (
         SELECT d.category_id AS id,
            d.name,
                CASE d.code
                    WHEN 'SEC'::text THEN 'ShieldLock'::text
                    WHEN 'PERF'::text THEN 'Speedometer2'::text
                    WHEN 'HLTH'::text THEN 'HeartPulse'::text
                    ELSE 'Diagram3'::text
                END AS icon,
            COALESCE(ds.sev, 0) AS severity,
            COALESCE(ds.traffic_light, 'green'::text) AS status,
            COALESCE(ds.traffic_light, 'green'::text) AS "trafficLight",
            ( SELECT count(DISTINCT i2.issue_id) AS count
                   FROM rootcause.issues i2
                  WHERE ((i2.domain_code)::text = (d.code)::text)) AS "advisoryCount"
           FROM (rootcause.domains d
             LEFT JOIN domain_status ds ON (((ds.domain_code)::text = (d.code)::text)))
          WHERE (d.is_enabled = true)
        ), area_data AS (
         SELECT DISTINCT (d.category_id || a.category_id) AS id,
            a.name,
                CASE a.code
                    WHEN 'ACC'::text THEN 'ShieldCheck'::text
                    WHEN 'AU'::text THEN 'ShieldCheck'::text
                    WHEN 'AUTH'::text THEN 'ShieldCheck'::text
                    WHEN 'AZ'::text THEN 'Key'::text
                    WHEN 'AUTHZ'::text THEN 'Key'::text
                    WHEN 'NET'::text THEN 'Globe'::text
                    WHEN 'INJ'::text THEN 'LockFill'::text
                    WHEN 'ENC'::text THEN 'LockFill'::text
                    WHEN 'LOG'::text THEN 'FileEarmarkText'::text
                    WHEN 'AUD'::text THEN 'ShieldCheck'::text
                    WHEN 'AUDIT'::text THEN 'ShieldCheck'::text
                    WHEN 'ATK'::text THEN 'ShieldExclamation'::text
                    WHEN 'CMD'::text THEN 'Terminal'::text
                    WHEN 'CFG'::text THEN 'GearWideConnected'::text
                    WHEN 'DAT'::text THEN 'Database'::text
                    WHEN 'DATA'::text THEN 'Database'::text
                    WHEN 'PRI'::text THEN 'SortNumericDown'::text
                    WHEN 'PAT'::text THEN 'Search'::text
                    WHEN 'VS'::text THEN 'VectorPen'::text
                    WHEN 'QE'::text THEN 'Lightning'::text
                    WHEN 'QRY'::text THEN 'CodeSlash'::text
                    WHEN 'IX'::text THEN 'ListCheck'::text
                    WHEN 'CONN'::text THEN 'Link'::text
                    WHEN 'MEM'::text THEN 'Memory'::text
                    WHEN 'LM'::text THEN 'Lock'::text
                    WHEN 'SYS'::text THEN 'Pc'::text
                    WHEN 'MNT'::text THEN 'Wrench'::text
                    WHEN 'IDX'::text THEN 'ListCheck'::text
                    WHEN 'IO'::text THEN 'HddStack'::text
                    WHEN 'LAT'::text THEN 'Stopwatch'::text
                    WHEN 'OPT'::text THEN 'Sliders'::text
                    WHEN 'WRT'::text THEN 'PencilSquare'::text
                    WHEN 'THRU'::text THEN 'Speedometer'::text
                    WHEN 'CD'::text THEN 'ArrowRepeat'::text
                    WHEN 'AD'::text THEN 'App'::text
                    WHEN 'DM'::text THEN 'DatabaseGear'::text
                    ELSE 'Shield'::text
                END AS icon,
            COALESCE(ast.sev, 0) AS severity,
            COALESCE(ast.traffic_light, 'green'::text) AS status,
            COALESCE(ast.traffic_light, 'green'::text) AS "trafficLight"
           FROM (((rootcause.areas a
             JOIN rootcause.issues i ON (((i.area_code)::text = (a.code)::text)))
             JOIN rootcause.domains d ON (((d.code)::text = (i.domain_code)::text)))
             LEFT JOIN area_status ast ON ((((ast.domain_code)::text = (i.domain_code)::text) AND ((ast.area_code)::text = (a.code)::text))))
          WHERE (d.is_enabled = true)
        ), issue_detail_files AS (
         SELECT i.issue_id,
            (ARRAY[((i.issue_id)::text || '.json'::text)] || COALESCE(( SELECT array_agg(DISTINCT ((rc.root_cause_id)::text || '.json'::text) ORDER BY ((rc.root_cause_id)::text || '.json'::text)) AS array_agg
                   FROM rootcause.root_causes rc
                  WHERE ((rc.issue_id)::text = (i.issue_id)::text)), ARRAY[]::text[])) AS detail_files
           FROM rootcause.issues i
        ), category_data AS (
         SELECT ((d.category_id || a.category_id) || i.category_id) AS id,
            i.name,
                CASE
                    WHEN ((i.name)::text ~~* '%injection%'::text) THEN 'BugFill'::text
                    WHEN (((i.name)::text ~~* '%login%'::text) OR ((i.name)::text ~~* '%auth%'::text) OR ((i.name)::text ~~* '%account%'::text)) THEN 'Lock'::text
                    WHEN (((i.name)::text ~~* '%encrypt%'::text) OR ((i.name)::text ~~* '%tls%'::text) OR ((i.name)::text ~~* '%ssl%'::text)) THEN 'LockFill'::text
                    WHEN (((i.name)::text ~~* '%privilege%'::text) OR ((i.name)::text ~~* '%permission%'::text) OR ((i.name)::text ~~* '%access%'::text)) THEN 'Key'::text
                    WHEN (((i.name)::text ~~* '%anomal%'::text) OR ((i.name)::text ~~* '%suspicious%'::text)) THEN 'ExclamationTriangle'::text
                    WHEN (((i.name)::text ~~* '%audit%'::text) OR ((i.name)::text ~~* '%log%'::text)) THEN 'FileEarmarkText'::text
                    WHEN (((i.name)::text ~~* '%network%'::text) OR ((i.name)::text ~~* '%remote%'::text) OR ((i.name)::text ~~* '%connection%'::text)) THEN 'Globe'::text
                    WHEN (((i.name)::text ~~* '%query%'::text) OR ((i.name)::text ~~* '%execution%'::text)) THEN 'Lightning'::text
                    WHEN ((i.name)::text ~~* '%index%'::text) THEN 'ListCheck'::text
                    WHEN (((i.name)::text ~~* '%lock%'::text) OR ((i.name)::text ~~* '%block%'::text) OR ((i.name)::text ~~* '%deadlock%'::text)) THEN 'Lock'::text
                    WHEN (((i.name)::text ~~* '%memory%'::text) OR ((i.name)::text ~~* '%buffer%'::text)) THEN 'Memory'::text
                    WHEN (((i.name)::text ~~* '%disk%'::text) OR ((i.name)::text ~~* '%io%'::text) OR ((i.name)::text ~~* '%storage%'::text)) THEN 'HddStack'::text
                    WHEN ((i.name)::text ~~* '%cpu%'::text) THEN 'Cpu'::text
                    WHEN ((i.name)::text ~~* '%backup%'::text) THEN 'CloudUpload'::text
                    WHEN ((i.name)::text ~~* '%transact%'::text) THEN 'ArrowLeftRight'::text
                    WHEN (((i.name)::text ~~* '%config%'::text) OR ((i.name)::text ~~* '%setting%'::text)) THEN 'GearWideConnected'::text
                    WHEN (((i.name)::text ~~* '%data%'::text) OR ((i.name)::text ~~* '%sensitive%'::text) OR ((i.name)::text ~~* '%pii%'::text)) THEN 'ShieldCheck'::text
                    ELSE 'ExclamationTriangle'::text
                END AS icon,
            COALESCE(ist.sev, 0) AS severity,
            COALESCE(ist.traffic_light, 'green'::text) AS status,
            COALESCE(ist.traffic_light, 'green'::text) AS "trafficLight",
            idf.detail_files AS "detailFiles"
           FROM ((((rootcause.issues i
             JOIN rootcause.domains d ON (((d.code)::text = (i.domain_code)::text)))
             JOIN rootcause.areas a ON (((a.code)::text = (i.area_code)::text)))
             JOIN issue_detail_files idf ON (((idf.issue_id)::text = (i.issue_id)::text)))
             LEFT JOIN issue_status ist ON (((ist.issue_id)::text = (i.issue_id)::text)))
          WHERE ((d.is_enabled = true) AND (EXISTS ( SELECT 1
                   FROM (rootcause.v_rootcauses vrc
                     JOIN metrics.servers s ON ((s.db_vendor = (vrc.vendor_name)::text)))
                  WHERE ((vrc.issue_id)::text = (i.issue_id)::text))))
        )
 SELECT json_build_object('adminConsoleURL', 'http://localhost:8000/admin', 'domains', ( SELECT json_agg(row_to_json(d.*) ORDER BY d.id) AS json_agg
           FROM domain_data d), 'areas', ( SELECT json_agg(row_to_json(a.*) ORDER BY a.id) AS json_agg
           FROM area_data a), 'categories', ( SELECT json_agg(row_to_json(c.*) ORDER BY c.id) AS json_agg
           FROM category_data c), 'servers', ( SELECT json_agg(DISTINCT s.server ORDER BY s.server) AS json_agg
           FROM metrics.servers s
          WHERE (s.is_active = true))) AS result;

ALTER TABLE IF EXISTS rootcause.v_category_definitions
    OWNER TO enterprisedb;


-- View: rootcause.v_root_cause_alerts

-- DROP VIEW rootcause.v_root_cause_alerts;

CREATE OR REPLACE VIEW rootcause.v_root_cause_alerts
 AS
 SELECT DISTINCT raqrs.server,
    rc.domain_name,
    rc.area_name,
    rc.issue_name,
    rc.root_cause_id,
    rc.root_cause_name,
    rc.root_cause_desc,
    rc.detection_name,
    rc.detection_desc,
    rc.step_name,
    raqrs.query_result AS execute_numeric_query,
    raq.query_resultset,
    rc.risk_level
   FROM (((rootcause.v_rootcauses rc
     JOIN rootcause.rootcause_alert_query raq ON ((raq.root_cause_id = (rc.root_cause_id)::text)))
     JOIN rootcause.rootcause_alert_query_result_server raqrs ON ((raqrs.root_cause_id = (rc.root_cause_id)::text)))
     JOIN metrics.servers s ON ((s.server = raqrs.server)))
  WHERE ((lower((rc.vendor_name)::text) = lower(s.db_vendor)) OR (lower((rc.vendor_name)::text) = 'sqlserver'::text));

ALTER TABLE IF EXISTS rootcause.v_root_cause_alerts
    OWNER TO enterprisedb;




-- View: metrics.v_custom_metrics

-- DROP VIEW metrics.v_custom_metrics;

CREATE OR REPLACE VIEW metrics.v_custom_metrics
 AS
 SELECT custom_metrics.query,
    custom_metrics.category_id,
    custom_metrics.metric_name,
    custom_metrics.is_active,
    custom_metrics.db_vendor
   FROM metrics.custom_metrics
UNION ALL
 SELECT DISTINCT replace((v_rootcauses.content ->> 'sql'::text), '\n'::text, ' '::text) AS query,
    '-1'::integer AS category_id,
    v_rootcauses.root_cause_id AS metric_name,
    v_rootcauses.is_active,
    v_rootcauses.vendor_name AS db_vendor
   FROM rootcause.v_rootcauses;

ALTER TABLE IF EXISTS metrics.v_custom_metrics
    OWNER TO enterprisedb;

