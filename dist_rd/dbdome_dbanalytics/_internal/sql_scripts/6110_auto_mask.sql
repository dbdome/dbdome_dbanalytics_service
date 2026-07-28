-- ============================================================
-- webook_alerts auto-mask: when a rule has auto_mask = true (and is_active, and
-- risk_level = critical), the 'auto_mask' scheduler process applies SQL Server
-- Dynamic Data Masking to the sensitive columns surfaced by the PII detection
-- query results (monitoring.v_sec_sql_pri_001_rc12) on the matching server.
-- Gated by the same config.global_params 'masking_dry_run' switch as the manual
-- mask action, so it logs-only until masking is enabled.
-- ============================================================
ALTER TABLE config.webook_alerts ADD COLUMN IF NOT EXISTS auto_mask boolean DEFAULT false;

-- allow the dashboard toggle (/webook_alert_set) to set auto_mask
CREATE OR REPLACE PROCEDURE config.set_webook_alert(p_row_id integer, p_field text, p_value boolean)
LANGUAGE plpgsql AS $$
BEGIN
    IF p_row_id IS NULL THEN
        RAISE EXCEPTION 'set_webook_alert: p_row_id is required';
    END IF;
    IF p_field NOT IN ('send_mail_alert', 'send_siem_alert', 'send_diagnosis_evidence',
                       'blocker', 'auto_mask', 'is_active') THEN
        RAISE EXCEPTION 'set_webook_alert: invalid field %', p_field;
    END IF;
    EXECUTE format('UPDATE config.webook_alerts SET %I = $1 WHERE row_id = $2', p_field)
        USING p_value, p_row_id;
END $$;

-- register the scheduler process (every 5 minutes)
INSERT INTO metrics.registered_processes (process_name, is_active, interval, description)
SELECT 'auto_mask', true, 300,
       'Auto-apply Dynamic Data Masking to PII columns when a critical webook_alerts rule has auto_mask=true'
WHERE NOT EXISTS (SELECT 1 FROM metrics.registered_processes WHERE process_name = 'auto_mask');
