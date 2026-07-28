-- =============================================================================
-- 6560_internal_health_alerts.sql
-- Internal (self-monitoring) alerts for the DBDOME appliance itself:
--   * free disk on the local server < threshold (default 10%)
--   * CPU utilisation > threshold (default 90%)
--   * memory utilisation > threshold (default 90%)
--   * a watched Windows service is not running
--     (DBDOME_scheduler, DBDOME_Grafana, DBDOME_web, postgresql-x64-18)
-- Breaches are emailed to the alert recipients. Driven by the
-- 'internal_health_monitor' scheduled process (processes/internal_health_monitor.py).
-- =============================================================================

-- thresholds / enable / dedup window, one row per check
CREATE TABLE IF NOT EXISTS config.internal_health_checks (
    check_key        text PRIMARY KEY,        -- disk_free_pct | cpu_pct | mem_pct | service_down
    operator         text NOT NULL,           -- '<' or '>' (how threshold is compared)
    threshold        numeric,                 -- NULL for service_down
    enabled          boolean NOT NULL DEFAULT true,
    recurrency_hours integer NOT NULL DEFAULT 6 CHECK (recurrency_hours >= 0),
    description      text,
    updated_at       timestamp NOT NULL DEFAULT LOCALTIMESTAMP
);

INSERT INTO config.internal_health_checks (check_key, operator, threshold, enabled, recurrency_hours, description)
VALUES
  ('disk_free_pct', '<', 10, true, 6,  'Free disk on the local system drive below threshold %'),
  ('cpu_pct',       '>', 90, true, 1,  'CPU utilisation above threshold %'),
  ('mem_pct',       '>', 90, true, 1,  'Memory utilisation above threshold %'),
  ('service_down',  '=', NULL, true, 1, 'A watched service is not running')
ON CONFLICT (check_key) DO NOTHING;

-- watched services (Windows service names)
CREATE TABLE IF NOT EXISTS config.internal_monitored_services (
    service_name text PRIMARY KEY,
    enabled      boolean NOT NULL DEFAULT true,
    updated_at   timestamp NOT NULL DEFAULT LOCALTIMESTAMP
);

INSERT INTO config.internal_monitored_services (service_name)
VALUES ('DBDOME_scheduler'), ('DBDOME_Grafana'), ('DBDOME_web'), ('postgresql-x64-18')
ON CONFLICT (service_name) DO NOTHING;

-- register the scheduled process (every 5 minutes)
INSERT INTO metrics.registered_processes (process_name, is_active, interval)
SELECT 'internal_health_monitor', true, 300
WHERE NOT EXISTS (SELECT 1 FROM metrics.registered_processes WHERE process_name = 'internal_health_monitor');

ALTER TABLE config.internal_health_checks       OWNER TO dbdome_adm;
ALTER TABLE config.internal_monitored_services  OWNER TO dbdome_adm;
