-- =============================================================================
-- Add Informix "Active transactions" query to metrics.custom_metrics
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

INSERT INTO metrics.custom_metrics (category_id, metric_name, query, description, is_active, db_vendor)
VALUES (
    -1,
    'Active transactions',
    'SELECT
    t.tx_id,
    t.tx_owner AS sid,
    s.username AS login_name,
    s.hostname AS host_name,
    s.progname AS program_name,
    t.tx_logbeg,
    t.tx_loguniq,
    t.tx_flags,
    DBINFO(''utc_current'') - t.tx_begtime AS duration_seconds,
    CASE t.tx_flags
        WHEN 0 THEN ''inactive''
        WHEN 1 THEN ''active''
        WHEN 2 THEN ''committed''
        WHEN 4 THEN ''rolled back''
        ELSE ''other ('' || t.tx_flags || '')''
    END AS tx_status
FROM sysmaster:systrans t
JOIN sysmaster:syssessions s ON s.sid = t.tx_owner
ORDER BY duration_seconds DESC',
    'Active transactions on Informix — shows transaction ID, owning session, user, host, program, duration, and log usage from sysmaster:systrans',
    true,
    'informix'
);

-- Verify
SELECT row_id, metric_name, db_vendor, is_active, LEFT(query, 80) AS query_preview
FROM metrics.custom_metrics
WHERE db_vendor = 'informix'
ORDER BY row_id;

COMMIT;
