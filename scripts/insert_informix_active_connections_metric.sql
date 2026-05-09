-- =============================================================================
-- Add Informix "Active connections" query to metrics.custom_metrics
-- =============================================================================
-- Run on: dbanalytics PostgreSQL (port 5444)
-- =============================================================================

BEGIN;

-- Fix sequence if needed
SELECT setval(
    pg_get_serial_sequence('metrics.custom_metrics', 'row_id'),
    GREATEST(
        (SELECT MAX(row_id) FROM metrics.custom_metrics),
        currval(pg_get_serial_sequence('metrics.custom_metrics', 'row_id'))
    )
);

-- Active connections
INSERT INTO metrics.custom_metrics (category_id, metric_name, query, description, is_active, db_vendor)
VALUES (
    -1,
    'Active connections',
    'SELECT
    s.sid,
    s.username AS login_name,
    s.uid,
    s.hostname AS host_name,
    s.progname AS program_name,
    s.connected AS login_time,
    s.pid AS client_pid,
    DBINFO(''utc_current'') - DBINFO(''utc_to_datetime'', s.connected) AS connected_seconds
FROM sysmaster:syssessions s
WHERE s.sid > 0
  AND s.username IS NOT NULL
  AND s.username <> ''''
ORDER BY s.connected',
    'Active connections on Informix — shows session ID, user, host, program, connection time and duration from sysmaster:syssessions',
    true,
    'informix'
);

-- Connection count per user
INSERT INTO metrics.custom_metrics (category_id, metric_name, query, description, is_active, db_vendor)
VALUES (
    -1,
    'Connection count per user',
    'SELECT
    s.username AS login_name,
    COUNT(*) AS connection_count,
    COUNT(DISTINCT s.hostname) AS distinct_hosts,
    COUNT(DISTINCT s.progname) AS distinct_programs
FROM sysmaster:syssessions s
WHERE s.sid > 0
  AND s.username IS NOT NULL
  AND s.username <> ''''
GROUP BY s.username
ORDER BY connection_count DESC',
    'Connection count per user on Informix — grouped by username with distinct host and program counts',
    true,
    'informix'
);

-- Verify
SELECT row_id, metric_name, db_vendor, is_active, LEFT(query, 80) AS query_preview
FROM metrics.custom_metrics
WHERE db_vendor = 'informix'
ORDER BY row_id;

COMMIT;
