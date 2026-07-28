-- =============================================================================
-- 7280_dam_compliance_scorecard.sql
-- DAM Compliance SCORING engine for the DAM Compliance report.
--
--   monitoring.v_dam_compliance_scorecard  -> one row per DAM control area with a
--       0-100 compliance score, status band, weight and the regulatory clause it
--       satisfies per framework (PCI-DSS / HIPAA / SOX / GDPR / SOC 2).
--   monitoring.v_dam_regulation_score      -> weighted score + status per
--       regulation, plus an OVERALL row (weighted across all controls).
--
-- Scores are computed from the live DBDOME evidence over a trailing 30-day
-- window. Each control's formula is transparent and documented inline so the
-- score is defensible to an auditor. Higher = better (more compliant).
--
-- Status bands:  >=90 Compliant | 75-89 Substantially | 60-74 Partially | <60 At Risk
-- Idempotent (CREATE OR REPLACE). Read-only; no data is modified.
-- =============================================================================

CREATE OR REPLACE VIEW monitoring.v_dam_compliance_scorecard AS
WITH win AS (SELECT (now() - interval '30 days') AS since)
SELECT * FROM (

  -- 1. Monitoring Coverage = % of registered DBs actively monitored
  SELECT 1 AS nn, 'Monitoring Coverage' AS control_area,
         '% databases actively monitored' AS metric,
         (SELECT count(*) FILTER (WHERE is_active)::text || ' / ' || count(*)::text
            FROM metrics.servers WHERE servername IS NOT NULL) AS metric_value,
         (SELECT COALESCE(round(100.0 * count(*) FILTER (WHERE is_active)
                                / NULLIF(count(*), 0)), 0)::int
            FROM metrics.servers WHERE servername IS NOT NULL) AS score,
         15 AS weight,
         'Req 10' AS pci, '164.308(a)(4)' AS hipaa, 'Sec 404' AS sox,
         'Art 32' AS gdpr, 'CC7.2' AS soc2

  UNION ALL
  -- 2. Sensitive-Data Protection = % of catalogued sensitive columns masked
  SELECT 2, 'Sensitive-Data Protection', '% sensitive columns masked',
         (SELECT COALESCE(round(100.0 * sum(actively_masked)
                / NULLIF(sum(total_sensitive_columns), 0)), 100)::text || '%'
            FROM config.v_masking_coverage),
         (SELECT COALESCE(round(100.0 * sum(actively_masked)
                / NULLIF(sum(total_sensitive_columns), 0)), 100)::int
            FROM config.v_masking_coverage),
         12, 'Req 3', '164.312(a)(2)(iv)', NULL, 'Art 32', 'CC6.1'

  UNION ALL
  -- 3. Privileged Access Governance = penalise open high/critical access incidents
  SELECT 3, 'Privileged Access Governance', 'open high/critical access incidents',
         (SELECT count(*)::text FROM alerts.v_alert_incidents
           WHERE status = 'open' AND lower(risk_level) IN ('critical','high')
             AND (area_name ILIKE '%access%' OR area_name ILIKE '%privile%'
                  OR area_name ILIKE '%auth%')),
         (SELECT GREATEST(0, 100 - 8 * count(*))::int FROM alerts.v_alert_incidents
           WHERE status = 'open' AND lower(risk_level) IN ('critical','high')
             AND (area_name ILIKE '%access%' OR area_name ILIKE '%privile%'
                  OR area_name ILIKE '%auth%')),
         12, 'Req 7, 8.7', '164.312(a)(1)', 'Sec 404', 'Art 32', 'CC6.1'

  UNION ALL
  -- 4. Authentication Security = penalise sources with repeated failed logins
  SELECT 4, 'Authentication Security', 'sources with >=5 failed logins (30d)',
         (SELECT count(*)::text FROM monitoring.siem_login_failures, win
           WHERE COALESCE(failurecount,0) >= 5 AND login_time > win.since),
         (SELECT GREATEST(0, 100 - 10 * count(*))::int
            FROM monitoring.siem_login_failures, win
           WHERE COALESCE(failurecount,0) >= 5 AND login_time > win.since),
         10, 'Req 8, 10.2.1.5', '164.312(d)', NULL, NULL, 'CC6.1'

  UNION ALL
  -- 5. Audit Trail Completeness = % of active DBs producing audit/activity records
  SELECT 5, 'Audit Trail Completeness', '% active DBs producing audit records (30d)',
         (SELECT LEAST(100, COALESCE(round(100.0 * (
                   SELECT count(DISTINCT s) FROM (
                     SELECT server_name AS s FROM log.ddl_audit_log, win WHERE event_time > win.since
                     UNION SELECT server FROM alerts.alert_log, win WHERE entry_date > win.since
                   ) a )
                 / NULLIF((SELECT count(*) FROM metrics.servers WHERE is_active AND servername IS NOT NULL),0)), 0))::text || '%'),
         (SELECT LEAST(100, COALESCE(round(100.0 * (
                   SELECT count(DISTINCT s) FROM (
                     SELECT server_name AS s FROM log.ddl_audit_log, win WHERE event_time > win.since
                     UNION SELECT server FROM alerts.alert_log, win WHERE entry_date > win.since
                   ) a )
                 / NULLIF((SELECT count(*) FROM metrics.servers WHERE is_active AND servername IS NOT NULL),0)), 0))::int),
         12, 'Req 10.2', '164.312(b)', 'Sec 404', 'Art 30', 'CC7.2'

  UNION ALL
  -- 6. Change Control (DDL) = penalise high-risk DDL events
  SELECT 6, 'Change Control (DDL)', 'high-risk DDL events (30d)',
         (SELECT count(*)::text FROM log.v_ddl_high_risk, win WHERE event_time > win.since),
         (SELECT GREATEST(50, 100 - 5 * count(*))::int
            FROM log.v_ddl_high_risk, win WHERE event_time > win.since),
         8, 'Req 10.2.1, 6.4', '164.312(c)', 'Sec 404', 'Art 32', 'CC8.1'

  UNION ALL
  -- 7. Separation of Duties = penalise unacknowledged SoD violations
  SELECT 7, 'Separation of Duties', 'unresolved SoD violations',
         (SELECT count(*)::text FROM log.sod_violations WHERE acknowledged_at IS NULL),
         (SELECT GREATEST(0, 100 - 12 * count(*))::int
            FROM log.sod_violations WHERE acknowledged_at IS NULL),
         8, 'Req 6.4.2', '164.308(a)(3)', 'Sec 404', NULL, 'CC5.2'

  UNION ALL
  -- 8. Policy-Violation Response = % of incidents resolved (30d)
  SELECT 8, 'Policy-Violation Response', '% incidents resolved (30d)',
         (SELECT COALESCE(round(100.0 * count(*) FILTER (WHERE status='resolved')
                 / NULLIF(count(*),0)), 100)::text || '%'
            FROM alerts.v_alert_incidents, win WHERE opened_at > win.since),
         (SELECT COALESCE(round(100.0 * count(*) FILTER (WHERE status='resolved')
                 / NULLIF(count(*),0)), 100)::int
            FROM alerts.v_alert_incidents, win WHERE opened_at > win.since),
         8, 'Req 10.4', '164.308(a)(1)(ii)(D)', 'Sec 404', 'Art 32', 'CC7.2'

  UNION ALL
  -- 9. Active Threat Prevention = blocking actually in force
  SELECT 9, 'Active Threat Prevention', 'blocked/prevented events (30d)',
         (SELECT count(*)::text FROM log.v_blocked_events, win WHERE event_time > win.since),
         (SELECT CASE WHEN count(*) > 0 THEN 100 ELSE 80 END::int
            FROM log.v_blocked_events, win WHERE event_time > win.since),
         8, 'Req 10.7', '164.312(a)(1)', 'Sec 404', 'Art 32', 'CC7.4'

  UNION ALL
  -- 10. Incident Management (MTTR) = mean time to resolve (30d)
  SELECT 10, 'Incident Management (MTTR)', 'avg resolution hours (30d)',
         (SELECT COALESCE(round(avg(EXTRACT(EPOCH FROM (resolved_at - opened_at))/3600.0)::numeric,1),0)::text || ' h'
            FROM alerts.v_alert_incidents, win WHERE status='resolved' AND opened_at > win.since),
         (SELECT CASE
                   WHEN count(*) FILTER (WHERE resolved_at IS NOT NULL) = 0 THEN 90
                   WHEN avg(EXTRACT(EPOCH FROM (resolved_at - opened_at))/3600.0) <= 24  THEN 100
                   WHEN avg(EXTRACT(EPOCH FROM (resolved_at - opened_at))/3600.0) <= 72  THEN 85
                   WHEN avg(EXTRACT(EPOCH FROM (resolved_at - opened_at))/3600.0) <= 168 THEN 70
                   ELSE 55 END::int
            FROM alerts.v_alert_incidents, win WHERE status='resolved' AND opened_at > win.since),
         9, 'Req 12.10', '164.308(a)(6)', 'Sec 404', 'Art 33', 'CC7.3'

) s ORDER BY nn;


CREATE OR REPLACE VIEW monitoring.v_dam_regulation_score AS
WITH sc AS (SELECT * FROM monitoring.v_dam_compliance_scorecard),
exploded AS (
    SELECT 'PCI-DSS' AS regulation, 1 AS ord, score, weight FROM sc WHERE pci   IS NOT NULL
    UNION ALL SELECT 'HIPAA',  2, score, weight FROM sc WHERE hipaa IS NOT NULL
    UNION ALL SELECT 'SOX',    3, score, weight FROM sc WHERE sox   IS NOT NULL
    UNION ALL SELECT 'GDPR',   4, score, weight FROM sc WHERE gdpr  IS NOT NULL
    UNION ALL SELECT 'SOC 2',  5, score, weight FROM sc WHERE soc2  IS NOT NULL
    UNION ALL SELECT 'OVERALL',9, score, weight FROM sc
)
SELECT regulation,
       round(sum(score * weight) / NULLIF(sum(weight), 0))::int AS score,
       CASE
         WHEN round(sum(score * weight) / NULLIF(sum(weight), 0)) >= 90 THEN 'Compliant'
         WHEN round(sum(score * weight) / NULLIF(sum(weight), 0)) >= 75 THEN 'Substantially Compliant'
         WHEN round(sum(score * weight) / NULLIF(sum(weight), 0)) >= 60 THEN 'Partially Compliant'
         ELSE 'At Risk'
       END AS status,
       min(ord) AS ord
FROM exploded
GROUP BY regulation
ORDER BY ord;
