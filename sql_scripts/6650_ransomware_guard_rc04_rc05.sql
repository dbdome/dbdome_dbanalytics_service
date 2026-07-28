-- =============================================================================
-- 6650_ransomware_guard_rc04_rc05.sql
--
-- Complete the ransomware pack (issue SEC-SQL-AUD-031) with two more root causes,
-- also detected by the ransomware_guard process over SEC-SQL-ACC-011-RC02:
--   SEC-SQL-AUD-031-RC04  Bulk export followed by mass delete (double-extortion) -
--                         one login both exfiltrates (SELECT INTO / bcp / OPENROWSET /
--                         SELECT *) and destroys (TRUNCATE / DROP / DELETE-no-WHERE)
--                         within the window.
--   SEC-SQL-AUD-031-RC05  System command / OLE automation from a session - the
--                         ransomware delivery mechanism (xp_cmdshell, sp_OACreate/
--                         sp_OAMethod, xp_dirtree, sp_execute_external_script,
--                         BULK INSERT / OPENROWSET(BULK), xp_regwrite).
-- Idempotent.
-- =============================================================================

DO $$
DECLARE r record; v_dp int; v_ds int; v_rp int; v_rs int;
BEGIN
    FOR r IN SELECT * FROM (VALUES
        ('SEC-SQL-AUD-031-RC04','Bulk export followed by mass delete (double-extortion)',
         'A single login both exfiltrated data (bulk export: SELECT INTO / bcp / OPENROWSET / SELECT *) and destroyed data (TRUNCATE / DROP / DELETE without WHERE) within the same window - the double-extortion ransomware pattern.'),
        ('SEC-SQL-AUD-031-RC05','System command / OLE automation from a session (ransomware delivery)',
         'A session invoked OS command / external process capabilities (xp_cmdshell, sp_OACreate/sp_OAMethod, xp_dirtree, sp_execute_external_script, BULK INSERT / OPENROWSET(BULK), xp_regwrite) - the delivery/execution mechanism for ransomware and exfiltration.')
    ) AS t(rcid, name, descr)
    LOOP
        INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, vendors_applicable, topics)
        VALUES (r.rcid, 'SEC-SQL-AUD-031', r.name, lower(replace(r.rcid,'-','_')), r.descr,
                ARRAY['sqlserver'], ARRAY['ransomware','exfiltration','destructive','command execution'])
        ON CONFLICT (root_cause_id) DO NOTHING;

        IF NOT EXISTS (SELECT 1 FROM rootcause.detection_paths WHERE root_cause_id=r.rcid AND vendor_slug='sqlserver') THEN
            INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
            VALUES ('sqlserver','process','Detect '||r.rcid||' (sqlserver)',
                    jsonb_build_object('engine','process','process','ransomware_guard'),
                    jsonb_build_object('condition','row_count > 0','description',r.name))
            RETURNING id INTO v_ds;
            INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
            VALUES (r.rcid,'sqlserver','Detect '||r.rcid||' (sqlserver)',
                    'Process-based detection (ransomware_guard); not a collector SQL query.','diagnostic', false)
            RETURNING id INTO v_dp;
            INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
            VALUES (v_dp, v_ds, 1, 'confirmed','ruled_out');
        END IF;

        IF NOT EXISTS (SELECT 1 FROM rootcause.resolution_paths WHERE root_cause_id=r.rcid AND vendor_slug='sqlserver') THEN
            INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
            VALUES ('sqlserver','remediate','Resolve '||r.rcid||': kill session, isolate, restore from clean backup',
                    jsonb_build_object('action','kill_session',
                        'description','Kill the offending session (subject to blocker_dry_run), isolate the instance, and investigate exfiltration / command execution.'),
                    'critical', true, false)
            RETURNING id INTO v_rs;
            INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
            VALUES (r.rcid,'sqlserver','Resolve: '||r.rcid||' (sqlserver)',
                    'resolve-'||lower(replace(r.rcid,'-','_'))||'-sqlserver',
                    'Kill the session, isolate the instance, and investigate.',
                    'supervised','critical','authored', true)
            RETURNING id INTO v_rp;
            INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order)
            VALUES (v_rp, v_rs, 1);
        END IF;
    END LOOP;
END $$;
