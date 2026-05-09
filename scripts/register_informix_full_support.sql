-- =============================================================================
-- DBDOME: Full Informix Support — Vendor, Detection Steps, Paths, Resolutions
-- =============================================================================
-- Run on: dbanalytics PostgreSQL (port 5444)
--
-- Creates:
--   - Vendor registration
--   - Detection steps with Informix-native SQL (sysmaster, sysadmin, etc.)
--   - Detection paths (high + medium risk) per root cause
--   - Resolution steps + paths
--   - Coverage: 25 root causes across Performance + Security domains
--
-- Informix system catalogs used:
--   sysmaster:syssessions      — active sessions
--   sysmaster:sysprofile       — server profile counters
--   sysmaster:syslocks         — lock information
--   sysmaster:syssqlstat       — SQL statement stats
--   sysmaster:sysptprof        — table/partition I/O
--   sysmaster:sysdatabases     — databases
--   sysmaster:systabnames      — table names
--   sysmaster:sysextents       — extents (fragmentation)
--   sysmaster:syschunks        — disk chunks
--   sysmaster:sysdbspaces      — dbspaces
--   sysmaster:syslogfil        — logical log files
--   sysmaster:syschkio         — chunk I/O stats
--   sysmaster:syscfgtab        — onconfig parameters
--   sysmaster:systrans         — active transactions
--   sysmaster:syssesprof       — session profile
--   sysmaster:sysonlinelog     — online log messages
--   sysmaster:sysadtinfo       — audit configuration
--   sysuser:sysusers           — database users
--   sysmaster:sysconfig        — runtime configuration
-- =============================================================================

BEGIN;

-- ═══════════════════════════════════════════════════════════════
-- 1. REGISTER VENDOR
-- ═══════════════════════════════════════════════════════════════
INSERT INTO rootcause.vendors (slug, name, database_type_code)
SELECT 'informix', 'IBM Informix', 'SQL'
WHERE NOT EXISTS (SELECT 1 FROM rootcause.vendors WHERE slug = 'informix');

-- ═══════════════════════════════════════════════════════════════
-- 2. HELPER: Bulk-create detection + resolution for Informix
-- ═══════════════════════════════════════════════════════════════

-- We define all root causes + SQL in a temp table, then loop to create everything.

CREATE TEMP TABLE _ifx_defs (
    root_cause_id   VARCHAR(30) NOT NULL,
    step_name       VARCHAR(200) NOT NULL,
    sql_text        TEXT NOT NULL,
    expected_cond   VARCHAR(100) NOT NULL DEFAULT 'row_count > 0',
    expected_desc   TEXT NOT NULL,
    resolution_text TEXT NOT NULL
) ON COMMIT DROP;

-- ═══════════════════════════════════════════════════════════════
-- PERFORMANCE — Slow Query Execution
-- ═══════════════════════════════════════════════════════════════
INSERT INTO _ifx_defs VALUES (
    'PERF-SQL-QE-001-RC15',
    'Detect expensive queries (informix)',
    'SELECT FIRST 50 s.sid, s.username, s.hostname, s.progname, sq.sql_statement, sq.sql_totaltime / CASE WHEN sq.sql_executions = 0 THEN 1 ELSE sq.sql_executions END AS avg_time, sq.sql_totaltime, sq.sql_executions, sq.sql_rowsprocessed FROM sysmaster:syssqlstat sq JOIN sysmaster:syssessions s ON s.sid = sq.sql_sid WHERE sq.sql_executions > 0 ORDER BY avg_time DESC',
    'row_count > 0',
    'Returns the most expensive queries by average execution time from sysmaster:syssqlstat',
    'Review the top time-consuming SQL. Check for missing indexes with oncheck -pT, update statistics with UPDATE STATISTICS, consider query rewrites.'
);

-- PERFORMANCE — High CPU Utilization
INSERT INTO _ifx_defs VALUES (
    'PERF-SQL-CPU-001-RC01',
    'Detect high CPU sessions (informix)',
    'SELECT s.sid, s.username, s.hostname, s.progname, s.connected AS connect_time, p.usr_cpu + p.sys_cpu AS total_cpu, p.num_reads + p.num_writes AS total_io FROM sysmaster:syssessions s JOIN sysmaster:syssesprof p ON s.sid = p.sid WHERE p.usr_cpu + p.sys_cpu > 0 ORDER BY total_cpu DESC',
    'row_count > 0',
    'Identifies sessions consuming the most CPU from sysmaster:syssesprof',
    'Identify the CPU-heavy queries and optimize them. Check for full table scans, missing indexes, and outdated statistics.'
);

-- PERFORMANCE — Buffer Pool Pressure
INSERT INTO _ifx_defs VALUES (
    'PERF-SQL-CE-001-RC01',
    'Detect buffer pool pressure (informix)',
    'SELECT p.name AS counter_name, p.value FROM sysmaster:sysprofile p WHERE p.name IN (''bufreads'', ''bufwrites'', ''pagreads'', ''pagwrites'', ''bufwaits'', ''flushes'') ORDER BY p.name',
    'row_count > 0',
    'Returns buffer pool read/write counters and wait metrics from sysprofile',
    'If bufreads >> pagreads the cache is effective. If pagreads is high relative to bufreads, increase BUFFERS in onconfig. Monitor bufwaits — any non-zero value indicates pressure.'
);

-- PERFORMANCE — Lock Contention
INSERT INTO _ifx_defs VALUES (
    'PERF-SQL-LC-001-RC01',
    'Detect deadlocks (informix)',
    'SELECT p.name, p.value FROM sysmaster:sysprofile p WHERE p.name IN (''deadlks'', ''lktouts'', ''lockwts'', ''lockreqs'') ORDER BY p.name',
    'row_count > 0',
    'Returns deadlock count, lock timeouts, lock waits, and lock requests from sysprofile',
    'If deadlks > 0, review application transaction ordering. Check lktouts for frequent lock timeouts. Consider reducing transaction scope or adjusting LOCK_MODE in onconfig.'
);

-- PERFORMANCE — Blocking Query
INSERT INTO _ifx_defs VALUES (
    'PERF-SQL-LC-003-RC01',
    'Detect blocking sessions (informix)',
    'SELECT lk.owner AS blocker_sid, lk.waiter AS blocked_sid, bs.username AS blocker_user, ws.username AS blocked_user, bs.progname AS blocker_prog, ws.progname AS blocked_prog, lk.dbsname, lk.tabname, lk.type AS lock_type FROM sysmaster:syslocks lk JOIN sysmaster:syssessions bs ON bs.sid = lk.owner JOIN sysmaster:syssessions ws ON ws.sid = lk.waiter WHERE lk.waiter > 0 ORDER BY lk.waiter',
    'row_count > 0',
    'Detects sessions blocked by other sessions via sysmaster:syslocks',
    'Identify the blocking query and consider killing it with onmode -z <sid>. Review application logic for lock escalation opportunities.'
);

-- PERFORMANCE — Long-Running Transaction
INSERT INTO _ifx_defs VALUES (
    'PERF-SQL-TX-001-RC01',
    'Detect long-running transactions (informix)',
    'SELECT t.tx_id, t.tx_logbeg, t.tx_loguniq, s.sid, s.username, s.hostname, s.progname, DBINFO(''utc_current'') - t.tx_begtime AS duration_seconds FROM sysmaster:systrans t JOIN sysmaster:syssessions s ON s.sid = t.tx_owner WHERE t.tx_begtime > 0 ORDER BY duration_seconds DESC',
    'row_count > 0',
    'Returns active transactions sorted by duration from sysmaster:systrans',
    'Long transactions hold logical log space. Investigate queries, commit more frequently, or use onmode -z to abort the session if needed.'
);

-- PERFORMANCE — Transaction Log Growth
INSERT INTO _ifx_defs VALUES (
    'PERF-SQL-TX-002-RC01',
    'Detect logical log status (informix)',
    'SELECT number AS log_number, size, used, is_archived, is_backed_up, is_current, is_new FROM sysmaster:syslogfil ORDER BY number',
    'row_count > 0',
    'Returns logical log file status, usage, and backup state',
    'If used logs are high and not backed up, run ontape -a or configure automatic log backup. Add more log files with onparams -a -l if needed.'
);

-- PERFORMANCE — High Disk Latency / IO
INSERT INTO _ifx_defs VALUES (
    'PERF-SQL-IO-001-RC01',
    'Detect chunk I/O stats (informix)',
    'SELECT c.chknum, d.name AS dbspace_name, c.reads, c.writes, c.pagesread, c.pageswritten, c.readtime, c.writetime, CASE WHEN c.reads > 0 THEN c.readtime / c.reads ELSE 0 END AS avg_read_time, CASE WHEN c.writes > 0 THEN c.writetime / c.writes ELSE 0 END AS avg_write_time FROM sysmaster:syschkio c JOIN sysmaster:syschunks ch ON ch.chknum = c.chknum JOIN sysmaster:sysdbspaces d ON d.dbsnum = ch.dbsnum WHERE c.reads + c.writes > 0 ORDER BY avg_read_time DESC',
    'row_count > 0',
    'Returns per-chunk I/O latency from sysmaster:syschkio',
    'High avg_read_time indicates slow disks. Move hot chunks to faster storage. Consider spreading data across multiple dbspaces.'
);

-- PERFORMANCE — Max Connections Reached
INSERT INTO _ifx_defs VALUES (
    'PERF-SQL-CN-004-RC01',
    'Detect connection count vs max (informix)',
    'SELECT (SELECT COUNT(*) FROM sysmaster:syssessions WHERE sid > 0) AS current_sessions, (SELECT cf_effective FROM sysmaster:syscfgtab WHERE cf_name = ''NETTYPE'') AS max_configured',
    'row_count > 0',
    'Returns current session count vs configured maximum',
    'If approaching max, increase NETTYPE connections in onconfig or tune connection pooling at the application layer.'
);

-- PERFORMANCE — Missing Index
INSERT INTO _ifx_defs VALUES (
    'PERF-SQL-IX-001-RC01',
    'Detect tables with sequential scans (informix)',
    'SELECT t.dbsname, t.tabname, p.seqscans, p.totalrows, p.rowsread, CASE WHEN p.totalrows > 0 THEN ROUND(p.rowsread * 100.0 / p.totalrows, 2) ELSE 0 END AS scan_pct FROM sysmaster:sysptprof p JOIN sysmaster:systabnames t ON t.partnum = p.partnum WHERE p.seqscans > 100 AND p.totalrows > 1000 ORDER BY p.seqscans DESC',
    'row_count > 0',
    'Tables with high sequential scan counts likely need indexes',
    'Run UPDATE STATISTICS on the table. Check query patterns with SET EXPLAIN ON and create appropriate indexes.'
);

-- PERFORMANCE — Index Fragmentation
INSERT INTO _ifx_defs VALUES (
    'PERF-SQL-IX-003-RC01',
    'Detect extent fragmentation (informix)',
    'SELECT t.dbsname, t.tabname, COUNT(*) AS extent_count FROM sysmaster:sysextents e JOIN sysmaster:systabnames t ON t.partnum = e.pe_partnum GROUP BY t.dbsname, t.tabname HAVING COUNT(*) > 20 ORDER BY extent_count DESC',
    'row_count > 0',
    'Tables with many extents are fragmented and may have degraded I/O performance',
    'Defragment by rebuilding: ALTER TABLE ... TO (new_dbspace). Or use oncheck -cI. Increase initial/next extent sizes to prevent future fragmentation.'
);

-- PERFORMANCE — Outdated Statistics
INSERT INTO _ifx_defs VALUES (
    'PERF-SQL-CPU-004-RC01',
    'Detect tables with no statistics (informix)',
    'SELECT t.dbsname, t.tabname, p.totalrows, p.ustlowts AS last_stats_time FROM sysmaster:sysptprof p JOIN sysmaster:systabnames t ON t.partnum = p.partnum WHERE p.ustlowts = 0 AND p.totalrows > 100 ORDER BY p.totalrows DESC',
    'row_count > 0',
    'Tables that have never had statistics updated will produce poor query plans',
    'Run UPDATE STATISTICS HIGH on these tables. Schedule regular statistics updates via cron or the Informix scheduler.'
);

-- PERFORMANCE — Dbspace Usage
INSERT INTO _ifx_defs VALUES (
    'PERF-SQL-MEM-001-RC01',
    'Detect dbspace usage (informix)',
    'SELECT d.name AS dbspace_name, d.nchunks, SUM(c.chksize) AS total_pages, SUM(c.nfree) AS free_pages, ROUND((1 - SUM(c.nfree) * 1.0 / NULLIF(SUM(c.chksize), 0)) * 100, 2) AS used_pct FROM sysmaster:sysdbspaces d JOIN sysmaster:syschunks c ON c.dbsnum = d.dbsnum GROUP BY d.name, d.nchunks HAVING ROUND((1 - SUM(c.nfree) * 1.0 / NULLIF(SUM(c.chksize), 0)) * 100, 2) > 80 ORDER BY used_pct DESC',
    'row_count > 0',
    'Dbspaces with usage above 80% are at risk of running out of space',
    'Add chunks to the dbspace with onspaces -a. Monitor with onstat -d. Set up alerting on dbspace usage.'
);

-- ═══════════════════════════════════════════════════════════════
-- SECURITY — Default Admin Accounts
-- ═══════════════════════════════════════════════════════════════
INSERT INTO _ifx_defs VALUES (
    'SEC-SQL-AU-001-RC01',
    'Detect default admin accounts (informix)',
    'SELECT username, usertype FROM sysuser:sysusers WHERE username IN (''informix'', ''root'') AND usertype = ''D''',
    'row_count > 0',
    'Default Informix admin accounts (informix, root) still active with DBA privileges',
    'Create named admin accounts and restrict direct use of the informix/root accounts. Use GRANT and REVOKE to apply least privilege.'
);

-- SECURITY — Audit Logging
INSERT INTO _ifx_defs VALUES (
    'SEC-SQL-AUD-001-RC01',
    'Detect audit configuration (informix)',
    'SELECT adtmode, adtpath, adterr FROM sysmaster:sysadtinfo',
    'row_count > 0',
    'Checks if Informix audit (ADTMODE) is enabled and configured',
    'Enable audit with onaudit -c. Set ADTMODE to a non-zero value. Configure ADTPATH for audit log storage. Set ADTERR to define error behavior.'
);

-- SECURITY — Encryption in transit
INSERT INTO _ifx_defs VALUES (
    'SEC-SQL-ENC-001-RC01',
    'Detect SSL/TLS configuration (informix)',
    'SELECT cf_name, cf_effective FROM sysmaster:syscfgtab WHERE cf_name IN (''USEOSTIME'', ''IFX_FIPS_MODE'', ''SSL_PROTOCOL'', ''SECURITY_LOCALCONNECTION'')',
    'row_count > 0',
    'Checks Informix SSL/TLS and security configuration parameters',
    'Enable ENCCSM (Communications Support Module) and configure SSL in sqlhosts. Use onsecurity to manage certificates.'
);

-- SECURITY — Database version / patching
INSERT INTO _ifx_defs VALUES (
    'SEC-SQL-PAT-001-RC01',
    'Detect Informix version (informix)',
    'SELECT DBINFO(''version'', ''full'') AS version_full, DBINFO(''version'', ''major'') AS version_major, DBINFO(''version'', ''minor'') AS version_minor, DBINFO(''version'', ''os'') AS version_os FROM systables WHERE tabid = 1',
    'row_count > 0',
    'Returns the Informix server version for patch level assessment',
    'Ensure the Informix server is on a supported version with the latest fix pack applied. Check IBM Fix Central for available updates.'
);

-- SECURITY — Excessive Privileges
INSERT INTO _ifx_defs VALUES (
    'SEC-SQL-AZ-001-RC01',
    'Detect users with DBA privilege (informix)',
    'SELECT username, usertype FROM sysuser:sysusers WHERE usertype = ''D'' ORDER BY username',
    'row_count > 0',
    'Lists all users with DBA (Database Administrator) privilege — potential over-provisioning',
    'Review DBA privileges. Use GRANT RESOURCE instead of DBA where full admin is not required. Apply least-privilege principle.'
);

-- SECURITY — Dormant/Unused Accounts
INSERT INTO _ifx_defs VALUES (
    'SEC-SQL-AU-006-RC01',
    'Detect dormant accounts (informix)',
    'SELECT u.username, u.usertype FROM sysuser:sysusers u WHERE u.username NOT IN (SELECT DISTINCT username FROM sysmaster:syssessions) AND u.usertype IN (''D'', ''R'') ORDER BY u.username',
    'row_count > 0',
    'Users with DBA or RESOURCE privilege who have no active sessions may be dormant',
    'Review dormant accounts. Revoke privileges from accounts that are no longer needed. Consider removing or locking them at the OS level.'
);

-- SECURITY — Configuration check
INSERT INTO _ifx_defs VALUES (
    'SEC-SQL-CFG-005-RC01',
    'Detect debug/trace flags (informix)',
    'SELECT cf_name, cf_effective FROM sysmaster:syscfgtab WHERE cf_name IN (''DUMPSHMEM'', ''DUMPCORE'', ''DUMPDIR'', ''DBSPACETEMP'', ''STACKSIZE'') ORDER BY cf_name',
    'row_count > 0',
    'Checks for debug-related configuration that should not be enabled in production',
    'Review DUMPSHMEM and DUMPCORE settings. Disable core dumps in production if not needed for IBM support cases.'
);

-- SECURITY — Default Ports
INSERT INTO _ifx_defs VALUES (
    'SEC-SQL-NET-002-RC01',
    'Detect listening port (informix)',
    'SELECT cf_name, cf_effective FROM sysmaster:syscfgtab WHERE cf_name IN (''NETTYPE'', ''DBSERVERNAME'', ''DBSERVERALIASES'') ORDER BY cf_name',
    'row_count > 0',
    'Returns network configuration including listening interfaces',
    'Verify the server is not exposed on default port 9088/9089 to untrusted networks. Use firewall rules and sqlhosts to restrict access.'
);

-- PERFORMANCE — Active Sessions Monitoring
INSERT INTO _ifx_defs VALUES (
    'PERF-SQL-CN-010-RC01',
    'Detect active sessions snapshot (informix)',
    'SELECT s.sid, s.username, s.uid, s.hostname, s.progname, s.connected, s.pid FROM sysmaster:syssessions s WHERE s.sid > 0 ORDER BY s.sid',
    'row_count > 0',
    'Returns all active sessions for connection monitoring',
    'Monitor session counts over time. Set up alerts when approaching NETTYPE limits.'
);

-- PERFORMANCE — Active Transactions Monitoring
INSERT INTO _ifx_defs VALUES (
    'PERF-SQL-TX-010-RC01',
    'Detect active transactions snapshot (informix)',
    'SELECT t.tx_id, t.tx_owner AS sid, s.username, s.hostname, s.progname, t.tx_logbeg, t.tx_loguniq, t.tx_flags FROM sysmaster:systrans t JOIN sysmaster:syssessions s ON s.sid = t.tx_owner ORDER BY t.tx_id',
    'row_count > 0',
    'Returns all active transactions for transaction monitoring',
    'Monitor for long-running transactions that may hold logical log space.'
);

-- SECURITY — Anomalous After-hours Activity
INSERT INTO _ifx_defs VALUES (
    'SEC-SQL-ACC-010-RC07',
    'Detect after-hours transaction activity (informix)',
    'SELECT s.sid, s.username, s.hostname, s.progname, s.connected, EXTEND(CURRENT, HOUR TO HOUR)::INT AS current_hour FROM sysmaster:syssessions s WHERE s.sid > 0 AND (EXTEND(CURRENT, HOUR TO HOUR)::INT < 7 OR EXTEND(CURRENT, HOUR TO HOUR)::INT >= 19) ORDER BY s.sid',
    'row_count > 0',
    'Active sessions outside business hours (before 07:00 or after 19:00) may indicate unauthorized activity',
    'Review sessions active outside business hours. Implement connection restrictions via trusted hosts or application-level controls.'
);

-- PERFORMANCE — Checkpoint I/O
INSERT INTO _ifx_defs VALUES (
    'PERF-SQL-IO-003-RC01',
    'Detect checkpoint stats (informix)',
    'SELECT p.name, p.value FROM sysmaster:sysprofile p WHERE p.name IN (''numckpts'', ''ckptwaits'', ''fgwrites'', ''lru_writes'', ''chunk_writes'') ORDER BY p.name',
    'row_count > 0',
    'Checkpoint and flush counters from sysprofile — high ckptwaits indicates checkpoint I/O pressure',
    'Tune RTO_SERVER_RESTART and CKPTINTVL in onconfig. Increase LRU_MAX_DIRTY and LRU_MIN_DIRTY to spread writes more evenly.'
);

-- ═══════════════════════════════════════════════════════════════
-- 3. CREATE ALL OBJECTS FROM TEMP TABLE
-- ═══════════════════════════════════════════════════════════════
DO $$
DECLARE
    r RECORD;
    v_step_id INT;
    v_path_id_high INT;
    v_path_id_med INT;
    v_res_step_id INT;
    v_res_path_id INT;
    v_count INT := 0;
BEGIN
    FOR r IN SELECT * FROM _ifx_defs
    LOOP
        -- Skip if this vendor already has a detection path for this root cause
        IF EXISTS (
            SELECT 1 FROM rootcause.detection_paths
            WHERE root_cause_id = r.root_cause_id AND vendor_slug = 'informix'
        ) THEN
            RAISE NOTICE 'Skipping % — already exists for informix', r.root_cause_id;
            CONTINUE;
        END IF;

        -- Ensure root cause has informix in vendors_applicable
        UPDATE rootcause.root_causes
        SET vendors_applicable = array_append(vendors_applicable, 'informix')
        WHERE root_cause_id = r.root_cause_id
          AND NOT ('informix' = ANY(vendors_applicable));

        -- Create detection step
        INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
        VALUES (
            'informix', 'query', r.step_name,
            json_build_object('sql', r.sql_text)::jsonb,
            json_build_object('condition', r.expected_cond, 'description', r.expected_desc)::jsonb
        ) RETURNING id INTO v_step_id;

        -- Create detection path (high risk)
        INSERT INTO rootcause.detection_paths (
            root_cause_id, vendor_slug, name, description, path_type, is_active
        ) VALUES (
            r.root_cause_id, 'informix',
            r.step_name || ' - high',
            r.expected_desc,
            'diagnostic', true
        ) RETURNING id INTO v_path_id_high;

        INSERT INTO rootcause.detection_path_steps (
            detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action
        ) VALUES (v_path_id_high, v_step_id, 1, 'confirmed', 'ruled_out');

        -- Create detection path (medium risk)
        INSERT INTO rootcause.detection_paths (
            root_cause_id, vendor_slug, name, description, path_type, is_active
        ) VALUES (
            r.root_cause_id, 'informix',
            r.step_name || ' - medium',
            r.expected_desc,
            'diagnostic', true
        ) RETURNING id INTO v_path_id_med;

        INSERT INTO rootcause.detection_path_steps (
            detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action
        ) VALUES (v_path_id_med, v_step_id, 1, 'confirmed', 'ruled_out');

        -- Create resolution step
        INSERT INTO rootcause.resolution_steps (
            vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible
        ) VALUES (
            'informix', 'recommendation',
            'Resolve: ' || r.step_name,
            json_build_object('action', r.resolution_text)::jsonb,
            'medium', false, true
        ) RETURNING id INTO v_res_step_id;

        -- Create resolution path
        INSERT INTO rootcause.resolution_paths (
            root_cause_id, vendor_slug, name, slug, description,
            execution_mode, risk_level, is_active
        ) VALUES (
            r.root_cause_id, 'informix',
            'Resolve: ' || r.step_name,
            'resolve-ifx-' || replace(lower(r.root_cause_id), '-', '_') || '-' || v_res_step_id,
            r.resolution_text,
            'supervised', 'medium', true
        ) RETURNING id INTO v_res_path_id;

        INSERT INTO rootcause.resolution_path_steps (
            resolution_path_id, resolution_step_id, step_order
        ) VALUES (v_res_path_id, v_res_step_id, 1);

        v_count := v_count + 1;
        RAISE NOTICE 'Created [%]: step=%, paths=%/%, res=%/%',
            r.root_cause_id, v_step_id, v_path_id_high, v_path_id_med, v_res_step_id, v_res_path_id;
    END LOOP;

    RAISE NOTICE 'Total Informix root causes created: %', v_count;
END;
$$;

-- ═══════════════════════════════════════════════════════════════
-- 4. VERIFY
-- ═══════════════════════════════════════════════════════════════
SELECT '=== Vendor ===' AS section;
SELECT slug, name, database_type_code FROM rootcause.vendors WHERE slug = 'informix';

SELECT '=== Detection Paths ===' AS section;
SELECT dp.root_cause_id, dp.name, dp.is_active
FROM rootcause.detection_paths dp
WHERE dp.vendor_slug = 'informix'
ORDER BY dp.root_cause_id;

SELECT '=== Detection Steps ===' AS section;
SELECT ds.id, ds.name, LEFT(ds.content->>'sql', 80) AS sql_preview
FROM rootcause.detection_steps ds
WHERE ds.vendor_slug = 'informix'
ORDER BY ds.id;

SELECT '=== In v_rootcauses View ===' AS section;
SELECT root_cause_id, root_cause_name, vendor_name, risk_level
FROM rootcause.v_rootcauses
WHERE vendor_name = 'informix'
ORDER BY root_cause_id;

SELECT '=== Summary ===' AS section;
SELECT
    (SELECT COUNT(*) FROM rootcause.detection_paths WHERE vendor_slug = 'informix') AS detection_paths,
    (SELECT COUNT(*) FROM rootcause.detection_steps WHERE vendor_slug = 'informix') AS detection_steps,
    (SELECT COUNT(*) FROM rootcause.resolution_paths WHERE vendor_slug = 'informix') AS resolution_paths,
    (SELECT COUNT(*) FROM rootcause.resolution_steps WHERE vendor_slug = 'informix') AS resolution_steps,
    (SELECT COUNT(DISTINCT root_cause_id) FROM rootcause.detection_paths WHERE vendor_slug = 'informix') AS root_causes_covered;

COMMIT;
