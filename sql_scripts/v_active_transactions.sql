CREATE OR REPLACE VIEW monitoring.v_active_transactions
 AS
 SELECT at.row_id AS query_id,
    at.server,
    at.query,
    at.reads,
    at.writes,
    at.command,
    at.cpu_time,
    at.host_name,
    at.wait_type,
    at.login_name,
    at.session_id,
    at.start_time,
    at.program_name,
    at.database_name,
    at.duration_secs,
    at.logical_reads,
    at.last_wait_type,
    at.blocking_session_id,
    at.last_request_end_time,
    COALESCE(findings.anomaly_count, (0)::bigint) AS anomaly_count,
    findings.anomaly_types,
    findings.max_severity,
        CASE
            WHEN (at.duration_secs > 300) THEN 'Long-Running'::text
            WHEN (at.blocking_session_id > 0) THEN 'Blocked'::text
            WHEN ((at.wait_type IS NOT NULL) AND ((at.wait_type)::text <> ''::text)) THEN 'Waiting'::text
            ELSE 'Active'::text
        END AS transaction_status,
        CASE
            WHEN (EXISTS ( SELECT 1
               FROM monitoring.sensitive_schema ss
              WHERE (at.query ~~* (('%%'::text || (ss.table_name)::text) || '%%'::text)))) THEN true
            ELSE false
        END AS touches_pii,
    mqp.columns,
    mqp.tables,
    mqp.literal,
    mqp.condition,
    mqp.joins,
    mqp.func,
    anom.anomaly_score
   FROM (((monitoring.active_transactions at
     LEFT JOIN monitoring.metric_query_parsing mqp ON ((mqp.query_id = at.row_id)))
     LEFT JOIN monitoring.autoencoder_v1_sql_anomalies anom ON (((anom.server = (at.server)::text) AND (anom.query = at.query))))
     LEFT JOIN LATERAL ( SELECT count(*) AS anomaly_count,
            string_agg(DISTINCT
                CASE
                    WHEN ((gm.metric_name)::text ~~ '%%RC01'::text) THEN 'Unknown Login'::text
                    WHEN ((gm.metric_name)::text ~~ '%%RC02'::text) THEN 'Unexpected Program'::text
                    WHEN ((gm.metric_name)::text ~~ '%%RC03'::text) THEN 'Unexpected DB'::text
                    WHEN ((gm.metric_name)::text ~~ '%%RC04'::text) THEN 'Suspicious SQL'::text
                    WHEN ((gm.metric_name)::text ~~ '%%RC05'::text) THEN 'PII Access'::text
                    WHEN ((gm.metric_name)::text ~~ '%%RC06'::text) THEN 'SQL Injection'::text
                    WHEN ((gm.metric_name)::text ~~ '%%RC07'::text) THEN 'After Hours'::text
                    WHEN ((gm.metric_name)::text ~~ '%%RC08'::text) THEN 'Priv Escalation'::text
                    WHEN ((gm.metric_name)::text ~~ '%%RC09'::text) THEN 'Exfiltration'::text
                    WHEN ((gm.metric_name)::text ~~ '%%RC10'::text) THEN 'Multi-Host'::text
                    WHEN ((gm.metric_name)::text ~~ '%%RC11'::text) THEN 'Schema Recon'::text
                    WHEN ((gm.metric_name)::text ~~ '%%RC12'::text) THEN 'Dormant Acct'::text
                    WHEN ((gm.metric_name)::text ~~ '%%RC13'::text) THEN 'Mass Modify'::text
                    WHEN ((gm.metric_name)::text ~~ '%%TX-001%%'::text) THEN 'Long-Running TX'::text
                    WHEN ((gm.metric_name)::text ~~ '%%TX-003%%'::text) THEN 'Orphaned TX'::text
                    ELSE NULL::text
                END, ', '::text) AS anomaly_types,
            max(COALESCE((gm.metric_metadata_vs_expected ->> 'severity'::text), 'medium'::text)) AS max_severity
           FROM monitoring.general_metric_metadata_results gm
          WHERE (((gm.server)::text = (at.server)::text) AND (gm.metric_metadata_vs_expected IS NOT NULL) AND ((gm.metric_metadata_vs_expected ->> 'matched'::text) = 'true'::text) AND (gm.entry_date >= (at.last_request_end_time - '01:00:00'::interval)) AND (gm.entry_date <= (at.last_request_end_time + '01:00:00'::interval)) AND (((gm.metric_name)::text ~~ 'SEC-SQL-ACC-010%%'::text) OR ((gm.metric_name)::text ~~ 'PERF-SQL-TX%%'::text) OR ((gm.metric_name)::text ~~ 'PERF-SQL-CN%%'::text)))) findings ON (true));

ALTER TABLE IF EXISTS monitoring.v_active_transactions
    OWNER TO dbdome_mon_usr;



SELECT cm.query, cm.category_id, cm.metric_name,
                          ds.expected,
                          d.name AS domain_name,
                          a.name AS area_name,
                          i.name AS issue_name,
                          rc.root_cause_id,
                          rc.name AS root_cause_name,
                          rc.description AS root_cause_desc,
                          dp.name AS detection_name,
                          dp.description AS detection_desc,
                          ds.name AS step_name,
                          ds.expected->>'severity' AS risk_level
                   FROM metrics.v_custom_metrics cm
                   LEFT JOIN rootcause.detection_paths dp
                        ON dp.root_cause_id = cm.metric_name AND dp.is_active = true
                   LEFT JOIN rootcause.detection_path_steps dps
                        ON dps.detection_path_id = dp.id AND dps.sequence = 1
                   LEFT JOIN rootcause.detection_steps ds
                        ON ds.id = dps.detection_step_id
                   LEFT JOIN rootcause.root_causes rc
                        ON rc.root_cause_id = cm.metric_name
                   LEFT JOIN rootcause.issues i
                        ON i.issue_id = rc.issue_id
                   LEFT JOIN rootcause.domains d
                        ON d.code = i.domain_code
                   LEFT JOIN rootcause.areas a
                        ON a.code = i.area_code AND a.database_type_code = i.database_type_code
                   WHERE cm.is_active = true
                     AND lower(cm.db_vendor) IN ('mssql', 'sqlserver')