-- Update monitoring.v_active_transactions to include rootcause detection findings
-- Combines raw active_transactions data with detection results from general_metric_metadata_results

DROP VIEW IF EXISTS monitoring.v_sql_injection CASCADE;
DROP VIEW IF EXISTS monitoring.v_active_transactions CASCADE;
CREATE OR REPLACE VIEW monitoring.v_active_transactions AS
SELECT
    at.row_id AS query_id,
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
    -- Rootcause detection findings for this server
    COALESCE(findings.anomaly_count, 0) AS anomaly_count,
    findings.anomaly_types,
    findings.max_severity,
    -- Transaction-specific root cause matches
    CASE
        WHEN at.duration_secs > 300 THEN 'Long-Running'
        WHEN at.blocking_session_id > 0 THEN 'Blocked'
        WHEN at.wait_type IS NOT NULL AND at.wait_type != '' THEN 'Waiting'
        ELSE 'Active'
    END AS transaction_status,
    -- PII flag: does the query touch sensitive columns?
    CASE
        WHEN EXISTS (
            SELECT 1 FROM monitoring.sensitive_schema ss
            WHERE at.query ILIKE '%%' || ss.table_name || '%%'
        ) THEN true
        ELSE false
    END AS touches_pii,
    -- Columns and tables from query parsing
    mqp.columns,
    mqp.tables,
    mqp.literal,
    mqp.condition,
    mqp.joins,
    mqp.func,
    -- Anomaly score from autoencoder
    anom.anomaly_score
FROM monitoring.active_transactions at
LEFT JOIN monitoring.metric_query_parsing mqp ON mqp.query_id = at.row_id
LEFT JOIN monitoring.autoencoder_v1_sql_anomalies anom ON anom.server = at.server AND anom.query = at.query
LEFT JOIN LATERAL (
    SELECT
        COUNT(*) AS anomaly_count,
        STRING_AGG(DISTINCT
            CASE
                WHEN gm.metric_name LIKE '%%RC01' THEN 'Unknown Login'
                WHEN gm.metric_name LIKE '%%RC02' THEN 'Unexpected Program'
                WHEN gm.metric_name LIKE '%%RC03' THEN 'Unexpected DB'
                WHEN gm.metric_name LIKE '%%RC04' THEN 'Suspicious SQL'
                WHEN gm.metric_name LIKE '%%RC05' THEN 'PII Access'
                WHEN gm.metric_name LIKE '%%RC06' THEN 'SQL Injection'
                WHEN gm.metric_name LIKE '%%RC07' THEN 'After Hours'
                WHEN gm.metric_name LIKE '%%RC08' THEN 'Priv Escalation'
                WHEN gm.metric_name LIKE '%%RC09' THEN 'Exfiltration'
                WHEN gm.metric_name LIKE '%%RC10' THEN 'Multi-Host'
                WHEN gm.metric_name LIKE '%%RC11' THEN 'Schema Recon'
                WHEN gm.metric_name LIKE '%%RC12' THEN 'Dormant Acct'
                WHEN gm.metric_name LIKE '%%RC13' THEN 'Mass Modify'
                WHEN gm.metric_name LIKE '%%TX-001%%' THEN 'Long-Running TX'
                WHEN gm.metric_name LIKE '%%TX-003%%' THEN 'Orphaned TX'
                ELSE NULL
            END, ', '
        ) AS anomaly_types,
        MAX(COALESCE(gm.metric_metadata_vs_expected::jsonb->>'severity', 'medium')) AS max_severity
    FROM monitoring.general_metric_metadata_results gm
    WHERE gm.server = at.server
      AND gm.metric_metadata_vs_expected IS NOT NULL
      AND (gm.metric_metadata_vs_expected::jsonb->>'matched')::text = 'true'
      AND gm.entry_date >= at.last_request_end_time - INTERVAL '1 hour'
      AND gm.entry_date <= at.last_request_end_time + INTERVAL '1 hour'
      AND (gm.metric_name LIKE 'SEC-SQL-ACC-010%%'
           OR gm.metric_name LIKE 'PERF-SQL-TX%%'
           OR gm.metric_name LIKE 'PERF-SQL-CN%%')
) findings ON true;
