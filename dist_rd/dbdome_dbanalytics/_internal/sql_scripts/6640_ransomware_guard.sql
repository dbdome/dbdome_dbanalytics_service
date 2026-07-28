-- =============================================================================
-- 6640_ransomware_guard.sql
--
-- Ransomware detection pack. Three new root causes under a new issue
-- SEC-SQL-AUD-031 "Ransomware Activity" (SEC/AUD/SQL, sqlserver, risk critical),
-- detected by the ransomware_guard analysis process over the SEC-SQL-ACC-011-RC02
-- active-transactions feed (sql_text):
--   SEC-SQL-AUD-031-RC01  Mass in-place encryption of data (ENCRYPTBY* / large 0x blobs in UPDATE)
--   SEC-SQL-AUD-031-RC02  Mass data-modification velocity (encryption sweep) -- threshold in
--                         config.global_params 'ransomware_mod_velocity' (default 50 / 10 min per login)
--   SEC-SQL-AUD-031-RC03  Ransom-note artifacts (ransom keywords / object names in sql_text)
--
-- Detection is process-based (detection_path is_active=false). On a hit the process
-- raises the alert (incident + mail + SIEM) and kills the session (dry-run by default,
-- gated by config.global_params 'blocker_dry_run'). Idempotent.
-- =============================================================================

DO $$
DECLARE r record; v_dp int; v_ds int; v_rp int; v_rs int;
BEGIN
    INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description)
    VALUES ('SEC-SQL-AUD-031','SEC','SQL','AUD','Ransomware Activity','ransomware-activity',
            'Behavioural indicators of database ransomware: in-place mass encryption of data, a high-velocity data-modification sweep, and ransom-note artifacts.')
    ON CONFLICT (issue_id) DO NOTHING;

    FOR r IN SELECT * FROM (VALUES
        ('SEC-SQL-AUD-031-RC01','Mass in-place encryption of data (ransomware)',
         'A user session is overwriting data with encrypted/binary values (ENCRYPTBYKEY/PASSPHRASE/CERT or large 0x blobs in UPDATE statements) - the signature of in-place ransomware encryption.'),
        ('SEC-SQL-AUD-031-RC02','Mass data-modification velocity (ransomware sweep)',
         'A single login is issuing an abnormally high number of data-modification statements in a short window (config.global_params ransomware_mod_velocity) - a ransomware encryption sweep across the schema.'),
        ('SEC-SQL-AUD-031-RC03','Ransom-note artifacts detected',
         'Active transaction SQL contains ransom-note indicators (e.g. "your files are encrypted", decrypt/bitcoin/.onion, readme/recover objects) - attacker leaving payment instructions.')
    ) AS t(rcid, name, descr)
    LOOP
        INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, vendors_applicable, topics)
        VALUES (r.rcid, 'SEC-SQL-AUD-031', r.name, lower(replace(r.rcid,'-','_')), r.descr,
                ARRAY['sqlserver'], ARRAY['ransomware','encryption','destructive','exfiltration'])
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
                        'description','Kill the offending session immediately (subject to blocker_dry_run), isolate the instance from the network, and restore affected data from a known-clean backup.'),
                    'critical', true, false)
            RETURNING id INTO v_rs;
            INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, status, is_active)
            VALUES (r.rcid,'sqlserver','Resolve: '||r.rcid||' (sqlserver)',
                    'resolve-'||lower(replace(r.rcid,'-','_'))||'-sqlserver',
                    'Kill the session, isolate the instance, and restore from a known-clean backup.',
                    'supervised','critical','authored', true)
            RETURNING id INTO v_rp;
            INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order)
            VALUES (v_rp, v_rs, 1);
        END IF;
    END LOOP;
END $$;

-- velocity threshold (tunable without a rebuild)
INSERT INTO config.global_params (key, value)
SELECT 'ransomware_mod_velocity', '50'
WHERE NOT EXISTS (SELECT 1 FROM config.global_params WHERE key='ransomware_mod_velocity');

-- register the analysis process
INSERT INTO metrics.registered_processes (process_name, is_active, interval, description)
SELECT 'ransomware_guard', true, 60,
       'Detect ransomware behaviour (mass encryption / modification-velocity / ransom artifacts) in SEC-SQL-ACC-011-RC02 active transactions; alert + kill session'
WHERE NOT EXISTS (SELECT 1 FROM metrics.registered_processes WHERE process_name='ransomware_guard');
