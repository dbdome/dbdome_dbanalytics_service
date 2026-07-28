-- ============================================================
-- Procedure behind the /webook_alert_set API (mirrors metrics.server_activate
-- for the server-enable flow). Toggling a flag on the Webhook Alerts Config
-- dashboard calls this via the web app instead of writing from Grafana directly.
--
-- Field is whitelisted (no dynamic-column injection). Idempotent.
-- ============================================================
CREATE OR REPLACE PROCEDURE config.set_webook_alert(p_row_id integer, p_field text, p_value boolean)
LANGUAGE plpgsql AS $$
BEGIN
    IF p_row_id IS NULL THEN
        RAISE EXCEPTION 'set_webook_alert: p_row_id is required';
    END IF;
    IF p_field NOT IN ('send_mail_alert', 'send_siem_alert', 'send_diagnosis_evidence',
                       'blocker', 'is_active') THEN
        RAISE EXCEPTION 'set_webook_alert: invalid field %', p_field;
    END IF;
    EXECUTE format('UPDATE config.webook_alerts SET %I = $1 WHERE row_id = $2', p_field)
        USING p_value, p_row_id;
END $$;
