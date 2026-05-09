-- =============================================================================
-- Register CrowdStrike Falcon as a SIEM provider in DBDOME
-- =============================================================================
-- Run on: dbanalytics PostgreSQL (port 5444)
--
-- Two modes supported:
--   1. LogScale (Humio) — HTTP API with ingest token
--   2. Syslog/CEF — TCP to a Falcon SIEM Connector / log collector
-- =============================================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════
-- Option A: LogScale (Humio) Ingest API
-- ═══════════════════════════════════════════════════════════════
-- Uncomment this block for LogScale mode:

-- INSERT INTO config.siem (service_type, service_name, service_ip, service_port)
-- VALUES (
--     'crowdstrike',
--     'logscale',                                        -- mode: logscale API
--     'https://cloud.community.humio.com',               -- LogScale URL (or your private instance)
--     443
-- );
--
-- INSERT INTO config.global_params (key, value) VALUES
--     ('crowdstrike_ingest_token', '<YOUR-LOGSCALE-INGEST-TOKEN>'),
--     ('crowdstrike_logscale_url', 'https://cloud.community.humio.com');

-- ═══════════════════════════════════════════════════════════════
-- Option B: Syslog/CEF over TCP
-- ═══════════════════════════════════════════════════════════════
-- Uncomment this block for Syslog mode:

-- INSERT INTO config.siem (service_type, service_name, service_ip, service_port)
-- VALUES (
--     'crowdstrike',
--     'syslog',                                          -- mode: syslog/CEF
--     '172.16.120.50',                                   -- Falcon SIEM Connector IP
--     514                                                -- Syslog port
-- );

-- ═══════════════════════════════════════════════════════════════
-- Verify
-- ═══════════════════════════════════════════════════════════════
SELECT * FROM config.siem ORDER BY service_type;
SELECT key, value FROM config.global_params WHERE key LIKE 'crowdstrike_%';

COMMIT;
