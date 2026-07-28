-- Foreign-key constraints, applied after all tables exist.
-- Idempotent: each FK is added only if its name isn't already present.

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'log' AND c.relname = 'access_review_decisions'
          AND con.conname = 'access_review_decisions_instance_id_fkey') THEN
        ALTER TABLE ONLY log.access_review_decisions
    ADD CONSTRAINT access_review_decisions_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES log.access_review_instances(instance_id);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'log' AND c.relname = 'access_review_instances'
          AND con.conname = 'access_review_instances_cycle_id_fkey') THEN
        ALTER TABLE ONLY log.access_review_instances
    ADD CONSTRAINT access_review_instances_cycle_id_fkey FOREIGN KEY (cycle_id) REFERENCES config.access_review_cycles(cycle_id);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'log' AND c.relname = 'attestations'
          AND con.conname = 'attestations_control_id_fkey') THEN
        ALTER TABLE ONLY log.attestations
    ADD CONSTRAINT attestations_control_id_fkey FOREIGN KEY (control_id) REFERENCES config.attestation_controls(control_id);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'log' AND c.relname = 'attestations'
          AND con.conname = 'attestations_period_id_fkey') THEN
        ALTER TABLE ONLY log.attestations
    ADD CONSTRAINT attestations_period_id_fkey FOREIGN KEY (period_id) REFERENCES config.attestation_periods(period_id);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'log' AND c.relname = 'firewall_audit_log'
          AND con.conname = 'firewall_audit_log_matched_policy_fkey') THEN
        ALTER TABLE ONLY log.firewall_audit_log
    ADD CONSTRAINT firewall_audit_log_matched_policy_fkey FOREIGN KEY (matched_policy) REFERENCES config.firewall_policies(policy_id);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'log' AND c.relname = 'incident_capa'
          AND con.conname = 'incident_capa_incident_id_fkey') THEN
        ALTER TABLE ONLY log.incident_capa
    ADD CONSTRAINT incident_capa_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES log.incidents(incident_id) ON DELETE CASCADE;
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'log' AND c.relname = 'incident_timeline'
          AND con.conname = 'incident_timeline_incident_id_fkey') THEN
        ALTER TABLE ONLY log.incident_timeline
    ADD CONSTRAINT incident_timeline_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES log.incidents(incident_id) ON DELETE CASCADE;
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'areas'
          AND con.conname = 'areas_database_type_id_fkey') THEN
        ALTER TABLE ONLY public.areas
    ADD CONSTRAINT areas_database_type_id_fkey FOREIGN KEY (database_type_id) REFERENCES public.database_types(id);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'detection_events'
          AND con.conname = 'detection_events_detection_path_id_fkey') THEN
        ALTER TABLE ONLY public.detection_events
    ADD CONSTRAINT detection_events_detection_path_id_fkey FOREIGN KEY (detection_path_id) REFERENCES public.detection_paths(id);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'detection_events'
          AND con.conname = 'detection_events_root_cause_id_fkey') THEN
        ALTER TABLE ONLY public.detection_events
    ADD CONSTRAINT detection_events_root_cause_id_fkey FOREIGN KEY (root_cause_id) REFERENCES public.root_causes(id);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'detection_events'
          AND con.conname = 'detection_events_vendor_id_fkey') THEN
        ALTER TABLE ONLY public.detection_events
    ADD CONSTRAINT detection_events_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES public.vendors(id);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'detection_path_steps'
          AND con.conname = 'detection_path_steps_detection_path_id_fkey') THEN
        ALTER TABLE ONLY public.detection_path_steps
    ADD CONSTRAINT detection_path_steps_detection_path_id_fkey FOREIGN KEY (detection_path_id) REFERENCES public.detection_paths(id) ON DELETE CASCADE;
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'detection_path_steps'
          AND con.conname = 'detection_path_steps_on_match_goto_fkey') THEN
        ALTER TABLE ONLY public.detection_path_steps
    ADD CONSTRAINT detection_path_steps_on_match_goto_fkey FOREIGN KEY (on_match_goto) REFERENCES public.detection_path_steps(id);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'detection_path_steps'
          AND con.conname = 'detection_path_steps_on_no_match_goto_fkey') THEN
        ALTER TABLE ONLY public.detection_path_steps
    ADD CONSTRAINT detection_path_steps_on_no_match_goto_fkey FOREIGN KEY (on_no_match_goto) REFERENCES public.detection_path_steps(id);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'detection_paths'
          AND con.conname = 'detection_paths_root_cause_id_fkey') THEN
        ALTER TABLE ONLY public.detection_paths
    ADD CONSTRAINT detection_paths_root_cause_id_fkey FOREIGN KEY (root_cause_id) REFERENCES public.root_causes(id);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'detection_paths'
          AND con.conname = 'detection_paths_superseded_by_id_fkey') THEN
        ALTER TABLE ONLY public.detection_paths
    ADD CONSTRAINT detection_paths_superseded_by_id_fkey FOREIGN KEY (superseded_by_id) REFERENCES public.detection_paths(id);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'detection_paths'
          AND con.conname = 'detection_paths_vendor_id_fkey') THEN
        ALTER TABLE ONLY public.detection_paths
    ADD CONSTRAINT detection_paths_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES public.vendors(id);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'issues'
          AND con.conname = 'issues_area_id_fkey') THEN
        ALTER TABLE ONLY public.issues
    ADD CONSTRAINT issues_area_id_fkey FOREIGN KEY (area_id) REFERENCES public.areas(id);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'issues'
          AND con.conname = 'issues_database_type_id_fkey') THEN
        ALTER TABLE ONLY public.issues
    ADD CONSTRAINT issues_database_type_id_fkey FOREIGN KEY (database_type_id) REFERENCES public.database_types(id);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'issues'
          AND con.conname = 'issues_domain_id_fkey') THEN
        ALTER TABLE ONLY public.issues
    ADD CONSTRAINT issues_domain_id_fkey FOREIGN KEY (domain_id) REFERENCES public.domains(id);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'resolution_actions'
          AND con.conname = 'resolution_actions_detection_event_id_fkey') THEN
        ALTER TABLE ONLY public.resolution_actions
    ADD CONSTRAINT resolution_actions_detection_event_id_fkey FOREIGN KEY (detection_event_id) REFERENCES public.detection_events(id);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'resolution_actions'
          AND con.conname = 'resolution_actions_resolution_path_id_fkey') THEN
        ALTER TABLE ONLY public.resolution_actions
    ADD CONSTRAINT resolution_actions_resolution_path_id_fkey FOREIGN KEY (resolution_path_id) REFERENCES public.resolution_paths(id);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'resolution_path_steps'
          AND con.conname = 'resolution_path_steps_on_failure_goto_fkey') THEN
        ALTER TABLE ONLY public.resolution_path_steps
    ADD CONSTRAINT resolution_path_steps_on_failure_goto_fkey FOREIGN KEY (on_failure_goto) REFERENCES public.resolution_path_steps(id);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'resolution_path_steps'
          AND con.conname = 'resolution_path_steps_on_success_goto_fkey') THEN
        ALTER TABLE ONLY public.resolution_path_steps
    ADD CONSTRAINT resolution_path_steps_on_success_goto_fkey FOREIGN KEY (on_success_goto) REFERENCES public.resolution_path_steps(id);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'resolution_path_steps'
          AND con.conname = 'resolution_path_steps_resolution_path_id_fkey') THEN
        ALTER TABLE ONLY public.resolution_path_steps
    ADD CONSTRAINT resolution_path_steps_resolution_path_id_fkey FOREIGN KEY (resolution_path_id) REFERENCES public.resolution_paths(id) ON DELETE CASCADE;
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'resolution_path_steps'
          AND con.conname = 'resolution_path_steps_resolution_step_id_fkey') THEN
        ALTER TABLE ONLY public.resolution_path_steps
    ADD CONSTRAINT resolution_path_steps_resolution_step_id_fkey FOREIGN KEY (resolution_step_id) REFERENCES public.resolution_steps(id);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'resolution_paths'
          AND con.conname = 'resolution_paths_root_cause_id_fkey') THEN
        ALTER TABLE ONLY public.resolution_paths
    ADD CONSTRAINT resolution_paths_root_cause_id_fkey FOREIGN KEY (root_cause_id) REFERENCES public.root_causes(id);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'resolution_paths'
          AND con.conname = 'resolution_paths_vendor_id_fkey') THEN
        ALTER TABLE ONLY public.resolution_paths
    ADD CONSTRAINT resolution_paths_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES public.vendors(id);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'resolution_steps'
          AND con.conname = 'resolution_steps_vendor_id_fkey') THEN
        ALTER TABLE ONLY public.resolution_steps
    ADD CONSTRAINT resolution_steps_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES public.vendors(id);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'root_causes'
          AND con.conname = 'root_causes_issue_id_fkey') THEN
        ALTER TABLE ONLY public.root_causes
    ADD CONSTRAINT root_causes_issue_id_fkey FOREIGN KEY (issue_id) REFERENCES public.issues(id);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'vendors'
          AND con.conname = 'vendors_database_type_id_fkey') THEN
        ALTER TABLE ONLY public.vendors
    ADD CONSTRAINT vendors_database_type_id_fkey FOREIGN KEY (database_type_id) REFERENCES public.database_types(id);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'rootcause' AND c.relname = 'issue_decision_tree_nodes'
          AND con.conname = 'issue_decision_tree_nodes_parent_node_id_fkey') THEN
        ALTER TABLE ONLY rootcause.issue_decision_tree_nodes
    ADD CONSTRAINT issue_decision_tree_nodes_parent_node_id_fkey FOREIGN KEY (parent_node_id) REFERENCES rootcause.issue_decision_tree_nodes(id) ON DELETE CASCADE;
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'rootcause' AND c.relname = 'issue_decision_tree_nodes'
          AND con.conname = 'issue_decision_tree_nodes_tree_id_fkey') THEN
        ALTER TABLE ONLY rootcause.issue_decision_tree_nodes
    ADD CONSTRAINT issue_decision_tree_nodes_tree_id_fkey FOREIGN KEY (tree_id) REFERENCES rootcause.issue_decision_trees(id) ON DELETE CASCADE;
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'rootcause' AND c.relname = 'issue_decision_trees'
          AND con.conname = 'issue_decision_trees_issue_id_fkey') THEN
        ALTER TABLE ONLY rootcause.issue_decision_trees
    ADD CONSTRAINT issue_decision_trees_issue_id_fkey FOREIGN KEY (issue_id) REFERENCES rootcause.issues(issue_id);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'rootcause' AND c.relname = 'issues'
          AND con.conname = 'issues_area_code_database_type_code_fkey') THEN
        ALTER TABLE ONLY rootcause.issues
    ADD CONSTRAINT issues_area_code_database_type_code_fkey FOREIGN KEY (area_code, database_type_code) REFERENCES rootcause.areas(code, database_type_code);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'rootcause' AND c.relname = 'issues'
          AND con.conname = 'issues_domain_code_fkey') THEN
        ALTER TABLE ONLY rootcause.issues
    ADD CONSTRAINT issues_domain_code_fkey FOREIGN KEY (domain_code) REFERENCES rootcause.domains(code);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'rootcause' AND c.relname = 'resolution_steps'
          AND con.conname = 'resolution_steps_vendor_slug_fkey') THEN
        ALTER TABLE ONLY rootcause.resolution_steps
    ADD CONSTRAINT resolution_steps_vendor_slug_fkey FOREIGN KEY (vendor_slug) REFERENCES rootcause.vendors(slug);
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'web' AND c.relname = 'chat_messages'
          AND con.conname = 'chat_messages_user_id_fkey') THEN
        ALTER TABLE ONLY web.chat_messages
    ADD CONSTRAINT chat_messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES web.users(id) ON DELETE CASCADE;
    END IF;
END $do$;

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'web' AND c.relname = 'refresh_tokens'
          AND con.conname = 'refresh_tokens_user_id_fkey') THEN
        ALTER TABLE ONLY web.refresh_tokens
    ADD CONSTRAINT refresh_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES web.users(id) ON DELETE CASCADE;
    END IF;
END $do$;

